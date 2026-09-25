-- EVENT STUDIO — component: checkpoints
-- Ordered (races/parkour) with client intents validated by server coords + travel time,
-- or unordered/hidden (hunts) with fully server-side detection.

local U = ES.Util
local Log = ES.Log

local CP = {}
CP.__index = CP

---cfg = {
---  points = {...}, laps = 1, ordered = true, radius = 10, use3d = false,
---  serverDetect = false,   -- server finds proximity itself (no client intents); used by hunts
---  hidden = false,         -- do not send coordinates to clients (serverDetect required)
---  onCheckpoint = fn(p, index, lap), onLap = fn(p, lap), onComplete = fn(p)
---}
function CP.attach(inst, cfg)
    local pts = U.deepCopy(cfg.points or (inst.arena and inst.arena.checkpoints) or {})
    if cfg.reverse then
        local rev = {}
        for i = #pts, 1, -1 do rev[#rev + 1] = pts[i] end
        pts = rev
    end
    local self = setmetatable({
        inst = inst,
        cfg = cfg,
        points = pts,
        laps = cfg.laps or 1,
        ordered = cfg.ordered ~= false,
        radius = cfg.radius or 10.0,
        prog = {},     -- [participant] = { idx, lap, lastAt, lastPos, visited = {}, count, done }
        lastReset = {},
    }, CP)
    if cfg.hidden then cfg.serverDetect = true end
    return self
end

function CP:progressOf(p)
    local pr = self.prog[p]
    if not pr then
        local start = p.spawnPoint or (p.src and U.vec(GetEntityCoords(GetPlayerPed(p.src)))) or self.points[1]
        pr = { idx = 1, lap = 1, lastAt = nil, lastPos = start, visited = {}, count = 0, done = false }
        self.prog[p] = pr
    end
    return pr
end

function CP:radiusOf(i)
    return (self.points[i] and self.points[i].radius) or self.radius
end

function CP:distanceTo(pos, i)
    local pt = self.points[i]
    if self.cfg.use3d then return U.dist(pos, pt) end
    return U.dist2d(pos, pt)
end

---Accept checkpoint i for p (after validation).
function CP:accept(p, i)
    local pr = self:progressOf(p)
    local now = ES.now()
    pr.lastAt = now
    pr.lastPos = self.points[i]
    pr.count = pr.count + 1
    pr.lastIndex = i
    self.inst:addStat(p, 'checkpoints', 1)
    if self.ordered then
        pr.idx = pr.idx + 1
        if pr.idx > #self.points then
            if pr.lap < self.laps then
                pr.lap = pr.lap + 1
                pr.idx = 1
                self.inst:addStat(p, 'laps', 1)
                if self.cfg.onLap then self.cfg.onLap(p, pr.lap) end
            else
                pr.done = true
                self.inst:addStat(p, 'laps', 1)
            end
        end
    else
        pr.visited[i] = true
        if U.count(pr.visited) >= #self.points then pr.done = true end
    end
    if self.cfg.onCheckpoint then self.cfg.onCheckpoint(p, i, pr.lap) end
    self.inst:push(p, 'component', { name = 'checkpoints', update = self:personal(p) })
    if pr.done and self.cfg.onComplete then self.cfg.onComplete(p) end
end

function CP:personal(p)
    local pr = self:progressOf(p)
    local visited
    if not self.ordered then visited = U.keys(pr.visited) end
    return { next = pr.idx, lap = pr.lap, laps = self.laps, count = pr.count, total = #self.points,
             done = pr.done, visited = visited }
end

---Client intent: { index = n }
function CP:onAction(p, action, data)
    if action == 'reset' then return self:reset(p) end
    if action ~= 'checkpoint' then return nil end
    if self.cfg.serverDetect then return false, 'server_detect' end
    local st = self.inst.state
    if st ~= ES.Lifecycle.States.ACTIVE and st ~= ES.Lifecycle.States.FINISHING then return false, 'not_active' end
    if p.status ~= 'active' then return false, 'not_active' end
    local i = data and math.tointeger(data.index)
    local pr = self:progressOf(p)
    if pr.done then return false, 'done' end
    if not i or not self.points[i] then return false, 'bad_index' end
    if self.ordered and i ~= pr.idx then
        return false, 'wrong_order'
    elseif not self.ordered and pr.visited[i] then
        return false, 'visited'
    end
    local sec = Config.General.security
    local pos = U.vec(GetEntityCoords(GetPlayerPed(p.src)))
    local d = self:distanceTo(pos, i)
    if d > self:radiusOf(i) + (sec.checkpointTolerance or 8.0) then
        Log.security(p.src, 'checkpoint_far', { instanceId = self.inst.id, index = i, distance = U.round(d, 1) })
        return false, 'too_far'
    end
    local ref = pr.lastAt or (self.inst.clock.startedAt or ES.now())
    local travel = U.dist(pr.lastPos or self.points[i], self.points[i])
    local minMs = (travel / (sec.maxPlausibleSpeed or 140.0)) * 1000
    if ES.now() - ref < minMs then
        Log.security(p.src, 'checkpoint_too_fast', { instanceId = self.inst.id, index = i, ms = ES.now() - ref, minMs = math.floor(minMs) })
        return false, 'too_fast'
    end
    self:accept(p, i)
    return true, self:personal(p)
