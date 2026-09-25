-- EVENT STUDIO — scheduler & rotations (server only)
-- Schedules/rotations created in the admin center are stored in the database and merged with these.
--
-- Rule types:
--   { type = 'once', date = '2026-12-31', time = '21:00' }
--   { type = 'daily', time = '20:00' }
--   { type = 'weekly', days = { 5 }, time = '21:00' }       -- 1 = Monday ... 7 = Sunday
--   { type = 'monthly', day = 1, time = '19:00' }
--   { type = 'interval', minutes = 90, from = '14:00', to = '23:30' }

Config.Scheduler = {
    enabled = true,
    tickSeconds = 30,
    utcOffsetMinutes = nil,        -- nil = server local time; set e.g. 60 to force UTC+1
    defaultLeadMinutes = 5,        -- registration opens this long before the start time

    schedules = {
        { id = 'friday_street_race', enabled = true, definition = 'street_circuit',
          rule = { type = 'weekly', days = { 5 }, time = '21:00' } },
        { id = 'saturday_tdm', enabled = true, definition = 'team_deathmatch',
          rule = { type = 'weekly', days = { 6 }, time = '20:00' } },
        { id = 'sunday_hunt', enabled = true, definition = 'city_scavenger',
          rule = { type = 'weekly', days = { 7 }, time = '18:00' } },
        { id = 'weekly_rotation', enabled = false, rotation = 'default_week',
          rule = { type = 'daily', time = '20:30' } },
    },

    -- A rotation resolves to a definition for the day. pick = random | sequential | leastRecent
    rotations = {
        default_week = {
            pick = 'leastRecent',
            days = {
                [1] = { category = 'racing' },
                [2] = { category = 'combat' },
                [3] = { category = 'social' },
                [4] = { category = 'vehicle' },
                [5] = { definitions = { 'pistol_duel_cup' } },  -- tournament night example
                [6] = { category = 'objective' },
                [7] = { category = 'hunt' },
            },
        },
    },
}
