# Moderation policy and process

Answers the app-store question "how do you handle objectionable content and
abusive users?" (Apple guideline 1.2, Google Play user-generated-content
policy). Keep this in step with the code.

## What users can do in the app

- **Report** a person from a chat (reason, optional details). Stored in `reports`.
- **Block** a person: they disappear from matching and chat both ways.
- **Unmatch** and leave a match at any time.
- **Contact support** from Settings (address set by `SUPPORT_EMAIL`).
- The terms of service state the behaviour rules and that accounts that break
  them are removed.

## What the owner does

1. **Daily digest.** At about 09:00 India time a Vercel cron job calls
   `/api/internal/moderation/digest`. If anyone filed a report in the last 24
   hours it emails the list to `MODERATION_EMAIL` (reason, both people, how many
   reports that person has in total, any details). No new reports, no email.
2. **Review within 48 hours.** Read the report. For chat content, look at the
   match's messages in the database.
3. **Decide:**
   - *No action:* mark the report reviewed (action `dismiss`).
   - *Remove the person:* delete their account (action `remove_user`). This also
     deletes everything about them, including reports filed against them.
   - *Urgent safety concern* (threats, someone in danger): act the same day and
     contact local authorities if needed.
4. **Support email.** Answer within 2 working days.

Moderator actions are plain API calls protected by `MODERATION_TOKEN`:

```bash
curl -X POST https://<api-host>/api/internal/moderation/action \
  -H "Authorization: Bearer $MODERATION_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"reportId": "<report id from the digest>", "action": "dismiss"}'
```

`action` is `dismiss` or `remove_user`.

## Known limits (decisions for the owner)

- **Removing an account erases the evidence.** `remove_user` deletes the
  reports about that person. If you want a record of why someone was removed
  (or to stop the same email signing up again), we need a small "banned emails"
  list kept after deletion. Not built yet.
- A reported person can also delete their own account, which deletes the
  reports against them. Same fix as above if you want reports kept.
- There is no automatic filtering of abusive chat messages.
- Only one reviewer (the owner). Name a backup if you travel.

## Setup checklist

Set in Vercel (API project) environment variables:

| Variable | Purpose |
|---|---|
| `MODERATION_EMAIL` | Where the daily digest goes |
| `MODERATION_TOKEN` | 24+ random characters; enables moderator actions |
| `CRON_SECRET` | Already used by cron jobs; protects the digest job |
| `RESEND_API_KEY`, `OTP_FROM_EMAIL` | Email sending (verified domain needed to reach anyone but the account owner) |

See `docs/OWNER_INPUTS.md` for the ordered list.
