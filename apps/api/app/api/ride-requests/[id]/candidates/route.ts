import { NextResponse } from "next/server";
import { sql } from "drizzle-orm";
import { getDb } from "@airport-ride-matchmaking/db";
import { jsonError, requireUserId } from "@/lib/api-response";
import { neighborRes7Cells } from "@/lib/h3";

const CANDIDATE_LIMIT = 10;

export async function GET(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const { id } = await params;
  const db = getDb();

  const mineResult = await db.execute<{
    id: string;
    user_id: string;
    h3_cell_res7: string;
    h3_cell_res8: string;
    flight_arrival_at: string;
    arrival_window_start: string;
    arrival_window_end: string;
    gender: string;
    gender_preference: string;
  }>(sql`
    SELECT rr.id, rr.user_id, rr.h3_cell_res7, rr.h3_cell_res8, rr.flight_arrival_at,
           rr.arrival_window_start, rr.arrival_window_end, p.gender, p.gender_preference
    FROM ride_requests rr
    JOIN profiles p ON p.user_id = rr.user_id
    WHERE rr.id = ${id} AND rr.user_id = ${userId}
    LIMIT 1
  `);
  const mine = mineResult.rows[0];
  if (!mine) return jsonError("Ride request not found", 404);

  // h3 cell IDs are hex strings (no special chars), safe to inline as a Postgres array literal.
  const neighborCellsLiteral = `{${neighborRes7Cells(mine.h3_cell_res7).join(",")}}`;

  const candidates = await db.execute(sql`
    SELECT rr.id, rr.user_id, rr.flight_number, rr.flight_arrival_at, rr.destination_locality_label,
           rr.h3_cell_res7, rr.h3_cell_res8,
           p.display_name, p.gender, p.profile_photo_url
    FROM ride_requests rr
    JOIN profiles p ON p.user_id = rr.user_id
    WHERE rr.status = 'open'
      AND rr.user_id != ${mine.user_id}
      AND rr.h3_cell_res7 = ANY(${neighborCellsLiteral}::text[])
      AND rr.arrival_window_start <= ${mine.arrival_window_end}
      AND rr.arrival_window_end >= ${mine.arrival_window_start}
      AND NOT EXISTS (
        SELECT 1 FROM blocks b
        WHERE (b.blocker_id = ${mine.user_id} AND b.blocked_id = rr.user_id)
           OR (b.blocker_id = rr.user_id AND b.blocked_id = ${mine.user_id})
      )
      AND (${mine.gender_preference} != 'same_gender_only' OR p.gender = ${mine.gender})
      AND (p.gender_preference != 'same_gender_only' OR p.gender = ${mine.gender})
      AND NOT EXISTS (
        SELECT 1 FROM matches m
        WHERE m.status = 'rejected'
          AND (
            (m.ride_request_a_id = ${mine.id} AND m.ride_request_b_id = rr.id)
            OR (m.ride_request_a_id = rr.id AND m.ride_request_b_id = ${mine.id})
          )
      )
    ORDER BY
      (rr.h3_cell_res8 = ${mine.h3_cell_res8}) DESC,
      ABS(EXTRACT(EPOCH FROM (rr.flight_arrival_at - ${mine.flight_arrival_at}))) ASC
    LIMIT ${CANDIDATE_LIMIT}
  `);

  return NextResponse.json({ candidates: candidates.rows });
}
