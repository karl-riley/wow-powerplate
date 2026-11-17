"""Detector interface shared by the audio and visual detectors."""

from __future__ import annotations

from abc import ABC, abstractmethod


class Detector(ABC):
    @abstractmethod
    def wait_for_cue(self, timeout: float) -> bool:
        """Block until the cue is seen/heard (True) or ``timeout`` seconds pass (False)."""

    def close(self) -> None:  # noqa: B027 - optional hook
        """Release any resources held by the detector."""
