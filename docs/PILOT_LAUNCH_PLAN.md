# Web pilot: launch, marketing and the agent-run company

Decision: start the market pilot now with the **web app**; mobile apps follow.
The store work stays on the shelf (see [OWNER_INPUTS.md](OWNER_INPUTS.md)); only
the web-relevant steps below block the pilot. Written 2026-11-16. Prices are
from third-party comparison pages and move: confirm at checkout.

## 1. Domain

**Chosen: `airpool.online`** (owner decision 2026-11-16; `airpool.in` was taken). Web app on `airpool.online`, API on `api.airpool.online`, sending address like `login@airpool.online`. Android package id `online.airpool.app`.

`.online` costs about $1 in year one but renews at roughly $16-36 a year depending on the registrar (third-party trackers; confirm at checkout), and it looks less established than `.in` or `.com`. Fine for the pilot: set a renewal reminder and plan to move to a `.in` or `.com` if it works. Use the permanent domain for email and links from the start of any move.

**What to buy:** one `.in` domain to start (cheap, credible for an India pilot),
add the `.com` later only if the brand takes off. Registrar notes:

| Registrar | Why | Caveat |
|---|---|---|
| Porkbun / Cloudflare Registrar | Honest renewals (about $10/yr for `.com`, `.app` about $14) | I could not confirm either sells `.in` |
| GoDaddy | `.in` as low as about $1 in year one with a promo code | Renews about $13/yr: put a reminder |
| Hostinger / BigRock | `.in` about $5.70-5.94 first year, about $9.33-9.99 renewal | Check the ICANN/GST add-ons at checkout |
| Namecheap | `.in` about $8 first year, about $9.6 renewal | |

Budget: roughly Rs 500-1,100 for the first year of a `.in`.

**Name shortlist.** A DNS lookup (not a registry check) found no records for
these `.in` names, so they are *probably* free: confirm at the registrar and run
a quick trademark search (ipindiaservices.gov.in) before printing anything.

| Name | Take |
|---|---|
| `airpool.in` | Turned out to be taken (my DNS check was wrong). `airpool.online` was chosen instead |
| `landandgo.in` | Friendly, memorable |
| `sharecab.in` / `splitcab.in` | Descriptive, good for search |
| `landedride.in`, `touchdownride.in`, `tarmacpool.in` | Brandable alternatives |
| `blrpool.in`, `blrcab.in` | Avoid: ties the brand to one airport |

Already taken: `airpool.in`, `airpool.com`, `airpool.app`, `airportpool.in`, `cabmate.in`, `ridebuddy.in`, `sharemycab.in`.
The chosen name `airpool.online` makes the Android package id `online.airpool.app` (OWNER_INPUTS B2).

## 2. What blocks a web pilot (do these first)

