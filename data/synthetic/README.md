# Synthetic development dataset

All records described here are deterministic **SYNTHETIC/DEMO DATA** created
only for local development, database testing, future Swagger testing, and SIH
prototype demonstrations. They are not official government schemes, real bank
branches, or real people's information.

The PostgreSQL seed contains approximately:

- 6 scheme categories
- 12 fictional concessional schemes
- 18 synthetic applicants
- 18 fictional channel-partner branches
- 20 synthetic applications

The records cover different categories, income and loan limits, interest rates,
locations, quotas, NPA percentages, active states, and application statuses.
ML match scores and approval probabilities are always left `NULL`.

From `smart-sanction/backend`, with PostgreSQL running and `.env` configured:

```powershell
python -m seed.seed_database
```

The command is idempotent: it detects the deterministic seed identifiers and
inserts only missing records. It does not delete, truncate, or recreate tables.

