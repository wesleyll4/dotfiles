# Arch package inventory (Task 11)

This is an inventory of observed software, not an installation manifest. Empty
Ansible lists remain intentional until each candidate is reviewed.

## Development boundary candidates

| Item | Responsibility | Source/status | Evidence |
| --- | --- | --- | --- |
| git | development/common | native Arch | `/usr/bin/git`, package `git` |
| GitHub CLI | development | native Arch | explicit package `github-cli` |
| ripgrep | development/CLI tooling | native Arch | `/usr/bin/rg`, package `ripgrep` |
| fd | development/CLI tooling | native Arch | `/usr/bin/fd`, package `fd` |
| bat | development/CLI tooling | native Arch | `/usr/bin/bat`, package `bat` |
| Neovim | development/editor | native Arch | `/usr/bin/nvim`, package `neovim` |
| Node.js/npm | development/runtime | native package plus Mise-managed runtime | package `nodejs`; active runtime under `~/.local/share/mise` |
| .NET | development/runtime | other/user-managed | active runtime under `~/.local/share/mise/dotnet-root` |
| Docker + Compose/buildx | development/containers | native Arch | explicit packages `docker`, `docker-compose`, `docker-buildx` |

No candidate above is enabled by this task.

## Desktop and current/default software

| Item | Responsibility | Source/status |
| --- | --- | --- |
| Kitty | terminal emulator | native Arch; current/default; preference unknown |
| Zsh | interactive shell | native Arch; current/default; preference unknown |
| Waybar | desktop shell/UI | native Arch; current/default; preference unknown |
| Walker | desktop launcher | AUR/foreign (`walker-bin`); current/default; preference unknown |
| Hyprland | compositor | native Arch |
| hypridle/hyprlock | desktop session | native Arch |
| Chromium/Firefox | browser applications | native Arch |
| Dolphin | file manager | native Arch |
| Starship/Mise/Yazi | CLI tooling | native Arch packages and user configuration |

## Gaming candidates (not enabled)

| Item | Responsibility | Source/status |
| --- | --- | --- |
| Steam | gaming | native Arch |
| MangoHud | gaming | native Arch |
| Sober | gaming/application | Flatpak (`org.vinegarhq.Sober`, Flathub) |

## AUR/foreign candidates (kept out of native lists)

Observed foreign packages include `walker-bin`, `networkmanager-dmenu-git`,
`yay-bin`, `wlogout`, `aylurs-gtk-shell-git`, `libastal-*`, and the Elephant
provider packages. They require an explicit AUR decision and are not passed to
the native `packages` role.

## Flatpak candidates (kept out of native lists)

Observed applications are `com.stremio.Stremio` and `org.vinegarhq.Sober` from
Flathub. They are not passed to the native `packages` role.

## Other / user-managed

Mise-managed Node.js and .NET runtimes, locally installed tooling, and future
secret-manager integrations are not represented as native Arch package names.

The legacy `packages.arch` currently contains `greetd`, `greetd-regreet`, and
`python`; greetd/ReGreet remains owned by the existing guarded installer and is
outside the development boundary.
