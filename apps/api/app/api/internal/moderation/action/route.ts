import { NextResponse } from "next/server";
import { eq } from "drizzle-orm";
import { z } from "zod";
import { getDb, reports } from "@airport-ride-matchmaking/db";
import { deleteAccount } from "@/lib/account-deletion";
import { jsonError } from "@/lib/api-response";
import { env } from "@/lib/env";
import { hasBearer } from "@/lib/moderation/auth";

const actionSchema = z.object({
  reportId: z.string().uuid(),
  action: z.enum(["dismiss", "remove_user"]),
});

/**
 * Moderator action on one report, protected by MODERATION_TOKEN.
 *  - dismiss: mark the report reviewed, no action against the person.
 *  - remove_user: delete the reported person's account (and, with it, every
 *    report filed against them -- see docs/MODERATION.md).
 */
export async function POST(request: Request) {
  if (!hasBearer(request, env.moderationToken)) return jsonError("Unauthorized", 401);

  const parsed = actionSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return jsonError(parsed.error.issues[0].message, 400);
  const { reportId, action } = parsed.data;

  const db = getDb();
  const [report] = await db.select().from(reports).where(eq(reports.id, reportId)).limit(1);
  if (!report) return jsonError("Report not found", 404);

  if (action === "dismiss") {
    await db.update(reports).set({ status: "reviewed" }).where(eq(reports.id, reportId));
    return NextResponse.json({ ok: true, action });
  }

  const removed = await deleteAccount(report.reportedId);
  return NextResponse.json({ ok: true, action, removed });
}
