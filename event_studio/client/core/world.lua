-- EVENT STUDIO — client world control: teleport, freeze, respawn, loadout snapshot/restore, exit restore

local World = { frozen = false, snapshot = nil, protectedUntil = 0 }
ES.World = World

local function bridge() return ES.ClientBridge or {} end

local function groundZ(x, y, z)
    for _, probe in ipairs({ z + 2.0, z + 50.0, 800.0 }) do
        local found, gz = GetGroundZFor_3dCoord(x, y, probe, false)
        if found then return gz end
    end
    return nil
end

---Teleport with fade and collision loading. snap = adjust Z to ground if the given Z is off.
function World.teleport(coords, heading, snap)
    local ped = PlayerPedId()
    local x, y, z = coords.x + 0.0, coords.y + 0.0, coords.z + 0.0
    DoScreenFadeOut(250)
    local t = GetGameTimer()
    while not IsScreenFadedOut() and GetGameTimer() - t < 1000 do Wait(0) end
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
    end
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, (heading or 0.0) + 0.0)
    t = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() - t < 3000 do Wait(0) end
    if snap ~= false then
        local gz = groundZ(x, y, z)
        if gz and math.abs(gz - z) > 2.5 then SetEntityCoordsNoOffset(ped, x, y, gz + 1.0, false, false, false) end
    end
    DoScreenFadeIn(350)
end

function World.freeze(frozen)
    World.frozen = frozen
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    FreezeEntityPosition(ped, frozen)
    if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then FreezeEntityPosition(veh, frozen) end
end

-- Weapons ---------------------------------------------------------------------

local knownWeapons = {
    'WEAPON_KNIFE', 'WEAPON_BAT', 'WEAPON_CROWBAR', 'WEAPON_FLASHLIGHT', 'WEAPON_NIGHTSTICK', 'WEAPON_HAMMER', 'WEAPON_MACHETE',
    'WEAPON_SWITCHBLADE', 'WEAPON_KNUCKLE', 'WEAPON_WRENCH', 'WEAPON_HATCHET', 'WEAPON_POOLCUE', 'WEAPON_GOLFCLUB', 'WEAPON_BOTTLE', 'WEAPON_DAGGER',
    'WEAPON_PISTOL', 'WEAPON_PISTOL_MK2', 'WEAPON_COMBATPISTOL', 'WEAPON_APPISTOL', 'WEAPON_PISTOL50', 'WEAPON_SNSPISTOL', 'WEAPON_HEAVYPISTOL',
    'WEAPON_VINTAGEPISTOL', 'WEAPON_REVOLVER', 'WEAPON_STUNGUN', 'WEAPON_FLAREGUN', 'WEAPON_MARKSMANPISTOL', 'WEAPON_CERAMICPISTOL',
    'WEAPON_MICROSMG', 'WEAPON_SMG', 'WEAPON_SMG_MK2', 'WEAPON_ASSAULTSMG', 'WEAPON_COMBATPDW', 'WEAPON_MACHINEPISTOL', 'WEAPON_MINISMG',
    'WEAPON_PUMPSHOTGUN', 'WEAPON_SAWNOFFSHOTGUN', 'WEAPON_ASSAULTSHOTGUN', 'WEAPON_BULLPUPSHOTGUN', 'WEAPON_HEAVYSHOTGUN', 'WEAPON_DBSHOTGUN',
    'WEAPON_ASSAULTRIFLE', 'WEAPON_ASSAULTRIFLE_MK2', 'WEAPON_CARBINERIFLE', 'WEAPON_CARBINERIFLE_MK2', 'WEAPON_ADVANCEDRIFLE',
    'WEAPON_SPECIALCARBINE', 'WEAPON_BULLPUPRIFLE', 'WEAPON_COMPACTRIFLE', 'WEAPON_MG', 'WEAPON_COMBATMG', 'WEAPON_GUSENBERG',
    'WEAPON_SNIPERRIFLE', 'WEAPON_HEAVYSNIPER', 'WEAPON_MARKSMANRIFLE', 'WEAPON_MUSKET', 'WEAPON_RPG', 'WEAPON_GRENADELAUNCHER',
    'WEAPON_MINIGUN', 'WEAPON_GRENADE', 'WEAPON_STICKYBOMB', 'WEAPON_MOLOTOV', 'WEAPON_SMOKEGRENADE', 'WEAPON_PETROLCAN', 'WEAPON_FIREEXTINGUISHER',
}

