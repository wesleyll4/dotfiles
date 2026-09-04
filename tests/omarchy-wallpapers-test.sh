#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT

source_dir="$fixture/source"
process_home="$fixture/process-home"
dotfiles_home="$fixture/dotfiles-home"
target_dir="$dotfiles_home/.config/omarchy/backgrounds/catppuccin"
state_link="$dotfiles_home/.local/state/omarchy/current/background"
external_state="$process_home/.local/state/omarchy/current/background"
native_bin="$fixture/bin"
native_log="$fixture/native.log"
next_log="$fixture/native-next.log"
systemctl_log="$fixture/systemctl.log"
systemctl_state="$fixture/systemctl.state"
check_log="$fixture/check-run.log"
post_apply_check_log="$fixture/post-apply-check-run.log"
systemd_user_dir="$dotfiles_home/.config/systemd/user"
service_file="$systemd_user_dir/dotfiles-omarchy-wallpaper-rotation.service"
timer_file="$systemd_user_dir/dotfiles-omarchy-wallpaper-rotation.timer"
unmanaged="$dotfiles_home/.config/omarchy/shell.json"
mkdir -p "$source_dir" "$process_home" "$dotfiles_home" "$target_dir" "$native_bin" "$(dirname "$state_link")" "$(dirname "$unmanaged")"
printf 'paper plane bytes\n' >"$source_dir/paper-plane.jpg"
printf 'elf prison bytes\n' >"$source_dir/elf-prison.jpg"
printf 'native shell config\n' >"$unmanaged"
printf 'disabled\ninactive\n' >"$systemctl_state"

cat >"$native_bin/omarchy-theme-bg-set" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
: "${DOTFILES_WALLPAPER_TEST_STATE:?DOTFILES_WALLPAPER_TEST_STATE is required by the native seam}"
current_link="$HOME/.local/state/omarchy/current/background"
[[ "$DOTFILES_WALLPAPER_TEST_STATE" == "$current_link" ]] || {
    printf 'native seam state mismatch: expected=%s actual=%s\n' \
        "$DOTFILES_WALLPAPER_TEST_STATE" "$current_link" >&2
    exit 1
}
mkdir -p "$(dirname "$current_link")"
ln -sfn -- "$(realpath -- "$1")" "$current_link"
printf 'HOME=%s path=%s\n' "$HOME" "$1" >>"$OMARCHY_WALLPAPER_TEST_LOG"
EOF
chmod 0755 "$native_bin/omarchy-theme-bg-set"

cat >"$native_bin/omarchy-theme-bg-next" <<'EOF'
#!/usr/bin/env bash
printf 'omarchy-theme-bg-next\n' >>"$OMARCHY_WALLPAPER_TEST_NEXT_LOG"
EOF
chmod 0755 "$native_bin/omarchy-theme-bg-next"

cat >"$native_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$OMARCHY_WALLPAPER_TEST_SYSTEMCTL_LOG"
enabled_state=$(sed -n '1p' "$OMARCHY_WALLPAPER_TEST_SYSTEMCTL_STATE")
active_state=$(sed -n '2p' "$OMARCHY_WALLPAPER_TEST_SYSTEMCTL_STATE")
case " $* " in
    *" is-enabled "*)
        if [[ "$enabled_state" == enabled ]]; then
            printf 'enabled\n'
            exit 0
        fi
        printf 'disabled\n'
        exit 1
        ;;
    *" is-active "*)
        if [[ "$active_state" == active ]]; then
            printf 'active\n'
            exit 0
        fi
        printf 'inactive\n'
        exit 3
        ;;
    *" show "*)
        if [[ -e "$OMARCHY_WALLPAPER_TEST_TIMER_FILE" ]]; then
            printf 'LoadState=loaded\nActiveState=%s\n' "$active_state"
        else
            printf 'LoadState=not-found\n'
        fi
        ;;
    *" enable "*) printf 'enabled\n%s\n' "$active_state" >"$OMARCHY_WALLPAPER_TEST_SYSTEMCTL_STATE" ;;
    *" start "*) printf '%s\nactive\n' "$enabled_state" >"$OMARCHY_WALLPAPER_TEST_SYSTEMCTL_STATE" ;;
