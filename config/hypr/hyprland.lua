-- Hyprland (>= 0.57, Lua config)
-- Монохром, без скруглений, без blur и теней.

local hyprdir = (debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) or (os.getenv("HOME") .. "/.config/hypr")
package.path = hyprdir .. "/?.lua;" .. package.path

----------------
--  SETTINGS  --
----------------

-- Значения по умолчанию. Окно настроек (Super + I) сохраняет изменения в
-- ~/.config/dotfiles-local/settings.lua — этот файл не в репозитории.
local S = {
    monitors       = {},            -- [output] = { mode =, position =, scale = }
    kb_layout      = "us,ru",
    kb_options     = "grp:alt_shift_toggle",
    sensitivity    = 0,
    accel_flat     = false,
    natural_scroll = false,
    repeat_rate    = 35,
    repeat_delay   = 250,
    gaps_in        = 4,
    gaps_out       = 8,
    border_size    = 1,
    animations     = true,
    border_anim    = true,
    dim_inactive   = true,
    terminal       = "kitty",
    browser        = "firefox",
    files          = "thunar",
    canvas         = {},            -- spread, shrink, pad, friction
    game_tearing   = true,          -- игры: кадр сразу на экран, без ожидания vsync
    game_classes   = "",            -- доп. классы окон игр (regex через |)
}
local local_dir = os.getenv("HOME") .. "/.config/dotfiles-local"
do
    local ok, user = pcall(dofile, local_dir .. "/settings.lua")
    if ok and type(user) == "table" then
        for k, v in pairs(user) do S[k] = v end
    end
end

local terminal    = S.terminal
local fileManager = S.files
local browser     = S.browser
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
for name, m in pairs(S.monitors) do
    hl.monitor({
        output   = name,
        mode     = m.mode or "preferred",
        position = m.position or "auto",
        scale    = tonumber(m.scale) or 1,
    })
end

-----------------
--  AUTOSTART  --
-----------------

-- Сеанс может быть запущен как через uwsm («Hyprland (uwsm-managed)» в SDDM),
-- так и напрямую. Через uwsm программы запускаются как systemd-юниты.
local UWSM = os.getenv("UWSM_FINALIZE_VARNAMES") ~= nil
local function app(cmd) return UWSM and ("uwsm app -- " .. cmd) or cmd end

hl.on("hyprland.start", function()
    hl.exec_cmd(app(scripts .. "/wallpaper"))
    hl.exec_cmd(app(scripts .. "/bar"))
    hl.exec_cmd(app(scripts .. "/player"))
    hl.exec_cmd(app("mako"))
    hl.exec_cmd(app(scripts .. "/idle"))
    hl.exec_cmd(app("wl-paste --type text --watch cliphist store"))
    hl.exec_cmd(app("wl-paste --type image --watch cliphist store"))
    -- В uwsm-сеансе polkit-агент запускает systemd (hyprpolkitagent.service)
    if not UWSM then
        hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")
    end
end)

-- Переменные окружения. В uwsm-сеансе они же берутся из ~/.config/uwsm/env;
-- здесь — чтобы всё работало и в сеансе без uwsm.
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

---------------------
--  LOOK AND FEEL  --
---------------------

hl.config({
    general = {
        gaps_in     = S.gaps_in,
        gaps_out    = S.gaps_out,
        border_size = S.border_size,
        col = {
            active_border   = { colors = { "rgba(b0b0b0ff)", "rgba(3a3a3aff)", "rgba(b0b0b0ff)" }, angle = 45 },
            inactive_border = "rgba(1e1e1eff)",
        },
        resize_on_border = true,
        layout           = "dwindle",      -- allow_tearing задаётся в разделе «Игры»
    },

    decoration = {
        rounding         = 0,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        dim_inactive     = S.dim_inactive,
        dim_strength     = 0.12,
        dim_special      = 0.4,
        shadow = { enabled = false },
        blur   = { enabled = false },
    },

    animations = { enabled = S.animations },

    dwindle = { preserve_split = true },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        background_color         = "rgb(0b0b0b)",
        focus_on_activate        = true,
        middle_click_paste       = false,
        float_force_onscreen     = 0,
    },

    input = {
        kb_layout     = S.kb_layout,
        kb_options    = S.kb_options,
        follow_mouse  = 1,
        sensitivity   = S.sensitivity,
        accel_profile = S.accel_flat and "flat" or "adaptive",
        natural_scroll = S.natural_scroll,
        repeat_rate   = S.repeat_rate,
        repeat_delay  = S.repeat_delay,
        touchpad = { natural_scroll = true },
    },

    binds = { workspace_back_and_forth = true },
})

