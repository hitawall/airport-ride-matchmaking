import { Resend } from "resend";
import { env } from "@/lib/env";
import type { OtpChannel } from "./channel";

let _resend: Resend | null = null;

function resend() {
  if (!_resend) _resend = new Resend(env.resendApiKey);
  return _resend;
}

const CREAM = "#FBF3E7";
const SURFACE_WHITE = "#FFFDF9";
const CORAL = "#E8604B";
const PLUM = "#4A2545";
const INK = "#241F21";
const DIVIDER = "#EADFCB";

function otpEmailHtml(code: string): string {
  return `<!DOCTYPE html>
<html>
  <body style="margin:0;padding:0;background-color:${CREAM};font-family:Georgia,'Times New Roman',serif;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:${CREAM};padding:40px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:420px;background-color:${SURFACE_WHITE};border-radius:24px;overflow:hidden;">
            <tr>
              <td style="background-color:${PLUM};padding:28px 32px;">
                <span style="color:${CREAM};font-size:20px;font-weight:700;letter-spacing:-0.3px;">&#9992;&nbsp; Airport Ride Matchmaking</span>
              </td>
            </tr>
            <tr>
              <td style="padding:36px 32px 12px 32px;">
                <p style="margin:0 0 4px 0;color:${INK};font-size:24px;font-weight:700;letter-spacing:-0.3px;">
                  Here's your code
                </p>
                <p style="margin:0;color:${INK};font-size:15px;line-height:1.6;opacity:0.75;">
                  Enter this to finish signing in. It expires in 5 minutes.
                </p>
              </td>
            </tr>
            <tr>
              <td style="padding:20px 32px 8px 32px;">
                <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                  <tr>
                    <td align="center" style="background-color:${CORAL};border-radius:16px;padding:18px 0;">
                      <span style="color:#ffffff;font-size:34px;font-weight:700;letter-spacing:10px;font-family:'Courier New',monospace;">${code}</span>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
            <tr>
              <td style="padding:20px 32px 32px 32px;">
                <div style="border-top:1px solid ${DIVIDER};padding-top:16px;">
                  <p style="margin:0;color:${INK};font-size:13px;line-height:1.6;opacity:0.6;">
                    Didn't request this? You can safely ignore this email -- no one can sign in without this code.
                  </p>
                </div>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

export class EmailOtpChannel implements OtpChannel {
  async send(recipient: string, code: string): Promise<void> {
    const { error } = await resend().emails.send({
      from: env.otpFromEmail,
      to: recipient,
      subject: "Your Airport Ride Matchmaking verification code",
      text: `Your verification code is ${code}. It expires in 5 minutes. If you didn't request this, you can ignore this email.`,
      html: otpEmailHtml(code),
    });
    if (error) throw new Error(`Resend send failed: ${error.message}`);
  }
}
