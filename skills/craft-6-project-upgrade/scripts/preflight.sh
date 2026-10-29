#!/usr/bin/env bash
# Checks a Craft 5 project for upgrade work that craft6-revamp doesn't report.
# Usage: preflight.sh [project-path]   (defaults to the current directory)
#
# Read-only. craft6-revamp already reports plugin compatibility, entrify commands,
# customized entry points, and the config it can't rewrite. This script covers the
# rest: the host PHP version, code the tool never touches (templates, modules),
# and deploy files to review. Its output is the checklist for Stage 4.
# Patterns are heuristics: review each hit, they are not an exact list.
# Needs bash, grep, sed and php.

set -uo pipefail

root="${1:-.}"
root="${root%/}"

if [ ! -f "$root/composer.json" ]; then
  echo "No composer.json in $root" >&2
  exit 1
fi
if ! command -v php >/dev/null 2>&1; then
  echo "php is required on PATH (any version; it is used to check the host PHP version)." >&2
  exit 1
fi

section() { printf '\n== %s ==\n' "$1"; }
ok() { printf '  ok    %s\n' "$1"; }
info() { printf '  info  %s\n' "$1"; }
warn() { printf '  WARN  %s\n' "$1"; }

# grep_hits <label> <regex> <paths...>: print count and first matches of an extended regex.
grep_hits() {
  local label="$1" regex="$2"
  shift 2
  local existing=()
  for p in "$@"; do [ -e "$p" ] && existing+=("$p"); done
  [ ${#existing[@]} -eq 0 ] && return 0
  local out
  out=$(grep -rnE --include='*.php' --include='*.twig' --include='*.html' --include='*.js' \
    --exclude-dir=vendor --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=cpresources \
    "$regex" "${existing[@]}" 2>/dev/null || true)
  if [ -n "$out" ]; then
    local n
    n=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
    warn "$label: $n hit(s)"
    printf '%s\n' "$out" | head -n "${MAX_HITS:-5}" | sed "s|^$root/||; s|^|          |"
  fi
}

section "PHP"
[ -f "$root/.ddev/config.yaml" ] && info "DDEV config found: if you work in DDEV, run PHP, Composer and Artisan through ddev (the tool sets DDEV to PHP 8.5) and ignore the host PHP check"
cli_php=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
case "$cli_php" in
  8.5|8.6|9.*) ok "host PHP $cli_php can run Craft 6" ;;
  *) warn "host PHP $cli_php cannot run Craft 6: install PHP 8.5 (or use DDEV, Herd or Valet) before the composer update step" ;;
esac

section "Deploy and infrastructure files"
deploy_files=0
for f in .github/workflows deploy.php .platform.app.yaml .platform docker-compose.yml Dockerfile fly.toml render.yaml nginx.conf .buddy buddy.yml; do
  [ -e "$root/$f" ] && { warn "$f: review paths (web/ -> public/, config/ -> config/craft/), the PHP version, and craft CLI commands"; deploy_files=1; }
done
[ "$deploy_files" -eq 0 ] && ok "no known deploy or infrastructure files"
grep -rnE 'craft (queue|up|migrate|project-config)' "$root"/.github "$root"/deploy.php "$root"/*.sh 2>/dev/null | head -5 | sed 's/^/  info  CLI invocation to review: /'

section "Modules and custom PHP"
for d in modules src app; do
  n=$(find "$root/$d" -name '*.php' 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" -gt 0 ] && info "$d/ contains $n PHP file(s): a module; it runs through the adapter, verify each feature after the upgrade (see craft-6-plugin-upgrade skill to modernize)"
done
grep_hits "Craft::\$app / Yii::\$app in PHP" '(Craft|Yii)::\$app' "$root/modules" "$root/src" "$root/app" "$root/config"

section "Templates"
tpl="$root/templates"
[ -d "$tpl" ] || tpl="$root/resources/views"
if [ -d "$tpl" ]; then
  info "${tpl#$root/}/ has $(find "$tpl" -type f | wc -l | tr -d ' ') file(s)"
  grep_hits "craft.app (needs facades before ejecting)" 'craft\.app\b' "$tpl"
  grep_hits "deprecated filters (filterByValue, firstWhere, index, purify, ucfirst)" '\|\s*(filterByValue|firstWhere|index|purify|ucfirst)\b' "$tpl"
  grep_hits "view.* (Yii view object: use HtmlStack, include() or renderObjectTemplate())" '\bview\.[a-zA-Z]+|\{%\s*(js|css|script|html)\b' "$tpl"
  grep_hits "flash and session access (errors / old() replace these)" 'getFlash|setFlash|\bsession\.|craft\.app\.session' "$tpl"
  grep_hits "categories, tags or globals" 'craft\.(categories|tags|globalSets)\b|\{%\s*set\s+\w+\s*=\s*craft\.globals' "$tpl"
  grep_hits "asset setTransform() (use asset.transform({...}) and read the result)" '\.setTransform\(' "$tpl"
  grep_hits "SQL expressions in orderBy/select/groupBy strings (wrap in expression(); rand() and random() are fine)" '\.(orderBy|select|addSelect|groupBy)\(\s*["'"'"'][^"'"'"']*\(' "$tpl"
  grep_hits "low-level query builder (where/andWhere/orWhere) syntax may change" '\.(andWhere|orWhere|where)\(\s*[\[{]' "$tpl"
  grep_hits "includes or template paths with web/ or templates/" "(web|templates)/" "$tpl"
else
  info "no templates/ or resources/views/ directory"
fi

printf '\n== Summary ==\n'
echo "  Review the WARN lines. The rest of the upgrade checklist comes from craft6-revamp's report and Next steps."
