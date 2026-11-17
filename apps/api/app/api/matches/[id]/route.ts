import { NextResponse } from "next/server";
import { eq, inArray, sql } from "drizzle-orm";
import { getDb, profiles, ratings, rideRequests } from "@airport-ride-matchmaking/db";
import { jsonError, requireUserId } from "@/lib/api-response";
import { getMatchForParticipant } from "@/lib/chat";

export async function GET(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const { id } = await params;
  const match = await getMatchForParticipant(id, userId);
  if (!match) return jsonError("Match not found", 404);

  const counterpartId = match.userAId === userId ? match.userBId : match.userAId;
  const db = getDb();
  const [stats] = await db
    .select({
      avgRating: sql<string>`AVG(${ratings.score})::numeric(3,2)`,
      ratingCount: sql<number>`COUNT(*)::int`,
    })
    .from(ratings)
    .where(eq(ratings.ratedId, counterpartId));
  const [counterpart] = await db
    .select({ displayName: profiles.displayName, profilePhotoUrl: profiles.profilePhotoUrl })
    .from(profiles)
    .where(eq(profiles.userId, counterpartId))
    .limit(1);

  // Both trips: the meeting terminal, and each rider's destination area (the
  // same area name already shown on candidate cards) for the fare split hint.
  const trips = await db
    .select({
      id: rideRequests.id,
      airportCode: rideRequests.airportCode,
      terminal: rideRequests.terminal,
      destinationLocalityLabel: rideRequests.destinationLocalityLabel,
      trolleyBags: rideRequests.trolleyBags,
    })
    .from(rideRequests)
    .where(inArray(rideRequests.id, [match.rideRequestAId, match.rideRequestBId]));
  const tripA = trips.find((t) => t.id === match.rideRequestAId);
  const tripB = trips.find((t) => t.id === match.rideRequestBId);
  const rideRequest = tripA;
  const iAmA = match.userAId === userId;

  return NextResponse.json({
    ...match,
    airportCode: rideRequest?.airportCode ?? null,
    terminal: rideRequest?.terminal ?? null,
    myDestinationLocalityLabel: (iAmA ? tripA : tripB)?.destinationLocalityLabel ?? null,
    counterpartDestinationLocalityLabel: (iAmA ? tripB : tripA)?.destinationLocalityLabel ?? null,
    myTrolleyBags: (iAmA ? tripA : tripB)?.trolleyBags ?? null,
    counterpartTrolleyBags: (iAmA ? tripB : tripA)?.trolleyBags ?? null,
    counterpartDisplayName: counterpart?.displayName ?? null,
    counterpartPhotoUrl: counterpart?.profilePhotoUrl ?? null,
    counterpartAvgRating: stats.ratingCount ? Number(stats.avgRating) : null,
    counterpartRatingCount: stats.ratingCount,
  });
}
