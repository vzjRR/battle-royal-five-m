-- Test harness: boots the mock runtime + real server code, provides fake clients and assertions.

local H = { tests = {}, reqId = 0 }

function H.test(name, fn) H.tests[#H.tests + 1] = { name = name, fn = fn } end

function H.eq(a, b, msg)
    if a ~= b then error(('%s: expected %s, got %s'):format(msg or 'eq', tostring(b), tostring(a)), 2) end
end
function H.ok(v, msg) if not v then error(msg or 'expected truthy', 2) end end
function H.no(v, msg) if v then error(msg or 'expected falsy', 2) end end

---Boot the server runtime (once per test file).
function H.boot(opts)
    opts = opts or {}
    dofile(Sim.root .. '/tests/lib/fivem.lua')
    if opts.beforeLoad then opts.beforeLoad() end
    Sim.loadServer()
    assert(ES.ready, 'server did not become ready')
    -- simulated clients react to teleports so that server-side coordinates follow
    Sim.onClientEvent = function(src, name, args)
        if name ~= 'es:push' then return end
        local topic, data = args[1], args[2]
        local p = Sim.players[src]
        if not p then return end
        if (topic == 'teleport' or topic == 'respawn') and data.coords then
            p.pos = { x = data.coords.x, y = data.coords.y, z = data.coords.z }
            if topic == 'respawn' then p.health = data.health or 200 end
        elseif topic == 'left' then
            if data.coords then p.pos = { x = data.coords.x, y = data.coords.y, z = data.coords.z } end
            p.vehicle = 0
        elseif topic == 'vehicle' and data.coords then
            p.pos = { x = data.coords.x, y = data.coords.y, z = data.coords.z }
        end
    end
    return Sim
end

---Call an RPC as player src. Returns ok, result.
function H.rpc(src, name, payload)
    H.reqId = H.reqId + 1
    local id = H.reqId
    Sim.dispatch('es:rpc', src, name, id, payload)
    for _ = 1, 40 do
        for _, m in ipairs(Sim.outbox[src] or {}) do
            if m.name == 'es:rpc:res' and m.args[1] == id then return m.args[2], m.args[3] end
        end
        Sim.advance(50)
    end
    return nil, 'no_response'
end

---All push payloads of a topic received by src (optionally clearing them).
function H.pushes(src, topic)
    local out = {}
    for _, m in ipairs(Sim.outbox[src] or {}) do
        if m.name == 'es:push' and m.args[1] == topic then out[#out + 1] = m.args[2] end
    end
    return out
end

function H.lastPush(src, topic)
    local list = H.pushes(src, topic)
    return list[#list]
end

function H.clear(src) Sim.outbox[src] = {} end

---Add n players with ids from `from`. Returns list of srcs.
function H.players(n, from, opts)
    local list = {}
    for i = 0, n - 1 do
        local src = (from or 1) + i
        Sim.addPlayer(src, opts)
        list[#list + 1] = src
    end
    return list
end

function H.setPos(src, x, y, z) Sim.players[src].pos = { x = x, y = y, z = z or 0.0 } end

function H.admin(src) Sim.players[src].aces['eventstudio.admin'] = true ES.Perm.clear(src) end

---Create an instance via API and join the given players. Returns inst.
function H.createAndJoin(defId, srcs, opts)
    local ok, id = ES.Manager.create(defId, opts or { registration = 30 })
    assert(ok, 'create failed: ' .. tostring(id))
    for _, s in ipairs(srcs) do
        local jok, err = ES.Manager.join(s, id, true)
        assert(jok, ('join %s failed: %s'):format(s, tostring(err)))
    end
    return ES.Manager.get(id)
end

---Force an instance from REGISTRATION to ACTIVE (lobby + countdown elapsed).
function H.toActive(inst)
    assert(inst:start(true))
    for _ = 1, 400 do
        if inst.state == 'ACTIVE' then return end
        Sim.advance(100)
    end
    error('instance did not reach ACTIVE, state=' .. inst.state)
end

function H.waitState(inst, state, maxMs)
    local waited = 0
    while inst.state ~= state and waited < (maxMs or 60000) do
        Sim.advance(100)
        waited = waited + 100
    end
    return inst.state == state
end

---Register a test reward type that records payouts.
function H.recordRewards()
    H.paid = {}
    ES.Rewards.registerType('test', function(src, e) table.insert(H.paid, { src = src, amount = e.amount }) return true end)
end

function H.run(file)
    local passed, failed = 0, 0
    for _, t in ipairs(H.tests) do
        local ok, err = xpcall(t.fn, debug.traceback)
        if ok then
            passed = passed + 1
            Sim.print(('  \27[32m✓\27[0m %s'):format(t.name))
        else
            failed = failed + 1
            Sim.print(('  \27[31m✗ %s\27[0m\n%s'):format(t.name, tostring(err)))
            if os.getenv('ES_LOGS') == '1' then
                for i = math.max(1, #Sim.logs - 40), #Sim.logs do Sim.print('    | ' .. Sim.logs[i]) end
            end
        end
    end
    return passed, failed
end

return H
