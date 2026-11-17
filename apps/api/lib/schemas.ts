import { z } from "zod";
import { DEFAULT_AIRPORT_CODE, findAirport, isValidTerminal } from "./airports";
import { normalizePhoneNumber } from "./phone";

/** Most trolley bags one rider can list. */
export const MAX_TROLLEY_BAGS = 6;

export const emailSchema = z.string().trim().toLowerCase().email("Enter a valid email address");

export const otpSendSchema = z.object({
  email: emailSchema,
});

export const googleSignInSchema = z.object({
  accessToken: z.string().min(10, "Missing Google sign-in").max(4096),
});

export const otpVerifySchema = z.object({
  email: emailSchema,
  requestId: z.string().min(1),
  code: z.string().min(4).max(8),
});

// Recorded for safety reporting only (never verified or used for auth), but it
// must be a real mobile number for a supported country (see lib/phone.ts). The
// parsed value is the normalized E.164 form, e.g. +919876543210.
export const phoneNumberSchema = z.string().transform((value, ctx) => {
  const normalized = normalizePhoneNumber(value);
  if (!normalized) {
    ctx.addIssue({ code: z.ZodIssueCode.custom, message: "Enter a valid 10-digit Indian mobile number" });
    return z.NEVER;
  }
  return normalized;
});

export const profileUpdateSchema = z.object({
  displayName: z.string().min(1).max(80),
  gender: z.enum(["male", "female", "other", "prefer_not_to_say"]),
  genderPreference: z.enum(["any", "same_gender_only"]),
  homeLocalityLabel: z.string().max(120).optional(),
  bio: z.string().max(280).optional(),
  phoneNumber: phoneNumberSchema,
  profilePhotoUrl: z.string().url().optional(),
});

export const rideRequestCreateSchema = z
  .object({
  // Defaults to the primary airport so a client that only knows one airport
  // keeps working. The terminal is always required.
  airportCode: z.string().min(2).max(8).default(DEFAULT_AIRPORT_CODE),
  terminal: z.string({ required_error: "Choose your terminal" }).min(1, "Choose your terminal").max(8),
  flightNumber: z.string().min(2).max(12).optional(),
  flightArrivalAt: z.string().datetime(),
  destinationAddress: z.string().min(1).max(240),
  destinationLat: z.number().gte(-90).lte(90),
  destinationLng: z.number().gte(-180).lte(180),
  destinationLocalityLabel: z.string().min(1).max(120),
  // Required: both riders should know how much luggage to expect.
  trolleyBags: z
    .number({ required_error: "Tell us how many trolley bags you have" })
    .int("Enter a whole number of trolley bags")
    .min(0)
    .max(MAX_TROLLEY_BAGS),
  })
  .superRefine((value, ctx) => {
    if (!findAirport(value.airportCode)) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ["airportCode"], message: "That airport isn't supported yet" });
    } else if (!isValidTerminal(value.airportCode, value.terminal)) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ["terminal"], message: "Choose a terminal from the list" });
    }
  });

export const matchActionSchema = z.object({
  rideRequestId: z.string().uuid(),
  candidateRideRequestId: z.string().uuid(),
  action: z.enum(["like", "pass"]),
});

export const chatMessageCreateSchema = z.object({
  body: z.string().min(1).max(2000),
});

export const reportCreateSchema = z.object({
  reportedUserId: z.string().uuid(),
  matchId: z.string().uuid().optional(),
  reason: z.enum([
    "harassment",
    "no_show",
    "inappropriate_messages",
    "fake_profile",
    "safety_concern",
    "other",
  ]),
  details: z.string().max(1000).optional(),
});

export const blockCreateSchema = z.object({
  blockedUserId: z.string().uuid(),
});

export const ratingCreateSchema = z.object({
  score: z.number().int().min(1).max(5),
});

export const feedbackCreateSchema = z.object({
  type: z.enum(["feature_request", "bug_report", "general"]),
  message: z.string().min(1).max(2000),
});
