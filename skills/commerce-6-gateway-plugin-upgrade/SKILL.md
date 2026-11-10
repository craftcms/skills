---
name: commerce-6-gateway-plugin-upgrade
description: Upgrades a Craft Commerce 5 payment gateway plugin to Craft Commerce 6 (Craft 6, Laravel), including dropping Omnipay and writing the provider's API calls directly, moving settings and payment forms to the Ui builder, and porting webhooks, responses, tests and CI. Use when asked to upgrade, port or make a Commerce gateway plugin compatible with Commerce 6, or to remove Omnipay or craftcms/commerce-omnipay from a gateway.
license: MIT
compatibility: Craft Commerce 6.x (pre-release, test against 6.x-dev) on Craft CMS 6 and PHP 8.5. Builds on the craft-6-plugin-upgrade skill for general Craft 6 plugin changes. Requires ripgrep (rg) for scripts/scan-gateway.sh.
---

# Upgrading a Commerce 5 gateway plugin to Commerce 6

Commerce 6 is a native Craft 6 (Laravel) plugin. Commerce 5 gateway plugins don't run on it: the gateway base class, interfaces, registration, settings, payment forms, responses and webhooks all changed. There is no Yii 2 adapter path for gateways, so a gateway plugin is upgraded to a **native, adapter-free** Craft 6 plugin in one new major version.

**Omnipay is deprecated and is not ported to Commerce 6.** `craftcms/commerce-omnipay` and the `omnipay/*` drivers are Yii-era, mostly unmaintained, and built on the Commerce 5 gateway API. A Commerce 6 gateway calls the provider's API itself, usually with Laravel's `Http` client, or with the provider's own maintained PHP SDK if it has one. Don't try to bridge or wrap Omnipay.

This skill covers what is specific to gateways. For everything else (the plugin class, service container, events, migrations, Twig, translations), load the **craft-6-plugin-upgrade** skill and follow its native (end state B) guidance. Its `scripts/scan-craft5.sh` also applies to gateway plugins.

## Ground rules

- Commerce 6 is pre-release. The source of truth is the installed `craftcms/commerce` 6.x source, mainly `src/Payment/` and the "Payments" section of its `CHANGELOG-WIP.md`. When this skill and the source disagree, trust the source and say so.
- Never guess an API name or signature. Look it up in `vendor/craftcms/commerce/src` or `vendor/craftcms/cms/src`.
- Never guess the provider's API either. Read the provider's current API reference for every endpoint, field, status value and signature scheme you use, and link it in a docblock. Check whether the product is still alive before porting it (Worldpay Online Payments, used by `omnipay/worldpay`, was shut down in October 2022).
- Port behavior faithfully first: same settings names and stored values, same request fields, same status mapping. Make deliberate behavior changes separately, and record each one in `UPGRADE.md` and the changelog.
- Saved gateways must keep working: the `commerce_gateways.type` column and project config still hold the Commerce 5 class name, and old transactions hold old references and responses that refunds and captures read.
- Small open questions go in the PR description under "Undecided or still to do" instead of blocking the upgrade.

## Stage 0: Assess

1. Run `scripts/scan-gateway.sh <plugin-path>`. It lists Omnipay usage, the Commerce 5 gateway APIs in use, the plugin's own events, templates and asset bundles, subscription code, and code that redirects or exits by itself. Then run `scan-craft5.sh` from craft-6-plugin-upgrade for general Yii and Craft 5 usage.
2. Find what the gateway actually talks to: the Omnipay driver's endpoints, request bodies and status handling (read them in `vendor/omnipay/*` on the old branch), or the provider SDK. That is the behavior to reproduce.
3. Check the provider's status: is the API or product still live, deprecated, or replaced? Is the SDK abandoned (Packagist and GitHub archive state)? If the product is gone, port anyway only if asked, and recommend retiring the plugin.
4. List features that Commerce 6 removed: **subscriptions and plans are gone** (no `SubscriptionGateway` and no Subscription element). Plan to delete that code and document it.
5. Agree with the developer on:
   - **Namespace.** First-party Craft plugins use `CraftCms\Commerce<Name>` (for example `CraftCms\CommerceMollie`). Third-party plugins use their own vendor namespace.
   - **Branch.** A new major, named `N.x` and cut from the latest release branch, requiring `craftcms/commerce: 6.x-dev` until Commerce 6 is tagged. If the repo still uses `main`, `master` or `develop` as its release branch, tell the developer.
   - **SDK or direct HTTP.** Use a maintained official SDK if it exists and is Laravel-friendly (Stripe keeps `stripe/stripe-php`). Otherwise write a small client with `Illuminate\Support\Facades\Http`.

