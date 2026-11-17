import numpy as np

from conftest import RATE, background, tone, with_splash
from wow_fishing.config import AudioConfig
from wow_fishing.detectors.audio import (
    AudioDetector,
    SpikeAnalyzer,
    band_energy,
    find_spikes,
    rms,
)
from wow_fishing.fakes import ArrayAudioSource

CFG = AudioConfig()


def test_rms_of_sine():
    assert abs(rms(tone(440, 1.0, 0.5)) - 0.5 / np.sqrt(2)) < 1e-3
    assert rms(np.array([], dtype=np.float32)) == 0.0


def test_band_energy_only_counts_band():
    in_band = band_energy(tone(2500, 0.05, 0.3), RATE, 1000, 5000)
    out_band = band_energy(tone(200, 0.05, 0.3), RATE, 1000, 5000)
    assert in_band > 1000 * out_band


def test_no_spike_in_steady_background():
    assert find_spikes(background(5.0), RATE, CFG) == []


def test_detects_splash_near_expected_time():
    spikes = find_spikes(with_splash(6.0, at=3.0), RATE, CFG)
    assert len(spikes) == 1
    assert 2.9 <= spikes[0] <= 3.2


def test_cooldown_suppresses_repeat_spikes():
    audio = with_splash(8.0, at=3.0)
    burst = tone(2500, 0.15, 0.3)
    start = int(3.5 * RATE)
    audio[start : start + burst.size] += burst
    assert len(find_spikes(audio, RATE, CFG)) == 1


def test_quiet_spike_below_min_rms_ignored():
    cfg = AudioConfig(min_rms=0.5)
    assert find_spikes(with_splash(6.0, at=3.0), RATE, cfg) == []


def test_analyzer_does_not_fire_during_warmup():
    analyzer = SpikeAnalyzer(CFG, RATE)
    loud = tone(2500, analyzer.chunk_size / RATE, 0.5)
    quiet = np.zeros(analyzer.chunk_size, dtype=np.float32)
    assert analyzer.process(quiet) is False
    assert analyzer.process(loud) is False


class FakeClock:
    """Advances by a fixed step each call, so timeouts are deterministic."""

    def __init__(self, step: float) -> None:
        self.now = 0.0
        self.step = step

    def __call__(self) -> float:
        self.now += self.step
        return self.now


def test_detector_returns_true_on_splash():
    # Cooldown is shortened so the post-flush cooldown doesn't swallow the early splash.
    cfg = AudioConfig(cooldown=0.1)
    source = ArrayAudioSource(with_splash(6.0, at=3.0), RATE)
    detector = AudioDetector(source, cfg, clock=FakeClock(0.01))
    assert detector.wait_for_cue(timeout=30.0) is True
    assert source.flushed == 1


def test_detector_times_out_on_silence():
    source = ArrayAudioSource(background(2.0), RATE)
    detector = AudioDetector(source, CFG, clock=FakeClock(0.05))
    assert detector.wait_for_cue(timeout=1.0) is False


def test_detector_close_closes_source():
    source = ArrayAudioSource(np.zeros(10, dtype=np.float32), RATE)
    AudioDetector(source, CFG).close()
    assert source.closed
