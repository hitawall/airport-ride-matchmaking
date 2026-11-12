import { NextResponse } from "next/server";
import { desc, eq } from "drizzle-orm";
import { getDb, rideRequests } from "@airport-ride-matchmaking/db";
import { jsonError, requireUserId } from "@/lib/api-response";

export async function GET(request: Request) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const db = getDb();
  const [rideRequest] = await db
    .select()
    .from(rideRequests)
    .where(eq(rideRequests.userId, userId))
    .orderBy(desc(rideRequests.createdAt))
    .limit(1);
  if (!rideRequest) return jsonError("No ride request found", 404);

  return NextResponse.json(rideRequest);
}
