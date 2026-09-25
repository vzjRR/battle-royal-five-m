-- EVENT STUDIO — vehicle, objective, survival, hunt and social presets

local podium = {
    placement = {
        [1] = { { type = 'cash', amount = 7500 } },
        [2] = { { type = 'cash', amount = 4000 } },
        [3] = { { type = 'cash', amount = 2000 } },
    },
    participation = { { type = 'cash', amount = 500 } },
}

-- VEHICLE ---------------------------------------------------------------

ES.Definition({
    id = 'sumo_classic', name = 'Sumo', mode = 'sumo', arena = 'lsia_sumo',
    description = 'Push everyone out of the ring. Sudden death shrinks the ring after 2:30.',
    players = { min = 2, max = 8 }, timing = { registration = 120, duration = 300 },
    options = { vehicle = { model = 'sandking', type = 'automobile' } },
    rewards = podium,
})

ES.Definition({
    id = 'demolition_derby', name = 'Demolition Derby', mode = 'sumo', arena = 'lsia_derby',
    description = 'Wreck the others. Last running vehicle wins.',
    players = { min = 3, max = 8 }, timing = { registration = 150, duration = 420 },
    options = { vehicle = { model = 'dukes', type = 'automobile' }, eliminateOnWreck = true, suddenDeathAfter = 240, graceMs = 3000 },
    rewards = podium,
})

ES.Definition({
    id = 'vehicle_koth', name = 'Vehicle King of the Hill', mode = 'koth', arena = 'sandy_airfield',
    category = 'vehicle',
    description = 'Hold Bravo — but only while inside a vehicle.',
    players = { min = 2, max = 12 }, timing = { registration = 150, duration = 480 },
    options = { requireVehicle = true, vehicle = { model = 'sandking', type = 'automobile' }, weapons = {}, scoreTarget = 180 },
    rewards = podium,
})

-- OBJECTIVE -------------------------------------------------------------

ES.Definition({
    id = 'airfield_koth', name = 'Airfield King of the Hill', mode = 'koth', arena = 'sandy_airfield',
    description = 'Hold the active zone. It moves every 90 seconds.',
    players = { min = 2, max = 16 }, timing = { registration = 150, duration = 600 },
    options = { style = 'hill', rotateEvery = 90, scoreTarget = 300 },
    rewards = podium,
})

ES.Definition({
    id = 'airfield_domination', name = 'Airfield Domination', mode = 'koth', arena = 'sandy_airfield',
    description = 'Capture and hold Alpha, Bravo and Charlie. Team with the most points wins.',
    players = { min = 4, max = 16, teams = { count = 2, auto = true } }, timing = { registration = 180, duration = 900 },
    options = { style = 'domination', captureSeconds = 8, scoreTarget = 600 },
    rewards = { placement = { [1] = { { type = 'cash', amount = 5000 } } }, participation = { { type = 'cash', amount = 500 } } },
})

ES.Definition({
    id = 'airfield_ctf', name = 'Airfield Capture the Flag', mode = 'ctf', arena = 'sandy_airfield',
    description = 'Red vs Blue. Three captures wins.',
    players = { min = 4, max = 16, teams = { count = 2, auto = true } }, timing = { registration = 180, duration = 900 },
    rewards = { placement = { [1] = { { type = 'cash', amount = 6000 } } }, participation = { { type = 'cash', amount = 500 } } },
})

-- SURVIVAL --------------------------------------------------------------

ES.Definition({
    id = 'shrinking_zone', name = 'Desert Shrinking Zone', mode = 'zone_survival', arena = 'senora_desert',
    description = 'One life. The safe zone shrinks in four phases. Last one alive wins.',
    difficulty = 'hard', players = { min = 3, max = 32 }, timing = { registration = 180, duration = 600 },
    scoring = 'competitive', rewards = podium,
})

ES.Definition({
    id = 'limited_ammo_zone', name = 'Limited Ammo Survival', mode = 'zone_survival', arena = 'senora_desert',
    description = 'Twelve bullets. Make them count.',
    difficulty = 'extreme', players = { min = 3, max = 24 }, timing = { registration = 150, duration = 540 },
    options = { ammo = 12, weapons = { 'WEAPON_PISTOL' } },
    rewards = podium,
})

-- HUNT ------------------------------------------------------------------

ES.Definition({
    id = 'city_scavenger', name = 'City Scavenger Hunt', mode = 'hunt', arena = 'city_landmarks',
    description = 'Visit every landmark in any order. Vehicles provided.',
    players = { min = 1, max = 16 }, timing = { registration = 180, duration = 1200 },
    options = { vehicle = { model = 'blista', type = 'automobile' }, radius = 12 },
    rewards = podium,
})

ES.Definition({
    id = 'hidden_treasure', name = 'Hidden Treasure Trail', mode = 'hunt', arena = 'city_landmarks',
    description = 'Follow the clues. Locations are hidden — warmer / colder hints guide you.',
    difficulty = 'hard', players = { min = 1, max = 16 }, timing = { registration = 180, duration = 1500 },
    options = { ordered = true, hidden = true, vehicle = { model = 'blista', type = 'automobile' }, radius = 15 },
    rewards = podium,
})

-- SOCIAL ----------------------------------------------------------------

ES.Definition({
    id = 'red_light_green_light', name = 'Red Light, Green Light', mode = 'redlight', arena = 'lsia_runway_field',
    description = 'Move on green. Freeze on red. Reach the finish line.',
    players = { min = 2, max = 32 }, timing = { registration = 120, duration = 240 },
    scoring = 'casual', rewards = podium,
})

ES.Definition({
    id = 'freeze_challenge', name = 'Freeze Challenge', mode = 'redlight', arena = 'lsia_runway_field',
    description = 'Do not move. At all. Survivors share the win.',
    players = { min = 2, max = 32 }, timing = { registration = 90, duration = 90 },
    options = { freezeOnly = true, tolerance = 0.6 },
    scoring = 'casual',
    rewards = { participation = { { type = 'cash', amount = 1000 } } },
})

ES.Definition({
    id = 'trivia_night', name = 'Trivia Night', mode = 'trivia',
    description = 'Ten questions, fifteen seconds each. Speed bonus for fast answers.',
    players = { min = 2, max = 64 }, timing = { registration = 180, lobby = 5 },
    options = { count = 10, questionSet = 'general' },
    scoring = 'casual', rewards = podium,
})

ES.Definition({
    id = 'reaction_test', name = 'Reaction Test', mode = 'reaction',
    description = 'Press when the screen says GO. Early presses cost points.',
    players = { min = 2, max = 64 }, timing = { registration = 120, lobby = 5 },
    scoring = 'casual', rewards = podium,
})

ES.Definition({
    id = 'staff_challenge', name = 'Staff Challenge', mode = 'custom',
    description = 'A staff-hosted challenge. Follow the host\'s instructions; staff award points.',
    visibility = 'public', players = { min = 1, max = 64 }, timing = { registration = 120, duration = 900 },
    options = { instructions = 'Listen to the host. Points are awarded by staff.' },
    scoring = 'casual',
})
