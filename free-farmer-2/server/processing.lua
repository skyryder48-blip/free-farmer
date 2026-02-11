--[[
    free-farmer — Server Processing System
    Processing station interactions, recipe validation, inventory management.
    6 stations: Grain Mill, Cheese Press, Butter Churn, Cider Press, Drying Rack, Wool Processor.
]]

local Utils = _G.FarmUtils

-- =============================================================================
-- HELPER: Find station config by ID
-- =============================================================================

---@param stationId string
---@return table|nil station
local function GetProcessingStation(stationId)
    for _, station in ipairs(Config.ProcessingStations) do
        if station.id == stationId then
            return station
        end
    end
    return nil
end

---@param stationId string
---@param recipeId string
---@return table|nil recipe
local function GetRecipe(stationId, recipeId)
    local station = GetProcessingStation(stationId)
    if not station then return nil end

    for _, recipe in ipairs(station.recipes) do
        if recipe.id == recipeId then
            return recipe
        end
    end
    return nil
end

-- =============================================================================
-- CALLBACKS
-- =============================================================================

--- Get recipes available at a station (filtered by player level)
lib.callback.register('free-farmer:server:getStationRecipes', function(src, stationId)
    local station = GetProcessingStation(stationId)
    if not station then return nil end

    local playerLevel = GetPlayerFarmingLevel(src)

    if playerLevel < station.requiredLevel then
        return { locked = true, requiredLevel = station.requiredLevel }
    end

    local recipes = {}
    for _, recipe in ipairs(station.recipes) do
        local inputCount = exports.ox_inventory:Search(src, 'count', recipe.input) or 0

        recipes[#recipes + 1] = {
            id = recipe.id,
            label = recipe.label,
            input = recipe.input,
            inputAmount = recipe.inputAmount,
            output = recipe.output,
            outputAmount = recipe.outputAmount,
            processingTime = recipe.processingTime,
            hasEnough = inputCount >= recipe.inputAmount,
            currentCount = inputCount,
        }
    end

    return {
        locked = false,
        stationLabel = station.label,
        recipes = recipes,
    }
end)

--- Process an item at a station
lib.callback.register('free-farmer:server:processItem', function(src, stationId, recipeId)
    local station = GetProcessingStation(stationId)
    if not station then
        return { success = false, message = 'Station not found.' }
    end

    -- Level check
    local playerLevel = GetPlayerFarmingLevel(src)
    if playerLevel < station.requiredLevel then
        return { success = false, message = ('Requires Farming Level %d.'):format(station.requiredLevel) }
    end

    local recipe = GetRecipe(stationId, recipeId)
    if not recipe then
        return { success = false, message = 'Recipe not found.' }
    end

    -- Verify input inventory
    local inputCount = exports.ox_inventory:Search(src, 'count', recipe.input) or 0
    if inputCount < recipe.inputAmount then
        return { success = false, message = ('Need %dx %s (have %d).'):format(recipe.inputAmount, recipe.input, inputCount) }
    end

    -- Remove inputs
    local removed = exports.ox_inventory:RemoveItem(src, recipe.input, recipe.inputAmount)
    if not removed then
        return { success = false, message = 'Could not remove input items.' }
    end

    -- Add outputs
    local added = exports.ox_inventory:AddItem(src, recipe.output, recipe.outputAmount)
    if not added then
        -- Refund inputs if output fails
        exports.ox_inventory:AddItem(src, recipe.input, recipe.inputAmount)
        return { success = false, message = 'Inventory full — cannot add processed items.' }
    end

    -- Award XP
    local xpAmount = recipe.xpReward or Config.XP.actions.process_item or 10
    AwardXP(src, 'process_item', xpAmount)

    -- Update player stats
    EnsurePlayerFarmData(src)

    -- Challenge progress
    if _G.UpdateChallengeProgress then
        _G.UpdateChallengeProgress(src, 'process', { count = 1 })
    end

    -- Leaderboard stat
    if _G.UpdateLeaderboardScore then
        local citizenid = Utils.GetCitizenId(src)
        if citizenid then
            _G.UpdateLeaderboardScore(citizenid, 2) -- 2 points per processing action
        end
    end

    Utils.Debug('[Processing] Player %d processed %dx %s -> %dx %s at %s',
        src, recipe.inputAmount, recipe.input, recipe.outputAmount, recipe.output, stationId)

    return {
        success = true,
        outputItem = recipe.output,
        outputAmount = recipe.outputAmount,
        stationLabel = station.label,
        recipeLabel = recipe.label,
    }
end)

--- Progress bar confirmation callback (client triggers when progress bar completes)
lib.callback.register('free-farmer:server:confirmProcessing', function(src)
    return true
end)
