#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
fixture_home="$fixture/home"
runtime="$fixture_home/candidate-runtime"
mkdir -p "$fixture_home"

run_fixture() {
    ANSIBLE_CONFIG="$root/ansible/ansible.cfg" \
        ansible-playbook "$root/tests/fixtures/hyprland-candidate.yml" \
        -e "dotfiles_root=$root" \
        -e "dotfiles_home=$fixture_home"
}

run_fixture >/tmp/hyprland-candidate-first.log 2>&1
XDG_CONFIG_HOME="$fixture_home/.config" HOME="$fixture_home" \
    Hyprland --verify-config --config "$runtime/hyprland.lua" \
    >/tmp/hyprland-candidate-verify.log 2>&1
grep -F 'config ok' /tmp/hyprland-candidate-verify.log >/dev/null

for slot in session shell apps; do
    [[ "$(realpath -e -- "$runtime/integrations/$slot.lua")" == "$runtime/integrations/$slot.lua" ]]
done
[[ "$(realpath -e -- "$fixture_home/.config/hypr")" == "$fixture_home/.config/hypr" ]]
[[ "$(realpath -e -- "$fixture_home/.config/waybar")" == "$fixture_home/.config/waybar" ]]
[[ "$(realpath -e -- "$fixture_home/.config/walker")" == "$fixture_home/.config/walker" ]]
[[ "$(realpath -e -- "$fixture_home/.config/elephant")" == "$fixture_home/.config/elephant" ]]
[[ "$(realpath -e -- "$fixture_home")" != "$(realpath -e -- "$HOME")" ]]
while IFS= read -r -d '' path; do
    resolved=$(realpath -e -- "$path")
    [[ "$resolved" == "$fixture_home"/* || "$resolved" == "$fixture_home" ]]
done < <(find "$fixture_home" \( -type f -o -type l \) -print0)

second=$(mktemp)
run_fixture >"$second" 2>&1
grep -E 'main_desktop[[:space:]]*: ok=.*changed=0.*failed=0' "$second" >/dev/null
rm -f /tmp/hyprland-candidate-first.log /tmp/hyprland-candidate-verify.log "$second"
printf 'complete Hyprland candidate: ok\n'
