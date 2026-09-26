-- Appearance: theme registry files, live settings from the Admin Center (validation, permissions, broadcast, persistence).
local H = T
H.boot()

local function exists(path)
    local f = io.open(Sim.root .. '/' .. path, 'rb')
    if f then f:close() return true end
    return false
end

H.test('every theme in the registry has its CSS, logo and artwork files; fonts are bundled', function()
    H.ok(#ES.Themes >= 8, 'at least 8 designs')
    local ids = {}
    for _, t in ipairs(ES.Themes) do
        H.no(ids[t.id], 'duplicate theme id ' .. t.id)
        ids[t.id] = true
        H.ok(exists('web/themes/' .. t.file .. '.css'), 'missing web/themes/' .. t.file .. '.css')
        if t.logo then H.ok(exists('web/' .. t.logo), 'missing web/' .. t.logo) end
        if t.art then H.ok(exists('web/' .. t.art), 'missing web/' .. t.art) end
        H.eq(#t.preview, 4, t.id .. ' preview colors')
        H.ok(t.shape == 'round' or t.shape == 'cut', t.id .. ' shape')
    end
    H.ok(ES.theme(Config.UI.theme), 'configured default theme exists')
    local css = io.open(Sim.root .. '/web/fonts/fonts.css'):read('a')
    for file in css:gmatch("url%('([^']+)'%)") do H.ok(exists('web/fonts/' .. file), 'missing font ' .. file) end
    H.ok(exists('web/fonts/OFL.txt'), 'font license shipped')
end)

H.test('client:ready sends the effective appearance with the theme list', function()
    local src = H.players(1, 950)[1]
    local ok, res = H.rpc(src, 'client:ready', {})
    H.ok(ok)
    H.eq(res.ui.theme, 'krovix-gilded')
    H.eq(res.ui.browserLayout, 'compact')
    H.ok(#res.ui.themes >= 8)
    H.eq(res.ui.extraThemes, nil, 'raw extraThemes list is not sent')
end)

H.test('appearance save: admin only, strict validation, broadcast to every player, persisted', function()
    local admin, player = table.unpack(H.players(2, 960))
    H.admin(admin)
    local okP, errP = H.rpc(player, 'admin:ui:save', { settings = { theme = 'krovix-obsidian' } })
    H.no(okP) H.eq(errP, 'forbidden')

    local bad = {
        { { theme = 'nope' }, 'unknown_theme' },
        { { browserLayout = 'fullscreen' }, 'invalid_layout' },
        { { colors = { accent = 'red; background:url(x)' } }, 'invalid_color' },
        { { colors = { accent = '#12345' } }, 'invalid_color' },
        { { brand = { logo = 'javascript:alert(1)' } }, 'invalid_image' },
        { { brand = { logo = 'img/../../server.cfg.png' } }, 'invalid_image' },
        { { artwork = 'https://evil.example/a.png") ; x: url("' }, 'invalid_image' },
        { { categories = { nosuch = { color = '#ffffff' } } }, 'invalid' },
        { { categories = { racing = { icon = '<img>' } } }, 'invalid' },
        { { browserKeepMoving = 'yes' }, 'invalid' },
    }
    for _, case in ipairs(bad) do
        Sim.advance(2600) -- stay under the save rate limit
        local ok, err = H.rpc(admin, 'admin:ui:save', { settings = case[1] })
        H.no(ok, 'accepted bad settings: ' .. case[2])
        H.eq(err, case[2])
    end

    H.clear(player)
    Sim.advance(2600)
    local ok, eff = H.rpc(admin, 'admin:ui:save', { settings = {
        theme = 'krovix-sapphire', browserLayout = 'docked', browserKeepMoving = true, hudPosition = 'top-left',
        colors = { accent = '#FF8800', text = '' }, brand = { title = '  Krovix RP  ', logo = false }, artwork = 'img/art/grid.svg',
        categories = { racing = { icon = 'anchor', color = '#00AAFF' } },
    } })
    H.ok(ok, tostring(eff))
    H.eq(eff.theme, 'krovix-sapphire')
    H.eq(eff.colors.accent, '#ff8800', 'colors normalised to lower case')
    H.eq(eff.colors.text, nil, 'empty color = design default')
    H.eq(eff.brand.title, 'Krovix RP', 'title trimmed')
    H.eq(eff.brand.subtitle, Config.UI.brand.subtitle, 'untouched fields keep the config value')
    H.eq(eff.brand.logo, false)
    H.eq(eff.categories.racing.icon, 'anchor')
    H.eq(eff.categories.combat.icon, Config.UI.categories.combat.icon, 'other categories untouched')
    local pushed = H.lastPush(player, 'ui')
    H.ok(pushed, 'every player receives the new look')
    H.eq(pushed.theme, 'krovix-sapphire')
    H.eq(pushed.browserLayout, 'docked')

    -- the browser cards follow the saved category colors
    local ok2, ready = H.rpc(player, 'client:ready', {})
    H.ok(ok2)
    H.eq(ready.ui.categories.racing.color, '#00aaff')

    -- persisted: a restart loads the saved settings
    ES.UI.overrides, ES.UI.cache = {}, nil
    ES.UI.load()
    H.eq(ES.UI.effective().theme, 'krovix-sapphire')
    H.eq(ES.UI.effective().browserKeepMoving, true)
end)

H.test('appearance reset needs confirmation and goes back to config/ui.lua', function()
    local admin = H.players(1, 970)[1]
    H.admin(admin)
    H.ok((H.rpc(admin, 'admin:ui:save', { settings = { theme = 'krovix-crimson' } })))
    local okNo, err = H.rpc(admin, 'admin:ui:reset', {})
    H.no(okNo) H.eq(err, 'confirm_required')
    local ok, eff = H.rpc(admin, 'admin:ui:reset', { confirm = true })
    H.ok(ok)
    H.eq(eff.theme, Config.UI.theme)
    ES.UI.overrides, ES.UI.cache = {}, nil
    ES.UI.load()
    H.eq(ES.UI.effective().theme, Config.UI.theme, 'reset is persisted')
end)

H.test('a corrupted saved document is ignored instead of breaking the UI', function()
    ES.Storage.saveDocument('setting', 'ui', { theme = 'deleted-theme', colors = { accent = 'nope' } })
    ES.UI.overrides, ES.UI.cache = {}, nil
    ES.UI.load()
    H.eq(ES.UI.effective().theme, Config.UI.theme)
    ES.Storage.deleteDocument('setting', 'ui')
end)
