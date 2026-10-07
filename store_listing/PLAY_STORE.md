# IrriKart — Google Play submission kit

Everything needed to fill in Play Console for the first release.

## Build

```
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

Signed with the upload key in `android/app/upload-keystore.jks` (credentials in
`android/key.properties`; both git-ignored). **Back both up somewhere safe**
(password manager / company drive). Enrol in **Play App Signing** (default) —
Google holds the app signing key; a lost upload key can be reset via Play
support.

Bump `version:` in `pubspec.yaml` (`1.0.0+1` → `1.0.1+2` …) before every upload;
the `+N` build number must always increase.

## After the first upload — required for Google Sign-In

Play re-signs the app with its own key, so Google Sign-In fails on Play
installs until that key is registered in Firebase:

1. Play Console → *Test and release → Setup → App signing* → copy the **App
   signing key certificate** SHA-1 and SHA-256.
2. Add both to Firebase:
   `firebase apps:android:sha:create 1:505911392963:android:9897b31d65ec12c99bc076 <SHA> --project irrikart-auth`
3. Re-download `android/app/google-services.json`
   (`firebase apps:sdkconfig ANDROID 1:505911392963:android:9897b31d65ec12c99bc076 --project irrikart-auth -o android/app/google-services.json`),
   rebuild and upload a new build.

Upload-key SHAs are already registered.

## Before submitting — fill in the legal details

`web-frontend/src/lib/legal.ts` has `FILL_ME` placeholders (registered business
name, address, support email, grievance officer). Replace them and push —
Play rejects privacy policies without real contact details.

## Store listing

**App name:** IrriKart — Farm & Irrigation Store

**Short description (≤80):**
Drip kits, sprinklers, pumps & farm tools — genuine brands, delivered across India.

**Full description:**

IrriKart is the easiest way for Indian farmers, dealers and FPOs to buy
irrigation and farm equipment online.

🌱 EVERYTHING YOUR FARM NEEDS
Drip irrigation kits, sprinklers, filters, valves, pipes and fittings, foggers,
controllers and more — from brands you trust.

🔍 CLEAR SPECS, HONEST PRICES
Every product shows full specifications, pack sizes, stock and ratings from
real buyers, so you know exactly what you're getting.

🔒 SECURE PREPAID CHECKOUT
Pay with UPI, debit/credit cards or netbanking through Razorpay.

🚚 TRACK EVERY ORDER
Follow each order from dispatch to your doorstep.

🤝 BULK & FPO ORDERS
Buying for your village or FPO? Get a bulk quote on WhatsApp in one tap.

💬 HELP WHEN YOU NEED IT
Chat with the IrriKart team on WhatsApp right from the app.

**Category:** Shopping  ·  **Tags:** shopping, agriculture
**Contact email / website:** (same as `legal.ts`)
**Privacy policy:** https://web-frontend-alpha-two.vercel.app/privacy

**Graphics** (this folder):
- App icon: `icon_512.png`
- Feature graphic: `feature_graphic_1024x500.png`
- Phone screenshots: `screenshots/01…06` (1080×1920)

## App content answers

- **Privacy policy:** URL above.
- **Ads:** No ads.
- **App access:** Sign-in required for cart/checkout. Provide a test Google
  account (or note that any Google account works) under *App access*.
- **Target audience:** 18+.
- **Content rating:** IARC questionnaire → reference/shopping, no user-to-user
  chat, no gambling → expected rating *Everyone / 3+*.
- **Government app / financial features:** No. (Payments are via Razorpay;
  the app does not provide financial services.)
- **Health:** No.
- **Account deletion:** In-app (Account → Delete account) and web:
  https://web-frontend-alpha-two.vercel.app/delete-account

### Data safety

Data is encrypted in transit: **Yes**. Users can request deletion: **Yes**.

| Data type | Collected | Shared | Purpose | Optional? |
|---|---|---|---|---|
| Name | Yes | Yes (delivery partners) | Account management, App functionality | Required |
| Email address | Yes | No | Account management | Required |
| Phone number | Yes | Yes (delivery partners) | App functionality (delivery) | Required |
| Physical address | Yes | Yes (delivery partners, sellers) | App functionality (delivery) | Required |
| Purchase history | Yes | Yes (sellers) | App functionality | Required |
| Payment info | No — handled by Razorpay's SDK, never reaches IrriKart | — | — | — |
| User-generated content (reviews) | Yes | No (shown publicly in app) | App functionality | Optional |
| Photos (Google profile picture URL) | Yes | No | Account management | Required |

Not collected: location, contacts, SMS, files, app activity analytics,
device identifiers, crash logs (no crash SDK in the app).

> Razorpay's SDK collects device/payment data for fraud prevention as its own
> processor — declare per Razorpay's Play data-safety guidance:
> https://razorpay.com/docs/payments/payment-gateway/android-integration/standard/data-safety/
