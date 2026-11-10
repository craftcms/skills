# The Commerce 6 gateway API

Read `vendor/craftcms/commerce/src/Payment/` alongside this file: `Gateway/Gateway.php`, `Gateway/Contracts/GatewayInterface.php`, `Gateway/Contracts/RequestResponseInterface.php`, `Payments.php`, `Transactions.php` and `Webhooks.php`. `Gateway/Types/Dummy.php` and `Manual.php` are small working examples.

## Class map

| Commerce 5 | Commerce 6 |
| --- | --- |
| `craft\commerce\base\Gateway` | `CraftCms\Commerce\Payment\Gateway\Gateway` |
| `craft\commerce\base\GatewayInterface` | `CraftCms\Commerce\Payment\Gateway\Contracts\GatewayInterface` |
| `craft\commerce\base\RequestResponseInterface` | `CraftCms\Commerce\Payment\Gateway\Contracts\RequestResponseInterface` |
| `craft\commerce\models\Transaction` | `CraftCms\Commerce\Payment\Data\Transaction` (the object gateways receive) |
| `craft\commerce\records\Transaction::STATUS_*`, `TYPE_*` | `CraftCms\Commerce\Payment\Models\Transaction::STATUS_*`, `TYPE_*` |
| `craft\commerce\models\PaymentSource` | `CraftCms\Commerce\Payment\Data\PaymentSource` |
| `craft\commerce\models\payments\BasePaymentForm`, `OffsitePaymentForm`, `CreditCardPaymentForm` | `CraftCms\Commerce\Payment\Forms\BasePaymentForm`, `OffsitePaymentForm`, `CreditCardPaymentForm` |
| `craft\commerce\elements\Order` | `CraftCms\Commerce\Order\Elements\Order` |
| `craft\commerce\errors\PaymentException`, `PaymentSourceException`, `PaymentSourceCreatedLaterException` | `CraftCms\Commerce\Payment\Exceptions\*` |
| `yii\base\NotSupportedException` for unsupported operations | `CraftCms\Commerce\Exceptions\NotImplementedException` |
| `Plugin::getInstance()->getTransactions()`, `getPayments()`, `getGateways()`, `getCurrencies()` | Inject or `app()` `CraftCms\Commerce\Payment\Transactions`, `Payments`, `Gateway\Gateways`, `Currencies` (facades exist in `CraftCms\Commerce\Support\Facades`) |
| `Gateways::EVENT_REGISTER_GATEWAY_TYPES` | `CraftCms\Commerce\Payment\Gateway\GatewayTypes::register()` in the plugin's `boot()` |
| `Craft::t('commerce', ...)` | `CraftCms\Cms\t(..., category: 'commerce')`, or the plugin's own category |
| `App::parseEnv()`, `App::parseBooleanEnv()` | `CraftCms\Cms\Support\Env::parse()`, `Env::parseBoolean()` |
| `UrlHelper::actionUrl()`, `siteUrl()` | `CraftCms\Cms\Support\Url::actionUrl()`, `siteUrl()` |
| `Craft::info()` / `Craft::warning()` / `Craft::error()` | `Illuminate\Support\Facades\Log` |
| `craft\web\Response` from `processWebHook()` | `Illuminate\Http\Response` (`response(...)`) |

## Methods that changed

| Commerce 5 | Commerce 6 |
| --- | --- |
| `getSettingsHtml()` with a Twig template | `settingsUi(UiContext $context = new UiContext()): ?Ui`. `getSettingsHtml()` is inherited and renders it. |
| `defineRules()` | `getRules(): array` (Laravel rules), merged with `parent::getRules()` |
| `getPaymentFormHtml(array $params): ?string` (abstract) | `paymentFormUi(BasePaymentForm $form, array $params = []): ?Ui`. `getPaymentFormHtml()` is inherited and renders it. See [payment-forms.md](payment-forms.md). |
| `getPaymentConfirmationFormHtml(array $params): string` | `paymentConfirmationFormUi(array $params = []): ?Ui` |
| `processWebHook(): craft\web\Response` | `processWebHook(): Illuminate\Http\Response` |
| `init()` | Constructor or lazy getters; gateways are components created by `Gateways::createGateway()` |

`paymentFormUi()`, `paymentConfirmationFormUi()` and a non-abstract `getPaymentFormHtml()` landed in craftcms/commerce#4442. If the installed Commerce still has an abstract `getPaymentFormHtml()`, that change isn't in your 6.x-dev yet: update Commerce rather than overriding the method.

