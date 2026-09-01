#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
target_home=${DOTFILES_TARGET_HOME:-${HOME:?}}
system_root=${DOTFILES_SYSTEM_ROOT:-/}
systemctl_cmd=${DOTFILES_SYSTEMCTL:-systemctl}
skip_packages=${DOTFILES_SKIP_PACKAGES:-0}
effective_uid=${DOTFILES_EFFECTIVE_UID:-${EUID:-$(id -u)}}
runuser_cmd=${DOTFILES_RUNUSER:-runuser}
greetd_source=${DOTFILES_GREETD_SOURCE:-$repo_root/greetd/etc/greetd}
backup_root=
greetd_target=

required_greetd_files=(
    config.toml
    hyprland-greeter.lua
    launch-regreet.sh
    regreet.css
    regreet.toml
    tokyo-night-city.png
)
greetd_files=("${required_greetd_files[@]}")

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

usage() {
    printf 'usage: %s {check|install-user|install-system [--no-activate|--activate --demo-tested]|rollback}\n' "$0" >&2
    exit 2
}

collect_greetd_files() {
    local source name lower
    local LC_ALL=C
    greetd_files=("${required_greetd_files[@]}")
    [[ -d "$greetd_source/wallpapers" ]] || return 0

    for source in "$greetd_source"/wallpapers/*; do
        [[ -e "$source" || -L "$source" ]] || continue
        name=${source##*/}
        lower=${name,,}
        case "$lower" in
            *.png|*.jpg|*.jpeg|*.webp) ;;
            *) continue ;;
        esac
        [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] ||
            die "unsafe local wallpaper name: $name"
        [[ -f "$source" ]] || die "local wallpaper is not a readable file: $name"
        greetd_files+=("wallpapers/$name")
    done
}

is_managed_relative() {
    local relative=$1 name lower
    case "$relative" in
        etc/greetd/config.toml|etc/greetd/hyprland-greeter.lua|etc/greetd/launch-regreet.sh|etc/greetd/regreet.css|etc/greetd/regreet.toml|etc/greetd/tokyo-night-city.png)
            return 0
            ;;
        etc/greetd/wallpapers/*)
            name=${relative##*/}
            [[ "$relative" == "etc/greetd/wallpapers/$name" ]] || return 1
            [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || return 1
            lower=${name,,}
            case "$lower" in
                *.png|*.jpg|*.jpeg|*.webp) return 0 ;;
            esac
            ;;
    esac
    return 1
}

