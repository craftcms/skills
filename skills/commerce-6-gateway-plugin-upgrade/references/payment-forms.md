# Payment forms

Commerce 6 gateways describe their payment form with the Ui builder instead of rendering Twig. `getPaymentFormHtml()` is inherited, so templates that call `gateway.getPaymentFormHtml({...})` and `cart.gateway.getPaymentFormHtml({...})` keep working.

Remove:

- the payment form Twig templates (`paymentForm.twig`, `_creditCardFields`…) and the template root registration
- the asset bundles
- any override of `getPaymentFormHtml()` or `getPaymentConfirmationFormHtml()`

## `paymentFormUi()`

```php
#[Override]
public function paymentFormUi(BasePaymentForm $form, array $params = []): ?Ui
```

- Return `null` if the gateway needs no form, such as a hosted checkout with nothing to choose. `getPaymentFormHtml()` then returns `null`, as Commerce 5 gateways without a form did.
- Name each control after the payment form model's attribute (`Choice::make('paymentMethod')`). Commerce fills in values from `$form->toArray()` and shows `$form`'s validation errors on the matching control. Errors whose key matches no control (such as `month` and `year` behind a single `expiry` control) are listed above the form instead. To show them on a control, move them onto that control's attribute in `paymentFormUi()` before returning the Ui.
- `$params` holds what the template passed to `getPaymentFormHtml()`, such as `order`.
- Commerce namespaces the names (`paymentForm[<gatewayHandle>][paymentMethod]`), as before.

A choice with grouped options:

```php
return Ui::make([
    Field::make(t('Payment Method', category: 'commerce-mollie'), Choice::make('paymentMethod')
        ->options(array_map(fn(array $method) => ['label' => $method['name'], 'value' => $method['id']], $methods))),
])->when($issuerOptions !== [], fn(Ui $ui) => $ui->add(
    // $issuerOptions items: ['label' => ..., 'value' => ..., 'group' => 'iDEAL']
    Field::make(t('Issuer', category: 'commerce-mollie'), Choice::make('issuer')->options($issuerOptions)),
));
```

If building the form needs an API call (such as listing payment methods), catch failures, log them and return `null` or a smaller form. A provider outage must not break the checkout page.

## Provider scripts and hosted fields

Card fields hosted by the provider (Stripe Elements, PayPal buttons, Worldpay.js, eWAY encryption) need markup the Ui controls can't express. Use a trusted `TemplateContent` node, and load scripts with the `HtmlStack` facade:

```php
use CraftCms\Cms\Support\Facades\HtmlStack;
use CraftCms\Cms\Ui\Nodes\TemplateContent;

HtmlStack::jsFile('https://js.paystack.co/v2/paystack.js');

return Ui::make([
    TemplateContent::make('paystack-redirect', e(t('You will be redirected', category: 'commerce-paystack')))
        ->trusted(),
]);
```

- Escape every value you put into the trusted HTML (`e()`, or `htmlspecialchars()` for attributes), especially keys and IDs from settings.
- Keep the data attributes and container classes the plugin's JavaScript reads, so the script and the posted field names don't change.
- Keep the plugin's own script in `resources/js/` and inline it with a key, so it's added once per page however many forms render: `HtmlStack::js((string)file_get_contents(dirname(__DIR__) . '/resources/js/paymentForm.js'), Position::Ready, 'commerce-eway-payment-form')` (`CraftCms\Cms\View\Enums\Position`). `HtmlStack::jsFile($url, $options, $key)` loads external scripts.
- Text controls render `name` on both the `<craft-input>` wrapper and the inner `<input>`. JavaScript that finds inputs by name must select `input[name="…"]`, not `[name="…"]`.

## `paymentConfirmationFormUi()`

For gateways with stored payment sources that need a confirmation step (such as re-entering a CVV), implement `paymentConfirmationFormUi(array $params = []): ?Ui`. `getPaymentConfirmationFormHtml()` renders it and returns `''` when it is `null`.

Two limits on Commerce 6.x-dev (the second one is unchanged from Commerce 5):

- The confirmation form renders without a payment form model, so it shows no submitted values or validation errors.
- `PaymentsController::pay()` only reads the posted payment form when the order has no payment source. When paying with a saved source, the confirmation form's fields (a CVV) don't reach the gateway. Don't build behavior on them without checking the installed Commerce.

## Front-end rendering

The rendered form is Craft's `<craft-field>` / `<craft-input>` web components wrapping plain `<input>` and `<select>` elements. On a site template the inputs post the right names and values and the errors show as a list, but labels and styling come from Craft's control panel components. Check the form in a real site template, and tell the developer if the labels are missing there. Stores that need full control can still write the form themselves using the same field names.

## Documenting it

In `UPGRADE.md`, say that the template was removed, that `getPaymentFormHtml()` still works, that the form posts the same field names, and that customizing it now means extending the gateway and overriding `paymentFormUi()`, or writing the form in the site's own template.
