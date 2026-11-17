#!/usr/bin/env node
/**
 * End-to-end checks of the real API flows against a running server and its
 * database, using throwaway users that are deleted afterwards.
 *
 *   pnpm --filter @airport-ride-matchmaking/api dev     # in one terminal
 *   pnpm --filter @airport-ride-matchmaking/api test:integration
 *
 * Needs the server to run with OTP_TEST_MODE=true (login code 000000) and, for
 * the expiry checks, DATABASE_URL and CRON_SECRET in apps/api/.env.local (or the
 * environment). It writes real rows, so it refuses to run against anything but
 * localhost unless ALLOW_REMOTE=1. See docs/TESTING.md.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { neon } from "@neondatabase/serverless";

const here = path.dirname(fileURLToPath(import.meta.url));
const envFile = path.join(here, "..", ".env.local");
if (fs.existsSync(envFile)) {
  for (const line of fs.readFileSync(envFile, "utf8").split(/\r?\n/)) {
    const m = line.match(/^([A-Z0-9_]+)=["']?([^"'\r\n]*)/);
    if (m && process.env[m[1]] === undefined) process.env[m[1]] = m[2];
  }
}

const BASE = process.env.API_URL ?? "http://localhost:3000";
const host = new URL(BASE).hostname;
if (!["localhost", "127.0.0.1", "[::1]"].includes(host) && process.env.ALLOW_REMOTE !== "1") {
  console.error(`Refusing to run against ${host}: this writes real rows. Set ALLOW_REMOTE=1 to override.`);
  process.exit(2);
}
const sql = process.env.DATABASE_URL ? neon(process.env.DATABASE_URL) : null;

async function raw(method, route, token, body) {
  const res = await fetch(`${BASE}/api${route}`, {
    method,
    headers: { "content-type": "application/json", ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = text;
  }
  return { status: res.status, body: json };
}
async function call(method, route, token, body) {
  const r = await raw(method, route, token, body);
  if (r.status >= 400) throw new Error(`${method} ${route} -> ${r.status} ${JSON.stringify(r.body)}`);
  return r.body;
}

const stamp = Date.now();
let counter = 0;
const created = [];

/** A signed-in rider with a complete profile. */
async function rider(name, { gender = "other", genderPreference = "any" } = {}) {
  const email = `it-${stamp}-${++counter}@example.com`;
  const sent = await call("POST", "/auth/otp/send", null, { email });
  const v = await call("POST", "/auth/otp/verify", null, { email, requestId: sent.requestId, code: "000000" });
  const phoneNumber = String(6000000000 + Math.floor(Math.random() * 3999999999));
  await call("PUT", "/profile/me", v.token, {
    displayName: name,
    gender,
    genderPreference,
    phoneNumber,
    profilePhotoUrl: "https://example.com/p.jpg",
  });
  const user = { ...v, name, phoneNumber, email };
  created.push(user);
  return user;
}

const inHours = (h) => new Date(Date.now() + h * 3600e3).toISOString();
const trip = (u, { terminal = "T1", hours = 36, area = ["Indiranagar", 12.9719, 77.6412] } = {}) =>
  call("POST", "/ride-requests", u.token, {
    airportCode: "BLR",
    terminal,
    flightArrivalAt: inHours(hours),
    destinationAddress: area[0],
    destinationLat: area[1],
    destinationLng: area[2],
    destinationLocalityLabel: area[0],
    trolleyBags: 1,
  });
const candidates = async (u, ride) =>
  (await call("GET", `/ride-requests/${ride.id}/candidates`, u.token)).candidates.map((c) => c.user_id);
const like = (u, mine, theirs) =>
  call("POST", "/matches", u.token, { rideRequestId: mine.id, candidateRideRequestId: theirs.id, action: "like" });

let failures = 0;
function check(label, condition, detail = "") {
  if (!condition) failures += 1;
  console.log(`${condition ? "  ok " : " FAIL"} ${label}${condition ? "" : ` ${detail}`}`);
}
async function scenario(title, fn) {
  console.log(`\n${title}`);
  try {
    await fn();
  } catch (e) {
    failures += 1;
    console.log(` FAIL ${e.message}`);
  }
}

await scenario("Profiles", async () => {
  const a = await rider("Asha");
  const other = await rider("Ravi");
  const dup = await raw("PUT", "/profile/me", other.token, {
    displayName: "Ravi",
    gender: "other",
    genderPreference: "any",
    phoneNumber: a.phoneNumber,
  });
  check("the same phone number cannot be used by two accounts", dup.status === 409, String(dup.status));
});

