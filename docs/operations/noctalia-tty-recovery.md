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

Stop only Noctalia (AGS is identified by its `mydots` instance, not by the
process name `ags`):

```bash
pkill -x noctalia || true
if ags list | grep -q mydots; then
  ags quit --instance mydots
  for _ in $(seq 1 10); do
    ags list | grep -q mydots || break
    sleep 1
  done
fi
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
preflight snapshot. Use `ags list` to verify the AGS instance:

```bash
pgrep -x waybar >/dev/null || waybar &
pgrep -x walker >/dev/null || walker --gapplication-service &
pgrep -x elephant >/dev/null || systemctl --user restart elephant
if ! ags list | grep -q mydots; then
  ags run "$home/.config/ags" &
  for _ in $(seq 1 10); do
    ags list | grep -q mydots && break
    sleep 1
  done
fi
```

Do not execute lock, suspend, logout, reboot, or shutdown actions while
recovering. If `hyprctl` does not respond, keep the restored link in place,
switch to another TTY, and restart the graphical session through the normal
login manager after preserving the logs.
