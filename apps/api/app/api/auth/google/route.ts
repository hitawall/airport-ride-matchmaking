import { NextResponse } from "next/server";
import { track } from "@/lib/telemetry";
import { googleSignInSchema } from "@/lib/schemas";
import { jsonError } from "@/lib/api-response";
import { signInWithVerifiedEmail } from "@/lib/accounts";
import { GoogleSignInError, verifyGoogleAccessToken } from "@/lib/google";

export async function POST(request: Request) {
  const body = await request.json().catch(() => null);
  const parsed = googleSignInSchema.safeParse(body);
  if (!parsed.success) return jsonError(parsed.error.issues[0].message, 400);

  try {
    const email = await verifyGoogleAccessToken(parsed.data.accessToken);
    const result = await signInWithVerifiedEmail(email);
    await track("google_sign_in", result.userId, { is_new_user: result.isNewUser });
    return NextResponse.json(result);
  } catch (e) {
    if (e instanceof GoogleSignInError) return jsonError(e.message, e.status);
    throw e;
  }
}
