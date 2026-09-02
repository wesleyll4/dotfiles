#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/home" "$fixture/elsewhere"

run_bootstrap() {
    local os_release=$1
    printf '%s\n' "$os_release" >"$fixture/os-release"
    (cd "$fixture/elsewhere" && \
        DOTFILES_BOOTSTRAP_DRY_RUN=1 \
        DOTFILES_OS_RELEASE_FILE="$fixture/os-release" \
        DOTFILES_TARGET_HOME="$fixture/home" \
        "$root/bootstrap" desktop --check)
}

output=$(run_bootstrap 'ID=arch')

grep -Fx "ANSIBLE_CONFIG=$root/ansible/ansible.cfg" <<<"$output" >/dev/null
grep -Fx "dotfiles_root=$root" <<<"$output" >/dev/null
grep -Fx "dotfiles_home=$fixture/home" <<<"$output" >/dev/null
grep -F "$root/ansible/playbooks/desktop.yml" <<<"$output" >/dev/null
grep -F -- '--check' <<<"$output" >/dev/null

run_bootstrap $'ID=omarchy\nID_LIKE=arch' >/dev/null
run_bootstrap $'ID=omarchy\nID_LIKE="foo arch bar"' >/dev/null

if run_bootstrap $'ID=debian\nID_LIKE="debian foo"' >/dev/null 2>&1; then
    printf 'incompatible distro was accepted\n' >&2
    exit 1
fi

if run_bootstrap $'ID=omarchy\nID_LIKE=archlinuxfoo' >/dev/null 2>&1; then
    printf 'arch substring was accepted\n' >&2
    exit 1
fi
