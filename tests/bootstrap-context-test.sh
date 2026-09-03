#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/home" "$fixture/elsewhere"

mkdir -p "$fixture/bin"
cat >"$fixture/bin/ansible-playbook" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >"$ANSIBLE_ARGV_FILE"
EOF
chmod +x "$fixture/bin/ansible-playbook"

run_bootstrap() {
    local os_release=$1
    printf '%s\n' "$os_release" >"$fixture/os-release"
    (cd "$fixture/elsewhere" && \
        DOTFILES_BOOTSTRAP_DRY_RUN=1 \
        DOTFILES_OS_RELEASE_FILE="$fixture/os-release" \
        DOTFILES_TARGET_HOME="$fixture/home" \
        "$root/bootstrap" desktop --check)
}

run_bootstrap_with_args() {
    local argv_file=$1
    shift
    printf '%s\n' 'ID=arch' >"$fixture/os-release"
    (cd "$fixture/elsewhere" && \
        PATH="$fixture/bin:$PATH" \
        ANSIBLE_ARGV_FILE="$argv_file" \
        DOTFILES_OS_RELEASE_FILE="$fixture/os-release" \
        DOTFILES_TARGET_HOME="$fixture/home" \
        "$root/bootstrap" omarchy "$@")
}

assert_argv_contains() {
    local expected=$1
    local argv_file=$2
    grep -Fx -- "$expected" "$argv_file" >/dev/null || {
        printf 'expected ansible-playbook argv to contain %s\n' "$expected" >&2
        return 1
    }
}

assert_bootstrap_invocation() {
    if ! run_bootstrap_with_args "$@"; then
        printf 'assertion failed: bootstrap invocation was rejected before fake ansible-playbook captured argv\n' >&2
        return 1
    fi
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

argv_file="$fixture/argv-a"
assert_bootstrap_invocation "$argv_file" --ask-become-pass
assert_argv_contains '--ask-become-pass' "$argv_file"

argv_file="$fixture/argv-b"
assert_bootstrap_invocation "$argv_file" --check --ask-become-pass
assert_argv_contains '--check' "$argv_file"
assert_argv_contains '--ask-become-pass' "$argv_file"

argv_file="$fixture/argv-c"
assert_bootstrap_invocation "$argv_file" --ask-become-pass --check
assert_argv_contains '--check' "$argv_file"
assert_argv_contains '--ask-become-pass' "$argv_file"

if run_bootstrap_with_args "$fixture/argv-unknown" --unknown >/dev/null 2>&1; then
    printf 'unknown argument was accepted\n' >&2
    exit 1
fi
