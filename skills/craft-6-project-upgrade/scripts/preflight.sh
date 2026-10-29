#!/usr/bin/env bash
# Inventory a Craft 5 project before upgrading it to Craft 6.
# Usage: preflight.sh [project-path]   (defaults to the current directory)
#
# Read-only. Reports blockers (must fix before running craft6-revamp), things the
# upgrade tool will not handle, and post-upgrade work (deprecations the adapter
# will keep working, but which need attention before ejecting it).
# Patterns are heuristics: review each hit, they are not an exact list.
# Needs bash, grep, sed and php (for reading composer files).

set -uo pipefail

root="${1:-.}"
root="${root%/}"

if [ ! -f "$root/composer.json" ]; then
  echo "No composer.json in $root" >&2
  exit 1
fi

blockers=0
section() { printf '\n== %s ==\n' "$1"; }
ok() { printf '  ok    %s\n' "$1"; }
info() { printf '  info  %s\n' "$1"; }
warn() { printf '  WARN  %s\n' "$1"; }
block() { printf '  BLOCK %s\n' "$1"; blockers=$((blockers + 1)); }

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

php_json() {
  # php_json <file> <php expression using $j>
  php -r '$j = json_decode(file_get_contents($argv[1]), true); '"$2" "$1" 2>/dev/null
}

if ! command -v php >/dev/null 2>&1; then
  echo "php is required on PATH (it can be any version; it is only used to read JSON)." >&2
  exit 1
fi

section "Craft and PHP"
craft_version=""
if [ -f "$root/composer.lock" ]; then
  craft_version=$(php_json "$root/composer.lock" 'foreach (array_merge($j["packages"] ?? [], $j["packages-dev"] ?? []) as $p) { if ($p["name"] === "craftcms/cms") { echo $p["version"]; } }')
fi
if [ -z "$craft_version" ]; then
  block "craftcms/cms not found in composer.lock (run composer install first, or this is not a Craft project)"
elif php -r 'exit(version_compare(ltrim($argv[1], "v"), "6.0.0-alpha.1", ">=") ? 0 : 1);' "$craft_version"; then
  block "craftcms/cms $craft_version is already 6.x: this project looks partly or fully upgraded"
elif php -r 'exit(version_compare(ltrim($argv[1], "v"), "5.9.0", ">=") ? 0 : 1);' "$craft_version"; then
  ok "craftcms/cms $craft_version (craft6-revamp needs 5.9.0+; update to the latest 5.x first anyway)"
else
  block "craftcms/cms $craft_version: update to the latest Craft 5.x first (craft6-revamp refuses anything below 5.9.0)"
fi

cli_php=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
if [ -f "$root/.ddev/config.yaml" ]; then
  ddev_type=$(sed -nE 's/^type:[[:space:]]*"?([a-z0-9]+)"?.*/\1/p' "$root/.ddev/config.yaml" | head -1)
  ddev_php=$(sed -nE 's/^php_version:[[:space:]]*"?([0-9.]+)"?.*/\1/p' "$root/.ddev/config.yaml" | head -1)
  ddev_docroot=$(sed -nE 's/^docroot:[[:space:]]*"?([^"]+)"?.*/\1/p' "$root/.ddev/config.yaml" | head -1)
  info "DDEV project: type=${ddev_type:-?} php_version=${ddev_php:-?} docroot=${ddev_docroot:-?} (the tool switches these to laravel / 8.5 / public)"
  info "Run PHP and Composer commands through ddev (ddev composer, ddev artisan, ddev php craft)"
else
  info "No DDEV config. Host CLI PHP is $cli_php; Craft 6 needs PHP 8.5 wherever composer update and artisan run"
  case "$cli_php" in 8.5|8.6|9.*) ok "host PHP $cli_php can run Craft 6" ;; *) warn "host PHP $cli_php cannot run Craft 6; install PHP 8.5 before the composer update step" ;; esac
