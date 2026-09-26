-- EVENT STUDIO — arena / location registry
-- Arenas come from config/arenas/*.lua (ES.Arenas.fromConfig) and from storage (builder / API).

local U = ES.Util
local Arenas = { list = {}, source = {} }
ES.Arenas = Arenas

local point = { type = 'vec3' }
local pointList = { type = 'list', item = 'table', maxItems = 256, optional = true }

local schema = {
    id = 'id',
    name = { type = 'string', maxLen = 64 },
    description = { type = 'string', maxLen = 256, optional = true },
    center = point,
    radius = { type = 'number', min = 5, max = 10000, default = 150 },
    spawns = pointList,
    teamSpawns = { type = 'list', item = 'table', maxItems = 8, optional = true },
    vehicleSpawns = pointList,
    checkpoints = pointList,
    zones = pointList,
    objectives = pointList,
    targets = pointList,
    spectator = pointList,
    bounds = { type = 'table', optional = true },
    finish = { type = 'table', optional = true },
    tags = { type = 'list', item = 'string', optional = true },
    -- what the route runs on, used by the route checker: road | water | open (tarmac, off-road) | foot | air
    route = { type = 'enum', values = { 'road', 'water', 'open', 'foot', 'air' }, optional = true },
    checked = { type = 'table', optional = true },   -- last route check: { at, by, problems }
}

---Route type of an arena: explicit `route`, else inferred from its points.
function Arenas.routeType(a)
    if a.route then return a.route end
    if a.checkpoints and #a.checkpoints > 0 then
        if a.vehicleSpawns and #a.vehicleSpawns > 0 then return 'road' end
        return 'foot'
    end
    return 'open'
end

local function normPoints(list)
    if not list then return nil end
    local out = {}
    for i, p in ipairs(list) do
        local v = U.vec(p)
        if not v then return nil, 'invalid point #' .. i end
        -- keep extra metadata fields (radius, id, label, clue, team, ...)
        if type(p) == 'table' then
            for k, val in pairs(p) do
                if type(k) == 'string' and k ~= 'x' and k ~= 'y' and k ~= 'z' then v[k] = val end
            end
        end
        v.w = v.w or v.h
        out[i] = v
    end
    return out
end

---Validate + normalise an arena table. Returns ok, arenaOrError.
function Arenas.validate(a)
    local ok, clean = ES.Schema.validateFields(a, schema)
    if not ok then return false, clean end
    for _, key in ipairs({ 'spawns', 'vehicleSpawns', 'checkpoints', 'zones', 'objectives', 'targets', 'spectator' }) do
        if clean[key] then
            local list, err = normPoints(clean[key])
            if not list then return false, key .. ': ' .. err end
            clean[key] = list
        end
    end
    if clean.teamSpawns then
        for t, list in ipairs(clean.teamSpawns) do
            local norm, err = normPoints(list)
            if not norm then return false, 'teamSpawns[' .. t .. ']: ' .. err end
            clean.teamSpawns[t] = norm
        end
    end
    if clean.bounds then
        local b = clean.bounds
        clean.bounds = { center = U.vec(b.center or clean.center), radius = tonumber(b.radius) or clean.radius,
                         minZ = tonumber(b.minZ), maxZ = tonumber(b.maxZ) }
    end
    if clean.finish then
        local f = U.vec(clean.finish)
        f.radius = tonumber(clean.finish.radius) or 10.0
        clean.finish = f
    end
    return true, clean
end

function Arenas.register(a, source)
    local ok, clean = Arenas.validate(a)
    if not ok then return false, clean end
    Arenas.list[clean.id] = clean
    Arenas.source[clean.id] = source or 'api'
    return true, clean.id
end

function Arenas.get(id) return Arenas.list[id] end

function Arenas.all()
    local out = {}
    for _, a in pairs(Arenas.list) do out[#out + 1] = a end
    table.sort(out, function(x, y) return x.name < y.name end)
    return out
end

---Does the arena satisfy mode requirements? (e.g. { 'checkpoints' })
function Arenas.satisfies(arena, requires)
    for _, key in ipairs(requires or {}) do
        local v = arena[key]
        if v == nil or (type(v) == 'table' and next(v) == nil) then return false, key end
    end
    return true
end

function Arenas.loadAll()
    local n = 0
    for _, a in ipairs(ES.ConfigArenas or {}) do
        local ok, err = Arenas.register(a, 'config')
        if ok then n = n + 1 else
            ES.Log.error('Arena %s invalid: %s', tostring(a.id), tostring(err))
            ES.LoadErrors = ES.LoadErrors or {}
            table.insert(ES.LoadErrors, 'arena ' .. tostring(a.id) .. ': ' .. tostring(err))
        end
    end
    for id, a in pairs(ES.Storage.loadDocuments('arena') or {}) do
        local ok, err = Arenas.register(a, 'storage')
        if ok then n = n + 1 else ES.Log.error('Stored arena %s invalid: %s', id, tostring(err)) end
    end
    ES.Log.info('Loaded %d arenas', n)
end

return Arenas
