-- Бесконечный холст для рабочего стола.
--
--   Super + F                        тайлинг <-> холст (текущий рабочий стол)
--   ЛКМ по пустому месту (тянуть)    двигать холст, после отпускания — докатывается по инерции
--   Super + средняя кнопка (тянуть)  двигать холст, даже если курсор над окном
--   колесо по пустому месту          прокрутка холста (с Shift — по горизонтали)
--   Super + Alt + стрелки / HJKL     плавный сдвиг холста
--   Super + Alt + C                  плавно навести камеру на активное окно
--
-- Холст ограничен: экран не уезжает дальше крайних окон плюс запас PAD.
--
-- При входе в режим холста окна становятся плавающими, чуть уменьшаются и
-- «разъезжаются» от центра, освобождая пространство. Новые окна открываются
-- в центре экрана. Состояние переживает перезагрузку конфига.

local M = {}

-- Значения по умолчанию; переопределяются через окно настроек (M.setup(mod, opts))
local SPREAD   = 1.35   -- во сколько раз растянуть расстояния от центра при входе
local SHRINK   = 0.82   -- масштаб окон при входе
local PAD      = 0.35   -- насколько можно уехать за крайние окна (доля экрана)
local STEP     = 400    -- шаг клавиатурного сдвига, px
local SCROLL   = 90     -- шаг прокрутки колесом, px
local FRICTION = 0.94   -- затухание инерции за тик
local TICK     = 8      -- период таймера, мс

local runtime    = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
local state_file = runtime .. "/hypr-canvas"
local bar_file   = runtime .. "/hypr-canvas-bar"

local active = {}   -- [workspace id] = true
local pan = {
    timer = nil, mode = nil,     -- nil | "drag" | "glide"
    x = 0, y = 0, vx = 0, vy = 0,
    idle = 0,
}

------------------------------------------------------------------ состояние --

local function load_state()
    local f = io.open(state_file, "r")
    if not f then return end
    for line in f:lines() do
        local id = tonumber(line)
        if id then active[id] = true end
    end
    f:close()
end

local function save_state()
    local f = io.open(state_file, "w")
    if not f then return end
    for id in pairs(active) do f:write(id, "\n") end
    f:close()
end

-- Индикатор в waybar (модуль custom/canvas, сигнал 8)
local function update_bar()
    local ws = hl.get_active_workspace()
    local f = io.open(bar_file, "w")
    if f then
        f:write((ws and ws.id and active[ws.id]) and "∞ infinite" or "")
        f:close()
    end
    hl.exec_cmd("pkill -RTMIN+8 waybar")
end

------------------------------------------------------------------- утилиты --

local function sel(w) return "address:" .. w.address end

local function current()
    local ws = hl.get_active_workspace()
    if not ws or ws.special or not ws.id or not active[ws.id] then return nil end
    return ws
end

local function windows(ws)
    local out = {}
    for _, w in ipairs(hl.get_windows({ workspace = ws })) do
        if w.mapped and not w.hidden then table.insert(out, w) end
    end
    return out
end

-- Рабочая область монитора без панелей
local function usable(m)
    local r = type(m.reserved) == "table" and m.reserved or {}
    local top, bottom = r.top or 0, r.bottom or 0
    local left, right = r.left or 0, r.right or 0
    return m.x + left, m.y + top, m.width - left - right, m.height - top - bottom
end

local function over_empty_space()
    local ws = current()
    local c = hl.get_cursor_pos()
    local m = hl.get_active_monitor()
    if not ws or not c or not m then return false end
    local ux, uy, uw, uh = usable(m)
    if c.x < ux or c.y < uy or c.x > ux + uw or c.y > uy + uh then return false end
    for _, w in ipairs(windows(ws)) do
        if c.x >= w.at.x and c.x < w.at.x + w.size.x and c.y >= w.at.y and c.y < w.at.y + w.size.y then
            return false
        end
    end
    return true
end

