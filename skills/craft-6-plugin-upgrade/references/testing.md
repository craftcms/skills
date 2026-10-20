# Setting up a host project and testing an upgrade

These recipes were used to upgrade a real plugin (`craftcms/guest-entries`) against `craftcms/cms` 6.0.0-alpha.20. Adapt names and URLs. They assume DDEV, as the Craft 6 install docs do.

## 1. Create a clean Craft 6 host

```bash
mkdir my-host && cd my-host
ddev config --project-type=laravel --docroot=public --php-version=8.5 --database=mysql:8.4
ddev start
ddev composer create-project "craftcms/craft:^6.0.0-alpha.1" --no-interaction
```

Without a terminal, `create-project` installs everything and then fails at its last step (`artisan craft:install`, which is interactive). Finish the install yourself:

```bash
ddev exec php artisan craft:install --no-interaction \
  --email=admin@example.test --username=admin --password=password123 \
  --siteName="Test" --siteUrl=https://my-host.ddev.site --language=en-US --timezone=UTC
```

Pass the real URL. A shell variable such as `$PRIMARY_SITE_URL` is expanded inside the container and fails.

## 2. Install the plugin from a path repository

DDEV only mounts the project directory, so clone the plugin inside it:

```bash
git clone <plugin repo> plugins/my-plugin
ddev composer config repositories.my-plugin path plugins/my-plugin
ddev composer require vendor/my-plugin:@dev -W
ddev artisan craft:plugin:install my-plugin
ddev artisan craft:plugin:list
```

To avoid pushing by accident, disable the clone's push URL: `git remote set-url --push origin DISABLED`.

After you change the plugin's own `composer.json` (for example removing the adapter), update the host:

```bash
ddev composer update vendor/my-plugin craftcms/yii2-adapter -W
```

## 3. Run PHP inside the app

Put the code in a file in the host project and run it with `--execute`:

```bash
ddev exec php artisan tinker --execute="include 'my-script.php';"
```

`artisan tinker my-script.php` opens an interactive prompt after the file runs and hangs in a non-interactive shell.

## 4. Test an action URL

Laravel needs a CSRF token. Get a session cookie from any page, then send the `XSRF-TOKEN` cookie value (URL-decoded) in an `X-XSRF-TOKEN` header:

```bash
U=https://my-host.ddev.site; J=$(mktemp)
curl -sk -c $J -o /dev/null $U/
TOK=$(grep XSRF-TOKEN $J | awk '{print $7}' | python3 -c "import sys,urllib.parse;print(urllib.parse.unquote(sys.stdin.read().strip()))")
curl -sk -b $J -c $J -X POST $U/actions/my-plugin/save \
  -H "X-XSRF-TOKEN: $TOK" -H "Accept: application/json" -d 'title=Hello'
```

A request without the token returns `419`. A 404 from the adapter's catch-all legacy route (`yii2-adapter/routes/web.php`) means the plugin is no longer a Yii module and the action has no native route yet.

## 5. Test the control panel settings page

Log in with the same cookie jar (`POST /admin/login` with `loginName` and `password`, `Accept: application/json`). Then:

- `GET /admin/settings/plugins/<handle>` returns the page. The form is JSON inside `<script data-page="app" type="application/json">...</script>`. Parse it to check the nodes, control paths and values.
- Save with JSON: `POST /admin/settings/plugins/<handle>` with `Content-Type: application/json`, the `X-XSRF-TOKEN` header, and a body like `{"settings": {...}}`. Expect `200` and a project config change under `plugins.<handle>.settings`.

On 6.0.0-alpha.20, a settings save that fails validation returns a 500 `TypeError` from `PluginsController::saveSettings()` (it returns a `CpScreenResponse` where `Response` is declared). The plugin's rule still fired; this is a Craft bug, not a problem with your rules.

## 6. Test a front-end form round trip

Create a Twig template in the host's `resources/views/` with the plugin's documented form (`csrfInput()`, `actionInput('<handle>/<action>')`, `redirectInput(...)`). Then:

