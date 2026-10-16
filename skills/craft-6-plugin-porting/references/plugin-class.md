# Plugin class, traits and modules

Source: Craft 6.x extend docs, "Extension Options", "Base Plugin Class".

## Lifecycle

Laravel builds the app, discovers providers, calls each provider's `register()`, then `boot()`. Craft's `craftcms/plugin-installer` caches `craftcms-plugin` packages and boots them only when installed and enabled (respecting `disabledPlugins`).

- Put initialization in `boot()`. `register()` is rarely right: the event system may not be reliable that early.
- There is no central `Craft::$app` before plugins boot.
- Replaces `Craft::$app->onInit()`, `EVENT_INIT` and `EVENT_AFTER_LOAD_PLUGINS`: `app()->booted($callback)`.
- Cleanup at end of lifecycle: `app()->terminating($callback)`.
- Work after the response is sent (roughly `EVENT_AFTER_REQUEST`): `defer(fn () => ...)`.
- `boot()` supports dependency injection through its signature.

## Declarative registration via plugin traits

The base plugin class already uses all of these. Define the property or method, not the `use`.

| Trait | Property or method | Purpose |
| --- | --- | --- |
| `HasCommands` | `$commands` | Artisan command classes |
| `HasConfig` | `$config` (bool) | Set `false` to disable config publishing |
| `HasEditions` | `$editions`, `$minCmsEdition`, `static editions()` | Edition gating (`is()`) |
| `HasElementTypes` | `$elementTypes` | Element types |
| `HasFieldtypes` | `$fieldTypes` | Field types |
| `HasFrontendAssets` | `$vite`, `$styles`, `$scripts` | Asset publishing |
| `HasListeners` | `$events` | Event class to listener(s) |
| `HasPermissions` | `getPermissions()` | `CraftCms\Cms\User\Data\Permission` objects |
| `HasRoutes` | loads `routes/web.php`, `cp.php`, `actions.php` | Routes |
| `HasScheduling` | `schedule()` | Recurring tasks |
| `HasSettings` | `$hasCpSettings`, `$hasReadOnlyCpSettings` | CP settings screen |
| `HasTranslations` | `$t9nCategory`, `$sourceLanguage` | Translation category (defaults to handle) |
| `HasUtilities` | `$utilities` | Utilities |
| `HasViews` | (automatic) | Template root |
| `HasWidgets` | `$widgets` | Dashboard widgets |

## Modules

"Modules" are no longer a distinct concept.

- Project-specific module code goes in the `App` namespace, entry point is a regular service provider (for example `app/Providers/AppServiceProvider.php`).
- Register providers in `bootstrap/providers.php`, or make the primary provider an `Illuminate\Support\AggregateServiceProvider`.
- Bare service providers do not get the declarative traits above. Bind events and listeners directly, or use the registries ([events-and-registries.md](events-and-registries.md)).
- To share a module between projects, package it as a Laravel package (a Craft plugin if it needs Craft lifecycle management).
- Autoload the `App\` namespace to `app/` in `composer.json` (`autoload.psr-4`).

```php
// bootstrap/providers.php
return [
    App\Providers\AppServiceProvider::class,
];
```

## Modern PHP

PHP 8.5 is required, so 8.2 to 8.5 features are available (property hooks, `#[Override]`, typed class constants, pipe operator, new `array_*` functions). Craft itself leans on enums and attributes. Use `#[\Override]` when overriding Craft methods, to catch signature drift.

## Switching to the native base class (Stage 2): what stops working

When the plugin class changes from `craft\base\Plugin` to `CraftCms\Cms\Plugin\Plugin`, the adapter no longer treats the plugin as a Yii module. Port these at the same time:

- **Controllers and action URLs:** Yii controllers are not routed. Port them and register `routes/actions.php` ([http-and-auth.md](http-and-auth.md)).
- **Settings page:** `settingsHtml()` is not used. Implement `settingsForm()` ([fields-widgets-forms.md](fields-widgets-forms.md)).
- **Settings model:** `createSettings()` must return a `PluginSettings`. It is `protected static function createSettings(): ?PluginSettings` (static, unlike `createSettingsModel()`).
- **Initialization:** `init()` becomes `boot()`, which accepts injected services, for example `boot(\CraftCms\Cms\Route\Routes $routes)`.
- **Template root and icon:** `resources/views/` (or `resources/templates/`), `resources/icon.svg`.

Test after each of these: the plugin still installs and enables, and its settings load from project config unchanged.

## Class organization (conventional namespace)

Craft 6 organizes classes by role, not by Yii parentage. If the developer agreed to a conventional namespace, move classes as you port them:

| Craft 5 / Yii location | Craft 6 location | Core examples |
| --- | --- | --- |
| `src/Plugin.php` (`craft\myplugin\Plugin`) | `src/Plugin.php` (`CraftCms\MyPlugin\Plugin`) | |
| `src/models/Settings.php` | `src/Settings.php` (next to the plugin class) | |
| `src/controllers/` | `src/Http/Controllers/` | `CraftCms\Cms\Http\Controllers\AddressesController` |
| request validation (new) | `src/Http/Requests/` | `CraftCms\Cms\Http\Requests\...` |
| middleware (new) | `src/Http/Middleware/` | `CraftCms\Cms\Http\Middleware\...` |
| `src/events/` | `src/Events/` | `CraftCms\Cms\Section\Events\SectionSaved` |
| listeners (new) | `src/Listeners/` | |
| `src/models/` (data objects) | `src/Data/` | `CraftCms\Cms\Section\Data\Section` |
| `src/records/` (now Eloquent) | `src/Models/` | `CraftCms\Cms\Section\Models\Section` |
| `src/services/` | feature folders with `#[Singleton]` classes | `CraftCms\Cms\Section\Sections` |
| `src/console/controllers/` | `src/Console/Commands/` | `CraftCms\Cms\Entry\Commands\...` |
| `src/jobs/` | `src/Jobs/` | |

- Directories are PascalCase and case-sensitive. A case-only rename needs two `git mv` steps on macOS (`git mv events events_tmp && git mv events_tmp Events`).
- `composer.json` `autoload.psr-4` maps the namespace to `src/`. Remove the old root once nothing uses it, unless you keep a deliberate compatibility layer.
- Larger plugins can group by feature instead (`src/Reporting/Events/`, `src/Reporting/Data/`), as Craft does.
- Record every renamed class in `UPGRADE.md` with its old and new fully qualified name.
- After moving, re-run `scripts/scan-craft5.sh`: it flags leftover Yii-style lowercase directories.
