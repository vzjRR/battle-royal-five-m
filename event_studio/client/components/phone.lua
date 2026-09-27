-- EVENT STUDIO — "Events" app for phone and tablet resources.
-- The app is web/phone.html: the same event window as F7 (live & open, upcoming, leaderboard, tournaments, sign up,
-- join, leave, spectate), shown inside the phone. It calls our NUI callbacks directly, and every action still goes
-- through the server's RPC checks, so the app adds no new rights.
--
-- Supported (each only when that resource is started; turn any of them off in config/phone.lua):
--   LB Phone, LB Tablet, Quasar Smartphone PRO, YSeries (yseries / yphone / yflip-phone), 17mov Phone, GKSPhone.
--   NPWD v4 registers on the server (server/components/phone.lua).
-- qb-phone has no way for another resource to add an app; players there use the events window key (F7).

local cfg = ES.Config.Phone or {}
local RES = GetCurrentResourceName()
local NUI = ('https://cfx-nui-%s/'):format(RES)
local APP_ID = 'eventstudio'
local PAGE = 'web/phone.html'

local Phone = { added = {} }
ES.Phone = Phone

local function iconUrl()
    local icon = cfg.icon or 'web/img/app-icon.png'
    if icon:find('^https://') then return icon end
    return NUI .. icon
end

local function label() return cfg.name or 'Events' end
local function description() return cfg.description or 'See events, sign up and join.' end
local function preinstalled() return cfg.preinstalled ~= false end

-- One entry per phone / tablet. add() registers the app, remove() takes it away, close() closes the device if it
-- offers a way (used when the player is moved into an event).
local ADAPTERS = {
    {
        key = 'lbPhone', resources = { 'lb-phone' }, name = 'LB Phone',
        add = function(res)
            return exports[res]:AddCustomApp({
                identifier = APP_ID, name = label(), description = description(), developer = 'Krovix Store',
                defaultApp = preinstalled(), size = 2048,
                ui = RES .. '/' .. PAGE,
                icon = iconUrl(),
                fixBlur = true,
            })
        end,
        remove = function(res) return exports[res]:RemoveCustomApp(APP_ID) end,
        close = function(res) exports[res]:ToggleOpen(false) end,
    },
    {
        key = 'lbTablet', resources = { 'lb-tablet' }, name = 'LB Tablet',
        add = function(res)
            return exports[res]:AddCustomApp({
                identifier = APP_ID, resource = RES, name = label(), description = description(), developer = 'Krovix Store',
                defaultApp = preinstalled(), size = 2048,
                ui = PAGE .. '?device=tablet',   -- path inside `resource`
                icon = iconUrl(),
            })
        end,
        remove = function(res) return exports[res]:RemoveCustomApp(APP_ID) end,
        close = function(res) exports[res]:ToggleOpen(false) end,
    },
    {
        key = 'quasar', resources = { 'qs-smartphone-pro' }, name = 'Quasar Smartphone PRO',
        add = function(res)
            return exports[res]:addCustomApp({
                app = APP_ID, label = label(), description = description(), creator = 'Krovix Store',
                image = iconUrl(), ui = NUI .. PAGE,
                job = false, blockedJobs = {}, timeout = 5000, category = 'social', isGame = false, age = '16+',
                extraDescription = {},
            })
        end,
        remove = function(res) return exports[res]:removeCustomApp(APP_ID) end,
    },
    {
        key = 'yseries', resources = { 'yseries', 'yphone', 'yflip-phone' }, name = 'YSeries',
        ready = function(res)
            local ok, loaded = pcall(function() return exports[res]:GetDataLoaded() end)
            return not ok or loaded == true -- older builds without GetDataLoaded: go ahead
        end,
        add = function(res)
            return exports[res]:AddCustomApp({
                key = APP_ID, name = label(), defaultApp = preinstalled(),
                ui = NUI .. PAGE,
                icon = { yos = iconUrl(), humanoid = iconUrl() },
            })
        end,
        remove = function(res) return exports[res]:RemoveCustomApp(APP_ID) end,
    },
    {
        key = 'mov17', resources = { '17mov_Phone' }, name = '17mov Phone',
        add = function(res)
            return exports[res]:AddApplication({
                name = APP_ID, label = label(), resourceName = RES,
                ui = NUI .. PAGE, icon = iconUrl(),
                iconBackground = { angle = 135, colors = { '#1a1f2b', '#0b0d12' } },
                default = preinstalled(), preInstalled = preinstalled(), rating = 5,
            })
        end,
        remove = function(res) return exports[res]:RemoveApplication({ name = APP_ID, resourceName = RES }) end,
    },
    {
        key = 'gks', resources = { 'gksphone' }, name = 'GKSPhone',
        add = function(res)
            return exports[res]:AddCustomApp({
                name = label(), description = description(), icons = iconUrl(),
                appurl = NUI .. PAGE, url = '/customapp', categori = 'mix',
                show = true, startapp = preinstalled(), signal = false,
            })
        end,
        remove = function(res) return exports[res]:RemoveCustomApp(label()) end,
    },
}

