# Settings, the settings page and config files

Published docs: [config.md](https://craftcms.com/docs/6.x/extend/config.html), [forms.md](https://craftcms.com/docs/6.x/extend/forms.html) (written for the older `Form` API; the classes are now `Ui`), [validation.md](https://craftcms.com/docs/6.x/extend/validation.html).

## Settings class

```php
<?php

declare(strict_types=1);

namespace Acme\Shortlinks;

use CraftCms\Cms\Plugin\PluginSettings;

class Settings extends PluginSettings
{
    public bool $enabled = true;

    public int $defaultStatusCode = 301;

    public ?string $apiKey = null;

    public function getRules(): array
    {
        return array_merge(parent::getRules(), [
            'defaultStatusCode' => ['required', 'integer', 'in:301,302,307,308'],
            'apiKey' => ['nullable', 'string'],
        ]);
    }
}
```

- `PluginSettings` extends `CraftCms\Cms\Component\Component`. Public properties are the settings: they are validated, saved to project config (`plugins.<handle>.settings`) and filled back in on boot. Use typed properties with defaults.
- Rules are Laravel validation rules keyed by property name. Craft rules live in `CraftCms\Cms\Validation\Rules\` (`HandleRule`, `EnvValueRule`, `UriFormatRule`, …).
- Arrays of rows (tables) are fine as `public array $rows = []`.

Register it on the plugin, note the method is **static**:

```php
protected static function createSettings(): Settings
{
    return new Settings;
}
```

Read settings anywhere after boot:

```php
/** @var Settings $settings */
$settings = Plugin::getInstance()->getSettings();
```

To inject it instead, bind it in `boot()`: `$this->app->instance(Settings::class, $this->getSettings());`. Then type-hint `Settings $settings` in controllers, jobs and services.

## Settings page

Set `public bool $hasCpSettings = true;` and implement `settingsUi()`. Craft routes `admin/settings/plugins/<handle>`, renders the form, saves to project config and shows the flash. Do not write a settings controller or template.

```php
use CraftCms\Cms\Ui\Controls\Choice;
use CraftCms\Cms\Ui\Controls\Lightswitch;
use CraftCms\Cms\Ui\Controls\Text;
use CraftCms\Cms\Ui\Ui;
use CraftCms\Cms\Ui\UiContext;
use CraftCms\Cms\Ui\Nodes\Field;

use function CraftCms\Cms\t;

public function settingsUi(UiContext $context = new UiContext): ?Ui
{
    return Ui::make([
        Field::make(t('Enabled', category: 'shortlinks'), Lightswitch::make('enabled')),
        Field::make(t('Default status code', category: 'shortlinks'), Choice::make('defaultStatusCode')
            ->options([
                ['label' => '301 (permanent)', 'value' => 301],
                ['label' => '302 (temporary)', 'value' => 302],
            ]))
            ->instructions(t('Used when a redirect does not set its own.', category: 'shortlinks')),
        Field::make(t('API key', category: 'shortlinks'), Text::make('apiKey')),
    ]);
}
```

- The method is `public` (the published docs show `protected`, which is a fatal error).
- Control paths are relative to the `settings` namespace: `Text::make('apiKey')`, not `settings[apiKey]`. Nested values use dots: `Text::make('limits.max')`.
- Current values and validation errors are filled in from `$context` automatically. Do not call `->value()` on plugin settings controls. Read in-progress values (for conditional fields) from `$context->values['settings'][...]`.
- Controls: `CraftCms\Cms\Ui\Controls\` (`Text`, `Textarea`, `Number`, `Lightswitch`, `Checkbox`, `Choice`, `Combobox`, `Table`, `Date`, `ElementSelect`, `Handle`, `Color`, …). Nodes: `CraftCms\Cms\Ui\Nodes\` (`Field`, `Heading`, `Callout`, `Group`, `Tab`, `MarkdownContent`, `HiddenField`, `Separator`). Read a control's class for its fluent methods before using them.
- `Field::make(?string $label, ?Control $control)`, then `->instructions()`, `->tip()`, `->warning()`, `->required()`. `Heading::make(string $uid, string $content)` and `Callout::make(string $uid, string $content)` take a unique id first.
- Mark a control `->reactive()` to rebuild the form when it changes (to show or hide dependent fields).

### Validating with a FormRequest

For cross-field rules, or to validate before the settings model is filled, return a `FormRequest` **class-string** from `getSettingsRequestClass()`:
```php
public function getSettingsRequestClass(): ?string
{
    return Http\Requests\SettingsRequest::class;
}
```

```php
<?php

declare(strict_types=1);

namespace Acme\Shortlinks\Http\Requests;

use Acme\Shortlinks\Settings;
use Illuminate\Foundation\Http\FormRequest;

class SettingsRequest extends FormRequest
{
    public function rules(): array
    {
        // Reuse the model's rules, prefixed: the request sees the whole body, not just `settings`.
        return collect(new Settings()->getRules())
            ->mapWithKeys(fn ($rules, $key) => ["settings.$key" => $rules])
            ->all();
    }
}
```

Craft passes only `$request->safe()->input('settings', [])` on to the model, so **every setting needs a rule** in the request (use `'nullable'` / `'sometimes'` for optional ones) or its submitted value is silently dropped. Keep `getRules()` on the settings model too, for config-file values and programmatic saves. Without a FormRequest, `getRules()` alone validates the save.

### Dates

The `Date` control (`CraftCms\Cms\Ui\Controls\Date`) submits a `YYYY-MM-DD` string; store it as a nullable string setting. PHP's default timezone follows Craft's system timezone, so `now()` and `Carbon::parse()` are in site time.

## Config file

Users can override settings in `config/craft/<handle>.php` in their project (`vendor/orchestra/testbench-core/laravel/config/craft/<handle>.php` in the workbench). Ship a stub at `config/<handle>.php` in the plugin root (published with `vendor/bin/testbench vendor:publish --tag=<handle>`):

```php
<?php

return [
    // 'defaultStatusCode' => 302,
];
```

Values in the published file override project config. Values from it are also in `config('craft.<handle>')`, so you can show a warning or make the control read-only when a key is overridden:

```php
use CraftCms\Cms\Ui\Enums\ControlMode;
use CraftCms\Cms\Support\Arr;

$overrides = config("craft.{$this->handle}") ?? [];
$control = Text::make('apiKey');
if (Arr::has($overrides, 'apiKey')) {
    $control->mode(ControlMode::ReadOnly);
}
```

## Environment variables

Store the raw value (`$MY_API_KEY`) and parse it when used: `CraftCms\Cms\Support\Env::parse($settings->apiKey)`. Validate the parsed value with `new EnvValueRule(['required', 'string'])`.

## Verify

- `GET /admin/settings/plugins/<handle>` renders (see [testing.md](testing.md#control-panel-requests)).
- Save valid values, then check `vendor/orchestra/testbench-core/laravel/config/craft/project/project.yaml` (or `vendor/bin/testbench tinker`) shows them under `plugins.<handle>.settings`.
- Save invalid values and expect a validation failure (422 with field errors for JSON requests) and unchanged project config. A 500 here is a Craft bug: report it rather than working around it.
