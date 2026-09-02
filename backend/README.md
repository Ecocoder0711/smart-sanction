# SMART-SANCTION Backend

SMART-SANCTION is a backend service for discovering suitable concessional loan
schemes, calculating repayment details, finding nearby channel partners, and
managing user-owned loan applications.

The core of the implementation is deterministic and explainable: stored
applicant data, scheme eligibility rules, financial calculations, and
geographic partner routing all run without a model, and no score is ever
fabricated. An optional ML layer (`RandomForestAdapter`) adds an approval
probability and a cosine match score; it is disabled by default and degrades to
`ml_status: "unavailable"` whenever it cannot run.

## Current status

Phases 1–7 of the backend are complete:

- FastAPI application with Swagger, ReDoc, and OpenAPI
- PostgreSQL persistence through SQLAlchemy 2
- Alembic migrations
- JWT Bearer authentication
- Argon2 password hashing
- Authenticated profile and application ownership
- Scheme and partner discovery APIs
- Explainable eligibility checks
- EMI, interest, and repayment calculations
- Haversine-based nearby-partner recommendations
- Two-stage partner routing (nearest-K then Partner Health Score), used by both
  `GET /api/partners/routed` and `POST /api/match`
- Deterministic matching orchestration through `POST /api/match`
- Controlled internal application status transitions
- Idempotent synthetic/demo data seeding
- ML adapter protocol with ML disabled by default
- 143 automated tests

## Technology stack

| Area             | Technology                    |
| ---------------- | ----------------------------- |
| API              | FastAPI                       |
| Validation       | Pydantic 2                    |
| Database         | PostgreSQL 16                 |
| ORM              | SQLAlchemy 2                  |
| Migrations       | Alembic                       |
| Authentication   | JWT with PyJWT                |
| Password hashing | Argon2 through pwdlib         |
| Server           | Uvicorn                       |
| Testing          | pytest and FastAPI TestClient |

## Repository structure

```text
smart-sanction/
├── backend/
│   ├── app/
│   │   ├── api/                 # Dependencies and HTTP routes
│   │   ├── core/                # Settings, security, and enums
│   │   ├── database/            # SQLAlchemy base/session and migrations
│   │   ├── models/              # PostgreSQL ORM models
│   │   ├── schemas/             # Request and response contracts
│   │   ├── services/            # Business logic and orchestration
│   │   │   └── ml/              # Future ML interface only
│   │   ├── utils/               # Geographic distance utility
│   │   └── main.py              # FastAPI application entry point
│   ├── seed/                    # Deterministic synthetic seed scripts
│   ├── tests/                   # Automated backend tests
│   ├── .env.example
│   ├── alembic.ini
│   ├── Dockerfile
│   └── requirements.txt
├── data/
│   └── synthetic/README.md
└── docs/
    └── ml-integration.md
```

## Prerequisites

- Python 3.11 or newer
- PostgreSQL 16, locally installed or running in Docker
- Git
- Docker Desktop, if using the container instructions below

## Local setup

All backend commands should be run from the `backend` directory.

### 1. Clone and enter the backend

```powershell
git clone https://github.com/Eccoder0711/smart-sanction.git
cd smart-sanction\backend
```

### 2. Create a virtual environment

```powershell
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
```

### 3. Start PostgreSQL

The development database is defined in `docker-compose.yml` at the repository
root, so every machine gets identical settings. From the repository root:

```bash
docker compose up -d
```

On later runs the same command starts the existing container. Check its state
(`STATUS` reports `healthy` only once Postgres is accepting connections):

```bash
docker compose ps
```

Other useful commands, from the repository root:

```bash
docker compose logs -f db   # follow database logs
docker compose down         # stop, keeping all data
docker compose down -v      # stop and DELETE all data
```

PostgreSQL is required. The project's Alembic migrations use PostgreSQL-only
DDL, so pointing `DATABASE_URL` at SQLite will fail on `alembic upgrade head`.
The automated test suite is unaffected: it builds its own isolated in-memory
SQLite schema and never runs the migrations.

### 4. Configure the environment

```powershell
Copy-Item .env.example .env
python -c "import secrets; print(secrets.token_hex(32))"
```

Copy the generated value into `JWT_SECRET_KEY` in `.env`. The Compose service
above matches this example configuration:

