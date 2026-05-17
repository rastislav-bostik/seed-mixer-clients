# Client matrix

Tracks each client variant — what it is, why it exists, how to run it.

| Dir | Stack | Targets | Why it exists | How to run |
|---|---|---|---|---|
| `flutter-app/` | Flutter 3.x + Dart | Android, iOS, Web | First cross-platform attempt; cheap reach across 3 targets with 1 codebase | `cd flutter-app && flutter run -d chrome` |

_More rows added as clients are scaffolded._

## Selection criteria (eventually)

When picking which client stays as the "real" one, evaluate on:

1. **Developer ergonomics** — how fast to add a screen, debug, hot-reload?
2. **UX fidelity** — does it feel native enough on each platform?
3. **Build & deploy** — CI complexity, store submission pain, web hosting cost.
4. **Community / longevity** — package ecosystem, hire-ability, official Anthropic-blessed-style stability.
5. **Personal joy** — which stack do I actually want to open on Sunday morning?

No single winner expected — the answer might be "Flutter for mobile, Next.js for web" or "native iOS + Nuxt web" depending on what hurts.
