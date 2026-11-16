import { NextResponse } from "next/server";
import { track } from "@/lib/telemetry";
import { and, eq, gt, inArray } from "drizzle-orm";
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

  // The person who unmatched goes straight back into the search (their trip
  // reopens) so they are never left at a dead end, as long as their arrival
  // window has not passed. The other person's trip is cancelled as before so
  // they are not matched again without choosing to.
  const bothIds = [match.rideRequestAId, match.rideRequestBId];
  const [reopened] = await db
    .update(rideRequests)
    .set({ status: "open", updatedAt: new Date() })
    .where(
      and(
        inArray(rideRequests.id, bothIds),
        eq(rideRequests.userId, userId),
        eq(rideRequests.status, "matched"),
        gt(rideRequests.arrivalWindowEnd, new Date()),
      ),
    )
    .returning({ id: rideRequests.id });
  await db
    .update(rideRequests)
    .set({ status: "cancelled", updatedAt: new Date() })
    .where(and(inArray(rideRequests.id, bothIds), eq(rideRequests.status, "matched")));

  await track("match_unmatched", userId);
  return NextResponse.json({ ...updated, reopenedRideRequestId: reopened?.id ?? null });
}
