import { randomUUID } from "node:crypto";
import { NextResponse } from "next/server";
import { and, eq, gte, sql } from "drizzle-orm";
import { getDb, otpRequests } from "@airport-ride-matchmaking/db";
import { otpSendSchema } from "@/lib/schemas";
import { jsonError } from "@/lib/api-response";
import { sendOtp } from "@/lib/msg91";
import { env } from "@/lib/env";

const MAX_SENDS_PER_HOUR = 3;
const OTP_TTL_SECONDS = 5 * 60;

export async function POST(request: Request) {
  const body = await request.json().catch(() => null);
  const parsed = otpSendSchema.safeParse(body);
  if (!parsed.success) return jsonError(parsed.error.issues[0].message, 400);
  const { phone } = parsed.data;

  const db = getDb();
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  const [{ count }] = await db
    .select({ count: sql<number>`count(*)::int` })
    .from(otpRequests)
    .where(and(eq(otpRequests.phone, phone), gte(otpRequests.createdAt, oneHourAgo)));
  if (count >= MAX_SENDS_PER_HOUR) {
    return jsonError("Too many OTP requests. Try again later.", 429);
  }

  const { requestId } = env.otpTestMode ? { requestId: `test-${randomUUID()}` } : await sendOtp(phone);
  const expiresAt = new Date(Date.now() + OTP_TTL_SECONDS * 1000);
  await db.insert(otpRequests).values({
    phone,
    msg91RequestId: requestId,
    expiresAt,
  });

  return NextResponse.json({
    requestId,
    expiresInSeconds: OTP_TTL_SECONDS,
    ...(env.otpTestMode && { testMode: true }),
  });
}
