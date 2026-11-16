import { NextResponse } from "next/server";
import { and, desc, eq, gt } from "drizzle-orm";
import { getDb, rideRequests } from "@airport-ride-matchmaking/db";
import { jsonError, requireUserId } from "@/lib/api-response";

/**
 * Puts a rider back in the search with their most recent trip, if it was
 * cancelled (for example because their match ended) and their arrival window
 * has not passed. Only ever done when the rider asks: we do not know they are
 * still around after a match ends.
 */
export async function POST(request: Request) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const db = getDb();
  const [latest] = await db
    .select()
    .from(rideRequests)
    .where(eq(rideRequests.userId, userId))
    .orderBy(desc(rideRequests.createdAt))
    .limit(1);

  if (!latest) return jsonError("No trip to resume. Start a new search.", 404);
  if (latest.status === "open") return NextResponse.json(latest);
  if (latest.status === "matched") return jsonError("You already have an active match.", 409);
  if (latest.arrivalWindowEnd.getTime() <= Date.now()) {
    return jsonError("Your arrival window has passed. Start a new search.", 410);
  }

  const [resumed] = await db
    .update(rideRequests)
    .set({ status: "open", updatedAt: new Date() })
    .where(and(eq(rideRequests.id, latest.id), gt(rideRequests.arrivalWindowEnd, new Date())))
    .returning();
  if (!resumed) return jsonError("Your arrival window has passed. Start a new search.", 410);
  return NextResponse.json(resumed);
}
