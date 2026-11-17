import { createHmac } from "node:crypto";

/**
 * Product analytics. Off until POSTHOG_API_KEY is set; with it unset every
 * call is a no-op, so the app runs identically without it.
 *
 * Privacy rules (see docs/TELEMETRY.md):
 *  - The person is an opaque id derived from the user id with a server secret
 *    (HMAC), never the email, phone or name. Once an account is deleted nothing
 *    can link that id back to anyone.
 *  - Properties are coarse, fixed fields chosen by the call site. Never pass
 *    message text, addresses, names, emails or phone numbers.
 *  - Failures are swallowed: telemetry must never break a request.
 */
export type TelemetryEvent =
  | "account_created"
  | "otp_verified"
  | "google_sign_in"
  | "ride_request_created"
  | "match_like"
  | "match_pass"
  | "mutual_match_created"
  | "match_unmatched"
  | "message_sent"
  | "rating_given"
  | "report_filed"
  | "block_created"
  | "feedback_submitted"
  | "account_deleted"
  | "app_opened";

export type EventProps = Record<string, string | number | boolean | null>;

const SEND_TIMEOUT_MS = 1500;

/** Stable opaque id for a user. Falls back to JWT_SECRET so no extra setup is needed. */
export function pseudonymize(userId: string): string {
  const salt = process.env.TELEMETRY_ID_SALT || process.env.JWT_SECRET || "dev-only-salt";
  return createHmac("sha256", salt).update(userId).digest("hex").slice(0, 32);
}

export function telemetryEnabled(): boolean {
  return !!process.env.POSTHOG_API_KEY;
}

export async function track(event: TelemetryEvent, userId: string, props: EventProps = {}): Promise<void> {
  const key = process.env.POSTHOG_API_KEY;
  if (!key) return;
  const host = (process.env.POSTHOG_HOST || "https://us.i.posthog.com").replace(/\/$/, "");
  try {
    await fetch(`${host}/capture/`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      signal: AbortSignal.timeout(SEND_TIMEOUT_MS),
      body: JSON.stringify({
        api_key: key,
        event,
        distinct_id: pseudonymize(userId),
        properties: {
          ...props,
          // No IP-based location or person profile for server-side events.
          $ip: null,
          $process_person_profile: false,
          environment: process.env.VERCEL_ENV ?? "local",
          release: process.env.VERCEL_GIT_COMMIT_SHA?.slice(0, 7) ?? "dev",
        },
      }),
    });
  } catch (error) {
    console.error("telemetry: send failed", error instanceof Error ? error.name : "unknown");
  }
}