await scenario("Ride requests and candidates", async () => {
  const a = await rider("Asha");
  const same = await rider("Same terminal");
  const otherTerminal = await rider("Other terminal");
  const late = await rider("Lands much later");
  const blocked = await rider("Blocked");
  const female = await rider("Wants women only", { gender: "female", genderPreference: "same_gender_only" });

  check("a terminal is required", (await raw("POST", "/ride-requests", a.token, { airportCode: "BLR", flightArrivalAt: inHours(36), destinationAddress: "x", destinationLat: 12.9, destinationLng: 77.6, destinationLocalityLabel: "x", trolleyBags: 1 })).status === 400);
  check("a terminal the airport lacks is refused", (await raw("POST", "/ride-requests", a.token, { airportCode: "BLR", terminal: "T9", flightArrivalAt: inHours(36), destinationAddress: "x", destinationLat: 12.9, destinationLng: 77.6, destinationLocalityLabel: "x", trolleyBags: 1 })).status === 400);
  check("the number of trolley bags is required", (await raw("POST", "/ride-requests", a.token, { airportCode: "BLR", terminal: "T1", flightArrivalAt: inHours(36), destinationAddress: "x", destinationLat: 12.9, destinationLng: 77.6, destinationLocalityLabel: "x" })).status === 400);

  const ra = await trip(a);
  await trip(same, { hours: 36.5 });
  await trip(otherTerminal, { terminal: "T2" });
  await trip(late, { hours: 40 });
  await trip(blocked);
  await trip(female);
  await call("POST", "/blocks", a.token, { blockedUserId: blocked.userId });

  const ids = await candidates(a, ra);
  check("someone at the same terminal around the same time is a candidate", ids.includes(same.userId));
  check("a different terminal is never a candidate", !ids.includes(otherTerminal.userId));
  check("arrival times that do not overlap are never candidates", !ids.includes(late.userId));
  check("blocked people are never candidates", !ids.includes(blocked.userId));
  check("same-gender-only riders are not shown to people of another gender", !ids.includes(female.userId));
  check("you are never your own candidate", !ids.includes(a.userId));
  const asSeen = (await call("GET", `/ride-requests/${ra.id}/candidates`, a.token)).candidates.find((c) => c.user_id === same.userId);
  check("a candidate shows how many trolley bags they bring", asSeen?.trolley_bags === 1, JSON.stringify(asSeen?.trolley_bags));
});

await scenario("Like, mutual match, chat and unread alerts", async () => {
  const a = await rider("Asha");
  const b = await rider("Ravi");
  const ra = await trip(a);
  const rb = await trip(b);

  const first = await like(a, ra, rb);
  check("the first like waits for the other person", first.status === "proposed_by_a");
  const summaryB = await call("GET", "/notifications/summary", b.token);
  check("the other person is told someone liked their trip", summaryB.incomingLikes?.count === 1);

  const mutual = await like(b, rb, ra);
  check("liking back makes it mutual", mutual.status === "mutual");
  check("both trips become matched", (await call("GET", "/ride-requests/mine", a.token)).status === "matched");
  check("a matched rider cannot like again", (await raw("POST", "/matches", a.token, { rideRequestId: ra.id, candidateRideRequestId: rb.id, action: "like" })).status === 400);

  await call("POST", `/matches/${mutual.id}/messages`, a.token, { body: "Hi!" });
  const unread = await call("GET", "/notifications/summary", b.token);
  check("the message shows as unread for the other person", unread.unreadMessages?.[0]?.count === 1);
  check("the new match shows as a mutual match", unread.mutualMatches?.some((m) => m.id === mutual.id));
  await call("GET", `/matches/${mutual.id}/messages`, b.token);
  const read = await call("GET", "/notifications/summary", b.token);
  check("reading the chat clears the unread alert", (read.unreadMessages ?? []).length === 0);
  check("a stranger cannot read the chat", (await raw("GET", `/matches/${mutual.id}/messages`, (await rider("Stranger")).token)).status === 404);
});

