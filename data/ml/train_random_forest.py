"""Train a demo RandomForestClassifier on the synthetic beneficiary dataset.

beneficiaries.csv has no real approval outcome to learn from, so this script
manufactures a heuristic "approved" label from a simple affordability rule
plus injected noise (see LOAN_TO_INCOME_THRESHOLD / NOISE_RATE below). This
is a SYNTHETIC/DEMO target for prototyping the future ML matching engine
described in docs/ml-integration.md, not a real underwriting policy.

The trained pipeline (category encoding + classifier) is exported as one
artifact so a future serving adapter does not need to duplicate the
feature-encoding logic.

Usage (from data/, with data/requirements.txt installed):
    python ml/train_random_forest.py
"""

from __future__ import annotations

import random
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, roc_auc_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder

SCRIPT_DIR = Path(__file__).resolve().parent
DATA_PATH = SCRIPT_DIR.parent / "synthetic" / "beneficiaries.csv"
ARTIFACT_PATH = (
    SCRIPT_DIR.parent.parent
    / "backend"
    / "app"
    / "services"
    / "ml"
    / "artifacts"
    / "random_forest_v1.joblib"
)

RANDOM_SEED = 42
TEST_SIZE = 0.2

# Heuristic-label assumptions (SYNTHETIC/DEMO only, not a real credit policy):
# a loan is "affordable" when it does not exceed this multiple of income.
LOAN_TO_INCOME_THRESHOLD = 3.0
# Fraction of heuristic labels flipped at random so the classifier is not
# trained on a perfectly separable rule derived from its own input features.
NOISE_RATE = 0.08

NUMERIC_FEATURES = ["annual_income", "desired_loan_amount", "previous_default"]
CATEGORICAL_FEATURES = ["category"]
FEATURE_COLUMNS = NUMERIC_FEATURES + CATEGORICAL_FEATURES


def _load_features() -> pd.DataFrame:
    """Load beneficiary features, normalizing previous_default to bool."""
    df = pd.read_csv(DATA_PATH)
    if df["previous_default"].dtype == object:
        df["previous_default"] = df["previous_default"].map(
            {"True": True, "False": False}
        )
    df["previous_default"] = df["previous_default"].astype(bool)
    return df


def _heuristic_labels(df: pd.DataFrame, rng: random.Random) -> pd.Series:
    """Derive a noisy, rule-based 'approved' label for demo training only."""
    affordable = (
        df["desired_loan_amount"] <= df["annual_income"] * LOAN_TO_INCOME_THRESHOLD
    )
    approved = (affordable & ~df["previous_default"]).astype(int).to_numpy()
    flip_mask = np.array([rng.random() < NOISE_RATE for _ in range(len(approved))])
    approved[flip_mask] = 1 - approved[flip_mask]
    return pd.Series(approved, index=df.index, name="approved")


def build_pipeline() -> Pipeline:
    """Build the category-encoding + RandomForestClassifier pipeline."""
    preprocessor = ColumnTransformer(
        transformers=[
            ("category", OneHotEncoder(handle_unknown="ignore"), CATEGORICAL_FEATURES),
        ],
        remainder="passthrough",
    )
    classifier = RandomForestClassifier(
        n_estimators=200,
        max_depth=8,
        random_state=RANDOM_SEED,
        n_jobs=-1,
    )
    return Pipeline(steps=[("preprocess", preprocessor), ("classifier", classifier)])


def main() -> None:
    """Train on the heuristic label, print metrics, and export the pipeline."""
    rng = random.Random(RANDOM_SEED)
    df = _load_features()
    features = df[FEATURE_COLUMNS]
    labels = _heuristic_labels(df, rng)

    print(f"Loaded {len(df)} records from {DATA_PATH}")
    print(f"Label distribution: {labels.value_counts().to_dict()}")

    X_train, X_test, y_train, y_test = train_test_split(
        features,
        labels,
        test_size=TEST_SIZE,
        random_state=RANDOM_SEED,
        stratify=labels,
    )

    pipeline = build_pipeline()
    pipeline.fit(X_train, y_train)

    predictions = pipeline.predict(X_test)
    probabilities = pipeline.predict_proba(X_test)[:, 1]
    accuracy = accuracy_score(y_test, predictions)
    roc_auc = roc_auc_score(y_test, probabilities)

    print(f"Accuracy: {accuracy:.4f}")
    print(f"ROC-AUC: {roc_auc:.4f}")

    ARTIFACT_PATH.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(pipeline, ARTIFACT_PATH)
    print(f"Saved trained pipeline to {ARTIFACT_PATH}")


if __name__ == "__main__":
    main()
