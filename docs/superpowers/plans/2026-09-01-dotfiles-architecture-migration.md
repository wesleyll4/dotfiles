# Dotfiles Architecture Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans task-by-task. Check off each item only after its validation passes.

**Goal:** Introduce the approved Ansible-centered architecture without changing current desktop behavior until a complete Hyprland candidate is validated and cut over once.

**Architecture:** bootstrap is the only root-level entrypoint. It computes checkout and target-home paths, exports the repository Ansible configuration, and invokes profile playbooks. Profiles load explicit policy vars; roles execute state. Config sources are staged before runtime cutover. Hyprland core loads three fixed provider slots: session.lua, shell.lua, and apps.lua.

**Tech Stack:** Bash, Ansible builtin modules, YAML, Hyprland Lua, existing shell tests, Git.

**Spec:** docs/superpowers/specs/2026-09-01-dotfiles-architecture-design.md

## Global Constraints

- Preserve existing Kitty, Zsh, Waybar, Walker, Hyprlock, Hypridle, Elephant, AGS, greetd/ReGreet, and application behavior.
- Do not add a second platform, package catalog, AUR helper, Flatpak manager, provider replacement, or gaming role without reviewed evidence.
- config/ is the versioned source of truth. Ansible never writes into the checkout.
- Profiles compose and select policy. Roles execute. Host vars are machine facts. Platform group vars are platform differences.
- desktop_hyprland contains only compositor-neutral behavior and requires session.lua, shell.lua, apps.lua. It names no application, shell/UI, lock, or idle provider.
- desktop_session_current owns Hyprlock, Hypridle, and lock behavior. desktop_shell_current owns Waybar, Walker, Elephant, AGS/Astal, launcher, clipboard, menus, and Walker session/power actions. desktop_actions_current owns terminal, browser, file-manager, and screenshot actions.
- Only the three named runtime slots are managed. Unknown files under the integrations directory are never removed.
- User configuration links accept only absent target, expected source, or explicit approved legacy source. All other states fail untouched.
- Every source migration is stage, validate in fixture, cut over, then later compatibility cleanup. No cleanup is combined with cutover.
- Greetd/ReGreet remains under the existing guarded installer through this plan.

## Execution Context Contract

bootstrap calculates these values once:

~~~text
dotfiles_root = canonical absolute directory containing bootstrap
dotfiles_home = canonical absolute DOTFILES_TARGET_HOME when supplied,
                otherwise canonical absolute HOME of invoking desktop user
~~~

bootstrap exports:

~~~bash
export ANSIBLE_CONFIG="$dotfiles_root/ansible/ansible.cfg"
~~~

It invokes Ansible with absolute playbook path and explicit variables:

~~~bash
ansible-playbook "$dotfiles_root/ansible/playbooks/$profile.yml" \
  -e "dotfiles_root=$dotfiles_root" \
  -e "dotfiles_home=$dotfiles_home"
~~~

ansible/ansible.cfg contains only repository-relative project defaults:

~~~ini
[defaults]
inventory = ./inventories/local/hosts.yml
roles_path = ./roles
interpreter_python = auto_silent
retry_files_enabled = False
~~~

Because ANSIBLE_CONFIG is absolute, Ansible resolves inventory and roles from the checked-out ansible directory regardless of caller current working directory. Every play begins with assertions that dotfiles_root and dotfiles_home are absolute existing directories. Roles use dotfiles_home for all user targets and never use ansible_env.HOME.

Fixture commands inject:

~~~text
dotfiles_root = canonical repository root
dotfiles_home = temporary fixture HOME
~~~

Fixture tests assert every created path is below dotfiles_home and fail if a task reports a target below the real HOME.

## Variable Loading Contract

The inventory has a real platform group:

~~~yaml
all:
  children:
    local:
      children:
        platform_arch:
          hosts:
            main_desktop:
              ansible_connection: local
~~~

ansible/inventories/local/group_vars/platform_arch.yml is loaded through platform_arch membership. Profile policy is explicit:

~~~yaml
# desktop.yml
vars_files:
  - ../profiles/desktop.yml
~~~

ansible/profiles/desktop.yml and ansible/profiles/dev.yml define dotfiles_profile_name, role-selection policy, application action commands, and selected slot sources. They contain no tasks.

## Task 1: Review and checkpoint current state

**Type:** safety checkpoint.

**Files:** review all current tracked/untracked paths; do not create architecture state first.

- [x] Record git status, diff stat, and untracked paths.
- [x] Scan secret candidates without printing values.
- [x] Run bash syntax, tests/install-test.sh, and tests/config-test.sh.
- [x] Commit only reviewed current state as chore: checkpoint current desktop configuration.
- [x] Confirm clean worktree and record commit hash.

