-- Vellum Shell session services. Installed as ~/.config/hypr/autostart.lua.
hl.on("hyprland.start", function()
    local home = os.getenv("HOME")
    hl.exec_cmd(home .. "/.config/quickshell/vellum_shell/scripts/shell-start")
    -- NetworkManager password prompts (Wi-Fi, 802.1X, PPPoE) come from the
    -- shell itself. Only VPN plugins with their own password dialog (OpenVPN,
    -- OpenConnect) still need nm-applet; uncomment it if you use one:
    -- hl.exec_cmd("nm-applet --indicator")
end)
