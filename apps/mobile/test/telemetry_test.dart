import "package:flutter_test/flutter_test.dart";
import "package:mobile/core/telemetry.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("opting out is remembered for the run even where storage is unavailable", () async {
    await Telemetry.setEnabled(false);
    expect(Telemetry.enabled, isFalse);
    await Telemetry.setEnabled(true);
    expect(Telemetry.enabled, isTrue);
  });

  test("reporting is a silent no-op when disabled", () async {
    await Telemetry.setEnabled(false);
    // Must not throw or make a network call.
    await Telemetry.reportError(StateError("boom"), StackTrace.current);
    await Telemetry.setEnabled(true);
  });
}
