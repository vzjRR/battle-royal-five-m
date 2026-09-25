-- EVENT STUDIO — scoring profiles (shared so the NUI can explain scoring)
-- Match score ranks players inside an event. Season points are awarded after results
-- from the profile below and feed the leaderboards.

Config.Scoring = {
    season = 'monthly',               -- monthly | quarterly | yearly | any fixed string e.g. 'S1'
    defaultProfile = 'standard',

    profiles = {
        standard = {
            placement = { 100, 75, 50, 35, 25, 20, 15, 10 }, -- 1st, 2nd, ...
            participation = 10,       -- everyone who was active at least once
            kill = 5, assist = 0, death = 0,
            objective = 10, checkpoint = 0, lap = 0,
            survivalPerMinute = 0,
            streak = { every = 3, bonus = 5 },
            abandonPenalty = -10,     -- left / disconnected and did not return
            disqualifyPenalty = -25,
        },
        casual = {
            placement = { 50, 35, 25, 15, 10 },
            participation = 15,
            kill = 2, objective = 5,
            abandonPenalty = 0,
        },
        competitive = {
            placement = { 150, 100, 70, 50, 35, 25, 15, 10, 5, 5 },
            participation = 5,
            kill = 8, assist = 3, objective = 15,
            streak = { every = 5, bonus = 10 },
            abandonPenalty = -25, disqualifyPenalty = -50,
        },
    },
}
