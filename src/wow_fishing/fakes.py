"""Fake detector, key presser and audio source for tests and ``--detector fake``."""

from __future__ import annotations

import time
from collections.abc import Iterable

import numpy as np

from .detectors.base import Detector


class FakeDetector(Detector):
    """Reports a cue after ``interval`` seconds, up to ``cues`` times (None = forever)."""

    def __init__(self, interval: float = 2.0, cues: int | None = None) -> None:
        self.interval = interval
        self.remaining = cues

    def wait_for_cue(self, timeout: float) -> bool:
        if self.remaining is not None and self.remaining <= 0:
            return False
        wait = min(self.interval, timeout)
        time.sleep(wait)
        if wait < self.interval:
            return False
        if self.remaining is not None:
            self.remaining -= 1
        return True


class ScriptedDetector(Detector):
    """Returns a scripted sequence of results without sleeping; False when exhausted."""

    def __init__(self, results: Iterable[bool]) -> None:
        self._results = iter(results)
        self.calls: list[float] = []

    def wait_for_cue(self, timeout: float) -> bool:
        self.calls.append(timeout)
        return next(self._results, False)


class RecordingKeyPresser:
    def __init__(self) -> None:
        self.presses: list[str] = []

    def press(self, key: str) -> None:
        self.presses.append(key)


class ArrayAudioSource:
    """Serves a numpy array as an audio stream; pads with silence once exhausted."""

    def __init__(self, samples: np.ndarray, sample_rate: int = 16000) -> None:
        self._samples = np.asarray(samples, dtype=np.float32)
        self._rate = sample_rate
        self._pos = 0
        self.flushed = 0
        self.closed = False

    @property
    def sample_rate(self) -> int:
        return self._rate

    @property
    def exhausted(self) -> bool:
        return self._pos >= self._samples.size

    def read(self, frames: int) -> np.ndarray:
        chunk = self._samples[self._pos : self._pos + frames]
        self._pos += frames
        if chunk.size < frames:
            chunk = np.concatenate([chunk, np.zeros(frames - chunk.size, dtype=np.float32)])
        return chunk

    def flush(self) -> None:
        self.flushed += 1

    def close(self) -> None:
        self.closed = True
