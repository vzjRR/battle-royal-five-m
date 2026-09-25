-- EVENT STUDIO — component: vehicles (server-created, bucketed, seated, cleaned up)

local U = ES.Util
local Log = ES.Log

local Vehicles = {}
Vehicles.__index = Vehicles

---cfg = {
---  vehicle = { model = 'sultan', type = 'automobile' } | nil,
---  pool = { {model,type}, ... }, random = false,
---  points = arena.vehicleSpawns, lock = true, ghost = false,
---  eliminateOnWreck = false, wreckEngineHealth = 0, outOfVehicleSeconds = 8, outOfVehicleAction = 'reseat'|'eliminate'|nil,
---  plate = 'EVENT', colors = { primary, secondary }
---}
function Vehicles.attach(inst, cfg)
    local arena = inst.arena or {}
    local self = setmetatable({
        inst = inst,
        cfg = cfg,
        points = cfg.points or arena.vehicleSpawns or arena.spawns or {},
        cursor = 0,
        byP = {},         -- [participant] = { entity, net, model }
        outSince = {},
    }, Vehicles)
    return self
end

function Vehicles:chooseModel(p)
    local c = self.cfg
    if c.pool and #c.pool > 0 then
        if c.random then return U.pick(c.pool) end
        return c.pool[((p.joinSeq or 1) - 1) % #c.pool + 1]
    end
    return c.vehicle or { model = 'sultan', type = 'automobile' }
end

function Vehicles:nextPoint()
    if #self.points == 0 then return nil end
    self.cursor = self.cursor % #self.points + 1
    return self.points[self.cursor]
end

---Spawn a vehicle for p at point and seat them.
function Vehicles:provision(p, point)
    if not p.src then return nil end
    point = point or self:nextPoint() or U.vec(GetEntityCoords(GetPlayerPed(p.src)))
    self:remove(p)
    local spec = self:chooseModel(p)
    local hash = type(spec.model) == 'number' and spec.model or GetHashKey(spec.model)
    local veh = CreateVehicleServerSetter(hash, spec.type or 'automobile', point.x, point.y, point.z, point.w or 0.0)
    local waited = 0
    while not DoesEntityExist(veh) and waited < 3000 do
        Wait(50)
        waited = waited + 50
    end
    if not DoesEntityExist(veh) then
        Log.warn('#%d vehicle %s failed to spawn (invalid model?)', self.inst.id, tostring(spec.model))
        self.inst:push(p, 'announce', { text = L('vehicle_spawn_failed'), kind = 'error' })
        return nil
    end
    SetEntityRoutingBucket(veh, self.inst.bucket)
    SetVehicleNumberPlateText(veh, (self.cfg.plate or 'EVENT'):sub(1, 8))
    if self.cfg.colors then SetVehicleColours(veh, self.cfg.colors[1] or 0, self.cfg.colors[2] or 0) end
    local net = NetworkGetNetworkIdFromEntity(veh)
    self.byP[p] = { entity = veh, net = net, model = spec.model }
    p.spawnPoint = p.spawnPoint or point
    self.inst.entities[#self.inst.entities + 1] = veh
    p.vehicle = veh
    SetPedIntoVehicle(GetPlayerPed(p.src), veh, -1)
    self.inst:push(p, 'vehicle', { net = net, lock = self.cfg.lock ~= false, ghost = self.cfg.ghost == true,
        heading = point.w or 0.0, coords = { x = point.x, y = point.y, z = point.z } })
    self.outSince[p] = nil
    return veh
end

function Vehicles:provisionAll()
    local list = self.inst:activeParticipants()
    table.sort(list, function(a, b) return a.joinSeq < b.joinSeq end)
    for _, p in ipairs(list) do self:provision(p) end
end

function Vehicles:remove(p)
    local v = self.byP[p]
    if v then
        if DoesEntityExist(v.entity) then DeleteEntity(v.entity) end
        self.byP[p] = nil
        p.vehicle = nil
    end
end

function Vehicles:entityOf(p)
    local v = self.byP[p]
    return v and DoesEntityExist(v.entity) and v.entity or nil
end

function Vehicles:isWrecked(p)
    local veh = self:entityOf(p)
    if not veh then return true end
    if GetEntityHealth(veh) <= 0 then return true end
    return GetVehicleEngineHealth(veh) <= (self.cfg.wreckEngineHealth or 0)
end

function Vehicles:tick()
    local c = self.cfg
    for _, p in ipairs(self.inst:activeParticipants()) do
        local veh = self:entityOf(p)
        if c.eliminateOnWreck and self:isWrecked(p) then
            self.inst:eliminate(p, 'wrecked')
        elseif veh and c.outOfVehicleAction then
            local inVeh = GetVehiclePedIsIn(GetPlayerPed(p.src), false) == veh
            if inVeh then
                self.outSince[p] = nil
            else
                self.outSince[p] = self.outSince[p] or ES.now()
                if ES.now() - self.outSince[p] >= (c.outOfVehicleSeconds or 8) * 1000 then
                    if c.outOfVehicleAction == 'eliminate' then
                        self.inst:eliminate(p, 'left_vehicle')
                    else
                        SetPedIntoVehicle(GetPlayerPed(p.src), veh, -1)
                        self.outSince[p] = nil
                    end
                end
            end
        end
    end
end
Vehicles.tickWhileFinishing = false

function Vehicles:clientSetup(p)
    if not p then return nil end
    local v = self.byP[p]
    return { lock = self.cfg.lock ~= false, ghost = self.cfg.ghost == true, net = v and v.net or nil }
end

function Vehicles:onJoin(p) self:provision(p, p.spawnPoint) end
function Vehicles:onLeave(p) self:remove(p) end

function Vehicles:onEliminated(p)
    if self.cfg.keepWrecks then return end
    SetTimeout(3000, function() self:remove(p) end)
end

function Vehicles:detach()
    for p in pairs(self.byP) do self:remove(p) end
end

ES.RegisterComponent('vehicles', Vehicles)
