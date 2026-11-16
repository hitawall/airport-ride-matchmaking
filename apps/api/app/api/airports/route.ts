import { NextResponse } from "next/server";
import { AIRPORTS, DEFAULT_AIRPORT_CODE } from "@/lib/airports";

/**
 * Public list of supported airports with their terminals and destination
 * localities. The app builds its airport, terminal and destination pickers
 * from this, so adding an airport needs no app release.
 */
export async function GET() {
  return NextResponse.json(
    { defaultAirportCode: DEFAULT_AIRPORT_CODE, airports: AIRPORTS },
    { headers: { "cache-control": "public, max-age=300, s-maxage=300" } },
  );
}
