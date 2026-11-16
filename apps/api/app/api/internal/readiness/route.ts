import { NextResponse } from "next/server";
import { jsonError } from "@/lib/api-response";
import { hasBearer } from "@/lib/moderation/auth";
import { isReady, runReadinessChecks } from "@/lib/readiness";

export const dynamic = "force-dynamic";

/**
 * Launch-readiness report for the owner and the preflight script. Protected by
 * CRON_SECRET; says which settings are in place, never what they are.
 */
export async function GET(request: Request) {
  if (!hasBearer(request, process.env.CRON_SECRET)) return jsonError("Unauthorized", 401);

  const checks = runReadinessChecks(process.env);
  return NextResponse.json(
    { ready: isReady(checks), environment: process.env.VERCEL_ENV ?? "local", checks },
    { headers: { "cache-control": "no-store" } },
  );
}
