import { NextResponse } from "next/server";
import { and, eq, inArray, lt, sql } from "drizzle-orm";
import { getDb, rideRequests } from "@airport-ride-matchmaking/db";
import { jsonError } from "@/lib/api-response";
import { hasBearer } from "@/lib/moderation/auth";
import { releaseOrphanedMatchedRequests } from "@/lib/matching";

const EXPIRY_GRACE_HOURS = 4;
// Generous on purpose -- people are often still coordinating logistics
// (where to meet, splitting a cab) well after the ride window itself ends.
const MATCH_EXPIRY_GRACE_HOURS = 24;

/**
 * Vercel Cron calls this on a schedule with an HTTP GET (POST is kept for manual
 * runs). Protected via the CRON_SECRET bearer token.
 */
async function handle(request: Request) {
  if (!hasBearer(request, process.env.CRON_SECRET)) return jsonError("Unauthorized", 401);

  const cutoff = new Date(Date.now() - EXPIRY_GRACE_HOURS * 60 * 60 * 1000);
  const db = getDb();
  const expired = await db
    .update(rideRequests)
    .set({ status: "expired", updatedAt: new Date() })
    .where(and(eq(rideRequests.status, "open"), lt(rideRequests.arrivalWindowEnd, cutoff)))
    .returning({ id: rideRequests.id });

  // Freeze chat on mutual matches once both sides' ride window has passed --
  // the mobile chat screen already treats any non-"mutual" status as read-only.
  const matchCutoff = new Date(Date.now() - MATCH_EXPIRY_GRACE_HOURS * 60 * 60 * 1000);
  const expiredMatches = await db.execute(sql`
    UPDATE matches m
    SET status = 'expired', updated_at = now()
    FROM ride_requests ra, ride_requests rb
    WHERE m.ride_request_a_id = ra.id
      AND m.ride_request_b_id = rb.id
      AND m.status = 'mutual'
      AND GREATEST(ra.arrival_window_end, rb.arrival_window_end) < ${matchCutoff.toISOString()}
    RETURNING m.id, m.ride_request_a_id, m.ride_request_b_id
  `);

  // The sweep above only ever expires "open" ride requests -- once matched,
  // a ride request would otherwise stay stuck at "matched" forever with no
  // mutual match left to point to, leaving the rider with no way back into
  // the queue. Free up both sides whenever their match just expired.
  const expiredRideRequestIds = expiredMatches.rows.flatMap((row) => [
    row.ride_request_a_id as string,
    row.ride_request_b_id as string,
  ]);
  if (expiredRideRequestIds.length > 0) {
    await db
      .update(rideRequests)
      .set({ status: "expired", updatedAt: new Date() })
      .where(
        and(inArray(rideRequests.id, expiredRideRequestIds), eq(rideRequests.status, "matched")),
      );
  }

  // Catch-all: any "matched" request with no mutual match left, whatever the
  // reason (see releaseOrphanedMatchedRequests).
  const releasedOrphans = await releaseOrphanedMatchedRequests();

  return NextResponse.json({
    expiredCount: expired.length,
    expiredMatchCount: expiredMatches.rows.length,
    releasedOrphanCount: releasedOrphans.length,
  });
}

export const GET = handle;
export const POST = handle;
