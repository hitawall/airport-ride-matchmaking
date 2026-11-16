function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required env var: ${name}`);
  return value;
}

export const env = {
  get jwtSecret() {
    return required("JWT_SECRET");
  },
  /** Trial-only bypass: accepts a fixed dev OTP code instead of sending a real email. Never enable with real users. */
  get otpTestMode() {
    return process.env.OTP_TEST_MODE === "true";
  },
  /**
   * Store-review account: a single email that logs in with a fixed code so app
   * store reviewers (who cannot read email) can get in. Active only when both
   * REVIEW_ACCOUNT_EMAIL and a REVIEW_ACCOUNT_CODE are set; unset them to
   * switch it off. The code is exactly 6 digits because that is all the app's
   * code input and the API accept; 000000 is refused since it is the test-mode
   * code. Guessing is impractical: 5 attempts per code and 3 codes per hour.
   */
  get reviewAccountEmail(): string | undefined {
    return process.env.REVIEW_ACCOUNT_EMAIL?.trim().toLowerCase() || undefined;
  },
  get reviewAccountCode(): string | undefined {
    const code = process.env.REVIEW_ACCOUNT_CODE?.trim();
    return code && /^\d{6}$/.test(code) && code !== "000000" ? code : undefined;
  },
  get resendApiKey() {
    return required("RESEND_API_KEY");
  },
  /** Must be an address on a domain verified with Resend. */
  get otpFromEmail() {
    return required("OTP_FROM_EMAIL");
  },
  get pusherAppId() {
    return required("PUSHER_APP_ID");
  },
  get pusherKey() {
    return required("PUSHER_KEY");
  },
  get pusherSecret() {
    return required("PUSHER_SECRET");
  },
  get pusherCluster() {
    return required("PUSHER_CLUSTER");
  },
  get cronSecret() {
    return required("CRON_SECRET");
  },
  /**
   * Where the daily moderation digest of new reports is emailed. Optional:
   * with it unset the digest job runs but sends nothing (see docs/MODERATION.md).
   */
  get moderationEmail(): string | undefined {
    return process.env.MODERATION_EMAIL?.trim() || undefined;
  },
  /**
   * Bearer token for the moderator actions (mark a report reviewed, remove an
   * account). Optional: with it unset those endpoints refuse every request.
   * Use a long random value, different from CRON_SECRET.
   */
  get moderationToken(): string | undefined {
    const token = process.env.MODERATION_TOKEN?.trim();
    return token && token.length >= 24 ? token : undefined;
  },
};
