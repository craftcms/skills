---
name: craft-6-project-upgrade
description: Walks a developer and their agent through upgrading a Craft CMS 5 project (site) to Craft 6 (Laravel) in stages - preflight on 5.x, run the craft6-revamp tool, install and migrate, fix and verify, then clear deprecations and optionally remove the craftcms/yii2-adapter. Use when asked to upgrade, migrate or move a Craft 5 site or project to Craft 6 or Laravel. For plugins and modules, use craft-6-plugin-upgrade.
license: MIT
compatibility: Needs bash, grep, php and Composer. The project needs PHP 8.5 and MySQL 8.0.17+, MariaDB 10.4.6+ or PostgreSQL 13+ to run Craft 6. Written against craftcms/cms 6.0.0-alpha.20 and craft6-revamp 1.2.0.
---

# Upgrading a Craft 5 project to Craft 6

Craft 6 is a Laravel package, and a Craft 6 project is a Laravel application: `artisan`, `bootstrap/app.php`, `public/`, `config/*.php` for Laravel and `config/craft/` for Craft, `resources/views/` for templates, `lang/` for translations. The upgrade moves a Craft 5 project into that shape, installs Craft 6 with the `craftcms/yii2-adapter` compatibility layer, and runs migrations. After that the site should work. Removing the adapter is a separate, optional clean-up.

Work **in stages**. Each stage has a goal, steps, exit criteria and a checkpoint. Finish one before starting the next, and stop at each checkpoint to summarize and confirm with the developer.

Agree an **end state** in Stage 0:

- **End state A, running on Craft 6 with the adapter.** Stages 0 to 3. This is the officially supported result of an upgrade, and the right stop for most projects during the alpha.
- **End state B, adapter removed.** Also do Stage 4. Only realistic when no installed plugin requires the adapter and the project's templates and modules have been modernized.

## Ground rules

- Craft 6 is in alpha. The source of truth is, in order: the installed `vendor/craftcms/cms` (and `vendor/craftcms/yii2-adapter`) source, the `craft6-revamp` tool's own output, the published docs (https://craftcms.com/docs/6.x/upgrade.html), then this skill. A snapshot of the upgrade, compatibility and requirements docs is in [references/docs/](references/docs/INDEX.md). Where they disagree, say so and follow the higher source. [references/known-issues.md](references/known-issues.md) lists the disagreements and pitfalls found so far: **read it before Stage 1.**
- **Do not run anything on a live server.** Upgrade a local or disposable copy. The tool rewrites files in place and the migrations change the database.
- **Make it restorable before changing anything.** The working tree should be committed (or the project copied) and the database backed up. Ask before any step that deletes files or data. Commit after each stage so the developer can review the diff per stage.
- Use the project's own tooling. With DDEV, prefix PHP, Composer and Artisan commands with `ddev` (`ddev composer`, `ddev artisan`, `ddev php craft`). Without DDEV, run them with a PHP 8.5 CLI. See [references/environments.md](references/environments.md).
- Never guess a config key, class name or command. Check `php artisan list`, the installed source, or the docs, and say plainly when something is unverified.
- Explain *why* as you go. The developer is learning a Laravel project layout, not just receiving a diff.

## Stage 0: Preflight on Craft 5

**Goal:** the Craft 5 project is in a state the tool accepts, everything that will need attention is listed, and the project can be restored.

1. Run `scripts/preflight.sh <project-path>` (read-only). It reports blockers, what the tool will and won't handle, and post-upgrade work. Keep the output: it is the checklist for Stages 3 and 4.
2. Resolve blockers on Craft 5:
   - Craft must be on the latest 5.x (the tool refuses anything below 5.9.0). Update with `php craft update all` or Composer, run `php craft up`, and commit.
   - Plugins: list each one with whether a Craft 6 release exists (check its Packagist versions for a `craftcms/cms ^6` requirement). During the alpha most don't. Options per plugin: wait, remove it, replace it with Laravel configuration (filesystem, mailer and logging plugins are obsolete), or disable it for the upgrade with `CRAFT_DISABLED_PLUGINS="*"`. A plugin without a 6.x release will block `composer update` in Stage 2, so decide now.
   - Categories, tags and global sets will be entrified (converted to entries) during the upgrade. If the developer wants control over that, run the `entrify/*` commands on 5.x first.
