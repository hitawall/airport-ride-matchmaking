import { Resend } from "resend";
import { env } from "@/lib/env";
import type { OtpChannel } from "./channel";

let _resend: Resend | null = null;

function resend() {
  if (!_resend) _resend = new Resend(env.resendApiKey);
  return _resend;
}

export class EmailOtpChannel implements OtpChannel {
  async send(recipient: string, code: string): Promise<void> {
    const { error } = await resend().emails.send({
      from: env.otpFromEmail,
      to: recipient,
      subject: "Your Airport Ride Matchmaking verification code",
      text: `Your verification code is ${code}. It expires in 5 minutes. If you didn't request this, you can ignore this email.`,
    });
    if (error) throw new Error(`Resend send failed: ${error.message}`);
  }
}
