# Firebase setup — email authentication

The app ships with `lib/core/firebase/firebase_options.dart` full of
placeholders, so it builds and runs for anyone who does not have the Firebase
project yet. In that state sign-in is disabled and the auth screens show an
"Sign-in is not available yet" notice; browsing the catalogue works normally.

Everything below is a one-time setup by whoever owns the Firebase project.

## 1. Create the project

1. <https://console.firebase.google.com> → **Add project** → `irrikart` (or
   reuse the existing IrriKart project).
2. Google Analytics is optional and not used by this app.

## 2. Enable email/password sign-in

**Build → Authentication → Get started → Sign-in method → Email/Password →
Enable → Save.**

Leave "Email link (passwordless sign-in)" off — the app uses password sign-in.

Keep **email enumeration protection** on (the default). It is why a wrong
password and an unknown email both come back as `invalid-credential`, and why
`AuthService` maps both to the same "Incorrect email or password." message.

## 3. Register the apps

Android:

- **Project settings → Your apps → Add app → Android**
- Package name: `com.irrikart.app` (must match `android/app/build.gradle`)
- No `google-services.json` download is needed — see the note below.

iOS:

- **Add app → iOS**, bundle id `com.irrikart.app`.

## 4. Generate the real config

```bash
dart pub global activate flutterfire_cli
cd irrikart-mobile-app
flutterfire configure \
  --project=<firebase-project-id> \
  --out=lib/core/firebase/firebase_options.dart \
  --platforms=android,ios
```

That overwrites the placeholder file. `DefaultFirebaseOptions.isConfigured`
then returns true and `bootstrapFirebase()` initialises Firebase for real, so
the auth screens light up with no further code change.

### Why no `google-services.json` / `GoogleService-Info.plist`

`Firebase.initializeApp(options: …)` passes the configuration from Dart, which
is all `firebase_auth` needs. The platform config files (and the
`google-services` Gradle plugin) only become necessary for Analytics, Crashlytics
or FCM. Add them then, not now.

## 5. Verify

```bash
flutter run
```

- Sign up with a throwaway address — a verification email should arrive, and
  the Account tab shows the "Verify your email" banner until it is confirmed.
- Sign out from the Account tab, sign back in.
- "Forgot password" should send a reset link.

## Platform requirements already handled

| | |
|---|---|
| `android/app/build.gradle` | `minSdkVersion 23` (pinned; `firebase_auth` needs it) |
| `ios/Podfile` | `platform :ios, '13.0'` |

## What the app does when Firebase is down

`bootstrapFirebase()` never throws. It returns one of three statuses, exposed
through `firebaseStatusProvider`:

| Status | Cause | Effect |
|---|---|---|
| `ready` | Firebase initialised | sign-in works |
| `notConfigured` | placeholder `firebase_options.dart` | auth screens disabled with a notice |
| `failed` | bad config, or `initializeApp` threw | same as above, logged to the console |

A farmer on a dead connection must still be able to open the catalogue, so a
Firebase failure is never allowed to take the launch screen down with it.

## Code map

```
lib/core/firebase/firebase_options.dart    generated config (placeholders today)
lib/core/firebase/firebase_bootstrap.dart  safe one-shot init, called from main()
lib/core/auth/auth_service.dart            sign in / sign up / reset / sign out
                                           + Riverpod providers, error mapping
lib/screens/auth/views/                    login, signup, password recovery
```

No screen touches `FirebaseAuth` directly. Every failure arrives as an
`AuthException` whose `userMessage` is already safe to render.
