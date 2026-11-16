import "package:flutter_test/flutter_test.dart";
import "package:mobile/core/ui/formatters.dart";

void main() {
  final now = DateTime(2026, 11, 16, 10, 0);

  group("formatTime", () {
    test("formats afternoon and midnight/noon edges", () {
      expect(formatTime(DateTime(2026, 11, 16, 14, 30)), "2:30 PM");
      expect(formatTime(DateTime(2026, 11, 16, 0, 5)), "12:05 AM");
      expect(formatTime(DateTime(2026, 11, 16, 12, 0)), "12:00 PM");
    });
  });

  group("formatFriendlyDateTime", () {
    test("says Today, Tomorrow and Yesterday", () {
      expect(formatFriendlyDateTime(DateTime(2026, 11, 16, 14, 30), now: now), "Today, 2:30 PM");
      expect(formatFriendlyDateTime(DateTime(2026, 11, 17, 9, 5), now: now), "Tomorrow, 9:05 AM");
      expect(formatFriendlyDateTime(DateTime(2026, 11, 15, 18, 0), now: now), "Yesterday, 6:00 PM");
    });

    test("falls back to weekday and date further out", () {
      expect(formatFriendlyDateTime(DateTime(2026, 11, 20, 18, 0), now: now), "Fri 20 Nov, 6:00 PM");
    });
  });
}
