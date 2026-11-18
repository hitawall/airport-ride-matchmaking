/**
 * Countries whose phone numbers we accept. Adding a country later is one entry
 * here (and the matching one in apps/mobile/lib/core/phone.dart): its dial code
 * and the pattern of the national number, with no leading trunk zero.
 */
export const SUPPORTED_COUNTRIES = [
  { iso: "IN", dialCode: "91", nationalPattern: /^[6-9]\d{9}$/, trunkPrefix: "0" },
] as const;

export const DEFAULT_COUNTRY = SUPPORTED_COUNTRIES[0];

/**
 * Normalizes a phone number to E.164 (`+919876543210`) if it is a valid mobile
 * number for a supported country, otherwise returns null. Accepts the usual
 * ways of typing an Indian number: `9876543210`, `09876543210`,
 * `919876543210`, `+91 98765-43210`, with spaces, dashes, dots and brackets.
 */
export function normalizePhoneNumber(input: string): string | null {
  const compact = input.replace(/[\s\-.()]/g, "");
  if (!/^\+?\d+$/.test(compact)) return null;
  const hasPlus = compact.startsWith("+");
  const digits = compact.replace(/^\+/, "");

  for (const country of SUPPORTED_COUNTRIES) {
    let national: string | null = null;
    if (digits.startsWith(country.dialCode) && (hasPlus || digits.length === country.dialCode.length + 10)) {
      national = digits.slice(country.dialCode.length);
    } else if (!hasPlus) {
      national = digits.startsWith(country.trunkPrefix) ? digits.slice(country.trunkPrefix.length) : digits;
    }
    if (national && country.nationalPattern.test(national)) return `+${country.dialCode}${national}`;
  }
  return null;
}

/** Shown when a mobile number already belongs to another account. */
export const PHONE_TAKEN_MESSAGE =
  "That mobile number is already used by another account. Use a different number, or sign in with the email you first used.";
