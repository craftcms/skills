# Environments

## DDEV

The recommended setup. Run PHP tools through DDEV so they use the container's PHP:

| Craft 5 | Craft 6 |
| --- | --- |
| `ddev composer ...` | `ddev composer ...` |
| `ddev craft ...` | `ddev artisan ...` or `ddev php craft ...` |

- `craft6-revamp` runs on the host (it only edits files), or in a throwaway Docker container (see [upgrade docs](https://craftcms.com/docs/6.x/upgrade.html#performing-the-upgrade)).
- After the tool changes `.ddev/config.yaml` (`type: laravel`, `php_version: "8.5"`, `docroot: public`), run `ddev restart` before `ddev composer update`. The `laravel` project type means `ddev craft` no longer exists: use `ddev artisan` or `ddev php craft`.
- DDEV sets database variables itself for the `laravel` type, so check `.ddev/.env*` and `.env` don't conflict.
- `ddev launch` opens the site, and Mailpit (`ddev mailpit`) catches email from the default mail config.

## Laravel Herd or Valet

Both serve sites on the host's PHP, so the PHP version is per site:

| | Herd | Valet |
| --- | --- | --- |
| Use PHP 8.5 for this site (run in the project root) | `herd isolate 8.5` | `valet isolate php@8.5` |
| Run PHP or Composer with the site's PHP | `herd php artisan ...`, `herd composer ...` | `valet php artisan ...`, `valet composer ...` |
| Check which PHP the site uses | `herd which-php` | `valet which-php` |

- Isolate the site to PHP 8.5 after the Stage 0 baseline and before `composer update`, and use the `herd`/`valet` proxies for every PHP and Composer command from then on. The plain `php` on the PATH is the global version, which may not be 8.5.
- `craft6-revamp` needs PHP 8.2 or newer and runs on any PHP the host has.
- No web server config changes are needed. Valet serves a project with the Laravel driver once `public/index.php` and `artisan` both exist, which is the case after the tool runs, and before that with its Craft driver from `web/`. Herd builds on Valet, so expect the same, but this is only checked against Valet's source. If the web root wasn't renamed to `public/`, the Laravel driver won't match: rename it, or add a custom driver.
- The site URL stays `http(s)://<folder>.test`. Keep `APP_URL` and the site base URLs on that host, with `https` if the site is secured (`herd secure` / `valet secure`).
- The database runs separately: Herd Pro services, DBngin, or Homebrew. Check `DB_HOST`, `DB_PORT` and the socket in `.env`. Herd Pro also catches mail; otherwise use the `log` mailer while testing.

## Plain PHP

- Craft 6 needs PHP 8.5 with the extensions in the [requirements docs](https://craftcms.com/docs/6.x/requirements.html). Check with `php -v` and `php -m`. If several PHP versions are installed, call the 8.5 binary explicitly (`php8.5 artisan ...`, `php8.5 $(which composer) update`).
- The database server must be running, and `.env` `DB_*` values must reach it (`DB_HOST=127.0.0.1` rather than `localhost` avoids socket surprises with MySQL).

## Docker or another container setup

Treat it like DDEV: run Composer and Artisan inside the container, and switch the image to PHP 8.5 and the docroot to `public/` before `composer update`.

## Running a local server

With Herd or Valet the site is already served at `<folder>.test`. Otherwise, use Laravel's development server on Craft 6: `php artisan serve --host=127.0.0.1 --port=8000`. On Craft 5 (the baseline), use `php -S 127.0.0.1:8000 -t web` **without** a router script: passing `web/index.php` (or `public/index.php`) as the router sends CSS and JS through Craft, which breaks control panel scripts and logins.

Set `APP_URL` and the site's base URL (often `PRIMARY_SITE_URL` in `.env`) to the exact URL, port included, that you serve on, or links, redirects and control panel assets will point elsewhere. For a long-running server, use the environment's service manager rather than a backgrounded shell process.
