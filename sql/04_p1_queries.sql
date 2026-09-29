USE bookmyshow;

-- Booking, seat, and payment view for the sample confirmed booking.
SELECT b.booking_id,
       b.status AS booking_status,
       u.full_name,
       m.title AS movie_title,
       ss.row_label,
       ss.seat_number,
       bs.price_at_booking,
       p.status AS payment_status,
       p.provider_payment_id
FROM bookings AS b
JOIN users AS u ON u.user_id = b.user_id
JOIN showtimes AS sh ON sh.showtime_id = b.showtime_id
JOIN movies AS m ON m.movie_id = sh.movie_id
JOIN booking_seats AS bs ON bs.booking_id = b.booking_id
JOIN show_seats AS inventory ON inventory.showtime_id = b.showtime_id AND inventory.seat_id = bs.seat_id
JOIN seats AS ss ON ss.seat_id = bs.seat_id
LEFT JOIN payments AS p ON p.booking_id = b.booking_id AND p.status = 'SUCCEEDED'
WHERE b.booking_id = 5001
ORDER BY ss.row_label, ss.seat_number;

-- Available inventory for a show (held seats are available only after expiry is claimed transactionally).
SELECT inventory.seat_id, inventory.price
FROM show_seats AS inventory
LEFT JOIN seat_allocations AS allocation
  ON allocation.showtime_id = inventory.showtime_id
 AND allocation.seat_id = inventory.seat_id
 AND (allocation.state = 'BOOKED'
      OR (allocation.state = 'HELD' AND allocation.hold_expires_at > UTC_TIMESTAMP()))
WHERE inventory.showtime_id = 1001
  AND allocation.seat_id IS NULL
ORDER BY inventory.seat_id;

-- Webhook deliveries are deduplicated by (provider, provider_event_id).
SELECT provider, provider_event_id, event_type, processing_status, received_at, processed_at
FROM payment_webhook_events
ORDER BY received_at DESC;