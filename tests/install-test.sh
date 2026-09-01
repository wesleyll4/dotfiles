#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
installer="$repo_root/install.sh"
tmp_roots=()

cleanup() {
    local path
    for path in "${tmp_roots[@]}"; do
        rm -rf -- "$path"
    done
}
trap cleanup EXIT

new_fixture() {
    FIXTURE=$(mktemp -d)
    tmp_roots+=("$FIXTURE")
    mkdir -p "$FIXTURE/home/.config/hypr" "$FIXTURE/system/etc/greetd" "$FIXTURE/bin"
cat >"$FIXTURE/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${DOTFILES_SYSTEMCTL_LOG:?}"
if [[ ${DOTFILES_SYSTEMCTL_FAIL_ON:-} == "$*" ]]; then
    exit 1
fi
if [[ $* == 'disable --now greetd.service' && -n ${DOTFILES_EXPECT_DEPLOYED_ON_DISABLE:-} ]]; then
    grep -F '[default_session]' "$DOTFILES_EXPECT_DEPLOYED_ON_DISABLE" >/dev/null
fi
EOF
    chmod +x "$FIXTURE/bin/systemctl"
    cat >"$FIXTURE/bin/runuser" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${DOTFILES_RUNUSER_LOG:?}"
[[ $1 == --user ]]
shift 2
[[ $1 == -- ]]
shift
exec "$@"
EOF
    chmod +x "$FIXTURE/bin/runuser"
}

run_installer() {
    DOTFILES_TARGET_HOME="$FIXTURE/home" \
    DOTFILES_SYSTEM_ROOT="${TEST_SYSTEM_ROOT:-$FIXTURE/system}" \
    DOTFILES_GREETD_SOURCE="${TEST_GREETD_SOURCE:-$repo_root/greetd/etc/greetd}" \
    DOTFILES_SYSTEMCTL="$FIXTURE/bin/systemctl" \
    DOTFILES_SYSTEMCTL_LOG="$FIXTURE/systemctl.log" \
    DOTFILES_RUNUSER_LOG="$FIXTURE/runuser.log" \
    DOTFILES_EXPECT_DEPLOYED_ON_DISABLE="${DOTFILES_EXPECT_DEPLOYED_ON_DISABLE:-}" \
    DOTFILES_SKIP_PACKAGES=1 \
        "$installer" "$@"
}

stage_and_activate() {
    run_installer install-system || return
    run_installer install-system --activate --demo-tested
}

make_isolated_greetd_source() {
    TEST_GREETD_SOURCE="$FIXTURE/source"
    mkdir -p "$TEST_GREETD_SOURCE"
    cp -a "$repo_root/greetd/etc/greetd/." "$TEST_GREETD_SOURCE/"
    rm -rf -- "$TEST_GREETD_SOURCE/wallpapers"
    mkdir -p "$TEST_GREETD_SOURCE/wallpapers"
}

assert_symlink_to() {
    local path=$1 expected=$2 actual
    [[ -L "$path" ]] || { printf 'expected symlink: %s\n' "$path" >&2; return 1; }
    actual=$(readlink "$path")
    [[ "$actual" == "$expected" ]] || {
        printf 'wrong symlink target: %s (expected %s)\n' "$actual" "$expected" >&2
        return 1
    }
}

test_check_is_read_only() {
    new_fixture
    run_installer check >"$FIXTURE/check.out" || return
    grep -F 'Hyprland Lua' "$FIXTURE/check.out" >/dev/null || return
    [[ ! -e "$FIXTURE/systemctl.log" ]] || return
    [[ ! -e "$FIXTURE/home/.config/hypr/hyprland.lua" ]] || return
}

test_root_check_validates_hyprland_as_sudo_user() {
    new_fixture
    DOTFILES_EFFECTIVE_UID=0 \
    SUDO_USER="$(id -un)" \
    SUDO_UID="$(id -u)" \
    DOTFILES_RUNUSER="$FIXTURE/bin/runuser" \
        run_installer check >/dev/null || return
    grep -F -- "--user $(id -un) -- env" "$FIXTURE/runuser.log" >/dev/null || return
    grep -F 'Hyprland --verify-config' "$FIXTURE/runuser.log" >/dev/null || return
}

