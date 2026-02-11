--[[
    free-farmer — Client Animal System
    Client-side AI controller (state bag driven), ox_target interactions on
    animal peds, feed/water troughs, barn management UI, animal purchase UI.
    AI behavior runs on the owning client and re-applies on ownership migration.
]]

local Utils = _G.FarmClientUtils
local aiApplied = {}       -- [netId] = true  (prevent duplicate AI threads)
local animalZoneTargets = {} -- [zoneId] = { targetIds }

-- =============================================================================
-- AI BEHAVIOR — Applied client-side via state bag watchers
-- =============================================================================

---@param ped number Entity handle
---@param penConfig table Pen config from Config.FarmZones
---@param aiConfig table AI config from Config.Animals
local function ApplyGrazingBehavior(ped, penConfig, aiConfig)
    CreateThread(function()
        while DoesEntityExist(ped) do
            TaskStartScenarioInPlace(ped, 'WORLD_COW_GRAZING', 0, true)
            Wait(math.random(aiConfig.idleTime.min, aiConfig.idleTime.max))

            if not DoesEntityExist(ped) then break end

            ClearPedTasks(ped)
            local center = Utils.GetPolygonCenter(penConfig.polygon)
            TaskWanderInArea(ped, center.x, center.y, center.z, penConfig.wanderRadius, aiConfig.wanderSpeed, aiConfig.wanderSpeed)
            Wait(math.random(5000, 10000))
        end
    end)
end

---@param ped number
---@param penConfig table
---@param aiConfig table
local function ApplyPeckingBehavior(ped, penConfig, aiConfig)
    CreateThread(function()
        while DoesEntityExist(ped) do
            TaskStartScenarioInPlace(ped, 'WORLD_CHICKEN_PECKING', 0, true)
            Wait(math.random(aiConfig.idleTime.min, aiConfig.idleTime.max))

            if not DoesEntityExist(ped) then break end

            ClearPedTasks(ped)
            local center = Utils.GetPolygonCenter(penConfig.polygon)
            local targetX = center.x + math.random(-math.floor(penConfig.wanderRadius), math.floor(penConfig.wanderRadius))
            local targetY = center.y + math.random(-math.floor(penConfig.wanderRadius), math.floor(penConfig.wanderRadius))
            TaskGoToCoordAnyMeans(ped, targetX, targetY, center.z, aiConfig.wanderSpeed, 0, 0, 786603, 0xbf800000)
            Wait(math.random(3000, 6000))
        end
    end)
end

---@param ped number
---@param penConfig table
---@param aiConfig table
local function ApplyRoamingBehavior(ped, penConfig, aiConfig)
    CreateThread(function()
        while DoesEntityExist(ped) do
            local center = Utils.GetPolygonCenter(penConfig.polygon)
            TaskWanderInArea(ped, center.x, center.y, center.z, penConfig.wanderRadius, aiConfig.wanderSpeed, aiConfig.wanderSpeed)
            Wait(math.random(aiConfig.idleTime.min, aiConfig.idleTime.max))

            if not DoesEntityExist(ped) then break end

            -- Occasional pause
            if math.random() < 0.3 then
                ClearPedTasks(ped)
                Wait(math.random(3000, 8000))
            end
        end
    end)
end

---@param ped number Entity handle
---@param animalType string
local function ApplyAnimalAI(ped, animalType)
    local animalConfig = Config.Animals[animalType]
    if not animalConfig or not animalConfig.ai then return end

    -- Configure ped flags
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 17, true)

    -- Get pen config from state bag
    local penId = Entity(ped).state.penId
    if not penId or penId == '' then return end

    local penConfig = nil
    for _, zone in ipairs(Config.FarmZones) do
        if zone.pens then
            for _, pen in ipairs(zone.pens) do
                if pen.id == penId then
                    penConfig = pen
                    break
                end
            end
        end
        if penConfig then break end
    end

    if not penConfig then return end

    local ai = animalConfig.ai

    if ai.behavior == 'grazing' then
        ApplyGrazingBehavior(ped, penConfig, ai)
    elseif ai.behavior == 'pecking' then
        ApplyPeckingBehavior(ped, penConfig, ai)
    elseif ai.behavior == 'roaming' then
        ApplyRoamingBehavior(ped, penConfig, ai)
    end