**Validation:** all existing tests pass.

**Rollback:** later work uses git revert only; never hard-reset this checkpoint.

## Task 2: Create bootstrap, Ansible skeleton, and explicit context tests

**Type:** structural; no runtime configuration or package action.

**Files:**

- Create: bootstrap
- Create: ansible/ansible.cfg
- Create: ansible/requirements.yml
- Create: ansible/inventories/local/hosts.yml
- Create: ansible/inventories/local/group_vars/all.yml
- Create: ansible/profiles/desktop.yml
- Create: ansible/profiles/dev.yml
- Create: ansible/playbooks/desktop.yml
- Create: ansible/playbooks/dev.yml
- Create: ansible/playbooks/verify.yml
- Create: ansible/roles/common/defaults/main.yml
- Create: ansible/roles/common/tasks/main.yml
- Create: tests/ansible-structure-test.sh
- Create: tests/bootstrap-context-test.sh
- Create: secrets/README.md
- Create: docs/inspirations/README.md
- Modify: .gitignore, README.md

- [x] Write structure test for every required file and bootstrap executable.
- [x] Write bootstrap-context test that calls bootstrap from a temporary unrelated current directory with DOTFILES_BOOTSTRAP_DRY_RUN=1 and asserts output contains the canonical ANSIBLE_CONFIG, absolute playbook, dotfiles_root, and fixture dotfiles_home.
- [x] Implement bootstrap help, desktop/dev selection, --check, and dry run. Real mode may install only Ansible when ansible-playbook is absent.
- [x] Define empty requirements lists: collections: [] and roles: [].
- [x] Implement common preflight assertions for absolute dotfiles_root and dotfiles_home.
- [x] Document ignored local secret input policy and inspirations fields; add only matching ignore patterns.
- [x] Run bash syntax, structure test, and bootstrap context test.
- [x] Commit: feat: add Ansible bootstrap and skeleton.

**Validation:** dry run makes no package, HOME, or service change.

**Rollback:** revert structural commit.

## Task 3: Install Ansible once and prove bootstrap/profile discovery

**Type:** minimal prerequisite; installs Ansible only.

**Files:**

- Create: tests/ansible-vars-test.sh
- Create: tests/fixtures/assert-desktop-vars.yml
- Create: tests/fixtures/assert-dev-vars.yml
- Modify: README.md

- [x] Confirm bootstrap dry-run lists only Ansible and selected no-op playbook.
- [x] Run bootstrap desktop --check.
- [x] Fixture plays load the same profile vars_files as real profile plays and assert expected profile name, dotfiles_root, and fixture dotfiles_home. Platform vars and package lists are intentionally absent until Task 4.
- [x] Run ansible-vars-test.sh from an unrelated current directory; it verifies ANSIBLE_CONFIG, inventory, roles path, explicit profile vars, and fixture HOME only.
- [x] Run the public entrypoint check mode through `./bootstrap <profile> --check`; run `ansible-playbook --syntax-check` directly with the same explicit `ANSIBLE_CONFIG`, inventory, roles path, and profile `vars_files` context. Syntax check is intentionally not a bootstrap option.
- [x] Commit: docs: verify Ansible bootstrap workflow.

**Validation:** configuration, inventory, roles path, profile vars, and fixture HOME resolve through bootstrap contract.

**Rollback:** revert documentation/tests; leave Ansible installed.

## Task 4: Add minimal Arch package boundary

**Type:** structural; no declared packages are installed.

**Files:**

- Create: ansible/roles/platform_arch/tasks/main.yml
- Create: ansible/roles/packages/defaults/main.yml
- Create: ansible/roles/packages/tasks/main.yml
- Create: ansible/roles/packages/tasks/backend_arch.yml
- Modify: ansible/inventories/local/group_vars/platform_arch.yml
- Modify: profile playbooks and structure test
- Modify: tests/ansible-vars-test.sh and profile-var fixtures
- Create: tests/fixtures/assert-package-backend.yml

- [x] Define empty literal lists for cli tools, development, terminal, shell, Hyprland core, session, shell UI, and actions.
- [x] Create platform_arch.yml with dotfiles_platform_name: arch and the empty literal lists, then extend ansible-vars-test.sh fixtures to assert the platform name and list-shaped package vars.
- [x] Implement packages interface package_names as list; backend uses ansible.builtin.package with state present only for nonempty list.
- [x] Include platform_arch before capability roles and assert current package manager is Arch-compatible.
- [x] Add check-mode fixture with package_names containing bash to prove builtin package backend selection without transaction.
- [x] Backend selection passed with ansible.builtin.package; no external collection is required.
- [x] Commit: feat: add Arch package role boundary.

