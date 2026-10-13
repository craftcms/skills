# Database migrations

Source: Craft 6.x extend docs, "Migrations".

## Rules

- Bring the `Install` migration fully up to date with the expected current schema, then cull the older incremental migrations (as for any major plugin version jump). It must be able to completely remove that schema on uninstall.
- Once the base class is `CraftCms\Cms\Plugin\Plugin`, the adapter assumes migrations no longer need legacy shims. Only native Laravel migrations will work.
- Location: top-level `database/migrations/` of the package.
- A migration named `Install` runs `up()` on install and `down()` on uninstall.
- `up()` and `down()` return nothing. Let exceptions bubble.
- Craft migration events (`EVENT_AFTER_UP`, `EVENT_AFTER_DOWN`) are replaced by Laravel's migration events.

## Converting

Yii `craft\db\Migration` becomes an anonymous Laravel migration class:

```php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('activity_events', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('handle')->unique();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('activity_events');
    }
};
```

- Replace `$this->createTable()`, `addColumn()`, `createIndex()`, `addForeignKey()`, `dropTable()` etc. with `Schema` and `Blueprint`. Laravel column types and modifiers are named differently, so check the Laravel migrations docs for each.
- Generate a stub with `ddev artisan make:migration`, then move the file into the plugin's `database/migrations/`. It is not yet plugin-aware, but the file has no class name or namespace, so moving is safe as long as the filename is unique and ordered. Customized stubs in the host app may change the output.
- Driver differences: the schema builder smooths most. Where needed, branch on `DB::connection()->getDriverName()` (`'mysql'`, `'pgsql'`).
- Optional migrations can be offered with `$this->publishesMigrations([...])` in `boot()`. Never publish the plugin's regular migrations, because Craft already tracks them and publishing causes double runs.
- If a Laravel package you wrap already ships migrations (for example Cashier), don't duplicate them.
- Extra migration tracks: only if you genuinely need them. See `MigrateCommand::registerMigrator()` in [events-and-registries.md](events-and-registries.md).

## Records to Eloquent

Replace `ActiveRecord` queries (`MyRecord::find()->where(...)`) with Eloquent (`MyModel::query()->where(...)`). See [models-and-validation.md](models-and-validation.md). Query builders for Craft element queries gain Craft macros such as `whereParam()` (the old `Db::parseParam()` equivalents).
