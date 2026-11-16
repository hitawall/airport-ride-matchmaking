import { afterEach, describe, expect, it, vi } from "vitest";
import { hasBearer } from "@/lib/moderation/auth";
import { scrub } from "@/lib/telemetry/errors";
import { pseudonymize } from "@/lib/telemetry";
import { reviewAccountCode } from "@/lib/otp/review-account";

const request = (authorization?: string) =>
  new Request("http://x.test", { headers: authorization ? { authorization } : {} });

describe("hasBearer (moderation and cron auth)", () => {
  it("accepts exactly the expected token", () => {
    expect(hasBearer(request("Bearer s3cret-token"), "s3cret-token")).toBe(true);
  });
  it("rejects a wrong, missing or malformed token", () => {
    expect(hasBearer(request("Bearer other"), "s3cret-token")).toBe(false);
    expect(hasBearer(request(), "s3cret-token")).toBe(false);
    expect(hasBearer(request("s3cret-token"), "s3cret-token")).toBe(false);
  });
  it("rejects everything when no token is configured", () => {
    expect(hasBearer(request("Bearer "), undefined)).toBe(false);
    expect(hasBearer(request("Bearer undefined"), undefined)).toBe(false);
  });
});

describe("scrub (error reports never carry personal data)", () => {
  it("removes email addresses and phone numbers", () => {
    const out = scrub("failed for asha@example.com and +91 98765 43210, call 9876543210");
    expect(out).not.toContain("asha@example.com");
    expect(out).not.toContain("98765");
    expect(out).toContain("[email]");
    expect(out).toContain("[number]");
  });
  it("caps very long text", () => {
    expect(scrub("x".repeat(5000)).length).toBe(2000);
  });
});

describe("pseudonymize", () => {
  afterEach(() => vi.unstubAllEnvs());

  it("is stable per user, differs between users, and never contains the id", () => {
    vi.stubEnv("TELEMETRY_ID_SALT", "salt-one");
    const a = pseudonymize("user-1");
    expect(pseudonymize("user-1")).toBe(a);
    expect(pseudonymize("user-2")).not.toBe(a);
    expect(a).not.toContain("user-1");
  });
  it("changes when the salt changes", () => {
    vi.stubEnv("TELEMETRY_ID_SALT", "salt-one");
    const a = pseudonymize("user-1");
    vi.stubEnv("TELEMETRY_ID_SALT", "salt-two");
    expect(pseudonymize("user-1")).not.toBe(a);
  });
});

describe("reviewAccountCode (store reviewer login)", () => {
  afterEach(() => vi.unstubAllEnvs());

  it("is off unless both the email and a valid code are set", () => {
    vi.stubEnv("REVIEW_ACCOUNT_EMAIL", "");
    vi.stubEnv("REVIEW_ACCOUNT_CODE", "");
    expect(reviewAccountCode("reviewer@example.com")).toBeNull();
    vi.stubEnv("REVIEW_ACCOUNT_EMAIL", "reviewer@example.com");
    expect(reviewAccountCode("reviewer@example.com")).toBeNull();
  });
  it("gives the code only to the reviewer's email", () => {
    vi.stubEnv("REVIEW_ACCOUNT_EMAIL", "Reviewer@Example.com");
    vi.stubEnv("REVIEW_ACCOUNT_CODE", "482913");
    expect(reviewAccountCode(" reviewer@example.com ")).toBe("482913");
    expect(reviewAccountCode("someone@example.com")).toBeNull();
  });
  it("refuses the test-mode code and anything that is not 6 digits", () => {
    vi.stubEnv("REVIEW_ACCOUNT_EMAIL", "reviewer@example.com");
    vi.stubEnv("REVIEW_ACCOUNT_CODE", "000000");
    expect(reviewAccountCode("reviewer@example.com")).toBeNull();
    vi.stubEnv("REVIEW_ACCOUNT_CODE", "12345");
    expect(reviewAccountCode("reviewer@example.com")).toBeNull();
  });
});
