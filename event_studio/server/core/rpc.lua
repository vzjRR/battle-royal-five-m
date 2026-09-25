-- EVENT STUDIO — the single client→server gateway
-- Client:  TriggerServerEvent('es:rpc', name, requestId, payload)
-- Server:  TriggerClientEvent('es:rpc:res', src, requestId, ok, result)

local RPC = {}
ES.RPC = RPC

local handlers = {}
local buckets = {}   -- [src][name] = token bucket
local U = ES.Util
local Log = ES.Log

local defaultRate = { burst = 10, per = 5 }

---Register an RPC.
---spec = { perm = 'action' | public = true, schema = { field = spec }, rate = { burst, per }, confirm = bool }
function RPC.register(name, spec, handler)
    assert(type(name) == 'string' and type(handler) == 'function', 'RPC.register(name, spec, fn)')
    assert(spec.perm or spec.public, ('RPC %s must declare perm or public'):format(name))
    handlers[name] = { spec = spec, fn = handler }
end

local function respond(src, reqId, ok, result)
    if reqId then TriggerClientEvent('es:rpc:res', src, reqId, ok, result) end
end

local function rateOk(src, name, rate)
    rate = rate or defaultRate
    buckets[src] = buckets[src] or {}
    local b = buckets[src][name]
    if not b then
        b = U.newBucket(rate.burst, rate.per)
        buckets[src][name] = b
    end
    -- global per-player bucket guards against spreading spam across RPC names
    local g = buckets[src]['*']
    if not g then
        g = U.newBucket(40, 5)
        buckets[src]['*'] = g
    end
    local now = ES.now()
    return U.takeToken(g, now) and U.takeToken(b, now)
end

---Dispatch (exposed for tests).
function RPC.dispatch(src, name, reqId, payload)
    if type(name) ~= 'string' or #name > 64 then
        Log.security(src, 'rpc_malformed')
        return false, 'malformed'
    end
    if reqId ~= nil and (type(reqId) ~= 'number' or reqId % 1 ~= 0) then reqId = nil end

    if not ES.ready then
        respond(src, reqId, false, 'not_ready')
        return false, 'not_ready'
    end
    local h = handlers[name]
    if not h then
        Log.security(src, 'rpc_unknown', { name = name })
        respond(src, reqId, false, 'unknown')
        return false, 'unknown'
    end
    if not rateOk(src, name, h.spec.rate) then
        Log.security(src, 'rpc_rate_limited', { name = name })
        respond(src, reqId, false, 'rate_limited')
        return false, 'rate_limited'
    end
    if payload ~= nil and type(payload) ~= 'table' then
        Log.security(src, 'rpc_bad_payload', { name = name })
        respond(src, reqId, false, 'bad_payload')
        return false, 'bad_payload'
    end
    local data = {}
    if h.spec.schema then
        local ok, res = ES.Schema.validateFields(payload or {}, h.spec.schema)
        if not ok then
            Log.debug('RPC %s from %s rejected: %s', name, src, res)
            respond(src, reqId, false, 'invalid:' .. tostring(res))
            return false, 'invalid'
        end
        data = res
    end
    if h.spec.perm and not ES.Perm.can(src, h.spec.perm) then
        Log.security(src, 'rpc_forbidden', { name = name, perm = h.spec.perm })
        respond(src, reqId, false, 'forbidden')
        return false, 'forbidden'
    end
    if h.spec.confirm and not (payload and payload.confirm == true) then
        respond(src, reqId, false, 'confirm_required')
        return false, 'confirm_required'
    end
    local ok, a, b = pcall(h.fn, src, data)
    if not ok then
        Log.error('RPC %s failed: %s', name, tostring(a))
        respond(src, reqId, false, 'error')
        return false, 'error'
    end
    -- handlers return (true, result) | (false, errorCode) | result
    if a == false then
        respond(src, reqId, false, b)
        return false, b
    end
    local result = (a == true) and b or a
    respond(src, reqId, true, result)
    return true, result
end

RegisterNetEvent('es:rpc', function(name, reqId, payload)
    local src = source
    if type(src) ~= 'number' or src <= 0 then return end
    RPC.dispatch(src, name, reqId, payload)
end)

function RPC.clear(src) buckets[src] = nil end

---Push a topic to one player or a list of players.
function ES.push(target, topic, data)
    if type(target) == 'table' then
        for i = 1, #target do TriggerClientEvent('es:push', target[i], topic, data) end
    else
        TriggerClientEvent('es:push', target, topic, data)
    end
end

return RPC
