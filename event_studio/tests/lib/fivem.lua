-- FiveM server runtime mock for EVENT STUDIO tests.
-- Provides natives, events, coroutine threads with a virtual clock, KVP, players, peds and vehicles.
-- It loads the real server scripts listed in fxmanifest.lua.

local Sim = {
    root = (_G.Sim and _G.Sim.root) or '.',
    clock = 0, threads = {}, handlers = {}, outbox = {}, players = {}, vehicles = {}, kvp = {},
    exports = {}, commands = {}, state = {}, logs = {}, verbose = os.getenv('ES_VERBOSE') == '1',
    nextEntity = 50000, cancelled = false, resourceStates = {}, convars = { onesync = 'on', es_debug = '0' },
}
_G.Sim = Sim

local realTime = os.time
Sim.epoch = realTime({ year = 2026, month = 9, day = 25, hour = 12, min = 0, sec = 0 })
os.time = function(t)
    if t then return realTime(t) end
    return Sim.epoch + (Sim.clock // 1000)
end

json = dofile(Sim.root .. '/tests/lib/json.lua')

----------------------------------------------------------------------------
-- Threads & timing
----------------------------------------------------------------------------

local function addThread(co, delay)
    Sim.threads[#Sim.threads + 1] = { co = co, wakeAt = Sim.clock + (delay or 0) }
end

local function resume(t, ...)
    local ok, res = coroutine.resume(t.co, ...)
    if not ok then
        error(debug.traceback(t.co, tostring(res)), 0)
    end
    if coroutine.status(t.co) == 'dead' then return false end
    t.wakeAt = Sim.clock + (tonumber(res) or 0)
    return true
end

---Run fn immediately inside a coroutine (like an event handler); continue later if it yields.
function Sim.runNow(fn, ...)
    local t = { co = coroutine.create(fn) }
    if resume(t, ...) then Sim.threads[#Sim.threads + 1] = t end
end

function Sim.step()
    for _ = 1, 60 do
        local due = {}
        local keep = {}
        for _, t in ipairs(Sim.threads) do
            if t.wakeAt <= Sim.clock then due[#due + 1] = t else keep[#keep + 1] = t end
        end
        if #due == 0 then return end
        Sim.threads = keep
        for _, t in ipairs(due) do
            if resume(t) then Sim.threads[#Sim.threads + 1] = t end
        end
    end
end

function Sim.advance(ms, stepMs)
    stepMs = stepMs or 50
    local target = Sim.clock + ms
    Sim.step()
    while Sim.clock < target do
        Sim.clock = math.min(target, Sim.clock + stepMs)
        Sim.step()
    end
end

Citizen = {}
function Citizen.CreateThread(fn) addThread(coroutine.create(fn), 0) end
function Citizen.CreateThreadNow(fn) Sim.runNow(fn) end
function Citizen.Wait(ms)
    if not coroutine.isyieldable() then error('Wait called outside a thread') end
    coroutine.yield(ms or 0)
end
CreateThread = Citizen.CreateThread
Wait = Citizen.Wait
function SetTimeout(ms, fn) addThread(coroutine.create(fn), ms) end
function GetGameTimer() return Sim.clock end

promise = {}
function promise.new()
    local p = { resolved = false }
    function p:resolve(v) if not self.resolved then self.resolved, self.value = true, v end end
    function p:reject(v) self:resolve(v) end
    return p
end
function Citizen.Await(p)
    while not p.resolved do coroutine.yield(0) end
    return p.value
end

----------------------------------------------------------------------------
-- Events
----------------------------------------------------------------------------

local function handlersFor(name)
    Sim.handlers[name] = Sim.handlers[name] or {}
    return Sim.handlers[name]
end

function AddEventHandler(name, fn) table.insert(handlersFor(name), fn) end
function RegisterNetEvent(name, fn) if fn then AddEventHandler(name, fn) end end
function RegisterServerEvent(name, fn) RegisterNetEvent(name, fn) end
function CancelEvent() Sim.cancelled = true end
function WasEventCanceled() return Sim.cancelled end

---Dispatch an event with a given `source`. Returns true if cancelled.
function Sim.dispatch(name, src, ...)
    local list = Sim.handlers[name]
    Sim.cancelled = false
    if not list then return false end
    local args = table.pack(...)
    for _, fn in ipairs(list) do
        local prev = _G.source
        _G.source = src
        Sim.runNow(function() fn(table.unpack(args, 1, args.n)) end)
        _G.source = prev
    end
    return Sim.cancelled
end

function TriggerEvent(name, ...) Sim.dispatch(name, nil, ...) end

function TriggerClientEvent(name, target, ...)
    local args = table.pack(...)
    local function deliver(src)
        Sim.outbox[src] = Sim.outbox[src] or {}
        table.insert(Sim.outbox[src], { name = name, args = args })
        if Sim.onClientEvent then Sim.onClientEvent(src, name, args) end
    end
    if target == -1 then
        for src in pairs(Sim.players) do deliver(src) end
    else
        deliver(tonumber(target))
    end
end

----------------------------------------------------------------------------
-- Players, peds, vehicles
----------------------------------------------------------------------------

local PED_BASE = 10000

function Sim.addPlayer(src, opts)
    opts = opts or {}
    Sim.players[src] = {
        src = src, name = opts.name or ('Player' .. src), license = opts.license or ('license:' .. string.format('%040d', src)),
        pos = opts.pos or { x = 0.0, y = 0.0, z = 0.0 }, heading = 0.0, bucket = 0, health = 200, vehicle = 0, aces = opts.aces or {},
        ping = opts.ping or 30,
    }
    Sim.outbox[src] = {}
    return Sim.players[src]
end

function Sim.removePlayer(src)
    Sim.dispatch('playerDropped', src, 'quit')
    Sim.players[src] = nil
end

local function pedOwner(ped)
    local src = ped - PED_BASE
    return Sim.players[src] and src or nil
end

function GetPlayerPed(src)
    src = tonumber(src)
    return Sim.players[src] and (PED_BASE + src) or 0
end
function GetPlayers()
    local out = {}
    for src in pairs(Sim.players) do out[#out + 1] = tostring(src) end
    table.sort(out)
    return out
end
function GetPlayerName(src) local p = Sim.players[tonumber(src)] return p and p.name or nil end
function GetPlayerIdentifierByType(src, kind)
    local p = Sim.players[tonumber(src)]
    if not p then return nil end
    if kind == 'license' then return p.license end
    return nil
end
function GetPlayerPing(src) local p = Sim.players[tonumber(src)] return p and p.ping or 0 end
function DropPlayer(src, reason) Sim.dropped = Sim.dropped or {} Sim.dropped[tonumber(src)] = reason end
function IsPlayerAceAllowed(src, object) local p = Sim.players[tonumber(src)] return p ~= nil and p.aces[object] == true end
function GetPlayerRoutingBucket(src) local p = Sim.players[tonumber(src)] return p and p.bucket or 0 end
function SetPlayerRoutingBucket(src, b) local p = Sim.players[tonumber(src)] if p then p.bucket = b end end

function GetEntityCoords(ent)
    local src = pedOwner(ent)
    if src then local p = Sim.players[src].pos return { x = p.x, y = p.y, z = p.z } end
    local v = Sim.vehicles[ent]
    if v then return { x = v.pos.x, y = v.pos.y, z = v.pos.z } end
    return { x = 0.0, y = 0.0, z = 0.0 }
end
function GetEntityHeading(ent) local src = pedOwner(ent) return src and Sim.players[src].heading or 0.0 end
function GetEntityHealth(ent)
    local src = pedOwner(ent)
    if src then return Sim.players[src].health end
    local v = Sim.vehicles[ent]
    return v and v.health or 0
end
function GetEntityType(ent) if pedOwner(ent) then return 1 end if Sim.vehicles[ent] then return 2 end return 0 end
function IsPedAPlayer(ent) return pedOwner(ent) ~= nil end
function NetworkGetEntityFromNetworkId(net) return net end
function NetworkGetNetworkIdFromEntity(ent) return ent end
function NetworkGetEntityOwner(ent) return pedOwner(ent) end
function DoesEntityExist(ent) return pedOwner(ent) ~= nil or Sim.vehicles[ent] ~= nil end
function DeleteEntity(ent) Sim.vehicles[ent] = nil end

function CreateVehicleServerSetter(hash, vtype, x, y, z, h)
    Sim.nextEntity = Sim.nextEntity + 1
    local id = Sim.nextEntity
    Sim.vehicles[id] = { model = hash, type = vtype, pos = { x = x, y = y, z = z }, heading = h, health = 1000, engine = 1000.0, bucket = 0 }
    return id
end
function SetEntityRoutingBucket(ent, b) if Sim.vehicles[ent] then Sim.vehicles[ent].bucket = b end end
function GetEntityRoutingBucket(ent) return Sim.vehicles[ent] and Sim.vehicles[ent].bucket or 0 end
function SetVehicleNumberPlateText() end
function SetVehicleColours() end
function SetEntityOrphanMode() end
function SetPedIntoVehicle(ped, veh) local src = pedOwner(ped) if src then Sim.players[src].vehicle = veh end end
function GetVehiclePedIsIn(ped) local src = pedOwner(ped) return src and Sim.players[src].vehicle or 0 end
function GetVehicleEngineHealth(veh) return Sim.vehicles[veh] and Sim.vehicles[veh].engine or -4000.0 end
function SetRoutingBucketPopulationEnabled() end
function SetRoutingBucketEntityLockdownMode() end

----------------------------------------------------------------------------
-- Misc natives
----------------------------------------------------------------------------

function IsDuplicityVersion() return true end
function GetCurrentResourceName() return 'event_studio' end
function GetInvokingResource() return 'test' end
function GetResourceState(name) return Sim.resourceStates[name] or 'missing' end
function GetConvar(k, d) return Sim.convars[k] or d end
function GetConvarInt(k, d) return tonumber(Sim.convars[k]) or d end
function LoadResourceFile(_, path)
    local f = io.open(Sim.root .. '/' .. path, 'r')
    if not f then return nil end
    local s = f:read('a')
    f:close()
    return s
end
function PerformHttpRequest(url, cb) Sim.http = Sim.http or {} table.insert(Sim.http, url) if cb then cb(204, '', {}) end end
function ExecuteCommand(cmd) Sim.executed = Sim.executed or {} table.insert(Sim.executed, cmd) end
function RegisterCommand(name, fn) Sim.commands[name] = fn end

function GetHashKey(s)
    s = tostring(s):lower()
    local h = 0
    for i = 1, #s do
        h = (h + s:byte(i)) & 0xFFFFFFFF
        h = (h + (h << 10)) & 0xFFFFFFFF
        h = h ~ (h >> 6)
    end
    h = (h + (h << 3)) & 0xFFFFFFFF
    h = h ~ (h >> 11)
    h = (h + (h << 15)) & 0xFFFFFFFF
    if h >= 0x80000000 then h = h - 0x100000000 end
    return h
end

-- KVP
function GetResourceKvpString(k) return Sim.kvp[k] end
function SetResourceKvp(k, v) Sim.kvp[k] = v end
function DeleteResourceKvp(k) Sim.kvp[k] = nil end
local finds = {}
function StartFindKvp(prefix)
    local keys = {}
    for k in pairs(Sim.kvp) do if k:sub(1, #prefix) == prefix then keys[#keys + 1] = k end end
    table.sort(keys)
    finds[#finds + 1] = { keys = keys, i = 0 }
    return #finds
end
function FindKvp(h) local f = finds[h] f.i = f.i + 1 return f.keys[f.i] end
function EndFindKvp(h) finds[h] = nil end

-- State bags
GlobalState = {}
function Player(src)
    Sim.state[src] = Sim.state[src] or {}
    local bag = Sim.state[src]
    return { state = setmetatable({ set = function(_, k, v) bag[k] = v end }, { __index = bag }) }
end

-- Exports
exports = setmetatable({}, {
    __call = function(_, name, fn) Sim.exports[name] = fn end,
    __index = function(_, res)
        return setmetatable({}, { __index = function(_, fname)
            return function() error(('export %s.%s not available in tests'):format(res, fname)) end
        end })
    end,
})

local realPrint = print
print = function(...)
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    local line = table.concat(parts, ' ')
    table.insert(Sim.logs, line)
    if Sim.verbose then realPrint(line) end
end
Sim.print = realPrint

----------------------------------------------------------------------------
-- Manifest loader
----------------------------------------------------------------------------

local function expand(pattern)
    if not pattern:find('*', 1, true) then return { pattern } end
    local out = {}
    local cmd = ("cd '%s' && ls -1 %s 2>/dev/null"):format(Sim.root, pattern)
    local p = io.popen(cmd)
    for line in p:lines() do out[#out + 1] = line end
    p:close()
    table.sort(out)
    return out
end

function Sim.manifestScripts()
    local lists = { shared = {}, server = {} }
    local env = setmetatable({}, { __index = function() return function() end end })
    env.shared_scripts = function(t) lists.shared = t end
    env.server_scripts = function(t) lists.server = t end
    local chunk = assert(loadfile(Sim.root .. '/fxmanifest.lua', 't', env))
    chunk()
    local files = {}
    for _, group in ipairs({ lists.shared, lists.server }) do
        for _, pattern in ipairs(group) do
            for _, f in ipairs(expand(pattern)) do files[#files + 1] = f end
        end
    end
    return files
end

function Sim.loadServer()
    for _, f in ipairs(Sim.manifestScripts()) do
        local chunk, err = loadfile(Sim.root .. '/' .. f)
        if not chunk then error('load ' .. f .. ': ' .. tostring(err)) end
        Sim.runNow(chunk)
    end
    Sim.advance(200)
end

return Sim
