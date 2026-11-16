import { timingSafeEqual } from "node:crypto";

/** True when the request carries `Authorization: Bearer <expected>`. */
export function hasBearer(request: Request, expected: string | undefined): boolean {
  if (!expected) return false;
  const header = request.headers.get("authorization") ?? "";
  const given = Buffer.from(header);
  const wanted = Buffer.from(`Bearer ${expected}`);
  return given.length === wanted.length && timingSafeEqual(given, wanted);
}
