# What I need from you, in order

Everything that can be built without you is built. The items below are the
only things left that need **your** accounts, decisions or values. Do them top
to bottom; each says what to do, where the value goes, which issue it closes,
and what happens next. Tick a box when done and tell me, and I will do the
follow-up work (shown as "Then I...").

Not covered here on purpose: iOS (#112, later), Ola Maps (#22), Google sign-in
(#43). The custom domain (#46) appears because several steps depend on it.

Where values go: **GitHub repo variables** = Settings > Secrets and variables >
Actions > Variables. **GitHub secrets** = same page, Secrets tab. **Vercel env** =
Vercel > the *API* project > Settings > Environment Variables (Production).

---

## A. Start now (slow, runs while we work)

- [ ] **A1. Google Play Developer account** (individual). Pay the one-time fee, finish identity verification. Can take days. Closes the wait for step J.
- [ ] **A2. Line up 12+ testers** with Gmail accounts and Android phones (friends, family). Google requires 12 testers opted in for 14 continuous days before production for new personal accounts. Collect their Gmail addresses. The 14 days only start once the app is in closed testing, so this is the longest part of the whole path.

## B. Decisions (no accounts needed) - issue #111

- [ ] **B1. Final app name** and a short launcher label (about 12 characters). Draft: "Airport Ride Matchmaking" / "Airport Rides".
- [ ] **B2. Android package id**: permanent after the first Play upload. Decided: `online.airpool.app` (reverse of the chosen domain `airpool.online`). I change it in the build files once you confirm the domain is bought (see C1). Until then the build keeps the old placeholder.
- [ ] **B3. Icon**: look at the draft (`apps/mobile/assets/icon/store_icon_512.png`) and say keep or change.
  Then I: set name/id, regenerate icons, record in `docs/MOBILE_RELEASE_PLAN.md`. Details: [APP_IDENTITY.md](APP_IDENTITY.md).

## C. Domain and email - issues #46, #110

- [ ] **C1. Buy `airpool.online`** (chosen 2026-11-16; #46; confirm it is available at the registrar first, and note `.online` renews at roughly $16-36/yr). Steps: [PILOT_LAUNCH_PLAN.md](PILOT_LAUNCH_PLAN.md) section 1, then tell me it is bought and I connect it to Vercel. (Alternative if you change your mind: tell me to skip it and use a Gmail address meanwhile (then email delivery to the public needs a domain anyway, so this is recommended).
- [ ] **C2. Resend: verify the domain** (add the DNS records Resend shows). Create a send-only API key.
- [ ] **C3. Vercel env (API, Production):** `RESEND_API_KEY`, `OTP_FROM_EMAIL` (e.g. `Airport Ride <login@yourdomain.com>`).
- [ ] **C4. Switch off test mode:** test sign-in with a Gmail and an Outlook address, then **remove `OTP_TEST_MODE`** from Production and redeploy. Do not remove it before email works or nobody can log in. Steps: [PRODUCTION_EMAIL_SETUP.md](PRODUCTION_EMAIL_SETUP.md).
- [ ] **C5. A support mailbox** (e.g. `support@yourdomain.com`, or a Gmail for now). Used in D1 and the Play listing.
  Then I: point the web app to the new domain if you want, and verify with the preflight (step I).

## D. Legal text - issue #108

- [ ] **D1. GitHub repo variables:** `OPERATOR_NAME` (your legal name as an individual), `SUPPORT_EMAIL` (C5), `GRIEVANCE_OFFICER` (name and email; for an individual this is you), optionally `APP_NAME` (B1), `LEGAL_JURISDICTION` (default India), `WEB_APP_URL` (the final web address).
- [ ] **D2. Review the privacy policy and terms** in the app (Settings > About, or `<web>/#/privacy`, `<web>/#/terms`). Ideally have a lawyer look: text is in `apps/mobile/lib/features/legal/legal_content.dart`, I keep it matching the code.
- [ ] **D3. Set repo variable `LEGAL_REVIEWED` = `true`** once you accept the text. This removes the "Draft" banner.
  Then I: redeploy the web app (so `/privacy`, `/terms`, `/delete-account` are the public URLs for the Play form).

## E. Moderation - issue #113

- [ ] **E1. Vercel env:** `MODERATION_EMAIL` (where the daily report digest goes; needs C2/C3 done), `MODERATION_TOKEN` (24+ random characters, not the same as `CRON_SECRET`).
- [ ] **E2. Decide:** should we keep a record of removed accounts and reports (so reports survive account deletion, and a removed person cannot just re-register)? Today removal deletes everything including the reports. See [MODERATION.md](MODERATION.md).
  Then I: build the "kept record" if you say yes.

## F. Store reviewer login - issue #109

- [ ] **F1. Vercel env:** `REVIEW_ACCOUNT_EMAIL` and `REVIEW_ACCOUNT_CODE` (exactly 6 digits, not `000000`).
- [ ] **F2. Run the seed script once** against production (command in [STORE_REVIEW_ACCOUNT.md](STORE_REVIEW_ACCOUNT.md)), or ask me to walk you through it.

## G. Android signing - issue #105

- [ ] **G1. Create the upload keystore** and keep it plus passwords safe (password manager and an offline copy; losing it is painful). Steps: [ANDROID_RELEASE_SIGNING.md](ANDROID_RELEASE_SIGNING.md).
- [ ] **G2. GitHub secrets:** `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. After this, every push to `main` produces a signed `app-release.aab` as a downloadable CI artifact.

## H. Monitoring - issue #121 (all optional but recommended)

- [ ] **H1. Uptime monitor** (UptimeRobot or Better Stack, free) on `https://<api-host>/api/health` and the web app. Alerts to your email or phone.
- [ ] **H2. Sentry**: create a project, copy the DSN, Vercel env `SENTRY_DSN`.
- [ ] **H3. PostHog**: create a project, Vercel env `POSTHOG_API_KEY` (and `POSTHOG_HOST` for an EU project). Build the dashboard described in [TELEMETRY.md](TELEMETRY.md).

## I. Launch check

- [ ] **I1. GitHub secret `PROD_CRON_SECRET`** (same value as `CRON_SECRET` in Vercel), then Actions > "Production preflight" > Run workflow. It must print `READY`.
  Then I: fix anything it flags.
- [ ] **I2. Real phone test**: install the CI-built release (or a debug build from Android Studio) and walk through sign-in, profile with photo, boarding-pass scan, swipe, chat, settings, delete account. Tell me what breaks. (Android Studio setup is optional; the CI artifact can be installed by sideloading.)

## J. Play Console - issues #105, #106, #107, #109

- [ ] **J1. Create the app** in Play Console with the name (B1) and package id (B2).
- [ ] **J2. Store listing**: short (80 chars) and full description, 512x512 icon (ready), **feature graphic 1024x500**, **2-8 phone screenshots** (take from the real app; I can draft descriptions on request), category Travel and Local, contact email (C5), privacy policy URL `<web>/#/privacy`.
- [ ] **J3. Forms:** Content rating questionnaire, Target audience 18+, Ads: none, **Data safety** (I can write the answers from the code on request: email, name, phone, photo, messages, app activity, crash logs; encrypted in transit; deletion supported with URL `<web>/#/delete-account`), **App access** (reviewer login from F1: the exact text is in STORE_REVIEW_ACCOUNT.md), Government/financial/health: none.
- [ ] **J4. Upload the signed bundle** (G2) to **Internal testing**, install on two phones, check the automatic pre-launch report.
- [ ] **J5. Closed testing:** add the 12+ testers (A2), start the 14-day clock, collect feedback.
- [ ] **J6. Apply for production access**, then release with a staged rollout (10%, 50%, 100%).

---

### Quick reference: every variable and secret

| Where | Name | Step |
|---|---|---|
| GitHub variable | `OPERATOR_NAME`, `SUPPORT_EMAIL`, `GRIEVANCE_OFFICER` | D1 |
| GitHub variable | `APP_NAME`, `LEGAL_JURISDICTION`, `WEB_APP_URL` (optional) | D1 |
| GitHub variable | `LEGAL_REVIEWED` = `true` | D3 |
| GitHub secret | `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | G2 |
| GitHub secret | `PROD_CRON_SECRET` | I1 |
| Vercel (API) | `RESEND_API_KEY`, `OTP_FROM_EMAIL` | C3 |
| Vercel (API) | remove `OTP_TEST_MODE` | C4 |
| Vercel (API) | `MODERATION_EMAIL`, `MODERATION_TOKEN` | E1 |
| Vercel (API) | `REVIEW_ACCOUNT_EMAIL`, `REVIEW_ACCOUNT_CODE` | F1 |
| Vercel (API) | `SENTRY_DSN`, `POSTHOG_API_KEY`, `POSTHOG_HOST` | H2, H3 |
