# ReGreet Wallpaper Rotation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Randomly choose one of Wes's two local wallpapers whenever ReGreet starts, retain the tracked Tokyo Night fallback, and replace red power controls with neutral blue-gray styling.

**Architecture:** Ignored wallpaper links live below the existing greetd source tree, so the installer can stage their bytes without publishing them. A tracked launcher selects an installed wallpaper, renders a private runtime TOML from the tracked template, and starts ReGreet; the existing manifest, backup, drift, and rollback protections are extended to nested optional wallpaper files.

**Tech Stack:** Bash, greetd, ReGreet TOML, GTK4 CSS, Hyprland Lua, Python `tomllib`, shell integration tests.

## Global Constraints

- Preserve all pre-existing uncommitted user changes.
- Work directly on `master` and do not create commits or push.
- Do not commit or redistribute the selected Wallhaven images.
- Use `/etc/greetd/tokyo-night-city.png` when no local wallpaper is staged.
- Select a wallpaper once per greeter start, not during password entry.
- Keep activation separate and require a successful demo first.

---

### Task 1: ReGreet launcher and visual styling

**Files:**
- Create: `greetd/etc/greetd/launch-regreet.sh`
- Modify: `greetd/etc/greetd/regreet.toml`
- Modify: `greetd/etc/greetd/regreet.css`
- Modify: `greetd/etc/greetd/hyprland-greeter.lua`
- Modify: `scripts/validate-greetd.py`
- Modify: `tests/config-test.sh`

**Interfaces:**
- Consumes: `/etc/greetd/wallpapers/*.{png,jpg,jpeg,webp}` and `/etc/greetd/tokyo-night-city.png`.
- Produces: `launch-regreet.sh [--demo]`, which starts ReGreet with a generated private runtime config.

- [ ] **Step 1: Write failing launcher, template and CSS assertions**

  Add shell tests that run the desired launcher with an isolated wallpaper directory, template, runtime directory and fake ReGreet command. Assert that a sole local image is inserted into the generated config, an empty directory uses the fallback, `--demo` is forwarded, the Hyprland command calls the launcher, and the destructive selector no longer contains `#f7768e`.

- [ ] **Step 2: Run the focused tests and verify RED**

  Run: `bash tests/config-test.sh`

  Expected: failure because `launch-regreet.sh` does not exist and the current CSS still uses `#f7768e`.

- [ ] **Step 3: Implement the minimal launcher and style change**

  Implement a Bash launcher using a safe extension allowlist, `${RANDOM}` selection (with `REGREET_RANDOM_INDEX` for deterministic verification), `mktemp` under `${XDG_RUNTIME_DIR}`, `sed` substitution of `@WALLPAPER@`, cleanup on exit, and optional `--demo`. Change the tracked TOML background path to the marker, route the Hyprland startup command through the launcher, and restyle destructive actions with `#a9b1d6` text and the Tokyo Night blue accent on hover/focus.

- [ ] **Step 4: Validate GREEN**

  Run: `bash tests/config-test.sh`

  Expected: all configuration and launcher checks pass.

---

### Task 2: Optional wallpaper staging with safety and rollback

**Files:**
- Modify: `install.sh`
- Modify: `tests/install-test.sh`
- Modify: `.gitignore`
- Create locally, ignored: `greetd/etc/greetd/wallpapers/monochrome.png` symlink
- Create locally, ignored: `greetd/etc/greetd/wallpapers/elf-prison.jpg` symlink

**Interfaces:**
- Consumes: optional source files whose basenames match `[A-Za-z0-9._-]+` and whose lowercase extension is `png`, `jpg`, `jpeg`, or `webp`.
- Produces: regular root-owned copies below `/etc/greetd/wallpapers/` and deployed-state entries for each copy.

- [ ] **Step 1: Write failing installer tests**

  Add tests that provide isolated optional wallpaper sources and assert: nested files are staged as regular files; a symlinked destination is rejected before backup; source-set drift after the demo blocks activation; rollback restores or removes wallpaper files according to the backup; and invalid extensions/names are rejected or ignored according to the explicit allowlist.

- [ ] **Step 2: Run the focused installer suite and verify RED**

  Run: `bash tests/install-test.sh`

  Expected: the new wallpaper staging assertions fail because the installer currently manages only five flat files.

- [ ] **Step 3: Extend managed-file discovery and lifecycle operations**

  Add deterministic source discovery before validation. Extend the managed-file allowlist to `etc/greetd/wallpapers/<safe-image-name>`, create nested parents before backup/install/snapshot operations, install the launcher as mode `0755`, compare the staged manifest's exact file set during activation, and use the manifest during rollback so optional files receive the same symlink, drift and recovery protections as static files.

- [ ] **Step 4: Validate GREEN**

  Run: `bash tests/install-test.sh`

  Expected: every installer test passes, including the existing Ly recovery tests.

---

### Task 3: Local setup, documentation and complete verification

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-08-16-regreet-wallpaper-rotation.md`
- Local ignored links: the two approved wallpaper sources.

**Interfaces:**
- Consumes: the approved image paths under `/home/wes/Pictures/wallpapers/`.
- Produces: a reproducible setup recipe and `/etc/greetd/launch-regreet.sh --demo` as the test command.

- [ ] **Step 1: Add the ignored local links after validating both sources**

  Confirm both exact files are regular images, create only the intended `wallpapers` directory, and link them under the two approved stable names. Do not copy image bytes into tracked Git content.

- [ ] **Step 2: Document setup and demo commands**

  Explain the ignored local asset policy, fallback behavior, staging command, and `/etc/greetd/launch-regreet.sh --demo`. State that closing and reopening the demo reruns the selection.

- [ ] **Step 3: Run complete verification**

  Run: `bash -n install.sh greetd/etc/greetd/launch-regreet.sh tests/config-test.sh tests/install-test.sh`

  Run: `bash tests/config-test.sh`

  Run: `bash tests/install-test.sh`

  Run: `git diff --check`

  Expected: syntax checks and both suites pass, with no whitespace errors.

- [ ] **Step 4: Hand off system staging**

  Ask Wes to run `sudo ./install.sh install-system --no-activate`, then `/etc/greetd/launch-regreet.sh --demo` more than once. Do not activate greetd until he confirms the demo.
