---
name: craft-6-project-upgrade
description: Walks a developer and their agent through upgrading a Craft CMS 5 project (site) to Craft 6 (Laravel) in stages - preflight on 5.x, run the craft6-revamp tool, install and migrate, fix and verify, then clear deprecations and optionally remove the craftcms/yii2-adapter. Use when asked to upgrade, migrate or move a Craft 5 site or project to Craft 6 or Laravel. For plugins and modules, use craft-6-plugin-upgrade.
license: MIT
compatibility: Needs bash, grep, php and Composer. The project needs PHP 8.5 and MySQL 8.0.17+, MariaDB 10.4.6+ or PostgreSQL 13+ to run Craft 6. Needs a Craft 6 build newer than 6.0.0-alpha.20 (6.x-dev from 29 Oct 2026, or a later release). Needs craft6-revamp 1.3.1 or later.
---

# Upgrading a Craft 5 project to Craft 6

Craft 6 is a Laravel package, and a Craft 6 project is a Laravel application: `artisan`, `bootstrap/app.php`, `public/`, `config/*.php` for Laravel and `config/craft/` for Craft, `database/migrations/` for the app's own tables, `resources/views/` for templates, `lang/` for translations. The upgrade moves a Craft 5 project into that shape, installs Craft 6 with the `craftcms/yii2-adapter` compatibility layer, and runs migrations. After that the site should work. Removing the adapter is a separate, optional clean-up.

Work **in stages**. Each stage has a goal, steps, exit criteria and a checkpoint. Finish one before starting the next, and stop at each checkpoint to summarize and confirm with the developer.

Agree an **end state** in Stage 0:

- **End state A, running on Craft 6 with the adapter.** Stages 0 to 3. This is the officially supported result of an upgrade.
- **End state B, adapter removed.** Also do Stage 4. Realistic when no installed plugin requires the adapter and the project's config, templates and modules can be modernized. A clean project gets there in an afternoon.

## Ground rules

- Craft 6 is in alpha. The source of truth is, in order: the installed `vendor/craftcms/cms` (and `vendor/craftcms/yii2-adapter`) source, the `craft6-revamp` tool's own output, the published docs (https://craftcms.com/docs/6.x/upgrade.html), then this skill. Fetch the docs pages you need rather than relying on memory: [upgrade](https://craftcms.com/docs/6.x/upgrade.html), [compatibility](https://craftcms.com/docs/6.x/compatibility.html) (the adapter, deprecations, config and ejecting it) and [requirements](https://craftcms.com/docs/6.x/requirements.html). Where they disagree, say so and follow the higher source.
- **Don't work around Craft bugs.** If an error comes from vendor code and the project didn't cause it, don't patch `vendor/` or invent a workaround. Record the exact error, the `craftcms/cms` version (and commit, for a `-dev` build) from `composer.lock`, and the steps. Tell the developer, and suggest reporting it to https://github.com/craftcms/cms/issues.
- **Moving project code to a native Craft 6 API is not a workaround.** Small changes to the project's own templates, config or modules that use a documented native replacement are encouraged (Stage 3, step 4). If the old call crashed, still record and report it: other projects rely on the adapter for it.
- **Do not run anything on a live server.** Upgrade a local or disposable copy. The tool rewrites files in place and the migrations change the database.
- **Make it restorable before changing anything.** The working tree should be committed (or the project copied) and the database backed up. Ask before any step that deletes files or data. Commit after each stage so the developer can review the diff per stage.
- Use the project's own tooling, and ask the developer which runtime they use if it isn't clear: a `.ddev/` folder doesn't prove they work in DDEV. With DDEV, prefix PHP, Composer and Artisan commands with `ddev` (`ddev composer`, `ddev artisan`, `ddev php craft`). With Laravel Herd or Valet, isolate the site to PHP 8.5 and use `herd php`/`herd composer` (or `valet php`/`valet composer`). Otherwise, run them with a PHP 8.5 CLI. See [references/environments.md](references/environments.md).
- Never guess a config key, class name or command. Check `php artisan list`, `php artisan help <command>`, the installed source, or the docs, and say plainly when something is unverified.
- Judge success by evidence: status codes **and** final URLs, saved values read back from the database, jobs actually processed. A 200 can be a login page.
- Explain *why* as you go. The developer is learning a Laravel project layout, not just receiving a diff.

