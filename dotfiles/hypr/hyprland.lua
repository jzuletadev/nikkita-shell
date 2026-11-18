-- ~/nikita-shell/dotfiles/hypr/hyprland.lua
--
-- Hyprland configuration (Lua, Hyprland 0.57+).
--   * Paths are absolute: Hyprland starts through uwsm, without the shell's PATH.
--   * Every shortcut is made with `bind`, with an id and a description: Settings →
--     Shortcuts lists them and can change their keys.
--   * Settings writes what you change there (input, shortcuts, gestures) to
--     ~/.local/state/nikita-shell/hyprland-settings.lua, read below. This
--     file holds the defaults.

local home = os.getenv("HOME")
local state = home .. "/.local/state/nikita-shell"

-- What Settings changed (services/HyprSettings.qml writes this file): input options,
-- the keys of a shortcut, your own shortcuts, touchpad gestures. Missing, the
-- defaults in this file stand; unreadable, too, and Settings says why.
local user, problems = {}, {}
do
    local path = state .. "/hyprland-settings.lua"
    local f = io.open(path)
    if f then
        f:close()
        local ok, t = pcall(dofile, path)
        if ok and type(t) == "table" then
            user = t
        else
            problems[#problems + 1] = "hyprland-settings.lua can't be read, so the defaults are in use: " .. tostring(t)
        end
    end
end

-- Every monitor: preferred mode, automatic position, scale 1.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "1",
})
-- Then the layout you kept in Settings → Display, if any (services/Monitors.qml
-- writes it; delete the file to go back to the automatic one).
do
    local ok, monitors = pcall(dofile, state .. "/monitors.lua")
    if ok and type(monitors) == "table" then
        for _, m in ipairs(monitors) do
            hl.monitor(m)
        end
    end
