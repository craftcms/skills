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

- The helpers are namespaced functions: `use function CraftCms\Cms\template;` (and `pageTemplate`, `t`, and so on) at the top of the file. They return a `string`, so a controller can return the result directly.
- Default mode follows the request. A plugin's own CP templates (widget bodies, email or download pages) rendered during a front-end request need `TemplateMode::Cp` passed explicitly, or they are not found. Only use `TemplateMode::Site` for templates a developer chose or defined in a settings UI. Never assume a user-space template exists.
- Mark classes, properties or methods as sandbox-safe with `#[CraftCms\Cms\Twig\Attributes\AllowedInSandbox]`. The sandbox blocks `json_encode`, `className()` and `atom`, and Yii `Event` objects. Don't tell sites to allow `json_encode`: it serializes objects the sandbox would otherwise block, which leaked a user's password hash in testing. Build JSON with `"{{ value|e('js') }}"`, and give sandboxed templates arrays rather than objects.
- `renderString()` (`TemplateManager::renderString()`) turns autoescaping off for string templates. Check escaping with a real request to a template file.
- Laravel's `view()` also resolves Blade templates in your template root. Blade gets the same globals but not Twig's filters/functions.
- Events: `TemplateRendering`/`TemplateRendered` (and `PageTemplateRendering`/`PageTemplateRendered` for page templates) in `CraftCms\Cms\Twig\Events`.

## Template roots

- Your plugin automatically gets a CP template root at `resources/views/` (falls back to `resources/templates/` or top-level `templates/`).
- Site template roots: `public array $siteTemplateRoots = ['theme/light' => __DIR__.'/resources'];` or `TemplateRoots::register()`.
- Templates you have not moved yet: register the old folder explicitly, `app(TemplateRoots::class)->register(TemplateMode::Cp, $this->handle, $path)` in `boot()`, and remove it once the templates are in `resources/views/`.
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
CraftVariable::macro('track', function (string $eventName, array $data = [], int $value = 1) {
    // ...
});
// {% do craft.track('pageView', { elementId: entry.id }) %}
```

The macro closure is called directly with the arguments from Twig, and `$this` is the `CraftVariable`. Do **not** return a second closure from it: that closure is never run, so the call silently does nothing. To expose a service, return it: `CraftVariable::macro('reports', fn () => app(Reports::class))`. To expose a query, build and return it: `CraftVariable::macro('orders', function (array $criteria = []) { $query = Order::find(); \CraftCms\Cms\Support\Typecast::configure($query, $criteria); return $query; })`. Check `Typecast` exists in the installed `craftcms/cms` before using it.

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

The CP client-side architecture is being rebuilt (web components, Inertia, Vue), and the docs don't cover it yet. Prefer plugin `$scripts`/`$styles`/`$vite` publishing ([other-areas.md](other-areas.md)) over `{% js %}` snippets, copy the closest core component, and flag anything below that you can't check as unverified. These patterns worked in real upgrades:

- **Build:** a plugin Vite build marks `vue` and `@craftcms/cp` as external (Craft provides them at runtime), sets the Vue plugin's `template.compilerOptions.isCustomElement` to `tag => tag.startsWith('craft-')`, and writes to `public/build`, registered with `$vite`. Commit the build output. A small script with no build step can go in `$scripts`.
- **Registering components:** `window.Cp.booting(cp => cp.$components.register('MyUtility', MyUtility))`. Server-rendered CP HTML (utility `contentHtml()`, widget bodies) is compiled as a Vue template, so return a tag for the component rather than HTML with inline scripts.
- **Posting from a CP page:** route the action in `routes/cp.php` (the CP group already adds `auth` and `can:accessCp`; add the plugin's own `can:` middleware). The controller ends with `Inertia::flash('result', [...])` and `return back();`, as core's `FindAndReplaceController` does. The component posts with `window.Cp.$router.post(url, data, {preserveState: true, preserveScroll: true, onFlash, onError})`: use the mounted app's router, not a separate Inertia import. Tests read `session(Inertia\Support\SessionKey::FLASH_DATA)`. A CP-only action URL can move from `routes/actions.php` to this route in the native major; record the old URL in `UPGRADE.md`.
- **Element editor:** the full-page entry editor is an Inertia page, so `Element::EVENT_DEFINE_SIDEBAR_HTML` and `ElementSidebarHtmlResolving` never fire there. Add a details panel instead: register it with `Cp.$elementDetailsPanels.register()` and feed it data from an `ElementEditorPayloadResolving` listener.
- **Live Preview:** there's no inline Garnish script in the Vue editor. Use `onPreviewEvent('after-update-iframe' | 'before-close')` from `@craftcms/cp`. Craft's token middleware strips a request parameter named `token`, so don't name your own parameter that.
- **Testing:** load the page in a real browser and check the console. Many failures (an unregistered component, a missing external) show nothing on the server.

## Front-end forms (verified on guest-entries)

Twig front-end forms keep working: `csrfInput()` (renders `_token`), `actionInput('<handle>/<action>')`, `redirectInput(...)`, `hiddenInput()`, `input()`, `tag()` and `ul()` all exist. Posting to the page with an `action` param reaches the plugin's `routes/actions.php` route.

What changes is what the template can see after a **failed** post: the user is redirected back and the data is flashed, so a Craft 5 `entry` variable is not available:

| Craft 5 | Craft 6 |
| --- | --- |
| `{% set entry = entry ?? null %}` | not needed |
| `entry.title` (to repopulate) | `old('title')` |
| `entry.body` (custom field) | `old('fields.body')` |
| `entry.getErrors('title')` | `errors.get('title')` |
| `craft.app.sections.getSectionByHandle('x')` | `Sections.getSectionByHandle('x')` (Craft's facades are available in Twig) |
| flash message | `session().get('error')` / `session().get('success')` |

After a successful post with `redirectInput('thanks')`, the target page can read `session().get('success')`.

Update the plugin's README templates to these idioms, and list the differences in `UPGRADE.md`. Test with a real template in the host project ([testing.md](testing.md)), not by reasoning from the docs.
