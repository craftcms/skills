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
// whose {type} values are translated. Those branches never match, unless
// the placeholder receives a raw value such as an API enum. It also warns
// about plurals that lost the source's explicit selectors (=1), empty
// plural category branches (one {}), ‘ used as an apostrophe, and straight
// quotes or apostrophes outside code, HTML tags, and inch or foot marks.
// Warnings don't change the exit code.
//
// Usage: php check.php <translations-dir> [--missing] [--clashes]
// Needs the intl and mbstring extensions. Exits with 1 when it finds a problem. --missing
// also lists untranslated keys. --clashes lists translations shared by keys
// with different English text, which often means one word for two concepts
// or a value on the wrong key.

$dir = rtrim($argv[1] ?? '', '/');
$listMissing = in_array('--missing', $argv, true);
$listClashes = in_array('--clashes', $argv, true);
$byValue = [];
$sources = glob("$dir/en/*.php") ?: [];
if (!$sources) {
    fwrite(STDERR, "Usage: php check.php <translations-dir> [--missing] [--clashes]\n");
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
        // ICU apostrophe quoting: '' prints ', and a ' before { or } quotes
        // text up to the next ', so a placeholder inside it prints literally.
        if ($c === "'" && $i < $len && $s[$i] === "'") {
            $i++;
            continue;
        }
        if ($c === "'" && $i < $len && ($s[$i] === '{' || $s[$i] === '}')) {
            while ($i < $len && !($s[$i] === "'" && ($s[$i + 1] ?? '') !== "'")) {
                $i += $s[$i] === "'" ? 2 : 1;
            }
            $i++;
            continue;
        }
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
 * Returns [argument, type, key, body] for the branches of every plural,
 * select, and selectordinal argument in an ICU message.
 */
function branches(string $s): array
{
    $branches = [];
    preg_match_all('/\{\s*(\w+)\s*,\s*(plural|select|selectordinal)\s*,/u', $s, $m, PREG_OFFSET_CAPTURE);
    foreach ($m[0] as $n => [$match, $offset]) {
        $i = $offset + strlen($match);
        while (preg_match('/\G\s*(?:offset:\d+\s*)?([^\s{}]+)\s*\{/u', $s, $b, 0, $i)) {
            $i += strlen($b[0]);
            $start = $i;
            for ($depth = 1; $i < strlen($s) && $depth > 0; $i++) {
                $depth += ['{' => 1, '}' => -1][$s[$i]] ?? 0;
            }
            $branches[] = [$m[1][$n][0], $m[2][$n][0], $b[1], substr($s, $start, $i - $start - 1)];
        }
    }
    return $branches;
}

/**
 * Returns the explicit selectors (=0, =1, and so on) of each plural argument,
 * keyed by argument name.
 */
function explicitSelectors(string $s): array
{
    $selectors = [];
    foreach (branches($s) as [$arg, $type, $key]) {
        if ($type !== 'select' && str_starts_with($key, '=')) {
            $selectors[$arg][] = $key;
        }
    }
    return $selectors;
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
            foreach (branches($value) as [$arg, $type, $branchKey, $body]) {
                if ($type === 'select' && $branchKey !== 'other' && !isset($terms[$lang][mb_strtolower($branchKey)])) {
                    echo "  warning: {{$arg}} select key “{$branchKey}” isn’t a $lang translation: $key\n";
                }
                // An empty "one" branch also catches numbers like fr 0 or ru 21,
                // which then print nothing instead of falling through to "other".
                if ($type !== 'select' && trim($body) === '' && in_array($branchKey, ['zero', 'one', 'two', 'few', 'many'], true)) {
                    echo "  warning: empty {{$arg}} branch “{$branchKey}”: $key\n";
                }
            }
            // A translation may drop a plural its language doesn't need, but one
            // that keeps it has to keep the source's explicit selectors.
            $own = explicitSelectors($value);
            $plurals = array_column(array_filter(branches($value), fn($b) => $b[1] !== 'select'), 0);
            foreach (explicitSelectors($en[$key]) as $arg => $selectors) {
                if (in_array($arg, $plurals, true) && $lost = array_diff($selectors, $own[$arg] ?? [])) {
                    echo "  warning: {{$arg}} lost the source’s " . implode(', ', $lost) . " branch: $key\n";
                }
            }
            if (preg_match('/\p{L}‘/u', $value)) {
                echo "  warning: ‘ used as an apostrophe: $key\n";
            }
            // Code spans, HTML tags, and inch or foot marks keep straight quotes.
            if (preg_match('/[\'"]/', preg_replace(['/`[^`]*`/', '/<[^>]*>/', '/(?<=\d)[\'"]/'], '', $value))) {
                echo "  warning: straight quote or apostrophe: $key\n";
            }
            if ($listClashes) {
                $byValue[$lang][mb_strtolower($value)][] = $key;
            }
        }
    }
}
if ($listClashes) {
    echo "== clashes\n";
    foreach ($byValue as $lang => $values) {
        foreach ($values as $value => $keys) {
            // Keys that differ only in case or final punctuation are the same term.
            $distinct = array_unique(array_map(fn($k) => rtrim(mb_strtolower($k), '.:?!…'), $keys));
            if (count($distinct) > 1) {
                echo "$lang  “{$value}”: " . implode(' | ', $keys) . "\n";
            }
        }
    }
}
exit($problems ? 1 : 0);