end
-- Which monitor is which workspace: Settings → Display → Main display keeps the
-- monitors in order, the main one first (monitor-order in the state folder, a line
-- each: "desc:<make model serial>", so it follows the monitor to another port, or a
-- connector name). Workspace 1 belongs to the first, 2 to the second, and so on:
-- SUPER+1 always goes to the main display, and each monitor starts on its own. With
-- no choice made, Hyprland's own order stands.
-- The workspaces past those (3, 4… with two monitors) are made on the main display,
-- or with "new-workspaces=current" in the same file, on the monitor you are on, as
-- Hyprland does by itself (Settings → Display → New workspaces).
local monitor_order, new_workspaces = {}, "main"
do
    local f = io.open(state .. "/monitor-order")
    if f then
        for line in f:lines() do
            local mode = line:match("^new%-workspaces=(%a+)$")
            if mode == "main" or mode == "current" then
                new_workspaces = mode
            elseif #monitor_order < 10 and (line:match('^desc:[^"%c]+$') or line:match("^[%w%-_.]+$")) then
                monitor_order[#monitor_order + 1] = line
            end
        end
        f:close()
    end
end
for i, monitor in ipairs(monitor_order) do
    hl.workspace_rule({ workspace = tostring(i), monitor = monitor, default = true })
end
-- Where workspace i belongs: its own monitor, the main display for the rest when
-- new ones go there, or nowhere in particular.
local function home_of(i)
    return monitor_order[i] or (new_workspaces == "main" and monitor_order[1]) or nil
end
if new_workspaces == "main" and monitor_order[1] then
    for i = #monitor_order + 1, 10 do
        hl.workspace_rule({ workspace = tostring(i), monitor = monitor_order[1] })
    end
end
local function find_monitor(id)
    for _, m in ipairs(hl.get_monitors()) do
        if m.name == id or (id:sub(1, 5) == "desc:" and m.description == id:sub(6)) then
            return m
        end
    end
end
-- A rule only places a workspace when it is created: one that already exists on
-- another monitor (the order just changed, or its monitor came back) is moved.
-- A monitor whose workspace was just taken away shows its own one instead of the
-- empty one Hyprland gives it; nothing else changes what a monitor shows.
local function place_workspaces()
    -- What each monitor shows now: a moved workspace comes up on its new monitor,
    -- and that one should go on showing what it did.
    local shown = {}
    for _, m in ipairs(hl.get_monitors()) do
        shown[m.name] = m.active_workspace and m.active_workspace.id or nil
    end
    local left, got = {}, {}
    for i = 1, 10 do
        local id = home_of(i)
        local m, ws = id and find_monitor(id), hl.get_workspace(i)
        if m and ws and ws.monitor and ws.monitor.name ~= m.name then
            left[ws.monitor.name] = true
            got[m.name] = true
            hl.dispatch(hl.dsp.workspace.move({ workspace = i, monitor = m.name }))
        end
    end
    for i, id in ipairs(monitor_order) do
        local m = find_monitor(id)
        if m and left[m.name] then
            m:set_workspace(i)
        elseif m and got[m.name] and shown[m.name] and hl.get_workspace(shown[m.name]) then
            m:set_workspace(shown[m.name])
        end
    end
end
hl.on("config.reloaded", place_workspaces)
hl.on("monitor.added", place_workspaces)
-- The session starts on the main display.
hl.on("hyprland.start", function()
    local m = monitor_order[1] and find_monitor(monitor_order[1])
    if m then
        hl.dispatch(hl.dsp.focus({ monitor = m.name }))
    end
end)

local mainMod = "SUPER"
local terminal = "kitty"
local scripts = home .. "/nikita-shell/scripts"
-- The desktop's commands (dotfiles/quickshell); `qs ipc show` lists them.
local qs = "qs ipc call nikita"

-- ---- Environment ----
-- For what Hyprland starts, and handed to systemd at start (see Autostart), so the
-- desktop's service and the apps it opens get them too.
local session_env = {}
local function env(name, value)
    hl.env(name, value)
    session_env[#session_env + 1] = name
end
env("XCURSOR_SIZE", "20")
env("EDITOR", "nvim")
env("VISUAL", "nvim")

-- ---- Input ----
hl.config({
    input = {
        -- SUPER+SPACE cycles them (not ALT+SHIFT: it clashes with too many apps).
        kb_layout = "us,es",
        kb_options = "",
        follow_mouse = 1,
        touchpad = {
            natural_scroll = true,
        },
    },
})
-- Settings → Keyboard and Settings → Mouse & touchpad: only what you changed there.
if type(user.input) == "table" then
    hl.config({ input = user.input })
end
-- A touchpad's own speed: per device, by name (Settings lists the ones plugged in).
for _, device in ipairs(type(user.devices) == "table" and user.devices or {}) do
    hl.device(device)
end

-- ---- Window border: gray, by theme ----
-- theme-manager.sh reloads Hyprland after a switch, so this is read again.
local function theme()
    local f = io.open(state .. "/theme")
    if not f then
        return "dark"
    end
    local t = f:read("*l")
    f:close()
    return t
end
local appearance = theme() == "light"
    and { border_size = 2, border_active = "rgb(5c5c5c)", border_inactive = "rgb(d0d0d0)" }
    or { border_size = 2, border_active = "rgb(a0a0a0)", border_inactive = "rgb(303030)" }

-- ---- General look ----
hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 6,
        border_size = appearance.border_size,
        col = {
            active_border = appearance.border_active,
            inactive_border = appearance.border_inactive,
        },
        layout = "dwindle",
        resize_on_border = true,
        extend_border_grab_area = 15,
        hover_icon_on_border = true,
    },
})

hl.config({
    decoration = {
        rounding = 12, -- Theme.radiusM in dotfiles/quickshell/common/Theme.qml
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        blur = {
            enabled = true,
            size = 6,
            passes = 2,
        },
    },
})

hl.config({
    animations = {
        enabled = true,
    },
})

