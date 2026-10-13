# Models, records, settings and validation

Source: Craft 6.x extend docs, "Models, Records, and Data", "Validation", "Settings + Config".

## Models vs records

- Craft 5 `craft\db\Record` becomes an Eloquent model, usually extending `CraftCms\Cms\Shared\BaseModel` (gives `dateCreated`, `dateUpdated`, `dateDeleted`; add `CraftCms\Cms\Shared\Concerns\HasUid` for UIDs).
- Eloquent models only describe the database shape. In Craft's own code they no longer carry validation, events or behavior. Plugins are not required to follow that split.
- Most `craft\base\Model` subclasses become data objects extending `CraftCms\Cms\Component\Component` (constructor config, typecasting, validation, array access, macros).
- Opt in piecemeal with `CraftCms\Cms\Validation\Contracts\Validatable` + `CraftCms\Cms\Validation\Concerns\Validates`, the `#[Ruleset]` attribute, and `CraftCms\Cms\Support\Typecast::configure()`.
- Small data-only models can often become plain arrays, validated at the input layer.
- Behaviors have no equivalent. For `Macroable` classes (everything extending `Component`), register macros in `boot()`: `Site::macro('isB2b', fn () => ...)`. For instance-level events, use a subscriber.

## Settings

`createSettingsModel()` becomes `createSettings()` and must return a `CraftCms\Cms\Plugin\PluginSettings` subclass (or `null`). Treat it as a drop-in for `craft\base\Model`.

Resolved settings come from, in increasing precedence: defaults on the settings class, project config (`plugins.{handle}.settings`), then the project's `config/craft/{plugin-handle}.php`.

- Ship a config stub at `config/<plugin-handle>.php` in the package, and `HasConfig` publishes it. It may return an array or a fluent object (`Demo::config()->apiKey(env('KEY'))`). Fluent methods are yours to write. `Plugin::config()` only *builds*. Read resolved values with `getSettings()`.
- Environment overrides: `Env::config($class, 'MY_PLUGIN_NS_')`. Wrap rules that must see *parsed* env/alias values in `CraftCms\Cms\Validation\Rules\EnvValueRule`.
- Only settings defined in a published config file are pushed into `config('craft.plugin-handle.*')`. A key's presence there means "controlled from config".
- CP settings page: set `$hasCpSettings = true` and implement `settingsForm(FormContext $context = new FormContext): ?Form` (see [fields-widgets-forms.md](fields-widgets-forms.md)). Existing `settingsHtml()` is shimmed by the adapter.
- Custom normalization: return your own `FormRequest` class from `getSettingsRequestClass()`. Rules are then evaluated against the whole request, so prefix keys with `settings.`.

## Validation

Craft 5 `defineRules()` (Yii rules) becomes Laravel rules, keyed by attribute with arrays of rule strings or objects.

```php
// on a Component / PluginSettings
public function getRules(): array
{
    return array_merge(parent::getRules(), [
        'adminNotificationAddress' => ['required', 'email:rfc'],
    ]);
}
```

Alternatives: `rulesClass()` returning a ruleset class, or the `#[Ruleset(MyRules::class)]` attribute. Rulesets come from the `craftcms/laravel-ruleset-validation` package, and extending `CraftCms\Cms\Validation\Ruleset` emits events as rules resolve.

Validatable API: `getRules()`, `errors()`, `getFirstErrors()`, `getMessages()`, `attributeLabels()`, `addModelErrors()`, `validationData()`, `prepareForValidation()`, `validate()`, `passedValidation()`, `failedValidation()`, `afterValidate()`.

Where possible move validation to the input layer:

- `$request->validate([...])` in a controller.
- A `FormRequest` class injected into the controller.
- A ruleset injected into the controller: call `$ruleset->validate()` yourself, because it is not a `FormRequest` and does not auto-run.
- Yii scenarios: supported through the ruleset package (scenarios are strings, centralize as constants or an enum).

Modify other plugins' or Craft's rules by listening to `CraftCms\Cms\Element\Validation\Events\ValidationRulesResolving` and calling `$event->addRule()`.

Field types have two rule sets: `getRules()` (field settings) and `getElementRules()` (content on an element). The adapter wraps legacy `defineRules()` and `getElementValidationRules()`.
