"""Visual detector (screen capture plus template match). Stub in v1."""

from __future__ import annotations

from .base import Detector


class VisualDetector(Detector):
    """Planned: capture the screen with ``mss`` and template-match with OpenCV.

    The ``mss`` and ``cv2`` imports will be done lazily inside this class
    once implemented, so the package stays importable without them.
    """

    def wait_for_cue(self, timeout: float) -> bool:
        raise NotImplementedError("The visual detector is not implemented yet; use audio.")
