import { NextResponse } from "next/server";
import { sql } from "drizzle-orm";
import { getDb } from "@airport-ride-matchmaking/db";

// Never cached: an uptime monitor must see the live state.
export const dynamic = "force-dynamic";

/**
 * Cheap public health check for uptime monitors: 200 when the database
 * answers, 503 when it does not. Returns no configuration or user data.
 */
export async function GET() {
  const startedAt = Date.now();
  let database = false;
  try {
    await getDb().execute(sql`select 1`);
    database = true;
  } catch (error) {
    console.error("health: database check failed", error instanceof Error ? error.message : error);
  }

  return NextResponse.json(
    {
      status: database ? "ok" : "degraded",
      database,
      version: process.env.VERCEL_GIT_COMMIT_SHA?.slice(0, 7) ?? "dev",
      latencyMs: Date.now() - startedAt,
    },
    { status: database ? 200 : 503, headers: { "cache-control": "no-store" } },
  );
}
