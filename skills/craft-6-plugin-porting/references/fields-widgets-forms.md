# Field types, widgets, utilities and settings forms

Source: Craft 6.x extend docs, "Field Types", "Widgets", "Settings + Config". The "Elements" and "Forms" pages were not fully reviewed. Read `CraftCms\Cms\Form` in the 6.x source or the Forms docs page before writing a non-trivial form.

## Field types

- Register: `protected array $fieldTypes = [PatternField::class];` on the plugin, or the `FieldTypes` registry in `boot()`.
- Custom field layout elements: listen to `CraftCms\Cms\FieldLayout\Events\FieldLayoutUIElementsResolving` (no plugin property). New field types rarely need one, because Craft wraps each instance in `CustomField`.
- Rules: `getRules()` (the field's settings) and `getElementRules()` (stored content). The adapter wraps legacy `defineRules()` / `getElementValidationRules()`.
- Settings UI: implement `settingsForm(FormContext $context = new FormContext): ?Form` returning `CraftCms\Cms\Form\Form` with `Field::make(...)` nodes and controls such as `Text`, `Table`, `Choice`, `Number`. The class is re-hydrated with current input on each call, so use ordinary `if` logic to show conditional controls. The adapter shims legacy `getSettingsHtml()`.
- Input UI: implement `formControl(FieldContext $context): Control` and return only the control. Craft wraps it with label/instructions. The adapter shims `inputHtml()`. Inline editing still uses `inputHtml()` for now (the docs say this may change during alpha).
- Query handling: `queryCondition()` becomes `modifyQuery(Builder $query, array $instances, mixed $value, ElementQueryInterface $elementQuery): void`. Mutate the builder using macros such as `whereParam()`/`whereNumericParam()` and `static::valueSql($instances, 'key')`. Throw or return early to reject a value (Craft swallows the exception).
- `dbType()` still drives default query translation.

## Widgets

- Extend `CraftCms\Cms\Dashboard\Widgets\Widget`. Register with `protected array $widgets = [...]` or `WidgetTypes`.
- Static: `displayName()`, `icon()`, `isSelectable()`, `allowMultipleInstances()`. Instance: `getTitle()`, `settingsForm()`, `getRules()`.
- Widgets render client-side: `component()` returns a component name, `props()` returns props. For HTML only: `'craft:html-widget'` with `['html' => template(...)]`. Custom Vue components register via `Cp.$components.register(...)` in a published JS file.
- Never render user-supplied HTML/Twig in a widget, because anyone with CP access can configure widgets.
- Template-driven widgets: Markdown files with YAML front matter in the project's `resources/widgets/`.

## Utilities, element types, and others

- Utilities: `protected array $utilities = [...]` or `UtilityTypes`.
- Element types: `protected array $elementTypes = [...]` or `ElementTypes`. No porting guide existed for elements when this skill was written, so read the 6.x source and the adapter's `@deprecated` tags, and tell the user.
- Auth methods: `AuthMethods` registry (see [events-and-registries.md](events-and-registries.md)).
- GraphQL, link types, image transformers, asset file kinds: registries (same file).
