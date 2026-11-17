import importlib
import sys

import pytest

from wow_fishing.__main__ import main
from wow_fishing.config import Config, load_config


def test_defaults_when_no_path():
    cfg = load_config(None)
    assert cfg == Config()
    assert cfg.input.delay_between_presses == 1.0


def test_load_partial_toml(tmp_path):
    path = tmp_path / "config.toml"
    path.write_text('[input]\nkey = "f"\n\n[audio]\nspike_ratio = 3.5\n')
    cfg = load_config(path)
    assert cfg.input.key == "f"
    assert cfg.audio.spike_ratio == 3.5
    assert cfg.loop.cue_timeout == 30.0


def test_unknown_option_rejected(tmp_path):
    path = tmp_path / "config.toml"
    path.write_text("[input]\nkeyy = 1\n")
    with pytest.raises(ValueError, match="keyy"):
        load_config(path)


def test_unknown_section_rejected(tmp_path):
    path = tmp_path / "config.toml"
    path.write_text("[nope]\nx = 1\n")
    with pytest.raises(ValueError, match="nope"):
        load_config(path)


def test_example_config_matches_defaults():
    from pathlib import Path

    example = Path(__file__).resolve().parents[1] / "config.example.toml"
    assert load_config(example) == Config()


def test_cli_fake_dry_run(caplog, tmp_path):
    cfg = tmp_path / "c.toml"
    cfg.write_text("[input]\ndelay_between_presses = 0.0\n")
    with caplog.at_level("INFO"):
        rc = main(
            ["--detector", "fake", "--dry-run", "--no-hotkeys", "--max-cycles", "1", "-c", str(cfg)]
        )
    assert rc == 0
    assert caplog.text.count("[dry-run] press") == 2


def test_windows_only_libraries_not_imported_eagerly():
    for name in ("pydirectinput", "pyaudiowpatch", "keyboard", "cv2", "mss"):
        sys.modules.pop(name, None)
    for mod in list(sys.modules):
        if mod.startswith("wow_fishing"):
            del sys.modules[mod]
    importlib.import_module("wow_fishing.__main__")
    importlib.import_module("wow_fishing.detectors.audio")
    importlib.import_module("wow_fishing.detectors.visual")
    for name in ("pydirectinput", "pyaudiowpatch", "keyboard", "cv2", "mss"):
        assert name not in sys.modules
