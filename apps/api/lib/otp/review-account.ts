import { env } from "@/lib/env";

/**
 * The fixed login code for the app-store review account, or null for everyone
 * else (and for everyone when the review account is not configured).
 *
 * Verification needs no special case: the code is stored on the OTP request
 * like any other, so the normal check, the 5-attempt lockout and the
 * 3-codes-per-hour limit all still apply to this account.
 */
export function reviewAccountCode(email: string): string | null {
  const reviewEmail = env.reviewAccountEmail;
  const code = env.reviewAccountCode;
  if (!reviewEmail || !code) return null;
  return email.trim().toLowerCase() === reviewEmail ? code : null;
}
