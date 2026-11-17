"""Keypress wrapper. The real implementation uses ``pydirectinput`` (Windows only)."""

from __future__ import annotations

import logging
from typing import Protocol

log = logging.getLogger(__name__)


class KeyPresser(Protocol):
    def press(self, key: str) -> None:
        """Press and release ``key``."""
        ...


class PyDirectInputKeyPresser:
    """Sends keys through ``pydirectinput`` (many games ignore plain synthetic input)."""

    def __init__(self) -> None:
        import pydirectinput  # Windows only; imported lazily

        self._pdi = pydirectinput

    def press(self, key: str) -> None:
        self._pdi.press(key)


class LoggingKeyPresser:
    """Dry-run presser that only logs, so the loop can be exercised anywhere."""

    def press(self, key: str) -> None:
        log.info("[dry-run] press %r", key)
