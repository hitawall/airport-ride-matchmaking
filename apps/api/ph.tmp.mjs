import { neon } from "@neondatabase/serverless";
import fs from "node:fs";
const sql = neon(fs.readFileSync(".env.local","utf8").match(/^DATABASE_URL=["']?([^"'\r\n]+)/m)[1]);
const rows = await sql`select display_name, profile_photo_url, updated_at from profiles order by updated_at desc`;
for (const r of rows) {
  let info = "no photo";
  if (r.profile_photo_url) {
    try {
      const res = await fetch(r.profile_photo_url, { headers: { origin: "https://airport-ride-matchmaking-web.vercel.app" } });
      info = `${res.status} ${res.headers.get("content-type")} ${res.headers.get("content-length")}B cors=${res.headers.get("access-control-allow-origin")}`;
    } catch (e) { info = "fetch failed: " + e.message; }
  }
  console.log(r.display_name.padEnd(10), String(r.profile_photo_url ?? "").slice(0, 70), "|", info);
}
