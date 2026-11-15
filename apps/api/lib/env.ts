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
};
