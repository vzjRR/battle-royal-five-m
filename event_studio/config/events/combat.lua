-- EVENT STUDIO — combat presets

local podium = {
    placement = {
        [1] = { { type = 'cash', amount = 8000 } },
        [2] = { { type = 'cash', amount = 4000 } },
        [3] = { { type = 'cash', amount = 2000 } },
    },
    participation = { { type = 'cash', amount = 500 } },
}

ES.Definition({
    id = 'docks_ffa', name = 'Docks Free-For-All', mode = 'deathmatch', arena = 'docks_yard',
    description = 'Everyone for themselves. First to 25 kills.',
    players = { min = 2, max = 16 }, timing = { registration = 150, duration = 600 },
    options = { killTarget = 25 },
    rewards = podium,
})

ES.Definition({
    id = 'team_deathmatch', name = 'Team Deathmatch', mode = 'deathmatch', arena = 'docks_yard',
    description = 'Red vs Blue. First team to 50 kills.',
    players = { min = 4, max = 16, teams = { count = 2, auto = true } }, timing = { registration = 180, duration = 900 },
    options = { killTarget = 50, weapons = { 'WEAPON_PISTOL', 'WEAPON_SMG', 'WEAPON_ASSAULTRIFLE' } },
    rewards = { placement = { [1] = { { type = 'cash', amount = 5000 } } }, participation = { { type = 'cash', amount = 500 } } },
})

ES.Definition({
    id = 'last_man_standing', name = 'Last Man Standing', mode = 'deathmatch', arena = 'docks_yard',
    description = 'One life. Be the last one alive.',
    difficulty = 'hard', players = { min = 3, max = 16 }, timing = { registration = 150, duration = 600 },
    options = { lives = 1, killTarget = 0, weapons = { 'WEAPON_PISTOL', 'WEAPON_PUMPSHOTGUN' } },
    scoring = 'competitive', rewards = podium,
})

ES.Definition({
    id = 'last_team_standing', name = 'Last Team Standing', mode = 'deathmatch', arena = 'docks_yard',
    description = 'Teams, one life per round, best of five rounds.',
    difficulty = 'hard', players = { min = 4, max = 12, teams = { count = 2, auto = true } }, timing = { registration = 180, duration = 1200 },
    options = { lives = 1, rounds = 5, killTarget = 0, weapons = { 'WEAPON_CARBINERIFLE', 'WEAPON_PISTOL' } },
    scoring = 'competitive',
    rewards = { placement = { [1] = { { type = 'cash', amount = 6000 } } } },
})

ES.Definition({
    id = 'pistols_only', name = 'Pistols Only', mode = 'deathmatch', arena = 'docks_yard',
    players = { min = 2, max = 16 }, timing = { registration = 120, duration = 480 },
    options = { killTarget = 20, weapons = { 'WEAPON_PISTOL', 'WEAPON_COMBATPISTOL', 'WEAPON_PISTOL50' } },
    rewards = podium,
})

ES.Definition({
    id = 'snipers_only', name = 'Snipers Only', mode = 'deathmatch', arena = 'sandy_airfield',
    players = { min = 2, max = 12 }, timing = { registration = 120, duration = 600 },
    options = { killTarget = 15, weapons = { 'WEAPON_SNIPERRIFLE', 'WEAPON_MARKSMANRIFLE' }, respawnDelay = 5 },
    rewards = podium,
})

ES.Definition({
    id = 'melee_brawl', name = 'Melee Brawl', mode = 'deathmatch', arena = 'docks_yard',
    description = 'Knives, bats and fists only.',
    players = { min = 2, max = 16 }, timing = { registration = 120, duration = 420 },
    options = { killTarget = 15, weapons = { 'WEAPON_KNIFE', 'WEAPON_BAT', 'WEAPON_CROWBAR' }, ammo = 1 },
    rewards = podium,
})

ES.Definition({
    id = 'shotgun_arena', name = 'Shotgun Arena', mode = 'deathmatch', arena = 'docks_yard',
    players = { min = 2, max = 12 }, timing = { registration = 120, duration = 420 },
    options = { killTarget = 20, weapons = { 'WEAPON_PUMPSHOTGUN', 'WEAPON_SAWNOFFSHOTGUN' } },
    rewards = podium,
})

ES.Definition({
    id = 'random_weapons', name = 'Random Arsenal', mode = 'deathmatch', arena = 'docks_yard',
    description = 'A random weapon every life.',
    players = { min = 2, max = 16 }, timing = { registration = 120, duration = 480 },
    options = { killTarget = 20, randomWeapons = true, weapons = { 'WEAPON_PISTOL', 'WEAPON_MICROSMG', 'WEAPON_PUMPSHOTGUN', 'WEAPON_ASSAULTRIFLE', 'WEAPON_SNIPERRIFLE', 'WEAPON_BAT' } },
    scoring = 'casual', rewards = podium,
})

ES.Definition({
    id = 'weapon_rotation', name = 'Weapon Rotation', mode = 'deathmatch', arena = 'docks_yard',
    description = 'Everyone switches weapon every 45 seconds.',
    players = { min = 2, max = 16 }, timing = { registration = 120, duration = 540 },
    options = { killTarget = 0, rotateEvery = 45, weapons = { 'WEAPON_PISTOL', 'WEAPON_SMG', 'WEAPON_PUMPSHOTGUN', 'WEAPON_CARBINERIFLE', 'WEAPON_SNIPERRIFLE' } },
    rewards = podium,
})

ES.Definition({
    id = 'pistol_duel', name = 'Pistol Duel', mode = 'deathmatch', arena = 'docks_yard',
    description = '1v1, one life per round, first to three rounds.',
    players = { min = 2, max = 2, spectators = true }, timing = { registration = 120, duration = 600, lobby = 5 },
    options = { lives = 1, rounds = 5, killTarget = 0, weapons = { 'WEAPON_PISTOL' }, respawnDelay = 2 },
    scoring = 'competitive',
    rewards = { placement = { [1] = { { type = 'cash', amount = 3000 } } } },
})

ES.Definition({
    id = 'pistol_duel_cup', name = 'Pistol Duel (Tournament)', mode = 'deathmatch', arena = 'docks_yard',
    description = 'Match definition used by duel tournaments. Hidden from the browser.',
    visibility = 'hidden',
    players = { min = 2, max = 2 }, timing = { registration = 45, duration = 420, lobby = 5, results = 8 },
    options = { lives = 1, rounds = 3, killTarget = 0, weapons = { 'WEAPON_PISTOL' } },
    scoring = 'competitive',
})

ES.Definition({
    id = 'gun_game', name = 'Gun Game', mode = 'gungame', arena = 'docks_yard',
    description = 'Every kill upgrades your weapon. Finish with the knife.',
    players = { min = 2, max = 16 }, timing = { registration = 150, duration = 600 },
    rewards = podium,
})