hl.curve("smoothOut", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.curve("smoothIn", { type = "bezier", points = { { 0.32, 0 }, { 0.67, 0 } } })

hl.animation({
    leaf = "windows",
    enabled = true,
    speed = 4,
    bezier = "smoothOut",
    style = "popin 80%",
})
hl.animation({
    leaf = "windowsOut",
    enabled = true,
    speed = 4,
    bezier = "smoothOut",
    style = "popin 80%",
})
hl.animation({
    leaf = "border",
    enabled = true,
    speed = 8,
    bezier = "smoothOut",
})
hl.animation({
    leaf = "fade",
    enabled = true,
    speed = 4,
    bezier = "smoothOut",
})
hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 5,
    bezier = "smoothOut",
    style = "slide",
})
hl.animation({
    leaf = "layersIn",
    enabled = true,
    speed = 3,
    bezier = "smoothOut",
    style = "fade",
})
hl.animation({
    leaf = "layersOut",
    enabled = true,
    speed = 2,
    bezier = "smoothIn",
    style = "fade",
})
hl.animation({
    leaf = "fadeLayersIn",
    enabled = true,
    speed = 3,
    bezier = "smoothOut",
})
hl.animation({
    leaf = "fadeLayersOut",
    enabled = true,
    speed = 2,
    bezier = "smoothIn",
})

-- ---- Layer rules ----
-- Every panel lives in one full-screen `nikita` surface per monitor: `ignore_alpha`
-- blurs only where a panel is drawn, not the transparent rest.
hl.layer_rule({
    match = { namespace = "nikita" },
    blur = true,
    ignore_alpha = 0.5,
})
-- The launcher animates itself (the field, a light veil), so no fade from here;
-- like `nikita`, blur only behind what it draws (the veil stays under 0.5).
hl.layer_rule({
    match = { namespace = "nikita-launcher" },
    no_anim = true,
    blur = true,
    ignore_alpha = 0.5,
})

-- The window switcher's keyboard (ALT+TAB): an invisible surface; the rail in
-- `nikita` shows the switcher.
hl.layer_rule({
    match = { namespace = "nikita-switcher" },
    no_anim = true,
})

-- ---- Misc ----
hl.config({
    misc = {
        disable_hyprland_logo = true, -- no default wallpaper/logo flash at login
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        background_color = "rgb(141414)", -- shown behind awww while it starts
        -- If Quickshell dies while locked, hyprlock can take over the lock.
        allow_session_lock_restore = true,
    },
})

-- ---- Window rules ----

hl.window_rule({
    match = {
        class = "^org\\.quickshell$",
        title = "^(Settings|Music|Login screen \\(preview\\))$",
    },
    float = true,
    center = true,
})

hl.window_rule({
    match = { class = "^(mpv|io\\.github\\.celluloid_player\\.Celluloid)$" },
    float = true,
    size = "1050 650",
    center = true,
})
hl.window_rule({
    match = { class = "^org\\.gnome\\.Loupe$" },
    float = true,
    center = true,
})
-- The portal's file chooser (Settings → Profile picture, browsers): over the window
-- that asked, not tiled behind it.
hl.window_rule({
    match = { class = "^xdg-desktop-portal-gtk$" },
    float = true,
    size = "960 640",
    center = true,
})

-- ---- Keybinds ----
-- Every shortcut goes through `bind`, with an id: Settings → Shortcuts can give it
-- other keys (user.keys[id]; "" turns it off) and lists them all, by section, from
-- what is published at the end of this file. `fixed` ones can't be changed there
-- (a mouse drag, tapping SUPER).
local shortcuts = {}
local section = ""
local function bind(id, keys, action, opts)
    local custom = type(user.keys) == "table" and user.keys[id] or nil
    local now = type(custom) == "string" and custom or keys
    shortcuts[#shortcuts + 1] = {
        id = id,
        section = section,
        description = opts.description,
        default = keys,
        keys = now,
        fixed = opts.fixed or false,
    }
    opts.fixed = nil
    if now ~= "" then
        hl.bind(now, action, opts)
    end
end

