// Lists what people have sent through the in-app feedback form, newest first.
// Read-only. Run from apps/api:
//
//   node --env-file=.env.local scripts/feedback.mjs          (latest 50)
//   node --env-file=.env.local scripts/feedback.mjs 200      (latest 200)
//
// Needs DATABASE_URL (the same value the API uses).
import { neon } from "@neondatabase/serverless";

if (!process.env.DATABASE_URL) throw new Error("Set DATABASE_URL first");
const limit = Math.min(Math.max(parseInt(process.argv[2] ?? "50", 10) || 50, 1), 1000);

const sql = neon(process.env.DATABASE_URL);
const rows = await sql`
  SELECT f.created_at, f.type, f.message, u.email, p.display_name
  FROM feedback f
  JOIN users u ON u.id = f.user_id
  LEFT JOIN profiles p ON p.user_id = f.user_id
  ORDER BY f.created_at DESC
  LIMIT ${limit}`;

if (rows.length === 0) {
  console.log("No feedback yet.");
} else {
  for (const r of rows) {
    const when = new Date(r.created_at).toISOString().replace("T", " ").slice(0, 16);
    console.log(`\n[${when} UTC] ${r.type}  from ${r.display_name ?? "(no name)"} <${r.email}>`);
    console.log(r.message);
  }
  console.log(`\n${rows.length} shown.`);
}
