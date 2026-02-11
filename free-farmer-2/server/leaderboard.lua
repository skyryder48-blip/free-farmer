--[[
    free-farmer — Server Leaderboard System
    Score tracking, weekly/monthly resets, top player rankings.
]]

local Utils = _G.FarmUtils

-- =============================================================================
-- SCORE MANAGEMENT
-- =============================================================================

---@param identifier string
---@param points number
function UpdateLeaderboardScore(identifier, points)
    if not identifier or not points or points <= 0 then return end

    local now = os.time()

    MySQL.execute.await([[
        INSERT INTO farm_leaderboard (identifier, total_score, weekly_score, monthly_score, updated_at)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            total_score = total_score + VALUES(total_score),
            weekly_score = weekly_score + VALUES(weekly_score),
            monthly_score = monthly_score + VALUES(monthly_score),
            updated_at = ?
    ]], { identifier, points, points, points, now, now })
end

---@param identifier string
---@param name string
function UpdateLeaderboardName(identifier, name)
    if not identifier or not name then return end

    MySQL.execute.await([[
        INSERT INTO farm_leaderboard (identifier, character_name, updated_at)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE character_name = VALUES(character_name), updated_at = VALUES(updated_at)
    ]], { identifier, name, os.time() })
end

-- Export globally
_G.UpdateLeaderboardScore = UpdateLeaderboardScore
_G.UpdateLeaderboardName = UpdateLeaderboardName

-- =============================================================================
-- WEEKLY / MONTHLY RESET THREAD
-- =============================================================================

CreateThread(function()
    Wait(20000) -- Let resource load

    while true do
        Wait(3600000) -- Check every hour

        local now = os.time()
        local currentDate = os.date('*t', now)

        -- Weekly reset: Monday at midnight (wday 2 = Monday)
        if currentDate.wday == 2 and currentDate.hour == 0 then
            MySQL.execute.await('UPDATE farm_leaderboard SET weekly_score = 0')
            Utils.Log('[Leaderboard] Weekly scores reset')
        end

        -- Monthly reset: 1st of month at midnight
        if currentDate.day == 1 and currentDate.hour == 0 then
            MySQL.execute.await('UPDATE farm_leaderboard SET monthly_score = 0')
            Utils.Log('[Leaderboard] Monthly scores reset')
        end
    end
end)

-- =============================================================================
-- CALLBACKS
-- =============================================================================

--- Get leaderboard data
lib.callback.register('free-farmer:server:getLeaderboard', function(src, period)
    local scoreColumn = 'total_score'
    if period == 'weekly' then
        scoreColumn = 'weekly_score'
    elseif period == 'monthly' then
        scoreColumn = 'monthly_score'
    end

    -- Ensure leaderboard names are up to date for online players
    local players = exports.qbx_core:GetQBPlayers()
    for playerSrc, player in pairs(players) do
        local cid = player.PlayerData.citizenid
        local name = ('%s %s'):format(
            player.PlayerData.charinfo.firstname,
            player.PlayerData.charinfo.lastname
        )
        UpdateLeaderboardName(cid, name)
    end

    local leaderboard = MySQL.query.await(([[
        SELECT identifier, character_name, %s as score,
               total_score, weekly_score, monthly_score
        FROM farm_leaderboard
        ORDER BY %s DESC
        LIMIT 50
    ]]):format(scoreColumn, scoreColumn))

    if not leaderboard then return {} end

    -- Add rank numbers
    local result = {}
    for i, entry in ipairs(leaderboard) do
        result[#result + 1] = {
            rank = i,
            name = entry.character_name or 'Unknown',
            score = entry.score or 0,
            totalScore = entry.total_score or 0,
            weeklyScore = entry.weekly_score or 0,
            monthlyScore = entry.monthly_score or 0,
        }
    end

    return result
end)
