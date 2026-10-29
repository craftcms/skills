---
name: craft-6-project-upgrade
description: Walks a developer and their agent through upgrading a Craft CMS 5 project (site) to Craft 6 (Laravel) in stages - preflight on 5.x, run the craft6-revamp tool, install and migrate, fix and verify, then clear deprecations and optionally remove the craftcms/yii2-adapter. Use when asked to upgrade, migrate or move a Craft 5 site or project to Craft 6 or Laravel. For plugins and modules, use craft-6-plugin-upgrade.
license: MIT
compatibility: Needs bash, grep, php and Composer. The project needs PHP 8.5 and MySQL 8.0.17+, MariaDB 10.4.6+ or PostgreSQL 13+ to run Craft 6. Written against craftcms/cms 6.0.0-alpha.20 and craft6-revamp 1.2.0.
---

# Upgrading a Craft 5 project to Craft 6

Craft 6 is a Laravel package, and a Craft 6 project is a Laravel application: `artisan`, `bootstrap/app.php`, `public/`, `config/*.php` for Laravel and `config/craft/` for Craft, `database/migrations/` for the app's own tables, `resources/views/` for templates, `lang/` for translations. The upgrade moves a Craft 5 project into that shape, installs Craft 6 with the `craftcms/yii2-adapter` compatibility layer, and runs migrations. After that the site should work. Removing the adapter is a separate, optional clean-up.

Work **in stages**. Each stage has a goal, steps, exit criteria and a checkpoint. Finish one before starting the next, and stop at each checkpoint to summarize and confirm with the developer.

Agree an **end state** in Stage 0:

- **End state A, running on Craft 6 with the adapter.** Stages 0 to 3. This is the officially supported result of an upgrade.
- **End state B, adapter removed.** Also do Stage 4. Realistic when no installed plugin requires the adapter and the project's config, templates and modules can be modernized. A clean project gets there in an afternoon.

## Ground rules

- Craft 6 is in alpha. The source of truth is, in order: the installed `vendor/craftcms/cms` (and `vendor/craftcms/yii2-adapter`) source, the `craft6-revamp` tool's own output, the published docs (https://craftcms.com/docs/6.x/upgrade.html), then this skill. A snapshot of the upgrade, compatibility and requirements docs is in [references/docs/](references/docs/INDEX.md). Where they disagree, say so and follow the higher source.
- **Read [references/known-issues.md](references/known-issues.md) before Stage 1.** It lists confirmed failures of the stock upgrade path and their fixes. Most of them hit every project.
- **Do not run anything on a live server.** Upgrade a local or disposable copy. The tool rewrites files in place and the migrations change the database.
- **Make it restorable before changing anything.** The working tree should be committed (or the project copied) and the database backed up. Ask before any step that deletes files or data. Commit after each stage so the developer can review the diff per stage.
- Use the project's own tooling. With DDEV, prefix PHP, Composer and Artisan commands with `ddev` (`ddev composer`, `ddev artisan`, `ddev php craft`). Without DDEV, run them with a PHP 8.5 CLI. See [references/environments.md](references/environments.md).
- Never guess a config key, class name or command. Check `php artisan list`, `php artisan help <command>`, the installed source, or the docs, and say plainly when something is unverified.
- Judge success by evidence: status codes **and** final URLs, saved values read back from the database, jobs actually processed. A 200 can be a login page.
- Explain *why* as you go. The developer is learning a Laravel project layout, not just receiving a diff.

## Stage 0: Preflight on Craft 5

**Goal:** the Craft 5 project is in a state the tool accepts, everything that will need attention is listed, and the project can be restored.

