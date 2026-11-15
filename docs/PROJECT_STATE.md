# Project State — Airport Ride-Matchmaking

**Last updated**: 2026-11-15
**Read this first** when picking the project back up, especially on a new machine. For the *why* behind the architecture, see [MVP_PLAN.md](./MVP_PLAN.md). For day-to-day workflow rules (git, slash commands), see [CLAUDE.md](../CLAUDE.md).

## Live deployments

| What | URL |
|---|---|
| Web app (Flutter web) | https://airport-ride-matchmaking-web.vercel.app |
| API | https://airport-ride-matchmaking-api.vercel.app |

Vercel org/scope: `shubham-arora-s-projects`. Projects: `airport-ride-matchmaking-api` (Root Directory set to `apps/api`, linked from the **repo root** — see "Gotchas" below), `airport-ride-matchmaking-web` (static deploys of `apps/mobile/build/web`).

Database: Neon Postgres, provisioned via the Vercel Marketplace integration, PostGIS extension enabled. Vercel Blob store for profile photos, also via Marketplace.

## Current status: MVP is feature-complete and testable today

Everything in the original [MVP_PLAN.md](./MVP_PLAN.md) milestone list is built, plus a round of fixes/polish from live user testing. You can log in (phone + OTP) and use the full flow: onboarding → profile → create ride request → match → chat, right now, with **zero paid third-party accounts** (see "How OTP works right now" below).

### Done (all merged to `main`, chronological)

