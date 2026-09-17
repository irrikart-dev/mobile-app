# IrriKart — App Catalog API Contract (v1)

**Audience:** mobile app team
**Owner:** backend / admin-dashboard team
**Last updated:** 2026-09-11

This document is the agreed contract for everything the app reads out of the catalogue.
The admin dashboard writes to the same tables these endpoints read, with no cache layer in
between, so an edit saved in the dashboard is visible to the next app request.

---

## 1. Status legend

| Endpoint | Status |
|---|---|
| `GET /api/v1/catalog/categories` | **Live** — implemented 2026-09-11 |
| `GET /api/v1/catalog/products` | **Live** — implemented 2026-09-11 |
| `GET /api/v1/catalog/products/{idOrSlug}` | **Live** — implemented 2026-09-11 |

The admin-side equivalents (`/api/v1/admin/*`) already exist and are admin-token-gated.
The app must **not** call `/api/v1/admin/*` — those return admin-only fields and require an
`ADMIN` role. Build against the `/api/v1/catalog/*` shapes below; they are stable and will
not change without a version bump and notice to this team.

---

## 2. Base URL and versioning

```
{API_BASE}/api/v1
```

`API_BASE` is environment-specific (dev / staging / prod) and must be configurable in the
app build, never hardcoded. The `/v1` segment changes only on a breaking change; additive
fields are not breaking and can ship at any time, so **parse defensively and ignore unknown
fields**.

---

## 3. Authentication

Catalogue reads are **public** — no token required. Sending a Firebase ID token is harmless
but not needed.

User-scoped endpoints (cart, orders, wishlist, reviews) require:

```
Authorization: Bearer <Firebase ID token>
```

Tokens are verified with `checkRevoked: true`, so a server-side "log out all devices" takes
effect immediately. On `401` the app must refresh the Firebase ID token once and retry; if
the retry also fails, send the user to login.

---

## 4. Response envelope

Every response uses the same envelope.

**Success**

```json
{
  "success": true,
  "data": { }
}
```

**Error**

```json
{
  "success": false,
  "message": "Product not found",
  "details": { }
}
```

`details` is optional and present mainly on validation errors. Do not show `message` to end
users verbatim for `5xx` — it may be `"Internal server error"`.

| Status | Meaning | App behaviour |
|---|---|---|
| `200` | OK | — |
| `400` | Bad request / validation | Fix the request; log it |
| `401` | Missing, invalid or revoked token | Refresh token once, then re-login |
| `403` | Authenticated but not allowed | Do not retry |
| `404` | Not found, or product is not live | Show "no longer available" |
| `409` | Conflict (e.g. stock gone) | Refresh the screen |
| `5xx` | Server error | Retry with backoff, show generic error |

---

## 5. Endpoints

### 5.1 List categories

```http
GET /api/v1/catalog/categories
```

No parameters. Sorted by `name` ascending.

```json
{
  "success": true,
  "data": [
    {
      "id": "cmf1a2b3c000001",
      "slug": "drip-irrigation",
      "name": "Drip Irrigation",
      "blurb": "Emitters, fittings and laterals.",
      "imageUrl": "https://<project>.supabase.co/storage/v1/object/public/assets/products/9f2c.jpg",
      "productCount": 12
    }
  ]
}
```

`productCount` counts all products in the category, including ones not live. Do not use it
as "how many the user will see"; use the length of the product list for that.

---

### 5.2 List products

```http
GET /api/v1/catalog/products?category={categoryId}&search={text}&page=1&limit=20
```

| Param | Type | Required | Notes |
|---|---|---|---|
| `category` | string | no | Category `id` (not slug) |
| `search` | string | no | Case-insensitive match on name, slug and SKU |
| `page` | int | no | 1-based, default `1` |
| `limit` | int | no | Default `20`, max `100` |

