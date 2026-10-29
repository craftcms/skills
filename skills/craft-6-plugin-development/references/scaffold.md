# Scaffolding a plugin

## Layout

```text
my-plugin/
├── composer.json
├── README.md
├── CHANGELOG.md
├── config/my-plugin.php          # optional: published config stub (see settings.md)
├── database/migrations/
│   ├── Install.php               # optional: runs on install (up) and uninstall (down)
│   └── 2026_01_01_000000_add_foo.php   # later schema changes
├── lang/en/my-plugin.php         # optional: translations
├── resources/
│   ├── icon.svg                  # plugin icon (Plugin Store, Settings → Plugins)
│   ├── icon-mask.svg             # optional: monochrome CP nav icon
│   └── views/                    # control panel template root, namespaced by handle
├── routes/
│   ├── web.php                   # front-end routes
│   ├── cp.php                    # control panel routes (prefixed with the cpTrigger)
│   └── actions.php               # legacy action paths: actions/<handle>/...
└── src/
    ├── Plugin.php
    ├── Settings.php
    ├── Http/Controllers/, Http/Requests/, Http/Middleware/
    ├── Events/, Listeners/, Data/, Models/, Enums/, Exceptions/
    ├── Jobs/, Console/Commands/, Policies/
    └── Fields/, Widgets/, Utilities/, Twig/
```

Craft finds everything relative to the directory that contains the plugin class: resources are `dirname(src)/resources`, migrations `dirname(src)/database/migrations`, routes `dirname(src)/routes`. Keep `Plugin.php` directly in `src/`, or override `getResourcesPath()` / `getMigrationsPath()`.

Only create the folders you use.

## composer.json

```json
{
    "name": "acme/shortlinks",
    "description": "Manage shortlinks from the control panel.",
    "type": "craft-plugin",
    "license": "MIT",
    "require": {
        "php": "^8.5",
        "craftcms/cms": "^6.0.0"
    },
    "autoload": {
        "psr-4": {
            "Acme\\Shortlinks\\": "src/"
        }
    },
    "extra": {
        "handle": "shortlinks",
        "name": "Shortlinks",
        "developer": "Acme",
        "documentationUrl": "https://github.com/acme/shortlinks",
        "class": "Acme\\Shortlinks\\Plugin"
    },
    "minimum-stability": "dev",
    "prefer-stable": true,
    "config": {
        "allow-plugins": {
            "craftcms/plugin-installer": true
        }
    }
}
```

- `type` must be `craft-plugin`. `craftcms/plugin-installer` writes every such package into the project's `vendor/craftcms/plugins.php` cache, which is how Craft finds plugins. That includes a root package, so the workbench finds the plugin it is developing.
- `extra.handle` is required: kebab-case, unique. `extra.class` is required unless the class is `Plugin` at the PSR-4 root (set it anyway).
- Do **not** add `extra.laravel.providers`. Craft boots plugins itself, only when installed and enabled.
- Keep `minimum-stability: dev` with `prefer-stable: true` until Craft 6.0.0 is tagged stable; Composer then picks stable releases automatically.

## The plugin class

```php
<?php

declare(strict_types=1);

namespace Acme\Shortlinks;

use CraftCms\Cms\Plugin\Plugin as BasePlugin;

class Plugin extends BasePlugin
{
    public string $schemaVersion = '1.0.0';

    public function boot(): void
    {
        // Initialization. Method injection works: boot(Sections $sections)
    }
}
```

`handle`, `name`, `developer`, `version` and `packageName` are filled in from Composer. Do not hard-code them.

### Declarative features

All of these come from traits already on the base class. Redeclare the property with the **same visibility** as the trait (changing it is a fatal error).

| Member | Visibility / type | Purpose |
| --- | --- | --- |
| `$schemaVersion` | `public string` | Bump when you add a migration, so Craft knows updates are pending |
| `$hasCpSettings` | `public bool` | Settings tile and page under Settings → Plugins |
| `$hasReadOnlyCpSettings` | `public bool` | Show settings read-only when admin changes are disallowed |
| `$hasCpSection` | `public bool` | Adds a CP nav item linking to `admin/<handle>` |
| `$config` | `public bool` | Publish and read `config/<handle>.php` (default true) |
| `$events` | `protected array` | `EventClass::class => Listener::class` (or list of listeners) |
| `$commands` | `protected array` | Artisan command classes |
| `$fieldTypes` | `protected array` | Field type classes |
| `$widgets` | `protected array` | Dashboard widget classes |
| `$utilities` | `protected array` | Utility classes |
| `$elementTypes` | `protected array` | Element type classes |
| `$siteTemplateRoots` | `protected array` | `'namespace' => path` for the site Twig environment |
| `$vite`, `$styles`, `$scripts` | `protected array` | CP assets to publish and load |
| `getPermissions()` | `protected function (): array` | `CraftCms\Cms\User\Data\Permission` objects |
| `schedule(Schedule $schedule)` | `protected function (): void` | Scheduled tasks |
| `getCpNavItem()` | `public function (): NavItem\|array\|null` | Customize the CP nav item (subnav, badge) |
| `settingsUi(UiContext $context = new UiContext)` | `public function (): ?Ui` | Settings page UI |
| `createSettings()` | `protected static function (): ?PluginSettings` | Settings object (**static**) |

Lifecycle hooks (all `protected function (): void`): `beforeInstall()`, `afterInstall()`, `beforeUninstall()`, `afterUninstall()`.

When unsure about a member, read the trait in `vendor/craftcms/cms/src/Plugin/Concerns/`.

### Editions

```php
public static function editions(): array
{
    return ['lite', 'pro'];
}

// Later:
if ($this->is('pro')) { /* ... */ }
```

## Install into the workbench

Set up the workbench as described in [testing.md](testing.md#workbench-setup); its seeder installs the plugin. Check:

```bash
vendor/bin/testbench craft:plugin:list          # installed and enabled
```

- Code edits are live. After changing `composer.json` (autoload, `extra`), run `composer dump-autoload` (which also regenerates `vendor/craftcms/plugins.php`), then `composer build`.
- A plugin that is listed but disabled, or whose routes vanished, usually means a wrong `extra.class` or a fatal error during boot. Check `workbench/storage/logs/laravel.log`.
- Other plugin commands: `craft:plugin:uninstall <handle> --force`, `craft:plugin:install`, `craft:plugin:enable`, `craft:plugin:disable`.
- To try the plugin in an existing Craft 6 project instead, add a path repository there (`composer config repositories.shortlinks '{"type":"path","url":"/abs/path/to/shortlinks"}'`, `composer require acme/shortlinks:@dev -W`), then `php artisan craft:plugin:install shortlinks`. There, changes to the plugin's `composer.json` need `composer update acme/shortlinks`.

## Icon

`resources/icon.svg` should be a square SVG with a `viewBox`. A simple placeholder:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" rx="12" fill="#e5422b"/><path d="M20 32h24M32 20v24" stroke="#fff" stroke-width="6" stroke-linecap="round"/></svg>
```
