# Events and registries

Craft's events are ordinary Laravel event classes, so `Event::listen()`, listener classes and `event()` work as usual. Published docs: [events.md](https://craftcms.com/docs/6.x/extend/events.html), [registries.md](https://craftcms.com/docs/6.x/extend/registries.html).

## Listening to Craft events

Every Craft event is a class. There are no `EVENT_*` constants, no `sender`, and no `Event::on(Class, NAME, …)`. Find the class you need:

```bash
ls vendor/craftcms/cms/src/*/Events/            # all event classes, grouped by feature
rg -l "event\(new ElementSaved" vendor/craftcms/cms/src   # where one is dispatched
```

Names follow object + action: `…Saving` / `…Deleting` (before, can veto or modify), `…Saved` / `…Deleted` (after), `…Resolving` (collect or modify data, the old "define"/"register" events). Read the class: its public constructor properties are the payload.

Register listeners declaratively on the plugin:

```php
use CraftCms\Cms\Element\Events\ElementSaved;

protected array $events = [
    ElementSaved::class => Listeners\PurgeLinkCache::class,
    // several: ElementSaved::class => [Listeners\A::class, Listeners\B::class],
];
```

```php
<?php

declare(strict_types=1);

namespace Acme\Shortlinks\Listeners;

use CraftCms\Cms\Element\Events\ElementSaved;
use CraftCms\Cms\Entry\Elements\Entry;

class PurgeLinkCache
{
    public function __construct(private readonly LinkCache $cache) {}   // injected

    public function handle(ElementSaved $event): void
    {
        if (! $event->element instanceof Entry) {
            return;
        }
        // ...
    }
}
```

- `ElementSaved` fires for **every** element type, including drafts, revisions and users. Filter by `instanceof` and check `$event->element->getIsDraft()`, `getIsRevision()` and `$event->element->propagating` as needed.
- Before-events: set `$event->isValid = false` on events that use `CraftCms\Cms\Shared\Concerns\ValidatableEvent` to veto.
- Common ones: `Element\Events\ElementSaved|ElementSaving|ElementDeleted`, `Entry\Events\*`, `View\Events\TemplateGlobalsResolving`, `View\Events\TemplateRendering|TemplateRendered|PageTemplateRendering|PageTemplateRendered` (all in `CraftCms\Cms\View\Events`, not `Twig\Events`), `FieldLayout\Events\FieldLayoutUIElementsResolving`, `Plugin\Events\PluginSettingsSaved`.

## Dispatching your own events

Follow Craft's conventions so other developers can extend your plugin the same way: name events object + action (`LinkResolving`, `LinkResolved`), make the payload public constructor properties, and add `CraftCms\Cms\Shared\Concerns\ValidatableEvent` (gives `$isValid = true`) to before-events that may be vetoed:

```php
event($event = new LinkResolving($link, $link->destination));
if (! $event->isValid) {
    abort(404);
}
```

Document every event a plugin dispatches in its README: class, when it fires, properties, and whether it can veto.

## Registries

Component types (field types, widgets, utilities, element types, auth methods, template roots, link types, …) are held in registries. The plugin properties push into them. To register conditionally or remove something, inject the registry in `boot()`:

```php
use CraftCms\Cms\Field\FieldTypes;

public function boot(FieldTypes $fieldTypes): void
{
    if ($this->is('pro')) {
        $fieldTypes->register(Fields\ProField::class);
    }
}
```

The published [registries.md](https://craftcms.com/docs/6.x/extend/registries.html) lists them. Confirm the class name and method in `vendor/craftcms/cms/src` before use.

## Verify

Trigger the real action (save an entry in the CP or with tinker through `Elements::saveElement()`) and check the listener's side effect (a row, a log line, a cache key). For your own events, add a throwaway `Event::listen()` to `workbench/routes/web.php` that vetoes or modifies, and check the plugin honours it. Remove it afterwards.
