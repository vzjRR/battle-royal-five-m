-- EVENT STUDIO — event definition registry (presets from config + builder/API definitions)

local U = ES.Util
local Defs = { list = {}, source = {} }
ES.Definitions = Defs

local rewardEntry = { type = 'table' }
local rewardList = { type = 'list', item = rewardEntry, maxItems = 16, optional = true }

local schema = {
    id = 'id',
    name = { type = 'string', maxLen = 64, minLen = 1 },
    description = { type = 'string', maxLen = 600, optional = true },
    mode = 'id',
    arena = { type = 'id', optional = true },
    category = { type = 'string', optional = true },
    icon = { type = 'string', maxLen = 128, optional = true },
    banner = { type = 'string', maxLen = 256, optional = true },
    visibility = { type = 'enum', values = { 'public', 'hidden', 'staff' }, optional = true },
    enabled = { type = 'boolean', default = true },
    status = { type = 'enum', values = { 'draft', 'published' }, default = 'published' },
    difficulty = { type = 'enum', values = { 'easy', 'medium', 'hard', 'extreme' }, optional = true },
    tags = { type = 'list', item = { type = 'string', maxLen = 24 }, maxItems = 8, optional = true },
    players = { type = 'table', optional = true },
    timing = { type = 'table', optional = true },
    gameplay = { type = 'table', optional = true },
    options = { type = 'table', optional = true },
    scoring = { type = 'any', optional = true },
    rewards = { type = 'table', optional = true },
}

local playersSchema = {
    min = { type = 'integer', min = 1, max = 256 },
    max = { type = 'integer', min = 1, max = 256 },
    spectators = 'boolean',
    spectateOnEliminate = 'boolean',
    reconnectGrace = { type = 'integer', min = 0, max = 600 },
    teams = { type = 'object', optional = true, fields = {
        count = { type = 'integer', min = 2, max = 8, default = 2 },
        size = { type = 'integer', min = 1, max = 64, optional = true },
        auto = { type = 'boolean', default = true },
        names = { type = 'list', item = { type = 'string', maxLen = 24 }, optional = true },
        colors = { type = 'list', item = { type = 'string', maxLen = 16 }, optional = true },
        fixed = { type = 'list', item = 'table', optional = true },  -- tournaments: pre-made teams
    } },
    invite = { type = 'list', item = 'integer', optional = true },
}

local timingSchema = {
    registration = { type = 'integer', min = 0, max = 86400 },
    extendOnce = { type = 'integer', min = 0, max = 3600 },
    lobby = { type = 'integer', min = 0, max = 600 },
    countdown = { type = 'integer', min = 0, max = 60 },
    duration = { type = 'integer', min = 0, max = 14400 },
    grace = { type = 'integer', min = 0, max = 600 },
    results = { type = 'integer', min = 3, max = 300 },
}

local gameplaySchema = {
    health = { type = 'integer', min = 100, max = 1000 },
    armor = { type = 'integer', min = 0, max = 100 },
    friendlyFire = 'boolean',
    restoreWeapons = 'boolean',
    blockInventoryWeapons = 'boolean',
}

local defaultTeamNames = { 'Red', 'Blue', 'Green', 'Yellow', 'Purple', 'Orange', 'Cyan', 'Pink' }
local defaultTeamColors = { '#ff4d5e', '#3d8bff', '#3dff8b', '#ffd23d', '#b36bff', '#ff9a3d', '#3dfff0', '#ff6bd6' }

local function validateRewards(r)
    if not r then return true end
    local limits = (Config.Rewards and Config.Rewards.limits) or {}
    local function checkList(list, path)
        if type(list) ~= 'table' then return false, path .. ': expected list' end
        for i, e in ipairs(list) do
            if type(e) ~= 'table' or type(e.type) ~= 'string' then return false, ('%s[%d]: missing type'):format(path, i) end
            if (e.type == 'cash' or e.type == 'bank' or e.type == 'xp') then
                if type(e.amount) ~= 'number' or e.amount <= 0 then return false, ('%s[%d]: invalid amount'):format(path, i) end
                local lim = limits[e.type]
                if lim and e.amount > lim then return false, ('%s[%d]: amount above limit %d'):format(path, i, lim) end
            elseif e.type == 'item' then
                if type(e.name) ~= 'string' or type(e.count or 1) ~= 'number' then return false, ('%s[%d]: invalid item'):format(path, i) end
                if limits.itemCount and (e.count or 1) > limits.itemCount then return false, ('%s[%d]: item count above limit'):format(path, i) end
            end
        end
        return true
    end
    if r.placement then
        for place, list in pairs(r.placement) do
            local ok, err = checkList(list, 'rewards.placement[' .. tostring(place) .. ']')
            if not ok then return false, err end
        end
    end
    for _, key in ipairs({ 'participation', 'winnerTeam' }) do
        if r[key] then
            local ok, err = checkList(r[key], 'rewards.' .. key)
            if not ok then return false, err end
        end
    end
    return true
