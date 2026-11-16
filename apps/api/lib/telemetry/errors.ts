import { randomUUID } from "node:crypto";

/**
 * Error reporting. Always logs a structured line to the Vercel logs; also
 * forwards to Sentry when SENTRY_DSN is set (a plain HTTPS call, no SDK).
 * Callers must pass only route names, status codes and error text -- never
 * request bodies, headers, emails, phone numbers or message text.
 */
export interface ErrorContext {
  source: "api" | "app";
  route?: string;
  method?: string;
  status?: number;
  platform?: string;
  release?: string;
  tags?: Record<string, string>;
}

const EMAIL = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi;
const LONG_DIGITS = /\+?\d[\d\s().-]{8,}\d/g;
const MAX_TEXT = 2000;

/** Removes anything that looks like an email address or phone number, and caps length. */
export function scrub(text: string): string {
  return text.replace(EMAIL, "[email]").replace(LONG_DIGITS, "[number]").slice(0, MAX_TEXT);
}

interface ParsedDsn {
  endpoint: string;
  publicKey: string;
  dsn: string;
}

function parseDsn(dsn: string | undefined): ParsedDsn | null {
  if (!dsn) return null;
  try {
    const url = new URL(dsn);
    const projectId = url.pathname.replace(/^\//, "");
    if (!url.username || !projectId) return null;
    return {
      endpoint: `${url.protocol}//${url.host}/api/${projectId}/envelope/`,
      publicKey: url.username,
      dsn,
    };
  } catch {
    return null;
  }
}

export async function reportError(
  error: { name?: string; message: string; stack?: string },
  context: ErrorContext,
): Promise<void> {
  const name = scrub(error.name ?? "Error");
  const message = scrub(error.message);
  const stack = error.stack ? scrub(error.stack) : undefined;

  console.error(
    JSON.stringify({
      level: "error",
      source: context.source,
      route: context.route,
      method: context.method,
      status: context.status,
      name,
      message,
    }),
  );

  const dsn = parseDsn(process.env.SENTRY_DSN);
  if (!dsn) return;

  const eventId = randomUUID().replaceAll("-", "");
  const release = context.release ?? process.env.VERCEL_GIT_COMMIT_SHA?.slice(0, 7) ?? "dev";
  const event = {
    event_id: eventId,
    timestamp: Date.now() / 1000,
    platform: context.source === "api" ? "node" : "other",
    level: "error",
    release,
    environment: process.env.VERCEL_ENV ?? "local",
    tags: {
      source: context.source,
      ...(context.route && { route: context.route }),
      ...(context.status !== undefined && { status: String(context.status) }),
      ...(context.platform && { client_platform: context.platform }),
      ...context.tags,
    },
    exception: { values: [{ type: name, value: message, ...(stack && { stacktrace: { frames: [{ filename: stack }] } }) }] },
  };
  const envelope = [
    JSON.stringify({ event_id: eventId, sent_at: new Date().toISOString(), dsn: dsn.dsn }),
    JSON.stringify({ type: "event" }),
    JSON.stringify(event),
  ].join("\n");

  try {
    await fetch(dsn.endpoint, {
      method: "POST",
      headers: {
        "content-type": "application/x-sentry-envelope",
        "x-sentry-auth": `Sentry sentry_version=7, sentry_key=${dsn.publicKey}, sentry_client=airport-ride/1.0`,
      },
      signal: AbortSignal.timeout(1500),
      body: envelope,
    });
  } catch {
    // Reporting must never throw.
  }
}
