# Templates, Twig and rendering

Source: Craft 6.x extend docs, "Templates + Rendering", "Behaviors" (macros), "Helpers".

## Rendering

| Craft 5 | Craft 6 |
| --- | --- |
| `Craft::$app->getView()->renderTemplate($t, $vars)` | `template($t, $vars)` |
| `renderPageTemplate()` (CP layout, asset injection) | `pageTemplate($t, $vars)` |
| `renderString()` | `renderString($string, $vars)` |
| Switching modes with `View::TEMPLATE_MODE_SITE` | `template($t, $vars, TemplateMode::Site)` or `TemplateMode::with(TemplateMode::Site, fn () => ...)` |
| Sandboxed rendering | `sandboxedTemplate()`, `renderSandboxedString()`, `renderSandboxedObjectTemplate()` |

- Default mode follows the request. Only use `TemplateMode::Site` for templates a developer chose or defined in a settings UI. Never assume a user-space template exists.
- Mark classes, properties or methods as sandbox-safe with `#[CraftCms\Cms\Twig\Attributes\AllowedInSandbox]`.
- Laravel's `view()` also resolves Blade templates in your template root. Blade gets the same globals but not Twig's filters/functions.
- Events: `TemplateRendering`/`TemplateRendered` (and `PageTemplateRendering`/`PageTemplateRendered` for page templates) in `CraftCms\Cms\Twig\Events`.

## Template roots

- Your plugin automatically gets a CP template root at `resources/views/` (falls back to `resources/templates/` or top-level `templates/`).
- Site template roots: `public array $siteTemplateRoots = ['theme/light' => __DIR__.'/resources'];` or `TemplateRoots::register()`.
- Prefer exposing an API that renders HTML fragments (for example `{{ form('handle').render() }}`) over shipping site-mode templates.

## Twig extensions

```php
// in boot()
\CraftCms\Cms\Support\Facades\Twig::registerExtension(new MyTwigExtension);
// or app(\CraftCms\Cms\Twig\Twig::class)->registerExtension(...)
```

Craft's internal Twig extensions were split into `CraftCms\Cms\Twig\Extensions\*` (Core, Laravel, Date, Array, Text, Html, Cp, Fe, SinglePreloader). Your whole API is also reachable from Twig via `app()`.

## `craft.myplugin` and variables

Craft 5 `CraftVariable::EVENT_INIT` + `$variable->set('myplugin', ...)` becomes a macro (`CraftCms\Cms\Twig\Variables\CraftVariable`):

```php
CraftVariable::macro('track', function () {
    return function (string $eventName, array $data = [], int $value = 1) {
        // ...
    };
});
// {% do craft.track('pageView', { elementId: entry.id }) %}
```

Unknown calls on `CraftVariable` forward to `CraftCms\Cms\Cms`, then Laravel's application, so generic macro names can be intercepted. Use distinctive names.

## Globals

```php
Event::listen(function (\CraftCms\Cms\View\Events\TemplateGlobalsResolving $event) {
    $event->globals['reporting'] = app(Manager::class);
});
```

Available in Twig and Blade. Craft also adds extra Twig-only variables from its extensions.

## Facades in Twig

Add a `CraftCms\Cms\Twig\Variables\Facade` instance of your facade class so `{% do Events.track(...) %}` works. Craft already exposes all its own facades.

## Behaviors

No Yii behaviors. Use `Macroable` macros, registered in `boot()`. See [models-and-validation.md](models-and-validation.md).

## Control panel front end

The CP client-side architecture is being rebuilt (web components via Lion, Inertia, Vue). The docs do not yet give specifics. Prefer plugin `$scripts`/`$styles`/`$vite` publishing ([other-areas.md](other-areas.md)) over `{% js %}` snippets, and flag any heavy CP UI work as unverified.
