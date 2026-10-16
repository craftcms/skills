# Controllers, routes and permissions

Source: Craft 6.x extend docs, "Controllers + Routing", "Session".

## Routing

Controllers are no longer auto-discovered or auto-routed. Map them with Laravel's `Route` facade in your plugin's top-level `routes/` directory. `HasRoutes` loads three files:

- `routes/web.php`: front-end routes, middleware `craft` and `craft.web`.
- `routes/cp.php`: control panel routes, middleware `craft.cp` (enforces basic permissions), prefixed with `cpTrigger`.
- `routes/actions.php`: compatibility for Yii action paths. Registered twice, under `{actionTrigger}/{plugin-handle}/...` and `{cpTrigger}/{actionTrigger}/{plugin-handle}/...`. Legacy but fully supported even without the adapter. Use it to keep front-end forms and integrations you don't control working, then prefer `web.php`/`cp.php`.

```php
// routes/web.php
Route::post('activity/track', TrackEvent::class);

// routes/actions.php (-> actions/activity/events/track and admin/actions/activity/events/track)
Route::post('events/track', TrackEvent::class);
```

- Prefix routes with your plugin handle to avoid collisions.
- Consider omitting front-end routes and letting developers mount your controllers where they want.
- Names, `route:list -v` for middleware, `Route::view()` for template-only routes.
- Unverified (not covered in the docs): how Craft 5 URL-rule registration (`EVENT_REGISTER_URL_RULES`, `EVENT_REGISTER_CP_URL_RULES`) maps over. The natural port is route files, but confirm against the `UrlManager` deprecation notes in source.

## Controllers

- No base controller to extend. Plain classes (grouped or invokable).
- Replace `actionFoo()` methods and `$this->request`, `$this->requirePostRequest()`, `requireLogin()` etc. with injected `Illuminate\Http\Request`, middleware and route definitions.
- Inject dependencies in the constructor (multi-action) or `__invoke()`/`handle()` (single action).
- `use CraftCms\Cms\Http\RespondsWithFlash` for `asSuccess()`, `asFailure()` and the JSON/model variants.
- Unverified: how Craft 5 `$allowAnonymous` and `requireLogin()` map over. The docs say authorization is done with middleware, so expect route placement and `can:`/auth middleware.
- Validate input with `$request->validate([...])`, a `FormRequest`, or a ruleset. See [models-and-validation.md](models-and-validation.md).
- Responses: `abort()`, `abort_if()`, `abort_unless()`, `redirect()`, `back()->with()`, `back()->withInput()`.
- Render templates with `template()`, `pageTemplate()` (CP layout or page-lifecycle hooks), `view()` (Blade).
- Rate limiting and hardening: define a `RateLimiter::for()` in `boot()` and apply `throttle:<name>` middleware to routes.
- Terminable middleware is not safe on all hosts. Use `app()->terminating()` for cleanup.

## Permissions and authorization

- Register permissions with `getPermissions()` returning `CraftCms\Cms\User\Data\Permission` objects (`key`, `label`, optional `nested`). Keys are globally unique, so name them explicitly with a plugin prefix.
- Guard routes: `->middleware(['can:activity-viewReports'])`.
- Checks: `Gate::check('ability')`, `Gate::authorize('view', $report)`, `currentUserElement()->can('ability')` (`CraftCms\Cms\currentUserElement()`), `$user->can('ability', $subject)`. Bare ability names fall through to Craft permissions.
- Compound checks: a policy class registered with `Gate::policy(Report::class, ReportPolicy::class)`. Ability names then reduce to `view`, `save`, etc.
- Intercept: `Gate::before()`, `Gate::after()`, or the `GateEvaluated` event.

## Session and user

- Current user: `$request->craftUser()` or the helpers `CraftCms\Cms\currentUser()` and `currentUserElement()` (the element class is now `CraftCms\Cms\User\Elements\User`). `Auth::craftUser()` shown in the 6.x docs does **not** exist on 6.0.0-alpha.20 (it throws `SessionGuard::craftUser does not exist`).
- Flash messages: `CraftCms\Cms\Support\Flash`, or `RespondsWithFlash`. Categories `success`, `notice`, `error`.
- Validation errors live in `errors` (a `ViewErrorBag`) in templates. Repopulate with `old()`. Use `back()->with(...)` with serializable data.

## Porting a Yii controller action (verified on guest-entries)