Returns **only live products** (`active = true` in the dashboard's "Live" toggle). Products
the admin has hidden never appear here. Sorted by `updatedAt` descending.

```json
{
  "success": true,
  "data": {
    "items": [ /* Product objects, see §6 */ ],
    "page": 1,
    "limit": 20,
    "total": 43
  }
}
```

---

### 5.3 Get one product

```http
GET /api/v1/catalog/products/{idOrSlug}
```

Accepts either the `id` or the `slug`. Returns `404` if the product does not exist **or is
not live** — the app should treat both the same way.

```json
{
  "success": true,
  "data": { /* Product object, see §6 */ }
}
```

---

## 6. Product object

```json
{
  "id": "cmf1a2b3c000009",
  "sku": "IK-BUBBLER",
  "slug": "bubbler",
  "name": "Bubbler",
  "category": "cmf1a2b3c000001",
  "categoryName": "Other Products",
  "imageUrl": "https://<project>.supabase.co/storage/v1/object/public/assets/products/9f2c.jpg",
  "tagline": "Low-flow bubbler for tree basins",
  "description": "Full description text.",
  "features": ["Low-arc spray", "Adjustable flow"],
  "specs": [{ "label": "Flow rate", "value": "40 LPH" }],
  "unit": "piece",
  "price": 139,
  "inStock": true,
  "stockQty": 24,
  "rating": 0,
  "reviewCount": 0,
  "updatedAt": "2026-09-11T17:34:12.000Z"
}
```

| Field | Type | Notes |
|---|---|---|
| `id` | string | Stable primary key. Use this for cart lines, orders, analytics — **not** the slug |
| `sku` | string | Human-readable code, shown in support flows. May change if admin edits it |
| `slug` | string | URL-safe, used for deep links. Auto-derived from the name |
| `name` | string | Display title |
| `category` | string | Category `id` |
| `categoryName` | string | Denormalised for list rendering without a second call |
| `imageUrl` | string \| null | Absolute public URL. `null` means no image — render a placeholder |
| `tagline` | string | Short one-liner. May be `""` |
| `description` | string | Long text. May be `""` |
| `features` | string[] | Bullet list. May be `[]` |
| `specs` | `{label, value}[]` | Spec table rows. May be `[]` |
| `unit` | string | Pack unit: `piece`, `set`, `roll`, `pack`, `box`, `metre`, `kg`, `litre` |
| `price` | number | Selling price in **INR**, JSON number, up to 2 decimals |
| `inStock` | boolean | Admin's "In stock" switch — the buyability flag |
| `stockQty` | number | Units on hand. Can be `> 0` while `inStock` is `false` |
| `rating` | number | 0–5, `0` when unrated |
| `reviewCount` | number | Count of published reviews |
| `updatedAt` | string | ISO 8601 UTC. Changes on every admin edit |

### Buyability rule

Show "Add to cart" only when **`inStock === true` AND `stockQty > 0`**. `inStock` is the
admin's manual switch; `stockQty` is the live count. Either one being falsy means the
product is display-only.

### Fields the app must not expect

These are internal and are **not** returned by `/catalog/*`:
`active`, `source`, `reserved`, `createdAt`.

### Removed fields — do not build UI for these

Removed on **2026-09-11**. If an older spec or mock mentions them, that spec is stale.

| Field | Was | Status |
|---|---|---|
| `mrp` | List price for strikethrough display | **Removed.** There is one price only |
| `discountPercent` | Derived `mrp` vs `price` discount badge | **Removed.** No discount concept exists yet |
| `featured` | Home-screen pin flag | **Removed.** No featured rail; use a category rail instead |

Discounts will come back as a promotions feature with its own contract, not as a second
price on the product. Do not design a home screen around `featured`.

---

## 7. Freshness — how "immediately" is guaranteed

The backend adds **no caching layer**: these endpoints read PostgreSQL directly, so the
moment an admin saves, the next request returns new data. Staleness can therefore only come
from the app. Rules:

1. **No long-lived client cache.** If you cache catalogue responses, TTL must be **≤ 60 s**.
2. **Revalidate on foreground.** Re-fetch the visible screen when the app returns from
   background after more than 60 s.
3. **Pull-to-refresh** on the catalogue and category screens must bypass any local cache.
4. **Re-fetch before checkout.** Always re-read the product immediately before adding to
   cart and before payment, since price and stock are the fields most likely to have moved.
5. **Use `updatedAt` to diff.** If you keep a local store, compare `updatedAt` rather than
   deep-comparing objects.
6. **Never persist `price` across sessions.** Read it fresh; a stale price shown at checkout
   is a support incident.

`imageUrl` is always an **absolute** Supabase Storage URL — every image, including the
original catalogue's, now lives there (migrated 2026-09-11; the API no longer resolves any
relative path itself). Replacing a product's image always produces a new URL rather than
overwriting the old one, so image URLs can be cached aggressively and need no cache-busting
query string.

---

## 8. Errors, retries and offline

- Retry only `5xx` and network failures, with exponential backoff, max 3 attempts.
- Never retry `4xx`.
- On total failure, show the last known list with a clear "may be out of date" banner —
  but never allow checkout from that state without a successful re-fetch (see §7 rule 4).

---

## 9. Changing this contract

Additive fields ship without notice — parse defensively. Any **removal or type change** is
announced in this document with a date, and the backend team gives the app team one release
of overlap before removing a field. Breaking changes bump `/v1` to `/v2`.

Questions or a field you need that isn't here: raise it with the backend team before
building a workaround client-side.