3. Prepare the 5.x site, using the project's normal CLI:
   - `php craft project-config/apply` (so files and DB agree), then `php craft queue/run` until the queue is empty: the queue table is rebuilt during the upgrade and pending jobs are lost.
   - Resolve outstanding deprecation warnings (Utilities > Deprecation Warnings, or the `deprecationerrors` table).
   - Note the email transport settings (Settings > Email) and every filesystem; both move to Laravel config.
   - Back up the database (`php craft db/backup`) and commit or copy the code.
4. Agree the end state (A or B) and the plugin decisions with the developer.

**Exit:** preflight shows no blockers, the queue is empty, a DB backup and a clean commit exist, and the plan is written down.
**Checkpoint:** present the preflight summary, the plugin decisions and the end state. Get agreement before running the tool.

## Stage 1: Run the upgrade tool

**Goal:** the project's files are in the Craft 6 layout. Nothing has been installed or migrated yet.
**References:** [references/what-the-tool-does.md](references/what-the-tool-does.md)

1. Install `craftcms/craft6-revamp` with **PHP 8.2 or newer** on the host. Either globally (`composer global require craftcms/craft6-revamp -W`) or, to leave the global Composer alone, into a throwaway directory: `composer require --working-dir=/tmp/craft6-revamp craftcms/craft6-revamp`, then run `/tmp/craft6-revamp/vendor/bin/craft6-revamp`. With DDEV it runs on the host, not in the container (the container is still on the old PHP).
2. Run it against the project root: `craft6-revamp /path/to/project`, or from the project root with no argument. The path is a **positional argument**, not `--path` (the README is wrong).
3. The tool asks two questions: whether to rename the web root to `public/` (say yes, unless something outside the repo depends on the old name), and whether to proceed (it replaces `index.php` and deletes `bootstrap.php`). **Without a TTY, as when an agent runs it, Laravel Prompts accepts the default for every question, which is "yes".** Get the developer's agreement before running it non-interactively.
4. Save the tool's **Next steps** table: it is project-specific (filesystem disk suggestions, `@web`/`@webroot` aliases, removed settings, `loginPath`).
5. Review the diff (`git status`, `git diff`). Expect: `composer.json` changes, new `artisan`, `bootstrap/app.php`, `bootstrap/cache/`, `storage/framework/*`, Laravel config files in `config/`, Craft config moved to `config/craft/`, `templates/` to `resources/views/`, `translations/` to `lang/`, `web/` to `public/`, a new `public/index.php`, `.env` variables renamed, and `craft` and `bootstrap.php` deleted.

**Exit:** the tool finished every step, and the diff matches the list above.
**Checkpoint:** show the diff summary and the tool's Next steps. Commit ("Run craft6-revamp").

## Stage 2: Install Craft 6 and migrate

**Goal:** Craft 6 is installed, the database is migrated, and the CLI works.

1. Apply the Stage 0 plugin decisions in `composer.json` (remove or bump plugins, remove `yiisoft/yii2-shell`) **before** updating. Make sure Composer runs on PHP 8.5 (with DDEV, `ddev restart` first so the container switches to PHP 8.5 and the `laravel` project type).
2. Fix the config that would stop the app from booting, because the `post-autoload-dump` scripts boot it during `composer update` (see [references/known-issues.md](references/known-issues.md)). At minimum, set `@webroot` in `config/craft/general.php` to `public_path()`, and remove `omitScriptNameInUrls` and `pathParam`.
3. `composer update -W`. The `post-autoload-dump` scripts the tool added run `package:discover` and `craft:setup:publish`, which publishes the control panel assets and recreates the `craft` executable. If a script fails, fix the cause and rerun `composer update` or the failing command; don't move on with a half-installed vendor directory.
4. `php artisan key:generate` (sets `APP_KEY` in `.env`). Laravel needs it for encryption and sessions, and it replaces `CRAFT_SECURITY_KEY`, which the tool deleted.
5. Run `php artisan craft:setup:publish` if the Composer scripts didn't.
6. Run the migrations: `php artisan craft:up`. It backs up the database first (`--noBackup` skips that). "Application in production" warnings are expected when `APP_DEBUG` is off.
7. If the site uses project config: `php artisan craft:project-config:apply` should report no changes.

**Exit:** `composer update` succeeded, `php artisan craft:up` reports nothing left to run, `php artisan list` lists the `craft:*` commands, and `php craft` works.
**Checkpoint:** report what ran, any errors and how they were fixed. Commit ("Install Craft 6").

