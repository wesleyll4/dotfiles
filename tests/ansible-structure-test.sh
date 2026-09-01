#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)

for path in \
    bootstrap \
    ansible/ansible.cfg \
    ansible/requirements.yml \
    ansible/inventories/local/hosts.yml \
    ansible/inventories/local/group_vars/all.yml \
    ansible/profiles/workstation.yml \
    ansible/profiles/dev.yml \
    ansible/playbooks/workstation.yml \
    ansible/playbooks/dev.yml \
    ansible/playbooks/verify.yml \
    ansible/roles/common/defaults/main.yml \
    ansible/roles/common/tasks/main.yml \
    secrets/README.md \
    docs/inspirations/README.md; do
    [[ -f "$root/$path" ]] || {
        printf 'missing required architecture path: %s\n' "$path" >&2
        exit 1
    }
done

[[ -x "$root/bootstrap" ]] || {
    printf 'bootstrap is not executable\n' >&2
    exit 1
}

"$root/bootstrap" --help | grep -F 'workstation|dev' >/dev/null
