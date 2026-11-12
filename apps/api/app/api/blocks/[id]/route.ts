import { NextResponse } from "next/server";
import { and, eq } from "drizzle-orm";
import { getDb, blocks } from "@airport-ride-matchmaking/db";
import { jsonError, requireUserId } from "@/lib/api-response";

export async function DELETE(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const { id } = await params;
  const db = getDb();
  const [deleted] = await db
    .delete(blocks)
    .where(and(eq(blocks.id, id), eq(blocks.blockerId, userId)))
    .returning();
  if (!deleted) return jsonError("Block not found", 404);

  return NextResponse.json({ ok: true });
}
