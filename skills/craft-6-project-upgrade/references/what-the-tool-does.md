# What craft6-revamp does

`craftcms/craft6-revamp` (https://github.com/craftcms/craft6-revamp) moves a Craft 5 project into the Craft 6 layout. It does not install anything or touch the database. This page lists each step (as of 1.2.0, `src/RevampCommand.php`) so you can review its diff, finish a step it skipped, or do the upgrade by hand. The docs' manual steps are in [docs/upgrade.md](docs/upgrade.md#upgrading-manually).

## Checks before it changes anything

- `composer.json` and `composer.lock` exist, and the lock has `craftcms/cms` at 5.9.0 or later (a plain numeric version: a `dev-` or alias version fails).
- It finds the web root: the first of `public/`, `public_html/`, `web/`, `html/` with an `index.php`, otherwise the first non-vendor folder with an `index.php`.
- If the web root isn't `public/`, it asks whether to rename it. Then it warns that `index.php` will be replaced and `bootstrap.php` removed, and asks to proceed.

## Steps

| Step | What it does | By hand |
| --- | --- | --- |
| Update composer.json | `craftcms/cms` → `^6.0.0-alpha.1`; adds `craftcms/yii2-adapter: *`; `craftcms/generator` → `3.x-dev`; removes `vlucas/phpdotenv` and `config.platform.php`; adds `post-autoload-dump` scripts `Illuminate\Foundation\ComposerScripts::postAutoloadDump`, `@php artisan package:discover --ansi`, `@php artisan craft:setup:publish --ansi` | Same edits |
| Update DDEV | `type: laravel`, `php_version: "8.5"`, `docroot: public` (only when renaming) | Same edits, then `ddev restart` |
| Environment variables | In `.env`, `.ddev/.env`, `.ddev/.env.web`: `CRAFT_DB_DRIVER`→`DB_CONNECTION`, `CRAFT_DB_SERVER`→`DB_HOST`, `CRAFT_DB_PORT`→`DB_PORT`, `CRAFT_DB_USER`→`DB_USERNAME`, `CRAFT_DB_PASSWORD`→`DB_PASSWORD`, `CRAFT_DB_DATABASE`→`DB_DATABASE`, `CRAFT_DB_SCHEMA`→`DB_SCHEMA`, `CRAFT_DB_TABLE_PREFIX`→`DB_TABLE_PREFIX`, `CRAFT_DEV_MODE`→`APP_DEBUG`; removes `CRAFT_SECURITY_KEY`. In `.env` only, adds `CACHE_STORE=file`, `SESSION_DRIVER=file`, `APP_KEY=` | Same; other `CRAFT_*` variables (`CRAFT_ENVIRONMENT`, `CRAFT_APP_ID`, ...) are left alone |
| `artisan` | Creates Laravel's `artisan` (mode 0755) unless one exists | Copy from the 6.x starter |
| Bootstrap | `bootstrap/app.php` (routing with only `health: '/up'`; `usePublicPath()` if the web root keeps another name) and `bootstrap/cache/.gitignore` | Copy from the 6.x starter |
| Storage | `storage/framework/{cache,sessions,views}` with `.gitignore` files | `mkdir -p` and add `.gitignore` |
| Config | Moves everything in `config/` (including `project/`, `htmlpurifier/`, `license.key`) to `config/craft/`, unless `config/craft/` already exists | `mkdir config/craft && git mv` |
| Laravel config | Copies `app, auth, broadcasting, cache, concurrency, cors, database, filesystems, hashing, logging, mail, queue, services, session, view` into `config/` if missing | `php artisan config:publish` after install |
| Translations | `translations/` → `lang/` | `git mv` |
| Templates | `templates/` → `resources/views/` (asks, and renames an existing `resources/views/` to `views-old`) | `git mv` |
| Web root | Renames it to `public/` if agreed | `git mv`, update the web server and DDEV docroot |
| `index.php` | Replaces it with Laravel's front controller | Copy from the 6.x starter |
| `craft` | Deletes it; `craft:setup:publish` recreates it | Delete |
| `bootstrap.php` | Deletes it | Delete; move any customizations first |

## Next steps it prints

Project-specific, so save them. They can include: updating `@web`/`@webroot` aliases (only when it renamed the web root), removing `omitScriptNameInUrls` and `pathParam`, adding `loginPath` if there's a front-end login form, `ddev restart`, a Laravel disk config for each Craft filesystem, then `composer update`, `artisan craft:setup:publish` and `artisan key:generate`.
