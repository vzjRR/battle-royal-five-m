-- EVENT STUDIO — sample arenas (LSIA airport). Verify in-game and adjust as needed.

ES.Arena({
    id = 'lsia_drag',
    name = 'LSIA Drag Strip',
    description = 'Straight-line sprint on the airport runway.',
    center = { -1300.0, -2500.0, 13.9 },
    radius = 700,
    vehicleSpawns = { { -1175.0, -2320.0, 13.9, 150.0 }, { -1181.0, -2316.5, 13.9, 150.0 }, { -1187.0, -2313.0, 13.9, 150.0 }, { -1193.0, -2309.5, 13.9, 150.0 } },
    checkpoints = {
        { -1260.0, -2470.0, 13.9, radius = 20.0 },
        { -1390.0, -2695.0, 13.9, radius = 25.0, label = 'Finish' },
    },
})

ES.Arena({
    id = 'lsia_time_trial',
    name = 'LSIA Time Trial',
    description = 'Technical loop around taxiways.',
    center = { -1250.0, -2700.0, 13.9 },
    radius = 900,
    vehicleSpawns = { { -1037.0, -2730.0, 13.8, 240.0 }, { -1041.0, -2735.0, 13.8, 240.0 }, { -1045.0, -2740.0, 13.8, 240.0 }, { -1049.0, -2745.0, 13.8, 240.0 } },
    checkpoints = {
        { -1150.0, -2800.0, 13.9 }, { -1310.0, -2900.0, 13.9 }, { -1500.0, -2980.0, 13.9 },
        { -1600.0, -2830.0, 13.9 }, { -1440.0, -2610.0, 13.9 }, { -1250.0, -2560.0, 13.9 },
        { -1040.0, -2720.0, 13.9, radius = 15.0, label = 'Finish' },
    },
})

ES.Arena({
    id = 'lsia_sumo',
    name = 'LSIA Sumo Ring',
    description = 'Flat tarmac ring — leave the circle and you are out.',
    center = { -1150.0, -2900.0, 13.9 },
    radius = 40,
    bounds = { center = { -1150.0, -2900.0, 13.9 }, radius = 40.0, minZ = 8.0 },
    vehicleSpawns = {
        { -1150.0, -2870.0, 13.9, 180.0 }, { -1150.0, -2930.0, 13.9, 0.0 }, { -1120.0, -2900.0, 13.9, 90.0 }, { -1180.0, -2900.0, 13.9, 270.0 },
        { -1129.0, -2879.0, 13.9, 135.0 }, { -1171.0, -2921.0, 13.9, 315.0 }, { -1129.0, -2921.0, 13.9, 45.0 }, { -1171.0, -2879.0, 13.9, 225.0 },
    },
})

ES.Arena({
    id = 'lsia_derby',
    name = 'LSIA Derby Bowl',
    description = 'Larger tarmac area for demolition derby.',
    center = { -1250.0, -3050.0, 13.9 },
    radius = 90,
    bounds = { center = { -1250.0, -3050.0, 13.9 }, radius = 90.0, minZ = 8.0 },
    vehicleSpawns = {
        { -1250.0, -2980.0, 13.9, 180.0 }, { -1250.0, -3120.0, 13.9, 0.0 }, { -1180.0, -3050.0, 13.9, 90.0 }, { -1320.0, -3050.0, 13.9, 270.0 },
        { -1200.0, -3000.0, 13.9, 135.0 }, { -1300.0, -3100.0, 13.9, 315.0 }, { -1200.0, -3100.0, 13.9, 45.0 }, { -1300.0, -3000.0, 13.9, 225.0 },
    },
})

ES.Arena({
    id = 'lsia_runway_field',
    name = 'LSIA Runway Field',
    description = 'Start line and finish line 120 m apart for Red Light, Green Light.',
    center = { -1100.0, -2640.0, 13.9 },
    radius = 150,
    spawns = {
        { -1100.0, -2580.0, 13.9, 180.0 }, { -1096.0, -2580.0, 13.9, 180.0 }, { -1104.0, -2580.0, 13.9, 180.0 }, { -1092.0, -2580.0, 13.9, 180.0 },
        { -1108.0, -2580.0, 13.9, 180.0 }, { -1088.0, -2580.0, 13.9, 180.0 }, { -1112.0, -2580.0, 13.9, 180.0 }, { -1084.0, -2580.0, 13.9, 180.0 },
    },
    finish = { -1100.0, -2700.0, 13.9, radius = 12.0 },
})
