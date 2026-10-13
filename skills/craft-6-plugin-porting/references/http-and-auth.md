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
- Checks: `Gate::check('ability')`, `Gate::authorize('view', $report)`, `Auth::craftUser()->can('ability')`, `$user->can('ability', $subject)`. Bare ability names fall through to Craft permissions.
- Compound checks: a policy class registered with `Gate::policy(Report::class, ReportPolicy::class)`. Ability names then reduce to `view`, `save`, etc.
- Intercept: `Gate::before()`, `Gate::after()`, or the `GateEvaluated` event.

## Session and user

- Current user element: `Illuminate\Support\Facades\Auth::craftUser()` (class is now `CraftCms\Cms\User\Elements\User`). Global `currentUser()` helper also exists.
- Flash messages: `CraftCms\Cms\Support\Flash`, or `RespondsWithFlash`. Categories `success`, `notice`, `error`.
- Validation errors live in `errors` (a `ViewErrorBag`) in templates. Repopulate with `old()`. Use `back()->with(...)` with serializable data.
