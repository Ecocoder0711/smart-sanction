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
    """Supported lifecycle states for a loan application."""

    SUBMITTED = "submitted"
    UNDER_REVIEW = "under_review"
    APPROVED = "approved"
    REJECTED = "rejected"
    COMPLETED = "completed"
