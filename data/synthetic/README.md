# Synthetic development dataset

All records described here are deterministic **SYNTHETIC/DEMO DATA** created
only for local development, database testing, future Swagger testing, and SIH
prototype demonstrations. They are not official government schemes, real bank
branches, or real people's information.

The PostgreSQL seed contains approximately:

- 5 scheme eligibility categories (`ANY`, `SC`, `ST`, `OBC`, `GENERAL`)
- 12 fictional concessional schemes
- 18 synthetic applicants
- 18 fictional channel-partner branches
- 20 synthetic applications

The records cover different categories, income and loan limits, interest rates,
locations, quotas, NPA percentages, active states, and application statuses.
ML match scores and approval probabilities are always left `NULL`.

Applicant `category` values are limited to `SC`, `ST`, `OBC`, and
`GENERAL`. Applicant `gender` is stored separately as `MALE`, `FEMALE`,
or `OTHER`. Scheme category eligibility and gender eligibility are also
separate; `ANY` represents an unrestricted scheme dimension.

From `smart-sanction/backend`, with PostgreSQL running and `.env` configured:

```powershell
python -m seed.seed_database
```

The command is idempotent: it detects the deterministic seed identifiers and
inserts only missing records. It does not delete, truncate, or recreate tables.

## Bulk ML dataset generator

`generate_synthetic_data.py` is a separate, larger CSV generator for
prototyping and training the future ML matching engine described in
[`docs/ml-integration.md`](../../docs/ml-integration.md). Unlike the
PostgreSQL seed above, it does not touch a database — it writes two CSV
files directly into this directory:

- `beneficiaries.csv` — 10,000 fictional records shaped like the `User`
  model (`full_name`, `phone`, `annual_income`, `category`, `latitude`,
  `longitude`), plus two extra ML features the model does not persist:
  `desired_loan_amount` and `previous_default`.
- `channel_partners.csv` — 100 fictional records shaped like the
  `ChannelPartner` model (`bank_name`, `branch_code`, `latitude`,
  `longitude`, `npa_percentage`, `quota_remaining`).

All records are entirely fictional, generated with a fixed random seed so
runs are reproducible; none describe a real person, bank, or scheme.

From `smart-sanction/data`, in a virtual environment with
`data/requirements.txt` installed:

```bash
python synthetic/generate_synthetic_data.py
```

Re-running the script overwrites both CSV files with the same deterministic
output.