test_install_user_links_lua_entrypoint() {
    new_fixture
    run_installer install-user || return
    assert_symlink_to \
        "$FIXTURE/home/.config/hypr/hyprland.lua" \
        "$repo_root/hypr/.config/hypr/hyprland.lua"
    assert_symlink_to \
        "$FIXTURE/home/.config/hypr/lua" \
        "$repo_root/hypr/.config/hypr/lua"
}

test_install_user_refuses_unknown_conflict() {
    new_fixture
    printf 'mine\n' >"$FIXTURE/home/.config/hypr/hyprland.lua"
    if run_installer install-user >"$FIXTURE/conflict.out" 2>&1; then
        printf 'install-user unexpectedly replaced a conflict\n' >&2
        return 1
    fi
    grep -F 'refusing to replace' "$FIXTURE/conflict.out" >/dev/null || return
    grep -Fx 'mine' "$FIXTURE/home/.config/hypr/hyprland.lua" >/dev/null || return
}

test_install_system_backs_up_and_switches_services() {
    new_fixture
    printf 'old\n' >"$FIXTURE/system/etc/greetd/config.toml"
    stage_and_activate || return
    grep -F '[default_session]' "$FIXTURE/system/etc/greetd/config.toml" >/dev/null || return
    grep -Fx 'old' "$FIXTURE/system/var/lib/wes-dotfiles/backups/latest/etc/greetd/config.toml" >/dev/null || return
    grep -Fx 'disable --now ly@tty1.service' "$FIXTURE/systemctl.log" >/dev/null || return
    grep -Fx 'enable --now greetd.service' "$FIXTURE/systemctl.log" >/dev/null || return
}

test_install_system_is_idempotent_and_keeps_original_backup() {
    new_fixture
    printf 'original config\n' >"$FIXTURE/system/etc/greetd/config.toml"

    stage_and_activate || return
    local first_backup
    first_backup=$(readlink "$FIXTURE/system/var/lib/wes-dotfiles/backups/latest")

    run_installer install-system --activate --demo-tested || return
    local second_backup
    second_backup=$(readlink "$FIXTURE/system/var/lib/wes-dotfiles/backups/latest")

    [[ "$first_backup" == "$second_backup" ]] || return
    grep -Fx 'original config' \
        "$FIXTURE/system/var/lib/wes-dotfiles/backups/latest/etc/greetd/config.toml" >/dev/null || return
}

test_install_system_reenables_ly_when_greetd_fails() {
    new_fixture
    run_installer install-system || return
    if DOTFILES_SYSTEMCTL_FAIL_ON='enable --now greetd.service' run_installer install-system --activate --demo-tested; then
        printf 'install-system unexpectedly succeeded after greetd failure\n' >&2
        return 1
    fi
    tail -n 1 "$FIXTURE/systemctl.log" | grep -Fx 'enable --now ly@tty1.service' >/dev/null || return
}

test_install_system_can_stage_without_switching_services() {
    new_fixture
    run_installer install-system || return
    [[ -f "$FIXTURE/system/etc/greetd/regreet.toml" ]] || return
    [[ -x "$FIXTURE/system/etc/greetd/launch-regreet.sh" ]] || return
    [[ ! -e "$FIXTURE/systemctl.log" ]] || return
}

test_install_system_stages_optional_wallpaper_as_regular_file() {
    new_fixture
    make_isolated_greetd_source
    printf 'local wallpaper\n' >"$TEST_GREETD_SOURCE/wallpapers/monochrome.png"

    run_installer install-system || return

    local deployed="$FIXTURE/system/etc/greetd/wallpapers/monochrome.png"
    [[ -f "$deployed" && ! -L "$deployed" ]] || return
    grep -Fx 'local wallpaper' "$deployed" >/dev/null
}

