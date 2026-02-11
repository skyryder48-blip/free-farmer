--[[
    free-farmer — Client Processing System
    Processing station ox_target interactions, recipe selection UI, progress bars.
    Stations are registered on resource start (always accessible, level-gated server-side).
]]

-- =============================================================================
-- PROCESSING STATION TARGETS
-- =============================================================================

local stationTargets = {}

local function RegisterProcessingStations()
    for _, station in ipairs(Config.ProcessingStations) do
        local targetId = exports.ox_target:addSphereZone({
            coords = station.location,
            radius = 2.0,
            debug = Config.Debug,
            options = {
                {
                    name = 'ff_process_' .. station.id,
                    icon = 'fa-solid fa-industry',
                    label = station.label,
                    onSelect = function()
                        OpenProcessingMenu(station.id)
                    end,
                },
            },
        })

        stationTargets[#stationTargets + 1] = targetId
    end
end

local function RemoveProcessingStations()
    for _, targetId in ipairs(stationTargets) do
        exports.ox_target:removeZone(targetId)
    end
    stationTargets = {}
end

-- =============================================================================
-- PROCESSING STATION BLIPS
-- =============================================================================

local processingBlips = {}

local function CreateProcessingBlips()
    for _, station in ipairs(Config.ProcessingStations) do
        if station.blip then
            local blip = AddBlipForCoord(station.location.x, station.location.y, station.location.z)
            SetBlipSprite(blip, station.blip.sprite or 648)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, station.blip.scale or 0.6)
            SetBlipColour(blip, station.blip.color or 0)
            SetBlipAsShortRange(blip, true)

            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(station.label)
            EndTextCommandSetBlipName(blip)

            processingBlips[#processingBlips + 1] = blip
        end
    end
end

local function RemoveProcessingBlips()
    for _, blip in ipairs(processingBlips) do
        RemoveBlip(blip)
    end
    processingBlips = {}
end

-- =============================================================================
-- RECIPE SELECTION MENU
-- =============================================================================

function OpenProcessingMenu(stationId)
    local data = lib.callback.await('free-farmer:server:getStationRecipes', false, stationId)

    if not data then
        lib.notify({ type = 'error', description = 'Station unavailable.' })
        return
    end

    if data.locked then
        lib.notify({ type = 'error', description = ('Requires Farming Level %d.'):format(data.requiredLevel) })
        return
    end

    if not data.recipes or #data.recipes == 0 then
        lib.notify({ type = 'inform', description = 'No recipes available.' })
        return
    end

    local options = {}
    for _, recipe in ipairs(data.recipes) do
        local statusText = recipe.hasEnough
            and ('Ready — %d/%d %s'):format(recipe.currentCount, recipe.inputAmount, recipe.input)
            or ('Need %d/%d %s'):format(recipe.currentCount, recipe.inputAmount, recipe.input)

        options[#options + 1] = {
            title = recipe.label,
            description = ('%dx %s -> %dx %s | %s'):format(
                recipe.inputAmount, recipe.input, recipe.outputAmount, recipe.output, statusText
            ),
            icon = recipe.hasEnough and 'fa-solid fa-check' or 'fa-solid fa-lock',
            disabled = not recipe.hasEnough,
            onSelect = function()
                StartProcessing(stationId, recipe)
            end,
        }
    end

    lib.registerContext({
        id = 'ff_processing_menu',
        title = data.stationLabel,
        options = options,
    })
    lib.showContext('ff_processing_menu')
end

-- =============================================================================
-- PROCESSING PROGRESS BAR
-- =============================================================================

function StartProcessing(stationId, recipe)
    local completed = lib.progressBar({
        duration = recipe.processingTime,
        label = ('Processing %s...'):format(recipe.label),
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
        },
        anim = {
            dict = 'amb@world_human_gardener_plant@male@base',
            name = 'base',
        },
    })

    if not completed then
        lib.notify({ type = 'inform', description = 'Processing cancelled.' })
        return
    end

    -- Server processes the actual item exchange
    local result = lib.callback.await('free-farmer:server:processItem', false, stationId, recipe.id)

    if result and result.success then
        lib.notify({
            type = 'success',
            description = ('Produced %dx %s'):format(result.outputAmount, result.outputItem),
        })
    elseif result then
        lib.notify({ type = 'error', description = result.message })
    end
end

-- =============================================================================
-- INITIALIZATION
-- =============================================================================

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do
        Wait(500)
    end

    CreateProcessingBlips()
    RegisterProcessingStations()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    RemoveProcessingBlips()
    RemoveProcessingStations()
end)
