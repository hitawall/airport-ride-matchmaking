import "package:flutter_test/flutter_test.dart";
import "package:mobile/core/phone.dart";

void main() {
  group("normalizePhoneNumber", () {
    test("accepts the usual ways of typing an Indian mobile number", () {
      for (final input in [
        "9876543210",
        "+919876543210",
        "919876543210",
        "09876543210",
        "+91 98765 43210",
        "98765-43210",
        " (98765) 43210 ",
        "+91-98765.43210",
      ]) {
        expect(normalizePhoneNumber(input), "+919876543210", reason: input);
      }
    });

    test("treats a 10-digit number that happens to start with 91 as a local number", () {
      expect(normalizePhoneNumber("9198765432"), "+919198765432");
    });

    test("rejects numbers that are not valid Indian mobiles", () {
      for (final input in [
        "",
        "5876543210", // must start with 6 to 9
        "987654321", // 9 digits
        "98765432101", // 11 digits, no trunk prefix
        "+14155552671", // US number
        "+9198765432", // too short
        "abc9876543210",
        "98765 4321O", // letter O
        "+91+9876543210",
        "919876543210123",
      ]) {
        expect(normalizePhoneNumber(input), isNull, reason: input);
      }
    });

    test("respects a specific country", () {
      expect(normalizePhoneNumber("9876543210", country: defaultPhoneCountry), "+919876543210");
    });
  });

  group("phoneForInput", () {
    test("drops the country code of a supported country", () {
      expect(phoneForInput("+919876543210"), "9876543210");
    });

    test("leaves other values untouched and handles empty", () {
      expect(phoneForInput("+14155552671"), "+14155552671");
      expect(phoneForInput(null), "");
      expect(phoneForInput(""), "");
    });
  });
}
