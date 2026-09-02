#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/home/.config/hypr" "$fixture/home/.config/mise/conf.d" "$fixture/source/config/user/omarchy/bin" "$fixture/source/config/user/mise/conf.d"
cp "$root/config/user/omarchy/bin/dotfiles-toggle-dp3" "$fixture/source/config/user/omarchy/bin/"
cp "$root/config/user/mise/conf.d/omarchy-development.toml" "$fixture/source/config/user/mise/conf.d/"

export DOTFILES_TEST_ROOT="$root"
export DOTFILES_TEST_SOURCE="$fixture/source"
export DOTFILES_TEST_HOME="$fixture/home"
export ANSIBLE_CONFIG="$root/ansible/ansible.cfg"
export ANSIBLE_LOCAL_TEMP="$fixture/ansible-tmp"
export ANSIBLE_REMOTE_TEMP="$fixture/ansible-tmp"

run_role() {
    ansible-playbook "$root/tests/fixtures/omarchy-overrides.yml" -i "$root/ansible/inventories/local/hosts.yml"
}

printf '%s\n' 'hl.monitor({ output = "HDMI-A-1", mode = "2560x1080@60", position = "0x0", scale = 1 })' 'hl.monitor({ output = "DP-3", mode = "1920x1080@60", position = "2560x0", scale = 1 })' >"$fixture/home/.config/hypr/monitors.lua"
: >"$fixture/home/.config/hypr/bindings.lua"
run_role

printf '%s\n' '# changed' >>"$fixture/source/config/user/omarchy/bin/dotfiles-toggle-dp3"
printf '%s\n' '# changed' >>"$fixture/source/config/user/mise/conf.d/omarchy-development.toml"
run_role
cmp "$fixture/source/config/user/omarchy/bin/dotfiles-toggle-dp3" "$fixture/home/.local/bin/dotfiles-toggle-dp3"
cmp "$fixture/source/config/user/mise/conf.d/omarchy-development.toml" "$fixture/home/.config/mise/conf.d/omarchy-development.toml"

printf 'foreign\n' >"$fixture/home/.local/bin/dotfiles-toggle-dp3"
if run_role; then printf 'non-owned toggle was accepted\n' >&2; exit 1; fi
rm "$fixture/home/.local/bin/dotfiles-toggle-dp3"
printf 'foreign\n' >"$fixture/home/.config/mise/conf.d/omarchy-development.toml"
if run_role; then printf 'non-owned Mise overlay was accepted\n' >&2; exit 1; fi
rm "$fixture/home/.config/mise/conf.d/omarchy-development.toml"
run_role

printf '%s\n' 'hl.monitor({ output = "DP-3", mode = "1920x1080@60", position = "2560x0", scale = 2 })' >"$fixture/home/.config/hypr/monitors.lua"
if run_role; then exit 1; fi
printf '%s\n' 'hl.monitor({ output = "HDMI-A-1", mode = "2560x1080@60", position = "0x0", scale = 1 })' 'hl.monitor({ output = "DP-3", mode = "1920x1080@60" })' 'hl.monitor({ position = "2560x0", scale = 1 })' >"$fixture/home/.config/hypr/monitors.lua"
if run_role; then exit 1; fi

printf '%s\n' 'hl.monitor({ output = "HDMI-A-1", mode = "2560x1080@60", position = "0x0", scale = 1 })' 'hl.monitor({ output = "DP-3", mode = "1920x1080@60", position = "2560x0", scale = 1 })' >"$fixture/home/.config/hypr/monitors.lua"
cat >"$fixture/home/.config/hypr/monitors.lua" <<'EOF'
-- BEGIN DOTFILES OMARCHY MONITORS
hl.monitor({ output = "HDMI-A-1", mode = "2560x1080@60", position = "0x0", scale = 1 })
hl.monitor({ output = "DP-3", mode = "1920x1080@60", position = "2560x0", scale = 1 })
-- END DOTFILES OMARCHY MONITORS
hl.monitor({ output = "DP-3", mode = "1920x1080@60", position = "0x0", scale = 1 })
EOF
if run_role; then exit 1; fi
printf '%s\n' 'hl.monitor({ output = "HDMI-A-1", mode = "2560x1080@60", position = "0x0", scale = 1 })' 'hl.monitor({ output = "DP-3", mode = "1920x1080@60", position = "2560x0", scale = 1 })' >"$fixture/home/.config/hypr/monitors.lua"
cat >"$fixture/home/.config/hypr/bindings.lua" <<'EOF'
-- BEGIN DOTFILES OMARCHY BINDINGS
o.bind("SUPER + CTRL + M", "Toggle DP-3", "dotfiles-toggle-dp3")
-- END DOTFILES OMARCHY BINDINGS
o.bind("SUPER  +  CTRL  +  M", "external conflict", "other-command")
EOF
if run_role; then exit 1; fi

printf 'Omarchy overlay policy regressions: ok\n'
