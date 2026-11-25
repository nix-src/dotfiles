-- Бесконечный холст для рабочего стола.
--
--   Super + F                         тайлинг <-> холст (для текущего рабочего стола)
--   Super + средняя кнопка (тянуть)   двигать холст
--   Super + Alt + ЛКМ (тянуть)        двигать холст
--   Super + Alt + стрелки / HJKL      сдвинуть холст на 300px
--   Super + Alt + колесо              прокрутка холста (с Shift — по горизонтали)
--   Super + Alt + C                   центрировать холст на активном окне
--
-- В режиме холста все окна плавающие и могут уходить за пределы экрана,
-- новые окна тоже открываются плавающими. Состояние переживает перезагрузку
-- конфига (хранится в $XDG_RUNTIME_DIR).

local M = {}

local runtime    = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
local state_file = runtime .. "/hypr-canvas"
local bar_file   = runtime .. "/hypr-canvas-bar"

local active = {}          -- [workspace id] = true
local pan    = { timer = nil, x = 0, y = 0 }

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
    local on = ws and ws.id and active[ws.id]
    local f = io.open(bar_file, "w")
    if f then
        f:write(on and "canvas" or "")
        f:close()
    end
    hl.exec_cmd("pkill -RTMIN+8 waybar")
end

------------------------------------------------------------------- утилиты --

local function sel(w) return "address:" .. w.address end

local function current()
    local ws = hl.get_active_workspace()
    if not ws or ws.special or not ws.id then return nil end
    return ws
end

local function windows(ws)
    local out = {}
    for _, w in ipairs(hl.get_windows({ workspace = ws })) do
        if w.mapped and not w.hidden then table.insert(out, w) end
    end
    return out
end

local function shift(ws, dx, dy)
    if dx == 0 and dy == 0 then return end
    for _, w in ipairs(windows(ws)) do
        if w.floating and not w.pinned and (w.fullscreen or 0) == 0 then
            hl.dispatch(hl.dsp.window.move({ x = dx, y = dy, relative = true, window = sel(w) }))
        end
    end
end

----------------------------------------------------------------- переключение --

function M.toggle()
    local ws = current()
    if not ws then return end

    if active[ws.id] then
        active[ws.id] = nil
        for _, w in ipairs(windows(ws)) do
            if w.floating then
                hl.dispatch(hl.dsp.window.float({ action = "disable", window = sel(w) }))
            end
        end
    else
        active[ws.id] = true
        -- Фиксируем текущую раскладку и делаем окна плавающими на тех же местах
        for _, w in ipairs(windows(ws)) do
            if not w.floating and (w.fullscreen or 0) == 0 then
                local x, y, wd, ht = w.at.x, w.at.y, w.size.x, w.size.y
                hl.dispatch(hl.dsp.window.float({ action = "enable", window = sel(w) }))
                hl.dispatch(hl.dsp.window.resize({ x = wd, y = ht, window = sel(w) }))
                hl.dispatch(hl.dsp.window.move({ x = x, y = y, window = sel(w) }))
            end
        end
    end

    save_state()
    update_bar()
end

------------------------------------------------------------------- панорама --

local function set_move_anim(on)
    if on then
        hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "snap" })
    else
        hl.animation({ leaf = "windowsMove", enabled = false })
    end
end

local function super_down()
    return hl.is_key_down("Super_L") or hl.is_key_down("Super_R")
end

function M.pan_stop()
    if pan.timer then pan.timer:set_enabled(false) end
    if pan.dragging then
        pan.dragging = false
        set_move_anim(true)
    end
end

local function pan_tick()
    local ws = current()
    if not ws or not active[ws.id] or not super_down() then
        return M.pan_stop()
    end
    local c = hl.get_cursor_pos()
    if not c then return end
    local dx = math.floor(c.x - pan.x + 0.5)
    local dy = math.floor(c.y - pan.y + 0.5)
    pan.x, pan.y = pan.x + dx, pan.y + dy
    shift(ws, dx, dy)
end

function M.pan_start()
    local ws = current()
    if not ws or not active[ws.id] then return end
    local c = hl.get_cursor_pos()
    if not c then return end
    pan.x, pan.y = c.x, c.y
    pan.dragging = true
    set_move_anim(false)
    if pan.timer then
        pan.timer:set_enabled(true)
    else
        pan.timer = hl.timer(pan_tick, { timeout = 8, type = "repeat" })
    end
end

function M.nudge(dx, dy)
    local ws = current()
    if ws and active[ws.id] then shift(ws, dx, dy) end
end

-- Сдвинуть холст так, чтобы активное окно оказалось в центре монитора
function M.center()
    local ws = current()
    local w = hl.get_active_window()
    if not ws or not active[ws.id] or not w or not w.monitor then return end
    local m = w.monitor
    local dx = math.floor(m.x + m.width / 2 - (w.at.x + w.size.x / 2))
    local dy = math.floor(m.y + m.height / 2 - (w.at.y + w.size.y / 2))
    shift(ws, dx, dy)
end

------------------------------------------------------------------ установка --

function M.setup(mod)
    load_state()

    -- Новые окна на холсте сразу плавающие и по центру
    hl.on("window.open", function(w)
        if not w or not w.workspace or not w.workspace.id then return end
        if active[w.workspace.id] and not w.floating then
            hl.dispatch(hl.dsp.window.float({ action = "enable", window = sel(w) }))
            hl.dispatch(hl.dsp.window.center({ window = sel(w) }))
        end
    end)

    hl.on("workspace.active", function() update_bar() end)
    hl.on("workspace.removed", function()
        -- пустой рабочий стол исчез -> забываем его режим
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
    hl.bind(m .. "F", M.toggle)

    for _, btn in ipairs({ "mouse:274", "ALT + mouse:272" }) do
        hl.bind(m .. btn, M.pan_start)
        hl.bind(m .. btn, M.pan_stop, { release = true })
    end

    local step = 300
    local dirs = {
        { "left", "H", step, 0 }, { "right", "L", -step, 0 },
        { "up",   "K", 0, step }, { "down",  "J", 0, -step },
    }
    for _, d in ipairs(dirs) do
        for _, key in ipairs({ d[1], d[2] }) do
            hl.bind(m .. "ALT + " .. key, function() M.nudge(d[3], d[4]) end, { repeating = true })
        end
    end

    hl.bind(m .. "ALT + mouse_up",           function() M.nudge(0, 120) end)
    hl.bind(m .. "ALT + mouse_down",         function() M.nudge(0, -120) end)
    hl.bind(m .. "ALT + SHIFT + mouse_up",   function() M.nudge(120, 0) end)
    hl.bind(m .. "ALT + SHIFT + mouse_down", function() M.nudge(-120, 0) end)
    hl.bind(m .. "ALT + C",                  M.center)

    update_bar()
end

return M
