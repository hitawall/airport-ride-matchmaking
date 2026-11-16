import "package:flutter_test/flutter_test.dart";
import "package:mobile/core/bcbp_decoder.dart";

/// The layout of a real IndiGo pass (carried in an Aztec code), with the
/// passenger name and booking reference replaced by made-up values.
final _indigoAztec =
    "M1${"DOE/JANE".padRight(20)} ABC123 DELBLR6E 0880 317Y010E0117 148>5181  6316B6E 00000000000002A0000000000000 0   6E 000000000        15KN";

void main() {
  test("reads the flight from an IndiGo boarding pass", () {
    final pass = decodeBoardingPass(_indigoAztec, now: DateTime(2026, 11, 12));
    expect(pass, isNotNull);
    expect(pass!.carrier, "6E");
    expect(pass.flightNumber, "880");
    expect(pass.carrierFlightNumber, "6E880");
    expect(pass.fromAirport, "DEL");
    expect(pass.toAirport, "BLR");
    expect(pass.flightDate, DateTime(2026, 11, 13));
  });

  test("keeps a letter suffix and drops zero padding", () {
    final raw = "M1${"DOE/JOHN".padRight(20)} ABC123 BLRDEL6E 012A 100Y001A0001 100";
    final pass = decodeBoardingPass(raw.padRight(70), now: DateTime(2026, 4, 10));
    expect(pass!.flightNumber, "12A");
  });

  test("a day that already passed this year means next year", () {
    final pass = decodeBoardingPass(_indigoAztec, now: DateTime(2026, 12, 30));
    expect(pass!.flightDate.year, 2027);
  });

  test("rejects text that is not a boarding pass", () {
    expect(decodeBoardingPass("https://example.com/not-a-pass"), isNull);
    expect(decodeBoardingPass("M1SHORT"), isNull);
    expect(decodeBoardingPass(""), isNull);
  });
}
