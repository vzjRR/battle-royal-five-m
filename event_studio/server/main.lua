-- EVENT STUDIO — server boot

local Log = ES.Log

local function waitForFrameworks()
    -- give frameworks that are still starting a moment (resource order issues)
    local res = Config.Framework.resources
    for _ = 1, 50 do
        local starting = false
        for _, name in pairs(res) do
            if GetResourceState(name) == 'starting' then starting = true end
        end
        if GetResourceState('oxmysql') == 'starting' then starting = true end
        if not starting then return end
        Wait(200)
    end
end

Citizen.CreateThread(function()
    waitForFrameworks()
    ES.Storage.init()
    ES.initBridge()
    ES.Arenas.loadAll()
    ES.Definitions.loadAll()
    ES.Scheduler.loadAll()
    ES.Tournaments.loadAll()
    ES.Scheduler.start()
    ES.Director.start()
    ES.Tournaments.start()
    ES.ready = true
    GlobalState['es:ready'] = true
    Log.info('Event Studio %s ready — %d modes, %d definitions, %d arenas (Krovix Store)',
        ES.version, ES.Util.count(ES.Modes), ES.Util.count(ES.Definitions.list), ES.Util.count(ES.Arenas.list))
    if GetConvar('onesync', 'off') == 'off' then
        Log.error('OneSync is disabled. Event Studio requires OneSync (set onesync on).')
    end
end)
