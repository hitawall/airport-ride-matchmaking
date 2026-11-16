/// A country whose phone numbers we accept. Adding one later is a single entry
/// in [supportedPhoneCountries] (and the matching one in
/// apps/api/lib/phone.ts): the dial code, the pattern of the national number
/// (without the trunk zero), an example for the hint and the error message.
class PhoneCountry {
  const PhoneCountry({
    required this.iso,
    required this.name,
    required this.dialCode,
    required this.nationalPattern,
    required this.example,
    required this.invalidMessage,
    this.trunkPrefix = "0",
  });

  final String iso;
  final String name;

  /// Digits only, no plus sign: "91".
  final String dialCode;
  final String nationalPattern;
  final String example;
  final String invalidMessage;
  final String trunkPrefix;

  String get label => "+$dialCode";
}

const supportedPhoneCountries = [
  PhoneCountry(
    iso: "IN",
    name: "India",
    dialCode: "91",
    nationalPattern: r"^[6-9]\d{9}$",
    example: "98765 43210",
    invalidMessage: "Enter a valid 10-digit Indian mobile number",
  ),
];

final defaultPhoneCountry = supportedPhoneCountries.first;

/// Normalizes [input] to E.164 (`+919876543210`) when it is a valid mobile
/// number for [country] (or, when null, for any supported country); otherwise
/// returns null. Accepts the usual ways of typing an Indian number:
/// `9876543210`, `09876543210`, `919876543210`, `+91 98765-43210`, with spaces,
/// dashes, dots and brackets.
String? normalizePhoneNumber(String input, {PhoneCountry? country}) {
  final compact = input.replaceAll(RegExp(r"[\s\-.()]"), "");
  if (!RegExp(r"^\+?\d+$").hasMatch(compact)) return null;
  final hasPlus = compact.startsWith("+");
  final digits = hasPlus ? compact.substring(1) : compact;

  for (final candidate in country == null ? supportedPhoneCountries : [country]) {
    String? national;
    if (digits.startsWith(candidate.dialCode) &&
        (hasPlus || digits.length == candidate.dialCode.length + 10)) {
      national = digits.substring(candidate.dialCode.length);
    } else if (!hasPlus) {
      national = digits.startsWith(candidate.trunkPrefix)
          ? digits.substring(candidate.trunkPrefix.length)
          : digits;
    }
    if (national != null && RegExp(candidate.nationalPattern).hasMatch(national)) {
      return "+${candidate.dialCode}$national";
    }
  }
  return null;
}

/// How to show a stored number in the input field: without the country code
/// when it belongs to a supported country, unchanged otherwise.
String phoneForInput(String? stored) {
  if (stored == null || stored.isEmpty) return "";
  for (final country in supportedPhoneCountries) {
    final prefix = "+${country.dialCode}";
    if (stored.startsWith(prefix)) return stored.substring(prefix.length);
  }
  return stored;
}
