hl.window_rule({
    name = "stremio-idle-inhibit",
    match = { class = "^com\\.stremio\\.Stremio$" },
    idle_inhibit = "fullscreen",
})

hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

hl.window_rule({
    name = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move = "20 monitor_h-120",
    float = true,
})

hl.window_rule({
    name = "nmtui-float-style",
    match = { title = "^(nmtui)$" },
    float = true,
})

hl.window_rule({
    name = "floating-webapp",
    match = { class = "floating-webapp" },
    float = true,
    size = "500 200",
    center = true,
})

hl.window_rule({
    name = "webapp-tiling",
    match = { class = "^chromium$" },
    float = false,
})

hl.window_rule({
    name = "cheatsheet",
    match = { class = "cheatsheet" },
    float = true,
    size = "700 900",
    center = true,
})
