USE bookmyshow;

-- Set these UTC bounds in the application after resolving the selected local date
-- in the theatre's IANA time zone. The half-open interval handles DST days of
-- 23 or 25 hours and keeps the indexed starts_at_utc column sargable.
SET @theatre_id = 201;
SET @day_start_utc = '2026-09-30 18:30:00';
SET @day_end_utc = '2026-10-01 18:30:00';

SELECT sh.showtime_id,
       m.movie_id,
       m.title AS movie_title,
       m.language_code,
       sc.name AS screen_name,
       sh.starts_at_utc,
       sh.ends_at_utc,
       th.time_zone AS theatre_time_zone
FROM theatres AS th
JOIN screens AS sc ON sc.theatre_id = th.theatre_id
JOIN showtimes AS sh ON sh.screen_id = sc.screen_id
JOIN movies AS m ON m.movie_id = sh.movie_id
WHERE th.theatre_id = @theatre_id
  AND sh.status = 'SCHEDULED'
  AND sh.starts_at_utc >= @day_start_utc
  AND sh.starts_at_utc < @day_end_utc
ORDER BY sh.starts_at_utc, m.title, sc.name;