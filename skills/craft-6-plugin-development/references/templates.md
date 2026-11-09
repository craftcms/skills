# Templates, Twig and front-end output

Published docs: [templates.md](https://craftcms.com/docs/6.x/extend/templates.html), [assets.md](https://craftcms.com/docs/6.x/extend/assets.html), [macros.md](https://craftcms.com/docs/6.x/extend/macros.html).

## Rendering

Helpers are namespaced functions: `use function CraftCms\Cms\template;` (also `pageTemplate`, `renderString`, `renderObjectTemplate`, `sandboxedTemplate`, `renderSandboxedString`).

- `template($path, $vars, ?TemplateMode $mode)`: render a template to a string.
- `pageTemplate(...)`: a full page (CP layouts, or site pages that should get registered assets).
- `renderString($twig, $vars)`: a template string. Defaults to **site** mode.
- `renderSandboxedString()` / `sandboxedTemplate()`: for anything an editor or end user wrote.

`template()` and `pageTemplate()` take their mode from the request when you don't pass one: CP for `admin/…` requests **and for the console**. (`renderString()` always defaults to Site.) When rendering a site template from a command, job or tinker, pass `CraftCms\Cms\View\TemplateMode::Site`, or you'll get "Unable to find the template".

## Passing data to Twig

- Twig has no `route()` function. Use `url()`, `cpUrl()`, `siteUrl()`, `actionUrl()`, or pass URLs from PHP.
- Pass Eloquent models directly: `{{ link.code }}` behaves like `$link->code` (missing attributes give `null`; casts, accessors and relations work).

## Template roots

- CP: `resources/views/` (or `resources/templates/`) is registered as the plugin handle. `resources/views/_links/index.twig` → `shortlinks/_links/index`.
- Site: plugins have none by default. Add `protected array $siteTemplateRoots = ['shortlinks' => __DIR__.'/../resources/site'];` if site templates must include plugin templates. Prefer exposing a Twig function that returns HTML.

## Twig extensions

```php
use Acme\Shortlinks\Twig\ShortlinksExtension;
use CraftCms\Cms\Support\Facades\Twig as CraftTwig;

public function boot(): void
{
    CraftTwig::registerExtension(new ShortlinksExtension);
}
```

Alias the facade (or import your extension class): a relative `new Twig\Foo` after `use …\Facades\Twig;` resolves to the facade's namespace. Resolve services inside the callables with `app(...)`, not at construction time.

Prefix function names with the plugin (`shortlinkUrl()`), not generic ones (`url()`, `seo()`), which collide with Craft and other plugins.

## `craft.*` variables

```php
use CraftCms\Cms\Twig\Variables\CraftVariable;

CraftVariable::macro('shortlinks', fn () => app(ShortlinksVariable::class));
```

`{{ craft.shortlinks.top(5) }}`. The macro's closure *is* the method: its return value is what Twig gets. (The published docs wrap it in a second closure, which returns a Closure object to Twig.) `CraftVariable` forwards unknown calls to Craft and the Laravel app before macros, so use a distinctive name.

## User-entered HTML

Sanitize HTML that editors or visitors wrote before output: `CraftCms\Cms\Support\Facades\HtmlSanitizers::sanitize($html)` in PHP, `{{ body|sanitize }}` in Twig. Register a stricter named sanitizer with `HtmlSanitizers::extend('<handle>-links-only', …)` and use it as `sanitize($html, '<handle>-links-only')`.

## Global variables

```php
use CraftCms\Cms\View\Events\TemplateGlobalsResolving;
use Illuminate\Support\Facades\Event;

Event::listen(function (TemplateGlobalsResolving $event): void {
    $event->globals['shortlinks'] = app(ShortlinksVariable::class);
});
```

Available in Twig and Blade, both site and CP.

## Injecting into front-end pages

To add tags to every site page's `<head>` (meta tags, JSON-LD, analytics) without asking developers to edit templates, the options are:

1. A Twig function the developer places in their layout (`{{ seoHead() }}`): simplest, explicit, recommended default.
2. Automatic injection, tested in an SEO plugin: capture the page's entry with a `PageTemplateRendering` listener, then rewrite the HTML in middleware on `craft.web`.

   ```php
   use CraftCms\Cms\View\Events\PageTemplateRendering;   // public $template, $variables, $templateMode; vetoable
   use CraftCms\Cms\View\TemplateMode;

   public function boot(): void
   {
       Event::listen(function (PageTemplateRendering $event): void {
           if ($event->templateMode === TemplateMode::Site && ($event->variables['entry'] ?? null) instanceof Entry) {
               app(Head::class)->entry = $event->variables['entry'];   // Head is a #[Scoped] service
           }
       });
       $this->app['router']->pushMiddlewareToGroup('craft.web', Http\Middleware\InjectHead::class);
   }
   ```

   ```php
   // InjectHead::handle()
   $response = $next($request);
   if ($response->getStatusCode() === 200
       && str_contains($response->headers->get('Content-Type', ''), 'text/html')
       && is_string($html = $response->getContent()) && stripos($html, '</head>') !== false) {
       $tags = $this->head->render();
       // A callback, not a replacement string: '$10' in a title would be read as a backreference.
       $response->setContent(preg_replace_callback('/<\/head>/i', fn (): string => $tags.'</head>', $html, 1));
       $response->headers->remove('Content-Length');
   }
   return $response;
   ```

   Let a manual Twig function (option 1) set a flag on the scoped service so the middleware skips pages that already placed the tags.
3. `CraftCms\Cms\Support\Facades\HtmlStack` (service `CraftCms\Cms\View\HtmlStack`): `metaTag([...])`, `linkTag([...])`, `html($html, Position::Head)`, `script()`, `css()`, `jsFile()`. Queued HTML is output where the page template calls `{{ head() }}` / `{{ endBody() }}` (or by `pageTemplate()`), so it only appears on pages whose layout includes those tags. Register during the request, for example in a `TemplateRendering` listener or the Twig function itself.

Verify by requesting a real site page with curl and grepping the HTML.

## Front-end routes and sitemaps

Routes in `routes/web.php` can return any response: `response($xml, 200, ['Content-Type' => 'application/xml'])` for `sitemap.xml`, `response($txt)->header('Content-Type', 'text/plain')` for `robots.txt`. Use `Route::get('sitemap.xml', …)`; the dot is fine. Craft's site catch-all is a Laravel `fallback()` route, so plugin routes take precedence over element URIs. Real files in `public/` win over every route ([gotchas.md](gotchas.md#packaging)).

## CP assets

```php
protected array $scripts = ['shortlinks.js' => __DIR__.'/../resources/dist/shortlinks.js'];
protected array $styles = ['shortlinks.css' => __DIR__.'/../resources/dist/shortlinks.css'];
```

They are published to `public/vendor/<package>/` and load on every CP page. Read `Plugin/Concerns/HasFrontendAssets.php` for the exact key/value meaning and the `$vite` option before using it. Prefer server-driven UI (the UI builder, `reactive()` controls) over custom JavaScript.

## Verify

```bash
cat > /tmp/render.php <<'PHP'
<?php
echo \CraftCms\Cms\renderString('{{ shortlinkUrl("abc") }}');
PHP
vendor/bin/testbench tinker --execute="include '/tmp/render.php';"
```

And request a real site page that uses your function. Put a test template in `workbench/resources/views/` (the workbench's site template root) with a matching entry URI or a `workbench/routes/web.php` route that returns `\CraftCms\Cms\template('<name>')`.
