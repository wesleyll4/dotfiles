#!/usr/bin/env bash
set -euo pipefail

fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
legacy="$fixture/legacy.lua"
candidate="$fixture/candidate.lua"
target="$fixture/hyprland.lua"
temp="$fixture/.cutover"
printf 'legacy\n' >"$legacy"
printf 'candidate\n' >"$candidate"
ln -s "$legacy" "$target"

mkdir "$temp"
ln -s "$candidate" "$temp/hyprland.lua"
test -e "$target"
mv -T "$temp/hyprland.lua" "$target"
test -e "$target"
test "$(readlink "$target")" = "$candidate"
rm -rf -- "$temp"

mkdir "$temp"
ln -s "$legacy" "$temp/hyprland.lua"
test -e "$target"
mv -T "$temp/hyprland.lua" "$target"
test -e "$target"
test "$(readlink "$target")" = "$legacy"
printf 'atomic Hyprland link replacement and rollback: ok\n'
