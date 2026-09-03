#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT

source_dir="$fixture/source"
process_home="$fixture/process-home"
dotfiles_home="$fixture/dotfiles-home"
target_dir="$dotfiles_home/.config/omarchy/backgrounds/Catppuccin"
state_link="$dotfiles_home/.local/state/omarchy/current/background"
external_state="$process_home/.local/state/omarchy/current/background"
native_bin="$fixture/bin"
native_log="$fixture/native.log"
unmanaged="$dotfiles_home/.config/omarchy/shell.json"
mkdir -p "$source_dir" "$process_home" "$dotfiles_home" "$target_dir" "$native_bin" "$(dirname "$state_link")" "$(dirname "$unmanaged")"
printf 'paper plane bytes\n' >"$source_dir/paper-plane.jpg"
printf 'elf prison bytes\n' >"$source_dir/elf-prison.jpg"
printf 'native shell config\n' >"$unmanaged"

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
export PATH="$native_bin:$PATH"
export HOME="$process_home"

run_role() {
    ansible-playbook "$root/tests/fixtures/omarchy-wallpapers.yml" \
        -i "$root/ansible/inventories/local/hosts.yml"
}

if ! run_role >"$fixture/first-run.log" 2>&1; then
    cat "$fixture/first-run.log" >&2
    exit 1
fi
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

run_role >/dev/null
[[ "$(readlink -f -- "$state_link")" == "$(realpath -- "$target_dir/paper-plane.jpg")" ]]
[[ $(wc -l <"$native_log") -eq $native_calls_before ]]
cmp -- "$fixture/unmanaged.before" "$unmanaged"

run_role >/dev/null
[[ "$(readlink -f -- "$state_link")" == "$(realpath -- "$target_dir/paper-plane.jpg")" ]]
[[ $(wc -l <"$native_log") -eq $native_calls_before ]]
cmp -- "$fixture/unmanaged.before" "$unmanaged"

printf '%s\n' 'Omarchy wallpaper collection fixture: ok'
