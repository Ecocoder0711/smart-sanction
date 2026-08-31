"""Read-only scheme and category API routes."""

from decimal import Decimal
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Path, Query, status
from sqlalchemy.orm import Session

from app.database.session import get_db
from app.schemas.calculator import SchemeCalculationRequest, SchemeCalculationResponse
from app.schemas.scheme import (
    SchemeCategoryResponse,
    SchemeListResponse,
    SchemeResponse,
)
from app.services import scheme_service
from app.services import calculator_service

router = APIRouter(prefix="/api/schemes", tags=["Schemes"])
DatabaseSession = Annotated[Session, Depends(get_db)]


@router.get(
    "/categories",
    response_model=list[SchemeCategoryResponse],
    summary="List scheme categories",
    description="Returns all stored scheme categories ordered by category name.",
)
def list_scheme_categories(session: DatabaseSession) -> list[SchemeCategoryResponse]:
    """Return all scheme categories."""
    return scheme_service.list_categories(session)


@router.get(
    "",
    response_model=SchemeListResponse,
    summary="List and filter schemes",
    description=(
        "Returns active schemes by default. Filters only retrieve stored data and "
        "do not perform an eligibility decision."
    ),
)
def list_schemes(
    session: DatabaseSession,
    category_id: Annotated[
        int | None,
        Query(gt=0, description="Filter by scheme category primary key."),
    ] = None,
    category: Annotated[
        str | None,
        Query(min_length=1, max_length=50, description="Filter by category name."),
    ] = None,
    max_income: Annotated[
        Decimal | None,
        Query(
            ge=0,
            description="Applicant income; returns schemes whose income limit accepts it.",
        ),
    ] = None,
    requested_amount: Annotated[
        Decimal | None,
        Query(
            gt=0,
            description="Requested amount; returns schemes with a sufficient loan limit.",
        ),
    ] = None,
    is_active: Annotated[
        bool | None,
        Query(description="Filter active or inactive schemes; defaults to active."),
    ] = True,
) -> SchemeListResponse:
    """Return schemes matching the supplied retrieval filters."""
    items = scheme_service.list_schemes(
        session,
        category_id=category_id,
        category=category,
        max_income=max_income,
        requested_amount=requested_amount,
        is_active=is_active,
    )
    return SchemeListResponse(items=items, total=len(items))


@router.get(
    "/{scheme_id}",
    response_model=SchemeResponse,
    summary="Get a scheme",
    description="Returns one stored scheme and its category.",
    responses={404: {"description": "Scheme not found."}},
)
def get_scheme(
    session: DatabaseSession,
    scheme_id: Annotated[int, Path(gt=0, description="Scheme primary key.")],
) -> SchemeResponse:
    """Return one scheme or a clean 404 response."""
    scheme = scheme_service.get_scheme(session, scheme_id)
    if scheme is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Scheme not found",
        )
    return scheme


@router.post(
    "/{scheme_id}/calculate",
    response_model=SchemeCalculationResponse,
    summary="Calculate a scheme loan",
    description=(
        "Uses the selected active scheme's stored interest rate for a deterministic "
        "reducing-balance calculation. Stored scheme data is not modified."
    ),
    responses={
        400: {"description": "Scheme is inactive."},
        404: {"description": "Scheme not found."},
    },
)
def calculate_scheme_loan(
    payload: SchemeCalculationRequest,
    session: DatabaseSession,
    scheme_id: Annotated[int, Path(gt=0, description="Scheme primary key.")],
) -> SchemeCalculationResponse:
    """Calculate repayment using the stored scheme interest rate."""
    scheme = scheme_service.get_scheme(session, scheme_id)
    if scheme is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Scheme not found",
        )
    if not scheme.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Scheme is inactive",
        )
    return calculator_service.calculate_scheme_loan(
        scheme,
        principal=payload.requested_amount,
        tenure_months=payload.tenure_months,
    )
