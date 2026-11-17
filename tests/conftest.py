import numpy as np
import pytest

RATE = 16000


@pytest.fixture
def rate() -> int:
    return RATE


def tone(freq: float, seconds: float, amp: float, rate: int = RATE) -> np.ndarray:
    t = np.arange(int(seconds * rate)) / rate
    return (amp * np.sin(2 * np.pi * freq * t)).astype(np.float32)


def background(seconds: float, rate: int = RATE, seed: int = 0) -> np.ndarray:
    """Quiet low-frequency ambience plus faint noise, outside the detection band."""
    rng = np.random.default_rng(seed)
    noise = rng.normal(0, 0.002, int(seconds * rate)).astype(np.float32)
    return tone(200, seconds, 0.03, rate) + noise


def with_splash(total: float, at: float, rate: int = RATE) -> np.ndarray:
    """Background audio with a short loud 2.5 kHz burst starting at ``at`` seconds."""
    audio = background(total, rate)
    start = int(at * rate)
    burst = tone(2500, 0.15, 0.3, rate)
    audio[start : start + burst.size] += burst
    return audio
