-- Noctalia v5 desktop shell provider; session and application actions stay external.
hl.on("hyprland.start", function()
    hl.exec_cmd("noctalia")
end)

hl.bind("SUPER + Space", hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"))
hl.bind("SUPER + V", hl.dsp.exec_cmd("noctalia msg panel-toggle clipboard"))
hl.bind("SUPER + SHIFT + Space", hl.dsp.exec_cmd("noctalia msg panel-toggle control-center"))
hl.bind("SUPER + Escape", hl.dsp.exec_cmd("noctalia msg panel-toggle session"))

return {}
