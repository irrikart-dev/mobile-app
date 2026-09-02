# Firebase setup — email authentication

Sign-in and sign-up split across two pieces of config, in two different repos:

| | Configures | Repo |
|---|---|---|
| Client SDK | log in, forgot password, the final "sign this device in" step of sign-up | `irrikart-mobile-app` (this repo) |
| Admin SDK + SMTP | actually creating the account during sign-up | `backend` |

Both degrade gracefully when unset — the app builds and runs with neither, and
tells the user "not available yet" instead of crashing. Set up the client SDK
first; the sign-up flow additionally needs the backend piece.

## Why sign-up needs the backend too

The sign-up flow is: **email → emailed 6-digit code → set password**. Firebase
Authentication has no "send an email OTP" primitive by itself (only phone-SMS
OTP and passwordless email *links*), so the code is generated, emailed and
checked by the backend, and the Firebase account is only created — via the
**Admin SDK** — once that code is verified. The app never calls
`createUserWithEmailAndPassword`; the last step signs into the account the
backend just made, using a custom token it hands back.

```
app                              backend
 email ──────────────────────►  generate + email OTP
 code  ──────────────────────►  verify OTP → signupToken (JWT, 10 min)
 password + signupToken ─────►  Admin SDK createUser() → customToken
 signInWithCustomToken(customToken)   ◄── (client SDK, back in the app)
```

## 1. Create the project

1. <https://console.firebase.google.com> → **Add project** → `irrikart` (or
   reuse the existing IrriKart project). Since you're logged in via the
   Firebase CLI already, `firebase projects:list` shows the project id you need
   below.
2. Google Analytics is optional and not used by this app.

## 2. Enable email/password sign-in

**Build → Authentication → Get started → Sign-in method → Email/Password →
Enable → Save.**

Leave "Email link (passwordless sign-in)" off.

## 3. Client SDK — register the apps and generate config

Android: **Project settings → Your apps → Add app → Android**, package name
`com.irrikart.app` (must match `android/app/build.gradle`).

iOS: **Add app → iOS**, bundle id `com.irrikart.app`.

Then, from this repo:

```bash
dart pub global activate flutterfire_cli
flutterfire configure \
  --project=<firebase-project-id> \
  --out=lib/core/firebase/firebase_options.dart \
  --platforms=android,ios
```

That overwrites the placeholder file with real values, and
`bootstrapFirebase()` starts returning `FirebaseStatus.ready` — login,
password reset, and the final step of sign-up all light up with no further
code change. (This repo's `irrikart-auth` project is already configured this
way — `firebase_options.dart` carries real values, not placeholders.)

`flutterfire configure` also drops `android/app/google-services.json` and
would drop `ios/Runner/GoogleService-Info.plist` — both **gitignored on
purpose** (`.gitignore` lines 57–58), so regenerate them locally by rerunning
the command above rather than expecting them from git. `Firebase.initializeApp
(options: …)` uses the Dart config either way, so nothing breaks between a
machine that has them and one that doesn't for `firebase_auth` itself — but
`google_sign_in`'s Android build applies the `google-services` Gradle plugin
(wired into `android/app/build.gradle` / `android/settings.gradle` by
`flutterfire configure`, which **are** committed), and that plugin fails the
build if `google-services.json` is missing. Run `flutterfire configure` on
every machine that builds the Android target.

## 4. Admin SDK + SMTP — makes sign-up actually work (backend repo)

In the **backend** repo, not this one:

1. Firebase Console → **Project settings → Service accounts → Generate new
   private key**. Downloads a JSON file — keep it out of git.
2. In `backend/.env`, either:
   - `FIREBASE_SERVICE_ACCOUNT_PATH=/absolute/path/to/that-file.json`, or
   - paste its `project_id` / `client_email` / `private_key` fields into
     `FIREBASE_PROJECT_ID` / `FIREBASE_CLIENT_EMAIL` / `FIREBASE_PRIVATE_KEY`
     (handy on hosts with no persistent file storage).
3. Set `SMTP_HOST` / `SMTP_PORT` / `SMTP_USER` / `SMTP_PASS` so the OTP email
   actually sends. Left blank, the backend **logs the code to its own console
   instead** — the whole flow is testable with no mail provider, but it's a
   dev-only fallback (the backend refuses to boot with it in production).
