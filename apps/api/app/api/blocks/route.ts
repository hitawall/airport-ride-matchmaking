import { NextResponse } from "next/server";
import { and, eq } from "drizzle-orm";
import { getDb, blocks } from "@airport-ride-matchmaking/db";
import { blockCreateSchema } from "@/lib/schemas";
import { jsonError, requireUserId } from "@/lib/api-response";

export async function POST(request: Request) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const body = await request.json().catch(() => null);
  const parsed = blockCreateSchema.safeParse(body);
  if (!parsed.success) return jsonError(parsed.error.issues[0].message, 400);
  const { blockedUserId } = parsed.data;

  if (blockedUserId === userId) return jsonError("Cannot block yourself", 400);

  const db = getDb();
  const [existing] = await db
    .select()
    .from(blocks)
    .where(and(eq(blocks.blockerId, userId), eq(blocks.blockedId, blockedUserId)))
    .limit(1);
  if (existing) return NextResponse.json(existing);

  const [block] = await db
    .insert(blocks)
    .values({ blockerId: userId, blockedId: blockedUserId })
    .returning();

  return NextResponse.json(block, { status: 201 });
}
