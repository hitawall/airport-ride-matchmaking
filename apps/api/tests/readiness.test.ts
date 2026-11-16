import { describe, expect, it } from "vitest";
import { isReady, runReadinessChecks } from "@/lib/readiness";

const good = {
  OTP_FROM_EMAIL: "Airpool <login@airpool.online>",
  RESEND_API_KEY: "re_123",
  JWT_SECRET: "x".repeat(40),
  REVIEW_ACCOUNT_EMAIL: "reviewer@example.com",
  REVIEW_ACCOUNT_CODE: "482913",
  PUSHER_APP_ID: "1",
  PUSHER_KEY: "k",
  PUSHER_SECRET: "s",
  PUSHER_CLUSTER: "ap2",
  BLOB_READ_WRITE_TOKEN: "t",
  CRON_SECRET: "c",
};

const check = (env: Record<string, string | undefined>, name: string) =>
  runReadinessChecks(env).find((c) => c.name === name)!;

describe("launch readiness", () => {
  it("a fully configured API is ready", () => {
    expect(isReady(runReadinessChecks(good))).toBe(true);
  });

  it("OTP test mode blocks launch (anyone could sign in as anyone)", () => {
    const checks = runReadinessChecks({ ...good, OTP_TEST_MODE: "true" });
    expect(check({ ...good, OTP_TEST_MODE: "true" }, "otp-test-mode-off").ok).toBe(false);
    expect(isReady(checks)).toBe(false);
  });

  it("Resend's shared test sender blocks launch", () => {
    expect(check({ ...good, OTP_FROM_EMAIL: "Airpool <onboarding@resend.dev>" }, "email-sender-verified-domain").ok).toBe(false);
  });

  it("a short JWT secret blocks launch", () => {
    expect(check({ ...good, JWT_SECRET: "short" }, "jwt-secret-strong").ok).toBe(false);
  });

  it("the review account must be a 6-digit code that is not the test code", () => {
    expect(check({ ...good, REVIEW_ACCOUNT_CODE: "000000" }, "review-account").ok).toBe(false);
    expect(check({ ...good, REVIEW_ACCOUNT_CODE: undefined }, "review-account").ok).toBe(false);
  });

  it("recommended items never block launch", () => {
    const checks = runReadinessChecks(good);
    expect(checks.filter((c) => c.level === "recommended").some((c) => !c.ok)).toBe(true);
    expect(isReady(checks)).toBe(true);
  });
});
