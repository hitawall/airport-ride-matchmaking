import { after } from "next/server";
import { and, eq, gte, ne } from "drizzle-orm";
import {
  chatMessages,
  getDb,
  matches,
  profiles,
  rideRequests,
  users,
} from "@airport-ride-matchmaking/db";
import { env } from "@/lib/env";
import { sendServiceEmail, webAppUrl } from "@/lib/email";

/** At most one "new message" email per sender per match in this window. */
const MESSAGE_EMAIL_WINDOW_MS = 10 * 60 * 1000;

async function recipientEmail(userId: string): Promise<string | null> {
  const [row] = await getDb()
    .select({ email: users.email })
    .from(users)
    .where(eq(users.id, userId))
    .limit(1);
  if (!row?.email) return null;
  // The store reviewer's mailbox is not real.
  if (env.reviewAccountEmail && row.email.toLowerCase() === env.reviewAccountEmail) return null;
  return row.email;
}

async function displayName(userId: string): Promise<string> {
  const [row] = await getDb()
    .select({ name: profiles.displayName })
    .from(profiles)
    .where(eq(profiles.userId, userId))
    .limit(1);
  return row?.name ?? "Your match";
}

// The web app uses hash routing, so the chat lives at /#/chat/{matchId}.
function chatUrl(matchId: string): string | undefined {
  const base = webAppUrl();
  return base ? `${base}/#/chat/${matchId}` : undefined;
}

function terminalLabel(airportCode: string | null | undefined, terminal: string | null | undefined) {
  if (!terminal) return airportCode ?? "the airport";
  const n = /^T(\d+)$/.exec(terminal);
  return `${airportCode ?? ""} ${n ? `Terminal ${n[1]}` : terminal}`.trim();
}

/** Tells both people about a new mutual match. Runs after the response is sent. */
export function notifyMutualMatch(matchId: string): void {
  after(async () => {
    try {
      const db = getDb();
      const [match] = await db.select().from(matches).where(eq(matches.id, matchId)).limit(1);
      if (!match) return;
      const [ride] = await db
        .select({ airportCode: rideRequests.airportCode, terminal: rideRequests.terminal })
        .from(rideRequests)
        .where(eq(rideRequests.id, match.rideRequestAId))
        .limit(1);
      const meet = terminalLabel(ride?.airportCode, ride?.terminal);
      const url = chatUrl(matchId);

      for (const [me, other] of [
        [match.userAId, match.userBId],
        [match.userBId, match.userAId],
      ] as const) {
        const to = await recipientEmail(me);
        if (!to) continue;
        const otherName = await displayName(other);
        await sendServiceEmail({
          to,
          subject: "You have a ride match",
          heading: `You matched with ${otherName}`,
          paragraphs: [
            `You and ${otherName} both want to share a cab from ${meet}.`,
            "Say hello and agree where to meet at the official pickup zone. You each book and pay for your own cab.",
          ],
          action: url ? { label: "Open the chat", url } : undefined,
        });
      }
    } catch (error) {
      console.error("notifyMutualMatch failed", error instanceof Error ? error.message : error);
    }
  });
}

/**
 * Tells the other person about a new chat message, at most once per sender per
 * match per 10 minutes. The message text is never included. Runs after the
 * response is sent.
 */
export function notifyNewMessage(matchId: string, senderId: string, newMessageId: string): void {
  after(async () => {
    try {
      const db = getDb();
      const since = new Date(Date.now() - MESSAGE_EMAIL_WINDOW_MS);
      const [recent] = await db
        .select({ id: chatMessages.id })
        .from(chatMessages)
        .where(
          and(
            eq(chatMessages.matchId, matchId),
            eq(chatMessages.senderId, senderId),
            ne(chatMessages.id, newMessageId),
            gte(chatMessages.createdAt, since),
          ),
        )
        .limit(1);
      if (recent) return;

      const [match] = await db.select().from(matches).where(eq(matches.id, matchId)).limit(1);
      if (!match) return;
      const recipientId = match.userAId === senderId ? match.userBId : match.userAId;
      const to = await recipientEmail(recipientId);
      if (!to) return;
      const senderName = await displayName(senderId);
      const url = chatUrl(matchId);
      await sendServiceEmail({
        to,
        subject: `New message from ${senderName}`,
        heading: `${senderName} sent you a message`,
        paragraphs: ["Open the chat to read and reply."],
        action: url ? { label: "Open the chat", url } : undefined,
      });
    } catch (error) {
      console.error("notifyNewMessage failed", error instanceof Error ? error.message : error);
    }
  });
}