esac
EOF
chmod 0755 "$native_bin/systemctl"

export ANSIBLE_CONFIG="$root/ansible/ansible.cfg"
export ANSIBLE_LOCAL_TEMP="$fixture/ansible-tmp"
export ANSIBLE_REMOTE_TEMP="$fixture/ansible-tmp"
export DOTFILES_TEST_ROOT="$root"
export DOTFILES_TEST_HOME="$dotfiles_home"
export DOTFILES_WALLPAPER_TEST_SOURCE="$source_dir"
export DOTFILES_WALLPAPER_TEST_TARGET="$target_dir"
export DOTFILES_WALLPAPER_TEST_STATE="$state_link"
export DOTFILES_WALLPAPER_TEST_DEFAULT="elf-prison.jpg"
export OMARCHY_WALLPAPER_TEST_LOG="$native_log"
export OMARCHY_WALLPAPER_TEST_NEXT_LOG="$next_log"
export OMARCHY_WALLPAPER_TEST_SYSTEMCTL_LOG="$systemctl_log"
export OMARCHY_WALLPAPER_TEST_SYSTEMCTL_STATE="$systemctl_state"
export OMARCHY_WALLPAPER_TEST_TIMER_FILE="$timer_file"
export PATH="$native_bin:$PATH"
export HOME="$process_home"

if ! "$native_bin/systemctl" --user show "$timer_file" | grep -Fx 'LoadState=not-found' >/dev/null; then
    printf '%s\n' 'fake systemctl show contract missing LoadState=not-found' >&2
    exit 1
fi

run_role() {
    ansible-playbook "$root/tests/fixtures/omarchy-wallpapers.yml" \
        -i "$root/ansible/inventories/local/hosts.yml" "$@"
}

if ! run_role --check >"$check_log" 2>&1; then
    cat "$check_log" >&2
    exit 1
fi
grep -F -- 'TASK [omarchy_wallpapers : Materialize the Omarchy wallpaper rotation service]' "$check_log" >/dev/null
grep -F -- 'TASK [omarchy_wallpapers : Materialize the Omarchy wallpaper rotation timer]' "$check_log" >/dev/null
grep -A1 -F -- 'TASK [omarchy_wallpapers : Materialize the Omarchy wallpaper rotation service]' "$check_log" |
    grep -F -- 'changed: [main_desktop]' >/dev/null
grep -A1 -F -- 'TASK [omarchy_wallpapers : Materialize the Omarchy wallpaper rotation timer]' "$check_log" |
    grep -F -- 'changed: [main_desktop]' >/dev/null
[[ ! -e "$service_file" ]]
[[ ! -e "$timer_file" ]]
if grep -F -- 'daemon-reload' "$systemctl_log" >/dev/null; then
    printf '%s\n' 'check mode unexpectedly reloaded the user systemd manager' >&2
    exit 1
fi
if grep -F -- 'enable dotfiles-omarchy-wallpaper-rotation.timer' "$systemctl_log" >/dev/null; then
    printf '%s\n' 'check mode unexpectedly enabled wallpaper timer' >&2
    exit 1
fi
if grep -F -- 'start dotfiles-omarchy-wallpaper-rotation.timer' "$systemctl_log" >/dev/null; then
    printf '%s\n' 'check mode unexpectedly started wallpaper timer' >&2
    exit 1
fi

if ! run_role >"$fixture/first-run.log" 2>&1; then
    cat "$fixture/first-run.log" >&2
    exit 1
