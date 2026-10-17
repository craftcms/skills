# Database migrations

Source: Craft 6.x extend docs, "Migrations".

## Rules

- Bring the `Install` migration fully up to date with the expected current schema, then cull the older incremental migrations (as for any major plugin version jump). It must be able to completely remove that schema on uninstall.
- Once the base class is `CraftCms\Cms\Plugin\Plugin`, the adapter assumes migrations no longer need legacy shims. Only native Laravel migrations will work.
- Location: top-level `database/migrations/` of the package.
- A migration named `Install` runs `up()` on install and `down()` on uninstall. Make it a named class in `Install.php` (not an anonymous class), and split `up()` into steps (`createTables()`, `createIndexes()`, `addForeignKeys()`, `insertDefaultData()`).
- `Install::down()` must remove everything the plugin added: drop its tables, delete its field layouts (match both the old and new class names if you aliased classes), and remove its project config (`ProjectConfig::remove('<handle>')`).
- Dated migrations after `Install` only need `up()`. The Craft 5 incremental migrations are culled, and a plugin that ships a data migration usually updates project config as well (`ProjectConfig::set(...)`) when the data lives there.
- Bump `$schemaVersion` and set `$minVersionRequired` on the plugin class to the latest 5.x version users must upgrade from first.
- `up()` and `down()` return nothing. Let exceptions bubble.
- Craft migration events (`EVENT_AFTER_UP`, `EVENT_AFTER_DOWN`) are replaced by Laravel's migration events.

## Converting

Yii `craft\db\Migration` becomes an anonymous Laravel migration class:

```php
use CraftCms\Cms\Database\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('activity_events', function (Blueprint $table) {
            $table->integer('id', true); // not id(): see below
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

- **Primary keys that other tables reference:** Craft's own tables (`elements`, `users`, `sites`, ...) use signed `int` ids. `$table->id()` creates an unsigned `bigint`, so a foreign key from your table to a Craft table fails with a type mismatch. Use `$table->integer('id', true)` for your ids and `$table->integer('elementId')` for columns that point at Craft's tables. `$table->id()` is fine for tables that never take part in a foreign key with Craft's tables.
- Extend `CraftCms\Cms\Database\Migration` (it adds console output and `silent()`) rather than Illuminate's class.
- Table names: write them unprefixed. The connection adds the table prefix, so the Yii `{{%table}}` syntax is simply dropped. For raw SQL use `DB::getTablePrefix()`.
- Craft's `uid` column is `char(36) default '0'`. Raw inserts with `DB::table()->insert()` skip model events, so set `'uid' => Str::uuid()->toString()`, `dateCreated` and `dateUpdated` yourself, or the rows are saved with `uid = '0'`.
- `Schema::createIndex($table, ['col'], unique: true)` is available as a Craft macro.
- Replace `$this->createTable()`, `addColumn()`, `createIndex()`, `addForeignKey()`, `dropTable()` etc. with `Schema` and `Blueprint`. Laravel column types and modifiers are named differently, so check the Laravel migrations docs for each.
- Generate a stub with `ddev artisan make:migration`, then move the file into the plugin's `database/migrations/`. It is not yet plugin-aware, but the file has no class name or namespace, so moving is safe as long as the filename is unique and ordered. Customized stubs in the host app may change the output.
- Driver differences: the schema builder smooths most. Where needed, branch on `DB::connection()->getDriverName()` (`'mysql'`, `'pgsql'`).
- Optional migrations can be offered with `$this->publishesMigrations([...])` in `boot()`. Never publish the plugin's regular migrations, because Craft already tracks them and publishing causes double runs.
- If a Laravel package you wrap already ships migrations (for example Cashier), don't duplicate them.
- Extra migration tracks: only if you genuinely need them. See `MigrateCommand::registerMigrator()` in [events-and-registries.md](events-and-registries.md).

## Records to Eloquent

Replace `ActiveRecord` queries (`MyRecord::find()->where(...)`) with Eloquent (`MyModel::query()->where(...)`). See [models-and-validation.md](models-and-validation.md). Query builders for Craft element queries gain Craft macros such as `whereParam()` (the old `Db::parseParam()` equivalents).
