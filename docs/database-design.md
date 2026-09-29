# BookMyShow Ticketing Database Design

## Scope and assumptions

The schema targets MySQL 8.0.16+ with InnoDB. Timestamps named `*_utc` are UTC `DATETIME` values; the application sets database sessions to UTC. Theatre-local calendar dates are converted to UTC half-open boundaries by the application using the theatre's IANA `time_zone`. This avoids relying on MySQL time-zone tables and correctly handles daylight-saving transitions.

The schema separates the theatre's physical seat map from per-show inventory. A row in `show_seats` is the single authoritative lock for one physical seat at one show. `show_seats` is materialized for every show when it is published.

## Entities and attributes

| Table | Attributes | Purpose |
|---|---|---|
| `users` | `user_id` PK, `email` UQ, `full_name`, `created_at` | Account placing a booking. |
| `movies` | `movie_id` PK, `title`, `language_code`, `duration_minutes`, `certificate` | Movie metadata shared by showtimes. |
| `theatres` | `theatre_id` PK, `name`, `address`, `city`, `time_zone` | Venue and its local calendar/time-zone context. |
| `screens` | `screen_id` PK, `theatre_id` FK, `name`; UQ `(theatre_id,name)` | Auditorium within a theatre. |
| `seats` | `seat_id` PK, `screen_id` FK, `row_label`, `seat_number`, `seat_type`; UQ `(screen_id,row_label,seat_number)` | Stable physical seat in a screen. |
| `showtimes` | `showtime_id` PK, `screen_id` FK, `movie_id` FK, `starts_at_utc`, `ends_at_utc`, `status` | A scheduled movie in one screen. |
| `bookings` | `booking_id` PK, `showtime_id` FK, `user_id` FK, `status`, `hold_expires_at`, `total_amount`, `currency`, timestamps | One user's booking attempt for a show. A `PENDING` booking has a deadline. |
| `show_seats` | PK `(showtime_id,seat_id)`, `price` | Per-show seat inventory and stable serialization row. |
| `booking_seats` | `booking_seat_id` PK, `booking_id` FK, `seat_id` FK, `price_at_booking`, `created_at`; UQ `(booking_id,seat_id)` | Historical seat/price snapshot for each booking attempt. |
| `seat_allocations` | PK `(showtime_id,seat_id)`, unique `booking_seat_id`, `state`, `hold_expires_at` | Current holds/booked ownership only; no row means unallocated. |
| `payments` | `payment_id` PK, `booking_id` FK, provider identifiers, `idempotency_key`, `amount`, `currency`, `status`, generated `successful_booking_id` | Payment attempts. Unique keys deduplicate requests and limit a booking to one successful payment. |
| `payment_webhook_events` | `webhook_event_id` PK, provider/event ID, `payment_id` FK, `event_type`, processing status, JSON payload, received/processed timestamps | Durable inbox for idempotent provider webhook processing. |
| `users` | `user_id` PK, `email` UQ, `full_name`, `created_at` | Account placing a booking. |
| `movies` | `movie_id` PK, `title`, `language_code`, `duration_minutes`, nullable `certificate` | Movie metadata shared by showtimes. |
| `theatres` | `theatre_id` PK, `name`, `address`, `city`, `time_zone` | Venue and its local calendar/time-zone context. |
| `screens` | `screen_id` PK, `theatre_id` FK, `name`; UQ `(theatre_id,name)` | Auditorium within a theatre. |
| `seats` | `seat_id` PK, `screen_id` FK, `row_label`, `seat_number`, `seat_type`; UQ `(screen_id,row_label,seat_number)` | Stable physical seat in a screen. |
| `showtimes` | `showtime_id` PK, `screen_id` FK, `movie_id` FK, `starts_at_utc`, `ends_at_utc`, `status` | A scheduled movie in one screen. |
| `bookings` | `booking_id` PK, `showtime_id` FK, `user_id` FK, `status`, nullable `hold_expires_at`, `total_amount`, `currency`, `created_at`, `updated_at` | One user's booking attempt for a show. A `PENDING` booking has a deadline. |
| `show_seats` | `showtime_id` PK part, `seat_id` PK part, `price` | Per-show seat inventory and stable serialization row. |
| `booking_seats` | `booking_seat_id` PK, `booking_id` FK, `seat_id` FK, `price_at_booking`, `created_at`; UQ `(booking_id,seat_id)` | Historical seat/price snapshot for each booking attempt. |
| `seat_allocations` | `showtime_id` PK part, `seat_id` PK part, `booking_seat_id` UQ/FK, `state`, nullable `hold_expires_at` | Current holds/booked ownership only; no row means unallocated. |
| `payments` | `payment_id` PK, `booking_id` FK, `provider`, nullable `provider_payment_id`, `idempotency_key`, `amount`, `currency`, `status`, generated nullable `successful_booking_id`, `created_at`, `updated_at` | Payment attempts. Unique keys deduplicate requests and limit a booking to one successful payment. |
| `payment_webhook_events` | `webhook_event_id` PK, `provider`, `provider_event_id` UQ, nullable `payment_id` FK, `event_type`, `processing_status`, `payload` JSON, `received_at`, nullable `processed_at` | Durable inbox for idempotent provider webhook processing. |

