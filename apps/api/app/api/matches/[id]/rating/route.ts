import { NextResponse } from "next/server";
import { track } from "@/lib/telemetry";
import { getDb, ratings } from "@airport-ride-matchmaking/db";
import { ratingCreateSchema } from "@/lib/schemas";
import { jsonError, requireUserId } from "@/lib/api-response";
import { getMatchForParticipant } from "@/lib/chat";

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const { id } = await params;
  const match = await getMatchForParticipant(id, userId);
  if (!match) return jsonError("Match not found", 404);
  if (match.status === "proposed_by_a" || match.status === "proposed_by_b") {
    return jsonError("You can only rate a match once it's mutual", 409);
  }

  const body = await request.json().catch(() => null);
  const parsed = ratingCreateSchema.safeParse(body);
  if (!parsed.success) return jsonError(parsed.error.issues[0].message, 400);

  const ratedId = match.userAId === userId ? match.userBId : match.userAId;
  const db = getDb();
  try {
    const [rating] = await db
      .insert(ratings)
      .values({ raterId: userId, ratedId, matchId: id, score: parsed.data.score })
      .returning();
    await track("rating_given", userId, { score: parsed.data.score });
    return NextResponse.json(rating, { status: 201 });
  } catch (err) {
    const cause = err instanceof Error ? (err.cause as { code?: string } | undefined) : undefined;
    if (cause?.code === "23505") {
      return jsonError("You've already rated this match", 409);
    }
    throw err;
  }
}