4. Restart the backend. `/api/v1/auth/signup/complete` returns 503 until this
   step is done — the app's sign-up flow works right up to "set password" and
   then reports "sign-up is not fully configured" until then.

Full details: `backend/README.md` and `backend/.env.example`.

## 4b. Google Sign-In

Enabled on `irrikart-auth` already (Console → Authentication → Sign-in
method → Google), which auto-provisions a **Web** OAuth client — that client
id is what `AuthService`/`googleSignInProvider` pass as `serverClientId` on
every platform, which is what makes `google_sign_in` hand back a token
Firebase accepts without a `google-services.json` in the repo.

What each platform additionally needs, already done for `irrikart-auth`:

- **Android** — the signing certificate's SHA-1 *and* SHA-256 fingerprints
  registered against the Firebase Android app (Project settings → Your apps →
  Android → Add fingerprint). Missing/wrong fingerprint is the single most
  common cause of Google Sign-In failing on Android — it shows up as
  `PlatformException(sign_in_failed, ...)`, mapped to "Google sign-in could
  not start" in `AuthService._messageForGoogle`. Get the debug keystore's:
  ```bash
  keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
  ```
  **Do this again for the release keystore before shipping** — its
  fingerprint is different from debug's, and Google Sign-In will fail on a
  release build until it's registered too.
- **iOS** — the iOS OAuth client id (`firebase_options.dart`'s
  `ios.iosClientId`) reversed and added as a URL scheme in `Info.plist`
  (`CFBundleURLTypes`) — already there, generated from the same client id
  `flutterfire configure` wrote.

## 5. Verify

```bash
flutter run
```

- Sign up with a throwaway address: email → code (check your inbox, or the
  backend's terminal if SMTP isn't set) → set a password → lands signed in.
- "Continue with Google" on either the login or sign-up screen should open the
  account picker and land signed in either way — same call handles new and
  returning accounts.
- Log out from the Account tab, log back in.
- "Forgot password" should send a reset link.

## Platform requirements already handled

| | |
|---|---|
| `android/app/build.gradle` | `minSdkVersion 23` (pinned; `firebase_auth` needs it) |
| `ios/Podfile` | `platform :ios, '13.0'` |

## What the app does when Firebase (or the backend) is down

`bootstrapFirebase()` never throws. It returns one of three statuses, exposed
through `firebaseStatusProvider`:

| Status | Cause | Effect |
|---|---|---|
| `ready` | client Firebase initialised | log in / sign-up work |
| `notConfigured` | placeholder `firebase_options.dart` | auth screens disabled with a notice |
| `failed` | bad config, or `initializeApp` threw | same as above, logged to the console |

Separately, if the client SDK is `ready` but the **backend's** Admin SDK isn't
configured, sign-up gets as far as "set password" and then shows a clear
"sign-up is not fully configured" error rather than a crash — see step 4.

A farmer on a dead connection must still be able to open the catalogue, so
none of this is allowed to take the launch screen down with it.

## Code map

```
lib/core/firebase/firebase_options.dart    generated client config (placeholders today)
lib/core/firebase/firebase_bootstrap.dart  safe one-shot init, called from main()
lib/core/auth/auth_service.dart            sign in / reset / sign out / custom-token sign-in / Google sign-in
lib/core/auth/signup_api.dart              talks to the backend's OTP endpoints
lib/screens/auth/views/                    login, signup (3-step), password recovery
lib/screens/auth/views/components/google_sign_in_button.dart   shared "Continue with Google" button

backend/src/services/signup-service.js     OTP generation/verification, orchestrates the above
backend/src/services/firebase-admin.js     Admin SDK init (service account)
backend/src/services/mailer.js             sends the OTP email (or logs it in dev)
backend/src/routes/auth.routes.js          POST /api/v1/auth/signup/{request-otp,verify-otp,complete}
```

No screen touches `FirebaseAuth` or the backend directly outside these files.
Every failure arrives as an `AuthException` or `SignupApiException` whose
`userMessage` is already safe to render.