**Checkpoint:** a short plan listing the endpoints, settings, events, templates, removed features and behavior changes, with the namespace and branch decisions.

## Stage 1: Package and plugin class

See [references/package-and-plugin.md](references/package-and-plugin.md).

1. `composer.json`: require `php: ^8.5` and `craftcms/commerce: 6.x-dev`, and remove `craftcms/commerce-omnipay`, `omnipay/*`, `php-http/*` adapters and any abandoned SDK. Add the new PSR-4 root, and keep the old one only for `legacy/` aliases. Set `minimum-stability: dev` and `prefer-stable: true`. Don't commit `composer.lock` while tracking a dev branch.
2. The plugin class extends `CraftCms\Cms\Plugin\Plugin` and registers the gateway in `boot(GatewayTypes $gatewayTypes)` with `$gatewayTypes->register(Gateway::class)`. Remove the `EVENT_REGISTER_GATEWAY_TYPES` listener.
3. Keep the Commerce 5 gateway class loadable with a `class_alias` in `legacy/`, so saved gateways resolve to the new class.
4. Bump `schemaVersion`, set `minVersionRequired` to the last release of the previous major, and delete old install migrations that converted Commerce 1 or 2 gateway types.

## Stage 2: The gateway class

See [references/gateway-api.md](references/gateway-api.md).

1. Extend `CraftCms\Commerce\Payment\Gateway\Gateway` and implement `GatewayInterface` fully: every `supports*()` method, and the operations you don't support throw `CraftCms\Commerce\Exceptions\NotImplementedException`.
2. Settings stay public properties with the same names, so stored settings keep loading. Keep `getX(bool $parse = true)` getters that run `Env::parse()` / `Env::parseBoolean()`.
3. Validation moves from `defineRules()` to `getRules()` (Laravel rules), merged with `parent::getRules()`.
4. The settings template becomes `settingsUi(UiContext $context = new UiContext()): ?Ui`. Commerce renders it, and `getSettingsHtml()` is inherited.
5. `getPaymentFormModel()` returns a `CraftCms\Commerce\Payment\Forms\BasePaymentForm` subclass (`OffsitePaymentForm`, `CreditCardPaymentForm` or the plugin's own).

## Stage 3: Replace Omnipay with the provider's API

See [references/replacing-omnipay.md](references/replacing-omnipay.md).

1. Write a `Client` class: one method per endpoint, built on `Http::baseUrl(...)`, with auth, JSON, a User-Agent naming the plugin and Commerce versions, and the provider's partner or attribution ID if the old driver sent one.
2. Write response classes implementing `RequestResponseInterface`, one per provider object (payment, refund...). They decide `isSuccessful()`, `isProcessing()` and `isRedirect()` from the provider's documented statuses, and handle error bodies and network failures.
3. Build request bodies in the gateway. Convert amounts with Commerce's `Currencies` teller, never with `* 100` (check the provider's minor unit rules for zero- and three-decimal currencies).
4. Replace Omnipay's events with the plugin's own Laravel event, usually a `PaymentRequestBuilding` event whose public `$request` array listeners can change. Document the before and after code in `UPGRADE.md`.
5. Keep refunds and captures working for transactions made before the upgrade: read the parent's `reference` and `response` in the format Commerce 5 stored them.

## Stage 4: Payment forms are Ui

See [references/payment-forms.md](references/payment-forms.md).

1. Delete the payment form Twig templates and asset bundles. Don't override `getPaymentFormHtml()`.
2. Implement `paymentFormUi(BasePaymentForm $form, array $params = []): ?Ui`. Return `null` when there is no form (hosted checkout). Use Ui controls named after the payment form model's attributes, so Commerce fills in values and validation errors.
3. For a provider's hosted fields or button container, use a trusted `TemplateContent` node, and load scripts with the `HtmlStack` facade.
4. Use `paymentConfirmationFormUi()` for the stored payment source confirmation step, if the gateway has one.

## Stage 5: Webhooks and returning customers

See [references/webhooks.md](references/webhooks.md).