**Validation:** platform group vars are proven available by the extended fixtures; empty real lists cause no package action; backend fixture selects builtin backend.

**Rollback:** revert.

## Task 5: Implement expected/legacy symlink adoption

**Type:** structural safety mechanism.

**Files:**

- Create: ansible/roles/common/tasks/adopt_link.yml
- Create: tests/config-link-test.sh
- Create: tests/fixtures/link-adoption.yml
- Modify: common role and README.md

**Interface:**

~~~yaml
managed_link_expected_source: /absolute/new/source
managed_link_legacy_sources: [/absolute/old/source]
managed_link_target: /absolute/runtime/target
~~~

- [x] Implement canonical source validation within dotfiles_root.
- [x] Create missing target link.
- [x] Preserve matching expected link unchanged.
- [x] Relink only matching approved legacy symlink after recording it and removing that verified symlink.
- [x] Fail untouched for unexpected symlink, regular file, or directory.
- [x] Fixture covers expected source, two approved legacy sources, unexpected symlink, file, and directory.
- [x] Commit: feat: add safe expected and legacy link adoption.

**Validation:** fixture proves no generic force behavior and no write outside fixture dotfiles_home.

**Rollback:** restore recorded legacy link; revert.

## Task 6: Stage CLI-tool config sources

**Type:** source staging; no live target change.

**Files:**

- Create: config/user/starship/starship.toml
- Create: config/user/mise/config.toml
- Create: config/user/yazi/keymap.toml
- Create: ansible/roles/cli_tools/defaults/main.yml
- Create: ansible/roles/cli_tools/tasks/main.yml
- Modify: tests/config-link-test.sh
- Create: tests/fixtures/cli-tools-link-adoption.yml
- Modify: tests/ansible-structure-test.sh

- [x] Copy current source files with cp -a; compare staged/new content with old source.
- [x] Keep old starship, mise, yazi source paths valid.
- [x] Add only fixture mappings with expected new sources and explicit legacy paths.
- [x] Validate fixture twice without real HOME.
- [x] Commit: feat: stage CLI tool config sources.

**Validation:** byte comparisons and fixture idempotence pass.

**Rollback:** revert staging commit; no live link changed.

## Task 7: Cut over CLI-tool runtime links

**Type:** functional user-config cutover.

**Files:**

- Modify: cli_tools tasks, desktop/dev profile composition, README.md

- [x] Record current live targets and preflight each with expected/legacy contract.
- [x] Apply cli_tools role with dotfiles_home real HOME.
- [x] Verify Starship, Mise, Yazi links and behavior.
- [x] Run profile twice and require no changes.
- [x] Commit: feat: cut over CLI tool runtime links.

**Validation:** all runtime links target staged source; second run unchanged.

**Rollback:** restore recorded links and revert cutover.

## Task 8: Remove CLI compatibility sources

**Type:** cleanup.

**Files:** remove only legacy CLI source paths proven unused.

- [x] Assert all live targets point to expected new source.
- [x] Search tracked config for each old path.
- [x] Remove one old component source per cleanup commit.
- [x] Re-run CLI fixture and real profile after each removal.

**Validation:** no active target breaks.

**Rollback:** revert the relevant cleanup commit.

## Task 9: Stage and cut over Zsh

**Type:** staged then functional migration; no terminal dependency.

**Files:**

- Create: config/user/zsh/.zshrc
- Create: ansible/roles/shell_zsh/defaults/main.yml
- Create: ansible/roles/shell_zsh/tasks/main.yml
- Modify: profiles, link fixture, README.md

- [x] Stage copy and compare with old source; commit feat: stage current Zsh source.
- [x] Extend fixture for expected and legacy .zshrc link.
- [x] Preflight/cut over only ~/.zshrc via legacy contract; run zsh -n and fresh-shell smoke test; commit feat: cut over current Zsh runtime link.
- [x] After target and tracked-reference checks, remove old source in chore: remove Zsh compatibility source.

**Validation:** aliases, Starship, Zoxide, Mise, and Yazi function remain.

**Rollback:** restore recorded ~/.zshrc link then revert cutover; cleanup is separately reversible.

## Task 10: Stage and cut over Kitty

**Type:** staged then functional migration; no Zsh dependency. Kitty keeps its existing
real runtime directory; migration is performed entry-by-entry.

**Files:**

- Create: config/user/kitty/
- Create: ansible/roles/terminal_kitty/defaults/main.yml
- Create: ansible/roles/terminal_kitty/tasks/main.yml
- Modify: profiles, link fixture, README.md
- Remove later: kitty/.config/kitty/

