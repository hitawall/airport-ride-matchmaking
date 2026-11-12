import { NextResponse } from "next/server";
import { and, desc, eq, gt } from "drizzle-orm";
import { getDb, otpRequests, users } from "@airport-ride-matchmaking/db";
import { otpVerifySchema } from "@/lib/schemas";
import { jsonError } from "@/lib/api-response";
import { verifyOtp } from "@/lib/msg91";
import { issueToken } from "@/lib/auth";

export async function POST(request: Request) {
  const body = await request.json().catch(() => null);
  const parsed = otpVerifySchema.safeParse(body);
  if (!parsed.success) return jsonError(parsed.error.issues[0].message, 400);
  const { phone, requestId, code } = parsed.data;

  const db = getDb();
  const [otpRow] = await db
    .select()
    .from(otpRequests)
    .where(
      and(
        eq(otpRequests.phone, phone),
        eq(otpRequests.msg91RequestId, requestId),
        gt(otpRequests.expiresAt, new Date()),
      ),
    )
    .orderBy(desc(otpRequests.createdAt))
    .limit(1);
  if (!otpRow) return jsonError("OTP request not found or expired", 400);

  const ok = await verifyOtp(phone, code);
  if (!ok) return jsonError("Invalid code", 400);

  await db.update(otpRequests).set({ verifiedAt: new Date() }).where(eq(otpRequests.id, otpRow.id));

  const [existingUser] = await db.select().from(users).where(eq(users.phone, phone)).limit(1);
  const isNewUser = !existingUser;
  const user = existingUser
    ? (await db
        .update(users)
        .set({ phoneVerified: true, updatedAt: new Date() })
        .where(eq(users.id, existingUser.id))
        .returning())[0]
    : (await db.insert(users).values({ phone, phoneVerified: true }).returning())[0];

  const token = await issueToken(user.id);
  return NextResponse.json({ token, userId: user.id, isNewUser });
}
