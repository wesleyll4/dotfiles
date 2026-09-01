#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT

snapshot() {
    local target=$1
    if [[ -L "$target" ]]; then
        printf 'link|%s|%s|%s\n' "$(readlink "$target")" "$(stat -c '%i' "$target")" "$(stat -c '%Y' "$target")"
    elif [[ -f "$target" ]]; then
        printf 'file|%s|%s|%s\n' "$(sha256sum "$target" | awk '{print $1}')" "$(stat -c '%i' "$target")" "$(stat -c '%Y' "$target")"
    elif [[ -d "$target" ]]; then
        printf 'directory|%s|%s\n' "$(stat -c '%i' "$target")" "$(stat -c '%Y' "$target")"
    else
        printf 'absent\n'
    fi
}

run_case() {
    local scenario=$1 expected_rc=$2
    local home="$fixture/$scenario/home" target="$fixture/$scenario/home/.config/hypr/hyprland.lua"
    mkdir -p "$home"
    ANSIBLE_CONFIG="$root/ansible/ansible.cfg" ansible-playbook tests/fixtures/hyprland-preflight.yml \
        -e "dotfiles_root=$root" -e "dotfiles_home=$home" -e "prepare_fixture=true" -e "preflight_scenario=$scenario" >/dev/null
    local before after
    before=$(snapshot "$target")
    set +e
    ANSIBLE_CONFIG="$root/ansible/ansible.cfg" ansible-playbook tests/fixtures/hyprland-preflight.yml \
        -e "dotfiles_root=$root" -e "dotfiles_home=$home" -e "prepare_fixture=false" -e "preflight_scenario=$scenario" >/dev/null 2>&1
    local rc=$?
    set -e
    after=$(snapshot "$target")
    [[ "$rc" -eq "$expected_rc" ]]
    test "$before" = "$after"
}

run_case legacy 0
run_case expected 0
run_case unexpected 2
run_case regular 2
run_case directory 2
printf 'Hyprland preflight fixtures: ok\n'
