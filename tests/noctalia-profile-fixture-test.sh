#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
real_home=${HOME:?}
tmp_root=$(mktemp -d)
trap 'rm -rf -- "$tmp_root"' EXIT

fixture_home="$tmp_root/home"
xdg_config="$tmp_root/xdg-config"
xdg_state="$tmp_root/xdg-state"
xdg_data="$tmp_root/xdg-data"
xdg_cache="$tmp_root/xdg-cache"
runtime="$tmp_root/runtime"
mkdir -p "$fixture_home" "$xdg_config/noctalia" "$xdg_state/noctalia" "$xdg_data" "$xdg_cache" "$runtime"

candidate="$tmp_root/hypr"
mkdir -p "$candidate/integrations"
cp -a "$repo_root/config/user/hypr/candidate/core" "$candidate/"
cp -- "$repo_root/config/user/hypr/candidate/hyprland.lua" "$candidate/"
cp -- "$repo_root/config/user/hypr/candidate/session/current/session.lua" "$candidate/integrations/session.lua"
cp -- "$repo_root/config/user/hypr/candidate/shell/noctalia/shell.lua" "$candidate/integrations/shell.lua"
cp -- "$repo_root/config/user/hypr/candidate/actions/current/apps.lua" "$candidate/integrations/apps.lua"
cp -- "$repo_root/config/user/desktop-shell/noctalia/config.toml" "$xdg_config/noctalia/config.toml"

cmp -- "$candidate/integrations/session.lua" "$repo_root/config/user/hypr/candidate/session/current/session.lua"
cmp -- "$candidate/integrations/apps.lua" "$repo_root/config/user/hypr/candidate/actions/current/apps.lua"
if grep -E -i 'waybar|walker|elephant|ags|hypridle|hyprlock|kitty|chromium|dolphin|screenshot' "$candidate/integrations/shell.lua"; then
    printf 'Noctalia shell slot contains an external provider/action\n' >&2
    exit 1
fi
! grep -E -i 'noctalia|waybar|walker|elephant|ags|hypridle|hyprlock' "$candidate/integrations/apps.lua" >/dev/null
grep -F 'SUPER + CTRL + L' "$candidate/integrations/session.lua" >/dev/null

XDG_CONFIG_HOME="$xdg_config" \
XDG_STATE_HOME="$xdg_state" \
XDG_DATA_HOME="$xdg_data" \
XDG_CACHE_HOME="$xdg_cache" \
    noctalia config validate
XDG_CONFIG_HOME="$xdg_config" \
XDG_STATE_HOME="$xdg_state" \
XDG_DATA_HOME="$xdg_data" \
XDG_CACHE_HOME="$xdg_cache" \
    noctalia msg --help >"$tmp_root/ipc-help"
for command_name in 'panel-toggle launcher' 'panel-toggle clipboard' 'panel-toggle control-center' 'panel-toggle session'; do
    grep -F "${command_name%% *}" "$tmp_root/ipc-help" >/dev/null
done
noctalia msg session --help >"$tmp_root/session-help"
grep -E 'lock|suspend|logout|reboot|shutdown' "$tmp_root/session-help" >/dev/null

Hyprland --verify-config --config "$candidate/hyprland.lua" >"$tmp_root/hyprland.out" 2>&1
grep -F 'config ok' "$tmp_root/hyprland.out" >/dev/null

materialized="$tmp_root/materialized"
materialize() {
    mkdir -p "$materialized/hypr/core" "$materialized/hypr/integrations" "$materialized/config/noctalia"
    cp -a "$repo_root/config/user/hypr/candidate/core/." "$materialized/hypr/core/"
    cp -- "$repo_root/config/user/hypr/candidate/hyprland.lua" "$materialized/hypr/hyprland.lua"
    cp -- "$repo_root/config/user/hypr/candidate/session/current/session.lua" "$materialized/hypr/integrations/session.lua"
    cp -- "$repo_root/config/user/hypr/candidate/shell/noctalia/shell.lua" "$materialized/hypr/integrations/shell.lua"
    cp -- "$repo_root/config/user/hypr/candidate/actions/current/apps.lua" "$materialized/hypr/integrations/apps.lua"
    cp -- "$repo_root/config/user/desktop-shell/noctalia/config.toml" "$materialized/config/noctalia/config.toml"
}
materialize
first_hash=$(find "$materialized" -type f -print0 | sort -z | xargs -0 sha256sum)
materialize
second_hash=$(find "$materialized" -type f -print0 | sort -z | xargs -0 sha256sum)
[[ "$first_hash" == "$second_hash" ]]

! grep -R -F "$real_home" "$tmp_root" >/dev/null
# The live session may have Noctalia state; isolation is established by the
# temporary HOME/XDG roots used for every fixture operation.

printf 'ok - Noctalia complete temporary profile fixture, IPC, ownership, and idempotence\n'
