-- Vellum Shell shortcuts. Installed as ~/.config/hypr/bindings.lua.
local shell = [[quickshell ipc --path "$HOME/.config/quickshell/vellum_shell/shell.qml" call]]

-- These keys are also present in Hyprland's example config, so replace them.
hl.unbind("SUPER + V")
hl.unbind("SUPER + P")

hl.bind("SUPER + SPACE", hl.dsp.exec_cmd(shell .. " launcher toggle"), { description = "Vellum launcher" })
hl.bind("SUPER + V", hl.dsp.exec_cmd(shell .. " clipboard toggle"), { description = "Vellum clipboard" })
hl.bind("SUPER + N", hl.dsp.exec_cmd(shell .. " notifications toggle"), { description = "Vellum notifications" })
hl.bind("SUPER + P", hl.dsp.exec_cmd(shell .. " settings toggle"), { description = "Vellum settings" })
hl.bind("SUPER + SHIFT + L", hl.dsp.exec_cmd(shell .. " lock lock"), { description = "Vellum lock screen" })
hl.bind("PRINT", hl.dsp.exec_cmd(shell .. " screenshot capture"), { description = "Vellum screenshot" })
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd(shell .. " screenshot region"), { description = "Vellum region screenshot" })

-- Media, volume and brightness keys. Hyprland's example config binds these to
-- playerctl and brightnessctl, which Vellum does not need, so replace them.
-- Volume goes straight to wpctl (capped at 100%), so the keys keep working
-- when the shell is down; the shell shows the OSD from the PipeWire change.
-- Brightness goes through the backend CLI for the same reason. `locked` keeps
-- them working on the lock screen.
local vellum = [["$HOME/.local/bin/vellum"]]
for _, key in ipairs({
    "XF86AudioRaiseVolume", "XF86AudioLowerVolume", "XF86AudioMute", "XF86AudioMicMute",
    "XF86AudioPlay", "XF86AudioPause", "XF86AudioNext", "XF86AudioPrev",
    "XF86MonBrightnessUp", "XF86MonBrightnessDown",
}) do
    hl.unbind(key)
end

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
    { locked = true, repeating = true, description = "Volume up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { locked = true, repeating = true, description = "Volume down" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    { locked = true, description = "Mute output" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
    { locked = true, description = "Mute microphone" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd(shell .. " media playPause"), { locked = true, description = "Play or pause" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(shell .. " media playPause"), { locked = true, description = "Play or pause" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd(shell .. " media next"), { locked = true, description = "Next track" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd(shell .. " media previous"), { locked = true, description = "Previous track" })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(vellum .. [[ call brightness step '{"delta":5}']]),
    { locked = true, repeating = true, description = "Brightness up" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(vellum .. [[ call brightness step '{"delta":-5}']]),
    { locked = true, repeating = true, description = "Brightness down" })
