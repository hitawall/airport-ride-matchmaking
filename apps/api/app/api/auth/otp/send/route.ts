import { randomInt, randomUUID } from "node:crypto";
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
  const [{ count, oldest }] = await db
    .select({ count: sql<number>`count(*)::int`, oldest: sql<string | null>`min(${otpRequests.createdAt})` })
    .from(otpRequests)
    .where(and(eq(otpRequests.email, email), gte(otpRequests.createdAt, oneHourAgo)));
  if (count >= MAX_SENDS_PER_HOUR) {
    // Tell them when the oldest request in the window drops out, instead of a
    // vague "try later".
    const freeAt = (oldest ? new Date(oldest).getTime() : Date.now()) + 60 * 60 * 1000;
    const seconds = Math.max(60, Math.ceil((freeAt - Date.now()) / 1000));
    const minutes = Math.ceil(seconds / 60);
    const response = jsonError(
      `You have asked for too many codes. Try again in ${minutes} ${minutes === 1 ? "minute" : "minutes"}.`,
      429,
    );
    response.headers.set("Retry-After", String(seconds));
    return response;
  }

  const requestId = randomUUID();
  // The store-review account gets its fixed code and no email (reviewers cannot
  // read the inbox); everyone else gets a random code by email.
  const reviewCode = env.otpTestMode ? null : reviewAccountCode(email);
  const code = env.otpTestMode
    ? "000000"
    : (reviewCode ?? String(randomInt(100000, 1000000)));

  if (!env.otpTestMode && !reviewCode) {
    try {
      await getOtpChannel().send(email, code);
    } catch (error) {
      // Nothing is stored, so a failed send does not use up one of the
      // user's hourly attempts. Log the cause (no email address, no code).
      console.error("otp: email delivery failed", error instanceof Error ? error.message : error);
      return jsonError("We couldn't send the code right now. Please try again in a minute.", 502);
    }
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
