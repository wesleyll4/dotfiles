#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp_root=$(mktemp -d)
trap 'rm -rf -- "$tmp_root"' EXIT

expected="$repo_root/config/user/hypr/candidate/shell/current/shell.lua"
noctalia="$repo_root/config/user/hypr/candidate/shell/noctalia/shell.lua"
mkdir -p "$tmp_root/home/.config/hypr/integrations" "$tmp_root/home/.config/noctalia"

run_state() {
    local name=$1 shell_target=$2 noctalia_pid=$3 current_pid=$4 expect=$5
    local fixture="$tmp_root/$name"
    mkdir -p "$fixture/home/.config/hypr/integrations" "$fixture/home/.config/noctalia"
    cp -- "$repo_root/config/user/desktop-shell/noctalia/config.toml" "$fixture/home/.config/noctalia/config.toml"
    case "$shell_target" in
        current) ln -s -- "$expected" "$fixture/home/.config/hypr/integrations/shell.lua" ;;
        noctalia) ln -s -- "$noctalia" "$fixture/home/.config/hypr/integrations/shell.lua" ;;
        unexpected) printf 'unexpected\n' >"$fixture/home/.config/hypr/integrations/shell.lua" ;;
        none) : ;;
    esac
    local before after result
    before=$(find "$fixture/home" -type f -o -type l -print0 | sort -z | xargs -0 sha256sum 2>/dev/null || true)
    result=fail
    if [[ "$shell_target" == current && "$current_pid" == running && "$noctalia_pid" == stopped ]]; then
        result=pass
    elif [[ "$shell_target" == noctalia && "$noctalia_pid" == running && "$current_pid" == stopped ]]; then
        result=pass
    fi
    after=$(find "$fixture/home" -type f -o -type l -print0 | sort -z | xargs -0 sha256sum 2>/dev/null || true)
    [[ "$result" == "$expect" ]]
    [[ "$before" == "$after" ]]
}

run_state current-active current stopped running pass
run_state noctalia-active noctalia running stopped pass
run_state both-active current running running fail
run_state none-active none stopped stopped fail
run_state unexpected-target unexpected stopped running fail

printf 'ok - Noctalia preflight state fixtures preserve inconsistent states\n'
