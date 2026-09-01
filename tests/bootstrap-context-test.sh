#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/home" "$fixture/elsewhere"

output=$(cd "$fixture/elsewhere" && \
    DOTFILES_BOOTSTRAP_DRY_RUN=1 \
    DOTFILES_TARGET_HOME="$fixture/home" \
    "$root/bootstrap" workstation --check)

grep -Fx "ANSIBLE_CONFIG=$root/ansible/ansible.cfg" <<<"$output" >/dev/null
grep -Fx "dotfiles_root=$root" <<<"$output" >/dev/null
grep -Fx "dotfiles_home=$fixture/home" <<<"$output" >/dev/null
grep -F "$root/ansible/playbooks/workstation.yml" <<<"$output" >/dev/null
grep -F -- '--check' <<<"$output" >/dev/null
