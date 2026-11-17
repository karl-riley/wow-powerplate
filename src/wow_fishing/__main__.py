"""CLI entry point: ``python -m wow_fishing``."""

from __future__ import annotations

import argparse
import logging
import sys
from collections.abc import Sequence

from .config import Config, load_config
from .controls import Controls, register_hotkeys
from .detectors.base import Detector
from .input import KeyPresser, LoggingKeyPresser, PyDirectInputKeyPresser
from .loop import FishingLoop


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="wow-fishing", description="Hobby project: react to a fishing splash cue."
    )
    parser.add_argument("-c", "--config", help="path to config.toml (defaults are used if omitted)")
    parser.add_argument(
        "--detector",
        choices=["audio", "visual", "fake"],
        default="audio",
        help="cue detector (default: audio; 'fake' fires every few seconds for demos)",
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="log key presses instead of sending them"
    )
    parser.add_argument(
        "--no-hotkeys", action="store_true", help="do not register global pause/quit hotkeys"
    )
    parser.add_argument("--max-cycles", type=int, help="stop after this many completed cycles")
    parser.add_argument("-v", "--verbose", action="store_true")
    return parser


def build_detector(name: str, config: Config) -> Detector:
    if name == "fake":
        from .fakes import FakeDetector

        return FakeDetector()
    if name == "visual":
        from .detectors.visual import VisualDetector

        return VisualDetector()
    from .detectors.audio import AudioDetector, LoopbackAudioSource

    source = LoopbackAudioSource(config.audio.chunk_ms)
    return AudioDetector(source, config.audio)


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )
    config = load_config(args.config)

    keys: KeyPresser = LoggingKeyPresser() if args.dry_run else PyDirectInputKeyPresser()
    controls = Controls()
    if not args.no_hotkeys:
        register_hotkeys(controls, config.loop)

    detector = build_detector(args.detector, config)
    try:
        cycles = FishingLoop(detector, keys, config, controls).run(max_cycles=args.max_cycles)
    except KeyboardInterrupt:
        logging.getLogger(__name__).info("interrupted")
        cycles = 0
    finally:
        detector.close()
    logging.getLogger(__name__).info("done after %d cycle(s)", cycles)
    return 0


if __name__ == "__main__":
    sys.exit(main())
