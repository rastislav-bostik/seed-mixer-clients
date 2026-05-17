# seed_mixer_app (Flutter)

Flutter client for the seed-mixer backend. Targets Android, iOS, and Web.

## Run

```bash
cd flutter-app
flutter pub get

# Web (fastest dev loop, no emulator needed)
flutter run -d chrome

# Android (needs Android Studio + SDK + an emulator/device)
flutter run -d android

# iOS (needs full Xcode + simulator/device)
flutter run -d ios

# Point at a different backend (default: production Render URL)
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
```

## Layout

```
lib/
├── main.dart                 # bootstrap, theme loading, go_router config
├── api/
│   ├── api_client.dart       # thin HTTP wrapper (timeout, retry, JSON parse)
│   └── seed_mixer_repository.dart  # endpoint → DTO → domain mapping
├── models/
│   ├── product.dart          # Product + ProductDto + mappers
│   ├── ingredient.dart       # Ingredient + IngredientDto + mapper
│   └── offering.dart         # Offering + OfferingDto + mapper
├── screens/
│   ├── mixtures_list_screen.dart
│   └── mixture_detail_screen.dart
├── theme/
│   └── app_theme.dart        # builds ThemeData from assets/tokens.json
└── widgets/
    ├── error_banner.dart     # friendly error + Render cold-start hint
    └── product_image.dart    # cached network image with placeholder

assets/
└── tokens.json               # copy of shared/design-tokens/tokens.json
```

## API resilience

This client follows the monorepo's [API resilience principles](../docs/architecture.md#api-resilience--surviving-breaking-changes):

- **DTOs are loose** — every field optional, fromJson ignores unknown keys.
- **Domain models are clean** — what the UI actually needs, with defaults.
- **One mapper per resource** — `productFromSummaryDto`, `productFromDetailDto`, `ingredientFromDto`, `offeringFromDto`. Pure functions, no DI.
- **70 s timeout** — Render free tier cold-starts. The `ErrorBanner` distinguishes "warming up" from real errors.
- **Single retry on 5xx** — no exponential backoff, no jitter, deliberately simple.

When the backend changes a field name:
1. Edit the DTO `fromJson` (one line).
2. Edit the mapper (one line).
3. Domain model + every screen stays untouched.

## Design tokens

`assets/tokens.json` is a copy of `shared/design-tokens/tokens.json`. Resync with:

```bash
cp ../shared/design-tokens/tokens.json assets/tokens.json
```

(Eventually a watcher or build step; for the PoC the copy is fine.)

## Implementation notes

For the "why is this code shaped the way it is" — scroll-perf knobs, web target CORS workaround, image cache strategy, real-device install workaround, diagnostic tooling — see [`docs/IMPLEMENTATION_NOTES.md`](docs/IMPLEMENTATION_NOTES.md).
