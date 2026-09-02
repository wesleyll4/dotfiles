# Noctalia shell recovery from TTY

Use this procedure only if the graphical session stops responding after a
future Noctalia cutover. It is intentionally manual and does not change
`apps.lua`, Hypridle, or Hyprlock.

From `Ctrl+Alt+F3`, log in as the target user and set the checkout path:

```bash
root=/path/to/dotfiles
home="$HOME"
current="$root/config/user/hypr/candidate/shell/current/shell.lua"
slot="$home/.config/hypr/integrations/shell.lua"
```

Stop only Noctalia:

```bash
pkill -x noctalia || true
```

Restore the current provider atomically. The temporary link must be on the
same filesystem as the destination:

```bash
tmp="$slot.recovery-$$"
ln -s -- "$current" "$tmp"
mv -T -- "$tmp" "$slot"
```

Validate before reloading anything:

```bash
Hyprland --verify-config --config "$home/.config/hypr/hyprland.lua"
```

If the session still responds, reload it:

```bash
hyprctl reload
```

Restart only the current provider components that were active in the
preflight snapshot:

```bash
pgrep -x waybar >/dev/null || waybar &
pgrep -x walker >/dev/null || walker --gapplication-service &
pgrep -x elephant >/dev/null || systemctl --user restart elephant
pgrep -x ags >/dev/null || ags run "$home/.config/ags" &
```

Do not execute lock, suspend, logout, reboot, or shutdown actions while
recovering. If `hyprctl` does not respond, keep the restored link in place,
switch to another TTY, and restart the graphical session through the normal
login manager after preserving the logs.
