# Stage 1: required changes

Source: Craft 6.x extend docs, "Required Changes", "Base Plugin Class", "The Adapter", "Paths".

This is the minimum to get a plugin running on Craft 6.x. Everything else is about ejecting the adapter and is optional.

## Checklist

1. Resolve all Craft 5.x deprecation warnings first. The adapter does not work otherwise.
2. `composer require craftcms/yii2-adapter` in the **plugin** package. Do not assume the host project includes it.
3. Require `craftcms/cms` at `^6.0.0` and PHP 8.5.
4. Make the primary class extend `CraftCms\Cms\Plugin\Plugin` instead of `craft\base\Plugin`.
5. Update the signatures of lower-level methods on the base class and its interfaces, notably `attributes()` and `attributeLabels()`. If the plugin doesn't override them, nothing to do.
6. Move code from `init()` to `boot()`.
7. Rename `createSettingsModel()` to `createSettings()`, returning a subclass of `CraftCms\Cms\Plugin\PluginSettings` (or `null`).
8. Tag a new major version (alpha or beta is fine). A cross-compatible 5.x/6.x release is not possible.
9. Test with the adapter required only by this plugin: remove the adapter and all other plugins from the host project first, because the adapter activates whenever any installed plugin requires it.

During alpha/beta a project may need `CRAFT_DISABLED_PLUGINS="*"` in `.env` to stop incompatible plugins loading mid-upgrade.

## Base class

```php
use CraftCms\Cms\Plugin\Plugin as BasePlugin;

class Demo extends BasePlugin
{
    public function boot(): void
    {
        // formerly init()
    }
}
```

Plugins are Laravel service providers, but they live outside Laravel's package discovery so Craft can manage install, uninstall, enable and disable. Do **not** add `extra.laravel.providers` for a Craft plugin class.

Only if the class is not named `Plugin.php` at the autoload root, set `extra.class` in `composer.json`:

```json
"extra": {
  "handle": "_demo-plugin",
  "name": "Demo Plugin",
  "developer": "Pixel & Tonic",
  "documentationUrl": "https://github.com/craftcms/demo-plugin",
  "class": "CraftCms\\DemoPlugin\\Demo"
}
```

(The structure page also mentions registering via `extra.laravel.providers` in a snippet. This conflicts with the provider page above, so verify against `craftcms/plugin-installer` before relying on it.)

## Package layout

- Keep the plugin class in `src/`. If you cannot, define `basePath()` and/or `resourcesPath()` on the plugin class.
- Icons: `icon.svg` and `icon-mask.svg` in a top-level `resources/` directory.
- Routes: top-level `routes/` directory (`web.php`, `cp.php`, `actions.php`).
- Migrations: top-level `database/migrations/`.
- Translations: rename `translations/` to `lang/`.
- Config stub: `config/<plugin-handle>.php` at the package root.
- Templates: `resources/views/` (falls back to `resources/templates/`, or a top-level `templates/`).
- Autoloading is case-sensitive and the namespace must match the path under the autoload root. You do not have to adopt PascalCase namespaces.

## Legacy aliasing snippets

Alias a fully compatible class into the old namespace:

```php
// old namespace
namespace myorg\pluginname\base;

if (false) {
    /** @deprecated 2.0.0 {@see \MyOrg\PluginName\Contracts\SomeInterface} */
    interface SomeInterface {}
}

class_alias(\MyOrg\PluginName\Contracts\SomeInterface::class, SomeInterface::class);
```

Forward a restructured legacy method to the new API:

```php
use CraftCms\Cms\Support\Facades\Deprecator;

Deprecator::log(__METHOD__, 'Old::method() is deprecated. Use New\Thing instead.');
return app(\MyOrg\PluginName\New\Thing::class)->...;
```

Never use the adapter's own deprecation API, which can trigger its own warning.
