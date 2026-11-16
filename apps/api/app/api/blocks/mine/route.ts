import { NextResponse } from "next/server";
import { desc, eq } from "drizzle-orm";
import { getDb, blocks, profiles } from "@airport-ride-matchmaking/db";
import { requireUserId } from "@/lib/api-response";

export async function GET(request: Request) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const db = getDb();
  const rows = await db
    .select({
      id: blocks.id,
      blockerId: blocks.blockerId,
      blockedId: blocks.blockedId,
      createdAt: blocks.createdAt,
      blockedDisplayName: profiles.displayName,
      blockedPhotoUrl: profiles.profilePhotoUrl,
    })
    .from(blocks)
    .leftJoin(profiles, eq(profiles.userId, blocks.blockedId))
    .where(eq(blocks.blockerId, userId))
    .orderBy(desc(blocks.createdAt));

  return NextResponse.json({ blocks: rows });
}
