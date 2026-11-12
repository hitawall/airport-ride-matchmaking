import { z } from "zod";

// Indian mobile numbers, normalized to +91XXXXXXXXXX before any DB/MSG91 call.
export const phoneSchema = z
  .string()
  .regex(/^\+91[6-9]\d{9}$/, "Phone must be in +91XXXXXXXXXX format");

export const otpSendSchema = z.object({
  phone: phoneSchema,
});

export const otpVerifySchema = z.object({
  phone: phoneSchema,
  requestId: z.string().min(1),
  code: z.string().min(4).max(8),
});

export const profileUpdateSchema = z.object({
  displayName: z.string().min(1).max(80),
  gender: z.enum(["male", "female", "other", "prefer_not_to_say"]),
  genderPreference: z.enum(["any", "same_gender_only"]),
  homeLocalityLabel: z.string().max(120).optional(),
  bio: z.string().max(280).optional(),
});

export const rideRequestCreateSchema = z.object({
  flightNumber: z.string().min(2).max(12),
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
