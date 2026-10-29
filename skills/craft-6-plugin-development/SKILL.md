---
name: craft-6-plugin-development
description: Builds a new Craft CMS 6 (Laravel) plugin from scratch - scaffolding the Composer package and plugin class, then adding settings, routes and controllers, control panel pages, database tables, events, field types, widgets, Twig extensions, jobs and commands, and verifying each in a Craft 6 workbench inside the plugin repository. Use when asked to create, scaffold or extend a Craft 6 plugin. For upgrading an existing Craft 5 plugin, use craft-6-plugin-upgrade instead.
license: MIT
compatibility: Craft CMS 6 (beta or later; written against the 6.x branch, October 2026), PHP 8.5, Composer 2. The workbench (Orchestra Testbench) needs PHP with pdo_sqlite and runs without DDEV or Docker.
---

# Building a Craft CMS 6 plugin

Craft 6 is a Laravel 13 package. A plugin is a Composer package of type `craft-plugin` whose main class extends `CraftCms\Cms\Plugin\Plugin`, which is a Laravel service provider. Craft boots it only while it is installed and enabled. Everything Laravel offers (routes, Eloquent, events, jobs, commands, validation, policies) is available, and Craft adds declarative registration through properties on the plugin class.

Build in small increments. Get an empty plugin installing in its workbench first, then add one feature at a time and prove each works before starting the next.

## Ground rules

- For anything plain Laravel (controllers, form requests, validation, Eloquent, middleware, jobs, commands, mail, logging), follow Laravel's own conventions and docs. The references here only cover what Craft adds or changes.

- Craft 6's plugin APIs are stable: what this skill and the published docs describe won't be renamed under you. The workbench installs `craftcms/cms:6.x-dev` so you get the latest fixes. The source of truth, in order: the installed `vendor/craftcms/cms` source, then the published docs at https://craftcms.com/docs/6.x/ (the extension guides are under [`extend/`](https://craftcms.com/docs/6.x/extend/)). If a Craft documentation MCP server is connected, search it rather than guessing URLs; otherwise fetch the pages directly. A few published pages still use older names (for example they call the UI builder `Form`; see [references/gotchas.md](references/gotchas.md)). When the docs or a reference here disagree with the installed source, trust the source and say so.
- If something looks like a bug in Craft itself, don't work around it in the plugin. First update Craft (`composer update craftcms/cms -W`, then `vendor/bin/testbench craft:up --no-interaction`) and check the 6.x branch's recent commits, since it may already be fixed. If it persists, reproduce it minimally and report it (file, line, steps, installed commit from `composer show craftcms/cms`) to the developer.
- **Never guess a class name, namespace or signature.** Before using a Craft API, find it: `rg -n "class Foo\b" vendor/craftcms/cms/src`, or read the base class or interface you extend. The Craft 5 (Yii) API names you may remember (`craft\base\...`, `Craft::$app`, `EVENT_*` constants, `defineRules()`, `getSettingsHtml()`, `actionFoo()`) are wrong in a native plugin.
- Do not require `craftcms/yii2-adapter` in a new plugin. Nothing here needs it.
- Use a PSR-4 namespace under the developer's own vendor (`Acme\Redirects`); `CraftCms\` is for first-party packages.
- Prefer injection over `Plugin::getInstance()` in services and controllers; `getInstance()` is fine in route files, config stubs and Twig glue.
- Build control panel screens with Craft's `Ui` builder (`CpScreenResponse->ui()`), or with Vue pages registered on the CP's Inertia app for custom UI. Twig CP templates only render as legacy "bridge screens"; don't use them for new plugins ([http-and-cp.md](references/http-and-cp.md#control-panel-pages)).
- Every user-facing string goes through `t('…', category: '<plugin-handle>')` (the namespaced function `CraftCms\Cms\t`, imported with `use function CraftCms\Cms\t;`).

## Workflow

### 1. Agree the scope

Write a short plan: the plugin handle (kebab-case, also the translation category and the default URL prefix), package name, namespace, and the list of features in build order. Order features so each one builds on proven ground: plugin installs → settings → data and migrations → services and events → routes and control panel pages → components (fields, widgets, utilities) → Twig and front-end output → jobs, commands, scheduling → tests.

### 2. Scaffold the plugin

Create the minimum package from [references/scaffold.md](references/scaffold.md): `composer.json`, `src/Plugin.php`, `resources/icon.svg`, and a `README.md` and `CHANGELOG.md`.

### 3. Add the workbench

