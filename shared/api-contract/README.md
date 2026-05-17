# API contract

Mirror of the seed-mixer backend OpenAPI schema. Source of truth lives in `seed-mixer/` (Hono + `@hono/zod-openapi`).

## Current state

- **Live schema:** `https://seed-mixer-api.onrender.com/openapi.json`
- **Local mirror:** `openapi.json` in this directory — last synced 2026-05-17

## Sync

Refresh the local mirror with:

```bash
curl -sS https://seed-mixer-api.onrender.com/openapi.json > shared/api-contract/openapi.json
```

(Or pull directly from `seed-mixer/` if you have the backend running locally.)

Then each client generates its own bindings:
- Flutter — `openapi-generator-cli` → Dart
- Next/Vite/Nuxt — `openapi-typescript` → `.d.ts`
- Kotlin — `openapi-generator-cli` → Kotlin data classes
- Swift — `openapi-generator-cli` → Swift structs

## For PoC

Hand-written models per stack are fine. Drop the generator pipeline in once endpoint shapes stop changing every other day.
