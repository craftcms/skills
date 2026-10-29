# Known issues and gotchas

Confirmed failures of the stock upgrade path, and the places where the docs, the `craft6-revamp` tool and the Craft 6 code disagree. "Confirmed" means it reproduced in an upgrade of a clean Craft 5.11.5.1 project to `craftcms/cms` 6.0.0-alpha.20 with craft6-revamp 1.2.0. Re-check entries against newer versions before relying on them, and add new ones as you find them.

## Blocks the upgrade

| Symptom | Cause | Fix | When |
| --- | --- | --- | --- |
| `composer update` fails: `craftcms/generator 3.x-dev requires craftcms/cms ^5.8.0 ... conflicts with your root composer.json require (^6.0.0-alpha.1)` | The tool rewrites `craftcms/generator` to `3.x-dev`, which still requires Craft 5. No published version supports Craft 6. | Remove `craftcms/generator` from `composer.json` (the 6.x starter doesn't include it). Check Packagist for a Craft 6-compatible version first. | Stage 2, before `composer update`. Confirmed. |
| Every control panel page returns 500: `SQLSTATE[42S02] ... Table '<db>.jobs' doesn't exist ... select count(*) as aggregate from jobs where queue = default`. `php artisan migrate:status` says `No migrations found`. | Craft's `migrate_to_laravel_queue` migration drops the old `queue` table and creates `jobprogress`, but leaves Laravel's `jobs`, `job_batches` and `failed_jobs` to the app. The tool creates no app migrations. | Copy the 6.x starter's `database/migrations/0001_01_01_000002_create_jobs_table.php` (or `php artisan make:queue-table`), then `php artisan migrate --force`. Same for cache and session tables when those drivers are `database`. | Stage 2, after `craft:up`. Confirmed on alpha.20; fixed on 6.x after it (craftcms/cms c76f361), where `craft:up` creates the tables. Don't add the starter migration if they exist. |
| Front-end home page returns 500: `The file or directory to be published does not exist: .../yii2-adapter/legacy/web/assets/installer/dist` at `index.twig:125` | The stock Craft 5 welcome template calls `view.getAssetManager().getPublishedUrl('@app/web/assets/installer/dist', ...)`. Fails even with the adapter. | Fixed on 6.x after alpha.20 (craftcms/cms c7f67b4). On alpha.20, replace `resources/views/index.twig` with the 6.x starter's if it is still the placeholder. | Stage 2. Confirmed on alpha.20 only. |
| `craft:mailer:test` and every system email fail: `Filter "e" is not allowed in "__string_template__..."` | The stock Craft 5 `config/twig-sandbox.php` has empty `allowed*` arrays, documented as "extends the defaults". Craft 6 merges it with Laravel's `mergeConfigFrom()`, which is shallow, so the empty arrays **replace** the default allow-lists. | Delete the stock file before `composer update`; `craft:setup:publish` publishes Craft 6's full defaults. For a customized file, copy `vendor/craftcms/cms/config/twig-sandbox.php` and re-add the project's additions. Don't disable the sandbox. | Stage 2. Confirmed. |

## Config that breaks or warns on boot

- **`@webroot`**: the stock `general.php` sets `'@webroot' => dirname(__DIR__) . '/web'`. After the move to `config/craft/`, `dirname(__DIR__)` is `config/`. Use `public_path()` (as the 6.x starter does). The tool only mentions the alias when it renames the web root. Confirmed.
- **`enableTwigSandbox()`** (in the stock `general.php`): every boot logs `Method craft\config\GeneralConfig::enableTwigSandbox() is deprecated ... The Twig sandbox is always enabled for untrusted templates.` Remove the call. Confirmed.
- **`omitScriptNameInUrls()`, `pathParam()`**: no longer used. Remove. The tool's Next steps say so.
- **`APP_ENV`**: the tool doesn't set it (or `APP_URL`), so Laravel runs as `production` even with `APP_DEBUG=true`, and Artisan asks for confirmation before migrating. Set both in `.env` in Stage 2. Confirmed.
- **Publishing restores config files.** `craft:setup:publish` (run by Composer's `post-autoload-dump`) copies Craft's default `config/craft/{general,redirects,routes,twig-sandbox}.php` wherever the file doesn't exist. Deleting one of them isn't durable; it comes back with Craft 6's defaults, which is usually what you want. It never overwrites an existing file. Confirmed.

## Expected noise, not errors

- **About a dozen "Ambiguous class resolution" warnings** during `composer update` while the adapter is installed: the same trait classes ship in `craftcms/cms` and `craftcms/yii2-adapter`. Install succeeds, and they disappear after the adapter is removed. Don't add autoload exclusions. (alpha.20)
- **Adapter-internal deprecation warnings** that come back after the project is clean, with every trace frame inside `vendor/craftcms/yii2-adapter`: `Craft::$app->fields` (`ApplicationTrait.php`), `generalConfig.isSystemLive` and `generalConfig.generateTransformsBeforePageLoad` (the adapter's `GeneralConfig.php`). They stop once the adapter is removed, so they don't block Stage 4. (Confirmed in two runs on alpha.20; fixed on 6.x after alpha.20 by craftcms/cms 43d1474, so later versions shouldn't log them.)
- **Login redirects to the front end**, not the dashboard, on Craft 6. Navigate to the dashboard explicitly. Navigating away immediately after submitting the login form can cancel the login: wait for the URL to leave the login page.

## Docs, tool and code disagree

| Topic | Docs say | Tool or code does | Follow |
| --- | --- | --- | --- |
| Publishing after `composer update` | `artisan vendor:publish --tag=craftcms` (fix pending in craftcms/docs) | `artisan craft:setup:publish`, also added to `post-autoload-dump`. It publishes the `craftcms-assets`, `craftcms-config` and `craftcms-console` tags plus plugin assets. | `craft:setup:publish` |
| `APP_KEY` | Not mentioned (fix pending) | Tool adds an empty `APP_KEY` and its Next steps say `artisan key:generate` | Run `key:generate` |
| Tool path option | README: `craft6-revamp --path /path` (fix pending) | Positional argument: `craft6-revamp /path` | Positional argument |
| Table prefix variable | `CRAFT_DB_TABLE` → `DB_TABLE_PREFIX` (fix pending) | Tool renames `CRAFT_DB_TABLE_PREFIX` | `CRAFT_DB_TABLE_PREFIX` |
| Queue tables | Not mentioned | Craft leaves `jobs`/`failed_jobs` to the app; the tool doesn't create them | Add the migration (above) |
| Project scaffold | Starter has `routes/web.php`, `routes/console.php`, `app/Providers/AppServiceProvider.php`, `bootstrap/providers.php`, `database/migrations/` | Tool's `bootstrap/app.php` only registers the `/up` health route, and creates none of those | Add what the project needs |

## Commands that don't work

- `php craft queue:run` (legacy syntax through the new `craft` entry point): `An option named "verbose" already exists`. `craft:queue:info` queries the dropped `queue` table. Use Laravel's `php artisan queue:work --stop-when-empty`, `queue:failed`, and the `jobs`/`failed_jobs` tables. (alpha.20, adapter installed)
- `php -S host:port -t public public/index.php`: passing `index.php` as the router sends CSS and JS requests through Craft, so control panel scripts fail (`Unexpected token '<'`, `$ is not defined`) and logins fail with `Unable to verify your data submission`. Use `php artisan serve`, or `php -S` without a router. Same on Craft 5 with `web/`.

## Other gotchas

- **The tool answers "yes" to everything without a TTY.** Laravel Prompts return the default when STDIN isn't interactive, and the defaults are "rename to public/" and "proceed".
- **The tool needs PHP 8.2+ on the host** and pulls `illuminate/*` 12.x into the global Composer. Install it into a throwaway directory if the global install conflicts.
- **`yiisoft/yii2-shell`** is in the stock Craft 5 `require-dev`. Remove it; use `laravel/tinker`.
- **`.env.example*` files are not updated** by the tool, and the stock `.env.example.dev` has no database settings at all. Rewrite them with the new names: `APP_ENV`, `APP_URL`, `APP_DEBUG`, `APP_KEY=`, `DB_CONNECTION`, `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`, `DB_SCHEMA`, `DB_TABLE_PREFIX`, `CACHE_STORE`, `SESSION_DRIVER`, `MAIL_MAILER`.
- **`.gitignore`** from Craft 5 doesn't cover Craft 6 build output. Add `/public/vendor/craft` (published control panel assets), `/public/storage`, `/storage/*.key` and `*.log`, as in the 6.x starter.
