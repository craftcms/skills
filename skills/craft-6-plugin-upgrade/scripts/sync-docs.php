#!/usr/bin/env php
<?php

declare(strict_types=1);

/**
 * Refresh the bundled snapshot of the Craft 6.x extension docs.
 *
 * Copies docs/6.x/extend/*.md plus upgrade.md, compatibility.md and requirements.md
 * from https://github.com/craftcms/docs into references/docs/, converting the
 * VuePress-specific syntax to plain Markdown, and writes references/docs/INDEX.md
 * with the source commit so readers know how old the snapshot is.
 *
 * Maintainers only: this deletes and rebuilds references/docs/ and uses the network.
 * It is not part of the upgrade workflow.
 *
 * Usage:
 *     php scripts/sync-docs.php                     # shallow, sparse clone of the default branch
 *     php scripts/sync-docs.php --ref=some-branch   # a different branch or tag
 *     php scripts/sync-docs.php --source=~/docs     # use an existing local checkout instead
 *
 * Requires PHP 8.1+ and git. No Composer packages.
 */

const REPO_URL = 'https://github.com/craftcms/docs.git';
const SITE = 'https://craftcms.com/docs/';

// Link aliases defined in the docs' VuePress config (docs/.vuepress/anchor-prefixes.js).
const ALIASES = [
    'laravel' => 'https://laravel.com/framework/docs/13.x/',
    'guide' => 'https://www.yiiframework.com/doc/guide/2.0/en/',
    'repo' => 'https://github.com/',
    'kb' => 'https://craftcms.com/knowledge-base/',
    'plugin' => 'https://plugins.craftcms.com/',
    'craftcom' => 'https://craftcms.com/',
];

// Aliases that refer to API or config entries. They are rendered as inline code.
const CODE_ALIASES = ['craft6', 'craft5', 'craft4', 'craft3', 'config5', 'config4', 'config3', 'yii2', 'yii1'];

const CALLOUTS = ['tip' => 'Tip', 'warning' => 'Warning', 'danger' => 'Danger', 'note' => 'Note'];

$skillRoot = dirname(__DIR__);
$outDir = $skillRoot . '/references/docs';

function run(string $command, ?string $cwd = null): string
{
    $full = ($cwd !== null ? 'cd ' . escapeshellarg($cwd) . ' && ' : '') . $command . ' 2>&1';
    exec($full, $output, $status);
    if ($status !== 0) {
        fwrite(STDERR, "error: command failed: $command\n" . implode("\n", $output) . "\n");
        exit(1);
    }

    return trim(implode("\n", $output));
}

function removeTree(string $path): void
{
    if (!file_exists($path) && !is_link($path)) {
        return;
    }
    if (is_link($path) || is_file($path)) {
        unlink($path);

        return;
    }
    foreach (scandir($path) as $entry) {
        if ($entry !== '.' && $entry !== '..') {
            removeTree($path . '/' . $entry);
        }
    }
    rmdir($path);
}

function convertLinkTarget(string $target): string
{
    // Expand aliases like laravel:events#x, and make site-absolute paths absolute URLs.
    if (preg_match('~^([a-z0-9]+):(.*)$~s', $target, $m) && isset(ALIASES[$m[1]])) {
        return ALIASES[$m[1]] . $m[2];
    }
    if (str_starts_with($target, '/')) {
        return SITE . ltrim($target, '/');
    }

    return $target;
}

function convertInline(string $line): string
{
    // <craft5:craft\db\Migration::EVENT_AFTER_UP> and <config5:disabledPlugins>
    $line = preg_replace_callback(
        '~<([a-z0-9]+):([^>\s]+)>~',
        fn (array $m) => in_array($m[1], CODE_ALIASES, true) ? "`{$m[2]}`" : $m[0],
        $line,
    );

    // [text](target)
    $line = preg_replace_callback(
        '~\]\(([^)\s]+)\)~',
        fn (array $m) => '](' . convertLinkTarget($m[1]) . ')',
        $line,
    );

    // <See path="registries.md" />
    $line = preg_replace_callback(
        '~<See path="([^"]+)"(?:\s+description="([^"]*)")?\s*/>~',
        fn (array $m) => "See [{$m[1]}]({$m[1]})." . (($m[2] ?? '') !== '' ? " {$m[2]}" : ''),
        $line,
    );

    // <Journey path="Settings, Email" />
    $line = preg_replace_callback(
        '~<Journey path="([^"]+)"\s*/>~',
        fn (array $m) => '**' . str_replace(', ', ' → ', $m[1]) . '**',
        $line,
    );

    // <Icon type="cog" />
    return preg_replace('~<Icon type="([^"]+)"\s*/>~', '(\1 icon)', $line);
}

