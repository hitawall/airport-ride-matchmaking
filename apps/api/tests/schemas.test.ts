import { describe, expect, it } from "vitest";
import {
  chatMessageCreateSchema,
  emailSchema,
  matchActionSchema,
  profileUpdateSchema,
  ratingCreateSchema,
  rideRequestCreateSchema,
} from "@/lib/schemas";

const uuid = "5b1f6b1e-3c8a-4f0e-9a52-0f6d1b7a1c11";

describe("emailSchema", () => {
  it("trims and lowercases", () => {
    expect(emailSchema.parse("  Asha@Example.COM ")).toBe("asha@example.com");
  });
  it("rejects things that are not emails", () => {
    expect(emailSchema.safeParse("not-an-email").success).toBe(false);
  });
});

describe("profileUpdateSchema", () => {
  const valid = {
    displayName: "Asha",
    gender: "female",
    genderPreference: "any",
    phoneNumber: "98765 43210",
  };
  it("normalises the phone number to E.164", () => {
    expect(profileUpdateSchema.parse(valid).phoneNumber).toBe("+919876543210");
  });
  it("requires a valid phone number", () => {
    expect(profileUpdateSchema.safeParse({ ...valid, phoneNumber: "123" }).success).toBe(false);
  });
  it("needs a gender of male, female or other", () => {
    for (const good of ["male", "female", "other"]) expect(profileUpdateSchema.safeParse({ ...valid, gender: good }).success).toBe(true);
    for (const bad of ["prefer_not_to_say", "", undefined]) expect(profileUpdateSchema.safeParse({ ...valid, gender: bad }).success).toBe(false);
  });
  it("limits the bio length", () => {
    expect(profileUpdateSchema.safeParse({ ...valid, bio: "x".repeat(281) }).success).toBe(false);
  });
});

describe("rideRequestCreateSchema", () => {
  const valid = {
    terminal: "T1",
    flightArrivalAt: "2026-12-01T10:00:00.000Z",
    destinationAddress: "Indiranagar",
    destinationLat: 12.97,
    destinationLng: 77.64,
    destinationLocalityLabel: "Indiranagar",
    trolleyBags: 1,
  };
  it("defaults the airport to the primary one", () => {
    expect(rideRequestCreateSchema.parse(valid).airportCode).toBe("BLR");
  });
  it("requires a terminal", () => {
    const { terminal, ...rest } = valid;
    void terminal;
    expect(rideRequestCreateSchema.safeParse(rest).success).toBe(false);
  });
  it("rejects a terminal the airport does not have", () => {
    expect(rideRequestCreateSchema.safeParse({ ...valid, terminal: "T9" }).success).toBe(false);
  });
  it("rejects an unsupported airport", () => {
    expect(rideRequestCreateSchema.safeParse({ ...valid, airportCode: "ZZZ" }).success).toBe(false);
  });
  it("requires the number of trolley bags, as a whole number from 0 to 4 (4 meaning 3+)", () => {
    const { trolleyBags, ...rest } = valid;
    void trolleyBags;
    expect(rideRequestCreateSchema.safeParse(rest).success).toBe(false);
    for (const bad of [-1, 5, 1.5]) expect(rideRequestCreateSchema.safeParse({ ...valid, trolleyBags: bad }).success).toBe(false);
    for (const good of [0, 1, 4]) expect(rideRequestCreateSchema.safeParse({ ...valid, trolleyBags: good }).success).toBe(true);
  });
  it("rejects coordinates outside the globe", () => {
    expect(rideRequestCreateSchema.safeParse({ ...valid, destinationLat: 91 }).success).toBe(false);
  });
});

describe("other request schemas", () => {
  it("match actions are only like or pass", () => {
    expect(matchActionSchema.safeParse({ rideRequestId: uuid, candidateRideRequestId: uuid, action: "like" }).success).toBe(true);
    expect(matchActionSchema.safeParse({ rideRequestId: uuid, candidateRideRequestId: uuid, action: "block" }).success).toBe(false);
  });
  it("chat messages cannot be empty or huge", () => {
    expect(chatMessageCreateSchema.safeParse({ body: "" }).success).toBe(false);
    expect(chatMessageCreateSchema.safeParse({ body: "x".repeat(2001) }).success).toBe(false);
    expect(chatMessageCreateSchema.safeParse({ body: "hi" }).success).toBe(true);
  });
  it("ratings are whole numbers from 1 to 5", () => {
    for (const score of [0, 6, 2.5]) expect(ratingCreateSchema.safeParse({ score }).success).toBe(false);
    for (const score of [1, 3, 5]) expect(ratingCreateSchema.safeParse({ score }).success).toBe(true);
  });
});
