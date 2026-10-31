-- Vellum Shell session services. Installed as ~/.config/hypr/autostart.lua.
hl.on("hyprland.start", function()
    local home = os.getenv("HOME")
    hl.exec_cmd(home .. "/.config/quickshell/vellum_shell/scripts/shell-start")
    -- The NetworkManager secret agent: it asks for the passwords that
    -- NetworkManager needs on its own (enterprise Wi-Fi, VPN). The shell's
    -- network panel covers everything else.
    hl.exec_cmd("nm-applet --indicator")
end)