/** Turn the <ul><li><IconLink .../></li></ul> tile lists into plain bullet lists. */
function flattenIconLinks(string $text): string
{
    $attr = function (string $block, string $name): string {
        return preg_match('~' . $name . '="([^"]*)"~', $block, $m) ? $m[1] : '';
    };

    // Only touch <ul> blocks that hold IconLink tiles; other <ul>/<li> markup is code samples.
    return preg_replace_callback(
        '~<ul\b[^>]*>(?:(?!</ul>).)*?<IconLink\b.*?</ul>\s*\n?~s',
        function (array $block) use ($attr) {
            preg_match_all('~<IconLink\b(.*?)/>~s', $block[0], $items);
            $bullets = array_map(
                fn (string $i) => '- [' . $attr($i, 'title') . '](' . $attr($i, 'link') . '): ' . $attr($i, 'subtitle'),
                $items[1],
            );

            return implode("\n", $bullets) . "\n\n";
        },
        $text,
    );
}

function convert(string $text): string
{
    $text = flattenIconLinks($text);
    $out = [];
    $stack = []; // open ::: containers: a callout name, "code" or "block"
    $inFence = false;
    $top = function () use (&$stack) {
        return $stack === [] ? null : $stack[count($stack) - 1];
    };

    foreach (preg_split('~\r\n|\r|\n~', $text) as $line) {
        if (preg_match('~^(\s*)```(.*)$~', $line, $fence)) {
            if (!$inFence) {
                $inFence = true;
                // ```php{5}  or  ```php Event Class  ->  ```php
                preg_match('~^([A-Za-z0-9_+-]*)~', trim($fence[2]), $lang);
                $line = $fence[1] . '```' . $lang[1];
            } else {
                $inFence = false;
            }
            $out[] = ($top() === null || in_array($top(), ['code', 'block'], true)) ? $line : '> ' . $line;
            continue;
        }

        if ($inFence) {
            $out[] = ($top() !== null && isset(CALLOUTS[$top()])) ? '> ' . $line : $line;
            continue;
        }

        if (trim($line) === '<!-- more -->') {
            continue;
        }

        if (preg_match('~^:::\s*(\w+)?\s*$~', $line, $m)) {
            $kind = $m[1] ?? '';
            if ($kind !== '') {
                if (isset(CALLOUTS[$kind])) {
                    $stack[] = $kind;
                    $out[] = '> **' . CALLOUTS[$kind] . ':**';
                } else { // `::: code` and anything unknown: a plain group
                    $stack[] = 'code';
                }
            } elseif ($stack !== []) {
                $closed = array_pop($stack);
                if (isset(CALLOUTS[$closed])) {
                    $out[] = '';
                }
            }
            continue;
        }

        if (preg_match('~^<Block label="([^"]+)">\s*$~', $line, $block)) {
            $stack[] = 'block';
            $out[] = '**' . $block[1] . '**';
            continue;
        }
        if (trim($line) === '</Block>') {
            if ($top() === 'block') {
                array_pop($stack);
            }
            continue;
        }

        $line = convertInline($line);
        if ($top() !== null && isset(CALLOUTS[$top()])) {
            $line = trim($line) !== '' ? '> ' . $line : '>';
        }
        $out[] = $line;
    }

    return rtrim(implode("\n", $out)) . "\n";
}

function firstHeading(string $text): string
{
    foreach (preg_split('~\r\n|\r|\n~', $text) as $line) {
        if (str_starts_with($line, '# ')) {
            return trim(substr($line, 2));
        }
    }

    return '';
}

