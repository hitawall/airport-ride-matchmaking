import { SignJWT, jwtVerify } from "jose";
import { env } from "./env";

const JWT_TTL_SECONDS = 30 * 24 * 60 * 60; // 30 days

function secretKey() {
  return new TextEncoder().encode(env.jwtSecret);
}

export async function issueToken(userId: string): Promise<string> {
  return new SignJWT({ sub: userId })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime(Math.floor(Date.now() / 1000) + JWT_TTL_SECONDS)
    .sign(secretKey());
}

export async function verifyToken(token: string): Promise<string | null> {
  try {
    const { payload } = await jwtVerify(token, secretKey());
    return typeof payload.sub === "string" ? payload.sub : null;
  } catch {
    return null;
  }
}

/** Extracts and verifies the bearer token from a request, returning the authenticated userId or null. */
export async function getAuthenticatedUserId(request: Request): Promise<string | null> {
  const header = request.headers.get("authorization");
  if (!header?.startsWith("Bearer ")) return null;
  const token = header.slice("Bearer ".length);
  return verifyToken(token);
}
