import { desc, eq, gte, sql } from "drizzle-orm";
import { alias } from "drizzle-orm/pg-core";
import { getDb, profiles, reports } from "@airport-ride-matchmaking/db";

export interface DigestReport {
  id: string;
  reason: string;
  details: string | null;
  matchId: string | null;
  status: string;
  createdAt: Date;
  reporterId: string;
  reporterName: string | null;
  reportedId: string;
  reportedName: string | null;
  /** All reports ever filed against the reported person (including this one). */
  reportsAgainstReported: number;
}

/** Reports filed at or after `since`, newest first. */
export async function reportsSince(since: Date): Promise<DigestReport[]> {
  const db = getDb();
  const reporter = alias(profiles, "reporter");
  const reported = alias(profiles, "reported");
  return db
    .select({
      id: reports.id,
      reason: reports.reason,
      details: reports.details,
      matchId: reports.matchId,
      status: reports.status,
      createdAt: reports.createdAt,
      reporterId: reports.reporterId,
      reporterName: reporter.displayName,
      reportedId: reports.reportedId,
      reportedName: reported.displayName,
      reportsAgainstReported: sql<number>`(
        SELECT count(*)::int FROM reports r2 WHERE r2.reported_id = ${reports.reportedId}
      )`,
    })
    .from(reports)
    .leftJoin(reporter, eq(reporter.userId, reports.reporterId))
    .leftJoin(reported, eq(reported.userId, reports.reportedId))
    .where(gte(reports.createdAt, since))
    .orderBy(desc(reports.createdAt));
}

const REASON_LABELS: Record<string, string> = {
  harassment: "Harassment",
  no_show: "No-show",
  inappropriate_messages: "Inappropriate messages",
  fake_profile: "Fake profile",
  safety_concern: "Safety concern",
  other: "Other",
};

export function reasonLabel(reason: string): string {
  return REASON_LABELS[reason] ?? reason;
}

function escapeHtml(text: string): string {
  return text
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

export function digestSubject(count: number): string {
  return `[Moderation] ${count} new report${count === 1 ? "" : "s"}`;
}

/** Plain-text body. Report details are user-written, so they appear as-is here. */
export function renderDigestText(items: DigestReport[]): string {
  const lines = [
    `${items.length} new report${items.length === 1 ? "" : "s"} in the last 24 hours.`,
    "Target: review within 48 hours (docs/MODERATION.md).",
    "",
  ];
  for (const r of items) {
    lines.push(
      `${reasonLabel(r.reason)} - ${r.createdAt.toISOString()}`,
      `  Report:   ${r.id}`,
      `  Reported: ${r.reportedName ?? "(deleted)"} (${r.reportedId}) - ${r.reportsAgainstReported} report(s) in total`,
      `  Reporter: ${r.reporterName ?? "(deleted)"} (${r.reporterId})`,
      `  Match:    ${r.matchId ?? "none"}`,
      `  Details:  ${r.details?.trim() || "(none)"}`,
      "",
    );
  }
  return lines.join("\n");
}

/** HTML body. Everything user-supplied is escaped. */
export function renderDigestHtml(items: DigestReport[]): string {
  const rows = items
    .map(
      (r) => `<li style="margin-bottom:16px">
<strong>${escapeHtml(reasonLabel(r.reason))}</strong> &middot; ${escapeHtml(r.createdAt.toISOString())}<br>
Reported: ${escapeHtml(r.reportedName ?? "(deleted)")} <code>${escapeHtml(r.reportedId)}</code> &middot; ${r.reportsAgainstReported} report(s) in total<br>
Reporter: ${escapeHtml(r.reporterName ?? "(deleted)")} <code>${escapeHtml(r.reporterId)}</code><br>
Report: <code>${escapeHtml(r.id)}</code> &middot; Match: <code>${escapeHtml(r.matchId ?? "none")}</code><br>
Details: ${escapeHtml(r.details?.trim() || "(none)")}
</li>`,
    )
    .join("\n");
  return `<!DOCTYPE html><html><body style="font-family:Arial,sans-serif;color:#241F21">
<p>${items.length} new report${items.length === 1 ? "" : "s"} in the last 24 hours. Target: review within 48 hours.</p>
<ol>${rows}</ol></body></html>`;
}
