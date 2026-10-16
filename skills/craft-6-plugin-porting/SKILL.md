---
name: craft-6-plugin-porting
description: Walks a developer and their agent through porting a Craft CMS 5 (Yii 2) plugin or module to Craft 6 (Laravel) in stages - assess, make it run on 6.x with the craftcms/yii2-adapter, then migrate each area to native Laravel and remove the adapter. Use when asked to upgrade, port, or make a Craft plugin or module compatible with Craft 6, Laravel, or the Yii 2 adapter.
license: MIT
compatibility: Requires ripgrep (rg) for scripts/scan-craft5.sh. Maintainers refreshing the docs snapshot also need PHP 8.1+ and git.
---

# Porting a Craft 5 plugin or module to Craft 6

Craft 6 is a Laravel package. Craft is a tenant in a Laravel app, and so are plugins. Plugins are Laravel service providers, and "modules" become ordinary service providers in the project's `App` namespace.

This skill walks the developer and the agent through the port **in stages**. Each stage has a goal, steps, exit criteria and a checkpoint. Do the stages in order, finish one before starting the next, and stop at each checkpoint to summarize and confirm with the developer.

Only Stage 1 is required. Stages 2 to 5 eject the Yii 2 adapter and can be done gradually, or never: shipping on the adapter is an officially supported way to release a 6.x-compatible plugin.

Agree an **end state** with the developer in Stage 0, because it decides how far to go:

- **End state A, ship on the adapter:** the adapter stays a dependency of the released plugin. Stage 1 is enough, and later stages are optional clean-up.
- **End state B, adapter-free:** the adapter is required while porting, so the plugin runs on Craft 6 after Stage 1, but it is **not used and not required by the end**. Run all stages. Stage 5 removes it and proves the plugin works without it.

Treat the adapter as scaffolding in end state B. Each stage should reduce what depends on it, and `scripts/scan-craft5.sh` should show fewer hits as the port progresses.

## Ground rules

