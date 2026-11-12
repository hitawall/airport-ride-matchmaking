import { NextResponse } from "next/server";
import { eq } from "drizzle-orm";
import { getDb, profiles } from "@airport-ride-matchmaking/db";
import { profileUpdateSchema } from "@/lib/schemas";
import { jsonError, requireUserId } from "@/lib/api-response";

export async function GET(request: Request) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const db = getDb();
  const [profile] = await db.select().from(profiles).where(eq(profiles.userId, userId)).limit(1);
  if (!profile) return jsonError("Profile not found", 404);
  return NextResponse.json(profile);
}

export async function PUT(request: Request) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const body = await request.json().catch(() => null);
  const parsed = profileUpdateSchema.safeParse(body);
  if (!parsed.success) return jsonError(parsed.error.issues[0].message, 400);

  const db = getDb();
  const [existing] = await db.select().from(profiles).where(eq(profiles.userId, userId)).limit(1);

  const [profile] = existing
    ? await db
        .update(profiles)
        .set({ ...parsed.data, updatedAt: new Date() })
        .where(eq(profiles.userId, userId))
        .returning()
    : await db
        .insert(profiles)
        .values({ userId, ...parsed.data })
        .returning();

  return NextResponse.json(profile);
}
