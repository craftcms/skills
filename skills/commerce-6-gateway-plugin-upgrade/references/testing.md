# Testing and CI

## Test case

Gateway plugins test inside Orchestra Testbench with Craft, Commerce and the plugin installed. `PluginTestCase` only installs the root package, so install Commerce first:

```php
namespace CraftCms\CommerceMollie\Tests;

use CraftCms\Cms\Plugin\Plugins;
use CraftCms\Cms\Plugin\Testing\PluginTestCase;
use Override;

use function Orchestra\Testbench\package_path;

abstract class TestCase extends PluginTestCase
{
    #[Override]
    protected function setUp(): void
    {
        // Commerce needs more than one user in some tests, and the Solo edition only allows one.
        putenv('CRAFT_EDITION=pro');
        unset($_SERVER['CRAFT_SITE']);

        parent::setUp();
    }

    #[Override]
    public function setupInstallsPlugin(): void
    {
        $composerPlugins = require package_path('vendor/craftcms/plugins.php');
        $handle = $composerPlugins[array_key_first(array_filter($composerPlugins, fn(array $plugin) => $plugin['basePath'] === package_path('src')))]['handle'];

        $this->app->when(Plugins::class)->needs('$composerPlugins')->give(fn() => $composerPlugins);

        foreach (['commerce', $handle] as $pluginHandle) {
            // Plugins::installPlugin() caches the loaded plugins, so each install needs a fresh instance.
            $this->app->forgetInstance(Plugins::class);
            $this->app->get(Plugins::class)->installPlugin($pluginHandle);
        }

        $this->app->forgetInstance(Plugins::class);
        $this->app->get(Plugins::class)->loadPlugins();

        $routes = $this->app->get('router')->getRoutes();
        $routes->refreshNameLookups();
        $routes->refreshActionLookups();
    }
}
```

`tests/Pest.php`: `uses(TestCase::class)->in('Feature');`. For `phpunit.xml`, see the testing reference in the craft-6-plugin-development skill.

## Fixtures

```php
function mollieGateway(array $settings = ['apiKey' => 'test_key']): Gateway
{
    return app(Gateways::class)->createGateway([
        'type' => Gateway::class,
        'name' => 'Mollie',
        'handle' => 'mollie',
        'paymentType' => 'purchase',
        'settings' => $settings,
    ]);
}

function mollieTransaction(float $amount = 12.3): Transaction
{
    $gateway = mollieGateway();
    app(Gateways::class)->saveGateway($gateway);

    $order = new Order();
    $order->email = 'customer@example.com';
    $order->gatewayId = $gateway->id;
    Elements::saveElement($order);

    $transaction = app(Transactions::class)->createTransaction($order, null, TransactionModel::TYPE_PURCHASE);
    $transaction->paymentAmount = $amount;
    $transaction->amount = $amount;

    return $transaction;
}
```

Fake the provider with `Http::fake([...])` and assert on what was sent with `Http::assertSent(fn(Request $request) => ...)`. Take response bodies from the provider's API reference, not from your own code. Use `Http::preventStrayRequests()` so a missing fake fails instead of calling the real API.

## What to test

Pick inputs where a plausible wrong implementation gives a different answer:

- The gateway type is registered, and the Commerce 5 class name loads with its settings.
- Settings validation (required keys, payment type), and `getSettingsHtml()` renders the fields.
- The request body: amounts in odd values (`19.99`, a zero-decimal currency, a three-decimal currency), addresses, line items, metadata, return, cancel and webhook URLs, and the event changing the request.
- Every documented status, on purchase and on the customer's return, mapped to success, processing, redirect or failure, with a message for each failure.
- Error bodies and non-JSON responses.
- Refunds through `app(Payments::class)->refundTransaction($transaction, $amount)`: full, partial, and a transaction stored by Commerce 5.
- Captures for authorize gateways.
- Each webhook path ([webhooks.md](webhooks.md)).
- `paymentFormUi()`: the controls and names, the trusted markup escaping keys, scripts registered, and the fallback when the provider is unreachable.

Break the code on purpose (drop a signature check, change the rounding) and check a test fails.

## Tooling and CI

- ECS with `craftcms/ecs`, PHPStan with Larastan (level 5 or higher), and Pest.
- Run `scan-craft5.sh` from craft-6-plugin-upgrade on `src/`. Only intentional `legacy/` aliases should show up.
- Check nothing pulls in Yii or Omnipay: `composer show yiisoft/yii2`, `composer show craftcms/commerce-omnipay` and `composer show omnipay/common` should each report the package isn't installed.

A GitHub Actions workflow on PHP 8.5:

```yaml
name: ci
on:
  workflow_dispatch:
  push:
    branches:
      - '5.x'
  pull_request:
permissions:
  contents: read
jobs:
  ci:
    name: ${{ matrix.name }}
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        include:
          - name: 'Code Quality / ECS'
            run: composer check-cs
          - name: 'Code Quality / PHPStan'
            run: composer phpstan -- --error-format=github
          - name: 'Tests'
            run: composer test -- --ci
    steps:
      - uses: actions/checkout@v4
      - uses: shivammathur/setup-php@v2
        with:
          php-version: '8.5'
          extensions: dom, curl, libxml, mbstring, zip, pdo, sqlite, pdo_sqlite, bcmath, intl, gd, fileinfo
          tools: composer:v2
          coverage: none
      - uses: ramsey/composer-install@v3
      - run: ${{ matrix.run }}
```

## Known problems on 6.x-dev

- **Composer refuses to install Craft 6.x-dev** when one of Craft's pinned dependencies has a Packagist security advisory (in November 2026, `mcp/sdk` 0.8.1, advisory PKSA-s52d-n7sx-trsg). CI fails at `composer install` in every job. It needs a fix in `craftcms/cms`. Locally, `COMPOSER_NO_SECURITY_BLOCKING=1 composer update` unblocks it. Don't add the advisory to the plugin's ignore list without the developer's agreement.
- **Unmerged Commerce fixes.** If a test fails inside Commerce (for example "Array to string conversion" when saving a transaction), check whether Commerce 6.x-dev has the fix yet. Apply an unmerged fix to `vendor/craftcms/commerce` locally to keep going, and list the dependency in the PR.
- **Manual checks in a browser.** A Testbench workbench host with Commerce and the plugin (installed through a path repository) lets you open the gateway settings page, save it with errors, and render the payment form on a site template. Pest can't show those.
