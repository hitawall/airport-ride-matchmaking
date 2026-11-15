import { z } from "zod";

export const emailSchema = z.string().trim().toLowerCase().email("Enter a valid email address");

export const otpSendSchema = z.object({
  email: emailSchema,
});

export const otpVerifySchema = z.object({
  email: emailSchema,
  requestId: z.string().min(1),
  code: z.string().min(4).max(8),
});

// Loose, intentionally permissive -- this is recorded for reporting only,
// never verified or used for auth, so it just needs to look like a phone
// number (digits, optional leading +, 8-15 digits).
export const phoneNumberSchema = z
  .string()
  .trim()
  .regex(/^\+?\d{8,15}$/, "Enter a valid phone number");

export const profileUpdateSchema = z.object({
  displayName: z.string().min(1).max(80),
  gender: z.enum(["male", "female", "other", "prefer_not_to_say"]),
  genderPreference: z.enum(["any", "same_gender_only"]),
  homeLocalityLabel: z.string().max(120).optional(),
  bio: z.string().max(280).optional(),
  phoneNumber: phoneNumberSchema.optional(),
});

export const rideRequestCreateSchema = z.object({
  flightNumber: z.string().min(2).max(12).optional(),
  flightArrivalAt: z.string().datetime(),
  destinationAddress: z.string().min(1).max(240),
  destinationLat: z.number().gte(-90).lte(90),
  destinationLng: z.number().gte(-180).lte(180),
  destinationLocalityLabel: z.string().min(1).max(120),
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
