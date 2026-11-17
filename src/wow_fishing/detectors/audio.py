"""Audio cue detection: RMS and band-energy spike detection on game output.

The DSP (:class:`SpikeAnalyzer`) is pure numpy. Audio capture sits behind the
:class:`AudioSource` protocol; the real WASAPI loopback source is Windows-only
and imports its library lazily.
"""

from __future__ import annotations

import time
from collections.abc import Callable
from typing import Protocol

import numpy as np

from ..config import AudioConfig
from .base import Detector

_EPS = 1e-12
_WARMUP_CHUNKS = 10


class AudioSource(Protocol):
    """A stream of mono float samples in the range [-1, 1]."""

    @property
    def sample_rate(self) -> int: ...

    def read(self, frames: int) -> np.ndarray:
        """Return exactly ``frames`` mono float32 samples (blocking)."""
        ...

    def flush(self) -> None:
        """Drop any audio buffered but not yet read."""
        ...

    def close(self) -> None: ...


def rms(chunk: np.ndarray) -> float:
    if chunk.size == 0:
        return 0.0
    return float(np.sqrt(np.mean(np.square(chunk, dtype=np.float64))))


def band_energy(chunk: np.ndarray, sample_rate: int, low_hz: float, high_hz: float) -> float:
    """Mean spectral power of ``chunk`` between ``low_hz`` and ``high_hz``."""
    n = chunk.size
    if n == 0:
        return 0.0
    windowed = chunk.astype(np.float64) * np.hanning(n)
    spectrum = np.fft.rfft(windowed)
    freqs = np.fft.rfftfreq(n, d=1.0 / sample_rate)
    mask = (freqs >= low_hz) & (freqs <= high_hz)
    if not mask.any():
        return 0.0
    power = (np.abs(spectrum[mask]) ** 2) / (n * n)
    return float(power.mean())


class SpikeAnalyzer:
    """Flags chunks whose band energy jumps well above a running baseline."""

    def __init__(self, config: AudioConfig, sample_rate: int) -> None:
        self.config = config
        self.sample_rate = sample_rate
        self.chunk_size = max(1, int(sample_rate * config.chunk_ms / 1000))
        self._chunk_seconds = self.chunk_size / sample_rate
        self._baseline: float | None = None
        self._seen = 0
        self._cooldown_left = 0.0

    def start_cooldown(self) -> None:
        """Ignore spikes for the configured cooldown (e.g. right after sending input)."""
        self._cooldown_left = self.config.cooldown

    def process(self, chunk: np.ndarray) -> bool:
        cfg = self.config
        energy = band_energy(chunk, self.sample_rate, cfg.band_low_hz, cfg.band_high_hz)
        level = rms(chunk)
        self._seen += 1

        if self._baseline is None:
            self._baseline = energy
            return False

        in_cooldown = self._cooldown_left > 0
        if in_cooldown:
            self._cooldown_left = max(0.0, self._cooldown_left - self._chunk_seconds)

        is_spike = (
            self._seen > _WARMUP_CHUNKS
            and not in_cooldown
            and level >= cfg.min_rms
            and energy > cfg.spike_ratio * max(self._baseline, _EPS)
        )
        if is_spike:
            self._cooldown_left = cfg.cooldown
            return True

        # Only quiet-ish chunks feed the baseline so spikes don't raise it.
        self._baseline += cfg.baseline_alpha * (energy - self._baseline)
        return False


def find_spikes(samples: np.ndarray, sample_rate: int, config: AudioConfig) -> list[float]:
    """Run the analyzer over a whole recording; return spike times in seconds."""
    analyzer = SpikeAnalyzer(config, sample_rate)
    size = analyzer.chunk_size
    times: list[float] = []
    for start in range(0, samples.size - size + 1, size):
        if analyzer.process(samples[start : start + size]):
            times.append(start / sample_rate)
    return times


class AudioDetector(Detector):
    def __init__(
        self,
        source: AudioSource,
        config: AudioConfig,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._source = source
        self._analyzer = SpikeAnalyzer(config, source.sample_rate)
        self._clock = clock

    def wait_for_cue(self, timeout: float) -> bool:
        self._source.flush()
        self._analyzer.start_cooldown()
        deadline = self._clock() + timeout
        while self._clock() < deadline:
            chunk = self._source.read(self._analyzer.chunk_size)
            if self._analyzer.process(chunk):
                return True
        return False

    def close(self) -> None:
        self._source.close()


class LoopbackAudioSource:
    """WASAPI loopback capture of the default output device (Windows, PyAudioWPatch)."""

    def __init__(self, chunk_ms: int = 50) -> None:
        import pyaudiowpatch as pyaudio  # Windows only; imported lazily

        self._pa = pyaudio.PyAudio()
        try:
            wasapi = self._pa.get_host_api_info_by_type(pyaudio.paWASAPI)
            device = self._pa.get_device_info_by_index(wasapi["defaultOutputDevice"])
            if not device.get("isLoopbackDevice"):
                for loopback in self._pa.get_loopback_device_info_generator():
                    if device["name"] in loopback["name"]:
                        device = loopback
                        break
                else:
                    raise RuntimeError("No WASAPI loopback device found for the default output.")

            self._channels = int(device["maxInputChannels"])
            self._rate = int(device["defaultSampleRate"])
            self._stream = self._pa.open(
                format=pyaudio.paFloat32,
                channels=self._channels,
                rate=self._rate,
                input=True,
                input_device_index=device["index"],
                frames_per_buffer=max(1, int(self._rate * chunk_ms / 1000)),
            )
        except Exception:
            self._pa.terminate()
            raise

    @property
    def sample_rate(self) -> int:
        return self._rate

    def read(self, frames: int) -> np.ndarray:
        raw = self._stream.read(frames, exception_on_overflow=False)
        data = np.frombuffer(raw, dtype=np.float32).reshape(-1, self._channels)
        return data.mean(axis=1)

    def flush(self) -> None:
        available = self._stream.get_read_available()
        if available > 0:
            self._stream.read(available, exception_on_overflow=False)

    def close(self) -> None:
        self._stream.stop_stream()
        self._stream.close()
        self._pa.terminate()
