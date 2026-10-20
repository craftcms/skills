# Element types

The Craft 6.x docs have no upgrade guide for custom element types. This page summarizes the shape of a native element type, taken from a large plugin that has been upgraded and from Craft's own `Entry` and `Asset`. Treat it as a map, and read the installed `craftcms/cms` source for each class before writing code (`CraftCms\Cms\Entry\Elements\Entry` is the best template). Say plainly to the developer which parts you could not verify.

## The pieces

| Craft 5 | Craft 6 |
| --- | --- |
| `craft\base\Element` subclass | `CraftCms\Cms\Element\Element` subclass, in `src/<Feature>/Elements/` |
| `find()` returns `ElementQueryInterface` | `public static function find(): MyElementQuery` (typed, see `Entry::find(): EntryQuery`) |
| `craft\elements\db\ElementQuery` subclass with `$tableName` and `beforePrepare()` | `CraftCms\Cms\Element\Queries\ElementQuery` subclass with `protected string $table = '...'` (unprefixed), in `src/<Feature>/Elements/Queries/` |
| Record class with `ActiveRecord` | Thin Eloquent model for the element's own table ([models-and-validation.md](models-and-validation.md)): `$timestamps = false`, `$incrementing = false` |
| `afterSave()` writing a record | Same method name: load the model (`MyRecord::query()->find($this->id)`) or create one and set `id`, set the columns, `save()`. Use `Query::prepareDateForDb()` for dates |
| `defineRules()` | `#[Ruleset(MyElementRules::class)]` on the class, with a rules class extending `CraftCms\Cms\Element\Validation\ElementRules`. Leftover imperative checks can stay on the element as `afterValidate()` |
| `canView()` / `canSave()` / `canDelete()` | A policy extending `CraftCms\Cms\Element\Policies\ElementPolicy`, registered with `Gate::policy(...)` ([http-and-auth.md](http-and-auth.md)) |
| `defineSources()`, `defineActions()`, `defineSortOptions()`, `defineTableAttributes()`, `eagerLoadingMap()` | Same names, with typed signatures (no `string $context = null` defaults). Check each signature in the installed `Element` class |
| `EVENT_REGISTER_ELEMENT_TYPES` | `protected array $elementTypes = [MyElement::class];` on the plugin class |
| Structure helpers on `Craft::$app->getStructures()` | `CraftCms\Cms\Structure\Structures` (`appendToRoot()`, `prepend()`, `append()`, `moveBefore()`), with `StructureMode` |
| Element exporters, GraphQL types, link types | `defineExporters()`, `$gqlTypes` / `$gqlQueries`, `$linkTypes` on the plugin class |

## Query classes

Large plugins split query behavior into traits with `public static apply*()` helpers (the pattern Craft's own `QueriesAssetLocation` uses), so the same logic serves both the query class and condition rules. When a condition rule must modify the query, call the static helper against the query directly rather than a setter on the element query, or the ordering of the `beforeQuery` callbacks changes the result.

## Other things that move with an element type

- Stored class names: element type names are written to the database (field layouts, relations). Keep a `class_alias` at the old name, and make the install migration's field layout cleanup accept both names.
- Garbage collection: partial elements are cleaned up through `RunningGarbageCollection`, using the core `DeletePartialElements` action per element table.
- Authorization hooks for extra rules: listen for `CraftCms\Cms\Auth\Events\ElementAuthorizing` and branch with `match ($event->ability)`.
- Reusing core controllers: the core element edit and revision controllers can be routed directly (`Route::get('plugin/things/{id}{slug?}', EditElementController::class)`), so a plugin no longer needs its own edit controller. Check the route patterns in the installed `routes/cp.php`.
- Fields that compute their value from the element (no column): return `null` from `dbType()` and override `normalizeValue()` and `copyValue()`.

## Test it

Create an element, save it, query it back, change it, delete it and restore it (soft delete), and check the element index and edit page in the control panel. A boot test that asserts the type is registered is a cheap regression guard:

```php
expect(app(ElementTypes::class)->types()->contains(Thing::class))->toBeTrue();
```
