-- Current desktop shell provider: UI services and provider-owned actions only.
hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("walker --gapplication-service")
    hl.exec_cmd("systemctl --user restart elephant")
    hl.exec_cmd("ags run ~/.config/ags")
end)

hl.bind("SUPER + CTRL + Escape", hl.dsp.exec_cmd("killall waybar || waybar"))
hl.bind("SUPER + Space", hl.dsp.exec_cmd("walker"))
hl.bind("SUPER + F2", hl.dsp.exec_cmd("walker -m menus:monitors"))
hl.bind("SUPER + F1", hl.dsp.exec_cmd("walker -m menus:cheatsheet"))
hl.bind("SUPER + V", hl.dsp.exec_cmd("walker --provider clipboard"))
hl.bind("SUPER + Escape", hl.dsp.exec_cmd("walker -m menus:session"))
hl.bind("SUPER + C", hl.dsp.exec_cmd("astal -i mydots -t calendar"))

return {}
