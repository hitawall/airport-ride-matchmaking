/**
 * The airports the app serves. This is the single source of truth: the API
 * validates ride requests against it and the app loads it from
 * `GET /api/airports`, so adding an airport is a data change here (see
 * docs/AIRPORTS.md) and needs no app release.
 *
 * Matching only ever pairs people with the same airport AND the same terminal.
 */
export interface Terminal {
  /** Short stable id stored in the database, e.g. "T1". Never rename once used. */
  code: string;
  /** Shown to people, e.g. "Terminal 1". */
  name: string;
}

export interface Locality {
  label: string;
  lat: number;
  lng: number;
}

export interface Airport {
  /** IATA code, stored in the database, e.g. "BLR". Never change once used. */
  code: string;
  name: string;
  city: string;
  /** Where the airport is. Used only for the indicative fare split in the app. */
  lat: number;
  lng: number;
  terminals: Terminal[];
  /**
   * Curated destination list for airport -> home matching (bucketed by known
   * locality rather than free-text geocoding). Shown in the destination picker.
   */
  localities: Locality[];
}

export const DEFAULT_AIRPORT_CODE = "BLR";

export const AIRPORTS: Airport[] = [
  {
    code: "BLR",
    name: "Kempegowda International Airport",
    city: "Bengaluru",
    lat: 13.1986,
    lng: 77.7066,
    terminals: [
      { code: "T1", name: "Terminal 1" },
      { code: "T2", name: "Terminal 2" },
    ],
    localities: [
        { label: "Koramangala", lat: 12.9352, lng: 77.6245 },
        { label: "Indiranagar", lat: 12.9719, lng: 77.6412 },
        { label: "HSR Layout", lat: 12.9121, lng: 77.6446 },
        { label: "Whitefield", lat: 12.9698, lng: 77.7500 },
        { label: "Electronic City", lat: 12.8452, lng: 77.6602 },
        { label: "Marathahalli", lat: 12.9569, lng: 77.7011 },
        { label: "BTM Layout", lat: 12.9166, lng: 77.6101 },
        { label: "Jayanagar", lat: 12.9308, lng: 77.5838 },
        { label: "JP Nagar", lat: 12.9077, lng: 77.5851 },
        { label: "Banashankari", lat: 12.9255, lng: 77.5468 },
        { label: "Hebbal", lat: 13.0355, lng: 77.5971 },
        { label: "Yelahanka", lat: 13.1005, lng: 77.5963 },
        { label: "Malleshwaram", lat: 13.0035, lng: 77.5692 },
        { label: "Rajajinagar", lat: 12.9915, lng: 77.5520 },
        { label: "Sarjapur Road", lat: 12.9010, lng: 77.6870 },
        { label: "MG Road", lat: 12.9757, lng: 77.6061 },
        { label: "Brigade Road", lat: 12.9716, lng: 77.6079 },
        { label: "Ulsoor", lat: 12.9815, lng: 77.6210 },
        { label: "Domlur", lat: 12.9609, lng: 77.6387 },
        { label: "CV Raman Nagar", lat: 12.9830, lng: 77.6650 },
        { label: "Bellandur", lat: 12.9255, lng: 77.6761 },
        { label: "Bannerghatta Road", lat: 12.8845, lng: 77.5972 },
        { label: "Kanakapura Road", lat: 12.8995, lng: 77.5584 },
        { label: "Basavanagudi", lat: 12.9423, lng: 77.5736 },
        { label: "Vijayanagar", lat: 12.9719, lng: 77.5341 },
        { label: "RT Nagar", lat: 13.0210, lng: 77.5938 },
        { label: "Sadashivanagar", lat: 13.0070, lng: 77.5810 },
        { label: "Sanjaynagar", lat: 13.0258, lng: 77.5750 },
        { label: "Yeshwanthpur", lat: 13.0280, lng: 77.5540 },
        { label: "Peenya", lat: 13.0280, lng: 77.5200 },
        { label: "Nagarbhavi", lat: 12.9646, lng: 77.5059 },
        { label: "Mysore Road", lat: 12.9440, lng: 77.5290 },
        { label: "Vidyaranyapura", lat: 13.0656, lng: 77.5590 },
        { label: "Hennur", lat: 13.0330, lng: 77.6390 },
        { label: "Kalyan Nagar", lat: 13.0230, lng: 77.6390 },
        { label: "Banaswadi", lat: 13.0140, lng: 77.6500 },
        { label: "KR Puram", lat: 12.9975, lng: 77.6960 },
        { label: "Mahadevapura", lat: 12.9890, lng: 77.6950 },
        { label: "Varthur", lat: 12.9412, lng: 77.7440 },
        { label: "Sarjapur", lat: 12.8610, lng: 77.7800 },
        { label: "Begur", lat: 12.8700, lng: 77.6350 },
        { label: "Jigani", lat: 12.7825, lng: 77.6355 },
        { label: "Hosur Road", lat: 12.8900, lng: 77.6300 },
        { label: "Chandra Layout", lat: 12.9560, lng: 77.5290 },
        { label: "Vijayanagar West", lat: 12.9680, lng: 77.5190 },
        { label: "Girinagar", lat: 12.9340, lng: 77.5560 },
        { label: "Ramamurthy Nagar", lat: 13.0160, lng: 77.6680 },
        { label: "Horamavu", lat: 13.0330, lng: 77.6530 },
        { label: "Thanisandra", lat: 13.0580, lng: 77.6240 },
        { label: "Bagalur", lat: 13.1270, lng: 77.6400 },
        { label: "Devanahalli", lat: 13.2437, lng: 77.7120 },
        { label: "Hoskote", lat: 13.0700, lng: 77.7980 },
        { label: "Attibele", lat: 12.7760, lng: 77.7700 },
        { label: "Chandapura", lat: 12.8030, lng: 77.7080 },
        { label: "Yelachenahalli", lat: 12.8890, lng: 77.5750 },
        { label: "Uttarahalli", lat: 12.8988, lng: 77.5460 },
        { label: "Kengeri", lat: 12.9055, lng: 77.4850 },
        { label: "Rajarajeshwari Nagar", lat: 12.9270, lng: 77.5170 },
    ],
  },
];

export function findAirport(code: string): Airport | undefined {
  return AIRPORTS.find((a) => a.code === code);
}

/** True when `terminal` is one of the airport's terminals. */
export function isValidTerminal(airportCode: string, terminal: string): boolean {
  return !!findAirport(airportCode)?.terminals.some((t) => t.code === terminal);
}
