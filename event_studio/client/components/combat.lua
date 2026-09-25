-- EVENT STUDIO — client component: combat (loadout apply, death detection → server hint)

local Combat = { active = false, dead = false, thread = false }
ES.Combat = Combat

local function killerServerId(ped)
    local src = GetPedSourceOfDeath(ped)
    if src == 0 or src == ped then return nil end
    if IsEntityAVehicle(src) then src = GetPedInVehicleSeat(src, -1) end
    if src ~= 0 and IsPedAPlayer(src) then
        local idx = NetworkGetPlayerIndexFromPed(src)
        if idx and idx ~= -1 then return GetPlayerServerId(idx) end
    end
    return nil
end

local function watch()
    if Combat.thread then return end
    Combat.thread = true
    CreateThread(function()
        while Combat.active do
            local ped = PlayerPedId()
            if not Combat.dead and (IsEntityDead(ped) or IsPedFatallyInjured(ped)) then
                Combat.dead = true
                ES.rpc('event:action', { action = 'died', data = { killer = killerServerId(ped) } })
            end
            Wait(250)
        end
        Combat.thread = false
    end)
end

function Combat.onRespawned() Combat.dead = false end

ES.RegisterClientComponent('combat', {
    setup = function(data)
        if not data.active then return end
        Combat.active = true
        Combat.dead = false
        local g = ES.Client.current and ES.Client.current.gameplay or {}
        if g.restoreWeapons ~= false then ES.World.snapshotWeapons() end -- idempotent; never lose own weapons
        ES.World.giveLoadout(data.weapons, true)
        local ped = PlayerPedId()
        local r = ES.Client.role or {}
        local hp, armor = r.health or g.health or 200, r.armor or g.armor or 0
        SetEntityMaxHealth(ped, math.max(200, hp))
        SetEntityHealth(ped, hp)
        SetPedArmour(ped, armor)
        SetCanAttackFriendly(ped, true, false)
        NetworkSetFriendlyFireOption(true)
        watch()
    end,
    clear = function()
        Combat.active = false
        Combat.dead = false
    end,
})
