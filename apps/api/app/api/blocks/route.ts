import { NextResponse } from "next/server";
import { track } from "@/lib/telemetry";
import { and, eq, or } from "drizzle-orm";
import { getDb, blocks, matches } from "@airport-ride-matchmaking/db";
import { blockCreateSchema } from "@/lib/schemas";
import { jsonError, requireUserId } from "@/lib/api-response";
import { endMatch } from "@/lib/matching";

export async function POST(request: Request) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const body = await request.json().catch(() => null);
  const parsed = blockCreateSchema.safeParse(body);
  if (!parsed.success) return jsonError(parsed.error.issues[0].message, 400);
  const { blockedUserId } = parsed.data;

  if (blockedUserId === userId) return jsonError("Cannot block yourself", 400);

  const db = getDb();
  const [existing] = await db
    .select()
    .from(blocks)
    .where(and(eq(blocks.blockerId, userId), eq(blocks.blockedId, blockedUserId)))
    .limit(1);

  const block =
    existing ??
    (await db.insert(blocks).values({ blockerId: userId, blockedId: blockedUserId }).returning())[0];
  if (!existing) await track("block_created", userId);

  // Blocking someone you are currently matched with ends that match, so the
  // chat cannot continue.
  const [active] = await db
    .select()
    .from(matches)
    .where(
      and(
        eq(matches.status, "mutual"),
        or(
          and(eq(matches.userAId, userId), eq(matches.userBId, blockedUserId)),
          and(eq(matches.userAId, blockedUserId), eq(matches.userBId, userId)),
        ),
      ),
    )
    .limit(1);
  const ended = active ? await endMatch(active, userId) : null;

  return NextResponse.json(
    {
      ...block,
      endedMatchId: ended?.updated.id ?? null,
      reopenedRideRequestId: ended?.reopenedRideRequestId ?? null,
    },
    { status: existing ? 200 : 201 },
  );
}
