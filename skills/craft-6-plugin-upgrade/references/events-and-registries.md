# Events, listeners and registries

Source: Craft 6.x extend docs, "Events + Listeners", "Registries".

## Events

Every Craft event is now its own class. The old `EVENT_*` constants map to event classes, but the names changed semantically, so they cannot be converted by regex. Read the docblock on each deprecated constant to find the new class.

Naming pattern is object-action:

- `...Resolving`: replaces "define"/"register" events (for example `InputOptionsResolving` replaces `EVENT_DEFINE_OPTIONS`).
- `...ing` (for example `EntryTypeDeleting`): before something happens. Replaces `EVENT_BEFORE_*`.
- Past tense (for example `SectionSaved`): after it happened. Replaces `EVENT_AFTER_*`.

There is no `sender`. You listen for the event class, wherever it came from. Instance-level events are rare. A handler that used to be scoped by sender (`Event::on(User::class, EVENT_AFTER_SAVE, ...)`) becomes one listener on the generic event that checks the type itself:

```php
class ElementSavedListener
{
    public function handle(ElementSaved $event): void
    {
        if ($event->element instanceof User) { /* ... */ }
        if ($event->element instanceof Address) { /* ... */ }
    }
}
```

Not every event is Craft's: Laravel's own events (`Illuminate\Auth\Events\Login`, `Logout`, `Illuminate\Mail\Events\MessageSending`) replace some Craft ones. Not every name follows the pattern either (`DefineDeletionBlockers`). Look each one up from the docblock.

Listeners that run before the plugin is installed should return early (`if (!$this->plugin->isInstalled) return;`), because listeners are registered on every request.

## Handlers (Yii `Event::on` to Laravel listeners)

Declarative, on the plugin class:

```php
protected array $events = [
    DraftApplied::class => Listeners\LogElementActivity::class,
    MessageSending::class => Listeners\LogMailMessage::class,
    ElementCardHtmlResolving::class => [
        Listeners\AddCardDetails::class,
        [self::class, 'redactSensitiveCardData'],
    ],
];
```

Closures go in `boot()` (PHP cannot put closures in static properties). Laravel infers the event from the type-hint:

```php
Event::listen(function (RegisterFilesystemTypes $event): void {
    $event->types->push(Dropbox::class);
});
```

- Listeners should return `void`. Return `false` only to stop propagation.
- Group handlers in a subscriber, registered in `boot()` with `Event::subscribe(MySubscriber::class)`.
- In a project (not a plugin), listener classes in `App\Listeners` are auto-discovered.
- Handlers that used `$event->types[] = ...` to register things should usually become registry calls (below), or may remain as event listeners where the event class still exists.

## Emitting your own events

```php
event($e = new DeliveryConfirmed);
// or Dispatchable: DeliveryConfirmed::dispatch($args);
```

- Cancelable (old `CancelableEvent`): `use CraftCms\Cms\Shared\Concerns\ValidatableEvent`, check `$event->isValid`.
- Handleable: `use CraftCms\Cms\Shared\Concerns\HandleableEvent`, check `$event->handled`.
- First non-null return: `Event::until()` or `event(..., halt: true)`.
- Implement `Illuminate\Contracts\Events\ShouldDispatchAfterCommit` to defer until the DB transaction commits.

If your plugin's old events must keep working for downstream code, the legacy Yii event system cannot be proxied without the adapter. Craft forwards new events to Yii in a static `registerEvents()` method on legacy classes (see `craft\elements\User` and `CraftCms\Yii2Adapter\Event\EventCompatibility::boot()`). The bridge pattern for your own events, and when to choose it over a clean break, is in [strategy.md](strategy.md#bridging-old-yii-events-needs-the-adapter).

## Registries (replace `RegisterComponentTypesEvent`)

Every registry extends `CraftCms\Cms\Component\TypeRegistry` with `register()` and `remove()`. Declared types are validated against the registry's `CONTRACT`. Inject registries into `boot()`:

```php
public function boot(FieldTypes $fieldTypes, WidgetTypes $widgetTypes): void
{
    $fieldTypes->register(Fields\MyField::class);
    $widgetTypes->remove(\CraftCms\Cms\Dashboard\Widgets\Feed::class);
}
```

Prefer the declarative plugin properties (`$fieldTypes`, `$widgets`, ...) where one exists. Built-in registries per the docs:

