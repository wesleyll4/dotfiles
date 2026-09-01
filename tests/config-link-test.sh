#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT

repo="$fixture/repository"
home="$fixture/home"
outside="$fixture/outside"
mkdir -p "$repo/config" "$home/links" "$outside"
printf 'expected\n' > "$repo/config/expected"
printf 'legacy-one\n' > "$repo/config/legacy-one"
printf 'legacy-two\n' > "$repo/config/legacy-two"
printf 'unexpected\n' > "$repo/config/unexpected"

expected="$repo/config/expected"
legacy_one="$repo/config/legacy-one"
legacy_two="$repo/config/legacy-two"
unexpected="$repo/config/unexpected"

run_adoption() {
    local target=$1 expected_source=$2 legacy_sources=$3
    ANSIBLE_CONFIG="$root/ansible/ansible.cfg" \
        ansible-playbook "$root/tests/fixtures/link-adoption.yml" \
        -e "dotfiles_root=$repo" \
        -e "dotfiles_home=$home" \
        -e "managed_link_target=$target" \
        -e "managed_link_expected_source=$expected_source" \
        -e "{\"managed_link_legacy_sources\": $legacy_sources}"
}

assert_link_target() {
    local target=$1 source=$2
    [[ -L "$target" ]]
    [[ "$(realpath -e -- "$target")" == "$source" ]]
}

assert_fails_unchanged_symlink() {
    local target=$1 before=$2
    if run_adoption "$target" "$expected" "[$legacy_one, $legacy_two]"; then
        printf 'unexpected symlink adoption succeeded: %s\n' "$target" >&2
        exit 1
    fi
    [[ "$(readlink -- "$target")" == "$before" ]]
}

# Missing target is created as the expected link.
missing_target="$home/links/missing"
run_adoption "$missing_target" "$expected" "[$legacy_one, $legacy_two]"
assert_link_target "$missing_target" "$expected"

# Existing expected link stays unchanged.
expected_target="$home/links/expected"
ln -s -- "$expected" "$expected_target"
expected_before=$(readlink -- "$expected_target")
run_adoption "$expected_target" "$expected" "[$legacy_one, $legacy_two]"
[[ "$(readlink -- "$expected_target")" == "$expected_before" ]]

# Each explicitly approved legacy source is relinked to expected.
legacy_one_target="$home/links/legacy-one"
ln -s -- "$legacy_one" "$legacy_one_target"
run_adoption "$legacy_one_target" "$expected" "[$legacy_one, $legacy_two]"
assert_link_target "$legacy_one_target" "$expected"

legacy_two_target="$home/links/legacy-two"
ln -s -- "$legacy_two" "$legacy_two_target"
run_adoption "$legacy_two_target" "$expected" "[$legacy_one, $legacy_two]"
assert_link_target "$legacy_two_target" "$expected"

# Rejected targets preserve their exact content/state.
unexpected_target="$home/links/unexpected"
ln -s -- "$unexpected" "$unexpected_target"
assert_fails_unchanged_symlink "$unexpected_target" "$(readlink -- "$unexpected_target")"

file_target="$home/links/file"
printf 'do not replace\n' > "$file_target"
file_before=$(sha256sum -- "$file_target")
if run_adoption "$file_target" "$expected" "[$legacy_one, $legacy_two]"; then
    printf 'regular file adoption succeeded\n' >&2
    exit 1
fi
[[ "$(sha256sum -- "$file_target")" == "$file_before" ]]

directory_target="$home/links/directory"
mkdir -p "$directory_target"
printf 'do not replace\n' > "$directory_target/sentinel"
directory_before=$(sha256sum -- "$directory_target/sentinel")
if run_adoption "$directory_target" "$expected" "[$legacy_one, $legacy_two]"; then
    printf 'directory adoption succeeded\n' >&2
    exit 1
fi
[[ -d "$directory_target" ]]
[[ "$(sha256sum -- "$directory_target/sentinel")" == "$directory_before" ]]

