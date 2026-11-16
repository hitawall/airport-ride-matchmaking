import "package:flutter_riverpod/flutter_riverpod.dart";
import "../core/api_client.dart";

class Locality {
  const Locality(this.label, this.lat, this.lng);
  final String label;
  final double lat;
  final double lng;

  factory Locality.fromJson(Map<String, dynamic> json) =>
      Locality(json["label"] as String, (json["lat"] as num).toDouble(), (json["lng"] as num).toDouble());
}

class Terminal {
  const Terminal({required this.code, required this.name});
  final String code;
  final String name;

  factory Terminal.fromJson(Map<String, dynamic> json) =>
      Terminal(code: json["code"] as String, name: json["name"] as String);
}

class Airport {
  const Airport({
    required this.code,
    required this.name,
    required this.city,
    required this.terminals,
    required this.localities,
  });

  final String code;
  final String name;
  final String city;
  final List<Terminal> terminals;
  final List<Locality> localities;

  factory Airport.fromJson(Map<String, dynamic> json) => Airport(
    code: json["code"] as String,
    name: json["name"] as String,
    city: json["city"] as String,
    terminals: (json["terminals"] as List).map((t) => Terminal.fromJson(t as Map<String, dynamic>)).toList(),
    localities: (json["localities"] as List).map((l) => Locality.fromJson(l as Map<String, dynamic>)).toList(),
  );
}

/// The airports the server supports, loaded from `GET /api/airports`. Adding an
/// airport or terminal there needs no app release (see docs/AIRPORTS.md).
class AirportCatalog {
  const AirportCatalog({required this.airports, required this.defaultAirportCode});

  final List<Airport> airports;
  final String defaultAirportCode;

  Airport get defaultAirport => airports.firstWhere(
    (a) => a.code == defaultAirportCode,
    orElse: () => airports.first,
  );

  factory AirportCatalog.fromJson(Map<String, dynamic> json) => AirportCatalog(
    airports: (json["airports"] as List).map((a) => Airport.fromJson(a as Map<String, dynamic>)).toList(),
    defaultAirportCode: json["defaultAirportCode"] as String,
  );
}

final airportCatalogProvider = FutureProvider<AirportCatalog>((ref) async {
  final json = await ApiClient().get("/api/airports") as Map<String, dynamic>;
  return AirportCatalog.fromJson(json);
});

/// Short label for where people meet, e.g. "BLR · Terminal 2" or "BLR" for
/// older requests that have no terminal.
String airportTerminalLabel(String? airportCode, String? terminal) {
  final code = airportCode ?? "";
  if (terminal == null || terminal.isEmpty) return code;
  // Terminals are stored as codes like "T2"; show them as "Terminal 2".
  final readable = RegExp(r"^T(\d+)$").firstMatch(terminal);
  final name = readable == null ? terminal : "Terminal ${readable.group(1)}";
  return code.isEmpty ? name : "$code · $name";
}
