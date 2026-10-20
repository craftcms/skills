# Services and dependency injection

Source: Craft 6.x extend docs, "Services", "Helpers", "Settings + Config" (initialization).

Services are now plain autoloadable classes. No component tree, no `setComponents()`, no getters on the plugin.

## Upgrading a service class

Craft 5:

```php
Activity::getInstance()->getReports()->generate(...);
```

Craft 6:

```php
namespace MyOrg\Activity\Reporting;

#[\Illuminate\Container\Attributes\Singleton]
class Manager
{
    public function generate(Template $template): Report {}
}

app(\MyOrg\Activity\Reporting\Manager::class)->generate(...);
```

- Mark most services `#[Singleton]` so the container reuses the instance. A service that holds per-request state (the current cart, the current user's context, a per-request cache) should be `#[\Illuminate\Container\Attributes\Scoped]` instead, so long-running workers (Octane, queue workers) don't leak that state between requests.
- Never `new` a service, especially a singleton. Resolve it via the container or injection.
- Services need no base class. Extending `CraftCms\Cms\Component\Component` adds validation, macros, array access and constructor config if wanted.
- Do a strict horizontal upgrade first. Restructure afterwards if desired (for example split large services into invokable "action" classes that can be dispatched as jobs, as Craft did with garbage collection).

## Getting dependencies

- Inject via a controller constructor, a controller's `handle()`/`__invoke()`, a command's `handle()`, a job's `handle()`, or a plugin `boot()`.
- Outside DI: `app(Foo::class)`, or a facade.
- Craft services: `app(\CraftCms\Cms\ProjectConfig\ProjectConfig::class)` or the facade `CraftCms\Cms\Support\Facades\ProjectConfig::get('graphql.enabled')`.

Optional facade for your own API:

```php
class Reports extends \Illuminate\Support\Facades\Facade
{
    #[\Override]
    protected static function getFacadeAccessor(): string
    {
        return Manager::class;
    }
}
```

Craft exposes its facades to Twig. See [templates-and-twig.md](templates-and-twig.md) for yours.

## Replacements

| Craft 5 / Yii | Craft 6 |
| --- | --- |
| `Plugin::getInstance()->getFoo()` getters | Resolve the service class from the container; drop the getter. If other code has hundreds of call sites, keep a deprecated getter (for example a `serviceMap` trait on the plugin class that returns the legacy shims) while you move them, and remove it later |
| `Plugin::setComponents([...])` | Not needed |
| `Craft::createObject($class, $config)` | `app()->make($class, [...])` |
| `Craft::$app->...` service locator | Inject the service, or `app()` / facade |
| Application config tree / component config arrays | `config(...)` read at runtime in the service, defaults from general config |
| `Craft::$app->getView()->renderTemplate(..., View::TEMPLATE_MODE_SITE)` | `TemplateMode::with(TemplateMode::Site, fn () => ...)` or `template(..., TemplateMode::Site)` |
| Yii behaviors | Macros. See [templates-and-twig.md](templates-and-twig.md) and [models-and-validation.md](models-and-validation.md) |
| `Plugin::getInstance()->getSettings()` | Inject the settings class (bound in the container, see below), or `app(MyPlugin::class)->getSettings()`. Don't call `Plugin::getInstance()` in upgraded code |

## Typical helper moves

Most static helper classes moved to the `CraftCms\Cms\Support` namespace. Do not guess the new class. Check the `@deprecated` tag on the old helper, which points to the replacement. Common global helpers: `template()`, `pageTemplate()`, `renderString()`, `t()`, `cp_url()`, `site_url()`, `currentUser()`.

## Common lookups when replacing `Craft::$app` calls

| Craft 5 | Craft 6 |
| --- | --- |
| `Craft::$app->getSections()` / `getEntries()` (sections) | `CraftCms\Cms\Section\Sections` (inject) or the `CraftCms\Cms\Support\Facades\Sections` facade |
| `Craft::$app->getElements()->saveElement()` | `CraftCms\Cms\Element\Elements::saveElement()` (inject) |
| `Craft::$app->getProjectConfig()` | `CraftCms\Cms\Support\Facades\ProjectConfig` |
| `Craft::$app->getEdition()` / `Craft::Pro` | `CraftCms\Cms\Edition::isAtLeast(Edition::Pro)` |
| `Craft::$app->getUser()->getIdentity()` | `CraftCms\Cms\currentUserElement()` (or `currentUser()`) |
| `Db::idByUid('{{%elements}}', $uid)` | `DB::table(Table::ELEMENTS)->idByUid($uid)` |
| `User::find()->can('createEntries:' . $uid)` | Same method on `CraftCms\Cms\User\Elements\User::find()`; iterate the result |
| `Craft::$app->getView()->renderTemplate()` | `template()` |

Always check the installed source for the exact class and method before relying on a row: these were confirmed on 6.0.0-alpha.20.

## Don't use static lookups: let the container hand things over

`Plugin::getInstance()` and `Craft::$app` are the service-locator habit. In upgraded code, get the plugin, its settings and its services from the container:

```php
// Bind the settings once, in the plugin's boot():
public function boot(): void
{
    $this->app->singleton(Settings::class, fn () => $this->getSettings());
}

// Then type-hint what you need. Laravel injects it:
public function __invoke(Request $request, Sections $sections, Elements $elements, Settings $settings): Response
{
    $sectionSettings = $settings->getSection($section->uid);
}
```

- The plugin itself resolves from the container as the same booted instance: `app(MyPlugin::class)` (checked: it is identical to `MyPlugin::getInstance()`, with its handle and settings). Use it only where injection isn't possible (a static method, a closure in `boot()`).
- Inject into controller `__invoke()`/`handle()` methods, constructors, commands, jobs and listeners. Use a facade only for a one-liner where injection would be awkward.
- Plain data objects (such as a per-section settings object) can still be created with `new`. Services and the plugin must not be.
- `scripts/scan-craft5.sh` flags remaining `::getInstance()` calls under "Static lookups".

## Caching responses and data (verified on craftcms/element-api)

| Craft 5 / Yii | Craft 6 |
| --- | --- |
| `Craft::$app->getCache()->get($key)` | `CraftCms\DependencyAwareCache\Facades\DependencyCache::get($key)` (returns `null` on a miss, not `false`) |
| `$cache->set($key, $value, $duration, $dependency)` | `DependencyCache::put($key, $value, $ttl, $dependency)` |
| `yii\caching\TagDependency` | `CraftCms\DependencyAwareCache\Dependency\TagDependency` (`$dependency->tags[] = 'my-tag'`; `TagDependency::invalidate('my-tag')`) |
| `Craft::$app->getElements()->startCollectingCacheInfo()` / `stopCollectingCacheInfo()` | Inject `CraftCms\Cms\Element\ElementCaches`: same method names, `stopCollectingCacheInfo()` returns `[$dependency, $maxDuration]` |
| `Craft::$app->getConfig()->getGeneral()->cacheDuration` | Inject `CraftCms\Cms\Config\GeneralConfig` |
| `ConfigHelper::durationInSeconds()` | `CraftCms\Cms\Support\Config::durationInSeconds()` |
| `ArrayHelper::remove($a, 'k', $default)` / `ArrayHelper::merge()` | `CraftCms\Cms\Support\Arr::pull($a, 'k', $default)` / `Arr::merge()` (same recursive semantics as Yii) |
| `Craft::configure($query, $criteria)` | `CraftCms\Cms\Support\Typecast::configure($query, $criteria)` (what core does) |
| `$request->getPathInfo()` / `getQueryString()` | `$request->path()` / `$request->getQueryString()` |
| `Craft::$app->getSites()->getCurrentSite()` | Inject `CraftCms\Cms\Site\Sites` and call `getCurrentSite()` |
| `Craft::$app->getDeprecator()->log($key, $msg)` | `CraftCms\Cms\Support\Facades\Deprecator::log($key, $msg)` |
| `ClearCaches::EVENT_REGISTER_TAG_OPTIONS` handler | `CraftCms\Cms\Utility\Utilities\ClearCaches::addTag($tag, $label)` in `boot()` |

Core's `CraftCms\Cms\Gql\Gql::executeQuery()` is the model for caching a computed result with element-cache tags.

**Audit every cache duration.** Yii's default cache duration was the `cacheDuration` general config setting. In Laravel, a `null` TTL means **forever**, and `0` means **don't cache**. An upgrade that passes `null` through caches forever, and no response-body test will notice. Pass `Config::durationInSeconds($generalConfig->cacheDuration) ?: null` where the old code relied on the default, and keep Craft's meaning of `0` (until invalidated) as `null`.

To check an upgrade against the original, diff it against the Yii implementation while the adapter is still installed: call the new private method through `ReflectionMethod` in tinker and compare with `yii\helpers\Json::encode()` on strings like `a<b>&'"/é`.
