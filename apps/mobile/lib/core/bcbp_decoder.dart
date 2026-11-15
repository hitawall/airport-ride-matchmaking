/// Decodes the mandatory fields of an IATA Bar Coded Boarding Pass (BCBP,
/// Resolution 792) "M" format string -- the data encoded in the PDF417/QR
/// barcode printed on nearly every boarding pass. Only the fixed-width
/// mandatory fields are read; airline-specific conditional fields are
/// ignored.
///
/// BCBP has no year or time field -- only a day-of-year ("Julian date") for
/// the flight. [flightDate] resolves that to the closest matching calendar
/// date to [now] (a boarding pass is always scanned at or shortly before the
/// trip, never long after).
class BoardingPassData {
  const BoardingPassData({
    required this.carrier,
    required this.flightNumber,
    required this.fromAirport,
    required this.toAirport,
    required this.flightDate,
  });

  final String carrier;
  final String flightNumber;
  final String fromAirport;
  final String toAirport;
  final DateTime flightDate;

  /// e.g. "AC834"
  String get carrierFlightNumber => "$carrier$flightNumber";
}

/// Returns null if [raw] is too short or isn't a recognized "M"-format BCBP
/// string -- callers should fall back to manual entry in that case.
BoardingPassData? decodeBoardingPass(String raw, {DateTime? now}) {
  if (raw.length < 60 || raw[0] != "M") return null;

  final fromAirport = raw.substring(30, 33).trim();
  final toAirport = raw.substring(33, 36).trim();
  final carrier = raw.substring(36, 39).trim();
  final flightNumberRaw = raw.substring(39, 44).trim();
  final julianDateRaw = raw.substring(44, 47);

  final julianDay = int.tryParse(julianDateRaw);
  if (julianDay == null || julianDay < 1 || julianDay > 366) return null;
  if (carrier.isEmpty || flightNumberRaw.isEmpty) return null;

  // Flight numbers are zero-padded digits with an optional trailing letter
  // suffix (e.g. "0834 " -> "834", "012A " -> "12A").
  final suffixMatch = RegExp(r"^0*(\d+)([A-Z]?)$").firstMatch(flightNumberRaw);
  final flightNumber = suffixMatch == null
      ? flightNumberRaw
      : "${suffixMatch.group(1)}${suffixMatch.group(2)}";

  return BoardingPassData(
    carrier: carrier,
    flightNumber: flightNumber,
    fromAirport: fromAirport,
    toAirport: toAirport,
    flightDate: _resolveJulianDate(julianDay, now ?? DateTime.now()),
  );
}

DateTime _resolveJulianDate(int julianDay, DateTime now) {
  DateTime candidateForYear(int year) =>
      DateTime(year, 1, 1).add(Duration(days: julianDay - 1));

  final thisYear = candidateForYear(now.year);
  // A boarding pass is scanned at or shortly before travel -- if the
  // day-of-year already looks more than a couple of days in the past for
  // the current year, it must mean next year's occurrence (e.g. scanning
  // a Jan 1 flight on New Year's Eve).
  if (thisYear.isBefore(now.subtract(const Duration(days: 2)))) {
    return candidateForYear(now.year + 1);
  }
  return thisYear;
}
