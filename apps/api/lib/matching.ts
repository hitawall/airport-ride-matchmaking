import { and, eq, or, type InferSelectModel } from "drizzle-orm";
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
