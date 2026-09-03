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

snapshot_target() {
    if [[ -L "$fixture/etc/default-limine" ]]; then
        printf 'symlink:%s:%s\n' \
            "$(readlink -- "$fixture/etc/default-limine")" \
            "$(sha256sum -- "$fixture/etc/default-limine")"
    elif [[ -f "$fixture/etc/default-limine" ]]; then
        printf 'file:%s\n' "$(sha256sum -- "$fixture/etc/default-limine")"
    elif [[ -d "$fixture/etc/default-limine" ]]; then
        printf 'directory:%s\n' "$(sha256sum -- "$fixture/etc/default-limine/sentinel")"
    else
        printf 'absent\n'
    fi
}

unexpected_failures=()

expect_failure() {
    local name=$1 before after before_log after_log
    before=$(snapshot_target)
    before_log=$(sha256sum -- "$OMARCHY_STORAGE_TEST_LOG")
    if run_role >"$fixture/$name.out" 2>"$fixture/$name.err"; then
        printf 'RED: %s unexpectedly passed\n' "$name" >&2
        unexpected_failures+=("$name unexpectedly passed")
    fi
    after=$(snapshot_target)
    if [[ "$before" != "$after" ]]; then
        printf 'RED: %s changed the fake Limine target\n' "$name" >&2
        diff -u <(printf '%s\n' "$before") <(printf '%s\n' "$after") >&2 || true
        unexpected_failures+=("$name changed the fake Limine target")
    fi
    after_log=$(sha256sum -- "$OMARCHY_STORAGE_TEST_LOG")
    if [[ "$before_log" != "$after_log" ]]; then
        printf 'RED: %s called the fake limine-update\n' "$name" >&2
        unexpected_failures+=("$name called the fake limine-update")
    fi
}

reset_target() {
    rm -rf -- "$fixture/etc/default-limine" "$fixture/real-default-limine"
    printf '%s\n' 'KERNEL_CMDLINE[default]+="quiet cryptdevice=PARTUUID=AAA:root root=/dev/mapper/root rootflags=subvol=@ rw"' >"$fixture/etc/default-limine"
    printf '%s\n' 'allow-discards|discard' 'no-write-workqueue|perf-no_write_workqueue' >"$fixture/hooks/encrypt"
    cat >"$fixture/bin/limine-update" <<'EOF'
#!/usr/bin/env bash
printf 'limine-update\n' >>"$OMARCHY_STORAGE_TEST_LOG"
EOF
    chmod +x "$fixture/bin/limine-update"
}

reset_target
rm -- "$fixture/etc/default-limine"
expect_failure target_missing

reset_target
rm -- "$fixture/etc/default-limine"
mkdir -- "$fixture/etc/default-limine"
printf '%s\n' sentinel >"$fixture/etc/default-limine/sentinel"
expect_failure target_directory

reset_target
mv -- "$fixture/etc/default-limine" "$fixture/real-default-limine"
ln -s -- "$fixture/real-default-limine" "$fixture/etc/default-limine"
expect_failure target_symlink

reset_target
rm -- "$fixture/bin/limine-update"
expect_failure limine_update_missing

reset_target
chmod -x "$fixture/bin/limine-update"
expect_failure limine_update_not_executable

reset_target
rm -- "$fixture/hooks/encrypt"
expect_failure encrypt_hook_missing

reset_target
printf '%s\n' 'no-write-workqueue|perf-no_write_workqueue' >"$fixture/hooks/encrypt"
expect_failure encrypt_hook_missing_allow_discards_parser

reset_target
printf '%s\n' 'allow-discards|discard' >"$fixture/hooks/encrypt"
expect_failure encrypt_hook_missing_no_write_workqueue_parser

reset_target
printf '%s\n' 'KERNEL_CMDLINE[linux]+="quiet"' >"$fixture/etc/default-limine"
expect_failure default_cmdline_missing

reset_target
printf '%s\n' \
    'KERNEL_CMDLINE[default]+="quiet cryptdevice=PARTUUID=AAA:root rw"' \
    'KERNEL_CMDLINE[default]+="quiet cryptdevice=PARTUUID=BBB:root rw"' >"$fixture/etc/default-limine"
expect_failure default_cmdline_duplicate

reset_target
printf '%s\n' \
    'KERNEL_CMDLINE[default]+="quiet cryptdevice=PARTUUID=AAA:root root=/dev/mapper/root"' \
    'KERNEL_CMDLINE[default]+="broken' \
    'cryptdevice=PARTUUID=BBB:root ' \
    'root=/dev/mapper/root"' >"$fixture/etc/default-limine"
expect_failure default_cmdline_malformed_duplicate

reset_target
printf '%s\n' 'KERNEL_CMDLINE[default]+="quiet root=/dev/mapper/root rw"' >"$fixture/etc/default-limine"
expect_failure cryptdevice_missing

reset_target
printf '%s\n' 'KERNEL_CMDLINE[default]+="cryptdevice=PARTUUID=AAA:root cryptdevice=PARTUUID=BBB:root"' >"$fixture/etc/default-limine"
expect_failure cryptdevice_duplicate

reset_target
printf '%s\n' 'KERNEL_CMDLINE[default]+="cryptdevice=PARTUUID=AAA:data rw"' >"$fixture/etc/default-limine"
expect_failure cryptdevice_mapper_data

for crypto_token_case in allow_discards_only no_write_workqueue_only unknown_crypto_option; do
    reset_target
    case "$crypto_token_case" in
        allow_discards_only)
            token='cryptdevice=PARTUUID=AAA:root:allow-discards'
            ;;
        no_write_workqueue_only)
            token='cryptdevice=PARTUUID=AAA:root:no-write-workqueue'
            ;;
        unknown_crypto_option)
            token='cryptdevice=PARTUUID=AAA:root:foo'
            ;;
    esac
    printf 'KERNEL_CMDLINE[default]+="%s"\n' "$token" >"$fixture/etc/default-limine"
    cp -- "$fixture/etc/default-limine" "$fixture/before"
    expect_failure "$crypto_token_case"
    cmp -- "$fixture/before" "$fixture/etc/default-limine" 2>/dev/null || {
        printf 'RED: %s changed the fake Limine target\n' "$crypto_token_case" >&2
        unexpected_failures+=("$crypto_token_case changed the fake Limine target")
    }
done

reset_target
printf '%s\n' 'KERNEL_CMDLINE[default]+="quiet cryptdevice=PARTUUID=AAA:root:allow-discards,no-write-workqueue root=/dev/mapper/root rootflags=subvol=@ rw"' >"$fixture/etc/default-limine"
: >"$OMARCHY_STORAGE_TEST_LOG"
if ! run_role >"$fixture/final-state.out" 2>"$fixture/final-state.err"; then
    printf 'RED: final_state apply failed\n' >&2
    unexpected_failures+=("final_state apply failed")
else
    grep -Eq 'changed=0.*failed=0|changed=0 failed=0' "$fixture/final-state.out" || {
        printf 'RED: final_state apply was not idempotent\n' >&2
        unexpected_failures+=("final_state apply was not idempotent")
    }
    [[ ! -s "$OMARCHY_STORAGE_TEST_LOG" ]] || {
        printf 'RED: final_state apply called the fake limine-update\n' >&2
        unexpected_failures+=("final_state apply called the fake limine-update")
    }
fi

if ((${#unexpected_failures[@]} > 0)); then
    printf 'RED: %d negative cases did not fail closed\n' "${#unexpected_failures[@]}" >&2
    exit 1
fi

printf '%s\n' 'Omarchy storage tuning guard-rail tests: ok'
