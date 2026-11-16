# Store review account

Google Play and the App Store reviewers have to log in, but login is a code sent by email and they cannot read your inbox. This sets up one dedicated account that logs in with a fixed code. It affects no other account.

## How it works

- Two environment variables on the **production API** (Vercel project `airport-ride-matchmaking-api`, Production environment):
  - `REVIEW_ACCOUNT_EMAIL`: the reviewer's email address, e.g. `reviewer@yourdomain.com`
  - `REVIEW_ACCOUNT_CODE`: exactly **6 digits** (the app and API accept nothing else), not `000000`. Pick random digits, not `123456`.
- When someone requests a code for that email, no email is sent and the stored code is the fixed one. Everything else is the normal flow, so the existing limits still apply: 5 wrong attempts invalidate a code, and 3 codes per hour per email. Guessing the code is impractical.
- Unset either variable (and redeploy) to switch the account off. Do this after the store review period if you prefer.
- Ignored while `OTP_TEST_MODE=true`.

## Setup (once, you)

1. In Vercel, add the two variables for Production and redeploy the API.
2. Seed the account so the reviewer sees a complete profile and can search for a match (needs `DATABASE_URL`; run from `apps/api` with the production variables available, e.g. after `vercel env pull .env.production.local --environment production`):

   ```bash
   cd apps/api
   node --env-file=.env.production.local scripts/seed-review-account.mjs
   ```

   It creates the user and a profile named "App Reviewer" with a profile photo (the app icon by default; set `REVIEW_ACCOUNT_PHOTO_URL` to use another image).
3. Test it: open the live app, enter the review email and any phone number, and type the fixed code.

## What to give the reviewers

- **Play Console, App content, App access**: choose "All or some functionality is restricted" and add: email `REVIEW_ACCOUNT_EMAIL`, "Enter any phone number on the first screen, then use the 6-digit code `REVIEW_ACCOUNT_CODE` on the verification screen."
- **App Store Connect, App Review Information** (later, for iOS): the same instructions in the sign-in information and notes.
- Tell them a match needs a second traveler: for a complete walkthrough, create a second throwaway account yourself and give both ride requests the same destination and time, or explain that matches appear when two travelers have overlapping trips.