test_install_system_rejects_symlinked_wallpaper_destination() {
    new_fixture
    make_isolated_greetd_source
    mkdir -p "$FIXTURE/system/etc/greetd/wallpapers"
    printf 'local wallpaper\n' >"$TEST_GREETD_SOURCE/wallpapers/monochrome.png"
    printf 'outside\n' >"$FIXTURE/outside-wallpaper"
    ln -s "$FIXTURE/outside-wallpaper" \
        "$FIXTURE/system/etc/greetd/wallpapers/monochrome.png"

    if run_installer install-system; then
        printf 'install-system accepted a symlinked wallpaper destination\n' >&2
        return 1
    fi
    grep -Fx 'outside' "$FIXTURE/outside-wallpaper" >/dev/null || return
    [[ ! -e "$FIXTURE/system/var/lib/wes-dotfiles/backups/latest" ]]
}

test_activate_refuses_wallpaper_source_set_changed_after_demo() {
    new_fixture
    make_isolated_greetd_source
    printf 'local wallpaper\n' >"$TEST_GREETD_SOURCE/wallpapers/monochrome.png"
    run_installer install-system || return
    rm -f -- "$TEST_GREETD_SOURCE/wallpapers/monochrome.png"

    if run_installer install-system --activate --demo-tested; then
        printf 'activation accepted a changed wallpaper source set\n' >&2
        return 1
    fi
    [[ ! -e "$FIXTURE/systemctl.log" ]]
}

test_rollback_restores_optional_wallpaper() {
    new_fixture
    make_isolated_greetd_source
    mkdir -p "$FIXTURE/system/etc/greetd/wallpapers"
    printf 'new wallpaper\n' >"$TEST_GREETD_SOURCE/wallpapers/elf-prison.jpg"
    printf 'old wallpaper\n' >"$FIXTURE/system/etc/greetd/wallpapers/elf-prison.jpg"

    stage_and_activate || return
    grep -Fx 'new wallpaper' \
        "$FIXTURE/system/etc/greetd/wallpapers/elf-prison.jpg" >/dev/null || return
    run_installer rollback || return
    grep -Fx 'old wallpaper' \
        "$FIXTURE/system/etc/greetd/wallpapers/elf-prison.jpg" >/dev/null
}

test_install_system_ignores_non_image_wallpaper_file() {
    new_fixture
    make_isolated_greetd_source
    printf 'not an image\n' >"$TEST_GREETD_SOURCE/wallpapers/notes.txt"

    run_installer install-system || return
    [[ ! -e "$FIXTURE/system/etc/greetd/wallpapers/notes.txt" ]]
}

test_restage_removes_obsolete_managed_wallpaper() {
    new_fixture
    make_isolated_greetd_source
    printf 'old selection\n' >"$TEST_GREETD_SOURCE/wallpapers/obsolete.png"
    run_installer install-system || return
    [[ -f "$FIXTURE/system/etc/greetd/wallpapers/obsolete.png" ]] || return

    rm -f -- "$TEST_GREETD_SOURCE/wallpapers/obsolete.png"
    run_installer install-system || return

    [[ ! -e "$FIXTURE/system/etc/greetd/wallpapers/obsolete.png" ]] || {
        printf 'restaging left an obsolete managed wallpaper deployed\n' >&2
        return 1
    }
    if grep -F 'etc/greetd/wallpapers/obsolete.png' \
        "$FIXTURE/system/var/lib/wes-dotfiles/backups/latest/deployed.sha256" >/dev/null; then
        printf 'restaging kept an obsolete wallpaper in the deployed manifest\n' >&2
        return 1
    fi
}

test_activate_refuses_non_executable_staged_launcher() {
    new_fixture
    run_installer install-system || return
    chmod 0644 "$FIXTURE/system/etc/greetd/launch-regreet.sh"

    if run_installer install-system --activate --demo-tested; then
        printf 'activation accepted a non-executable staged launcher\n' >&2
        return 1
    fi
    [[ ! -e "$FIXTURE/systemctl.log" ]]
}

test_rollback_restores_files_and_ly() {
    new_fixture
    printf 'old\n' >"$FIXTURE/system/etc/greetd/config.toml"
    stage_and_activate || return
    DOTFILES_EXPECT_DEPLOYED_ON_DISABLE="$FIXTURE/system/etc/greetd/config.toml" run_installer rollback || return
    grep -Fx 'old' "$FIXTURE/system/etc/greetd/config.toml" >/dev/null || return
    tail -n 2 "$FIXTURE/systemctl.log" | grep -Fx 'disable --now greetd.service' >/dev/null || return
    tail -n 2 "$FIXTURE/systemctl.log" | grep -Fx 'enable --now ly@tty1.service' >/dev/null || return
}

