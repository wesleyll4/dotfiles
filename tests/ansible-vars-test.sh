#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/home" "$fixture/elsewhere"

run_fixture() {
    local playbook=$1 profile=$2
    (
        cd "$fixture/elsewhere"
        ANSIBLE_CONFIG="$root/ansible/ansible.cfg" \
            ansible-playbook "$root/tests/fixtures/$playbook" \
            -e "dotfiles_root=$root" \
            -e "dotfiles_home=$fixture/home" \
            -e "expected_profile=$profile"
    )
}

run_fixture assert-desktop-vars.yml desktop
run_fixture assert-dev-vars.yml dev