end

---Player asks to be put back at the last checkpoint (stuck / flipped).
function CP:reset(p)
    if p.status ~= 'active' then return false, 'not_active' end
    local now = ES.now()
    if self.lastReset[p] and now - self.lastReset[p] < 5000 then return false, 'cooldown' end
    self.lastReset[p] = now
    local pr = self:progressOf(p)
    local last = pr.lastIndex and self.points[pr.lastIndex] or p.spawnPoint
    if not last then return false, 'no_point' end
    local nextPt = self.points[pr.idx] or last
    local heading = math.deg(math.atan(nextPt.y - last.y, nextPt.x - last.x)) - 90.0
    local point = { x = last.x, y = last.y, z = last.z + 0.5, w = heading }
    local veh = self.inst:component('vehicles')
    if veh and veh:entityOf(p) then
        veh:provision(p, point)
    else
        self.inst:push(p, 'teleport', { coords = { x = point.x, y = point.y, z = point.z }, heading = heading })
    end
    pr.lastAt = now -- teleport must not count as fast travel
    pr.lastPos = point
    return true
end

---Race progress value for ranking (higher = further). Uses server coords.
function CP:progressValue(p)
    local pr = self:progressOf(p)
    local n = #self.points
    local base = (pr.lap - 1) * n + (pr.idx - 1)
    if pr.done or not p.src or not self.points[pr.idx] then return base end
    local pos = U.vec(GetEntityCoords(GetPlayerPed(p.src)))
    local prev = pr.lastPos or self.points[pr.idx]
    local seg = math.max(1.0, U.dist2d(prev, self.points[pr.idx]))
    local frac = U.clamp(1 - self:distanceTo(pos, pr.idx) / seg, 0, 0.99)
    return base + frac
end

function CP:tick()
    if not self.cfg.serverDetect then
        if self.cfg.trackProgress ~= false then
            for _, p in ipairs(self.inst:activeParticipants()) do p.progress = self:progressValue(p) end
        end
        return
    end
    for _, p in ipairs(self.inst:activeParticipants()) do
        local pr = self:progressOf(p)
        if not pr.done then
            local pos = U.vec(GetEntityCoords(GetPlayerPed(p.src)))
            if self.ordered then
                if self:distanceTo(pos, pr.idx) <= self:radiusOf(pr.idx) then self:accept(p, pr.idx) end
            else
                for i = 1, #self.points do
                    if not pr.visited[i] and self:distanceTo(pos, i) <= self:radiusOf(i) then
                        self:accept(p, i)
                        break
                    end
                end
            end
        end
    end
end
CP.tickWhileFinishing = true

---Nearest unvisited distance (hunts use it for warmer/colder hints).
function CP:nearestDistance(p)
    local pr = self:progressOf(p)
    local pos = U.vec(GetEntityCoords(GetPlayerPed(p.src)))
    local best
    for i = 1, #self.points do
        local candidate = self.ordered and (i == pr.idx) or (not self.ordered and not pr.visited[i])
        if candidate then
            local d = self:distanceTo(pos, i)
            if not best or d < best then best = d end
        end
    end
    return best
end

function CP:clientSetup(p)
    local points
    if not self.cfg.hidden then
        points = {}
        for i, pt in ipairs(self.points) do
            points[i] = { x = pt.x, y = pt.y, z = pt.z, radius = self:radiusOf(i), label = pt.label, clue = pt.clue, image = pt.image }
        end
    else
        points = {}
        for i, pt in ipairs(self.points) do points[i] = { clue = pt.clue, image = pt.image, label = pt.label } end
    end
    local setup = { points = points, ordered = self.ordered, hidden = self.cfg.hidden == true,
                    serverDetect = self.cfg.serverDetect == true, laps = self.laps, use3d = self.cfg.use3d == true,
                    nextCount = Config.UI.markers.nextCount or 2, allowReset = self.cfg.allowReset ~= false }
    if p then setup.personal = self:personal(p) end
    return setup
end

function CP:onLeave(p) end

ES.RegisterComponent('checkpoints', CP)