local function enabled(a)
    if cfg.enabled == false then return false end
    return not cfg.devices or cfg.devices[a.key] ~= false
end

local function started(a)
    for _, res in ipairs(a.resources) do
        if GetResourceState(res) == 'started' then return res end
    end
end

---Register the app in one device (safe to call again: the device replaces or ignores a second add).
local function add(a, res)
    if not enabled(a) then return end
    CreateThread(function()
        if a.ready then
            for _ = 1, 60 do if a.ready(res) then break end Wait(1000) end
        end
        local ok, result, err = pcall(a.add, res)
        if ok and (result ~= false or tostring(err):find('EXISTS')) then
            Phone.added[a.key] = res
        else
            print(('[event_studio] could not add the Events app to %s: %s'):format(a.name, tostring(ok and (err or result) or result)))
        end
    end)
end

function Phone.addAll()
    for _, a in ipairs(ADAPTERS) do
        local res = started(a)
        if res and Phone.added[a.key] ~= res then add(a, res) end
    end
end

---Close every phone / tablet that can be closed from outside (LB Phone and LB Tablet today).
function Phone.close()
    for _, a in ipairs(ADAPTERS) do
        local res = Phone.added[a.key]
        if res and a.close then pcall(a.close, res) end
    end
end

-- The page asks for its data (messages from this resource do not reach an iframe inside another resource).
RegisterNUICallback('phone:init', function(_, cb)
    local info = ES.ServerInfo
    if not info then return cb({}) end
    cb({ ui = info.ui, strings = info.strings, locale = info.locale, staff = info.staff, role = info.role, scoring = info.scoring })
end)

RegisterNUICallback('phone:close', function(_, cb)
    Phone.close()
    cb({ ok = true })
end)

-- Wait until the server has answered client:ready, so the page has its texts and design.
CreateThread(function()
    while not ES.ServerInfo do Wait(1000) end
    Phone.addAll()
end)

-- A phone that starts (or restarts) after us gets the app again; a stopped phone forgets it.
local function adapterOf(name)
    for _, a in ipairs(ADAPTERS) do
        for _, res in ipairs(a.resources) do if res == name then return a end end
    end
end
AddEventHandler('onClientResourceStart', function(name)
    local a = adapterOf(name)
    if a and ES.ServerInfo then SetTimeout(1500, function() add(a, name) end) end
end)
AddEventHandler('onClientResourceStop', function(name)
    local a = adapterOf(name)
    if a and Phone.added[a.key] == name then Phone.added[a.key] = nil end
end)
RegisterNetEvent('17mov_Phone:Client:Ready', function()
    local a = adapterOf('17mov_Phone')
    if a and ES.ServerInfo and GetResourceState('17mov_Phone') == 'started' then add(a, '17mov_Phone') end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= RES then return end
    for _, a in ipairs(ADAPTERS) do
        local res = Phone.added[a.key]
        if res then pcall(a.remove, res) end
    end
end)

Phone.adapters = ADAPTERS
return Phone
