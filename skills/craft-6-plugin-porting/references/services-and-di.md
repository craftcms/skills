# Services and dependency injection

Source: Craft 6.x extend docs, "Services", "Helpers", "Settings + Config" (initialization).

Services are now plain autoloadable classes. No component tree, no `setComponents()`, no getters on the plugin.

## Porting a service

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

- Mark most services `#[Singleton]` so the container reuses the instance.
- Never `new` a service, especially a singleton. Resolve it via the container or injection.
- Services need no base class. Extending `CraftCms\Cms\Component\Component` adds validation, macros, array access and constructor config if wanted.
- Do a strict horizontal port first. Restructure afterwards if desired (for example split large services into invokable "action" classes that can be dispatched as jobs, as Craft did with garbage collection).

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
| `Plugin::getInstance()->getFoo()` getters | Resolve the service class from the container; drop the getter (keep a deprecated one only if a compat layer is needed) |
| `Plugin::setComponents([...])` | Not needed |
| `Craft::createObject($class, $config)` | `app()->make($class, [...])` |
| `Craft::$app->...` service locator | Inject the service, or `app()` / facade |
| Application config tree / component config arrays | `config(...)` read at runtime in the service, defaults from general config |
| `Craft::$app->getView()->renderTemplate(..., View::TEMPLATE_MODE_SITE)` | `TemplateMode::with(TemplateMode::Site, fn () => ...)` or `template(..., TemplateMode::Site)` |
| Yii behaviors | Macros. See [templates-and-twig.md](templates-and-twig.md) and [models-and-validation.md](models-and-validation.md) |
| `Plugin::getInstance()->getSettings()` | Still works. Also `app(MyPlugin::class)->getSettings()` |

## Typical helper moves

Most static helper classes moved to the `CraftCms\Cms\Support` namespace. Do not guess the new class. Check the `@deprecated` tag on the old helper, which points to the replacement. Common global helpers: `template()`, `pageTemplate()`, `renderString()`, `t()`, `cp_url()`, `site_url()`, `currentUser()`.
