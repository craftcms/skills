# Known issues and gotchas

Pitfalls found while upgrading projects with this skill, and the places where the docs, the `craft6-revamp` tool and the Craft 6 code disagree. Each entry names the versions it was seen with. Re-check entries against newer versions before relying on them, and add new ones as you find them.

## Docs, tool and code disagree

| Topic | Docs say | Tool or code does | Follow |
| --- | --- | --- | --- |
| Publishing after `composer update` | `artisan vendor:publish --tag=craftcms` | Tool's Next steps say `artisan craft:setup:publish`, and the tool adds it to `post-autoload-dump`. The command publishes the `craftcms-assets`, `craftcms-config` and `craftcms-console` tags plus plugin assets. | `craft:setup:publish` |
| `APP_KEY` | Not mentioned | Tool adds an empty `APP_KEY` and its Next steps say `artisan key:generate` | Run `key:generate` |
| Tool path option | README: `craft6-revamp --path /path` | The command takes a positional `path` argument (`craft6-revamp /path`) | Positional argument |
| Table prefix variable | `CRAFT_DB_TABLE` → `DB_TABLE_PREFIX` | Tool renames `CRAFT_DB_TABLE_PREFIX`, not `CRAFT_DB_TABLE` | Check both by hand |
| Composer constraint | `^6.0.0-alpha.1` | The 6.x starter project requires `craftcms/cms: ^6.0.0` and `laravel/framework: ^13.17` with `minimum-stability: dev` and `prefer-stable: true` | Tool's constraint is fine during the alpha |
| Project scaffold | Starter project has `routes/web.php`, `routes/console.php`, `app/Providers/AppServiceProvider.php`, `bootstrap/providers.php` | Tool's `bootstrap/app.php` only registers the `/up` health route, and creates none of those files | Add them from the starter when needed |

## Pitfalls

- **`@webroot` breaks when config moves.** The stock Craft 5 `general.php` sets `'@webroot' => dirname(__DIR__) . '/web'`. After the move to `config/craft/`, `dirname(__DIR__)` is `config/`, so the alias points at `config/web`. The tool only mentions the alias when it renames the web root. Replace it with `public_path()` (as the 6.x starter does), and check `@web` too. (craft6-revamp 1.2.0)
- **The tool answers "yes" to everything without a TTY.** It uses Laravel Prompts, which return the default when STDIN is not interactive, and the defaults are "rename to public/" and "proceed". (craft6-revamp 1.2.0)
- **The tool needs PHP 8.2+ on the host** and pulls `illuminate/*` 12.x into the global Composer. Install it into a throwaway directory if the global install conflicts.
- **The stock Craft 5 `templates/index.twig` (the welcome page) uses `view.getAssetManager()`** to publish installer images. Expect it to break or log a deprecation; it is placeholder content and can be replaced with the 6.x starter's `resources/views/index.twig`. (Unverified on 6.0.0-alpha.20.)
- **`yiisoft/yii2-shell`** is in the stock Craft 5 `require-dev`. It has no Craft 6 equivalent; remove it and use `laravel/tinker`.
- **`.env.example*` files are not updated** by the tool. Rename the variables in them by hand to match `.env`.
