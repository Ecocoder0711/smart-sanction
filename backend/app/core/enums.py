"""Shared domain enumerations."""

from enum import Enum


class ApplicantCategory(str, Enum):
    """Supported applicant caste/social categories."""

    SC = "SC"
    ST = "ST"
    OBC = "OBC"
    GENERAL = "GENERAL"


class Gender(str, Enum):
    """Supported applicant gender values."""

    MALE = "MALE"
    FEMALE = "FEMALE"
    OTHER = "OTHER"


class SchemeCategoryEligibility(str, Enum):
    """Category targeting supported by a scheme."""

    ANY = "ANY"
    SC = "SC"
    ST = "ST"
    OBC = "OBC"
    GENERAL = "GENERAL"


class GenderEligibility(str, Enum):
    """Gender targeting supported by a scheme."""

    ANY = "ANY"
    MALE = "MALE"
    FEMALE = "FEMALE"
    OTHER = "OTHER"


class ApplicationStatus(str, Enum):
    """Supported lifecycle states for a loan application.

    Declared in lifecycle order. DRAFT precedes SUBMITTED: a draft is the
    applicant's own unsent work, is the only state that may lack a partner,
    and is the only state besides SUBMITTED a client may create directly.
    """

    DRAFT = "draft"
    SUBMITTED = "submitted"
    UNDER_REVIEW = "under_review"
    APPROVED = "approved"
    REJECTED = "rejected"
    COMPLETED = "completed"
