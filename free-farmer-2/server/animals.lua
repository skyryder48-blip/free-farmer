--[[
    free-farmer — Server Animal System
    Animal CRUD, health ticks, production cycles, simplified auto-breeding,
    OneSync entity spawning/despawning, barn storage, feed/water troughs.

    Simplified Breeding:
    - No gender pairing or pregnancy tracking
    - Pen maintains a "well-kept" timer
    - If enough adults are healthy + fed/watered for a sustained period, offspring appear
    - Rewards consistent care rather than micro-managed breeding interactions
]]

local Utils = _G.FarmUtils

-- =============================================================================
-- STATE TRACKING
-- =============================================================================

local spawnedAnimals = {}    -- [animalUuid] = { entity = entityId, netId = netId }
local animalFarmZones = {}   -- [farmZoneId] = playerCount
local penBreedingState = {}  -- [penId] = { wellKeptSince = int|nil, lastBirth = int|nil }

-- =============================================================================
-- ANIMAL SPAWNING / DESPAWNING
-- =============================================================================

---@param animalData table Database row from farm_animals
---@return number|nil entityId
local function SpawnAnimal(animalData)
    if animalData.is_stored == 1 or animalData.is_stored == true then return nil end
    if spawnedAnimals[animalData.animal_uuid] then return spawnedAnimals[animalData.animal_uuid].entity end

    local animalConfig = Config.Animals[animalData.animal_type]
    if not animalConfig then return nil end

    local penConfig = Utils.GetPenConfig(animalData.pen_id)
    if not penConfig then return nil end

    local spawnPos = Utils.GetRandomPointInPolygon(penConfig.polygon)
    local pedModel = joaat(animalConfig.pedModel)

    local entity = CreatePed(28, pedModel, spawnPos.x, spawnPos.y, spawnPos.z, math.random(0, 360), true, false)

    if not entity or entity == 0 then
        Utils.Error('[Animals] Failed to spawn %s (uuid: %s)', animalData.animal_type, animalData.animal_uuid)
        return nil
    end

    SetEntityOrphanMode(entity, 2)

    -- State bags for client-side AI + interactions
    local stateBag = Entity(entity).state
    stateBag:set('animalUuid', animalData.animal_uuid, true)
    stateBag:set('animalType', animalData.animal_type, true)
    stateBag:set('animalName', animalData.animal_name or '', true)
    stateBag:set('health', animalData.health, true)
    stateBag:set('quality', animalData.quality, true)
    stateBag:set('growthStage', animalData.growth_stage, true)
    stateBag:set('isSick', animalData.is_sick == 1, true)
    stateBag:set('productionReady', animalData.production_ready == 1, true)
    stateBag:set('penId', animalData.pen_id or '', true)

    local netId = NetworkGetNetworkIdFromEntity(entity)

    spawnedAnimals[animalData.animal_uuid] = {
        entity = entity,
        netId = netId,
    }

    Utils.Debug('[Animals] Spawned %s "%s" (uuid: %s, entity: %d)',
        animalData.animal_type,
        animalData.animal_name or 'unnamed',
        animalData.animal_uuid,
        entity)

    return entity
end

---@param animalUuid string
local function DespawnAnimal(animalUuid)
    local data = spawnedAnimals[animalUuid]
    if not data then return end

    if data.entity and DoesEntityExist(data.entity) then
        DeleteEntity(data.entity)
    end

    spawnedAnimals[animalUuid] = nil
    Utils.Debug('[Animals] Despawned uuid: %s', animalUuid)
end

--- Refresh a spawned animal's state bags from DB
---@param animalUuid string
local function RefreshAnimalStateBags(animalUuid)
    local data = spawnedAnimals[animalUuid]
    if not data or not data.entity or not DoesEntityExist(data.entity) then return end

    local animal = MySQL.single.await(
        'SELECT * FROM farm_animals WHERE animal_uuid = ?', { animalUuid }
    )
    if not animal then return end

    local stateBag = Entity(data.entity).state
    stateBag:set('health', animal.health, true)
    stateBag:set('quality', animal.quality, true)
    stateBag:set('growthStage', animal.growth_stage, true)
    stateBag:set('isSick', animal.is_sick == 1, true)
    stateBag:set('productionReady', animal.production_ready == 1, true)
    stateBag:set('animalName', animal.animal_name or '', true)
end

-- =============================================================================
-- ZONE ENTER / EXIT — Spawn/Despawn animals when players arrive/leave
-- =============================================================================

