# After the upgrade: configuration, verification, removing the adapter

The official version of most of this is [docs/compatibility.md](docs/compatibility.md). This page is the working checklist. Items marked **adapter only** keep working while `craftcms/yii2-adapter` is installed, and must be changed before it is removed (Stage 4). The rest need attention in Stage 3.

## Configuration

Craft's own config files now live in `config/craft/`. Laravel's live in `config/` and read `.env`.

- **`config/craft/general.php`**
  - Paths: `dirname(__DIR__)` now means `config/`. Use Laravel path helpers: `base_path()`, `public_path()`, `storage_path()`. Set `'@webroot' => public_path()`.
  - Remove `omitScriptNameInUrls`, `pathParam` and `enableTwigSandbox` (no longer used; the sandbox is always on).
  - Moved to Laravel config: `timezone` (`config/app.php`), `defaultCookieDomain` (`config/session.php` `domain`), `phpSessionName` (`config/session.php` `cookie`), `blowfishHashCost` (`config/hashing.php`), `elevatedSessionDuration` (`config/auth.php` `password_timeout`), `testToEmailAddress` (`Mail::alwaysTo()` in a service provider, or the `log` mailer). `systemMessageTemplate` moved to Settings > Email.
  - `loginPath` now defaults to `false`. Set it if the site has a front-end login form.
  - Classes: the fluent `craft\config\GeneralConfig` keeps working through the adapter. The native class is `CraftCms\Cms\Config\GeneralConfig` (the 6.x starter uses it). Switching is part of Stage 4: change the `use` line, drop `use craft\helpers\App` if unused (use `env()`), and check each setting still exists on the native class.
  - Multi-environment arrays (`'*' => [...]`) and app-type files (`general.web.php`): **adapter only**. Flatten them using environment variables.
