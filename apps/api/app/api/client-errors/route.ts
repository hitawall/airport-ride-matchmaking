import { NextResponse } from "next/server";
import { z } from "zod";
import { jsonError } from "@/lib/api-response";
import { reportError } from "@/lib/telemetry/errors";

const MAX_BODY_BYTES = 8 * 1024;
const MAX_PER_MINUTE = 20;

const bodySchema = z.object({
  name: z.string().max(120).default("Error"),
  message: z.string().max(1000),
  stack: z.string().max(4000).optional(),
  platform: z.enum(["android", "ios", "web", "other"]),
  appVersion: z.string().max(32).regex(/^[\w.+-]*$/),
});

// Best-effort flood guard per server instance (serverless instances are
// short-lived, so this limits bursts, not a determined attacker). The payload
// is also size-capped and scrubbed, and nothing is stored in our database.
const recent = new Map<string, number[]>();

function tooMany(ip: string): boolean {
  const now = Date.now();
  const hits = (recent.get(ip) ?? []).filter((t) => now - t < 60_000);
  hits.push(now);
  recent.set(ip, hits);
  if (recent.size > 500) recent.clear();
  return hits.length > MAX_PER_MINUTE;
}

/**
 * Crash and error reports from the app. Public on purpose (errors can happen
 * before sign-in), so the body is capped, scrubbed of emails and phone numbers,
 * and only forwarded to the error tracker when SENTRY_DSN is set.
 */
export async function POST(request: Request) {
  const ip = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
  if (tooMany(ip)) return jsonError("Too many reports", 429);

  const text = await request.text();
  if (text.length > MAX_BODY_BYTES) return jsonError("Report too large", 413);

  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch {
    return jsonError("Invalid report", 400);
  }
  const parsed = bodySchema.safeParse(json);
  if (!parsed.success) return jsonError("Invalid report", 400);

  const { name, message, stack, platform, appVersion } = parsed.data;
  await reportError(
    { name, message, stack },
    { source: "app", platform, release: appVersion ? `app-${appVersion}` : undefined },
  );
  return new NextResponse(null, { status: 204 });
}