The plugin repository carries its own disposable Craft install: an Orchestra Testbench workbench, like craftcms/cms. Testbench generates it (`vendor/bin/testbench workbench:install --devtool`); you add a short `testbench.yaml`, a seeder that installs Craft and the plugin, and Pest. Follow [testing.md](references/testing.md#workbench-setup) step by step. Then:

```bash
composer build                              # installs Craft (SQLite, admin / password123) and the plugin
vendor/bin/testbench craft:plugin:list      # the plugin must show as installed and enabled
composer serve                              # http://127.0.0.1:8000/admin
composer test                               # Pest, against a fresh in-memory install per test
```

Do not add features until this works. Commit the workbench with the plugin. With DDEV or an existing Craft project you can also install the plugin there ([scaffold.md](references/scaffold.md#install-into-the-workbench)), but set up the workbench anyway.

### 4. Add features, one at a time

Use the reference for each area:

| Feature | Reference |
| --- | --- |
| Package layout, `composer.json`, plugin class, plugin properties, editions | [scaffold.md](references/scaffold.md) |
| Settings, settings page (UI builder), config file, env vars | [settings.md](references/settings.md) |
| Routes, controllers, form requests, flash, permissions, CP section, CP pages (`Ui` builder, Vue/Inertia) | [http-and-cp.md](references/http-and-cp.md) |
| Migrations, Eloquent models, data objects, services, caching | [data-and-services.md](references/data-and-services.md) |
| Listening to Craft events, dispatching your own, registries | [events.md](references/events.md) |
| Field types, widgets, utilities, element types | [components.md](references/components.md) |
| Templates, Twig extensions, `craft.*` variables, globals, front-end output, assets | [templates.md](references/templates.md) |
| Jobs, commands, scheduling, mail, logging | [background.md](references/background.md) |
| The workbench, verifying, fixtures, automated tests | [testing.md](references/testing.md) |
| Known traps | [gotchas.md](references/gotchas.md) |

For each feature:

1. Look up the extension point in the reference, then confirm it in `vendor/craftcms/cms/src`.
2. Implement it.
3. Verify it in the workbench the way a user would reach it (an HTTP request, a CP page, a CLI command, a template render), not only by reading the code. `/_workbench/login/<userId>` logs curl or a browser in to the control panel without a password; [testing.md](references/testing.md) has recipes for CSRF tokens, settings saves, fixtures and rendering templates.
4. Run `php -l` on changed files and `vendor/bin/testbench route:list --path=<handle>` after route changes. Add a Pest test for behavior worth keeping.

### Specialised extension points

For these, start from the base class or registry, read a built-in implementation next to it in `vendor/craftcms/cms/src`, and check the published docs for a guide:

| Plugin adds… | Start from | Register with |
| --- | --- | --- |
| An AI task (administrators map it to a provider and model) | `CraftCms\Cms\Ai\Task` (runs `laravel/ai` agents) | `boot(AiTasks $tasks)` → `$tasks->register(...)` |
| MCP tools or resources | A class with attributed methods | `boot(CapabilityRegistry $capabilities)` → `register(...)` (`CraftCms\Cms\Mcp`) |
| An approval workflow stage | `CraftCms\Cms\Workflow\Stages\WorkflowStage` | `boot(WorkflowStageTypes $types)` → `register(...)` |
| An asset transform driver (image CDN) | `CraftCms\Cms\Asset\Contracts\AssetTransformDriver` | `boot(AssetTransformDrivers $drivers)` → `extend('<handle>', fn ($app) => …)` |
| An upload transport | `CraftCms\Cms\Filesystem\Contracts\Uploader` | `boot(Uploaders $uploaders)` → `extend(...)`, plus a JS transport via `Craft.Uploads.registerTransport()` |
| A Markdown flavor | `CraftCms\Cms\Markdown\Flavors\Flavor` | `Markdown::extend(...)` (`CraftCms\Cms\Support\Facades\Markdown`) |
| An element type backed by an Eloquent model | `CraftCms\Cms\Element\Eloquent\EloquentElement` | `$elementTypes` ([components.md](references/components.md#element-types)) |

### 5. Finish

- Uninstall and reinstall the plugin: `craft:plugin:uninstall <handle>` must drop every table it created, and `craft:plugin:install` must recreate them.
- Make sure `composer test` passes, with tests for the plugin's main behaviors and their failure paths ([testing.md](references/testing.md#automated-tests)).
- Seed demo content in `workbench/database/seeders/DatabaseSeeder.php` so a fresh clone gets a working demo from `composer build`.
- Run Laravel Pint if the developer uses it.
- Write the README: requirements, install, configuration, the public API (Twig, events, routes, config keys).

Report what was built, how each feature was verified, and anything unverified.

## Rules of thumb

- `boot()` is for initialization and supports method injection: `public function boot(Sections $sections): void`. Avoid `register()` unless you need early Laravel wiring (container bindings, CSRF exemptions, rate limiters).
- Prefer the declarative plugin properties (`$events`, `$commands`, `$fieldTypes`, `$widgets`, `$utilities`, `$elementTypes`, `getPermissions()`, `schedule()`) over manual registration. They are `protected` in the base traits: redeclare them as `protected`.
- Your plugin's `database/migrations/Install.php` runs on install (`up()`) and uninstall (`down()`). Other files in `database/migrations/` are updates, run by `craft:up` or `migrate` after the plugin's `schemaVersion` changes.
- Plugin settings live in project config. Put large or frequently-changing data in your own tables, not settings.
- A route in `routes/web.php` or `routes/actions.php` is public unless you add middleware. Add `auth` and `can:` for anything privileged.
- When something fails, read `workbench/storage/logs/laravel.log` before changing code.
- Run Artisan commands as `vendor/bin/testbench <command>` from the plugin root; a plugin has no `artisan`.
