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
