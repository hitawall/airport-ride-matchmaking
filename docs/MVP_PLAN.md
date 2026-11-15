# Airport Ride-Matchmaking — MVP Plan

> **Historical document.** This is the original plan approved before any code was written (2026-11-12). It captures the *reasoning* behind the architecture (why Flutter, why the legal boundary, why each product decision) and is still accurate for that. It does **not** reflect everything built since — several things shipped differently than planned here (see [PROJECT_STATE.md](./PROJECT_STATE.md) for the authoritative current status):
> - Google Maps / Places autocomplete was deferred; destination entry uses a curated Bengaluru-locality dropdown instead (works without any API key)
> - `pusher_channels_flutter` was dropped from the client; chat/match updates use polling only for now
> - `freezed`/`json_serializable` codegen was dropped in favor of plain hand-written Dart model classes (simpler, no build_runner step)
> - An `OTP_TEST_MODE` bypass was added post-launch so the app is testable without MSG91 credentials
> - A real Home/dashboard screen, consistent back-navigation, swipe gestures, and a full visual design pass were added in response to user testing feedback (none of this was in the original milestone list)
>
> Read this for *why* the foundation looks the way it does. Read **PROJECT_STATE.md** for *what's actually running right now* and what to do next.

## Context

`hitawall/airport-ride-matchmaking` is a brand-new, empty repo (bootstrapped so far only with the `claude-code-essentials` template: `CLAUDE.md`, issue/PR templates, labels, CI placeholder, `/new-issue` `/feature` `/fix` `/sync` slash commands — no app code yet).

The product: a ride-**matchmaking** app (not a cab booking service) for Bengaluru, scoped initially to airport→home trips from Kempegowda International Airport (BLR). Travelers landing around the same time, heading in roughly the same direction, get matched with each other ("Tinder, but to share a cab, not to date") so they can split a single cab instead of booking separately.

**Hard legal boundary — drives the whole design**: Karnataka's transport department declared carpooling apps illegal in Sept 2023 when they pool *private* vehicles into a de facto commercial service (penalties, RC suspension). This app only introduces people who then book an **already-licensed cab** (Uber/Ola/Rapido) themselves — closer to a social-matchmaking layer than an aggregator, but this distinction is untested in court. Mitigation baked into every milestone: **the app never operates vehicles, never handles payment/fare-splitting, never books the cab.**

Goal: a web prototype first (fast to test), then native iOS/Android apps, from **one codebase, no rewrite**.

## Confirmed product decisions

| Decision | Choice |
|---|---|
| Payment / fare-splitting | Fully out of scope, permanently — legal risk mitigation |
| Identity verification (MVP) | Phone OTP + profile photo only. No gov-ID/KYC in MVP |
| Gender-based match filtering | **In MVP**, and **symmetric** — a "women-only" preference makes that user invisible to men's candidate lists too, not just a one-way filter |
| Flight arrival time | Manual entry (flight number + expected arrival time typed by user). No live flight-tracking API |
| Multiple simultaneous mutual matches | **First-mutual-wins** — the first mutual like locks in as the match; all other pending candidates for both users auto-expire |
| Contact sharing after match | **In-app chat only, forever** — no phone number reveal, even after mutual match |

## Tech stack

**Frontend framework was re-evaluated on pure technical merit (not stack-comfort) and switched from Expo/React Native to Flutter** — two independent research passes agreed Flutter wins for this app specifically, mainly because `react-native-maps` has no web implementation at all (a dead end for the map pin-picker, which is central to ride-request creation), whereas Flutter's `google_maps_flutter` + `google_maps_flutter_web` is one Google-maintained plugin giving identical map behavior across web/iOS/Android. Flutter's own rendering engine (Skia/Impeller, not native-widget bridging) also gives the swipe-card match UI consistent physics/animation across all three targets with no per-platform tuning. Flutter web's historical SEO weakness is irrelevant here since the whole product sits behind phone-OTP auth.

