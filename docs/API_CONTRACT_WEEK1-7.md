
# IrriKart App API Contract — Week 1–7 Backend Changes

> **Superseded.** Use [API_CONTRACT.md](API_CONTRACT.md) — the full contract, covering every customer endpoint including returns, notifications and offers. This file is kept for the Week 1–7 change history only.

2026-10-07 · @Devfoundry
## Overview
The backend now supports COD, saved payment methods, payment retry, order cancellation, reorder, invoices, catalogue filters, brands, wishlist, recently viewed and guest-cart merge. The app must wire these up. This doc is the contract: every endpoint, request, response and status the app depends on.
- 
**Base URL:** `https://<api-host>/api/v1`. All paths below are relative to it.
- 
**Auth:** endpoints marked auth need `Authorization: Bearer <Firebase ID token>`. Call `POST /auth/firebase/sync` once after sign-in, as today.
- 
**Success envelope:** `{ "success": true, "data": … }`. `204` responses have no body.
- 
**Error envelope:** `{ "success": false, "message": "…", "details"?: … }`. `message` is written for end users and can be shown as-is.
- 
**Money:** whole rupees as numbers (`4500` = ₹4,500), never paise.
- 
**Dates:** ISO 8601 strings in UTC.
- 
**Live reference:** every endpoint is also in the OpenAPI spec at `/docs` (Swagger UI) and `/openapi.json`.
## Breaking changes
Only the payment-failure flow changes behaviour. Everything else is new endpoints or new fields on existing responses, which an app that ignores unknown keys will tolerate.
 | 
What | 
Before | 
Now | 
App must
 | 
Order after a failed online payment | 
`CANCELLED`, stock released | 
`PAYMENT_FAILED`, stock still held, order can be paid again | 
Treat `PAYMENT_FAILED` as a terminal state of the payment poll, and show retry and cancel actions (see Checkout & payment flow)
 | 
`POST /payments/verify` result `status` | 
`CONFIRMED`, `CANCELLED` or `PLACED` | 
`CONFIRMED`, `PAYMENT_FAILED` or `PLACED` | 
Handle `PAYMENT_FAILED`
 | 
Order `status` values | 
7 values | 
adds `PAYMENT_FAILED` | 
Map the new value to a label and colour; never crash on an unknown status
 | 
Unpaid online orders | 
stayed `PLACED` forever | 
auto-cancel after 30 min (`cancelledBy: "system"`) | 
Show cancelled orders with their `cancelReason`
Deploy order: the backend ships first. Builds of the app without these changes keep working, except that a failed payment shows as an order stuck in an unknown state.
## Auth & profile
The app can read and rename the signed-in user. Phone and email come from Firebase and can't be changed through the API.
 | 
Method | 
Path | 
Auth | 
Body | 
Returns
 | 
GET | 
`/auth/me` | 
yes | 
— | 
User
 | 
PATCH | 
`/auth/me` | 
yes | 
`{ "name": "Ravi Patil" }` (1–100 chars, trimmed) | 
updated User
User fields the app should use: `id`, `name` (nullable), `phone` (nullable), `email` (nullable), `createdAt`. Ignore any other fields.
OTP sign-in, OTP resend and password reset stay client-side in the Firebase SDK. The backend has no endpoints for them.
## Catalogue: filters, sorting, brands
`GET /catalog/products` now accepts filters and a sort. All parameters are optional and combine with AND. The response shape is unchanged: `{ items, page, limit, total }`.
 | 
Query param | 
Type | 
Meaning
 | 
`category` | 
category id | 
Products in that category
 | 
`brand` | 
brand id | 
Products of that brand
 | 
`vendor` | 
vendor id | 
One seller's storefront
 | 
`search` | 
text | 
Title, slug or SKU contains it (case-insensitive)
 | 
`minPrice`, `maxPrice` | 
number (₹) | 
Any variant priced in range; `minPrice` must be ≤ `maxPrice`
 | 
`minRating` | 
0–5 | 
Product rating ≥ value
 | 
`inStock` | 
`true` / `false` | 
`true` = marked in stock and at least one variant with stock
 | 
`sort` | 
`newest` · `price_asc` · `price_desc` · `popular` · `rating` | 
Omitted = most recently edited first
 | 
