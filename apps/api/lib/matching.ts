import { and, eq, or, sql, type InferSelectModel } from "drizzle-orm";
import { getDb, matches } from "@airport-ride-matchmaking/db";

type Match = InferSelectModel<typeof matches>;

/** Finds the matches row for an unordered ride-request pair, regardless of which side was stored as A/B. */
export async function findExistingMatch(
  rideRequestIdA: string,
  rideRequestIdB: string,
): Promise<Match | undefined> {
  const db = getDb();
  const [row] = await db
    .select()
    .from(matches)
    .where(
      or(
        and(
          eq(matches.rideRequestAId, rideRequestIdA),
          eq(matches.rideRequestBId, rideRequestIdB),
        ),
        and(
          eq(matches.rideRequestAId, rideRequestIdB),
          eq(matches.rideRequestBId, rideRequestIdA),
        ),
      ),
    )
    .limit(1);
  return row;
}

/**
 * A ride request is "matched" only while a mutual match points at it. If the
 * match has ended some other way (expired, an older sweep, a partial run), the
 * request would otherwise stay "matched" forever and the rider could never
 * start a new one. This frees every such orphan, optionally for one rider.
 * Returns the ids it released.
 */
export async function releaseOrphanedMatchedRequests(userId?: string): Promise<string[]> {
  const result = await getDb().execute(sql`
    UPDATE ride_requests rr
    SET status = 'expired', updated_at = now()
    WHERE rr.status = 'matched'
      ${userId ? sql`AND rr.user_id = ${userId}` : sql``}
      AND NOT EXISTS (
        SELECT 1 FROM matches m
        WHERE m.status = 'mutual'
          AND (m.ride_request_a_id = rr.id OR m.ride_request_b_id = rr.id)
      )
    RETURNING rr.id
  `);
  return result.rows.map((row) => row.id as string);
}