- **Frontend**: Flutter (Dart) — one codebase for the web prototype now and iOS/Android later, no rewrite. State management: Riverpod. Navigation: `go_router` (declarative routing, serves the same role as Expo Router). Web build via `flutter build web --wasm` (Skwasm with automatic CanvasKit fallback for unsupported browsers).
- **Maps**: `google_maps_flutter` (mobile) + `google_maps_flutter_web` (web) — same widget/API across all three targets, no platform-specific wrapper needed.
- **Backend**: thin Next.js app, API routes only (no pages), deployed on Vercel — unchanged, independent of frontend framework choice.
- **Database**: Neon Postgres + PostGIS extension (`CREATE EXTENSION postgis;` — confirmed supported on Neon) for destination geocoordinates. H3 hex-grid cell IDs for cheap proximity matching, computed server-side in the Next.js API via `h3-js` (**not** a Postgres H3 extension — not confirmed available on Neon). The Flutter client never touches H3 directly; it only calls the API and receives a ranked candidate list.
- **Geocoding/autocomplete**: Google Maps Platform only (Geocoding API + Places Autocomplete) — consolidated onto one provider since `google_maps_flutter` already requires a Google Maps API key; avoids running two map providers. India gets a 7x higher free tier on Google's Essentials SKUs.
- **Auth**: Phone OTP via MSG91 (cheaper, better Indian-carrier DLT compliance than Firebase/Twilio for India-only) — this choice is backend/SMS-delivery-driven, independent of the frontend framework switch.
- **Chat/realtime**: Pusher Channels (DB-agnostic, no need to run a second Postgres alongside Neon) via the community `pusher_channels_flutter` package, + polling fallback.
- **Repo structure**: `apps/api` (Next.js, TypeScript, pnpm) and `packages/db` (Drizzle ORM schema/migrations, TypeScript) stay in a pnpm/Turborepo workspace as before. `apps/mobile` is now a **separate Flutter/Dart project** (its own `pubspec.yaml`/toolchain) sitting as a sibling directory — it is not part of the pnpm workspace, since Dart and TypeScript don't share a type system. There is **no shared-types package** across the API/app boundary; the contract between them is a plain REST/JSON API, documented (e.g. a committed OpenAPI/markdown spec in `apps/api`) rather than compiler-enforced. Dart-side request/response models use `freezed`/`json_serializable`, hand-written to match the documented contract.
- **Notifications**: polling every 10–15s on an "awaiting match" screen for MVP; native push (`firebase_messaging` or equivalent) + Web Push deferred.

## Build order

### Milestone 0 — Provisioning
Start **MSG91 DLT template registration first** — unpredictable lead time (hours to days), blocks all auth testing if started late. In parallel: Neon project + `postgis` extension + `main`/`dev` branches; two Vercel projects (`-api`, `-web`) linked to Neon; Google Cloud project with Maps SDK for Android, Maps SDK for iOS, Maps JavaScript API, Geocoding API, and Places API all enabled, billing attached; local Flutter SDK install + `flutter doctor` clean; Pusher Channels account; Vercel Blob store for profile photos.

### Milestone 1 — Monorepo scaffolding
TypeScript side stays a pnpm/Turborepo workspace: `pnpm-workspace.yaml`, `turbo.json`, `apps/api`, `packages/db`, `packages/config`. Drizzle ORM + `@neondatabase/serverless` (not Prisma — plays better with raw SQL for H3 neighbor queries). `apps/mobile` is created separately as its own Flutter project (`flutter create`) with Riverpod, `go_router`, `google_maps_flutter`/`google_maps_flutter_web`, `freezed`/`json_serializable`, and `pusher_channels_flutter` added to `pubspec.yaml` — it is not part of the pnpm workspace. Fill in the already-templated `.github/workflows/ci.yml` with two jobs: a Node.js job for `apps/api` (`pnpm install --frozen-lockfile && pnpm turbo lint typecheck test`) and a Flutter job for `apps/mobile` (`flutter pub get && flutter analyze && flutter test`). `.env.example` (for `apps/api`) documenting every var (no secrets): `DATABASE_URL`, `JWT_SECRET`, `MSG91_AUTH_KEY`, `MSG91_TEMPLATE_ID`, `GOOGLE_MAPS_API_KEY`, `PUSHER_*`, `BLOB_READ_WRITE_TOKEN`. A short `apps/api/API_CONTRACT.md` (or OpenAPI spec) documents every endpoint's request/response shape — this is the hand-maintained substitute for a shared-types package across the Dart/TypeScript boundary.