-- Границы холста: экран не может уехать дальше крайних окон плюс запас PAD.
-- Чем больше окон и чем шире они разложены, тем больше доступное поле.
local function clamp(ws, dx, dy)
    local x1, y1, x2, y2
    for _, w in ipairs(windows(ws)) do
        if w.floating and not w.pinned then
            x1 = math.min(x1 or w.at.x, w.at.x)
            y1 = math.min(y1 or w.at.y, w.at.y)
            x2 = math.max(x2 or w.at.x + w.size.x, w.at.x + w.size.x)
            y2 = math.max(y2 or w.at.y + w.size.y, w.at.y + w.size.y)
        end
    end
    if not x1 then return 0, 0 end
    local ux, uy, uw, uh = usable(hl.get_active_monitor())

    -- Допустимый диапазон сдвига по оси: если содержимое (с запасом) шире экрана —
    -- экран остаётся внутри него, если уже — содержимое остаётся внутри экрана.
    -- Ноль всегда разрешён, чтобы не дёргать холст, уже стоящий за границей.
    local function axis(d, lo, hi, vlo, vlen, pad)
        local a, b = (vlo + vlen) - (hi + pad), vlo - (lo - pad)
        local min_d, max_d = math.min(a, b, 0), math.max(a, b, 0)
        return math.max(min_d, math.min(max_d, d))
    end
    return math.floor(axis(dx, x1, x2, ux, uw, uw * PAD)),
           math.floor(axis(dy, y1, y2, uy, uh, uh * PAD))
end

-- Сдвинуть все окна холста; возвращает фактический сдвиг (с учётом границ)
local function shift(ws, dx, dy)
    dx, dy = clamp(ws, dx, dy)
    if dx == 0 and dy == 0 then return 0, 0 end
    for _, w in ipairs(windows(ws)) do
        if w.floating and not w.pinned and (w.fullscreen or 0) == 0 then
            hl.dispatch(hl.dsp.window.move({ x = dx, y = dy, relative = true, window = sel(w) }))
        end
    end
    return dx, dy
end

local function set_move_anim(on)
    if on then
        hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "snap" })
    else
        hl.animation({ leaf = "windowsMove", enabled = false })
    end
end

----------------------------------------------------------------- переключение --

function M.toggle()
    local ws = hl.get_active_workspace()
    if not ws or ws.special or not ws.id then return end

    if active[ws.id] then
        active[ws.id] = nil
        for _, w in ipairs(windows(ws)) do
            if w.floating then
                hl.dispatch(hl.dsp.window.float({ action = "disable", window = sel(w) }))
            end
        end
    else
        active[ws.id] = true
        local m = hl.get_active_monitor()
        local ux, uy, uw, uh = usable(m)
        local cx, cy = ux + uw / 2, uy + uh / 2
        -- Сначала снимаем геометрию всех окон: свойства читаются «вживую»,
        -- а после всплытия первого окна остальные перестраиваются.
        local plan = {}
        for _, w in ipairs(windows(ws)) do
            if not w.floating and (w.fullscreen or 0) == 0 then
                local wcx, wcy = w.at.x + w.size.x / 2, w.at.y + w.size.y / 2
                local nw = math.floor(w.size.x * SHRINK)
                local nh = math.floor(w.size.y * SHRINK)
                table.insert(plan, {
                    sel = sel(w), w = nw, h = nh,
                    x = math.floor(cx + (wcx - cx) * SPREAD - nw / 2),
                    y = math.floor(cy + (wcy - cy) * SPREAD - nh / 2),
                })
            end
        end
        -- окна разъезжаются от центра экрана и чуть уменьшаются
        for _, p in ipairs(plan) do
            hl.dispatch(hl.dsp.window.float({ action = "enable", window = p.sel }))
            hl.dispatch(hl.dsp.window.resize({ x = p.w, y = p.h, window = p.sel }))
            hl.dispatch(hl.dsp.window.move({ x = p.x, y = p.y, window = p.sel }))
        end
    end

    save_state()
    update_bar()
    if _G.wallpaper_refresh then _G.wallpaper_refresh() end
end

function M.is_active(id) return active[id] == true end

------------------------------------------------------------------- панорама --

local function stop()
    if pan.timer then pan.timer:set_enabled(false) end
    if pan.mode then set_move_anim(true) end
    pan.mode = nil
    pan.vx, pan.vy = 0, 0
end

local function tick()
    local ws = current()
    if not ws then return stop() end

    if pan.mode == "drag" then
        local c = hl.get_cursor_pos()
        if not c then return end
        local dx = math.floor(c.x - pan.x + 0.5)
        local dy = math.floor(c.y - pan.y + 0.5)
        pan.x, pan.y = pan.x + dx, pan.y + dy
        -- сглаженная скорость для инерции
        pan.vx = pan.vx * 0.8 + dx * 0.2
        pan.vy = pan.vy * 0.8 + dy * 0.2
        if dx == 0 and dy == 0 then
            pan.idle = pan.idle + TICK
            -- страховка: если отпускание кнопки потерялось
            if pan.idle > 1500 then return stop() end
        else
            pan.idle = 0
            shift(ws, dx, dy)
        end
    elseif pan.mode == "glide" then
        pan.vx, pan.vy = pan.vx * FRICTION, pan.vy * FRICTION
        local dx, dy = math.floor(pan.vx + 0.5), math.floor(pan.vy + 0.5)
        if math.abs(pan.vx) < 0.6 and math.abs(pan.vy) < 0.6 then return stop() end
        local ax, ay = shift(ws, dx, dy)
        -- упёрлись в границу — гасим инерцию по этой оси
        if ax ~= dx then pan.vx = 0 end
        if ay ~= dy then pan.vy = 0 end
    else
        stop()
    end
