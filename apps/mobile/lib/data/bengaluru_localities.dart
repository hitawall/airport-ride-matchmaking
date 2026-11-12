class Locality {
  const Locality(this.label, this.lat, this.lng);
  final String label;
  final double lat;
  final double lng;
}

/// Curated destination list for the MVP's airport->home matching. Matches the
/// "bucket by known locality" approach identified as the right MVP-scale
/// granularity -- precise geocoding/autocomplete can replace this once
/// GOOGLE_MAPS_API_KEY is provisioned.
const bengaluruLocalities = [
  Locality("Koramangala", 12.9352, 77.6245),
  Locality("Indiranagar", 12.9719, 77.6412),
  Locality("HSR Layout", 12.9121, 77.6446),
  Locality("Whitefield", 12.9698, 77.7500),
  Locality("Electronic City", 12.8452, 77.6602),
  Locality("Marathahalli", 12.9569, 77.7011),
  Locality("BTM Layout", 12.9166, 77.6101),
  Locality("Jayanagar", 12.9308, 77.5838),
  Locality("JP Nagar", 12.9077, 77.5851),
  Locality("Banashankari", 12.9255, 77.5468),
  Locality("Hebbal", 13.0355, 77.5971),
  Locality("Yelahanka", 13.1005, 77.5963),
  Locality("Malleshwaram", 13.0035, 77.5692),
  Locality("Rajajinagar", 12.9915, 77.5520),
  Locality("Sarjapur Road", 12.9010, 77.6870),
];