end

-- =============================================================================
-- STATE BAG HANDLER — Triggers AI when animal enters client scope
-- =============================================================================

AddStateBagChangeHandler('animalType', nil, function(bagName, _, value)
    if not value then return end

    local netId = tonumber(bagName:gsub('entity:', ''), 10)
    if not netId then return end

    -- Prevent duplicate AI
    if aiApplied[netId] then return end
    aiApplied[netId] = true

    CreateThread(function()
        local timeout = 0
        while not NetworkDoesEntityExistWithNetworkId(netId) and timeout < 50 do
            Wait(100)
            timeout = timeout + 1
        end

        if not NetworkDoesEntityExistWithNetworkId(netId) then
            aiApplied[netId] = nil
            return
        end

        local ped = NetworkGetEntityFromNetworkId(netId)
        if not ped or ped == 0 then
            aiApplied[netId] = nil
            return
        end

        ApplyAnimalAI(ped, value)

        -- Cleanup tracking when entity is removed
        CreateThread(function()
            while DoesEntityExist(ped) do
                Wait(5000)
            end
            aiApplied[netId] = nil
        end)
    end)
end)

-- =============================================================================
-- OX_TARGET — Animal model interactions
-- =============================================================================

-- Build unique model list
local animalModelSet = {}
for _, config in pairs(Config.Animals) do
    animalModelSet[config.pedModel] = true
