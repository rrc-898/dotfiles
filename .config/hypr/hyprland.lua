-- ~/.config/hypr/hyprland.lua
-- Docs: https://wiki.hypr.land/Configuring/Start/

---- MY PROGRAMS ----

mainMod    = "SUPER"
terminal   = "kitty"
menu       = "rofi -show drun"
fileManager = "thunar"
browser    = os.getenv("HOME") .. "/.local/bin/zen"

---- AUTOSTART ----

hl.on("hyprland.start", function()
    -- Log para diagnosticar si waybar se cierra sola (ver ~/.cache/43pr/waybar.log)
    hl.exec_cmd("mkdir -p ~/.cache/43pr && waybar >~/.cache/43pr/waybar.log 2>&1")
    hl.exec_cmd("dunst")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    -- Export the session to systemd/D-Bus first: portals need it, and the
    -- hyprpolkitagent user unit (Arch and Fedora) requires WAYLAND_DISPLAY
    -- 43pr-session.target brings up graphical-session.target, which the portals
    -- require (stop first: a Hyprland restart must not keep the old env)
    hl.exec_cmd("systemctl --user stop 43pr-session.target; dbus-update-activation-environment --systemd --all && systemctl --user start 43pr-session.target hyprpolkitagent.service")

    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("sleep 2 && qs")
end)

---- ENVIRONMENT VARIABLES ----

hl.env("XCURSOR_SIZE", "14")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")

---- INPUT ----

hl.config({
    input = {
        kb_layout = "es",
        numlock_by_default = true,
        follow_mouse = 1,
        sensitivity = 0.5,
        touchpad = {
            natural_scroll = false,
            tap_to_click = true,
        },
    },
})

-- LAYOUT
hl.config({
    dwindle = { preserve_split = true },
})
hl.config({
    master = { new_status = "master" },
})

-- MISC
hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
})

---- SPLIT-OUT FILES ----

require("monitors")
require("keybinds")
require("look")
require("rules")

-- HyprMod managed settings
require("hyprland-gui")