The complete executable definitions and sample rows are in `sql/02_create_tables.sql` and `sql/03_sample_data.sql`.

## Example rows

The fixture creates the following representative records (timestamps are UTC):

| Table | Example row |
|---|---|
| `users` | `(1, anaya@example.com, Anaya Rao)` |
| `movies` | `(101, The Last Monsoon, en, 142 min, UA)` |
| `theatres` | `(201, Orion Screens, Bengaluru, Asia/Kolkata)` |
| `screens` | `(301, theatre 201, Screen 1)` |
| `seats` | `(401, screen 301, A1, PREMIUM)` |
| `showtimes` | `(1001, screen 301, movie 101, 2026-10-01 13:30-15:52 UTC, SCHEDULED)` |
| `bookings` | `(5001, show 1001, user 1, CONFIRMED, INR 600.00)` |
| `show_seats` | `(show 1001, seat 401, INR 300.00)` |
| `booking_seats` | `(5011, booking 5001, seat 401, INR 300.00 at booking)` |
| `seat_allocations` | `(show 1001, seat 401, booking-seat 5011, BOOKED)` |
| `payments` | `(6001, booking 5001, DEMO_PAY, SUCCEEDED, INR 600.00)` |
| `payment_webhook_events` | `(7001, DEMO_PAY, demo-event-5001-paid, payment.succeeded, PROCESSED)` |

## Normalization

- **1NF:** Every field contains a single scalar value. Seat selections are rows in `booking_seats`, not a comma-separated list or array on `bookings`.
- **2NF:** Non-key attributes depend on the whole key. `booking_seats.price_at_booking` depends on its booking-seat row; show, seat, and booking attributes live in their own relations.
- **3NF:** Non-key attributes describe their table's key, not another non-key attribute. Theatre details are stored once in `theatres`; screens refer to theatres; showtimes refer to screens and movies. Theatre identity is not redundantly copied into showtimes.
- **BCNF:** Entity relations use candidate keys for their determinants: email determines a user, `(theatre_id,name)` determines a screen, `(screen_id,row_label,seat_number)` determines a physical seat, and `(showtime_id,seat_id)` determines one inventory row. `show_seats` does not repeat `screen_id` (which is determined by `showtime_id`); insert/update triggers enforce that the selected physical seat belongs to the showtime's screen. The current-allocation relation has two candidate keys, `(showtime_id,seat_id)` and `booking_seat_id`; either determines its state and deadline. Booking-seat history does not repeat `showtime_id`, which is determined by `booking_id`.

`show_seats.price` is the current offered price for that show-seat; `booking_seats.price_at_booking` intentionally snapshots the agreed price so later pricing changes do not alter a booking. They represent different facts, not duplicated mutable state. Active ownership is represented only by a `seat_allocations` row, while `booking_seats` remains the history.

## Seat holds and concurrency

The database, not Redis, decides ownership. Redis may provide fast temporary availability hints, but a Redis key expiring or becoming unavailable cannot authorize a booking. MySQL transactions are the correctness boundary:

1. Create a `PENDING` booking with `hold_expires_at = UTC_TIMESTAMP() + INTERVAL 5 MINUTE`.
2. Lock requested `show_seats` rows with `SELECT ... FOR UPDATE`, always in ascending `seat_id` order for multi-seat requests.
3. Insert a `booking_seats` price snapshot, then insert its `seat_allocations` row. An expired allocation must first be released transactionally. The allocation primary key `(showtime_id,seat_id)` is the final exclusivity guard; require affected-row count to equal requested seats or roll back the whole attempt.
4. Calculate/store the exact total from locked inventory rows and commit. Return success only after commit.
5. An expiry worker finds due pending bookings via `ix_bookings_expiry`, locks the booking and its inventory rows, and deletes only allocation rows still `HELD` for that booking and past deadline. It then changes the booking from `PENDING` to `EXPIRED` in the same transaction. `booking_seats` history remains.

