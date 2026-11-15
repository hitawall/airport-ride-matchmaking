/**
 * Strategy interface for OTP delivery. Each channel (email today; WhatsApp,
 * SMS, etc. later) implements this the same way, so swapping or adding a
 * channel means writing a new class here -- the request/verify routes never
 * change.
 */
export interface OtpChannel {
  send(recipient: string, code: string): Promise<void>;
}
