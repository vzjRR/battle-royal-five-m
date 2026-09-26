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

function ES.openBrowser()
    ES.NUI.panelOpen = true
    ES.NUI.setFocus(true)
    ES.NUI.send('open', { view = 'browser' })
end

function ES.openAdmin()
    ES.rpc('admin:bootstrap', {}, function(ok, res)
        if not ok then
            ES.NUI.send('toast', { text = res == 'forbidden' and 'No permission.' or tostring(res), kind = 'error' })
            return
        end
        ES.NUI.panelOpen = true
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
