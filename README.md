# IrriKart Mobile

Agricultural tools and inputs marketplace for India. Flutter app for Android and iOS.

## Requirements

| Tool | Version |
|---|---|
| Flutter | 3.27.4+ (stable) |
| Dart | 3.9.2+ |
| JDK | 17 (required by AGP 8.x) |
| Android SDK | compileSdk 35, minSdk 23, targetSdk 34 |
| Xcode | 15+, iOS deployment target 13.0 |

## Getting started

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # REQUIRED — see below
flutter run -t lib/main_dev.dart
```

> **Generated code is not committed.** `*.g.dart` and `*.freezed.dart` are gitignored, so a
> fresh clone will not compile until you run `build_runner`. Run it after every pull that
> touches a DTO, entity, or provider. Use `dart run build_runner watch -d` while developing.

## Flavors

| Flavor | Entrypoint | Application id |
|---|---|---|
| dev | `lib/main_dev.dart` | `com.irrikart.app.dev` |
| staging | `lib/main_staging.dart` | `com.irrikart.app.staging` |
| prod | `lib/main_prod.dart` | `com.irrikart.app` |

```bash
flutter run   -t lib/main_dev.dart     --flavor dev
flutter build apk --release -t lib/main_prod.dart --flavor prod
```

The app runs against **mock data sources** by default (`FeatureFlags.useMockData`) because the
backend API does not exist yet. Nothing above the data source layer knows the difference.

## Authentication

Email + password, via **Firebase Authentication** (`firebase_core` +
`firebase_auth`). Sign-up, sign-in, password reset and email verification are
wired to the existing auth screens.

`lib/core/firebase/firebase_options.dart` is checked in with **placeholder
values** so the repo builds without the Firebase project. Until it is replaced,
the auth screens disable themselves with a notice and the rest of the app works
as normal — a Firebase failure never crashes the launch screen.

Run `flutterfire configure` to wire up the real project. Full runbook:
[`docs/FIREBASE_SETUP.md`](docs/FIREBASE_SETUP.md).

```
lib/core/firebase/   firebase_options.dart, firebase_bootstrap.dart (safe init)
lib/core/auth/       auth_service.dart — providers + error mapping
```

No screen touches `FirebaseAuth` directly; failures surface as `AuthException`
with a `userMessage` that is already safe to render.

## Catalogue data

The catalogue loads from the backend (`GET /api/v1/catalog`), which returns the
43 products carried over from the IrriKart site **and** everything added in the
admin dashboard in one response. A product added or repriced in the dashboard
therefore reaches the app on its next catalogue load — pull to refresh on the
home screen, or a cold start — with no app release.

If the API is unreachable the app falls back to the bundled `assets/mock/`
fixtures and shows a "showing the saved catalogue" notice on the home screen.

Point a build at a different API:

```bash
flutter run --dart-define=IRRIKART_API_BASE_URL=https://api.irrikart.in/api/v1
```

With no override, release builds use `https://api.irrikart.in/api/v1` and debug
builds use the local backend (`10.0.2.2:4000` on the Android emulator). See
`lib/core/network/api_config.dart`.

Seed products keep their bundled image assets, so they render instantly and
offline; products added in the dashboard carry a remote `imageUrl`.
`CatalogImage` handles both.

## Architecture

Feature-first, with a shared core. Each feature is self-contained:

```
lib/
├── core/       config, network (dio), error, storage, router (go_router), theme, utils, analytics, di
├── shared/     cross-feature domain types (Money, PackUnit) and widgets
└── features/   auth, catalog, cart, checkout, orders, payments, shipping, vendor, rfq, …
    └── <feature>/
        ├── <feature>_providers.dart    # DI: picks mock or real data source
        ├── data/          dto/ mappers/ datasources/ fixtures/ repositories/
        ├── domain/        entities/ repositories/ usecases/
        └── presentation/  providers/ screens/ widgets/
```

**Stack:** Riverpod (codegen) · freezed + json_serializable · dio · go_router · flutter_secure_storage

**Conventions:**
- Repositories **throw** typed `Failure`s; the UI catches them via `AsyncValue.guard`. No `Either`.
- Money is always an **integer minor unit (paise) plus a currency code**. Never a double.
- Timestamps are ISO-8601 UTC.
- `data/` never leaks a DTO upward — mappers convert to `domain/` entities at the boundary.

See `docs/ARCHITECTURE.md`, `docs/API_CONTRACT.md`, and `docs/ADDING_A_FEATURE.md`.

## Checks

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

All three must pass before pushing. CI runs the same sequence plus a staging build.