`page`, `limit` | 
int | 
Default 1 and 20; `limit` max 100
Example: `GET /catalog/products?category=cat_123&minPrice=100&maxPrice=2000&inStock=true&sort=price_asc&page=1&limit=20`
- 
**Price sort** uses each product's default (first) variant price, the same `price` shown on cards.
- 
**Popular** currently ranks by review count.
- 
**New product fields:** `brandId` and `brandName`, both nullable.
**Brands:** `GET /catalog/brands` (no auth) returns `[{ "id", "slug", "name", "productCount" }]`, sorted by name. Use it to build the brand filter.
An invalid param (bad sort, `minPrice > maxPrice`, `limit > 100`) returns `400` with `message: "Validation failed"`.
## Wishlist & recently viewed
Both lists are stored server-side per user and return the same product shape as `GET /catalog/products` items. Products that are later hidden or delisted drop out of both lists automatically.
 | 
Method | 
Path | 
Auth | 
Returns | 
Notes
 | 
GET | 
`/catalog/wishlist` | 
yes | 
`Product[]`, newest first | 
 | 
POST | 
`/catalog/wishlist/{productId}` | 
yes | 
updated `Product[]` | 
Idempotent: adding twice is fine. `404` if the product isn't live
 | 
DELETE | 
`/catalog/wishlist/{productId}` | 
yes | 
updated `Product[]` | 
No error if it wasn't there
 | 
GET | 
`/catalog/recently-viewed` | 
yes | 
`Product[]`, last 20, most recent first | 
 | 
POST | 
`/catalog/recently-viewed/{productId}` | 
yes | 
`204` | 
Call when the product page opens. A repeat view moves it to the top
For signed-out users, keep recently viewed locally and don't call these endpoints. The heart icon should show the signed-in wishlist state from `GET /catalog/wishlist`.
## Guest cart merge
Signed-out users can build a cart. The app keeps it locally as `{ variantId, quantity }` lines and posts them once after sign-in. The server cart has no guest mode.
`POST /cart/merge` (auth)
1–100 lines; `quantity` is a positive integer.
Response:
- 
**Additive:** each line adds onto whatever is already in the server cart, the same as `POST /cart/items`.
- 
**Skipped lines:** a line that can't be added (variant gone, not enough stock, or a different seller from the cart) is not added. It comes back in `skipped` with a user-facing `reason`, and the other lines still merge. A short-stock line is skipped whole, not reduced.
- 
**After the call:** clear the local guest cart and show the returned `cart`. If `skipped` is non-empty, show the reasons once (for example in a bottom sheet).
- 
**One seller per cart** still applies, as with `POST /cart/items`.
## Checkout & payment flow
Checkout takes a `paymentMethod`. `ONLINE` (the default) opens Razorpay. `COD` confirms the order immediately. A failed online payment is retryable for 30 minutes instead of ending the order.
### Place the order
`POST /orders/checkout` (auth)
`couponCode` is optional. `paymentMethod` is `ONLINE` or `COD`, default `ONLINE`.
Response `201` for **ONLINE**:
Response `201` for **COD**:
- 
**COD limit:** COD is allowed up to ₹5,000 (server setting). Above it, checkout returns `400` with `Cash on delivery is available on orders up to ₹5000`. Hide or disable COD when the cart total is over the limit, but always show the server message when it refuses.
- 
**Cart after checkout:** COD empties the server cart at once. For ONLINE, the cart is emptied only when payment is captured, so refetch `GET /cart` after the order is `CONFIRMED`.
### Pay online
- 
Open Razorpay Checkout with `key = keyId`, `order_id = providerOrderId`, `amount = amount × 100` (paise), `currency = INR`. Pass `customer_id = customerId` when it isn't null, so saved methods appear and new ones can be saved.
- 
**On SDK success:** call `POST /payments/verify` with `{ "orderId", "providerPaymentId": razorpay_payment_id, "signature": razorpay_signature }`. It returns `{ "orderId", "status" }`.
- 
If `status` is still `PLACED`, the payment is authorised but not settled. Poll `GET /orders/{orderId}` every 2–3 s, for up to 60 s, until `status` leaves `PLACED`.
- 
**On SDK error or dismissal:** go to the order screen and poll the same way. A declined payment becomes `PAYMENT_FAILED` within seconds (via webhook). A dismissed sheet with no attempt stays `PLACED`.
The SDK's success callback is not proof of payment. Only the order `status` returned by the API is.
### Retry a failed or abandoned payment
`POST /orders/{orderId}/pay` (auth, no body) reopens payment for an order in `PLACED` or `PAYMENT_FAILED`. It returns the same shape as the ONLINE checkout response, against the same Razorpay order, so run the Pay online steps again.
- 
`409` `This order was cancelled — place it again from your cart` once the order has expired or been cancelled.
- 
`409` `This order is already paid` if it's already confirmed.
Use this endpoint for **Retry payment**. Don't send the user back to checkout: a second checkout creates a second order, and the first one keeps its stock held until it expires.
### Expiry
An online order still `PLACED` or `PAYMENT_FAILED` 30 minutes after it was placed is cancelled automatically, with `cancelledBy: "system"` and `cancelReason: "Payment not completed in time"`. Its stock and coupon are released. A payment that lands after that is refunded in full automatically. Show a countdown or "Complete payment within 30 minutes" on unpaid orders.
## Saved payment methods
Cards and UPI IDs are saved inside Razorpay Checkout, not by our API. The API only lists and deletes them. Saving works only when checkout is opened with the `customerId` from the checkout or retry response.
 | 