### Milestone 2 — Database schema
`packages/db/schema.ts` + Drizzle migrations:
- **users**: `id, phone unique, phone_verified, created_at, updated_at`
- **profiles** (1:1): `user_id pk, display_name, gender, gender_preference ('any'|'same_gender_only'), profile_photo_url, home_locality_label, bio, is_active`
- **otp_requests**: `id, phone, msg91_request_id, attempt_count, verified_at, expires_at`
- **ride_requests**: `id, user_id, flight_number, flight_arrival_at, arrival_window_start/end (±45min), destination_address, destination_lat/lng, destination_geog (generated, display/sort only — not matching), h3_cell_res7, h3_cell_res8, destination_locality_label, status ('open'|'matched'|'expired'|'cancelled')`. Indexes: `(status, h3_cell_res7)`, `(status, arrival_window_start, arrival_window_end)`.
- **matches**: `id, ride_request_a_id, ride_request_b_id, user_a_id, user_b_id, status ('proposed_by_a'|'proposed_by_b'|'mutual'|'rejected'|'expired'), score, responded_at_a/b`. Unique constraint on the unordered pair to prevent duplicates.
- **chat_messages**: `id, match_id, sender_id, body, created_at, read_at`. Index `(match_id, created_at)`.
- **reports**: `id, reporter_id, reported_id, match_id?, reason (enum), details, status`
- **blocks**: `id, blocker_id, blocked_id, created_at`. Unique `(blocker_id, blocked_id)`.

### Milestone 3 — Backend API: Auth
`POST /api/auth/otp/send` (rate-limited ~3/hr/phone) → MSG91 send, insert `otp_requests`. `POST /api/auth/otp/verify` → MSG91 verify, upsert `users`, issue JWT (30-day, `expo-secure-store` native / `localStorage` web). Bearer-JWT middleware for all routes below.

### Milestone 4 — Backend API: Profile & ride requests
`GET/PUT /api/profile/me`, `POST /api/profile/photo` (Vercel Blob). `POST /api/ride-requests` (computes arrival window + H3 cells server-side via `h3-js`; enforces one active `open` request per user, 409 otherwise). `GET /api/ride-requests/mine`, `PATCH /api/ride-requests/:id` (cancel only). Vercel Cron every 15 min sweeps `open → expired` past `arrival_window_end + 4h`.

### Milestone 5 — Matching algorithm
H3 computed and neighbor-expanded (`h3.gridDisk(cell, 1)`) in app code, not SQL/extension. Candidate query (`GET /api/ride-requests/:id/candidates`): other `open` requests where `h3_cell_res7` is in my k=1 neighbor ring, arrival windows overlap, no block exists either direction, **and gender-preference check applied symmetrically in both directions** (neither side sees the other if either has set `same_gender_only` and genders differ). Ranked: exact res8 cell match first, then closest arrival time. `POST /api/matches {action: like|pass}`: upserts a `matches` row; on mutual, transactionally set both `ride_requests.status='matched'` and **expire every other pending match for both users** (first-mutual-wins, per decision above). `POST /api/matches/:id/reject` excludes that pair permanently from future candidate queries.

### Milestone 6 — Chat & realtime
`GET /api/matches/mine`, `GET /api/matches/:id`, `POST /api/matches/:id/messages` (inserts + fires Pusher event on `match-{id}` channel), `GET /api/matches/:id/messages?after=` (history + polling fallback). Expo client subscribes to Pusher on entering chat, polls on disconnect. **No phone number is ever included in any API response for a matched counterpart** — enforce this at the serializer level, not just the UI, per the contact-sharing decision.

### Milestone 7 — Reports & blocks
`POST /api/reports`, `POST /api/blocks` (immediately excludes pair from future candidates + hides thread client-side; messages retained server-side, not hard-deleted), `DELETE/GET /api/blocks`. No moderation dashboard in MVP — triage via direct Neon console queries.

