-- Hyprland (>= 0.57, Lua config)
-- Монохром, без скруглений, без blur и теней.

local terminal    = "kitty"
local fileManager = "thunar"
local menu        = "fuzzel"
local scripts     = os.getenv("HOME") .. "/.config/hypr/scripts"
local mod         = "SUPER"

----------------
--  MONITORS  --
----------------

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

-----------------
--  AUTOSTART  --
-----------------

hl.on("hyprland.start", function()
    hl.exec_cmd("uwsm app -- waybar")
    hl.exec_cmd("uwsm app -- mako")
    hl.exec_cmd("uwsm app -- hypridle")
    hl.exec_cmd("uwsm app -- wl-paste --type text --watch cliphist store")
    hl.exec_cmd("uwsm app -- wl-paste --type image --watch cliphist store")
end)

-- Остальные переменные окружения — в ~/.config/uwsm/env
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

---------------------
--  LOOK AND FEEL  --
---------------------

hl.config({
    general = {
        gaps_in     = 3,
        gaps_out    = 6,
        border_size = 1,
        col = {
            active_border   = "rgba(8a8a8aff)",
            inactive_border = "rgba(222222ff)",
        },
        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding         = 0,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        shadow = { enabled = false },
        blur   = { enabled = false },
    },

    animations = { enabled = true },

    dwindle = { preserve_split = true },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        background_color         = "rgb(0c0c0c)",
        focus_on_activate        = true,
        middle_click_paste       = false,
    },

    input = {
        kb_layout    = "us,ru",
        kb_options   = "grp:alt_shift_toggle",
        follow_mouse = 1,
        sensitivity  = 0,
        repeat_rate  = 35,
        repeat_delay = 250,
        touchpad = { natural_scroll = true },
    },

    binds = { workspace_back_and_forth = true },
})

-- Короткие и быстрые анимации
hl.curve("snap", { type = "bezier", points = { {0.2, 1}, {0.3, 1} } })
hl.animation({ leaf = "global",     enabled = true, speed = 3,   bezier = "snap" })
hl.animation({ leaf = "windows",    enabled = true, speed = 3,   bezier = "snap", style = "popin 95%" })
hl.animation({ leaf = "fade",       enabled = true, speed = 2.5, bezier = "snap" })
hl.animation({ leaf = "border",     enabled = true, speed = 3,   bezier = "snap" })
hl.animation({ leaf = "layers",     enabled = true, speed = 2.5, bezier = "snap", style = "fade" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.5, bezier = "snap", style = "fade" })

-------------------
--  KEYBINDINGS  --
-------------------

local function bind(keys, dsp, opts) hl.bind(keys, dsp, opts) end
local function exec(cmd) return hl.dsp.exec_cmd(cmd) end

-- Приложения
bind(mod .. " + Return",         exec(terminal))
bind(mod .. " + D",              exec(menu))
bind(mod .. " + E",              exec(fileManager))
bind(mod .. " + B",              exec("firefox"))
bind(mod .. " + C",              exec(scripts .. "/clipboard"))
bind(mod .. " + N",              exec("makoctl dismiss --all"))

-- Сессия
bind(mod .. " + Escape",         exec("loginctl lock-session"))
bind(mod .. " + SHIFT + Escape", exec(scripts .. "/powermenu"))
bind(mod .. " + SHIFT + R",      hl.dsp.reload_config())

-- Окна
bind(mod .. " + Q",              hl.dsp.window.close())
bind(mod .. " + F",              hl.dsp.window.fullscreen())
bind(mod .. " + SHIFT + F",      hl.dsp.window.fullscreen({ mode = "maximized" }))
bind(mod .. " + V",              hl.dsp.window.float({ action = "toggle" }))
bind(mod .. " + P",              hl.dsp.window.pseudo())
bind(mod .. " + T",              hl.dsp.layout("togglesplit"))

-- Фокус / перемещение / размер: стрелки и hjkl
local dirs = {
    { "left",  "H", "l", -40,   0 },
    { "right", "L", "r",  40,   0 },
    { "up",    "K", "u",   0, -40 },
    { "down",  "J", "d",   0,  40 },
}
for _, d in ipairs(dirs) do
    for _, key in ipairs({ d[1], d[2] }) do
        bind(mod .. " + " .. key,            hl.dsp.focus({ direction = d[3] }))
        bind(mod .. " + SHIFT + " .. key,    hl.dsp.window.move({ direction = d[3] }))
        bind(mod .. " + CTRL + " .. key,     hl.dsp.window.resize({ x = d[4], y = d[5], relative = true }), { repeating = true })
    end
end

-- Рабочие столы 1..10
for i = 1, 10 do
    local key = i % 10
    bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
bind(mod .. " + Tab",          hl.dsp.focus({ workspace = "previous" }))
bind(mod .. " + mouse_down",   hl.dsp.focus({ workspace = "e+1" }))
bind(mod .. " + mouse_up",     hl.dsp.focus({ workspace = "e-1" }))

-- Scratchpad
bind(mod .. " + S",            hl.dsp.workspace.toggle_special("scratch"))
bind(mod .. " + SHIFT + S",    hl.dsp.window.move({ workspace = "special:scratch" }))

-- Мышь
bind(mod .. " + mouse:272",    hl.dsp.window.drag(),   { mouse = true })
bind(mod .. " + mouse:273",    hl.dsp.window.resize(), { mouse = true })

-- Скриншоты / пипетка
bind("Print",                  exec(scripts .. "/screenshot area"))
bind("SHIFT + Print",          exec(scripts .. "/screenshot screen"))
bind(mod .. " + Print",        exec("hyprpicker -a"))

-- Мультимедиа
local locked_rep = { locked = true, repeating = true }
bind("XF86AudioRaiseVolume",  exec("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), locked_rep)
bind("XF86AudioLowerVolume",  exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      locked_rep)
bind("XF86AudioMute",         exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
bind("XF86AudioMicMute",      exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
bind("XF86MonBrightnessUp",   exec("brightnessctl -e4 -n2 set 5%+"),                  locked_rep)
bind("XF86MonBrightnessDown", exec("brightnessctl -e4 -n2 set 5%-"),                  locked_rep)
bind("XF86AudioNext",         exec("playerctl next"),       { locked = true })
bind("XF86AudioPrev",         exec("playerctl previous"),   { locked = true })
bind("XF86AudioPlay",         exec("playerctl play-pause"), { locked = true })
bind("XF86AudioPause",        exec("playerctl play-pause"), { locked = true })

--------------------
--  WINDOW RULES  --
--------------------

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- Утилиты открываются плавающими по центру
hl.window_rule({
    name  = "float-utils",
    match = { class = "^(float|org\\.pulseaudio\\.pavucontrol|nm-connection-editor|blueman-manager|xdg-desktop-portal-gtk|hyprland-run)$" },
    float  = true,
    size   = "900 600",
    center = true,
})

hl.window_rule({
    name  = "float-dialogs",
    match = { title = "^(Open File|Save File|Open Folder|Select a File|File Operation Progress|Confirm to replace files)(.*)$" },
    float  = true,
    center = true,
})