- [ ] Inventory every entry currently present in ~/.config/kitty, including backup artifacts.
- [ ] Compare all managed sources byte-for-byte; preserve every source, including kitty.conf.bak.
- [ ] Stage copy and commit feat: stage current Kitty source without changing the runtime directory.
- [ ] Define explicit per-entry mappings; each managed runtime entry must be a symlink to an approved legacy source.
- [ ] Extend fixtures for per-entry expected/legacy adoption while rejecting regular files, directories, and unapproved symlinks.
- [ ] Preflight all runtime entries; abort before mutation on any unexpected state.
- [ ] Relink only approved entries to config/user/kitty/<entry>; never remove or replace ~/.config/kitty.
- [ ] Confirm the installed Kitty version; start a controlled fresh instance with `kitty --config <candidate-kitty.conf>`, verify its behavior, then cut over and open a new Kitty through the normal path; run two profile executions with changed=0 on the second; commit feat: cut over current Kitty runtime links.
- [ ] After no live/versioned references remain, remove old sources in a separate cleanup commit.

**Validation:** the installed Kitty version accepts the candidate config, a controlled fresh instance starts and exits cleanly, and a normal post-cutover Kitty instance retains current shell behavior.

**Rollback:** restore each recorded per-entry legacy link; the runtime directory itself is never replaced.

## Task 11: Add development boundary and reviewed package inventory

**Type:** structural/discovery; package application requires separate approval.

**Files:**

- Create: ansible/roles/development/defaults/main.yml
- Create: ansible/roles/development/tasks/main.yml
- Create: docs/decisions/current-tools.md
- Create: docs/decisions/development-and-gaming-scope.md
- Create: docs/package-inventory-arch.md
- Modify: profiles and platform_arch.yml

- [ ] Document current/default and undecided status of Kitty, Zsh, Waybar, Walker.
- [ ] Development consumes development_packages empty list.
- [ ] Record repository command candidates and pacman ownership one approved command at a time.
- [ ] Separate native, AUR, Flatpak, and unknown sources.
- [ ] Present inventory for explicit approval before list population.
- [ ] Commit structural boundary. Package-list population and real package run occur only after explicit review in a separate commit.

**Validation:** development check mode has no package action before reviewed lists exist.

**Rollback:** revert; do not uninstall packages automatically.

## Task 12: Stage complete neutral Hyprland core candidate

**Type:** staging; no live Hyprland target changes.

**Files:**

- Create: config/user/hypr/candidate/core/
- Create: config/user/hypr/candidate/integrations/noop.lua
- Create: ansible/inventories/local/host_vars/main_desktop.yml
- Create: ansible/roles/desktop_hyprland/defaults/main.yml
- Create: ansible/roles/desktop_hyprland/tasks/stage.yml
- Modify: tests/config-test.sh

- [ ] Copy current Lua sources to candidate paths without removing old sources.
- [ ] Render monitor module from host facts matching current HDMI-A-1 and DP-3 geometry.
- [ ] Retain only compositor options, inputs, monitors, workspaces, neutral rules, and neutral focus/move/resize/workspace binds.
- [ ] Require session.lua, shell.lua, apps.lua; no candidate core string names application, lock, idle, or shell provider.
- [ ] Validate temporary candidate core with all slots set to no-op.
- [ ] Commit: feat: stage Hyprland core candidate.

**Validation:** fixture Hyprland verification passes; live configuration untouched.

**Rollback:** revert staging commit.

## Task 13: Stage session candidate

**Type:** staging; no live Hyprland target changes.

**Files:**

- Create: config/user/hypr/candidate/session/current/
- Create: ansible/roles/desktop_session_current/defaults/main.yml
- Create: ansible/roles/desktop_session_current/tasks/main.yml
- Modify: tests/config-test.sh

- [ ] Copy Hypridle/Hyprlock sources byte-for-byte; keep old source valid.
- [ ] Create session.lua containing only existing idle startup and lock binding behavior.
- [ ] Test session owns lock/idle while core does not.
- [ ] Commit: feat: stage current desktop session candidate.

**Validation:** session candidate parses in temporary runtime.

**Rollback:** revert; no live target changed.

## Task 14: Stage shell and actions candidates

**Type:** staging; no live Hyprland target changes.

**Files:**

- Create: config/user/hypr/candidate/shell/current/
- Create: config/user/hypr/candidate/actions/current/
- Create: ansible/roles/desktop_shell_current/defaults/main.yml
- Create: ansible/roles/desktop_shell_current/tasks/main.yml
- Create: ansible/roles/desktop_actions_current/defaults/main.yml
- Create: ansible/roles/desktop_actions_current/tasks/main.yml
- Modify: ansible/profiles/desktop.yml
- Modify: tests/config-test.sh

