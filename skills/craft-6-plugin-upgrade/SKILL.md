---
name: craft-6-plugin-upgrade
description: "Walks a developer and their agent through upgrading a Craft CMS 5 (Yii 2) plugin or module to Craft 6 (Laravel) in stages: assess, choose an adapter-based compatibility release or a direct native port, and migrate the required areas to Laravel. Use when asked to upgrade or make a Craft plugin or module compatible with Craft 6, Laravel, or the Yii 2 adapter."
license: MIT
compatibility: Requires ripgrep (rg) for scripts/scan-craft5.sh. Maintainers refreshing the docs snapshot also need PHP 8.1+ and git.
---

# Upgrading a Craft 5 plugin or module to Craft 6

Craft 6 is a Laravel package. Craft is a tenant in a Laravel app, and so are plugins. Plugins are Laravel service providers, and "modules" become ordinary service providers in the project's `App` namespace.

This skill walks the developer and the agent through the upgrade **in stages**. Each stage has a goal, steps, exit criteria and a checkpoint. Use the stages for the selected strategy, and summarize progress at checkpoints. Reuse decisions and authorization already given by the developer. Pause when a decision or action needs approval, rather than asking again at every stage.

Stage 1 is for the adapter-based route. Stages 2 to 5 cover a native port and can follow Stage 1 or start directly without installing the adapter. Shipping on the adapter is also an officially supported way to release a 6.x-compatible plugin.

Agree an **end state** with the developer in Stage 0, because it decides how far to go:

- **End state A, ship on the adapter:** the adapter stays a dependency of the released plugin. Stage 1 is enough, and later stages are optional clean-up.
- **End state B, adapter-free:** port directly through Stages 2 to 5, or use the adapter temporarily through Stage 1 if the developer chooses that approach. The finished plugin must work without the adapter. Do not install it when the developer has requested a direct native port.

If end state B uses the adapter temporarily, treat it as scaffolding and do not build new code on it. Each stage should reduce the legacy dependencies. Review the scan findings as the upgrade progresses, accounting for intentional aliases and native APIs that share names with legacy ones.

**Track the adapter accurately.** If it is installed temporarily, report the remaining dependencies and remove it once they are gone, within the agreed scope. Do not request another confirmation when the developer has already authorized its removal. If work stops early, say whether the adapter is still required and what depends on it.

## Ground rules

