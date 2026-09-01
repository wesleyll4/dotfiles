#!/usr/bin/env python3
"""Validate the repository's greetd/ReGreet bundle without starting a greeter."""

from __future__ import annotations

import struct
import sys
import tomllib
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"greetd validation failed: {message}")


def load_toml(path: Path) -> dict:
    try:
        with path.open("rb") as stream:
            return tomllib.load(stream)
    except (OSError, tomllib.TOMLDecodeError) as error:
        fail(f"{path.name}: {error}")


def expect(value: object, expected: object, label: str) -> None:
    if value != expected:
        fail(f"{label} must be {expected!r}, got {value!r}")


def validate_png(path: Path) -> None:
    try:
        header = path.read_bytes()[:24]
    except OSError as error:
        fail(f"{path.name}: {error}")
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        fail(f"{path.name} is not a valid PNG")
    width, height = struct.unpack(">II", header[16:24])
    if (width, height) != (2560, 1080):
        fail(f"wallpaper must be 2560x1080, got {width}x{height}")


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: validate-greetd.py GREETD_CONFIG_DIRECTORY")

    root = Path(sys.argv[1])
    greetd = load_toml(root / "config.toml")
    regreet = load_toml(root / "regreet.toml")

    expect(greetd.get("terminal", {}).get("vt"), 1, "terminal.vt")
    session = greetd.get("default_session", {})
    expect(session.get("user"), "greeter", "default_session.user")
    expect(
        session.get("command"),
        "dbus-run-session start-hyprland -- -c /etc/greetd/hyprland-greeter.lua",
        "default_session.command",
    )

    expect(regreet.get("skip_selection"), False, "skip_selection")
    expect(
        regreet.get("background", {}).get("path"),
        "@WALLPAPER@",
        "background.path",
    )
    if regreet.get("background", {}).get("fit") not in {
        "Fill",
        "Contain",
        "Cover",
        "ScaleDown",
    }:
        fail("background.fit is not a supported GTK content fit")
    expect(
        regreet.get("widget", {}).get("clock", {}).get("timezone"),
        "America/Sao_Paulo",
        "widget.clock.timezone",
    )

    css = root / "regreet.css"
    try:
        css_text = css.read_text(encoding="utf-8")
    except OSError as error:
        fail(f"{css.name}: {error}")
    if "frame.background" not in css_text or "button.suggested-action" not in css_text:
        fail("regreet.css is missing required login-panel selectors")
    destructive = css_text.split("button.destructive-action {", 1)
    if len(destructive) != 2:
        fail("regreet.css is missing the destructive-action selector")
    destructive_block = destructive[1].split("}", 1)[0]
    if "#f7768e" in destructive_block or "247, 118, 142" in destructive_block:
        fail("destructive-action still uses the red accent")
    for selector in (
        "button.destructive-action {",
        "button.destructive-action:hover,",
        "button.destructive-action:active,",
    ):
        parts = css_text.split(selector, 1)
        if len(parts) != 2 or "background-image: none;" not in parts[1].split("}", 1)[0]:
            fail(f"{selector} does not reset the GTK destructive background image")

    launcher = root / "launch-regreet.sh"
    try:
        launcher_text = launcher.read_text(encoding="utf-8")
    except OSError as error:
        fail(f"{launcher.name}: {error}")
    if "REGREET_WALLPAPER_DIR" not in launcher_text or "@WALLPAPER@" not in launcher_text:
        fail("launch-regreet.sh is missing wallpaper selection support")

    try:
        greeter_lua = (root / "hyprland-greeter.lua").read_text(encoding="utf-8")
    except OSError as error:
        fail(f"hyprland-greeter.lua: {error}")
    if "/etc/greetd/launch-regreet.sh" not in greeter_lua:
        fail("Hyprland greeter does not invoke launch-regreet.sh")

    validate_png(root / "tokyo-night-city.png")
    print("greetd/ReGreet metadata: ok")


if __name__ == "__main__":
    main()
