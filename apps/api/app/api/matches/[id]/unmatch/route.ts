import { NextResponse } from "next/server";
import { track } from "@/lib/telemetry";
import { and, eq, inArray } from "drizzle-orm";
import { getDb, matches, rideRequests } from "@airport-ride-matchmaking/db";
import { jsonError, requireUserId } from "@/lib/api-response";
import { getMatchForParticipant } from "@/lib/chat";

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const { id } = await params;
  const match = await getMatchForParticipant(id, userId);
  if (!match) return jsonError("Match not found", 404);
  if (match.status !== "mutual") {
    return jsonError("Only active matches can be unmatched", 409);
  }

  const db = getDb();
  const [updated] = await db
    .update(matches)
    .set({ status: "unmatched", updatedAt: new Date() })
    .where(eq(matches.id, id))
    .returning();

  // Free up both sides' ride requests -- otherwise they're stuck at
  // "matched" forever with no mutual match to point to, and the home
  // screen has no way back into the matching queue.
  await db
    .update(rideRequests)
    .set({ status: "cancelled", updatedAt: new Date() })
    .where(
      and(
        inArray(rideRequests.id, [match.rideRequestAId, match.rideRequestBId]),
        eq(rideRequests.status, "matched"),
      ),
    );

  await track("match_unmatched", userId);
  return NextResponse.json(updated);
}
