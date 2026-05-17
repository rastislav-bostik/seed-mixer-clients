# Architecture

## High level

```
+----------------------+         HTTP/JSON         +----------------------+
|  seed-mixer-clients  |  <--------------------->  |     seed-mixer       |
|                      |                           |  (Hono API + data)   |
|  Flutter / Native /  |                           |                      |
|   Next / Vite / Nuxt |                           |  scrapers, OCR,      |
|                      |                           |  Orama search        |
+----------------------+                           +----------------------+
```

The backend is intentionally minimal — a Hono server that exposes scraped + linked data over JSON. All client logic (caching, offline, optimistic UI, …) lives in the clients.

## API base URL

**Production (default):** `https://seed-mixer-api.onrender.com`
**OpenAPI schema:** `https://seed-mixer-api.onrender.com/openapi.json` — mirrored to `shared/api-contract/openapi.json`

⚠ Render free tier sleeps after inactivity. First request after sleep can take 30–60 s (cold start). Clients should show a non-blocking "warming up" hint for slow first responses.

⚠ Backend is under active development in a parallel session. Expect occasional 5xx errors and field renames. The mapper layer (see API resilience below) absorbs the churn.

**Local backend (optional):** clone `seed-mixer/` and run `pnpm serve` → `http://localhost:3000`.

| Target | URL when using local | URL when using prod |
|---|---|---|
| iOS simulator | `http://localhost:3000` | `https://seed-mixer-api.onrender.com` |
| Android emulator | `http://10.0.2.2:3000` | `https://seed-mixer-api.onrender.com` |
| Web (Chrome) | `http://localhost:3000` | `https://seed-mixer-api.onrender.com` |
| Physical device on same LAN | `http://<host-lan-ip>:3000` | `https://seed-mixer-api.onrender.com` |

Each client reads its base URL from a per-stack env mechanism:
- Flutter: `--dart-define=API_BASE_URL=…` (default: prod URL)
- Next/Nuxt: `NEXT_PUBLIC_API_BASE_URL` / `NUXT_PUBLIC_API_BASE_URL`
- Vite: `VITE_API_BASE_URL`
- Kotlin/Swift: gradle/xcconfig build flavor

## Endpoint surface (as of 2026-05-17)

```
GET /manufacturers              → list of manufacturers + product counts
GET /categories                 → list of categories + product counts
GET /products                   → filtered product summaries
                                  (filters: type, manufacturer, source, category, contains[])
GET /products/{source}/{slug}   → full product detail with composition
GET /search?q=...&limit=N       → fuzzy species search (Orama BM25, tolerance=1)
GET /species                    → all species summaries
GET /species/{id}               → species detail with growing info + product cross-refs
```

No `/version`, no `/health` endpoint yet. Server-version probe (see resilience section) will need to be added on the backend later — for now clients infer health from the first real request's success/timeout.

No `/v1/` prefix yet. When the backend versions endpoints, clients pin to one explicit version.

## Shared contracts

`shared/api-contract/` mirrors the OpenAPI schema from `seed-mixer/`. The generation flow (TBD):

1. `seed-mixer/` exports OpenAPI JSON from `@hono/zod-openapi`
2. CI / manual sync copies it to `shared/api-contract/openapi.json`
3. Each client generates its own typed bindings from that JSON

For PoC we can also hand-write models per stack — generators added once shapes stabilize.

## Design tokens

`shared/design-tokens/tokens.json` holds colors, spacing, typography in a stack-agnostic shape (loosely [DTCG](https://design-tokens.github.io/community-group/format/) format). Per-client build step transforms it into:

- Flutter: Dart constants
- Web: CSS custom properties or Tailwind theme extension
- Native: `Colors.xml` / Swift extension

## API resilience — surviving breaking changes

The backend will break things. Clients must tolerate it without building an enterprise anti-corruption layer.

**Five rules, applied identically in every client:**

1. **Versioned base URL** — `/v1/mixtures`, `/v1/species`, … Client pins to one version. Upgrades are explicit.
2. **DTO ≠ domain model** — `MixtureDto` mirrors the raw JSON (loose, optional-heavy, may contain unknown fields). `Mixture` is what screens/state work with. Never pass DTOs into the UI layer.
3. **One thin mapper per resource** — pure function like `mixtureFromDto(dto): Mixture`. ~20–40 lines, lives next to the domain model. No DI, no class hierarchy, no codegen until schemas stabilize.
4. **Tolerant parsing** — unknown JSON fields silently ignored. Optional fields default in the mapper. Never crash on schema drift; degrade visibly ("—" for missing description, empty list for missing relations).
5. **Server-version probe** — `GET /version` at boot. If server-major > client-supports, show a soft "update available" hint. Never block the app.

**Mental model:** the mapper is the only place in the codebase that knows about both shapes. A breaking change is a 1-line DTO edit + a 1-line mapper edit. The 5,000 lines of UI behind don't move.

**Anti-patterns to avoid:**
- Generic adapter pattern with interfaces + DI containers.
- Auto-generated mappers wired into the build (do this AFTER schema stabilizes).
- Multiple API client versions running side-by-side.
- Per-screen "fallback to old endpoint" branching.

Each client's README documents where its `*Dto` types and mappers live.

## Decision log

ADR-style notes go in `docs/decisions/` (created on demand). For now this file captures the layout intent — moves to ADRs once we start making non-obvious trade-offs.