- [ ] Copy UI configs/scripts to candidates while retaining old source paths.
- [ ] shell.lua owns current Waybar/Walker/Elephant/AGS, launcher, clipboard, menus, and Walker power/session behavior.
- [ ] apps.lua owns terminal, browser, file-manager, screenshot actions and binds. Their current commands are profile policy vars.
- [ ] Test each action has exactly one owner and core has none.
- [ ] Commit: feat: stage current shell and actions candidates.

**Validation:** no live configuration target changes.

**Rollback:** revert staging commit.

## Task 15: Assemble and validate full temporary Hyprland runtime

**Type:** fixture validation; no live target changes.

**Files:**

- Create: tests/hyprland-candidate-test.sh
- Create: tests/fixtures/hyprland-candidate.yml
- Modify: ansible/playbooks/verify.yml
- Modify: tests/config-test.sh

- [ ] Create temporary XDG_CONFIG_HOME and temporary dotfiles_home.
- [ ] Materialize candidate core, rendered monitors, current session config, current shell config, current actions, and three selected slots.
- [ ] Assert every fixture output is below temporary dotfiles_home.
- [ ] Run Hyprland --verify-config against temporary entrypoint.
- [ ] Run fixture twice and assert second run has no changes.
- [ ] Commit: test: validate complete Hyprland candidate.

**Validation:** complete candidate passes before any live path changes.

**Rollback:** revert test-only commit.

## Task 16: Perform one guarded live Hyprland cutover

**Type:** functional cutover; core, session, shell, actions become live together.

**Files:**

- Create: ansible/playbooks/hyprland-cutover.yml
- Create: ansible/roles/desktop_hyprland/tasks/cutover.yml
- Modify: desktop.yml, README.md

- [ ] Require passing Task-15 fixture and record every live target/link.
- [ ] Preflight every target and each named slot; permit only absent, expected, or approved legacy source.
- [ ] Use one Ansible block/rescue: materialize complete runtime and session.lua, shell.lua, apps.lua; switch live entrypoint last; do not reload inside block.
- [ ] Rescue restores every recorded old link target upon any task failure.
- [ ] After block success, verify live entrypoint, perform one controlled reload/restart, and smoke-test current desktop behavior.
- [ ] Run desktop profile second time and require no changes.
- [ ] Commit: feat: cut over Hyprland configuration architecture.

**Validation:** no incomplete core is activated; all providers are valid before one reload.

**Rollback:** run documented rollback play from TTY, verify legacy entrypoint, then revert cutover commit.

## Task 17: Remove desktop compatibility sources and add idempotence suite

**Type:** cleanup plus validation; no intended behavior change.

**Files:**

- Remove: only legacy desktop source paths proven unused
- Create: tests/ansible-idempotence-test.sh
- Modify: verify.yml, README.md
- Create: docs/architecture.md

- [ ] Verify every live target points expected source and tracked config has no old-source reference.
- [ ] Remove one component legacy source in each cleanup commit; never combine with live cutover.
- [ ] Fixture test runs profile twice with temporary dotfiles_home, empty package lists, candidate slots, and asserts changed=0 second run.
- [ ] Run complete suite: context, vars, link, candidate, idempotence, existing config, existing install tests.
- [ ] Commit cleanup components separately; commit validation/doc changes as test: verify profile idempotence.

**Validation:** links remain valid and no fixture touches real HOME.

**Rollback:** revert individual cleanup or validation commit.

## Task 18: Preserve greetd/ReGreet boundary

**Type:** documentation/regression preservation; no system migration.

**Files:**

- Create: docs/decisions/greetd-regreet-transition.md
- Modify: README.md
- Modify: tests/install-test.sh only for a currently untested documented guarantee

- [ ] Document current installer guarantees: system-root validation, non-symlink deployment, backups, drift detection, staged demo, Ly restoration, rollback recovery.
- [ ] Add only a missing regression fixture; do not modify install.sh behavior.
- [ ] Run existing greetd/config tests without sudo or real service switch.
- [ ] Commit: docs: preserve greetd migration boundary.

**Validation:** existing installer remains the owner and test suite passes.

**Rollback:** revert documentation/test-only commit.

## Deferred Work

This plan does not implement Omarchy, CachyOS, another distribution, Quickshell, Noctalia, omarchy-shell, Ghostty, Fish, external package collection, AUR/Flatpak management, gaming role, large CI, or Ansible greetd/ReGreet migration.