- Craft 6 was in alpha when this skill was written, so extension APIs may change. The source of truth is the Craft 6.x extend docs (https://craftcms.com/docs/6.x/extend/), the installed `craftcms/cms` 6.x package, and already-ported first-party plugins (for example `craftcms/guest-entries`, `craftcms/demo-plugin`).
- A verbatim snapshot of the 6.x extension docs lives in [references/docs/](references/docs/INDEX.md). Check its stamp (source commit and date) in `INDEX.md`. Maintainers refresh it with `php scripts/sync-docs.php`. Do not run that script during a port, because it rewrites `references/docs/` and uses the network. The hand-written references below are a workflow-oriented summary, so when they and the snapshot disagree, trust the snapshot, and when the snapshot and installed `craftcms/cms` source disagree, trust the source.
- Never guess an API name, namespace or signature. If the references here do not cover it, look it up in the snapshot, the source or the docs. Say plainly when something is unverified.
- The deprecation notes (`@deprecated`, `#[Deprecated]`) on the adapter's legacy classes point to the replacement. Use them.
- Requirements: PHP 8.5, and Craft 5 on its latest 5.x release first. Projects cannot jump from Craft 4 or earlier.
- Make one change set at a time, keep the plugin's tests passing, and commit between stages if the project uses git. Ask before deleting files or restructuring.
- Explain *why* as you go. The developer is learning Craft 6 conventions, not just receiving a diff.

## Stage 0: Assess

**Goal:** know what is being ported and how far to go.

1. Identify the target: a distributable plugin (Composer package of type `craft-plugin`) or a project module.
2. Run `scripts/scan-craft5.sh <path>` (set `VERBOSE=1` for sample matches). It reports hits per area, the plugin's own events, the directory layout and which Craft 6 layout folders are missing. Summarize usage of Yii and Craft 5 APIs per area, using the table in "Reference map" below. Keep this output: it is the baseline to compare against at the end.
3. Agree a strategy and the end state (A or B above) with the developer ([references/strategy.md](references/strategy.md)):
   - Simple plugin (mostly event handling): plan to fully port.
   - Larger plugin: do Stage 1, release an alpha, then migrate gradually.
   - Plugin with its own extension surface (the scan lists its own events): decide whether to ship a compatibility layer. In end state B, that layer must not need Yii or the adapter either.
   - Maybe obsolete (filesystems, mail transports, log back-ends): say so before porting.
4. Confirm the Craft 5 side is clean: latest 5.x, and no outstanding deprecation warnings. The scan cannot check this. Install the plugin in a Craft 5 project, exercise its features, then review Utilities > Deprecation Warnings. If that isn't possible, say so and carry on.

**Exit:** a short written plan listing the areas found, the end state (A or B) and the target stage (1 only, or through 5).
**Checkpoint:** present the plan and get agreement.

## Stage 1: Make it run on Craft 6 (required)

**Goal:** the plugin installs and boots on Craft 6.x with the adapter doing the heavy lifting.
**Reference:** [references/required-changes.md](references/required-changes.md)

1. Require `craftcms/yii2-adapter` and `craftcms/cms:^6.0.0` (and PHP 8.5) in the plugin's `composer.json`.
2. Change the base class to `CraftCms\Cms\Plugin\Plugin`. Rename `init()` to `boot()`. Rename `createSettingsModel()` to `createSettings()`, returning a `PluginSettings` subclass.
3. Fix signature changes on overridden base methods, notably `attributes()` and `attributeLabels()`.
4. Set up the package layout the new base class expects (`src/`, `resources/` icons, `routes/`, `database/migrations/`, `lang/`). Set `extra.class` only if the class is not named `Plugin.php`. Do not add `extra.laravel.providers`.
5. Test in a clean host project: only this plugin installed, with the adapter required by the plugin and not by the project ([references/plugin-class.md](references/plugin-class.md) and "Local development" in [references/other-areas.md](references/other-areas.md)).
6. Tag an alpha major version if the developer wants to publish.

**Exit:** `ddev artisan craft:plugin:install` succeeds, the plugin's main features work, and no new deprecation errors appear in the Deprecation Warnings utility that block usage.
**Checkpoint:** report what changed, what was tested, and the list of deprecation warnings still being raised. These drive the next stages. Ask whether to continue to Stage 2.

## Stage 2: Foundations, native settings, layout and database

**Goal:** the plugin's own skeleton stops depending on the adapter.
**References:** [plugin-class.md](references/plugin-class.md), [models-and-validation.md](references/models-and-validation.md) (settings and config), [database.md](references/database.md)

1. Move initialization out of anything legacy and into `boot()`. Use the declarative plugin properties (`$commands`, `$fieldTypes`, `$widgets`, `$events`, ...) where they exist.
2. Port settings: `PluginSettings`, a config stub in `config/<handle>.php`, and `getRules()` in place of `defineRules()`.
3. Port migrations: bring the `Install` migration up to date, cull old incremental migrations, and convert to Laravel `Schema`/`Blueprint` migrations in `database/migrations/`. Convert `ActiveRecord` classes to Eloquent models.
4. Rename `translations/` to `lang/`, and switch `Craft::t()` to `t()`.

**Exit:** install, uninstall and settings save all work on native code, and migrations run without the adapter's shims.
**Checkpoint:** summarize, then ask whether to continue.

## Stage 3: Logic, services, events and validation

**Goal:** the plugin's internal logic uses the Laravel container and events.
**References:** [services-and-di.md](references/services-and-di.md), [events-and-registries.md](references/events-and-registries.md), [models-and-validation.md](references/models-and-validation.md)

1. Port services to plain classes, mark them `#[Singleton]`, and replace `Craft::$app` locator calls and plugin getters with injection or `app()`.
2. Port event handlers to the new event classes. Look up each replacement from the old constant's docblock. Never convert them with a regex. Register with `$events`, `Event::listen()` in `boot()`, or a subscriber.
3. Replace `RegisterComponentTypesEvent` handlers with registries or plugin properties.
4. Port your own events to event classes, and decide what happens to the old ones.
5. Move validation to Laravel rules (`getRules()`, form requests, rulesets), preferably at the input layer.
6. Replace behaviors with macros.

**Exit:** no use of `Craft::$app`, `Yii::$app` or Yii events remains in the plugin's own logic, and tests pass.
**Checkpoint:** summarize, then ask whether to continue.

## Stage 4: Surfaces, HTTP, console, queue and templates

**Goal:** everything users and other systems touch is native.
**References:** [http-and-auth.md](references/http-and-auth.md), [templates-and-twig.md](references/templates-and-twig.md), [other-areas.md](references/other-areas.md)

1. Controllers: plain classes, routes in `routes/web.php`, `cp.php` and (for legacy action URLs you cannot change) `actions.php`. Move permission checks to `getPermissions()`, `can:` middleware, gates and policies.
2. Console: Artisan commands registered through `$commands`.
3. Queue: jobs extending `CraftCms\Cms\Queue\Job` with `handle()`. Scheduling via `schedule()`.
4. Mail: system messages through `getSystemMessages()`, other mail through `CraftMailable`.
5. Twig: extensions via the `Twig` facade, `craft.*` additions as `CraftVariable` macros, globals via `TemplateGlobalsResolving`. Rendering via `template()`/`pageTemplate()`.
6. Assets: `$scripts`/`$styles`/`$vite` in place of asset bundles.

**Exit:** the plugin's HTTP, CLI, queue, mail and template paths all work and no legacy shims are hit for them.
**Checkpoint:** summarize, then ask whether to continue.

## Stage 5: Components, fields, widgets, then remove the adapter

**Goal:** custom components are native, and the plugin no longer requires the adapter.
**References:** [fields-widgets-forms.md](references/fields-widgets-forms.md), [strategy.md](references/strategy.md)

1. Fields: `settingsForm()` and `formControl()` in place of `getSettingsHtml()`/`getInputHtml()`, `modifyQuery()` in place of `queryCondition()`, and `getRules()`/`getElementRules()`.
2. Widgets and utilities: new base classes and registration. Element types have no porting guide yet, so read the source and tell the developer.
3. Legacy layer: decide what, if anything, to keep for downstream users (`class_alias()`, a `legacy/` autoload root, `Deprecator::log()`), and update `composer.json` autoloading for old and new namespaces.
4. End state B: remove `craftcms/yii2-adapter` from the plugin's `composer.json`. In a clean host project that has neither the adapter nor other plugins, test every feature. Confirm nothing pulls Yii in: `composer why craftcms/yii2-adapter` and `composer why yiisoft/yii2` should both report nothing.
5. Re-run `scripts/scan-craft5.sh` on the plugin's native source. For end state B it should report no hits. Any intentional legacy-compatibility folder (for example `legacy/`) is the only expected exception, and it needs an explanation.
6. Run static analysis and, optionally, Laravel Pint.

**Exit:** for end state B, the plugin works with the adapter absent, with no Yii classes pulled in, and the scan is clean apart from explained exceptions.
**Checkpoint:** final report listing what is native, anything still relying on the adapter or legacy shims, anything unverified, and release notes the developer should write (new major version, PHP 8.5, breaking changes for downstream users).

## Reference map

| The code uses... | Reference |
| --- | --- |
| `Plugin::init()`, `setComponents()`, getters, `createSettingsModel()`, `composer.json`, folder layout | [required-changes.md](references/required-changes.md), [plugin-class.md](references/plugin-class.md) |
| Services, `Craft::$app->...`, `Craft::createObject()` | [services-and-di.md](references/services-and-di.md) |
| `Event::on()`, `EVENT_*`, `RegisterComponentTypesEvent` | [events-and-registries.md](references/events-and-registries.md) |
| Controllers, `actionFoo`, URL rules, permissions, session | [http-and-auth.md](references/http-and-auth.md) |
| Models, records, settings, `defineRules()`, validation, behaviors | [models-and-validation.md](references/models-and-validation.md) |
| Migrations, `craft\db\Migration`, install migration | [database.md](references/database.md) |
| Twig extensions, `craft.myplugin`, globals, rendering | [templates-and-twig.md](references/templates-and-twig.md) |
| Field types, widgets, utilities, settings forms | [fields-widgets-forms.md](references/fields-widgets-forms.md) |
| Console, queue, scheduling, mail, translation, logging, assets, local dev | [other-areas.md](references/other-areas.md) |
| Strategy, obsolete plugins, compat layers | [strategy.md](references/strategy.md) |

## Rules of thumb

- A strict horizontal port first, with restructuring afterwards.
- Initialization belongs in `boot()`, because `register()` runs too early for events.
- Never instantiate services directly. Resolve them from the container.
- Keep old classes loadable where the database, project config or other code may reference them.
- Do not use the adapter's own deprecation API in new code. Use `CraftCms\Cms\Support\Facades\Deprecator::log()`.
- Do not publish the plugin's regular migrations into the app, because they would run twice.
- There are no cross-compatible 5.x and 6.x releases. Tag a new major version for 6.x. A plugin shows as "Craft 6.0-ready" once it requires `craftcms/cms:^6.0.0` and adopts the new base class.

## Edge cases

- **Filesystems, mail transports and log back-ends:** likely obsolete in Craft 6 (Laravel disks, mailers and logging). Tell the developer before porting them mechanically.
- **Control panel JavaScript:** the docs say little yet about the new client-side architecture, so flag heavy CP UI work as unverified.
- **Docs inconsistencies:** a few snippets in the docs conflict (noted in the reference files). Verify against source before relying on them.
- **Developer wants to stop at Stage 1 (end state A):** that is a valid, supported outcome. Make sure the plugin's `composer.json` requires the adapter, and say which deprecations remain.
- **Adapter-free but the plugin keeps a legacy event or class API:** the legacy Yii event system can't be proxied without the adapter. Either keep legacy names as plain aliases (`class_alias()`), or document the break. Don't quietly keep a Yii dependency.