await scenario("Unmatch tells the other person and never re-queues them", async () => {
  const a = await rider("Asha");
  const b = await rider("Ravi");
  const ra = await trip(a);
  const rb = await trip(b);
  await like(a, ra, rb);
  const match = await like(b, rb, ra);

  const done = await call("POST", `/matches/${match.id}/unmatch`, a.token);
  check("the person who unmatched is back in the search", done.reopenedRideRequestId === ra.id);
  const summary = await call("GET", "/notifications/summary", b.token);
  check("the other person gets a match-ended alert", summary.endedMatches?.some((m) => m.id === match.id));
  check("the other person is not put back in the queue", (await call("GET", "/ride-requests/mine", b.token)).status !== "open");
  check("an ended chat refuses new messages", (await raw("POST", `/matches/${match.id}/messages`, b.token, { body: "hello?" })).status === 403);
  check("the chat reports that it ended", (await call("GET", `/matches/${match.id}/messages`, b.token)).matchStatus === "unmatched");
  const resumed = await call("POST", "/ride-requests/resume", b.token);
  check("they can choose to search again", resumed.status === "open" && resumed.id === rb.id);
  check("an unmatched pair can appear to each other again", (await candidates(b, rb)).includes(a.userId) && (await candidates(a, ra)).includes(b.userId));
  const again = await like(b, rb, ra);
  check("liking an unmatched person restarts the match", again.status === "proposed_by_a" && again.userAId === b.userId);
  const rematch = await like(a, ra, rb);
  check("and they can match again", rematch.status === "mutual");
});

await scenario("Passing on someone hides them", async () => {
  const a = await rider("Asha");
  const c = await rider("Passed on");
  const ra = await trip(a);
  const rc = await trip(c);
  check("they show up first", (await candidates(a, ra)).includes(c.userId));
  await call("POST", "/matches", a.token, { rideRequestId: ra.id, candidateRideRequestId: rc.id, action: "pass" });
  check("after a pass they are hidden", !(await candidates(a, ra)).includes(c.userId));
  check("and cannot be liked later", (await raw("POST", "/matches", a.token, { rideRequestId: ra.id, candidateRideRequestId: rc.id, action: "like" })).status === 409);
});

await scenario("Blocking someone you are matched with ends the match", async () => {
  const a = await rider("Asha");
  const b = await rider("Ravi");
  const ra = await trip(a);
  const rb = await trip(b);
  await like(a, ra, rb);
  const match = await like(b, rb, ra);
  const blocked = await call("POST", "/blocks", b.token, { blockedUserId: a.userId });
  check("the match ended", blocked.endedMatchId === match.id);
  check("the blocked person cannot message", (await raw("POST", `/matches/${match.id}/messages`, a.token, { body: "?" })).status === 403);
  check("blocking again is harmless", (await raw("POST", "/blocks", b.token, { blockedUserId: a.userId })).status === 200);
});

await scenario("Resuming a trip", async () => {
  const a = await rider("Asha");
  check("with no trip there is nothing to resume", (await raw("POST", "/ride-requests/resume", a.token)).status === 404);
  const ra = await trip(a);
  check("resuming an open trip is a no-op", (await call("POST", "/ride-requests/resume", a.token)).id === ra.id);
  if (sql) {
    await sql`update ride_requests set status = 'cancelled', arrival_window_end = now() - interval '1 hour' where id = ${ra.id}`;
    check("a trip whose window has passed cannot be resumed", (await raw("POST", "/ride-requests/resume", a.token)).status === 410);
  }
});

if (sql && process.env.CRON_SECRET) {
  await scenario("Expiry sweep", async () => {
    const a = await rider("Asha");
    const b = await rider("Ravi");
    const ra = await trip(a);
    const rb = await trip(b);
    await like(a, ra, rb);
    const match = await like(b, rb, ra);
    const sweep = () => raw("POST", "/internal/ride-requests/sweep", process.env.CRON_SECRET);

    await sweep();
    check("a live match is left alone", (await call("GET", "/ride-requests/mine", a.token)).status === "matched");

    await sql`update matches set status = 'expired' where id = ${match.id}`;
    await sweep();
    const released = await sql`select status from ride_requests where id in (${ra.id}, ${rb.id})`;
    check("trips stuck as matched after the match expired are released", released.every((r) => r.status !== "matched"));

    const c = await rider("Old trip");
    const rc = await trip(c);
    await sql`update ride_requests set arrival_window_end = now() - interval '5 hours' where id = ${rc.id}`;
    await sweep();
    check("open trips expire 4 hours after their window ends", (await sql`select status from ride_requests where id = ${rc.id}`)[0].status === "expired");
  });
}

await scenario("Deleting an account removes it", async () => {
  const a = await rider("Asha");
  await trip(a);
  await call("DELETE", "/account", a.token);
  created.splice(created.indexOf(a), 1);
  check("the account can no longer be used", [401, 404].includes((await raw("GET", "/profile/me", a.token)).status));
});

for (const u of created) await raw("DELETE", "/account", u.token).catch(() => {});
console.log(failures === 0 ? "\nAll integration checks passed." : `\n${failures} check(s) failed.`);
process.exit(failures === 0 ? 0 : 1);
