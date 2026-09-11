# telehealth-clinical-api

GraphQL API for telehealth scheduling and clinical records. Rails 8.1, Devise + JWT,
Sidekiq, PostgreSQL 16, Redis 7.

This is the **clinical half** of a two-service system. The other half is
**[telehealth-billing-service](https://github.com/wasdevv/telehealth-billing-service)** —
a Django service that owns invoices, payments and outbound patient messaging, with its
own database. Neither service reaches into the other's tables; they talk over the HTTP
contract documented below.

---

## Architecture

```
                         ┌───────────────────────────────────────┐
                         │  Client (mobile / SPA / curl)         │
                         │  Authorization: Bearer <JWT>          │
                         └───────────────────┬───────────────────┘
                                             │
                                   POST /graphql   (one endpoint,
                                             │      whole domain)
                                             ▼
   ┌───────────────────────────────────────────────────────────────────────────┐
   │  telehealth-clinical-api        Rails 8.1, API mode        THIS REPO      │
   │                                                                           │
   │   /auth/login  /auth/logout  /auth/google_oauth2  /auth/2fa/*   /up       │
   │   ─────────────────────────────────────────────────────────────────────   │
   │   GraphQL schema  ──▶  Interactors  ──▶  Models                           │
   │   (depth 10,           Appointments::Book / Cancel                        │
   │    complexity 1000,    MedicalRecords::Create                             │
   │    page size 25)       pessimistic lock, side effects after commit        │
   └───────┬───────────────────────────┬───────────────────────────┬───────────┘
           │                           │                           │
           ▼                           ▼                           │
   ┌────────────────┐         ┌──────────────────┐                 │
   │ PostgreSQL 16  │         │  Redis 7         │                 │
   │                │         │                  │                 │
   │ users          │         │  Sidekiq queues: │                 │
   │ patients       │         │   notifications  │                 │
   │ doctors        │         │   default        │                 │
   │ availabilities │         │   maintenance    │                 │
   │ appointments   │         │  + sidekiq-cron  │                 │
   │ medical_records│  ← PHI, │  + Rails.cache   │                 │
   │                │  encrypted                 │                 │
   │ audit_logs     │         └──────────────────┘                 │
   │ jwt_denylists  │                                              │
   └────────────────┘                                              │
                                                                   │
              Token <INTERNAL_SERVICE_TOKEN>, Idempotency-Key      │
                                                                   ▼
   ┌───────────────────────────────────────────────────────────────────────────┐
   │  telehealth-billing-service     Django              SEPARATE REPO         │
   │                                                                           │
   │   POST /api/v1/invoices/                 create or recognise an invoice   │
   │   POST /api/v1/invoices/void/            void by external_ref             │
   │   POST /api/v1/notifications/reminder/   email + SMS                      │
   └───────────────────────────────┬───────────────────────────────────────────┘
                                   ▼
                           ┌───────────────┐
                           │ PostgreSQL    │  ← the billing database.
                           │ (billing's)   │    A different database on purpose.
                           └───────────────┘
```

---

## Setup

### Requirements

Ruby 3.4.4, PostgreSQL 16, Redis 7. Or just Docker.

### Locally

```bash
bundle install
cp .env.example .env

# Generate the secrets .env asks for:
bin/rails secret                # SECRET_KEY_BASE, and again for DEVISE_JWT_SECRET_KEY
bin/rails db:encryption:init    # the three ACTIVE_RECORD_ENCRYPTION_* keys

bin/rails db:prepare
bin/rails db:seed               # development only; refuses to run anywhere else

bin/rails server                                     # API on :3000
bundle exec sidekiq -C config/sidekiq.yml            # workers, in a second terminal
```

`http://localhost:3000/sidekiq` shows the queues. It is mounted in **development only** —
it has no authentication of its own, so exposing it in production would hand anyone the
queue console.

The seeds create these accounts, all with the password `telehealth-demo-2026`:

| Email | Role |
|---|---|
| `admin@example.com` | admin |
| `dr.reyes@example.com` | doctor (cardiology) |
| `dr.okafor@example.com` | doctor (dermatology) |
| `sam.patient@example.com` | patient |
| `kai.patient@example.com` | patient (no phone on file) |

### With Docker

```bash
cp .env.example .env     # fill in the secrets; compose refuses to start without them
docker compose -f docker-compose.standalone.yml up --build
```

Four containers with healthchecks: `api`, `sidekiq`, `postgres:16`, `redis:7`. Only `api`
prepares the schema (`PREPARE_DATABASE=true`), so the two app containers never race to
migrate.

`DJANGO_BILLING_URL` defaults to `http://billing:8000`. This file does **not** define a
`billing` service — that is the sibling repository's container. On its own, invoice calls
time out, and the API is built to survive exactly that: the appointment is kept and the
invoice is retried in the background. To run both services together, put them on one
network with the billing service named `billing`.

### Tests and lint

```bash
bundle exec rspec
bundle exec rubocop
```

---

## Using the API

### 1. Log in

```bash
curl -sX POST http://localhost:3000/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"user":{"email":"sam.patient@example.com","password":"telehealth-demo-2026"}}'
```

```json
{ "token": "eyJhbGciOi...", "user": { "id": 4, "email": "sam.patient@example.com", "role": "patient", "two_factor_enabled": false } }
```

The token also comes back in the `Authorization` response header. Send it on every
GraphQL request:

```bash
export TOKEN=...
```

If the account has a second factor, this step returns **`202` and no token** — see
[Two-factor](#two-factor-authentication).

### 2. Who am I

```bash
curl -sX POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"query":"{ me { id email role patient { fullName } } }"}'
```

### 3. Find a doctor and a free slot

```bash
curl -sX POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"query":"{ doctors(specialty: \"cardiology\") { edges { node { id fullName specialty availabilities { id startsAt endsAt } } } } }"}'
```

### 4. Book it

```bash
curl -sX POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"query":"mutation { bookAppointment(availabilityId: \"1\") { resource { id status startsAt externalRef doctor { fullName } } errors { field code message } } }"}'
```

```json
{"data":{"bookAppointment":{
  "resource":{"id":"1","status":"SCHEDULED","startsAt":"2026-09-12T10:00:00Z",
              "externalRef":"appointment:1","doctor":{"fullName":"Dr. Ana Reyes"}},
  "errors":[]}}}
```

Booking a slot that is already taken returns the same shape with `resource: null`:

```json
{"errors":[{"field":"availabilityId","code":"slot_taken","message":"That slot is already booked."}]}
```

### 5. List your appointments

```bash
curl -sX POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"query":"query($from: ISO8601DateTime) { myAppointments(status: SCHEDULED, from: $from) { edges { node { id startsAt status doctor { fullName } } } pageInfo { hasNextPage endCursor } } }","variables":{"from":"2026-01-01T00:00:00Z"}}'
```

### 6. Cancel

```bash
curl -sX POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"query":"mutation { cancelAppointment(id: \"1\", reason: \"Feeling better\") { resource { id status } errors { field code message } } }"}'
```

### 7. File a clinical record (doctor only)

```bash
curl -sX POST http://localhost:3000/graphql \
  -H "Content-Type: application/json" -H "Authorization: Bearer $DOCTOR_TOKEN" \
  -d '{"query":"mutation { addMedicalRecord(appointmentId: \"1\", diagnosis: \"Essential hypertension\", notes: \"BP 150/95, start amlodipine 5mg\") { resource { id diagnosis } errors { field code message } } }"}'
```

### 8. Log out (revokes the token)

```bash
curl -siX DELETE http://localhost:3000/auth/logout -H "Authorization: Bearer $TOKEN"
```

The token's `jti` goes on the denylist; the next request with it gets `401`.

### Every mutation answers in one shape

```graphql
{
  resource { ... }                       # null when the mutation failed
  errors { field code message }          # empty when it succeeded
}
```

`code` is the stable half — `slot_taken`, `in_the_past`, `not_found`, `not_cancellable`,
`not_responsible_doctor`, `record_exists`, `invoice_rejected`, `missing_profile`.
`message` is for humans and may be reworded.

---

## Two-factor authentication

```bash
# 1. Enrol (authenticated). Returns an otpauth:// URI and an SVG QR code.
#    Nothing is enabled yet.
curl -sX POST http://localhost:3000/auth/2fa/setup -H "Authorization: Bearer $TOKEN"

# 2. Prove the phone has the secret. Only now does the factor go live, and only now
#    are recovery codes issued — this is the one and only time they are shown.
curl -sX POST http://localhost:3000/auth/2fa/enable \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"code":"041304"}'

# 3. From now on, logging in returns 202 with a challenge instead of a token.
curl -sX POST http://localhost:3000/auth/login -H 'Content-Type: application/json' \
  -d '{"user":{"email":"sam.patient@example.com","password":"telehealth-demo-2026"}}'
# => {"two_factor_required":true,"challenge":"eyJfcmFpbHMi...","expires_in":300}

# 4. Exchange the challenge plus a code for the token.
curl -sX POST http://localhost:3000/auth/2fa/verify -H 'Content-Type: application/json' \
  -d '{"challenge":"eyJfcmFpbHMi...","code":"123456"}'
# a recovery code works too:
#   -d '{"challenge":"...","recovery_code":"wsv3y6qyt5ua"}'
```

The challenge is a signed, five-minute, single-purpose token — it is not a session and
cannot be presented to `/graphql`. Google OAuth goes through the same gate: an account
with a second factor gets a challenge from the callback too, so OAuth is not a way around
it. TOTP codes are single-use within their own window, and a recovery code is consumed
atomically under a row lock.

---

## Billing integration contract

Fixed by the sibling service. Authentication is
`Authorization: Token <INTERNAL_SERVICE_TOKEN>`; timeouts are 2s open / 5s read.

| Call | Accepted | Behaviour here |
|---|---|---|
| `POST /api/v1/invoices/` | `201` created, `200` already existed | `Idempotency-Key: sha256(external_ref)`. On timeout the booking is **kept** and `BillingInvoiceWorker` retries with the same key. On a 4xx the booking is compensated. |
| `POST /api/v1/invoices/void/` | `200`, `404` | `404` is success: nothing to void is the same end state. On failure `BillingVoidWorker` retries; a cancellation is never blocked by billing. |
| `POST /api/v1/notifications/reminder/` | `202` | `phone` is `""` when the patient has none, `starts_at` is ISO8601 UTC. |

`external_ref` is `appointment:<id>`, generated by PostgreSQL as a stored generated
column, so it can never drift from the row or be set by hand — which is what makes the
derived idempotency key trustworthy.

### Environment variables

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | PostgreSQL (production / Docker). Locally, `POSTGRES_HOST`/`PORT`/`USER`/`PASSWORD`. |
| `REDIS_URL` | Sidekiq queues, sidekiq-cron, Rails cache |
| `SECRET_KEY_BASE` | Rails message signing (incl. the 2FA challenge) |
| `DEVISE_JWT_SECRET_KEY` | JWT signing |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` | PHI + TOTP secret encryption |
| `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` | ditto |
| `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` | ditto |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | Google OAuth |
| `DJANGO_BILLING_URL` | `http://billing:8000` under Compose |
| `INTERNAL_SERVICE_TOKEN` | shared with the billing service |

Outside development and test the process **refuses to boot** without the encryption and
JWT keys. A missing secret is a loud crash at deploy time rather than a column that is
quietly not protected.

---

## Background work

| Worker | Queue | When |
|---|---|---|
| `AppointmentReminderWorker` | `notifications` | `perform_at(starts_at - 24h)`, or immediately if the booking is already inside that window. Re-checks the appointment on execution and stays quiet if it was cancelled. |
| `BillingInvoiceWorker` | `default` | Retry after an invoice timeout; same idempotency key. |
| `BillingVoidWorker` | `default` | Retry after a void failure. |
| `DailyNoShowSweeper` | `maintenance` | `15 3 * * *` UTC |
| `BillingReconciliationWorker` | `maintenance` | `45 3 * * *` UTC |
| `ExpiredTokenSweeper` | `maintenance` | `0 4 * * *` UTC |

Two of these are named after behaviour the given contract cannot express exactly, and the
code says so rather than quietly inventing it:

- **`DailyNoShowSweeper`** — the domain has four statuses (`scheduled`, `confirmed`,
  `completed`, `cancelled`) enforced by a database check constraint. There is no
  `no_show`, and adding a fifth status here would change a contract every other component
  reads. So a swept appointment becomes `cancelled` with `cancellation_reason: "no_show"`.
  The invoice is deliberately **not** voided — a patient who did not appear still consumed
  the doctor's hour.
- **`BillingReconciliationWorker`** — the billing contract has no read endpoint, so this
  cannot compare two ledgers. What it can do without inventing an endpoint is re-submit
  each invoice creation; the idempotency key makes a repeat a no-op, which turns "an
  invoice was lost to a timeout and its retries ran out" from permanent into self-healing
  within a day.

---

## Security notes

- **PHI encrypted at rest.** `medical_records.notes` and `.diagnosis` use Active Record
  Encryption. `spec/models/encryption_spec.rb` asserts against the **raw column**, not the
  accessor — calling `record.notes` would pass with encryption switched off.
- **PHI access is audited.** Every successful read of a clinical record writes an
  `audit_logs` row: actor, resource, action, timestamp, request IP. One row per record per
  request, so asking for both `notes` and `diagnosis` does not double-log one act of
  reading one chart. If the audit row cannot be written, **the PHI is not returned** —
  unlogged access must not happen.
- **Audit rows are append-only.** No `updated_at`, `readonly?` once persisted, and
  `dependent: :restrict_with_exception` so deleting a user cannot erase the record of what
  they read.
- **Participant authorization starts from a scoped relation.** A patient sees only their
  own appointments, a doctor only theirs, an admin all. Someone else's id returns `null`
  rather than a refusal, so the API cannot be used to probe for records that exist.
- **TOTP secrets encrypted, recovery codes hashed.** Only SHA256 digests are stored;
  comparison is constant-time; a code is consumed atomically under a row lock.
- **Logout really revokes.** The JWT's `jti` goes on a denylist, checked on every request.
- **Nothing leaves this service carrying PHI.** The invoice description is generic by
  construction, and PHI plus every token is in `filter_parameters`.

This is a portfolio implementation of HIPAA-shaped engineering, not a compliance
certification: a real deployment also needs a BAA with every processor, key management in
an HSM or KMS, backup encryption, breach procedures and access reviews.

---

## Design decisions

### Why GraphQL

Scheduling screens want wildly different slices of the same graph — a patient's list needs
the doctor's name, a doctor's day needs the patient's phone, an admin audit view needs
both plus the record. In REST that becomes either a dozen endpoints or one endpoint with
`?include=` and over-fetching. One typed schema lets each client ask for what it renders,
and the type system documents the domain for free. The price is that a client can compose
a query the server author never wrote, which is why the schema has a depth limit, a
complexity limit and a page-size cap — and why they are **calibrated, not guessed**: a
realistic client query measures 361, so the limit is 1000, not the 200 that would have
rejected ordinary use while every spec stayed green.

### Why a pessimistic lock

Two patients tapping the same 10:00 slot is not a hypothetical. `Appointments::Book` takes
`SELECT ... FOR UPDATE` on the availability row before it checks whether the slot is free,
so the second request blocks until the first commits and then sees the appointment that
was created. An optimistic check — `exists?` then `create` — reads a snapshot taken before
the competing transaction committed, which is exactly the race. There is also a **partial
unique index** on `availability_id WHERE status IN ('scheduled','confirmed')`: belt and
braces, and the thing that keeps the invariant true if a future code path forgets the lock.
The two are tested separately, because the concurrency spec passes with the lock removed —
the index catches the loser and produces the same error — so proving the lock exists takes
its own assertion on the emitted SQL.

Side effects run **after** the transaction commits. A Sidekiq job enqueued inside a
transaction can be picked up before the commit lands, or survive a rollback entirely, and
an HTTP call made inside one cannot be undone at all. Redis and Django have never heard of
our transaction.

### Why interactors

Booking is not one write. It is: validate the slot, take a lock, create a row, commit,
schedule a reminder for 24 hours out, create an invoice in another service, and decide
what a timeout there means. That does not belong in a resolver (which should translate
input and context, nothing else) or in a model callback (which fires from every path
including seeds and imports, and cannot express "after commit, call this other service").
An interactor is the smallest object that holds a use case with a clear input, a clear
result, and a `rollback` for compensating what has already committed. Resolvers here are
three lines each.

### Why separate databases

The billing service owns invoices, payments and PSP tokens; this one owns PHI. Separate
databases mean the billing service's schema, backups, key material and blast radius are
not the clinical service's problem, and a compromise of the payment side does not hand
over medical records. They integrate over an explicit contract with idempotency keys,
which also means either can be redeployed or restored independently. The cost is real —
no join across the boundary, and every call is a network call that can time out — which is
why the timeout path is designed rather than incidental.

### Why Sidekiq instead of Solid Queue

Rails 8 ships Solid Queue as the default, and it is genuinely good: one fewer service to
run when your queue is modest and PostgreSQL is already there. This service goes the other
way on purpose.

`AppointmentReminderWorker` is scheduled with `perform_at` for a point 24 hours out, and
three jobs run on cron. The queues are weighted (`notifications` 3, `default` 2,
`maintenance` 1) because a late reminder is something a patient notices and a late invoice
retry is not. Sidekiq's scheduled set, sidekiq-cron and per-queue weights are mature and
operationally boring; Solid Queue's equivalents are younger, and its recurring tasks
arrived later than the rest. Redis is in the stack regardless — it backs `Rails.cache` —
so Sidekiq adds no new dependency, only uses one that is already there. A worker pulling
jobs out of PostgreSQL would also mean the database serving patient requests is the same
one being polled by workers; keeping them apart is one less way for a busy queue to slow
down a booking.

Solid Cache and Solid Cable are absent for the same reason in reverse: Redis already
handles the cache, and this service has no WebSocket. Kamal and Thruster are absent because
deployment here is Docker plus GitHub Actions. So are Propshaft, importmap and Hotwire —
this is `--api` mode and there is nothing to render.

### Why Devise instead of the Rails 8 authentication generator

The Rails 8 generator produces a session-and-cookie flow with a `Session` record — good,
small, and the right answer for a server-rendered app. This is an API with three
requirements it does not cover:

1. **JWT issuance and revocation.** Clients are mobile apps and SPAs holding a bearer
   token. Logout has to actually invalidate that token, which needs a denylist keyed on
   `jti` — `devise-jwt` provides the strategy and the revocation interface.
2. **Google OAuth.** `omniauth-google-oauth2` plugs into Devise's `:omniauthable` with an
   identity-linking policy; rebuilding the OAuth dance by hand is the kind of security
   code that should be boring and widely reviewed.
3. **A second factor that gates token issuance.** A correct password for a 2FA account
   must produce a challenge and **no usable token**. That is a branch between "credentials
   accepted" and "session established" — a distinction the generator's flow does not make.

What was not taken wholesale: tokens here are minted explicitly in the controllers rather
than by devise-jwt's path-matching middleware, because a URL regexp cannot express "unless
this account has a second factor". `:recoverable`, `:rememberable`, `:confirmable` and
`:registerable` are all off — this service sends no email of its own and accounts are
provisioned rather than self-signed-up.

### Rails 7 → 8.1

The target role mentions Rails 7; this is 8.1 on purpose — it is the supported version
today, and everything that matters here (Active Record, GraphQL, Devise, Sidekiq,
interactors) behaves identically on both. Two things actually came up in upgrade territory,
both worth knowing:

1. **`json` 3.x breaks ActiveSupport 8.1's JSON decoding.** `ActiveSupport::JSON.decode`
   calls `JSON.parse(source, options)` with a positional Hash; `json` 3.0 made those
   options keyword-only, so on Ruby 3.4 every JSON request body raises
   `ArgumentError: wrong number of arguments (given 2, expected 1)` — which, in an API
   whose entire surface is JSON, means nothing works. It surfaced first as a `jsonb`
   column that would not round-trip and a `db/schema.rb` containing
   `# Could not dump table "users"`, which would have broken the schema load in CI as well.
   The Gemfile pins `json ~> 2.9` with a comment saying when the pin can go.
2. **`omniauth-rails_csrf_protection` 1.0.2 uses `ActiveSupport::Configurable`**, which is
   deprecated in 8.1 and removed in 8.2. It works today and warns on boot; it will need a
   newer release before 8.2.

No other gem needed a version adjustment: `devise 4.9.4`, `devise-jwt 0.13.0`,
`graphql 2.6.10`, `sidekiq 7.3.9` and `interactor-rails 2.3.0` resolved cleanly against
Rails 8.1.3.1 on Ruby 3.4.4.

---

## CI/CD

`.github/workflows/ci.yml` — PostgreSQL 16 and Redis 7 service containers with
healthchecks, `ruby/setup-ruby` with `bundler-cache`, schema load, RSpec, RuboCop, and a
second job that builds the production image with Buildx and the GitHub Actions cache
(`type=gha`).

`.github/workflows/mirror.yml` — mirrors `main` to GitLab with `git push --mirror`.
Configure before use:

- repository **secret** `GITLAB_TOKEN` — a GitLab PAT with `write_repository`
- repository **variable** `GITLAB_REPOSITORY` — e.g.
  `gitlab.com/your-namespace/telehealth-clinical-api.git` (host and path only)

The token is only ever interpolated into the remote URL and is never echoed.
