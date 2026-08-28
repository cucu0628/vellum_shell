-- Vellum Shell session services. Installed as ~/.config/hypr/autostart.lua.
hl.on("hyprland.start", function()
    local home = os.getenv("HOME")
    hl.exec_cmd(home .. "/.config/quickshell/vellum_shell/scripts/shell-start")
    hl.exec_cmd("nm-applet --indicator")
end)