---Remember the player's weapons so they can be restored after the event.
function World.snapshotWeapons()
    if World.snapshot then return end
    local ped = PlayerPedId()
    local list = {}
    for _, name in ipairs(knownWeapons) do
        local hash = GetHashKey(name)
        if HasPedGotWeapon(ped, hash, false) then
            list[#list + 1] = { hash = hash, ammo = GetAmmoInPedWeapon(ped, hash) }
        end
    end
    World.snapshot = { weapons = list, health = GetEntityHealth(ped), armor = GetPedArmour(ped) }
end

function World.restoreWeapons()
    local snap = World.snapshot
    World.snapshot = nil
    local ped = PlayerPedId()
    RemoveAllPedWeapons(ped, true)
    if not snap then return end
    for _, w in ipairs(snap.weapons) do GiveWeaponToPed(ped, w.hash, w.ammo, false, false) end
    SetPedArmour(ped, snap.armor or 0)
end

function World.giveLoadout(weapons, clear)
    local ped = PlayerPedId()
    if clear then RemoveAllPedWeapons(ped, true) end
    for i, w in ipairs(weapons or {}) do
        local hash = GetHashKey(w.name)
        GiveWeaponToPed(ped, hash, w.ammo or 250, false, i == 1)
    end
end

-- Respawn ---------------------------------------------------------------------

function World.respawn(data)
    local c = data.coords
    local ped = PlayerPedId()
    DoScreenFadeOut(200)
    Wait(250)
    NetworkResurrectLocalPlayer(c.x + 0.0, c.y + 0.0, c.z + 0.0, (data.heading or 0.0) + 0.0, true, false)
    ped = PlayerPedId()
    ClearPedBloodDamage(ped)
    ClearPedTasksImmediately(ped)
    if bridge().revive then pcall(bridge().revive) end
    World.teleport(c, data.heading, true)
    ped = PlayerPedId()
    SetEntityMaxHealth(ped, math.max(200, data.health or 200))
    SetEntityHealth(ped, data.health or 200)
    SetPedArmour(ped, data.armor or 0)
    if data.protectionMs and data.protectionMs > 0 then
        World.protectedUntil = GetGameTimer() + data.protectionMs
        CreateThread(function()
            SetEntityInvincible(ped, true)
            SetEntityAlpha(ped, 170, false)
            while GetGameTimer() < World.protectedUntil do Wait(100) end
            SetEntityInvincible(ped, false)
            ResetEntityAlpha(ped)
        end)
    end
    if ES.Combat then ES.Combat.onRespawned() end
end

-- Enter / exit ----------------------------------------------------------------

function World.onEnter(snap)
    if World.entered then return end
    World.entered = true
    local g = snap.gameplay or {}
    if g.restoreWeapons ~= false then World.snapshotWeapons() end
    if bridge().onEnterEvent then pcall(bridge().onEnterEvent, g) end
    if ES.ClientHooks and ES.ClientHooks.onEnterEvent then pcall(ES.ClientHooks.onEnterEvent, snap) end
end

function World.onExit(data)
    local wasEntered = World.entered
    World.entered = false
    World.freeze(false)
    local ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    ResetEntityAlpha(ped)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    SetLocalPlayerAsGhost(false)
    if IsEntityDead(ped) then
        local c = GetEntityCoords(ped)
        NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
        ped = PlayerPedId()
        if bridge().revive then pcall(bridge().revive) end
    end
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
        Wait(300)
    end
    if wasEntered or World.snapshot then World.restoreWeapons() end
    if data and data.coords then World.teleport(data.coords, data.heading, true) end
    if bridge().onLeaveEvent then pcall(bridge().onLeaveEvent) end
    if ES.ClientHooks and ES.ClientHooks.onLeaveEvent then pcall(ES.ClientHooks.onLeaveEvent, data) end
end

ES.on('teleport', function(d) CreateThread(function() World.teleport(d.coords, d.heading, true) end) end)
ES.on('freeze', function(d) World.freeze(d.frozen) end)
ES.on('respawn', function(d) CreateThread(function() World.respawn(d) end) end)
ES.on('loadout', function(d)
    if ES.Client.current and not World.snapshot then World.snapshotWeapons() end
    World.giveLoadout(d.weapons, d.clear)
end)
