# Production email and launch preflight

Login needs real email codes. Until this is done the production API runs with
`OTP_TEST_MODE=true`, which accepts the code `000000` for any email. **Do not
turn test mode off until step 3 works, or nobody can log in.**

## Steps (owner)

1. **Domain.** Buy the custom domain (issue #46) and note its name.
2. **Resend.** In Resend, add the domain and add the DNS records it shows at
   your domain registrar (SPF, DKIM; DMARC is recommended). Wait for
   "Verified". Create an API key limited to sending.
3. **Vercel (API project) env vars, Production:**
   - `RESEND_API_KEY` = the key
   - `OTP_FROM_EMAIL` = e.g. `Airport Ride <login@yourdomain.com>` (must be on the verified domain, not `resend.dev`)
   - leave `OTP_TEST_MODE` **unset** (or `false`) once step 4 passes
4. **Test before switching.** Keep test mode on, redeploy, then temporarily set `OTP_TEST_MODE=false`
   on a **Preview** deployment (or switch production during a quiet period) and sign in with a Gmail and an
   Outlook address. Check: arrives in under a minute, lands in the inbox (not spam), the code works.
5. **Remove `OTP_TEST_MODE`** from Production and redeploy.
6. **Run the preflight** (below). It must say `READY`.

## Preflight

Checks the live API without revealing any secret values:

```bash
node apps/api/scripts/preflight.mjs https://airport-ride-matchmaking-api.vercel.app "<CRON_SECRET>"
```

It also runs from GitHub: Actions > "Production preflight" > Run workflow
(needs the repository secret `PROD_CRON_SECRET`, the same value as the API's
`CRON_SECRET`).

Required checks: test mode off, email configured with a verified sender, strong
`JWT_SECRET`, store-reviewer login set up ([STORE_REVIEW_ACCOUNT.md](STORE_REVIEW_ACCOUNT.md)),
chat and photo storage configured, `CRON_SECRET` set. Recommended: moderation
email and token ([MODERATION.md](MODERATION.md)), `WEB_APP_ORIGIN`.

## Limits worth knowing

- Max **3 codes per hour per email**. The app shows the server's message when the limit is hit. A failed email send does not use up an attempt.
- A code expires after 5 minutes and allows 5 wrong tries.
- If sending fails (Resend outage, unverified domain) the app shows "We couldn't send the code right now" and the cause is in the Vercel logs (`otp: email delivery failed`).
- `/api/health` is public and returns 200 only when the database answers; point an uptime monitor at it (see issue #121).