```dotenv
DATABASE_URL=postgresql+psycopg://postgres:change_me@localhost:5432/smart_sanction
JWT_SECRET_KEY=replace_with_a_random_secret_of_at_least_32_characters
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60
RECOMMENDED_PARTNER_RADIUS_KM=50
ML_AVAILABLE=false
SMART_SANCTION_ENVIRONMENT=development
SMART_SANCTION_DEBUG=false
```

| Variable                        | Purpose                                          | Default/requirement              |
| ------------------------------- | ------------------------------------------------ | -------------------------------- |
| `DATABASE_URL`                  | PostgreSQL connection using the psycopg 3 driver | Required for database operations |
| `JWT_SECRET_KEY`                | Signs and verifies access tokens                 | Required; at least 32 characters |
| `JWT_ALGORITHM`                 | JWT signing algorithm                            | `HS256`                          |
| `ACCESS_TOKEN_EXPIRE_MINUTES`   | Access-token lifetime                            | `60`                             |
| `RECOMMENDED_PARTNER_RADIUS_KM` | Default recommendation radius                    | `50`                             |
| `ML_AVAILABLE`                  | Gates all ML scoring (see below)                 | `false`                          |
| `SMART_SANCTION_ENVIRONMENT`    | Runtime environment label                        | `development`                    |
| `SMART_SANCTION_DEBUG`          | Application debug flag                           | `false`                          |

Never commit `.env`. The repository tracks only `.env.example`.

#### Variable names: only the last two take the prefix

`Settings` declares `env_prefix="SMART_SANCTION_"`, but pydantic-settings does
not apply a prefix to a field that has an explicit `validation_alias`. Every
variable above the blank line is read by its bare name, so
`SMART_SANCTION_ML_AVAILABLE=true` is **silently ignored** — the working
variable is `ML_AVAILABLE`. Only `SMART_SANCTION_ENVIRONMENT` and
`SMART_SANCTION_DEBUG` are prefixed.

To try ML for a single run without editing `.env`:

```bash
ML_AVAILABLE=true uvicorn app.main:app --reload
```

### 5. Apply migrations

```powershell
alembic upgrade head
alembic current
```

The current migration head is:

```text
20260904_0004
```

### 6. Seed synthetic data

```powershell
python -m seed.seed_database
```

The seed is deterministic and idempotent. Re-running it inserts only missing
records and does not truncate or recreate tables. It provides:

- 6 fictional scheme categories
- 12 fictional schemes
- 18 synthetic applicant profiles
- 18 fictional channel-partner branches
- 20 synthetic applications

These records are for development and demonstration only. They are not official
government schemes, real financial institutions, or real people. Seeded
applications keep ML fields `NULL`.

## Run the API

Development server with automatic reload:

