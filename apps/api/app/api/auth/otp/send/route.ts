import { randomUUID } from "node:crypto";
import { NextResponse } from "next/server";
import { and, eq, gte, sql } from "drizzle-orm";
import { getDb, otpRequests } from "@airport-ride-matchmaking/db";
import { otpSendSchema } from "@/lib/schemas";
import { jsonError } from "@/lib/api-response";
import { getOtpChannel } from "@/lib/otp";
import { reviewAccountCode } from "@/lib/otp/review-account";
import { env } from "@/lib/env";

const MAX_SENDS_PER_HOUR = 3;
const OTP_TTL_SECONDS = 5 * 60;

export async function POST(request: Request) {
  const body = await request.json().catch(() => null);
  const parsed = otpSendSchema.safeParse(body);
  if (!parsed.success) return jsonError(parsed.error.issues[0].message, 400);
  const { email } = parsed.data;

  const db = getDb();
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  const [{ count }] = await db
    .select({ count: sql<number>`count(*)::int` })
    .from(otpRequests)
    .where(and(eq(otpRequests.email, email), gte(otpRequests.createdAt, oneHourAgo)));
  if (count >= MAX_SENDS_PER_HOUR) {
    return jsonError("Too many OTP requests. Try again later.", 429);
  }

  const requestId = randomUUID();
  // The store-review account gets its fixed code and no email (reviewers cannot
  // read the inbox); everyone else gets a random code by email.
  const reviewCode = env.otpTestMode ? null : reviewAccountCode(email);
  const code = env.otpTestMode
    ? "000000"
    : (reviewCode ?? String(Math.floor(100000 + Math.random() * 900000)));

  if (!env.otpTestMode && !reviewCode) {
    await getOtpChannel().send(email, code);
  }

  const expiresAt = new Date(Date.now() + OTP_TTL_SECONDS * 1000);
  await db.insert(otpRequests).values({
    email,
    requestId,
    code,
    expiresAt,
  });

  return NextResponse.json({
    requestId,
    expiresInSeconds: OTP_TTL_SECONDS,
    ...(env.otpTestMode && { testMode: true }),
  });
}
