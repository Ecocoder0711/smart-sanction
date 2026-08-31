# ML integration contract

Phase 7 works without an ML implementation. The deterministic eligibility,
financial, and partner-proximity results remain usable when ML is unavailable.

## Plug-in point

Implement the `MatchingEngine` protocol in
`backend/app/services/ml/contracts.py`, then inject that adapter into
`matching_service.match_schemes(..., ml_engine=engine)`. Enable calls with
`ML_AVAILABLE=true`. No engine is installed in Phase 7.

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
`applications.ml_approval_probability`. Phase 7 never writes either field:
both remain SQL `NULL` until a real ML integration and an explicit persistence
policy are added.

## HTTP example without ML

`POST /api/match` accepts:

```json
{"requested_amount": "200000.00", "tenure_months": 60}
```

The authenticated user comes only from the Bearer JWT. A response candidate
contains separate `eligibility`, `financial`, `partners`, and nullable
`ml` sections. With Phase 7 configuration, the response reports
`"ml_status": "unavailable"` and `"ml": null`.
