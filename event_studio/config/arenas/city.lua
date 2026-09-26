-- EVENT STUDIO — sample arenas (city). Coordinates are starting points: verify in-game and adjust
-- with the Admin Center arena builder ("Add point at my position"). Z values are snapped to the
-- ground client-side when a spawn is slightly off.
-- Point format: { x, y, z, h } or { x = , y = , z = , w = heading, radius = , label = , clue = , team = }

ES.Arena({
    id = 'downtown_circuit',
    route = 'road',
    name = 'Downtown Circuit',
    description = 'Street loop around Pillbox Hill and Legion Square.',
    center = { 215.0, -800.0, 30.7 },
    radius = 600,
    vehicleSpawns = {
        { 224.4, -1015.0, 29.0, 340.0 }, { 230.2, -1012.8, 29.0, 340.0 },
        { 221.9, -1022.6, 29.0, 340.0 }, { 227.7, -1020.4, 29.0, 340.0 },
        { 219.4, -1030.2, 29.0, 340.0 }, { 225.2, -1028.0, 29.0, 340.0 },
        { 216.9, -1037.8, 29.0, 340.0 }, { 222.7, -1035.6, 29.0, 340.0 },
    },
    checkpoints = {
        { 250.8, -930.6, 29.1 }, { 285.0, -835.0, 29.1 }, { 318.0, -740.0, 29.1 },
        { 395.2, -700.9, 29.1 }, { 402.6, -840.3, 29.1 }, { 398.4, -965.9, 29.2 },
        { 300.6, -1045.0, 29.2 }, { 226.0, -1000.0, 29.0, radius = 14.0, label = 'Start / Finish' },
    },
    spectator = { { 195.2, -933.8, 30.7 } },
})

ES.Arena({
    id = 'legion_obstacle',
    route = 'foot',
    name = 'Legion Square Obstacle Run',
    description = 'On-foot checkpoint course around Legion Square.',
    center = { 195.2, -933.8, 30.7 },
    radius = 150,
    spawns = {
        { 160.5, -990.2, 30.1, 340.0 }, { 162.5, -989.0, 30.1, 340.0 }, { 164.5, -987.8, 30.1, 340.0 },
        { 158.5, -991.4, 30.1, 340.0 }, { 156.5, -992.6, 30.1, 340.0 }, { 166.5, -986.6, 30.1, 340.0 },
    },
    checkpoints = {
        { 176.0, -960.0, 30.1, radius = 4.0 }, { 200.0, -930.0, 30.7, radius = 4.0 }, { 230.0, -900.0, 30.7, radius = 4.0 },
        { 215.0, -870.0, 30.5, radius = 4.0 }, { 180.0, -880.0, 30.5, radius = 4.0 }, { 150.0, -930.0, 30.1, radius = 4.0 },
        { 162.0, -985.0, 30.1, radius = 5.0, label = 'Finish' },
    },
})

ES.Arena({
    id = 'city_landmarks',
    route = 'foot',
    name = 'Los Santos Landmarks',
    description = 'Scavenger targets at famous landmarks across the city.',
    center = { -300.0, -600.0, 33.0 },
    radius = 3000,
    spawns = { { 195.2, -933.8, 30.7, 0.0 }, { 198.2, -930.8, 30.7, 0.0 }, { 192.2, -936.8, 30.7, 0.0 }, { 201.2, -927.8, 30.7, 0.0 } },
    vehicleSpawns = { { 215.0, -800.0, 30.7, 160.0 }, { 219.0, -802.0, 30.7, 160.0 }, { 223.0, -804.0, 30.7, 160.0 }, { 227.0, -806.0, 30.7, 160.0 } },
    targets = {
        { -1850.0, -1230.0, 13.0, radius = 12.0, label = 'Del Perro Pier', clue = 'Where the city ends in a wooden walkway above the waves.' },
        { 298.0, -584.0, 43.3, radius = 12.0, label = 'Pillbox Medical', clue = 'Doctors on a hill.' },
        { -425.0, 1123.0, 325.9, radius = 15.0, label = 'Galileo Observatory', clue = 'Look at the stars from above the city.' },
        { -544.0, -204.0, 38.2, radius = 12.0, label = 'City Hall', clue = 'Where the city is governed.' },
        { -1200.0, -1570.0, 4.6, radius = 12.0, label = 'Muscle Beach', clue = 'Lift heavy things by the sea.' },
        { -66.0, -802.0, 44.2, radius = 12.0, label = 'Tallest Tower', clue = 'The foot of the tallest building in town.' },
    },
})
