hl.env("GTK_USE_PORTAL", "0")
hl.env("GDK_DEBUG", "no-portals")
hl.env("XCURSOR_SIZE", "24")

hl.monitor({
    output = "HDMI-A-1",
    mode = "2560x1080@60",
    position = "0x0",
    scale = 1,
})
hl.monitor({
    output = "DP-3",
    mode = "1920x1080@60",
    position = "2560x0",
    scale = 1,
})

hl.config({
    general = {
        gaps_in = 0,
        gaps_out = 0,
        border_size = 0,
    },
    animations = {
        enabled = false,
    },
    input = {
        kb_layout = "us",
        kb_variant = "intl",
        follow_mouse = 1,
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        disable_hyprland_guiutils_check = true,
        background_color = "rgb(1a1b26)",
    },
})

hl.window_rule({
    name = "regreet-on-ultrawide",
    match = { class = "^[Rr]e[Gg]reet$" },
    monitor = "HDMI-A-1",
    fullscreen = true,
})

hl.on("hyprland.start", function()
    hl.exec_cmd("/etc/greetd/launch-regreet.sh; hyprctl dispatch 'hl.dsp.exit()'")
end)
