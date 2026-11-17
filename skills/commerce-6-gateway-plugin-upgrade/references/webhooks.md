# Webhooks

## Routes and URLs

Commerce routes webhooks to the gateway's `processWebHook()` from two URLs. Both accept GET and POST (craftcms/commerce#4442), and both are exempt from CSRF checks:

- `actions/commerce/webhooks/process-webhook?gateway=<id>`, which `getWebhookUrl(array $params = [])` builds. Extra params are added to the query string.
- `commerce/webhooks/process-webhook/gateway/<id>`, a path with no query string, for providers that reject query strings in notification URLs (MultiSafepay). Build it with `Url::siteUrl('commerce/webhooks/process-webhook/gateway/' . $this->id)`.

`php craft commerce:gateways:webhook-url` prints a gateway's URL for the developer to paste into the provider's dashboard. If the provider takes the URL per request (Mollie, MultiSafepay), send it in the create-payment request with the transaction hash in it.

## The flow Commerce runs

`CraftCms\Commerce\Payment\Webhooks::processWebhook()`:

1. calls `getTransactionHashFromWebhook()` and, if it returns a hash, takes the cache lock `commerceTransaction:<hash>` (the same lock the customer's return takes), so the webhook and the return can't record the same payment twice
2. calls `processWebHook()` if `supportsWebhooks()` is true
3. turns uncaught exceptions into an empty response with the exception's HTTP status, or 500

So the gateway must make `getTransactionHashFromWebhook()` return the Commerce transaction hash cheaply, from a query parameter you added to the webhook URL, or a field you sent to the provider (metadata, or the hash as the provider's reference). Return `null` if it isn't there.

## Writing `processWebHook()`

```php
#[Override]
public function processWebHook(): Response
{
    $transaction = ($hash = $this->getTransactionHashFromWebhook())
        ? app(Transactions::class)->getTransactionByHash($hash)
        : null;

    if (!$transaction || $transaction->gatewayId !== $this->id) {
        return response('ok'); // nothing to do; don't make the provider retry forever
    }

    // 1. Verify: check the signature if the provider signs webhooks, and match the
    //    posted payment ID against $transaction->reference.
    // 2. Re-fetch the payment from the provider's API using the stored reference.
    //    Never trust the status in the posted body.
    // 3. Skip it if a successful child transaction of this type already exists.
    // 4. Record the result as a **new** child transaction. `saveTransaction()` refuses to update a transaction that already has an `id`; if a flow really needs to change a stored row (Stripe updates its redirect transaction's status), it has to update `CraftCms\Commerce\Payment\Models\Transaction` directly, so say why in a comment.
    $child = app(Transactions::class)->createTransaction(null, $transaction);
    $child->type = $transaction->type;
    $child->status = TransactionModel::STATUS_SUCCESS; // or STATUS_FAILED
    $child->response = $payment;
    $child->reference = $response->getTransactionReference();
    $child->code = $response->getCode();
    $child->message = $response->getMessage();
    app(Transactions::class)->saveTransaction($child);

    return response('ok');
}
```

Rules learned while porting the first-party gateways:

- **Verify everything.** Compare signatures in constant time (`hash_equals()`), computed from the **raw** body (`request()->getContent()`), not the parsed input. Check the algorithm the provider documents (Paystack signs with HMAC-SHA512, not SHA-256). Reject a missing secret instead of signing with an empty one. Return 400 or 403 for a bad signature.
- **Re-fetch the status** from the provider's API, even for signed webhooks, unless the provider's protocol is the signed notification itself (Opayo Server).
- **Match identifiers.** A webhook naming another payment, another order or another gateway's transaction is ignored.
- **Idempotency.** Providers retry and send duplicates. Record each final status once.
- **Retries.** Return 5xx only when the provider should retry, such as when its API couldn't be reached during the re-fetch. Return 2xx for things retrying won't fix.
- **Statuses.** Only record final states (paid, failed, canceled, expired). Ignore intermediate ones.
- **Only handle the events you need** (`charge.success`), and log the others.
- **Responses the provider expects** (Opayo's `Status=OK\nRedirectURL=…` text body) are returned as a `Response` with the right content type. Never `echo` or `exit()`.
- **Gateways without webhooks** return `false` from `supportsWebhooks()`. `processWebHook()` can then throw, because Commerce never calls it.

## Testing webhooks

Send real HTTP requests to the webhook route in Pest (`$this->post(...)`, `$this->get(...)`), with `Http::fake()` for the re-fetch. Cover a valid notification, a bad or missing signature, an unknown transaction, another gateway's transaction, a duplicate, a mismatched payment ID and the provider being unavailable. Laravel skips CSRF checks in tests, so a passing test doesn't prove the provider's POST gets through CSRF; that's Commerce's job, but say it's unverified.
