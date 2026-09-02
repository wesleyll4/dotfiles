#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/bin"

cat >"$fixture/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ $1 == monitors && $2 == all && $3 == -j ]]; then
    case ${MOCK_MONITOR_STATE:-active} in
    active) printf '[{"name":"DP-3","disabled":false}]\n' ;;
    disabled) printf '[{"name":"DP-3","disabled":true}]\n' ;;
    absent) printf '[{"name":"HDMI-A-1","disabled":false}]\n' ;;
    esac
    exit 0
fi
printf '%s\n' "$*" >"$MOCK_HYPRCTL_LOG"
EOF
chmod +x "$fixture/bin/hyprctl"

run_toggle() {
    : >"$fixture/hyprctl.log"
    MOCK_MONITOR_STATE=$1 MOCK_HYPRCTL_LOG="$fixture/hyprctl.log" \
        PATH="$fixture/bin:$PATH" \
        "$root/config/user/omarchy/bin/dotfiles-toggle-dp3"
}

run_toggle active
grep -Fx 'eval hl.monitor({ output = "DP-3", disabled = true })' "$fixture/hyprctl.log" >/dev/null

run_toggle disabled
grep -Fx 'eval hl.monitor({ output = "DP-3", disabled = false, mode = "1920x1080@60", position = "2560x0", scale = 1 })' "$fixture/hyprctl.log" >/dev/null

if run_toggle absent >/dev/null 2>&1; then
    printf 'physically absent DP-3 was accepted\n' >&2
    exit 1
fi
[[ ! -s "$fixture/hyprctl.log" ]]
printf 'DP-3 toggle states: ok\n'
