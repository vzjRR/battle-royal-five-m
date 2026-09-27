-- Phone / tablet app: NPWD registration on the server, the app files, and the phone adapters' settings.
local H = T
local registered = {}
H.boot({ beforeLoad = function()
    Sim.resourceStates.npwd = 'started'
    Sim.resourceMeta.npwd = { version = '4.1.0' }
    Sim.foreignExports.npwd = { RegisterExternalApp = function(_, app) registered[#registered + 1] = app end }
end })

local function read(path)
    local f = io.open(Sim.root .. '/' .. path, 'rb')
    if not f then return nil end
    local s = f:read('a') f:close()
    return s
end

H.test('NPWD 4: the Events app is registered with this resource', function()
    Sim.advance(4000)
    H.eq(#registered, 1, 'registered once')
    H.eq(registered[1].id, 'eventstudio')
    H.eq(registered[1].resourceName, GetCurrentResourceName())
    H.eq(registered[1].name, Config.Phone.name)
end)

H.test('NPWD 3 is skipped (it cannot load outside apps this way)', function()
    registered = {}
    Sim.resourceMeta.npwd = { version = '3.16.0' }
    TriggerEvent('onResourceStart', 'npwd')
    Sim.advance(3000)
    H.eq(#registered, 0)
    Sim.resourceMeta.npwd = { version = '4.1.0' }
end)

H.test('app files exist and are listed in the manifest', function()
    local manifest = read('fxmanifest.lua')
    for _, f in ipairs({ 'web/phone.html', 'dist/web/app.js', 'web/img/app-icon.png', 'config/phone.lua', 'client/components/phone.lua', 'server/core/phone.lua' }) do
        H.ok(read(f), 'missing ' .. f)
    end
    H.ok(manifest:find("'web/phone.html'", 1, true), 'phone page served')
    H.ok(manifest:find("'dist/web/app.js'", 1, true), 'NPWD app served')
    H.ok(manifest:find("'config/phone.lua'", 1, true), 'phone config shared with the client')
    local page = read('web/phone.html')
    H.ok(page:find('data-embed="phone"', 1, true), 'phone page runs in app mode')
    H.ok(read('dist/web/app.js'):find('__npwd_ext_eventstudio', 1, true), 'NPWD global name matches the registered id')
end)

H.test('every phone and tablet can be turned off in config/phone.lua', function()
    local client = read('client/components/phone.lua')
    for key in pairs(Config.Phone.devices) do
        if key ~= 'npwd' then H.ok(client:find("key = '" .. key .. "'", 1, true), 'no adapter for ' .. key) end
    end
    for key in client:gmatch("key = '([%w]+)'") do H.ok(Config.Phone.devices[key] ~= nil, 'no config switch for ' .. key) end
end)

-- Runs client/components/phone.lua in a sandbox with fake phone resources and records every export call.
local function runClient(started, opts)
    opts = opts or {}
    local calls, callbacks, threads, handlers = {}, {}, {}, {}
    local fakeExports = setmetatable({}, { __index = function(_, res)
        return setmetatable({}, { __index = function(_, fn)
            return function(_, arg) calls[#calls + 1] = { res = res, fn = fn, arg = arg } return true end
        end })
    end })
    local env = setmetatable({
        ES = { Config = { Phone = opts.config or Config.Phone }, ServerInfo = { ui = { theme = 'krovix-gilded' }, strings = { a = 'b' }, locale = { code = 'en' } } },
        exports = fakeExports,
        GetCurrentResourceName = function() return 'event_studio' end,
        GetResourceState = function(r) return started[r] and 'started' or 'missing' end,
        RegisterNUICallback = function(name, fn) callbacks[name] = fn end,
        RegisterNetEvent = function(name, fn) handlers[name] = fn end,
        AddEventHandler = function(name, fn) handlers[name] = fn end,
        CreateThread = function(fn) threads[#threads + 1] = fn end,
        SetTimeout = function(_, fn) threads[#threads + 1] = fn end,
        Wait = function() end,
    }, { __index = _G })
    local chunk = assert(loadfile(Sim.root .. '/client/components/phone.lua', 't', env))
    chunk()
    local i = 1
    while threads[i] do threads[i]() i = i + 1 end -- run the boot thread and the add threads it starts
    return calls, callbacks, env.ES.Phone, handlers
end

local function find(calls, res, fn)
    for _, c in ipairs(calls) do if c.res == res and c.fn == fn then return c.arg end end
end

H.test('client: the app is added to every started phone and tablet with the right export and fields', function()
    local calls = runClient({ ['lb-phone'] = true, ['lb-tablet'] = true, ['qs-smartphone-pro'] = true, yphone = true, ['17mov_Phone'] = true, gksphone = true })
    local page = 'https://cfx-nui-event_studio/web/phone.html'
    local lb = find(calls, 'lb-phone', 'AddCustomApp')
    H.ok(lb, 'LB Phone') H.eq(lb.identifier, 'eventstudio') H.eq(lb.ui, 'event_studio/web/phone.html') H.eq(lb.defaultApp, true)
    local tab = find(calls, 'lb-tablet', 'AddCustomApp')
    H.ok(tab, 'LB Tablet') H.eq(tab.resource, 'event_studio') H.eq(tab.ui, 'web/phone.html?device=tablet')
    local qs = find(calls, 'qs-smartphone-pro', 'addCustomApp')
    H.ok(qs, 'Quasar') H.eq(qs.app, 'eventstudio') H.eq(qs.ui, page)
    local ys = find(calls, 'yphone', 'AddCustomApp')
    H.ok(ys, 'YSeries under its yphone name') H.eq(ys.key, 'eventstudio') H.eq(ys.ui, page) H.ok(ys.icon.yos and ys.icon.humanoid)
    local m17 = find(calls, '17mov_Phone', 'AddApplication')
    H.ok(m17, '17mov') H.eq(m17.name, 'eventstudio') H.eq(m17.resourceName, 'event_studio') H.eq(m17.ui, page)
    local gks = find(calls, 'gksphone', 'AddCustomApp')
    H.ok(gks, 'GKSPhone') H.eq(gks.appurl, page)
    H.eq(lb.icon, 'https://cfx-nui-event_studio/web/img/app-icon.png')
end)

H.test('client: nothing is added for phones that are not started, turned off, or when the app is disabled', function()
    local calls = runClient({})
    H.eq(#calls, 0, 'no phone resources')
    local cfg = { enabled = true, devices = { lbPhone = false } }
    calls = runClient({ ['lb-phone'] = true, ['lb-tablet'] = true }, { config = cfg })
    H.no(find(calls, 'lb-phone', 'AddCustomApp'), 'LB Phone turned off')
    H.ok(find(calls, 'lb-tablet', 'AddCustomApp'), 'LB Tablet still on')
    calls = runClient({ ['lb-phone'] = true }, { config = { enabled = false } })
    H.eq(#calls, 0, 'app disabled')
end)

H.test('client: the page gets its data from phone:init, and phone:close closes LB Phone / LB Tablet', function()
    local calls, callbacks, Phone = runClient({ ['lb-phone'] = true, ['lb-tablet'] = true })
    local got
    callbacks['phone:init']({}, function(d) got = d end)
    H.eq(got.ui.theme, 'krovix-gilded') H.eq(got.strings.a, 'b')
    callbacks['phone:close']({}, function() end)
    local closed = {}
    for _, c in ipairs(calls) do if c.fn == 'ToggleOpen' then closed[c.res] = c.arg end end
    H.eq(closed['lb-phone'], false) H.eq(closed['lb-tablet'], false)
    H.ok(Phone.close, 'teleports call ES.Phone.close')
end)
