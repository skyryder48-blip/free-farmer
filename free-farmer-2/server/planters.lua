--[[
    free-farmer — Server Planter System
    Portable garden planters that players place anywhere in the world.
    Server-spawned props with OneSync orphan mode for persistence.
    Single growth tick thread processes all active planters.
]]

local Utils = _G.FarmServerUtils
local AwardXP = _G.FarmAwardXP
local GetPlayerFarmingLevel = _G.GetPlayerFarmingLevel
local GetPlayerFarmingXPModifier = _G.GetPlayerFarmingXPModifier

local spawnedPlanters = {} -- {[planter_uuid] = entityId}

-- =============================================================================
-- PLANTER ENTITY MANAGEMENT
-- =============================================================================

--- Get the prop for a planter (always base prop — crop growth is tracked via state bags)
---@return string propModel
local function GetPlanterProp()
    return Config.Planter.prop
end

--- Spawn a planter entity in the world (server-side OneSync)
---@param planterData table DB row from farm_planters
---@return number|nil entityId
function SpawnPlanterEntity(planterData)
    if spawnedPlanters[planterData.planter_uuid] then
        return spawnedPlanters[planterData.planter_uuid]
    end

    local propModel = GetPlanterProp()
    local propHash = joaat(propModel)

    local entity = CreateObjectNoOffset(
        propHash,
        planterData.coords_x,
        planterData.coords_y,
        planterData.coords_z,
        true, true, false
    )

    if not entity or entity == 0 then
        Utils.Debug('^1[Planters] Failed to spawn planter %s^7', planterData.planter_uuid)
        return nil
    end

    SetEntityOrphanMode(entity, 2) -- Persist even without nearby players
    SetEntityHeading(entity, planterData.heading or 0.0)

    -- State bags for client interaction
    local entState = Entity(entity).state
    entState:set('planterUuid', planterData.planter_uuid, true)
    entState:set('planterOwner', planterData.owner_identifier, true)
    entState:set('planterCrop', planterData.crop_type or '', true)
    entState:set('planterStage', planterData.growth_stage or 0, true)
    entState:set('planterStatus', GetPlanterStatus(planterData), true)
    entState:set('isFarmPlanter', true, true)

    spawnedPlanters[planterData.planter_uuid] = entity

    Utils.Debug('[Planters] Spawned planter %s (entity %d, prop %s)',
        planterData.planter_uuid, entity, propModel)

    return entity
end

--- Despawn a planter entity
---@param uuid string
function DespawnPlanterEntity(uuid)
    local entity = spawnedPlanters[uuid]
    if entity and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
    spawnedPlanters[uuid] = nil
end

--- Update state bags on a spawned planter entity (no despawn/respawn needed)
---@param uuid string
local function UpdatePlanterStateBags(uuid)
    local entity = spawnedPlanters[uuid]
    if not entity or not DoesEntityExist(entity) then return end

    local planterData = MySQL.single.await(
        'SELECT * FROM farm_planters WHERE planter_uuid = ?', { uuid }
    )
    if not planterData then return end

    local entState = Entity(entity).state
    entState:set('planterCrop', planterData.crop_type or '', true)
    entState:set('planterStage', planterData.growth_stage or 0, true)
    entState:set('planterStatus', GetPlanterStatus(planterData), true)
end

--- Determine planter status string
---@param planterData table
---@return string status 'empty' | 'planted' | 'harvestable'
function GetPlanterStatus(planterData)
    if not planterData.crop_type or planterData.growth_stage == 0 then
        return 'empty'
    end

    local cropConfig = Config.Crops[planterData.crop_type]
    if not cropConfig then return 'empty' end

    local totalStages = #cropConfig.growthStages
    if planterData.growth_stage >= totalStages then
        return 'harvestable'
    end

    return 'planted'
end

-- =============================================================================
-- SPAWN ALL PLANTERS ON RESOURCE START
-- =============================================================================

CreateThread(function()
    Wait(2000) -- Let DB initialize

    local planters = MySQL.query.await('SELECT * FROM farm_planters')
    if not planters then return end

    local count = 0
    for _, planter in ipairs(planters) do
        SpawnPlanterEntity(planter)
        count = count + 1
    end

    if count > 0 then
        Utils.Debug('[Planters] Spawned %d planters on startup', count)
    end
end)

