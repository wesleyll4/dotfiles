#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp_root=$(mktemp -d)
trap 'rm -rf -- "$tmp_root"' EXIT

mkdir -p "$tmp_root/bin"
cat >"$tmp_root/bin/noctalia" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s %s\n' "$#" "$*" >>"${NOCTALIA_TEST_LOG:?}"

if [[ $# -eq 2 && $1 == config && $2 == validate ]]; then
        config_file="${XDG_CONFIG_HOME:?}/noctalia/config.toml"
        [[ -f "$config_file" ]] || {
            printf 'Noctalia fixture config is missing: %s\n' "$config_file" >&2
            exit 1
        }
        python - "$config_file" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as config:
    tomllib.load(config)
PY
elif [[ $# -eq 3 && $1 == config && $2 == export && $3 == merged ]]; then
        config_file="${XDG_CONFIG_HOME:?}/noctalia/config.toml"
        [[ -f "$config_file" ]] || {
            printf 'Noctalia fixture config is missing: %s\n' "$config_file" >&2
            exit 1
        }
        cat "$config_file"
else
    printf 'Unsupported fake Noctalia argv: %s\n' "$*" >&2
    exit 2
fi
EOF
chmod +x "$tmp_root/bin/noctalia"
export NOCTALIA_TEST_LOG="$tmp_root/noctalia.log"

config_source="$repo_root/config/user/desktop-shell/noctalia/config.toml"
shell_source="$repo_root/config/user/hypr/candidate/shell/noctalia/shell.lua"

[[ -f "$config_source" && -f "$shell_source" ]]
if grep -E -i 'waybar|walker|elephant|ags|hypridle|hyprlock|kitty|chromium|dolphin|screenshot' "$shell_source"; then
    printf 'Noctalia shell provider contains an external owner\n' >&2
    exit 1
fi
grep -F 'noctalia' "$shell_source" >/dev/null
if grep -F 'SUPER + CTRL + L' "$shell_source" >/dev/null; then
    printf 'Noctalia shell provider owns the external lock bind\n' >&2
    exit 1
fi

grep -F '[idle.behavior.lock]' "$config_source" >/dev/null
grep -F '[idle.behavior.lock-and-suspend]' "$config_source" >/dev/null
grep -F '[idle.behavior.screen-off]' "$config_source" >/dev/null
grep -F 'enabled = false' "$config_source" >/dev/null
grep -F 'lock_before_suspend = false' "$config_source" >/dev/null
grep -F 'enable_daemon = false' "$config_source" >/dev/null

mkdir -p "$tmp_root/config/noctalia" "$tmp_root/state/noctalia" "$tmp_root/data" "$tmp_root/cache"
cp -- "$config_source" "$tmp_root/config/noctalia/config.toml"
XDG_CONFIG_HOME="$tmp_root/config" \
XDG_STATE_HOME="$tmp_root/state" \
XDG_DATA_HOME="$tmp_root/data" \
XDG_CACHE_HOME="$tmp_root/cache" \
PATH="$tmp_root/bin:$PATH" \
    noctalia config validate

XDG_CONFIG_HOME="$tmp_root/config" \
XDG_STATE_HOME="$tmp_root/state" \
XDG_DATA_HOME="$tmp_root/data" \
XDG_CACHE_HOME="$tmp_root/cache" \
PATH="$tmp_root/bin:$PATH" \
    noctalia config export merged >"$tmp_root/merged-config.toml"
grep -Fx '2 config validate' "$NOCTALIA_TEST_LOG" >/dev/null
grep -Fx '3 config export merged' "$NOCTALIA_TEST_LOG" >/dev/null
grep -F '[bar.default]' "$tmp_root/merged-config.toml" >/dev/null
grep -F '[bar.default.monitor.DP-3]' "$tmp_root/merged-config.toml" >/dev/null
grep -F '[bar.default.monitor.HDMI-A-1]' "$tmp_root/merged-config.toml" >/dev/null
grep -F 'community_palette = "Catppuccin Mocha Blue"' "$tmp_root/merged-config.toml" >/dev/null
grep -F 'format = "%A | %d %b %H:%M"' "$tmp_root/merged-config.toml" >/dev/null
# The live configuration may legitimately exist; isolation is proven by the
# temporary XDG paths above and by the candidate checks below.

candidate="$tmp_root/candidate"
cp -a "$repo_root/config/user/hypr/candidate/." "$candidate"
cp -- "$shell_source" "$candidate/integrations/shell.lua"
Hyprland --verify-config --config "$candidate/hyprland.lua" >"$tmp_root/hyprland.out" 2>&1
grep -F 'config ok' "$tmp_root/hyprland.out" >/dev/null
! grep -R -F "$HOME" "$tmp_root" >/dev/null

materialized="$tmp_root/materialized/noctalia"
mkdir -p "$materialized"
cp -- "$config_source" "$materialized/config.toml"
first_hash=$(sha256sum "$materialized/config.toml")
cp -- "$config_source" "$materialized/config.toml"
second_hash=$(sha256sum "$materialized/config.toml")
[[ "$first_hash" == "$second_hash" ]]

printf 'ok - Noctalia provider staging, invariants, fixture, and idempotence\n'
