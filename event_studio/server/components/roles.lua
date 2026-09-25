-- EVENT STUDIO — component: roles
-- Assigns gameplay roles (juggernaut, VIP, hunter, runner …) with per-role health, armor and weapons.
-- Used by juggernaut, vip and hunters modes; any mode can use it.

local U = ES.Util

local Roles = {}
Roles.__index = Roles

---cfg = {
---  roles = { [id] = { label = 'Juggernaut', health = 1000, armor = 100, weapons = { ... }, color = '#ff3d71' } },
---  default = 'runner',       -- role for everyone not explicitly assigned
---}
function Roles.attach(inst, cfg)
    local self = setmetatable({ inst = inst, cfg = cfg, of = {} }, Roles)
    return self
end

function Roles:def(roleId) return self.cfg.roles[roleId] or {} end
function Roles:roleOf(p) return self.of[p] or self.cfg.default end

function Roles:members(roleId, activeOnly)
    local out = {}
    for _, p in ipairs(self.inst:allParticipants()) do
        if self:roleOf(p) == roleId and (not activeOnly or p.status == 'active') then out[#out + 1] = p end
    end
    return out
end

---Pick `count` random active participants (optionally from a filter) for a role.
function Roles:pick(roleId, count, filter)
    local pool = {}
    for _, p in ipairs(self.inst:activeParticipants()) do
        if (not filter or filter(p)) and self:roleOf(p) ~= roleId then pool[#pool + 1] = p end
    end
    U.shuffle(pool)
    local chosen = {}
    for i = 1, math.min(count, #pool) do
        self:set(pool[i], roleId)
        chosen[#chosen + 1] = pool[i]
    end
    return chosen
end

---Set a role and apply its loadout, health and armor.
function Roles:set(p, roleId, silent)
    self.of[p] = roleId
    p.role = roleId
    if p.src then
        local d = self:def(roleId)
        local g = self.inst.def.gameplay
        p.healthOverride, p.armorOverride = d.health, d.armor
        self.inst:push(p, 'role', { role = roleId, label = d.label or roleId, color = d.color,
            health = d.health or g.health, armor = d.armor or g.armor, silent = silent == true })
        local combat = self.inst:component('combat')
        if combat and d.weapons then combat:giveLoadout(p, d.weapons) end
        self.inst:syncState(p.src)
    end
    self.inst:dirty()
end

function Roles:clientSetup(p)
    if not p then return nil end
    local roleId = self:roleOf(p)
    local d = self:def(roleId)
    return { role = roleId, label = d.label or roleId, color = d.color }
end

function Roles:onJoin(p)
    if not self.of[p] then self.of[p] = self.cfg.default end
    self:set(p, self:roleOf(p), true)
end

ES.RegisterComponent('roles', Roles)
