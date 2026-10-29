# Known traps

Each item was hit while building real plugins against Craft 6. If one no longer matches the installed source, trust the source.

## Plugin class

- Redeclared trait properties must keep the trait's visibility: `$events`, `$commands`, `$fieldTypes`, `$widgets`, `$utilities`, `$elementTypes`, `$siteTemplateRoots`, `$vite`, `$styles`, `$scripts` are `protected`; `$hasCpSettings`, `$hasCpSection`, `$schemaVersion`, `$config` are `public`.
- `createSettings()` is `protected static`. `settingsUi()` and `getCpNavItem()` are `public`.
- In a regular Craft project (not the workbench), after changing `extra.class` or the namespace run `composer update <package>`. `dump-autoload` does not refresh `vendor/craftcms/plugins.php`, and the plugin silently disappears (no routes, shown disabled).
- Don't pick a handle that matches a Craft config file name (`general`, `redirects`, `routes`, `twig-sandbox`): plugin config overrides live in the same `config/craft/` folder.

## Settings

- The published docs call the UI builder `Form` (`CraftCms\Cms\Form\…`, `settingsForm()`, `FormContext`, `formControl()`). In Craft 6 it is `CraftCms\Cms\Ui\…`: `Ui`, `UiContext`, `settingsUi()`, `uiControl()`. They also show the method as `protected`; it is `public`.
- Plugin settings controls get their values from the form context. Field-type and widget settings forms set `->value($this->prop)` themselves.

## Rendering

- `template()` and `pageTemplate()` default their mode from the request (`renderString()` defaults to Site). In the console (commands, jobs, tinker) that is CP mode, so site templates aren't found. Pass `TemplateMode::Site`.
- `CraftVariable::macro('name', fn () => $value)`: the closure is the method. The docs wrap it in a second closure, which hands Twig a `Closure`.
- CP subnav items are `NavItem` objects, not Craft 5's keyed arrays.
- `use CraftCms\Cms\Support\Facades\Twig;` then `new Twig\MyExtension` resolves under the facade's namespace. Alias the facade.

## Routes and HTTP

- Craft adds `auth` and `accessCp` to plugin CP routes and CP-prefixed action routes. Add `accessPlugin-<handle>` and your own permissions with `can:`; Craft never adds those.
- `$hasCpSection` creates an `accessPlugin-<handle>` permission and hides the nav item without it, but doesn't protect the routes.

## Jobs

- Call `parent::__construct()` in a job constructor; it sets the queue name.

## Workbench

- Run commands with `vendor/bin/testbench`, not `php artisan` (there is no `artisan` in a plugin).
- Without `AUTH_MODEL=CraftCms\Cms\User\Models\User` in `testbench.yaml`'s `env:`, login fails with "The authenticated user must implement CraftCms\Cms\User\Contracts\CraftUser".
- Without `DB_CONNECTION=sqlite` and `CACHE_STORE=file`, Craft talks to Testbench's in-memory `testing` connection (`no such table: cache`).
- `composer dump-autoload` purges the skeleton database. If login suddenly fails or tables are missing, run `composer build`.

## Packaging

- A Craft project's `public/robots.txt` is served before any route, so it shadows a plugin's `robots.txt` route. Mention it in the README if the plugin serves one (the workbench has no such file).
