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
migration. Back up the database before applying schema changes. Railway's
`npm start` command runs this migration before starting the API, so the Railway
service must have valid MySQL connection variables configured. The API and
migration use the same connection resolver, including the same URL precedence
and Railway-private-host TLS behavior. Startup logs the selected database name
and verifies every schema table plus the authentication columns before serving
requests.

The backend enables MySQL TLS by default for external host-based connections.
For Railway services in the same project and environment, use the internal
`MYSQLHOST`/`MYSQL_URL` connection: Railway encrypts private service traffic
over WireGuard, and its MySQL server may reject a separate MySQL TLS handshake.
That private hostname therefore never enables driver TLS, even if a stale
`DB_SSL=true` variable is set. The connection code also removes TLS query
options from a Railway-private MySQL URL. For external database hosts,
`DB_SSL=true` enables TLS and TLS remains enabled by default for host-based
connections. Do not disable TLS for a public or otherwise untrusted database
connection.

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

## Patient medical assistant

The patient-only AI chat is served at `/api/medical-assistant`. It uses an
official Google GenAI SDK to call Gemini Developer API from the backend; no
provider credentials belong in the Flutter app. The backend is restricted to
the free-tier `gemini-3.5-flash-lite` model and does not fall back to another
provider or model. Configure these backend environment variables:

- `AI_PROVIDER=gemini`
- `AI_API_KEY`: secret API key for the selected AI provider.
- `AI_MODEL=gemini-3.5-flash-lite`.
- `MEDICAL_CHAT_ENCRYPTION_KEY`: base64-encoded, randomly generated 32-byte
  key used for AES-256-GCM encryption of chat messages and consented summaries.

Generate the encryption key with
`node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"`.
Store it in the server's secret manager, back it up securely, and keep it stable:
changing or losing it makes existing encrypted conversations unreadable. Chat
messages and the recent conversation history are encrypted in the database.
Before they are sent to Gemini, the backend redacts common email, phone/ID,
explicit name, and address patterns. This pattern-based redaction is not
complete and cannot reliably detect every name or identifying detail.

**Privacy limitation:** Google's Gemini Developer API free tier states that
submitted content may be used to improve Google's products. Symptom text is
sensitive health information even after direct identifiers are removed. Do not
use the free tier for real patient data or production healthcare until legal,
privacy, security, and consent requirements have been reviewed and the provider's
current data-processing and retention terms are acceptable. Keep the API key
only in the backend secret manager or ignored `backend/.env`, and serve the
mobile API over HTTPS.

Apply the additive tables with `npm --prefix backend run migrate`. Without
provider or encryption configuration the API returns an explicit unavailable
error; it does not generate fallback or canned chat replies. Gemini model
unavailability and free-tier rate limits are reported explicitly and never
trigger a paid-model fallback. Only a patient can access their own
conversations. A symptom summary is shared with a selected doctor only when the
patient explicitly opts in; without consent the doctor receives a consultation
request without symptom details.

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
