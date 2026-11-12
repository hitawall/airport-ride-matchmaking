import { NextResponse } from "next/server";
import { getDb, reports } from "@airport-ride-matchmaking/db";
import { reportCreateSchema } from "@/lib/schemas";
import { jsonError, requireUserId } from "@/lib/api-response";

export async function POST(request: Request) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const body = await request.json().catch(() => null);
  const parsed = reportCreateSchema.safeParse(body);
  if (!parsed.success) return jsonError(parsed.error.issues[0].message, 400);
  const { reportedUserId, matchId, reason, details } = parsed.data;

  if (reportedUserId === userId) return jsonError("Cannot report yourself", 400);

  const db = getDb();
  const [report] = await db
    .insert(reports)
    .values({ reporterId: userId, reportedId: reportedUserId, matchId, reason, details })
    .returning();

  return NextResponse.json(report, { status: 201 });
}