section = "Desktop"
-- `release`: SUPER alone opens the launcher, SUPER+<key> doesn't.
bind("launcher", mainMod .. " + Super_L", hl.dsp.exec_cmd(qs .. " launcher"), { release = true, fixed = true, description = "App search" })
bind("settings", mainMod .. " + slash", hl.dsp.exec_cmd(qs .. " settings ''"), { description = "Settings" })
bind("lock", mainMod .. " + L", hl.dsp.exec_cmd(qs .. " lock || hyprlock"), { description = "Lock screen" })
bind("dnd", mainMod .. " + N", hl.dsp.exec_cmd(qs .. " dnd"), { description = "Do not disturb on/off" })
bind("music", mainMod .. " + SHIFT + M", hl.dsp.exec_cmd(qs .. " music"), { description = "Music" })
bind("layout-next", mainMod .. " + SPACE", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"), { description = "Switch keyboard layout" })

section = "Apps"
bind("terminal", mainMod .. " + T", hl.dsp.exec_cmd(terminal), { description = "Terminal (kitty)" })
bind("files", mainMod .. " + E", hl.dsp.exec_cmd("nautilus --new-window || thunar"), { description = "File manager" })

section = "Windows"
bind("close", mainMod .. " + Q", hl.dsp.window.close(), { description = "Close window" })
bind("fullscreen", mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Fullscreen on/off" })
-- Back to tiled, the resize and center do nothing.
bind("float", mainMod .. " + SHIFT + F", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    hl.dispatch(hl.dsp.window.resize({ x = 1280, y = 720 }))
    hl.dispatch(hl.dsp.window.center())
end, { description = "Floating on/off" })
bind("show-desktop", mainMod .. " + D", hl.dsp.exec_cmd(scripts .. "/minimize.sh toggle"), { description = "Show desktop (minimize all / restore)" })
-- Global shortcuts the desktop listens to (services/ShellState.qml): Hyprland keeps
-- these keys, so the switcher hears each TAB through them; letting go of the
-- modifier reaches the switcher itself.
bind("switcher", "ALT + Tab", hl.dsp.global("nikita:switcher"), { description = "Switch windows (hold ALT, TAB for the next)" })
bind("switcher-back", "ALT + SHIFT + Tab", hl.dsp.global("nikita:switcherBack"), { description = "Switch windows, backwards" })
bind("drag-move", mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, fixed = true, description = "Drag to move the window" })
bind("drag-resize", mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, fixed = true, description = "Drag to resize the window" })
bind("focus-left", mainMod .. " + left", hl.dsp.focus({ direction = "left" }), { description = "Focus window on the left" })
bind("focus-right", mainMod .. " + right", hl.dsp.focus({ direction = "right" }), { description = "Focus window on the right" })
bind("focus-up", mainMod .. " + up", hl.dsp.focus({ direction = "up" }), { description = "Focus window above" })
bind("focus-down", mainMod .. " + down", hl.dsp.focus({ direction = "down" }), { description = "Focus window below" })
bind("move-left", mainMod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }), { description = "Move window left (swap places)" })
bind("move-right", mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }), { description = "Move window right (swap places)" })
bind("move-up", mainMod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }), { description = "Move window up (swap places)" })
bind("move-down", mainMod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }), { description = "Move window down (swap places)" })
bind("narrower", mainMod .. " + CTRL + left", hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true, description = "Make window narrower (hold to repeat)" })
bind("wider", mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }), { repeating = true, description = "Make window wider (hold to repeat)" })
bind("shorter", mainMod .. " + CTRL + up", hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true, description = "Make window shorter (hold to repeat)" })
bind("taller", mainMod .. " + CTRL + down", hl.dsp.window.resize({ x = 0, y = 40, relative = true }), { repeating = true, description = "Make window taller (hold to repeat)" })

section = "Workspaces"
-- After going to a workspace, the desktop shows where you are: the workspace rail
-- of that monitor peeks and its mark bounces, even when the workspace was already
-- on screen (SUPER+1 and SUPER+2 on two monitors only move the focus).
local function locate(i)
    local ws = hl.get_workspace(i)
    local name = ws and ws.monitor and ws.monitor.name or ""
    hl.exec_cmd(qs .. " locate '" .. name:gsub("[^%w%-_.]", "") .. "'")
