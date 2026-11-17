import sys
from pathlib import Path

from conftest import RATE, with_splash
from wow_fishing.config import AudioConfig
from wow_fishing.fakes import ArrayAudioSource

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import record_sample  # noqa: E402


def test_wav_roundtrip(tmp_path):
    samples = with_splash(1.0, at=0.5)
    path = tmp_path / "x.wav"
    record_sample.write_wav(path, samples, RATE)
    loaded, rate = record_sample.read_wav(path)
    assert rate == RATE
    assert loaded.size == samples.size
    assert abs(loaded - samples).max() < 1e-3


def test_record_returns_requested_length():
    source = ArrayAudioSource(with_splash(2.0, at=1.0), RATE)
    out = record_sample.record(source, 1.5)
    assert out.size == int(1.5 * RATE)


def test_analyze_reports_cue(capsys):
    record_sample.analyze(with_splash(6.0, at=3.0), RATE, AudioConfig())
    assert "cue at" in capsys.readouterr().out


def test_analyze_reports_no_cue(capsys):
    record_sample.analyze(with_splash(6.0, at=3.0), RATE, AudioConfig(min_rms=0.9))
    assert "No cues detected" in capsys.readouterr().out
