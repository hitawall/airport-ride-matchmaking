import { NextResponse } from "next/server";
import { eq } from "drizzle-orm";
import { getDb, matches } from "@airport-ride-matchmaking/db";
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

  return NextResponse.json(updated);
}
