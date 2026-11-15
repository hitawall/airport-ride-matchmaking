import { env } from "@/lib/env";
import type { OtpChannel } from "./channel";
import { EmailOtpChannel } from "./email-channel";
import { NoopOtpChannel } from "./noop-channel";

export type { OtpChannel } from "./channel";

let _channel: OtpChannel | null = null;

/** Picks the active OTP delivery strategy. Today this is a single choice
 * (email, or a no-op in trial mode); if a second channel is ever added
 * alongside it, this is the one place that changes. */
export function getOtpChannel(): OtpChannel {
  if (!_channel) {
    _channel = env.otpTestMode ? new NoopOtpChannel() : new EmailOtpChannel();
  }
  return _channel;
}
