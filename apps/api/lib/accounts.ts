import { eq } from "drizzle-orm";
import { getDb, users } from "@airport-ride-matchmaking/db";
import { issueToken } from "./auth";
import { track } from "./telemetry";

/**
 * Signs someone in by a verified email, creating the account the first time.
 * The email is the identity, so every way of proving it (a one-time code, or
 * Google) leads to the same account.
 */
export async function signInWithVerifiedEmail(email: string) {
  const db = getDb();
  const [existingUser] = await db.select().from(users).where(eq(users.email, email)).limit(1);
  const isNewUser = !existingUser;
  const user = existingUser
    ? (await db
        .update(users)
        .set({ emailVerified: true, updatedAt: new Date() })
        .where(eq(users.id, existingUser.id))
        .returning())[0]
    : (await db.insert(users).values({ email, emailVerified: true }).returning())[0];

  const token = await issueToken(user.id);
  if (isNewUser) await track("account_created", user.id);
  return { token, userId: user.id, isNewUser };
}
