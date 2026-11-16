import { NextResponse } from "next/server";
import { deleteAccount } from "@/lib/account-deletion";
import { jsonError, requireUserId } from "@/lib/api-response";

/** Permanently deletes the signed-in user's account and all their data. */
export async function DELETE(request: Request) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const deleted = await deleteAccount(userId);
  if (!deleted) return jsonError("Account not found", 404);

  return NextResponse.json({ ok: true });
}
