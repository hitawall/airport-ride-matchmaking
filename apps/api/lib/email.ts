import { Resend } from "resend";

const CREAM = "#FBF3E7";
const SURFACE_WHITE = "#FFFDF9";
const CORAL = "#E8604B";
const PLUM = "#4A2545";
const INK = "#241F21";
const DIVIDER = "#EADFCB";

export function escapeHtml(text: string): string {
  return text
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

/** True when emails can be sent at all (Resend key and a sender address set). */
export function emailConfigured(): boolean {
  return !!process.env.RESEND_API_KEY && !!process.env.OTP_FROM_EMAIL;
}

/** The web app's address, used for links in emails. No trailing slash. */
export function webAppUrl(): string | null {
  const origin = process.env.WEB_APP_ORIGIN?.trim().replace(/\/$/, "");
  return origin && origin !== "*" ? origin : null;
}

export interface ServiceEmail {
  to: string;
  subject: string;
  heading: string;
  /** Plain-text paragraphs; escaped for the HTML version. */
  paragraphs: string[];
  /** Optional button; the link is also printed in the plain-text version. */
  action?: { label: string; url: string };
}

function renderHtml({ heading, paragraphs, action }: ServiceEmail): string {
  const body = paragraphs
    .map(
      (p) =>
        `<p style="margin:0 0 12px 0;color:${INK};font-size:15px;line-height:1.6;">${escapeHtml(p)}</p>`,
    )
    .join("");
  const button = action
    ? `<tr><td style="padding:8px 32px 8px 32px;"><a href="${escapeHtml(action.url)}" style="display:inline-block;background-color:${CORAL};color:#ffffff;text-decoration:none;font-weight:700;font-size:15px;padding:14px 24px;border-radius:14px;">${escapeHtml(action.label)}</a></td></tr>`
    : "";
  return `<!DOCTYPE html>
<html><body style="margin:0;padding:0;background-color:${CREAM};font-family:Georgia,'Times New Roman',serif;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:${CREAM};padding:40px 16px;"><tr><td align="center">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:440px;background-color:${SURFACE_WHITE};border-radius:24px;overflow:hidden;">
<tr><td style="background-color:${PLUM};padding:24px 32px;"><span style="color:${CREAM};font-size:18px;font-weight:700;">&#9992;&nbsp; Airport Ride Matchmaking</span></td></tr>
<tr><td style="padding:32px 32px 12px 32px;"><p style="margin:0 0 12px 0;color:${INK};font-size:22px;font-weight:700;">${escapeHtml(heading)}</p>${body}</td></tr>
${button}
<tr><td style="padding:20px 32px 28px 32px;"><div style="border-top:1px solid ${DIVIDER};padding-top:14px;"><p style="margin:0;color:${INK};font-size:12px;line-height:1.6;opacity:0.6;">You are getting this because of activity on your account. We never put your messages in emails.</p></div></td></tr>
</table></td></tr></table></body></html>`;
}

/** Sends one service email. Returns false (and logs) on any failure; never throws. */
export async function sendServiceEmail(email: ServiceEmail): Promise<boolean> {
  if (!emailConfigured()) return false;
  try {
    const text = [
      email.heading,
      "",
      ...email.paragraphs,
      ...(email.action ? ["", `${email.action.label}: ${email.action.url}`] : []),
    ].join("\n");
    const { error } = await new Resend(process.env.RESEND_API_KEY).emails.send({
      from: process.env.OTP_FROM_EMAIL!,
      to: email.to,
      subject: email.subject,
      text,
      html: renderHtml(email),
    });
    if (error) throw new Error(error.message);
    return true;
  } catch (error) {
    console.error("service email failed", error instanceof Error ? error.message : error);
    return false;
  }
}
