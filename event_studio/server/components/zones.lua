-- EVENT STUDIO — component: zones
-- Server-computed occupancy, capture/ownership, and shrinking/moving safe zones.

local U = ES.Util

local Zones = {}
Zones.__index = Zones

---cfg = {
---  zones = { { id, x, y, z, radius, height, label }, ... },
---  captureSeconds = 5, teamBased = bool, requireVehicle = false,
---  safe = false,           -- safe-zone mode: being OUTSIDE is the danger (see outside())
---  color = '#3dd6ff'
---}
function Zones.attach(inst, cfg)
    local self = setmetatable({
        inst = inst,
        cfg = cfg,
        zones = {},
        order = {},
        occupants = {},   -- [id] = { participant, ... }
        owner = {},       -- [id] = key (team index or src)
        progress = {},    -- [id] = { key = k, value = 0..1 }
        contested = {},
        shrink = {},      -- [id] = { from, to, fromCenter, toCenter, start, duration }
    }, Zones)
    for i, z in ipairs(cfg.zones or (inst.arena and inst.arena.zones) or {}) do
        local id = z.id or tostring(i)
        local zone = { id = id, x = z.x, y = z.y, z = z.z, radius = z.radius or 15.0, height = z.height or 25.0,
                       label = z.label or id, index = i }
        self.zones[id] = zone
        self.order[#self.order + 1] = zone
        self.occupants[id] = {}
    end
    return self
end

function Zones:keyOf(p)
    if self.cfg.teamBased and p.team then return p.team end
    return p.src
end

function Zones:inside(zone, pos)
    return U.dist2d(pos, zone) <= zone.radius and math.abs(pos.z - zone.z) <= zone.height
end

function Zones:updateShrink(now)
    for id, s in pairs(self.shrink) do
        local zone = self.zones[id]
        local t = U.clamp((now - s.start) / s.duration, 0, 1)
        zone.radius = U.lerp(s.from, s.to, t)
        if s.toCenter then
            zone.x = U.lerp(s.fromCenter.x, s.toCenter.x, t)
            zone.y = U.lerp(s.fromCenter.y, s.toCenter.y, t)
        end
        if t >= 1 then self.shrink[id] = nil end
    end
end

function Zones:tick(dt)
    local now = ES.now()
    self:updateShrink(now)
    local positions = {}
    for _, p in ipairs(self.inst:activeParticipants()) do
        local ped = GetPlayerPed(p.src)
        if not self.cfg.requireVehicle or GetVehiclePedIsIn(ped, false) ~= 0 then
            positions[p] = U.vec(GetEntityCoords(ped))
        end
    end
    for _, zone in ipairs(self.order) do
        local occ = {}
        local keys = {}
        for p, pos in pairs(positions) do
            if self:inside(zone, pos) then
                occ[#occ + 1] = p
                keys[self:keyOf(p)] = true
            end
        end
        self.occupants[zone.id] = occ
        local n = U.count(keys)
        local wasContested = self.contested[zone.id]
        self.contested[zone.id] = n > 1
        if n == 1 and self.cfg.captureSeconds then
            local key = next(keys)
            local pr = self.progress[zone.id]
            if self.owner[zone.id] ~= key then
                if not pr or pr.key ~= key then pr = { key = key, value = 0 } end
                pr.value = pr.value + (dt / 1000) / math.max(0.1, self.cfg.captureSeconds)
                self.progress[zone.id] = pr
                if pr.value >= 1 then
                    local prev = self.owner[zone.id]
                    self.owner[zone.id] = key
                    self.progress[zone.id] = nil
                    self:onOwnerChange(zone, key, prev)
                end
            end
        elseif n == 0 then
            local pr = self.progress[zone.id]
            if pr then
                pr.value = pr.value - (dt / 1000) / math.max(0.1, self.cfg.captureSeconds or 5)
                if pr.value <= 0 then self.progress[zone.id] = nil end
            end
        end
        if wasContested ~= self.contested[zone.id] then self:pushZone(zone) end
    end
    -- progress pushes at most every 500 ms
    if not self.lastProgressPush or now - self.lastProgressPush >= 500 then
        self.lastProgressPush = now
        local any = {}
        for id, pr in pairs(self.progress) do any[#any + 1] = { id = id, key = pr.key, value = U.round(pr.value, 2) } end
        if #any > 0 or self.hadProgress then
            self.inst:broadcast('component', { name = 'zones', update = { progress = any } })
        end
        self.hadProgress = #any > 0
    end
end

function Zones:onOwnerChange(zone, key, prev)
    self:pushZone(zone)
    if self.cfg.onCapture then self.cfg.onCapture(zone, key, prev) end
end

function Zones:publicZone(zone)
    return { id = zone.id, x = zone.x, y = zone.y, z = zone.z, radius = zone.radius, height = zone.height,
             label = zone.label, owner = self.owner[zone.id], contested = self.contested[zone.id] or false }
end

function Zones:pushZone(zone)
    self.inst:broadcast('component', { name = 'zones', update = { zone = self:publicZone(zone) } })
end

---Animate radius (and optionally center) over durationMs. Client interpolates locally.
function Zones:shrinkTo(id, radius, durationMs, center)
    local zone = self.zones[id]
    if not zone then return end
    self.shrink[id] = { from = zone.radius, to = radius, start = ES.now(), duration = math.max(1, durationMs),
                        fromCenter = { x = zone.x, y = zone.y }, toCenter = center and U.vec(center) or nil }
    self.inst:broadcast('component', { name = 'zones', update = {
        shrink = { id = id, from = zone.radius, to = radius, durationMs = durationMs,
                   fromCenter = { x = zone.x, y = zone.y }, toCenter = center and { x = center.x, y = center.y } or nil },
    } })
end

function Zones:occupantsOf(id) return self.occupants[id] or {} end
function Zones:ownerOf(id) return self.owner[id] end
function Zones:isContested(id) return self.contested[id] == true end

---Is participant p outside zone id (server coords)?
function Zones:outside(p, id)
    local zone = self.zones[id]
    if not zone or not p.src then return false end
    return not self:inside(zone, U.vec(GetEntityCoords(GetPlayerPed(p.src))))
end

function Zones:clientSetup()
    local list = {}
    for i, z in ipairs(self.order) do list[i] = self:publicZone(z) end
    return { zones = list, safe = self.cfg.safe == true, teamBased = self.cfg.teamBased == true, color = self.cfg.color }
end

ES.RegisterComponent('zones', Zones)
