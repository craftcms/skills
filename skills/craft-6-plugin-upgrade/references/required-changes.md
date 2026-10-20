# Stage 1: required changes

Source: Craft 6.x extend docs, "Required Changes", "Base Plugin Class", "The Adapter", "Paths".

This is the minimum to get a plugin running on Craft 6.x. Everything else is about ejecting the adapter and is optional.

## Checklist (Stage 1, adapter-only)

1. Resolve all Craft 5.x deprecation warnings first. The adapter does not work otherwise.
2. `composer require craftcms/yii2-adapter` in the **plugin** package. Do not assume the host project includes it.
3. Require `craftcms/cms` at `^6.0.0` and PHP `^8.5` (use `6.x-dev` for the adapter and cms while no matching release exists, and set `minimum-stability` accordingly). If `config.platform.php` is set lower than 8.5, remove or raise it: Composer would otherwise refuse the adapter.
4. **Keep the legacy base class (`craft\base\Plugin`) for now.** The adapter routes `actions/<handle>/<controller>` URLs only to plugins that are Yii modules. After switching to `CraftCms\Cms\Plugin\Plugin`, those URLs return 404 until the controllers are upgraded and routed (Stage 2). The upstream compatibility branch of `craftcms/guest-entries` did exactly this: a Composer constraint change and `attributes(): array`.
5. Update signatures of overridden methods that the legacy classes still provide, notably `attributes()` and `attributeLabels()`. If the plugin doesn't override them, nothing to do.
6. Test with the adapter required only by this plugin: remove other plugins from the host project first, because the adapter activates whenever any installed plugin requires it. See [testing.md](testing.md).
7. A plugin shows as "Craft 6.0-ready" in the control panel once it tags a new major version requiring `craftcms/cms:^6.0.0` and adopts the new base class (Stage 2). Cross-compatible 5.x/6.x releases are not possible.

During alpha/beta a project may need `CRAFT_DISABLED_PLUGINS="*"` in `.env` to stop incompatible plugins loading mid-upgrade.

## Base class (Stage 2)

Switch only together with the controller and route upgrade. See [plugin-class.md](plugin-class.md).

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
