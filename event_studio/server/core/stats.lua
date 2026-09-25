-- EVENT STUDIO — statistics, personal bests, leaderboards

local Stats = {}
ES.Stats = Stats

---Persist an instance's results and update aggregate stats.
function Stats.record(inst, rows)
    local summary = inst:summary()
    summary.finalState = 'COMPLETED'
    ES.Storage.recordInstance(summary, rows)

    local season = ES.Scoring.season()
    local statRows = {}
    for _, r in ipairs(rows) do
        if r.everActive and not r.removed and r.identifier then
            local completed = (r.status == 'finished' or r.status == 'active' or r.status == 'eliminated') and 1 or 0
            local base = {
                identifier = r.identifier, name = r.name, joined = 1, completed = completed,
                wins = r.placement == 1 and 1 or 0, podiums = (r.placement and r.placement <= 3) and 1 or 0,
                kills = r.kills or 0, deaths = r.deaths or 0, objectives = r.objectives or 0,
                points = r.points or 0, best_streak = r.bestStreak or 0,
            }
            for _, s in ipairs({ season, 'all' }) do
                for _, c in ipairs({ inst.def.category, '*' }) do
                    local row = ES.Util.deepCopy(base)
                    row.season, row.category = s, c
                    statRows[#statRows + 1] = row
                end
            end
            if inst.mode.personalBests and r.finishMs and r.status == 'finished' then
                local improved, previous = ES.Storage.submitBest(r.identifier, r.name, inst.def.id, r.finishMs)
                if improved and r.src then
                    ES.push(r.src, 'announce', { text = L('personal_best', ES.Util.fmtDuration(r.finishMs)), kind = 'success' })
                end
            end
        end
    end
    ES.Storage.addStats(statRows)
end

function Stats.leaderboard(category, season, limit)
    return ES.Storage.leaderboard(season or ES.Scoring.season(), category or '*', math.min(limit or 25, 100)) or {}
end

function Stats.player(identifier, season)
    return ES.Storage.playerStats(identifier, season or ES.Scoring.season()) or {}
end

function Stats.bests(defId, limit)
    return ES.Storage.bests(defId, math.min(limit or 10, 50)) or {}
end

---Leaderboard rows without identifiers (for players' NUI).
function Stats.publicRows(rows)
    local out = {}
    for i, r in ipairs(rows) do
        out[i] = { rank = i, name = r.name, points = r.points, wins = r.wins, podiums = r.podiums, joined = r.joined,
                   kills = r.kills, deaths = r.deaths, objectives = r.objectives, best_ms = r.best_ms }
    end
    return out
end

return Stats