Method | 
Path | 
Auth | 
Returns
 | 
GET | 
`/payments/methods` | 
yes | 
`SavedMethod[]` (empty until the user saves one)
 | 
DELETE | 
`/payments/methods/{id}` | 
yes | 
`204`; `404` if no such method
`method` is Razorpay's value (`card`, `upi`, `wallet`, `netbanking`). Display whichever of `card`, `vpa`, `wallet`, `bank` is filled, based on `method`.
`customerId` can be `null` if Razorpay was unreachable when the order was placed. Checkout still works then; the sheet just won't offer saving. Build a **Saved payment methods** screen under Profile with list and remove.
## Orders: detail, cancel, reorder, invoice
Order list and detail gain payment and cancellation fields, and orders get three new actions.
 | 
Method | 
Path | 
Auth | 
Body | 
Returns
 | 
GET | 
`/orders` | 
yes | 
— | 
`OrderSummary[]`, newest first, max 50
 | 
GET | 
`/orders/{id}` | 
yes | 
— | 
`OrderDetail`
 | 
POST | 
`/orders/{id}/pay` | 
yes | 
— | 
Payment sheet (see Checkout & payment flow)
 | 
POST | 
`/orders/{id}/cancel` | 
yes | 
`{ "reason": "Ordered by mistake" }` (3–500 chars) | 
`OrderDetail` + `refundStatus`
 | 
POST | 
`/orders/{id}/reorder` | 
yes | 
— | 
`{ cart, skipped }`, same as cart merge
 | 
GET | 
`/orders/{id}/invoice` | 
yes | 
— | 
PDF file (`application/pdf`)
**OrderSummary** — `id`, `orderNumber`, `status`, `paymentMethod` (`ONLINE` / `COD`), `paymentStatus` (`CREATED` / `CAPTURED` / `FAILED`, or `null` for COD), `accepted` (seller has accepted it), `amount`, `currency`, `createdAt`.
**OrderDetail** — everything in OrderSummary, plus:
- 
`subtotal` and `discount` (coupon saving); `amount` = `subtotal − discount`.
- 
`items[]`: `id`, `variantId`, `productId`, `name`, `slug`, `image`, `sku`, `unit`, `quantity`, `unitPrice`, `totalPrice`. Pass `items[].id` as `orderItemId` when posting a review.
- 
`address`: `name`, `phone`, `line1`, `line2`, `city`, `state`, `pincode`.
- 
`acceptedAt`, `cancelledAt`, `cancelledBy` (`customer` / `vendor` / `admin` / `system`), `cancelReason`. All nullable.
- 
`shipment`: `null`, or `{ status, awbNumber, trackingEvents[] }`. Unchanged.
- 
`vendorAmount`, `platformAmount`: internal split. Don't display.
### Cancel
The customer can cancel while the order is `PLACED` or `PAYMENT_FAILED`, or `CONFIRMED` within 24 hours of placing it. Once it is `PACKED` it can't be cancelled. Stock is returned either way, and a paid online order is refunded in full to the original payment method.
`refundStatus` in the response is `null` (nothing was charged, or COD), `pending` / `processed` (refund started), or `failed`. On `failed`, show "Your refund is being processed manually"; the team follows up from the admin dashboard.
Collect the reason with presets plus a free-text option, for example "Ordered by mistake", "Found a better price" or "Delivery too slow".
### Reorder
Adds the past order's lines to the cart. Lines that can't be added come back in `skipped` with a reason. Navigate to the cart after.
### Invoice
Available once the order is `CONFIRMED`, `PACKED`, `SHIPPED`, `DELIVERED` or `RETURNED`. Otherwise it returns `409`. The endpoint needs the auth header, so download it with the app's HTTP client, save it as `invoice-<orderNumber>.pdf`, then open the system viewer or share sheet. A plain URL opened in a browser won't work.
## Order status reference
Show the customer-facing label below, never the raw code. `PAYMENT_FAILED` is the only new state; treat any status the app doesn't know as "Processing".
An order still `PLACED` can also time out or be cancelled, the same as `PAYMENT_FAILED`. A COD order skips payment and is `CONFIRMED` at checkout.
 | 