end

local function start_drag()
    local c = hl.get_cursor_pos()
    if not c then return end
    pan.x, pan.y, pan.vx, pan.vy, pan.idle = c.x, c.y, 0, 0, 0
    pan.mode = "drag"
    set_move_anim(false)
    if pan.timer then
        pan.timer:set_enabled(true)
    else
        pan.timer = hl.timer(tick, { timeout = TICK, type = "repeat" })
    end
end

local function release()
    if pan.mode ~= "drag" then return end
    if math.abs(pan.vx) > 1.5 or math.abs(pan.vy) > 1.5 then
        pan.mode = "glide"
    else
        stop()
    end
end

-- ЛКМ по пустому месту: клик всё равно проходит дальше (non_consuming)
function M.press_empty()
    if pan.mode == "glide" then stop() end
    if over_empty_space() then start_drag() end
end

-- Super + средняя кнопка: тянуть откуда угодно
function M.press_any()
    if pan.mode == "glide" then stop() end
    if current() then start_drag() end
end

M.release = release

-- Плавный сдвиг с анимацией окон
function M.nudge(dx, dy)
    local ws = current()
    if ws then
        stop()
        shift(ws, dx, dy)
    end
end

function M.scroll(dx, dy)
    if over_empty_space() then M.nudge(dx, dy) end
end

-- Навести камеру на активное окно
function M.center()
    local ws = current()
    local w = hl.get_active_window()
    if not ws or not w then return end
    local ux, uy, uw, uh = usable(hl.get_active_monitor())
    stop()
    shift(ws, math.floor(ux + uw / 2 - (w.at.x + w.size.x / 2)),
              math.floor(uy + uh / 2 - (w.at.y + w.size.y / 2)))
end

------------------------------------------------------------------ установка --

function M.setup(mod, opts)
    opts = opts or {}
    SPREAD   = tonumber(opts.spread)   or SPREAD
    SHRINK   = tonumber(opts.shrink)   or SHRINK
    PAD      = tonumber(opts.pad)      or PAD
    FRICTION = tonumber(opts.friction) or FRICTION
    load_state()

    -- Новые окна на холсте — плавающие, в центре экрана
    hl.on("window.open", function(w)
        if not w or not w.workspace or not w.workspace.id then return end
        if active[w.workspace.id] and not w.floating then
            hl.dispatch(hl.dsp.window.float({ action = "enable", window = sel(w) }))
            hl.dispatch(hl.dsp.window.center({ window = sel(w) }))
        end
    end)

    hl.on("workspace.active", function()
        stop()
        update_bar()
    end)

    hl.on("workspace.removed", function()
        local alive = {}
        for _, ws in ipairs(hl.get_workspaces()) do
            if ws.id then alive[ws.id] = true end
        end
        for id in pairs(active) do
            if not alive[id] then active[id] = nil end
        end
        save_state()
    end)

    local m = mod .. " + "
    local pass = { non_consuming = true }
    local pass_up = { non_consuming = true, release = true }

    hl.bind(m .. "F", M.toggle)

    hl.bind("mouse:272", M.press_empty, pass)
    hl.bind("mouse:272", M.release, pass_up)
    hl.bind(m .. "mouse:274", M.press_any)
    hl.bind(m .. "mouse:274", M.release, { release = true })

    hl.bind("mouse_up",           function() M.scroll(0, SCROLL) end, pass)
    hl.bind("mouse_down",         function() M.scroll(0, -SCROLL) end, pass)
    hl.bind("SHIFT + mouse_up",   function() M.scroll(SCROLL, 0) end, pass)
    hl.bind("SHIFT + mouse_down", function() M.scroll(-SCROLL, 0) end, pass)

    local dirs = {
        { "left", "H", STEP, 0 }, { "right", "L", -STEP, 0 },
        { "up",   "K", 0, STEP }, { "down",  "J", 0, -STEP },
    }
    for _, d in ipairs(dirs) do
        for _, key in ipairs({ d[1], d[2] }) do
            hl.bind(m .. "ALT + " .. key, function() M.nudge(d[3], d[4]) end, { repeating = true })
        end
    end
    hl.bind(m .. "ALT + C", M.center)

    update_bar()
end

return M
