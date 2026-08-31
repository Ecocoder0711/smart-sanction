"""Financial calculator contracts; calculations are implemented in a later phase."""

from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.scheme import SchemeResponse


class CalculatorRequest(BaseModel):
    """Loan repayment calculation input."""

    model_config = ConfigDict(extra="forbid")

    principal: Decimal = Field(gt=0, max_digits=14, decimal_places=2)
    annual_interest_rate: Decimal = Field(ge=0, max_digits=7, decimal_places=4)
    tenure_months: int = Field(gt=0, le=1200)


class CalculatorResponse(BaseModel):
    """Loan repayment calculation output."""

    principal: Decimal
    annual_interest_rate: Decimal
    tenure_months: int
    emi: Decimal
    total_repayment: Decimal
    total_interest: Decimal


class SchemeCalculationRequest(BaseModel):
    """Calculation input whose interest rate comes from a stored scheme."""

    model_config = ConfigDict(extra="forbid")

    requested_amount: Decimal = Field(gt=0, max_digits=14, decimal_places=2)
    tenure_months: int = Field(gt=0, le=1200)


class SchemeCalculationResponse(BaseModel):
    """Loan calculation associated with a public scheme."""

    scheme: SchemeResponse
    principal: Decimal
    interest_rate: Decimal
    tenure_months: int
    emi: Decimal
    total_interest: Decimal
    total_repayment: Decimal
