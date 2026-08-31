# SMART-SANCTION Backend

SMART-SANCTION is a backend service for discovering suitable concessional loan
schemes, calculating repayment details, finding nearby channel partners, and
managing user-owned loan applications.

The current implementation is deterministic and explainable. It combines stored
applicant data, scheme eligibility rules, financial calculations, and geographic
partner proximity. An ML integration contract exists for future work, but no ML
model, prediction logic, or fabricated score is included.

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
- Deterministic matching orchestration through `POST /api/match`
- Controlled internal application status transitions
- Idempotent synthetic/demo data seeding
- ML adapter protocol with ML disabled by default
- 50 automated tests

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

To create the development database with Docker:

```powershell
docker run --name smart-sanction-postgres -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=change_me -e POSTGRES_DB=smart_sanction -p 5432:5432 -v smart-sanction-postgres-data:/var/lib/postgresql/data -d postgres:16
```

On later runs, start the existing container:

```powershell
docker start smart-sanction-postgres
```

Check its state:

```powershell
docker ps --filter "name=smart-sanction-postgres"
```

### 4. Configure the environment

```powershell
Copy-Item .env.example .env
python -c "import secrets; print(secrets.token_hex(32))"
```

Copy the generated value into `JWT_SECRET_KEY` in `.env`. The Docker command
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
| `ML_AVAILABLE`                  | Enables a future installed ML adapter            | `false`                          |
| `SMART_SANCTION_ENVIRONMENT`    | Runtime environment label                        | `development`                    |
| `SMART_SANCTION_DEBUG`          | Application debug flag                           | `false`                          |

Never commit `.env`. The repository tracks only `.env.example`.

### 5. Apply migrations

```powershell
alembic upgrade head
alembic current
```

The current migration head is:

```text
20260829_0001
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
5. Finds available partners inside the configured radius.
6. Returns candidates in deterministic scheme-ID order.

No eligible scheme is a valid HTTP 200 business response with an empty candidate
list. Missing coordinates or no nearby partners also return valid candidates
with an empty partner list and a clear explanation.

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

Actual ML is **not implemented**.

`app/services/ml/contracts.py` defines the `MatchingEngine` protocol
for a future adapter. With `ML_AVAILABLE=false`:

- no model is called;
- no scores or approval probabilities are fabricated;
- deterministic matching remains fully functional;
- response ML sections are null and report `unavailable`;
- application ML database fields remain `NULL`.

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
50 passed
```

The automated suite uses an isolated in-memory test database and covers
authentication, ownership, users, schemes, partners, applications, eligibility,
calculations, matching, ML-unavailable behavior, and application workflow
transitions.

## Useful maintenance commands

```powershell
# Show the current migration
alembic current

# Apply pending migrations
alembic upgrade head

# Re-run the idempotent synthetic seed
python -m seed.seed_database

# Stop PostgreSQL after stopping the local API with Ctrl+C
docker stop smart-sanction-postgres
```

## Safety notes

- Do not commit `.env`, passwords, JWT secrets, database dumps, or PostgreSQL
  container data.
- Do not treat the synthetic dataset as official government or financial data.
- Do not describe deterministic matching rules as ML.
- Matching and calculator results are transient and are not persisted.
- The application table remains the source of persisted workflow state.
