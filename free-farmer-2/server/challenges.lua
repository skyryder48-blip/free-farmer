--[[
    free-farmer — Server Challenge System
    Daily challenge generation, progress tracking, completion rewards.
    3 active challenges per player, auto-refreshed every 24 hours.
]]

local Utils = _G.FarmUtils

-- =============================================================================
-- HELPERS
-- =============================================================================

---@param challengeTypeId string
---@return table|nil
local function GetChallengeTypeById(challengeTypeId)
    for _, ct in ipairs(Config.Challenges.types) do
        if ct.id == challengeTypeId then
            return ct
        end
    end
    return nil
end

---@param identifier string
local function GenerateChallenge(identifier)
    local challengeType = Config.Challenges.types[math.random(#Config.Challenges.types)]
    local requirements = challengeType.generateRequirements()
    local now = os.time()
    local expiresAt = now + Config.Challenges.refreshInterval

    MySQL.insert.await([[
        INSERT INTO farm_challenges (identifier, challenge_type, requirements, progress, completed, expires_at, created_at)
        VALUES (?, ?, ?, ?, 0, ?, ?)
    ]], {
        identifier,
        challengeType.id,
        json.encode(requirements),
        json.encode({}),
        expiresAt,
        now,
    })
end

---@param identifier string
local function RefreshPlayerChallenges(identifier)
    local now = os.time()

    -- Expire old challenges
    MySQL.update.await([[
        DELETE FROM farm_challenges
        WHERE identifier = ? AND completed = 0 AND expires_at < ?
    ]], { identifier, now })

    -- Count active
    local activeCount = MySQL.scalar.await([[
        SELECT COUNT(*) FROM farm_challenges
        WHERE identifier = ? AND completed = 0 AND expires_at >= ?
    ]], { identifier, now }) or 0

    -- Generate new ones to fill slots
    local needed = Config.Challenges.maxActive - activeCount
    for _ = 1, needed do
        GenerateChallenge(identifier)
    end
end

-- =============================================================================
-- CHALLENGE PROGRESS TRACKING
-- =============================================================================

---@param src number Player server ID
---@param action string Action type: 'harvest', 'plant', 'milk', 'collect_eggs', 'feed_animal', 'water_animal', 'breed', 'process', 'care'
---@param data table Action data: { crop?, amount?, count? }
function UpdateChallengeProgress(src, action, data)
    local citizenid = Utils.GetCitizenId(src)
    if not citizenid then return end

    local now = os.time()

    -- Get active challenges
    local challenges = MySQL.query.await([[
        SELECT * FROM farm_challenges
        WHERE identifier = ? AND completed = 0 AND expires_at >= ?
    ]], { citizenid, now })

    if not challenges then return end

    for _, challenge in ipairs(challenges) do
        local requirements = json.decode(challenge.requirements) or {}
        local progress = json.decode(challenge.progress) or {}

        local updated = false

        -- Match action to challenge requirement
        if requirements.action == action then
            if action == 'harvest' then
                -- Harvest volume challenge: track per-crop or total
                if requirements.crop then
                    if data.crop == requirements.crop then
                        progress.amount = (progress.amount or 0) + (data.amount or 1)
                        updated = true
                    end
                else
                    progress.amount = (progress.amount or 0) + (data.amount or 1)
                    updated = true
                end

            elseif action == 'milk' then
                progress.amount = (progress.amount or 0) + (data.amount or 1)
                updated = true

            elseif action == 'collect_eggs' then
                progress.amount = (progress.amount or 0) + (data.amount or 1)
                updated = true

            elseif action == 'plant' then
                progress.amount = (progress.amount or 0) + (data.count or 1)
                updated = true

            elseif action == 'process' then
                progress.amount = (progress.amount or 0) + (data.count or 1)
                updated = true

            elseif action == 'breed' then
                progress.amount = (progress.amount or 0) + (data.count or 1)
                updated = true

            elseif action == 'care' then
                -- 'care' matches both feed and water for the animal_care challenge
                progress.amount = (progress.amount or 0) + 1
                updated = true
            end

        elseif requirements.action == 'care' and (action == 'feed_animal' or action == 'water_animal') then
            -- Animal care challenge accepts feed and water actions
            progress.amount = (progress.amount or 0) + 1
            updated = true
        end

        if updated then
            -- Check completion
            local isComplete = (progress.amount or 0) >= (requirements.amount or 999999)

            if isComplete then
                -- Mark completed
                MySQL.update.await([[
                    UPDATE farm_challenges SET completed = 1, progress = ? WHERE id = ?
                ]], { json.encode(progress), challenge.id })

                -- Get challenge type for rewards
                local challengeType = GetChallengeTypeById(challenge.challenge_type)
                if challengeType then
                    -- Award XP
                    AwardXP(src, 'complete_challenge', challengeType.xpReward)

                    -- Update leaderboard
                    if _G.UpdateLeaderboardScore then
                        _G.UpdateLeaderboardScore(citizenid, challengeType.leaderboardPoints)
                    end

                    -- Update player stats
                    MySQL.update.await([[
                        UPDATE farm_player_data SET total_challenges_completed = total_challenges_completed + 1 WHERE identifier = ?
                    ]], { citizenid })

                    -- Notify player
                    TriggerClientEvent('ox_lib:notify', src, {
                        type = 'success',
                        title = 'Challenge Completed!',
                        description = challengeType.label .. ' — +' .. challengeType.xpReward .. ' XP',
                    })
                end
            else
                -- Just update progress
                MySQL.update.await([[
                    UPDATE farm_challenges SET progress = ? WHERE id = ?
                ]], { json.encode(progress), challenge.id })
            end
        end
    end
end

-- Export globally so other server files can call it
_G.UpdateChallengeProgress = UpdateChallengeProgress

-- =============================================================================
-- CHALLENGE REFRESH THREAD
-- =============================================================================

CreateThread(function()
    Wait(15000) -- Let resource load

    while true do
        -- Refresh challenges for all tracked players
        local players = MySQL.query.await('SELECT DISTINCT identifier FROM farm_player_data')

        if players then
            for _, p in ipairs(players) do
                RefreshPlayerChallenges(p.identifier)
            end
        end

        Utils.Debug('[Challenges] Daily challenge refresh complete')
        Wait(Config.Challenges.refreshInterval * 1000)
    end
end)

-- =============================================================================
-- CALLBACKS
-- =============================================================================

--- Get player's active challenges
lib.callback.register('free-farmer:server:getChallenges', function(src)
    local citizenid = Utils.GetCitizenId(src)
    if not citizenid then return {} end

    -- Ensure they have challenges
    EnsurePlayerFarmData(src)
    RefreshPlayerChallenges(citizenid)

    local now = os.time()
    local challenges = MySQL.query.await([[
        SELECT * FROM farm_challenges
        WHERE identifier = ? AND expires_at >= ?
        ORDER BY completed ASC, created_at DESC
    ]], { citizenid, now })

    if not challenges then return {} end

    local result = {}
    for _, c in ipairs(challenges) do
        local challengeType = GetChallengeTypeById(c.challenge_type)
        local requirements = json.decode(c.requirements) or {}
        local progress = json.decode(c.progress) or {}

        local currentAmount = progress.amount or 0
        local targetAmount = requirements.amount or 0

        -- Build description from challenge type
        local description = challengeType and challengeType.label or c.challenge_type
        if challengeType then
            if requirements.crop then
                description = challengeType.description:format(targetAmount, requirements.crop)
            else
                description = challengeType.description:format(targetAmount)
            end
        end

        result[#result + 1] = {
            id = c.id,
            type = c.challenge_type,
            label = challengeType and challengeType.label or c.challenge_type,
            description = description,
            difficulty = challengeType and challengeType.difficulty or 'easy',
            xpReward = challengeType and challengeType.xpReward or 0,
            leaderboardPoints = challengeType and challengeType.leaderboardPoints or 0,
            current = currentAmount,
            target = targetAmount,
            completed = c.completed == 1,
            expiresAt = c.expires_at,
            timeRemaining = c.expires_at - now,
        }
    end

    return result
end)
