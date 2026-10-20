#!/usr/bin/env bash
# Inventory Craft 5 / Yii 2 APIs in a plugin or module so an upgrade can be planned.
# Usage: scan-craft5.sh [path]   (defaults to the current directory)
#        VERBOSE=1 scan-craft5.sh [path]   also prints the first matches for each area
# Read-only. Prints match counts per area, the plugin's own events, and the package layout.
# Patterns are heuristics: review the hits, they are not a complete or exact list.
#
# Classes are matched two ways: by fully qualified name (`extends \craft\db\Migration`)
# and by short name when the file imports the class (`use craft\db\Migration;` ... `extends Migration`).

set -euo pipefail

target="${1:-.}"

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep (rg) is required." >&2
  exit 1
fi

if [ ! -d "$target" ]; then
  echo "Not a directory: $target" >&2
  exit 1
fi

globs=(
  --glob '*.php' --glob '*.twig' --glob '*.html' --glob 'composer.json'
  --glob '!vendor/**' --glob '!node_modules/**' --glob '!.git/**'
  --glob '!ecs.php' --glob '!rector.php'
)

# The plugin's own PSR-4 namespaces (read from composer.json). A Craft 5 plugin often lives in `craft\myplugin`,
# so imports of its own classes must not count as Craft or Yii imports.
own_namespaces=()
if [ -f "$target/composer.json" ] && command -v python3 >/dev/null 2>&1; then
  while IFS= read -r ns; do
    [ -n "$ns" ] && own_namespaces+=("$ns")
  done < <(python3 - "$target/composer.json" <<'PY' 2>/dev/null || true
import json, sys
data = json.load(open(sys.argv[1]))
for section in ('autoload', 'autoload-dev'):
    for ns in (data.get(section, {}).get('psr-4', {}) or {}):
        print(ns.rstrip('\\'))
PY
)
fi

# without_own_namespaces: drop `use <own namespace>\...` lines from matches read on stdin.
without_own_namespaces() {
  local out ns
  out=$(cat)
  if [ "${#own_namespaces[@]}" -gt 0 ]; then
    for ns in "${own_namespaces[@]}"; do
      out=$(printf '%s\n' "$out" | grep -vF -e "use ${ns}\\" || true)
    done
  fi
  [ -n "$out" ] && printf '%s\n' "$out"
  return 0
}

labels=()
refs=()
patterns=()
imports=()

# add <label> <reference file> <ripgrep pattern> [<import>:<ShortName>,...]
add() {
  labels+=("$1")
  refs+=("$2")
  patterns+=("$3")
  imports+=("${4:-}")
}

add 'Plugin class and settings' plugin-class.md \
  'extends \\?craft\\base\\Plugin|createSettingsModel|function init\(|setComponents' \
  'craft\\base\\Plugin:Plugin'
add 'Yii service locator' services-and-di.md \
  'Craft::\$app|Yii::\$app|Craft::createObject|Yii::createObject'
add 'Static lookups (use container)' services-and-di.md \
  '::getInstance\(\)'
add 'Events' events-and-registries.md \
  'Event::on\(|EVENT_[A-Z_]+|RegisterComponentTypesEvent|yii\\base\\Event|->trigger\(|hasEventHandlers' \
  'craft\\events\\CancelableEvent:CancelableEvent,yii\\base\\Event:Event'
add 'Controllers and routing' http-and-auth.md \
  'extends \\?craft\\(web|console)\\Controller|function action[A-Z]|allowAnonymous|requirePostRequest|requireLogin|requirePermission|requireAdmin|URL_RULES|getBodyParam|getRequiredBodyParam|getIsSiteRequest' \
  'craft\\web\\Controller:Controller,craft\\console\\Controller:Controller'
add 'Models, records, validation' models-and-validation.md \
  'extends \\?craft\\base\\Model|craft\\db\\(ActiveRecord|Record)|function defineRules|behaviors\(\)' \
  'craft\\base\\Model:Model,craft\\db\\ActiveRecord:ActiveRecord,craft\\db\\Record:Record,craft\\base\\Behavior:Behavior'
add 'Migrations' database.md \
  'extends \\?craft\\db\\Migration|createTable\(|addColumn\(|createIndex\(|addForeignKey\(|safeUp|safeDown' \
  'craft\\db\\Migration:Migration'
add 'Twig and templates' templates-and-twig.md \
  'renderTemplate|renderPageTemplate|AbstractExtension|CraftVariable|registerAssetBundle|TEMPLATE_MODE|craft\.app\b|\{% *import ["\x27]_includes/forms|forms\.[A-Za-z]+Field|\{% *(js|css|do|exit|requireLogin|requirePermission) ' \
  'craft\\web\\twig\\variables\\CraftVariable:CraftVariable'
add 'Fields, widgets, elements' fields-widgets-forms.md \
  'extends \\?craft\\base\\(Field|Widget|Element)|getSettingsHtml|getInputHtml|inputHtml|queryCondition|settingsHtml' \
  'craft\\base\\Field:Field,craft\\base\\Widget:Widget,craft\\base\\Element:Element,craft\\base\\Utility:Utility'