fi

section "Version control"
if [ -d "$root/.git" ]; then
  if [ -n "$(git -C "$root" status --porcelain 2>/dev/null)" ]; then
    warn "git working tree has uncommitted changes: commit them so the upgrade diff is reviewable"
  else
    ok "git working tree is clean"
  fi
else
  warn "not a git repository: take a full copy of the project before running the tool"
fi

section "Plugins and Composer packages"
php_json "$root/composer.json" '
  foreach (["require", "require-dev"] as $s) {
    foreach (($j[$s] ?? []) as $name => $c) {
      if ($name === "php" || str_starts_with($name, "ext-")) continue;
      echo "$s\t$name\t$c\n";
    }
  }' | while IFS=$'\t' read -r s name c; do
  case "$name" in
    craftcms/cms) info "$s $name $c (tool sets ^6.0.0-alpha.1)" ;;
    vlucas/phpdotenv) info "$s $name $c (tool removes it; Laravel loads .env itself)" ;;
    craftcms/generator) info "$s $name $c (tool sets 3.x-dev; check it requires craftcms/cms ^6 before composer update, or remove it)" ;;
    yiisoft/yii2-shell) warn "$s $name $c (Yii shell is gone in Craft 6; remove it and use laravel/tinker)" ;;
    *) info "$s $name $c" ;;
  esac
done
if [ -f "$root/composer.lock" ]; then
  plugins=$(php_json "$root/composer.lock" 'foreach (array_merge($j["packages"] ?? [], $j["packages-dev"] ?? []) as $p) { if (($p["type"] ?? "") === "craft-plugin") { echo $p["name"], " ", $p["version"], "\n"; } }')
  c5deps=$(php_json "$root/composer.lock" 'foreach (array_merge($j["packages"] ?? [], $j["packages-dev"] ?? []) as $p) { $c = $p["require"]["craftcms/cms"] ?? null; if ($c !== null && ($p["type"] ?? "") !== "craft-plugin" && $p["name"] !== "craftcms/generator") { echo $p["name"], " ", $p["version"], " (requires craftcms/cms ", $c, ")\n"; } }')
  if [ -n "$c5deps" ]; then
    warn "non-plugin packages that require craftcms/cms (each needs a Craft 6 release, or removal, before composer update):"
    printf '%s\n' "$c5deps" | sed 's/^/          /'
  fi
  if [ -n "$plugins" ]; then
    warn "Craft plugins installed (check each for a 6.x release; set CRAFT_DISABLED_PLUGINS=\"*\" or uninstall any that are not ready):"
    printf '%s\n' "$plugins" | sed 's/^/          /'
    printf '%s\n' "$plugins" | grep -Ei 'aws-s3|google-cloud|azure|filesystem|-fs |sendgrid|mailgun|postmark|smtp|mandrill|amazon-ses|logstash|-log' | sed 's/^/  WARN  probably obsolete in Craft 6 (Laravel disks, mailers or logging replace it): /'
  else
    ok "no Craft plugins in composer.lock"
  fi
fi
php_json "$root/composer.json" 'foreach (($j["autoload"]["psr-4"] ?? []) as $ns => $p) { echo "$ns => ", is_array($p) ? implode(", ", $p) : $p, "\n"; }' | sed 's/^/  info  autoload psr-4: /'
platform_php=$(php_json "$root/composer.json" 'echo $j["config"]["platform"]["php"] ?? "";')
[ -n "$platform_php" ] && info "config.platform.php is $platform_php (the tool removes it)"

section "Entry points and bootstrap"
webroot=""
for d in web public public_html html; do
  if [ -f "$root/$d/index.php" ]; then webroot="$d"; break; fi
done
if [ -z "$webroot" ]; then
  warn "no web root with index.php found in web/, public/, public_html/ or html/ (the tool scans for one, check what it picks)"
