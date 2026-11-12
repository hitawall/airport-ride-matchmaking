import { NextResponse } from "next/server";
import { getAuthenticatedUserId } from "./auth";

export function jsonError(message: string, status: number) {
  return NextResponse.json({ error: message }, { status });
}

export function unauthorized() {
  return jsonError("Unauthorized", 401);
}

/** Resolves the authenticated userId or returns an unauthorized NextResponse to short-circuit the handler. */
export async function requireUserId(request: Request): Promise<string | NextResponse> {
  const userId = await getAuthenticatedUserId(request);
  if (!userId) return unauthorized();
  return userId;
}
