# Telemetry: availability, errors and usage

Everything is built and switched **off** until the owner supplies keys. With no
keys set, nothing is sent anywhere and the app behaves identically.

## What exists

| Need | How | Needs from owner |
|---|---|---|
| Is it up? | Public `GET /api/health` (200 only if the database answers) | An uptime monitor pointed at it |
| Launch readiness | `/api/internal/readiness` + preflight ([PRODUCTION_EMAIL_SETUP.md](PRODUCTION_EMAIL_SETUP.md)) | Run it before launch |
| API errors | `instrumentation.ts` logs every unhandled 5xx (route, method, error text, no bodies) to the Vercel logs, and to Sentry if `SENTRY_DSN` is set | Sentry project + DSN |
| App crashes | Flutter hooks send unhandled errors to `POST /api/client-errors` (public, size-capped, emails and phone numbers scrubbed, max 5 per app run), which forwards to Sentry | Same DSN |
| Product usage | The API records server-side events (below) to PostHog when `POSTHOG_API_KEY` is set | PostHog project key |
| Active users | The app sends `app_opened` once per run after sign-in (`POST /api/events`) | Same key |
| Opt-out | Settings > "Share anonymous usage data" turns off crash reports and `app_opened` | none |

No SDKs were added to the app or the API: events and errors are plain HTTPS
calls, so keys stay on the server and the web build has no tracking cookies.

## Events (all server-side except `app_opened`)

`account_created`, `otp_verified`, `google_sign_in`, `ride_request_created`, `match_like`,
`match_pass`, `mutual_match_created`, `match_unmatched`, `message_sent`,
`rating_given` (score), `report_filed` (reason), `block_created`,
`feedback_submitted`, `account_deleted`, `app_opened` (platform, app version).

Every event carries release (git commit), environment, and an opaque id.
Funnel steps before sign-in other than OTP verified are not tracked: the first
signal is `otp_verified`.

## Privacy rules (keep when adding events)

- The person id is `HMAC-SHA256(userId, TELEMETRY_ID_SALT or JWT_SECRET)`. It is
  never the email, phone or name. After an account is deleted nothing links the
  id back to anyone, so past events are effectively anonymous. (`account_deleted`
  is recorded just before.)
- Properties are fixed, coarse fields chosen in code. Never put message text,
  addresses, names, emails, phone numbers or photo URLs in an event.
- Server events send no IP and create no person profile in PostHog.
- The privacy policy ("Technical" and "Who we share it with") and the store
  data-safety forms must stay in step with this list.
- The Settings opt-out covers what the app sends (crashes, `app_opened`). The
  server-side events describe actions the user performs on the service
  (like, message, ...), are pseudonymous, and are described in the privacy policy.

## Owner setup (in order)

1. **Uptime monitor** (UptimeRobot, Better Stack, ...): monitor
   `https://<api-host>/api/health` every 1-5 minutes and the web app URL; alert
   to your email/phone. Expect HTTP 200 and `"status":"ok"`.
2. **Sentry**: create a project (platform: any / JavaScript), copy the DSN, set
   `SENTRY_DSN` in the Vercel API project. Add an alert on new issues. Free tier is enough to start.
3. **PostHog**: create a project (choose the region), copy the project API key,
   set `POSTHOG_API_KEY` (and `POSTHOG_HOST=https://eu.i.posthog.com` for an EU project) in Vercel.
4. **Dashboard** in PostHog: signups per day (`account_created`), funnel
   `otp_verified` -> `ride_request_created` -> `match_like` -> `mutual_match_created` -> `message_sent`,
   daily active users (`app_opened`), match rate, requests per day.
5. Redeploy the API. Check events arrive within a minute of using the app.
6. Update the Play Data safety form: "App activity" and "Crash logs" collected,
   not shared for ads, optional (user can turn off in Settings for the app-sent part).

## Not covered (deliberately)

- Silent-failure counters for Resend bounces, Pusher outages, Blob upload failures
  and the daily cron: failures are in the Vercel logs, and the uptime monitor
  catches a total outage. Resend's dashboard shows bounces. Add alerts there.
- Supply-side metrics (open requests per area) are queries on the database, not events.
- Latency dashboards: use Vercel's built-in observability for the API project.
