"""Public deterministic financial calculator route."""

from fastapi import APIRouter

from app.schemas.calculator import CalculatorRequest, CalculatorResponse
from app.services import calculator_service

router = APIRouter(prefix="/api/calculator", tags=["Calculator"])


@router.post(
    "",
    response_model=CalculatorResponse,
    summary="Calculate loan repayment",
    description=(
        "Uses the standard reducing-balance EMI formula with Decimal precision "
        "and a zero-interest branch. Results are not stored."
    ),
)
def calculate_loan(payload: CalculatorRequest) -> CalculatorResponse:
    """Return rounded EMI, repayment, and interest for valid inputs."""
    return calculator_service.calculate_loan(
        principal=payload.principal,
        annual_interest_rate=payload.annual_interest_rate,
        tenure_months=payload.tenure_months,
    )

