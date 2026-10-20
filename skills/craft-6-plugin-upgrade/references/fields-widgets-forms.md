# Field types, widgets, utilities and settings forms

Source: Craft 6.x extend docs, "Field Types", "Widgets", "Settings + Config". The "Elements" and "Forms" pages were not fully reviewed. Read `CraftCms\Cms\Form` in the 6.x source or the Forms docs page before writing a non-trivial form.

**API names changed during the alpha.** On 6.0.0-alpha.20 the settings API is `CraftCms\Cms\Form\{Form,FormContext}` with `settingsForm()`. Newer 6.x builds rename it to `CraftCms\Cms\Ui\{Ui,UiContext}`, `settingsUi(UiContext $context = new UiContext): Ui`, with nodes in `CraftCms\Cms\Ui\Nodes\*` and controls in `CraftCms\Cms\Ui\Controls\*`. The structure is the same. Check the installed package (`ls vendor/craftcms/cms/src/Form vendor/craftcms/cms/src/Ui`) and use whichever exists. Examples below use the alpha.20 names.

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
- A widget that only shows an HTML body can share a trait that returns `'craft:html-widget'` from `component()` and `['html' => template('plugin/_widgets/x', $vars, TemplateMode::Cp)]` from `props()`. Pass `TemplateMode::Cp` explicitly.
- Never render user-supplied HTML/Twig in a widget, because anyone with CP access can configure widgets.
- Template-driven widgets: Markdown files with YAML front matter in the project's `resources/widgets/`.

## Utilities, element types, and others

- Utilities: `protected array $utilities = [...]` or `UtilityTypes`.
- Element types: `protected array $elementTypes = [...]` or `ElementTypes`. There is no official upgrade guide for elements. See [element-types.md](element-types.md) for the map, then read the 6.x source and the adapter's `@deprecated` tags, and tell the user what is unverified.
- Auth methods: `AuthMethods` registry (see [events-and-registries.md](events-and-registries.md)).
- GraphQL, link types, image transformers, asset file kinds: registries (same file).

## Plugin settings form (verified on guest-entries)

A plugin's CP settings page is a `Form` returned from `settingsForm()` (set `public bool $hasCpSettings = true;`). Craft renders it in the `settings` namespace and fills it from the settings class's `validationData()`, so control paths are the settings property names. They can be arrays for nested values:

```php
use CraftCms\Cms\Form\Controls\Choice;
use CraftCms\Cms\Form\Controls\Lightswitch;
use CraftCms\Cms\Form\Form;
use CraftCms\Cms\Form\FormContext;
use CraftCms\Cms\Form\Nodes\CopyAttribute;
use CraftCms\Cms\Form\Nodes\Field;
use CraftCms\Cms\Form\Nodes\Group;

public function settingsForm(FormContext $context = new FormContext): ?Form
{
    $form = Form::make();

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
- Control classes and nodes live in `CraftCms\Cms\Form\Controls` and `CraftCms\Cms\Form\Nodes`. `Choice` takes `options([['label' => ..., 'value' => ...]])`. `Field::make($label, $control)` takes `instructions()`, `tip()`, `required()`.
- UIDs are valid path segments (they contain hyphens, not dots), but avoid dots in your own keys.
- To check the result, request the settings page as a logged-in user and read the Inertia JSON ([testing.md](testing.md)).
- To show config-file overrides, read `config('craft.<handle>')`; a key is present when set in `config/craft/<handle>.php`.
- A plugin with its own multi-page settings area doesn't use `settingsForm()` at all: set `$hasCpSettings = false` and `$hasReadOnlyCpSettings = true`, override `getSettingsResponse()` to redirect to your first settings page, and register each page with `CraftCms\Cms\Cp\Settings::registerSetting()` and `registerReadOnlySetting()`.
- To show that a value is controlled from the config file, read the config (`Config::get('craft.<handle>')`) and add a `->warning(...)` to the field.
- Custom controls or nodes with a Vue front end: bundle with the plugin's `$vite` input and register the component from JS with `window.Cp.$components.register(...)`. The PHP side implements the node or control contract and is registered with the matching registry.
- Settings that have been removed or moved: override `setAttributes()` on the settings class and `unset()` the removed keys before calling `parent::setAttributes()`, so old project config and `config/craft/<handle>.php` files that still contain them don't break.
- Optional: return a `FormRequest` class from `getSettingsRequestClass()` to validate the whole request instead of just the settings model. Rules then use `settings.`-prefixed keys.
