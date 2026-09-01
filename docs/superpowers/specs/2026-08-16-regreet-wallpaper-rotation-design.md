# ReGreet Local Wallpaper Rotation Design

## Goal

Show either the monochrome wallpaper or the two-elves wallpaper at random each
time the ReGreet login session starts, while replacing the red power controls
with neutral blue-gray styling.

## Assets and Git policy

The selected images are:

- `/home/wes/Pictures/wallpapers/wallhaven-3q3vw6.png` (monochrome)
- `/home/wes/Pictures/wallpapers/wallhaven-8geml1.jpg` (two elves)

They remain local and are not committed or redistributed through the dotfiles
repository. The existing repository-owned Tokyo Night image remains the
portable fallback when no local wallpaper is installed.

The repository contains only the selection mechanism and an ignored local
asset directory. On this machine, the two selected images are linked into that
directory. The system installer follows those links while staging and copies
the image bytes under `/etc/greetd/wallpapers/`, so the greeter never needs
access to the user's home directory.

## Startup flow

A small ReGreet launcher scans `/etc/greetd/wallpapers/` for regular image
files. When at least one exists, it selects one uniformly at random. When the
directory is empty or absent, it selects
`/etc/greetd/tokyo-night-city.png`.

The launcher creates a private runtime ReGreet configuration from the tracked
configuration template, substitutes the selected absolute image path, and then
executes ReGreet with the tracked stylesheet. A failure to create the runtime
configuration stops the greeter command with a clear error instead of silently
starting with a broken configuration.

The Hyprland greeter session calls this launcher rather than invoking ReGreet
directly. Wallpaper selection happens once per greeter session; this avoids a
distracting slideshow while the user is typing a password.

## Installation and rollback

`install-system --no-activate` stages the launcher and every available local
wallpaper along with the existing greetd files. The staged manifest records all
deployed files, including the optional wallpapers, so activation still refuses
source drift after the demo. Backup and rollback include those files and do not
follow destination symlinks.

Other machines work without extra setup: they stage no local wallpapers and
use the repository fallback. Their own untracked images can be added to the
same ignored directory.

## Visual styling

Reboot and power-off buttons use the existing dark surface, blue-gray text and
a muted blue border. Hover and focus states use the Tokyo Night blue accent.
No destructive action uses a red fill or red border.

## Verification

Automated tests cover:

- selecting only files from the installed wallpaper directory;
- selecting the fallback when that directory is missing or empty;
- generating a valid runtime configuration containing the chosen path;
- staging, drift detection, backup and rollback of optional wallpapers;
- rejecting unsafe wallpaper names or symlinked system destinations;
- validating that the destructive button CSS no longer contains the red
  accent.

The final manual check is a ReGreet demo after restaging. Activation remains a
separate explicit command after the demo is approved.
