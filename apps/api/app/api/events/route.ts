import { NextResponse } from "next/server";
import { z } from "zod";
import { jsonError, requireUserId } from "@/lib/api-response";
import { track } from "@/lib/telemetry";

const bodySchema = z.object({
  event: z.literal("app_opened"),
  platform: z.enum(["android", "ios", "web", "other"]),
  appVersion: z.string().max(32).regex(/^[\w.+-]*$/),
});

/**
 * Usage events sent by the app. Only `app_opened` (for daily and weekly active
 * users and release adoption); the app skips it when the user opted out in
 * Settings. Everything else is recorded server-side from the real action.
 */
export async function POST(request: Request) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const parsed = bodySchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return jsonError("Invalid event", 400);

  await track("app_opened", userId, { platform: parsed.data.platform, app_version: parsed.data.appVersion });
  return new NextResponse(null, { status: 204 });
}
