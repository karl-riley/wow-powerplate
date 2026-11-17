"""Pause/quit state shared between the loop and the hotkey listener."""

from __future__ import annotations

import logging
import threading

from .config import LoopConfig

log = logging.getLogger(__name__)


class Controls:
    """Thread-safe pause and stop flags."""

    def __init__(self) -> None:
        self._stop = threading.Event()
        self._paused = threading.Event()

    @property
    def stopped(self) -> bool:
        return self._stop.is_set()

    @property
    def paused(self) -> bool:
        return self._paused.is_set()

    def stop(self) -> None:
        self._stop.set()

    def toggle_pause(self) -> None:
        if self._paused.is_set():
            self._paused.clear()
            log.info("resumed")
        else:
            self._paused.set()
            log.info("paused")

    def wait(self, seconds: float) -> bool:
        """Sleep up to ``seconds``; return True if stop was requested meanwhile."""
        return self._stop.wait(seconds)


def register_hotkeys(controls: Controls, config: LoopConfig) -> None:
    """Register global pause/quit hotkeys using the Windows-only ``keyboard`` package."""
    import keyboard  # Windows only; imported lazily

    keyboard.add_hotkey(config.pause_hotkey, controls.toggle_pause)
    keyboard.add_hotkey(config.quit_hotkey, controls.stop)
    log.info("hotkeys: %s = pause/resume, %s = quit", config.pause_hotkey, config.quit_hotkey)
