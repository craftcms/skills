# Replacing Omnipay

Omnipay is not ported to Commerce 6. `craftcms/commerce-omnipay` is built on the Commerce 5 gateway API and Yii, and most `omnipay/*` drivers are unmaintained. Remove both from `composer.json`, along with `php-http/guzzle7-adapter` or other HTTP adapters that only Omnipay needed.

The old Omnipay driver is still the best specification of what the plugin sends today. Before deleting it, check out the previous release branch, run `composer install`, and read `vendor/omnipay/<driver>/src/Message/*Request.php` and `*Response.php` for every endpoint, request field, hard-coded value and status check.

## What the Omnipay base classes did, and where it goes now

| `craft\commerce\omnipay\base\…` | Commerce 6 |
| --- | --- |
| `Gateway`, `OffsiteGateway`, `CreditCardGateway` | Extend `CraftCms\Commerce\Payment\Gateway\Gateway` directly. Implement every `GatewayInterface` method. |
| `RequestResponse` | The plugin's own response classes implementing `RequestResponseInterface` (below). |
| `createGateway(): AbstractGateway`, `getGatewayClassName()` | A `Client` class, built per call from the gateway settings: `new Client((string)$this->getApiKey(), $this->getTestMode())`. |
| `populateRequest(array &$request, ?BasePaymentForm $form)` | A `buildPaymentRequest(Transaction $transaction, ?BasePaymentForm $form): array` method on the gateway. |
| `createPaymentRequest()`, `createRequest()`, `prepareAuthorizeRequest()`… | The same method, building the provider's own field names. |
| `createItemBagForOrder()`, `createCard()` | Methods that build the provider's line items and customer or address objects from the order. |
| `sendRequest()`, `performRequest()`, `prepareResponse()` | `Client` method calls wrapped in a response class. |
| `EVENT_BEFORE_SEND_PAYMENT_REQUEST`, `EVENT_BUILD_GATEWAY_REQUEST` | The plugin's own Laravel event, dispatched with `event()`, whose public `$request` array listeners can change. |
| `EVENT_AFTER_CREATE_ITEM_BAG` | A line items event, or the same request event (the line items are in `$request`). |
| `EVENT_BEFORE_GATEWAY_REQUEST_SEND` | Usually no replacement. Say so in `UPGRADE.md`. |
| `sendCartInfo` setting | Keep it only if the provider still uses the line items. Otherwise remove it and document why. |
| `getPaymentFormHtml()` rendering `commerce/_components/gateways/_creditCardFields` | `paymentFormUi()` ([payment-forms.md](payment-forms.md)). |
| `processWebHook()` returning `ok` and doing nothing | Either `supportsWebhooks(): false`, or a real handler ([webhooks.md](webhooks.md)). |

Name the new event in Laravel style, after what's happening (`PaymentRequestBuilding`), and include what listeners need:

```php
class PaymentRequestBuilding
{
    /** @param array<string, mixed> $request The body of the provider's create-payment request. */
    public function __construct(
        public readonly Transaction $transaction,
        public readonly ?BasePaymentForm $form,
        public array $request,
    ) {
    }
}

// In the gateway:
$event = new PaymentRequestBuilding($transaction, $form, $this->buildPaymentRequest($transaction, $form));
event($event);
$response = $this->client()->createPayment($event->request);
```

Document the change in `UPGRADE.md` with before and after listener code. The request keys are now the provider's own parameter names, not Omnipay's (`redirectUrl` not `returnUrl`, `method` not `paymentMethod`), so say that explicitly.

## The client

One small class, one method per endpoint:

```php
class Client
{
    public const string BASE_URL = 'https://api.mollie.com/v2';

    public function __construct(private readonly string $apiKey)
    {
    }

    /** @return array<string, mixed> */
    public function createPayment(array $data): array
    {
        return $this->request()->post('payments', $data)->json() ?? [];
    }

    private function request(): PendingRequest
    {
        return Http::baseUrl(self::BASE_URL)
            ->withToken($this->apiKey)
            ->acceptJson()
            ->asJson()
            ->withUserAgent('MollieCraftCommerce/' . (InstalledVersions::getPrettyVersion('craftcms/commerce-mollie') ?? 'dev'));
    }
}
```

