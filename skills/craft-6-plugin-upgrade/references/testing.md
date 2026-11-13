# Setting up a host project and testing an upgrade

These recipes were used to upgrade a real plugin (`craftcms/guest-entries`) against `craftcms/cms` 6.0.0-alpha.20. Adapt names and URLs. They assume DDEV, as the Craft 6 install docs do; without DDEV, run the same `composer` and `php artisan` commands directly.

## 0. Verify the target Craft version

The original alpha.20 recipes needed `6.x-dev` for unreleased UI and adapter fixes. This is not a requirement for every upgrade: `6.0.0-beta.1` already includes `Ui`. Start with the agreed compatible release and check its installed source. If a missing API or confirmed bug requires an unreleased fix, agree that dependency change before using the following development-branch recipe:

```bash
composer create-project craftcms/craft:6.x-dev my-host --no-scripts --no-install
cd my-host && mv composer.json.default composer.json   # if the skeleton ships it under that name
composer require craftcms/cms:6.x-dev -W
# in the plugin repo: keep require at ^6.0.0, lock the dev branch
composer update craftcms/cms --with craftcms/cms:6.x-dev -W
```

- If the selected strategy installs the adapter, Composer must be allowed to run Yii's plugin: `composer config --no-plugins allow-plugins.yiisoft/yii2-composer true`.
- Without a GitHub token, Composer's zip downloads can stall for many minutes: `composer config -g github-oauth.github.com "$(gh auth token)"`.
- A path repository on a branch is required as `<branch>-dev` (`4.x-dev`), not `dev-<branch>`.
- Record the exact installed Craft version and source commit with the results. Re-run checks after dependency changes, but do not update the host outside the agreed scope just to finish a report.
- After switching a host between adapter and native with `--no-scripts`, delete `bootstrap/cache/packages.php` and `services.php` and run `php artisan package:discover`, or Laravel looks for providers that are gone.

## 1. Create a clean Craft 6 host

```bash
mkdir my-host && cd my-host
ddev config --project-type=laravel --docroot=public --php-version=8.5 --database=mysql:8.4
ddev start
ddev composer create-project "craftcms/craft:^6.0.0-beta.1" --no-interaction
# Use an agreed version or development branch if needed, as described in section 0.
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

`artisan tinker my-script.php` opens an interactive prompt after the file runs and hangs in a non-interactive shell. A Craft 5 site upgraded with `craft6-revamp` may have no `tinker` command; `composer require --dev laravel/tinker` adds it.

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
- **No Pest arch test for legacy classes:** `arch()->not->toUse('craft')` passes even when `src/` uses a legacy class, because without the adapter installed the class doesn't exist and Pest can't see it. Use the scan and PHPStan (which reports the unknown class) instead. An arch test is still fine for `strict_types` or debug functions.

- Environment gotchas: tests that touch elements may need `CRAFT_EDITION` set to the edition the plugin requires, and a leaked `$_SERVER['CRAFT_SITE']` carries over between tests. Reset both in `TestCase::setUp()`.
- Raw SQL that works on MySQL can fail on SQLite or Postgres; use the schema builder or `tpetry/laravel-query-expressions` for cross-database expressions.

## 11. `PluginTestCase` traps

Craft's `CraftCms\Cms\Plugin\Testing\PluginTestCase` (Orchestra Testbench) installs the plugin for each test. Things that cost real upgrades time:

- It reads `extra.class` from `composer.json`; without it every test fails with "does not define a plugin class".
- Core's model factories ship in the package but aren't autoloaded for plugins. Map them in the plugin's `autoload-dev`: `"CraftCms\\Cms\\Database\\Factories\\": "vendor/craftcms/cms/database/Factories/"`.
- Factories write rows directly, so `createElement()` fires no element events. Save through `Elements::saveElement()` when the plugin listens for saves (the factory can still provide the section and entry type). Saving an entry also creates a revision, which fires `ElementSaved` again; filter revisions in listeners and assertions.
- The Solo edition allows one user. Call `Edition::set(Edition::Pro)` before creating a second one (permission tests).
- `config/craft/<handle>.php` values are applied when the plugin is created, during `setUp()`. `config()->set('craft.<handle>.x', ...)` inside a test changes nothing; set the bound settings instead (`app(Settings::class)->x = ...`). A leftover `vendor/orchestra/testbench-core/laravel/vendor` symlink (from running `vendor/bin/testbench vendor:publish`) re-applies the config on each request and hides this locally, so check failing CI in a fresh clone.
- Craft's HTML error pages close output buffers, which makes Pest mark the test risky. Use `postJson()`/`getJson()` for 401 and 403 assertions.
- `Env::get()` reads `$_SERVER`, not `putenv()`. SDKs with default credential chains may hang on a cloud metadata endpoint unless the test sets credentials.
- Testbench symlinks its `vendor` back to the plugin's, so tools that walk the tree (`prettier --check .`) loop forever. Exclude `vendor/**`.

## Tooling and CI

- `craftcms/phpstan`, `craftcms/rector` and `craftcms/ecs` support Craft 5 and older PHP; PHPStan 1.x can't parse PHP 8.5. For the native major use `larastan/larastan` (level 4 to 6 over `src` and `routes`), Pint ([strategy.md](strategy.md#style)) and Pest with `pestphp/pest-plugin-laravel`. Add `@method Settings getSettings()` to the plugin class so Larastan knows the settings class.
- Craft's request and HTTP client macros (`Request::isPreview()`, `Http::create()`) were reported as undefined methods by Larastan in CI while passing locally. If that happens, add a narrow `ignoreErrors` entry with `reportUnmatched: false` and note why.
- Craft's shared GitHub workflow (`craftcms/.github`) runs Codeception for tests and has no Pint job. Set `craft_version: '6'`, keep its `phpstan` and `prettier` jobs, and add a separate job on PHP 8.5 that runs `composer check-cs` and `composer test`. An adapter release branch still set to `craft_version: '4'` runs on PHP 8.0 and may fail for that reason alone.
- A `[ci skip]` commit at the head of a branch means CI never runs on the code below it. Start the workflow by hand or put the skip on a commit that isn't the head.
- `git archive` drops files that `.gitattributes` marks `export-ignore` (usually `tests/`); copy the working tree instead when you need the tests elsewhere.
