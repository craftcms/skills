#!/usr/bin/env bash
# Inventory what a Commerce 5 gateway plugin uses that changes in Commerce 6.
# Usage: scan-gateway.sh [path]            (defaults to the current directory)
#        VERBOSE=1 scan-gateway.sh [path]  also prints the first matches for each area
# Read-only. Patterns are heuristics: review the hits, they are not a complete list.
# Run scan-craft5.sh from the craft-6-plugin-upgrade skill too, for general Yii and Craft 5 usage.

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
  --glob '!vendor/**' --glob '!node_modules/**' --glob '!.git/**'
  --glob '!composer.lock' --glob '!package-lock.json'
)

# area <label> <pattern> [extra rg args...]
area() {
  local label="$1" pattern="$2"
  shift 2
  local matches count
  matches=$(rg -n --no-heading "${globs[@]}" "$@" -e "$pattern" "$target" 2>/dev/null || true)
  count=$(printf '%s' "$matches" | grep -c . || true)
  printf '%-56s %5s\n' "$label" "$count"
  if [ "${VERBOSE:-0}" = "1" ] && [ "$count" -gt 0 ]; then
    printf '%s\n' "$matches" | head -5 | sed 's/^/    /'
  fi
}

echo "== Omnipay (not ported to Commerce 6: replace with the provider's API) =="
area "composer: omnipay / commerce-omnipay" '"(omnipay/[^"]+|craftcms/commerce-omnipay|php-http/guzzle[^"]*)"\s*:' --glob 'composer.json'
area "Omnipay\\ classes" 'Omnipay\\' --glob '*.php'
area "craft\\commerce\\omnipay\\ base classes" 'craft\\commerce\\omnipay\\' --glob '*.php'
area "Omnipay hooks (populateRequest, createGateway…)" 'function (populateRequest|createGateway|getGatewayClassName|createPaymentRequest|createItemBagForOrder|createCard|sendRequest|prepareResponse|performRequest|createRequest|prepare[A-Za-z]+Request)\(' --glob '*.php'
area "Omnipay events (EVENT_BEFORE_SEND_PAYMENT_REQUEST…)" 'EVENT_(BEFORE_SEND_PAYMENT_REQUEST|BUILD_GATEWAY_REQUEST|AFTER_CREATE_ITEM_BAG|BEFORE_GATEWAY_REQUEST_SEND)' --glob '*.php'
area "sendCartInfo setting" 'sendCartInfo' --glob '*.php' --glob '*.twig'

echo
echo "== Commerce 5 gateway API =="
area "craft\\commerce\\base\\Gateway / interfaces" 'craft\\commerce\\base\\(Gateway|GatewayInterface|RequestResponseInterface|SubscriptionGateway)' --glob '*.php'
area "Gateway type registration event" 'EVENT_REGISTER_GATEWAY_TYPES|RegisterComponentTypesEvent' --glob '*.php'
area "Commerce 5 models and records" 'craft\\commerce\\(models|records|elements|errors)\\' --glob '*.php'
area "Commerce plugin getters (getTransactions()…)" '(Commerce|Plugin)::getInstance\(\)->get[A-Z]' --glob '*.php'
area "defineRules() (use getRules())" 'function defineRules\(' --glob '*.php'
area "getSettingsHtml() (use settingsUi())" 'function getSettingsHtml\(' --glob '*.php'
area "getPaymentFormHtml() override (use paymentFormUi())" 'function getPayment(Confirmation)?FormHtml\(' --glob '*.php'
area "processWebHook() returning craft\\web\\Response" 'craft\\web\\Response' --glob '*.php'
area "Subscriptions and plans (removed in Commerce 6)" 'Subscription|\bPlan\b|subscribe\(|cancelSubscription|getSubscriptionFormModel|supportsPlanSwitch' --glob '*.php' --glob '*.twig'

echo
echo "== Templates, assets and output =="
area "Twig templates (.twig, .html)" '.' --glob '*.twig' --glob '**/templates/**/*.html' --files-with-matches
area "Asset bundles" 'extends AssetBundle|registerAssetBundle' --glob '*.php'
area "View::registerJs / registerJsFile" 'registerJs(File)?\(' --glob '*.php'
area "Direct output (echo, exit, die, send())" '^\s*(echo |exit\b|die\b)|->send\(\)' --glob '*.php'
area "Self redirects (redirect()->send…)" '->redirect\(' --glob '*.php'

echo
echo "== Plugin's own events (document each in UPGRADE.md) =="
rg -n --no-heading "${globs[@]}" --glob '*.php' -e 'const EVENT_[A-Z_]+' "$target" 2>/dev/null | sed 's/^/    /' || echo "    none"

echo
echo "== Migrations =="
if [ -d "$target/src/migrations" ]; then
  ls -1 "$target/src/migrations" | sed 's/^/    /'
else
  echo "    none in src/migrations"
fi
