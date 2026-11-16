import { del, list } from "@vercel/blob";
import { eq, inArray, or, sql } from "drizzle-orm";
import {
  blocks,
  chatMessages,
  feedback,
  getDb,
  matches,
  otpRequests,
  profiles,
  ratings,
  reports,
  rideRequests,
  users,
} from "@airport-ride-matchmaking/db";

/**
 * Permanently deletes a user and everything tied to them: profile, uploaded
 * photos, ride requests, matches (and the chats, ratings and reports hanging
 * off them), blocks, feedback and login codes. The other person in a match
 * simply loses that match; if it was active their ride request is reopened for
 * searching again.
 *
 * The neon-http driver has no multi-statement transactions, so this runs as an
 * ordered series of idempotent deletes: if it fails part way the user's token
 * is still valid and calling it again finishes the job. Returns false when the
 * user does not exist (already deleted).
 */
export async function deleteAccount(userId: string): Promise<boolean> {
  const db = getDb();

  const [user] = await db.select({ email: users.email }).from(users).where(eq(users.id, userId)).limit(1);
  if (!user) return false;

  const matchRows = await db
    .select({ id: matches.id })
    .from(matches)
    .where(or(eq(matches.userAId, userId), eq(matches.userBId, userId)));
  const matchIds = matchRows.map((m) => m.id);

  // The other person of an active match gets their ride request back.
  await db.execute(sql`
    UPDATE ride_requests SET status = 'cancelled', updated_at = now()
    WHERE status = 'matched' AND id IN (
      SELECT CASE WHEN user_a_id = ${userId} THEN ride_request_b_id ELSE ride_request_a_id END
      FROM matches
      WHERE status = 'mutual' AND (user_a_id = ${userId} OR user_b_id = ${userId})
    )
  `);

  if (matchIds.length > 0) {
    await db.delete(chatMessages).where(inArray(chatMessages.matchId, matchIds));
    await db.delete(ratings).where(inArray(ratings.matchId, matchIds));
    await db.delete(reports).where(inArray(reports.matchId, matchIds));
  }
  await db.delete(chatMessages).where(eq(chatMessages.senderId, userId));
  await db.delete(ratings).where(or(eq(ratings.raterId, userId), eq(ratings.ratedId, userId)));
  await db.delete(reports).where(or(eq(reports.reporterId, userId), eq(reports.reportedId, userId)));
  await db.delete(feedback).where(eq(feedback.userId, userId));
  await db.delete(blocks).where(or(eq(blocks.blockerId, userId), eq(blocks.blockedId, userId)));
  await db.delete(matches).where(or(eq(matches.userAId, userId), eq(matches.userBId, userId)));
  await db.delete(rideRequests).where(eq(rideRequests.userId, userId));
  await db.delete(profiles).where(eq(profiles.userId, userId));
  if (user.email) await db.delete(otpRequests).where(eq(otpRequests.email, user.email));

  await deleteProfilePhotos(userId);

  await db.delete(users).where(eq(users.id, userId));
  return true;
}

/** Best effort: a storage hiccup must not leave the account half-deleted. */
async function deleteProfilePhotos(userId: string) {
  try {
    // Uploads are stored as profile-photos/<userId>-<random suffix>.<ext>.
    const { blobs } = await list({ prefix: `profile-photos/${userId}` });
    if (blobs.length > 0) await del(blobs.map((b) => b.url));
  } catch (error) {
    console.error("Failed to delete profile photos for a deleted account", error);
  }
}