- Use `Illuminate\Support\Facades\Http` so tests can fake it with `Http::fake()`.
- Choose sandbox or live base URLs the same way the old driver did (usually a `testMode` setting).
- Keep any partner, referrer or attribution ID the old driver sent.
- Decide per call whether HTTP errors should throw (`->throw()`) or return the error body for the response class to report. Payment calls usually return the body, so the customer sees the provider's message. Lookups used to build forms can throw and be caught.
- Encode IDs in paths with `rawurlencode()`.
- OAuth providers (PayPal): fetch the token in the client and cache it with `Cache::remember()` until shortly before it expires.
- A maintained official SDK is fine (Stripe keeps `stripe/stripe-php`). Replace SDKs that are archived or abandoned on Packagist.

## Response classes

Wrap each provider object in a class implementing `RequestResponseInterface`. Base every decision on the provider's documented statuses, and handle error bodies that aren't the object you expected:

```php
class PaymentResponse implements RequestResponseInterface
{
    public function __construct(protected readonly array $data, protected readonly bool $completing = false)
    {
    }

    public function isSuccessful(): bool
    {
        return $this->isPayment() && $this->data['status'] === 'paid';
    }

    public function isProcessing(): bool
    {
        // e.g. bank transfers that stay open until the money arrives
    }

    public function isRedirect(): bool
    {
        return $this->isPayment() && $this->data['status'] === 'open' && $this->getRedirectUrl() !== '' && !$this->isProcessing();
    }

    public function getMessage(): string
    {
        if (!$this->isPayment()) {
            return (string)($this->data['detail'] ?? t('Unable to reach Mollie.', category: 'commerce-mollie'));
        }
        // a readable reason for failed, canceled and expired payments
    }

    // getRedirectMethod(), getRedirectData(), getRedirectUrl(), getTransactionReference(), getCode(), getData()
}
```

- `getTransactionReference()` is what later calls (complete, capture, refund, webhook) use to find the payment. Keep the same reference format as Commerce 5 when you can, so transactions made before the upgrade keep working.
- `getData()` returns the decoded array; Commerce stores it as JSON.
- Give a readable `getMessage()` for every failure. Omnipay often left it empty.
- A missing or non-JSON body (a 401 HTML page, a timeout) must fail cleanly with a message, not throw a `TypeError`.

## Amounts

Never multiply by 100. Use Commerce's currency tools:

```php
$currencies = app(Currencies::class); // CraftCms\Commerce\Payment\Currencies

// Decimal string with the currency's precision ("12.30", "1500" for JPY)
$value = $currencies->getTeller($currency)->convertToString($amount);

// Integer in the currency's minor unit (1230 for 12.30 EUR, 1500 for 1500 JPY)
$minor = (int)$currencies->getTeller($currency)->convertToMoney($amount)->getAmount();
```

Check the provider's rules for currencies with zero or three decimals: some providers use a fixed exponent instead of ISO 4217 (Paystack multiplies XOF by 100 even though XOF has no subunit). `Currencies::getSubunitFor($currency)` gives the ISO exponent.

Charge `$transaction->paymentAmount` in `$transaction->paymentCurrency`. Line items are in the order's currency, so when `paymentCurrency` differs from the order currency, either don't send line items or throw a clear error if the payment method needs them (Mollie's Klarna does).

## Things that change behavior

Record each of these in `UPGRADE.md` when they happen:

- Statuses that were treated as failures but are really pending (bank transfers, reviews). Mapping them to `isProcessing()` completes the order.
- Webhooks that used to do nothing and now record payments.
- Settings that become required (`getRules()`), because Omnipay never validated them.
- Different rounding or formatting of amounts.
- Request values that came from Omnipay defaults (card holder name, device ID, hard-coded flags).
- Removed events, templates, asset bundles and install migrations.
