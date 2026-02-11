--[[
    free-farmer — Client Main
    Zone management (lib.zones.sphere), map blips, entity state bag handling.
    0.00ms when player is outside all farm zones.
]]

local currentFarmZone = nil
local farmZoneBlips = {}
local registeredZones = {}
local fieldTargets = {}

-- =============================================================================
-- MAP BLIPS
-- =============================================================================

local function CreateFarmBlips()
    for _, zone in ipairs(Config.FarmZones) do
        local blip = AddBlipForCoord(zone.blip.coords.x, zone.blip.coords.y, zone.blip.coords.z)
        SetBlipSprite(blip, zone.blip.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, zone.blip.scale)
        SetBlipColour(blip, zone.blip.color)
        SetBlipAsShortRange(blip, zone.blip.shortRange)

        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(zone.label)
        EndTextCommandSetBlipName(blip)

        farmZoneBlips[#farmZoneBlips + 1] = blip
    end
end

local function RemoveFarmBlips()
    for _, blip in ipairs(farmZoneBlips) do
        RemoveBlip(blip)
    end
    farmZoneBlips = {}
end

-- =============================================================================
-- ZONE MANAGEMENT
-- =============================================================================

--- Called when player enters a farm zone
---@param zone table The farm zone config
local function OnEnterFarmZone(zone)
    if currentFarmZone == zone.id then return end

    currentFarmZone = zone.id
    TriggerServerEvent('free-farmer:server:playerEnteredZone', zone.id)

    -- Register ox_target interactions for fields in this zone
    RegisterFieldTargets(zone)

    -- Register animal zone targets (troughs, barn) if loaded
    if RegisterAnimalZoneTargets then
        RegisterAnimalZoneTargets(zone)
    end

    if Config.Debug then
        lib.notify({
            title = 'Farm Zone',
            description = 'Entered ' .. zone.label,
            type = 'inform',
            duration = 3000,
        })
    end
end

--- Called when player exits a farm zone
---@param zone table The farm zone config
local function OnExitFarmZone(zone)
    if currentFarmZone ~= zone.id then return end

    TriggerServerEvent('free-farmer:server:playerLeftZone', zone.id)

    -- Remove ox_target interactions
    UnregisterFieldTargets(zone)

    -- Unregister animal zone targets if loaded
    if UnregisterAnimalZoneTargets then
        UnregisterAnimalZoneTargets(zone)
    end

    currentFarmZone = nil

    if Config.Debug then
        lib.notify({
            title = 'Farm Zone',
            description = 'Left ' .. zone.label,
            type = 'inform',
            duration = 3000,
        })
    end
end

--- Create zone detection spheres for all farm zones
local function CreateFarmZones()
    for _, zone in ipairs(Config.FarmZones) do
        local zoneObj = lib.zones.sphere({
            coords = zone.blip.coords,
            radius = zone.zoneRadius,
            debug = Config.Debug,

            onEnter = function()
                OnEnterFarmZone(zone)
            end,

            onExit = function()
                OnExitFarmZone(zone)
            end,
        })

        registeredZones[#registeredZones + 1] = zoneObj
    end
end

-- =============================================================================
-- ENTITY STATE BAG HANDLERS
-- Applies client-side visual properties to server-spawned entities
-- =============================================================================

-- Field crop props: freeze, disable collision (decorative only, not targetable)
AddStateBagChangeHandler('freefarmer_prop', nil, function(bagName, _, value)
    if not value then return end

    local netId = tonumber(bagName:gsub('entity:', ''), 10)
    if not netId then return end

    local timeout = 0
    while not NetworkDoesEntityExistWithNetworkId(netId) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end

    if not NetworkDoesEntityExistWithNetworkId(netId) then return end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 then return end

    FreezeEntityPosition(entity, true)
    SetEntityCollisionEnabled(entity, false, false)
    SetEntityInvincible(entity, true)
end)

-- Garden planters: freeze + invincible, but KEEP collision for ox_target interaction
AddStateBagChangeHandler('isFarmPlanter', nil, function(bagName, _, value)
    if not value then return end

    local netId = tonumber(bagName:gsub('entity:', ''), 10)
    if not netId then return end

    local timeout = 0
    while not NetworkDoesEntityExistWithNetworkId(netId) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end

    if not NetworkDoesEntityExistWithNetworkId(netId) then return end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 then return end

    FreezeEntityPosition(entity, true)
    SetEntityInvincible(entity, true)
    -- NOTE: collision stays ENABLED so ox_target can detect the prop
end)

-- =============================================================================
-- INITIALIZATION
-- =============================================================================

CreateThread(function()
    -- Wait for player to be loaded
    while not LocalPlayer.state.isLoggedIn do
        Wait(500)
    end

    CreateFarmBlips()
    CreateFarmZones()
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    RemoveFarmBlips()
end)

-- =============================================================================
-- EXPORTS FOR OTHER CLIENT FILES
-- =============================================================================

--- Get the current farm zone the player is in
---@return string|nil
function GetCurrentFarmZone()
    return currentFarmZone
end