else
  info "web root: $webroot/ (the tool offers to rename it to public/ and REPLACES $webroot/index.php)"
  if grep -qvE '^\s*(//|\*|/\*\*|\*/|<\?php|$)|require|\$app|define\(.CRAFT_BASE_PATH|define\(.CRAFT_VENDOR_PATH' "$root/$webroot/index.php"; then
    warn "$webroot/index.php has lines beyond the stock file: they will be lost"
    grep -vnE '^\s*(//|\*|/\*\*|\*/|<\?php|$)|require|\$app->run|\$app = require' "$root/$webroot/index.php" | sed 's/^/          /' | head -10
  fi
  for f in .htaccess web.config; do [ -f "$root/$webroot/$f" ] && info "$webroot/$f exists: keep it, and check it still rewrites to index.php"; done
  other=$(find "$root/$webroot" -maxdepth 1 -mindepth 1 ! -name index.php ! -name cpresources ! -name .htaccess ! -name '.gitignore' ! -name web.config 2>/dev/null | sed "s|^$root/||")
  [ -n "$other" ] && info "other files in $webroot/ move with it: $(printf '%s ' $other)"
fi
if [ -f "$root/bootstrap.php" ]; then
  custom=$(grep -nE 'define\(|ini_set|error_reporting|Dotenv|require' "$root/bootstrap.php" | grep -vE "CRAFT_BASE_PATH'?, __DIR__|CRAFT_VENDOR_PATH'?, CRAFT_BASE_PATH|autoload\.php|Dotenv\\\\Dotenv::create(Imm|M)utable\(CRAFT_BASE_PATH\)|class_exists\(Dotenv|error_reporting\(E_ALL & ~E_DEPRECATED & ~E_USER_DEPRECATED\)" || true)
  if [ -n "$custom" ]; then
    warn "bootstrap.php has customizations; the tool deletes the file, so move them to bootstrap/app.php, config, or .env:"
    printf '%s\n' "$custom" | sed 's/^/          /'
  else
    ok "bootstrap.php looks stock (the tool deletes it)"
  fi
fi
[ -f "$root/craft" ] && info "craft executable exists (the tool deletes it; craft:setup:publish recreates it)"
[ -e "$root/bootstrap" ] && block "a bootstrap/ directory already exists: the tool will not overwrite bootstrap/app.php, check it is not a leftover"
[ -f "$root/artisan" ] && warn "an artisan file already exists: the tool will keep it, check it is Laravel's"
[ -d "$root/resources/views" ] && warn "resources/views already exists: the tool asks before moving templates/ there and renames the old one to resources/views-old"

section "Environment variables"
for f in .env .ddev/.env .ddev/.env.web; do
  [ -f "$root/$f" ] || continue
  vars=$(grep -oE '^(export +)?CRAFT_[A-Z0-9_]+' "$root/$f" | sed 's/^export *//' | sort -u | tr '\n' ' ')
  [ -n "$vars" ] && info "$f: $vars"
done
info "the tool does NOT set APP_ENV or APP_URL: set them in .env after running it, or Laravel assumes production"
info "the tool renames CRAFT_DB_* and CRAFT_DEV_MODE, removes CRAFT_SECURITY_KEY, and adds APP_KEY, CACHE_STORE=file, SESSION_DRIVER=file"
info "it does NOT rename CRAFT_DB_TABLE (the docs' name), only CRAFT_DB_TABLE_PREFIX; check table prefixes by hand"
for f in .env.example .env.example.dev .env.example.staging .env.example.production; do
  [ -f "$root/$f" ] && info "$f is not touched by the tool; update it to the new variable names by hand"
done
grep -rlE 'CRAFT_DB_|CRAFT_DEV_MODE|CRAFT_SECURITY_KEY' "$root"/config "$root"/.github "$root"/docker-compose*.yml "$root"/Dockerfile* "$root"/.platform* "$root"/fly.toml "$root"/render.yaml 2>/dev/null | sed "s|^$root/||; s|^|  WARN  references old env var names: |"