The primary key `(showtime_id,seat_id)` ensures a single lockable inventory row per seat/show, while `seat_allocations` has a matching primary key to prevent duplicate active ownership. The transaction locks inventory first and inserts the allocation second. Triggers ensure a show inventory seat belongs to that show's screen and that allocation owner/show/seat values match; transactions over multiple seats either acquire the full requested set or acquire none.

### Expiry/payment race

Both the expiry worker and payment confirmation lock the booking and the relevant `show_seats` rows, using the same lock ordering. A payment success may confirm only a still-`PENDING` booking before expiry and only if all seats still have `HELD` allocation rows owned by its booking-seat records. It changes the booking to `CONFIRMED` and the allocation rows to `BOOKED` with null deadlines atomically. If expiry wins, a late successful payment cannot reclaim released inventory; mark the payment for refund/manual compensation instead. Never confirm a booking from a stale Redis hold.

`sql/06_concurrency_test.sql` contains the claim transaction for two independent MySQL sessions. Run both against the same initially available seat: one should acquire it and the other should report zero rows acquired after waiting.

## Idempotent payment webhooks

1. Verify the provider signature and timestamp before accepting the event.
2. Insert the event into `payment_webhook_events`. The unique `(provider,provider_event_id)` key is the idempotency boundary; on duplicate delivery, return the already recorded result rather than applying it twice.
3. In one transaction, lock the event/payment/booking, validate provider payment ID, amount, currency, and booking state, then apply the payment and booking/inventory transition. Mark the event `PROCESSED` and commit together.
4. Make downstream effects (ticket issue, email, refund) transactional-outbox jobs or independently idempotent consumers. Retry transient failures; preserve failed events for replay and alerting.

The unique payment idempotency key handles retried payment creation. The generated unique `successful_booking_id` allows only one `SUCCEEDED` payment per booking while still permitting multiple failed attempts.

## P1 and P2 execution

Run the SQL scripts in the order shown in the repository `README.md`. The sample creates two theatres, multiple screens, seats, movies, showtimes, one confirmed two-seat booking, one successful payment, and its webhook event.

For P2, `sql/05_p2_show_query.sql` lists scheduled movies and their start/end times for one theatre and day. Set `@theatre_id`, `@day_start_utc`, and `@day_end_utc`; the application should resolve local midnight for the selected date and the next date separately in the theatre time zone, then pass both UTC instants. The half-open filter (`>= start`, `< end`) avoids double-counting boundary shows and can use the `(screen_id,status,starts_at_utc)` index. For production, verify the plan with `EXPLAIN ANALYZE` against representative row counts and consider a covering index based on the measured workload. The seven-date picker can resolve and return the next seven theatre-local calendar dates independently of showtime retrieval.

## Load and burst test

The repository has no running HTTP service, so this project cannot produce a measured load result yet. `tests/seat-contention.js` is a k6 test designed for the service contract below; configure the test show-seat as available immediately before each run and point it at a deployed/test backend:

```sh
k6 run -e BASE_URL=http://localhost:8080 -e SHOW_ID=1001 -e SEAT_ID=403 -e VUS=500 tests/seat-contention.js
```

Expected endpoint contract: `POST /v1/holds` accepts `{ "showId": "1001", "seatIds": ["403"], "userId": "load-test-user-1" }`, returns `201` only after the hold transaction commits, and returns `409` to losing contenders. For 500 concurrent requests against the same seat, the test requires exactly one successful hold, conflicts for the rest, and less than 1% unexpected HTTP failures. Repeat with multiple seat IDs/shows and a ramped arrival-rate profile to measure throughput, p95/p99 latency, lock waits, deadlocks, database CPU, Redis pressure, expiry lag, and queue depth. Record the backend commit, MySQL size/configuration, k6 version, and results in the submission; a single-seat test proves exclusivity, not platform-wide capacity.

Do not run the destructive/reset steps against production data. Use an isolated test database and clean up or expire the test hold before rerunning.