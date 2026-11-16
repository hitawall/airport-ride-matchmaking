// Creates (or refreshes) the app-store review account with a complete profile and
// a profile photo, so a reviewer can reach every screen including searching for
// a match. Run from apps/api against the environment you want to seed:
//
//   node --env-file=.env.local scripts/seed-review-account.mjs
//
// Needs DATABASE_URL and REVIEW_ACCOUNT_EMAIL. Optional: REVIEW_ACCOUNT_PHOTO_URL
// (defaults to the app icon on the web app). See docs/STORE_REVIEW_ACCOUNT.md.
import { neon } from "@neondatabase/serverless";

const email = process.env.REVIEW_ACCOUNT_EMAIL?.trim().toLowerCase();
if (!email) throw new Error("Set REVIEW_ACCOUNT_EMAIL first");
if (!process.env.DATABASE_URL) throw new Error("Set DATABASE_URL first");

const photoUrl =
  process.env.REVIEW_ACCOUNT_PHOTO_URL ??
  "https://airpool.online/icons/Icon-512.png";

const sql = neon(process.env.DATABASE_URL);

let [user] = await sql`SELECT id FROM users WHERE email = ${email}`;
if (!user) {
  [user] = await sql`INSERT INTO users (email, email_verified) VALUES (${email}, true) RETURNING id`;
}

await sql`
  INSERT INTO profiles (user_id, display_name, gender, gender_preference, profile_photo_url, bio, phone_number)
  VALUES (${user.id}, 'App Reviewer', 'prefer_not_to_say', 'any', ${photoUrl},
          'Account for app store review.', '+919000000000')
  ON CONFLICT (user_id) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    profile_photo_url = EXCLUDED.profile_photo_url,
    bio = EXCLUDED.bio,
    updated_at = now()`;

console.log(`Review account ready: ${email} (user ${user.id})`);
