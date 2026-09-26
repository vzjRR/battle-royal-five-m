-- EVENT STUDIO — live appearance settings (theme, layout, colors, branding) edited from the Admin Center.
-- Config.UI is the base; saved overrides (storage document setting/ui) are merged on top and pushed to every client.

local U, Log, RPC = ES.Util, ES.Log, ES.RPC

local UI = { overrides = {} }
ES.UI = UI

local COLOR_KEYS = { 'accent', 'accent2', 'background', 'panel', 'text', 'good', 'warn', 'bad' }
local LAYOUTS = { compact = true, docked = true, full = true }
local HUD_POS = { ['top-right'] = true, ['top-left'] = true }

local function isHex(v)
    return type(v) == 'string' and (v:match('^#%x%x%x$') or v:match('^#%x%x%x%x%x%x$') or v:match('^#%x%x%x%x%x%x%x%x$')) ~= nil
end

---Image reference: false/'auto', a file under web/img/, or an https URL without quotes, spaces or parentheses.
local function isImage(v)
    if v == false or v == 'auto' then return true end
    if type(v) ~= 'string' or #v > 300 then return false end
    if v:match('^img/[%w_%-/]+%.[%a]+$') and not v:find('..', 1, true) then
        local ext = v:match('%.(%a+)$'):lower()
        return ext == 'png' or ext == 'svg' or ext == 'webp' or ext == 'jpg' or ext == 'jpeg'
    end
    return v:match('^https://[%w%-%._~:/%%?#@!$&*+,;=]+$') ~= nil
end

local function cleanText(v, max)
    if type(v) ~= 'string' then return nil end
    v = v:gsub('[%c]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #v == 0 or #v > max then return nil end
    return v
end

---Validate and normalise an overrides table. Returns clean table or nil, error.
function UI.validate(s)
    if type(s) ~= 'table' then return nil, 'invalid' end
    local out = {}
    if s.theme ~= nil then
        if type(s.theme) ~= 'string' or not ES.theme(s.theme) then return nil, 'unknown_theme' end
        out.theme = s.theme
    end
    if s.browserLayout ~= nil then
        if not LAYOUTS[s.browserLayout] then return nil, 'invalid_layout' end
        out.browserLayout = s.browserLayout
    end
    if s.browserKeepMoving ~= nil then
        if type(s.browserKeepMoving) ~= 'boolean' then return nil, 'invalid' end
        out.browserKeepMoving = s.browserKeepMoving
    end
    if s.hudPosition ~= nil then
        if not HUD_POS[s.hudPosition] then return nil, 'invalid' end
        out.hudPosition = s.hudPosition
    end
    if s.artwork ~= nil then
        if not isImage(s.artwork) then return nil, 'invalid_image' end
        out.artwork = s.artwork
    end
    if s.brand ~= nil then
        if type(s.brand) ~= 'table' then return nil, 'invalid' end
        out.brand = {}
        if s.brand.title ~= nil then out.brand.title = cleanText(s.brand.title, 48) or nil end
        if s.brand.subtitle ~= nil then out.brand.subtitle = cleanText(s.brand.subtitle, 64) or nil end
        if s.brand.logo ~= nil then
            if not isImage(s.brand.logo) then return nil, 'invalid_image' end
            out.brand.logo = s.brand.logo
        end
    end
    if s.colors ~= nil then
        if type(s.colors) ~= 'table' then return nil, 'invalid' end
        out.colors = {}
        for _, k in ipairs(COLOR_KEYS) do
            local v = s.colors[k]
            if v ~= nil and v ~= '' then
                if not isHex(v) then return nil, 'invalid_color' end
                out.colors[k] = v:lower()
            end
        end
    end
    if s.categories ~= nil then
        if type(s.categories) ~= 'table' then return nil, 'invalid' end
        out.categories = {}
        for cat, c in pairs(s.categories) do
            if type(cat) ~= 'string' or not Config.UI.categories[cat] or type(c) ~= 'table' then return nil, 'invalid' end
            local entry = {}
            if c.color ~= nil and c.color ~= '' then
                if not isHex(c.color) then return nil, 'invalid_color' end
                entry.color = c.color:lower()
            end
            if c.icon ~= nil and c.icon ~= '' then
                if type(c.icon) ~= 'string' or #c.icon > 24 or c.icon:find('[%c<>"\'`]') then return nil, 'invalid' end
                entry.icon = c.icon
            end
            out.categories[cat] = entry
        end
    end
    return out
end

local function merge(base, over)
    local out = U.deepCopy(base)
    for k, v in pairs(over or {}) do
        if type(v) == 'table' and type(out[k]) == 'table' then out[k] = merge(out[k], v) else out[k] = v end
    end
    return out
end

---Config.UI merged with the saved overrides, plus the theme list for the NUI.
function UI.effective()
    if UI.cache then return UI.cache end
    local ui = merge(Config.UI, UI.overrides)
    if not ES.theme(ui.theme) then ui.theme = 'krovix-gilded' end
    ui.themes = ES.allThemes()
    ui.extraThemes = nil
    UI.cache = ui
    return ui
end

function UI.load()
    local docs = ES.Storage.loadDocuments('setting') or {}
    local saved = docs.ui
    if saved then
        local clean, err = UI.validate(saved)
        if clean then UI.overrides = clean UI.cache = nil else Log.warn('Saved UI settings ignored: %s', tostring(err)) end
    end
end

local function broadcast()
    UI.cache = nil
    ES.push(-1, 'ui', UI.effective())
end

function UI.save(overrides, actor)
    UI.overrides = overrides
    ES.Storage.saveDocument('setting', 'ui', overrides, actor)
    broadcast()
end

function UI.reset(actor)
    UI.overrides = {}
    ES.Storage.deleteDocument('setting', 'ui')
    broadcast()
end

RPC.register('admin:ui:get', { perm = 'admin.open', rate = { burst = 5, per = 10 } }, function()
    return { effective = UI.effective(), overrides = UI.overrides, base = Config.UI }
end)

RPC.register('admin:ui:save', { perm = 'ui.edit', schema = { settings = 'table' }, rate = { burst = 4, per = 10 } }, function(src, data)
    local clean, err = UI.validate(data.settings)
    if not clean then return false, err end
    UI.save(clean, Log.actorLabel(src))
    Log.audit('ui.saved', src, nil, { theme = clean.theme, layout = clean.browserLayout })
    return UI.effective()
end)

RPC.register('admin:ui:reset', { perm = 'ui.edit', confirm = true, rate = { burst = 2, per = 10 } }, function(src)
    UI.reset(Log.actorLabel(src))
    Log.audit('ui.reset', src)
    return UI.effective()
end)

return UI