end
-- The key 0 is workspace 10.
for i = 1, 10 do
    bind("workspace-" .. i, mainMod .. " + " .. (i % 10), function()
        hl.dispatch(hl.dsp.focus({ workspace = i }))
        locate(i)
    end, { description = "Switch to workspace " .. i })
end
for i = 1, 10 do
    bind("move-to-workspace-" .. i, mainMod .. " + SHIFT + " .. (i % 10), function()
        hl.dispatch(hl.dsp.window.move({ workspace = i }))
        locate(i)
    end, { description = "Move window to workspace " .. i .. " (follow)" })
end
for i = 1, 10 do
    bind("send-to-workspace-" .. i, mainMod .. " + ALT + " .. (i % 10), hl.dsp.window.move({ workspace = i, follow = false }), { description = "Move window to workspace " .. i .. " (stay)" })
end

section = "Screenshots"
bind("screenshot-screen", mainMod .. " + S", hl.dsp.exec_cmd(scripts .. "/screenshot.sh screen"), { description = "Screenshot of the monitor (saved + copied)" })
bind("screenshot-region", mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(scripts .. "/screenshot.sh region"), { description = "Screenshot of a region (saved + copied)" })
bind("screenshot-window", mainMod .. " + CTRL + S", hl.dsp.exec_cmd(scripts .. "/screenshot.sh window"), { description = "Screenshot of the window (saved + copied)" })
bind("screenshot-annotate", mainMod .. " + ALT + S", hl.dsp.exec_cmd(scripts .. "/screenshot.sh annotate"), { description = "Screenshot of a region to annotate (Satty)" })
bind("color-pick", mainMod .. " + SHIFT + C", hl.dsp.exec_cmd(scripts .. "/color-pick.sh"), { description = "Pick a color from the screen (copied)" })

-- R as S is for screenshots: alone the monitor, SHIFT a region, ALT the extra (here,
-- the sound). Any of them stops a recording that is running.
section = "Screen recording"
bind("record-screen", mainMod .. " + R", hl.dsp.exec_cmd(qs .. " record screen"), { description = "Record the monitor (again to stop)" })
bind("record-region", mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(qs .. " record region"), { description = "Record a region (again to stop)" })
bind("record-audio", mainMod .. " + ALT + R", hl.dsp.exec_cmd(qs .. " record audio"), { description = "Record the monitor with its sound (again to stop)" })