fi
grep -Fx 'ExecStart=/usr/share/omarchy/bin/omarchy-theme-bg-next' "$service_file" >/dev/null
grep -Fx 'OnUnitActiveSec=15min' "$timer_file" >/dev/null
grep -Fx 'WantedBy=timers.target' "$timer_file" >/dev/null
grep -F -- '--user' "$systemctl_log" >/dev/null
grep -F -- 'enable dotfiles-omarchy-wallpaper-rotation.timer' "$systemctl_log" >/dev/null
grep -F -- 'start dotfiles-omarchy-wallpaper-rotation.timer' "$systemctl_log" >/dev/null
[[ $(grep -Fc -- 'enable dotfiles-omarchy-wallpaper-rotation.timer' "$systemctl_log") -eq 1 ]]
[[ $(grep -Fc -- 'start dotfiles-omarchy-wallpaper-rotation.timer' "$systemctl_log") -eq 1 ]]
[[ ! -e "$next_log" ]]
if [[ -e "$external_state" ]]; then
    printf 'RED: native seam received process HOME instead of dotfiles_home\n' >&2
    exit 1
fi
[[ -f "$target_dir/paper-plane.jpg" ]]
[[ -f "$target_dir/elf-prison.jpg" ]]
[[ "$(readlink -f -- "$state_link")" == "$(realpath -- "$target_dir/elf-prison.jpg")" ]]
grep -Fx "HOME=$dotfiles_home path=$target_dir/elf-prison.jpg" "$native_log" >/dev/null

printf 'unmanaged shell config\n' >"$unmanaged"
ln -sfn -- "$(realpath -- "$target_dir/paper-plane.jpg")" "$state_link"
cp -- "$unmanaged" "$fixture/unmanaged.before"
native_calls_before=$(wc -l <"$native_log")
service_checksum_before=$(sha256sum "$service_file")
timer_checksum_before=$(sha256sum "$timer_file")

run_role >/dev/null
[[ "$(readlink -f -- "$state_link")" == "$(realpath -- "$target_dir/paper-plane.jpg")" ]]
[[ $(wc -l <"$native_log") -eq $native_calls_before ]]
[[ $(grep -Fc -- 'enable dotfiles-omarchy-wallpaper-rotation.timer' "$systemctl_log") -eq 1 ]]
[[ $(grep -Fc -- 'start dotfiles-omarchy-wallpaper-rotation.timer' "$systemctl_log") -eq 1 ]]
cmp -- "$fixture/unmanaged.before" "$unmanaged"
[[ "$(sha256sum "$service_file")" == "$service_checksum_before" ]]
[[ "$(sha256sum "$timer_file")" == "$timer_checksum_before" ]]

run_role >/dev/null
[[ "$(readlink -f -- "$state_link")" == "$(realpath -- "$target_dir/paper-plane.jpg")" ]]
[[ $(wc -l <"$native_log") -eq $native_calls_before ]]
cmp -- "$fixture/unmanaged.before" "$unmanaged"
[[ "$(sha256sum "$service_file")" == "$service_checksum_before" ]]
[[ "$(sha256sum "$timer_file")" == "$timer_checksum_before" ]]

if ! run_role --check >"$post_apply_check_log" 2>&1; then
    cat "$post_apply_check_log" >&2
    exit 1
fi
[[ -e "$service_file" ]]
[[ -e "$timer_file" ]]
[[ "$(readlink -f -- "$state_link")" == "$(realpath -- "$target_dir/paper-plane.jpg")" ]]
[[ $(wc -l <"$native_log") -eq $native_calls_before ]]
grep -E '^main_desktop[[:space:]]+: ok=[0-9]+[[:space:]]+changed=0[[:space:]]' "$post_apply_check_log" >/dev/null
[[ $(grep -Fc -- 'enable dotfiles-omarchy-wallpaper-rotation.timer' "$systemctl_log") -eq 1 ]]
[[ $(grep -Fc -- 'start dotfiles-omarchy-wallpaper-rotation.timer' "$systemctl_log") -eq 1 ]]
cmp -- "$fixture/unmanaged.before" "$unmanaged"
[[ "$(sha256sum "$service_file")" == "$service_checksum_before" ]]
[[ "$(sha256sum "$timer_file")" == "$timer_checksum_before" ]]

printf '%s\n' 'Omarchy wallpaper collection fixture: ok'
