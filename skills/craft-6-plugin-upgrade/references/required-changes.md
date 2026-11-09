# Stage 1: required changes

Source: Craft 6.x extend docs, "Required Changes", "Base Plugin Class", "The Adapter", "Paths".

This is the minimum to get a plugin running on Craft 6.x. Everything else is about ejecting the adapter and is optional.

## Checklist (Stage 1, adapter-only)

1. Resolve all Craft 5.x deprecation warnings first. The adapter does not work otherwise.
2. Update `composer.json` in one of the two shapes below.
3. **Keep the legacy base class (`craft\base\Plugin`) for now.** The adapter routes `actions/<handle>/<controller>` URLs only to plugins that are Yii modules. After switching to `CraftCms\Cms\Plugin\Plugin`, those URLs return 404 until the controllers are upgraded and routed (Stage 2).
4. Update signatures of overridden methods that the legacy classes still provide, notably `attributes()` and `attributeLabels()`. If the plugin doesn't override them, nothing to do.
5. Work through [What breaks on the adapter](#what-breaks-on-the-adapter) for the parts of Craft the plugin uses.
6. Test with only this plugin installed: remove other plugins from the host project first, because the adapter activates whenever any installed plugin requires it. See [testing.md](testing.md).
7. A plugin shows as "Craft 6.0-ready" in the control panel once it tags a new major version requiring `craftcms/cms:^6.0.0` and adopts the new base class (Stage 2).

## Composer: two ways to ship the adapter release

**Cross-compatible, on the current major (what Craft's own plugins do).** One release supports Craft 4, 5 and 6:

```json
"require": {
  "craftcms/cms": "^4.0.0|^5.0.0|^6.0.0-alpha.1"
},
"suggest": {
  "craftcms/yii2-adapter": "Required to use My Plugin with Craft CMS 6."
}
```

- Use `suggest`, not `require`: Composer can't require the adapter only when Craft 6 is installed. Without it, Composer still installs the plugin on Craft 6, and `craft:plugin:install` then fails with `Class "craft\base\Plugin" not found`. Say in the README that Craft 6 users must `composer require craftcms/yii2-adapter`. `craft6-revamp` adds the adapter to projects it upgrades.
- Keep `config.platform.php` and the PHP constraint where they are, so Craft 4 and 5 users can still install.
- Branch on the Craft version where Craft 6 needs different code or markup: `version_compare(Craft::$app->getVersion(), '6.0.0-alpha', '>=')`. With the adapter, `Craft::$app->getVersion()` reports the Craft 6 version.
- If a feature can't work on the adapter at all, disable it on Craft 6 and say why in the UI (a `<craft-callout variant="warning">`), rather than letting it crash. Point users to the native major.

**Craft 6-only, as a new major.** Require `craftcms/yii2-adapter`, `craftcms/cms:^6.0.0` and PHP `^8.5` in the **plugin** package (use `6.x-dev` while no matching release exists, and set `minimum-stability` accordingly). If `config.platform.php` is lower than 8.5, remove or raise it: Composer would otherwise refuse the adapter.

Dependencies of the plugin that themselves require `craftcms/cms ^5` block both shapes. `craftcms/flysystem` needed 2.0.2 for Craft 6, for example. Check `composer why-not craftcms/cms 6.x-dev` in the host.

## What breaks on the adapter

The adapter keeps most Yii code running, but a constraint bump is rarely enough. Each of these broke a real plugin on Craft 6. Most of the fixes also run on Craft 5.

**PHP and libraries**

- PHP 8.3+: `range()` with a step that points the wrong way throws a `ValueError` (`range(0, $n - 1, -1)` for `$n > 0`).
- PHP 8.4+: implicitly nullable parameters (`string $x = null`) are deprecated. Write `?string $x = null`.
- graphql-php 15 removed `GraphQL\Type\Definition\FieldArgument`. Pass plain argument config arrays instead (they also work on graphql-php 14).
- Models: an override of `attributes()` or `attributeLabels()` without `: array` is a fatal error when the class loads.

**Legacy class names are aliases or subclasses of native classes**

- `craft\base\Element`, `craft\elements\Entry`, `craft\elements\db\ElementQuery` and similar are `class_alias`es of the native `CraftCms\Cms\…` classes. Code that relies on Yii behavior of those base classes breaks, and `is_subclass_of($class, yii\base\Component::class)` is false for them.
- `craft\fields\*` classes are subclasses of the native fields, not aliases. Fields saved on Craft 6 are stored as `CraftCms\Cms\Field\PlainText` and so on, so a `craft\fields\PlainText` type hint or a registry keyed by the legacy class name misses them. Resolve both names, or drop the type hint.
- Element type names are now the native class names (`CraftCms\Cms\Entry\Elements\Entry`), including in GraphQL `elementType` results and anything the plugin stores.
- Craft 6 components implement `Yiisoft\Arrays\ArrayableInterface`, not `yii\base\Arrayable`. Check for both before calling `toArray()`.
- Native elements have `errors()`, not `getErrors()` (which throws `BadMethodCallException`). Element and section IDs are strictly typed: `setTypeId()` rejects the string IDs Yii accepted, so cast them.

**Custom element types and queries**

Because the legacy query class is the native one, a Craft 5 element query doesn't work unchanged:

- `beforePrepare()` and `populate()` are never called (Craft only logs a deprecation). `$subQuery` and `joinElementTable()` no longer exist. Joins and conditions disappear, which shows up as `missing FROM-clause entry for table …` errors.
- `statusCondition(string $status): Closure` must return a closure that modifies the query builder, not a condition array. Status names may not arrive lowercased.
- `__set(string $name, mixed $value): void`, `setEagerLoadedElements(…, CraftCms\Cms\Element\Data\EagerLoadPlan $plan)` and `prepareEditScreen()` (now `Response|CpScreenResponse`) need the new signatures.
- `searchableAttributes()` is final. Override `protected static function defineSearchableAttributes()` (it exists on Craft 5 too).
- `previewTargets()` entries need a `label`.

Supporting Craft 5 and 6 from one release takes a version-switched trait that keeps the Craft 5 query code and adds the native version ([element-types.md](element-types.md#query-classes)). If that's too much, make Craft 6 support the native major's job.

**Missing or changed legacy APIs**

- `craft\migrations\Install` and `craft\helpers\MigrationHelper` don't exist. Core's install migration uses Laravel's schema builder, so tricks such as swapping the DB command map can't work.
- `Craft::$app->getLog()->targets['web']` doesn't exist. Use Laravel's `Log` facade.
- `craft\helpers\Queue::push()` returns `null` (Laravel's `dispatch()` gives no job ID). Don't treat that as a failure.
- A legacy controller's `asFailure()` returns `null` for a non-JSON request, and the request then falls through to template routing and a 500 (`Unable to find the template …`). Return a response yourself: `return $this->asFailure($message) ?? $this->redirect($url);`.
- Console commands run as `php artisan my-plugin:things:sync`. Update the README and any cron examples that use `php craft my-plugin/things/sync`.

**Twig sandbox**

Plugins that render templates written by site builders (URLs, payloads, object templates) through the sandbox get Craft 6's stricter allow list. Yii `Event` objects aren't allowed in it, so pass the event's data as an array (`get_object_vars($event)`). Templates that used `json_encode` need rewriting; don't tell sites to allow it ([templates-and-twig.md](templates-and-twig.md#rendering)).

**Control panel markup and JavaScript**

Craft 6 renders legacy CP templates inside its new shell, without Craft 5's `cp.css`:

- `.btn`, `.spinner`, `table.data`, `.error`, `.code` and similar classes have no styles. On Craft 6, render `<craft-button>` (its loading state replaces the spinner) and `<craft-callout variant="danger">`, and style the rest with Craft's CSS variables (`--c-spacing-*`, `--c-color-border-quiet`, `--c-font-mono`). `<craft-callout>` is `display: contents`, so put margins on a wrapper.
- `.hidden` is a plain `display: none` without `!important`, so a plugin's ID selectors can override it.
- `Garnish.$doc.ready()` fires before bridged CP screens mount. Use `Craft.whenReady` when it exists: `const whenReady = Craft.whenReady || (cb => Garnish.$doc.ready(cb))`.
- Lightswitches are `<craft-switch>` elements: select `craft-switch` as well as `.lightswitch`, and read its `checked` property instead of `.data('lightswitch')`. `<craft-select>` puts the `class` you pass on the `<select>` itself, so `$(this).parent().hasClass(…)` checks stop matching.
- Raw `<input>`s inside an editable table's `html` or `heading` cells aren't namespaced on Craft 6, and post outside `settings[…]`, so the setting silently isn't saved. Use real column types (`lightswitch`) and the row's `hiddenInputs` key.

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

Set `extra.class` in `composer.json`. Craft can find a class named `Plugin.php` at the autoload root without it, but `PluginTestCase` can't ("does not define a plugin class"):

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