-- NVIDIA: программный курсор, если аппаратный глючит
local nv = io.open("/proc/driver/nvidia/version", "r")
if nv then
    nv:close()
    hl.config({ cursor = { no_hardware_cursors = 1 } })
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND", "direct")
end

----------------
--  ANIMATIONS --
----------------

hl.curve("snap",   { type = "bezier", points = { {0.2, 1},   {0.3, 1}    } })
hl.curve("over",   { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.06} } })
hl.curve("smooth", { type = "bezier", points = { {0.4, 0},   {0.2, 1}    } })
hl.curve("linear", { type = "bezier", points = { {0, 0},     {1, 1}      } })

hl.animation({ leaf = "global",           enabled = true, speed = 4,   bezier = "snap" })
hl.animation({ leaf = "windowsIn",        enabled = true, speed = 4,   bezier = "over",   style = "popin 80%" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 3,   bezier = "snap",   style = "popin 85%" })
hl.animation({ leaf = "windowsMove",      enabled = true, speed = 4,   bezier = "snap" })
hl.animation({ leaf = "fadeIn",           enabled = true, speed = 3,   bezier = "snap" })
hl.animation({ leaf = "fadeOut",          enabled = true, speed = 3,   bezier = "snap" })
hl.animation({ leaf = "fadeDim",          enabled = true, speed = 4,   bezier = "smooth" })
hl.animation({ leaf = "border",           enabled = true, speed = 5,   bezier = "smooth" })
hl.animation({ leaf = "borderangle",      enabled = S.border_anim, speed = 60,  bezier = "linear", style = "loop" })
hl.animation({ leaf = "layersIn",         enabled = true, speed = 3,   bezier = "over",   style = "slide" })
hl.animation({ leaf = "layersOut",        enabled = true, speed = 2.5, bezier = "snap",   style = "fade" })
hl.animation({ leaf = "fadeLayersIn",     enabled = true, speed = 1.5, bezier = "linear" })
hl.animation({ leaf = "fadeLayersOut",    enabled = true, speed = 1.5, bezier = "linear" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 4,   bezier = "smooth", style = "slidefade 12%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4,   bezier = "over",   style = "slidefadevert 20%" })

hl.layer_rule({ name = "launcher-anim",      match = { namespace = "^launcher$" },      animation = "popin 90%" })
hl.layer_rule({ name = "notifications-anim", match = { namespace = "^notifications$" }, animation = "slide right" })
hl.layer_rule({ name = "miniplayer-anim",     match = { namespace = "^miniplayer$" },    animation = "slide top" })
hl.layer_rule({ name = "wallpaper-no-anim",  match = { namespace = "^mpvpaper$" },      no_anim = true })

-------------------
--  KEYBINDINGS  --
-------------------

local function bind(keys, dsp, opts) hl.bind(keys, dsp, opts) end
local function exec(cmd) return hl.dsp.exec_cmd(cmd) end

-- Приложения
bind(mod .. " + Return",         exec(terminal))
bind(mod .. " + D",              exec(menu))
bind(mod .. " + E",              exec(fileManager))
bind(mod .. " + B",              exec(browser))
bind(mod .. " + I",              exec(scripts .. "/ui settings"))
bind(mod .. " + C",              exec(scripts .. "/clipboard"))
bind(mod .. " + N",              exec("makoctl dismiss --all"))

-- Сессия
bind(mod .. " + Escape",         exec(scripts .. "/lock"))
bind(mod .. " + SHIFT + Escape", exec(scripts .. "/powermenu"))
bind(mod .. " + SHIFT + R",      hl.dsp.reload_config())

-- Окна
bind(mod .. " + Q",              hl.dsp.window.close())
bind(mod .. " + SHIFT + F",      hl.dsp.window.fullscreen())
bind(mod .. " + M",              hl.dsp.window.fullscreen({ mode = "maximized" }))
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
        bind(mod .. " + " .. key,         hl.dsp.focus({ direction = d[3] }))
        bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = d[3] }))
        bind(mod .. " + CTRL + " .. key,  hl.dsp.window.resize({ x = d[4], y = d[5], relative = true }), { repeating = true })
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

