# ML integration contract

ML is optional by design. The deterministic eligibility, financial, and
partner-proximity results remain fully usable when ML is unavailable, and the
API never fabricates a score in its place.

## Plug-in point

Implement the `MatchingEngine` protocol in
`backend/app/services/ml/contracts.py`, then inject that adapter into
`matching_service.match_schemes(..., ml_engine=engine)`.

`RandomForestAdapter` (`backend/app/services/ml/random_forest_engine.py`) is
the installed implementation. Calls are gated by `ML_AVAILABLE=true`.

> **Variable name:** `ML_AVAILABLE`, with no prefix. `Settings` sets
> `env_prefix="SMART_SANCTION_"`, but that prefix is not applied to a field
> carrying an explicit `validation_alias`, so `SMART_SANCTION_ML_AVAILABLE` is
> silently ignored. Enable it for one run with
> `ML_AVAILABLE=true uvicorn app.main:app`.

The adapter exposes:

```python
@property
def available(self) -> bool: ...

def predict(self, payload: MLMatchingInput) -> Sequence[MLCandidatePrediction]: ...
```

If `ML_AVAILABLE=false`, no adapter is installed, `available` is false, or
the adapter raises `MLUnavailableError`, the backend skips prediction,
returns `ml_status: "unavailable"`, and leaves every candidate's `ml`
value null.

### Artifact failure modes

`RandomForestAdapter` reports `available = False` — rather than raising — when
the artifact is missing, empty, truncated, corrupt, unreadable, pickled by an
incompatible scikit-learn version, or is a valid pickle of something that has
no `predict_proba`. Each of those degrades to `ml_status: "unavailable"`; none
of them fails the request. The `*.joblib` artifact is gitignored, so the
missing case is the normal state of a fresh clone.

An engine must also tolerate an **empty candidate tuple**: deterministic
eligibility legitimately matches nothing for some requests, and that must stay
a valid empty result. `RandomForestAdapter.predict` returns `[]` immediately
in that case, because scikit-learn rejects a zero-row feature frame.

## Input

One prediction call receives:

- applicant: `user_id: int`, `annual_income: Decimal`, `category: str`
- candidates: a tuple containing `scheme_id: int`, scheme `category: str`,
  `requested_amount: Decimal`, `max_loan_limit: Decimal`,
  `max_income_limit: Decimal`, `annual_interest_rate: Decimal`, and
  `tenure_months: int`

Only candidates that already passed deterministic eligibility are included.
The engine must not replace the eligibility, calculator, or proximity rules.

Example input:

```json
{
  "applicant": {
    "user_id": 19,
    "annual_income": "325000.00",
    "category": "General"
  },
  "candidates": [
    {
      "scheme_id": 7,
      "category": "General",
      "requested_amount": "200000.00",
      "max_loan_limit": "350000.00",
      "max_income_limit": "500000.00",
      "annual_interest_rate": "8.0000",
      "tenure_months": 60
    }
  ]
}
```

## Output

Return zero or one prediction per candidate:

```json
[
  {
    "scheme_id": 7,
    "match_score": "0.81250",
    "approval_probability": "0.74000",
    "rank": 1
  }
]
```

`scheme_id` identifies the candidate. Scores and probability are nullable
`Decimal` values in the inclusive range 0 to 1; rank is an optional positive
integer. Missing candidate predictions remain null.

When a user later creates an application, `match_score` corresponds to
`applications.ml_match_score` and `approval_probability` corresponds to
`applications.ml_approval_probability`. Neither field is written today: both
remain SQL `NULL` until an explicit persistence policy is added. Matching
results are transient.

`match_score` and `approval_probability` answer different questions and are
never blended. `match_score` is cosine similarity between the applicant's
(income, requested amount) and the scheme's (income cap, loan cap), so it
varies per candidate and determines both ordering and `rank`.
`approval_probability` comes from the Random Forest, whose features are all
applicant-level — within a single request it is therefore identical across
every candidate, and it must not be presented as a per-scheme score.

## HTTP example

`POST /api/match` accepts:

```json
{"requested_amount": "200000.00", "tenure_months": 60}
```

The authenticated user comes only from the Bearer JWT. A response candidate
contains separate `eligibility`, `financial`, `partners`, and nullable
`ml` sections. With the default configuration (`ML_AVAILABLE=false`) the
response reports `"ml_status": "unavailable"` and `"ml": null`; with ML
enabled and a loadable artifact it reports `"ml_status": "available"` and
populates `match_score`, `approval_probability`, and `rank`.

The `partners` section is **not** part of the ML layer and is unaffected by
`ML_AVAILABLE`. Each entry carries a `health_score` alongside `distance_km`,
produced by the deterministic two-stage router (nearest-K inside the configured
radius, then a fixed-weight Partner Health Score) described in the backend
README. No trained model is involved, and the score must not be presented as an
ML output.
