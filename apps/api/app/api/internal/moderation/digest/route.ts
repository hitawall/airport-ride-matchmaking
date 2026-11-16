import { NextResponse } from "next/server";
import { Resend } from "resend";
import { jsonError } from "@/lib/api-response";
import { env } from "@/lib/env";
import { hasBearer } from "@/lib/moderation/auth";
import {
  digestSubject,
  renderDigestHtml,
  renderDigestText,
  reportsSince,
} from "@/lib/moderation/digest";

const WINDOW_HOURS = 24;

/**
 * Daily moderation digest: emails the owner every report filed in the last 24
 * hours. Vercel Cron calls this with GET and the CRON_SECRET bearer token.
 * Sends nothing when there are no new reports or MODERATION_EMAIL is unset.
 */
async function handle(request: Request) {
  if (!hasBearer(request, process.env.CRON_SECRET)) return jsonError("Unauthorized", 401);

  const since = new Date(Date.now() - WINDOW_HOURS * 60 * 60 * 1000);
  const items = await reportsSince(since);
  if (items.length === 0) return NextResponse.json({ newReports: 0, emailed: false });

  const to = env.moderationEmail;
  if (!to) {
    return NextResponse.json({ newReports: items.length, emailed: false, reason: "MODERATION_EMAIL not set" });
  }

  const { error } = await new Resend(env.resendApiKey).emails.send({
    from: env.otpFromEmail,
    to,
    subject: digestSubject(items.length),
    text: renderDigestText(items),
    html: renderDigestHtml(items),
  });
  if (error) return jsonError(`Digest email failed: ${error.message}`, 502);

  return NextResponse.json({ newReports: items.length, emailed: true });
}

export const GET = handle;
export const POST = handle;
