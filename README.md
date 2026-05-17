# seed-mixer-clients

Playground monorepo for Seed Mixer client apps across different stacks.

The idea: build the same small app (list of seed mixtures + detail screen, eventually species browser and plant-ID) in several different stacks side by side, learn what each one feels like, then pick the one that stays.

Backend lives in a separate repo: [`seed-mixer`](../seed-mixer) (Hono + scrapers + JSON data).

## Clients

| Client | Stack | Status |
|---|---|---|
| `flutter-app/` | Flutter (Android + iOS + web) | scaffolding |
| _planned_ | Kotlin + Jetpack Compose (Android native) | not started |
| _planned_ | Swift + SwiftUI (iOS native) | not started |
| _planned_ | Next.js 15 (React, SSR) | not started |
| _planned_ | React + Vite (SPA) | not started |
| _planned_ | Nuxt 3 (Vue, SSR) | not started |

Layout is flat for now — `git mv` regroups later if it grows.

## Shared

- `shared/api-contract/` — OpenAPI mirror + typed clients (TS, Dart)
- `shared/design-tokens/` — colors, spacing, typography as JSON (stack-agnostic)
- `shared/assets/` — logos, fixture images, icons
- `docs/` — architecture notes, client-matrix, decision log

Each client consumes `shared/` via copy, symlink, or build step — whatever's cheapest per stack.

## Backend

The Hono API in `seed-mixer/serve.ts` is the source of truth during development. Clients point at `http://localhost:3000` by default (Android emulator uses `10.0.2.2:3000`).
