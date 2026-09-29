# BookMyShow Ticketing Database Assignment

MySQL 8.0 schema and sample solution for theatre showtimes, seat inventory, time-limited holds, bookings, payments, and idempotent payment webhooks.

## Run the SQL

Use MySQL 8.0.16 or later (for enforced `CHECK` constraints). From the repository root, run these scripts in order:

```sh
mysql -u root -p < sql/01_create_database.sql
mysql -u root -p < sql/02_create_tables.sql
mysql -u root -p < sql/03_sample_data.sql
mysql -u root -p < sql/04_p1_queries.sql
mysql -u root -p < sql/05_p2_show_query.sql
```

The database bootstrap is non-destructive: it does not drop existing data. To reset a local assignment database, explicitly run `DROP DATABASE bookmyshow;` yourself before step 1.

## Deliverables

- [Database design, entities, sample rows, normalization, locking, and payment flow](docs/database-design.md)
- [PDF submission document](docs/database-design.pdf) and its [print-ready source](docs/database-design-print.html)
- [P1 schema](sql/02_create_tables.sql), [sample rows](sql/03_sample_data.sql), and [example queries](sql/04_p1_queries.sql)
- [P2 theatre/date show listing](sql/05_p2_show_query.sql)
- [Two-session SQL contention check](sql/06_concurrency_test.sql)
- [k6 seat contention test](tests/seat-contention.js)

The starter repository has no API service, so the k6 test is an executable contract test for a service exposing `POST /v1/holds`; the expected request, responses, and run instructions are in the design document .