### Milestone 8 — Flutter app screens
Navigation via `go_router`; app/auth/profile/ride-request state via Riverpod providers calling `apps/api` per `API_CONTRACT.md`.
1. Legal interstitial (must acknowledge): "This app only introduces travelers to split a cab. You book and pay for your own ride via Uber/Ola/Rapido. Always meet at the official airport pickup zone."
2. Phone entry → OTP send
3. OTP verify (6-digit, resend timer)
4. Profile setup: name, gender, gender-preference toggle, photo (`image_picker`), home locality
5. Create ride request: flight number, arrival date/time, destination via Google Places Autocomplete + `google_maps_flutter` pin preview (same widget/code path on web and native)
6. Awaiting-match screen: polls candidates every 10–15s, safety banner
7. Match review cards: photo, name, gender, arrival-time delta, locality; gesture-driven swipe deck (`GestureDetector`/`Draggable` with Flutter's own animation engine — consistent physics on web/iOS/Android) with explicit Like/Pass buttons as a non-gesture fallback
8. Mutual-match celebration screen → chat CTA
9. Chat screen: messages + input, `pusher_channels_flutter` + polling fallback, persistent safety banner, report/block reachable from header
10. Settings: edit profile, view/cancel active request, blocked-users list, logout

### Milestone 9 — Web prototype deployment
`apps/mobile`: `flutter build web --wasm` → static `build/web/`, deployed as its own Vercel project (static output directory pointed at `build/web`). `apps/api` deployed separately with CORS enabled for the web origin. API base URL and Pusher key injected via Flutter's `--dart-define` at build time per Vercel environment (preview vs production) — consumed identically later by iOS/Android builds, no code change needed. PR-gated preview URLs for both projects, fitting the repo's existing issue/PR workflow.

## Explicitly deferred past MVP
Payment/fare-splitting (permanent) · gov-ID/KYC · live flight-tracking API · push notifications · ratings/reviews · multi-city expansion · group matches beyond 2 · route-polyline-based matching (vs H3 approximation) · EAS native builds/store submission · live-location-sharing/SOS · phone-number reveal (permanent) · admin moderation dashboard · analytics.

## Remaining open technical calls (defaults locked in, flagging for visibility — not blocking)
- H3 computed in TypeScript (`h3-js`) rather than a Postgres extension, since H3-on-Neon support isn't confirmed. The Flutter client never computes or sees raw H3 cells — it only consumes the ranked candidate list from the API.
- Pusher Channels picked concretely for realtime chat (DB-agnostic vs. Supabase Realtime, which would mean a second Postgres); consumed from Flutter via the community `pusher_channels_flutter` package.
- JWT-only auth, no refresh-token rotation — fine for an MVP with no money movement, revisit before scaling.
- API contract between `apps/api` (TypeScript) and `apps/mobile` (Dart) is documented, not compiler-shared — a deliberate tradeoff of the Flutter switch; keep `API_CONTRACT.md` updated whenever an endpoint shape changes.

## Execution approach
Each milestone above maps to one GitHub Epic issue (using the repo's existing `.github/ISSUE_TEMPLATE/epic.yml`) with child Feature/Task issues, built via the already-configured `/new-issue`, `/feature`, `/fix` slash commands and PR-gated `main` per `CLAUDE.md`'s git workflow rules.

## Verification
- Milestone 0–4: provisioning smoke tests (curl MSG91 send/verify, Ola Maps geocode against real Bengaluru addresses, `psql` to confirm `postgis` extension active on Neon).
- Milestone 5: unit tests on the candidate query against seeded fixture rows covering — same-cell match, adjacent-cell match, no-overlap-window exclusion, symmetric gender-filter exclusion in both directions, blocked-pair exclusion, first-mutual-wins expiring other pending matches.
- Milestone 8–9: manual end-to-end walkthrough in the Expo web build (`expo start --web`) — full flow from phone entry through a simulated mutual match and chat exchange using two seeded test accounts.
