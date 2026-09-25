-- EVENT STUDIO — mode & component registries

local U = ES.Util
ES.Modes = ES.Modes or {}
ES.Components = ES.Components or {}

local validCategories = {
    racing = true, vehicle = true, combat = true, objective = true, survival = true,
    hunt = true, obstacle = true, social = true, tournament = true,
}
ES.Categories = validCategories

---Register a game mode. See docs/EVENT_ENGINE.md §2.
function ES.RegisterMode(id, mode)
    assert(U.isId(id), 'mode id must be a safe id')
    assert(type(mode) == 'table', 'mode must be a table')
    assert(validCategories[mode.category], ('mode %s: invalid category %s'):format(id, tostring(mode.category)))
    mode.id = id
    mode.label = mode.label or id
    mode.teams = mode.teams or 'none'
    mode.options = mode.options or {}
    mode.rankBy = mode.rankBy or 'score'
    mode.arena = mode.arena or { requires = {} }
    ES.Modes[id] = mode
    if ES.Log then ES.Log.debug('Registered mode %s', id) end
    return true
end

---Register a reusable server component.
---component = { name, attach(inst, cfg) -> state, tick(inst, state, dt)?, detach(inst, state)?, clientSetup(inst, state, p)? }
function ES.RegisterComponent(name, component)
    component.name = name
    ES.Components[name] = component
end

---Public, JSON-safe mode list for the builder.
function ES.describeModes()
    local out = {}
    for id, m in pairs(ES.Modes) do
        out[#out + 1] = {
            id = id, label = m.label, category = m.category, teams = m.teams, description = m.description,
            options = ES.Schema.describe(m.options), requires = m.arena.requires or {}, needsArena = m.arena.none ~= true,
        }
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end