```powershell
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Or run through the virtual environment without activating it:

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Once running:

| Resource     | URL                                |
| ------------ | ---------------------------------- |
| API base     | http://127.0.0.1:8000              |
| Health       | http://127.0.0.1:8000/health       |
| Swagger UI   | http://127.0.0.1:8000/docs         |
| ReDoc        | http://127.0.0.1:8000/redoc        |
| OpenAPI JSON | http://127.0.0.1:8000/openapi.json |

The health response distinguishes a healthy database from an unavailable or
unconfigured connection.

## Authentication

Register a user and log in through Swagger or the authentication endpoints.
Login returns a JWT access token:

```http
Authorization: Bearer <access_token>
```

Swagger's **Authorize** button can apply the token to authenticated requests.
The backend always derives the current user from the JWT. Client-provided
`user_id` values are not accepted for owned resources.

## Applicant category and gender

Applicant category and gender are independent eligibility dimensions.

- `category` accepts exactly `SC`, `ST`, `OBC`, or `GENERAL`.
- `gender` accepts exactly `MALE`, `FEMALE`, or `OTHER`.
- `Women`, `Female`, and `Minority` are not applicant category values.
- If an older client sends `General`, the API safely normalizes it to
  `GENERAL`.
- If a client omits gender during registration, it is stored as `NULL`, not
  defaulted. `OTHER` means the applicant explicitly selected "Other"; a
  missing gender is `NULL`. The two are never conflated, because `OTHER` is a
  real value that scheme gender targeting matches against.

Every scheme exposes two separate targeting fields:

- `category.category_name`: `ANY`, `SC`, `ST`, `OBC`, or `GENERAL`
- `gender_eligibility`: `ANY`, `MALE`, `FEMALE`, or `OTHER`

`ANY` means that dimension is unrestricted. A scheme targeting `SC` and
`FEMALE` requires both conditions; a scheme targeting `ANY` and `FEMALE`
accepts female applicants from all four categories. Income, amount, and active
scheme rules are evaluated independently and remain unchanged.

## Multi-step registration

A profile can be built up across several screens instead of all at once, so
`annual_income`, `category`, and `gender` are nullable and may be `NULL`
immediately after registration.

| Step | Request | Fields |
| ---- | ------- | ------ |
| 1 | `POST /api/auth/register` | `full_name`, `phone`, `password` |
| 2 | `PUT /api/users/me` | `annual_income`, `category`, `gender`, `state`, `district` |
| 3 | `PUT /api/users/me` | `latitude`, `longitude` |

- Login works immediately after step 1; authentication never depends on
  profile completeness.
- Every user response includes `profile_complete`, a derived boolean that is
  `true` only when `annual_income`, `category`, and `gender` are all present.
  It is computed per response and never stored, so it cannot fall out of sync.
- Supplying these fields at registration is still fully supported, and a
  supplied value is validated exactly as strictly as before. Optional means
  omissible, not unvalidated.
- `POST /api/eligibility/check` and `POST /api/match` require a complete
  profile. An incomplete profile returns `400` naming the missing fields:

  ```json
  {"detail": {"message": "Profile is incomplete",
              "missing_fields": ["annual_income", "category", "gender"]}}
  ```

  No placeholder value is ever substituted, so an unanswered field cannot
  reach the eligibility rules or the ML feature vectors.
- `GET /api/partners/routed` is unaffected: it depends only on stored
  coordinates and still returns `400 "User location is not configured"` when
  they are missing. Its search radius also stays unbounded — the radius bound
  described under [Partner routing inside a match](#partner-routing-inside-a-match)
  applies only to `/api/match`, so `/api/partners/routed` still answers "the K
  nearest, wherever they are".

## API endpoints

| Method | Endpoint                             | Authentication | Purpose                                           |
| ------ | ------------------------------------ | -------------- | ------------------------------------------------- |
| `GET`  | `/health`                            | No             | Check API and database health                     |
| `POST` | `/api/auth/register`                 | No             | Register an applicant                             |
| `POST` | `/api/auth/login`                    | No             | Authenticate and receive a JWT                    |
| `GET`  | `/api/auth/me`                       | Bearer         | Read the authenticated profile                    |
| `PUT`  | `/api/auth/password`                 | Bearer         | Change the current password                       |
| `GET`  | `/api/users/me`                      | Bearer         | Read the current user's profile                   |
| `PUT`  | `/api/users/me`                      | Bearer         | Update safe profile fields                        |
| `GET`  | `/api/schemes/categories`            | No             | List scheme categories                            |
| `GET`  | `/api/schemes`                       | No             | List and filter schemes                           |
| `GET`  | `/api/schemes/{scheme_id}`           | No             | Read one scheme                                   |
| `POST` | `/api/schemes/{scheme_id}/calculate` | No             | Calculate repayment using a scheme rate           |
| `POST` | `/api/calculator`                    | No             | Calculate EMI and repayment details               |
| `POST` | `/api/eligibility/check`             | Bearer         | Evaluate explainable scheme eligibility           |
| `GET`  | `/api/partners`                      | No             | List channel partners                             |
| `GET`  | `/api/partners/{partner_id}`         | No             | Read one channel partner                          |
| `GET`  | `/api/partners/nearby`               | No             | Find available partners near supplied coordinates |
| `GET`  | `/api/partners/recommended`          | Bearer         | Recommend partners from the stored user location  |
| `GET`  | `/api/partners/routed`               | Bearer         | K nearest partners ranked by Partner Health Score |
| `POST` | `/api/match`                         | Bearer         | Build deterministic eligible scheme candidates    |
| `POST` | `/api/applications`                  | Bearer         | Create an owned submitted application             |
| `GET`  | `/api/applications`                  | Bearer         | List only the current user's applications         |
| `GET`  | `/api/applications/{application_id}` | Bearer         | Read an owned application                         |

Swagger is the authoritative interactive reference for request fields, query
parameters, validation constraints, response schemas, and error responses.

## Matching behavior

`POST /api/match` accepts only:

```json
{
  "requested_amount": "200000.00",
  "tenure_months": 60
}
```

`tenure_months` defaults to 60. The authenticated profile supplies category,
income, and coordinates. The service then:

1. Loads active schemes.
2. Applies the existing eligibility rules.
3. Excludes ineligible schemes.
4. Calculates repayment details for eligible candidates.
5. Routes available partners (see below).
6. Returns candidates in deterministic scheme-ID order.

No eligible scheme is a valid HTTP 200 business response with an empty candidate
list. Missing coordinates or no nearby partners also return valid candidates
with an empty partner list and a clear explanation.

### Partner routing inside a match

Each candidate carries the same two-stage routed partner list used by
`GET /api/partners/routed`, with one deliberate difference: Stage 1 is bounded
by `RECOMMENDED_PARTNER_RADIUS_KM`.

1. **Stage 1 — proximity.** The nearest eligible partners (active, with
   remaining quota) by Haversine distance, **inside the configured radius**,
   capped at `MATCH_PARTNER_K` (5).
2. **Stage 2 — health ranking.** Those candidates are ordered by the
   deterministic Partner Health Score over NPA, remaining quota, and distance,
   tie-breaking on `(-health_score, distance_km, id)`.

Each partner therefore carries a `health_score` in `[0, 1]` alongside
`distance_km`. Neither stage involves a trained model.

`/api/match` never returns a partner beyond the configured radius. The radius
bound matters because the health score's proximity term saturates past
`PROXIMITY_REFERENCE_KM`: without it, an applicant with no branch anywhere near
them would receive the five nearest on Earth, each with a plausible-looking
score that cannot distinguish 60 km from 8,000 km.

Routing depends only on the applicant's stored coordinates — not on the scheme
or the requested amount — so every candidate in one response carries the same
partner list.

## Application workflow

Applications are created with:

- ownership derived from the JWT;
- status `submitted`;
- validated scheme, partner, and requested amount;
- `ml_match_score = NULL`;
- `ml_approval_probability = NULL`.

The internal workflow service permits only:

```text
submitted → under_review
under_review → approved
under_review → rejected
approved → completed
```

No public endpoint allows ordinary users to mutate application status.
Partner/admin authorization is intentionally outside the current phase.

## ML integration status

`app/services/ml/contracts.py` defines the `MatchingEngine` protocol.
`RandomForestAdapter` implements it, supplying two independent values per
candidate:

- `approval_probability` — a trained `RandomForestClassifier` loaded from
  `app/services/ml/artifacts/random_forest_v1.joblib`. Its features are all
  applicant-level, so within one request it is the **same value for every
  candidate**: it scores the applicant, not the scheme.
- `match_score` — deterministic cosine similarity between the applicant's
  (income, requested amount) and each scheme's (income cap, loan cap). This
  varies per scheme and is what candidate ordering and `rank` are derived from.

The two are deliberately never blended.

`ML_AVAILABLE` defaults to `false`, and in that state:

- no model is called;
- no scores or approval probabilities are fabricated;
- deterministic matching remains fully functional;
- response ML sections are null and report `unavailable`;
- application ML database fields remain `NULL`.

The artifact is gitignored (`*.joblib`), so a fresh clone has no model. That is
handled, not an error: the adapter reports itself unavailable and matching
answers normally. The same graceful degradation covers a missing, truncated,
corrupt, or wrong-object artifact — `ml_status` reads `unavailable` rather than
the request failing. Regenerate the artifact with
`python data/ml/train_random_forest.py`.

See [the ML integration contract](../docs/ml-integration.md) for the expected input,
output, data types, and plug-in point.

## Testing

From `backend`:

```powershell
python -m compileall -q app seed tests
python -m pytest -q
```

Expected result:

```text
143 passed
```

The automated suite uses an isolated in-memory test database and covers
authentication, ownership, users, schemes, partners, applications, eligibility,
calculations, matching, both ML-available and ML-unavailable behavior, artifact
corruption handling, and application workflow transitions.

Tests pin `ML_AVAILABLE` themselves through the `ml_enabled` / `ml_disabled`
fixtures, so the suite gives the same result whether or not the variable is set
in your shell:

```bash
ML_AVAILABLE=true python -m pytest -q   # also 143 passed
```

## Useful maintenance commands

```powershell
# Show the current migration
alembic current

# Apply pending migrations
alembic upgrade head

# Re-run the idempotent synthetic seed
python -m seed.seed_database

# Stop PostgreSQL after stopping the local API with Ctrl+C
# (run from the repository root; data is kept in the named volume)
docker compose down
```

## Safety notes

- Do not commit `.env`, passwords, JWT secrets, database dumps, or PostgreSQL
  container data.
- Do not treat the synthetic dataset as official government or financial data.
- Do not describe deterministic matching rules as ML.
- Matching and calculator results are transient and are not persisted.
- The application table remains the source of persisted workflow state.
