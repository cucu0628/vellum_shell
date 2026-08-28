-- Vellum Shell shortcuts. Installed as ~/.config/hypr/bindings.lua.
local shell = [[quickshell ipc --path "$HOME/.config/quickshell/vellum_shell/shell.qml" call]]

-- These keys are also present in Hyprland's example config, so replace them.
hl.unbind("SUPER + V")
hl.unbind("SUPER + P")

hl.bind("SUPER + SPACE", hl.dsp.exec_cmd(shell .. " launcher toggle"), { description = "Vellum launcher" })
hl.bind("SUPER + V", hl.dsp.exec_cmd(shell .. " clipboard toggle"), { description = "Vellum clipboard" })
hl.bind("SUPER + N", hl.dsp.exec_cmd(shell .. " notifications toggle"), { description = "Vellum notifications" })
hl.bind("SUPER + P", hl.dsp.exec_cmd(shell .. " menu toggle"), { description = "Vellum menu" })
hl.bind("SUPER + SHIFT + L", hl.dsp.exec_cmd(shell .. " lock lock"), { description = "Vellum lock screen" })
hl.bind("PRINT", hl.dsp.exec_cmd(shell .. " screenshot capture"), { description = "Vellum screenshot" })
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd(shell .. " screenshot region"), { description = "Vellum region screenshot" })
