ALTER TABLE "otp_requests" ADD COLUMN "email" text;--> statement-breakpoint
ALTER TABLE "otp_requests" ADD COLUMN "request_id" text;--> statement-breakpoint
ALTER TABLE "otp_requests" ADD COLUMN "code" text;--> statement-breakpoint
ALTER TABLE "profiles" ADD COLUMN "phone_number" text;--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "email" text;--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "email_verified" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "users" ADD CONSTRAINT "users_email_unique" UNIQUE("email");