# Sources must be canonical and inside dotfiles_root; target must stay in home.
outside_source="$outside/source"
printf 'outside\n' > "$outside_source"
outside_target="$home/links/outside-source"
if run_adoption "$outside_target" "$outside_source" "[]"; then
    printf 'outside source adoption succeeded\n' >&2
    exit 1
fi
[[ ! -e "$outside_target" && ! -L "$outside_target" ]]

noncanonical_target="$home/links/noncanonical"
if run_adoption "$noncanonical_target" "$repo/config/../config/expected" "[]"; then
    printf 'noncanonical source adoption succeeded\n' >&2
    exit 1
fi
[[ ! -e "$noncanonical_target" && ! -L "$noncanonical_target" ]]

escaped_target="$outside/escaped"
if run_adoption "$escaped_target" "$expected" "[$legacy_one, $legacy_two]"; then
    printf 'outside-home target adoption succeeded\n' >&2
    exit 1
fi
[[ ! -e "$escaped_target" && ! -L "$escaped_target" ]]

cli_home="$fixture/cli-home"
mkdir -p "$cli_home/.config/mise" "$cli_home/.config/yazi"
ln -s -- "$root/config/user/starship/starship.toml" "$cli_home/.config/starship.toml"
ln -s -- "$root/config/user/mise/config.toml" "$cli_home/.config/mise/config.toml"
ln -s -- "$root/config/user/yazi/keymap.toml" "$cli_home/.config/yazi/keymap.toml"

run_cli_fixture() {
    ANSIBLE_CONFIG="$root/ansible/ansible.cfg" \
        ansible-playbook "$root/tests/fixtures/cli-tools-link-adoption.yml" \
        -e "dotfiles_root=$root" \
        -e "dotfiles_home=$cli_home"
}

run_cli_fixture
assert_link_target "$cli_home/.config/starship.toml" "$root/config/user/starship/starship.toml"
assert_link_target "$cli_home/.config/mise/config.toml" "$root/config/user/mise/config.toml"
assert_link_target "$cli_home/.config/yazi/keymap.toml" "$root/config/user/yazi/keymap.toml"

cli_second_run=$(run_cli_fixture)
grep -F 'changed=0' <<<"$cli_second_run" >/dev/null

zsh_home="$fixture/zsh-home"
mkdir -p "$zsh_home"
ln -s -- "$root/config/user/zsh/.zshrc" "$zsh_home/.zshrc"

run_zsh_fixture() {
    ANSIBLE_CONFIG="$root/ansible/ansible.cfg" \
        ansible-playbook "$root/tests/fixtures/zsh-link-adoption.yml" \
        -e "dotfiles_root=$root" \
        -e "dotfiles_home=$zsh_home"
}

run_zsh_fixture
assert_link_target "$zsh_home/.zshrc" "$root/config/user/zsh/.zshrc"
zsh_second_run=$(run_zsh_fixture)
grep -F 'changed=0' <<<"$zsh_second_run" >/dev/null

kitty_home="$fixture/kitty-home"
mkdir -p "$kitty_home/.config/kitty"
for kitty_entry in "One Dark.conf" current-theme.conf kitty.conf kitty.conf.bak; do
    ln -s -- "$root/config/user/kitty/$kitty_entry" "$kitty_home/.config/kitty/$kitty_entry"
done

run_kitty_fixture() {
    ANSIBLE_CONFIG="$root/ansible/ansible.cfg" \
        ansible-playbook "$root/tests/fixtures/terminal-kitty-link-adoption.yml" \
        -e "dotfiles_root=$root" \
        -e "dotfiles_home=$kitty_home"
}

run_kitty_fixture
for kitty_entry in "One Dark.conf" current-theme.conf kitty.conf kitty.conf.bak; do
    assert_link_target "$kitty_home/.config/kitty/$kitty_entry" "$root/config/user/kitty/$kitty_entry"
done
kitty_second_run=$(run_kitty_fixture)
grep -F 'changed=0' <<<"$kitty_second_run" >/dev/null

printf 'managed link adoption: ok\n'
