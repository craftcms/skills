# Choosing a porting strategy

Source: Craft 6.x extend docs, "Approach" and "The Adapter".

## Choose the end state

Decide this with the developer in Stage 0. It sets how many stages to run.

| End state | Adapter | Stages | When it fits |
| --- | --- | --- | --- |
| **A. Ship on the adapter** | Required by the released plugin | 1 required, 2 to 5 optional | Large plugin, limited time, or other code that depends on legacy behavior |
| **B. Adapter-free** | Required **while porting**, but not used or required in the release | All, ending with removal in Stage 5 | Small or medium plugin, or a maintainer who wants no Yii dependency |

End state B treats the adapter as scaffolding. The plugin runs on Craft 6 after Stage 1, and each later stage replaces something the adapter was covering. Proof of completion:

- `scripts/scan-craft5.sh` reports no hits on the plugin's native source. A deliberate `legacy/` folder is the only acceptable exception, and it needs an explanation.
- The adapter is gone from `composer.json`, and `composer why craftcms/yii2-adapter` and `composer why yiisoft/yii2` report nothing in a clean host project.
- Every feature works in that clean project.

Remember that the adapter is a supported destination too. If end state B stalls on something with no native replacement yet (for example custom element types, which the docs don't cover), fall back to A for that release and say so.

## Choose the namespace

Ask the developer, and don't change a namespace without their agreement. Craft 5 plugins usually use lowercase Yii-style namespaces (`craft\myplugin`); Laravel convention is PascalCase PSR-4 (`CraftCms\MyPlugin`, `MyOrg\MyPlugin`).

| Choice | Upside | Downside |
| --- | --- | --- |
| Conventional namespace | Matches Laravel and Craft 6 style. Doubles as a progress marker: ported classes are in the new namespace, anything still in the old one is not ported yet. | Breaking change for code that references your classes: list every rename in `UPGRADE.md`. |
| Keep the old namespace | Fewer breaking changes. | Ported and unported code look alike, so progress is harder to see. |

While moving, keep both namespaces in `composer.json` `autoload.psr-4`, and remove the old one once nothing uses it (unless you keep a deliberate legacy layer).

## Simple plugins

Plugins that mostly handle or alter an event can usually be **fully ported** and released as an alpha.

## Larger plugins

Plugins that add new features or new types of existing components should:

1. Make the minimum updates for compatibility ([required-changes.md](required-changes.md)).
2. Release that as an alpha, so others can test the upgrade in real projects and report issues with Craft, the adapter or the plugin.
3. Migrate gradually, using the alpha period.

If the plugin has its own extension surface (events, service APIs), decide and tell users whether it will be fully ported during the alpha, and whether a compatibility layer will ship.

## Is the plugin still needed?

Some low-level plugins are obsolete in Laravel:

- **Mail transport adapters.** Projects configure mailers in Laravel config and select one in Settings, Email. A control panel config layer tracked in project config may still be welcome.
- **Custom log back-ends.** Plugins may boot too late to capture a full picture. Consider whether Laravel logging is enough.
- **Filesystems.** Removed in Craft 6. Projects configure Laravel disks in `config/filesystems.php` and select them in each volume's settings.

## Clean break: Laravel events and an upgrade guide

If the developer doesn't want a compatibility layer, move the plugin's own Yii-style events (`EVENT_*` constants and `Event` subclasses) to Laravel event classes, remove the old ones, and write down what users must change in `UPGRADE.md` (start from `assets/UPGRADE.template.md`). Each removed event gets a before and after listener example. This is the simplest route to an adapter-free release, because the legacy Yii event system can't be proxied without the adapter.

## Compatibility layers for your own legacy API

Only needed if other plugins or projects extend your plugin, or the database or project config stores your fully-qualified class names (for example a `type` column that maps to a class).

- Move classes into the new namespace, and map the old names with `class_alias()`.
- Keep old classes in a `legacy/` autoload root with the same namespace, tagged `@deprecated`.
- `composer.json` must list the new **and** old `autoload.psr-4` namespaces.
- Where a legacy class has been restructured, keep it, call `Deprecator::log()`, then forward to the new API.
- A legacy event system tied to Yii cannot be proxied without the adapter. Either require the adapter or document the upgrade path.

See [required-changes.md](required-changes.md) for the alias and deprecation snippets.

## Style

Craft's 6.x codebase uses Laravel Pint. Optional for plugins: `composer require --dev laravel/pint`, then `vendor/bin/pint --test path/to/plugin`. No `pint.json` is needed unless excluding directories.
