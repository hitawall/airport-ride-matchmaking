import { NextResponse } from "next/server";
import { track } from "@/lib/telemetry";
import { and, eq } from "drizzle-orm";
import { getDb, profiles, rideRequests } from "@airport-ride-matchmaking/db";
import { rideRequestCreateSchema } from "@/lib/schemas";
import { jsonError, requireUserId } from "@/lib/api-response";
import { computeH3Cells } from "@/lib/h3";

const ARRIVAL_WINDOW_MINUTES = 45;

export async function POST(request: Request) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const body = await request.json().catch(() => null);
  const parsed = rideRequestCreateSchema.safeParse(body);
  if (!parsed.success) return jsonError(parsed.error.issues[0].message, 400);
  const data = parsed.data;

  const db = getDb();

  const [profile] = await db
    .select({ profilePhotoUrl: profiles.profilePhotoUrl })
    .from(profiles)
    .where(eq(profiles.userId, userId))
    .limit(1);
  if (!profile?.profilePhotoUrl) {
    return jsonError(
      "Add a profile photo before searching for a match. It helps your match recognize you at pickup.",
      403,
    );
  }

  const [existingOpen] = await db
    .select()
    .from(rideRequests)
    .where(and(eq(rideRequests.userId, userId), eq(rideRequests.status, "open")))
    .limit(1);
  if (existingOpen) {
    return jsonError("You already have an active ride request. Cancel it first.", 409);
  }

  const flightArrivalAt = new Date(data.flightArrivalAt);
  const arrivalWindowStart = new Date(
    flightArrivalAt.getTime() - ARRIVAL_WINDOW_MINUTES * 60 * 1000,
  );
  const arrivalWindowEnd = new Date(
    flightArrivalAt.getTime() + ARRIVAL_WINDOW_MINUTES * 60 * 1000,
  );
  const { h3CellRes7, h3CellRes8 } = computeH3Cells(data.destinationLat, data.destinationLng);

  const [rideRequest] = await db
    .insert(rideRequests)
    .values({
      userId,
      airportCode: data.airportCode,
      terminal: data.terminal,
      flightNumber: data.flightNumber,
      flightArrivalAt,
      arrivalWindowStart,
      arrivalWindowEnd,
      destinationAddress: data.destinationAddress,
      destinationLat: data.destinationLat,
      destinationLng: data.destinationLng,
      destinationLocalityLabel: data.destinationLocalityLabel,
      h3CellRes7,
      h3CellRes8,
    })
    .returning();

  await track("ride_request_created", userId, {
    has_flight_number: !!parsed.data.flightNumber,
    airport: data.airportCode,
    terminal: data.terminal,
  });
  return NextResponse.json(rideRequest, { status: 201 });
}