1. Run `scripts/preflight.sh <project-path>` (read-only). It reports blockers, what the tool will and won't handle, and post-upgrade work. Keep the output: it is the checklist for Stages 2 to 4.
2. Establish a working 5.x baseline to compare against: the site URL in `.env` (often `PRIMARY_SITE_URL`) must match where you serve it ([references/environments.md](references/environments.md#running-a-local-server)), the home page returns 200, and a browser login reaches the dashboard.
3. Resolve blockers on Craft 5:
   - Craft must be on the latest 5.x (the tool refuses anything below 5.9.0). Update with `php craft update all` or Composer, run `php craft up`, and commit.
   - Plugins **and dev tools**: list each Composer package that depends on `craftcms/cms` with whether a release supports Craft 6 (check Packagist for a `craftcms/cms ^6` requirement). During the alpha most plugins don't, and neither does `craftcms/generator` (see known issues). Options per package: wait, remove it, replace it with Laravel configuration (filesystem, mailer and logging plugins are obsolete), or disable a plugin for the upgrade with `CRAFT_DISABLED_PLUGINS="*"`. Any package left in `composer.json` that requires Craft 5 will block `composer update` in Stage 2, so decide now.
   - Categories, tags and global sets will be entrified (converted to entries) during the upgrade. If the developer wants control over that, run the `entrify/*` commands on 5.x first.
4. Prepare the 5.x site, using the project's normal CLI:
   - `php craft project-config/apply` (so files and DB agree), then `php craft queue/run` until the queue is empty: the queue table is dropped during the upgrade and pending jobs are lost.
   - Resolve outstanding deprecation warnings (Utilities > Deprecation Warnings, or the `deprecationerrors` table).
   - Note the email transport settings (Settings > Email) and every filesystem; both move to Laravel config.
   - Back up the database (`php craft db/backup`) and commit or copy the code.
5. Agree the end state (A or B) and the package decisions with the developer.

**Exit:** preflight shows no blockers, the baseline works, the queue is empty, a DB backup and a clean commit exist, and the plan is written down.
**Checkpoint:** present the preflight summary, the package decisions and the end state. Get agreement before running the tool.

## Stage 1: Run the upgrade tool

**Goal:** the project's files are in the Craft 6 layout. Nothing has been installed or migrated yet.
**References:** [references/what-the-tool-does.md](references/what-the-tool-does.md)

1. Install `craftcms/craft6-revamp` with **PHP 8.2 or newer** on the host. Either globally (`composer global require craftcms/craft6-revamp -W`) or, to leave the global Composer alone, into a throwaway directory: `composer require --working-dir=/tmp/craft6-revamp craftcms/craft6-revamp`, then run `/tmp/craft6-revamp/vendor/bin/craft6-revamp`. With DDEV it runs on the host, not in the container.
2. Run it against the project root: `craft6-revamp /path/to/project`, or from the project root with no argument. The path is a positional argument, not `--path`.
3. The tool asks whether to rename the web root to `public/` (say yes, unless something outside the repo depends on the old name), and whether to proceed (it replaces `index.php` and deletes `bootstrap.php`). **Without a TTY, as when an agent runs it, every question is answered with its default, which is "yes".** Get the developer's agreement before running it non-interactively.
4. Save the tool's **Next steps** table: it is project-specific (filesystem disk suggestions, aliases, removed settings, `loginPath`).
5. Review the diff (`git status`, `git diff`). Expect: `composer.json` changes, new `artisan`, `bootstrap/app.php`, `bootstrap/cache/`, `storage/framework/*`, Laravel config files in `config/`, Craft config moved to `config/craft/`, `templates/` to `resources/views/`, `translations/` to `lang/`, `web/` to `public/`, a new `public/index.php`, `.env` variables renamed, and `craft` and `bootstrap.php` deleted.

**Exit:** the tool finished every step, and the diff matches the list above.
**Checkpoint:** show the diff summary and the tool's Next steps. Commit ("Run craft6-revamp").

## Stage 2: Install Craft 6 and migrate

**Goal:** Craft 6 is installed, the database is migrated, and the app boots over HTTP and CLI.

Do steps 1 to 4 **before** `composer update`: its `post-autoload-dump` scripts boot the app, and `craft:setup:publish` copies Craft's default config files into `config/craft/` only where none exist.

1. `composer.json`: apply the Stage 0 package decisions. Remove `craftcms/generator` (the tool rewrites it to `3.x-dev`, which still requires Craft 5) and `yiisoft/yii2-shell`. Remove `yiisoft/yii2-composer` from `config.allow-plugins` once nothing needs it. With DDEV, `ddev restart` first so Composer runs on PHP 8.5.
2. `config/craft/general.php` (see [known-issues.md](references/known-issues.md#config-that-breaks-or-warns-on-boot)):
   - set `'@webroot' => public_path()` (the stock value `dirname(__DIR__) . '/web'` now points at `config/web`), and fix `@web` if set;
   - remove `omitScriptNameInUrls()`, `pathParam()` and `enableTwigSandbox()`.
3. `config/craft/twig-sandbox.php`: if it is the stock Craft 5 file (every `allowed*` list empty), **delete it**; publishing replaces it with Craft 6's defaults. Empty lists now replace the defaults instead of extending them, which breaks every system email. If it was customized, start from Craft 6's `vendor/craftcms/cms/config/twig-sandbox.php` after the update and re-add the project's additions.
4. `.env`: set `APP_ENV` (for example `local`) and `APP_URL` (the URL you'll serve on). The tool sets neither, and Laravel then runs as `production`. `CRAFT_ENVIRONMENT` is left alone; keep it until general config no longer reads it.
5. `composer update -W`. Expect about a dozen "Ambiguous class resolution" warnings for traits shipped by both `craftcms/cms` and the adapter: harmless, and gone when the adapter is removed. A real failure is a non-zero exit or a script error: fix the cause and rerun; don't move on with a half-installed vendor directory. Run `php artisan craft:setup:publish` yourself if the scripts didn't.
6. `php artisan key:generate` (sets `APP_KEY`, which replaces `CRAFT_SECURITY_KEY`).
7. `php artisan craft:up` (backs up the database first, `--noBackup` skips that). "Application in production" warnings mean `APP_ENV` isn't set.
8. Check the app's queue tables exist: `php artisan db:table jobs` (or query the database). Builds after 6.0.0-alpha.20 create `jobs`, `job_batches`, `failed_jobs` and Laravel's other support tables in `craft:up`; on alpha.20 and earlier, nothing does, and **every control panel page returns 500** (`Table '...jobs' doesn't exist`). Only if they're missing: copy `database/migrations/0001_01_01_000002_create_jobs_table.php` from the 6.x starter (https://github.com/craftcms/craft/tree/6.x), then `php artisan migrate --force`. Do the same for the cache table if `CACHE_STORE=database`, and sessions if `SESSION_DRIVER=database`. Don't add the starter migration when the tables already exist: it has no existence check and fails with "table already exists". Don't hide a missing table by switching to the `sync` queue.
9. If the site uses project config: `php artisan craft:project-config:apply` should succeed with no changes.
10. On 6.0.0-alpha.20 and earlier, the stock Craft 5 welcome page (`resources/views/index.twig`) returns 500. If it does, replace it with the 6.x starter's `resources/views/index.twig`. Later versions render it.
11. Smoke test: serve the site ([references/environments.md](references/environments.md#running-a-local-server)); the home page and `/admin/login` (or the custom `cpTrigger`) return 200.

**Exit:** `composer update` succeeded, `craft:up` and `migrate:status` report nothing pending, `php artisan list` lists the `craft:*` commands, `php craft` works, and the home page and login page return 200.
**Checkpoint:** report what ran, any errors and how they were fixed. Commit ("Install Craft 6").

## Stage 3: Fix the configuration and verify the site

**Goal:** the site works on Craft 6 with the adapter, and the developer knows what is left.
**References:** [references/after-upgrade.md](references/after-upgrade.md), [references/docs/compatibility.md](references/docs/compatibility.md)

1. Work through the tool's Next steps and the preflight WARN lines that apply now: general config settings that were removed or moved, `loginPath`, multi-environment config, `db.php`, filesystems to `config/filesystems.php` disks, the email transport to `config/mail.php`, `.env.example*` files, `.gitignore`, and deploy scripts. [references/after-upgrade.md](references/after-upgrade.md) has the details for each.
2. Compare the project with the Craft 6 starter project for files the tool does not create: `routes/web.php`, `routes/console.php`, `app/Providers/AppServiceProvider.php`, `bootstrap/providers.php`. Add them only when the project needs them (custom routes, a module, a scheduler), and say why.
3. Verify, and record the evidence ([references/after-upgrade.md](references/after-upgrade.md#verification)):
   - the front end: the home page and a sample of entry URLs return 200 and render real content;
   - the control panel: sign in with a browser, then load the dashboard, an entry edit page and Settings, checking each final URL is not the login page;
   - saving an entry through the control panel works, confirmed by reading the value back (database or front end). An empty project needs an entry type and section first ([recipe](references/after-upgrade.md#a-test-entry-on-an-empty-project));
   - the queue processes real jobs: saving an entry queues some, then `php artisan queue:work --stop-when-empty` runs them, and `jobs` and `failed_jobs` are empty;
   - email: `php artisan craft:mailer:test` succeeds. With the `log` mailer that proves rendering, not delivery; say so;
   - `storage/logs/` has no new errors since the verification started.
4. List the deprecation warnings (Utilities > Deprecation Warnings, or the `deprecationerrors` table), each with the file and line from its trace. They are Stage 4's to-do list.

**Exit:** every check in step 3 passes, or fails for a reason that is documented and agreed.
**Checkpoint:** report what works, what was changed, and the deprecation list. For end state A, this is the end: write the final report (below). Commit ("Fix Craft 6 configuration"). Ask whether to continue to Stage 4.

## Stage 4: Clear deprecations and remove the adapter (end state B only)

**Goal:** the project runs without `craftcms/yii2-adapter`.
**References:** [references/after-upgrade.md](references/after-upgrade.md#removing-the-adapter), [references/docs/compatibility.md](references/docs/compatibility.md)

1. Check that nothing else requires the adapter: `composer why craftcms/yii2-adapter` should list only the project. If a plugin requires it, stop: end state B isn't possible until that plugin drops it. Say so.
2. Modernize what only the adapter supports: `config/craft/general.php` to the native `CraftCms\Cms\Config\GeneralConfig` (and drop `craft\helpers\App`), multi-environment and app-type config, `config/craft/app.php` (delete the stock one), `config/craft/routes.php` (to `routes/web.php`), HTMLPurifier configs (delete an unmodified `Default.json`, translate custom ones), and templates that use `craft.app`, `view.*`, Yii flashes and the deprecated filters. Modules move into `app/` as Laravel service providers (the `craft-6-plugin-upgrade` skill covers the code).
3. Clear the deprecation warnings table, exercise the site again (Stage 3, step 3), and list what comes back, with traces. Classify each warning:
   - **project-owned**: the trace reaches the project's config, templates, modules or a plugin. Fix it.
   - **adapter-internal**: every frame is inside `vendor/craftcms/yii2-adapter` (for example `Craft::$app->fields`, `generalConfig.isSystemLive`, `generalConfig.generateTransformsBeforePageLoad` on alpha.20). The adapter raises these itself while bootstrapping; they can't be fixed from the project, and they stop when it is removed.
   Continue only when no project-owned warnings remain.
4. Back up the database and commit. Ask the developer to confirm, then `composer remove craftcms/yii2-adapter`. Confirm `composer show craftcms/yii2-adapter` and `composer show yiisoft/yii2` both report the package isn't installed. If the app no longer boots, fix the project code it points at, or `git checkout` and `composer install` to go back.
5. Composer's scripts re-run `craft:setup:publish`, which can recreate `config/craft/` files you deleted (for example `routes.php`, `twig-sandbox.php`) with Craft 6's defaults. That is expected; check their contents.
6. Clear the deprecation warnings table and repeat the Stage 3 verification with a fresh browser session. Run `php artisan craft:up` again. The deprecations table must now stay empty.

**Exit:** the adapter and `yiisoft/yii2` are not installed, every Stage 3 check passes, and no deprecation warnings are logged.
**Checkpoint:** final report.

## Final report

End with a short report for the developer:

- the end state reached, and the Craft, adapter, Laravel and PHP versions installed;
- what changed, stage by stage, with the commits;
- what was verified, and how (commands, URLs, status codes and final URLs, saved values);
- anything left: remaining deprecations, plugins not yet upgraded, config translated by hand that needs a second look, deploy changes (paths, PHP 8.5, `artisan` commands, a queue worker and the scheduler), and anything unverified (for example real email delivery);
- any gotcha not already in [references/known-issues.md](references/known-issues.md), so it can be added.

## Reference map

| Topic | Reference |
| --- | --- |
| Confirmed failures, and where the docs, the tool and the code disagree | [known-issues.md](references/known-issues.md) |
| Each step the tool performs, and doing it by hand | [what-the-tool-does.md](references/what-the-tool-does.md) |
| Config, env vars, mail, filesystems, templates, routes, modules, deploys, verification, removing the adapter | [after-upgrade.md](references/after-upgrade.md) |
| DDEV, plain PHP, Docker, running a local server | [environments.md](references/environments.md) |
| Official docs snapshot | [docs/INDEX.md](references/docs/INDEX.md) |
