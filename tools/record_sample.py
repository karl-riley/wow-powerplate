"""Record a short clip of game audio (WASAPI loopback) for offline threshold tuning.

Usage (Windows):
    python tools/record_sample.py --seconds 30 --out samples/splash.wav
    python tools/record_sample.py --analyze samples/splash.wav -c config.toml

Recording writes a mono 16-bit WAV. Analysis replays any mono/stereo 16-bit WAV
through the spike detector and prints when it would have fired, so you can tune
``[audio]`` values in config.toml without being in the game.
"""

from __future__ import annotations

import argparse
import wave
from pathlib import Path

import numpy as np

from wow_fishing.config import AudioConfig, load_config
from wow_fishing.detectors.audio import AudioSource, find_spikes, rms


def write_wav(path: Path, samples: np.ndarray, sample_rate: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = (np.clip(samples, -1.0, 1.0) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as fh:
        fh.setnchannels(1)
        fh.setsampwidth(2)
        fh.setframerate(sample_rate)
        fh.writeframes(pcm.tobytes())


def read_wav(path: Path) -> tuple[np.ndarray, int]:
    with wave.open(str(path), "rb") as fh:
        if fh.getsampwidth() != 2:
            raise ValueError("Only 16-bit PCM WAV files are supported.")
        channels = fh.getnchannels()
        rate = fh.getframerate()
        raw = fh.readframes(fh.getnframes())
    data = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
    return data.reshape(-1, channels).mean(axis=1), rate


def record(source: AudioSource, seconds: float) -> np.ndarray:
    chunk = max(1, source.sample_rate // 20)
    total = int(seconds * source.sample_rate)
    parts: list[np.ndarray] = []
    got = 0
    source.flush()
    while got < total:
        parts.append(source.read(chunk))
        got += chunk
    return np.concatenate(parts)[:total]


def analyze(samples: np.ndarray, sample_rate: int, config: AudioConfig) -> None:
    print(f"{samples.size / sample_rate:.1f}s at {sample_rate} Hz, overall RMS {rms(samples):.4f}")
    spikes = find_spikes(samples, sample_rate, config)
    if not spikes:
        print("No cues detected. Try lowering spike_ratio or min_rms, or widening the band.")
    for t in spikes:
        print(f"cue at {t:6.2f}s")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--seconds", type=float, default=30.0, help="recording length")
    parser.add_argument("--out", type=Path, default=Path("samples/sample.wav"))
    parser.add_argument("--analyze", type=Path, help="analyze an existing WAV instead of recording")
    parser.add_argument("-c", "--config", help="config.toml supplying [audio] values")
    args = parser.parse_args()
    config = load_config(args.config).audio

    if args.analyze:
        samples, rate = read_wav(args.analyze)
        analyze(samples, rate, config)
        return 0

    from wow_fishing.detectors.audio import LoopbackAudioSource

    source = LoopbackAudioSource(config.chunk_ms)
    try:
        print(f"Recording {args.seconds:.0f}s of game audio... play the game now.")
        samples = record(source, args.seconds)
    finally:
        source.close()
    write_wav(args.out, samples, source.sample_rate)
    print(f"Saved {args.out}")
    analyze(samples, source.sample_rate, config)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