Unchanged in name and meaning: `authorize()`, `capture()`, `completeAuthorize()`, `completePurchase()`, `purchase()`, `refund()`, `createPaymentSource()`, `deletePaymentSource()`, `getPaymentFormModel()`, every `supports*()` method, `availableForUseWithOrder()`, `getTransactionHashFromWebhook()`, `getPaymentTypeOptions()`, `showPaymentFormSubmitButton()`, `cpPaymentsEnabled()` and `getWebhookUrl()`.

## Settings

Settings are the gateway's public properties. Commerce 6 also treats public properties declared on an **abstract** subclass of `Gateway` as settings, so a shared base class for several gateway types works (craftcms/commerce#4442). Keep the property names from Commerce 5: they are the keys stored in project config.

```php
public ?string $apiKey = null;

public function getApiKey(bool $parse = true): ?string
{
    return $parse ? Env::parse($this->apiKey) : $this->apiKey;
}

#[Override]
public function getRules(): array
{
    return array_merge(parent::getRules(), [
        'paymentType' => ['required', Rule::in(['purchase'])],
        'apiKey' => ['required'],
    ]);
}

#[Override]
public function settingsUi(UiContext $context = new UiContext()): ?Ui
{
    return Ui::make([
        Field::make(t('API Key', category: 'commerce-mollie'))
            ->required()
            ->control(Text::make('apiKey')
                ->value($this->apiKey)
                ->textExpanderTriggers(SelectOptions::getEnvTextExpanderTriggers())),
    ]);
}
```

Classes: `CraftCms\Cms\Ui\Ui`, `CraftCms\Cms\Ui\UiContext`, `CraftCms\Cms\Ui\Nodes\Field`, `CraftCms\Cms\Ui\Controls\Text`, `Choice`, `Lightswitch` (check `vendor/craftcms/cms/src/Ui/Controls/` for the full list), `CraftCms\Cms\Cp\SelectOptions`. Pass the raw (unparsed) value to the control so environment variable names stay visible. Look at core settings screens, such as `CraftCms\Cms\Http\Controllers\Settings\EmailSettingsController::emailSettingsUi()`, for more patterns.

Settings that hold booleans from environment variables (`testMode`, `useSandbox`) keep `bool|string` types and a getter using `Env::parseBoolean()`.

## Responses and transaction statuses

`Payments` maps each `RequestResponseInterface` to the transaction status in this order:

1. `isSuccessful()` → `success`
2. `isProcessing()` → `processing`. The order **completes**, and a later webhook marks it paid. Use this for bank transfers and other asynchronous methods.
3. `isRedirect()` → `redirect`. Commerce sends the customer to `getRedirectUrl()`.
4. otherwise → `failed`, with `getMessage()` shown to the customer.

Commerce stores `getData()` in the transaction's `response` column, `getTransactionReference()` in `reference` and `getCode()` in `code`. Arrays and objects in `getData()` are JSON-encoded (craftcms/commerce#4442; before that they threw "Array to string conversion").

**Gateways never redirect customers themselves.** For a GET redirect, return `getRedirectMethod() === 'GET'` and the URL. For a POST redirect, return `'POST'` and the fields in `getRedirectData()`: Commerce renders an auto-submitting form, or the store's `gatewayPostRedirectTemplate`.

On the customer's return, Commerce routes `commerce/payments/complete-payment?commerceTransactionId=…&commerceTransactionHash=…` to `completePurchase()` or `completeAuthorize()`. Build return URLs with:

```php
$params = ['commerceTransactionId' => $transaction->id, 'commerceTransactionHash' => $transaction->hash];
$returnUrl = Url::actionUrl('commerce/payments/complete-payment', $params);
$cancelUrl = Url::siteUrl((string)$order->cancelUrl);
```

A response from `completePurchase()` that is still processing (the provider hasn't confirmed yet) should return `isProcessing()`, not fail, so the order completes and the webhook finishes it.

## Transaction fields gateways use

`Data\Transaction` has `id`, `hash`, `orderId`, `parentId`, `gatewayId`, `type`, `status`, `amount` and `currency` (order currency), `paymentAmount` and `paymentCurrency` (what to charge), `reference`, `code`, `message`, `note`, `response`, plus `getOrder()`, `getParent()` and `getGateway()`.

- Charge `paymentAmount` in `paymentCurrency`, not `amount`.
- Refund and capture transactions are children: their `reference` starts as the parent's reference, and `getParent()->response` holds what the original call stored. Old Commerce 5 transactions store Omnipay-era data there, so read it defensively.
- `Transactions` has `createTransaction(?Order, ?Transaction $parent, ?string $type)`, `saveTransaction()`, `getTransactionByHash()`, `getTransactionByReference()` and `getChildrenByTransactionId()`.
