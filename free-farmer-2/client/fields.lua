--[[
    free-farmer — Client Field Interactions
    Registers ox_target zones at field interaction points.
    Handles progress bars, animations, and crop selection UI.
]]

local Utils = _G.FarmClientUtils
local activeZoneIds = {} -- Stores numeric ox_target zone IDs for cleanup

-- Animation dictionaries
local ANIM = {
    plow     = { dict = 'amb@world_human_gardener_plant@male@base', name = 'base' },
    plant    = { dict = 'amb@world_human_gardener_plant@male@base', name = 'base' },
    harvest  = { dict = 'anim@mp_snowball',                        name = 'pickup_snowball' },
}

--- Load animation dictionary
---@param dict string
local function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return end
    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end
end

--- Play farming animation
---@param animKey string Key from ANIM table
local function PlayFarmAnim(animKey)
    local anim = ANIM[animKey]
    if not anim then return end
    LoadAnimDict(anim.dict)
    TaskPlayAnim(cache.ped, anim.dict, anim.name, 8.0, -8.0, -1, 1, 0, false, false, false)
end

--- Stop animation
local function StopFarmAnim()
    ClearPedTasks(cache.ped)
end

-- =============================================================================
-- FIELD STATUS CACHE
-- Populated on zone enter, read synchronously by canInteract (never blocks).
-- =============================================================================

local fieldStatusCache = {} -- [fieldId] = 'raw' | 'plowed' | 'planted' | 'harvestable'

--- Fetch all field statuses for a farm zone from server and cache them
---@param farmZoneId string
local function RefreshFieldStatusCache(farmZoneId)
    local statuses = lib.callback.await('free-farmer:server:getZoneFieldStatuses', false, farmZoneId)
    if statuses then
        for fieldId, status in pairs(statuses) do
            fieldStatusCache[fieldId] = status
        end
    end
end

--- Invalidate and refresh a single field's cached status
---@param fieldId string
local function RefreshSingleFieldStatus(fieldId)
    local info = lib.callback.await('free-farmer:server:checkField', false, fieldId)
    if info then
        fieldStatusCache[fieldId] = info.status
    end
end

---@param fieldId string
---@return boolean
function CanPlowField(fieldId)
    return fieldStatusCache[fieldId] == 'raw'
end

---@param fieldId string
---@return boolean
function CanPlantField(fieldId)
    return fieldStatusCache[fieldId] == 'plowed'
end

---@param fieldId string
---@return boolean
function CanHarvestField(fieldId)
    return fieldStatusCache[fieldId] == 'harvestable'
end

-- =============================================================================
-- FIELD TARGET REGISTRATION
-- =============================================================================