end
local animalModels = {}
for model in pairs(animalModelSet) do
    animalModels[#animalModels + 1] = model
end

-- Helper: get the animal's actual type from state bag (handles shared models)
local function GetAnimalType(entity)
    return Entity(entity).state.animalType
end

exports.ox_target:addModel(animalModels, {
    {
        name = 'ff_check_animal',
        icon = 'fa-solid fa-heart-pulse',
        label = 'Check Animal',
        canInteract = function(entity)
            return Entity(entity).state.animalUuid ~= nil
        end,
        onSelect = function(data)
            local info = lib.callback.await('free-farmer:server:checkAnimal', false, Entity(data.entity).state.animalUuid)
            if not info then
                lib.notify({ type = 'error', description = 'Could not check animal.' })
                return
            end

            local healthColor = info.health >= 70 and '#33CC33' or (info.health >= 30 and '#CCCC33' or '#CC3333')
            local lines = {
                ('**%s** %s'):format(info.label, info.name and ('— ' .. info.name) or ''),
                ('**Health:** %d/100'):format(info.health),
                ('**Quality:** %s'):format(Utils.Capitalize(info.quality)),
                ('**Stage:** %s'):format(info.growthStage),
                ('**Gender:** %s'):format(Utils.Capitalize(info.gender)),
            }

            if info.isSick then
                lines[#lines + 1] = '**Status:** SICK'
            end
            if info.isHungry then
                lines[#lines + 1] = '**Hungry:** Yes'
            end
            if info.isThirsty then
                lines[#lines + 1] = '**Thirsty:** Yes'
            end
            if info.productionReady and info.productionType ~= 'none' then
                lines[#lines + 1] = ('**%s Ready!**'):format(Utils.Capitalize(info.productionType))
            end

            lib.alertDialog({
                header = 'Animal Status',
                content = table.concat(lines, '  \n'),
                centered = true,
                cancel = false,
            })
        end,
    },
    {
        name = 'ff_feed_animal',
        icon = 'fa-solid fa-seedling',
        label = 'Feed Animal',
        canInteract = function(entity)
            return Entity(entity).state.animalUuid ~= nil
        end,
        onSelect = function(data)
            local animalUuid = Entity(data.entity).state.animalUuid

            if lib.progressBar({
                duration = 5000,
                label = 'Feeding animal...',
                useWhileDead = false,
                canCancel = true,
                anim = { dict = 'amb@world_human_gardener_plant@male@base', name = 'base' },
            }) then
                local result = lib.callback.await('free-farmer:server:feedAnimal', false, animalUuid)
                if result and result.success then
                    lib.notify({ type = 'success', description = ('Fed %s.'):format(result.animalLabel) })
                elseif result then
                    lib.notify({ type = 'error', description = result.message })
                end
            end
        end,
    },
    {
        name = 'ff_water_animal',
        icon = 'fa-solid fa-droplet',
        label = 'Give Water',
        canInteract = function(entity)
            return Entity(entity).state.animalUuid ~= nil
        end,
        onSelect = function(data)
            local animalUuid = Entity(data.entity).state.animalUuid

            if lib.progressBar({
                duration = 4000,
                label = 'Watering animal...',
                useWhileDead = false,
                canCancel = true,
                anim = { dict = 'amb@world_human_gardener_plant@male@base', name = 'base' },
            }) then
                local result = lib.callback.await('free-farmer:server:waterAnimal', false, animalUuid)
                if result and result.success then
                    lib.notify({ type = 'success', description = ('Watered %s.'):format(result.animalLabel) })
                elseif result then
                    lib.notify({ type = 'error', description = result.message })
                end
            end
        end,
    },
    {
        name = 'ff_collect_production',
        icon = 'fa-solid fa-bucket',
        label = 'Collect',
        canInteract = function(entity)
            local animalType = GetAnimalType(entity)
            if not animalType then return false end
            local config = Config.Animals[animalType]
            if not config then return false end
            if config.production.type == 'none' then return false end
            return Entity(entity).state.productionReady == true
        end,
        onSelect = function(data)
            local animalUuid = Entity(data.entity).state.animalUuid
            local animalType = GetAnimalType(data.entity)
            local config = Config.Animals[animalType]

            local label = 'Collecting...'
            local duration = 8000
            if config and config.production.type == 'milk' then
                label = 'Milking...'
                duration = 10000
            elseif config and config.production.type == 'eggs' then
                label = 'Collecting eggs...'
                duration = 6000
            elseif config and config.production.type == 'wool' then
                label = 'Shearing...'
                duration = 12000
            end

            if lib.progressBar({
                duration = duration,
                label = label,
                useWhileDead = false,
                canCancel = true,
                anim = { dict = 'anim@mp_snowball', name = 'pickup_snowball' },
            }) then
                local result = lib.callback.await('free-farmer:server:collectProduction', false, animalUuid)
                if result and result.success then
                    lib.notify({
                        type = 'success',
                        description = ('Collected %dx %s (%s quality)'):format(result.yield, result.item, result.quality),
                    })
                elseif result then
                    lib.notify({ type = 'error', description = result.message })
                end
            end
        end,
    },
    {
        name = 'ff_name_animal',
        icon = 'fa-solid fa-tag',
        label = 'Name Animal',
        canInteract = function(entity)
            return Entity(entity).state.animalUuid ~= nil
        end,
        onSelect = function(data)
            local animalUuid = Entity(data.entity).state.animalUuid
            local currentName = Entity(data.entity).state.animalName

            local input = lib.inputDialog('Name Your Animal', {
                { type = 'input', label = 'Animal Name', placeholder = currentName or 'Bessie', max = 50 },
            })

            if input and input[1] and #input[1] > 0 then
                local result = lib.callback.await('free-farmer:server:nameAnimal', false, animalUuid, input[1])
                if result and result.success then
                    lib.notify({ type = 'success', description = ('Named: %s'):format(result.name) })
                elseif result then
                    lib.notify({ type = 'error', description = result.message })
                end
            end
        end,
    },
    {
        name = 'ff_store_animal',
        icon = 'fa-solid fa-warehouse',
        label = 'Store in Barn',
        canInteract = function(entity)
            return Entity(entity).state.animalUuid ~= nil
        end,
        onSelect = function(data)
            local animalUuid = Entity(data.entity).state.animalUuid
            local animalName = Entity(data.entity).state.animalName or 'this animal'

            local confirm = lib.alertDialog({
                header = 'Store Animal',
                content = ('Store **%s** in the barn?'):format(animalName),
                centered = true,
                cancel = true,
            })

            if confirm == 'confirm' then
                local result = lib.callback.await('free-farmer:server:storeAnimal', false, animalUuid)
                if result and result.success then
                    lib.notify({ type = 'success', description = 'Animal stored in barn.' })
                elseif result then
                    lib.notify({ type = 'error', description = result.message })
                end
            end
        end,
    },
})

-- =============================================================================
-- ZONE-BASED TARGETS: Feed troughs, water troughs, barn interaction
-- Registered when player enters a farm zone, unregistered on exit.
-- =============================================================================

--- Register trough and barn ox_target zones for a farm zone
---@param zone table Farm zone config
function RegisterAnimalZoneTargets(zone)
    if animalZoneTargets[zone.id] then return end -- Already registered

    local targets = {}

    -- Pen troughs
    if zone.pens then
        for _, pen in ipairs(zone.pens) do
            -- Feed trough
            if pen.feedTrough then
                local feedId = exports.ox_target:addSphereZone({
                    coords = pen.feedTrough,
                    radius = 1.5,
                    debug = Config.Debug,
                    options = {
                        {
                            name = 'ff_feed_trough_' .. pen.id,
                            icon = 'fa-solid fa-bowl-food',
                            label = 'Fill Feed Trough (' .. pen.label .. ')',
                            onSelect = function()
                                if lib.progressBar({
                                    duration = 6000,
                                    label = 'Filling feed trough...',
                                    useWhileDead = false,
                                    canCancel = true,
                                    anim = { dict = 'amb@world_human_gardener_plant@male@base', name = 'base' },
                                }) then
                                    local result = lib.callback.await('free-farmer:server:useFeedTrough', false, pen.id)
                                    if result and result.success then
                                        lib.notify({ type = 'success', description = ('Fed %d %s.'):format(result.count, result.animalType) })
                                    elseif result then
                                        lib.notify({ type = 'error', description = result.message })
                                    end
                                end
                            end,
                        },
                    },
                })
                targets[#targets + 1] = feedId
            end

            -- Water trough
            if pen.waterTrough then
                local waterId = exports.ox_target:addSphereZone({
                    coords = pen.waterTrough,
                    radius = 1.5,
                    debug = Config.Debug,
                    options = {
                        {
                            name = 'ff_water_trough_' .. pen.id,
                            icon = 'fa-solid fa-faucet-drip',
                            label = 'Fill Water Trough (' .. pen.label .. ')',
                            onSelect = function()
                                if lib.progressBar({
                                    duration = 5000,
                                    label = 'Filling water trough...',
                                    useWhileDead = false,
                                    canCancel = true,
                                    anim = { dict = 'amb@world_human_gardener_plant@male@base', name = 'base' },
                                }) then
                                    local result = lib.callback.await('free-farmer:server:useWaterTrough', false, pen.id)
                                    if result and result.success then
                                        lib.notify({ type = 'success', description = ('Watered %d %s.'):format(result.count, result.animalType) })
                                    elseif result then
                                        lib.notify({ type = 'error', description = result.message })
                                    end
                                end
                            end,
                        },
                    },
                })
                targets[#targets + 1] = waterId
            end
        end
    end

    -- Animal barn
    if zone.animal_barn then
        local barnId = exports.ox_target:addSphereZone({
            coords = zone.animal_barn,
            radius = 2.0,
            debug = Config.Debug,
            options = {
                {
                    name = 'ff_barn_purchase_' .. zone.id,
                    icon = 'fa-solid fa-cart-shopping',
                    label = 'Purchase Animal',
                    onSelect = function()
                        OpenAnimalPurchaseMenu(zone.id)
                    end,
                },
                {
                    name = 'ff_barn_manage_' .. zone.id,
                    icon = 'fa-solid fa-warehouse',
                    label = 'Manage Barn',
                    onSelect = function()
                        OpenBarnMenu(zone.id)
                    end,
                },
                {
                    name = 'ff_barn_breeding_' .. zone.id,
                    icon = 'fa-solid fa-paw',
                    label = 'Check Breeding Status',
                    onSelect = function()
                        OpenBreedingStatusMenu(zone)
                    end,
                },
            },
        })
        targets[#targets + 1] = barnId
    end

    animalZoneTargets[zone.id] = targets
end

--- Unregister trough and barn targets when leaving a zone
---@param zone table Farm zone config
function UnregisterAnimalZoneTargets(zone)
    local targets = animalZoneTargets[zone.id]
    if not targets then return end

    for _, targetId in ipairs(targets) do
        exports.ox_target:removeZone(targetId)
    end

    animalZoneTargets[zone.id] = nil
end

-- =============================================================================
-- ANIMAL PURCHASE UI
-- =============================================================================

function OpenAnimalPurchaseMenu(farmZoneId)
    local available = lib.callback.await('free-farmer:server:getAvailableAnimals', false, farmZoneId)

    if not available or #available == 0 then
        lib.notify({ type = 'inform', description = 'No animals available for purchase at your level.' })
        return
    end

    local options = {}
    for _, entry in ipairs(available) do
        options[#options + 1] = {
            title = entry.label,
            description = ('$%d | %s (%d/%d)'):format(entry.price, entry.penLabel, entry.currentCount, entry.maxCount),
            icon = 'fa-solid fa-paw',
            disabled = entry.currentCount >= entry.maxCount,
            onSelect = function()
                local confirm = lib.alertDialog({
                    header = 'Purchase ' .. entry.label,
                    content = ('Buy a **%s** for **$%d**?\nPen: %s (%d/%d)'):format(
                        entry.label, entry.price, entry.penLabel, entry.currentCount, entry.maxCount
                    ),
                    centered = true,
                    cancel = true,
                })

                if confirm == 'confirm' then
                    local result = lib.callback.await('free-farmer:server:purchaseAnimal', false,
                        farmZoneId, entry.animalType, entry.penId)

                    if result and result.success then
                        lib.notify({
                            type = 'success',
                            description = ('Purchased %s (%s)'):format(result.animalLabel, result.gender),
                        })
                    elseif result then
                        lib.notify({ type = 'error', description = result.message })
                    end
                end
            end,
        }
    end

    lib.registerContext({
        id = 'ff_animal_purchase',
        title = 'Purchase Animals',
        options = options,
    })
    lib.showContext('ff_animal_purchase')
end

-- =============================================================================
-- BARN MANAGEMENT UI
-- =============================================================================

function OpenBarnMenu(farmZoneId)
    local data = lib.callback.await('free-farmer:server:getBarnAnimals', false, farmZoneId)

    if not data or (#data.active == 0 and #data.stored == 0) then
        lib.notify({ type = 'inform', description = 'You have no animals at this farm.' })
        return
    end

    local options = {}

    -- Active animals
    if #data.active > 0 then
        options[#options + 1] = {
            title = 'Active Animals (' .. #data.active .. ')',
            icon = 'fa-solid fa-cow',
            disabled = true,
        }

        for _, animal in ipairs(data.active) do
            local healthIcon = animal.health >= 70 and 'fa-solid fa-heart' or 'fa-solid fa-heart-crack'
            options[#options + 1] = {
                title = ('%s%s'):format(animal.label, animal.name and (' — ' .. animal.name) or ''),
                description = ('HP: %d | %s | %s'):format(animal.health, animal.quality, animal.growthStage),
                icon = healthIcon,
                onSelect = function()
                    local confirm = lib.alertDialog({
                        header = 'Store in Barn?',
                        content = ('Store **%s** in the barn?'):format(animal.name or animal.label),
                        centered = true,
                        cancel = true,
                    })
                    if confirm == 'confirm' then
                        local result = lib.callback.await('free-farmer:server:storeAnimal', false, animal.uuid)
                        if result and result.success then
                            lib.notify({ type = 'success', description = 'Animal stored.' })
                        elseif result then
                            lib.notify({ type = 'error', description = result.message })
                        end
                    end
                end,
            }
        end
    end

    -- Stored animals
    if #data.stored > 0 then
        options[#options + 1] = {
            title = 'Stored Animals (' .. #data.stored .. ')',
            icon = 'fa-solid fa-warehouse',
            disabled = true,
        }

        for _, animal in ipairs(data.stored) do
            options[#options + 1] = {
                title = ('%s%s'):format(animal.label, animal.name and (' — ' .. animal.name) or ''),
                description = ('HP: %d | %s | %s'):format(animal.health, animal.quality, animal.growthStage),
                icon = 'fa-solid fa-box',
                onSelect = function()
                    OpenReleasePenSelector(farmZoneId, animal)
                end,
            }
        end
    end

    lib.registerContext({
        id = 'ff_barn_manage',
        title = 'Barn Management',
        options = options,
    })
    lib.showContext('ff_barn_manage')
end

--- Let player choose which pen to release an animal into
function OpenReleasePenSelector(farmZoneId, animal)
    local zone = nil
    for _, z in ipairs(Config.FarmZones) do
        if z.id == farmZoneId then
            zone = z
            break
        end
    end

    if not zone or not zone.pens then
        lib.notify({ type = 'error', description = 'No pens available.' })
        return
    end

    local options = {}
    for _, pen in ipairs(zone.pens) do
        if pen.animalType == animal.type then
            options[#options + 1] = {
                title = pen.label,
                description = ('For %s'):format(pen.animalType),
                icon = 'fa-solid fa-door-open',
                onSelect = function()
                    local result = lib.callback.await('free-farmer:server:releaseAnimal', false, animal.uuid, pen.id)
                    if result and result.success then
                        lib.notify({ type = 'success', description = 'Animal released to pen.' })
                    elseif result then
                        lib.notify({ type = 'error', description = result.message })
                    end
                end,
            }
        end
    end

    if #options == 0 then
        lib.notify({ type = 'error', description = 'No compatible pens for this animal type.' })
        return
    end

    lib.registerContext({
        id = 'ff_release_pen',
        title = 'Select Pen',
        menu = 'ff_barn_manage',
        options = options,
    })
    lib.showContext('ff_release_pen')
end

-- =============================================================================
-- BREEDING STATUS UI
-- =============================================================================

function OpenBreedingStatusMenu(zone)
    if not zone.pens or #zone.pens == 0 then
        lib.notify({ type = 'inform', description = 'No pens at this farm.' })
        return
    end

    local options = {}

    for _, pen in ipairs(zone.pens) do
        local info = lib.callback.await('free-farmer:server:getBreedingStatus', false, pen.id)

        if info then
            local statusLines = {}
            statusLines[#statusLines + 1] = ('Adults: %d/%d needed'):format(info.adultCount, info.minHerdSize)
            statusLines[#statusLines + 1] = ('Pen: %d/%d'):format(info.totalCount, info.maxCapacity)

            if info.cooldownRemaining and info.cooldownRemaining > 0 then
                statusLines[#statusLines + 1] = ('Cooldown: %s'):format(Utils.FormatTime(info.cooldownRemaining))
            elseif info.wellKeptRemaining then
                if info.wellKeptRemaining > 0 then
                    statusLines[#statusLines + 1] = ('Well-kept progress: %s remaining'):format(Utils.FormatTime(info.wellKeptRemaining))
                else
                    statusLines[#statusLines + 1] = 'Ready to produce offspring!'
                end
            else
                statusLines[#statusLines + 1] = 'Conditions not yet met'
            end

            options[#options + 1] = {
                title = ('%s — %s'):format(pen.label, info.animalLabel),
                description = table.concat(statusLines, ' | '),
                icon = 'fa-solid fa-paw',
            }
        end
    end

    if #options == 0 then
        lib.notify({ type = 'inform', description = 'No breeding information available.' })
        return
    end

    lib.registerContext({
        id = 'ff_breeding_status',
        title = 'Breeding Status',
        options = options,
    })
    lib.showContext('ff_breeding_status')
end

-- =============================================================================
-- CLIENT UTILITY: Polygon center (needed by AI for pen center calculation)
-- =============================================================================

function Utils.GetPolygonCenter(polygon)
    local sumX, sumY, sumZ = 0.0, 0.0, 0.0
    local count = #polygon

    for _, p in ipairs(polygon) do
        sumX = sumX + p.x
        sumY = sumY + p.y
        sumZ = sumZ + p.z
    end

    return vec3(sumX / count, sumY / count, sumZ / count)
end
