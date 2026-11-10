# MediGo backend

## Database setup

Configure the MySQL connection with `DATABASE_URL` or the supported `DB_*` /
`MYSQL*` variables. Apply schema changes before starting the server locally or
deploying it:

```sh
npm --prefix backend run migrate
```

The migration runner creates missing tables, adds profile columns to existing
tables, extends the user role enum, and seeds the medical taxonomy. It is
designed to be repeatable and does not clear application data. Do not execute
`config/migration.sql`; it is a safety notice for the retired destructive
migration. Back up the database before applying schema changes.

## Admin account

Public registration only accepts doctor, patient, laboratory, and pharmacy
roles. To bootstrap the first admin, set `ADMIN_EMAIL` and `ADMIN_PASSWORD`
securely in the process environment and run:

```sh
npm --prefix backend run create-admin
```

The password must contain at least 14 characters. Bootstrap refuses to replace
an existing admin and does not create default credentials.

## Admin-managed features

Authenticate as an admin to manage:

- The symptom-consultation price, configured as a positive whole-number DZD
  amount. No default price is seeded; patient checkout remains unavailable
  until an admin sets one.
- Simulated payment transaction history.
- Advertisements, including image upload, dashboard placement, scheduling,
  activation, and impression/click counts.
- Medical-condition-to-specialty mappings used for doctor recommendations.

Admin API routes are under `/api/admin` and require both a valid token and the
`admin` role. Patients can browse `/api/medical/taxonomy`, search doctors at
`/api/users/doctors`, view recommendations at `/api/patients/me/doctors`, and
confirm their treating doctor with `PUT /api/patients/me/doctor`.

## Simulated consultations

Only patients can create a paid symptom consultation at
`POST /api/consultations/symptoms/pay`. Doctors, laboratories, and pharmacies
are not charged. The simulator accepts only these documented demo card
numbers:

- `4111111111111111` — simulated success.
- `4000000000000002` — simulated decline.

No real payment is made and no bank or payment provider is contacted. The
backend stores the transaction reference, amount/currency, status, idempotency
key, and card last four digits only; it does not persist the card number, CVV,
expiry, or cardholder name. A consultation is created only after simulated
success. Use a unique `idempotency_key` for each intentional payment attempt
and reuse it when retrying the same request.

## Verification

Run backend unit tests and syntax checks with:

```sh
npm --prefix backend test
```

The tests cover demo-card acceptance, expiry validation, success/decline
behavior, payment idempotency, and legacy patient identity lookup.
