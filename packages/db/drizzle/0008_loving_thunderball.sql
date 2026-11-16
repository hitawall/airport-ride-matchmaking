ALTER TABLE "ride_requests" ADD COLUMN "airport_code" text DEFAULT 'BLR' NOT NULL;--> statement-breakpoint
ALTER TABLE "ride_requests" ADD COLUMN "terminal" text;--> statement-breakpoint
CREATE INDEX "ride_requests_status_airport_terminal_idx" ON "ride_requests" USING btree ("status","airport_code","terminal");