"""The fishing loop: cue, press, wait, press, repeat."""

from __future__ import annotations

import logging

from .config import Config
from .controls import Controls
from .detectors.base import Detector
from .input import KeyPresser

log = logging.getLogger(__name__)

_PAUSE_POLL_SECONDS = 0.1


class FishingLoop:
    def __init__(
        self,
        detector: Detector,
        keys: KeyPresser,
        config: Config,
        controls: Controls | None = None,
    ) -> None:
        self.detector = detector
        self.keys = keys
        self.config = config
        self.controls = controls or Controls()

    def run(self, max_cycles: int | None = None) -> int:
        """Run until stopped (or ``max_cycles`` cues handled). Returns cycles completed."""
        cycles = 0
        controls = self.controls
        while not controls.stopped and (max_cycles is None or cycles < max_cycles):
            if controls.paused:
                controls.wait(_PAUSE_POLL_SECONDS)
                continue

            if not self.detector.wait_for_cue(self.config.loop.cue_timeout):
                log.debug("no cue within %.1fs", self.config.loop.cue_timeout)
                continue
            if controls.stopped or controls.paused:
                continue

            key = self.config.input.key
            log.info("cue detected: pressing %r", key)
            self.keys.press(key)
            if controls.wait(self.config.input.delay_between_presses):
                break
            self.keys.press(key)
            cycles += 1
        return cycles
