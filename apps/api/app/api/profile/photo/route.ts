import { NextResponse } from "next/server";
import { put } from "@vercel/blob";
import { jsonError, requireUserId } from "@/lib/api-response";

const MAX_PHOTO_BYTES = 8 * 1024 * 1024;
const ALLOWED_TYPES = ["image/jpeg", "image/png", "image/webp"];

export async function POST(request: Request) {
  const userId = await requireUserId(request);
  if (userId instanceof NextResponse) return userId;

  const formData = await request.formData().catch(() => null);
  const file = formData?.get("photo");
  if (!(file instanceof File)) return jsonError("Missing 'photo' file", 400);
  if (!ALLOWED_TYPES.includes(file.type)) return jsonError("Unsupported image type", 400);
  if (file.size > MAX_PHOTO_BYTES) return jsonError("Image too large (max 8MB)", 400);

  const extension = file.type.split("/")[1];
  const blob = await put(`profile-photos/${userId}.${extension}`, file, {
    access: "public",
    addRandomSuffix: true,
  });

  return NextResponse.json({ photoUrl: blob.url });
}
