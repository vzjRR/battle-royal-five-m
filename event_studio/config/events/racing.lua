-- EVENT STUDIO — racing & obstacle presets. Copy a block, change id/name/options to create your own.

local podium = {
    placement = {
        [1] = { { type = 'cash', amount = 10000 } },
        [2] = { { type = 'cash', amount = 6000 } },
        [3] = { { type = 'cash', amount = 3000 } },
    },
    participation = { { type = 'cash', amount = 500 } },
}

ES.Definition({
    id = 'street_circuit', name = 'Downtown Street Circuit', mode = 'race', arena = 'downtown_circuit',
    description = 'Three laps through the heart of the city. Traffic is disabled in the event instance.',
    difficulty = 'medium', tags = { 'street', 'circuit' },
    players = { min = 2, max = 8 },
    timing = { registration = 180, duration = 600, grace = 45 },
    options = { laps = 3, vehicle = { model = 'sultan', type = 'automobile' } },
    rewards = podium,
})

ES.Definition({
    id = 'drag_strip', name = 'Runway Drag Race', mode = 'race', arena = 'lsia_drag',
    description = 'Standing start, straight line, pure speed.',
    difficulty = 'easy', tags = { 'drag' },
    players = { min = 2, max = 4 },
    timing = { registration = 90, duration = 120, grace = 10, countdown = 5 },
    options = { laps = 1, vehicle = { model = 'elegy2', type = 'automobile' }, checkpointRadius = 20 },
    rewards = { placement = { [1] = { { type = 'cash', amount = 5000 } } } },
})

ES.Definition({
    id = 'airport_time_trial', name = 'Airport Time Trial', mode = 'race', arena = 'lsia_time_trial',
    description = 'Ghosted time trial — set your personal best.',
    difficulty = 'easy', tags = { 'time trial', 'solo' },
    players = { min = 1, max = 16 },
    timing = { registration = 60, duration = 300, grace = 120 },
    options = { laps = 1, ghost = true, vehicle = { model = 'comet2', type = 'automobile' } },
    scoring = 'casual',
    rewards = { placement = { [1] = { { type = 'cash', amount = 3000 } } } },
})

ES.Definition({
    id = 'elimination_race', name = 'Elimination Circuit', mode = 'race', arena = 'downtown_circuit',
    description = 'Last place is eliminated every 45 seconds. Survive or win.',
    difficulty = 'hard', tags = { 'elimination' },
    players = { min = 3, max = 8 },
    timing = { registration = 180, duration = 900, grace = 20 },
    options = { laps = 5, eliminateEvery = 45, vehicle = { model = 'kuruma', type = 'automobile' } },
    scoring = 'competitive',
    rewards = podium,
})

ES.Definition({
    id = 'random_vehicle_race', name = 'Random Ride Race', mode = 'race', arena = 'downtown_circuit',
    description = 'Everyone gets a random car. Luck and skill.',
    difficulty = 'medium', tags = { 'random', 'fun' },
    players = { min = 2, max = 8 },
    timing = { registration = 120, duration = 600, grace = 45 },
    options = { laps = 2, random = true, pool = {
        { model = 'panto', type = 'automobile' }, { model = 'adder', type = 'automobile' }, { model = 'bison', type = 'automobile' },
        { model = 'blista', type = 'automobile' }, { model = 'banshee', type = 'automobile' }, { model = 'faggio', type = 'bike' },
    } },
    scoring = 'casual',
    rewards = podium,
})

ES.Definition({
    id = 'bike_sprint', name = 'Superbike Sprint', mode = 'race', arena = 'lsia_time_trial',
    description = 'Superbikes only around the airport loop.',
    difficulty = 'medium', tags = { 'bike' },
    players = { min = 2, max = 8 },
    timing = { registration = 120, duration = 400, grace = 30 },
    options = { laps = 2, vehicle = { model = 'bati', type = 'bike' } },
    rewards = podium,
})

ES.Definition({
    id = 'alamo_boat_race', name = 'Alamo Sea Boat Race', mode = 'race', arena = 'alamo_sea',
    description = 'Speedboats around the Alamo Sea.',
    difficulty = 'medium', tags = { 'boat' },
    players = { min = 2, max = 4 },
    timing = { registration = 150, duration = 600, grace = 45 },
    options = { laps = 1, vehicle = { model = 'speeder', type = 'boat' }, checkpointRadius = 18 },
    rewards = podium,
})

ES.Definition({
    id = 'legion_obstacle_run', name = 'Legion Square Obstacle Run', mode = 'race', arena = 'legion_obstacle',
    category = 'obstacle',
    description = 'On foot. Tight checkpoints, fastest time wins.',
    difficulty = 'easy', tags = { 'parkour', 'on foot' },
    players = { min = 1, max = 6 },
    timing = { registration = 90, duration = 240, grace = 60 },
    options = { laps = 1, onFoot = true, checkpointRadius = 4 },
    scoring = 'casual',
    rewards = { placement = { [1] = { { type = 'cash', amount = 2500 } } } },
})
