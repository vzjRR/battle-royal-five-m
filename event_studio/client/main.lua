-- EVENT STUDIO — client boot, player keys, staff commands, exports

local booted = false

-- The player's own language (flag switch in the event window), kept on their PC between sessions.
local LOCALE_KVP = 'es_locale'

local function boot()
    local saved = GetResourceKvpString(LOCALE_KVP)
    if saved and ES.Locales[saved] then ES.localeOverride = saved else saved = nil end
    for attempt = 1, 30 do
        local ok, res = ES.rpcAwait('client:ready', { locale = saved }, 8000)
        if ok and type(res) == 'table' then
            ES.ServerInfo = res
            if res.locale and res.locale.code then ES.localeOverride = res.locale.code end
            ES.NUI.send('init', {
                ui = res.ui, strings = res.strings, locale = res.locale, version = res.version, staff = res.staff, role = res.role,
                commands = res.commands, scoring = res.scoring,
            })
            ES.applyKeys(res.ui and res.ui.keys)
            if res.staff then ES.registerStaffCommands() end
            booted = true
            return
        end
        Wait(math.min(2000 * attempt, 10000))
    end
    print('[event_studio] could not reach the server (client:ready)')
end

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    boot()
end)

---Switch this player's language: texts and direction change at once (event window, HUD, phone app, messages).
function ES.setLocale(code)
    if type(code) ~= 'string' or code:sub(1, 1) == '_' or not ES.Locales[code] then return nil end
    ES.localeOverride = code
    SetResourceKvp(LOCALE_KVP, code)
    local payload = { strings = ES.uiStrings(code), locale = ES.localeInfo(code) }
    if ES.ServerInfo then ES.ServerInfo.strings, ES.ServerInfo.locale = payload.strings, payload.locale end
    ES.NUI.send('locale', payload)
    ES.rpc('player:locale', { code = code }) -- so chat / notifications from the server use it too
    return payload
end

RegisterNUICallback('setLocale', function(data, cb)
    cb(ES.setLocale(type(data) == 'table' and data.code) or { ok = false })
end)

-- Browser ----------------------------------------------------------------------

-- While the docked window keeps game input, the mouse must not also turn the camera or fire weapons.
local BLOCKED_WHILE_MOVING = { 1, 2, 24, 25, 37, 68, 69, 70, 91, 92, 106, 140, 141, 142, 199, 200, 257, 263, 264 }

local function keepMovingLoop()
    CreateThread(function()
        while ES.NUI.panelOpen and ES.NUI.keepInput do
            for _, c in ipairs(BLOCKED_WHILE_MOVING) do DisableControlAction(0, c, true) end
            Wait(0)
        end
    end)
end

function ES.openBrowser()
    if ES.NUI.panelOpen and ES.NUI.keepInput then -- F7 again closes the docked window
        ES.NUI.send('close', {})
        return
    end
    local ui = (ES.ServerInfo and ES.ServerInfo.ui) or Config.UI
    local keep = ui.browserLayout == 'docked' and ui.browserKeepMoving == true
    ES.NUI.panelOpen = true
    ES.NUI.keepInput = keep
    ES.NUI.setFocus(true, keep)
    ES.NUI.send('open', { view = 'browser' })
    if keep then keepMovingLoop() end
end

function ES.openAdmin()
    ES.rpc('admin:bootstrap', {}, function(ok, res)
        if not ok then
            ES.NUI.send('toast', { text = res == 'forbidden' and 'No permission.' or tostring(res), kind = 'error' })
            return
        end
        ES.NUI.panelOpen = true
        ES.NUI.keepInput = false
        ES.NUI.setFocus(true)
        ES.NUI.send('open', { view = 'admin', data = res })
    end)
end

-- Player keys ------------------------------------------------------------------
-- Players only get keys (default F7 for the events window); typed commands are for staff. Owners change the keys
-- in Admin Center → Settings → Player controls, and the change reaches everyone live.
-- GTA keeps a player's first default for each key-mapping command, so every mapping's internal command carries its
-- key in the name (es_menu_f7). A new key therefore gets a fresh mapping with the new default; the old one stops acting.

local KEY_ACTIONS = {
    browser = { cmd = 'es_menu', label = 'Events: open the events window', press = function() ES.openBrowser() end },
    scoreboard = { cmd = 'es_board', label = 'Events: expanded scoreboard (hold)', hold = true,
        press = function() if ES.Client.current then ES.NUI.send('scoreboardExpand', { open = true }) end end,
        release = function() ES.NUI.send('scoreboardExpand', { open = false }) end },
    reset = { cmd = 'es_reset', label = 'Event: back to the last checkpoint',
        press = function() if ES.resetToCheckpoint then ES.resetToCheckpoint() end end },
    -- staff only: close registration, then start the countdown, without opening the Admin Center
    hostStart = { cmd = 'es_host', label = 'Events (staff): start the waiting event', staff = true,
        press = function() ES.hostStart() end },
}

