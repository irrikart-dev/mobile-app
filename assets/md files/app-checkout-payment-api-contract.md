# IrriKart — App Checkout & Payment API Contract (v1)

**Audience:** mobile app team
**Owner:** backend team
**Last updated:** 2026-09-14

This document covers placing an order from the cart, completing payment, and checking order
status/history. It assumes the app is already working against the
[cart contract](./app-cart-api-contract.md) — checkout always operates on the caller's
current cart, there is no separate "build an order" step.

---

## 1. Status legend

| Endpoint                            | Status                                                     |
| ------------------------------------ | ------------------------------------------------------------ |
| `POST /api/v1/orders/checkout`     | **Live** — implemented 2026-09-14                          |
| `GET /api/v1/orders/{id}`          | **Live** — implemented 2026-09-14, see §5                 |
| `GET /api/v1/orders`               | **Live** — implemented 2026-09-14, see §5                 |
| Razorpay webhook (server-to-server)  | **Live** — not called by the app, listed here for context |

---

## 2. Base URL, auth, envelope, errors

Same as the [cart contract](./app-cart-api-contract.md) §§2–4: same base URL, same
`Authorization: Bearer <Firebase ID token>` requirement, same `{ success, data }` /
`{ success, message, details }` envelope, same retry rules (retry `5xx`/network only,
exponential backoff, never retry `4xx`).

Checkout-specific status codes:

| Status  | Meaning                                    | App behaviour                                              |
| ------- | -------------------------------------------- | -------------------------------------------------------------- |
| `201` | Order placed, payment order created          | Proceed to open the payment widget (§3.3)                      |
| `400` | Cart empty, or invalid/expired coupon state  | Show the message, send user back to cart                       |
| `401` | Missing/invalid/revoked token                | Refresh token once, then re-login                              |
| `404` | Coupon code not found                        | Show "invalid coupon", let user remove it and retry             |
| `409` | Insufficient stock, or coupon usage limit hit | Show the message (names the line/limit), refresh cart, retry    |

---

## 3. Placing an order

### 3.1 Request

```http
POST /api/v1/orders/checkout
Content-Type: application/json

{ "couponCode": "WELCOME10" }
```

| Field         | Type   | Required | Notes                                   |
| ------------- | ------ | -------- | ----------------------------------------- |
| `couponCode` | string | no       | Omit entirely if no coupon is applied     |

No other body fields — items, quantities and prices all come from the caller's live cart
server-side. **Always `GET /cart` immediately before calling checkout** so the user sees
current totals before committing (same rule as the cart contract).

This call has side effects even before payment: it re-validates stock/price against live
data and **reserves stock** for every line (holds it so nobody else can buy it out from
under this order). Do not call it speculatively — only on the user's explicit "place order"
tap.

**The cart is *not* cleared by this call.** It stays exactly as-is until payment actually
confirms (see §4) — so `GET /cart` right after checkout still shows the same items. Don't
build UI that assumes the cart is empty right after this call returns; drive the "cart is
now empty" UI transition off the order's `status` becoming `CONFIRMED` (§5), or just
navigate the user to the order/payment screen and stop showing the cart screen for a moment
— your call, either works.

### 3.2 Response

```json
{
  "success": true,
  "data": {
    "orderId": "cmg4a1b2c000001",
    "orderNumber": "ORD-20260914-A1B2C3",
    "amount": 1499,
    "currency": "INR",
    "providerOrderId": "order_QwErTy123456",
    "provider": "razorpay",
    "keyId": "rzp_test_XXXXXXXXXXXX"
  }
}
```

| Field              | Type   | Notes                                                                 |
| ------------------ | ------ | ----------------------------------------------------------------------- |
| `orderId`         | string | Save it — this is `{id}` in §5's endpoints                            |
| `orderNumber`     | string | Human-readable order number, safe to show the user                      |
| `amount`          | number | Whole rupees (not paise), matches what was charged                      |
| `currency`        | string | Always `"INR"` today                                                  |
| `providerOrderId` | string | Pass straight through to the payment SDK as its order id                |
| `provider`        | string | Which gateway is active — always `"razorpay"` today, don't hardcode it |
| `keyId`           | string | Gateway's publishable key — pass straight through to the SDK          |

`provider` and `keyId` are deliberately generic field names, not `razorpayKeyId` — the
backend can switch payment gateways without renaming this response. If you ever see a
`provider` value other than `"razorpay"`, that's a real gateway switch, not a bug — check
back here for the field shape that gateway's SDK expects (may differ from §3.3).

### 3.3 Opening the payment widget (Razorpay, Flutter)

