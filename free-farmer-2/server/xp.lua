--[[
    free-farmer — Server XP & Progression System
    Awards XP, handles level-ups, checks crop/animal unlocks.
]]

local Utils = _G.FarmUtils

-- =============================================================================
-- CORE XP FUNCTIONS
-- =============================================================================

---@param src number Player server ID
---@param action string Action key from Config.XP.actions
---@param customAmount number|nil Override amount
function AwardXP(src, action, customAmount)
    local citizenid = Utils.GetCitizenId(src)
    if not citizenid then return end

    local amount = customAmount or Config.XP.actions[action] or 0
    if amount == 0 then return end

    -- Ensure player data exists
    EnsurePlayerFarmData(src)

    local playerData = MySQL.single.await(
        'SELECT * FROM farm_player_data WHERE identifier = ?', { citizenid }
    )
    if not playerData then return end

    local newXP = playerData.xp + amount
    local currentLevel = playerData.level
    local newLevel = currentLevel

    -- Check for level-ups
    while newLevel < Config.XP.maxLevel do
        local xpRequired = Config.XP.xpPerLevel(newLevel)
        if newXP >= xpRequired then
            newXP = newXP - xpRequired
            newLevel = newLevel + 1
        else
            break
        end
    end

    -- Update DB
    MySQL.update.await(
        'UPDATE farm_player_data SET xp = ?, level = ?, updated_at = ? WHERE identifier = ?',
        { newXP, newLevel, os.time(), citizenid }
    )

    -- Notify client of XP gain
    TriggerClientEvent('free-farmer:client:xpGained', src, amount)

    -- Notify on level-up
    if newLevel > currentLevel then
        local unlocks = {}

        -- Check crop unlocks
        for lvl = currentLevel + 1, newLevel do
            local crops = Config.XP.cropUnlocks[lvl]
            if crops then
                for _, name in ipairs(crops) do
                    unlocks[#unlocks + 1] = Utils.Capitalize(name)
                end
            end
            local animals = Config.XP.animalUnlocks[lvl]
            if animals then
                for _, name in ipairs(animals) do
                    unlocks[#unlocks + 1] = Utils.Capitalize(name)
                end
            end
        end

        TriggerClientEvent('free-farmer:client:levelUp', src, newLevel, unlocks)
        Utils.Debug('Player %d leveled up to %d', src, newLevel)
    end
end

---@param src number
---@return number level
function GetPlayerFarmingLevel(src)
    local citizenid = Utils.GetCitizenId(src)
    if not citizenid then return 1 end

    local data = MySQL.single.await(
        'SELECT level FROM farm_player_data WHERE identifier = ?', { citizenid }
    )
    return data and data.level or 1
end

---@param src number
---@return number multiplier (1.0 to 1.5)
function GetPlayerYieldModifier(src)
    local level = GetPlayerFarmingLevel(src)
    return Config.XP.yieldMultiplier(level)
end

-- Alias used by planters.lua
function GetPlayerFarmingXPModifier(src)
    return GetPlayerYieldModifier(src)
end

---@param src number
---@param cropType string
---@return boolean
function IsUnlockedCrop(src, cropType)
    local playerLevel = GetPlayerFarmingLevel(src)
    local cropConfig = Config.Crops[cropType]
    if not cropConfig then return false end
    return playerLevel >= cropConfig.unlockLevel
end

---@param src number
---@param animalType string
---@return boolean
function IsUnlockedAnimal(src, animalType)
    local playerLevel = GetPlayerFarmingLevel(src)
    local animalConfig = Config.Animals[animalType]
    if not animalConfig then return false end
    return playerLevel >= animalConfig.unlockLevel
end

--- Capitalize helper (local copy for use in this file)
function Utils.Capitalize(str)
    if not str or #str == 0 then return '' end
    return str:sub(1, 1):upper() .. str:sub(2)
end

-- =============================================================================
-- CALLBACKS
-- =============================================================================

lib.callback.register('free-farmer:server:getPlayerFarmStats', function(src)
    local citizenid = Utils.GetCitizenId(src)
    if not citizenid then return nil end

    EnsurePlayerFarmData(src)

    return MySQL.single.await(
        'SELECT * FROM farm_player_data WHERE identifier = ?', { citizenid }
    )
end)

-- =============================================================================
-- EXPORTS
-- =============================================================================

_G.AwardXP = AwardXP
_G.FarmAwardXP = AwardXP
_G.GetPlayerFarmingLevel = GetPlayerFarmingLevel
_G.GetPlayerYieldModifier = GetPlayerYieldModifier
_G.GetPlayerFarmingXPModifier = GetPlayerFarmingXPModifier
_G.IsUnlockedCrop = IsUnlockedCrop
_G.IsUnlockedAnimal = IsUnlockedAnimal
