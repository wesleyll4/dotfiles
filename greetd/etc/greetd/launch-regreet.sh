#!/usr/bin/env bash
set -euo pipefail

wallpaper_dir=${REGREET_WALLPAPER_DIR:-/etc/greetd/wallpapers}
fallback=${REGREET_FALLBACK:-/etc/greetd/tokyo-night-city.png}
template=${REGREET_TEMPLATE:-/etc/greetd/regreet.toml}
style=${REGREET_STYLE:-/etc/greetd/regreet.css}
regreet_bin=${REGREET_BIN:-regreet}
runtime_dir=${XDG_RUNTIME_DIR:-/tmp}
demo=0

if [[ $# -gt 1 || (${1:-} != '' && ${1:-} != --demo) ]]; then
    printf 'usage: %s [--demo]\n' "$0" >&2
    exit 2
fi
[[ ${1:-} == --demo ]] && demo=1

[[ -f "$template" ]] || { printf 'missing ReGreet template: %s\n' "$template" >&2; exit 1; }
[[ -f "$style" ]] || { printf 'missing ReGreet stylesheet: %s\n' "$style" >&2; exit 1; }
[[ -d "$runtime_dir" ]] || { printf 'missing runtime directory: %s\n' "$runtime_dir" >&2; exit 1; }

candidates=()
if [[ -d "$wallpaper_dir" ]]; then
    for candidate in "$wallpaper_dir"/*; do
        [[ -f "$candidate" && ! -L "$candidate" ]] || continue
        case ${candidate,,} in
            *.png|*.jpg|*.jpeg|*.webp) candidates+=("$candidate") ;;
        esac
    done
fi

if ((${#candidates[@]})); then
    random_value=${REGREET_RANDOM_INDEX:-$RANDOM}
    [[ $random_value =~ ^[0-9]+$ ]] || {
        printf 'REGREET_RANDOM_INDEX must be a non-negative integer\n' >&2
        exit 1
    }
    wallpaper=${candidates[random_value % ${#candidates[@]}]}
else
    [[ -f "$fallback" && ! -L "$fallback" ]] || {
        printf 'missing ReGreet fallback wallpaper: %s\n' "$fallback" >&2
        exit 1
    }
    wallpaper=$fallback
fi

template_text=$(<"$template")
[[ $template_text == *'@WALLPAPER@'* ]] || {
    printf 'ReGreet template has no @WALLPAPER@ marker\n' >&2
    exit 1
}

umask 077
runtime_config=$(mktemp "$runtime_dir/regreet.XXXXXXXX.toml") || {
    printf 'could not create the runtime ReGreet configuration\n' >&2
    exit 1
}
cleanup() {
    rm -f -- "$runtime_config"
}
trap cleanup EXIT HUP INT TERM
printf '%s\n' "${template_text//@WALLPAPER@/$wallpaper}" >"$runtime_config"

command=("$regreet_bin")
((demo)) && command+=(--demo)
command+=(--config "$runtime_config" --style "$style")
"${command[@]}"
