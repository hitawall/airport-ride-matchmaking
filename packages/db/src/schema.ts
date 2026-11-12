import { sql } from "drizzle-orm";
import {
  pgTable,
  uuid,
  text,
  boolean,
  timestamp,
  doublePrecision,
  numeric,
  integer,
  index,
  uniqueIndex,
  check,
} from "drizzle-orm/pg-core";

export const users = pgTable("users", {
  id: uuid("id").primaryKey().defaultRandom(),
  phone: text("phone").notNull().unique(),
  phoneVerified: boolean("phone_verified").notNull().default(false),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
});

export const profiles = pgTable(
  "profiles",
  {
    userId: uuid("user_id")
      .primaryKey()
      .references(() => users.id),
    displayName: text("display_name").notNull(),
    gender: text("gender").notNull(),
    genderPreference: text("gender_preference").notNull().default("any"),
    profilePhotoUrl: text("profile_photo_url"),
    homeLocalityLabel: text("home_locality_label"),
    bio: text("bio"),
    isActive: boolean("is_active").notNull().default(true),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [
    check("gender_check", sql`${table.gender} IN ('male','female','other','prefer_not_to_say')`),
    check(
      "gender_preference_check",
      sql`${table.genderPreference} IN ('any','same_gender_only')`,
    ),
  ],
);

export const otpRequests = pgTable("otp_requests", {
  id: uuid("id").primaryKey().defaultRandom(),
  phone: text("phone").notNull(),
  msg91RequestId: text("msg91_request_id").notNull(),
  attemptCount: integer("attempt_count").notNull().default(0),
  verifiedAt: timestamp("verified_at", { withTimezone: true }),
  expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

export const rideRequests = pgTable(
  "ride_requests",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id")
      .notNull()
      .references(() => users.id),
    flightNumber: text("flight_number").notNull(),
    flightArrivalAt: timestamp("flight_arrival_at", { withTimezone: true }).notNull(),
    arrivalWindowStart: timestamp("arrival_window_start", { withTimezone: true }).notNull(),
    arrivalWindowEnd: timestamp("arrival_window_end", { withTimezone: true }).notNull(),
    destinationAddress: text("destination_address").notNull(),
    destinationLat: doublePrecision("destination_lat").notNull(),
    destinationLng: doublePrecision("destination_lng").notNull(),
    h3CellRes7: text("h3_cell_res7").notNull(),
    h3CellRes8: text("h3_cell_res8").notNull(),
    destinationLocalityLabel: text("destination_locality_label").notNull(),
    status: text("status").notNull().default("open"),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [
    check("status_check", sql`${table.status} IN ('open','matched','expired','cancelled')`),
    index("ride_requests_status_h3res7_idx").on(table.status, table.h3CellRes7),
    index("ride_requests_status_window_idx").on(
      table.status,
      table.arrivalWindowStart,
      table.arrivalWindowEnd,
    ),
  ],
);

export const matches = pgTable(
  "matches",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    rideRequestAId: uuid("ride_request_a_id")
      .notNull()
      .references(() => rideRequests.id),
    rideRequestBId: uuid("ride_request_b_id")
      .notNull()
      .references(() => rideRequests.id),
    userAId: uuid("user_a_id")
      .notNull()
      .references(() => users.id),
    userBId: uuid("user_b_id")
      .notNull()
      .references(() => users.id),
    status: text("status").notNull(),
    score: numeric("score"),
    respondedAtA: timestamp("responded_at_a", { withTimezone: true }),
    respondedAtB: timestamp("responded_at_b", { withTimezone: true }),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [
    check(
      "match_status_check",
      sql`${table.status} IN ('proposed_by_a','proposed_by_b','mutual','rejected','expired')`,
    ),
    uniqueIndex("matches_pair_unique_idx").on(
      sql`LEAST(${table.rideRequestAId}, ${table.rideRequestBId})`,
      sql`GREATEST(${table.rideRequestAId}, ${table.rideRequestBId})`,
    ),
  ],
);

export const chatMessages = pgTable(
  "chat_messages",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    matchId: uuid("match_id")
      .notNull()
      .references(() => matches.id),
    senderId: uuid("sender_id")
      .notNull()
      .references(() => users.id),
    body: text("body").notNull(),
    // precision: 3 (milliseconds) so this round-trips exactly through JSON for
    // the /messages?after= polling cursor -- without it, Postgres' microsecond
    // precision means a cursor built from a truncated-to-ms timestamp can still
    // match the very message it's meant to exclude.
    createdAt: timestamp("created_at", { withTimezone: true, precision: 3 })
      .notNull()
      .defaultNow(),
    readAt: timestamp("read_at", { withTimezone: true }),
  },
  (table) => [index("chat_messages_match_created_idx").on(table.matchId, table.createdAt)],
);

export const reports = pgTable(
  "reports",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    reporterId: uuid("reporter_id")
      .notNull()
      .references(() => users.id),
    reportedId: uuid("reported_id")
      .notNull()
      .references(() => users.id),
    matchId: uuid("match_id").references(() => matches.id),
    reason: text("reason").notNull(),
    details: text("details"),
    status: text("status").notNull().default("open"),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [
    check(
      "report_reason_check",
      sql`${table.reason} IN ('harassment','no_show','inappropriate_messages','fake_profile','safety_concern','other')`,
    ),
    check("report_status_check", sql`${table.status} IN ('open','reviewed','actioned')`),
  ],
);

export const blocks = pgTable(
  "blocks",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    blockerId: uuid("blocker_id")
      .notNull()
      .references(() => users.id),
    blockedId: uuid("blocked_id")
      .notNull()
      .references(() => users.id),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [uniqueIndex("blocks_blocker_blocked_unique_idx").on(table.blockerId, table.blockedId)],
);