- Craft 6 was in alpha when this skill was written, so extension APIs may change. The source of truth is the Craft 6.x extend docs (https://craftcms.com/docs/6.x/extend/) and the installed `craftcms/cms` 6.x package.
- Verify the installed Craft version and source before choosing a target. Tagged releases can include the required APIs. Use `6.x-dev` only when the upgrade needs an unreleased fix and the developer agrees to that dependency change ([references/testing.md](references/testing.md)).
- When the adapter or Craft itself is at fault, tell the developer what you found and the evidence, so they can report it to Craft (https://github.com/craftcms/cms/issues). If the fix is small and only touches the adapter (the `yii2-adapter/` folder of `craftcms/cms`), suggest they open a pull request for it, and offer to draft it. Work around it in the plugin only where needed, gate the workaround on the Craft version, and note when to remove it.
- A verbatim snapshot of the 6.x extension docs lives in [references/docs/](references/docs/INDEX.md). Check its stamp (source commit and date) in `INDEX.md`. Maintainers refresh it with `php scripts/sync-docs.php`. Do not run that script during an upgrade, because it rewrites `references/docs/` and uses the network. The hand-written references below are a workflow-oriented summary, so when they and the snapshot disagree, trust the snapshot, and when the snapshot and installed `craftcms/cms` source disagree, trust the source.
- Never guess an API name, namespace or signature. If the references here do not cover it, look it up in the snapshot, the source or the docs. Say plainly when something is unverified.
- The deprecation notes (`@deprecated`, `#[Deprecated]`) on the adapter's legacy classes point to the replacement. Use them.
- Requirements: PHP 8.5, and Craft 5 on its latest 5.x release first. Projects cannot jump from Craft 4 or earlier.
- Make one change set at a time and validate within the requested scope. Follow the developer's instructions for tests, commits, deletions, and restructuring. Do not expand an authorized port into an unrelated refactor.
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
   - Maybe obsolete (filesystems, mail transports, log back-ends): say so before upgrading. Check Craft 6 actually covers the feature before calling it obsolete ([strategy.md](references/strategy.md#is-the-plugin-still-needed)).
   - Plugin with custom element types or element queries: a constraint bump is not enough for the adapter route, because `beforePrepare()` is never called on Craft 6 ([required-changes.md](references/required-changes.md#what-breaks-on-the-adapter)). Plan the query rewrite in Stage 1, or go native.
   - Plugin that calls core internals the adapter doesn't provide (`craft\migrations\Install`, `craft\helpers\MigrationHelper`, the DB command map): the adapter can't make it work. Disable the feature on Craft 6 in the adapter release and rebuild it natively.
   - Scope: ask whether any feature will be removed rather than upgraded. If the legacy tree ships, the adapter must be in `require`, not `require-dev`.
4. **Establish the namespace decision, reusing an explicit choice already provided.** Craft 5 plugins usually use a Yii-style lowercase namespace (`craft\myplugin`). Laravel and Craft 6 convention is a PascalCase PSR-4 vendor namespace under the developer's own vendor name (for example `MyOrg\MyPlugin`; the `CraftCms` namespace is for Craft's first-party packages, and isn't needed). Explain the trade-off and let them choose:
   - **Move to the conventional namespace:** a breaking change for anyone referencing the old class names (record it in `UPGRADE.md`), but it makes the upgrade easy to track. New or upgraded classes live in the new namespace and anything still in the old one is not upgraded yet, so the scan, `git grep` and `composer.json` autoload entries show progress at a glance.
   - **Keep the old namespace:** fewer breaking changes, but upgraded and not-yet-upgraded code look the same.
   The default recommendation is the conventional namespace **plus moving most classes into Laravel-style folders** (`Http/Controllers`, `Http/Requests`, `Events`, `Listeners`, `Data`, `Models`, `Jobs`, ...: [plugin-class.md](references/plugin-class.md#class-organization-the-default-move-most-things-into-laravel-style-namespaces)). Record the decision in the plan. Don't change a namespace without the developer's agreement.
5. Confirm the Craft 5 side is clean: latest 5.x, and no outstanding deprecation warnings. The scan cannot check this. Install the plugin in a Craft 5 project, exercise its features, then review Utilities > Deprecation Warnings. If that isn't possible, say so and carry on.

**Exit:** a short written plan listing the areas found, the end state (A or B), the namespace decision and the target stages (1 only, 2 to 5, or 1 to 5).
**Checkpoint:** present the plan and resolve any strategy or scope decisions the developer has not already made.

## Stage 1: Make it run on Craft 6 with the adapter (adapter route only)

**Goal:** the plugin installs on Craft 6.x and its features work, with the adapter doing the heavy lifting. This stage is adapter-only: **keep the legacy base class (`craft\base\Plugin`)**. The switch to the native base class happens in Stage 2, because it stops the adapter routing the plugin's Yii controllers, so the controllers must be upgraded at the same time.
**References:** [references/required-changes.md](references/required-changes.md), [references/testing.md](references/testing.md)

1. Choose the `composer.json` shape with the developer ([required-changes.md](references/required-changes.md#composer-two-ways-to-ship-the-adapter-release)):
   - **Cross-compatible release on the current major (the default):** add `|^6.0.0-alpha.1` to the existing `craftcms/cms` constraint and `"suggest": {"craftcms/yii2-adapter": "Required to use <Plugin> with Craft CMS 6."}`. Composer can't require a package for Craft 6 only, so the README must tell Craft 6 users to require the adapter (`craft6-revamp` adds it to upgraded projects). Gate any Craft 6-only code on `version_compare(Craft::$app->getVersion(), '6.0.0-alpha', '>=')`.
   - **Craft 6-only release:** require `craftcms/yii2-adapter`, `craftcms/cms:^6.0.0` and PHP `^8.5`, and tag a new major. Remove or raise `config.platform.php` if it is lower than 8.5, because it stops Composer resolving the adapter.
2. Fix what breaks on the adapter. Signature changes on overridden methods are the most common: `attributes()` and `attributeLabels()` need `: array`. Work through the list in [required-changes.md](references/required-changes.md#what-breaks-on-the-adapter): custom element queries, PHP 8.3/8.4 changes, graphql-php 15, legacy class names and control panel markup all broke real plugins.
3. Install the plugin in a clean host project through a path repository, with only this plugin installed ([references/testing.md](references/testing.md)).
4. Test the plugin's main features: its action URLs (with a CSRF token), its control panel pages (look at them: Craft 5's CP CSS isn't loaded), any front-end form, and any component it registers (a mail transport, filesystem or field type must actually work, not just install). Run console commands and queue jobs too, not only web requests. Note what works.
5. Tag a release if the developer wants to publish. This stops here for end state A.

**Exit:** `craft:plugin:install` succeeds, the action URLs respond correctly, the settings page renders and saves.
**Checkpoint:** report what changed, what was tested, and the list of deprecation warnings still being raised. These drive the next stages. If using a temporary adapter for end state B, report that it remains installed. Continue within the agreed scope.

## Stage 2: Switch to the native plugin class, and upgrade what that breaks

**Goal:** the plugin extends `CraftCms\Cms\Plugin\Plugin` and its features still work. Everything the legacy Yii plugin class gave you for free has to be provided natively at the same time. Do these together, and test after each one:
**References:** [plugin-class.md](references/plugin-class.md), [http-and-auth.md](references/http-and-auth.md), [models-and-validation.md](references/models-and-validation.md), [fields-widgets-forms.md](references/fields-widgets-forms.md), [database.md](references/database.md)

1. Change the base class to `CraftCms\Cms\Plugin\Plugin`. Move `init()` logic into `boot()` (which supports dependency injection). Replace `createSettingsModel()` with `protected static function createSettings(): ?PluginSettings` (it is **static**).
2. Settings: make the settings class extend `PluginSettings`, use `getRules()` instead of `defineRules()`, and give config values real public properties (a property hook can normalize assignments). The CP settings page uses `settingsUi(UiContext $context = new UiContext): ?Ui` (the UI builder, `settingsForm()` on 6.0.0-alpha.20), replacing the Twig `settingsHtml()` template. Craft never calls the old `createSettingsModel()` or `settingsHtml()`, and doesn't say so: settings come back `null`. Bind the settings class in `register()`, not `boot()` ([services-and-di.md](references/services-and-di.md#prefer-injection-for-runtime-dependencies)). Add a config stub only if the plugin wants one.
3. Controllers: Yii controllers are no longer routed. Upgrade each to a plain (usually invokable) class using `RespondsWithFlash`, and route it from `routes/actions.php` so existing `actions/<handle>/<action>` URLs keep working (Craft adds the `actions/<handle>/` prefix, so write `Route::post('save', ...)`, not `'<handle>/save'`) (`routes/web.php` and `cp.php` for new routes). Put `auth` first on every non-anonymous route, because `routes/actions.php` is also reachable by guests. Replace `Craft::$app` calls and Yii request and response helpers as you touch each class ([services-and-di.md](references/services-and-di.md), [http-and-auth.md](references/http-and-auth.md)). If the controller had `$enableCsrfValidation = false` or a setting for it, exempt the route in `boot()` with `PreventRequestForgery::except()`.
4. Layout: icon to `resources/`, routes to `routes/`, translations to `lang/`, templates to `resources/views/` (or `resources/templates/`). Cull old incremental migrations and convert the rest to `database/migrations/` (see [database.md](references/database.md)).
5. If the developer chose a new namespace in Stage 0, add it to `composer.json` `autoload.psr-4` next to the old one and move **most classes** into the Laravel-style layout as you upgrade each one (controllers in `Http/Controllers`, request validation in `Http/Requests`, events in `Events`, handlers in `Listeners`, data objects in `Data`, Eloquent models in `Models`, jobs in `Jobs`, commands in `Console/Commands`, settings next to the plugin class). Leave nothing behind in Yii-style folders. Use `git mv` so history follows. Remove the old autoload root when nothing uses it, update `extra.class` if the plugin class moved, and record every renamed class in `UPGRADE.md`.

**Exit:** the native class, settings save, action URLs, and front-end forms work in the selected environment. Exercise install, uninstall, and reinstall only in a disposable host with no data to preserve. A direct native port keeps the adapter absent.
**Checkpoint:** summarize what works, what remains, and whether an adapter is still installed. Continue within the agreed scope.

## Stage 3: Logic, services, events and validation

**Goal:** the plugin's internal logic uses the Laravel container and events. Much of this happens inside the classes you upgraded in Stage 2. This stage finishes anything left, and is where the plugin's own events change.
**References:** [services-and-di.md](references/services-and-di.md), [events-and-registries.md](references/events-and-registries.md), [models-and-validation.md](references/models-and-validation.md)

1. Upgrade services to plain classes, mark them `#[Singleton]` (or `#[Scoped]` if they hold per-request state), and replace `Craft::$app` locator calls and plugin getters with injection or `app()`.
2. Upgrade event handlers to the new event classes. Look up each replacement from the old constant's docblock. Never convert them with a regex. Register with `$events`, `Event::listen()` in `boot()`, or a subscriber.
3. Replace `RegisterComponentTypesEvent` handlers with registries or plugin properties.
4. Upgrade your own events to Laravel event classes. Unless the developer chose a compatibility layer, remove the old Yii-style `EVENT_*` constants and event base classes, and add a before and after entry for each to `UPGRADE.md`. Before removing one, search for code that listens to it (`gh search code EVENT_AFTER_FOO`, or the developer's other repos): another plugin may need a matching change. Vetoable events use `ValidatableEvent` ([events-and-registries.md](references/events-and-registries.md)).
5. Move validation to Laravel rules (`getRules()`, form requests, rulesets), preferably at the input layer (a `FormRequest` for submitted params).
6. Replace behaviors with macros.
7. Test the events: register throwaway listeners in the host, exercise each path (success, veto, spam, failure) and check each fires ([references/testing.md](references/testing.md)).

**Exit:** no use of `Craft::$app`, `Yii::$app` or Yii events remains in the plugin's own logic, the events behave as documented in `UPGRADE.md`, and tests pass.
**Checkpoint:** summarize what works, what remains, and whether an adapter is still installed. Continue within the agreed scope.

## Stage 4: Remaining surfaces: templates, console, queue and mail

**Goal:** everything else users and other systems touch is native.
**References:** [templates-and-twig.md](references/templates-and-twig.md), [other-areas.md](references/other-areas.md), [http-and-auth.md](references/http-and-auth.md)

1. Front-end templates and forms: check the plugin's README examples against the real behavior (see [templates-and-twig.md](references/templates-and-twig.md), "Front-end forms"). Failed submissions redirect back with flashed data, so `entry`-style variables are replaced by `old()`, `errors` and `session()`. Update the README and `UPGRADE.md`.
2. Permissions: `getPermissions()`, `can:` middleware, gates and policies.
3. Console: Artisan commands registered through `$commands`.
4. Queue: jobs extending `CraftCms\Cms\Queue\Job` with `handle()`. Scheduling via `schedule()`.
5. Mail: system messages through `getSystemMessages()`, other mail through `CraftMailable`.
6. Twig: extensions via the `Twig` facade, `craft.*` additions as `CraftVariable` macros, globals via `TemplateGlobalsResolving`. Craft's facades (for example `Sections`) are available in Twig.
7. Assets: `$scripts`/`$styles`/`$vite` in place of asset bundles. CP pages, utilities, field inputs and element editor additions are Vue components now ([templates-and-twig.md](references/templates-and-twig.md#control-panel-front-end)).

**Exit:** the plugin's templates, CLI, queue and mail paths all work, and the README and `UPGRADE.md` describe the behavior that was actually tested.
**Checkpoint:** summarize what works, what remains, and whether an adapter is still installed. Continue within the agreed scope.

## Stage 5: Components, fields, widgets, then remove the adapter

**Goal:** custom components are native, and the plugin no longer requires the adapter.
**References:** [fields-widgets-forms.md](references/fields-widgets-forms.md), [strategy.md](references/strategy.md)

1. Fields: `settingsUi()` and `uiControl()` (`settingsForm()` and `formControl()` on 6.0.0-alpha.20) in place of `getSettingsHtml()`/`getInputHtml()`, `modifyQuery()` in place of `queryCondition()`, and `getRules()`/`getElementRules()`. If the field class name changed, add a migration that renames the stored type ([fields-widgets-forms.md](references/fields-widgets-forms.md#field-types)).
2. Widgets and utilities: new base classes and registration. Element types have no upgrade guide yet, so read the source and tell the developer.
3. Legacy layer: decide what, if anything, to keep for downstream users (`class_alias()`, a `legacy/` autoload root, `Deprecator::log()`), and update `composer.json` autoloading for old and new namespaces. If the developer chose a clean break instead, finish `UPGRADE.md` now: every removed or renamed event, class, setting, route and variable should have a before and after entry, and the requirements and upgrade steps sections should be filled in.
4. End state B: remove any temporary `craftcms/yii2-adapter` dependency within the agreed scope, or confirm that it was never installed. In a clean host project that has neither the adapter nor other plugins, test every feature. Confirm nothing pulls Yii in: `composer show craftcms/yii2-adapter` and `composer show yiisoft/yii2` should both report that the package is not installed. (Small `yiisoft/*` utility libraries such as `yiisoft/arrays` are dependencies of Craft 6 itself and are expected.)
5. Re-run `scripts/scan-craft5.sh` on the plugin's native source. Review each remaining finding rather than requiring a literal zero: the scan also matches native rendering, schema, macro, and static-access APIs. Explain intentional compatibility aliases and distinguish them from unresolved legacy dependencies. With the adapter removed, static analysis also catches leftovers: PHPStan reports a legacy `craft\` class as unknown. (A Pest `arch()` test can't: it doesn't see classes that aren't installed, so it passes anyway.)
6. Run static analysis and the code style tool ([testing.md](references/testing.md#tooling-and-ci)).

**Exit:** for end state B, the plugin works with the adapter absent, with neither Yii nor the adapter installed, and all scan findings are resolved or explained.
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
- Resolve services through the container or dependency injection instead of constructing them directly or chaining plugin service getters. `Plugin::getInstance()` remains a supported native plugin API, but injection is preferable for runtime dependencies. Replace legacy `Craft::$app` access. Inject what you need (`Settings $settings`, `Sections $sections`) or resolve it with `app(ClassName::class)`. Bind the plugin's settings class in `register()` so classes can type-hint it: Craft loads the plugin's route files before `boot()` runs ([services-and-di.md](references/services-and-di.md)).
- Keep old classes loadable where the database, project config or other code may reference them.
- Do not use the adapter's own deprecation API in new code. Use `CraftCms\Cms\Support\Facades\Deprecator::log()`.
- Do not publish the plugin's regular migrations into the app, because they would run twice.
- Two release tracks: the adapter release can stay on the current major and support Craft 4, 5 and 6 (Stage 1), and the native code is a new major on its own branch. A plugin shows as "Craft 6.0-ready" once it requires `craftcms/cms:^6.0.0` and adopts the new base class.

## Edge cases

- **Filesystems, mail transports and log back-ends:** likely obsolete in Craft 6 (Laravel disks, mailers and logging). Tell the developer before upgrading them mechanically.
- **Control panel JavaScript:** the docs say little yet about the new client-side architecture. Follow the patterns in [templates-and-twig.md](references/templates-and-twig.md#control-panel-front-end), copy the closest core component, and flag anything else as unverified.
- **Element types with no native class:** `Category`, `Tag` and `GlobalSet` (and Matrix blocks) exist only as legacy classes inside `craftcms/yii2-adapter`. Native classes exist for `Entry`, `Asset`, `User` and `Address`. A plugin that queries the others can't go adapter-free yet: say so, and document it.
- **Plugin APIs defined by a config file:** when users write closures and class names in a config file, that file is the public API. List every Craft 5 class and call they use, with the Craft 6 replacement, in `UPGRADE.md` (it is where most of the breaking changes live), and warn that `config:cache` can't serialize closures. `config/craft/<handle>.php` is loaded before Craft boots, so README recipes that call `Craft::$app` there fail with `Class "Craft" not found`, even with the adapter. Move that logic to an event listener.
- **Audit cache TTLs and cookies:** a Laravel cache `null` TTL means forever, and JSON routes in `routes/web.php` get session cookies. See [services-and-di.md](references/services-and-di.md) and [http-and-auth.md](references/http-and-auth.md).
- **Docs inconsistencies:** a few snippets in the docs conflict (noted in the reference files). Verify against source before relying on them.
- **Developer wants to stop at Stage 1 (end state A):** that is a valid, supported outcome. Make sure the plugin's `composer.json` requires or suggests the adapter (and the README says to install it), and say which deprecations remain.
- **Adapter-free but the plugin keeps a legacy event or class API:** the legacy Yii event system can't be proxied without the adapter. Either keep legacy names as plain aliases (`class_alias()`), or document the break. Don't quietly keep a Yii dependency.