RegisterNetEvent('free-farmer:server:playerEnteredZone', function(farmZoneId)
    local src = source
    animalFarmZones[farmZoneId] = (animalFarmZones[farmZoneId] or 0) + 1

    if animalFarmZones[farmZoneId] == 1 then
        -- First player: spawn all animals for this zone
        local animals = MySQL.query.await(
            'SELECT * FROM farm_animals WHERE farm_zone = ? AND is_stored = 0', { farmZoneId }
        )

        if animals then
            for _, animal in ipairs(animals) do
                if not spawnedAnimals[animal.animal_uuid] then
                    SpawnAnimal(animal)
                end
            end
            Utils.Debug('[Animals] Spawned %d animals for zone %s', #animals, farmZoneId)
        end
    end
end)

RegisterNetEvent('free-farmer:server:playerLeftZone', function(farmZoneId)
    local src = source
    animalFarmZones[farmZoneId] = math.max(0, (animalFarmZones[farmZoneId] or 0) - 1)

    if animalFarmZones[farmZoneId] == 0 then
        -- Last player left: despawn all animals for this zone
        local animals = MySQL.query.await(
            'SELECT animal_uuid FROM farm_animals WHERE farm_zone = ? AND is_stored = 0', { farmZoneId }
        )

        if animals then
            for _, animal in ipairs(animals) do
                DespawnAnimal(animal.animal_uuid)
            end
            Utils.Debug('[Animals] Despawned animals for zone %s', farmZoneId)
        end
    end
end)

-- =============================================================================
-- PEN BOUNDARY ENFORCEMENT
-- =============================================================================

CreateThread(function()
    Wait(10000)

    while true do
        Wait(30000) -- Check every 30 seconds

        for uuid, data in pairs(spawnedAnimals) do
            if data.entity and DoesEntityExist(data.entity) then
                local animal = MySQL.single.await(
                    'SELECT pen_id FROM farm_animals WHERE animal_uuid = ?', { uuid }
                )

                if animal and animal.pen_id then
                    local penConfig = Utils.GetPenConfig(animal.pen_id)
                    if penConfig then
                        local pos = GetEntityCoords(data.entity)
                        if not Utils.IsPointInPolygon(pos, penConfig.polygon) then
                            local center = Utils.GetPolygonCenter(penConfig.polygon)
                            SetEntityCoords(data.entity, center.x, center.y, center.z, false, false, false, false)
                            Utils.Debug('[Animals] Teleported escaped animal %s back to pen', uuid)
                        end
                    end
                end
            end
        end
    end
end)

-- =============================================================================
-- HEALTH TICK (Hourly)
-- Processes: health decay, hunger/thirst, sickness, death,
--            production readiness, storage degradation
-- =============================================================================

CreateThread(function()
    Wait(8000) -- Let resource load

    while true do
        Wait(Config.AnimalHealthTickInterval * 1000)

        local now = os.time()

        -- =====================================================================
        -- ACTIVE ANIMALS
        -- =====================================================================
        local activeAnimals = MySQL.query.await(
            'SELECT * FROM farm_animals WHERE is_stored = 0'
        )

        if activeAnimals then
            for _, animal in ipairs(activeAnimals) do
                local animalConfig = Config.Animals[animal.animal_type]
                if not animalConfig then goto nextActive end

                local healthCfg = animalConfig.health
                local needsCfg = animalConfig.needs

                -- Check feeding / watering status
                local timeSinceFed = animal.last_fed and (now - animal.last_fed) or 999999
                local timeSinceWatered = animal.last_watered and (now - animal.last_watered) or 999999
                local isHungry = timeSinceFed > needsCfg.feedInterval
                local isThirsty = timeSinceWatered > needsCfg.waterInterval

                -- Calculate health change
                local healthDecay = healthCfg.baseDecay
                if isHungry then healthDecay = healthDecay + healthCfg.hungerPenalty end
                if isThirsty then healthDecay = healthDecay + healthCfg.thirstPenalty end

                local newHealth = math.max(0, animal.health - healthDecay)

                -- Sickness check
                local isSick = animal.is_sick == 1
                local sicknessType = animal.sickness_type
                if newHealth <= healthCfg.sicknessThreshold and not isSick then
                    isSick = true
                    sicknessType = 'malnutrition'
                end

                -- Death check
                if newHealth <= healthCfg.deathThreshold then
                    MySQL.update.await('DELETE FROM farm_animals WHERE animal_uuid = ?', { animal.animal_uuid })
                    DespawnAnimal(animal.animal_uuid)

                    local ownerSrc = Utils.GetPlayerByCitizenId(animal.owner_identifier)
                    if ownerSrc then
                        TriggerClientEvent('ox_lib:notify', ownerSrc, {
                            type = 'error',
                            title = 'Animal Died',
                            description = (animal.animal_name or ('Your ' .. animal.animal_type)) .. ' has died from neglect.',
                        })
                    end

                    goto nextActive
                end

                -- Production readiness
                local productionReady = animal.production_ready == 1
                if animalConfig.production.type ~= 'none' and animalConfig.production.cycleTime then
                    -- Only adults produce
                    local isAdult = false
                    local stages = animalConfig.growthStages
                    local lastStage = stages[#stages]
                    if lastStage and animal.growth_stage == lastStage.stage then
                        isAdult = true
                    end

                    if isAdult and not productionReady then
                        local timeSinceProduced = animal.last_produced and (now - animal.last_produced) or 999999
                        if timeSinceProduced >= animalConfig.production.cycleTime then
                            productionReady = true
                        end
                    end
                end

                -- Update DB
                MySQL.update.await([[
                    UPDATE farm_animals SET
                        health = ?, is_sick = ?, sickness_type = ?,
                        production_ready = ?, updated_at = ?
                    WHERE animal_uuid = ?
                ]], {
                    newHealth, isSick and 1 or 0, sicknessType,
                    productionReady and 1 or 0, now,
                    animal.animal_uuid,
                })

                -- Refresh state bags if spawned
                if spawnedAnimals[animal.animal_uuid] then
                    local ent = spawnedAnimals[animal.animal_uuid].entity
                    if ent and DoesEntityExist(ent) then
                        local sb = Entity(ent).state
                        sb:set('health', newHealth, true)
                        sb:set('isSick', isSick, true)
                        sb:set('productionReady', productionReady, true)
                    end
                end

                ::nextActive::
            end
        end

        -- =====================================================================
        -- STORED ANIMALS — Storage degradation
        -- =====================================================================
        local storedAnimals = MySQL.query.await(
            'SELECT * FROM farm_animals WHERE is_stored = 1'
        )

        if storedAnimals then
            for _, animal in ipairs(storedAnimals) do
                local animalConfig = Config.Animals[animal.animal_type]
                if not animalConfig then goto nextStored end

                local storedDuration = animal.stored_at and (now - animal.stored_at) or 0
                local daysStored = storedDuration / 86400

                -- Health decay from storage
                local storageLoss = math.floor(animalConfig.storageDecay * daysStored * 0.04) -- Per-hour fraction
                local newHealth = math.max(0, animal.health - math.max(1, storageLoss))

                -- Sickness from extended storage
                local isSick = animal.is_sick == 1
                local sicknessType = animal.sickness_type
                if storedDuration >= animalConfig.storageSicknessTime and not isSick then
                    isSick = true
                    sicknessType = 'storage_neglect'
                end

                -- Quality downgrade after 7+ days
                local quality = animal.quality
                if storedDuration > 604800 then
                    if quality == 'excellent' then quality = 'good'
                    elseif quality == 'good' then quality = 'average'
                    elseif quality == 'average' then quality = 'poor' end
                end

                -- Death from neglect in storage
                if newHealth <= 0 then
                    MySQL.update.await('DELETE FROM farm_animals WHERE animal_uuid = ?', { animal.animal_uuid })

                    local ownerSrc = Utils.GetPlayerByCitizenId(animal.owner_identifier)
                    if ownerSrc then
                        TriggerClientEvent('ox_lib:notify', ownerSrc, {
                            type = 'error',
                            title = 'Animal Died',
                            description = (animal.animal_name or ('Your ' .. animal.animal_type)) .. ' died in storage.',
                        })
                    end

                    goto nextStored
                end

                MySQL.update.await([[
                    UPDATE farm_animals SET
                        health = ?, is_sick = ?, sickness_type = ?, quality = ?, updated_at = ?
                    WHERE animal_uuid = ?
                ]], { newHealth, isSick and 1 or 0, sicknessType, quality, now, animal.animal_uuid })

                ::nextStored::
            end
        end

        -- =====================================================================
        -- GROWTH PROGRESSION
        -- =====================================================================
        local allAnimals = MySQL.query.await('SELECT * FROM farm_animals')

        if allAnimals then
            for _, animal in ipairs(allAnimals) do
                local animalConfig = Config.Animals[animal.animal_type]
                if not animalConfig then goto nextGrowth end

                -- Increment age by the health tick interval
                local newAge = animal.age + Config.AnimalHealthTickInterval

                -- Find current growth stage index
                local currentIdx = nil
                for idx, stage in ipairs(animalConfig.growthStages) do
                    if stage.stage == animal.growth_stage then
                        currentIdx = idx
                        break
                    end
                end

                if currentIdx and animalConfig.growthStages[currentIdx + 1] then
                    local currentStage = animalConfig.growthStages[currentIdx]

                    if currentStage.duration and newAge >= currentStage.duration then
                        local nextStage = animalConfig.growthStages[currentIdx + 1]

                        MySQL.update.await(
                            'UPDATE farm_animals SET age = ?, growth_stage = ?, updated_at = ? WHERE animal_uuid = ?',
                            { newAge, nextStage.stage, now, animal.animal_uuid }
                        )

                        -- Refresh state bags
                        if spawnedAnimals[animal.animal_uuid] then
                            local ent = spawnedAnimals[animal.animal_uuid].entity
                            if ent and DoesEntityExist(ent) then
                                Entity(ent).state:set('growthStage', nextStage.stage, true)
                            end
                        end

                        -- Notify owner
                        local ownerSrc = Utils.GetPlayerByCitizenId(animal.owner_identifier)
                        if ownerSrc then
                            TriggerClientEvent('ox_lib:notify', ownerSrc, {
                                type = 'inform',
                                description = (animal.animal_name or ('Your ' .. animal.animal_type)) .. ' has grown to ' .. nextStage.label,
                            })
                        end
                    else
                        MySQL.update.await(
                            'UPDATE farm_animals SET age = ?, updated_at = ? WHERE animal_uuid = ?',
                            { newAge, now, animal.animal_uuid }
                        )
                    end
                else
                    MySQL.update.await(
                        'UPDATE farm_animals SET age = ?, updated_at = ? WHERE animal_uuid = ?',
                        { newAge, now, animal.animal_uuid }
                    )
                end

                ::nextGrowth::
            end
        end

        -- =====================================================================
        -- SIMPLIFIED AUTO-BREEDING
        -- =====================================================================
        for _, zone in ipairs(Config.FarmZones) do
            if not zone.pens then goto nextZone end

            for _, pen in ipairs(zone.pens) do
                local animalConfig = Config.Animals[pen.animalType]
                if not animalConfig or not animalConfig.breeding then goto nextPen end

                local breedCfg = animalConfig.breeding

                -- Load persistent breeding state
                if not penBreedingState[pen.id] then
                    local dbState = MySQL.single.await(
                        'SELECT * FROM farm_pen_breeding WHERE pen_id = ?', { pen.id }
                    )
                    if dbState then
                        penBreedingState[pen.id] = {
                            wellKeptSince = dbState.well_kept_since,
                            lastBirth = dbState.last_birth,
                        }
                    else
                        penBreedingState[pen.id] = { wellKeptSince = nil, lastBirth = nil }
                        MySQL.insert.await(
                            'INSERT IGNORE INTO farm_pen_breeding (pen_id) VALUES (?)', { pen.id }
                        )
                    end
                end

                local state = penBreedingState[pen.id]

                -- Check cooldown
                if state.lastBirth and (now - state.lastBirth) < breedCfg.cooldown then
                    goto nextPen
                end

                -- Count adults in this pen
                local penAnimals = MySQL.query.await(
                    'SELECT * FROM farm_animals WHERE pen_id = ? AND is_stored = 0', { pen.id }
                )

                if not penAnimals or #penAnimals == 0 then
                    -- No animals, reset well-kept timer
                    if state.wellKeptSince then
                        state.wellKeptSince = nil
                        MySQL.update.await(
                            'UPDATE farm_pen_breeding SET well_kept_since = NULL WHERE pen_id = ?', { pen.id }
                        )
                    end
                    goto nextPen
                end

                local adultCount = 0
                local allWellKept = true

                for _, animal in ipairs(penAnimals) do
                    -- Check if adult (last growth stage)
                    local stages = animalConfig.growthStages
                    local lastStage = stages[#stages]
                    local isAdult = lastStage and animal.growth_stage == lastStage.stage

                    if isAdult then
                        adultCount = adultCount + 1

                        -- Check health
                        if animal.health < breedCfg.healthThreshold then
                            allWellKept = false
                        end

                        -- Check fed recently
                        local timeSinceFed = animal.last_fed and (now - animal.last_fed) or 999999
                        if timeSinceFed > animalConfig.needs.feedInterval * 2 then
                            allWellKept = false
                        end

                        -- Check watered recently
                        local timeSinceWatered = animal.last_watered and (now - animal.last_watered) or 999999
                        if timeSinceWatered > animalConfig.needs.waterInterval * 2 then
                            allWellKept = false
                        end

                        -- Check not sick
                        if animal.is_sick == 1 then
                            allWellKept = false
                        end
                    end
                end

                -- Conditions check: enough adults AND all well-kept
                local conditionsMet = adultCount >= breedCfg.minHerdSize and allWellKept

                if conditionsMet then
                    -- Start or continue well-kept timer
                    if not state.wellKeptSince then
                        state.wellKeptSince = now
                        MySQL.update.await(
                            'UPDATE farm_pen_breeding SET well_kept_since = ? WHERE pen_id = ?',
                            { now, pen.id }
                        )
                        Utils.Debug('[Breeding] Pen %s started well-kept timer', pen.id)
                    end

                    -- Check if duration met
                    if (now - state.wellKeptSince) >= breedCfg.wellKeptDuration then
                        -- BIRTH EVENT
                        local offspringCount = math.random(breedCfg.offspringMin, breedCfg.offspringMax)

                        -- Check pen capacity
                        local currentCount = #penAnimals
                        local maxCapacity = animalConfig.penSize
                        local ownerIdentifier = penAnimals[1].owner_identifier

                        local spawnedCount = 0
                        local storedCount = 0

                        for i = 1, offspringCount do
                            local babyUuid = Utils.GenerateUUID()
                            local babyGender = math.random() < 0.5 and 'male' or 'female'
                            local firstStage = animalConfig.growthStages[1].stage
                            local fitInPen = (currentCount + spawnedCount) < maxCapacity

                            MySQL.insert.await([[
                                INSERT INTO farm_animals (
                                    animal_uuid, owner_identifier, animal_type, gender,
                                    farm_zone, pen_id, is_stored, growth_stage,
                                    quality, health, created_at, updated_at
                                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'average', 100, ?, ?)
                            ]], {
                                babyUuid, ownerIdentifier, pen.animalType, babyGender,
                                zone.id, fitInPen and pen.id or nil, fitInPen and 0 or 1,
                                firstStage, now, now,
                            })

                            if fitInPen then
                                -- Spawn if zone is active
                                if animalFarmZones[zone.id] and animalFarmZones[zone.id] > 0 then
                                    local babyData = MySQL.single.await(
                                        'SELECT * FROM farm_animals WHERE animal_uuid = ?', { babyUuid }
                                    )
                                    if babyData then
                                        SpawnAnimal(babyData)
                                    end
                                end
                                spawnedCount = spawnedCount + 1
                            else
                                -- Auto-store in barn
                                MySQL.update.await(
                                    'UPDATE farm_animals SET stored_at = ? WHERE animal_uuid = ?',
                                    { now, babyUuid }
                                )
                                storedCount = storedCount + 1
                            end
                        end

                        -- Update breeding state
                        state.wellKeptSince = nil
                        state.lastBirth = now
                        MySQL.update.await(
                            'UPDATE farm_pen_breeding SET well_kept_since = NULL, last_birth = ? WHERE pen_id = ?',
                            { now, pen.id }
                        )

                        -- Notify owner
                        local ownerSrc = Utils.GetPlayerByCitizenId(ownerIdentifier)
                        if ownerSrc then
                            local desc = ('%d new %s born in %s!'):format(
                                offspringCount, pen.animalType, pen.label
                            )
                            if storedCount > 0 then
                                desc = desc .. (' (%d auto-stored — pen full)'):format(storedCount)
                            end

                            TriggerClientEvent('ox_lib:notify', ownerSrc, {
                                type = 'success',
                                title = 'New Offspring!',
                                description = desc,
                            })
                        end

                        Utils.Debug('[Breeding] Pen %s produced %d offspring (%d in pen, %d stored)',
                            pen.id, offspringCount, spawnedCount, storedCount)
                    end
                else
                    -- Conditions not met: reset well-kept timer
                    if state.wellKeptSince then
                        state.wellKeptSince = nil
                        MySQL.update.await(
                            'UPDATE farm_pen_breeding SET well_kept_since = NULL WHERE pen_id = ?',
                            { pen.id }
                        )
                        Utils.Debug('[Breeding] Pen %s conditions dropped — timer reset', pen.id)
                    end
                end

                ::nextPen::
            end

            ::nextZone::
        end

        Utils.Debug('[Animals] Health tick complete')
    end
end)

-- =============================================================================
-- ANIMAL PURCHASE
-- =============================================================================

lib.callback.register('free-farmer:server:getAvailableAnimals', function(src, farmZoneId)
    local playerLevel = GetPlayerFarmingLevel(src)
    local zone = Utils.GetFarmZoneById(farmZoneId)
    if not zone or not zone.pens then return {} end

    local available = {}

    for _, pen in ipairs(zone.pens) do
        local animalConfig = Config.Animals[pen.animalType]
        if animalConfig and playerLevel >= animalConfig.unlockLevel then
            -- Count current animals in pen
            local count = MySQL.scalar.await(
                'SELECT COUNT(*) FROM farm_animals WHERE pen_id = ? AND is_stored = 0', { pen.id }
            )

            available[#available + 1] = {
                animalType = pen.animalType,
                label = animalConfig.label,
                price = animalConfig.purchasePrice,
                unlockLevel = animalConfig.unlockLevel,
                penId = pen.id,
                penLabel = pen.label,
                currentCount = count or 0,
                maxCount = animalConfig.penSize,
            }
        end
    end

    return available
end)

lib.callback.register('free-farmer:server:purchaseAnimal', function(src, farmZoneId, animalType, penId)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return { success = false, message = 'Player not found.' } end

    local citizenid = player.PlayerData.citizenid
    local animalConfig = Config.Animals[animalType]
    if not animalConfig then
        return { success = false, message = 'Invalid animal type.' }
    end

    -- Level check
    if not IsUnlockedAnimal(src, animalType) then
        return { success = false, message = ('Requires Farming Level %d.'):format(animalConfig.unlockLevel) }
    end

    -- Pen validation
    local penConfig = Utils.GetPenConfig(penId)
    if not penConfig then
        return { success = false, message = 'Invalid pen.' }
    end

    if penConfig.animalType ~= animalType then
        return { success = false, message = 'This pen is for ' .. penConfig.animalType .. '.' }
    end

    -- Capacity check
    local penCount = MySQL.scalar.await(
        'SELECT COUNT(*) FROM farm_animals WHERE pen_id = ? AND is_stored = 0', { penId }
    )
    if penCount >= animalConfig.penSize then
        return { success = false, message = ('Pen is full (max %d).'):format(animalConfig.penSize) }
    end

    -- Money check
    local price = animalConfig.purchasePrice
    if player.PlayerData.money.cash < price and player.PlayerData.money.bank < price then
        return { success = false, message = ('Not enough money ($%d required).'):format(price) }
    end

    -- Remove money (prefer cash, fall back to bank)
    local moneyType = player.PlayerData.money.cash >= price and 'cash' or 'bank'
    player.Functions.RemoveMoney(moneyType, price, 'animal-purchase')

    -- Ensure farm data exists
    EnsurePlayerFarmData(src)

    -- Create animal
    local uuid = Utils.GenerateUUID()
    local gender = math.random() < 0.5 and 'male' or 'female'
    local firstStage = animalConfig.growthStages[1].stage
    local now = os.time()
    local ownerName = Utils.GetPlayerName(src) or 'Unknown'

    MySQL.insert.await([[
        INSERT INTO farm_animals (
            animal_uuid, owner_identifier, owner_name, animal_type, gender,
            farm_zone, pen_id, growth_stage, quality, health,
            last_fed, last_watered, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'average', 100, ?, ?, ?, ?)
    ]], {
        uuid, citizenid, ownerName, animalType, gender,
        farmZoneId, penId, firstStage,
        now, now, now, now,
    })

    -- Spawn if zone is active
    if animalFarmZones[farmZoneId] and animalFarmZones[farmZoneId] > 0 then
        local animalData = MySQL.single.await(
            'SELECT * FROM farm_animals WHERE animal_uuid = ?', { uuid }
        )
        if animalData then
            SpawnAnimal(animalData)
        end
    end

    Utils.Debug('[Animals] Player %d purchased %s (uuid: %s, pen: %s)', src, animalType, uuid, penId)

    return {
        success = true,
        animalLabel = animalConfig.label,
        gender = gender,
        uuid = uuid,
    }
end)

-- =============================================================================
-- ANIMAL INTERACTIONS
-- =============================================================================

--- Check animal status
lib.callback.register('free-farmer:server:checkAnimal', function(src, animalUuid)
    local animal = MySQL.single.await(
        'SELECT * FROM farm_animals WHERE animal_uuid = ?', { animalUuid }
    )
    if not animal then return nil end

    local animalConfig = Config.Animals[animal.animal_type]
    if not animalConfig then return nil end

    local now = os.time()
    local needsCfg = animalConfig.needs

    -- Find stage label
    local stageLabel = animal.growth_stage
    for _, stage in ipairs(animalConfig.growthStages) do
        if stage.stage == animal.growth_stage then
            stageLabel = stage.label
            break
        end
    end

    -- Feeding/watering status
    local timeSinceFed = animal.last_fed and (now - animal.last_fed) or 999999
    local timeSinceWatered = animal.last_watered and (now - animal.last_watered) or 999999

    return {
        uuid = animalUuid,
        type = animal.animal_type,
        label = animalConfig.label,
        name = animal.animal_name,
        gender = animal.gender,
        health = animal.health,
        quality = animal.quality,
        growthStage = stageLabel,
        isSick = animal.is_sick == 1,
        isHungry = timeSinceFed > needsCfg.feedInterval,
        isThirsty = timeSinceWatered > needsCfg.waterInterval,
        productionReady = animal.production_ready == 1,
        productionType = animalConfig.production.type,
    }
end)

--- Feed individual animal
lib.callback.register('free-farmer:server:feedAnimal', function(src, animalUuid)
    local animal = MySQL.single.await(
        'SELECT * FROM farm_animals WHERE animal_uuid = ?', { animalUuid }
    )
    if not animal then return { success = false, message = 'Animal not found.' } end

    local animalConfig = Config.Animals[animal.animal_type]
    if not animalConfig then return { success = false, message = 'Invalid animal type.' } end

    local needsCfg = animalConfig.needs

    -- Check for feed items (primary + alternatives)
    local feedItems = { needsCfg.feedItem }
    if needsCfg.alternativeFeed then
        for _, alt in ipairs(needsCfg.alternativeFeed) do
            feedItems[#feedItems + 1] = alt
        end
    end

    local usedItem = nil
    for _, item in ipairs(feedItems) do
        local count = exports.ox_inventory:Search(src, 'count', item)
        if count and count >= needsCfg.feedAmount then
            usedItem = item
            break
        end
    end

    if not usedItem then
        return { success = false, message = ('Need %dx %s to feed.'):format(needsCfg.feedAmount, needsCfg.feedItem) }
    end

    local removed = exports.ox_inventory:RemoveItem(src, usedItem, needsCfg.feedAmount)
    if not removed then
        return { success = false, message = 'Could not remove feed items.' }
    end

    local now = os.time()

    -- Feeding heals slightly
    local newHealth = math.min(100, animal.health + 5)

    MySQL.update.await(
        'UPDATE farm_animals SET last_fed = ?, health = ?, updated_at = ? WHERE animal_uuid = ?',
        { now, newHealth, now, animalUuid }
    )

    RefreshAnimalStateBags(animalUuid)
    AwardXP(src, 'feed_animal')

    return { success = true, animalLabel = animalConfig.label }
end)

--- Water individual animal
lib.callback.register('free-farmer:server:waterAnimal', function(src, animalUuid)
    local animal = MySQL.single.await(
        'SELECT * FROM farm_animals WHERE animal_uuid = ?', { animalUuid }
    )
    if not animal then return { success = false, message = 'Animal not found.' } end

    local animalConfig = Config.Animals[animal.animal_type]
    if not animalConfig then return { success = false, message = 'Invalid animal type.' } end

    local now = os.time()
    local newHealth = math.min(100, animal.health + 3)

    MySQL.update.await(
        'UPDATE farm_animals SET last_watered = ?, health = ?, updated_at = ? WHERE animal_uuid = ?',
        { now, newHealth, now, animalUuid }
    )

    RefreshAnimalStateBags(animalUuid)
    AwardXP(src, 'water_animal')

    return { success = true, animalLabel = animalConfig.label }
end)

--- Collect production (milk, eggs, wool)
lib.callback.register('free-farmer:server:collectProduction', function(src, animalUuid)
    local animal = MySQL.single.await(
        'SELECT * FROM farm_animals WHERE animal_uuid = ?', { animalUuid }
    )
    if not animal then return { success = false, message = 'Animal not found.' } end

    if animal.production_ready ~= 1 then
        return { success = false, message = 'Not ready for collection.' }
    end

    local animalConfig = Config.Animals[animal.animal_type]
    if not animalConfig then return { success = false, message = 'Invalid animal type.' } end

    local prod = animalConfig.production
    if prod.type == 'none' or not prod.item then
        return { success = false, message = 'This animal has no collectible production.' }
    end

    -- Calculate yield
    local baseYield = math.random(prod.baseYield.min, prod.baseYield.max)
    local qualityMod = prod.qualityMultiplier[animal.quality] or 1.0
    local finalYield = math.max(1, math.floor(baseYield * qualityMod))

    -- Add to inventory
    local added = exports.ox_inventory:AddItem(src, prod.item, finalYield, {
        quality = animal.quality,
    })

    if not added then
        return { success = false, message = 'Inventory full.' }
    end

    local now = os.time()
    MySQL.update.await([[
        UPDATE farm_animals SET
            production_ready = 0, last_produced = ?,
            total_production = total_production + 1, updated_at = ?
        WHERE animal_uuid = ?
    ]], { now, now, animalUuid })

    RefreshAnimalStateBags(animalUuid)

    -- XP based on production type
    local xpAction = 'milk_animal'
    if prod.type == 'eggs' then xpAction = 'collect_eggs' end
    if prod.type == 'wool' then xpAction = 'shear_sheep' end
    AwardXP(src, xpAction)

    -- Update stats
    local citizenid = Utils.GetCitizenId(src)
    if citizenid then
        MySQL.update.await(
            'UPDATE farm_player_data SET total_production_collected = total_production_collected + 1 WHERE identifier = ?',
            { citizenid }
        )
    end

    return {
        success = true,
        yield = finalYield,
        item = prod.item,
        quality = animal.quality,
        productionType = prod.type,
        animalLabel = animalConfig.label,
    }
end)

--- Name an animal
lib.callback.register('free-farmer:server:nameAnimal', function(src, animalUuid, name)
    if not name or #name == 0 or #name > 50 then
        return { success = false, message = 'Invalid name (1-50 characters).' }
    end

    local citizenid = Utils.GetCitizenId(src)
    if not citizenid then return { success = false, message = 'Player not found.' } end

    local animal = MySQL.single.await(
        'SELECT * FROM farm_animals WHERE animal_uuid = ? AND owner_identifier = ?',
        { animalUuid, citizenid }
    )
    if not animal then return { success = false, message = 'Animal not found or not yours.' } end

    MySQL.update.await(
        'UPDATE farm_animals SET animal_name = ?, updated_at = ? WHERE animal_uuid = ?',
        { name, os.time(), animalUuid }
    )

    -- Update state bag
    if spawnedAnimals[animalUuid] then
        local ent = spawnedAnimals[animalUuid].entity
        if ent and DoesEntityExist(ent) then
            Entity(ent).state:set('animalName', name, true)
        end
    end

    return { success = true, name = name }
end)

-- =============================================================================
-- TROUGH FEEDING (Bulk — feed/water all animals in pen at once)
-- =============================================================================

lib.callback.register('free-farmer:server:useFeedTrough', function(src, penId)
    local penConfig, zoneConfig = Utils.GetPenConfig(penId)
    if not penConfig then return { success = false, message = 'Pen not found.' } end

    local animalConfig = Config.Animals[penConfig.animalType]
    if not animalConfig then return { success = false, message = 'Invalid animal type.' } end

    local animals = MySQL.query.await(
        'SELECT * FROM farm_animals WHERE pen_id = ? AND is_stored = 0', { penId }
    )
    if not animals or #animals == 0 then
        return { success = false, message = 'No animals in this pen.' }
    end

    local needsCfg = animalConfig.needs
    local totalFeedNeeded = #animals * needsCfg.feedAmount

    -- Check for feed items
    local feedItems = { needsCfg.feedItem }
    if needsCfg.alternativeFeed then
        for _, alt in ipairs(needsCfg.alternativeFeed) do
            feedItems[#feedItems + 1] = alt
        end
    end

    local usedItem = nil
    for _, item in ipairs(feedItems) do
        local count = exports.ox_inventory:Search(src, 'count', item)
        if count and count >= totalFeedNeeded then
            usedItem = item
            break
        end
    end

    if not usedItem then
        return { success = false, message = ('Need %dx %s to feed all %d animals.'):format(totalFeedNeeded, needsCfg.feedItem, #animals) }
    end

    local removed = exports.ox_inventory:RemoveItem(src, usedItem, totalFeedNeeded)
    if not removed then
        return { success = false, message = 'Could not remove feed items.' }
    end

    local now = os.time()
    for _, animal in ipairs(animals) do
        local newHealth = math.min(100, animal.health + 5)
        MySQL.update.await(
            'UPDATE farm_animals SET last_fed = ?, health = ?, updated_at = ? WHERE animal_uuid = ?',
            { now, newHealth, now, animal.animal_uuid }
        )
        RefreshAnimalStateBags(animal.animal_uuid)
    end

    AwardXP(src, 'feed_animal')

    return { success = true, count = #animals, animalType = penConfig.animalType }
end)

lib.callback.register('free-farmer:server:useWaterTrough', function(src, penId)
    local penConfig = Utils.GetPenConfig(penId)
    if not penConfig then return { success = false, message = 'Pen not found.' } end

    local animals = MySQL.query.await(
        'SELECT * FROM farm_animals WHERE pen_id = ? AND is_stored = 0', { penId }
    )
    if not animals or #animals == 0 then
        return { success = false, message = 'No animals in this pen.' }
    end

    local now = os.time()
    for _, animal in ipairs(animals) do
        local newHealth = math.min(100, animal.health + 3)
        MySQL.update.await(
            'UPDATE farm_animals SET last_watered = ?, health = ?, updated_at = ? WHERE animal_uuid = ?',
            { now, newHealth, now, animal.animal_uuid }
        )
        RefreshAnimalStateBags(animal.animal_uuid)
    end

    AwardXP(src, 'water_animal')

    return { success = true, count = #animals, animalType = penConfig.animalType }
end)

-- =============================================================================
-- BARN STORAGE
-- =============================================================================

lib.callback.register('free-farmer:server:getBarnAnimals', function(src, farmZoneId)
    local citizenid = Utils.GetCitizenId(src)
    if not citizenid then return {} end

    local animals = MySQL.query.await([[
        SELECT * FROM farm_animals
        WHERE owner_identifier = ? AND farm_zone = ?
        ORDER BY is_stored ASC, animal_type ASC
    ]], { citizenid, farmZoneId })

    if not animals then return {} end

    local result = { active = {}, stored = {} }

    for _, animal in ipairs(animals) do
        local animalConfig = Config.Animals[animal.animal_type]
        local stageLabel = animal.growth_stage
        if animalConfig then
            for _, stage in ipairs(animalConfig.growthStages) do
                if stage.stage == animal.growth_stage then
                    stageLabel = stage.label
                    break
                end
            end
        end

        local entry = {
            uuid = animal.animal_uuid,
            type = animal.animal_type,
            label = animalConfig and animalConfig.label or animal.animal_type,
            name = animal.animal_name,
            gender = animal.gender,
            health = animal.health,
            quality = animal.quality,
            growthStage = stageLabel,
            isSick = animal.is_sick == 1,
            penId = animal.pen_id,
        }

        if animal.is_stored == 1 then
            result.stored[#result.stored + 1] = entry
        else
            result.active[#result.active + 1] = entry
        end
    end

    return result
end)

lib.callback.register('free-farmer:server:storeAnimal', function(src, animalUuid)
    local citizenid = Utils.GetCitizenId(src)
    if not citizenid then return { success = false, message = 'Player not found.' } end

    local animal = MySQL.single.await(
        'SELECT * FROM farm_animals WHERE animal_uuid = ? AND owner_identifier = ?',
        { animalUuid, citizenid }
    )
    if not animal then return { success = false, message = 'Animal not found or not yours.' } end
    if animal.is_stored == 1 then return { success = false, message = 'Already stored.' } end

    local now = os.time()
    MySQL.update.await(
        'UPDATE farm_animals SET is_stored = 1, stored_at = ?, pen_id = NULL, updated_at = ? WHERE animal_uuid = ?',
        { now, now, animalUuid }
    )

    DespawnAnimal(animalUuid)

    return { success = true }
end)

lib.callback.register('free-farmer:server:releaseAnimal', function(src, animalUuid, penId)
    local citizenid = Utils.GetCitizenId(src)
    if not citizenid then return { success = false, message = 'Player not found.' } end

    local animal = MySQL.single.await(
        'SELECT * FROM farm_animals WHERE animal_uuid = ? AND owner_identifier = ?',
        { animalUuid, citizenid }
    )
    if not animal then return { success = false, message = 'Animal not found or not yours.' } end
    if animal.is_stored ~= 1 then return { success = false, message = 'Animal is not stored.' } end

    local penConfig = Utils.GetPenConfig(penId)
    if not penConfig then return { success = false, message = 'Invalid pen.' } end

    if penConfig.animalType ~= animal.animal_type then
        return { success = false, message = 'Wrong pen type for this animal.' }
    end

    local animalConfig = Config.Animals[animal.animal_type]
    local currentCount = MySQL.scalar.await(
        'SELECT COUNT(*) FROM farm_animals WHERE pen_id = ? AND is_stored = 0', { penId }
    )
    if currentCount >= (animalConfig and animalConfig.penSize or 999) then
        return { success = false, message = 'Pen is full.' }
    end

    local now = os.time()
    MySQL.update.await(
        'UPDATE farm_animals SET is_stored = 0, stored_at = NULL, pen_id = ?, updated_at = ? WHERE animal_uuid = ?',
        { penId, now, animalUuid }
    )

    -- Spawn if zone is active
    if animalFarmZones[animal.farm_zone] and animalFarmZones[animal.farm_zone] > 0 then
        local updatedAnimal = MySQL.single.await(
            'SELECT * FROM farm_animals WHERE animal_uuid = ?', { animalUuid }
        )
        if updatedAnimal then
            SpawnAnimal(updatedAnimal)
        end
    end

    return { success = true }
end)

-- =============================================================================
-- BREEDING STATUS (for client display)
-- =============================================================================

lib.callback.register('free-farmer:server:getBreedingStatus', function(src, penId)
    local penConfig = Utils.GetPenConfig(penId)
    if not penConfig then return nil end

    local animalConfig = Config.Animals[penConfig.animalType]
    if not animalConfig or not animalConfig.breeding then return nil end

    local state = penBreedingState[penId]
    if not state then
        local dbState = MySQL.single.await(
            'SELECT * FROM farm_pen_breeding WHERE pen_id = ?', { penId }
        )
        if dbState then
            state = { wellKeptSince = dbState.well_kept_since, lastBirth = dbState.last_birth }
        else
            state = { wellKeptSince = nil, lastBirth = nil }
        end
        penBreedingState[penId] = state
    end

    local now = os.time()
    local breedCfg = animalConfig.breeding

    -- Count adults
    local animals = MySQL.query.await(
        'SELECT * FROM farm_animals WHERE pen_id = ? AND is_stored = 0', { penId }
    )
    local adultCount = 0
    local totalCount = #(animals or {})

    if animals then
        local lastStage = animalConfig.growthStages[#animalConfig.growthStages]
        for _, animal in ipairs(animals) do
            if lastStage and animal.growth_stage == lastStage.stage then
                adultCount = adultCount + 1
            end
        end
    end

    local info = {
        animalType = penConfig.animalType,
        animalLabel = animalConfig.label,
        penLabel = penConfig.label,
        adultCount = adultCount,
        totalCount = totalCount,
        minHerdSize = breedCfg.minHerdSize,
        maxCapacity = animalConfig.penSize,
    }

    if state.wellKeptSince then
        local elapsed = now - state.wellKeptSince
        local remaining = math.max(0, breedCfg.wellKeptDuration - elapsed)
        info.wellKeptProgress = elapsed
        info.wellKeptRemaining = remaining
        info.wellKeptDuration = breedCfg.wellKeptDuration
    end

    if state.lastBirth then
        local cooldownRemaining = math.max(0, breedCfg.cooldown - (now - state.lastBirth))
        info.cooldownRemaining = cooldownRemaining
    end

    return info
end)