Status | 
Label for the customer | 
What to show | 
Actions
 | 
`PLACED` | 
Awaiting payment | 
"Complete payment within 30 minutes" | 
Pay now (`/pay`), Cancel
 | 
`PAYMENT_FAILED` | 
Payment failed | 
"Your payment didn't go through. Your items are reserved for 30 minutes from when you placed the order." Red banner | 
**Retry payment** (`/pay`), Cancel
 | 
`CONFIRMED` | 
Order confirmed | 
If `accepted` is false: "Waiting for the seller to accept" | 
Cancel (within 24 h), Invoice
 | 
`PACKED` | 
Packed | 
— | 
Invoice
 | 
`SHIPPED` | 
Shipped | 
Shipment tracking | 
Invoice
 | 
`DELIVERED` | 
Delivered | 
— | 
Invoice, Review, Reorder
 | 
`CANCELLED` | 
Cancelled | 
`cancelReason`; "Refund started" if it was paid online | 
Reorder
 | 
`RETURNED` | 
Returned | 
— (returns flow arrives in Week 10) | 
Invoice, Reorder
Reorder works on any order; the table lists where it is most useful. Hide **Cancel** when the API would refuse it, but always handle a `409` (see Errors).
## Errors
Every error returns `{ success: false, message, details? }`, and `message` is safe to show as-is. Branch on the HTTP status, never on the message text: wording can change.
 | 
Status | 
When | 
App should
 | 
`400` | 
Validation failed (`details.fieldErrors` names the fields), or a business rule: COD over the limit or disabled, empty cart, missing address, order total under ₹1 | 
Show `message`; on validation errors highlight the fields
 | 
`401` | 
Missing, expired or revoked token (e.g. after logout-all-devices) | 
Refresh the Firebase ID token and retry once; still `401` → sign out
 | 
`404` | 
Order, product, address or saved method not found, or not the caller's | 
Show `message`, go back
 | 
`409` | 
State conflict: not enough stock, coupon limit reached, cart has another seller's items (`details` has both seller names), order can't be cancelled or paid in its current state, no invoice yet, or "This order was just updated — refresh and try again" | 
Show `message`, then refetch the order or cart so the screen matches the server
 | 
`429` | 
More than 300 requests in 15 min from one IP | 
Back off and retry later
 | 
`500` | 
Server error | 
Generic "Something went wrong" + retry
The `409`s on order actions are expected races (the seller packed it, the order expired, a webhook landed first). Handle them as normal outcomes, not crashes.
## Not in this release, and checklist
Not available yet, so don't build against it: shipping charges and pincode serviceability (Shiprocket work), returns and replacements (Week 10), coupon listing and offers (Week 9), RFQ (Week 9), push and in-app notifications (Week 11). Checkout has no shipping fee today: `amount` is the full payable total.
- 
Handle `PAYMENT_FAILED` in the payment poll, order list and order detail, with retry via `POST /orders/{id}/pay`
- 
Show the 30-minute payment window on `PLACED` and `PAYMENT_FAILED` orders
- 
Add a payment method choice (Online / Cash on delivery) to checkout and send `paymentMethod`
- 
Pass `customerId` to Razorpay Checkout so saved methods show and can be saved
- 
Build the Saved payment methods screen (list + remove)
- 
Add order cancel with reason presets, and show `refundStatus`
- 
Add Reorder and Invoice download on order detail
- 
Show `cancelReason` and the seller-acceptance note on order detail
- 
Add catalogue filters (price, brand, rating, in stock) and sort; fetch brands from `GET /catalog/brands`
- 
Wire the wishlist heart and the wishlist screen to the server
- 
Record product views and show a Recently viewed rail
- 
Keep a local guest cart and call `POST /cart/merge` after sign-in, showing any `skipped` reasons
- 
Add an edit-name field to Profile (`PATCH /auth/me`)
- 
Map every order status to a label, with a fallback for unknown values
Questions go to the backend team. The OpenAPI spec at `/docs` is the source of truth if this doc and the API ever disagree.