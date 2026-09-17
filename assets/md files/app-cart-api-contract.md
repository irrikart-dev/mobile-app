# IrriKart — App Cart API Contract (v1)

**Audience:** mobile app team
**Owner:** backend team
**Last updated:** 2026-09-13

This document is the agreed contract for the cart. Every cart endpoint is **user-scoped and
auth-only** — there is no guest/anonymous cart. A user must be logged in (a valid Firebase ID
token) before any cart call, including reading the cart. There is nothing to migrate on
login/logout: the cart is always the caller's own, resolved server-side from the token.

---

## 1. Status legend

| Endpoint                                | Status                                   |
| ---------------------------------------- | ----------------------------------------- |
| `GET /api/v1/cart`                     | **Live** — implemented 2026-09-13 |
| `POST /api/v1/cart/items`              | **Live** — implemented 2026-09-13 |
| `PATCH /api/v1/cart/items/{itemId}`    | **Live** — implemented 2026-09-13 |
| `DELETE /api/v1/cart/items/{itemId}`   | **Live** — implemented 2026-09-13 |
| `DELETE /api/v1/cart`                  | **Live** — implemented 2026-09-13 |

There is no admin-side equivalent — carts are not manageable from the dashboard.

---

## 2. Base URL and versioning

```
{API_BASE}/api/v1
```

Same base as the catalogue API. Additive fields are not breaking — **parse defensively and
ignore unknown fields**.

---

## 3. Authentication

**Every cart endpoint requires:**

```
Authorization: Bearer <Firebase ID token>
```

No exceptions — even `GET /cart` on a brand-new account (with no cart yet) requires a valid
token; it just returns an empty cart rather than a 401 for "not found." Tokens are verified
with `checkRevoked: true`. On `401`, refresh the Firebase ID token once and retry; if the
retry also fails, send the user to login.

There is no `guestToken` / anonymous cart concept. Do not build local-cart-then-merge flows —
build straight against the logged-in cart from day one.

---

## 4. Response envelope

Same envelope as every other endpoint in this API.

**Success**

```json
{ "success": true, "data": { } }
```

**Error**

```json
{ "success": false, "message": "Cart item not found", "details": { } }
```

| Status  | Meaning                              | App behaviour                                       |
| ------- | ------------------------------------- | ---------------------------------------------------- |
| `200` | OK                                     | —                                                    |
| `400` | Bad request / validation              | Fix the request (e.g. `quantity` must be `>= 1`) |
| `401` | Missing, invalid or revoked token     | Refresh token once, then re-login                     |
| `404` | Variant or cart item not found        | Refresh the cart from `GET /cart`                   |
| `409` | Requested quantity exceeds stock      | Show "only N available", refresh the cart             |
| `5xx` | Server error                          | Retry with backoff, show generic error                |

---

## 5. Endpoints

### 5.1 Get cart

```http
GET /api/v1/cart
```

No parameters. Returns the caller's cart. **If the user has never added anything, this is a
`200` with an empty cart** (`items: []`), never a `404`.

```json
{
  "success": true,
  "data": {
    "id": "cmg3x9y0z000001",
    "status": "ACTIVE",
    "items": [ /* Cart item objects, see §6 */ ],
    "itemCount": 3,
    "subtotal": 417,
    "total": 417
  }
}
```

`total` is currently always equal to `subtotal` — no tax/shipping/discount line yet. Both
fields exist so a future addition (shipping, promo) doesn't change the response shape.

---

### 5.2 Add item

```http
POST /api/v1/cart/items
Content-Type: application/json

{ "variantId": "cmf1a2b3c000009", "quantity": 2 }
```

| Field         | Type   | Required | Notes                                                    |
| ------------- | ------ | -------- | --------------------------------------------------------- |
| `variantId` | string | yes      | The product's variant `id` — **not** the SKU or slug |
| `quantity`  | int    | no       | `>= 1`, default `1`                                    |

If the variant is already in the cart, this **adds to the existing quantity** — it does not
create a duplicate line and does not reset the quantity. The price stored against the line
(`priceSnapshot`) is always read fresh from the product's current price at the moment of the
call, never trusted from the client.

Returns the **full updated cart** (same shape as §5.1), not just the added line — use it to
refresh the cart badge/screen in one round trip.

