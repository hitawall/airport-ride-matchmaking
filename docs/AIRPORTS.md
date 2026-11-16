# Airports and terminals

People are matched only with others at the **same airport and the same
terminal**. Airports, terminals and the destination areas offered for each are
data in one file, so adding one is a small change with no app release.

## Where the data lives

`apps/api/lib/airports.ts` is the single source of truth. The API validates every
ride request against it, and the app loads it from the public `GET /api/airports`
(cached 5 minutes). The app shows a fixed airport line while only one airport
exists, and an airport dropdown as soon as there are two or more.

## Add a terminal

Add `{ code: "T3", name: "Terminal 3" }` to the airport's `terminals`. Codes are
stored in the database: never rename or reuse one.

## Add an airport

1. Append an entry to `AIRPORTS` in `apps/api/lib/airports.ts`: IATA `code`
   (e.g. `DEL`), `name`, `city`, its `terminals`, and a `localities` list (the
   destination areas people can pick, each with `lat` and `lng`).
2. Keep `DEFAULT_AIRPORT_CODE` as `BLR` (the preselected airport) unless you want a different default.
3. Deploy the API. The app picks it up on next launch; no database change is needed (`airport_code` and `terminal` are plain text columns).
4. Check the terminal wording and the pickup guidance for that airport on the welcome screen and in the safety text.

Matching needs no change: candidates and the like action both require equal
airport and terminal.

## Rules enforced

- Creating a ride request requires a valid terminal for the chosen airport (the airport defaults to BLR if omitted).
- The candidates query only returns open requests with the same `airport_code` and `terminal`.
- The like/pass endpoint rejects a pair whose airport or terminal differ (409), so a hand-made request cannot create a cross-terminal match.
- Requests created before terminals existed have no terminal: they match nobody and expire on their own (4 hours after the arrival window), so nothing needs cleaning up.

## Database change (one-off, additive)

Migration `0008` adds `ride_requests.airport_code` (not null, default `BLR`) and
`ride_requests.terminal` (nullable) plus an index. It is backward compatible:
old API code that inserts without those columns keeps working. Apply it **before**
the API deploy that reads them: `pnpm --filter @airport-ride-matchmaking/db migrate`.
