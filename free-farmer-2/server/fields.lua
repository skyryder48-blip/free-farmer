--[[
    free-farmer — Server Field System
    Field state management, crop growth ticks, prop spawning/despawning, harvest calculations.
    All entity creation uses OneSync server-side spawning with SetEntityOrphanMode.
]]

local Utils = _G.FarmUtils

-- Active tracking
local activeFieldProps = {}    -- [fieldId] = { entityIds }
local activeFarmZones = {}     -- [farmZoneId] = playerCount
local fieldStateCache = {}     -- [fieldId] = { status, crop_type, growth_stage }

-- =============================================================================
-- FIELD STATE
-- =============================================================================

---@param fieldId string
---@return table|nil
local function GetFieldState(fieldId)
    return MySQL.single.await('SELECT * FROM farm_fields WHERE field_id = ?', { fieldId })
end

---@param fieldId string
---@param data table Key-value pairs to update
local function UpdateFieldState(fieldId, data)
    local sets = {}
    local params = {}

    for key, value in pairs(data) do
        sets[#sets + 1] = ('%s = ?'):format(key)
        params[#params + 1] = value
    end

    sets[#sets + 1] = 'updated_at = UNIX_TIMESTAMP()'
    params[#params + 1] = fieldId

    MySQL.update.await(
        ('UPDATE farm_fields SET %s WHERE field_id = ?'):format(table.concat(sets, ', ')),
        params
    )

    -- Update cache
    if fieldStateCache[fieldId] then
        for key, value in pairs(data) do
            fieldStateCache[fieldId][key] = value
        end
    end
end

--- Cache all field states on startup and zone enter
local function CacheFieldStates(farmZoneId)
    local fields = MySQL.query.await(
        'SELECT * FROM farm_fields WHERE farm_zone = ?',
        { farmZoneId }
    )

    for _, field in ipairs(fields or {}) do
        fieldStateCache[field.field_id] = field
    end
end

-- =============================================================================
-- PROP SPAWNING (Server-Side OneSync)
-- =============================================================================

---@param fieldId string
local function SpawnFieldProps(fieldId)
    if activeFieldProps[fieldId] then return end

    local state = fieldStateCache[fieldId] or GetFieldState(fieldId)
    if not state then return end

    -- Only spawn if there's a crop growing
    if state.status ~= 'planted' and state.status ~= 'harvestable' then
        return
    end

    local cropConfig = Config.Crops[state.crop_type]
    if not cropConfig then return end

    local stageConfig = cropConfig.growthStages[state.growth_stage]
    if not stageConfig then return end

    local fieldConfig = Utils.GetFieldConfig(fieldId)
    if not fieldConfig then return end

    local propModel = GetHashKey(stageConfig.prop)
    local entities = {}

    for _, spawnPoint in ipairs(fieldConfig.propSpawnPoints) do
        local entity = CreateObjectNoOffset(
            propModel,
            spawnPoint.x, spawnPoint.y, spawnPoint.z,
            true, true, false
        )

        if entity and entity ~= 0 then
            SetEntityOrphanMode(entity, 2)
            SetEntityHeading(entity, spawnPoint.w or 0.0)

            -- State bags for client-side visual config
            local stateBag = Entity(entity).state
            stateBag:set('freefarmer_prop', true, true)
            stateBag:set('fieldId', fieldId, true)
            stateBag:set('cropType', state.crop_type, true)
            stateBag:set('growthStage', state.growth_stage, true)

            entities[#entities + 1] = entity
        end
    end

    if #entities > 0 then
        activeFieldProps[fieldId] = entities
        Utils.Debug('Spawned %d props for field %s (stage %d)', #entities, fieldId, state.growth_stage)
    end
end

---@param fieldId string
local function DespawnFieldProps(fieldId)
    local entities = activeFieldProps[fieldId]
    if not entities then return end

    for _, entity in ipairs(entities) do
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end

    activeFieldProps[fieldId] = nil
    Utils.Debug('Despawned props for field %s', fieldId)
end

--- Refresh props for a field (despawn old, spawn new)
---@param fieldId string
local function RefreshFieldProps(fieldId)
    DespawnFieldProps(fieldId)
    SpawnFieldProps(fieldId)
end

-- =============================================================================
-- FARM ZONE ENTER / EXIT
-- =============================================================================

RegisterNetEvent('free-farmer:server:playerEnteredZone', function(farmZoneId)
    local src = source
    activeFarmZones[farmZoneId] = (activeFarmZones[farmZoneId] or 0) + 1

    Utils.Debug('Player %d entered %s (count: %d)', src, farmZoneId, activeFarmZones[farmZoneId])

    -- First player: cache states and spawn all field props
    if activeFarmZones[farmZoneId] == 1 then
        CacheFieldStates(farmZoneId)

        local zone = Utils.GetFarmZoneById(farmZoneId)
        if zone then
            for _, field in ipairs(zone.fields) do
                SpawnFieldProps(field.id)
            end
        end
    end
end)

RegisterNetEvent('free-farmer:server:playerLeftZone', function(farmZoneId)
    local src = source
    activeFarmZones[farmZoneId] = math.max(0, (activeFarmZones[farmZoneId] or 0) - 1)

    Utils.Debug('Player %d left %s (count: %d)', src, farmZoneId, activeFarmZones[farmZoneId])

    -- Last player out: despawn everything
    if activeFarmZones[farmZoneId] == 0 then
        local zone = Utils.GetFarmZoneById(farmZoneId)
        if zone then
            for _, field in ipairs(zone.fields) do
                DespawnFieldProps(field.id)
            end
        end
    end
end)

-- =============================================================================
-- GROWTH TICK
-- =============================================================================

CreateThread(function()
    -- Wait for resource to fully load
    Wait(5000)

    while true do
        Wait(Config.GrowthTickInterval * 1000)

        local fields = MySQL.query.await([[
            SELECT * FROM farm_fields
            WHERE status = 'planted'
            AND crop_type IS NOT NULL
            AND growth_stage > 0
        ]])

        if not fields then goto continue end

        local currentWeather = GetCurrentWeather()
        local now = os.time()

        for _, field in ipairs(fields) do
            local cropConfig = Config.Crops[field.crop_type]
            if not cropConfig then goto nextField end

            local stageConfig = cropConfig.growthStages[field.growth_stage]
            if not stageConfig or not stageConfig.duration then goto nextField end

            -- Track weather quality
            local weatherMod = cropConfig.weatherPreferences[currentWeather] or 1.0
            local goodTick = weatherMod >= 1.0 and 1 or 0
            local badTick = weatherMod < 0.9 and 1 or 0

            -- Check if stage duration elapsed
            local elapsed = now - (field.stage_updated_at or field.planted_at or now)

            if elapsed >= stageConfig.duration then
                local nextStageNum = field.growth_stage + 1
                local nextStage = cropConfig.growthStages[nextStageNum]

                if nextStage then
                    local newStatus = nextStage.duration == nil and 'harvestable' or 'planted'

                    UpdateFieldState(field.field_id, {
                        growth_stage = nextStageNum,
                        stage_updated_at = now,
                        status = newStatus,
                        weather_quality_modifier = weatherMod,
                        good_weather_ticks = field.good_weather_ticks + goodTick,
                        bad_weather_ticks = field.bad_weather_ticks + badTick,
                    })

                    -- Refresh props if zone is active
                    if activeFarmZones[field.farm_zone] and activeFarmZones[field.farm_zone] > 0 then
                        RefreshFieldProps(field.field_id)
                    end

                    Utils.Debug('Field %s advanced to stage %d (%s)',
                        field.field_id, nextStageNum, nextStage.label)
                end
            else
                -- Just update weather tracking
                MySQL.update.await([[
                    UPDATE farm_fields SET
                        weather_quality_modifier = ?,
                        good_weather_ticks = good_weather_ticks + ?,
                        bad_weather_ticks = bad_weather_ticks + ?
                    WHERE field_id = ?
                ]], { weatherMod, goodTick, badTick, field.field_id })
            end

            ::nextField::
        end

        ::continue::
    end
end)

-- =============================================================================
-- HARVEST YIELD CALCULATION
-- =============================================================================

---@param fieldId string
---@param src number Player source
---@return table { success, yield, quality, weatherBonus, xpBonus }
local function CalculateHarvestYield(fieldId, src)
    local field = GetFieldState(fieldId)
    if not field or not field.crop_type then
        return { success = false, yield = 0, quality = 'poor' }
    end

    local fieldConfig = Utils.GetFieldConfig(fieldId)
    local cropConfig = Config.Crops[field.crop_type]
    if not fieldConfig or not cropConfig then
        return { success = false, yield = 0, quality = 'poor' }
    end

    -- Base yield
    local baseYield = math.random(cropConfig.baseYield.min, cropConfig.baseYield.max)

    -- Scale by field size (per 100 sq meters)
    local sizeMultiplier = fieldConfig.size / 100.0
    local totalYield = baseYield * sizeMultiplier

    -- Weather bonus from accumulated ticks
    local weatherBonus = 1.0
    local totalTicks = field.good_weather_ticks + field.bad_weather_ticks
    if totalTicks > 0 then
        local goodRatio = field.good_weather_ticks / totalTicks
        if goodRatio >= 0.75 then
            weatherBonus = 1.15
        elseif goodRatio >= 0.6 then
            weatherBonus = 1.08
        elseif goodRatio >= 0.4 then
            weatherBonus = 1.0
        elseif goodRatio >= 0.25 then
            weatherBonus = 0.92
        else
            weatherBonus = 0.85
        end
    end

    -- Player XP modifier
    local xpBonus = GetPlayerYieldModifier(src)

    -- Final yield
    local finalYield = math.floor(totalYield * weatherBonus * xpBonus)
    finalYield = math.max(1, finalYield)

    -- Determine quality based on combined conditions
    local conditionScore = (weatherBonus + xpBonus) / 2.0
    local quality = 'poor'

    if conditionScore >= cropConfig.qualityThresholds.excellent then
        quality = 'excellent'
    elseif conditionScore >= cropConfig.qualityThresholds.good then
        quality = 'good'
    elseif conditionScore >= cropConfig.qualityThresholds.average then
        quality = 'average'
    end

    return {
        success = true,
        yield = finalYield,
        quality = quality,
        weatherBonus = weatherBonus,
        xpBonus = xpBonus,
    }
end

-- =============================================================================
-- FIELD INTERACTION CALLBACKS
-- =============================================================================

--- Plow a field
lib.callback.register('free-farmer:server:plowField', function(src, fieldId)
    local field = GetFieldState(fieldId)
    if not field then
        return { success = false, message = 'Field not found.' }
    end

    if field.status ~= 'raw' then
        return { success = false, message = 'This field is already plowed or has crops.' }
    end

    -- Ensure player farm data exists
    EnsurePlayerFarmData(src)

    UpdateFieldState(fieldId, {
        status = 'plowed',
        crop_type = nil,
        growth_stage = 0,
        planted_at = nil,
        stage_updated_at = nil,
        good_weather_ticks = 0,
        bad_weather_ticks = 0,
        weather_quality_modifier = 1.0,
    })

    AwardXP(src, 'plow_field')

    Utils.Debug('Player %d plowed field %s', src, fieldId)

    return { success = true }
end)

--- Get available crops for planting (filtered by level and field type)
lib.callback.register('free-farmer:server:getPlantableCrops', function(src, fieldId)
    local fieldConfig = Utils.GetFieldConfig(fieldId)
    if not fieldConfig then return {} end

    local field = GetFieldState(fieldId)
    if not field or field.status ~= 'plowed' then return {} end

    local playerLevel = GetPlayerFarmingLevel(src)
    local available = {}

    for cropType, cropConfig in pairs(Config.Crops) do
        -- Check field type compatibility
        local fieldTypeOk = false
        for _, ft in ipairs(cropConfig.fieldTypes) do
            if ft == fieldConfig.fieldType then
                fieldTypeOk = true
                break
            end
        end

        -- Check level requirement
        if fieldTypeOk and playerLevel >= cropConfig.unlockLevel then
            -- Check player has seeds
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

--- Plant seeds in a field
lib.callback.register('free-farmer:server:plantField', function(src, fieldId, cropType)
    local field = GetFieldState(fieldId)
    if not field then
        return { success = false, message = 'Field not found.' }
    end

    if field.status ~= 'plowed' then
        return { success = false, message = 'Field must be plowed first.' }
    end

    local cropConfig = Config.Crops[cropType]
    if not cropConfig then
        return { success = false, message = 'Invalid crop type.' }
    end

    -- Verify field type
    local fieldConfig = Utils.GetFieldConfig(fieldId)
    if not fieldConfig then
        return { success = false, message = 'Field configuration error.' }
    end

    local fieldTypeOk = false
    for _, ft in ipairs(cropConfig.fieldTypes) do
        if ft == fieldConfig.fieldType then
            fieldTypeOk = true
            break
        end
    end

    if not fieldTypeOk then
        return { success = false, message = 'This crop cannot grow in this field type.' }
    end

    -- Verify level
    if not IsUnlockedCrop(src, cropType) then
        return { success = false, message = ('Requires Farming Level %d.'):format(cropConfig.unlockLevel) }
    end

    -- Check seeds in inventory
    local seedCount = exports.ox_inventory:Search(src, 'count', cropConfig.seedItem)
    if not seedCount or seedCount < 1 then
        return { success = false, message = ('You need %s to plant.'):format(cropConfig.seedItem) }
    end

    -- Remove seed
    local removed = exports.ox_inventory:RemoveItem(src, cropConfig.seedItem, 1)
    if not removed then
        return { success = false, message = 'Failed to use seeds.' }
    end

    local now = os.time()

    UpdateFieldState(fieldId, {
        status = 'planted',
        crop_type = cropType,
        growth_stage = 1,
        planted_at = now,
        stage_updated_at = now,
        good_weather_ticks = 0,
        bad_weather_ticks = 0,
        weather_quality_modifier = 1.0,
    })

    -- Spawn crop props if zone is active
    if activeFarmZones[field.farm_zone] and activeFarmZones[field.farm_zone] > 0 then
        SpawnFieldProps(fieldId)
    end

    AwardXP(src, 'plant_seeds')

    -- Update stats
    local citizenid = Utils.GetCitizenId(src)
    if citizenid then
        MySQL.update.await([[
            UPDATE farm_player_data
            SET total_crops_planted = total_crops_planted + 1
            WHERE identifier = ?
        ]], { citizenid })
    end

    -- Challenge progress
    if _G.UpdateChallengeProgress then
        _G.UpdateChallengeProgress(src, 'plant', { count = 1 })
    end

    Utils.Debug('Player %d planted %s in field %s', src, cropType, fieldId)

    return { success = true, cropLabel = cropConfig.label }
end)

--- Harvest a field
lib.callback.register('free-farmer:server:harvestField', function(src, fieldId)
    local field = GetFieldState(fieldId)
    if not field then
        return { success = false, message = 'Field not found.' }
    end

    if field.status ~= 'harvestable' then
        return { success = false, message = 'This field is not ready for harvest.' }
    end

    local cropConfig = Config.Crops[field.crop_type]
    if not cropConfig then
        return { success = false, message = 'Unknown crop type.' }
    end

    -- Calculate yield
    local result = CalculateHarvestYield(fieldId, src)
    if not result.success then
        return { success = false, message = 'Harvest calculation failed.' }
    end

    -- Add items to inventory with quality metadata
    local added = exports.ox_inventory:AddItem(src, cropConfig.harvestItem, result.yield, {
        quality = result.quality,
    })

    if not added then
        return { success = false, message = 'Inventory full — cannot harvest.' }
    end

    DespawnFieldProps(fieldId)

    -- Perennial crops regrow; annual crops reset to raw
    if cropConfig.isPerennial and cropConfig.regrowthStage then
        local regrowthStage = cropConfig.regrowthStage
        local stageConfig = cropConfig.growthStages[regrowthStage]

        UpdateFieldState(fieldId, {
            status = 'planted',
            growth_stage = regrowthStage,
            stage_updated_at = os.time(),
            good_weather_ticks = 0,
            bad_weather_ticks = 0,
            weather_quality_modifier = 1.0,
        })

        -- Spawn regrowth props if zone is active
        if activeFarmZones[field.farm_zone] and activeFarmZones[field.farm_zone] > 0 then
            SpawnFieldProps(fieldId)
        end

        Utils.Debug('Perennial %s in %s regrew to stage %d (%s)',
            field.crop_type, fieldId, regrowthStage, stageConfig and stageConfig.label or '?')
    else
        UpdateFieldState(fieldId, {
            status = 'raw',
            crop_type = nil,
            growth_stage = 0,
            planted_at = nil,
            stage_updated_at = nil,
            good_weather_ticks = 0,
            bad_weather_ticks = 0,
            weather_quality_modifier = 1.0,
        })
    end

    AwardXP(src, 'harvest_crop')

    -- Update stats
    local citizenid = Utils.GetCitizenId(src)
    if citizenid then
        MySQL.update.await([[
            UPDATE farm_player_data
            SET total_crops_harvested = total_crops_harvested + 1
            WHERE identifier = ?
        ]], { citizenid })
    end

    -- Challenge progress
    if _G.UpdateChallengeProgress then
        _G.UpdateChallengeProgress(src, 'harvest', { crop = cropConfig.harvestItem, amount = result.yield })
    end

    -- Leaderboard points
    if _G.UpdateLeaderboardScore and citizenid then
        _G.UpdateLeaderboardScore(citizenid, 1)
    end

    Utils.Debug('Player %d harvested %s from %s (yield: %d, quality: %s)',
        src, field.crop_type, fieldId, result.yield, result.quality)

    return {
        success = true,
        yield = result.yield,
        quality = result.quality,
        cropLabel = cropConfig.label,
        itemName = cropConfig.harvestItem,
        harvestMethod = cropConfig.harvestMethod or 'standard',
        isPerennial = cropConfig.isPerennial or false,
        weatherBonus = result.weatherBonus,
        xpBonus = result.xpBonus,
    }
end)

--- Check field status (for player inspection)
lib.callback.register('free-farmer:server:checkField', function(src, fieldId)
    local field = GetFieldState(fieldId)
    if not field then return nil end

    local fieldConfig = Utils.GetFieldConfig(fieldId)
    local info = {
        fieldId = fieldId,
        label = fieldConfig and fieldConfig.label or fieldId,
        fieldType = fieldConfig and fieldConfig.fieldType or 'unknown',
        status = field.status,
        cropType = field.crop_type,
        growthStage = field.growth_stage,
        weather = GetCurrentWeather(),
    }

    -- Add crop details if planted
    if field.crop_type then
        local cropConfig = Config.Crops[field.crop_type]
        if cropConfig then
            info.cropLabel = cropConfig.label
            info.harvestMethod = cropConfig.harvestMethod or 'standard'
            info.isPerennial = cropConfig.isPerennial or false
            local totalStages = #cropConfig.growthStages
            info.totalStages = totalStages
            info.stageLabel = cropConfig.growthStages[field.growth_stage]
                and cropConfig.growthStages[field.growth_stage].label
                or 'Unknown'

            -- Time until next stage
            if field.stage_updated_at and field.growth_stage < totalStages then
                local stageConfig = cropConfig.growthStages[field.growth_stage]
                if stageConfig and stageConfig.duration then
                    local elapsed = os.time() - field.stage_updated_at
                    local remaining = math.max(0, stageConfig.duration - elapsed)
                    info.timeRemaining = remaining
                end
            end
        end
    end

    return info
end)

--- Get the harvest method for a field's current crop (client needs this before harvest anim)
lib.callback.register('free-farmer:server:getFieldHarvestMethod', function(src, fieldId)
    local field = GetFieldState(fieldId)
    if not field or not field.crop_type then return 'standard' end

    local cropConfig = Config.Crops[field.crop_type]
    if not cropConfig then return 'standard' end

    return cropConfig.harvestMethod or 'standard'
end)

--- Get all field statuses for a farm zone (bulk fetch for client cache)
lib.callback.register('free-farmer:server:getZoneFieldStatuses', function(src, farmZoneId)
    local zone = Utils.GetFarmZoneById(farmZoneId)
    if not zone then return {} end

    local statuses = {}
    for _, field in ipairs(zone.fields) do
        local state = fieldStateCache[field.id] or GetFieldState(field.id)
        if state then
            statuses[field.id] = state.status
        else
            statuses[field.id] = 'raw'
        end
    end

    return statuses
end)
