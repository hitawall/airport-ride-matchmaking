import { NextResponse } from "next/server";
import { and, eq, gte, sql } from "drizzle-orm";
import { getDb, feedback } from "@airport-ride-matchmaking/db";
import { feedbackCreateSchema } from "@/lib/schemas";
import { jsonError, requireUserId } from "@/lib/api-response";

const MAX_SUBMISSIONS_PER_HOUR = 5;

export async function POST(request: Request) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const body = await request.json().catch(() => null);
  const parsed = feedbackCreateSchema.safeParse(body);
  if (!parsed.success) return jsonError(parsed.error.issues[0].message, 400);

  const db = getDb();
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  const [{ count }] = await db
    .select({ count: sql<number>`count(*)::int` })
    .from(feedback)
    .where(and(eq(feedback.userId, userId), gte(feedback.createdAt, oneHourAgo)));
  if (count >= MAX_SUBMISSIONS_PER_HOUR) {
    return jsonError("Too many submissions. Try again later.", 429);
  }

  const [row] = await db
    .insert(feedback)
    .values({ userId, type: parsed.data.type, message: parsed.data.message })
    .returning();

  return NextResponse.json(row, { status: 201 });
}
