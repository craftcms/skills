# Jobs, commands, scheduling and mail

Plain Laravel jobs, Artisan commands, scheduling and mailables all work. This page covers only what Craft adds. Published docs: [queue](https://craftcms.com/docs/6.x/extend/queue.html), [commands](https://craftcms.com/docs/6.x/extend/commands.html), [scheduling](https://craftcms.com/docs/6.x/extend/scheduling.html), [mail](https://craftcms.com/docs/6.x/extend/mail.html).

## Queue jobs

Extend `CraftCms\Cms\Queue\Job` (already `ShouldQueue`, `Dispatchable`, `Queueable`, `SerializesModels`) so Craft can show its description and progress:

```php
use CraftCms\Cms\Queue\Job;

class CheckLinks extends Job
{
    public function __construct(public int $batchSize = 50)
    {
        parent::__construct();          // sets the queue name from Craft config: don't skip it
    }

    public function handle(LinkChecker $checker): void
    {
        $this->setProgress(50, 'Checking…');
    }

    protected function defaultDescription(): string
    {
        return 'Checking shortlinks';
    }
}
```

Pass ids and scalars to the constructor, not elements or services.

## Commands

Register Artisan command classes on the plugin with `protected array $commands = [Console\Commands\PruneLinks::class];` so they exist only while the plugin is installed. Prefix signatures with the handle (`shortlinks:prune`).

## Scheduling

Override the plugin's `schedule()` hook; it only runs while the plugin is enabled:

```php
protected function schedule(\Illuminate\Console\Scheduling\Schedule $schedule): void
{
    $schedule->command('shortlinks:prune')->daily();
}
```

Tell users in the README that the project must run `schedule:run` from cron.

## Mail

Extend `CraftCms\Cms\Email\Mailables\CraftMailable` to use Craft's email settings and layout. Editable system messages come from `protected function getSystemMessages(): array` on the plugin (read `Plugin/Concerns/HasSystemMessages.php`).
