# Choosing a porting strategy

Source: Craft 6.x extend docs, "Approach" and "The Adapter".

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