-- =============================================================================
-- GROWTH TICK
-- =============================================================================

CreateThread(function()
    while true do
        Wait(Config.PlanterGrowthTickInterval * 1000)

        local planters = MySQL.query.await([[
            SELECT * FROM farm_planters
            WHERE crop_type IS NOT NULL AND growth_stage > 0
        ]])

        if not planters or #planters == 0 then goto tick_end end

        local now = os.time()
        local multiplier = Config.Planter.growthTimeMultiplier or 1.2

        for _, planter in ipairs(planters) do
            local cropConfig = Config.Crops[planter.crop_type]
            if not cropConfig then goto next_planter end

            local stageConfig = cropConfig.growthStages[planter.growth_stage]
            if not stageConfig or not stageConfig.duration then goto next_planter end

            -- Apply growth time multiplier (planters grow slower)
            local adjustedDuration = math.floor(stageConfig.duration * multiplier)
            local elapsed = now - (planter.stage_updated_at or now)

            if elapsed >= adjustedDuration then
                local nextStageNum = planter.growth_stage + 1
                local nextStage = cropConfig.growthStages[nextStageNum]

                if nextStage then
                    MySQL.update.await([[
                        UPDATE farm_planters
                        SET growth_stage = ?, stage_updated_at = ?, updated_at = ?
                        WHERE planter_uuid = ?
                    ]], { nextStageNum, now, now, planter.planter_uuid })

                    -- Refresh entity prop to match new stage
                    UpdatePlanterStateBags(planter.planter_uuid)

                    Utils.Debug('[Planters] %s advanced to stage %d (%s)',
                        planter.planter_uuid, nextStageNum, nextStage.label)
                end
            end

            ::next_planter::
        end

        ::tick_end::
    end
end)

-- =============================================================================
-- CALLBACKS
-- =============================================================================

