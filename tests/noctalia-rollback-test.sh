#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT

runtime="$fixture/runtime"
mkdir -p "$runtime/integrations" "$runtime/core" "$runtime/config/noctalia" "$runtime/processes"
cp -a "$root/config/user/hypr/candidate/core/." "$runtime/core/"
cp -- "$root/config/user/hypr/candidate/hyprland.lua" "$runtime/hyprland.lua"
cp -- "$root/config/user/hypr/candidate/session/current/session.lua" "$runtime/integrations/session.lua"
cp -- "$root/config/user/hypr/candidate/actions/current/apps.lua" "$runtime/integrations/apps.lua"
cp -- "$root/config/user/desktop-shell/noctalia/config.toml" "$runtime/config/noctalia/config.toml"

current="$root/config/user/hypr/candidate/shell/current/shell.lua"
noctalia="$root/config/user/hypr/candidate/shell/noctalia/shell.lua"
slot="$runtime/integrations/shell.lua"
tmp_slot="$runtime/integrations/.shell.lua.new"

ln -s -- "$current" "$slot"

atomic_switch() {
    local source=$1
    ln -s -- "$source" "$tmp_slot"
    test -e "$slot"
    mv -T -- "$tmp_slot" "$slot"
    test -e "$slot"
}

atomic_switch "$current"
Hyprland --verify-config --config "$runtime/hyprland.lua" >"$fixture/current-verify" 2>&1
grep -F 'config ok' "$fixture/current-verify" >/dev/null
apps_hash=$(sha256sum "$runtime/integrations/apps.lua")
session_hash=$(sha256sum "$runtime/integrations/session.lua")

printf 'waybar\nwalker\nelephant\nags\n' >"$runtime/processes/current"
process_snapshot=$(sha256sum "$runtime/processes/current")
atomic_switch "$noctalia"
test "$(readlink "$slot")" = "$noctalia"
printf 'noctalia\n' >"$runtime/processes/noctalia"
rm -f -- "$runtime/processes/current"
# Simulated post-switch failure; the atomic slot remains present.
test -e "$slot"
Hyprland --verify-config --config "$runtime/hyprland.lua" >"$fixture/noctalia-verify" 2>&1
grep -F 'config ok' "$fixture/noctalia-verify" >/dev/null

atomic_switch "$current"
test "$(readlink "$slot")" = "$current"
printf 'waybar\nwalker\nelephant\nags\n' >"$runtime/processes/current"
rm -f -- "$runtime/processes/noctalia"
[[ "$(sha256sum "$runtime/processes/current")" == "$process_snapshot" ]]
[[ "$(sha256sum "$runtime/integrations/apps.lua")" == "$apps_hash" ]]
[[ "$(sha256sum "$runtime/integrations/session.lua")" == "$session_hash" ]]
Hyprland --verify-config --config "$runtime/hyprland.lua" >"$fixture/rollback-verify" 2>&1
grep -F 'config ok' "$fixture/rollback-verify" >/dev/null
test -e "$slot"
[[ ! -e "$tmp_slot" ]]
[[ ! -e "$runtime/processes/noctalia" ]]
[[ -f "$runtime/processes/current" ]]

rollback_actions() {
    local config=$1 stopped=$2 switched=$3 started=$4
    [[ "$started" == true ]] && printf 'stop-noctalia\n'
    [[ "$switched" == true ]] && printf 'restore-shell\n'
    [[ "$stopped" == true ]] && printf 'restart-snapshot-processes\n'
    [[ "$config" == true ]] && printf 'remove-new-config\n'
    return 0
}

for failure in before-materialize during-materialize after-materialize before-stop after-stop after-switch after-start; do
    case "$failure" in
        before-materialize) expected='';;
        during-materialize) expected='';;
        after-materialize) expected='remove-new-config';;
        before-stop) expected='remove-new-config';;
        after-stop) expected=$'restart-snapshot-processes\nremove-new-config';;
        after-switch) expected=$'restore-shell\nrestart-snapshot-processes\nremove-new-config';;
        after-start) expected=$'stop-noctalia\nrestore-shell\nrestart-snapshot-processes\nremove-new-config';;
    esac
    case "$failure" in
        before-materialize) actual=$(rollback_actions false false false false);;
        during-materialize) actual=$(rollback_actions false false false false);;
        after-materialize|before-stop) actual=$(rollback_actions true false false false);;
        after-stop) actual=$(rollback_actions true true false false);;
        after-switch) actual=$(rollback_actions true true true false);;
        after-start) actual=$(rollback_actions true true true true);;
    esac
    [[ "$actual" == "$expected" ]]
done

printf 'ok - atomic Noctalia switch, simulated failure, rollback, and ownership preservation\n'
