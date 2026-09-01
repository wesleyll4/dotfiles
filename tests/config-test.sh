#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
desktop_config="$repo_root/hypr/.config/hypr/hyprland.lua"
greeter_config="$repo_root/greetd/etc/greetd/hyprland-greeter.lua"
launcher="$repo_root/greetd/etc/greetd/launch-regreet.sh"
tmp_root=$(mktemp -d)
trap 'rm -rf -- "$tmp_root"' EXIT

make_fake_regreet() {
    local fake=$1
    cat >"$fake" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >"${REGREET_TEST_ARGS:?}"
while [[ $# -gt 0 ]]; do
    if [[ $1 == --config ]]; then
        cp -- "$2" "${REGREET_TEST_CONFIG:?}"
        exit 0
    fi
    shift
done
exit 1
EOF
    chmod +x "$fake"
}

test_launcher_uses_local_wallpaper() {
    local fixture="$tmp_root/local"
    mkdir -p "$fixture/wallpapers" "$fixture/runtime"
    printf 'image\n' >"$fixture/wallpapers/monochrome.png"
    printf 'fallback\n' >"$fixture/fallback.png"
    printf '[background]\npath = "@WALLPAPER@"\nfit = "Cover"\n' >"$fixture/template.toml"
    printf 'window {}\n' >"$fixture/style.css"
    make_fake_regreet "$fixture/regreet"

    REGREET_WALLPAPER_DIR="$fixture/wallpapers" \
    REGREET_FALLBACK="$fixture/fallback.png" \
    REGREET_TEMPLATE="$fixture/template.toml" \
    REGREET_STYLE="$fixture/style.css" \
    REGREET_BIN="$fixture/regreet" \
    REGREET_RANDOM_INDEX=0 \
    REGREET_TEST_ARGS="$fixture/args" \
    REGREET_TEST_CONFIG="$fixture/generated.toml" \
    XDG_RUNTIME_DIR="$fixture/runtime" \
        "$launcher" --demo

    grep -F "path = \"$fixture/wallpapers/monochrome.png\"" \
        "$fixture/generated.toml" >/dev/null
    grep -F -- '--demo' "$fixture/args" >/dev/null
    [[ ! -e "$fixture/runtime/regreet-runtime.toml" ]]
}

test_launcher_uses_fallback_without_local_images() {
    local fixture="$tmp_root/fallback"
    mkdir -p "$fixture/wallpapers" "$fixture/runtime"
    printf 'fallback\n' >"$fixture/fallback.png"
    printf '[background]\npath = "@WALLPAPER@"\nfit = "Cover"\n' >"$fixture/template.toml"
    printf 'window {}\n' >"$fixture/style.css"
    make_fake_regreet "$fixture/regreet"

    REGREET_WALLPAPER_DIR="$fixture/wallpapers" \
    REGREET_FALLBACK="$fixture/fallback.png" \
    REGREET_TEMPLATE="$fixture/template.toml" \
    REGREET_STYLE="$fixture/style.css" \
    REGREET_BIN="$fixture/regreet" \
    REGREET_TEST_ARGS="$fixture/args" \
    REGREET_TEST_CONFIG="$fixture/generated.toml" \
    XDG_RUNTIME_DIR="$fixture/runtime" \
        "$launcher"

    grep -F "path = \"$fixture/fallback.png\"" "$fixture/generated.toml" >/dev/null
    if grep -F -- '--demo' "$fixture/args" >/dev/null; then
        printf 'launcher forwarded --demo without being asked\n' >&2
        return 1
    fi
}

verify_config() {
    local name=$1 config=$2 output
    output="$tmp_root/$name.out"
    if ! Hyprland --verify-config --config "$config" >"$output" 2>&1; then
        cat "$output" >&2
        return 1
    fi
    grep -F 'config ok' "$output" >/dev/null
}

verify_config desktop "$desktop_config"
verify_config greeter "$greeter_config"
test_launcher_uses_local_wallpaper
test_launcher_uses_fallback_without_local_images
python "$repo_root/scripts/validate-greetd.py" "$repo_root/greetd/etc/greetd"

mkdir -p "$tmp_root/invalid-greetd"
cp -a "$repo_root/greetd/etc/greetd/." "$tmp_root/invalid-greetd/"
sed -i 's/user = "greeter"/user = "root"/' "$tmp_root/invalid-greetd/config.toml"
if python "$repo_root/scripts/validate-greetd.py" "$tmp_root/invalid-greetd" >/dev/null 2>&1; then
    printf 'invalid greetd user unexpectedly passed validation\n' >&2
    exit 1
fi

printf 'ok - Hyprland desktop and greeter Lua configs\n'
