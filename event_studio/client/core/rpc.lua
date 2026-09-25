-- EVENT STUDIO — client RPC + push dispatch

local pending = {}
local nextId = 0

---Call a server RPC. cb(ok, result) is optional; returns immediately.
function ES.rpc(name, payload, cb)
    nextId = nextId + 1
    local id = nextId
    if cb then
        pending[id] = { cb = cb, at = GetGameTimer() }
    end
    TriggerServerEvent('es:rpc', name, cb and id or nil, payload)
end

---Await a server RPC (inside a thread). Returns ok, result.
function ES.rpcAwait(name, payload, timeoutMs)
    local p = promise.new()
    ES.rpc(name, payload, function(ok, res) p:resolve({ ok, res }) end)
    SetTimeout(timeoutMs or 10000, function() p:resolve({ false, 'timeout' }) end)
    local r = Citizen.Await(p)
    return r[1], r[2]
end

RegisterNetEvent('es:rpc:res', function(id, ok, result)
    local p = pending[id]
    if not p then return end
    pending[id] = nil
    local success, err = pcall(p.cb, ok, result)
    if not success then print('[event_studio] rpc callback error: ' .. tostring(err)) end
end)

-- expire stale callbacks
CreateThread(function()
    while true do
        Wait(15000)
        local now = GetGameTimer()
        for id, p in pairs(pending) do
            if now - p.at > 15000 then
                pending[id] = nil
                pcall(p.cb, false, 'timeout')
            end
        end
    end
end)

-- Push topics ---------------------------------------------------------------

local handlers = {}

---Subscribe to a push topic. Multiple handlers per topic are allowed.
function ES.on(topic, fn)
    handlers[topic] = handlers[topic] or {}
    table.insert(handlers[topic], fn)
end

RegisterNetEvent('es:push', function(topic, data)
    local list = handlers[topic]
    if not list then return end
    for _, fn in ipairs(list) do
        local ok, err = pcall(fn, data)
        if not ok then print(('[event_studio] push %s handler error: %s'):format(topic, tostring(err))) end
    end
end)