| Craft 5 / Yii | Craft 6 |
| --- | --- |
| `class SaveController extends Controller`, `actionIndex()` | Plain class with `__invoke(Request $request, ...)`, `use CraftCms\Cms\Http\RespondsWithFlash` |
| `Craft::$app->getRequest()->getBodyParam('x')` | `$request->input('x')`, `$request->boolean('x', true)` |
| `$this->requirePostRequest()` | `Route::post(...)` |
| `$allowAnonymous = true` | Route placement and middleware: `routes/actions.php` is reachable by guests |
| `!$request->getIsSiteRequest()` then `NotFoundHttpException` | `abort_if($request->isCpRequest(), 404)` (`routes/actions.php` is registered for both site and CP prefixes) |
| `throw new BadRequestHttpException('...')` | `abort(400, '...')` |
| `$this->asModelSuccess($model, $msg, 'entry')` / `asModelFailure(...)` | Same names via `RespondsWithFlash` |
| `Db::idByUid('{{%elements}}', $uid)` | `DB::table(Table::ELEMENTS)->idByUid($uid)` (`CraftCms\Cms\Database\Table`) |
| `Craft::$app->getElements()->saveElement($el)` | Inject `CraftCms\Cms\Element\Elements` and call `saveElement($el)` |
| `Craft::$app->getEntries()->getSectionByHandle()` | Inject `CraftCms\Cms\Section\Sections` (or the `Sections` facade) |
| `$entry->setScenario(Element::SCENARIO_LIVE)` | `$entry->ruleset->useScenario(ElementRules::SCENARIO_LIVE)` |
| `Craft::info(...)` | `Illuminate\Support\Facades\Log::info(...)` |
| `Craft::t('cat', 'msg')` | `t('msg', category: 'cat')` |

```php
// routes/actions.php  ->  actions/<handle>/save, and the CP twin
Route::post('save', SaveController::class);
```

## CSRF

Laravel verifies CSRF tokens on web routes (missing token: 419). A Yii controller with `$enableCsrfValidation = false` (or a plugin setting for it) becomes a route exemption, registered in the plugin's `boot()`:

```php
use Illuminate\Foundation\Http\Middleware\PreventRequestForgery;

public function boot(\CraftCms\Cms\Route\Routes $routes): void
{
    if (!$this->getSettings()->enableCsrfProtection) {
        PreventRequestForgery::except([$routes->actionTriggerUriPrefix() . "/$this->handle/save"]);
    }
}
```

Craft uses the same mechanism for `graphql/api`. (The upstream native guest-entries port instead marked its setting deprecated and left CSRF to the application.)

## Failed form posts: what the template gets

For a non-Ajax post, `asModelFailure()` redirects back and flashes the data. The controller's model variable (`'entry'`) is **not** a template variable any more. Templates use:

- `old('title')`, `old('fields.body')` to repopulate the form
- `errors.get('title')` / `errors.has('title')` for validation errors
- `session().get('error')` for the message
- `session().get('<modelName>')` for the model's data as an array

An Ajax request (`Accept: application/json`) gets a JSON response with HTTP `200` or `400` and the keys `message`, `modelName`, `modelClass`, `modelId` (success only) and `entry`.

## API and JSON routes (verified porting craftcms/element-api)

- **Dynamic routes from config:** `routes/web.php` can loop over settings and register one route per entry. `app(Plugin::class)->getSettings()` already contains the values from `config/craft/<handle>.php` when routes load. Pass route parameters to user closures by name with `app()->call($closure, $routeParams)`: it also injects type-hinted services such as `Illuminate\Http\Request`.
- **Yii URL rules to Laravel routes:** `news/<id:\d+>.json` becomes `news/{id}.json`. Inline regexes and the `{handle}`/`{slug}` tokens are gone, so a parameter matches anything. Restore the old constraint with `->whereNumber('id')` (or `->where()`), or the old 404 becomes an error: a non-numeric value reaching an `int` argument is a `TypeError` (500). `Route::match(['GET', 'HEAD', 'OPTIONS'], ...)` for read-only APIs.
- **Response headers from user code:** `Craft::$app->getResponse()->getHeaders()->set($name, $value)` becomes `CraftCms\Cms\Support\Facades\ResponseHeaders::add($name, $value)`. It is a scoped service that Craft's `SetHeaders` middleware applies on the way out. To mimic Yii's `setDefault()` (set only if absent), check `app(ResponseHeaders::class)->headers` first.
- **No cookies on JSON routes:** routes in `routes/web.php` get the full web middleware stack, so every response sets an `XSRF-TOKEN` and a session cookie, and CDNs won't cache it. For a read-only API, exclude the stack from the route:

```php
Route::match(['GET', 'HEAD', 'OPTIONS'], $pattern, ApiController::class)
    ->withoutMiddleware([
        \Illuminate\Cookie\Middleware\EncryptCookies::class,
        \Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse::class,
        \Illuminate\Session\Middleware\StartSession::class,
        \Illuminate\View\Middleware\ShareErrorsFromSession::class,
        \Illuminate\Foundation\Http\Middleware\PreventRequestForgery::class,
    ]);
```

Verified: no `Set-Cookie`, and requests that carry a logged-in cookie still work.
- **JSON/JSONP output:** Yii's `JsonResponseFormatter` and `Json::htmlEncode()` differ from `JsonResponse`. To keep bodies identical, build the string yourself: JSONP is `callback(` + `json_encode($data, JSON_UNESCAPED_UNICODE | JSON_HEX_QUOT | JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS)` + `);` and ignores user JSON options and pretty-printing.
- **`config:cache` and closures:** `php artisan config:cache` throws `LogicException: ... is non-serializable` when a config file holds closures (as Element API's does). Say so in the README and `UPGRADE.md`. Routes can be cached, but must be re-cached when the config changes.
