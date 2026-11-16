# Airport Ride-Matchmaking

A ride-matchmaking app for Bengaluru — travelers landing at Kempegowda International Airport (BLR) around the same time, heading in roughly the same direction, get matched with each other so they can split a cab. Think "Tinder, but to share a ride, not to date."

**This app never books, operates, or pays for any vehicle.** It only introduces people; they book their own cab (Uber/Ola/Rapido) and coordinate the fare themselves. That boundary is deliberate — see [`docs/MVP_PLAN.md`](docs/MVP_PLAN.md) for the legal reasoning behind it.

## Live

- **Web app**: https://airpool.online
- **API**: https://api.airpool.online

Log in with any phone number — OTP code **`000000`** works for now (trial mode, see [`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md)).

## Docs

| File | What's in it |
|---|---|
| [`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md) | **Read this first.** Current status, what's done, what's blocked, gotchas. |
| [`docs/MVP_PLAN.md`](docs/MVP_PLAN.md) | Original architecture plan and the reasoning behind it. |
| [`CLAUDE.md`](CLAUDE.md) | Git/PR workflow rules for this repo. |

## Stack

- **Frontend**: Flutter (Dart) — one codebase for web today, iOS/Android later. Riverpod for state, `go_router` for navigation.
- **Backend**: Next.js (API routes only) on Vercel.
- **Database**: Neon Postgres + PostGIS, Drizzle ORM.
- **Monorepo**: pnpm/Turborepo for `apps/api` + `packages/db`; `apps/mobile` (Flutter) is a separate project alongside them.

## Getting started (local development)

```bash
bash scripts/setup-dev-environment.sh
```

This checks for required tools (Node 22+, pnpm, Flutter, Vercel CLI, GitHub CLI), installs dependencies, and links/pulls environment variables from Vercel (requires `vercel login` + access to the `shubham-arora-s-projects` team).

Then, in separate terminals:

```bash
# Backend
cp .env.local apps/api/.env.local
cd apps/api && pnpm dev          # http://localhost:3000

# Frontend
cd apps/mobile
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
```

## Resuming on a new machine

If you're picking this project back up on a different computer (or starting a fresh Claude Code session after a gap):

1. Clone the repo and run `bash scripts/setup-dev-environment.sh` (above).
2. Read [`docs/PROJECT_STATE.md`](docs/PROJECT_STATE.md) — it's kept current with what's deployed, what's done, and what's still open.
3. If you're using Claude Code, it should automatically pick up `.claude/skills/resume-project`, which does the above orientation for you — just start the session and ask it to continue the project, or explicitly invoke the skill.

Everything that matters — code, issue history, and the plan — lives in this repo and on GitHub. Nothing about this project's state should be trapped on one machine's local session.

## Workflow

Every change starts with a GitHub issue, goes on a `feat/issue-N-slug` or `fix/issue-N-slug` branch, opens a PR, waits for CI, then gets merged. Direct pushes to `main` aren't used. See [`CLAUDE.md`](CLAUDE.md) for the full rules and the `.claude/commands/` slash commands (`/new-issue`, `/feature`, `/fix`, `/sync`) that automate parts of it.