assert_absolute_root() {
    local requested=$system_root resolved expected_greetd resolved_greetd expected_backup resolved_backup
    [[ -n "$system_root" && "$system_root" == /* ]] || die 'DOTFILES_SYSTEM_ROOT must be an absolute path'
    resolved=$(realpath -e -- "$system_root") || die 'DOTFILES_SYSTEM_ROOT does not exist'
    [[ "$requested" == "$resolved" ]] ||
        die 'DOTFILES_SYSTEM_ROOT must be canonical and must not contain symlinks or ..'
    [[ "$resolved" == "/" || "$resolved" == /tmp/* ]] ||
        die 'DOTFILES_SYSTEM_ROOT must be / or a path below /tmp'

    system_root=$resolved
    if [[ "$system_root" == / ]]; then
        backup_root=/var/lib/wes-dotfiles/backups
        greetd_target=/etc/greetd
    else
        backup_root="$system_root/var/lib/wes-dotfiles/backups"
        greetd_target="$system_root/etc/greetd"
    fi

    expected_greetd=$greetd_target
    resolved_greetd=$(realpath -m -- "$greetd_target") || die 'cannot resolve greetd target path'
    [[ "$resolved_greetd" == "$expected_greetd" ]] ||
        die 'greetd target contains a symlink or escapes DOTFILES_SYSTEM_ROOT'
    expected_backup=$backup_root
    resolved_backup=$(realpath -m -- "$backup_root") || die 'cannot resolve backup path'
    [[ "$resolved_backup" == "$expected_backup" ]] ||
        die 'backup target contains a symlink or escapes DOTFILES_SYSTEM_ROOT'
}

require_real_root() {
    if [[ "$system_root" == "/" && ${EUID:-$(id -u)} -ne 0 ]]; then
        die 'install-system and rollback require root; run with sudo'
    fi
}

verify_sources() {
    local file
    collect_greetd_files
    [[ -f "$repo_root/hypr/.config/hypr/hyprland.lua" ]] || die 'missing Hyprland Lua entrypoint'
    [[ -d "$repo_root/hypr/.config/hypr/lua" ]] || die 'missing Hyprland Lua modules'
    for file in "${greetd_files[@]}"; do
        [[ -f "$greetd_source/$file" ]] || die "missing greetd source: $file"
    done
    [[ -f "$repo_root/packages.arch" ]] || die 'missing Arch package manifest'
    [[ -f "$repo_root/scripts/validate-greetd.py" ]] || die 'missing greetd metadata validator'
}

verify_lua() {
    command -v Hyprland >/dev/null || die 'Hyprland is not installed'
    run_hyprland_verifier "$repo_root/hypr/.config/hypr/hyprland.lua" ||
        die 'desktop Hyprland Lua validation failed'
    run_hyprland_verifier "$greetd_source/hyprland-greeter.lua" ||
        die 'greeter Hyprland Lua validation failed'
}

run_hyprland_verifier() {
    local config=$1 passwd_entry account_name account_uid account_home
    if [[ "$effective_uid" != 0 ]]; then
        Hyprland --verify-config --config "$config" >/dev/null 2>&1
        return
    fi

    [[ -n ${SUDO_USER:-} && ${SUDO_USER:-root} != root && ${SUDO_UID:-} =~ ^[0-9]+$ ]] ||
        die 'Hyprland validation must run as a desktop user; invoke install-system through sudo'
    passwd_entry=$(getent passwd "$SUDO_USER") || die "cannot resolve sudo user: $SUDO_USER"
    IFS=: read -r account_name _ account_uid _ _ account_home _ <<<"$passwd_entry"
    [[ "$account_name" == "$SUDO_USER" && "$account_uid" == "$SUDO_UID" ]] ||
        die 'SUDO_USER and SUDO_UID do not identify the same account'
    [[ -d "$account_home" ]] || die "sudo user home does not exist: $account_home"

    "$runuser_cmd" --user "$account_name" -- \
        env HOME="$account_home" XDG_RUNTIME_DIR="/run/user/$account_uid" \
        Hyprland --verify-config --config "$config" >/dev/null 2>&1
}

verify_greetd_metadata() {
    command -v python >/dev/null || die 'python is required to validate greetd metadata'
    python "$repo_root/scripts/validate-greetd.py" "$greetd_source" >/dev/null ||
        die 'greetd/ReGreet metadata validation failed'
}

check() {
    verify_sources
    verify_lua
    verify_greetd_metadata
    if [[ "$skip_packages" != 1 ]]; then
        command -v pacman >/dev/null || die 'this installer targets Arch Linux (pacman not found)'
        if ! command -v regreet >/dev/null; then
            printf 'warning: regreet is not installed yet; install-system will install it\n' >&2
        fi
    fi
    printf 'Hyprland Lua and greetd sources: ok\n'
}

ensure_link() {
    local source=$1 target=$2 current
    if [[ -L "$target" ]]; then
        current=$(readlink "$target")
        [[ "$current" == "$source" ]] || die "refusing to replace symlink: $target -> $current"
        return
    fi
    [[ ! -e "$target" ]] || die "refusing to replace existing path: $target"
    ln -s -- "$source" "$target"
}

install_user() {
    check
    mkdir -p -- "$target_home/.config/hypr"
    ensure_link "$repo_root/hypr/.config/hypr/hyprland.lua" "$target_home/.config/hypr/hyprland.lua"
    ensure_link "$repo_root/hypr/.config/hypr/lua" "$target_home/.config/hypr/lua"
    printf 'user Hyprland Lua links installed\n'
}

install_packages() {
    local packages=()
    [[ "$skip_packages" == 1 ]] && return
    mapfile -t packages <"$repo_root/packages.arch"
    pacman -S --needed -- "${packages[@]}"
    command -v regreet >/dev/null || die 'regreet is unavailable after package installation'
}

make_backup() {
    local stamp backup_dir target relative file existing

    if [[ -L "$backup_root/latest" ]]; then
        existing=$(cd "$backup_root/latest" 2>/dev/null && pwd -P) ||
            die 'latest rollback backup is a broken symlink'
        [[ "$existing" == "$backup_root"/* ]] ||
            die 'latest rollback backup resolves outside the managed backup root'
        [[ -f "$existing/missing.list" ]] ||
            die 'latest rollback backup is incomplete'
        verify_deployed_state "$existing"
        for file in "${greetd_files[@]}"; do
            target="$greetd_target/$file"
            relative="etc/greetd/$file"
            if [[ -e "$existing/$relative" ]] || grep -Fxq -- "$relative" "$existing/missing.list"; then
                continue
            fi
            mkdir -p -- "$(dirname "$existing/$relative")"
            if [[ -e "$target" ]]; then
                cp -a -- "$target" "$existing/$relative"
            else
                printf '%s\n' "$relative" >>"$existing/missing.list"
            fi
        done
        printf 'preserving existing rollback backup: %s\n' "$existing"
        return
    fi
    [[ ! -e "$backup_root/latest" ]] ||
        die 'latest rollback marker exists but is not a symlink'

    stamp=$(date -u +%Y%m%dT%H%M%S.%NZ)
    backup_dir="$backup_root/$stamp"
    [[ ! -e "$backup_dir" ]] || die "backup already exists: $backup_dir"
    mkdir -p -- "$backup_dir/etc/greetd"
    : >"$backup_dir/missing.list"

    for file in "${greetd_files[@]}"; do
        target="$greetd_target/$file"
        relative="etc/greetd/$file"
        mkdir -p -- "$(dirname "$backup_dir/$relative")"
        if [[ -e "$target" || -L "$target" ]]; then
            cp -a -- "$target" "$backup_dir/$relative"
        else
            printf '%s\n' "$relative" >>"$backup_dir/missing.list"
        fi
    done

    rm -f -- "$backup_root/latest"
    ln -s -- "$stamp" "$backup_root/latest"
}

verify_deployed_state() {
    local backup=$1 expected relative target actual mode count=0
    [[ -f "$backup/deployed.sha256" ]] ||
        die 'latest rollback backup has no deployed-state manifest'
    while read -r expected relative; do
        [[ -n "$expected" && -n "$relative" ]] ||
            die 'invalid deployed-state manifest'
        is_managed_relative "$relative" ||
            die "invalid deployed target in manifest: $relative"
        target="$system_root/$relative"
        [[ -f "$target" && ! -L "$target" ]] ||
            die "refusing to overwrite changed or missing system file: $target"
        actual=$(sha256sum -- "$target")
        actual=${actual%% *}
        [[ "$actual" == "$expected" ]] ||
            die "refusing to overwrite administrator-modified file: $target"
        mode=$(stat -c '%a' -- "$target") || die "cannot read deployed file mode: $target"
        if [[ "$relative" == etc/greetd/launch-regreet.sh ]]; then
            [[ "$mode" == 755 ]] ||
                die "staged ReGreet launcher must have mode 755: $target"
        else
            [[ "$mode" == 644 ]] ||
                die "staged greetd file must have mode 644: $target"
        fi
        count=$((count + 1))
    done <"$backup/deployed.sha256"
    [[ $count -gt 0 ]] || die 'deployed-state manifest is empty'
}

is_current_greetd_relative() {
    local expected=$1 file
    for file in "${greetd_files[@]}"; do
        [[ "$expected" == "etc/greetd/$file" ]] && return 0
    done
    return 1
}

prune_obsolete_wallpapers() {
    local backup expected relative target
    backup=$(cd "$backup_root/latest" && pwd -P)
    [[ -f "$backup/deployed.sha256" ]] || return 0

    while read -r expected relative; do
        case "$relative" in
            etc/greetd/wallpapers/*)
                if ! is_current_greetd_relative "$relative"; then
                    target="$system_root/$relative"
                    printf 'removing obsolete managed wallpaper: %s\n' "$target"
                    rm -f -- "$target"
                fi
                ;;
        esac
    done <"$backup/deployed.sha256"
}

record_deployed_state() {
    local backup file target relative digest
    backup=$(cd "$backup_root/latest" && pwd -P)
    : >"$backup/deployed.sha256"
    for file in "${greetd_files[@]}"; do
        target="$greetd_target/$file"
        relative="etc/greetd/$file"
        digest=$(sha256sum -- "$target")
        digest=${digest%% *}
        printf '%s %s\n' "$digest" "$relative" >>"$backup/deployed.sha256"
    done
}

verify_sources_match_staged() {
    local file source_digest target_digest target backup relative manifest_count
    backup=$(cd "$backup_root/latest" && pwd -P)
    manifest_count=$(wc -l <"$backup/deployed.sha256")
    [[ $manifest_count -eq ${#greetd_files[@]} ]] ||
        die 'source file set changed after the demo; stage again and rerun the demo'
    for file in "${greetd_files[@]}"; do
        target="$greetd_target/$file"
        relative="etc/greetd/$file"
        grep -Eq "^[[:xdigit:]]{64} ${relative//./\\.}$" "$backup/deployed.sha256" ||
            die "source file set changed after the demo: $file; stage again and rerun the demo"
        source_digest=$(sha256sum -- "$greetd_source/$file")
        source_digest=${source_digest%% *}
        target_digest=$(sha256sum -- "$target")
        target_digest=${target_digest%% *}
        [[ "$source_digest" == "$target_digest" ]] ||
            die "source changed after the demo: $file; stage again and rerun the demo"
    done
}

install_system_files() {
    local file target mode
    mkdir -p -- "$greetd_target"
    for file in "${greetd_files[@]}"; do
        target="$greetd_target/$file"
        [[ ! -L "$target" ]] || die "refusing to overwrite symlinked system file: $target"
        mkdir -p -- "$(dirname "$target")"
        mode=0644
        [[ "$file" == launch-regreet.sh ]] && mode=0755
        install -m "$mode" -- "$greetd_source/$file" "$target"
    done
}

validate_install_targets() {
    local file target resolved
    for file in "${greetd_files[@]}"; do
        target="$greetd_target/$file"
        resolved=$(realpath -m -- "$target") || die "cannot resolve install target: $target"
        [[ "$resolved" == "$target" ]] ||
            die "greetd target contains a symlink or escapes DOTFILES_SYSTEM_ROOT: $target"
        [[ ! -L "$target" ]] || die "refusing to overwrite symlinked system file: $target"
    done
}

switch_to_greetd() {
    if ! "$systemctl_cmd" disable --now ly@tty1.service; then
        "$systemctl_cmd" enable --now ly@tty1.service ||
            die 'Ly could not be restored after its disable command failed; switch to another TTY'
        die 'Ly disable failed; Ly was started again and greetd was not activated'
    fi
    if ! "$systemctl_cmd" enable --now greetd.service; then
        printf 'greetd failed to start; restoring Ly\n' >&2
        stop_greetd_safely ||
            die 'greetd failed and could not be stopped; Ly was not started to avoid a VT conflict'
        "$systemctl_cmd" enable --now ly@tty1.service ||
            die 'greetd failed and Ly could not be restored; switch to another TTY'
        die 'greetd failed to start; Ly was restored'
    fi
    if ! "$systemctl_cmd" is-active --quiet greetd.service; then
        printf 'greetd did not remain active; restoring Ly\n' >&2
        stop_greetd_safely ||
            die 'greetd health check failed and greetd could not be stopped; Ly was not started'
        "$systemctl_cmd" enable --now ly@tty1.service ||
            die 'greetd health check failed and Ly could not be restored; switch to another TTY'
        die 'greetd health check failed; Ly was restored'
    fi
}

stop_greetd_safely() {
    if "$systemctl_cmd" disable --now greetd.service; then
        return
    fi
    "$systemctl_cmd" stop greetd.service || true
    ! "$systemctl_cmd" is-active --quiet greetd.service
}

install_system() {
    local activation=${1:---no-activate}
    local demo_ack=${2:-}
    [[ "$activation" == --activate || "$activation" == --no-activate ]] || usage
    if [[ "$activation" == --activate ]]; then
        [[ "$demo_ack" == --demo-tested ]] ||
            die 'activation requires --demo-tested after closing a successful ReGreet demo'
    else
        [[ -z "$demo_ack" ]] || usage
    fi
    assert_absolute_root
    require_real_root
    if [[ "$activation" == --activate && ! -L "$backup_root/latest" ]]; then
        die 'greetd is not staged; run install-system --no-activate and test the demo first'
    fi
    verify_sources
    verify_lua
    assert_absolute_root

    if [[ "$activation" == --activate ]]; then
        verify_greetd_metadata
        verify_deployed_state "$(cd "$backup_root/latest" && pwd -P)"
        verify_sources_match_staged
        if [[ "$skip_packages" != 1 ]]; then
            command -v regreet >/dev/null || die 'regreet is unavailable; stage the installation again'
        fi
        switch_to_greetd
        printf 'greetd installed and active; Ly remains installed for rollback\n'
        return
    fi

    install_packages
    verify_greetd_metadata
    validate_install_targets
    make_backup
    prune_obsolete_wallpapers
    install_system_files
    record_deployed_state
    if [[ "$system_root" == "/" && "$skip_packages" != 1 ]]; then
        systemd-tmpfiles --create
    fi
    printf 'greetd staged; display-manager services were not changed\n'
}

validate_rollback_backup() {
    local backup=$1 relative linked
    [[ -f "$backup/missing.list" ]] || die 'rollback backup has no missing-file manifest'
    while IFS= read -r relative; do
        [[ -n "$relative" ]] || continue
        is_managed_relative "$relative" ||
            die "invalid rollback target in manifest: $relative"
    done <"$backup/missing.list"
    linked=$(find "$backup/etc/greetd" -type l -print -quit)
    [[ -z "$linked" ]] || die "rollback backup contains a symlink: $linked"
    verify_deployed_state "$backup"
}

restore_backup() {
    local backup=$1 relative target source
    while IFS= read -r relative; do
        [[ -n "$relative" ]] || continue
        target="$system_root/$relative"
        printf 'removing newly installed file: %s\n' "$target"
        rm -f -- "$target" || return
    done <"$backup/missing.list"

    while IFS= read -r -d '' source; do
        relative=${source#"$backup/"}
        is_managed_relative "$relative" || return
        target="$system_root/$relative"
        mkdir -p -- "$(dirname "$target")" || return
        rm -f -- "$target" || return
        cp -a -- "$source" "$target" || return
    done < <(find "$backup/etc/greetd" -type f -print0)
}

snapshot_deployed_files() {
    local recovery=$1 backup=$2 expected relative source target
    mkdir -p -- "$recovery"
    while read -r expected relative; do
        source="$system_root/$relative"
        target="$recovery/$relative"
        mkdir -p -- "$(dirname "$target")" || return
        cp -a -- "$source" "$target" || return
    done <"$backup/deployed.sha256"
}

restore_deployed_snapshot() {
    local recovery=$1 source relative target
    while IFS= read -r -d '' source; do
        relative=${source#"$recovery/"}
        is_managed_relative "$relative" || return
        target="$system_root/$relative"
        mkdir -p -- "$(dirname "$target")" || return
        cp -a -- "$source" "$target" || return
    done < <(find "$recovery/etc/greetd" -type f -print0)
}

rollback() {
    local backup recovery
    assert_absolute_root
    require_real_root
    [[ -L "$backup_root/latest" ]] || die "no rollback backup found at $backup_root/latest"
    backup=$(cd "$backup_root/latest" && pwd -P)
    [[ "$backup" == "$backup_root"/* ]] || die 'rollback backup resolves outside the managed backup root'
    validate_rollback_backup "$backup"
    recovery=$(mktemp -d "$backup_root/.rollback-recovery.XXXXXXXX") ||
        die 'could not create rollback recovery snapshot'
    snapshot_deployed_files "$recovery" "$backup" ||
        die 'could not snapshot the deployed greeter before rollback'
    stop_greetd_safely ||
        die 'greetd could not be stopped; Ly was not started to avoid two display managers on one VT'
    if ! restore_backup "$backup"; then
        restore_deployed_snapshot "$recovery" ||
            die 'rollback restore failed and the deployed greeter could not be recovered; switch to another TTY'
        "$systemctl_cmd" enable --now greetd.service ||
            die 'rollback restore failed and greetd could not be restarted; switch to another TTY'
        die 'rollback restore failed; the deployed greetd configuration was recovered'
    fi
    if ! "$systemctl_cmd" enable --now ly@tty1.service; then
        restore_deployed_snapshot "$recovery" ||
            die 'Ly failed and the deployed greeter could not be recovered; switch to another TTY'
        "$systemctl_cmd" enable --now greetd.service ||
            die 'Ly failed and greetd could not be restarted; switch to another TTY'
        die 'Ly could not be started; the deployed greetd configuration was recovered'
    fi
    rm -f -- "$backup_root/latest"
    [[ "$recovery" == "$backup_root"/.rollback-recovery.* ]] ||
        die 'rollback recovery path escaped the managed backup root'
    rm -rf -- "$recovery"
    printf 'Ly restored; greetd disabled\n'
}

case ${1:-} in
    check) check ;;
    install-user) install_user ;;
    install-system) install_system "${2:-}" "${3:-}" ;;
    rollback) rollback ;;
    *) usage ;;
esac