section = "Sound and brightness"
bind("mute", mainMod .. " + M", hl.dsp.exec_cmd(qs .. " vol mute"), { description = "Mute audio" })
-- Media keys go through the desktop: its dock peeks for a second and is the OSD.
bind("brightness-up", "XF86MonBrightnessUp", hl.dsp.exec_cmd(qs .. " bri up"), { locked = true, repeating = true, description = "Brightness up" })
bind("brightness-down", "XF86MonBrightnessDown", hl.dsp.exec_cmd(qs .. " bri down"), { locked = true, repeating = true, description = "Brightness down" })
bind("volume-up", "XF86AudioRaiseVolume", hl.dsp.exec_cmd(qs .. " vol up"), { locked = true, repeating = true, description = "Volume up" })
bind("volume-down", "XF86AudioLowerVolume", hl.dsp.exec_cmd(qs .. " vol down"), { locked = true, repeating = true, description = "Volume down" })
bind("volume-mute", "XF86AudioMute", hl.dsp.exec_cmd(qs .. " vol mute"), { locked = true, repeating = true, description = "Mute audio" })
-- On the player the dashboard shows (the local one or any app's).
bind("media-play", "XF86AudioPlay", hl.dsp.exec_cmd(qs .. " media play-pause"), { locked = true, description = "Play or pause" })
bind("media-pause", "XF86AudioPause", hl.dsp.exec_cmd(qs .. " media play-pause"), { locked = true, description = "Play or pause" })
bind("media-next", "XF86AudioNext", hl.dsp.exec_cmd(qs .. " media next"), { locked = true, description = "Next song" })
bind("media-previous", "XF86AudioPrev", hl.dsp.exec_cmd(qs .. " media previous"), { locked = true, description = "Previous song" })
-- Laptops whose keyboard light isn't handled by the firmware send these.
bind("keyboard-light-up", "XF86KbdBrightnessUp", hl.dsp.exec_cmd(qs .. " kbdlight up"), { locked = true, description = "Keyboard light up" })
bind("keyboard-light-down", "XF86KbdBrightnessDown", hl.dsp.exec_cmd(qs .. " kbdlight down"), { locked = true, description = "Keyboard light down" })

-- Your own (Settings → Shortcuts → Add): a command for a key. Settings keeps the
-- list; these aren't published back.
for _, c in ipairs(type(user.custom) == "table" and user.custom or {}) do
    if type(c) == "table" and type(c.keys) == "string" and c.keys ~= "" and type(c.command) == "string" and c.command ~= "" then
        hl.bind(c.keys, hl.dsp.exec_cmd(c.command), { description = type(c.description) == "string" and c.description ~= "" and c.description or c.command })
    end
end

-- While Settings → Shortcuts waits for a shortcut's new keys, the desktop switches
-- Hyprland to this set, which has none of the shortcuts above: every key reaches
-- the Settings window, to be read (SUPER + Q is a press, not "close this window").
-- Its one shortcut is the way back by hand, should the desktop ever fail to switch
-- back by itself (it also does when it starts).
hl.define_submap("nikita-capture", function()
    hl.bind("SUPER + CTRL + ALT + SHIFT + Escape", hl.dsp.submap("reset"), { description = "Shortcuts back on" })
end)

-- ---- Gestures ----
-- What a touchpad gesture can do: Settings → Mouse & touchpad offers these, by
-- title. `swipe` ones follow the fingers along that axis instead of running once.
local function float_and_center(action)
    hl.dispatch(hl.dsp.window.float({ action = action }))
    hl.dispatch(hl.dsp.window.resize({ x = 1280, y = 720 }))
    hl.dispatch(hl.dsp.window.center())
end
local function run(command)
    return function()
        hl.exec_cmd(command)
    end
end
local function focus(direction)
    return function()
        hl.dispatch(hl.dsp.focus({ direction = direction }))
    end
end
-- The workspace before or after the one you are on, as SUPER and that number would.
local function step_workspace(delta)
    return function()
        for _, m in ipairs(hl.get_monitors()) do
            if m.focused then
                local id = m.active_workspace and m.active_workspace.id
                if type(id) == "number" and id > 0 and id + delta >= 1 then
                    hl.dispatch(hl.dsp.focus({ workspace = id + delta }))
                    locate(id + delta)
                end
                return
            end
        end
    end
end
-- The volume following your fingers: up louder, down quieter, back and forth in
-- one gesture. Hyprland reports how far the fingers moved at every touchpad event
-- (`delta`, up is negative); that adds up to 1 % for every 10 units, sent at most
-- every 40 ms, so a swipe is a few wpctl runs, not one per event. The volume
-- dock peeks at the start and the end, as with the volume keys (`vol osd`: not
-- `vol show`, which `qs ipc` takes as "show this function", not as a call).
local volume_follow
do
    local pending, last = 0, 0
    local function send(now)
        local step = math.floor(math.abs(pending))
        if step < 1 then
            return
        end
        local louder = pending > 0
        pending = pending - (louder and step or -step)
        last = now
        hl.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " .. step .. "%" .. (louder and "+" or "-"))
    end
    volume_follow = {
        start = function()
            pending, last = 0, 0
            hl.exec_cmd(qs .. " vol osd")
        end,
        update = function(e)
            if type(e) ~= "table" or type(e.delta) ~= "table" then
                return
            end
            pending = pending - (tonumber(e.delta.y) or 0) / 10
            local now = tonumber(e.time_ms) or 0
            if now - last >= 40 then
                send(now)
            end
        end,
        finish = function()
            send(0)
            hl.exec_cmd(qs .. " vol osd")
        end,
    }
end
-- In groups, in the order Settings lists them (each `group` is a heading there).
local gesture_actions = {
    { id = "workspace", group = "Workspaces", title = "Switch workspace, following your fingers", swipe = "horizontal" },
    { id = "workspace-next", group = "Workspaces", title = "Next workspace", run = step_workspace(1) },
    { id = "workspace-prev", group = "Workspaces", title = "Previous workspace", run = step_workspace(-1) },
    { id = "focus-left", group = "Windows", title = "Focus the window on the left", run = focus("left") },
    { id = "focus-right", group = "Windows", title = "Focus the window on the right", run = focus("right") },
    { id = "focus-up", group = "Windows", title = "Focus the window above", run = focus("up") },
    { id = "focus-down", group = "Windows", title = "Focus the window below", run = focus("down") },
    { id = "float", group = "Windows", title = "Float the window, centered", run = function() float_and_center("set") end },
    { id = "tile", group = "Windows", title = "Tile the window", run = function() hl.dispatch(hl.dsp.window.float({ action = "unset" })) end },
    { id = "fullscreen", group = "Windows", title = "Fullscreen on/off", run = function() hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })) end },
    { id = "close", group = "Windows", title = "Close the window", run = function() hl.dispatch(hl.dsp.window.close()) end },
    { id = "hide-all", group = "Hide and bring back", title = "Hide every window, on every monitor", run = run(scripts .. "/minimize.sh hide-all") },
    { id = "show-all", group = "Hide and bring back", title = "Bring the hidden windows back where they were", run = run(scripts .. "/minimize.sh show-all") },
    { id = "minimize-all", group = "Hide and bring back", title = "Minimize this workspace's windows", run = run(scripts .. "/minimize.sh all") },
    { id = "restore-all", group = "Hide and bring back", title = "Bring the minimized windows here", run = run(scripts .. "/minimize.sh restore") },
    { id = "volume", group = "Sound", title = "Volume, following your fingers", swipe = "vertical", callbacks = volume_follow },
    { id = "volume-up", group = "Sound", title = "Volume up", run = run(qs .. " vol up") },
    { id = "volume-down", group = "Sound", title = "Volume down", run = run(qs .. " vol down") },
    { id = "launcher", group = "The desktop", title = "App search", run = run(qs .. " launcher") },
    { id = "show-panels", group = "The desktop", title = "Show all panels", run = run(qs .. " all") },
    { id = "lock", group = "The desktop", title = "Lock the screen", run = run(qs .. " lock || hyprlock") },
}
-- The defaults; Settings replaces the whole list (user.gestures) once you change one.
-- Three fingers move between places: workspaces sideways, and down hides every
-- window on every monitor (one move and nothing shows), up brings them back where
-- they were. Four fingers act here: the windows of this workspace sideways, the
-- volume up and down, following them; spread apart, every panel shows; pinched
-- together, the screen locks.
local default_gestures = {
    { fingers = 3, direction = "left", action = "workspace-prev" },
    { fingers = 3, direction = "right", action = "workspace-next" },
    { fingers = 3, direction = "up", action = "show-all" },
    { fingers = 3, direction = "down", action = "hide-all" },
    { fingers = 3, direction = "pinchout", action = "float" },
    { fingers = 3, direction = "pinchin", action = "tile" },
    { fingers = 4, direction = "left", action = "focus-left" },
    { fingers = 4, direction = "right", action = "focus-right" },
    { fingers = 4, direction = "up", action = "volume" },
    { fingers = 4, direction = "down", action = "volume" },
    { fingers = 4, direction = "pinchout", action = "show-panels" },
    { fingers = 4, direction = "pinchin", action = "lock" },
}
local gestures = type(user.gestures) == "table" and user.gestures or default_gestures
do
    local by_id = {}
    for _, a in ipairs(gesture_actions) do
        by_id[a.id] = a
    end
    -- Here, and in Settings, a pinch is named after the fingers: "pinchin" brings
    -- them together, "pinchout" spreads them apart. Hyprland names it after the
    -- zoom (TrackpadGestures.cpp): its "pinchin", also "zoomin", is the fingers
    -- spreading (scale above 1), and its "pinchout" the fingers coming together.
    local hyprland_direction = { pinchin = "pinchout", pinchout = "pinchin" }
    -- A swipe that follows the fingers is one gesture for both of its directions.
    local swiping = {}
    for _, g in ipairs(gestures) do
        local a = type(g) == "table" and by_id[g.action] or nil
        if a and a.swipe then
            local key = tostring(g.fingers) .. a.swipe
            if not swiping[key] then
                swiping[key] = true
                hl.gesture({ fingers = g.fingers, direction = a.swipe, action = a.callbacks or a.id })
            end
        elseif a then
            hl.gesture({ fingers = g.fingers, direction = hyprland_direction[g.direction] or g.direction, action = a.run })
        end
    end
