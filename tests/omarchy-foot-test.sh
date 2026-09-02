#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/home/.config/foot" "$fixture/source/config/user/omarchy/bin" "$fixture/bin"
cp "$root/config/user/omarchy/bin/dotfiles-foot-scrollback-nvim" "$fixture/source/config/user/omarchy/bin/"
export DOTFILES_TEST_ROOT="$root" DOTFILES_TEST_SOURCE="$fixture/source" DOTFILES_TEST_HOME="$fixture/home"
export ANSIBLE_CONFIG="$root/ansible/ansible.cfg" ANSIBLE_LOCAL_TEMP="$fixture/ansible-tmp" ANSIBLE_REMOTE_TEMP="$fixture/ansible-tmp"

run_role() {
    ansible-playbook "$root/tests/fixtures/omarchy-foot.yml" -i "$root/ansible/inventories/local/hosts.yml" >/dev/null
}

printf '%s\n' '[main]' 'font=monospace' '[key-bindings]' 'clipboard-copy=Control+Shift+c' '[text-bindings]' 'x=Control+x' >"$fixture/home/.config/foot/foot.ini"
run_role
grep -Fx '# BEGIN DOTFILES OMARCHY FOOT' "$fixture/home/.config/foot/foot.ini" >/dev/null
grep -Fx 'pipe-scrollback=[dotfiles-foot-scrollback-nvim] Control+Shift+h' "$fixture/home/.config/foot/foot.ini" >/dev/null
grep -Fx 'clipboard-copy=Control+Shift+c' "$fixture/home/.config/foot/foot.ini" >/dev/null
run_role
[[ $(grep -Fc 'pipe-scrollback=[dotfiles-foot-scrollback-nvim] Control+Shift+h' "$fixture/home/.config/foot/foot.ini") == 1 ]]

printf '%s\n' '# changed' >>"$fixture/source/config/user/omarchy/bin/dotfiles-foot-scrollback-nvim"
run_role
cmp "$fixture/source/config/user/omarchy/bin/dotfiles-foot-scrollback-nvim" "$fixture/home/.local/bin/dotfiles-foot-scrollback-nvim"
printf 'foreign\n' >"$fixture/home/.local/bin/dotfiles-foot-scrollback-nvim"
if run_role; then exit 1; fi
rm "$fixture/home/.local/bin/dotfiles-foot-scrollback-nvim"
run_role

printf '%s\n' '[key-bindings]' 'scrollback-up-page=Control+Shift+h' >"$fixture/home/.config/foot/foot.ini"
if run_role; then exit 1; fi
cat >"$fixture/home/.config/foot/foot.ini" <<'EOF'
[key-bindings]
# BEGIN DOTFILES OMARCHY FOOT
pipe-scrollback=[dotfiles-foot-scrollback-nvim] Control+Shift+h
# END DOTFILES OMARCHY FOOT
scrollback-up-page=Control+Shift+h
EOF
if run_role; then exit 1; fi
cat >"$fixture/home/.config/foot/foot.ini" <<'EOF'
[main]
font=monospace
EOF
if run_role; then exit 1; fi
rm "$fixture/home/.config/foot/foot.ini"
ln -s /tmp "$fixture/home/.config/foot/foot.ini"
if run_role; then exit 1; fi

mock_log="$fixture/mock.log"
cat >"$fixture/bin/foot" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'foot %s\n' "$*" >>"$MOCK_LOG"
"$@"
EOF
cat >"$fixture/bin/nvim" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'nvim %s\n' "$*" >>"$MOCK_LOG"
printf '%s\n' "${@: -1}" >"$TEMP_PATH_FILE"
cp "${@: -1}" "$CAPTURED_FILE"
EOF
chmod +x "$fixture/bin/foot" "$fixture/bin/nvim"
printf '%s\n' 'line 1' 'line 2' | MOCK_LOG="$mock_log" CAPTURED_FILE="$fixture/captured" TEMP_PATH_FILE="$fixture/temp-path" PATH="$fixture/bin:$PATH" "$root/config/user/omarchy/bin/dotfiles-foot-scrollback-nvim"
cmp <(printf '%s\n' 'line 1' 'line 2') "$fixture/captured"
grep -F -- 'foot nvim -R +' "$mock_log" >/dev/null
grep -F -- 'nvim -R +' "$mock_log" >/dev/null
[[ ! -e $(<"$fixture/temp-path") ]]

printf 'Omarchy Foot overlay tests: ok\n'
