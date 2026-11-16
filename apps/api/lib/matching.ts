import { and, eq, gt, inArray, or, sql, type InferSelectModel } from "drizzle-orm";
import { blocks, getDb, matches, rideRequests } from "@airport-ride-matchmaking/db";

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

/** True if either person has blocked the other. */
export async function usersBlocked(a: string, b: string): Promise<boolean> {
  const [row] = await getDb()
    .select({ id: blocks.id })
    .from(blocks)
    .where(
      or(
        and(eq(blocks.blockerId, a), eq(blocks.blockedId, b)),
        and(eq(blocks.blockerId, b), eq(blocks.blockedId, a)),
      ),
    )
    .limit(1);
  return !!row;
}

/**
 * Ends an active (mutual) match on behalf of `byUserId` (an unmatch, or a block).
 * The chat becomes read-only. The person who ended it goes straight back into the
 * search (their trip reopens if their arrival window has not passed). The other
 * person is NOT put back automatically, since we do not know they are still
 * around: their trip is cancelled, and they are offered a choice to resume it
 * (see POST /api/ride-requests/resume).
 */
export async function endMatch(match: Match, byUserId: string) {
  const db = getDb();
  const [updated] = await db
    .update(matches)
    .set({ status: "unmatched", updatedAt: new Date() })
    .where(eq(matches.id, match.id))
    .returning();

  const bothIds = [match.rideRequestAId, match.rideRequestBId];
  const [reopened] = await db
    .update(rideRequests)
    .set({ status: "open", updatedAt: new Date() })
    .where(
      and(
        inArray(rideRequests.id, bothIds),
        eq(rideRequests.userId, byUserId),
        eq(rideRequests.status, "matched"),
        gt(rideRequests.arrivalWindowEnd, new Date()),
      ),
    )
    .returning({ id: rideRequests.id });
  await db
    .update(rideRequests)
    .set({ status: "cancelled", updatedAt: new Date() })
    .where(and(inArray(rideRequests.id, bothIds), eq(rideRequests.status, "matched")));

  return { updated, reopenedRideRequestId: reopened?.id ?? null };
}
