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
    status: string;
    h3_cell_res7: string;
    h3_cell_res8: string;
    airport_code: string;
    terminal: string | null;
    flight_arrival_at: string;
    arrival_window_start: string;
    arrival_window_end: string;
    gender: string;
    gender_preference: string;
  }>(sql`
    SELECT rr.id, rr.user_id, rr.status, rr.h3_cell_res7, rr.h3_cell_res8, rr.airport_code, rr.terminal, rr.flight_arrival_at,
           rr.arrival_window_start, rr.arrival_window_end, p.gender, p.gender_preference
    FROM ride_requests rr
    JOIN profiles p ON p.user_id = rr.user_id
    WHERE rr.id = ${id} AND rr.user_id = ${userId}
    LIMIT 1
  `);
  const mine = mineResult.rows[0];
  if (!mine) return jsonError("Ride request not found", 404);

  // Not open anymore (expired/cancelled/matched) -- nothing to search for. Tell
  // the caller explicitly so the UI can stop polling instead of showing an
  // indefinite "no match yet" for a request that's no longer active.
  if (mine.status !== "open") {
    return NextResponse.json({ candidates: [], rideRequestStatus: mine.status });
  }

  // h3 cell IDs are hex strings (no special chars), safe to inline as a Postgres array literal.
  const neighborCellsLiteral = `{${neighborRes7Cells(mine.h3_cell_res7).join(",")}}`;

  const candidates = await db.execute(sql`
    SELECT rr.id, rr.user_id, rr.flight_number, rr.flight_arrival_at, rr.destination_locality_label,
           rr.h3_cell_res7, rr.h3_cell_res8, rr.airport_code, rr.terminal, rr.trolley_bags,
           p.display_name, p.gender, p.profile_photo_url, p.bio,
           r.avg_rating, r.rating_count
    FROM ride_requests rr
    JOIN profiles p ON p.user_id = rr.user_id
    LEFT JOIN (
      SELECT rated_id, AVG(score)::float8 AS avg_rating, COUNT(*)::int AS rating_count
      FROM ratings GROUP BY rated_id
    ) r ON r.rated_id = rr.user_id
    WHERE rr.status = 'open'
      AND rr.user_id != ${mine.user_id}
      -- Same airport AND same terminal, always. A request without a terminal
      -- (created before terminals existed) never matches anyone.
      AND rr.airport_code = ${mine.airport_code}
      AND rr.terminal IS NOT NULL
      AND rr.terminal = ${mine.terminal}
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
        WHERE (
            (m.ride_request_a_id = ${mine.id} AND m.ride_request_b_id = rr.id)
            OR (m.ride_request_a_id = rr.id AND m.ride_request_b_id = ${mine.id})
          )
          AND (
            -- Someone passed on this pair: it stays hidden. An unmatched pair is
            -- NOT hidden: they may meet again (only a block is permanent).
            m.status = 'rejected'
            -- I'm the one who already proposed (liked) this exact candidate --
            -- whoever proposes first always ends up as ride_request_a_id, so
            -- this is true only when *I* made the first move, not when they
            -- liked me and I haven't responded yet (that case should still
            -- show up so I can respond and get an instant mutual match).
            OR (m.status <> 'unmatched' AND m.ride_request_a_id = ${mine.id})
          )
      )
    ORDER BY
      (rr.h3_cell_res8 = ${mine.h3_cell_res8}) DESC,
      ABS(EXTRACT(EPOCH FROM (rr.flight_arrival_at - ${mine.flight_arrival_at}))) ASC
    LIMIT ${CANDIDATE_LIMIT}
  `);

  return NextResponse.json({ candidates: candidates.rows, rideRequestStatus: mine.status });
}
