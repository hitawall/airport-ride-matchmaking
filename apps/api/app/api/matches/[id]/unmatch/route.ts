import { NextResponse } from "next/server";
import { track } from "@/lib/telemetry";
import { jsonError, requireUserId } from "@/lib/api-response";
import { getMatchForParticipant } from "@/lib/chat";
import { endMatch } from "@/lib/matching";

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const { id } = await params;
  const match = await getMatchForParticipant(id, userId);
  if (!match) return jsonError("Match not found", 404);
  if (match.status !== "mutual") {
    return jsonError("Only active matches can be unmatched", 409);
  }

  const { updated, reopenedRideRequestId } = await endMatch(match, userId);

  await track("match_unmatched", userId);
  return NextResponse.json({ ...updated, reopenedRideRequestId });
}
