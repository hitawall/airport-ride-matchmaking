import { env } from "./env";
import { emailSchema } from "./schemas";

export class GoogleSignInError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
  }
}

const TOKEN_INFO_URL = "https://oauth2.googleapis.com/tokeninfo";

/**
 * Asks Google who an access token belongs to and returns their verified email.
 *
 * The token comes from Google's sign-in popup in the browser. We never trust
 * what the browser says about it: Google's own `tokeninfo` endpoint tells us
 * which app the token was issued to (it must be ours), whether the email is
 * verified by Google, and when it expires.
 */
export async function verifyGoogleAccessToken(accessToken: string): Promise<string> {
  const clientId = env.googleClientId;
  if (!clientId) throw new GoogleSignInError("Google sign-in isn't set up yet", 503);

  let info: Record<string, unknown>;
  try {
    const res = await fetch(`${TOKEN_INFO_URL}?access_token=${encodeURIComponent(accessToken)}`, {
      signal: AbortSignal.timeout(8000),
    });
    if (res.status === 400 || res.status === 401) {
      throw new GoogleSignInError("That Google sign-in didn't work. Please try again.", 401);
    }
    if (!res.ok) throw new Error(`tokeninfo ${res.status}`);
    info = (await res.json()) as Record<string, unknown>;
  } catch (e) {
    if (e instanceof GoogleSignInError) throw e;
    throw new GoogleSignInError("We couldn't reach Google just now. Please try again.", 502);
  }

  // Issued to our app, and not expired.
  if (info.aud !== clientId && info.azp !== clientId) {
    throw new GoogleSignInError("That Google sign-in didn't work. Please try again.", 401);
  }
  if (Number(info.expires_in) <= 0) {
    throw new GoogleSignInError("That Google sign-in expired. Please try again.", 401);
  }

  // The email must be present and confirmed by Google (booleans arrive as strings).
  const verified = info.email_verified === true || info.email_verified === "true";
  const email = emailSchema.safeParse(info.email);
  if (!verified || !email.success) {
    throw new GoogleSignInError("Your Google account needs a verified email address.", 403);
  }
  return email.data;
}
