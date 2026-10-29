# Environments

## DDEV

The recommended setup. Run PHP tools through DDEV so they use the container's PHP:

| Craft 5 | Craft 6 |
| --- | --- |
| `ddev composer ...` | `ddev composer ...` |
| `ddev craft ...` | `ddev artisan ...` or `ddev php craft ...` |

- `craft6-revamp` runs on the host (it only edits files), or in a throwaway Docker container (see [docs/upgrade.md](docs/upgrade.md#performing-the-upgrade)).
- After the tool changes `.ddev/config.yaml` (`type: laravel`, `php_version: "8.5"`, `docroot: public`), run `ddev restart` before `ddev composer update`. The `laravel` project type means `ddev craft` no longer exists: use `ddev artisan` or `ddev php craft`.
- DDEV sets database variables itself for the `laravel` type, so check `.ddev/.env*` and `.env` don't conflict.
- `ddev launch` opens the site, and Mailpit (`ddev mailpit`) catches email from the default mail config.

## Plain PHP (no DDEV)

- Craft 6 needs PHP 8.5 with the extensions in [docs/requirements.md](docs/requirements.md). Check with `php -v` and `php -m`. If several PHP versions are installed, call the 8.5 binary explicitly (`php8.5 artisan ...`, `php8.5 $(which composer) update`).
- The database server must be running, and `.env` `DB_*` values must reach it (`DB_HOST=127.0.0.1` rather than `localhost` avoids socket surprises with MySQL).
- Local server: `php artisan serve` (Laravel's development server), or `php -S 127.0.0.1:8000 -t public public/index.php`. Set `APP_URL` and the site's base URL (often `PRIMARY_SITE_URL` in `.env`) to the URL you serve on, or links and control panel assets will point elsewhere.

## Docker or another container setup

Treat it like DDEV: run Composer and Artisan inside the container, and switch the image to PHP 8.5 and the docroot to `public/` before `composer update`.