test_install_system_rejects_noncanonical_root() {
    new_fixture
    local escaped_root="$FIXTURE/system/.."
    if TEST_SYSTEM_ROOT="$escaped_root" run_installer install-system; then
        printf 'install-system accepted a root containing ..\n' >&2
        return 1
    fi
    [[ ! -e "$FIXTURE/etc/greetd/config.toml" ]] || return
}

test_install_system_rejects_symlink_root() {
    new_fixture
    mkdir -p "$FIXTURE/outside"
    ln -s "$FIXTURE/outside" "$FIXTURE/root-link"
    if TEST_SYSTEM_ROOT="$FIXTURE/root-link" run_installer install-system; then
        printf 'install-system accepted a symlink root\n' >&2
        return 1
    fi
    [[ ! -e "$FIXTURE/outside/etc/greetd/config.toml" ]] || return
}

test_install_system_rejects_symlinked_backup_parent() {
    new_fixture
    mkdir -p "$FIXTURE/outside"
    ln -s "$FIXTURE/outside" "$FIXTURE/system/var"
    if run_installer install-system; then
        printf 'install-system accepted a symlinked backup parent\n' >&2
        return 1
    fi
    [[ ! -e "$FIXTURE/outside/lib/wes-dotfiles" ]] || return
}

test_install_system_rejects_symlinked_destination_file() {
    new_fixture
    printf 'outside\n' >"$FIXTURE/outside-config"
    ln -s "$FIXTURE/outside-config" "$FIXTURE/system/etc/greetd/config.toml"
    if run_installer install-system; then
        printf 'install-system accepted a symlinked destination file\n' >&2
        return 1
    fi
    grep -Fx 'outside' "$FIXTURE/outside-config" >/dev/null || return
    [[ ! -e "$FIXTURE/system/var/lib/wes-dotfiles/backups/latest" ]] || return
}

test_reinstall_refuses_destination_drift() {
    new_fixture
    run_installer install-system || return
    printf 'administrator edit\n' >"$FIXTURE/system/etc/greetd/config.toml"
    if run_installer install-system; then
        printf 'reinstall overwrote destination drift\n' >&2
        return 1
    fi
    grep -Fx 'administrator edit' "$FIXTURE/system/etc/greetd/config.toml" >/dev/null || return
}

test_reinstall_after_rollback_creates_fresh_backup() {
    new_fixture
    printf 'first original\n' >"$FIXTURE/system/etc/greetd/config.toml"
    stage_and_activate || return
    run_installer rollback || return
    printf 'second original\n' >"$FIXTURE/system/etc/greetd/config.toml"
    run_installer install-system || return
    grep -Fx 'second original' \
        "$FIXTURE/system/var/lib/wes-dotfiles/backups/latest/etc/greetd/config.toml" >/dev/null || return
}

test_install_system_recovers_when_disabling_ly_fails() {
    new_fixture
    run_installer install-system || return
    if DOTFILES_SYSTEMCTL_FAIL_ON='disable --now ly@tty1.service' run_installer install-system --activate --demo-tested; then
        printf 'install-system unexpectedly succeeded after Ly disable failure\n' >&2
        return 1
    fi
    tail -n 1 "$FIXTURE/systemctl.log" | grep -Fx 'enable --now ly@tty1.service' >/dev/null || return
}

test_install_system_recovers_when_greetd_health_check_fails() {
    new_fixture
    run_installer install-system || return
    if DOTFILES_SYSTEMCTL_FAIL_ON='is-active --quiet greetd.service' run_installer install-system --activate --demo-tested; then
        printf 'install-system unexpectedly succeeded after greetd health-check failure\n' >&2
        return 1
    fi
    tail -n 1 "$FIXTURE/systemctl.log" | grep -Fx 'enable --now ly@tty1.service' >/dev/null || return
}

