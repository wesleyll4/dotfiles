local dp3_enabled = {
    output = "DP-3",
    mode = "1920x1080@60",
    position = "2560x0",
    scale = 1,
    disabled = false,
}

hl.monitor(dp3_enabled)
hl.monitor({ output = "HDMI-A-1", mode = "2560x1080@60", position = "0x0", scale = 1 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

local function toggle_dp3()
    if hl.get_monitor("DP-3") then
        hl.monitor({ output = "DP-3", disabled = true })
    else
        hl.monitor(dp3_enabled)
    end
end

return {
    toggle_dp3 = toggle_dp3,
}
