import { NextResponse } from "next/server";
import { sql } from "drizzle-orm";
import { getDb } from "@airport-ride-matchmaking/db";
import { requireUserId } from "@/lib/api-response";

/** A mutual match is "new" for this long; older ones never raise an alert. */
const NEW_MATCH_HOURS = 72;

/**
 * Everything the app needs to tell a rider something happened while they were
 * elsewhere: unread messages, people who liked their trip, and new mutual
 * matches. Cheap and read-only; the app polls it every few seconds.
 */
export async function GET(request: Request) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;
  const db = getDb();

  const [unread, likes, mutual, ended] = await Promise.all([
    db.execute(sql`
      SELECT cm.match_id, COUNT(*)::int AS count, p.display_name AS sender_name
      FROM chat_messages cm
      JOIN matches m ON m.id = cm.match_id AND m.status = 'mutual'
      JOIN profiles p ON p.user_id = cm.sender_id
      WHERE (m.user_a_id = ${userId} OR m.user_b_id = ${userId})
        AND cm.sender_id <> ${userId}
        AND cm.read_at IS NULL
      GROUP BY cm.match_id, p.display_name
    `),
    // Someone liked my open trip and I have not answered yet. Whoever likes
    // first is stored as side A, but both directions are handled.
    db.execute(sql`
      SELECT mine.id AS ride_request_id, COUNT(*)::int AS count
      FROM matches m
      JOIN ride_requests mine
        ON mine.user_id = ${userId} AND mine.status = 'open'
       AND mine.id IN (m.ride_request_a_id, m.ride_request_b_id)
      JOIN ride_requests theirs
        ON theirs.id = CASE WHEN mine.id = m.ride_request_a_id THEN m.ride_request_b_id ELSE m.ride_request_a_id END
       AND theirs.status = 'open'
      WHERE ((m.status = 'proposed_by_a' AND m.user_b_id = ${userId})
          OR (m.status = 'proposed_by_b' AND m.user_a_id = ${userId}))
        AND NOT EXISTS (
          SELECT 1 FROM blocks b
          WHERE (b.blocker_id = ${userId} AND b.blocked_id = theirs.user_id)
             OR (b.blocker_id = theirs.user_id AND b.blocked_id = ${userId})
        )
      GROUP BY mine.id
    `),
    db.execute(sql`
      SELECT m.id, p.display_name AS counterpart_name
      FROM matches m
      JOIN profiles p ON p.user_id = CASE WHEN m.user_a_id = ${userId} THEN m.user_b_id ELSE m.user_a_id END
      WHERE m.status = 'mutual'
        AND (m.user_a_id = ${userId} OR m.user_b_id = ${userId})
        AND m.updated_at > now() - make_interval(hours => ${NEW_MATCH_HOURS})
      ORDER BY m.updated_at DESC
    `),
    // Matches that ended recently (unmatched by either person, or by a block).
    // The app only alerts for ones this device has not seen end.
    db.execute(sql`
      SELECT m.id, p.display_name AS counterpart_name
      FROM matches m
      JOIN profiles p ON p.user_id = CASE WHEN m.user_a_id = ${userId} THEN m.user_b_id ELSE m.user_a_id END
      WHERE m.status = 'unmatched'
        AND (m.user_a_id = ${userId} OR m.user_b_id = ${userId})
        AND m.updated_at > now() - make_interval(hours => ${NEW_MATCH_HOURS})
      ORDER BY m.updated_at DESC
    `),
  ]);

  const likeRow = likes.rows[0];
  return NextResponse.json({
    unreadMessages: unread.rows.map((r) => ({
      matchId: r.match_id as string,
      count: r.count as number,
      senderName: r.sender_name as string,
    })),
    incomingLikes: likeRow
      ? { rideRequestId: likeRow.ride_request_id as string, count: likeRow.count as number }
      : null,
    mutualMatches: mutual.rows.map((r) => ({
      id: r.id as string,
      counterpartName: r.counterpart_name as string,
    })),
    endedMatches: ended.rows.map((r) => ({
      id: r.id as string,
      counterpartName: r.counterpart_name as string,
    })),
  });
}
