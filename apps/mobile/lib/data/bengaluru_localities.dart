class Locality {
  const Locality(this.label, this.lat, this.lng);
  final String label;
  final double lat;
  final double lng;
}

/// Curated destination list for the MVP's airport->home matching. Matches the
/// "bucket by known locality" approach identified as the right MVP-scale
/// granularity -- precise geocoding/autocomplete can replace this once
/// GOOGLE_MAPS_API_KEY is provisioned. Expanded for broader coverage and
/// filtered via a text search in the destination picker (see
/// create_ride_request_screen.dart) rather than a long static dropdown.
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
  Locality("MG Road", 12.9757, 77.6061),
  Locality("Brigade Road", 12.9716, 77.6079),
  Locality("Ulsoor", 12.9815, 77.6210),
  Locality("Domlur", 12.9609, 77.6387),
  Locality("CV Raman Nagar", 12.9830, 77.6650),
  Locality("Bellandur", 12.9255, 77.6761),
  Locality("Bannerghatta Road", 12.8845, 77.5972),
  Locality("Kanakapura Road", 12.8995, 77.5584),
  Locality("Basavanagudi", 12.9423, 77.5736),
  Locality("Vijayanagar", 12.9719, 77.5341),
  Locality("RT Nagar", 13.0210, 77.5938),
  Locality("Sadashivanagar", 13.0070, 77.5810),
  Locality("Sanjaynagar", 13.0258, 77.5750),
  Locality("Yeshwanthpur", 13.0280, 77.5540),
  Locality("Peenya", 13.0280, 77.5200),
  Locality("Nagarbhavi", 12.9646, 77.5059),
  Locality("Mysore Road", 12.9440, 77.5290),
  Locality("Vidyaranyapura", 13.0656, 77.5590),
  Locality("Hennur", 13.0330, 77.6390),
  Locality("Kalyan Nagar", 13.0230, 77.6390),
  Locality("Banaswadi", 13.0140, 77.6500),
  Locality("KR Puram", 12.9975, 77.6960),
  Locality("Mahadevapura", 12.9890, 77.6950),
  Locality("Varthur", 12.9412, 77.7440),
  Locality("Sarjapur", 12.8610, 77.7800),
  Locality("Begur", 12.8700, 77.6350),
  Locality("Jigani", 12.7825, 77.6355),
  Locality("Hosur Road", 12.8900, 77.6300),
  Locality("Chandra Layout", 12.9560, 77.5290),
  Locality("Vijayanagar West", 12.9680, 77.5190),
  Locality("Girinagar", 12.9340, 77.5560),
  Locality("Ramamurthy Nagar", 13.0160, 77.6680),
  Locality("Horamavu", 13.0330, 77.6530),
  Locality("Thanisandra", 13.0580, 77.6240),
  Locality("Bagalur", 13.1270, 77.6400),
  Locality("Devanahalli", 13.2437, 77.7120),
  Locality("Hoskote", 13.0700, 77.7980),
  Locality("Attibele", 12.7760, 77.7700),
  Locality("Chandapura", 12.8030, 77.7080),
  Locality("Yelachenahalli", 12.8890, 77.5750),
  Locality("Uttarahalli", 12.8988, 77.5460),
  Locality("Kengeri", 12.9055, 77.4850),
  Locality("Rajarajeshwari Nagar", 12.9270, 77.5170),
];
