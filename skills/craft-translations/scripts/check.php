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
// Braces have to balance the way they do in the source; ICU prints a stray
// "}" as text. Messages that Craft 5 sends to the control panel's JS, through
// registerTranslations() calls in the source directory, also have to work
// with Craft.formatMessage() in Craft.js. It splits each {arg, type, options}
// with JS split(',', 3), which drops everything after a third comma, so
// a plural or select whose options contain a comma, such as a nested
// {type, select, …} or {num, number}, throws “Message pattern is invalid”.
//
// Usage: php check.php <translations-dir> [--source=<dir>] [--missing] [--clashes]
// Needs the intl and mbstring extensions. Exits with 1 when it finds a problem.
// --source is the code to scan for registerTranslations() calls; it defaults
// to the translations directory's parent, such as src/. --missing also lists
// untranslated keys. --clashes lists translations shared by keys with
// different English text, which often means one word for two concepts or
// a value on the wrong key.

$dir = rtrim($argv[1] ?? '', '/');
$listMissing = in_array('--missing', $argv, true);
$listClashes = in_array('--clashes', $argv, true);
$sourceDir = dirname($dir);
foreach ($argv as $arg) {
    if (str_starts_with($arg, '--source=')) {
        $sourceDir = rtrim(substr($arg, 9), '/');
    }
}
$byValue = [];
$sources = glob("$dir/en/*.php") ?: [];
if (!$sources) {
    fwrite(STDERR, "Usage: php check.php <translations-dir> [--source=<dir>] [--missing] [--clashes]\n");
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

/**
 * Tokenizes a message the way Craft 5's Craft.js _tokenizePattern() does.
 * Returns false when the braces don't balance. Each argument is
 * [name, type, options] as JS split(',', 3) leaves it, plus what that
 * split drops.
 */
function jsTokens(string $s): array|false
{
    $chars = mb_str_split($s);
    $tokens = [];
    $depth = 0;
    $start = 0;
    foreach ($chars as $i => $c) {
        if ($c === '{' && $depth++ === 0) {
            $start = $i + 1;
        } elseif ($c === '}' && --$depth === 0) {
            $parts = explode(',', implode('', array_slice($chars, $start, $i - $start)));
            $tokens[] = [array_slice($parts, 0, 3), implode(',', array_slice($parts, 3))];
        } elseif ($depth < 0) {
            return false;
        }
    }
    return $depth === 0 ? $tokens : false;
}

/**
 * Returns why Craft 5's Craft.formatMessage() can't format a message as ICU
 * does, or null when it can.
 */
function jsProblem(string $s): ?string
{
    if (($tokens = jsTokens($s)) === false) {
        return 'unbalanced braces';
    }
    foreach ($tokens as [$parts, $dropped]) {
        $arg = trim($parts[0]);
        if ($dropped !== '') {
            return "a comma inside {{$arg}}’s options, after which Craft 5’s JS drops “" . mb_strimwidth(trim($dropped), 0, 40, '…') . '”';
        }
        if (!in_array(trim($parts[1] ?? ''), ['select', 'plural'], true) || !isset($parts[2])) {
            continue;
        }
        // Options are selector{message} pairs, each message a message itself.
        $options = jsTokens($parts[2]);
        if ($options === false) {
            return "unbalanced braces in {{$arg}}’s options";
        }
        foreach ($options as [$message, $messageDropped]) {
            if ($messageDropped !== '') {
                return "more than two commas in an option of {{$arg}}, after which Craft 5’s JS drops “" . mb_strimwidth(trim($messageDropped), 0, 40, '…') . '”';
            }
            if ($problem = jsProblem(implode(',', $message))) {
                return $problem;
            }
        }
    }
    return null;
}

/**
 * Returns the messages that registerTranslations() calls in PHP and Twig
 * files under $dir send to the control panel's JS, by category.
 */
function jsMessages(string $dir): array
{
    $messages = [];
    if (!is_dir($dir)) {
        return $messages;
    }
    $files = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($dir, FilesystemIterator::SKIP_DOTS));
    foreach ($files as $file) {
        $path = $file->getPathname();
        if (!preg_match('/\.(php|twig)$/', $path) || preg_match('#/(vendor|node_modules|translations)/#', $path)) {
            continue;
        }
        $code = file_get_contents($path);
        preg_match_all('/registerTranslations\(\s*([\'"])([\w.-]+)\1\s*,\s*\[/', $code, $calls, PREG_SET_ORDER | PREG_OFFSET_CAPTURE);
        foreach ($calls as $call) {
            $category = $call[2][0];
            $offset = $call[0][1] + strlen($call[0][0]);
            // Read the array's quoted strings up to its closing bracket.
            while (preg_match('/\G\s*(?:([\'"])((?:\\\\.|(?!\1).)*)\1\s*,?|\])/s', $code, $m, 0, $offset)) {
                $offset += strlen($m[0]);
                if (!isset($m[1]) || $m[1] === '') {
                    break;
                }
                $messages[$category][stripcslashes($m[2])] = true;
            }
        }
    }
    return $messages;
}

$jsMessages = jsMessages($sourceDir);
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
            } elseif (jsTokens($value) === false && jsTokens($en[$key]) !== false) {
                $issue = 'unbalanced braces';
            } elseif (isset($jsMessages[basename($category, '.php')][$key]) && !jsProblem($en[$key]) && $jsProblem = jsProblem($value)) {
                $issue = "Craft 5’s JS can’t format it: $jsProblem";
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
