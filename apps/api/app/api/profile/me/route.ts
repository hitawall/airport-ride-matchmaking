import { NextResponse } from "next/server";
import { and, eq, ne } from "drizzle-orm";
import { getDb, profiles } from "@airport-ride-matchmaking/db";
import { profileUpdateSchema } from "@/lib/schemas";
import { jsonError, requireUserId } from "@/lib/api-response";

const PHONE_TAKEN_MESSAGE =
  "That mobile number is already used by another account. Use a different number, or sign in with the email you first used.";

function isUniqueViolation(error: unknown): boolean {
  const e = error as { code?: string; cause?: { code?: string } } | null;
  return e?.code === "23505" || e?.cause?.code === "23505";
}

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

  // One mobile number per account. The unique index is the backstop for races.
  const [taken] = await db
    .select({ userId: profiles.userId })
    .from(profiles)
    .where(and(eq(profiles.phoneNumber, parsed.data.phoneNumber), ne(profiles.userId, userId)))
    .limit(1);
  if (taken) return jsonError(PHONE_TAKEN_MESSAGE, 409);

  const [existing] = await db.select().from(profiles).where(eq(profiles.userId, userId)).limit(1);

  try {
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
  } catch (error) {
    if (isUniqueViolation(error)) return jsonError(PHONE_TAKEN_MESSAGE, 409);
    throw error;
  }
}
