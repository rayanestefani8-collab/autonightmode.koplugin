--[[--
    Auto Night Mode — plugin para KOReader
    Funciona em qualquer launcher. Menu em: Configurações → Tela → Auto Night Mode

    @module koplugin.AutoNightMode
--]]--

local Device          = require("device")
local Event           = require("ui/event")
local InfoMessage     = require("ui/widget/infomessage")
local LuaSettings     = require("luasettings")
local SpinWidget      = require("ui/widget/spinwidget")
local UIManager       = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _               = require("gettext")
local logger          = require("logger")
local DataStorage     = require("datastorage")

local settings_file   = DataStorage:getSettingsDir() .. "/autonightmode.lua"

-- Chama um método do Device com segurança — retorna false se não existir
local function deviceCan(method)
    local ok, result = pcall(function() return Device[method](Device) end)
    return ok and result == true
end

local AutoNightMode = WidgetContainer:extend{
    name        = "autonightmode",
    is_doc_only = false,
    _defaults = {
        enabled          = false,
        on_hour          = 20,
        on_min           = 0,
        off_hour         = 7,
        off_min          = 0,
        night_warmth     = -1,
        day_warmth       = -1,
        night_brightness = -1,
        day_brightness   = -1,
        notify           = true,
    },
}

-- ─── Init ─────────────────────────────────────────────────────────────────────
function AutoNightMode:init()
    self.settings = LuaSettings:open(settings_file)
    self.ui.menu:registerToMainMenu(self)
    UIManager:scheduleIn(3, function() self:startLoop() end)
    logger.dbg("AutoNightMode: init")
end

-- ─── Settings helpers ─────────────────────────────────────────────────────────
function AutoNightMode:get(key)
    local v = self.settings:readSetting(key)
    if v == nil then return self._defaults[key] end
    return v
end

function AutoNightMode:set(key, value)
    self.settings:saveSetting(key, value)
    self.settings:flush()
end

-- ─── Schedule logic ───────────────────────────────────────────────────────────
local function toMin(h, m) return h * 60 + m end
local function nowMin()
    local t = os.date("*t")
    return t.hour * 60 + t.min
end

function AutoNightMode:isNightNow()
    local on_m  = toMin(self:get("on_hour"),  self:get("on_min"))
    local off_m = toMin(self:get("off_hour"), self:get("off_min"))
    local now   = nowMin()
    if on_m == off_m then return false end
    if on_m < off_m then
        return now >= on_m and now < off_m
    else
        return now >= on_m or now < off_m
    end
end

-- ─── Toggle night mode — usa o evento oficial do DeviceListener ───────────────
-- DeviceListener:onSetNightMode(bool) chama Screen:toggleNightMode(),
-- UIManager:ToggleNightMode() e salva em G_reader_settings corretamente.
function AutoNightMode:setNightMode(enable)
    self.ui:handleEvent(Event:new("SetNightMode", enable))
end

-- ─── Apply mode ───────────────────────────────────────────────────────────────
function AutoNightMode:applyMode(night, force)
    local current_night = G_reader_settings:isTrue("night_mode")
    logger.dbg("AutoNightMode: applyMode night=", tostring(night), "current=", tostring(current_night), "force=", tostring(force))

    if not force and (night == current_night) then return end

    -- 1. Night mode via evento oficial
    if night ~= current_night then
        self:setNightMode(night)
        logger.dbg("AutoNightMode: SetNightMode →", tostring(night))
    end

    -- 2. Warmth
    local warmth_target = night and self:get("night_warmth") or self:get("day_warmth")
    if warmth_target >= 0 and deviceCan("hasNaturalLight") then
        local powerd = Device:getPowerDevice()
        if powerd and powerd.setWarmth then
            powerd:setWarmth(math.max(0, math.min(100, warmth_target)))
            logger.dbg("AutoNightMode: warmth →", warmth_target)
        end
    end

    -- 3. Brilho
    local brightness_target = night and self:get("night_brightness") or self:get("day_brightness")
    if brightness_target >= 0 and deviceCan("hasFrontlight") then
        local powerd = Device:getPowerDevice()
        if powerd and powerd.setIntensity then
            powerd:setIntensity(math.max(0, math.min(100, brightness_target)))
            logger.dbg("AutoNightMode: brightness →", brightness_target)
        end
    end

    -- 4. Notificação
    if self:get("notify") then
        local msg = night
            and _("Modo noturno ativado automaticamente.")
            or  _("Modo diurno ativado automaticamente.")
        UIManager:show(InfoMessage:new{ text = msg, timeout = 2 })
    end
