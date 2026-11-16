import "package:flutter_test/flutter_test.dart";
import "package:mobile/features/matching/fare_split.dart";

// Kempegowda Airport and a few real Bengaluru areas.
const _airportLat = 13.1986, _airportLng = 77.7066;
const _koramangala = SplitRider(id: "a", name: "Asha", lat: 12.9352, lng: 77.6245);
const _indiranagar = SplitRider(id: "b", name: "Ravi", lat: 12.9719, lng: 77.6412);
const _whitefield = SplitRider(id: "c", name: "Meera", lat: 12.9698, lng: 77.7500);
const _electronicCity = SplitRider(id: "d", name: "Dev", lat: 12.8452, lng: 77.6602);

FareSplit _split(List<SplitRider> riders) =>
    suggestFareSplit(airportLat: _airportLat, airportLng: _airportLng, riders: riders);

double _fraction(FareSplit s, String id) => s.shares.firstWhere((x) => x.riderId == id).fraction;

void main() {
  test("distance is about right: airport to Indiranagar is roughly 28 km as the crow flies", () {
    final km = distanceKm(_airportLat, _airportLng, _indiranagar.lat, _indiranagar.lng);
    expect(km, inInclusiveRange(25, 31));
  });

  test("same destination splits evenly", () {
    final split = _split([_indiranagar, const SplitRider(id: "x", name: "Neighbour", lat: 12.9719, lng: 77.6412)]);
    expect(_fraction(split, "b"), closeTo(0.5, 1e-9));
    expect(_fraction(split, "x"), closeTo(0.5, 1e-9));
  });

  test("whoever is dropped nearer pays less, and shares add up to 100%", () {
    // Indiranagar is nearer the airport than Koramangala.
    final split = _split([_koramangala, _indiranagar]);
    expect(_fraction(split, "b"), lessThan(0.5));
    expect(_fraction(split, "a"), greaterThan(0.5));
    expect(split.shares.fold<double>(0, (a, s) => a + s.fraction), closeTo(1, 1e-9));
    expect(split.legs.length, 2);
    expect(split.legs.first.riderNames, ["Ravi", "Asha"]); // shared leg: both in the cab
    expect(split.legs.last.riderNames, ["Asha"]); // the extra leg is only theirs
  });

  test("the order riders are listed in does not change anyone's share", () {
    final one = _split([_koramangala, _indiranagar]);
    final two = _split([_indiranagar, _koramangala]);
    expect(_fraction(one, "a"), closeTo(_fraction(two, "a"), 1e-12));
    expect(_fraction(one, "b"), closeTo(_fraction(two, "b"), 1e-12));
  });

  test("a rider going the opposite way pays for nearly their own full trip", () {
    // Whitefield (east) vs Electronic City (south): little in common.
    final split = _split([_whitefield, _electronicCity]);
    expect(_fraction(split, "c"), inInclusiveRange(0.3, 0.7));
    expect(split.shares.fold<double>(0, (a, s) => a + s.fraction), closeTo(1, 1e-9));
  });

  test("works for three riders: the farthest pays the most", () {
    final split = _split([_indiranagar, _koramangala, _electronicCity]);
    final shares = {for (final s in split.shares) s.riderId: s.fraction};
    expect(shares["b"]!, lessThan(shares["a"]!));
    expect(shares["a"]!, lessThan(shares["d"]!));
    expect(shares.values.fold<double>(0, (a, b) => a + b), closeTo(1, 1e-9));
  });

  test("rupee amounts always add up to the fare", () {
    final split = _split([_koramangala, _indiranagar]);
    for (final fare in [100.0, 849.0, 1250.0, 1999.0]) {
      final amounts = split.amountsFor(fare);
      expect(amounts.fold<int>(0, (a, b) => a + b), fare.round());
    }
  });

  test("nobody gets a share when there are no riders", () {
    expect(_split(const []).shares, isEmpty);
  });
}