--- Place a new planter in the world
lib.callback.register('free-farmer:server:placePlanter', function(src, coords, heading)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return { success = false, message = 'Player not found.' } end

    local citizenid = player.PlayerData.citizenid

    -- Check player has garden_planter item
    local hasItem = exports.ox_inventory:Search(src, 'count', Config.Planter.item)
    if not hasItem or hasItem < 1 then
        return { success = false, message = 'You need a Garden Planter item.' }
    end

    -- Check max planter count
    local count = MySQL.scalar.await(
        'SELECT COUNT(*) FROM farm_planters WHERE owner_identifier = ?', { citizenid }
    )
    if count >= Config.Planter.maxPerPlayer then
        return {
            success = false,
            message = ('Maximum %d planters allowed.'):format(Config.Planter.maxPerPlayer),
        }
    end

    -- Remove item
    local removed = exports.ox_inventory:RemoveItem(src, Config.Planter.item, 1)
    if not removed then
        return { success = false, message = 'Could not remove planter from inventory.' }
    end

    -- Create DB record
    local uuid = Utils.GenerateUUID()
    local now = os.time()

    MySQL.insert.await([[
        INSERT INTO farm_planters
            (planter_uuid, owner_identifier, coords_x, coords_y, coords_z, heading, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], { uuid, citizenid, coords.x, coords.y, coords.z, heading, now, now })

    -- Spawn entity
    local planterData = MySQL.single.await(
        'SELECT * FROM farm_planters WHERE planter_uuid = ?', { uuid }
    )

    if planterData then
        SpawnPlanterEntity(planterData)
    end

    Utils.Debug('[Planters] Player %d placed planter %s at %.1f, %.1f, %.1f',
        src, uuid, coords.x, coords.y, coords.z)

    return { success = true, uuid = uuid }
end)

--- Get plantable crops for a planter (filtered by level + planterAllowed)
lib.callback.register('free-farmer:server:getPlanterPlantableCrops', function(src, planterUuid)
    local planter = MySQL.single.await(
        'SELECT * FROM farm_planters WHERE planter_uuid = ?', { planterUuid }
    )
    if not planter then return {} end
    if planter.crop_type then return {} end -- Already has a crop

    local playerLevel = GetPlayerFarmingLevel(src)
    local available = {}

    for cropType, cropConfig in pairs(Config.Crops) do
        if cropConfig.planterAllowed and playerLevel >= cropConfig.unlockLevel then
            local seedCount = exports.ox_inventory:Search(src, 'count', cropConfig.seedItem)
            available[#available + 1] = {
                type = cropType,
                label = cropConfig.label,
                seedItem = cropConfig.seedItem,
                seedCount = seedCount or 0,
                unlockLevel = cropConfig.unlockLevel,
            }
        end
    end

    return available
end)

--- Plant seeds in a planter
lib.callback.register('free-farmer:server:plantInPlanter', function(src, planterUuid, cropType)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return { success = false, message = 'Player not found.' } end

    local citizenid = player.PlayerData.citizenid

    local planter = MySQL.single.await(
        'SELECT * FROM farm_planters WHERE planter_uuid = ?', { planterUuid }
    )
    if not planter then
        return { success = false, message = 'Planter not found.' }
    end

    -- Verify ownership
    if planter.owner_identifier ~= citizenid then
        return { success = false, message = 'This is not your planter.' }
    end

    -- Verify empty
    if planter.crop_type then
        return { success = false, message = 'This planter already has a crop.' }
    end

    -- Validate crop
    local cropConfig = Config.Crops[cropType]
    if not cropConfig then
        return { success = false, message = 'Invalid crop type.' }
    end

    if not cropConfig.planterAllowed then
        return { success = false, message = cropConfig.label .. ' cannot grow in a planter.' }
    end

    -- Level check
    local playerLevel = GetPlayerFarmingLevel(src)
    if playerLevel < cropConfig.unlockLevel then
        return { success = false, message = ('Requires Farming Level %d.'):format(cropConfig.unlockLevel) }
    end

    -- Check seeds
    local seedCount = exports.ox_inventory:Search(src, 'count', cropConfig.seedItem)
    if not seedCount or seedCount < 1 then
        return { success = false, message = 'You need ' .. cropConfig.seedItem .. ' to plant.' }
    end

    -- Remove seed
    local removed = exports.ox_inventory:RemoveItem(src, cropConfig.seedItem, 1)
    if not removed then
        return { success = false, message = 'Could not remove seeds from inventory.' }
    end

    -- Update planter
    local now = os.time()
    MySQL.update.await([[
        UPDATE farm_planters
        SET crop_type = ?, growth_stage = 1, planted_at = ?, stage_updated_at = ?, updated_at = ?
        WHERE planter_uuid = ?
    ]], { cropType, now, now, now, planterUuid })

    -- Refresh entity
    UpdatePlanterStateBags(planterUuid)

    AwardXP(src, 'plant_planter')

    -- Update stats
    MySQL.update.await([[
        UPDATE farm_player_data
        SET total_crops_planted = total_crops_planted + 1
        WHERE identifier = ?
    ]], { citizenid })

    Utils.Debug('[Planters] Player %d planted %s in planter %s', src, cropType, planterUuid)

    return { success = true, cropLabel = cropConfig.label }
end)

--- Harvest a planter
lib.callback.register('free-farmer:server:harvestPlanter', function(src, planterUuid)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return { success = false, message = 'Player not found.' } end

    local citizenid = player.PlayerData.citizenid

    local planter = MySQL.single.await(
        'SELECT * FROM farm_planters WHERE planter_uuid = ?', { planterUuid }
    )
    if not planter then
        return { success = false, message = 'Planter not found.' }
    end

    if planter.owner_identifier ~= citizenid then
        return { success = false, message = 'This is not your planter.' }
    end

    local cropConfig = Config.Crops[planter.crop_type]
    if not cropConfig then
        return { success = false, message = 'Unknown crop in planter.' }
    end

    local totalStages = #cropConfig.growthStages
    if planter.growth_stage < totalStages then
        return { success = false, message = 'Crop is not ready for harvest.' }
    end

    -- Calculate yield (planter-specific, smaller scale)
    local planterYield = cropConfig.planterYield or { min = 1, max = 3 }
    local baseYield = math.random(planterYield.min, planterYield.max)

    -- XP modifier (only modifier for planters — no weather/field-size scaling)
    local xpMod = GetPlayerFarmingXPModifier(src)
    local finalYield = math.max(1, math.floor(baseYield * xpMod))

    -- Quality based on XP level only (simpler for planters)
    local level = GetPlayerFarmingLevel(src)
    local qualityScore = level / 100.0
    local quality = 'poor'
    if qualityScore >= cropConfig.qualityThresholds.excellent then
        quality = 'excellent'
    elseif qualityScore >= cropConfig.qualityThresholds.good then
        quality = 'good'
    elseif qualityScore >= cropConfig.qualityThresholds.average then
        quality = 'average'
    end

    -- Add items
    local added = exports.ox_inventory:AddItem(src, cropConfig.harvestItem, finalYield, {
        quality = quality,
    })

    if not added then
        return { success = false, message = 'Inventory full — cannot harvest.' }
    end

    -- Reset planter to empty
    local now = os.time()
    MySQL.update.await([[
        UPDATE farm_planters
        SET crop_type = NULL, growth_stage = 0, planted_at = NULL, stage_updated_at = NULL, updated_at = ?
        WHERE planter_uuid = ?
    ]], { now, planterUuid })

    -- Refresh entity back to empty planter prop
    UpdatePlanterStateBags(planterUuid)

    AwardXP(src, 'harvest_planter')

    -- Update stats
    MySQL.update.await([[
        UPDATE farm_player_data
        SET total_crops_harvested = total_crops_harvested + 1
        WHERE identifier = ?
    ]], { citizenid })

    Utils.Debug('[Planters] Player %d harvested %s from planter %s (yield: %d, quality: %s)',
        src, planter.crop_type, planterUuid, finalYield, quality)

    return {
        success = true,
        yield = finalYield,
        quality = quality,
        cropLabel = cropConfig.label,
        itemName = cropConfig.harvestItem,
    }
end)

--- Check planter status
lib.callback.register('free-farmer:server:checkPlanter', function(src, planterUuid)
    local planter = MySQL.single.await(
        'SELECT * FROM farm_planters WHERE planter_uuid = ?', { planterUuid }
    )
    if not planter then return nil end

    local info = {
        uuid = planterUuid,
        status = GetPlanterStatus(planter),
        cropType = planter.crop_type,
    }

    if planter.crop_type then
        local cropConfig = Config.Crops[planter.crop_type]
        if cropConfig then
            info.cropLabel = cropConfig.label
            info.growthStage = planter.growth_stage
            info.totalStages = #cropConfig.growthStages
            info.stageLabel = cropConfig.growthStages[planter.growth_stage]
                and cropConfig.growthStages[planter.growth_stage].label
                or 'Unknown'

            -- Time remaining
            if planter.stage_updated_at and planter.growth_stage < #cropConfig.growthStages then
                local stageConfig = cropConfig.growthStages[planter.growth_stage]
                if stageConfig and stageConfig.duration then
                    local adjustedDuration = math.floor(
                        stageConfig.duration * (Config.Planter.growthTimeMultiplier or 1.2)
                    )
                    local elapsed = os.time() - planter.stage_updated_at
                    local remaining = math.max(0, adjustedDuration - elapsed)
                    info.timeRemaining = remaining
                end
            end
        end
    end

    return info
end)

--- Pick up a planter (return item, destroy planter)
lib.callback.register('free-farmer:server:pickupPlanter', function(src, planterUuid)
    if not Config.Planter.pickupEnabled then
        return { success = false, message = 'Planters cannot be picked up.' }
    end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return { success = false, message = 'Player not found.' } end

    local citizenid = player.PlayerData.citizenid

    local planter = MySQL.single.await(
        'SELECT * FROM farm_planters WHERE planter_uuid = ?', { planterUuid }
    )
    if not planter then
        return { success = false, message = 'Planter not found.' }
    end

    if planter.owner_identifier ~= citizenid then
        return { success = false, message = 'This is not your planter.' }
    end

    -- Return garden_planter item
    local added = exports.ox_inventory:AddItem(src, Config.Planter.item, 1)
    if not added then
        return { success = false, message = 'Inventory full — cannot pick up.' }
    end

    -- Despawn and delete
    DespawnPlanterEntity(planterUuid)

    MySQL.update.await(
        'DELETE FROM farm_planters WHERE planter_uuid = ?', { planterUuid }
    )

    Utils.Debug('[Planters] Player %d picked up planter %s', src, planterUuid)

    return { success = true }
end)

--- Get player's planter count
lib.callback.register('free-farmer:server:getPlanterCount', function(src)
    local citizenid = Utils.GetCitizenId(src)
    if not citizenid then return 0 end

    local count = MySQL.scalar.await(
        'SELECT COUNT(*) FROM farm_planters WHERE owner_identifier = ?', { citizenid }
    )
    return count or 0
end)
