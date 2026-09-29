USE bookmyshow;

-- Run this entire script concurrently in two MySQL sessions. Set
-- @test_user_id to 2 in session A and 3 in session B. Exactly one session
-- should acquire the same initially available seat.

SET @showtime_id = 1001;
SET @seat_id = 403;
SET @test_user_id = 2;
SET @hold_seconds = 300;

START TRANSACTION;

SET @hold_deadline = UTC_TIMESTAMP() + INTERVAL @hold_seconds SECOND;

INSERT INTO bookings (showtime_id, user_id, status, hold_expires_at)
VALUES (@showtime_id, @test_user_id, 'PENDING', @hold_deadline);
SET @booking_id = LAST_INSERT_ID();

-- Lock the stable inventory row; acquire multiple seats in ascending seat_id
-- order to reduce deadlocks for multi-seat requests.
SELECT price INTO @seat_price
FROM show_seats
WHERE showtime_id = @showtime_id AND seat_id = @seat_id
FOR UPDATE;

-- Expired holds must be released by the expiry worker before this test runs.
INSERT INTO booking_seats (booking_id, seat_id, price_at_booking)
SELECT @booking_id, inventory.seat_id, inventory.price
FROM show_seats AS inventory
WHERE inventory.showtime_id = @showtime_id
  AND inventory.seat_id = @seat_id;

SET @booking_seat_id = LAST_INSERT_ID();

-- INSERT IGNORE makes the unique inventory key the final guard if a caller
-- bypasses the expected serialization path. A duplicate yields zero rows.
INSERT IGNORE INTO seat_allocations (showtime_id, seat_id, booking_seat_id, state, hold_expires_at)
SELECT @showtime_id, @seat_id, @booking_seat_id, 'HELD', @hold_deadline
FROM DUAL;

SET @seats_acquired = ROW_COUNT();

UPDATE bookings
SET total_amount = IF(@seats_acquired = 1, @seat_price, 0.00),
    status = CASE WHEN @seats_acquired = 1 THEN 'PENDING' ELSE 'CANCELLED' END,
    hold_expires_at = CASE WHEN @seats_acquired = 1 THEN @hold_deadline ELSE NULL END
WHERE booking_id = @booking_id;

SELECT @seats_acquired AS seats_acquired;

COMMIT;

-- Expected: winner reports 1, loser reports 0 after waiting for the winner.
-- Verify the single current owner:
SELECT allocation.showtime_id,
       allocation.seat_id,
       allocation.state,
       booking_seat.booking_id,
       allocation.hold_expires_at
FROM seat_allocations AS allocation
JOIN booking_seats AS booking_seat ON booking_seat.booking_seat_id = allocation.booking_seat_id
WHERE allocation.showtime_id = @showtime_id AND allocation.seat_id = @seat_id;