## Stage 3: Fix the configuration and verify the site

**Goal:** the site works on Craft 6 with the adapter, and the developer knows what is left.
**References:** [references/after-upgrade.md](references/after-upgrade.md), [references/docs/compatibility.md](references/docs/compatibility.md)

1. Work through the tool's Next steps and the preflight WARN lines that apply now: general config settings that were removed or moved, `loginPath`, multi-environment config, `db.php`, filesystems to `config/filesystems.php` disks, the email transport to `config/mail.php`, `.env.example*` files, and deploy scripts. [references/after-upgrade.md](references/after-upgrade.md) has the details for each.
2. Compare the project with the Craft 6 starter project (https://github.com/craftcms/craft/tree/6.x) for files the tool does not create: `routes/web.php`, `routes/console.php`, `app/Providers/AppServiceProvider.php`, `bootstrap/providers.php`, `.gitignore` entries. Add them when the project needs them (the starter's versions are a safe default), and tell the developer why.
3. Verify, and record the evidence ([references/after-upgrade.md](references/after-upgrade.md#verification)):
   - the front end: the home page and a sample of entry URLs return 200 and render;
   - the control panel: the login page renders, a user can sign in, and the dashboard, an entry edit page and Settings load;
   - saving an entry works;
   - the queue runs (`php artisan queue:work --once` or `php craft queue:run`);
   - email sends (`php artisan craft:mailer:test`), if a mailer is configured;
   - `storage/logs/` has no new errors.
4. List the new deprecation warnings (Utilities > Deprecation Warnings, or the `deprecationerrors` table). They are Stage 4's to-do list.

**Exit:** every check in step 3 passes, or fails for a reason that is documented and agreed.
**Checkpoint:** report what works, what was changed, and the deprecation list. For end state A, this is the end: write the final report (below). Commit ("Fix Craft 6 configuration"). Ask whether to continue to Stage 4.

## Stage 4: Clear deprecations and remove the adapter (end state B only)

**Goal:** the project runs without `craftcms/yii2-adapter`.
**References:** [references/after-upgrade.md](references/after-upgrade.md#removing-the-adapter), [references/docs/compatibility.md](references/docs/compatibility.md)

1. Check that nothing else requires the adapter: `composer why craftcms/yii2-adapter` should list only the project. If a plugin requires it, stop: end state B isn't possible until that plugin drops it. Say so.
2. Modernize what only the adapter supports: multi-environment and app-type config, `config/craft/app.php` components, `config/craft/routes.php` (to `routes/web.php`), custom HTMLPurifier configs (to HtmlSanitizer), and templates that use `craft.app`, `view.*`, Yii flashes and the deprecated filters. Modules move into `app/` as Laravel service providers (the `craft-6-plugin-upgrade` skill covers the code).
3. Clear the deprecation warnings table, exercise the site again (Stage 3, step 3), and confirm no new warnings are logged.
4. Ask the developer to confirm, then `composer remove craftcms/yii2-adapter`. Confirm `composer show yiisoft/yii2` reports it is not installed.
5. Repeat the Stage 3 verification, and run `php artisan craft:up` again.

**Exit:** the adapter and `yiisoft/yii2` are not installed, and every Stage 3 check passes.
**Checkpoint:** final report.

## Final report

End with a short report for the developer:

- the end state reached, and the Craft, adapter and PHP versions installed;
- what changed, stage by stage, with the commits;
- what was verified, and how (commands, URLs, status codes);
- anything left: remaining deprecations, plugins not yet upgraded, config translated by hand that needs a second look, deploy changes (paths, PHP 8.5, `artisan` commands, queue worker or scheduler), and anything unverified;
- any gotcha not already in [references/known-issues.md](references/known-issues.md), so it can be added.

## Reference map

| Topic | Reference |
| --- | --- |
| Pitfalls, and where the docs, the tool and the code disagree | [known-issues.md](references/known-issues.md) |
| Each step the tool performs, and doing it by hand | [what-the-tool-does.md](references/what-the-tool-does.md) |
| Config, env vars, mail, filesystems, templates, routes, modules, deploys, verification, removing the adapter | [after-upgrade.md](references/after-upgrade.md) |
| DDEV, plain PHP, Docker, running a local server | [environments.md](references/environments.md) |
| Official docs snapshot | [docs/INDEX.md](references/docs/INDEX.md) |