add 'Console and queue' other-areas.md \
  'extends \\?craft\\queue\\BaseJob|function execute\(|Craft::\$app->getQueue|Queue::push' \
  'craft\\queue\\BaseJob:BaseJob'
add 'Translation and logging' other-areas.md \
  'Craft::t\(|Craft::(info|warning|error|trace)\(|Yii::(info|warning|error|trace)\('
add 'Asset bundles and filesystems' other-areas.md \
  'extends \\?craft\\web\\AssetBundle|extends \\?craft\\base\\Fs|craft\\fs\\' \
  'craft\\web\\AssetBundle:AssetBundle,craft\\base\\Fs:Fs'
add 'Other yii/craft imports' required-changes.md \
  '^use (yii|craft)\\'

# matches <pattern> <import specs>: print file:line matches, by FQN pattern and by imported short name.
matches() {
  { matches_raw "$@"; } | without_own_namespaces
}

matches_raw() {
  local pattern="$1" specs="$2" pair import short file
  local pairs=() files=()
  rg --no-heading --line-number "${globs[@]}" -e "$pattern" "$target" 2>/dev/null || true
  [ -z "$specs" ] && return 0
  IFS=',' read -r -a pairs <<<"$specs"
  for pair in "${pairs[@]}"; do
    import="${pair%%:*}"
    short="${pair##*:}"
    while IFS= read -r file; do
      [ -z "$file" ] && continue
      rg --no-heading --line-number --with-filename -e "(extends|implements) ${short}\b" "$file" 2>/dev/null || true
    done < <(rg -l --glob '*.php' --glob '!vendor/**' -e "^use ${import}( as [A-Za-z_]+)?;" "$target" 2>/dev/null || true)
  done
}

echo "Scanning: $target"
echo

total=${#labels[@]}
i=0
while [ "$i" -lt "$total" ]; do
  count=$(matches "${patterns[$i]}" "${imports[$i]}" | sort -u | wc -l | tr -d ' ')
  printf '%-32s %5s hits   -> references/%s\n' "${labels[$i]}" "$count" "${refs[$i]}"
  i=$((i + 1))
done

echo
echo "Own events and extension surface (decide whether to keep a compatibility layer):"
own=$(rg --no-heading --line-number "${globs[@]}" \
  -e 'const EVENT_[A-Z_]+' -e 'class [A-Za-z]+ extends [A-Za-z\\]*Event\b' -e '(Event::trigger|->trigger)\(' \
  "$target" 2>/dev/null || true)
if [ -n "$own" ]; then
  echo "$own" | sed 's/^/  /' | head -20
else
  echo "  (none found)"
fi

echo
echo "composer.json:"
if [ -f "$target/composer.json" ]; then
  rg --no-heading --line-number '"craftcms/cms"|"craftcms/yii2-adapter"|"php"|"class"|"handle"|"psr-4"|"type"|"schemaVersion"' "$target/composer.json" 2>/dev/null | sed 's/^/  /' || true
else
  echo "  (no composer.json)"
fi

echo
echo "Directories (two levels):"
(cd "$target" && find . -mindepth 1 -maxdepth 2 -type d \
  ! -path './.git*' ! -path './vendor*' ! -path './node_modules*' | sort | sed 's|^\./|  |')

echo
echo "Yii-style directories to reorganize if moving to a conventional namespace:"
legacy_dirs=0
for pair in controllers:Http/Controllers filters:Http/Middleware web:Http events:Events models:Data-or-Models records:Models enums:Enums services:feature-folders behaviors:macros-or-traits validators:Validation helpers:Support console:Console/Commands jobs:Jobs queue:Jobs elements:Elements fields:Fields widgets:Widgets; do
  d="${pair%%:*}"; to="${pair#*:}"
  # find -name matches the stored name exactly, so `Events/` doesn't count as `events/` on case-insensitive filesystems.
  for base in "$target/src" "$target"; do
    if [ -d "$base" ] && find "$base" -maxdepth 1 -type d -name "$d" | grep -q .; then
      rel="${base#"$target"}"; rel="${rel#/}"; [ -n "$rel" ] && rel="$rel/"
      echo "  ${rel}${d}/  ->  ${to}"
      legacy_dirs=$((legacy_dirs + 1))
      break
    fi
  done
done
[ "$legacy_dirs" -eq 0 ] && echo "  (none)"

echo "Craft 6 layout targets:"
for p in src routes database/migrations lang resources config; do
  if [ -d "$target/$p" ]; then echo "  present  $p/"; else echo "  missing  $p/"; fi
done

echo
echo "Not covered by this scan: Craft 5 deprecation warnings. To check them, install the plugin in a Craft 5"
echo "project, exercise its features, then review Utilities > Deprecation Warnings."

if [ "${VERBOSE:-0}" = "1" ]; then
  echo
  i=0
  while [ "$i" -lt "$total" ]; do
    echo "== ${labels[$i]}"
    matches "${patterns[$i]}" "${imports[$i]}" | sort -u | head -15 | sed 's/^/  /'
    i=$((i + 1))
  done
fi
