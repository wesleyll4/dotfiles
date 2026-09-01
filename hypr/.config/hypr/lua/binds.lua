local c = require("lua/constants")
local monitors = require("lua/monitors")
local mod = c.main_mod

hl.bind(mod .. " + T", hl.dsp.exec_cmd(c.terminal))
hl.bind(mod .. " + W", hl.dsp.window.close())
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd(c.menu))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(c.file_manager))
hl.bind(mod .. " + B", hl.dsp.exec_cmd(c.browser))
hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + CTRL + V", hl.dsp.window.float())
hl.bind(mod .. " + ALT + J", hl.dsp.layout("togglesplit"))

for key, direction in pairs({ left = "l", right = "r", up = "u", down = "d" }) do
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = direction }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = direction }))
end

hl.bind(mod .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "r" }))

for index = 1, 10 do
    local key = index % 10
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = index }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = index }))
end

for key, direction in pairs({ H = "l", L = "r", K = "u", J = "d" }) do
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = direction }))
    hl.bind(mod .. " + CTRL + " .. key, hl.dsp.window.swap({ direction = direction }))
end

hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(mod .. " + CTRL + Escape", hl.dsp.exec_cmd("killall waybar || waybar"))
hl.bind(mod .. " + F2", hl.dsp.exec_cmd(c.menu .. " -m menus:monitors"))
hl.bind(mod .. " + CTRL + M", monitors.toggle_dp3)
hl.bind(mod .. " + F1", hl.dsp.exec_cmd(c.menu .. " -m menus:cheatsheet"))
hl.bind(mod .. " + V", hl.dsp.exec_cmd("walker --provider clipboard"))
hl.bind(mod .. " + CTRL + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mod .. " + CTRL + S", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot-region.sh"))
hl.bind(mod .. " + Escape", hl.dsp.exec_cmd("walker -m menus:session"))
hl.bind(mod .. " + C", hl.dsp.exec_cmd("astal -i mydots -t calendar"))

hl.bind(mod .. " + minus", hl.dsp.window.resize({ x = -100, y = 0, relative = true }))
hl.bind(mod .. " + equal", hl.dsp.window.resize({ x = 100, y = 0, relative = true }))
hl.bind(mod .. " + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = -100, relative = true }))
hl.bind(mod .. " + SHIFT + equal", hl.dsp.window.resize({ x = 0, y = 100, relative = true }))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
