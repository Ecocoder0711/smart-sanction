"""High-precision deterministic loan calculations."""

from decimal import Decimal, ROUND_HALF_UP, localcontext

from app.models import Scheme
from app.schemas.calculator import CalculatorResponse, SchemeCalculationResponse
from app.schemas.scheme import SchemeResponse

MONEY_QUANTUM = Decimal("0.01")


def _round_money(value: Decimal) -> Decimal:
    """Round a monetary value to paise using conventional half-up rounding."""
    return value.quantize(MONEY_QUANTUM, rounding=ROUND_HALF_UP)


def calculate_loan(
    *,
    principal: Decimal,
    annual_interest_rate: Decimal,
    tenure_months: int,
) -> CalculatorResponse:
    """Calculate EMI, repayment, and interest using reducing-balance finance."""
    if principal <= 0:
        raise ValueError("Principal must be greater than zero")
    if annual_interest_rate < 0:
        raise ValueError("Annual interest rate cannot be negative")
    if tenure_months <= 0:
        raise ValueError("Tenure must be greater than zero")

    with localcontext() as context:
        context.prec = 40
        if annual_interest_rate == 0:
            raw_emi = principal / Decimal(tenure_months)
            raw_total_repayment = principal
        else:
            monthly_rate = annual_interest_rate / Decimal("1200")
            growth_factor = (Decimal(1) + monthly_rate) ** tenure_months
            raw_emi = (
                principal
                * monthly_rate
                * growth_factor
                / (growth_factor - Decimal(1))
            )
            raw_total_repayment = raw_emi * Decimal(tenure_months)
        raw_total_interest = raw_total_repayment - principal

    return CalculatorResponse(
        principal=_round_money(principal),
        annual_interest_rate=annual_interest_rate,
        tenure_months=tenure_months,
        emi=_round_money(raw_emi),
        total_repayment=_round_money(raw_total_repayment),
        total_interest=_round_money(raw_total_interest),
    )


def calculate_scheme_loan(
    scheme: Scheme,
    *,
    principal: Decimal,
    tenure_months: int,
) -> SchemeCalculationResponse:
    """Calculate a loan using a scheme's stored annual interest rate."""
    calculation = calculate_loan(
        principal=principal,
        annual_interest_rate=scheme.interest_rate,
        tenure_months=tenure_months,
    )
    return SchemeCalculationResponse(
        scheme=SchemeResponse.model_validate(scheme),
        principal=calculation.principal,
        interest_rate=calculation.annual_interest_rate,
        tenure_months=calculation.tenure_months,
        emi=calculation.emi,
        total_interest=calculation.total_interest,
        total_repayment=calculation.total_repayment,
    )
