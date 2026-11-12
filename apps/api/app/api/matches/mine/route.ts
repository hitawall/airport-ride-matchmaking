import { NextResponse } from "next/server";
import { sql } from "drizzle-orm";
import { getDb } from "@airport-ride-matchmaking/db";
import { requireUserId } from "@/lib/api-response";

export async function GET(request: Request) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const db = getDb();
  const result = await db.execute(sql`
    SELECT
      m.id, m.status, m.user_a_id, m.user_b_id, m.created_at, m.updated_at,
      CASE WHEN m.user_a_id = ${userId} THEN pb.display_name ELSE pa.display_name END AS counterpart_display_name,
      CASE WHEN m.user_a_id = ${userId} THEN pb.profile_photo_url ELSE pa.profile_photo_url END AS counterpart_photo_url
    FROM matches m
    JOIN profiles pa ON pa.user_id = m.user_a_id
    JOIN profiles pb ON pb.user_id = m.user_b_id
    WHERE m.user_a_id = ${userId} OR m.user_b_id = ${userId}
    ORDER BY m.updated_at DESC
  `);

  return NextResponse.json({ matches: result.rows });
}
