"""Shared domain enumerations."""

from enum import Enum


class ApplicationStatus(str, Enum):
    """Supported lifecycle states for a loan application."""

    SUBMITTED = "submitted"
    UNDER_REVIEW = "under_review"
    APPROVED = "approved"
    REJECTED = "rejected"
    COMPLETED = "completed"