Errors:
- `404` — variant does not exist.
- `409` — requested quantity (added to whatever is already in the cart) exceeds what's
  available. The message names how many are actually available.

---

### 5.3 Update item quantity

```http
PATCH /api/v1/cart/items/{itemId}
Content-Type: application/json

{ "quantity": 5 }
```

`itemId` is the cart line's `id` (from `GET /cart` → `items[].id`), **not** the `variantId`.

`quantity` must be `>= 1`. **`quantity: 0` is rejected as `400`** — it is not a way to remove
a line. To remove a line, use `DELETE /cart/items/{itemId}` (§5.4) instead. This is a
deliberate rule, not an oversight: don't special-case zero client-side, just call delete.

Returns the full updated cart. Errors: `404` if the item isn't in the caller's cart, `409` if
the new quantity exceeds availability.

---

### 5.4 Remove item

```http
DELETE /api/v1/cart/items/{itemId}
```

Removes one line entirely. Returns the full updated cart. `404` if the item isn't in the
caller's cart (already removed, or never existed) — treat this as "already gone," not an
error worth surfacing to the user.

---

### 5.5 Clear cart

```http
DELETE /api/v1/cart
```

Removes every line. Always `200`, even if the cart was already empty. Returns the empty cart
shape (same as a brand-new account's `GET /cart`).

---

## 6. Cart item object

```json
{
  "id": "cmg3x9y0z100001",
  "variantId": "cmf1a2b3c000009",
  "productId": "cmf1a2b3c000008",
  "name": "Bubbler",
  "slug": "bubbler",
  "image": "https://<project>.supabase.co/storage/v1/object/public/assets/products/9f2c.jpg",
  "sku": "IK-BUBBLER",
  "unit": "piece",
  "quantity": 3,
  "price": 139,
  "lineTotal": 417,
  "available": 21
}
```

| Field         | Type          | Notes                                                                                   |
| ------------- | ------------- | ---------------------------------------------------------------------------------------- |
| `id`        | string        | This cart line's id. Use it for PATCH/DELETE on this line — **not** `variantId`     |
| `variantId` | string        | The product variant this line points at                                                  |
| `productId` | string        | For linking back to the product detail screen                                            |
| `name`      | string        | Product title, denormalised so the cart screen needs no second call                      |
| `slug`      | string        | For deep-linking back to the product                                                     |
| `image`     | string\| null | Absolute URL, same convention as the catalogue's `imageUrl`.`null` → placeholder      |
| `sku`       | string        | Human-readable code                                                                       |
| `unit`      | string        | Pack unit, same enum as catalogue's `unit`                                              |
| `quantity`  | number        | Current line quantity                                                                    |
| `price`     | number        | Price **at the time this line was last touched** (add or quantity update), INR, whole rupees |
| `lineTotal` | number        | `price * quantity`                                                                      |
| `available` | number        | `stock - reserved` on the variant **right now** — may be less than `quantity` if stock dropped after adding; show a warning, don't auto-adjust |

### Price re-checks

`price` on a cart line reflects whatever the product's price was the last time that line was
added to or its quantity changed — **not** necessarily the current live price. The backend
re-reads the live price on every add/update call, so the line is only ever as stale as "since
your last touch." Always re-fetch the cart (`GET /cart`) immediately before checkout so the
totals you charge against are current — same rule as the catalogue contract's "re-fetch
before checkout."

### `available` vs `quantity`

`available` can be lower than `quantity` if someone else bought stock after this line was
added. This is not an error state from the API's point of view — the line still exists as
the user left it. The app should surface this (e.g. "only 2 left, you have 3 in cart") and
let the user decide, rather than silently clamping the quantity.

---

## 7. Errors, retries and offline

Same rules as the catalogue contract:
- Retry only `5xx` and network failures, exponential backoff, max 3 attempts.
- Never retry `4xx`.
- Never allow checkout from a cached/offline cart view without a successful `GET /cart`
  re-fetch immediately beforehand.

---

## 8. Changing this contract

Additive fields ship without notice — parse defensively. Any removal or type change is
announced here with a date, with one release of overlap before removal. Breaking changes
bump `/v1` to `/v2`.

Questions or a field you need that isn't here: raise it with the backend team before building
a workaround client-side.