end

---Validate + normalise a definition (merged with defaults). Returns ok, defOrError.
function Defs.validate(input)
    local ok, d = ES.Schema.validateFields(input, schema)
    if not ok then return false, d end
    local mode = ES.Modes[d.mode]
    if not mode then return false, 'unknown mode ' .. d.mode end

    local defaults = Config.General.definitionDefaults
    d.category = d.category or mode.category
    if not ES.Categories[d.category] then return false, 'invalid category' end
    d.visibility = d.visibility or defaults.visibility
    d.difficulty = d.difficulty or defaults.difficulty

    local okP, players = ES.Schema.validateFields(U.merge(defaults.players, d.players), playersSchema)
    if not okP then return false, 'players.' .. players end
    if players.min > players.max then return false, 'players.min must be <= players.max' end
    players.min = math.max(players.min, mode.minPlayers or 1)
    if mode.teams == 'required' and not players.teams then
        players.teams = { count = 2, auto = true }
    elseif mode.teams == 'none' then
        players.teams = nil
    end
    if players.teams then
        local t = players.teams
        t.names = t.names or {}
        t.colors = t.colors or {}
        for i = 1, t.count do
            t.names[i] = t.names[i] or defaultTeamNames[i]
            t.colors[i] = t.colors[i] or defaultTeamColors[i]
        end
    end
    d.players = players

    local okT, timing = ES.Schema.validateFields(U.merge(defaults.timing, d.timing), timingSchema)
    if not okT then return false, 'timing.' .. timing end
    d.timing = timing

    local okG, gameplay = ES.Schema.validateFields(U.merge(defaults.gameplay, d.gameplay), gameplaySchema)
    if not okG then return false, 'gameplay.' .. gameplay end
    d.gameplay = gameplay

    local okO, options = ES.Schema.validateFields(d.options or {}, mode.options)
    if not okO then return false, 'options.' .. options end
    d.options = options

    if mode.arena.none == true and not mode.arena.optional then
        d.arena = nil
    elseif d.arena or not mode.arena.optional then
        if not d.arena then return false, 'arena required for mode ' .. d.mode end
        local arena = ES.Arenas.get(d.arena)
        if not arena then return false, 'unknown arena ' .. d.arena end
        local sat, missing = ES.Arenas.satisfies(arena, mode.arena.requires)
        if not sat then return false, ('arena %s lacks %s required by %s'):format(d.arena, missing, d.mode) end
    end

    if d.scoring == nil then d.scoring = Config.Scoring.defaultProfile end
    if type(d.scoring) == 'string' and not Config.Scoring.profiles[d.scoring] then
        return false, 'unknown scoring profile ' .. d.scoring
    elseif type(d.scoring) ~= 'string' and type(d.scoring) ~= 'table' then
        return false, 'scoring must be a profile name or table'
    end

    local okR, errR = validateRewards(d.rewards)
    if not okR then return false, errR end

    if mode.validate then
        local okM, errM = mode.validate(d)
        if okM == false then return false, errM end
    end
    return true, d
end

function Defs.register(input, source)
    local ok, d = Defs.validate(input)
    if not ok then return false, d end
    Defs.list[d.id] = d
    Defs.source[d.id] = source or 'api'
    return true, d.id
end

function Defs.get(id) return Defs.list[id] end

function Defs.remove(id)
    Defs.list[id] = nil
    Defs.source[id] = nil
end

---Definitions visible to a player (published + enabled + visibility rules)
function Defs.isRunnable(d)
    return d and d.enabled and d.status == 'published'
end

function Defs.all()
    local out = {}
    for _, d in pairs(Defs.list) do out[#out + 1] = d end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

function Defs.summary(d)
    local ui = Config.UI.categories[d.category] or {}
    return {
        id = d.id, name = d.name, description = d.description, mode = d.mode, arena = d.arena,
        category = d.category, icon = d.icon or ui.icon, banner = d.banner, visibility = d.visibility,
        enabled = d.enabled, status = d.status, difficulty = d.difficulty, tags = d.tags,
        minPlayers = d.players.min, maxPlayers = d.players.max, teams = d.players.teams and d.players.teams.count or nil,
        duration = d.timing.duration, source = Defs.source[d.id], rewardPreview = ES.Rewards and ES.Rewards.preview(d) or nil,
    }
end

function Defs.loadAll()
    local n = 0
    for _, d in ipairs(ES.ConfigDefinitions or {}) do
        local ok, err = Defs.register(d, 'config')
        if ok then n = n + 1 else ES.Log.error('Definition %s invalid: %s', tostring(d.id), tostring(err)) end
    end
    for id, d in pairs(ES.Storage.loadDocuments('definition') or {}) do
        local ok, err = Defs.register(d, 'storage')
        if ok then n = n + 1 else ES.Log.error('Stored definition %s invalid: %s', id, tostring(err)) end
    end
    ES.Log.info('Loaded %d event definitions', n)
end

return Defs