1. **Domain + Vercel custom domain** for the web app and API (issue #46).
2. **Real email codes** (OWNER_INPUTS section C): Resend domain, then switch off `OTP_TEST_MODE`. Without this nobody outside testing can sign in.
3. **Legal pages filled in** (OWNER_INPUTS D): operator name, support email, grievance officer, reviewed text.
4. **In-app alerts for matches and messages** (done; no email, since free email sends are kept for sign-in codes). Riders are alerted by a banner, unread counts and the browser tab title while the app is open. A rider who has closed the tab still will not hear until they return, so tell pilot users to keep the tab open or check back; revisit browser push notifications later if this hurts.
5. **Phone-friendly web**: install-to-home-screen support and a check of the boarding-pass scanner in mobile Chrome and Safari.
6. **Monitoring** (OWNER_INPUTS H): uptime monitor, Sentry, PostHog, so the pilot produces data.

## 3. Pilot design

**The real risk is density, not code.** A match needs someone else, at the same
terminal, in the same 90-minute window, going the same way. So concentrate:

- **One airport, two terminals, a few corridors.** Bengaluru only. Push the long, expensive trips first (Whitefield, Marathahalli, Indiranagar, Koramangala, HSR, Electronic City).
- **Pre-register, then land.** Waitlist with flight date/terminal; invite only when enough people share a day/window. Say "2-3 matches per day" is the goal, not "everyone matches instantly".
- **Seed with real groups**, not ads: people who fly in often (corporate travellers, student groups returning after holidays, a few friendly companies' travel desks).
- **Make "no match yet" survivable**: alert in the app when someone appears, and honest copy about waiting.

**Success criteria (suggested, set your own before launch):**

| Measure | Pilot target |
|---|---|
| Sign-ups with a completed ride request | 150-300 |
| Requests that find a mutual match within 24 h | 30%+ |
| Matches that actually share a cab (ask by email) | 50%+ of matches |
| Users who say they would use it again | 60%+ |
| Serious safety reports | 0 |

Decide at week 6: keep going, narrow further, or stop. If match rate stays low
with healthy sign-ups, the fix is density (fewer windows, more promotion), not features.

**Timeline:** week 0 domain, email, legal, in-app alerts. Week 1 friends and
family (20-50 people, watch real flights). Weeks 2-4 invite communities (below).
Weeks 5-6 measure and decide.

## 4. Marketing (cheap, India, no ad spend at first)

| Channel | Play |
|---|---|
| Communities | Reddit (r/bangalore, r/india), Facebook/WhatsApp groups for Bengaluru commuters, frequent flyers, alumni and IT-company groups. Be a helpful member first; read each group's rules, no spam |
| Search pages | Plain pages: "share a cab from Bangalore airport to Whitefield / Indiranagar / Koramangala ...". Slow to rank, cheap, durable |
| Content | A cab cost split calculator, a "safe airport pickup" checklist, short founder story. Only quote savings you have measured |
| Partnerships | Coworking spaces, PG/hostel owners, college student councils, company travel desks, airline-crew and frequent-flyer groups |
| Referral | "Invite someone on your flight window" link. Referrals work here because each invite directly raises your own match chance |
| Paid (later) | Small tests on Instagram/Google only after organic conversion is known |

Messaging: save money and make the long ride home less lonely; you book and pay
your own cab; meet at the official pickup zone; both of you chose to match.
Avoid claims about being a taxi service, safety guarantees, or specific savings
until measured. Do not leaflet or put signs at the airport without the
operator's permission.

**Compliance note (confirm with a lawyer):** the app only introduces riders and
does not handle fares, vehicles or payments, which keeps it closer to a social
introduction service than a taxi aggregator. Rules for ride-sharing and
aggregators differ by state, so get one review before marketing at scale.
Also: the DPDP Act duties are in the privacy policy; keep a grievance contact live.

**Running cost:** domain about Rs 500-1,100/yr; hosting, database and email are on free tiers today (verify limits as users grow; Resend's free tier caps daily/monthly sends).

## 5. A one-person company run by agents

**Can agents do it?** Partly, and well for the paper-heavy 70%. They can draft,
research, monitor, summarise and prepare. They cannot be legal persons, open
bank/payment accounts, pass identity checks, or be trusted to post, email or
spend unsupervised. So: **agents prepare, you approve and send.** Also check each platform's
rules: automated posting and fake personas on Reddit, Instagram or WhatsApp
break their terms and get accounts banned. Agents should never pretend to be a
real customer or an invented employee.

**Roles (each a Claude Code subagent with its own instructions):**

| "Department" | Does | Hard limit |
|---|---|---|
| Chief of staff | Reads the dashboard and inbox, builds your daily to-do, delegates | Never acts externally |
| Growth | Channel research, post drafts, community replies, weekly experiment plan | Drafts only; you post |
| Content/SEO | Landing pages, blog posts, FAQ | You review before publishing |
| Support | Drafts replies to support email from FAQ and policy | You send; escalates safety cases |
| Trust and safety | Triage of the daily report digest, suggests actions | You decide removals |
| Analytics | Weekly numbers: funnel, match rate, retention, from PostHog | Read-only |
| Engineering | This session: issues, code, tests, PRs | Merges follow the repo rules |
| Compliance | Keeps privacy policy and Data safety answers in step with the code | Not legal advice; lawyer signs off |

**How to set it up on this machine:**

1. **Handbook**: `docs/company/HANDBOOK.md` with mission, brand voice, product facts, what agents may do alone, what needs approval, and escalation (safety, legal, money, press). Every agent reads it first.
2. **Agent files**: `.claude/agents/<role>.md` (name, description, allowed tools, instructions) for the roles above. They can be invoked from any session.
3. **Approval queue**: agents write drafts to `ops/inbox/` (e.g. `ops/inbox/2026-12-01-reddit-post.md`); you move approved ones to `ops/approved/` and send/post them yourself. Nothing leaves the machine automatically.
4. **Schedules**: recurring tasks (Claude Code's scheduled tasks or cloud routines) such as a daily 9am "state of the company" brief, a weekly growth plan, a daily moderation triage. A local schedule only runs while this PC is awake and Claude is open; cloud routines or a small always-on machine fix that.
5. **Guardrails**: read-only credentials for analytics, no payment access, no bulk-send tools, secrets never in files, each agent limited to the tools it needs.
6. **Cost control**: use cheaper models for routine drafting and keep the strongest model for planning and code.

I can scaffold steps 1-3 (handbook, agent files, approval queue) and one scheduled
daily brief as the next piece of work.

## 6. Order of work

1. Pick and buy the domain, connect it to Vercel (you: buy; me: connect).
2. Real email, legal values, monitoring (OWNER_INPUTS C, D, H).
3. Me: in-app match and message alerts, web install polish, then agent scaffold.
4. Invite 20-50 people you know; fix what breaks.
5. Open to communities in weeks 2-4; weekly metrics review; week-6 decision.
