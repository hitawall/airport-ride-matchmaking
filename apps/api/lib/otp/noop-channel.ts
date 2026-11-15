import type { OtpChannel } from "./channel";

/** Trial-only bypass: doesn't actually send anything. Paired with the fixed
 * test code accepted in the verify route. Never enable with real users. */
export class NoopOtpChannel implements OtpChannel {
  async send(): Promise<void> {}
}