--- Register ox_target interaction points for all fields in a zone
---@param zone table Farm zone config
function RegisterFieldTargets(zone)
    -- Pre-fetch all field statuses for this zone (single callback)
    RefreshFieldStatusCache(zone.id)

    for _, field in ipairs(zone.fields) do
        local fieldId = field.id

        local zoneId = exports.ox_target:addBoxZone({
            coords = vec3(field.interactionPoint.x, field.interactionPoint.y, field.interactionPoint.z),
            size = vec3(3.0, 3.0, 2.5),
            rotation = field.interactionPoint.w or 0.0,
            debug = Config.Debug,
            options = {
                {
                    name = 'ff_plow_' .. fieldId,
                    icon = 'fas fa-tractor',
                    label = 'Plow Field',
                    onSelect = function()
                        PlowField(fieldId, zone.id)
                    end,
                    canInteract = function()
                        return CanPlowField(fieldId)
                    end,
                },
                {
                    name = 'ff_plant_' .. fieldId,
                    icon = 'fas fa-seedling',
                    label = 'Plant Seeds',
                    onSelect = function()
                        OpenPlantMenu(fieldId, zone.id)
                    end,
                    canInteract = function()
                        return CanPlantField(fieldId)
                    end,
                },
                {
                    name = 'ff_harvest_' .. fieldId,
                    icon = 'fas fa-wheat-awn',
                    label = 'Harvest Crop',
                    onSelect = function()
                        HarvestField(fieldId, zone.id)
                    end,
                    canInteract = function()
                        return CanHarvestField(fieldId)
                    end,
                },
                {
                    name = 'ff_check_' .. fieldId,
                    icon = 'fas fa-magnifying-glass',
                    label = 'Check Field',
                    onSelect = function()
                        CheckField(fieldId)
                    end,
                },
            },
        })

        activeZoneIds[#activeZoneIds + 1] = zoneId
    end
end

--- Remove ox_target interaction points for a zone
---@param zone table Farm zone config
function UnregisterFieldTargets(zone)
    for _, zoneId in ipairs(activeZoneIds) do
        exports.ox_target:removeZone(zoneId)
    end
    activeZoneIds = {}

    -- Clear cached statuses for this zone's fields
    for _, field in ipairs(zone.fields) do
        fieldStatusCache[field.id] = nil
    end
end

-- =============================================================================
-- FIELD ACTIONS
-- =============================================================================

--- Plow a field
---@param fieldId string
---@param zoneId string
function PlowField(fieldId, zoneId)
    PlayFarmAnim('plow')

    local success = lib.progressBar({
        duration = 8000,
        label = 'Plowing field...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    StopFarmAnim()

    if not success then
        lib.notify({ title = 'Farming', description = 'Cancelled.', type = 'error' })
        return
    end

    local result = lib.callback.await('free-farmer:server:plowField', false, fieldId)

    if result and result.success then
        RefreshSingleFieldStatus(fieldId)
        lib.notify({ title = 'Farming', description = 'Field plowed and ready for planting.', type = 'success' })
    else
        lib.notify({ title = 'Farming', description = result and result.message or 'Failed to plow.', type = 'error' })
    end
end

--- Open crop selection menu for planting
---@param fieldId string
---@param zoneId string
function OpenPlantMenu(fieldId, zoneId)
    local crops = lib.callback.await('free-farmer:server:getPlantableCrops', false, fieldId)

    if not crops or #crops == 0 then
        lib.notify({ title = 'Farming', description = 'No crops available to plant here.', type = 'error' })
        return
    end

    local options = {}
    for _, crop in ipairs(crops) do
        local seedLabel = crop.seedCount > 0
            and ('Seeds: %d'):format(crop.seedCount)
            or 'No seeds!'

        options[#options + 1] = {
            title = crop.label,
            description = seedLabel,
            icon = 'fas fa-seedling',
            disabled = crop.seedCount < 1,
            onSelect = function()
                PlantCrop(fieldId, crop.type, crop.label)
            end,
        }
    end

    lib.registerContext({
        id = 'free_farmer_plant_menu',
        title = 'Select Crop to Plant',
        options = options,
    })

    lib.showContext('free_farmer_plant_menu')
end

--- Plant a specific crop in a field
---@param fieldId string
---@param cropType string
---@param cropLabel string
function PlantCrop(fieldId, cropType, cropLabel)
    PlayFarmAnim('plant')

    local success = lib.progressBar({
        duration = 5000,
        label = ('Planting %s...'):format(cropLabel),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    StopFarmAnim()

    if not success then
        lib.notify({ title = 'Farming', description = 'Cancelled.', type = 'error' })
        return
    end

    local result = lib.callback.await('free-farmer:server:plantField', false, fieldId, cropType)

    if result and result.success then
        RefreshSingleFieldStatus(fieldId)
        lib.notify({
            title = 'Farming',
            description = ('%s planted. Watch it grow!'):format(result.cropLabel),
            type = 'success',
        })
    else
        lib.notify({ title = 'Farming', description = result and result.message or 'Failed to plant.', type = 'error' })
    end
end

--- Harvest a field (uses harvest method for animation/duration)
---@param fieldId string
---@param zoneId string
function HarvestField(fieldId, zoneId)
    -- Get the harvest method for the crop in this field
    local method = lib.callback.await('free-farmer:server:getFieldHarvestMethod', false, fieldId)
    local methodConfig = Config.HarvestMethods[method] or Config.HarvestMethods.standard

    -- Play method-specific animation
    LoadAnimDict(methodConfig.anim.dict)
    TaskPlayAnim(cache.ped, methodConfig.anim.dict, methodConfig.anim.name,
        8.0, -8.0, -1, 1, 0, false, false, false)

    local success = lib.progressBar({
        duration = methodConfig.duration,
        label = methodConfig.label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    StopFarmAnim()

    if not success then
        lib.notify({ title = 'Farming', description = 'Cancelled.', type = 'error' })
        return
    end

    local result = lib.callback.await('free-farmer:server:harvestField', false, fieldId)

    if result and result.success then
        RefreshSingleFieldStatus(fieldId)

        local qualityStr = Utils.Capitalize(result.quality)
        local perennialNote = result.isPerennial and ' (regrowing)' or ''

        lib.notify({
            title = 'Harvest Complete',
            description = ('Harvested %dx %s (%s quality)%s'):format(
                result.yield, result.cropLabel, qualityStr, perennialNote
            ),
            type = 'success',
            duration = 5000,
        })
    else
        lib.notify({ title = 'Farming', description = result and result.message or 'Failed to harvest.', type = 'error' })
    end
end

--- Check field status and display info
---@param fieldId string
function CheckField(fieldId)
    local info = lib.callback.await('free-farmer:server:checkField', false, fieldId)

    if not info then
        lib.notify({ title = 'Farming', description = 'Could not inspect field.', type = 'error' })
        return
    end

    -- Update status cache
    fieldStatusCache[fieldId] = info.status

    -- Build info text
    local lines = {}
    lines[#lines + 1] = ('**Field:** %s'):format(info.label)
    lines[#lines + 1] = ('**Type:** %s'):format(Utils.Capitalize(info.fieldType))
    lines[#lines + 1] = ('**Status:** %s'):format(Utils.Capitalize(info.status))
    lines[#lines + 1] = ('**Weather:** %s'):format(Utils.Capitalize(info.weather))

    if info.cropLabel then
        lines[#lines + 1] = ('**Crop:** %s'):format(info.cropLabel)
        lines[#lines + 1] = ('**Stage:** %s (%d/%d)'):format(
            info.stageLabel or '?', info.growthStage, info.totalStages
        )

        if info.isPerennial then
            lines[#lines + 1] = '**Type:** Perennial (regrows after harvest)'
        end

        if info.harvestMethod and info.harvestMethod ~= 'standard' then
            lines[#lines + 1] = ('**Harvest:** %s'):format(Utils.Capitalize(info.harvestMethod:gsub('_', ' ')))
        end

        if info.timeRemaining then
            lines[#lines + 1] = ('**Next stage:** %s'):format(Utils.FormatTime(info.timeRemaining))
        end
    end

    lib.alertDialog({
        header = 'Field Inspection',
        content = table.concat(lines, '  \n'),
        centered = true,
        cancel = false,
    })
end
