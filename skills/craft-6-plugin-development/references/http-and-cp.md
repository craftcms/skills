# Routes, controllers and control panel pages

Laravel routing, controllers, form requests and middleware all work as usual. This page covers what Craft adds. Published docs: [http.md](https://craftcms.com/docs/6.x/extend/http.html), [templates.md](https://craftcms.com/docs/6.x/extend/templates.html), [session.md](https://craftcms.com/docs/6.x/extend/session.html).

## Route files

Craft's `HasRoutes` trait loads three optional files from the plugin's top-level `routes/` directory:

| File | Middleware | Prefix | Use for |
| --- | --- | --- | --- |
| `routes/web.php` | `craft`, `craft.web` | none | Front-end pages, public endpoints |
| `routes/cp.php` | `web`, `craft`, `craft.cp` | the CP trigger (`admin/`) | Control panel pages |
| `routes/actions.php` | site and CP middleware | `actions/<handle>/` and `admin/actions/<handle>/` | Form posts that need the classic `actionInput('<handle>/…')` path |

```php
<?php

// routes/cp.php: GET /admin/shortlinks
use Acme\Shortlinks\Http\Controllers\LinksIndexController;
use Illuminate\Support\Facades\Route;

Route::middleware(['auth', 'can:accessCp', 'can:accessPlugin-shortlinks'])->group(function () {
    Route::get('shortlinks', LinksIndexController::class)->name('shortlinks.index');

    Route::middleware('can:shortlinks-manageLinks')->group(function () {
        Route::get('shortlinks/new', [LinksController::class, 'create'])->name('shortlinks.create');
        Route::post('shortlinks', [LinksController::class, 'store'])->name('shortlinks.store');
    });
});
```

- Prefix every path and route name with the plugin handle to avoid collisions.
- Check registration with `vendor/bin/testbench route:list --name=<handle>` if you name routes, or `--path=<handle>` (cp routes show as `{cpTrigger}/...`; `--path` misses routes whose path is configurable).
- Craft adds `auth` and `can:accessCp` to `cp.php` routes. Add `can:accessPlugin-<handle>` and your own permissions yourself, after `auth` (`can:` alone answers guests with 403 instead of the login redirect).
- `routes/web.php` and the site half of `routes/actions.php` are public by design. Add `throttle:` to public write endpoints.
- `Plugin::getInstance()->getSettings()` works inside route files (for configurable paths).
- Named routes: generate URLs in PHP with `route('shortlinks.index')`. Twig has **no** `route()` function; use `cpUrl('shortlinks')`, `actionUrl()`, `siteUrl()` or `url()`, or pass URLs in from the controller.

## Controllers

There is no Craft base controller; write plain Laravel controllers. Use the `CraftCms\Cms\Http\RespondsWithFlash` trait for save and delete responses: `asSuccess()`, `asFailure()`, `asModelSuccess()`, `asModelFailure()` (and `asJson…` variants) return JSON for `Accept: application/json` requests, and otherwise flash a CP notice and redirect (`asFailure()` redirects back with input).

```php
return $this->asSuccess(t('Link saved.', category: 'shortlinks'), ['link' => $link], redirect: cp_url('shortlinks/links'));
```

To flash from code that builds its own response, use `CraftCms\Cms\Support\Flash` (`Flash::success()`, `error()`, `notice()`); everything goes through the same CP message queue. Laravel validation errors reach `Ui` forms inline, and Twig templates can read `errors` and `old('field')`.

## Permissions

```php
use CraftCms\Cms\User\Data\Permission;

protected function getPermissions(): array
{
    return [
        new Permission(key: 'shortlinks-manageLinks', label: t('Manage shortlinks', category: 'shortlinks')),
    ];
}
```

- Keys are global: prefix them with the handle.
- `$nested` is a `Collection` (`nested: collect([new Permission(...)])`), not an array.
- Guard routes with `->middleware('can:shortlinks-manageLinks')`. Check in code with `Gate::check('shortlinks-manageLinks')` or `currentUser()?->can(...)`. Admins pass every check.
- With `$hasCpSection = true`, Craft adds an `accessPlugin-<handle>` permission and hides the nav item from users without it. It doesn't guard your routes: include `can:accessPlugin-<handle>` in the CP route group's middleware.

## Control panel section

```php
public bool $hasCpSection = true;   // nav item linking to admin/<handle>

use CraftCms\Cms\Cp\Data\NavItem;

use function CraftCms\Cms\cp_url;

public function getCpNavItem(): NavItem|array|null
{
    return parent::getCpNavItem()
        ->subnav([
            new NavItem()->label(t('Links', category: 'shortlinks'))->href(cp_url('shortlinks')),
            new NavItem()->label(t('Stats', category: 'shortlinks'))->href(cp_url('shortlinks/stats')),
        ]);
}
```

Build the subnav from the current user's permissions (`Gate::check(...)`) and make the nav item link to a page every user with `accessPlugin-<handle>` can open; otherwise a user with only one permission lands on a 403. `subnav()` takes a list of `NavItem` objects (not the Craft 5 keyed-array shape). The parent item links to `admin/<handle>`, so you must define a `Route::get('<handle>', …)` in `routes/cp.php`. The nav icon comes from `resources/icon-mask.svg`. Fluent methods are on `vendor/craftcms/cms/src/Cp/Data/ActionItem.php` (`label`, `href`, `icon`, `badgeCount`, `selected`, …).

## Control panel pages

The control panel is a Vue/Inertia app. Build plugin pages in this order of preference:

1. **The `Ui` builder** (`CpScreenResponse->ui(...)`) for indexes, edit forms and settings-style screens. Pure PHP, native look, accessible, and no JavaScript build. This covers most plugin CRUD.
2. **A Vue page** (`CpScreenResponse->inertiaPage('<handle>/Page', $props)`) for genuinely custom UI: dashboards, charts, drag-and-drop tools. Needs a Vite build ([below](#vue-pages)).
3. **Twig `pageTemplate()`** only when porting an existing Craft 5 template. These render as a legacy "bridge screen" inside the Vue shell. Don't use them for new plugins.

Any `CpScreenResponse` also works in a slideout with no controller changes: plugin JavaScript opens one with `Craft.openSlideout(url)` on Inertia pages, and the server can detect it from the `X-Craft-Container-Id` header.

Check every page in a browser if one is available: CP pages render client-side, so curl only sees JSON props ([testing.md](testing.md#control-panel-requests)).

### Index page with a `Ui` table

```php
use CraftCms\Cms\Http\Responses\CpScreenResponse;
use CraftCms\Cms\Ui\Nodes\Table;
use CraftCms\Cms\Ui\Ui;
use Illuminate\Support\Facades\Gate;

use function CraftCms\Cms\cp_url;
use function CraftCms\Cms\t;

public function index(): CpScreenResponse
{
    $canManage = Gate::check('shortlinks-manageLinks');

    $rows = Link::query()->orderBy('code')->get()->map(fn (Link $link): array => [
        'id' => $link->id,
        'code' => $canManage
            ? ['label' => $link->code, 'url' => cp_url("shortlinks/links/{$link->id}")]
            : $link->code,
        'destination' => $link->destination,
        'hits' => $link->hits,
        '_deletable' => $canManage,
        '_deleteUrl' => $canManage ? cp_url("shortlinks/links/{$link->id}") : null,   // receives DELETE
    ])->all();

    $table = Table::make('shortlinks-links')
        ->columns([
            ['key' => 'code', 'label' => t('Code', category: 'shortlinks')],
            ['key' => 'destination', 'label' => t('Destination', category: 'shortlinks')],
            ['key' => 'hits', 'label' => t('Hits', category: 'shortlinks')],
        ])
        ->rows($rows)
        ->emptyMessage(t('No links yet.', category: 'shortlinks'))
        ->when($canManage, fn (Table $table) => $table
            ->deletable()
            ->createAction(t('New link', category: 'shortlinks'), cp_url('shortlinks/links/new'))
            ->createActionInPageHeader());

    return new CpScreenResponse()
        ->title(t('Links', category: 'shortlinks'))
        ->ui(Ui::make([$table]));
}
```

- Cells are scalars, `['label' => …, 'url' => …]` links, or `['html' => …]` (escape it yourself).
- `_deletable` / `_deleteUrl` per row add a delete button with a confirm. The URL receives a `DELETE`; respond with `$this->asSuccess(...)`.
- Status and bulk actions (a moderation queue):

  ```php
  // Each row: '_status' => 'pending' (a string, or a bool for enabled/disabled). Craft turns it into
  // ['value' => 'pending', 'label' => 'Pending', 'fill' => <status color>]; see Ui/Nodes/Table::resolveRowStatus().
  $table
      ->statusFilter([                       // filters rows locally on _status.value
          ['value' => 'pending', 'label' => t('Pending', category: 'ratings')],
          ['value' => 'approved', 'label' => t('Approved', category: 'ratings')],
      ])
      ->bulkActions([                        // selected rows POST {ids: [...], ...params} to url
          ['label' => t('Approve', category: 'ratings'), 'url' => cp_url('ratings/moderate'), 'params' => ['status' => 'approved']],
          ['label' => t('Reject', category: 'ratings'), 'url' => cp_url('ratings/moderate'), 'params' => ['status' => 'rejected']],
      ])
      ->bulkDeletable(cp_url('ratings'));    // DELETE {ids: [...]}
  ```

  The endpoint validates `ids.*` and returns `$this->asSuccess(...)`; the table reloads its `ui` prop. `statusActions()` adds a separate "Set status" menu with the same item shape.
- More: `searchable()`, `pagination()` with `perPage()` and `dataUrl()` for server-side paging, `reorderable($url)`, `toggleableColumns()`. Read `vendor/craftcms/cms/src/Ui/Nodes/Table.php`, and `ReleasesController::index()` in Craft for a server-paginated, searchable example.

### Edit page with a `Ui` form

```php
use CraftCms\Cms\Ui\Controls\Choice;
use CraftCms\Cms\Ui\Controls\Text;
use CraftCms\Cms\Ui\Nodes\Field;
use CraftCms\Cms\Ui\Nodes\HiddenField;
use CraftCms\Cms\Ui\UiContext;

public function edit(?Link $link = null): CpScreenResponse
{
    $link ??= new Link(['statusCode' => 302]);

    return new CpScreenResponse()
        ->title($link->exists ? $link->code : t('New link', category: 'shortlinks'))
        ->addCrumb(t('Links', category: 'shortlinks'), 'shortlinks/links')
        ->ui(
            Ui::make([
                HiddenField::make('id'),
                Field::make(t('Code', category: 'shortlinks'), Text::make('code'))->required(),
                Field::make(t('Destination', category: 'shortlinks'), Text::make('destination'))->required(),
                Field::make(t('Status', category: 'shortlinks'), Choice::make('statusCode')->options([
                    ['label' => '301', 'value' => 301],
                    ['label' => '302', 'value' => 302],
                ])),
            ]),
            new UiContext(values: [
                'id' => $link->id,
                'code' => $link->code ?? '',
                'destination' => $link->destination ?? '',
                'statusCode' => $link->statusCode,
            ]),
            ['submit' => ['method' => 'post', 'url' => cp_url('shortlinks/links')]],
        );
}

public function store(StoreLinkRequest $request): Response
{
    $data = $request->validated();
    Link::findOrNew($data['id'] ?? null)->fill($data)->save();

    return $this->asSuccess(t('Link saved.', category: 'shortlinks'), redirect: cp_url('shortlinks/links'));
}
```

- Values come from the `UiContext`, keyed by control path. Pass every value (use `''`, not `null`, for empty text).
- The page shows a **Save** button that submits the values as an Inertia request to `submit.url`. A failed validation (`FormRequest`, `$request->validate()`, or `throw ValidationException::withMessages([...])`) redirects back and the errors appear inline on the matching controls; input is kept. A success redirect with a flash message returns to the index.
- Mark controls `->reactive()` and pass a `'refreshUrl' => …` prop to rebuild the UI server-side as values change (see Craft's `AssetTransformersController::renderUi()`).
- Read-only users: build controls with `->mode(ControlMode::ReadOnly)` (`CraftCms\Cms\Ui\Enums\ControlMode`) and omit `submit`. Still enforce authorization on the routes.
- For rows of values (a settings table), use `CraftCms\Cms\Ui\Controls\Table`: its columns are controls. Custom cell types extend `CraftCms\Cms\Field\TableCells\TableCell` and register through `boot(TableCellTypes $types)`.
- For tabs, scopes and custom controls, read `vendor/craftcms/cms/src/Ui/` (`Nodes/`, `Controls/`) and a core controller that builds a similar screen with `->ui()`.

### Vue pages

For custom UI, write a Vue single-file component, register it as an Inertia page, and render it from a controller:

```php
return new CpScreenResponse()
    ->title(t('Stats', category: 'shortlinks'))
    ->inertiaPage('shortlinks/Stats', ['totals' => $totals]);   // props become the component's props
```

```js
// resources/js/cp.js
import Stats from './pages/Stats.vue';

window.Cp.booting((cp) => {
  cp.$inertia.register('shortlinks/Stats', Stats);   // prefix page names with the handle
});
```

```js
// vite.config.js
import {defineConfig} from 'vite';
import vue from '@vitejs/plugin-vue';
import laravel from 'laravel-vite-plugin';

export default defineConfig({
  plugins: [laravel({input: ['resources/js/cp.js'], publicDirectory: 'public', buildDirectory: 'build'}), vue()],
  // Use the CP's own Vue and shared components (an import map provides them):
  build: {rollupOptions: {external: ['vue', '@craftcms/cp']}},
});
```

```php
// Plugin class: load the built entry on every CP page.
protected array $vite = ['resources/js/cp.js'];
```

- `package.json` dev dependencies: `vite`, `@vitejs/plugin-vue`, `laravel-vite-plugin`, `vue` (for compiling only; it's external at runtime). Run `npx vite build`; it writes `public/build/manifest.json` and assets.
- Craft copies `public/build/` to `public/vendor/<package>/build/` in the app (`vendor/orchestra/testbench-core/laravel/public/vendor/…` in the workbench) on plugin install. After rebuilding, run `vendor/bin/testbench vendor:publish --tag=<handle> --force` in the workbench. Commit the built assets (or build them in your release process) so users don't need Node.
- `@craftcms/cp` exports the CP's own components and composables (`AdminTable`, `ElementIndexPage`, `CpButtonLink`, `ActionMenu`, `useAppLayout`, …); read `resources/js/cp-module.ts` in Craft's repo. Global components such as `craft:layout-slot` and `craft:cp-container` are resolved with `resolveComponent()`. Craft's `<craft-…>` web components (`craft-button`, `craft-card`, `craft-badge`) are available in templates.
- Custom `Ui` controls and widget components are registered the same way with `cp.$components.register('<handle>:name', Component)`.

### Twig CP pages (porting only)

`pageTemplate('<handle>/_index')` with a template that extends `_layouts/cp` still works and is the shortest path for porting Craft 5 templates. Templates in `resources/views/` are available as `<handle>/…`. Expect a "bridge screen": legacy markup inside the Vue shell. Prefer rebuilding the page with the `Ui` builder.

## Element action menus

To add items to an element's action menu (entries, assets, users) without subclassing it, listen for `CraftCms\Cms\Element\Events\ElementActionMenuItemsResolving` and append to `$event->items`. Each item is an array with `label`, `icon` and an `action` that Craft runs client-side: an HTTP request, a clipboard copy, a download, or a custom JS event. Read `Element/Concerns/HasControlPanelUI.php` (`getActionMenuItems()`) and an existing element's `safeActionMenuItems()` for the item shapes.

## Front-end endpoints

CSRF applies to every POST on `web.php` routes. A front-end Twig form posts with `{{ csrfInput() }}`; API clients send the `X-XSRF-TOKEN` header. To exempt a webhook path, call `Illuminate\Foundation\Http\Middleware\PreventRequestForgery::except(['shortlinks/webhook'])` in `register()`.

## Verify

See [testing.md](testing.md): drive CP pages in a browser when possible, and use curl for status codes, redirects and JSON. Test a guest, a restricted user and a permitted user against every privileged route: guests must get a 302 to the login page (a 200 means the route is unprotected), restricted users a 403.
