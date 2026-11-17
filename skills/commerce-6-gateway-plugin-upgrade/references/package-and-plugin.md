# Package, plugin class and upgrade path

## Branch and version

A gateway for Commerce 6 is a new major version on its own branch, named `N.x` (for example `5.x` if the last release is 4.x). Cut it from the latest release branch so history follows. If the repository still releases from `main`, `master` or `develop`, tell the developer so they can rename it before releasing.

Until Commerce 6 is tagged, require `craftcms/commerce: 6.x-dev` and don't commit `composer.lock`. Commit one again once Commerce 6 is tagged and the constraint becomes `^6.0`.

## `composer.json`

```json
{
  "require": {
    "php": "^8.5",
    "craftcms/commerce": "6.x-dev"
  },
  "require-dev": {
    "craftcms/ecs": "dev-main",
    "larastan/larastan": "^3.4",
    "orchestra/testbench": "^11.0",
    "pestphp/pest": "^4.0",
    "pestphp/pest-plugin-laravel": "^4.0"
  },
  "autoload": {
    "psr-4": {
      "CraftCms\\CommerceMollie\\": "src/",
      "craft\\commerce\\mollie\\": "legacy/"
    }
  },
  "autoload-dev": {
    "psr-4": {
      "CraftCms\\CommerceMollie\\Tests\\": "tests/"
    }
  },
  "extra": {
    "handle": "commerce-mollie",
    "class": "CraftCms\\CommerceMollie\\Plugin"
  },
  "minimum-stability": "dev",
  "prefer-stable": true,
  "scripts": {
    "check-cs": "ecs check --ansi",
    "fix-cs": "ecs check --ansi --fix",
    "phpstan": "phpstan --memory-limit=1G",
    "test": "pest"
  }
}
```

- `craftcms/commerce` brings `craftcms/cms`, so don't require it separately unless the plugin needs a specific Craft version.
- Remove `craftcms/commerce-omnipay`, `omnipay/*`, `php-http/*`, abandoned SDKs and `craftcms/yii2-adapter`.
- Keep the plugin `handle`: it is the key in the `plugins` table and project config.
- Update URLs in `support` and `extra.documentationUrl` that point at the old branch.

## Plugin class

```php
namespace CraftCms\CommerceMollie;

use CraftCms\Cms\Plugin\Plugin as BasePlugin;
use CraftCms\Commerce\Payment\Gateway\GatewayTypes;

class Plugin extends BasePlugin
{
    public string $schemaVersion = '5.0.0';

    public string $minVersionRequired = '4.4.3';

    public function boot(GatewayTypes $gatewayTypes): void
    {
        $gatewayTypes->register(Gateway::class);
    }
}
```

- `minVersionRequired` is the last release of the previous major, so sites update to it on Craft 5 first and run its migrations.
- Most gateway plugins need no settings, services, routes or migrations of their own. Delete old `Install` migrations that only converted Commerce 1 or 2 gateway types (`MultiSafepay_Rest`, `WorldPay_Json`, `Eway_RapidDirect`…), and incremental migrations already covered by `minVersionRequired`.
- Translations move to `lang/<locale>/<handle>.php`, used as `t('…', category: '<handle>')`.

## Keeping saved gateways working

Gateways are stored with their class name in `commerce_gateways.type` and project config. Keep the Commerce 5 name loadable with an alias under `legacy/`, autoloaded from the old namespace:

```php
<?php

namespace craft\commerce\mollie\gateways;

// Gateways saved with Mollie for Craft Commerce 4 store this class name as their type.
/** @deprecated in 5.0.0. Use {@see \CraftCms\CommerceMollie\Gateway} instead. */
class_alias(\CraftCms\CommerceMollie\Gateway::class, 'craft\commerce\mollie\gateways\Gateway');

/** @phpstan-ignore-next-line */
if (false) {
    class Gateway extends \CraftCms\CommerceMollie\Gateway
    {
    }
}
```

Commerce handles its own renamed gateways the same way. A migration that rewrites the stored type is an alternative; if you add one, update project config too. Test that `Gateways::createGateway(['type' => '<old class>', 'settings' => [...]])` returns the new class with the settings intact.

Only alias classes that stored data or other code refers to: the gateway types, and classes users commonly extended. Everything else is renamed and listed in `UPGRADE.md`.

## Files to remove

- Omnipay base class usage and driver-specific classes
- `templates/` (payment form and settings Twig), asset bundles and their `resources/` sources, unless the JavaScript is still loaded by `paymentFormUi()`
- `src/migrations/Install.php` and old migrations
- `.ddev/` and other Craft 5 local dev configs, if the repo now uses the Testbench workbench
- polyfills for old browsers

## Docs

- `README.md`: requirements (Craft 6, Commerce 6, PHP 8.5), installation, settings, webhook setup, and the template example (`{{ cart.gateway.getPaymentFormHtml({}) }}`).
- `UPGRADE.md`: requirements, class and namespace table, removed settings with the reason, events before and after, templates, and behavior changes.
- `CHANGELOG.md`: an "Unreleased" section with a warning that the release requires Commerce 6, linking `UPGRADE.md`.