test_rollback_does_not_start_ly_when_greetd_wont_stop() {
    new_fixture
    stage_and_activate || return
    if DOTFILES_SYSTEMCTL_FAIL_ON='disable --now greetd.service' run_installer rollback; then
        printf 'rollback unexpectedly succeeded after greetd disable failure\n' >&2
        return 1
    fi
    if grep -Fx 'enable --now ly@tty1.service' "$FIXTURE/systemctl.log" >/dev/null; then
        printf 'rollback started Ly while greetd could still be active\n' >&2
        return 1
    fi
    grep -F '[default_session]' "$FIXTURE/system/etc/greetd/config.toml" >/dev/null || return
}

test_rollback_recovers_greetd_when_ly_wont_start() {
    new_fixture
    stage_and_activate || return
    if DOTFILES_SYSTEMCTL_FAIL_ON='enable --now ly@tty1.service' run_installer rollback; then
        printf 'rollback unexpectedly succeeded when Ly would not start\n' >&2
        return 1
    fi
    grep -F '[default_session]' "$FIXTURE/system/etc/greetd/config.toml" >/dev/null || return
    tail -n 1 "$FIXTURE/systemctl.log" | grep -Fx 'enable --now greetd.service' >/dev/null || return
}

test_activate_requires_staging_and_demo_acknowledgment() {
    new_fixture
    if run_installer install-system --activate --demo-tested; then
        printf 'activation unexpectedly succeeded without staging\n' >&2
        return 1
    fi
    run_installer install-system || return
    if run_installer install-system --activate; then
        printf 'activation unexpectedly succeeded without demo acknowledgment\n' >&2
        return 1
    fi
    [[ ! -e "$FIXTURE/systemctl.log" ]] || return
}

test_activate_refuses_sources_changed_after_demo() {
    new_fixture
    make_isolated_greetd_source
    run_installer install-system || return
    printf '\n/* changed after demo */\n' >>"$TEST_GREETD_SOURCE/regreet.css"
    if run_installer install-system --activate --demo-tested; then
        printf 'activation accepted sources changed after the demo\n' >&2
        return 1
    fi
    [[ ! -e "$FIXTURE/systemctl.log" ]] || return
}

main() {
    local test_name failures=0
    for test_name in \
        test_check_is_read_only \
        test_root_check_validates_hyprland_as_sudo_user \
        test_install_user_links_lua_entrypoint \
        test_install_user_refuses_unknown_conflict \
        test_install_system_backs_up_and_switches_services \
        test_install_system_is_idempotent_and_keeps_original_backup \
        test_install_system_reenables_ly_when_greetd_fails \
        test_install_system_can_stage_without_switching_services \
        test_install_system_stages_optional_wallpaper_as_regular_file \
        test_install_system_rejects_symlinked_wallpaper_destination \
        test_activate_refuses_wallpaper_source_set_changed_after_demo \
        test_rollback_restores_optional_wallpaper \
        test_install_system_ignores_non_image_wallpaper_file \
        test_restage_removes_obsolete_managed_wallpaper \
        test_activate_refuses_non_executable_staged_launcher \
        test_rollback_restores_files_and_ly \
        test_install_system_rejects_noncanonical_root \
        test_install_system_rejects_symlink_root \
        test_install_system_rejects_symlinked_backup_parent \
        test_install_system_rejects_symlinked_destination_file \
        test_reinstall_refuses_destination_drift \
        test_reinstall_after_rollback_creates_fresh_backup \
        test_install_system_recovers_when_disabling_ly_fails \
        test_install_system_recovers_when_greetd_health_check_fails \
        test_rollback_does_not_start_ly_when_greetd_wont_stop \
        test_rollback_recovers_greetd_when_ly_wont_start \
        test_activate_requires_staging_and_demo_acknowledgment \
        test_activate_refuses_sources_changed_after_demo; do
        if "$test_name"; then
            printf 'ok - %s\n' "$test_name"
        else
            printf 'not ok - %s\n' "$test_name" >&2
            failures=$((failures + 1))
        fi
    done
    [[ $failures -eq 0 ]]
}

main "$@"
