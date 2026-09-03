#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
task_file="$root/ansible/roles/omarchy_storage_tuning/tasks/main.yml"

grep -F '  ansible.builtin.systemd_service:' "$task_file" >/dev/null || {
    printf 'RED: fstrim task must use ansible.builtin.systemd_service\n' >&2
    exit 1
}
grep -F '    name: "{{ omarchy_storage_tuning_fstrim_unit }}"' "$task_file" >/dev/null || {
    printf 'RED: fstrim task must use the variable unit name\n' >&2
    exit 1
}
grep -Fx '    enabled: true' "$task_file" >/dev/null || {
    printf 'RED: fstrim task must declare enabled: true\n' >&2
    exit 1
}
grep -Fx '    state: started' "$task_file" >/dev/null || {
    printf 'RED: fstrim task must declare state: started\n' >&2
    exit 1
}

fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/etc" "$fixture/hooks" "$fixture/bin"

printf '%s\n' 'KERNEL_CMDLINE[default]+="quiet cryptdevice=PARTUUID=AAA:root root=/dev/mapper/root rootflags=subvol=@ rw"' >"$fixture/etc/default-limine"
printf '%s\n' 'allow-discards|discard' 'no-write-workqueue|perf-no_write_workqueue' >"$fixture/hooks/encrypt"
cat >"$fixture/bin/limine-update" <<'EOF'
#!/usr/bin/env bash
printf 'limine-update\n' >>"$OMARCHY_STORAGE_TEST_LOG"
EOF
chmod +x "$fixture/bin/limine-update"

export ANSIBLE_CONFIG="$root/ansible/ansible.cfg"
export ANSIBLE_LOCAL_TEMP="$fixture/ansible-tmp"
export ANSIBLE_REMOTE_TEMP="$fixture/ansible-tmp"
export OMARCHY_STORAGE_TEST_LOG="$fixture/storage-tuning.log"

run_role() {
    ansible-playbook "$root/tests/fixtures/omarchy-storage-tuning.yml" \
        -i "$root/ansible/inventories/local/hosts.yml" \
        -e "omarchy_storage_tuning_become=false" \
        -e "omarchy_storage_tuning_limine_config=$fixture/etc/default-limine" \
        -e "omarchy_storage_tuning_limine_update=$fixture/bin/limine-update" \
        -e "omarchy_storage_tuning_encrypt_hook=$fixture/hooks/encrypt"
}

run_role

grep -Fx 'KERNEL_CMDLINE[default]+="quiet cryptdevice=PARTUUID=AAA:root:allow-discards,no-write-workqueue root=/dev/mapper/root rootflags=subvol=@ rw"' "$fixture/etc/default-limine"
grep -Fx 'limine-update' "$OMARCHY_STORAGE_TEST_LOG"
