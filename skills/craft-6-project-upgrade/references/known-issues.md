# Known issues and gotchas

Failures of the stock upgrade path, and places where the docs, the `craft6-revamp` tool and Craft disagree. Each was reproduced by upgrading a clean Craft 5.11.5.1 project with craft6-revamp 1.2.0, and checked against two Craft builds:

- **alpha.20**: `craftcms/cms` and `craftcms/yii2-adapter` 6.0.0-alpha.20 (tagged 7 Oct 2026).
- **6.x-dev**: `craftcms/cms` 6.x-dev at `3af9d57` and `craftcms/yii2-adapter` 6.x-dev at `d3ebc14` (29 Oct 2026).

Find the installed version (and commit, for `-dev`) in `composer.lock`. For a newer build, assume the 6.x-dev column, then check: skip workarounds for issues that no longer happen, and add what you find.

## Issues by version

| Issue | alpha.20 | 6.x-dev | What to do |
| --- | --- | --- | --- |
| `composer update` fails: `craftcms/generator 3.x-dev requires craftcms/cms ^5.8.0` | Broken (Packagist, before 29 Oct) | Fixed: `3.x-dev` now requires `craftcms/cms ^6.0` | Check the constraint; remove the package if it still requires Craft 5. The 6.x starter doesn't include it. |
| Every control panel page returns 500: `Table '<db>.jobs' doesn't exist`. Craft drops the Yii `queue` table and nothing creates Laravel's `jobs`, `job_batches` and `failed_jobs`. | Broken | Fixed (`c76f361`): `craft:up` creates them, plus cache, sessions and other support tables, when missing | Run `craft:up`, then check. Only if `jobs` is missing, copy the 6.x starter's `0001_01_01_000002_create_jobs_table.php` and `php artisan migrate --force`. Adding it when the tables exist fails with `Table 'jobs' already exists`. |
| Stock Craft 5 welcome page (`resources/views/index.twig`) returns 500: `The file or directory to be published does not exist: .../installer/dist` | Broken | Fixed (`c7f67b4`) | On alpha.20, replace it with the 6.x starter's `index.twig`. Either way, replace it before removing the adapter: it uses `view.*`. |
| System email fails: `Filter "e" is not allowed` (alpha.20) or `Filter "escape" is not allowed` (6.x-dev). The stock Craft 5 `twig-sandbox.php` has empty `allowed*` lists, and Craft 6 lets them **replace** the default allow-lists instead of extending them. | Broken | Broken at `3af9d57`; fixed by `7c6ece5` ([#20159](https://github.com/craftcms/cms/pull/20159)), where project lists extend the defaults as in Craft 5 | Before that fix: delete the stock file before `composer update`; publishing restores Craft 6's defaults. For a customized file, copy `vendor/craftcms/cms/config/twig-sandbox.php` and re-add the project's entries. Don't disable the sandbox. |
| About a dozen `Ambiguous class resolution` warnings during `composer update`: the same `Legacy*` traits ship in `craftcms/cms` and the adapter | Present | Present (fix in progress) | Harmless for now; they go away when the adapter is removed. Don't add autoload exclusions. |
| Deprecation warnings that the adapter raises itself: `Craft::$app->fields`, `generalConfig.isSystemLive`, `generalConfig.generateTransformsBeforePageLoad` | Present; they come back after clearing even on a clean project | Fixed (`43d1474`) | On alpha.20, treat them as adapter-internal (Stage 4). They don't block removing the adapter. |
| `php craft queue:run`: `An option named "verbose" already exists`. `craft:queue:info` queries the dropped `queue` table, and rejects `--no-interaction`. | Broken | Broken (fix in progress) | Use Laravel's `php artisan queue:work --stop-when-empty`, `queue:failed`, and the `jobs`/`failed_jobs` tables. |
| Entry editor: the default **Save** saves and redirects, but the browser logs `TypeError: Cannot read properties of undefined (reading 'element')` in `rebase`, from `onSuccess`. "Save and continue editing" is fine. | Not seen | Broken, with and without the adapter (fix in progress) | Data is saved. Record it as a known Craft bug, not an upgrade failure. |
| After a CP login, Craft redirects to the front end instead of the dashboard | Seen | Not seen (goes to the dashboard) | Navigate to the dashboard explicitly when it happens. |

## Config the tool leaves broken (all versions so far)

- **`@webroot`**: the stock `general.php` sets `'@webroot' => dirname(__DIR__) . '/web'`. After the move to `config/craft/`, `dirname(__DIR__)` is `config/`. Use `public_path()` (as the 6.x starter does). The tool only mentions it when it renames the web root.
- **`enableTwigSandbox()`** (in the stock `general.php`): every boot logs `Method craft\config\GeneralConfig::enableTwigSandbox() is deprecated ... The Twig sandbox is always enabled for untrusted templates.` Remove the call.
- **`omitScriptNameInUrls()`, `pathParam()`**: no longer used. Remove. The tool's Next steps say so.
- **`APP_ENV`, `APP_URL`**: the tool sets neither, so Laravel runs as `production` even with `APP_DEBUG=true`, and Artisan asks for confirmation before migrating.
- **`.env.example*` files** aren't updated, and the stock `.env.example.dev` has no database settings at all. Rewrite them with the new names: `APP_ENV`, `APP_URL`, `APP_DEBUG`, `APP_KEY=`, `DB_CONNECTION`, `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`, `DB_SCHEMA`, `DB_TABLE_PREFIX`, `CACHE_STORE`, `SESSION_DRIVER`, `MAIL_MAILER`.
- **`.gitignore`**: add `/public/vendor/craft` (published control panel assets), `/public/storage`, `/storage/*.key` and `*.log`, as in the 6.x starter, before the first `composer update`.
- **`yiisoft/yii2-composer` in `config.allow-plugins`**: still needed while the adapter is installed. Removing it early makes Composer stop with `yiisoft/yii2-composer contains a Composer plugin which is blocked by your allow-plugins config`. Remove it after the adapter.

## Behavior to expect

- **Publishing restores config files.** `craft:setup:publish` (run by Composer's `post-autoload-dump`) copies Craft's default `config/craft/{general,redirects,routes,twig-sandbox}.php` wherever the file doesn't exist. Deleting one isn't durable: it comes back with Craft 6's defaults, which is usually what you want. It never overwrites an existing file.
- **A failed migration can leave maintenance mode on.** `storage/framework/down` stays after the fix and a clean `craft:up`. Run `php artisan up`.
- **The tool answers "yes" to everything without a TTY.** Laravel Prompts return the default when STDIN isn't interactive, and the defaults are "rename to public/" and "proceed".
- **The tool needs PHP 8.2+ on the host** and pulls `illuminate/*` 12.x into the global Composer. Install it into a throwaway directory to avoid conflicts.
- **`yiisoft/yii2-shell`** is in the stock Craft 5 `require-dev`. Remove it; use `laravel/tinker`.
- **`php -S host:port -t public public/index.php`**: passing `index.php` as the router sends CSS and JS requests through Craft, so control panel scripts fail and logins fail with `Unable to verify your data submission`. Use `php artisan serve`, or `php -S` without a router. Same on Craft 5 with `web/`.

## Docs, tool and code disagree

| Topic | Docs say | Tool or code does | Follow |
| --- | --- | --- | --- |
| Publishing after `composer update` | `artisan vendor:publish --tag=craftcms` (fix pending in craftcms/docs) | `artisan craft:setup:publish`, also added to `post-autoload-dump` | `craft:setup:publish` |
| `APP_KEY` | Not mentioned (fix pending) | Tool adds an empty `APP_KEY`; Next steps say `artisan key:generate` | Run `key:generate` |
| Tool path option | README: `craft6-revamp --path /path` (fix pending) | Positional argument: `craft6-revamp /path` | Positional argument |
| Table prefix variable | `CRAFT_DB_TABLE` → `DB_TABLE_PREFIX` (fix pending) | Tool renames `CRAFT_DB_TABLE_PREFIX` | `CRAFT_DB_TABLE_PREFIX` |
| Queue tables | The `migrate_to_laravel_queue` migration says they're "provisioned separately" | From 6.x-dev, `craft:up` creates them; on alpha.20 nothing does | See the table above |
| Project scaffold | Starter has `routes/web.php`, `routes/console.php`, `app/Providers/AppServiceProvider.php`, `bootstrap/providers.php` | Tool's `bootstrap/app.php` only registers the `/up` health route, and creates none of those | Add what the project needs |