-- Бесконечный холст (Super + F и панорамирование) — см. canvas.lua
local canvas = require("canvas")
canvas.setup(mod, S.canvas)

---------------------------------
--  ВИДЕООБОИ: ТОЛЬКО КОГДА ВИДНО  --
---------------------------------

-- Видео (mpvpaper) стоит ~8% CPU и заставляет Hyprland перерисовывать экран.
-- Пока на экране есть окна, обои почти не видны — процесс замораживается
-- (SIGSTOP, на экране остаётся последний кадр) и оживает на пустом рабочем
-- столе или в режиме холста.
local function wallpaper_visible()
    for _, m in ipairs(hl.get_monitors()) do
        local ws = m.active_workspace
        if ws and ws.id and not ws.special then
            if canvas.is_active(ws.id) then return true end
            local empty = true
            for _, w in ipairs(hl.get_windows({ workspace = ws })) do
                if w.mapped and not w.hidden then empty = false break end
            end
            if empty then return true end
        end
    end
    return false
end

local wallpaper_state = nil
function _G.wallpaper_refresh(force)
    local run = wallpaper_visible()
    if force or run ~= wallpaper_state then
        wallpaper_state = run
        hl.exec_cmd(run and "pkill -CONT -x mpvpaper" or "pkill -STOP -x mpvpaper")
    end
end

-- События приходят до того, как список окон обновится, — проверяем чуть позже
local function wallpaper_soon()
    if #hl.get_monitors() == 0 then return end
    hl.timer(function() _G.wallpaper_refresh() end, { timeout = 60, type = "oneshot" })
end
for _, ev in ipairs({ "workspace.active", "monitor.focused", "window.open", "window.close",
                      "window.destroy", "window.move_to_workspace" }) do
    hl.on(ev, wallpaper_soon)
end
-- после перезагрузки конфига состояние неизвестно — проверяем заново
-- (при старте сеанса это делает сам скрипт обоев)
hl.on("config.reloaded", function()
    -- без мониторов (например, при hyprland --verify-config) ничего не трогаем
    if #hl.get_monitors() > 0 then _G.wallpaper_refresh(true) end
end)

-------------
--  ИГРЫ  --
-------------

-- В Wayland нет «эксклюзивного» полноэкранного режима, как в Windows: игра всегда
-- выводится через композитор, а он по умолчанию ждёт vsync — отсюда задержка.
-- Для окон игр:
--   immediate      — tearing: кадр уходит на экран сразу, без ожидания vsync
--                    (действует для полноэкранного окна, как настоящий fullscreen);
--   content=game   — с render.direct_scanout = 2 полноэкранная игра выводится
--                    на экран напрямую, минуя композитинг;
--   idle_inhibit   — экран не гаснет и не блокируется во время игры.
-- CS2 (нативный), игры Steam/Proton (steam_app_*), gamescope, игры Wine (*.exe).
local games = "cs2|steam_app_[0-9]+|gamescope|.+\\.exe"
if S.game_classes ~= "" then games = games .. "|" .. S.game_classes end

hl.config({
    general = { allow_tearing = S.game_tearing },
    render  = { direct_scanout = 2 },   -- только для окон с типом содержимого «игра»
    misc    = { vrr = 2 },              -- адаптивная синхронизация в полноэкранных играх
})

hl.window_rule({
    name         = "games",
    match        = { class = "^(" .. games .. ")$" },
    immediate    = S.game_tearing,
    content      = "game",
    idle_inhibit = "always",
})

-- Видео в полноэкранном режиме тоже не даёт экрану гаснуть
hl.window_rule({
    name         = "fullscreen-no-idle",
    match        = { fullscreen = true },
    idle_inhibit = "fullscreen",
})

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
    match = { class = "^(float|dotfiles\\.settings|dotfiles\\.shell|org\\.pulseaudio\\.pavucontrol|nm-connection-editor|blueman-manager|xdg-desktop-portal-gtk|hyprland-run)$" },
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
