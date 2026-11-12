import { eq } from "drizzle-orm";
import { getDb, matches } from "@airport-ride-matchmaking/db";

/** Returns the match row only if userId is one of its two participants. */
export async function getMatchForParticipant(matchId: string, userId: string) {
  const db = getDb();
  const [row] = await db.select().from(matches).where(eq(matches.id, matchId)).limit(1);
  if (!row) return null;
  if (row.userAId !== userId && row.userBId !== userId) return null;
  return row;
}
