---
name: craft-6-plugin-upgrade
description: Walks a developer and their agent through upgrading a Craft CMS 5 (Yii 2) plugin or module to Craft 6 (Laravel) in stages - assess, make it run on 6.x with the craftcms/yii2-adapter, then migrate each area to native Laravel and remove the adapter. Use when asked to upgrade or make a Craft plugin or module compatible with Craft 6, Laravel, or the Yii 2 adapter.
license: MIT
compatibility: Requires ripgrep (rg) for scripts/scan-craft5.sh. Maintainers refreshing the docs snapshot also need PHP 8.1+ and git.
---

# Upgrading a Craft 5 plugin or module to Craft 6

Craft 6 is a Laravel package. Craft is a tenant in a Laravel app, and so are plugins. Plugins are Laravel service providers, and "modules" become ordinary service providers in the project's `App` namespace.

This skill walks the developer and the agent through the upgrade **in stages**. Each stage has a goal, steps, exit criteria and a checkpoint. Do the stages in order, finish one before starting the next, and stop at each checkpoint to summarize and confirm with the developer.

Only Stage 1 is required. Stages 2 to 5 eject the Yii 2 adapter and can be done gradually, or never: shipping on the adapter is an officially supported way to release a 6.x-compatible plugin.

Agree an **end state** with the developer in Stage 0, because it decides how far to go:

- **End state A, ship on the adapter:** the adapter stays a dependency of the released plugin. Stage 1 is enough, and later stages are optional clean-up.
- **End state B, adapter-free:** the adapter is required while upgrading, so the plugin runs on Craft 6 after Stage 1, but it is **not used and not required by the end**. Run all stages. Stage 5 removes it and proves the plugin works without it.

Treat the adapter as scaffolding in end state B. It stays installed so the plugin keeps running, but don't build anything new on it. Each stage should reduce what depends on it, and `scripts/scan-craft5.sh` should show fewer hits as the upgrade progresses.

**Prompt the developer to remove it at the end.** In end state B, close every checkpoint with a one-line reminder that the adapter is still installed and will be removed in Stage 5. When Stage 5 is reached, ask the developer to confirm before editing `composer.json`, and offer to run the removal checks. If the developer stops early, say plainly that the adapter is still required and what still depends on it.

## Ground rules

