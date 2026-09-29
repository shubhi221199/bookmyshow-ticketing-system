USE bookmyshow;

CREATE TABLE users (
    user_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    email VARCHAR(254) NOT NULL,
    full_name VARCHAR(160) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id),
    UNIQUE KEY uq_users_email (email)
) ENGINE = InnoDB;

CREATE TABLE movies (
    movie_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    title VARCHAR(200) NOT NULL,
    language_code VARCHAR(12) NOT NULL,
    duration_minutes SMALLINT UNSIGNED NOT NULL,
    certificate VARCHAR(12) NULL,
    PRIMARY KEY (movie_id),
    CONSTRAINT chk_movies_duration CHECK (duration_minutes > 0)
) ENGINE = InnoDB;

CREATE TABLE theatres (
    theatre_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(180) NOT NULL,
    address VARCHAR(300) NOT NULL,
    city VARCHAR(100) NOT NULL,
    time_zone VARCHAR(64) NOT NULL,
    PRIMARY KEY (theatre_id),
    KEY ix_theatres_city_name (city, name)
) ENGINE = InnoDB;

CREATE TABLE screens (
    screen_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    theatre_id BIGINT UNSIGNED NOT NULL,
    name VARCHAR(80) NOT NULL,
    PRIMARY KEY (screen_id),
    UNIQUE KEY uq_screens_theatre_name (theatre_id, name),
    CONSTRAINT fk_screens_theatre FOREIGN KEY (theatre_id)
        REFERENCES theatres (theatre_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE seats (
    seat_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    screen_id BIGINT UNSIGNED NOT NULL,
    row_label VARCHAR(8) NOT NULL,
    seat_number SMALLINT UNSIGNED NOT NULL,
    seat_type VARCHAR(24) NOT NULL,
    PRIMARY KEY (seat_id),
    UNIQUE KEY uq_seats_position (screen_id, row_label, seat_number),
    CONSTRAINT chk_seats_number CHECK (seat_number > 0),
    CONSTRAINT fk_seats_screen FOREIGN KEY (screen_id)
        REFERENCES screens (screen_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE showtimes (
    showtime_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    screen_id BIGINT UNSIGNED NOT NULL,
    movie_id BIGINT UNSIGNED NOT NULL,
    starts_at_utc DATETIME NOT NULL,
    ends_at_utc DATETIME NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'SCHEDULED',
    PRIMARY KEY (showtime_id),
    KEY ix_showtimes_screen_status_start (screen_id, status, starts_at_utc),
    KEY ix_showtimes_movie (movie_id),
    CONSTRAINT chk_showtimes_time CHECK (ends_at_utc > starts_at_utc),
    CONSTRAINT chk_showtimes_status CHECK (status IN ('SCHEDULED', 'CANCELLED', 'COMPLETED')),
    CONSTRAINT fk_showtimes_screen FOREIGN KEY (screen_id)
        REFERENCES screens (screen_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_showtimes_movie FOREIGN KEY (movie_id)
        REFERENCES movies (movie_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE bookings (
    booking_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    showtime_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    status VARCHAR(16) NOT NULL,
    hold_expires_at DATETIME NULL,
    total_amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    currency CHAR(3) NOT NULL DEFAULT 'INR',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (booking_id),
    KEY ix_bookings_expiry (status, hold_expires_at),
    KEY ix_bookings_user_created (user_id, created_at),
    CONSTRAINT chk_bookings_status CHECK (status IN ('PENDING', 'CONFIRMED', 'EXPIRED', 'CANCELLED', 'PAYMENT_FAILED')),
    CONSTRAINT chk_bookings_amount CHECK (total_amount >= 0),
    CONSTRAINT chk_bookings_hold_expiry CHECK ((status = 'PENDING' AND hold_expires_at IS NOT NULL) OR (status <> 'PENDING' AND hold_expires_at IS NULL)),
    CONSTRAINT fk_bookings_showtime FOREIGN KEY (showtime_id)
        REFERENCES showtimes (showtime_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_bookings_user FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE show_seats (
    showtime_id BIGINT UNSIGNED NOT NULL,
    seat_id BIGINT UNSIGNED NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (showtime_id, seat_id),
    CONSTRAINT chk_show_seats_price CHECK (price >= 0),
    CONSTRAINT fk_show_seats_show FOREIGN KEY (showtime_id)
        REFERENCES showtimes (showtime_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_show_seats_seat FOREIGN KEY (seat_id)
        REFERENCES seats (seat_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE booking_seats (
    booking_seat_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    booking_id BIGINT UNSIGNED NOT NULL,
    seat_id BIGINT UNSIGNED NOT NULL,
    price_at_booking DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (booking_seat_id),
    UNIQUE KEY uq_booking_seats_booking_seat (booking_id, seat_id),
    KEY ix_booking_seats_seat (seat_id),
    CONSTRAINT chk_booking_seats_price CHECK (price_at_booking >= 0),
    CONSTRAINT fk_booking_seats_booking FOREIGN KEY (booking_id)
        REFERENCES bookings (booking_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_booking_seats_seat FOREIGN KEY (seat_id)
        REFERENCES seats (seat_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE seat_allocations (
    showtime_id BIGINT UNSIGNED NOT NULL,
    seat_id BIGINT UNSIGNED NOT NULL,
    booking_seat_id BIGINT UNSIGNED NOT NULL,
    state VARCHAR(8) NOT NULL,
    hold_expires_at DATETIME NULL,
    PRIMARY KEY (showtime_id, seat_id),
    UNIQUE KEY uq_seat_allocations_booking_seat (booking_seat_id),
    KEY ix_seat_allocations_expiry (state, hold_expires_at),
    CONSTRAINT chk_seat_allocations_state CHECK (state IN ('HELD', 'BOOKED')),
    CONSTRAINT chk_seat_allocations_expiry CHECK (
        (state = 'HELD' AND hold_expires_at IS NOT NULL)
        OR (state = 'BOOKED' AND hold_expires_at IS NULL)
    ),
    CONSTRAINT fk_seat_allocations_inventory FOREIGN KEY (showtime_id, seat_id)
        REFERENCES show_seats (showtime_id, seat_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_seat_allocations_booking_seat FOREIGN KEY (booking_seat_id)
        REFERENCES booking_seats (booking_seat_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE payments (
    payment_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    booking_id BIGINT UNSIGNED NOT NULL,
    provider VARCHAR(32) NOT NULL,
    provider_payment_id VARCHAR(128) NULL,
    idempotency_key VARCHAR(128) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    currency CHAR(3) NOT NULL,
    status VARCHAR(16) NOT NULL,
    successful_booking_id BIGINT UNSIGNED GENERATED ALWAYS AS (
        CASE WHEN status = 'SUCCEEDED' THEN booking_id ELSE NULL END
    ) STORED,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (payment_id),
    UNIQUE KEY uq_payments_idempotency (idempotency_key),
    UNIQUE KEY uq_payments_provider_payment (provider, provider_payment_id),
    UNIQUE KEY uq_payments_successful_booking (successful_booking_id),
    KEY ix_payments_booking (booking_id, created_at),
    CONSTRAINT chk_payments_amount CHECK (amount >= 0),
    CONSTRAINT chk_payments_status CHECK (status IN ('INITIATED', 'AUTHORIZED', 'SUCCEEDED', 'FAILED', 'REFUNDED')),
    CONSTRAINT fk_payments_booking FOREIGN KEY (booking_id)
        REFERENCES bookings (booking_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE payment_webhook_events (
    webhook_event_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    provider VARCHAR(32) NOT NULL,
    provider_event_id VARCHAR(160) NOT NULL,
    payment_id BIGINT UNSIGNED NULL,
    event_type VARCHAR(80) NOT NULL,
    processing_status VARCHAR(16) NOT NULL DEFAULT 'RECEIVED',
    payload JSON NOT NULL,
    received_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP NULL,
    PRIMARY KEY (webhook_event_id),
    UNIQUE KEY uq_webhook_provider_event (provider, provider_event_id),
    KEY ix_webhook_status_received (processing_status, received_at),
    CONSTRAINT chk_webhook_processing_status CHECK (processing_status IN ('RECEIVED', 'PROCESSED', 'FAILED')),
    CONSTRAINT fk_webhook_payment FOREIGN KEY (payment_id)
        REFERENCES payments (payment_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

DELIMITER $$

CREATE TRIGGER trg_show_seats_validate_screen_insert
BEFORE INSERT ON show_seats
FOR EACH ROW
BEGIN
    DECLARE show_screen_id BIGINT UNSIGNED;
    DECLARE seat_screen_id BIGINT UNSIGNED;

    SELECT screen_id INTO show_screen_id
    FROM showtimes
    WHERE showtime_id = NEW.showtime_id;

    SELECT screen_id INTO seat_screen_id
    FROM seats
    WHERE seat_id = NEW.seat_id;

    IF show_screen_id <> seat_screen_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Seat must belong to the showtime screen';
    END IF;
END$$

CREATE TRIGGER trg_show_seats_validate_screen_update
BEFORE UPDATE ON show_seats
FOR EACH ROW
BEGIN
    DECLARE show_screen_id BIGINT UNSIGNED;
    DECLARE seat_screen_id BIGINT UNSIGNED;

    SELECT screen_id INTO show_screen_id
    FROM showtimes
    WHERE showtime_id = NEW.showtime_id;

    SELECT screen_id INTO seat_screen_id
    FROM seats
    WHERE seat_id = NEW.seat_id;

    IF show_screen_id <> seat_screen_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Seat must belong to the showtime screen';
    END IF;
END$$

CREATE TRIGGER trg_booking_seats_validate_show_insert
BEFORE INSERT ON booking_seats
FOR EACH ROW
BEGIN
    DECLARE booking_showtime_id BIGINT UNSIGNED;
    DECLARE matching_inventory_rows INT;

    SELECT showtime_id INTO booking_showtime_id
    FROM bookings
    WHERE booking_id = NEW.booking_id;

    SELECT COUNT(*) INTO matching_inventory_rows
    FROM show_seats
    WHERE showtime_id = booking_showtime_id AND seat_id = NEW.seat_id;

    IF matching_inventory_rows <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Booking seat must exist in the booking showtime inventory';
    END IF;
END$$

CREATE TRIGGER trg_seat_allocations_validate_owner_insert
BEFORE INSERT ON seat_allocations
FOR EACH ROW
BEGIN
    DECLARE owner_booking_id BIGINT UNSIGNED;
    DECLARE owner_seat_id BIGINT UNSIGNED;
    DECLARE booking_showtime_id BIGINT UNSIGNED;

    SELECT booking_id, seat_id INTO owner_booking_id, owner_seat_id
    FROM booking_seats
    WHERE booking_seat_id = NEW.booking_seat_id;

    SELECT showtime_id INTO booking_showtime_id
    FROM bookings
    WHERE booking_id = owner_booking_id;

    IF owner_seat_id <> NEW.seat_id OR booking_showtime_id <> NEW.showtime_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Seat allocation must match its booking seat';
    END IF;
END$$

CREATE TRIGGER trg_seat_allocations_validate_owner_update
BEFORE UPDATE ON seat_allocations
FOR EACH ROW
BEGIN
    DECLARE owner_booking_id BIGINT UNSIGNED;
    DECLARE owner_seat_id BIGINT UNSIGNED;
    DECLARE booking_showtime_id BIGINT UNSIGNED;

    SELECT booking_id, seat_id INTO owner_booking_id, owner_seat_id
    FROM booking_seats
    WHERE booking_seat_id = NEW.booking_seat_id;

    SELECT showtime_id INTO booking_showtime_id
    FROM bookings
    WHERE booking_id = owner_booking_id;

    IF owner_seat_id <> NEW.seat_id OR booking_showtime_id <> NEW.showtime_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Seat allocation must match its booking seat';
    END IF;
END$$

DELIMITER ;