## Stage 0: Preflight on Craft 5

**Goal:** the Craft 5 project is in a state the tool accepts, everything that will need attention is listed, and the project can be restored.

1. Run `scripts/preflight.sh <project-path>` (read-only). It checks the host PHP version and lists what craft6-revamp doesn't report: templates, modules and deploy files that need work. Keep the output: it is the checklist for Stages 3 and 4. Plugin compatibility, entrify commands and config the tool can't rewrite come from the tool itself in Stage 1.
2. Establish a working 5.x baseline to compare against: the site URL in `.env` (often `PRIMARY_SITE_URL`) must match where you serve it ([references/environments.md](references/environments.md#running-a-local-server)), the home page returns 200, and a browser login reaches the dashboard.
3. Resolve blockers on Craft 5:
   - Craft must be on the latest 5.x (the tool refuses anything below 5.9.0). Update with `php craft update all` or Composer, run `php craft up`, and commit.
   - Plugins **and dev tools**: for each Composer package that depends on `craftcms/cms`, find a version that supports Craft 6 (Packagist: a `craftcms/cms ^6` requirement, possibly only on a dev branch). Then prove the whole set resolves together, in a scratch copy of the project: set `craftcms/cms` and `craftcms/yii2-adapter` to the target version and each plugin to its candidate, and run `composer update -W --dry-run`. A Craft 6 version on Packagist (or a ✓ in the tool's report) only means the plugin *declares* support; the dry run of the whole set is the proof. A plugin's own dependencies (for example a field library it builds on) can still require Craft 5, or the Craft 6 branches of two related packages can reject each other. A dev branch is pre-release code: list each one and get the developer's approval to use it.
   - For each plugin with no resolvable Craft 6 version, decide with the developer: wait, remove it, or replace it with Laravel configuration (filesystem, mailer and logging plugins are obsolete). **If the project depends on it** (it provides field types holding content, SEO, forms or other site features), the upgrade is blocked: say so, and stop here unless the developer explicitly accepts a degraded result. Never remove a plugin that owns field types just to get past this: the content stays in the database, but the site stops rendering it, and saving those entries can lose it. If the developer accepts that, disable or remove it (don't uninstall it or drop its tables), record which fields, entries and templates are affected, don't save those entries until the plugin is back, and check after `craft:up` that their stored content is unchanged (for example by comparing `elements_sites.content` with the Stage 0 backup).
   - Categories, tags and global sets: Craft 6 keeps them only as legacy elements, which need the adapter. To reach end state B, or to stop depending on them, convert them on 5.x first with `php craft entrify/categories`, `entrify/tags` and `entrify/global-set`, and update the templates that query them. If the project is already on Craft 6, the adapter's `php artisan craft:entrify:*` commands do the same; back up the database first. After the upgrade, check what happened to any that remain (Stage 3).
4. Prepare the 5.x site, using the project's normal CLI:
   - `php craft project-config/apply` (so files and DB agree), then `php craft queue/run` until the queue is empty: the queue table is dropped during the upgrade and pending jobs are lost.
   - Resolve outstanding deprecation warnings (Utilities > Deprecation Warnings, or the `deprecationerrors` table).
   - Note the email transport settings (Settings > Email) and every filesystem; both move to Laravel config.
   - Back up the database (`php craft db/backup`) and commit or copy the code.
5. Agree the end state (A or B) and the package decisions with the developer. If a needed plugin blocks the upgrade, the honest outcome is "blocked"; don't plan around it silently.

**Exit:** Craft is on the latest 5.x, the plugin set resolves in a dry run, the baseline works, the queue is empty, a DB backup and a clean commit exist, and the plan is written down.
**Checkpoint:** present the preflight summary, the package decisions and the end state. Get agreement before running the tool.

## Stage 1: Run the upgrade tool

**Goal:** the project's files are in the Craft 6 layout. Nothing has been installed or migrated yet.
**References:** the tool's README (https://github.com/craftcms/craft6-revamp#readme) lists what it does and doesn't do. The [upgrade docs](https://craftcms.com/docs/6.x/upgrade.html#upgrading-manually) cover doing a step by hand.

1. Install `craftcms/craft6-revamp` 1.3.1 or later with **PHP 8.2 or newer** on the host. Either globally (`composer global require craftcms/craft6-revamp:^1.3.1 -W`) or, to leave the global Composer alone, into a throwaway directory: `composer require --working-dir=/tmp/craft6-revamp craftcms/craft6-revamp:^1.3.1`, then run `/tmp/craft6-revamp/vendor/bin/craft6-revamp`. With DDEV it runs on the host, not in the container.
2. Run it against the project root: `craft6-revamp /path/to/project`, or from the project root with no argument. The path is a positional argument.
3. Before changing anything, it reports which packages that require `craftcms/cms` have a Craft 6 version on Packagist (it needs the network; offline it says so and carries on), which plugins are probably obsolete, the `entrify` commands for any category groups, tag groups and global sets, and the lines a customized `index.php` or `bootstrap.php` will lose. Compare this with the Stage 0 decisions, and stop if it shows something new.
4. It asks whether to rename the web root to `public/` (say yes, unless something outside the repo depends on the old name), and whether to proceed (it replaces `index.php` and deletes `bootstrap.php`). Agents run it without a terminal: get the developer's agreement first, then run it with `-n`, which accepts those defaults. With `-n` it cancels (exit 1) if the git tree has uncommitted changes, or if `bootstrap/` or `config/craft/` already exist from an earlier run. Commit first. After a partial run, restore the project from the Stage 0 commit and run the tool again, rather than running it on top.
5. Save the tool's **Next steps** table: it is project-specific (filesystem disk suggestions, config it couldn't rewrite, Yii `app.php`, routes, HTMLPurifier, mail transport). Steps that didn't apply print "Nothing to do".
6. Review the diff (`git status`, `git diff`). Expect: `composer.json` changes, new `artisan`, `bootstrap/app.php`, `bootstrap/cache/`, `storage/framework/*`, Laravel config files in `config/`, Craft config moved to `config/craft/`, `templates/` to `resources/views/`, `translations/` to `lang/`, `web/` to `public/`, a new `public/index.php`, paths and removed settings fixed in `config/craft/general.php`, `.env` and `.env.example*` variables renamed (with `APP_ENV` and `APP_URL` added), `.gitignore` entries for Craft 6 build output, and `craft` and `bootstrap.php` deleted.

**Exit:** the tool finished every step, and the diff matches the list above.
**Checkpoint:** show the diff summary and the tool's Next steps. Commit ("Run craft6-revamp").

## Stage 2: Install Craft 6 and migrate

**Goal:** Craft 6 is installed, the database is migrated, and the app boots over HTTP and CLI.

Do steps 1 to 3 **before** `composer update`: its `post-autoload-dump` scripts boot the app, and `craft:setup:publish` copies Craft's default config files into `config/craft/` only where none exist, and recreates the `craft` executable the tool deleted.

1. `composer.json`: apply the Stage 0 package decisions. The tool sets `craftcms/cms` to `^6.0.0-alpha.1`. If the newest release is 6.0.0-alpha.20 or older, require `6.x-dev` for both `craftcms/cms` and `craftcms/yii2-adapter` instead (Craft 5's `minimum-stability` is already `dev`). Check that every remaining package that depends on `craftcms/cms`, including `craftcms/generator`, has a version that supports Craft 6; remove any that doesn't. **Keep `yiisoft/yii2-composer` in `config.allow-plugins`** while the adapter is installed: it pulls in Yii, and Composer refuses to run with the plugin blocked. With DDEV, `ddev restart` first so Composer runs on PHP 8.5.
2. Config the tool flagged but couldn't rewrite safely (its Next steps): fix it now if it would stop the app booting, for example a `dirname(__DIR__)` path in `config/craft/general.php`, which now resolves to `config/`. Use `base_path()` and `public_path()`.
3. `config/filesystems.php`: add the tool's suggested disk for each Craft filesystem, keyed by its handle, and check its paths and `env()` names. Craft's migrations convert filesystems to disks, so they must exist before `craft:up`. Check that `.env` has the `APP_URL` you'll serve on: the tool only sets it when `PRIMARY_SITE_URL` exists.
4. `composer update -W`. A real failure is a non-zero exit or a script error: fix the cause and rerun; don't move on with a half-installed vendor directory. Run `php artisan craft:setup:publish` yourself if the scripts didn't.
5. `php artisan key:generate` (sets `APP_KEY`, which replaces `CRAFT_SECURITY_KEY`).
6. `php artisan craft:up` (backs up the database first, unless `--noBackup` is passed or `backupOnUpdate` is false in general config: then rely on the Stage 0 backup). "Application in production" warnings mean `APP_ENV` isn't set. If a migration fails, Craft can leave the site in maintenance mode (`storage/framework/down`): after fixing the cause and rerunning, `php artisan up` brings it back.
7. If the site uses project config: `php artisan craft:project-config:apply` should succeed with no changes.
8. Smoke test: serve the site ([references/environments.md](references/environments.md#running-a-local-server)). The home page returns 200 with its real content, and `/admin/login` (or the custom `cpTrigger`) shows the login form. A 200 that shows "Update required", a maintenance page or an error page is a failure.

**Exit:** `composer update` succeeded, `craft:up` reports nothing to run (Craft's migrations aren't in the app's `database/migrations/`, so `migrate:status` may say "No migrations found"; that's normal), `php artisan list` lists the `craft:*` commands, `php craft` works, and the home page and login page return 200.
**Checkpoint:** report what ran, any errors and how they were fixed. Commit ("Install Craft 6").

## Stage 3: Fix the configuration and verify the site

**Goal:** the site works on Craft 6 with the adapter, and the developer knows what is left.
**References:** [references/after-upgrade.md](references/after-upgrade.md), [compatibility docs](https://craftcms.com/docs/6.x/compatibility.html)

1. Read each upgraded plugin's upgrade notes and update its config file in `config/craft/` (for example Element API endpoints become Laravel-style routes, and each site's URL prefix may need its own). Then work through the tool's Next steps and the preflight WARN lines that apply now: general config settings that were removed or moved, `loginPath`, multi-environment config, `db.php`, filesystems to `config/filesystems.php` disks, the email transport to `config/mail.php`, `.env.example*` files, `.gitignore`, and deploy scripts. [references/after-upgrade.md](references/after-upgrade.md) has the details for each.
2. Compare the project with the Craft 6 starter project for files the tool does not create: `routes/web.php`, `routes/console.php`, `app/Providers/AppServiceProvider.php`, `bootstrap/providers.php`. Add them only when the project needs them (custom routes, a module, a scheduler), and say why.
3. Verify against the 5.x baseline, and record the evidence ([references/after-upgrade.md](references/after-upgrade.md#verification)). Build a feature list from the project first: every front-end route and template, each site and its URL prefix, every plugin feature (forms, endpoints, field types), module features, and both admin and non-admin users. Then check each one:
   - the front end: the home page and a sample of entry URLs return 200 and render real content;
   - the control panel: sign in with a browser, then load the dashboard, an entry edit page and Settings, checking each final URL is not the login page. Do this as an admin **and** as an existing non-admin user migrated from Craft 5, not only a fresh account: migrated users carry history (notifications, preferences, permissions) that a new account doesn't. Compare what each user can do with the 5.x baseline: a permission that was already missing on Craft 5 isn't a regression;
   - saving an entry through the control panel works, confirmed by reading the value back (database or front end), and the browser console has no new errors after the save. Saving can prune old revisions, so a missing revision row is expected, not lost content. Also compare what you **didn't** edit: other fields, relations, nested entries, and the entry on every site;
   - every field input in the editor renders as a working control (relation fields included), not an error message or raw markup;
   - front-end forms (login, contact, ...) submit successfully, and land on the right site and language; An empty project needs an entry type and section first ([recipe](references/after-upgrade.md#a-test-entry-on-an-empty-project));
   - the queue processes real jobs: saving an entry queues some, then `php artisan queue:work --stop-when-empty` runs them, and `jobs` and `failed_jobs` are empty;
   - email: `php artisan craft:mailer:test --to=you@example.com --no-interaction` succeeds. With the `log` mailer that proves rendering, not delivery; say so;
   - `storage/logs/` has no new errors since the verification started.
4. Fix small things in the project's own code as you find them, using native Craft 6 APIs, rather than leaving them to the adapter: a template call that fails or logs a deprecation, a renamed filter or function, a config setting that moved. Keep it to small, local edits with a documented replacement (docs or installed source); larger rewrites, such as modules or routes, wait for Stage 4. For each one:
   - first record what the unchanged code did, with the exact error or deprecation message. If it crashed, report it as an adapter bug (Ground rules), even though you're replacing it;
   - check that the result matches the 5.x baseline (rendered HTML, URLs, values), not only that the error is gone;
   - if there is no native replacement, keep the adapter path and report it rather than inventing an equivalent;
   - commit these changes separately from the configuration fixes ("Use Craft 6 APIs in templates"), so they can be reviewed or reverted on their own.
5. List the deprecation warnings (Utilities > Deprecation Warnings, or the `deprecationerrors` table), each with the file and line from its trace. They are Stage 4's to-do list.
6. Check categories, tags and global sets: if they weren't converted on 5.x, they're still legacy elements, and need the adapter.

**Exit:** every check in step 3 passes, or fails for a reason that is documented and agreed. If Craft or a plugin was updated during Stage 3 (for example to pick up a fix), rerun the checks on the final build, and report results from earlier builds separately. If a feature the site needs doesn't work, report the result as **degraded** or **blocked**, not as end state A.
**Checkpoint:** report what works, what was changed, and the deprecation list. For end state A, this is the end: write the final report (below). Commit ("Fix Craft 6 configuration"). Ask whether to continue to Stage 4.

## Stage 4: Clear deprecations and remove the adapter (end state B only)

**Goal:** the project runs without `craftcms/yii2-adapter`.
**References:** [references/after-upgrade.md](references/after-upgrade.md#removing-the-adapter), [compatibility docs](https://craftcms.com/docs/6.x/compatibility.html)

1. Check that nothing else requires the adapter or Yii: `composer why craftcms/yii2-adapter` should list only the project, and `composer why yiisoft/yii2` only the adapter. Other packages can pull in Yii on their own (for example `craftcms/yii2-dynamodb`). If a plugin requires it, stop: end state B isn't possible until that plugin drops it. Say so.
2. Modernize what only the adapter supports: `config/craft/general.php` to the native `CraftCms\Cms\Config\GeneralConfig` (and drop `craft\helpers\App`), multi-environment and app-type config, `config/craft/app.php` (delete the stock one), `config/craft/routes.php` (to `routes/web.php`), HTMLPurifier configs (delete an unmodified `Default.json`, translate custom ones), and templates that use `craft.app`, `view.*`, Yii flashes and the deprecated filters. Modules move into `app/` as Laravel service providers. Before deleting a module (or a seed or demo module that looks unused), read its `init()`/bootstrap code for side effects the site relies on, such as setting env values, registering template roots, events or CP branding, and move those first. The `craft-6-plugin-upgrade` skill (https://github.com/craftcms/skills/tree/main/skills/craft-6-plugin-upgrade) covers the code; use it if it's installed, and otherwise follow its references from that URL.
3. Clear the deprecation warnings table, exercise the site again (Stage 3, step 3), and list what comes back, with traces. Classify each warning:
   - **project-owned**: the deprecated call itself is made from the project's config, templates, modules or a plugin (the frame right above the deprecated method), **or the message names a project file or setting** (for example a `config/craft/htmlpurifier/*.json` file or a general config setting), even when every frame is in vendor code. Fix it.
   - **not the project's**: the deprecated call is made by the adapter, Craft core or Laravel, even if a project template further up the trace triggered it with a normal, non-deprecated API (for example eager-loading a relation field). Typically no frame is in project or plugin code, only the adapter, Craft core, Laravel and entry points (`public/index.php`, `artisan`). The project can't fix these. Treat them as a Craft bug (see Ground rules), and don't let them block removing the adapter.
   Continue only when no project-owned warnings remain.
4. Back up the database and commit. Ask the developer to confirm, then `composer remove craftcms/yii2-adapter`. Afterwards, remove `yiisoft/yii2-composer` from `config.allow-plugins`. Confirm `composer show craftcms/yii2-adapter` and `composer show yiisoft/yii2` both report the package isn't installed. If the app no longer boots, fix the project code it points at, or `git checkout` and `composer install` to go back.
5. Composer's scripts re-run `craft:setup:publish`, which can recreate `config/craft/` files you deleted (for example `routes.php`, `twig-sandbox.php`) with Craft 6's defaults. That is expected; check their contents.
6. Clear the deprecation warnings table and repeat the Stage 3 verification with a fresh browser session. Run `php artisan craft:up` again. No project-owned deprecation warnings may come back.

**Exit:** the adapter and `yiisoft/yii2` are not installed, every Stage 3 check passes, and no project-owned deprecation warnings are logged. Any that remain must be not the project's, each reported as a Craft bug in the final report.
**Checkpoint:** final report.

## Final report

End with a short report for the developer:

- the end state reached (A, B, degraded or blocked, and why), and the Craft, adapter, Laravel, plugin and PHP versions installed, with commits for `-dev` builds;
- what changed, stage by stage, with the commits, including each project call moved to a native API in Stage 3 and why;
- what was verified, and how (commands, URLs, status codes and final URLs, saved values);
- anything left: remaining deprecations, plugins not yet upgraded, config translated by hand that needs a second look, deploy changes (paths, PHP 8.5, `artisan` commands, a queue worker and the scheduler), and anything unverified (for example real email delivery);
- anything that looked like a Craft or `craft6-revamp` bug, with the exact error and versions, so it can be reported.

## Reference map

| Topic | Reference |
| --- | --- |
| Each step the tool performs, and what it doesn't do | https://github.com/craftcms/craft6-revamp#readme |
| Config, env vars, mail, filesystems, templates, routes, modules, deploys, verification, removing the adapter | [after-upgrade.md](references/after-upgrade.md) |
| DDEV, Herd, Valet, plain PHP, Docker, running a local server | [environments.md](references/environments.md) |
| Official docs (fetch the latest) | https://craftcms.com/docs/6.x/upgrade.html, https://craftcms.com/docs/6.x/compatibility.html, https://craftcms.com/docs/6.x/requirements.html |

## Improving this skill

If something in this skill was wrong, missing or misleading (a step that failed, a command or config key that didn't exist, a check that sent you the wrong way, a source lookup the skill should have saved you), tell the developer at the end of your report. Offer to draft an issue for https://github.com/craftcms/skills/issues with the Craft version (`composer show craftcms/cms`), the `craft6-revamp` version, the file and section of the skill, what you expected, and what happened. Only open it if the developer agrees, and leave out private project details. Report bugs in Craft itself to https://github.com/craftcms/cms/issues, and bugs in the upgrade tool to https://github.com/craftcms/craft6-revamp/issues, instead.
