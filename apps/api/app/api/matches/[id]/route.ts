import { NextResponse } from "next/server";
import { eq, sql } from "drizzle-orm";
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

  const [rideRequest] = await db
    .select({ airportCode: rideRequests.airportCode, terminal: rideRequests.terminal })
    .from(rideRequests)
    .where(eq(rideRequests.id, match.rideRequestAId))
    .limit(1);

  return NextResponse.json({
    ...match,
    airportCode: rideRequest?.airportCode ?? null,
    terminal: rideRequest?.terminal ?? null,
    counterpartDisplayName: counterpart?.displayName ?? null,
    counterpartPhotoUrl: counterpart?.profilePhotoUrl ?? null,
    counterpartAvgRating: stats.ratingCount ? Number(stats.avgRating) : null,
    counterpartRatingCount: stats.ratingCount,
  });
}