**Foundation (issues #1, #3, #5, #7, #9, #11, #13)**
- Monorepo: pnpm/Turborepo workspace (`apps/api` Next.js + `packages/db` Drizzle) + a separate Flutter project (`apps/mobile`, not part of the pnpm workspace — Dart/TS don't share a type system)
- Full DB schema (8 tables) migrated against Neon/PostGIS
- Phone OTP auth (JWT sessions), profile CRUD + photo upload (Vercel Blob)
- Matching algorithm: H3 k=1 neighbor adjacency + arrival-time window overlap + **symmetric** gender-preference filter + block exclusion, like/pass with first-mutual-wins
- Chat (polling-based) between mutual matches, reports/blocks
- Full Flutter app screens (onboarding → chat)
- Deployed to Vercel (API + static web build)
- `OTP_TEST_MODE` bypass added so the app is testable with zero SMS-provider cost (see below)

**Post-launch fixes from live testing (issues #15, #17–#21, #29, #31)**
- Fixed a CORS bug (`PUT` was missing from `Access-Control-Allow-Methods`) that silently blocked profile saves
- Profile edit screen now pre-fills existing data (was always blank)
- Added a real Home/dashboard screen — replaced a silent auto-redirect with an actual rendered status screen
- Every screen in the match-making funnel now has a consistent, always-visible Home button — nothing is a dead end regardless of entry point
- Awaiting-match screen explains the polling cadence, shows elapsed time, and tells first users an empty match pool is expected, not broken
- Full visual design pass: warm cream/coral/plum palette, rounded cards, bold editorial type scale, applied consistently (inspired by the dating-app genre, not copying any specific app's trademarked assets)
- Like/pass buttons now show immediate confirmation (SnackBar) — the backend was always working (verified via Vercel logs, zero failed requests); the bug was purely missing UI feedback
- Swipe-left/swipe-right gestures added to match review, with card tilt/rotation, LIKE/PASS stamp overlays, and synced button-highlight animation; buttons remain fully functional as a fallback

### How OTP works right now (important)

`OTP_TEST_MODE=true` is set on the production API. This means:
- `POST /api/auth/otp/send` does **not** call a real SMS provider
- `POST /api/auth/otp/verify` accepts the fixed code **`000000`** for *any* phone number

This is intentional for trial testing (see issue #13) — it lets anyone test the full app today with zero cost and zero third-party account setup. **This must be turned off (`OTP_TEST_MODE=false` or unset) before any real, untrusted users are invited**, once real MSG91 credentials are wired in (see Blocked below).

### Blocked / open — needs your input, not urgent

Three integrations are deliberately deferred because they need credentials only you can provide. None of them block testing today; each has a working interim substitute. Tracked as open GitHub issues:

| Issue | What | Interim substitute | What's needed from you |
|---|---|---|---|
| [#24](https://github.com/hitawall/airport-ride-matchmaking/issues/24) | Real MSG91 OTP delivery | `OTP_TEST_MODE` (see above) | MSG91 account, `MSG91_AUTH_KEY`, `MSG91_TEMPLATE_ID` (DLT template registration can take hours–days, start early) |
| [#22](https://github.com/hitawall/airport-ride-matchmaking/issues/22) | Live Google Places autocomplete + map pin preview | Curated 15-locality dropdown (`apps/mobile/lib/data/bengaluru_localities.dart`) — works fine, no key needed | Google Cloud project, Maps JS/Places/Geocoding APIs enabled, billing, `GOOGLE_MAPS_API_KEY` |
| [#23](https://github.com/hitawall/airport-ride-matchmaking/issues/23) | Realtime push for chat/match updates | Polling (8–12s intervals) — works fine | Pusher account, `PUSHER_APP_ID`/`PUSHER_KEY`/`PUSHER_SECRET`/`PUSHER_CLUSTER` |

When you're ready for any of these, just say so in a new session (or this one) with the credentials and I'll wire them in.

## Workflow conventions (already set up, keep following these)

- **Every change starts with a GitHub issue**, goes on a `feat/issue-N-slug` or `fix/issue-N-slug` branch, opens a PR, waits for CI (`gh run list` / a Monitor loop), then gets squash-merged — **never push directly to `main`**. This was an explicit, repeated user requirement (see git history around issue #15/#16 where this was first enforced).
- **Deploys to both projects are now automatic on merge to `main`** (see issue #41): the API project is connected to Vercel's native GitHub integration (deploys itself, no workflow step); the web app is built and deployed by the `deploy-web` job in `.github/workflows/ci.yml`, which runs after the Mobile CI job passes and needs a `VERCEL_TOKEN` repo secret. If you ever need to redeploy manually: web is `flutter build web --dart-define=API_BASE_URL=https://airport-ride-matchmaking-api.vercel.app` from `apps/mobile` then `vercel deploy build/web --prod --yes --project airport-ride-matchmaking-web`; API is `vercel deploy --prod --yes` from the **repo root** (not `apps/api` — see Gotchas).
- Full rule set: [CLAUDE.md](../CLAUDE.md).

## Gotchas / things that will bite you if forgotten

1. **The Vercel API project must be linked and deployed from the repo root, not `apps/api`.** Deploying from within `apps/api` only uploads that subtree, which breaks the `workspace:*` dependency on `packages/db` (npm/pnpm can't resolve it without the monorepo root's lockfile/workspace file). The project's Root Directory is set to `apps/api` via the Vercel API (no CLI command exposes this setting directly) — the `.vercel/project.json` link lives at the repo root.
2. **`flutter build web --wasm` does not work** — `flutter_secure_storage_web` depends on legacy `dart:html`/`dart:js` interop that isn't WASM-compatible yet (an ecosystem gap, not our code). Use plain `flutter build web` (CanvasKit/JS target). Revisit `--wasm` if that package migrates to `package:web`.
3. **`google_fonts` is incompatible with the `material_ui` package** used throughout this app (two distinct, non-interchangeable `TextTheme` classes). The bold typography in `app_theme.dart` is achieved via font weight/size/letter-spacing on the built-in type scale instead.
4. **Vercel Hobby plan only allows daily cron jobs.** The ride-request expiry sweep (`apps/api/vercel.json`) runs `0 0 * * *` (daily), not the originally-planned 15-minute interval. Upgrade to Pro if faster expiry sweeps matter later.
5. **Browser automation in this environment cannot reliably click-test Flutter web's canvas-rendered UI**, especially text fields (works sometimes, fails sometimes, no consistent fix found — tried click, double-click, accessibility-mode toggle, discrete key events). Button taps work somewhat more reliably but not perfectly. When verifying fixes, prefer: (a) checking Vercel production logs for actual request/response status, (b) direct API testing via `curl`/Node scripts against the live Neon DB, (c) `flutter analyze`/`flutter test`, and only then (d) a best-effort visual browser check. Don't claim UI click-testing succeeded unless it actually did.
6. **Secrets are never committed.** `.env.local` (repo root) is gitignored and holds the pulled-down Vercel env vars for local dev. `apps/api/.env.local` is a gitignored *copy* sometimes made temporarily for local `next dev` testing (Next.js reads `.env.local` relative to the app directory) — delete it after local testing sessions, don't commit it.

## Resuming on a new machine

See the "Getting Started" and "Resuming on a new machine" sections in the [README](../README.md) — short version: clone, run `scripts/setup-dev-environment.sh`, then tell Claude Code to read this file and `MVP_PLAN.md`. The `.claude/skills/resume-project` skill automates that last step.
