-- ~/nikita-shell/system/greetd/hyprland.lua
--
-- The login screen's compositor. greetd starts it as the `greeter` user
-- (config.toml); it shows dotfiles/quickshell/greeter.qml and exits once that has
-- handed your session to greetd. install-greeter.sh copies it, with the QML, to
-- /usr/share/nikita-shell.

local root = "/usr/share/nikita-shell"

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "1" })
-- The layout you kept in Settings → Display, so the pointer crosses between monitors
-- where it does once you are in. Plain data that greeter-sync.sh copies; every field
-- is checked, and nothing in it runs.
do
    local f = io.open("/var/lib/nikita-shell/monitors")
    if f then
        for line in f:lines() do
            local out, mode, pos, scale, transform = line:match("^([%w%-_.]+) (%d+x%d+@[%d.]+) (%-?%d+x%-?%d+) ([%d.]+) ([0-7])$")
            if out then
                hl.monitor({ output = out, mode = mode, position = pos, scale = tonumber(scale), transform = tonumber(transform) })
            else
                local off = line:match("^([%w%-_.]+) disabled$")
                if off then
                    hl.monitor({ output = off, disabled = true })
                end
            end
        end
        f:close()
    end
end

hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "20")

hl.config({
    input = {
        -- As in hyprland.lua; SUPER+SPACE switches.
        kb_layout = "us,es",
        kb_options = "grp:win_space_toggle",
        touchpad = {
            natural_scroll = true,
        },
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        background_color = "rgb(141414)",
        -- Started without start-hyprland: if it dies, greetd starts it again.
        disable_watchdog_warning = true,
    },
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
})

-- greeter.qml animates itself.
hl.layer_rule({
    match = { namespace = "nikita-greeter" },
    no_anim = true,
})

-- Quickshell quits once greetd has the session; then this Hyprland exits and greetd
-- starts the session. If Quickshell crashes, it comes back.
hl.on("hyprland.start", function()
    hl.exec_cmd("until NIKITA_GREETER=1 qs -p " .. root .. "/dotfiles/quickshell/greeter.qml; do sleep 1; done; hyprctl dispatch 'hl.dsp.exit()'")
end)
