import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { GoogleSignInError, verifyGoogleAccessToken } from "@/lib/google";

const CLIENT_ID = "123-abc.apps.googleusercontent.com";

function tokenInfo(body: Record<string, unknown>, status = 200) {
  vi.stubGlobal(
    "fetch",
    vi.fn(async () => new Response(JSON.stringify(body), { status })),
  );
}

const good = { aud: CLIENT_ID, email: "Asha@Example.com", email_verified: "true", expires_in: "3000" };

describe("verifyGoogleAccessToken", () => {
  beforeEach(() => {
    process.env.GOOGLE_CLIENT_ID = CLIENT_ID;
  });
  afterEach(() => {
    delete process.env.GOOGLE_CLIENT_ID;
    vi.unstubAllGlobals();
  });

  async function failure(promise: Promise<unknown>) {
    const error = await promise.then(
      () => null,
      (e) => e,
    );
    expect(error).toBeInstanceOf(GoogleSignInError);
    return error as GoogleSignInError;
  }

  it("returns the lower-cased verified email for a token issued to our app", async () => {
    tokenInfo(good);
    expect(await verifyGoogleAccessToken("token-token-token")).toBe("asha@example.com");
  });

  it("accepts a real boolean for email_verified", async () => {
    tokenInfo({ ...good, email_verified: true });
    expect(await verifyGoogleAccessToken("token-token-token")).toBe("asha@example.com");
  });

  it("is off (503) until a client ID is configured", async () => {
    delete process.env.GOOGLE_CLIENT_ID;
    tokenInfo(good);
    expect((await failure(verifyGoogleAccessToken("token-token-token"))).status).toBe(503);
  });

  it("refuses a token issued to a different app", async () => {
    tokenInfo({ ...good, aud: "someone-else.apps.googleusercontent.com" });
    expect((await failure(verifyGoogleAccessToken("token-token-token"))).status).toBe(401);
  });

  it("refuses an email Google has not verified", async () => {
    tokenInfo({ ...good, email_verified: "false" });
    expect((await failure(verifyGoogleAccessToken("token-token-token"))).status).toBe(403);
  });

  it("refuses a token with no email", async () => {
    tokenInfo({ aud: CLIENT_ID, expires_in: "3000" });
    expect((await failure(verifyGoogleAccessToken("token-token-token"))).status).toBe(403);
  });

  it("refuses an expired token", async () => {
    tokenInfo({ ...good, expires_in: "0" });
    expect((await failure(verifyGoogleAccessToken("token-token-token"))).status).toBe(401);
  });

  it("refuses a token Google rejects", async () => {
    tokenInfo({ error: "invalid_token" }, 400);
    expect((await failure(verifyGoogleAccessToken("token-token-token"))).status).toBe(401);
  });

  it("reports a Google outage as a retryable error", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => {
        throw new Error("network down");
      }),
    );
    expect((await failure(verifyGoogleAccessToken("token-token-token"))).status).toBe(502);
  });
});