end

-- ---- What Settings reads back ----
-- The shortcuts with the keys they ended up with, the default gestures and what a
-- gesture can do: JSON in Hyprland's runtime folder (services/HyprSettings.qml
-- watches it).
-- Written from events, when Hyprland starts and after each reload, so checking this
-- file with `Hyprland --verify-config` writes nothing.
local function json(v)
    local t = type(v)
    if t == "table" then
        local parts = {}
        if #v > 0 or next(v) == nil then
            for _, x in ipairs(v) do
                parts[#parts + 1] = json(x)
            end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        for k, x in pairs(v) do
            parts[#parts + 1] = json(tostring(k)) .. ":" .. json(x)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif t == "string" then
        local escaped = v:gsub('[%c"\\]', function(c)
            return string.format("\\u%04x", c:byte())
        end)
        return '"' .. escaped .. '"'
    elseif t == "number" or t == "boolean" then
        return tostring(v)
    end
    return "null"
end
local function publish()
    local runtime, instance = os.getenv("XDG_RUNTIME_DIR"), os.getenv("HYPRLAND_INSTANCE_SIGNATURE")
    if not runtime or not instance then
        return
    end
    local offered = {}
    for _, a in ipairs(gesture_actions) do
        offered[#offered + 1] = { id = a.id, title = a.title, group = a.group or "", swipe = a.swipe or "" }
    end
    local f = io.open(runtime .. "/hypr/" .. instance .. "/nikita.json", "w")
    if f then
        f:write(json({ shortcuts = shortcuts, gestureDefaults = default_gestures, gestureActions = offered, problems = problems }))
        f:close()
    end
    -- Shown by Hyprland itself: the desktop may not be up to say it.
    if #problems > 0 then
        hl.notification.create({ text = problems[1], timeout = 12000 })
    end
end
hl.on("hyprland.start", publish)
hl.on("config.reloaded", publish)

-- A monitor plugged in later gets the wallpaper too: awww only covers the ones it
-- saw when it started, and leaves a new one black.
hl.on("monitor.added", function(monitor)
    hl.exec_cmd(scripts .. "/wallpaper.sh output '" .. monitor.name:gsub("[^%w%-_.]", "") .. "'")
end)

-- ---- Autostart ----
hl.on("hyprland.start", function()
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd(scripts .. "/wallpaper.sh restore")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("udiskie -s &")
    -- The whole desktop, and the notification server: a user service
    -- (system/shell/nikita-shell.service), so systemd brings it back if it goes. It is
    -- started here, once systemd has this session's display and the environment
    -- set above; without the service (an install from before it existed), `qs`
    -- runs directly.
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE "
        .. table.concat(session_env, " ") .. "; systemctl --user start nikita-shell.service || qs")
    -- WirePlumber sometimes starts too early and skips the internal sound card.
    hl.exec_cmd(scripts .. "/audio-check.sh")
end)
