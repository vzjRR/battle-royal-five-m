-- EVENT STUDIO — component: spawns (spawn point allocation + teleport/respawn orders)

local U = ES.Util

local Spawns = {}
Spawns.__index = Spawns

---cfg = { points = {...}, teamPoints = { [team] = {...} }, protectionMs = 3000, strategy = 'sequential'|'random'|'farthest' }
function Spawns.attach(inst, cfg)
    local arena = inst.arena or {}
    local self = setmetatable({
        inst = inst,
        points = cfg.points or arena.spawns or {},
        teamPoints = cfg.teamPoints or arena.teamSpawns or {},
        protectionMs = cfg.protectionMs or 3000,
        strategy = cfg.strategy or 'sequential',
        cursor = {},
        assigned = {},   -- [participant] = point (initial)
    }, Spawns)
    if #self.points == 0 and arena.center then self.points = { arena.center } end
    return self
end

function Spawns:listFor(p)
    if p.team and self.teamPoints[p.team] and #self.teamPoints[p.team] > 0 then
        return self.teamPoints[p.team], 't' .. p.team
    end
    return self.points, 'all'
end

---Pick a spawn point for a participant.
function Spawns:pick(p)
    local list, key = self:listFor(p)
    if #list == 0 then return nil end
    if self.strategy == 'random' then return U.pick(list) end
    if self.strategy == 'farthest' then
        local best, bestD = list[1], -1
        for _, pt in ipairs(list) do
            local nearest = math.huge
            for src, other in pairs(self.inst.participants) do
                if other ~= p and other.status == 'active' and (not p.team or other.team ~= p.team) then
                    local d = U.dist(pt, U.vec(GetEntityCoords(GetPlayerPed(src))))
                    if d < nearest then nearest = d end
                end
            end
            if nearest > bestD then best, bestD = pt, nearest end
        end
        return best
    end
    self.cursor[key] = (self.cursor[key] or 0) % #list + 1
    return list[self.cursor[key]]
end

---Teleport (no heal). Used at LOBBY entry and admin teleports.
function Spawns:teleport(p, point)
    point = point or self:pick(p)
    if not point or not p.src then return end
    self.assigned[p] = self.assigned[p] or point
    p.spawnPoint = point
    self.inst:push(p, 'teleport', { coords = { x = point.x, y = point.y, z = point.z }, heading = point.w or 0.0 })
end

---Full respawn with health/armor + spawn protection.
function Spawns:respawn(p, point)
    point = point or self:pick(p)
    if not point or not p.src then return end
    p.spawnPoint = point
    local g = self.inst.def.gameplay
    self.inst:push(p, 'respawn', {
        coords = { x = point.x, y = point.y, z = point.z }, heading = point.w or 0.0,
        health = p.healthOverride or g.health, armor = p.armorOverride or g.armor, protectionMs = self.protectionMs,
    })
end

---Place every active participant (called by modes in setup).
function Spawns:placeAll()
    local list = self.inst:activeParticipants()
    table.sort(list, function(a, b) return a.joinSeq < b.joinSeq end)
    for _, p in ipairs(list) do self:teleport(p) end
end

function Spawns:onJoin(p) self:respawn(p) end

ES.RegisterComponent('spawns', Spawns)
