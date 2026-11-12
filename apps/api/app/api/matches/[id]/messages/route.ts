import { NextResponse } from "next/server";
import { and, asc, eq, gt } from "drizzle-orm";
import { getDb, chatMessages } from "@airport-ride-matchmaking/db";
import { chatMessageCreateSchema } from "@/lib/schemas";
import { jsonError, requireUserId } from "@/lib/api-response";
import { getMatchForParticipant } from "@/lib/chat";
import { getPusher, matchChannelName } from "@/lib/pusher";

export async function GET(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const { id } = await params;
  const match = await getMatchForParticipant(id, userId);
  if (!match) return jsonError("Match not found", 404);

  const after = new URL(request.url).searchParams.get("after");
  const db = getDb();
  const whereClause = after
    ? and(eq(chatMessages.matchId, id), gt(chatMessages.createdAt, new Date(after)))
    : eq(chatMessages.matchId, id);

  const messages = await db
    .select()
    .from(chatMessages)
    .where(whereClause)
    .orderBy(asc(chatMessages.createdAt));

  return NextResponse.json({ messages });
}

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const { id } = await params;
  const match = await getMatchForParticipant(id, userId);
  if (!match) return jsonError("Match not found", 404);
  if (match.status !== "mutual") return jsonError("Chat is only available for mutual matches", 403);

  const body = await request.json().catch(() => null);
  const parsed = chatMessageCreateSchema.safeParse(body);
  if (!parsed.success) return jsonError(parsed.error.issues[0].message, 400);

  const db = getDb();
  const [message] = await db
    .insert(chatMessages)
    .values({ matchId: id, senderId: userId, body: parsed.data.body })
    .returning();

  try {
    await getPusher().trigger(matchChannelName(id), "new-message", message);
  } catch (err) {
    // Non-fatal: the message is already persisted and will show up via the
    // polling fallback even if realtime delivery (e.g. Pusher not configured
    // yet) fails.
    console.error("Pusher trigger failed", err);
  }

  return NextResponse.json(message, { status: 201 });
}