| Feature | Registry |
| --- | --- |
| Auth methods | `CraftCms\Cms\Auth\AuthMethods` |
| Element types | `CraftCms\Cms\Element\ElementTypes` |
| Field types | `CraftCms\Cms\Field\FieldTypes` |
| GraphQL directives, mutations, queries, types | `CraftCms\Cms\Gql\GqlDirectives`, `GqlMutations`, `GqlQueries`, `GqlTypes` |
| Image transformers | `CraftCms\Cms\Image\ImageTransformers` |
| Link types | `CraftCms\Cms\Field\LinkTypes` |
| Nested entry field types | `CraftCms\Cms\Field\NestedEntryFieldTypes` |
| Template cache collectors | `CraftCms\Cms\View\TemplateCacheCollectors` |
| Utility types | `CraftCms\Cms\Utility\UtilityTypes` |
| Widget types | `CraftCms\Cms\Dashboard\WidgetTypes` |

The docs' "Initialization" page shows `AuthMethodCatalog` in one snippet. The registries page says `AuthMethods`. Verify in source.

Registry-like catalogs that take an identifier plus a closure (lazily invoked, DI supported):

- Asset file kinds: `CraftCms\Cms\Asset\AssetFileKinds::register('drawing', ['label' => ..., 'extensions' => [...]])`
- Native field layout fields: `CraftCms\Cms\FieldLayout\NativeFields`
- CP settings tiles: `CraftCms\Cms\Cp\Settings::registerSetting()` / `registerReadOnlySetting()`
- System messages: `CraftCms\Cms\SystemMessage\SystemMessages` (plugins: implement `getSystemMessages()` instead)
- Permission groups: `CraftCms\Cms\User\UserPermissions::registerPermissionGroup()`
- Template roots: `CraftCms\Cms\View\TemplateRoots::register(TemplateMode::Cp, 'prefix', ...$paths)`
- Cache-clearing options: `CraftCms\Cms\Utility\Utilities\ClearCaches::add()` / `addTag()`
- Migration tracks: `CraftCms\Cms\Database\Commands\MigrateCommand::registerMigrator()` (normally use the plugin's default track)

Custom registries: extend `TypeRegistry`, set `CONTRACT`, optional `DEFAULT_TYPES` and `PROTECTED_TYPES`, override `identity()` if class string is not the identity. Make it a singleton so every consumer sees the same registrations:

```php
#[\Illuminate\Container\Attributes\Singleton]
class GatewayTypes extends \CraftCms\Cms\Component\TypeRegistry
{
    protected const ?string CONTRACT = GatewayInterface::class;
    protected const array DEFAULT_TYPES = [Dummy::class, Manual::class];
}

// another plugin, in boot():  $gatewayTypes->register(MyGateway::class);
```

Other core registries that plugins use: `CraftCms\Cms\Gql\GqlArguments::register('hasProduct', HasProduct::class)`, and (on newer 6.x builds) the control panel UI node and control type registries. Where the plugin kept a legacy `EVENT_REGISTER_*_TYPES` event, reconcile old handlers into the registry after every plugin has booted (`app()->booted(...)`).

## Upgrading a plugin's own events (clean break, verified)

A Craft 5 plugin that triggers its own Yii events from a controller:

```php
public const EVENT_BEFORE_SAVE_ENTRY = 'beforeSaveEntry';   // on the controller
$this->trigger(self::EVENT_BEFORE_SAVE_ENTRY, $event);        // $event extends CancelableEvent
if (!$event->isValid) { ... }
```

becomes plain event classes, dispatched with `event()`:

```php
use CraftCms\Cms\Shared\Concerns\ValidatableEvent;

class SavingGuestEntry
{
    use ValidatableEvent;                       // public bool $isValid = true

    public bool $isSpam = false;

    public function __construct(public Entry $entry) {}
}

event($saving = new SavingGuestEntry($entry));
if (!$saving->isValid) { ... }
```

- Name events object-action: `SavingGuestEntry` (before), `SavedGuestEntry` (after), `GuestEntrySaveFailed` (after an error).
- Drop `hasEventHandlers()` checks: dispatching an event with no listeners is cheap.
- Listeners are registered with `Event::listen(fn (SavingGuestEntry $e): void => ...)`, a plugin's `$events` map, or a subscriber. Listeners receive the event only: there is no `sender`.
- If you don't keep a compatibility layer, document every removed constant and a before and after listener in `UPGRADE.md` (see `assets/UPGRADE.template.md`).
- Test every path: normal, a listener that rejects, a listener that flags spam, and a failure ([testing.md](testing.md)).
