"""End-to-end tests for the ML-*enabled* matching contract.

These pin ML_AVAILABLE on via the `ml_enabled` fixture and inject the engine
through `use_ml_engine`, so they never depend on the developer's shell or on
the gitignored random_forest_v1.joblib artifact being present. The stub
pipeline reproduces scikit-learn's real zero-row behaviour, so the empty-match
regression below genuinely fails without the guard in RandomForestAdapter.
"""

import pickle
from decimal import Decimal
from pathlib import Path

import numpy as np
import pytest
from fastapi.testclient import TestClient

from app.services.ml.random_forest_engine import RandomForestAdapter
from tests.helpers import register_and_login

pytestmark = pytest.mark.usefixtures("ml_enabled")

# Above every seeded scheme's max_loan_limit, so eligibility matches nothing.
NO_ELIGIBLE_SCHEME_AMOUNT = "4000000.00"

# A path that cannot exist, so no artifact is ever read from disk.
MISSING_ARTIFACT = Path("/nonexistent/random_forest_v1.joblib")


class _StubPipeline:
    """Stand-in for the trained sklearn Pipeline.

    Records the row count of every call so a test can prove predict_proba was
    never handed a zero-row frame, and raises the same error real scikit-learn
    raises for that input so the regression cannot pass vacuously.
    """

    def __init__(self, probability: float = 0.75) -> None:
        self.probability = probability
        self.call_row_counts: list[int] = []

    def predict_proba(self, features) -> np.ndarray:
        self.call_row_counts.append(len(features))
        if len(features) == 0:
            raise ValueError(
                "Found array with 0 sample(s) (shape=(0,)) while a minimum "
                "of 1 is required."
            )
        return np.array([[1 - self.probability, self.probability]] * len(features))


def _working_engine(probability: float = 0.75) -> RandomForestAdapter:
    """A real adapter whose trained pipeline is stubbed out.

    Built against a nonexistent path so no artifact is read; installing the
    stub afterwards still exercises the adapter's own feature-frame, cosine,
    clamping and ranking logic for real.
    """
    adapter = RandomForestAdapter(artifact_path=MISSING_ARTIFACT)
    adapter._pipeline = _StubPipeline(probability)
    return adapter


def _match(client: TestClient, headers: dict[str, str], *, amount: str = "100000.00"):
    return client.post(
        "/api/match",
        headers=headers,
        json={"requested_amount": amount, "tenure_months": 36},
    )


def test_zero_eligible_schemes_returns_empty_200_instead_of_500(
    client: TestClient,
    use_ml_engine,
) -> None:
    """Regression: an empty candidate list used to reach predict_proba.

    sklearn rejects a zero-row frame, the ValueError escaped _prediction_map
    (which only catches MLUnavailableError), and a legitimate "nothing
    matched" answer surfaced to the applicant as HTTP 500.
    """
    _, headers = register_and_login(client, "9880000401")
    engine = use_ml_engine(_working_engine())

    response = _match(client, headers, amount=NO_ELIGIBLE_SCHEME_AMOUNT)

    assert response.status_code == 200
    body = response.json()
    assert body["candidate_count"] == 0
    assert body["candidates"] == []
    assert body["message"] == (
        "No matching scheme was found for the requested amount and profile."
    )
    # The model must not have been consulted at all for an empty candidate set.
    assert engine._pipeline.call_row_counts == []


def test_enabled_engine_populates_both_scores_and_rank(
    client: TestClient,
    use_ml_engine,
) -> None:
    _, headers = register_and_login(client, "9880000402")
    use_ml_engine(_working_engine(probability=0.75))

    response = _match(client, headers)

    assert response.status_code == 200
    body = response.json()
    assert body["ml_status"] == "available"
    assert body["candidate_count"] > 1

    for candidate in body["candidates"]:
        ml = candidate["ml"]
        assert ml is not None
        assert Decimal("0") <= Decimal(ml["match_score"]) <= Decimal("1")
        assert Decimal(ml["approval_probability"]) == Decimal("0.75")
        assert ml["rank"] >= 1

    # Deterministic sections must survive untouched alongside the ML ones.
    assert all(item["eligibility"]["eligible"] for item in body["candidates"])
    assert all(item["financial"]["emi"] for item in body["candidates"])
    assert all(item["financial"]["tenure_months"] == 36 for item in body["candidates"])


def test_enabled_engine_orders_candidates_by_match_score(
    client: TestClient,
    use_ml_engine,
) -> None:
    _, headers = register_and_login(client, "9880000403")
    use_ml_engine(_working_engine())

    body = _match(client, headers).json()

    scores = [Decimal(item["ml"]["match_score"]) for item in body["candidates"]]
    assert scores == sorted(scores, reverse=True)
    # rank is assigned from the same ordering, so it reads 1..N down the list.
    ranks = [item["ml"]["rank"] for item in body["candidates"]]
    assert ranks == list(range(1, len(ranks) + 1))


def test_corrupt_artifact_degrades_to_unavailable_without_500(
    client: TestClient,
    use_ml_engine,
    tmp_path,
) -> None:
    """A damaged model file must not take the endpoint down with it."""
    corrupt = tmp_path / "random_forest_v1.joblib"
    corrupt.write_bytes(bytes([182]) * 4096)  # non-pickle bytes -> KeyError
    _, headers = register_and_login(client, "9880000404")
    use_ml_engine(RandomForestAdapter(artifact_path=corrupt))

    response = _match(client, headers)

    assert response.status_code == 200
    body = response.json()
    assert body["ml_status"] == "unavailable"
    assert body["candidate_count"] > 0
    assert all(item["ml"] is None for item in body["candidates"])
    # Everything deterministic still answers normally.
    assert all(item["eligibility"]["eligible"] for item in body["candidates"])
    assert all(item["financial"]["emi"] for item in body["candidates"])


def test_missing_artifact_degrades_to_unavailable_without_500(
    client: TestClient,
    use_ml_engine,
) -> None:
    """The fresh-clone case: *.joblib is gitignored, so no model is present."""
    _, headers = register_and_login(client, "9880000405")
    use_ml_engine(RandomForestAdapter(artifact_path=MISSING_ARTIFACT))

    response = _match(client, headers)

    assert response.status_code == 200
    body = response.json()
    assert body["ml_status"] == "unavailable"
    assert body["candidate_count"] > 0
    assert all(item["ml"] is None for item in body["candidates"])


def test_wrong_object_artifact_degrades_instead_of_failing_at_request_time(
    client: TestClient,
    use_ml_engine,
    tmp_path,
) -> None:
    """A stale/incorrect export unpickles fine but cannot predict."""
    wrong = tmp_path / "random_forest_v1.joblib"
    wrong.write_bytes(pickle.dumps({"not": "a pipeline"}))
    _, headers = register_and_login(client, "9880000406")
    use_ml_engine(RandomForestAdapter(artifact_path=wrong))

    response = _match(client, headers)

    assert response.status_code == 200
    assert response.json()["ml_status"] == "unavailable"


def test_zero_eligible_schemes_with_missing_artifact_also_returns_200(
    client: TestClient,
    use_ml_engine,
) -> None:
    """Both degraded paths at once: ML on, no model, and nothing eligible."""
    _, headers = register_and_login(client, "9880000407")
    use_ml_engine(RandomForestAdapter(artifact_path=MISSING_ARTIFACT))

    response = _match(client, headers, amount=NO_ELIGIBLE_SCHEME_AMOUNT)

    assert response.status_code == 200
    body = response.json()
    assert body["candidate_count"] == 0
    assert body["ml_status"] == "unavailable"
