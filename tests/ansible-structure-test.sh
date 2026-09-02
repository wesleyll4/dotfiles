#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)

for path in \
    bootstrap \
    ansible/ansible.cfg \
    ansible/requirements.yml \
    ansible/inventories/local/hosts.yml \
    ansible/inventories/local/group_vars/all.yml \
    ansible/inventories/local/group_vars/platform_arch.yml \
    ansible/profiles/desktop.yml \
    ansible/profiles/dev.yml \
    ansible/playbooks/desktop.yml \
    ansible/playbooks/dev.yml \
    ansible/playbooks/verify.yml \
    ansible/roles/common/defaults/main.yml \
    ansible/roles/common/tasks/main.yml \
    ansible/roles/common/tasks/adopt_link.yml \
    ansible/roles/cli_tools/defaults/main.yml \
    ansible/roles/cli_tools/tasks/main.yml \
    ansible/roles/shell_zsh/defaults/main.yml \
    ansible/roles/shell_zsh/tasks/main.yml \
    ansible/roles/terminal_kitty/defaults/main.yml \
    ansible/roles/terminal_kitty/tasks/main.yml \
    ansible/roles/development/defaults/main.yml \
    ansible/roles/development/tasks/main.yml \
    ansible/roles/desktop_hyprland/defaults/main.yml \
    ansible/roles/desktop_hyprland/tasks/stage.yml \
    ansible/roles/desktop_session_current/defaults/main.yml \
    ansible/roles/desktop_session_current/tasks/main.yml \
    ansible/roles/desktop_shell_current/defaults/main.yml \
    ansible/roles/desktop_shell_current/tasks/main.yml \
    ansible/roles/desktop_actions_current/defaults/main.yml \
    ansible/roles/desktop_actions_current/tasks/main.yml \
    ansible/inventories/local/host_vars/main_desktop.yml \
    tests/fixtures/stage-hyprland-candidate.yml \
    tests/fixtures/stage-session-candidate.yml \
    tests/fixtures/stage-shell-actions-candidates.yml \
    tests/fixtures/hyprland-candidate.yml \
    tests/hyprland-candidate-test.sh \
    docs/decisions/current-tools.md \
    docs/decisions/development-and-gaming-scope.md \
    docs/package-inventory-arch.md \
    ansible/roles/platform_arch/tasks/main.yml \
    ansible/profiles/omarchy.yml \
    ansible/playbooks/omarchy.yml \
    ansible/roles/omarchy_hypr_overrides/defaults/main.yml \
    ansible/roles/omarchy_hypr_overrides/tasks/main.yml \
    ansible/roles/omarchy_development/defaults/main.yml \
    ansible/roles/omarchy_development/tasks/main.yml \
    config/user/omarchy/hypr/monitors.overlay.lua \
    config/user/omarchy/hypr/bindings.overlay.lua \
    config/user/omarchy/bin/dotfiles-toggle-dp3 \
    config/user/mise/conf.d/omarchy-development.toml \
    tests/fixtures/omarchy-overrides.yml \
    tests/omarchy-profile-test.sh \
    tests/omarchy-toggle-test.sh \
    tests/omarchy-overlay-policy-test.sh \
    tests/fixtures/omarchy-foot.yml \
    tests/omarchy-foot-test.sh \
    ansible/roles/packages/defaults/main.yml \
    ansible/roles/packages/tasks/main.yml \
    ansible/roles/packages/tasks/backend_arch.yml \
    secrets/README.md \
    docs/inspirations/README.md; do
    [[ -f "$root/$path" ]] || {
        printf 'missing required architecture path: %s\n' "$path" >&2
        exit 1
    }
done

[[ -x "$root/bootstrap" ]] || {
    printf 'bootstrap is not executable\n' >&2
    exit 1
}

[[ -x "$root/tests/config-link-test.sh" ]] || {
    printf 'config-link-test.sh is not executable\n' >&2
    exit 1
}

"$root/bootstrap" --help | grep -F 'desktop|desktop-noctalia|dev|omarchy' >/dev/null
