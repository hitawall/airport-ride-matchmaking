ALTER TABLE "users" DROP CONSTRAINT "users_phone_unique";--> statement-breakpoint
ALTER TABLE "otp_requests" DROP COLUMN "phone";--> statement-breakpoint
ALTER TABLE "otp_requests" DROP COLUMN "msg91_request_id";--> statement-breakpoint
ALTER TABLE "users" DROP COLUMN "phone";--> statement-breakpoint
ALTER TABLE "users" DROP COLUMN "phone_verified";