// --- main -------------------------------------------------------------------

$options = getopt('h', ['source:', 'ref:', 'help']);
if (isset($options['h']) || isset($options['help'])) {
    echo "Usage: php scripts/sync-docs.php [--source=PATH] [--ref=BRANCH]\n";
    exit(0);
}

$tmp = null;
if (isset($options['source'])) {
    $source = $options['source'];
    if (str_starts_with($source, '~')) {
        $source = getenv('HOME') . substr($source, 1);
    }
    $root = realpath($source);
    if ($root === false) {
        fwrite(STDERR, "error: --source path not found: {$options['source']}\n");
        exit(1);
    }
} else {
    $tmp = sys_get_temp_dir() . '/craft-docs-' . bin2hex(random_bytes(4));
    $root = $tmp . '/docs';
    mkdir($tmp, 0777, true);
    fwrite(STDERR, 'Cloning ' . REPO_URL . " ...\n");
    $branch = isset($options['ref']) ? ' --branch ' . escapeshellarg($options['ref']) : '';
    run('git clone --depth 1 --filter=blob:none --sparse' . $branch . ' ' . escapeshellarg(REPO_URL) . ' ' . escapeshellarg($root));
    run('git sparse-checkout set docs/6.x', $root);
}

try {
    $docs6 = $root . '/docs/6.x';
    if (!is_dir($docs6 . '/extend')) {
        fwrite(STDERR, "error: $docs6/extend not found. Is --source a craftcms/docs checkout?\n");
        exit(1);
    }

    $sha = run('git rev-parse HEAD', $root);
    $commitDate = run('git log -1 --format=%cs', $root);
    $branch = $options['ref'] ?? run('git rev-parse --abbrev-ref HEAD', $root);

    $sources = glob($docs6 . '/extend/*.md');
    sort($sources);
    foreach (['upgrade.md', 'compatibility.md', 'requirements.md'] as $name) {
        if (is_file($docs6 . '/' . $name)) {
            $sources[] = $docs6 . '/' . $name;
        }
    }

    removeTree($outDir);
    mkdir($outDir, 0777, true);

    $rows = [];
    foreach ($sources as $src) {
        $text = file_get_contents($src);
        $rel = substr($src, strlen($docs6) + 1);
        $dest = $outDir . '/' . $rel;
        if (!is_dir(dirname($dest))) {
            mkdir(dirname($dest), 0777, true);
        }
        $converted = convert($text);
        file_put_contents($dest, $converted);
        $stub = count(preg_split('~\r\n|\r|\n~', trim($converted))) <= 1;
        $rows[] = [$rel, firstHeading($text), $stub];
    }
} finally {
    if ($tmp !== null) {
        removeTree($tmp);
    }
}

$lines = [
    '# Craft 6.x extension docs (snapshot)',
    '',
    'Generated by `scripts/sync-docs.php`. Do not edit by hand; re-run the script to refresh.',
    '',
    '- Source: https://github.com/craftcms/docs (`docs/6.x/extend/`, plus `upgrade`, `compatibility` and `requirements`)',
    "- Branch: `$branch`",
    "- Commit: `$sha` ($commitDate)",
    '- Synced: ' . gmdate('Y-m-d'),
    '',
    'Craft 6 is in alpha, so this snapshot may be behind. If it conflicts with the installed '
        . '`craftcms/cms` 6.x source, trust the source and say so. Published version: https://craftcms.com/docs/6.x/extend/',
    '',
    'VuePress syntax (callouts, `<Block>`, `<See>`, link aliases) has been converted to plain Markdown. '
        . 'A few links are broken upstream (missing `.md`, typos). They are copied as-is.',
    '',
    '| File | Title |',
    '| --- | --- |',
];
foreach ($rows as [$name, $title, $stub]) {
    $lines[] = "| [$name]($name) | $title" . ($stub ? ' (empty stub upstream)' : '') . ' |';
}
file_put_contents($outDir . '/INDEX.md', implode("\n", $lines) . "\n");

echo 'Wrote ' . count($rows) . ' files to references/docs from ' . substr($sha, 0, 9) . " ($commitDate)\n";
