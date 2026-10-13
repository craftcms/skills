#!/usr/bin/env bash
# Inventory Craft 5 / Yii 2 APIs in a plugin or module so a port can be planned.
# Usage: scan-craft5.sh [path]   (defaults to the current directory)
# Read-only. Prints match counts per area, then the first few matches for each.
# Patterns are heuristics: review the hits, they are not a complete or exact list.

set -euo pipefail

target="${1:-.}"

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep (rg) is required." >&2
  exit 1
fi

# area|reference file|ripgrep pattern
areas=(
  "Plugin class and settings|plugin-class.md|extends \\\\?craft\\\\base\\\\Plugin|createSettingsModel|function init\(|setComponents|getInstance\(\)"
  "Yii service locator|services-and-di.md|Craft::\\\$app|Yii::\\\$app|Craft::createObject|Yii::createObject"
  "Events|events-and-registries.md|Event::on\(|EVENT_[A-Z_]+|RegisterComponentTypesEvent|yii\\\\base\\\\Event"
  "Controllers and routing|http-and-auth.md|extends \\\\?craft\\\\web\\\\Controller|function action[A-Z]|allowAnonymous|requirePostRequest|requireLogin|requirePermission|URL_RULES"
  "Models, records, validation|models-and-validation.md|extends \\\\?craft\\\\base\\\\Model|craft\\\\db\\\\ActiveRecord|function defineRules|function rules\(|behaviors\(\)"
  "Migrations|database.md|extends \\\\?craft\\\\db\\\\Migration|createTable\(|addColumn\(|createIndex\(|addForeignKey\("
  "Twig and templates|templates-and-twig.md|renderTemplate|renderPageTemplate|AbstractExtension|CraftVariable|registerAssetBundle|TEMPLATE_MODE"
  "Fields, widgets, elements|fields-widgets-forms.md|extends \\\\?craft\\\\base\\\\(Field|Widget|Element)|getSettingsHtml|getInputHtml|inputHtml|queryCondition"
  "Console and queue|other-areas.md|extends \\\\?craft\\\\console\\\\Controller|extends \\\\?craft\\\\queue\\\\BaseJob|function execute\(|Craft::\\\$app->getQueue"
  "Translation and logging|other-areas.md|Craft::t\(|Craft::(info|warning|error|trace)\(|Yii::(info|warning|error|trace)\("
  "Asset bundles and filesystems|other-areas.md|extends \\\\?craft\\\\web\\\\AssetBundle|extends \\\\?craft\\\\base\\\\Fs|craft\\\\fs\\\\"
  "Other yii/craft imports|required-changes.md|^use (yii|craft)\\\\"
)

globs=(--glob '*.php' --glob '*.twig' --glob 'composer.json' --glob '!vendor/**' --glob '!node_modules/**')

echo "Scanning: $target"
echo

for entry in "${areas[@]}"; do
  IFS='|' read -r label ref pattern <<<"$entry"
  # The pattern may itself contain '|' alternations: rejoin everything after the second field.
  pattern="${entry#*|*|}"
  count=$(rg --no-heading --line-number "${globs[@]}" -e "$pattern" "$target" 2>/dev/null | wc -l | tr -d ' ' || true)
  printf '%-32s %5s hits   -> references/%s\n' "$label" "$count" "$ref"
done

echo
echo "composer.json:"
rg --no-heading --line-number '"craftcms/cms"|"craftcms/yii2-adapter"|"php"|"class"|"psr-4"' "$target/composer.json" 2>/dev/null || echo "  (none found)"

echo
echo "Top-level layout:"
for p in src routes database/migrations translations lang templates resources config; do
  [ -e "$target/$p" ] && echo "  has $p/"
done

if [ "${VERBOSE:-0}" = "1" ]; then
  echo
  for entry in "${areas[@]}"; do
    label="${entry%%|*}"
    pattern="${entry#*|*|}"
    echo "== $label"
    rg --no-heading --line-number "${globs[@]}" -e "$pattern" "$target" 2>/dev/null | head -15 || true
  done
fi