local function hostToast(ok, res)
    if ok and type(res) == 'table' then
        ES.NUI.send('toast', { text = L(res.step == 'countdown' and 'ui.host_started' or 'ui.host_closed', res.name), kind = 'success' })
    else
        ES.NUI.send('toast', { text = 'err_' .. tostring(res), kind = 'error', key = true })
    end
end

---Host key / /eventstart: registration open -> close it; players in the arena -> 10 s countdown.
function ES.hostStart(id)
    ES.rpc('host:start', { id = id }, hostToast)
end

local activeKey = {}     -- action -> key in effect ('F7'), nil when off
local mapped = {}        -- internal command -> true
local hidden = {}        -- chat suggestions to hide

local function hideSuggestions()
    for _, name in ipairs(hidden) do TriggerEvent('chat:removeSuggestion', '/' .. name) end
end

local function mapKey(action, key)
    local a = KEY_ACTIONS[action]
    local name = ('%s_%s'):format(a.cmd, key:lower())
    if mapped[name] then return end
    mapped[name] = true
    local function live() return activeKey[action] == key end
    if a.hold then
        RegisterCommand('+' .. name, function() if live() then a.press() end end, false)
        RegisterCommand('-' .. name, function() a.release() end, false)
        RegisterKeyMapping('+' .. name, a.label, 'keyboard', key)
        hidden[#hidden + 1] = '+' .. name
        hidden[#hidden + 1] = '-' .. name
    else
        RegisterCommand(name, function() if live() then a.press() end end, false)
        RegisterKeyMapping(name, a.label, 'keyboard', key)
        hidden[#hidden + 1] = name
    end
end

---Apply the player keys sent by the server (ui.keys); called on boot and on every appearance change.
function ES.applyKeys(keys)
    keys = type(keys) == 'table' and keys or (ES.Config.Commands.keys or {})
    for action, a in pairs(KEY_ACTIONS) do
        local key = type(keys[action]) == 'string' and keys[action]:upper() or nil
        if a.staff and not (ES.ServerInfo and ES.ServerInfo.staff) then key = nil end
        if action == 'browser' and not key then key = 'F7' end
        activeKey[action] = key
        if key then mapKey(action, key) end
    end
    hideSuggestions()
end

-- The chat resource rebuilds its suggestion list whenever a resource starts; hide the internal names again.
AddEventHandler('onClientResourceStart', function()
    SetTimeout(1500, hideSuggestions)
end)

-- Staff commands -----------------------------------------------------------------
-- Registered only for staff (host and above, decided by the server in client:ready), so normal players do not have
-- them at all: they open the events window with the key and join, leave or spectate from there.

local staffRegistered = false

local function toast(ok, res, okText)
    ES.NUI.send('toast', { text = ok and okText or ('err_' .. tostring(res)), kind = ok and 'success' or 'error', key = not ok })
end

function ES.registerStaffCommands()
    if staffRegistered then return end
    staffRegistered = true
    local cmds = ES.Config.Commands
    if cmds.admin then RegisterCommand(cmds.admin, ES.openAdmin, false) end
    if cmds.browser then RegisterCommand(cmds.browser, ES.openBrowser, false) end
    if cmds.join then
        RegisterCommand(cmds.join, function(_, args)
            ES.rpc('event:join', { id = tonumber(args[1]) }, function(ok, res) toast(ok, res, 'joined') end)
        end, false)
    end
    if cmds.leave then
        RegisterCommand(cmds.leave, function()
            if ES.Spectator and ES.Spectator.active then ES.rpc('spectate:stop', {}) return end
            ES.rpc('event:leave', {}, function(ok, res) if not ok then toast(ok, res) end end)
        end, false)
    end
    if cmds.spectate then
        RegisterCommand(cmds.spectate, function(_, args)
            ES.rpc('event:spectate', { id = tonumber(args[1]) }, function(ok, res) if not ok then toast(ok, res) end end)
        end, false)
    end
    if cmds.hostStart then
        RegisterCommand(cmds.hostStart, function(_, args) ES.hostStart(tonumber(args[1])) end, false)
    end
    if ES.registerArenaFixCommand then ES.registerArenaFixCommand() end
end

-- Exports ----------------------------------------------------------------------

exports('IsInEvent', function() return ES.Client.current ~= nil end)
exports('GetCurrentEvent', function()
    local c = ES.Client.current
    if not c then return nil end
    return { id = c.id, mode = c.mode, state = c.state, role = c.role }
end)
exports('OpenBrowser', ES.openBrowser)
