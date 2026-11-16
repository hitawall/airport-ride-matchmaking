import { describe, expect, it } from "vitest";
import { normalizePhoneNumber } from "@/lib/phone";

describe("normalizePhoneNumber", () => {
  it.each([
    "9876543210",
    "09876543210",
    "919876543210",
    "+91 98765-43210",
    "+91 (98765) 43210",
    "98765.43210",
  ])("accepts %s as an Indian mobile number", (input) => {
    expect(normalizePhoneNumber(input)).toBe("+919876543210");
  });

  it.each([
    "",
    "12345",
    "5876543210", // Indian mobiles start 6-9
    "98765432101", // too long
    "+449876543210", // unsupported country
    "abcdefghij",
    "98765 4321x",
  ])("rejects %s", (input) => {
    expect(normalizePhoneNumber(input)).toBeNull();
  });

  it("gives the same result however the same number is typed (so duplicates are caught)", () => {
    expect(normalizePhoneNumber("98765 43210")).toBe(normalizePhoneNumber("+91-9876543210"));
  });
});
