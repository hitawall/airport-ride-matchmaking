import { NextResponse } from "next/server";
import { eq } from "drizzle-orm";
import { getDb, blocks } from "@airport-ride-matchmaking/db";
import { requireUserId } from "@/lib/api-response";

export async function GET(request: Request) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const db = getDb();
  const rows = await db.select().from(blocks).where(eq(blocks.blockerId, userId));

  return NextResponse.json({ blocks: rows });
}
