/**
 * Launch-readiness checks for the deployed API. Pure: takes the environment as
 * an argument so it can be run against any set of variables. Reports only
 * yes/no facts, never the values. `required` checks must pass before the app
 * goes to a store; `recommended` ones are worth fixing but do not block.
 */
export interface ReadinessCheck {
  name: string;
  ok: boolean;
  level: "required" | "recommended";
  message: string;
}

type Env = Record<string, string | undefined>;

const RESEND_SANDBOX_SENDER = /@resend\.dev>?$/i;

function present(value: string | undefined): boolean {
  return !!value && value.trim().length > 0;
}

export function runReadinessChecks(env: Env): ReadinessCheck[] {
  const checks: ReadinessCheck[] = [];
  const add = (name: string, ok: boolean, level: ReadinessCheck["level"], message: string) =>
    checks.push({ name, ok, level, message });

  const testMode = env.OTP_TEST_MODE === "true";
  add(
    "otp-test-mode-off",
    !testMode,
    "required",
    testMode
      ? "OTP_TEST_MODE is true: anyone can sign in as any email with the code 000000. Remove it once real email works."
      : "OTP test mode is off.",
  );

  const emailConfigured = present(env.RESEND_API_KEY) && present(env.OTP_FROM_EMAIL);
  add(
    "email-configured",
    emailConfigured,
    "required",
    emailConfigured
      ? "RESEND_API_KEY and OTP_FROM_EMAIL are set."
      : "RESEND_API_KEY or OTP_FROM_EMAIL is missing, so login codes cannot be emailed.",
  );

  const sandboxSender = present(env.OTP_FROM_EMAIL) && RESEND_SANDBOX_SENDER.test(env.OTP_FROM_EMAIL!.trim());
  add(
    "email-sender-verified-domain",
    present(env.OTP_FROM_EMAIL) && !sandboxSender,
    "required",
    sandboxSender
      ? "OTP_FROM_EMAIL uses Resend's shared test sender, which only delivers to the Resend account owner. Verify your own domain in Resend."
      : present(env.OTP_FROM_EMAIL)
        ? "OTP_FROM_EMAIL is not the Resend test sender."
        : "OTP_FROM_EMAIL is not set.",
  );

  add(
    "jwt-secret-strong",
    present(env.JWT_SECRET) && env.JWT_SECRET!.length >= 32,
    "required",
    "JWT_SECRET must be at least 32 characters.",
  );

  const reviewEmail = present(env.REVIEW_ACCOUNT_EMAIL);
  const reviewCode = /^\d{6}$/.test(env.REVIEW_ACCOUNT_CODE?.trim() ?? "") && env.REVIEW_ACCOUNT_CODE?.trim() !== "000000";
  add(
    "review-account",
    reviewEmail && reviewCode,
    "required",
    reviewEmail && reviewCode
      ? "Store reviewer login is enabled."
      : "Store reviewer login is not set up (REVIEW_ACCOUNT_EMAIL and a 6-digit REVIEW_ACCOUNT_CODE). Google and Apple reviewers cannot sign in without it.",
  );

  add(
    "chat-configured",
    ["PUSHER_APP_ID", "PUSHER_KEY", "PUSHER_SECRET", "PUSHER_CLUSTER"].every((k) => present(env[k])),
    "required",
    "Pusher keys are needed for live chat.",
  );
  add("photos-configured", present(env.BLOB_READ_WRITE_TOKEN), "required", "BLOB_READ_WRITE_TOKEN is needed for profile photos.");
  add("cron-secret", present(env.CRON_SECRET), "required", "CRON_SECRET protects the scheduled jobs.");

  add(
    "moderation-email",
    present(env.MODERATION_EMAIL),
    "recommended",
    present(env.MODERATION_EMAIL)
      ? "Daily report digest will be emailed."
      : "MODERATION_EMAIL is not set: new reports will not reach you (docs/MODERATION.md).",
  );
  add(
    "moderation-token",
    present(env.MODERATION_TOKEN) && env.MODERATION_TOKEN!.trim().length >= 24,
    "recommended",
    "MODERATION_TOKEN (24+ characters) enables dismissing reports and removing accounts.",
  );
  add("web-origin", present(env.WEB_APP_ORIGIN), "recommended", "WEB_APP_ORIGIN restricts which website may call the API.");

  return checks;
}

export function isReady(checks: ReadinessCheck[]): boolean {
  return checks.every((c) => c.ok || c.level !== "required");
}
