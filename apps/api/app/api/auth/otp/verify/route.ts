import { NextResponse } from "next/server";
import { track } from "@/lib/telemetry";
import { and, desc, eq, gt } from "drizzle-orm";
import { getDb, otpRequests, users } from "@airport-ride-matchmaking/db";
import { otpVerifySchema } from "@/lib/schemas";
import { jsonError } from "@/lib/api-response";
import { issueToken } from "@/lib/auth";
import { env } from "@/lib/env";

const MAX_VERIFY_ATTEMPTS = 5;

export async function POST(request: Request) {
  const body = await request.json().catch(() => null);
  const parsed = otpVerifySchema.safeParse(body);
  if (!parsed.success) return jsonError(parsed.error.issues[0].message, 400);
  const { email, requestId, code } = parsed.data;

  const db = getDb();
  const [otpRow] = await db
    .select()
    .from(otpRequests)
    .where(
      and(
        eq(otpRequests.email, email),
        eq(otpRequests.requestId, requestId),
        gt(otpRequests.expiresAt, new Date()),
      ),
    )
    .orderBy(desc(otpRequests.createdAt))
    .limit(1);
  if (!otpRow) return jsonError("OTP request not found or expired", 400);
  if (otpRow.attemptCount >= MAX_VERIFY_ATTEMPTS) {
    return jsonError("Too many incorrect attempts. Request a new code.", 429);
  }

  const ok = env.otpTestMode ? code === "000000" : code === otpRow.code;
  if (!ok) {
    await db
      .update(otpRequests)
      .set({ attemptCount: otpRow.attemptCount + 1 })
      .where(eq(otpRequests.id, otpRow.id));
    return jsonError("Invalid code", 400);
  }

  await db.update(otpRequests).set({ verifiedAt: new Date() }).where(eq(otpRequests.id, otpRow.id));

  const [existingUser] = await db.select().from(users).where(eq(users.email, email)).limit(1);
  const isNewUser = !existingUser;
  const user = existingUser
    ? (await db
        .update(users)
        .set({ emailVerified: true, updatedAt: new Date() })
        .where(eq(users.id, existingUser.id))
        .returning())[0]
    : (await db.insert(users).values({ email, emailVerified: true }).returning())[0];

  const token = await issueToken(user.id);
  if (isNewUser) await track("account_created", user.id);
  await track("otp_verified", user.id, { is_new_user: isNewUser });
  return NextResponse.json({ token, userId: user.id, isNewUser });
}
