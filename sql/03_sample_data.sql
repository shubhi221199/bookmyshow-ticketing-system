USE bookmyshow;

INSERT INTO users (user_id, email, full_name) VALUES
    (1, 'anaya@example.com', 'Anaya Rao'),
    (2, 'rohan@example.com', 'Rohan Mehta'),
    (3, 'devika@example.com', 'Devika Nair');

INSERT INTO movies (movie_id, title, language_code, duration_minutes, certificate) VALUES
    (101, 'The Last Monsoon', 'en', 142, 'UA'),
    (102, 'Paper Lanterns', 'hi', 118, 'U');

INSERT INTO theatres (theatre_id, name, address, city, time_zone) VALUES
    (201, 'Orion Screens', '18 Lake View Road', 'Bengaluru', 'Asia/Kolkata'),
    (202, 'Crescent Cinema', '4 Park Street', 'Kolkata', 'Asia/Kolkata');

INSERT INTO screens (screen_id, theatre_id, name) VALUES
    (301, 201, 'Screen 1'),
    (302, 201, 'Screen 2'),
    (303, 202, 'Screen 1');

INSERT INTO seats (seat_id, screen_id, row_label, seat_number, seat_type) VALUES
    (401, 301, 'A', 1, 'PREMIUM'),
    (402, 301, 'A', 2, 'PREMIUM'),
    (403, 301, 'B', 1, 'STANDARD'),
    (404, 301, 'B', 2, 'STANDARD'),
    (405, 302, 'A', 1, 'STANDARD'),
    (406, 302, 'A', 2, 'STANDARD'),
    (407, 303, 'A', 1, 'STANDARD'),
    (408, 303, 'A', 2, 'STANDARD');

INSERT INTO showtimes (showtime_id, screen_id, movie_id, starts_at_utc, ends_at_utc, status) VALUES
    (1001, 301, 101, '2026-10-01 13:30:00', '2026-10-01 15:52:00', 'SCHEDULED'),
    (1002, 302, 102, '2026-10-01 14:15:00', '2026-10-01 16:13:00', 'SCHEDULED'),
    (1003, 301, 102, '2026-10-02 13:00:00', '2026-10-02 14:58:00', 'SCHEDULED'),
    (1004, 303, 101, '2026-10-01 13:45:00', '2026-10-01 16:07:00', 'SCHEDULED');

INSERT INTO bookings (booking_id, showtime_id, user_id, status, hold_expires_at, total_amount, currency, created_at) VALUES
    (5001, 1001, 1, 'CONFIRMED', NULL, 600.00, 'INR', '2026-09-29 10:00:00');

INSERT INTO show_seats (showtime_id, seat_id, price)
SELECT sh.showtime_id,
       se.seat_id,
       CASE WHEN se.seat_type = 'PREMIUM' THEN 300.00 ELSE 200.00 END
FROM showtimes AS sh
JOIN seats AS se ON se.screen_id = sh.screen_id;

INSERT INTO booking_seats (booking_seat_id, booking_id, seat_id, price_at_booking) VALUES
    (5011, 5001, 401, 300.00),
    (5012, 5001, 402, 300.00);

INSERT INTO seat_allocations (showtime_id, seat_id, booking_seat_id, state, hold_expires_at) VALUES
    (1001, 401, 5011, 'BOOKED', NULL),
    (1001, 402, 5012, 'BOOKED', NULL);

INSERT INTO payments (payment_id, booking_id, provider, provider_payment_id, idempotency_key, amount, currency, status) VALUES
    (6001, 5001, 'DEMO_PAY', 'demo-payment-5001', 'booking-5001-attempt-1', 600.00, 'INR', 'SUCCEEDED');

INSERT INTO payment_webhook_events (webhook_event_id, provider, provider_event_id, payment_id, event_type, processing_status, payload, processed_at) VALUES
    (7001, 'DEMO_PAY', 'demo-event-5001-paid', 6001, 'payment.succeeded', 'PROCESSED',
        JSON_OBJECT('payment_id', 'demo-payment-5001', 'booking_id', 5001, 'amount', 600.00, 'currency', 'INR'),
     '2026-09-29 10:01:00');