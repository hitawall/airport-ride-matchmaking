import "dart:math";

/// One rider and where they are going.
class SplitRider {
  const SplitRider({required this.id, required this.name, required this.lat, required this.lng});

  final String id;
  final String name;
  final double lat;
  final double lng;
}

/// A stretch of the route and who is in the cab for it.
class SplitLeg {
  const SplitLeg({required this.km, required this.riderNames});

  final double km;
  final List<String> riderNames;
}

/// One rider's suggested share of the fare.
class SplitShare {
  const SplitShare({required this.riderId, required this.name, required this.fraction});

  final String riderId;
  final String name;

  /// 0 to 1.
  final double fraction;

  int get percent => (fraction * 100).round();
}

class FareSplit {
  const FareSplit({required this.shares, required this.legs, required this.totalKm});

  final List<SplitShare> shares;
  final List<SplitLeg> legs;
  final double totalKm;

  /// Whole rupees for each rider, in the same order as [shares]. They always add
  /// up to the rounded total, with any odd rupee given to the biggest share.
  List<int> amountsFor(double totalFare) {
    final total = totalFare.round();
    final amounts = <int>[for (final s in shares) (total * s.fraction).round()];
    final diff = total - amounts.fold<int>(0, (a, b) => a + b);
    if (diff != 0 && amounts.isNotEmpty) {
      var biggest = 0;
      for (var i = 1; i < shares.length; i++) {
        if (shares[i].fraction > shares[biggest].fraction) biggest = i;
      }
      amounts[biggest] += diff;
    }
    return amounts;
  }
}

/// Straight-line distance in kilometres between two points (haversine).
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const earthKm = 6371.0;
  double rad(double d) => d * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = pow(sin(dLat / 2), 2) + cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLng / 2), 2);
  return 2 * earthKm * asin(min(1.0, sqrt(a)));
}

/// A suggested way to share a cab from the airport. Purely indicative: nothing
/// stores or enforces it.
///
/// The cab drops people off nearest first. Each stretch of the route is split
/// equally between everyone still in the cab for it, so the person dropped first
/// pays only their part of the shared stretch, and whoever goes further also pays
/// for the extra distance only they travel. Distances are straight-line, which is
/// simple and good enough for a suggestion. Works for any number of riders.
FareSplit suggestFareSplit({
  required double airportLat,
  required double airportLng,
  required List<SplitRider> riders,
}) {
  if (riders.isEmpty) return const FareSplit(shares: [], legs: [], totalKm: 0);

  final ordered = [...riders]
    ..sort((a, b) => distanceKm(airportLat, airportLng, a.lat, a.lng)
        .compareTo(distanceKm(airportLat, airportLng, b.lat, b.lng)));

  final legs = <SplitLeg>[];
  final owed = <String, double>{for (final r in ordered) r.id: 0};
  var fromLat = airportLat;
  var fromLng = airportLng;
  for (var i = 0; i < ordered.length; i++) {
    final stop = ordered[i];
    final km = distanceKm(fromLat, fromLng, stop.lat, stop.lng);
    final onBoard = ordered.sublist(i);
    legs.add(SplitLeg(km: km, riderNames: [for (final r in onBoard) r.name]));
    for (final r in onBoard) {
      owed[r.id] = owed[r.id]! + km / onBoard.length;
    }
    fromLat = stop.lat;
    fromLng = stop.lng;
  }

  final totalKm = legs.fold<double>(0, (a, l) => a + l.km);
  // Everyone going to the same place (or no distance at all): split evenly.
  final shares = [
    for (final r in riders)
      SplitShare(
        riderId: r.id,
        name: r.name,
        fraction: totalKm < 0.05 ? 1 / riders.length : owed[r.id]! / totalKm,
      ),
  ];
  return FareSplit(shares: shares, legs: legs, totalKm: totalKm);
}
