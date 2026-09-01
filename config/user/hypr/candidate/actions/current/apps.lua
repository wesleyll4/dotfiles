-- Current application-actions provider: defaults and screenshot only.
hl.bind("SUPER + T", hl.dsp.exec_cmd("kitty"))
hl.bind("SUPER + E", hl.dsp.exec_cmd("dolphin"))
hl.bind("SUPER + B", hl.dsp.exec_cmd("chromium"))
hl.bind("SUPER + CTRL + S", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot-region.sh"))

return {}
