# Field types, widgets, utilities and settings forms

Source: Craft 6.x extend docs, "Field Types", "Widgets", "Settings + Config". The "Elements" and "Forms" pages were not fully reviewed. Read `CraftCms\Cms\Ui` in the 6.x source before writing a non-trivial form.

**API names changed during the alpha.** Current 6.x calls the UI builder `CraftCms\Cms\Ui\{Ui,UiContext}`, with `settingsUi(UiContext $context = new UiContext): ?Ui`, nodes in `CraftCms\Cms\Ui\Nodes\*` and controls in `CraftCms\Cms\Ui\Controls\*`. 6.0.0-alpha.20 and the published docs still use the older names: `CraftCms\Cms\Form\{Form,FormContext}`, `settingsForm()` and `formControl()`. Code written against the old names doesn't load on current 6.x. Check the installed package (`ls vendor/craftcms/cms/src/Ui`) and lock `craftcms/cms` to `6.x-dev` while the tagged alpha lacks `Ui`.

## Field types

- Register: `protected array $fieldTypes = [PatternField::class];` on the plugin, or the `FieldTypes` registry in `boot()`.
- Custom field layout elements: listen to `CraftCms\Cms\FieldLayout\Events\FieldLayoutUIElementsResolving` (no plugin property). New field types rarely need one, because Craft wraps each instance in `CustomField`.
- Rules: `getRules()` (the field's settings) and `getElementRules()` (stored content). The adapter wraps legacy `defineRules()` / `getElementValidationRules()`.
- Settings UI: implement `settingsUi(UiContext $context = new UiContext): ?Ui` returning `Ui::make([...])` with `Field::make(...)` nodes and controls such as `Text`, `Table`, `Choice`, `Number`. The class is re-hydrated with current input on each call, so use ordinary `if` logic to show conditional controls. The adapter shims legacy `getSettingsHtml()`.
- Input UI: implement `uiControl(FieldContext $context): Control` and return only the control (for example `Textarea::make($context->path)->value($context->value)->rows(4)`). Craft wraps it with label/instructions. The adapter shims `inputHtml()`. Inline editing still uses `inputHtml()` for now (the docs say this may change during alpha).
- Query handling: `queryCondition()` becomes `modifyQuery(Builder $query, array $instances, mixed $value, ElementQueryInterface $elementQuery): void`. Mutate the builder using macros such as `whereParam()`/`whereNumericParam()` and `static::valueSql($instances, 'key')`. Throw or return early to reject a value (Craft swallows the exception).
- `dbType()` still drives default query translation.
- **Renamed field class:** fields store their class name in the `fields` table and in project config. If the class moved (`craft\simpletext\Field` to `MyOrg\SimpleText\Fields\SimpleText`), ship a migration that updates both, as core's `src/Database/Migrations/0000_00_00_000004_migrate_field_types.php` does: `DB::table(Table::FIELDS)->where('type', $old)->update(['type' => $new])`, then `ProjectConfig::find()` and `set("$path.type", $new)` with `muteEvents` on. Plugin install marks pending migrations as applied, so it only runs on upgrades. Old settings may be stored as strings (`'6'`), so rules must accept numeric strings.
- Monospace inputs: `Text::make(...)->monospace()` and `Textarea::make(...)->monospace()` (there is no `code()`).
- `Choice::make(...)->allOption()` saves `['*']` from the control panel, not `'*'`. Check with `in_array(Choice::ALL_VALUE, (array) $value, true)` so a `'*'` from a config file also matches.
- A custom input with its own JavaScript (Craft 5 code that initialized a library on the textarea): extend the closest control, return your component name from `component()` (for example `'my-plugin:textarea'`), register the class with the `CraftCms\Cms\Ui\UiControlTypes` registry in `boot()`, and register the component from a `$scripts` file with `window.Cp.booting(cp => cp.$components.register(...))`. Pass attributes straight to the core component rather than wrapping it in a `<div>` (`<craft-field>` only shows slotted children), skip read-only and disabled inputs, and dispatch an `input` event after a library changes the value, or the change isn't saved. Core's Markdown field is the model.

## Widgets

- Extend `CraftCms\Cms\Dashboard\Widgets\Widget`. Register with `protected array $widgets = [...]` or `WidgetTypes`.
- Static: `displayName()`, `icon()`, `isSelectable()`, `allowMultipleInstances()`. Instance: `getTitle()`, `settingsUi()`, `getRules()`.
- Widgets render client-side: `component()` returns a component name, `props()` returns props. For HTML only: `'craft:html-widget'` with `['html' => template(...)]`. Custom Vue components register via `Cp.$components.register(...)` in a published JS file.
- A widget that only shows an HTML body can share a trait that returns `'craft:html-widget'` from `component()` and `['html' => template('plugin/_widgets/x', $vars, TemplateMode::Cp)]` from `props()`. Pass `TemplateMode::Cp` explicitly.
- Never render user-supplied HTML/Twig in a widget, because anyone with CP access can configure widgets.
- Template-driven widgets: Markdown files with YAML front matter in the project's `resources/widgets/`.

## Utilities, element types, and others

- Utilities: `protected array $utilities = [...]` or `UtilityTypes`. `contentHtml()` is compiled as a Vue template, so legacy HTML with inline scripts doesn't work. Return a tag for your own component (`Html::tag('MyUtility')`, as core's `FindAndReplace` does) and register the component from JS ([templates-and-twig.md](templates-and-twig.md#control-panel-front-end)).
- Element types: `protected array $elementTypes = [...]` or `ElementTypes`. There is no official upgrade guide for elements. See [element-types.md](element-types.md) for the map, then read the 6.x source and the adapter's `@deprecated` tags, and tell the user what is unverified.
- Auth methods: `AuthMethods` registry (see [events-and-registries.md](events-and-registries.md)).
- GraphQL, link types, image transformers, asset file kinds: registries (same file).

## Plugin settings form (verified on guest-entries)

A plugin's CP settings page is a `Ui` returned from `settingsUi()` (set `public bool $hasCpSettings = true;`). Craft renders it in the `settings` namespace and fills it from the settings class's `validationData()`, so control paths are the settings property names. They can be arrays for nested values:

```php
use CraftCms\Cms\Ui\Controls\Choice;
use CraftCms\Cms\Ui\Controls\Lightswitch;
use CraftCms\Cms\Ui\Nodes\CopyAttribute;
use CraftCms\Cms\Ui\Nodes\Field;
use CraftCms\Cms\Ui\Nodes\Group;
use CraftCms\Cms\Ui\Ui;
use CraftCms\Cms\Ui\UiContext;

public function settingsUi(UiContext $context = new UiContext): ?Ui
{
    $form = Ui::make();

    foreach ($sections as $section) {
        $form->add(
            Group::make("section-$section->uid", [
                Field::make(t('Allow guest submissions', category: 'my-plugin'),
                    Lightswitch::make(['sections', $section->uid, 'allowGuestSubmissions'])),
                Field::make(t('Default Author', category: 'my-plugin'),
                    Choice::make(['sections', $section->uid, 'authorUid'])
                        ->options([['label' => 'admin', 'value' => $uid]])
                        ->placeholder('')),
                CopyAttribute::make("section-uid-$section->uid", $section->uid),
            ])->label($section->name)->collapsible(),
        );
    }

    return $form;
}
```

- This replaces a Twig `editableTableField` template. A table is not required: groups of fields per row work well.
- Control classes and nodes live in `CraftCms\Cms\Ui\Controls` and `CraftCms\Cms\Ui\Nodes`. `Choice` takes `options([['label' => ..., 'value' => ...]])`. `Field::make($label, $control)` takes `instructions()`, `tip()`, `required()`.
- UIDs are valid path segments (they contain hyphens, not dots), but avoid dots in your own keys.
- To check the result, request the settings page as a logged-in user and read the Inertia JSON ([testing.md](testing.md)).
- To show config-file overrides, read `config('craft.<handle>')`; a key is present when set in `config/craft/<handle>.php`.
- A plugin with its own multi-page settings area doesn't use `settingsUi()` at all: set `$hasCpSettings = false` and `$hasReadOnlyCpSettings = true`, override `getSettingsResponse()` to redirect to your first settings page, and register each page with `CraftCms\Cms\Cp\Settings::registerSetting()` and `registerReadOnlySetting()`.
- To show that a value is controlled from the config file, read the config (`Config::get('craft.<handle>')`) and add a `->warning(...)` to the field.
- Custom controls or nodes with a Vue front end: bundle with the plugin's `$vite` input and register the component from JS with `window.Cp.$components.register(...)`. The PHP side implements the node or control contract and is registered with the matching registry.
- Settings that have been removed or moved: override `setAttributes()` on the settings class and `unset()` the removed keys before calling `parent::setAttributes()`, so old project config and `config/craft/<handle>.php` files that still contain them don't break.
- Optional: return a `FormRequest` class from `getSettingsRequestClass()` to validate the whole request instead of just the settings model. Rules then use `settings.`-prefixed keys.
