import { describe, expect, it } from "vitest";
import { AIRPORTS, DEFAULT_AIRPORT_CODE, findAirport, isValidTerminal } from "@/lib/airports";

describe("airport catalogue", () => {
  it("has the default airport", () => {
    expect(findAirport(DEFAULT_AIRPORT_CODE)).toBeDefined();
  });

  it("only accepts terminals the airport has", () => {
    expect(isValidTerminal("BLR", "T1")).toBe(true);
    expect(isValidTerminal("BLR", "T2")).toBe(true);
    expect(isValidTerminal("BLR", "T3")).toBe(false);
    expect(isValidTerminal("ZZZ", "T1")).toBe(false);
  });

  it("every airport has coordinates, terminals and destination areas with unique names", () => {
    for (const airport of AIRPORTS) {
      expect(Number.isFinite(airport.lat) && Number.isFinite(airport.lng)).toBe(true);
      expect(airport.terminals.length).toBeGreaterThan(0);
      const labels = airport.localities.map((l) => l.label);
      expect(new Set(labels).size).toBe(labels.length);
      for (const l of airport.localities) {
        expect(l.lat).toBeGreaterThan(-90);
        expect(l.lat).toBeLessThan(90);
      }
    }
  });
});
