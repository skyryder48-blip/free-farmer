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
-- COMMANDS: /challenges, /farmleaderboard, /farmstatsme
-- =============================================================================

--- /challenges — View active farming challenges
RegisterCommand('challenges', function()
    local challenges = lib.callback.await('free-farmer:server:getChallenges', false)

    if not challenges or #challenges == 0 then
        lib.notify({ type = 'inform', description = 'No active challenges.' })
        return
    end

    local Utils = _G.FarmClientUtils

    local options = {}
    for _, c in ipairs(challenges) do
        local progressText
        if c.completed then
            progressText = 'COMPLETED'
        else
            progressText = ('%d / %d'):format(c.current, c.target)
        end

        local timeText = ''
        if not c.completed and c.timeRemaining > 0 then
            timeText = ' | Expires: ' .. Utils.FormatTime(c.timeRemaining)
        end

        local icon = c.completed and 'fa-solid fa-check-circle' or 'fa-solid fa-crosshairs'
        local difficultyColors = { easy = '#33CC33', medium = '#CCCC33', hard = '#CC3333' }

        options[#options + 1] = {
            title = c.label,
            description = ('%s | %s | +%d XP%s'):format(c.description, progressText, c.xpReward, timeText),
            icon = icon,
            iconColor = c.completed and '#33CC33' or (difficultyColors[c.difficulty] or '#FFFFFF'),
        }
    end

    lib.registerContext({
        id = 'ff_challenges',
        title = 'Farming Challenges',
        options = options,
    })
    lib.showContext('ff_challenges')
end)

--- /farmleaderboard [total|weekly|monthly] — View farming leaderboard
RegisterCommand('farmleaderboard', function(_, args)
    local period = args[1] or 'total'
    if period ~= 'total' and period ~= 'weekly' and period ~= 'monthly' then
        period = 'total'
    end

    local leaderboard = lib.callback.await('free-farmer:server:getLeaderboard', false, period)

    if not leaderboard or #leaderboard == 0 then
        lib.notify({ type = 'inform', description = 'Leaderboard is empty.' })
        return
    end

    local periodLabels = { total = 'All Time', weekly = 'This Week', monthly = 'This Month' }

    local options = {}
    for _, entry in ipairs(leaderboard) do
        options[#options + 1] = {
            title = ('#%d %s'):format(entry.rank, entry.name),
            description = ('Score: %d'):format(entry.score),
            icon = entry.rank <= 3 and 'fa-solid fa-trophy' or 'fa-solid fa-user',
            iconColor = entry.rank == 1 and '#FFD700' or (entry.rank == 2 and '#C0C0C0' or (entry.rank == 3 and '#CD7F32' or '#FFFFFF')),
        }
    end

    lib.registerContext({
        id = 'ff_leaderboard',
        title = 'Farm Leaderboard — ' .. periodLabels[period],
        options = options,
    })
    lib.showContext('ff_leaderboard')
end)

--- /farmstatsme — View your own farming stats
RegisterCommand('farmstatsme', function()
    local data = lib.callback.await('free-farmer:server:getPlayerFarmStats', false)

    if not data then
        lib.notify({ type = 'inform', description = 'No farming data yet. Start farming!' })
        return
    end

    local lines = {
        ('**Level:** %d'):format(data.level),
        ('**XP:** %d'):format(data.xp),
        ('**Crops Planted:** %d'):format(data.total_crops_planted),
        ('**Crops Harvested:** %d'):format(data.total_crops_harvested),
        ('**Production Collected:** %d'):format(data.total_production_collected),
        ('**Challenges Completed:** %d'):format(data.total_challenges_completed),
    }

    lib.alertDialog({
        header = 'My Farm Stats',
        content = table.concat(lines, '  \n'),
        centered = true,
        cancel = false,
    })
end)

-- =============================================================================
-- EXPORTS FOR OTHER CLIENT FILES
-- =============================================================================

--- Get the current farm zone the player is in
---@return string|nil
function GetCurrentFarmZone()
    return currentFarmZone
end
