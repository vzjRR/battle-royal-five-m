-- EVENT STUDIO — NPWD 4 registers phone apps on the server (the other phones are handled in
-- client/components/phone.lua). NPWD then loads dist/web/app.js, which shows web/phone.html.

local cfg = Config.Phone or {}
local RES = GetCurrentResourceName()

local function npwdMajor()
    local v = GetResourceMetadata('npwd', 'version', 0)
    return tonumber(v and v:match('^(%d+)'))
end

local function registerNpwd()
    if cfg.enabled == false or (cfg.devices and cfg.devices.npwd == false) then return end
    if GetResourceState('npwd') ~= 'started' then return end
    local major = npwdMajor()
    if major and major < 4 then
        ES.Log.info('NPWD %s found: outside apps need NPWD 4 or newer, so the Events app is not added (players use the events window key).', tostring(major))
        return
    end
    local ok, err = pcall(function()
        exports.npwd:RegisterExternalApp({ id = 'eventstudio', resourceName = RES, name = cfg.name or 'Events' })
    end)
    if ok then ES.Log.info('Events app added to NPWD') else ES.Log.warn('Could not add the Events app to NPWD: %s', tostring(err)) end
end

AddEventHandler('onResourceStart', function(name)
    if name == 'npwd' then SetTimeout(2000, registerNpwd) end
end)
CreateThread(function()
    Wait(3000)
    registerNpwd()
end)