- **`config/craft/db.php`**: not read. Move settings to `.env` (`DB_*`) or `config/database.php`.
- **`config/craft/app.php`** (Yii components, modules, bootstrap): **adapter only**. Cache, session, queue, mutex and Redis config move to `config/cache.php`, `config/session.php`, `config/queue.php` and `config/database.php`. Modules become service providers.
- **`config/craft/routes.php`**: **adapter only**. Translate to `routes/web.php` (examples in [docs/compatibility.md](docs/compatibility.md#custom-rules)), and register the file in `bootstrap/app.php` `withRouting(web: ...)` as the 6.x starter does.
- **`config/craft/twig-sandbox.php`**: delete the stock Craft 5 file (empty lists) before `composer update`; see [known-issues.md](known-issues.md#blocks-the-upgrade). Customizations must now repeat Craft 6's default allow-lists, because the file replaces each list rather than extending it.
- **`config/craft/htmlpurifier/`**: replaced by Symfony HtmlSanitizer. Delete an unmodified `Default.json`. Translate custom configs to `config/craft/sanitizers/*.php` (check the directory name against the installed source: the docs spell it two ways).
- **Constants** set in the old `bootstrap.php` or `index.php` (`CRAFT_ENVIRONMENT`, `CRAFT_STORAGE_PATH`, ...): mostly gone. Use Laravel's `.env` and path helpers.

## Environment variables

- Check `.env`, `.ddev/.env*`, `.env.example*`, CI and hosting dashboards for the old names: `CRAFT_DB_*` → `DB_*`, `CRAFT_DEV_MODE` → `APP_DEBUG`, `CRAFT_SECURITY_KEY` removed, `APP_KEY` added (`php artisan key:generate`).
- `CRAFT_ENVIRONMENT` → Laravel uses `APP_ENV`. Set `APP_ENV` (e.g. `local`, `production`) and `APP_URL` in Stage 2; without `APP_ENV` Laravel assumes `production`.
- `.env.example*`: rewrite with the new names (list in [known-issues.md](known-issues.md#other-gotchas)).
- `.gitignore`: add `/public/vendor/craft`, `/public/storage`, `/storage/*.key`, `*.log`.
- `DB_CONNECTION` must be `mysql` or `pgsql`. Craft 5 used `mysql`/`pgsql` too, so the renamed value usually works.
- Keep other `CRAFT_*` variables used for general config overrides (`CRAFT_ALLOW_ADMIN_CHANGES`, ...); check each still applies against `CraftCms\Cms\Config\GeneralConfig`.

## Email

Configure a mailer in `config/mail.php` (`MAIL_MAILER`, `MAIL_HOST`, ... in `.env`) that matches the old Settings > Email transport. Sendmail → `sendmail`, SMTP → `smtp`, Mailgun/Postmark/SES → the Laravel transport (may need a Composer package). Test with `php artisan craft:mailer:test`. Password reset and verification emails are now queued, so a queue worker must run. If the old transport can't be reproduced locally, use `MAIL_MAILER=log` (or Mailpit) for development and keep the real settings for production in the deployment's `.env`.

## Filesystems and assets

Craft filesystems are gone. Each becomes a Laravel disk in `config/filesystems.php`, keyed by the filesystem's **handle**. The tool prints a suggestion for each. Local filesystems map to the `local` driver with `root` and `url`. Check that asset URLs still resolve after the web root rename (`@webroot`, `@web` in the filesystem's base path and URL).

## Templates

Templates live in `resources/views/`. The adapter keeps most Twig working. Before removing it:

- `craft.app.*` → facades (`Request.get()`, `Sites`, `Entries`, ...). See the table in [docs/compatibility.md](docs/compatibility.md#services).
- `view.*` (`registerJs`, `registerCssFile`, `getAssetManager`, ...) → `HtmlStack`, `include()`, `renderObjectTemplate()`.
- Filters: `filterByValue` → `where`, `firstWhere` with closures only, `index` → `collect(x).keyBy()`, `purify` → `sanitize`, `ucfirst` → `capitalize`.
- Front-end forms: errors come from the global `errors` (`errors.has('field')`, `errors.get('field')`), submitted values from `old('field')`.
- `craft.categories`, `craft.tags`, `craft.globalSets` and global set variables: the content was entrified. Query entries, or singles via the `Sections` facade.
- `where()`, `andWhere()`, `orWhere()` with Yii-style array conditions: Laravel query builder syntax.

## Modules

A Craft 5 module keeps working through the adapter. To modernize it, turn it into a Laravel service provider in `app/` (registered in `bootstrap/providers.php`). The `craft-6-plugin-upgrade` skill covers the code changes (events, services, controllers, templates).

## Deployment

Paths changed (`web/` → `public/`, `config/` → `config/craft/`, `storage/` gets `framework/`), PHP is 8.5, and the CLI is `php artisan` with `:` separators (`php craft` still works and accepts the old `/` syntax). Review the web server docroot, symlinked or persistent directories, deploy scripts, CI, cron jobs (consider Laravel's scheduler: `php artisan schedule:run` every minute) and queue workers (`php artisan queue:work`).

## Verification

Collect evidence, not impressions. Serve the site as described in [environments.md](environments.md#running-a-local-server), with `APP_URL` and the site's base URL (often `PRIMARY_SITE_URL`) matching.

- **CLI:** `php artisan about`, `php artisan list | grep craft:`, `php artisan craft:up` (nothing to run), `php artisan migrate:status` (all ran).
- **Front end:** `curl -s -o /dev/null -w '%{http_code} %{url_effective}\n' -L <url>` for the home page and sample entries. Check the HTML has the expected content, not an error page.
- **Control panel:** `/admin/login` (or the `cpTrigger`) returns 200. Sign in with a real browser (for example `agent-browser`), wait until the URL leaves the login page (Craft 6 may redirect to the front end), then open the dashboard, an entry and Settings and check each final URL. A 200 on `/admin/login` after a redirect is a failure. Use a fresh browser session for the final JavaScript error check; old errors persist in a session.
- **Saving:** edit an entry in the control panel, save, and read the value back from the database or the front end. Don't rely on the "Entry saved" toast alone.
- **Queue:** after a save, `SELECT COUNT(*) FROM jobs` is non-zero; `php artisan queue:work --stop-when-empty` processes the jobs (`DONE`) and stops; then `jobs` and `failed_jobs` are empty and `php artisan queue:failed` reports none. An empty `--once` run proves nothing. Don't use `php craft queue/run` or `craft:queue:info` (see [known-issues.md](known-issues.md#commands-that-dont-work)).
- **Mail:** `php artisan craft:mailer:test`. With `MAIL_MAILER=log` the message appears in `storage/logs/`; that proves templates render, not that mail is delivered.
- **Logs:** note the size of `storage/logs/laravel.log` (or the daily file) before verifying, and check only what was written after it for `ERROR`/`CRITICAL`.
- **Deprecations:** `SELECT message, file, line, traces FROM deprecationerrors` (with the table prefix), or Utilities > Deprecation Warnings. Read the `traces` column to see whose code raised each one.

### A test entry on an empty project

A fresh project has no sections, so there's nothing to save. Create, through the control panel or CLI:

1. An entry type (Settings > Entry Types). Keep the title field, or set a Default Title Format: an entry type without either can't be saved meaningfully.
2. A channel section using it, with an entry URI format (for example `news/{slug}`) and a template (for example `news/_entry`). `php artisan craft:sections:create --name=News --handle=news --type=channel --entryTypes=<handle> --uriFormat='news/{slug}' --template=news/_entry` does this from the CLI.
3. A minimal template at `resources/views/news/_entry.twig`, such as `<h1>{{ entry.title }}</h1>`.

Then create and save an entry, and request its URL.

## Removing the adapter

See [docs/compatibility.md](docs/compatibility.md#ejecting-the-adapter). In short: no plugin requires it (`composer why craftcms/yii2-adapter`), every **adapter only** item above is done, no project-owned deprecation warnings come back while the site is exercised (adapter-internal ones are expected, see [known-issues.md](known-issues.md#expected-noise-not-errors)), then `composer remove craftcms/yii2-adapter` and verify again. Expect errors from anything that still uses `craft\...` or Yii classes, including `config/craft/general.php` if it still uses `craft\config\GeneralConfig` or `craft\helpers\App`.
