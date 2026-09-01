# Hyprland Lua and ReGreet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the deprecated Hyprland configuration with a validated modular Lua configuration and replace Ly with a reproducible, rollback-safe greetd/ReGreet login.

**Architecture:** The normal session loads focused Lua modules from `hyprland.lua`, while the legacy `hyprland.conf` remains available for rollback. A separate minimal Hyprland Lua session hosts ReGreet on HDMI-A-1; repository-owned scripts install user links and guarded copies under `/etc/greetd`.

**Tech Stack:** Hyprland 0.56 Lua API, greetd, ReGreet/GTK4 CSS, POSIX shell, Arch Linux/systemd.

## Global Constraints

- Preserve all pre-existing uncommitted user changes.
- Keep `hypridle.conf`, `hyprlock.conf`, and `hyprland.conf` intact and usable.
- Keep Ly installed and provide rollback to `ly@tty1.service`.
- Target HDMI-A-1 at 2560x1080 and DP-3 at 1920x1080.
- Do not commit or redistribute the existing Wallhaven wallpaper.

---

### Task 1: Executable checks and repository layout

- [x] Add behavior tests for the installer before implementing it.
- [x] Add a non-mutating `check` command and package manifest.
- [x] Verify the tests fail before implementation and pass afterward.

### Task 2: Modular Hyprland Lua configuration

- [x] Translate settings, monitors, autostart, input, binds, and rules manually.
- [x] Keep shared values in an explicit constants module.
- [x] Resolve `SUPER+CTRL+J` as swap-down and assign togglesplit to `SUPER+ALT+J`.
- [x] Validate with `Hyprland --verify-config`.

### Task 3: ReGreet visual and greeter session

- [x] Generate an original ultrawide Tokyo Night sci-fi city wallpaper.
- [x] Add ReGreet TOML/CSS and a minimal Hyprland Lua greeter config.
- [x] Keep login on HDMI-A-1 and DP-3 visually quiet.
- [x] Validate the greeter Lua config and inspect the final image.

### Task 4: Safe installation and rollback

- [x] Implement `check`, `install-user`, `install-system`, and `rollback`.
- [x] Refuse unknown user-file conflicts and back up system files before replacement.
- [x] Disable Ly only after all static checks pass; never uninstall it.
- [x] Exercise installer behavior against isolated temporary roots.

### Task 5: Final verification

- [x] Run all tests and both Hyprland config validators.
- [x] Review the full diff for accidental changes to pre-existing work.
- [x] Leave system-service activation pending unless root execution is explicitly approved at the command boundary.
