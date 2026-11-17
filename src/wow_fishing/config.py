"""Configuration loaded from ``config.toml``."""

from __future__ import annotations

import tomllib
from dataclasses import dataclass, field, fields
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class InputConfig:
    key: str = "1"
    delay_between_presses: float = 1.0


@dataclass(frozen=True)
class LoopConfig:
    cue_timeout: float = 30.0
    pause_hotkey: str = "f9"
    quit_hotkey: str = "f10"


@dataclass(frozen=True)
class AudioConfig:
    band_low_hz: float = 1000.0
    band_high_hz: float = 5000.0
    chunk_ms: int = 50
    spike_ratio: float = 6.0
    min_rms: float = 0.01
    cooldown: float = 2.0
    baseline_alpha: float = 0.05


@dataclass(frozen=True)
class Config:
    input: InputConfig = field(default_factory=InputConfig)
    loop: LoopConfig = field(default_factory=LoopConfig)
    audio: AudioConfig = field(default_factory=AudioConfig)


def _section(cls: type, data: dict[str, Any], name: str) -> Any:
    known = {f.name for f in fields(cls)}
    unknown = set(data) - known
    if unknown:
        raise ValueError(f"Unknown option(s) in [{name}]: {', '.join(sorted(unknown))}")
    return cls(**data)


def config_from_dict(data: dict[str, Any]) -> Config:
    unknown = set(data) - {"input", "loop", "audio"}
    if unknown:
        raise ValueError(f"Unknown config section(s): {', '.join(sorted(unknown))}")
    return Config(
        input=_section(InputConfig, data.get("input", {}), "input"),
        loop=_section(LoopConfig, data.get("loop", {}), "loop"),
        audio=_section(AudioConfig, data.get("audio", {}), "audio"),
    )


def load_config(path: str | Path | None) -> Config:
    """Load a config file; ``None`` returns the defaults."""
    if path is None:
        return Config()
    with open(path, "rb") as fh:
        return config_from_dict(tomllib.load(fh))