1. `processWebHook(): Illuminate\Http\Response`. Never `echo`, `exit()` or send a response yourself.
2. Implement `getTransactionHashFromWebhook()` so Commerce locks the transaction while the webhook runs.
3. Treat every webhook as untrusted: verify the signature when the provider signs it, and re-fetch the payment from the provider's API before recording anything. Make it idempotent.
4. Record the result as a child transaction with `Transactions::createTransaction(null, $parent)` and `saveTransaction()`. Saved transactions are immutable: `saveTransaction()` throws "Transactions cannot be modified." for a transaction that has an `id`.
5. Return a non-2xx status only when the provider should retry.

## Stage 6: Tests, CI and docs

See [references/testing.md](references/testing.md).

1. Pest tests in Orchestra Testbench through `CraftCms\Cms\Plugin\Testing\PluginTestCase`, installing Commerce before the plugin. Fake the provider with `Http::fake()`, using response shapes from the provider's API reference.
2. Cover the registration and legacy class name, settings validation, the request body (amounts, addresses, line items), every status on purchase and on return, refunds through `Payments::refundTransaction()`, and each webhook path (valid, bad signature, unknown transaction, duplicate, provider down).
3. CI: ECS, PHPStan (Larastan) and Pest on PHP 8.5.
4. Write `UPGRADE.md` (requirements, class renames, removed settings, events before and after, templates, behavior changes) and a changelog entry. The `assets/UPGRADE.template.md` from craft-6-plugin-upgrade is a good starting point.
5. Open the PR into the new `N.x` branch, with sections for summary, evidence, dependencies and "Undecided or still to do". Say plainly that nothing was tested against the live provider if that's the case, and list what a sandbox run should cover.

## Reference map

| Topic | Reference |
| --- | --- |
| `composer.json`, plugin class, registration, legacy aliases, migrations | [references/package-and-plugin.md](references/package-and-plugin.md) |
| Commerce 5 to 6 gateway API, interface methods, transaction statuses, redirects | [references/gateway-api.md](references/gateway-api.md) |
| Omnipay base classes, methods and events, and what replaces them; clients, responses, amounts | [references/replacing-omnipay.md](references/replacing-omnipay.md) |
| `paymentFormUi()`, `TemplateContent`, scripts, front-end rendering | [references/payment-forms.md](references/payment-forms.md) |
| Webhook routes and URLs, verification, locking, child transactions | [references/webhooks.md](references/webhooks.md) |
| Test case, faking the provider, what to test, CI, known install problems | [references/testing.md](references/testing.md) |

## Edge cases

- **Subscriptions:** removed from Commerce 6 with no replacement. Delete subscription and plan code, and say so in `UPGRADE.md`. The database tables are kept for a future migration path.
- **Payment sources:** still supported (`createPaymentSource()`, `deletePaymentSource()`, `PaymentSourceCreatedLaterException`) for gateways that store cards. When `createPaymentSource()` throws `PaymentSourceCreatedLaterException`, `PaymentsController::pay()` only sets `savePaymentSource` on payment forms with a `paymentSource` property (unchanged from Commerce 5), so check the installed code before relying on it.
- **Console commands and CP utilities:** Yii console controllers become Artisan commands registered by the plugin (`php artisan <handle>:<name>`). Old `<handle>/<controller>/<action>` names only resolve as `craft:<handle>/...` aliases. Rebuild a CP utility only if it's still needed; a command plus an admin-only action can replace it.
- **Gateways with their own tables** (Stripe's customers and payment intents): the plugin's install migration moves to `database/migrations/`, and its own records become Eloquent models.
- **Dead provider products:** don't build a new integration under the old plugin name without asking. Port it if asked, and recommend retiring it.
- **Abandoned SDKs:** replace them with a direct client rather than pinning an abandoned package.
- **Settings that only Omnipay used** (often `sendCartInfo`): remove them, or keep them if the provider still uses the data. Either way, document it.
- **Webhook URLs with query strings:** some providers reject them. Use the path route `commerce/webhooks/process-webhook/gateway/<id>`.
- **Composer refuses to install Craft 6.x-dev** because of a security advisory on one of its dependencies: this needs a fix in `craftcms/cms`. Report it rather than silencing the advisory in the plugin. Locally, `COMPOSER_NO_SECURITY_BLOCKING=1` unblocks the install.
