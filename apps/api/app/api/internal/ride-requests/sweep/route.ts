import { NextResponse } from "next/server";
import { and, eq, lt } from "drizzle-orm";
import { getDb, rideRequests } from "@airport-ride-matchmaking/db";
import { jsonError } from "@/lib/api-response";
import { env } from "@/lib/env";

const EXPIRY_GRACE_HOURS = 4;

/** Vercel Cron hits this on a schedule; protected via CRON_SECRET bearer token. */
export async function POST(request: Request) {
  const authHeader = request.headers.get("authorization");
  if (authHeader !== `Bearer ${env.cronSecret}`) return jsonError("Unauthorized", 401);

  const cutoff = new Date(Date.now() - EXPIRY_GRACE_HOURS * 60 * 60 * 1000);
  const db = getDb();
  const expired = await db
    .update(rideRequests)
    .set({ status: "expired", updatedAt: new Date() })
    .where(and(eq(rideRequests.status, "open"), lt(rideRequests.arrivalWindowEnd, cutoff)))
    .returning({ id: rideRequests.id });

  return NextResponse.json({ expiredCount: expired.length });
}
