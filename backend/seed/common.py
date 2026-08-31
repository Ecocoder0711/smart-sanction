"""Small shared types used by the synthetic seed modules."""

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class SeedResult:
    """Insertion summary for one seeded entity type."""

    total: int
    inserted: int

    @property
    def existing(self) -> int:
        """Number of deterministic seed records already present."""
        return self.total - self.inserted

