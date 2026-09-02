#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
profile="$root/ansible/profiles/omarchy.yml"
playbook="$root/ansible/playbooks/omarchy.yml"

for path in "$profile" "$playbook" \
    "$root/ansible/roles/omarchy_hypr_overrides/defaults/main.yml" \
    "$root/ansible/roles/omarchy_hypr_overrides/tasks/main.yml" \
    "$root/ansible/roles/omarchy_development/defaults/main.yml" \
    "$root/ansible/roles/omarchy_development/tasks/main.yml" \
    "$root/ansible/roles/omarchy_foot_overrides/defaults/main.yml" \
    "$root/ansible/roles/omarchy_foot_overrides/tasks/main.yml" \
    "$root/config/user/omarchy/foot/key-bindings.overlay.ini" \
    "$root/config/user/omarchy/bin/dotfiles-foot-scrollback-nvim" \
    "$root/config/user/omarchy/hypr/monitors.overlay.lua" \
    "$root/config/user/omarchy/hypr/bindings.overlay.lua" \
    "$root/config/user/omarchy/bin/dotfiles-toggle-dp3" \
    "$root/config/user/mise/conf.d/omarchy-development.toml"; do
    [[ -f $path ]] || {
        printf 'missing Omarchy path: %s\n' "$path" >&2
        exit 1
    }
done

grep -F 'dotfiles_profile_name: omarchy' "$profile" >/dev/null
grep -F '  - common' "$profile" >/dev/null
grep -F '  - omarchy_hypr_overrides' "$profile" >/dev/null
grep -F '  - omarchy_development' "$profile" >/dev/null
grep -F '  - omarchy_foot_overrides' "$profile" >/dev/null
! grep -Eq '^  - (shell_zsh|terminal_kitty|desktop_session_current|desktop_shell_current|desktop_actions_current|development|cli_tools)$' "$profile"

grep -Fx 'dotnet = ["8", "9", "latest"]' "$root/config/user/mise/conf.d/omarchy-development.toml" >/dev/null
grep -Fx 'python = "latest"' "$root/config/user/mise/conf.d/omarchy-development.toml" >/dev/null
! grep -Eq '^(codex|node)[[:space:]]*=' "$root/config/user/mise/conf.d/omarchy-development.toml"

! grep -Eiq 'kitty|zsh|waybar|walker|elephant|ags|astal|noctalia|yazi|unbind' \
    "$root/config/user/omarchy/hypr/monitors.overlay.lua" \
    "$root/config/user/omarchy/hypr/bindings.overlay.lua" \
    "$root/config/user/omarchy/bin/dotfiles-toggle-dp3"

grep -F 'SUPER + CTRL + M' "$root/config/user/omarchy/hypr/bindings.overlay.lua" >/dev/null
! grep -Eq 'SUPER[[:space:]]*\+[[:space:]]*(H|J|K|L|T)' "$root/config/user/omarchy/hypr/bindings.overlay.lua"
grep -F 'dotfiles-toggle-dp3' "$root/config/user/omarchy/hypr/bindings.overlay.lua" >/dev/null
printf 'Omarchy profile structure and policy: ok\n'
