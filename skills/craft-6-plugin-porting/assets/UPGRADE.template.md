# Upgrading to {{PLUGIN_NAME}} {{NEW_VERSION}} (Craft 6)

This guide lists what changed in {{NEW_VERSION}} and what you need to update in your project, templates and custom code.

> Fill in every `{{...}}` placeholder, delete sections that don't apply, and replace the example blocks with this plugin's real before/after code. Only list changes that actually happened, and only differences a user of the previous version would observe (not internal refactors). Keep entries one line per class where you can: `Added X.`, `Deprecated Y. Use X instead.`, `Removed Z. Replaced by W.` Verify every new class name and signature against the installed `craftcms/cms` 6.x source.

## Requirements

- Craft CMS {{CRAFT_VERSION}} or later
- PHP {{PHP_VERSION}} or later
- {{Does it still require `craftcms/yii2-adapter`? If not, say it is no longer needed.}}

## Upgrade steps

1. Upgrade your project to Craft 6 first.
2. Update the plugin: `composer require {{PACKAGE_NAME}}:^{{NEW_VERSION}}`.
3. {{Any config, project config or migration step.}}
4. Review the breaking changes below and update your code.

## Breaking changes

### Events

Yii-style events were replaced by Laravel events. {{Summarize which events were removed, renamed or replaced.}}

| Before | After |
| --- | --- |
| `{{OldClass::EVENT_NAME}}` | `{{New\Event\Class}}` |

Before:

```php
Event::on(
    {{OldClass}}::class,
    {{OldClass}}::{{EVENT_NAME}},
    function ({{OldEventClass}} $event) {
        // ...
    }
);
```

After:

```php
use Illuminate\Support\Facades\Event;

Event::listen(function ({{NewEventClass}} $event): void {
    // ...
});
```

{{Note any differences: no `sender`, how to cancel (`isValid`, return `false`), how to mark handled, new properties.}}

### Classes and namespaces

| Before | After |
| --- | --- |
| `{{old\namespace\Class}}` | `{{New\Namespace\Class}}` |

### Settings and config

{{Where settings live now, new config file path, renamed or removed settings.}}

### Routes and action URLs

{{Changed or kept action URLs and routes. Say if form actions in templates need updating.}}

### Templates and Twig

{{Changed variables, functions, template paths.}}

### Permissions

{{Renamed or new permissions.}}

### Database and migrations

{{Schema changes, and what happens on update.}}

## Removed

{{List anything removed with no replacement.}}

## Need help?

{{Issue tracker or support link.}}
