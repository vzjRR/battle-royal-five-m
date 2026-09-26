-- EVENT STUDIO — client boot, commands, key mappings, exports

local booted = false

local function boot()
    for attempt = 1, 30 do
        local ok, res = ES.rpcAwait('client:ready', {}, 8000)
        if ok and type(res) == 'table' then
            ES.ServerInfo = res
            ES.NUI.send('init', {
                ui = res.ui, strings = res.strings, locale = res.locale, version = res.version, staff = res.staff, role = res.role,
                commands = res.commands, scoring = res.scoring,
            })
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

local cmds = ES.Config.Commands
local keys = cmds.keys or {}

if cmds.browser then
    RegisterCommand(cmds.browser, ES.openBrowser, false)
    if keys.browser then RegisterKeyMapping(cmds.browser, 'Events: open browser', 'keyboard', keys.browser) end
end

if cmds.admin then
    RegisterCommand(cmds.admin, ES.openAdmin, false)
end

local function toast(ok, res, okText)
    ES.NUI.send('toast', { text = ok and okText or ('err_' .. tostring(res)), kind = ok and 'success' or 'error', key = not ok })
end

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

if cmds.scoreboard then
    RegisterCommand('+' .. cmds.scoreboard, function()
        if ES.Client.current then ES.NUI.send('scoreboardExpand', { open = true }) end
    end, false)
    RegisterCommand('-' .. cmds.scoreboard, function()
        ES.NUI.send('scoreboardExpand', { open = false })
    end, false)
    if keys.scoreboard then RegisterKeyMapping('+' .. cmds.scoreboard, 'Events: expanded scoreboard', 'keyboard', keys.scoreboard) end
end

-- Exports ----------------------------------------------------------------------

exports('IsInEvent', function() return ES.Client.current ~= nil end)
exports('GetCurrentEvent', function()
    local c = ES.Client.current
    if not c then return nil end
    return { id = c.id, mode = c.mode, state = c.state, role = c.role }
end)
exports('OpenBrowser', ES.openBrowser)