end

-- ─── Check loop ───────────────────────────────────────────────────────────────
function AutoNightMode:check()
    if not self:get("enabled") then return end
    self:applyMode(self:isNightNow())
end

function AutoNightMode:startLoop()
    self:check()
    self._check_task = function()
        self:check()
        UIManager:scheduleIn(60, self._check_task)
    end
    UIManager:scheduleIn(60, self._check_task)
end

function AutoNightMode:onCloseWidget()
    if self._check_task then
        UIManager:unschedule(self._check_task)
    end
end

-- ─── Menu (Configurações → Tela) ──────────────────────────────────────────────
function AutoNightMode:addToMainMenu(menu_items)
    menu_items.autonightmode = {
        text         = _("Auto Night Mode"),
        sorting_hint = "screen",
        sub_item_table_func = function() return self:buildMenu() end,
    }
end

function AutoNightMode:buildMenu()
    local has_warmth = deviceCan("hasNaturalLight")
    local has_fl     = deviceCan("hasFrontlight")

    local function fmtTime(h_key, m_key)
        return string.format("%02d:%02d", self:get(h_key), self:get(m_key))
    end

    local function showTimePicker(title_h, title_m, h_key, m_key)
        UIManager:show(SpinWidget:new{
            title_text    = title_h,
            value         = self:get(h_key),
            value_min     = 0,
            value_max     = 23,
            value_step    = 1,
            default_value = self._defaults[h_key],
            callback      = function(spin)
                self:set(h_key, spin.value)
                UIManager:show(SpinWidget:new{
                    title_text    = title_m,
                    value         = self:get(m_key),
                    value_min     = 0,
                    value_max     = 55,
                    value_step    = 5,
                    default_value = self._defaults[m_key],
                    callback      = function(spin2)
                        self:set(m_key, spin2.value)
                    end,
                })
            end,
        })
    end

    local menu = {
        -- Toggle principal
        {
            text_func    = function()
                return self:get("enabled")
                    and _("Agendamento: ativado")
                    or  _("Agendamento: desativado")
            end,
            checked_func = function() return self:get("enabled") end,
            callback     = function()
                local new = not self:get("enabled")
                self:set("enabled", new)
                if new then
                    self:applyMode(self:isNightNow(), true)
                end
            end,
            keep_menu_open = true,
        },
        -- Hora de ligar
        {
            text_func = function()
                return _("Liga o modo noturno às: ") .. fmtTime("on_hour", "on_min")
            end,
            callback  = function()
                showTimePicker(
                    _("Hora — ligar modo noturno"),
                    _("Minuto — ligar modo noturno"),
                    "on_hour", "on_min"
                )
            end,
            keep_menu_open = true,
        },
        -- Hora de desligar
        {
            text_func = function()
                return _("Desliga o modo noturno às: ") .. fmtTime("off_hour", "off_min")
            end,
            callback  = function()
                showTimePicker(
                    _("Hora — desligar modo noturno"),
                    _("Minuto — desligar modo noturno"),
                    "off_hour", "off_min"
                )
            end,
            keep_menu_open = true,
        },
    }

    -- Warmth
    if has_warmth then
        local function wLabel(key)
            local v = self:get(key)
            return v < 0 and _("(não alterar)") or (tostring(v) .. "%")
        end

        table.insert(menu, {
            text_func = function()
                return _("Temperatura noturna: ") .. wLabel("night_warmth")
            end,
            callback = function()
                UIManager:show(SpinWidget:new{
                    title_text    = _("Temperatura noturna (0=frio … 100=quente)"),
                    value         = math.max(0, self:get("night_warmth")),
                    value_min     = 0,
                    value_max     = 100,
                    value_step    = 5,
                    default_value = 80,
                    callback      = function(spin) self:set("night_warmth", spin.value) end,
                })
            end,
            keep_menu_open = true,
        })

        table.insert(menu, {
            text_func = function()
                return _("Temperatura diurna: ") .. wLabel("day_warmth")
            end,
            callback = function()
                UIManager:show(SpinWidget:new{
                    title_text    = _("Temperatura diurna (0=frio … 100=quente)"),
                    value         = math.max(0, self:get("day_warmth")),
                    value_min     = 0,
                    value_max     = 100,
                    value_step    = 5,
                    default_value = 20,
                    callback      = function(spin) self:set("day_warmth", spin.value) end,
                })
            end,
            keep_menu_open = true,
        })

        table.insert(menu, {
            text_func = function()
                local off = self:get("night_warmth") < 0 and self:get("day_warmth") < 0
                return off and _("Controle de temperatura: desativado")
                           or _("Controle de temperatura: ativado")
            end,
            callback = function()
                local off = self:get("night_warmth") < 0 and self:get("day_warmth") < 0
                if off then
                    self:set("night_warmth", 80)
                    self:set("day_warmth",   20)
                else
                    self:set("night_warmth", -1)
                    self:set("day_warmth",   -1)
                end
            end,
            keep_menu_open = true,
        })
    end

    -- Brilho
    if has_fl then
        local function bLabel(key)
            local v = self:get(key)
            return v < 0 and _("(não alterar)") or (tostring(v) .. "%")
        end

        table.insert(menu, {
            text_func = function()
                return _("Brilho noturno: ") .. bLabel("night_brightness")
            end,
            callback = function()
                UIManager:show(SpinWidget:new{
                    title_text    = _("Brilho noturno (0–100%)"),
                    value         = math.max(0, self:get("night_brightness")),
                    value_min     = 0,
                    value_max     = 100,
                    value_step    = 5,
                    default_value = 20,
                    callback      = function(spin) self:set("night_brightness", spin.value) end,
                })
            end,
            keep_menu_open = true,
        })

        table.insert(menu, {
            text_func = function()
                return _("Brilho diurno: ") .. bLabel("day_brightness")
            end,
            callback = function()
                UIManager:show(SpinWidget:new{
                    title_text    = _("Brilho diurno (0–100%)"),
                    value         = math.max(0, self:get("day_brightness")),
                    value_min     = 0,
                    value_max     = 100,
                    value_step    = 5,
                    default_value = 70,
                    callback      = function(spin) self:set("day_brightness", spin.value) end,
                })
            end,
            keep_menu_open = true,
        })

        table.insert(menu, {
            text_func = function()
                local off = self:get("night_brightness") < 0 and self:get("day_brightness") < 0
                return off and _("Controle de brilho: desativado")
                           or _("Controle de brilho: ativado")
            end,
            callback = function()
                local off = self:get("night_brightness") < 0 and self:get("day_brightness") < 0
                if off then
                    self:set("night_brightness", 20)
                    self:set("day_brightness",   70)
                else
                    self:set("night_brightness", -1)
                    self:set("day_brightness",   -1)
                end
            end,
            keep_menu_open = true,
        })
    end

    -- Notificações
    table.insert(menu, {
        text_func    = function()
            return self:get("notify")
                and _("Notificações: ativadas")
                or  _("Notificações: desativadas")
        end,
        checked_func = function() return self:get("notify") end,
        callback     = function() self:set("notify", not self:get("notify")) end,
        keep_menu_open = true,
    })

    -- Aplicar agora
    table.insert(menu, {
        text     = _("Aplicar agora"),
        callback = function() self:applyMode(self:isNightNow(), true) end,
    })

    -- Status (só leitura)
    table.insert(menu, {
        text_func    = function()
            return string.format(
                _("Estado agora: %s  (%02d:%02d → %02d:%02d)"),
                self:isNightNow() and _("NOITE") or _("DIA"),
                self:get("on_hour"),  self:get("on_min"),
                self:get("off_hour"), self:get("off_min")
            )
        end,
        enabled_func = function() return false end,
    })

    return menu
end

return AutoNightMode