section "Configuration (config/)"
cfg="$root/config"
if [ -d "$cfg/craft" ]; then
  warn "config/craft/ already exists: the tool will skip moving config files"
fi
for f in "$cfg"/*.web.php "$cfg"/*.console.php; do
  [ -e "$f" ] && warn "app-type config file $(basename "$f"): flatten into the base file (only the adapter reads these)"
done
grep -lE "^\s*['\"]\*['\"]\s*=>" "$cfg"/*.php 2>/dev/null | sed "s|^$root/||; s|^|  WARN  multi-environment config array ('*' key), only supported by the adapter: |"
[ -f "$cfg/db.php" ] && warn "config/db.php is no longer read: move settings to .env DB_* vars or config/database.php"
if [ -f "$cfg/app.php" ]; then
  grep -nE "'components'|'modules'|'bootstrap'" "$cfg/app.php" | sed 's/^/  WARN  config\/app.php (Yii app config; only the adapter reads it): /'
fi
if [ -f "$cfg/general.php" ]; then
  grep -qE "\benableTwigSandbox\b" "$cfg/general.php" && warn "general.php calls enableTwigSandbox (deprecated in Craft 6, logs on every boot): remove it before composer update"
  for s in timezone defaultCookieDomain blowfishHashCost phpSessionName systemMessageTemplate elevatedSessionDuration omitScriptNameInUrls pathParam testToEmailAddress; do
    grep -qE "\b$s\b" "$cfg/general.php" && warn "general.php uses $s (removed or relocated in Craft 6, see compatibility.md > General Config)"
  done
  grep -nE "dirname\(__DIR__\)|CRAFT_BASE_PATH|@webroot|@web\b" "$cfg/general.php" | sed 's/^/  WARN  general.php path or alias that breaks when config moves to config\/craft\/ or web\/ becomes public\/: /'
  grep -qE "\bloginPath\b" "$cfg/general.php" || info "general.php has no loginPath: the default changed from 'login' to false, set it if the site has a front-end login form"
fi
if [ -f "$cfg/routes.php" ]; then
  if php -r '$r = include $argv[1]; exit(is_array($r) && $r === [] ? 0 : 1);' "$cfg/routes.php" 2>/dev/null; then
    ok "config/routes.php is empty"
  else
    warn "config/routes.php defines routes: only the adapter reads it; translate to routes/web.php before ejecting"
  fi
fi
if [ -d "$cfg/htmlpurifier" ]; then
  extra=$(find "$cfg/htmlpurifier" -type f ! -name Default.json | sed "s|^$root/||")
  [ -n "$extra" ] && warn "custom HTMLPurifier configs (replaced by Symfony HtmlSanitizer): $extra"
  info "config/htmlpurifier/Default.json can be deleted if it was never modified"
fi
for f in "$cfg"/*.php; do
  [ -e "$f" ] || continue
  case "$(basename "$f")" in
    general.php|app.php|app.web.php|app.console.php|db.php|routes.php|redirects.php|twig-sandbox.php|custom.php|license.key) ;;
    *) info "config/$(basename "$f"): plugin or custom config, moves to config/craft/; check the owning plugin's 6.x docs" ;;
  esac
done
[ -f "$cfg/license.key" ] && info "config/license.key moves to config/craft/license.key"

section "Project config"
pc="$cfg/project"
if [ -d "$pc" ]; then
  [ -n "$(find "$pc" -path '*/fs/*' -name '*.yaml' 2>/dev/null; grep -lE '^fs:' "$pc/project.yaml" 2>/dev/null)" ] && \
    info "filesystems defined: Craft filesystems are removed; the tool prints Laravel disk suggestions for config/filesystems.php"
  grep -rhoE 'type: [A-Za-z\\]+\\fs\\[A-Za-z]+|type: [a-z0-9]+\\[a-z0-9]+\\fs\\[A-Za-z]+' "$pc" 2>/dev/null | sort | uniq -c | sed 's/^/  info  filesystem /'
  transport=$(grep -A1 -E '^\s*transportType:' "$pc/project.yaml" 2>/dev/null | head -2 | tr -s ' ' | tr '\n' ' ')
  [ -n "$transport" ] && info "email $transport: replace with a mailer in config/mail.php after the upgrade"
  [ -d "$pc/categoryGroups" ] && warn "category groups exist: categories are deprecated and may be entrified during the upgrade (run php craft entrify/categories on 5.x first to control it)"
  [ -d "$pc/tagGroups" ] && warn "tag groups exist: tags are deprecated and may be entrified (php craft entrify/tags on 5.x first)"
  [ -d "$pc/globalSets" ] && warn "global sets exist: globals are removed in favour of singles (php craft entrify/global-set on 5.x first)"
  grep -q '^dateModified' "$pc/project.yaml" 2>/dev/null && info "project config is present: run php craft project-config/apply on 5.x first, so files and DB agree"
else
  info "no config/project directory"
fi

section "Modules and custom PHP"
for d in modules src app; do
  [ -d "$root/$d" ] && info "$d/ contains $(find "$root/$d" -name '*.php' | wc -l | tr -d ' ') PHP file(s): a module; it keeps working through the adapter (see craft-6-plugin-upgrade skill to modernize)"
done
grep_hits "Craft::\$app / Yii::\$app in PHP" '(Craft|Yii)::\$app' "$root/modules" "$root/src" "$root/app" "$root/config"

section "Templates"
tpl="$root/templates"
if [ -d "$tpl" ]; then
  info "templates/ has $(find "$tpl" -type f | wc -l | tr -d ' ') file(s) (moves to resources/views/)"
  grep_hits "craft.app (needs facades before ejecting)" 'craft\.app\b' "$tpl"
  grep_hits "deprecated filters (filterByValue, firstWhere, index, purify, ucfirst)" '\|\s*(filterByValue|firstWhere|index|purify|ucfirst)\b' "$tpl"
  grep_hits "view.* (Yii view object: use HtmlStack, include() or renderObjectTemplate())" '\bview\.[a-zA-Z]+|\{%\s*(js|css|script|html)\b' "$tpl"
  grep_hits "flash and session access (errors / old() replace these)" 'getFlash|setFlash|\bsession\.|craft\.app\.session' "$tpl"
  grep_hits "categories, tags or globals" 'craft\.(categories|tags|globalSets)\b|\{%\s*set\s+\w+\s*=\s*craft\.globals' "$tpl"
  grep_hits "low-level query builder (where/andWhere/orWhere) syntax may change" '\.(andWhere|orWhere|where)\(\s*[\[{]' "$tpl"
  grep_hits "includes or template paths with web/ or templates/" "(web|templates)/" "$tpl"
else
  info "no templates/ directory"
fi
[ -d "$root/translations" ] && info "translations/ exists (renamed to lang/)"

section "Deploy and infrastructure files"
for f in .github/workflows deploy.php .platform.app.yaml .platform docker-compose.yml Dockerfile fly.toml render.yaml nginx.conf .buddy buddy.yml; do
  [ -e "$root/$f" ] && warn "$f: review paths (web/ -> public/, config/ -> config/craft/), the PHP version, and craft CLI commands"
done
grep -rnE 'craft (queue|up|migrate|project-config)' "$root"/.github "$root"/deploy.php "$root"/*.sh 2>/dev/null | head -5 | sed 's/^/  info  CLI invocation to review: /'

printf '\n== Summary ==\n'
if [ "$blockers" -gt 0 ]; then
  echo "  $blockers blocker(s). Resolve them before running craft6-revamp."
  exit 2
fi
echo "  No blockers found. Review the WARN lines and take a DB backup before running craft6-revamp."
