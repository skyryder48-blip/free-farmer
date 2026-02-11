--[[
    free-farmer — Client Planter System
    Handles planter placement via ground raycast, and all planter interactions
    through ox_target on the planter prop model + state bag detection.
]]

local Utils = _G.FarmClientUtils

-- Animation helpers (reuse from fields pattern)
local function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return end
    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end
end

local function StopAnim()
    ClearPedTasks(cache.ped)
end

-- =============================================================================
-- PLANTER PLACEMENT
-- =============================================================================

--- Find a ground position in front of the player for planter placement
---@return boolean hit, vector3 coords, number heading
local function RaycastPlacement()
    local playerPed = cache.ped
    local playerCoords = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)

    -- Cast forward from player
    local forward = GetEntityForwardVector(playerPed)
    local dist = Config.Planter.placementMaxDistance or 3.0
    local target = playerCoords + forward * dist

    -- Find ground Z at target position
    local found, groundZ = GetGroundZFor_3dCoord(target.x, target.y, target.z + 5.0, false)

    if found then
        return true, vector3(target.x, target.y, groundZ), playerHeading
    end

    -- Fallback: use player's Z if ground not found
    return true, vector3(target.x, target.y, playerCoords.z), playerHeading
end

--- Place a garden planter in the world
function PlacePlanter()
    -- Check planter count first
    local count = lib.callback.await('free-farmer:server:getPlanterCount', false)
    if count >= Config.Planter.maxPerPlayer then
        lib.notify({
            title = 'Planter',
            description = ('Maximum %d planters reached.'):format(Config.Planter.maxPerPlayer),
            type = 'error',
        })
        return
    end

    -- Find ground position in front of player
    local _, coords, heading = RaycastPlacement()

    -- Place animation
    LoadAnimDict('anim@heists@box_carry@')
    TaskPlayAnim(cache.ped, 'anim@heists@box_carry@', 'putdown', 8.0, -8.0, 1500, 0, 0, false, false, false)

    local success = lib.progressBar({
        duration = 3000,
        label = 'Placing planter...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    StopAnim()

    if not success then
        lib.notify({ title = 'Planter', description = 'Cancelled.', type = 'error' })
        return
    end

    local result = lib.callback.await('free-farmer:server:placePlanter', false, coords, heading)

    if result and result.success then
        lib.notify({
            title = 'Planter',
            description = 'Garden planter placed!',
            type = 'success',
        })
    else
        lib.notify({
            title = 'Planter',
            description = result and result.message or 'Failed to place planter.',
            type = 'error',
        })
    end
end

-- =============================================================================
-- PLANTER INTERACTIONS (ox_target on model)
-- =============================================================================

-- Forward declaration for closure capture
local PlantInPlanter

--- Open crop selection menu for planting in a planter
---@param planterUuid string
local function OpenPlanterPlantMenu(planterUuid)
    local crops = lib.callback.await('free-farmer:server:getPlanterPlantableCrops', false, planterUuid)

    if not crops or #crops == 0 then
        lib.notify({
            title = 'Planter',
            description = 'No crops available for planters at your level.',
            type = 'error',
        })
        return
    end

    local options = {}
    for _, crop in ipairs(crops) do
        local canPlant = crop.seedCount > 0
        options[#options + 1] = {
            title = crop.label,
            description = canPlant
                and ('Seeds: %d — Level %d'):format(crop.seedCount, crop.unlockLevel)
                or ('No seeds — need %s'):format(crop.seedItem),
            icon = canPlant and 'fas fa-seedling' or 'fas fa-xmark',
            disabled = not canPlant,
            onSelect = function()
                PlantInPlanter(planterUuid, crop.type, crop.label)
            end,
        }
    end

    lib.registerContext({
        id = 'ff_planter_plant',
        title = 'Plant in Planter',
        options = options,
    })

    lib.showContext('ff_planter_plant')
end

--- Plant seeds in a planter
---@param planterUuid string
---@param cropType string
---@param cropLabel string
PlantInPlanter = function(planterUuid, cropType, cropLabel)
    LoadAnimDict('amb@world_human_gardener_plant@male@base')
    TaskPlayAnim(cache.ped, 'amb@world_human_gardener_plant@male@base', 'base',
        8.0, -8.0, -1, 1, 0, false, false, false)

    local success = lib.progressBar({
        duration = 4000,
        label = 'Planting ' .. cropLabel .. '...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    StopAnim()

    if not success then
        lib.notify({ title = 'Planter', description = 'Cancelled.', type = 'error' })
        return
    end

    local result = lib.callback.await('free-farmer:server:plantInPlanter', false, planterUuid, cropType)

    if result and result.success then
        lib.notify({
            title = 'Planter',
            description = ('Planted %s in planter.'):format(result.cropLabel),
            type = 'success',
        })
    else
        lib.notify({
            title = 'Planter',
            description = result and result.message or 'Failed to plant.',
            type = 'error',
        })
    end
end

--- Harvest from a planter
---@param planterUuid string
local function HarvestPlanter(planterUuid)
    LoadAnimDict('anim@mp_snowball')
    TaskPlayAnim(cache.ped, 'anim@mp_snowball', 'pickup_snowball',
        8.0, -8.0, -1, 1, 0, false, false, false)

    local success = lib.progressBar({
        duration = 8000,
        label = 'Harvesting planter...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    StopAnim()

    if not success then
        lib.notify({ title = 'Planter', description = 'Cancelled.', type = 'error' })
        return
    end

    local result = lib.callback.await('free-farmer:server:harvestPlanter', false, planterUuid)

    if result and result.success then
        local qualityStr = Utils.Capitalize(result.quality)
        lib.notify({
            title = 'Planter Harvest',
            description = ('Harvested %dx %s (%s quality)'):format(
                result.yield, result.cropLabel, qualityStr
            ),
            type = 'success',
            duration = 5000,
        })
    else
        lib.notify({
            title = 'Planter',
            description = result and result.message or 'Failed to harvest.',
            type = 'error',
        })
    end
end

--- Check planter status
---@param planterUuid string
local function CheckPlanter(planterUuid)
    local info = lib.callback.await('free-farmer:server:checkPlanter', false, planterUuid)
    if not info then
        lib.notify({ title = 'Planter', description = 'Could not check planter.', type = 'error' })
        return
    end

    local lines = {}
    lines[#lines + 1] = ('**Status:** %s'):format(Utils.Capitalize(info.status))

    if info.cropLabel then
        lines[#lines + 1] = ('**Crop:** %s'):format(info.cropLabel)
        lines[#lines + 1] = ('**Stage:** %s (%d/%d)'):format(
            info.stageLabel or '?', info.growthStage, info.totalStages
        )

        if info.timeRemaining then
            lines[#lines + 1] = ('**Next stage:** %s'):format(Utils.FormatTime(info.timeRemaining))
        end
    else
        lines[#lines + 1] = '*Empty — ready for planting*'
    end

    lib.alertDialog({
        header = 'Garden Planter',
        content = table.concat(lines, '  \n'),
        centered = true,
        size = 'sm',
    })
end

--- Pick up a planter
---@param planterUuid string
local function PickupPlanter(planterUuid)
    LoadAnimDict('anim@heists@box_carry@')
    TaskPlayAnim(cache.ped, 'anim@heists@box_carry@', 'pickup', 8.0, -8.0, 1500, 0, 0, false, false, false)

    local success = lib.progressBar({
        duration = 3000,
        label = 'Picking up planter...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    StopAnim()

    if not success then
        lib.notify({ title = 'Planter', description = 'Cancelled.', type = 'error' })
        return
    end

    local result = lib.callback.await('free-farmer:server:pickupPlanter', false, planterUuid)

    if result and result.success then
        lib.notify({
            title = 'Planter',
            description = 'Planter picked up.',
            type = 'success',
        })
    else
        lib.notify({
            title = 'Planter',
            description = result and result.message or 'Failed to pick up.',
            type = 'error',
        })
    end
end

-- =============================================================================
-- OX_TARGET REGISTRATION ON PLANTER PROP MODEL
-- =============================================================================

--- Helper: get state bag values from entity
---@param entity number
---@return string|nil uuid, string status
local function GetPlanterState(entity)
    local state = Entity(entity).state
    local uuid = state.planterUuid
    local status = state.planterStatus or 'empty'
    return uuid, status
end

-- Register ox_target on the planter prop model
-- This catches ALL planter props in the world. State bags filter interactions.
CreateThread(function()
    Wait(1000) -- Let things initialize

    local planterModel = Config.Planter.prop

    exports.ox_target:addModel(planterModel, {
        {
            name = 'ff_planter_plant',
            icon = 'fas fa-seedling',
            label = 'Plant Seeds',
            distance = Config.Planter.interactionDistance,
            canInteract = function(entity)
                local uuid, status = GetPlanterState(entity)
                return uuid ~= nil and status == 'empty'
            end,
            onSelect = function(data)
                local uuid = Entity(data.entity).state.planterUuid
                if uuid then
                    OpenPlanterPlantMenu(uuid)
                end
            end,
        },
        {
            name = 'ff_planter_harvest',
            icon = 'fas fa-wheat-awn',
            label = 'Harvest Planter',
            distance = Config.Planter.interactionDistance,
            canInteract = function(entity)
                local uuid, status = GetPlanterState(entity)
                return uuid ~= nil and status == 'harvestable'
            end,
            onSelect = function(data)
                local uuid = Entity(data.entity).state.planterUuid
                if uuid then
                    HarvestPlanter(uuid)
                end
            end,
        },
        {
            name = 'ff_planter_check',
            icon = 'fas fa-magnifying-glass',
            label = 'Check Planter',
            distance = Config.Planter.interactionDistance,
            canInteract = function(entity)
                return Entity(entity).state.planterUuid ~= nil
            end,
            onSelect = function(data)
                local uuid = Entity(data.entity).state.planterUuid
                if uuid then
                    CheckPlanter(uuid)
                end
            end,
        },
        {
            name = 'ff_planter_pickup',
            icon = 'fas fa-hand',
            label = 'Pick Up Planter',
            distance = Config.Planter.interactionDistance,
            canInteract = function(entity)
                if not Config.Planter.pickupEnabled then return false end
                return Entity(entity).state.planterUuid ~= nil
            end,
            onSelect = function(data)
                local uuid = Entity(data.entity).state.planterUuid
                if uuid then
                    PickupPlanter(uuid)
                end
            end,
        },
    })
end)

-- =============================================================================
-- ITEM USE HANDLER
-- Triggered by ox_inventory when player uses garden_planter item.
-- Item definition must include: client = { event = 'free-farmer:client:usePlanter' }
-- =============================================================================

RegisterNetEvent('free-farmer:client:usePlanter', function()
    PlacePlanter()
end)
