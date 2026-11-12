import { NextResponse } from "next/server";
import { and, eq, inArray, ne, or } from "drizzle-orm";
import { getDb, matches, rideRequests } from "@airport-ride-matchmaking/db";
import { matchActionSchema } from "@/lib/schemas";
import { jsonError, requireUserId } from "@/lib/api-response";
import { findExistingMatch } from "@/lib/matching";

export async function POST(request: Request) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const body = await request.json().catch(() => null);
  const parsed = matchActionSchema.safeParse(body);
  if (!parsed.success) return jsonError(parsed.error.issues[0].message, 400);
  const { rideRequestId, candidateRideRequestId, action } = parsed.data;

  const db = getDb();
  const [mine] = await db
    .select()
    .from(rideRequests)
    .where(and(eq(rideRequests.id, rideRequestId), eq(rideRequests.userId, userId)))
    .limit(1);
  if (!mine || mine.status !== "open") return jsonError("Ride request not open", 400);

  const [candidate] = await db
    .select()
    .from(rideRequests)
    .where(and(eq(rideRequests.id, candidateRideRequestId), eq(rideRequests.status, "open")))
    .limit(1);
  if (!candidate) return jsonError("Candidate ride request not found", 404);

  const existing = await findExistingMatch(rideRequestId, candidateRideRequestId);

  if (action === "pass") {
    if (existing?.status === "mutual") return jsonError("Already matched", 409);
    const [row] = existing
      ? await db
          .update(matches)
          .set({ status: "rejected", updatedAt: new Date() })
          .where(eq(matches.id, existing.id))
          .returning()
      : await db
          .insert(matches)
          .values({
            rideRequestAId: rideRequestId,
            rideRequestBId: candidateRideRequestId,
            userAId: userId,
            userBId: candidate.userId,
            status: "rejected",
          })
          .returning();
    return NextResponse.json(row);
  }

  // action === "like"
  if (!existing) {
    const [row] = await db
      .insert(matches)
      .values({
        rideRequestAId: rideRequestId,
        rideRequestBId: candidateRideRequestId,
        userAId: userId,
        userBId: candidate.userId,
        status: "proposed_by_a",
        respondedAtA: new Date(),
      })
      .returning();
    return NextResponse.json(row, { status: 201 });
  }

  if (existing.status === "rejected") return jsonError("This pair was already passed on", 409);
  if (existing.status === "mutual") return NextResponse.json(existing);

  const amIUserA = existing.userAId === userId;
  const myProposalStatus = amIUserA ? "proposed_by_a" : "proposed_by_b";
  const otherProposalStatus = amIUserA ? "proposed_by_b" : "proposed_by_a";

  if (existing.status === myProposalStatus) return NextResponse.json(existing);

  if (existing.status === otherProposalStatus) {
    // Mutual! First-mutual-wins: lock this pair in, expire every other pending
    // match for both users, set both ride requests to 'matched'.
    // NOTE: not wrapped in a DB transaction (the neon-http driver doesn't support
    // interactive multi-statement transactions) — acceptable race-condition risk
    // at MVP volume; revisit if concurrent double-matches are observed in practice.
    const [mutualRow] = await db
      .update(matches)
      .set({
        status: "mutual",
        ...(amIUserA ? { respondedAtA: new Date() } : { respondedAtB: new Date() }),
        updatedAt: new Date(),
      })
      .where(eq(matches.id, existing.id))
      .returning();

    await db
      .update(rideRequests)
      .set({ status: "matched", updatedAt: new Date() })
      .where(inArray(rideRequests.id, [rideRequestId, candidateRideRequestId]));

    await db
      .update(matches)
      .set({ status: "expired", updatedAt: new Date() })
      .where(
        and(
          ne(matches.id, existing.id),
          inArray(matches.status, ["proposed_by_a", "proposed_by_b"]),
          or(
            inArray(matches.rideRequestAId, [rideRequestId, candidateRideRequestId]),
            inArray(matches.rideRequestBId, [rideRequestId, candidateRideRequestId]),
          ),
        ),
      );

    return NextResponse.json(mutualRow);
  }

  return jsonError(`Unexpected match status: ${existing.status}`, 409);
}
