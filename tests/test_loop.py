import threading
import time

from wow_fishing.config import Config, InputConfig, LoopConfig
from wow_fishing.controls import Controls
from wow_fishing.fakes import RecordingKeyPresser, ScriptedDetector
from wow_fishing.loop import FishingLoop


def make_config(delay: float = 0.0, key: str = "1") -> Config:
    return Config(
        input=InputConfig(key=key, delay_between_presses=delay),
        loop=LoopConfig(cue_timeout=5.0),
    )


def test_cue_presses_key_twice_per_cycle():
    keys = RecordingKeyPresser()
    loop = FishingLoop(ScriptedDetector([True, True]), keys, make_config(key="7"))
    assert loop.run(max_cycles=2) == 2
    assert keys.presses == ["7"] * 4


def test_timeout_does_not_press_and_retries():
    keys = RecordingKeyPresser()
    detector = ScriptedDetector([False, False, True])
    loop = FishingLoop(detector, keys, make_config())
    assert loop.run(max_cycles=1) == 1
    assert len(detector.calls) == 3
    assert detector.calls[0] == 5.0
    assert keys.presses == ["1", "1"]


def test_delay_between_presses_is_respected():
    keys = RecordingKeyPresser()
    stamps: list[float] = []
    original = keys.press
    keys.press = lambda k: (stamps.append(time.monotonic()), original(k))[1]
    loop = FishingLoop(ScriptedDetector([True]), keys, make_config(delay=0.2))
    loop.run(max_cycles=1)
    assert len(stamps) == 2
    assert stamps[1] - stamps[0] >= 0.19


def test_stop_before_run_does_nothing():
    controls = Controls()
    controls.stop()
    keys = RecordingKeyPresser()
    loop = FishingLoop(ScriptedDetector([True]), keys, make_config(), controls)
    assert loop.run() == 0
    assert keys.presses == []


def test_stop_during_delay_skips_second_press():
    controls = Controls()
    keys = RecordingKeyPresser()
    loop = FishingLoop(ScriptedDetector([True]), keys, make_config(delay=5.0), controls)
    threading.Timer(0.1, controls.stop).start()
    start = time.monotonic()
    assert loop.run() == 0
    assert time.monotonic() - start < 2.0
    assert keys.presses == ["1"]


def test_pause_blocks_until_resumed():
    controls = Controls()
    controls.toggle_pause()
    keys = RecordingKeyPresser()
    loop = FishingLoop(ScriptedDetector([True]), keys, make_config(), controls)
    threading.Timer(0.3, controls.toggle_pause).start()
    start = time.monotonic()
    assert loop.run(max_cycles=1) == 1
    assert time.monotonic() - start >= 0.25
    assert keys.presses == ["1", "1"]
