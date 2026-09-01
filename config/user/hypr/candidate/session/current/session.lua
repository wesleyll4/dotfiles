-- Current session provider: idle startup and the existing lock action only.
hl.on("hyprland.start", function()
    hl.exec_cmd("hypridle")
end)

hl.bind("SUPER + CTRL + L", hl.dsp.exec_cmd("hyprlock"))

return {}
