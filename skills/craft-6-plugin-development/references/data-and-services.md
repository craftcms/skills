# Database tables, elements and Craft services

Migrations, Eloquent models and services are plain Laravel. This page covers how Craft runs plugin migrations and how to work with Craft's own data. Published docs: [migrations](https://craftcms.com/docs/6.x/extend/migrations.html), [models](https://craftcms.com/docs/6.x/extend/models.html), [services](https://craftcms.com/docs/6.x/extend/services.html).

## Install migration

`database/migrations/Install.php` is an anonymous Laravel migration with a fixed name. Craft runs its `up()` on `craft:plugin:install` and its `down()` on uninstall, then marks every other migration in the folder as already applied.

- `Install.php` must always describe the **current** full schema, and `down()` must drop everything in reverse dependency order.
- Prefix table names with the plugin handle in snake_case (`shortlinks_links`). Craft's own tables are unprefixed (`elements`, `sites`, `entries`, `users`), so plain names collide. Set `$table` on Eloquent models, since the inferred name won't have the prefix.
- Foreign keys to Craft data point at `elements.id` (entries, assets, users; a user's id is an element id), `sites.id` and `users.id`. Cascade on delete.
- Craft's tables use camelCase columns (`siteId`, `dateCreated`) and have `status`, `dateCreated` and similar names. Qualify columns in joins with them (`shortlinks_links.status`), or you get an ambiguous-column error.
- Use the schema builder only; Craft supports MySQL, PostgreSQL and SQLite.

## Later schema changes

Add a timestamped migration (`2026_11_01_000000_add_notes_to_links.php`, same anonymous-class format), bump the plugin's `$schemaVersion` so Craft knows updates are pending, and update `Install.php` to match. `craft:up` runs pending plugin migrations. Fresh installs skip them, because `Install.php` already has the final schema.

## Craft's services

Craft's services are injectable (`CraftCms\Cms\Section\Sections`, `CraftCms\Cms\Site\Sites`, `CraftCms\Cms\Element\Elements`, …) and most have facades in `CraftCms\Cms\Support\Facades\`. They return `Illuminate\Support\Collection`s, not arrays: `Sections::getAllSections()->map(...)->values()->all()` for `Choice` options.

For non-persisted structured data that needs validation (`getRules()`, `validate()`, `errors()`), extend `CraftCms\Cms\Component\Component`.

Expose a service to templates through a Twig function or global ([templates.md](templates.md)) rather than making templates call `app()`.

## Elements

Element queries keep their Craft 5 shape: `Entry::find()->section('blog')->limit(10)->all()`. Native element classes: `CraftCms\Cms\Entry\Elements\Entry`, `CraftCms\Cms\Asset\Elements\Asset`, `CraftCms\Cms\User\Elements\User`, `CraftCms\Cms\Address\Elements\Address`. Save with `CraftCms\Cms\Support\Facades\Elements::saveElement($element)`. Categories, tags and global sets exist only in the Yii adapter; don't use them.

- To relate your rows to elements, store the element id and load the element with its query (`Entry::find()->id($id)->one()`), not an Eloquent relation.
- Queries are scoped to the current site. An element id stored in a setting may not exist in every site: `Asset::find()->id($id)->site('*')->unique()->preferSites([$siteId])->one()`.
- A default query excludes drafts, revisions and disabled elements; add `->drafts(true)`, `->revisions(true)` or `->status(null)` when you need them.

## Activity timeline

When the plugin changes content on a user's behalf (sends a campaign, imports entries), record it in Craft's activity timeline rather than the log: extend `CraftCms\Cms\Activity\ActivityEventType`, return `ActivitySource::fromPlugin(Plugin::getInstance())` as its source, and call `CraftCms\Cms\Support\Facades\Activities::record(new YourEvent(...))` after the action succeeds. Read a core event type in `src/Activity/EventTypes/` for the constructor and `format()` shape.

## Caching

For caches that should clear when content changes, look at `CraftCms\Cms\Support\Facades\ElementCaches` and the `laravel-dependency-aware-cache` package Craft ships.

## Verify

`craft:plugin:install` must create every table and `craft:plugin:uninstall <handle> --force` must drop them all ([testing.md](testing.md#uninstall-and-reinstall)). Create rows through the real code path (a controller or command), not only from tinker.