- `GET` the page and read the `_token`, `action` and `redirect` hidden inputs.
- `POST` them back to the same page with `curl --data-urlencode ... -L`. Do **not** add `-X POST` when following redirects: curl would re-POST to the redirect target and get a `419`.
- A failed submission redirects back to the page. Check `old()`, `errors`, `session().get('error')` and `session().get('<entryVariable>')` in the rendered output.

## 7. Test events

Register throwaway listeners in the host's `app/Providers/AppServiceProvider.php` that append to a log file, then exercise each path (success, rejected by a listener, flagged as spam, unknown input) and check the log. Remove them afterwards.

## 8. Shell traps

- zsh treats `--include=*.php` as a glob and fails. Quote it, or use `rg -g '*.php'`.
- macOS has no `timeout` command.
- `composer why <package>` for a package that isn't installed prints its usage, not "nothing". Use `composer show <package>` and expect "not found".
- Keep test scripts and fixtures out of the plugin repository. Put them in the host project.

## 9. More traps (from the Element API upgrade)

- **Refresh the plugin cache after renaming the plugin class.** `craftcms/plugin-installer` caches each plugin's class in `vendor/craftcms/plugins.php`. After you rename the class or namespace, `composer dump-autoload` isn't enough: the plugin shows as disabled (`x` in `php artisan craft:plugin:list`) and its routes vanish. Run `ddev composer update vendor/my-plugin`.
- **Test entries with real titles:** create the entry type with a field layout, or titles save as `null`:

```php
$layout = new FieldLayout(['type' => Entry::class]);
$tab = new FieldLayoutTab(['name' => 'Content', 'layout' => $layout]);
$tab->setElements([new EntryTitleField()]);
$layout->setTabs([$tab]);
$type = new EntryType(['name' => 'Article', 'handle' => 'article', 'hasTitleField' => true]);
$type->setFieldLayout($layout);
```

- **Baseline first:** while the adapter-only Stage 1 works, save each endpoint's response body and key headers to files. After every later stage, diff against them. A byte-identical diff is the strongest evidence that an upgrade preserved behavior. It cannot see behavior that isn't in the response (cache lifetimes, cookies, error paths), so test those directly.
- **Run test commands from a script** with absolute tool paths (`/usr/bin/curl`) and `/bin/bash script.sh`: shell hooks (zoxide, mise) occasionally break `PATH` right after a `cd` into a new project.
- **Cache and TTL checks:** read the cache from tinker (`DependencyCache::get($key)`), use a short TTL such as `PT2S` and check the entry is gone after a `sleep`, and save an element to prove invalidation.

## 10. A native test suite (from a large upgrade)

For a plugin you will keep, move tests off the Yii/Codeception harness:

- Dev stack: `orchestra/testbench`, `pestphp/pest` with `pest-plugin-arch` and `pest-plugin-laravel`, `larastan/larastan`, optionally `rector/rector`. Add `craftcms/plugin-installer` and `pestphp/pest-plugin` to `config.allow-plugins`, and map `Tests\` and a `Workbench\` namespace in `autoload-dev`.
- Park the old tests in `tests-yii2/` as non-running reference, and upgrade them to Pest in the same stage as the code they test.
- **Boot test:** assert that the plugin's registrations take effect (`expect(app(ElementTypes::class)->types()->contains(Thing::class))->toBeTrue()`, and that expected macros resolve).
- **Architecture test as the exit gate:** it is stricter than the grep scan.

```php
arch('src has no legacy Craft classes')
    ->expect('src')->not->toUse('craft')->ignoring('craft\\myplugin');
arch('no debug functions')->expect('src')->not->toUse(['die', 'dd', 'dump']);
```

- Environment gotchas: tests that touch elements may need `CRAFT_EDITION` set to the edition the plugin requires, and a leaked `$_SERVER['CRAFT_SITE']` carries over between tests. Reset both in `TestCase::setUp()`.
- Raw SQL that works on MySQL can fail on SQLite or Postgres; use the schema builder or `tpetry/laravel-query-expressions` for cross-database expressions.
