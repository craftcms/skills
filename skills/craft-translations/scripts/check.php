<?php
// Checks the translation files in a translations directory, such as
// src/translations, against their English source files: keys that aren't in
// the source, messages that aren't valid ICU, and placeholders that the
// translation dropped. Each file in en/ is a message category (app, commerce,
// a plugin handle, and so on), checked against the same-named file in every
// other language folder.
//
// It also warns about select branches whose key isn't a translation anywhere
// in that language's folder, such as an English "draft" branch in a language
// whose {type} values are translated. Those branches never match. Warnings
// don't change the exit code, since a select can match names from another
// category, such as Craft's own app.php.
//
// Usage: php check.php <translations-dir> [--missing]
// Needs the intl and mbstring extensions. Exits with 1 when it finds a problem. --missing
// also lists untranslated keys.

$dir = rtrim($argv[1] ?? '', '/');
$listMissing = in_array('--missing', $argv, true);
$sources = glob("$dir/en/*.php") ?: [];
if (!$sources) {
    fwrite(STDERR, "Usage: php check.php <translations-dir> [--missing]\n");
    exit(2);
}

/**
 * Returns the argument names in an ICU message. By default, only top-level
 * arguments other than plural and select arguments count, since a translation
 * may drop those or the placeholders in their branches when its language
 * doesn't need them. With $all, every argument counts, including ones inside
 * branches, where a translation may move a placeholder.
 */
function icuArgs(string $s, bool $all = false, int &$i = 0, bool $nested = false): array
{
    $args = [];
    $len = strlen($s);
    while ($i < $len) {
        $c = $s[$i++];
        if ($c === '}' && $nested) {
            return $args;
        }
        if ($c !== '{') {
            continue;
        }
        preg_match('/\G\s*(\w+)\s*(?:,\s*(\w+)\s*)?/', $s, $m, 0, $i);
        $i += strlen($m[0] ?? '');
        $type = $m[2] ?? null;
        if ($all || (!$nested && !in_array($type, ['plural', 'select', 'selectordinal'], true))) {
            $args[] = $m[1] ?? '';
        }
        if (in_array($type, ['plural', 'select', 'selectordinal'], true)) {
            $i++; // the comma before the branches
            while ($i < $len && preg_match('/\G\s*(?:offset:\d+\s*)?([=\w]+)\s*\{/', $s, $b, 0, $i)) {
                $i += strlen($b[0]);
                $args = array_merge($args, icuArgs($s, $all, $i, true));
            }
        }
        // Skip the rest of the argument, such as its number or date format.
        for ($depth = 1; $i < $len && $depth > 0; $i++) {
            $depth += ['{' => 1, '}' => -1][$s[$i]] ?? 0;
        }
    }
    return $args;
}

/**
 * Returns [argument, key] pairs for the branches of every select argument in
 * an ICU message, other than `other`.
 */
function selectKeys(string $s): array
{
    $keys = [];
    preg_match_all('/\{\s*(\w+)\s*,\s*select\s*,/u', $s, $m, PREG_OFFSET_CAPTURE);
    foreach ($m[0] as $n => [$match, $offset]) {
        $i = $offset + strlen($match);
        while (preg_match('/\G\s*([^\s{}]+)\s*\{/u', $s, $b, 0, $i)) {
            $i += strlen($b[0]);
            for ($depth = 1; $i < strlen($s) && $depth > 0; $i++) {
                $depth += ['{' => 1, '}' => -1][$s[$i]] ?? 0;
            }
            if ($b[1] !== 'other') {
                $keys[] = [$m[1][$n][0], $b[1]];
            }
        }
    }
    return $keys;
}

$problems = 0;
$terms = [];
foreach ($sources as $source) {
    $category = basename($source);
    $en = require $source;
    echo "== $category\n";
    foreach (glob("$dir/*/$category") as $file) {
        $lang = basename(dirname($file));
        if ($lang === 'en') {
            continue;
        }
        if (!isset($terms[$lang])) {
            // Every translated string in the language's folder, which select
            // keys on translated names have to match.
            $terms[$lang] = [];
            foreach (glob("$dir/$lang/*.php") as $langFile) {
                foreach (require $langFile as $value) {
                    $terms[$lang][mb_strtolower($value)] = true;
                }
            }
        }
        $translations = require $file;
        $missing = array_diff_key($en, $translations);
        printf("%-6s %d of %d translated\n", $lang, count($en) - count($missing), count($en));
        if ($listMissing) {
            foreach (array_keys($missing) as $key) {
                echo "  missing: $key\n";
            }
        }
        foreach ($translations as $key => $value) {
            $issue = null;
            if (!isset($en[$key])) {
                $issue = "not in en/$category";
            } elseif (msgfmt_create('en', $en[$key]) === null) {
                continue; // The source isn't an ICU message, such as an email body.
            } elseif (msgfmt_create($lang, $value) === null) {
                $issue = 'invalid ICU message';
            } elseif ($lost = array_diff(icuArgs($key), icuArgs($value, true))) {
                $issue = 'missing placeholder {' . implode('}, {', array_unique($lost)) . '}';
            }
            if ($issue) {
                $problems++;
                echo "  $issue: $key\n";
                continue;
            }
            foreach (selectKeys($value) as [$arg, $selectKey]) {
                if (!isset($terms[$lang][mb_strtolower($selectKey)])) {
                    echo "  warning: {{$arg}} select key “{$selectKey}” isn’t a $lang translation: $key\n";
                }
            }
        }
    }
}
exit($problems ? 1 : 0);