- Craft 6 was in alpha when this skill was written, so extension APIs may change. The source of truth is the Craft 6.x extend docs (https://craftcms.com/docs/6.x/extend/), the installed `craftcms/cms` 6.x package, and already-upgraded first-party plugins (for example `craftcms/guest-entries`, `craftcms/demo-plugin`).
- A verbatim snapshot of the 6.x extension docs lives in [references/docs/](references/docs/INDEX.md). Check its stamp (source commit and date) in `INDEX.md`. Maintainers refresh it with `php scripts/sync-docs.php`. Do not run that script during an upgrade, because it rewrites `references/docs/` and uses the network. The hand-written references below are a workflow-oriented summary, so when they and the snapshot disagree, trust the snapshot, and when the snapshot and installed `craftcms/cms` source disagree, trust the source.
- Never guess an API name, namespace or signature. If the references here do not cover it, look it up in the snapshot, the source or the docs. Say plainly when something is unverified.
- The deprecation notes (`@deprecated`, `#[Deprecated]`) on the adapter's legacy classes point to the replacement. Use them.
- Requirements: PHP 8.5, and Craft 5 on its latest 5.x release first. Projects cannot jump from Craft 4 or earlier.
- Make one change set at a time, keep the plugin's tests passing, and commit between stages if the project uses git. Ask before deleting files or restructuring.
- **Keep an `UPGRADE.md` for the plugin's users.** Whenever the upgrade removes, renames or changes something other code may depend on (events, classes and namespaces, settings and config, routes and action URLs, Twig variables, permissions, requirements), add an entry with before and after code as you make the change. Start it from [assets/UPGRADE.template.md](assets/UPGRADE.template.md) at the first such change, and finish it in Stage 5. Only record changes that really happened, and check every new name against the installed source.
- Explain *why* as you go. The developer is learning Craft 6 conventions, not just receiving a diff.

## Stage 0: Assess

**Goal:** know what is being upgraded and how far to go.

1. Identify the target: a distributable plugin (Composer package of type `craft-plugin`) or a project module.
2. Run `scripts/scan-craft5.sh <path>` (set `VERBOSE=1` for sample matches). It reports hits per area, the plugin's own events, the directory layout and which Craft 6 layout folders are missing. Summarize usage of Yii and Craft 5 APIs per area, using the table in "Reference map" below. Keep this output: it is the baseline to compare against at the end.
3. Agree a strategy and the end state (A or B above) with the developer ([references/strategy.md](references/strategy.md)):
   - Simple plugin (mostly event handling): plan to fully upgrade.
   - Larger plugin: do Stage 1, release an alpha, then migrate gradually. A very large plugin is better upgraded bottom-up in clusters, with the old code kept under `src-yii2/` behind `class_alias` stubs ([strategy.md](references/strategy.md)).
   - Plugin with its own extension surface (the scan lists its own events): decide between a compatibility layer and a clean break. A clean break moves to Laravel events, removes the old Yii-style `EVENT_*` constants and documents what users must change in `UPGRADE.md` (see "Ground rules"). In end state B, any compatibility layer must not need Yii or the adapter either. A third option is a bridge that also triggers the old Yii events, which needs the adapter (end state A for that API).
   - Maybe obsolete (filesystems, mail transports, log back-ends): say so before upgrading.
   - Scope: ask whether any feature will be removed rather than upgraded. If the legacy tree ships, the adapter must be in `require`, not `require-dev`.
4. **Ask the developer about the namespace, and get an explicit answer.** Craft 5 plugins usually use a Yii-style lowercase namespace (`craft\myplugin`). Laravel and Craft 6 convention is a PascalCase PSR-4 vendor namespace under the developer's own vendor name (for example `MyOrg\MyPlugin`; the `CraftCms` namespace is for Craft's first-party packages, and isn't needed). Explain the trade-off and let them choose:
   - **Move to the conventional namespace:** a breaking change for anyone referencing the old class names (record it in `UPGRADE.md`), but it makes the upgrade easy to track. New or upgraded classes live in the new namespace and anything still in the old one is not upgraded yet, so the scan, `git grep` and `composer.json` autoload entries show progress at a glance.
   - **Keep the old namespace:** fewer breaking changes, but upgraded and not-yet-upgraded code look the same.
   The default recommendation is the conventional namespace **plus moving most classes into Laravel-style folders** (`Http/Controllers`, `Http/Requests`, `Events`, `Listeners`, `Data`, `Models`, `Jobs`, ...: [plugin-class.md](references/plugin-class.md#class-organization-the-default-move-most-things-into-laravel-style-namespaces)). Record the decision in the plan. Don't change a namespace without the developer's agreement.
5. Confirm the Craft 5 side is clean: latest 5.x, and no outstanding deprecation warnings. The scan cannot check this. Install the plugin in a Craft 5 project, exercise its features, then review Utilities > Deprecation Warnings. If that isn't possible, say so and carry on.

**Exit:** a short written plan listing the areas found, the end state (A or B), the namespace decision and the target stage (1 only, or through 5).
**Checkpoint:** present the plan and get agreement.

## Stage 1: Make it run on Craft 6 with the adapter (required)

**Goal:** the plugin installs on Craft 6.x and its features work, with the adapter doing the heavy lifting. This stage is adapter-only: **keep the legacy base class (`craft\base\Plugin`)**. The switch to the native base class happens in Stage 2, because it stops the adapter routing the plugin's Yii controllers, so the controllers must be upgraded at the same time.
**References:** [references/required-changes.md](references/required-changes.md), [references/testing.md](references/testing.md)

1. In the plugin's `composer.json`, require `craftcms/yii2-adapter`, `craftcms/cms:^6.0.0` and PHP `^8.5`. Remove or raise `config.platform.php` if it is lower than 8.5, because it stops Composer resolving the adapter.
2. Fix signature changes on overridden methods that the legacy classes still provide, notably `attributes()` and `attributeLabels()` (add the `: array` return type).
3. Install the plugin in a clean host project through a path repository, with only this plugin installed and the adapter required by the plugin, not the project ([references/testing.md](references/testing.md)).
4. Test the plugin's main features: its action URLs (with a CSRF token), its control panel settings page, and any front-end form. Note what works.
5. Tag an alpha major version if the developer wants to publish. This stops here for end state A.

**Exit:** `craft:plugin:install` succeeds, the action URLs respond correctly, the settings page renders and saves.
**Checkpoint:** report what changed, what was tested, and the list of deprecation warnings still being raised. These drive the next stages. In end state B, remind the developer that the adapter is still installed and will be removed in Stage 5. Ask whether to continue to Stage 2.

## Stage 2: Switch to the native plugin class, and upgrade what that breaks

**Goal:** the plugin extends `CraftCms\Cms\Plugin\Plugin` and its features still work. Everything the legacy Yii plugin class gave you for free has to be provided natively at the same time. Do these together, and test after each one:
**References:** [plugin-class.md](references/plugin-class.md), [http-and-auth.md](references/http-and-auth.md), [models-and-validation.md](references/models-and-validation.md), [fields-widgets-forms.md](references/fields-widgets-forms.md), [database.md](references/database.md)

1. Change the base class to `CraftCms\Cms\Plugin\Plugin`. Move `init()` logic into `boot()` (which supports dependency injection). Replace `createSettingsModel()` with `protected static function createSettings(): ?PluginSettings` (it is **static**).
2. Settings: make the settings class extend `PluginSettings`, use `getRules()` instead of `defineRules()`, and give config values real public properties (a property hook can normalize assignments). The CP settings page uses `settingsForm()` (the form builder), replacing the Twig `settingsHtml()` template. Add a config stub only if the plugin wants one.
3. Controllers: Yii controllers are no longer routed. Upgrade each to a plain (usually invokable) class using `RespondsWithFlash`, and route it from `routes/actions.php` so existing `actions/<handle>/<action>` URLs keep working (`routes/web.php` and `cp.php` for new routes). Put `auth` first on every non-anonymous route, because `routes/actions.php` is also reachable by guests. Replace `Craft::$app` calls and Yii request and response helpers as you touch each class ([services-and-di.md](references/services-and-di.md), [http-and-auth.md](references/http-and-auth.md)). If the controller had `$enableCsrfValidation = false` or a setting for it, exempt the route in `boot()` with `PreventRequestForgery::except()`.
4. Layout: icon to `resources/`, routes to `routes/`, translations to `lang/`, templates to `resources/views/` (or `resources/templates/`). Cull old incremental migrations and convert the rest to `database/migrations/` (see [database.md](references/database.md)).
5. If the developer chose a new namespace in Stage 0, add it to `composer.json` `autoload.psr-4` next to the old one and move **most classes** into the Laravel-style layout as you upgrade each one (controllers in `Http/Controllers`, request validation in `Http/Requests`, events in `Events`, handlers in `Listeners`, data objects in `Data`, Eloquent models in `Models`, jobs in `Jobs`, commands in `Console/Commands`, settings next to the plugin class). Leave nothing behind in Yii-style folders. Use `git mv` so history follows. Remove the old autoload root when nothing uses it, update `extra.class` if the plugin class moved, and record every renamed class in `UPGRADE.md`.

**Exit:** with the adapter still installed, install, uninstall, reinstall, settings save, every action URL and any front-end form all work on the native class.
**Checkpoint:** summarize. In end state B, remind the developer that the adapter is still installed and will be removed in Stage 5. Ask whether to continue.

## Stage 3: Logic, services, events and validation

**Goal:** the plugin's internal logic uses the Laravel container and events. Much of this happens inside the classes you upgraded in Stage 2. This stage finishes anything left, and is where the plugin's own events change.
**References:** [services-and-di.md](references/services-and-di.md), [events-and-registries.md](references/events-and-registries.md), [models-and-validation.md](references/models-and-validation.md)

1. Upgrade services to plain classes, mark them `#[Singleton]` (or `#[Scoped]` if they hold per-request state), and replace `Craft::$app` locator calls and plugin getters with injection or `app()`.
2. Upgrade event handlers to the new event classes. Look up each replacement from the old constant's docblock. Never convert them with a regex. Register with `$events`, `Event::listen()` in `boot()`, or a subscriber.
3. Replace `RegisterComponentTypesEvent` handlers with registries or plugin properties.
4. Upgrade your own events to Laravel event classes. Unless the developer chose a compatibility layer, remove the old Yii-style `EVENT_*` constants and event base classes, and add a before and after entry for each to `UPGRADE.md`.
5. Move validation to Laravel rules (`getRules()`, form requests, rulesets), preferably at the input layer (a `FormRequest` for submitted params).
6. Replace behaviors with macros.
7. Test the events: register throwaway listeners in the host, exercise each path (success, veto, spam, failure) and check each fires ([references/testing.md](references/testing.md)).

**Exit:** no use of `Craft::$app`, `Yii::$app` or Yii events remains in the plugin's own logic, the events behave as documented in `UPGRADE.md`, and tests pass.
**Checkpoint:** summarize. In end state B, remind the developer that the adapter is still installed and will be removed in Stage 5. Ask whether to continue.

## Stage 4: Remaining surfaces: templates, console, queue and mail

**Goal:** everything else users and other systems touch is native.
**References:** [templates-and-twig.md](references/templates-and-twig.md), [other-areas.md](references/other-areas.md), [http-and-auth.md](references/http-and-auth.md)

1. Front-end templates and forms: check the plugin's README examples against the real behavior (see [templates-and-twig.md](references/templates-and-twig.md), "Front-end forms"). Failed submissions redirect back with flashed data, so `entry`-style variables are replaced by `old()`, `errors` and `session()`. Update the README and `UPGRADE.md`.
2. Permissions: `getPermissions()`, `can:` middleware, gates and policies.
3. Console: Artisan commands registered through `$commands`.
4. Queue: jobs extending `CraftCms\Cms\Queue\Job` with `handle()`. Scheduling via `schedule()`.
5. Mail: system messages through `getSystemMessages()`, other mail through `CraftMailable`.
6. Twig: extensions via the `Twig` facade, `craft.*` additions as `CraftVariable` macros, globals via `TemplateGlobalsResolving`. Craft's facades (for example `Sections`) are available in Twig.
7. Assets: `$scripts`/`$styles`/`$vite` in place of asset bundles.

**Exit:** the plugin's templates, CLI, queue and mail paths all work, and the README and `UPGRADE.md` describe the behavior that was actually tested.
**Checkpoint:** summarize. In end state B, remind the developer that the adapter is still installed and will be removed in Stage 5. Ask whether to continue.

## Stage 5: Components, fields, widgets, then remove the adapter

**Goal:** custom components are native, and the plugin no longer requires the adapter.
**References:** [fields-widgets-forms.md](references/fields-widgets-forms.md), [strategy.md](references/strategy.md)

1. Fields: `settingsForm()` and `formControl()` in place of `getSettingsHtml()`/`getInputHtml()`, `modifyQuery()` in place of `queryCondition()`, and `getRules()`/`getElementRules()`.
2. Widgets and utilities: new base classes and registration. Element types have no upgrade guide yet, so read the source and tell the developer.
3. Legacy layer: decide what, if anything, to keep for downstream users (`class_alias()`, a `legacy/` autoload root, `Deprecator::log()`), and update `composer.json` autoloading for old and new namespaces. If the developer chose a clean break instead, finish `UPGRADE.md` now: every removed or renamed event, class, setting, route and variable should have a before and after entry, and the requirements and upgrade steps sections should be filled in.
4. End state B: ask the developer to confirm, then remove `craftcms/yii2-adapter` from the plugin's `composer.json`. In a clean host project that has neither the adapter nor other plugins, test every feature. Confirm nothing pulls Yii in: `composer show craftcms/yii2-adapter` and `composer show yiisoft/yii2` should both report that the package is not installed. (Small `yiisoft/*` utility libraries such as `yiisoft/arrays` are dependencies of Craft 6 itself and are expected.)
5. Re-run `scripts/scan-craft5.sh` on the plugin's native source. If the plugin has a test suite, add an architecture test that fails when `src/` uses legacy `craft\` classes ([references/testing.md](references/testing.md)). For end state B it should report no hits. Any intentional legacy-compatibility folder (for example `legacy/`) is the only expected exception, and it needs an explanation.
6. Run static analysis and, optionally, Laravel Pint.

**Exit:** for end state B, the plugin works with the adapter absent, with no Yii classes pulled in, and the scan is clean apart from explained exceptions.
**Checkpoint:** final report listing what is native, anything still relying on the adapter or legacy shims, anything unverified, the finished `UPGRADE.md`, and release notes the developer should write (new major version, PHP 8.5, breaking changes for downstream users).

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
| Custom element types | [element-types.md](references/element-types.md) |
| Console, queue, scheduling, mail, translation, logging, assets, local dev | [other-areas.md](references/other-areas.md) |
| Strategy, large-plugin staging, obsolete plugins, compat layers, event bridges | [strategy.md](references/strategy.md) |
| Setting up a host project and testing an upgrade | [testing.md](references/testing.md) |

## Rules of thumb

- A strict horizontal upgrade first, with restructuring afterwards.
- Initialization belongs in `boot()`: `register()` runs before other providers exist, so it is only for early Laravel wiring (CSRF exemptions, rate limiters, Laravel event listeners).
- Never instantiate services directly, and don't use static lookups such as `Plugin::getInstance()` or `Craft::$app` in upgraded code. Inject what you need (`Settings $settings`, `Sections $sections`) or resolve it with `app(ClassName::class)`. Bind the plugin's settings class in `boot()` so classes can type-hint it ([services-and-di.md](references/services-and-di.md)).
- Keep old classes loadable where the database, project config or other code may reference them.
- Do not use the adapter's own deprecation API in new code. Use `CraftCms\Cms\Support\Facades\Deprecator::log()`.
- Do not publish the plugin's regular migrations into the app, because they would run twice.
- There are no cross-compatible 5.x and 6.x releases. Tag a new major version for 6.x. A plugin shows as "Craft 6.0-ready" once it requires `craftcms/cms:^6.0.0` and adopts the new base class.

## Edge cases

- **Filesystems, mail transports and log back-ends:** likely obsolete in Craft 6 (Laravel disks, mailers and logging). Tell the developer before upgrading them mechanically.
- **Control panel JavaScript:** the docs say little yet about the new client-side architecture, so flag heavy CP UI work as unverified.
- **Element types with no native class:** in 6.0.0-alpha.20, `Category`, `Tag`, `GlobalSet` (and Matrix blocks) exist only as legacy classes inside `craftcms/yii2-adapter`. Native classes exist for `Entry`, `Asset`, `User` and `Address`. A plugin that queries the others can't go adapter-free yet: say so, and document it.
- **Plugin APIs defined by a config file:** when users write closures and class names in a config file, that file is the public API. List every Craft 5 class and call they use, with the Craft 6 replacement, in `UPGRADE.md` (it is where most of the breaking changes live), and warn that `config:cache` can't serialize closures.
- **Audit cache TTLs and cookies:** a Laravel cache `null` TTL means forever, and JSON routes in `routes/web.php` get session cookies. See [services-and-di.md](references/services-and-di.md) and [http-and-auth.md](references/http-and-auth.md).
- **Docs inconsistencies:** a few snippets in the docs conflict (noted in the reference files). Verify against source before relying on them.
- **Developer wants to stop at Stage 1 (end state A):** that is a valid, supported outcome. Make sure the plugin's `composer.json` requires the adapter, and say which deprecations remain.
- **Adapter-free but the plugin keeps a legacy event or class API:** the legacy Yii event system can't be proxied without the adapter. Either keep legacy names as plain aliases (`class_alias()`), or document the break. Don't quietly keep a Yii dependency.
