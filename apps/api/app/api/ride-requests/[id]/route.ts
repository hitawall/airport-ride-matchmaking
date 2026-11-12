import { NextResponse } from "next/server";
import { z } from "zod";
import { and, eq } from "drizzle-orm";
import { getDb, rideRequests } from "@airport-ride-matchmaking/db";
import { jsonError, requireUserId } from "@/lib/api-response";

const patchSchema = z.object({ status: z.literal("cancelled") });

export async function PATCH(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const { id } = await params;
  const body = await request.json().catch(() => null);
  const parsed = patchSchema.safeParse(body);
  if (!parsed.success) return jsonError(parsed.error.issues[0].message, 400);

  const db = getDb();
  const [rideRequest] = await db
    .update(rideRequests)
    .set({ status: "cancelled", updatedAt: new Date() })
    .where(and(eq(rideRequests.id, id), eq(rideRequests.userId, userId)))
    .returning();
  if (!rideRequest) return jsonError("Ride request not found", 404);

  return NextResponse.json(rideRequest);
}