Using the official `razorpay_flutter` package:

```dart
final razorpay = Razorpay();
razorpay.open({
  'key': data['keyId'],
  'order_id': data['providerOrderId'],
  'amount': data['amount'] * 100, // paise — this is the one place the app deals in paise
  'currency': data['currency'],
  'name': 'IrriKart',
});
```

The widget handles card/UPI/wallet entry itself — no card data ever touches the app or this
API directly.

---

## 4. What happens after payment (read before building the confirmation screen)

The SDK's success callback (`PaymentSuccessResponse`) firing is **not** order confirmation.
It only means Razorpay accepted the payment client-side. The order only becomes truly
confirmed when Razorpay's webhook reaches the backend server-to-server and the backend
commits the reserved stock and converts the cart — this typically happens within seconds
but is not instant and not guaranteed to happen before the SDK callback returns to the app.

```
app:      POST /orders/checkout           → order PLACED, stock reserved, cart untouched
app:      opens Razorpay widget, user pays
app:      SDK success/failure callback fires   ─┐
                                                  ├─ these can arrive in either order
razorpay → backend: webhook fires              ─┘
backend:  order → CONFIRMED (success): stock committed, cart converted (now empty)
          order → CANCELLED (failure/timeout): stock released, cart left untouched
```

**Treat the SDK callback as "payment probably went through, show a pending/processing
state"** — then poll `GET /orders/{orderId}` (§5.1) until `status` leaves `PLACED`. Do not
mark an order confirmed in app UI purely off the SDK callback.

If the order ends up `CANCELLED`, the cart was never touched (see §3.1) — the same items are
still sitting there, ready for the user to retry checkout with no extra work on your end.

---

## 5. Order status and history

### 5.1 Get one order

```http
GET /api/v1/orders/{orderId}
```

`orderId` is the `orderId` from the checkout response (§3.2). Poll this after the payment
SDK's callback fires — every 2–3s is reasonable — until `status` leaves `PLACED`, or give up
after a timeout (e.g. 30s) and show "still processing, check your order history" rather than
spinning forever; the order will resolve eventually even if the webhook is delayed.

```json
{
  "success": true,
  "data": {
    "id": "cmg4a1b2c000001",
    "orderNumber": "ORD-20260914-A1B2C3",
    "status": "CONFIRMED",
    "amount": 1499,
    "currency": "INR",
    "createdAt": "2026-09-14T10:32:00.000Z",
    "items": [
      {
        "variantId": "cmf1a2b3c000009",
        "productId": "cmf1a2b3c000008",
        "name": "Bubbler",
        "slug": "bubbler",
        "image": "https://<project>.supabase.co/storage/v1/object/public/assets/products/9f2c.jpg",
        "sku": "IK-BUBBLER",
        "quantity": 3,
        "unitPrice": 139,
        "totalPrice": 417
      }
    ]
  }
}
```

`status` is one of `PLACED`, `CONFIRMED`, `PACKED`, `SHIPPED`, `DELIVERED`, `CANCELLED`,
`RETURNED`. Only `PLACED` → `CONFIRMED`/`CANCELLED` matters for the payment flow (§4); the
rest (`PACKED` onward) are fulfillment states for a future order-tracking screen, not
something you need to handle yet — treat any status you don't recognize as "show it as-is,
don't crash."

`items[].unitPrice`/`totalPrice` are the price actually charged (snapshotted at checkout),
not the product's current live price — always show these, never re-fetch the catalogue price
for a placed order.

`404` if the order doesn't exist or belongs to a different user — don't distinguish these
cases in the UI, both just mean "not your order."

### 5.2 List order history

```http
GET /api/v1/orders
```

No parameters, no pagination yet (capped at the 50 most recent — ponytail-flagged in the
backend as fine until a real account accumulates more than that). Newest first.

```json
{
  "success": true,
  "data": [
    {
      "id": "cmg4a1b2c000001",
      "orderNumber": "ORD-20260914-A1B2C3",
      "status": "CONFIRMED",
      "amount": 1499,
      "currency": "INR",
      "createdAt": "2026-09-14T10:32:00.000Z"
    }
  ]
}
```

Deliberately lighter than §5.1 — no `items` array, so an order history list screen doesn't
pay for every order's line items and images up front. Call §5.1 for a given order when the
user taps into it for detail.

---

## 6. Changing this contract

Additive fields ship without notice — parse defensively. Any removal or type change is
announced here with a date, with one release of overlap before removal. Breaking changes
bump `/v1` to `/v2`.

Questions, or a field you need that isn't here: raise it with the backend team before
building a workaround client-side.
