-- EVENT STUDIO — component: bounds (server-side out-of-arena detection)

local U = ES.Util

local Bounds = {}
Bounds.__index = Bounds

---cfg = { center, radius, minZ, maxZ, graceMs = 3000, action = 'eliminate'|'respawn'|callback(p) }
function Bounds.attach(inst, cfg)
    local arena = inst.arena or {}
    local b = arena.bounds or {}
    local self = setmetatable({
        inst = inst,
        center = U.vec(cfg.center or b.center or arena.center),
        radius = cfg.radius or b.radius or arena.radius or 100,
        minZ = cfg.minZ or b.minZ,
        maxZ = cfg.maxZ or b.maxZ,
        graceMs = cfg.graceMs or 3000,
        action = cfg.action or 'eliminate',
        outSince = {},
    }, Bounds)
    return self
end

function Bounds:isOutside(pos)
    if U.dist2d(pos, self.center) > self.radius then return true end
    if self.minZ and pos.z < self.minZ then return true end
    if self.maxZ and pos.z > self.maxZ then return true end
    return false
end

function Bounds:tick()
    local now = ES.now()
    local s = self.shrink
    if s then
        local t = U.clamp((now - s.start) / s.duration, 0, 1)
        self.radius = U.lerp(s.from, s.to, t)
        if t >= 1 then self.shrink = nil end
    end
    for _, p in ipairs(self.inst:activeParticipants()) do
        local pos = U.vec(GetEntityCoords(GetPlayerPed(p.src)))
        if self:isOutside(pos) then
            if not self.outSince[p] then
                self.outSince[p] = now
                self.inst:push(p, 'component', { name = 'bounds', update = { outside = true, graceMs = self.graceMs } })
            elseif now - self.outSince[p] >= self.graceMs then
                self.outSince[p] = nil
                self.inst:push(p, 'component', { name = 'bounds', update = { outside = false } })
                if type(self.action) == 'function' then
                    self.action(p)
                elseif self.action == 'respawn' then
                    self.inst:respawn(p)
                else
                    self.inst:eliminate(p, 'out_of_bounds')
                end
            end
        elseif self.outSince[p] then
            self.outSince[p] = nil
            self.inst:push(p, 'component', { name = 'bounds', update = { outside = false } })
        end
    end
end

function Bounds:setRadius(r)
    self.radius = r
    self.inst:broadcast('component', { name = 'bounds', update = { radius = r } })
end

---Animate the radius; the client interpolates locally from one push.
function Bounds:shrinkTo(radius, durationMs)
    self.shrink = { from = self.radius, to = radius, start = ES.now(), duration = math.max(1, durationMs) }
    self.inst:broadcast('component', { name = 'bounds', update = { shrink = { from = self.radius, to = radius, durationMs = durationMs } } })
end

function Bounds:clientSetup()
    return { center = self.center, radius = self.radius, minZ = self.minZ }
end

function Bounds:onLeave(p) self.outSince[p] = nil end

ES.RegisterComponent('bounds', Bounds)
