---
name: resume-project
description: Orient a fresh Claude Code session on the airport-ride-matchmaking project's current state, history, and next steps. Use at the start of any new session on this repo, especially on a different machine than where work last happened.
---

# Resume: Airport Ride-Matchmaking

This project has substantial history that lives in GitHub (issues/PRs), not just local files. Before doing anything else in a new session:

1. **Read `docs/PROJECT_STATE.md`** — the authoritative, up-to-date snapshot: what's deployed, what's done, what's blocked, and known gotchas. This is more current than your training data or any summary you might otherwise guess at.
2. **Read `docs/MVP_PLAN.md`** — the original architecture plan and the reasoning behind it (why Flutter over React Native, the legal positioning, the product decisions). It has a header noting where reality has since diverged from the plan — trust PROJECT_STATE.md over this for anything that conflicts.
3. **Read `CLAUDE.md`** — the git workflow rules for this repo. The short version: every change starts with a GitHub issue, goes on a `feat/issue-N-slug` or `fix/issue-N-slug` branch, opens a PR, waits for CI, then gets squash-merged. **Never push directly to `main`** — this was an explicit, repeated requirement from the project owner earlier in this project's history (see the discussion around issue #15/#16 if you want the full context of why).
4. **Check open issues**: `gh issue list --state open` — as of the last update to PROJECT_STATE.md, issues #22 (Google Maps) and #43 (Google OAuth sign-in) are open and blocked on the user providing credentials. Don't start on these unprompted; they need the user's input first. (#23 Pusher and #24 real email OTP are both done.)
5. **If the user reports a bug**, check Vercel production logs first (`vercel logs api.airpool.online --environment production`) before assuming where the fault lies — more than once in this project's history, a reported "broken button" turned out to be a backend working perfectly with zero client-side feedback, not a logic bug. Verify before diagnosing.
6. **If you haven't run `scripts/setup-dev-environment.sh` yet on this machine**, do that first — it checks for required tools (Node, pnpm, Flutter, Vercel CLI, gh CLI), installs dependencies, and links/pulls Vercel env vars.

## Quick facts you'll otherwise re-derive the hard way

- Live web app: https://airpool.online
- Live API: https://api.airpool.online
- OTP login sends a real email via Resend (`OTP_TEST_MODE=false` in production); set it to `true` locally/temporarily for free testing, which accepts the fixed code `000000` for any email
- Chat/match updates push in realtime via Pusher Channels; polling remains as a fallback
- The Vercel API project must be deployed **from the repo root**, not `apps/api` (breaks the pnpm workspace otherwise) — see PROJECT_STATE.md "Gotchas" for why
- `flutter build web --wasm` does not work for this project (a dependency isn't WASM-compatible yet) — use plain `flutter build web`
- Browser-based click automation is unreliable against this app's Flutter-web canvas UI, especially text fields — prefer API-level verification (curl/logs/DB queries) over trying to force UI automation to work

After reading the above, summarize the current state back to the user in a few sentences and ask what they'd like to work on next, rather than assuming.
