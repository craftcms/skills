# Console, queue, scheduling, mail, translation, logging and assets

Source: Craft 6.x extend docs, "Commands", "Jobs + Queue", "Scheduled Tasks", "Mail", "Translation", "Logging", "Assets and Publishables", "Filesystems + Disks".

## Console commands

- Yii console controllers become Artisan commands: classes extending `Illuminate\Console\Command` using `CraftCms\Cms\Console\CraftCommand`, with `#[Signature('report:generate {templateId}')]` and `#[Description('...')]` (or `$signature`).
- `handle()` receives arguments by name. Other parameters are injected.
- Register with `public array $commands = [...]` on the plugin, or define closures in `boot()` with `Artisan::command(...)`.
- Use a plugin prefix (`my-plugin:`), avoid generic names such as `run`/`send`, and `command` is not allowed as an argument name.
- Legacy invocation like `php craft plugin/install` still works for core commands. To keep your own plugin's old `php craft my-plugin/things/list` calls working, give the command `$signature = 'my-plugin:things:list'` plus `protected $aliases = ['my-plugin/things', 'my-plugin/things/list'];`. New: `ddev artisan craft:plugin:install`.

## Queue jobs

- Extend `CraftCms\Cms\Queue\Job` (replaces `craft\queue\BaseJob`). `execute()` becomes `handle()`, with DI in the signature. Constructor properties hold the data.
- Dispatch with `dispatch(new Job(...))` or `Job::dispatch(...)`.
- Jobs are not necessarily queued: add `Illuminate\Contracts\Queue\ShouldQueue` and `InteractsWithQueue` to be pushed to the queue.
- Constructor properties become promoted `readonly` properties (call `parent::__construct()` if the base class needs it). `setProgress($queue, 0.2)` becomes `setProgress(20)` (an int percent, no queue argument). `RetryableJobInterface` (`getTtr()`, `canRetry()`) becomes `public int $timeout` and `public int $tries`.
- Name jobs with a `Job` suffix and keep them in `Jobs/`.
- `ttr` is now `timeout`. Jobs have UUIDs, and keep a `dateCompleted` instead of being deleted immediately (pruned in garbage collection).
- Priority: no equivalent. Apps may set a `lowPriorityQueue` in general config. Tell users how you use the queue.
- Job descriptions shown in the CP: use a prepared string, `I18N::prep(...)`.
- Laravel extras: chains, batches, overlap prevention. Confirm users' infrastructure supports non-standard features before relying on them.

## Scheduling

Define `schedule(Schedule $schedule)` on the plugin (`HasScheduling`) using `command()`, `job()`, `call()` and frequency methods. The host must run `php artisan schedule:run` every minute (cron). Document the dependency, because not every project has it.

## Mail

- Mailer adapters are gone. Mailers are configured in Laravel (config file, selected in Settings, Email). The docs name both `config/mail.php` (approach page) and `config/mailer.php` (mail page), so verify in source.
- System messages: implement `getSystemMessages()` returning `[key => fn () => new SystemMessage(...)]`. Send via `app(SystemMessages::class)->mailable($key, $user, $vars)` and `Mail::send($message)`.
- Other mail: extend `CraftCms\Cms\Email\Mailables\CraftMailable` (adds `siteId` for per-site mailer overrides).
- Monitor or suppress outgoing mail with a listener on `Illuminate\Mail\Events\MessageSending` (return `false` to suppress).

## Translation

- Rename `translations/` to `lang/`. File structure is unchanged.
- `Craft::t($category, $message, $params)` becomes `t($message, $params, $category)` (global function in `CraftCms\Cms`; named arg `category:` is convenient). The Twig `|t` filter is unchanged.
- Lazy translation for unknown display language: `I18N::prep($message, $params, $category)`.

## Logging and deprecations

- `Craft::info()`, `Craft::error()` and friends become `Illuminate\Support\Facades\Log`.
- Deprecation notices: `CraftCms\Cms\Support\Facades\Deprecator::log(__METHOD__, '...')`.
- Garbage collection: listen for `CraftCms\Cms\GarbageCollection\Events\RunningGarbageCollection` to clean up your own tables.

## Assets

- Register built control panel assets declaratively: `$scripts` and `$styles` maps (source path => public path under `public/vendor/<package>/`), `$publishables` for others. Point at built files, not sources. Re-publish after changes: `ddev artisan vendor:publish --tag=<plugin-handle>`.
- Vite: `protected array $vite = ['input' => [...], 'publicDirectory' => 'resources/dist', 'buildDirectory' => 'build']` and `laravel-vite-plugin` in `vite.config.js`. DDEV may need CORS and port settings. Each plugin needs a unique `port` and `hotFile` when developing several at once.
- Legacy asset bundles: implement `CraftCms\Cms\View\LegacyAssets\LegacyAssetInterface` with `register(HtmlStack $htmlStack)` and register through `InternalAssetRegistry`. Deprecated stopgap, so prefer `$scripts`/`$styles`.
- HTML fragments: `HtmlStack::html($html, Position::Head, $key)`. `View::POS_*` constants became the `Position` enum.
- Plugin icons live in `resources/`. If the CP nav icon doesn't show, see the CP nav note in [plugin-class.md](plugin-class.md).

## Filesystems

Removed. Projects use Laravel disks (`config/filesystems.php`) and keep the old handle. Filesystem-type plugins are probably obsolete.

## Local development

Path repositories still work. After requiring the package run `ddev artisan package:discover`. The project's `composer.json` needs `post-autoload-dump` scripts (`Illuminate\Foundation\ComposerScripts::postAutoloadDump`, `package:discover`, `craft:setup:publish`). The `craft6-revamp` tool adds these. Install with `ddev artisan craft:plugin:install`.
