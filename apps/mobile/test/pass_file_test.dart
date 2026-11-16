import "package:flutter_test/flutter_test.dart";
import "package:mobile/features/ride_request/pass_file.dart";

final _pass =
    "M1${"DOE/JANE".padRight(20)} ABC123 DELBLR6E 0880 317Y010E0117 148>5181  6316B6E 00000000000002A0000000000000 0   6E 000000000        15KN";

void main() {
  test("a boarding pass barcode gives the flight", () {
    final result = interpretPassBarcodes([_pass]);
    expect(result.data?.carrierFlightNumber, "6E880");
    expect(result.message, isNull);
  });

  test("finds the boarding pass among other barcodes in the file", () {
    final result = interpretPassBarcodes(["https://example.com/ticket", _pass]);
    expect(result.data?.carrierFlightNumber, "6E880");
  });

  test("a file with no barcode says so in plain words", () {
    final result = interpretPassBarcodes([]);
    expect(result.data, isNull);
    expect(result.message, contains("couldn't find a barcode"));
  });

  test("a barcode that is not a boarding pass is explained", () {
    final result = interpretPassBarcodes(["https://example.com/ticket"]);
    expect(result.data, isNull);
    expect(result.message, contains("isn't from a boarding pass"));
  });
}
