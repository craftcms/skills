# Field types, widgets, utilities and element types

Published docs: [fields.md](https://craftcms.com/docs/6.x/extend/fields.html), [widgets.md](https://craftcms.com/docs/6.x/extend/widgets.html), [forms.md](https://craftcms.com/docs/6.x/extend/forms.html) (written for the older `Form` API; the classes are now `Ui`). Copy the shape of the closest built-in component; they are the best examples.

## Field types

Base class `CraftCms\Cms\Field\Field`. Built-ins to copy: `Field/PlainText.php` (simple scalar), `Field/Number.php`, `Field/Dropdown.php` (options), `Field/Json.php`. Register with `protected array $fieldTypes = [Fields\Rating::class];`.

```php
<?php

declare(strict_types=1);

namespace Acme\Ratings\Fields;

use CraftCms\Cms\Element\Contracts\ElementInterface;
use CraftCms\Cms\Element\Contracts\ElementQueryInterface;
use Illuminate\Database\Query\Builder;
use CraftCms\Cms\Field\Field;
use CraftCms\Cms\Field\FieldContext;
use CraftCms\Cms\Ui\Contracts\Control;
use CraftCms\Cms\Ui\Controls\Number;
use CraftCms\Cms\Ui\Ui;
use CraftCms\Cms\Ui\UiContext;
use CraftCms\Cms\Ui\Nodes\Field as FormField;
use CraftCms\Cms\Support\Query;
use Override;

use function CraftCms\Cms\t;

class Rating extends Field
{
    public int $max = 5;                      // field settings are public properties

    #[Override]
    public static function displayName(): string
    {
        return t('Rating', category: 'ratings');
    }

    #[Override]
    public static function icon(): string
    {
        return 'star';
    }

    #[Override]
    public static function phpType(): string
    {
        return 'int|null';
    }

    #[Override]
    public static function dbType(): array|string|null
    {
        return Query::TYPE_INTEGER;          // CraftCms\Cms\Support\Query
    }

    #[Override]
    public function getRules(): array                  // rules for the field's settings
    {
        return array_merge(parent::getRules(), ['max' => ['required', 'integer', 'min:1', 'max:10']]);
    }

    public function settingsUi(UiContext $context = new UiContext): ?Ui
    {
        return Ui::make([
            FormField::make(t('Maximum', category: 'ratings'), Number::make('max')->value($this->max)),
        ]);
    }

    #[Override]
    public function uiControl(FieldContext $context): Control   // the element-edit input
    {
        return Number::make($context->path)->value($context->value)->mode($context->mode);
    }

    #[Override]
    public function normalizeValue(mixed $value, ?ElementInterface $element): mixed
    {
        if ($value === null || $value === '') {
            return null;
        }

        // Don't cast blindly: (int) '3.7' or (int) 'abc' would turn junk into a valid-looking score.
        // Leave malformed input as-is so getElementRules() rejects it.
        return filter_var($value, FILTER_VALIDATE_INT) !== false ? (int) $value : $value;
    }

    #[Override]
    public function getElementRules(ElementInterface $element): array   // rules for the stored value
    {
        return ['integer', 'min:1', "max:{$this->max}"];   // a flat list of rules for the value
    }

    #[Override]
    public static function modifyQuery(Builder $query, array $instances, mixed $value, ElementQueryInterface $elementQuery): void
    {
        // Parses '>= 4', 'not 3', [1, 2] etc. as numbers (copied from Field/Number.php).
        $query->whereNumericParam(self::valueSql($instances), $value, columnType: self::dbType());
    }
}
```

- **Structured values** (several sub-values per field, like an SEO override): `dbType()` returns `Query::TYPE_JSON`, `phpType()` `'array|null'`, `normalizeValue()` JSON-decodes strings, and `uiControl()` wraps nested controls in a `ContentBlock` (control paths are relative to the block):

  ```php
  return ContentBlock::make($context->path)->value($context->value)->mode($context->mode)
      ->addLabel(t('Override SEO', category: 'seo'))
      ->ui(Ui::make([
          UiField::make(t('Title', category: 'seo'), Text::make('title')->maxLength(255)),
          UiField::make(t('Image', category: 'seo'), ElementSelect::make('imageId')->elementType(Asset::class)->single()),
          UiField::make(t('Canonical URL', category: 'seo'), Text::make('canonical')->inputType('url')),
      ]));
  ```

  Validate nested keys in `getElementRules()` with a closure rule that runs `Validator::make($value, [...])` and passes each message to `$fail`. Use `Rule::in([...])` for options that contain commas. Translation is configured per field instance (`'translationMethod' => TranslationMethod::Site`), not by the class. See `Field/ContentBlock.php` and `Field/Json.php`.
- Field **settings** forms set values explicitly with `->value($this->prop)` (unlike plugin settings, which are filled from the context). Check the built-in you copied.
- `uiControl()` returns only the control; Craft wraps it with the label and instructions. It is re-rendered server-side on change, so conditional UI needs no JavaScript.
- `normalizeValue()` turns stored or posted data into the PHP value templates get. `serializeValue()` does the reverse (default is fine for scalars). Return value objects (in `src/Data/`) for complex values and implement `__toString()` if templates will print them.
- Query support: the default `modifyQuery()` does plain equality matching against the value stored at `dbType()`. For numeric comparisons (`.rating('>= 4')`), override it with `whereNumericParam()` as above; for dates, see `Field/Date.php`.
- Inline editing (element index tables) still uses `inputHtml()`.
- `getElementRules()` returns a flat list of Laravel rules applied to this field's value (see `Field/Number.php`).

Verify: create the field in the workbench (Settings → Fields, or with tinker), add it to an entry type's field layout, save an entry with a value through the CP or `Elements::saveElement()`, then read it back and query by it.

## Widgets

Base class `CraftCms\Cms\Dashboard\Widgets\Widget`. Widgets render in the client as Vue components. For simple output, use the built-in `craft:html-widget` component with server-rendered HTML; for interactive widgets, register your own component with `cp.$components.register('<handle>:widget-name', Component)` from your Vite bundle ([http-and-cp.md](http-and-cp.md#vue-pages)) and return that name from `component()`:

```php
class TopLinks extends Widget
{
    public int $limit = 5;

    public static function displayName(): string { return t('Top links', category: 'shortlinks'); }
    public static function icon(): ?string { return 'link'; }
    public function getTitle(): ?string { return t('Top links', category: 'shortlinks'); }

    public function component(): ?string { return 'craft:html-widget'; }

    public function props(): array
    {
        return ['html' => template('shortlinks/_widgets/top-links', ['links' => Link::query()->orderByDesc('hits')->limit($this->limit)->get()])];
    }

    public function getRules(): array { return ['limit' => ['required', 'integer', 'min:1']]; }

    public function settingsUi(UiContext $context = new UiContext): ?Ui { /* ... */ }
}
```

Register with `protected array $widgets = [Widgets\TopLinks::class];`. Confirm the method signatures (`getTitle()`, `icon()`) against `Dashboard/Widgets/Widget.php` and `RecentEntries.php`; the base class is the authority. Never render user-entered Twig in a widget, and sanitize user-entered HTML ([templates.md](templates.md#user-entered-html)).

Verify: add the widget through the dashboard UI in a browser, or with `app(\CraftCms\Cms\Dashboard\Dashboard::class)->saveWidget($widget)`. Widgets belong to a user, so from tinker log a user in first (`Auth::login($user)`), then load `/admin/dashboard` as that user. Widget output is visible to every CP user who adds it: only list entries the viewer may see (`Gate::allows('view', $entry)`, or query with the viewer's permissions), never drafts or disabled content by accident.

## Utilities

Base class `CraftCms\Cms\Utility\Utility`. Static methods: `id()` (kebab-case, URL `admin/utilities/<id>`), `displayName()`, `icon()`, `contentHtml()` (required), `toolbarHtml()`, `footerHtml()`, `badgeCount()`. Register with `protected array $utilities = [Utilities\LinkHealth::class];`. Users need the `utility:<id>` permission; admins always see it.

`contentHtml()` usually returns `template('shortlinks/_utilities/health', [...])`. Forms inside post to your own routes with `csrfInput()`.

## Element types

Custom element types are the most involved component and the upstream docs page is empty. Before starting:

1. If the data lives in your own table, extend `CraftCms\Cms\Element\Eloquent\EloquentElement` with your Eloquent model; Registering it syncs the element with its model and adds CP routes, a nav item under Content, and permissions. Read `Element/Eloquent/EloquentElement.php` and `EloquentElements.php`.
2. Otherwise read `vendor/craftcms/cms/src/Element/Element.php`, its `Concerns/`, and the smallest native element (`Address/Elements/Address.php`) with its query class and index/edit controllers.
3. Register with `protected array $elementTypes = [Elements\Redirect::class];`.

Tell the developer element types are unverified ground in this skill, and prove each part (save, query, index page, edit page, delete) in the workbench before moving on. Often an Eloquent model with CP pages ([http-and-cp.md](http-and-cp.md)) is enough and much simpler.
