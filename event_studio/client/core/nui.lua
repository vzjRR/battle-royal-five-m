-- EVENT STUDIO — NUI bridge (message bus + focus + generic RPC passthrough)

local NUI = { focus = false, ready = false, queue = {} }
ES.NUI = NUI

function NUI.send(action, data)
    if not NUI.ready then
        NUI.queue[#NUI.queue + 1] = { action = action, data = data }
        return
    end
    SendNUIMessage({ action = action, data = data })
end

function NUI.setFocus(on, keepInput)
    NUI.focus = on
    SetNuiFocus(on, on)
    SetNuiFocusKeepInput(keepInput == true)
end

RegisterNUICallback('ready', function(_, cb)
    NUI.ready = true
    for _, m in ipairs(NUI.queue) do SendNUIMessage(m) end
    NUI.queue = {}
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    NUI.setFocus(false)
    cb({ ok = true })
end)

-- Generic passthrough: the server validates everything, the NUI is just a client.
RegisterNUICallback('rpc', function(data, cb)
    if type(data) ~= 'table' or type(data.name) ~= 'string' then return cb({ ok = false, res = 'bad_request' }) end
    ES.rpc(data.name, data.payload, function(ok, res) cb({ ok = ok, res = res }) end)
end)

RegisterNUICallback('action', function(data, cb)
    ES.rpc('event:action', { action = data.action, data = data.data }, function(ok, res) cb({ ok = ok, res = res }) end)
end)

RegisterNUICallback('spectate', function(data, cb)
    if ES.Spectator then ES.Spectator.control(data.cmd) end
    cb({ ok = true })
end)

RegisterNUICallback('admin:position', function(_, cb)
    ES.rpc('admin:position', {}, function(ok, res) cb({ ok = ok, res = res }) end)
end)

RegisterNUICallback('waypoint', function(data, cb)
    if data and data.x and data.y then SetNewWaypoint(data.x + 0.0, data.y + 0.0) end
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() and NUI.focus then SetNuiFocus(false, false) end
end)
