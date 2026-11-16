# Testing

Three layers, from fastest to most realistic.

| Layer | What it covers | Command | Runs in CI |
|---|---|---|---|
| API unit tests | Phone and email rules, request schemas, airport and terminal rules, H3 cells, auth helpers, privacy scrubbing, launch-readiness checks | `pnpm --filter @airport-ride-matchmaking/api test` | Yes |
| App tests | Models, API client, boarding-pass decoder, formatters, phone field, alerts, fare split, install hints, screens with a fake API | `cd apps/mobile && flutter test` | Yes |
| API integration suite | Real flows against a running server and database: sign-in, profiles, trips, candidates, like and mutual match, chat and unread alerts, unmatch and resume, block, expiry sweep, account deletion | see below | Not yet (needs a throwaway database) |

## Running the integration suite

It writes real rows (and deletes them again), so point it at a database you
do not mind, never the live one. Start the API locally with the login test code
switched on, then run the suite:

```bash
OTP_TEST_MODE=true pnpm --filter @airport-ride-matchmaking/api dev
pnpm --filter @airport-ride-matchmaking/api test:integration
```

It reads `DATABASE_URL` and `CRON_SECRET` from `apps/api/.env.local` for the
expiry checks (they are skipped if missing) and refuses to run against anything
but localhost unless `ALLOW_REMOTE=1`. Set `RESEND_BASE_URL=http://127.0.0.1:9`
on the server to be sure no real email is attempted.

Why it is not in CI yet: the project uses a single hosted database, so a CI run
needs a throwaway copy (for example a Neon branch created per run). That needs a
Neon API key, which is an owner input.

## Where each rule is tested

- Matching (same airport and terminal, overlapping arrival windows, blocks, gender preference, an unmatched pair is never offered again): integration suite, "Ride requests and candidates" and "Unmatch".
- Like, pass and mutual transitions, trips becoming matched: "Like, mutual match, chat and unread alerts".
- Unmatch, ended-match alert, resume: "Unmatch tells the other person" and "Resuming a trip".
- Expiry (matches, open trips, stuck trips): "Expiry sweep".
- Moderation and cron authentication: API unit tests (`security-and-privacy`).
- Privacy (no emails or phone numbers in error reports): API unit tests.
