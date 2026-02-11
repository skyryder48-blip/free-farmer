--[[
    free-farmer — Server Main
    Resource initialization, database bootstrapping, player management
]]

local Utils = _G.FarmUtils

--- Seed field rows into the database for all configured farm zones
local function SeedFieldRows()
    for _, zone in ipairs(Config.FarmZones) do
        for _, field in ipairs(zone.fields) do
            local exists = MySQL.scalar.await(
                'SELECT COUNT(*) FROM farm_fields WHERE field_id = ?',
                { field.id }
            )

            if exists == 0 then
                MySQL.insert.await([[
                    INSERT INTO farm_fields (field_id, farm_zone, status)
                    VALUES (?, ?, 'raw')
                ]], { field.id, zone.id })

                Utils.Log('Seeded field: %s (%s)', field.id, zone.label)
            end
        end
    end
end

--- Verify all required database tables exist
local function VerifyDatabase()
    local tables = {
        'farm_fields',
        'farm_planters',
        'farm_animals',
        'farm_player_data',
        'farm_challenges',
        'farm_leaderboard',
        'farm_pen_breeding',
        'farm_ownership',
    }

    for _, tableName in ipairs(tables) do
        local result = MySQL.scalar.await(
            "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?",
            { tableName }
        )

        if result == 0 then
            Utils.Error('Missing database table: %s — Run sql/install.sql first!', tableName)
            return false
        end
    end

    Utils.Log('All database tables verified.')
    return true
end

-- =============================================================================
-- RESOURCE START
-- =============================================================================

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    Utils.Log('Starting free-farmer v1.0.0...')

    -- Verify DB
    if not VerifyDatabase() then
        Utils.Error('Database verification failed. Resource may not function correctly.')
        return
    end

    -- Seed field data
    SeedFieldRows()

    Utils.Log('free-farmer loaded successfully. %d farm zones configured.', #Config.FarmZones)
end)

-- =============================================================================
-- PLAYER MANAGEMENT
-- =============================================================================

--- Ensure player has a farming data row when they first interact with farming
---@param src number
---@return table|nil playerData
function EnsurePlayerFarmData(src)
    local citizenid = Utils.GetCitizenId(src)
    if not citizenid then return nil end

    local data = MySQL.single.await(
        'SELECT * FROM farm_player_data WHERE identifier = ?',
        { citizenid }
    )

    if not data then
        local name = Utils.GetPlayerName(src) or 'Unknown'
        MySQL.insert.await([[
            INSERT INTO farm_player_data (identifier, character_name, xp, level)
            VALUES (?, ?, 0, 1)
        ]], { citizenid, name })

        data = MySQL.single.await(
            'SELECT * FROM farm_player_data WHERE identifier = ?',
            { citizenid }
        )

        Utils.Debug('Created farming data for %s (%s)', name, citizenid)
    end

    return data
end

-- Export for other server files
_G.EnsurePlayerFarmData = EnsurePlayerFarmData

-- =============================================================================
-- ADMIN COMMANDS (Phase 5D — ACE permission protected)
-- =============================================================================

--- /farmassign [farmId] [playerId] — Assign a farm zone to a player
RegisterCommand('farmassign', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, 'command.farmassign') then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No permission.' })
        return
    end

    if #args < 2 then
        local msg = 'Usage: /farmassign [farmId] [playerId]'
        if src == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', src, { type = 'inform', description = msg }) end
        return
    end

    local farmId = args[1]
    local targetSrc = tonumber(args[2])

    local zone = Utils.GetFarmZoneById(farmId)
    if not zone then
        local msg = 'Invalid farm zone: ' .. farmId
        if src == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = msg }) end
        return
    end

    if not targetSrc then
        local msg = 'Invalid player ID.'
        if src == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = msg }) end
        return
    end

    local citizenid = Utils.GetCitizenId(targetSrc)
    if not citizenid then
        local msg = 'Player not found or not loaded.'
        if src == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = msg }) end
        return
    end

    local now = os.time()
    MySQL.execute.await([[
        INSERT INTO farm_ownership (farm_zone, owner_identifier, assigned_at)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE owner_identifier = VALUES(owner_identifier), assigned_at = VALUES(assigned_at)
    ]], { farmId, citizenid, now })

    local name = Utils.GetPlayerName(targetSrc) or citizenid
    local msg = ('Assigned %s to %s (%s)'):format(zone.label, name, citizenid)
    Utils.Log('[Admin] ' .. msg)
    if src == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = msg }) end
end, true) -- restricted = true (ACE permission)

--- /farmunassign [farmId] — Remove farm assignment
RegisterCommand('farmunassign', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, 'command.farmunassign') then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No permission.' })
        return
    end

    if #args < 1 then
        local msg = 'Usage: /farmunassign [farmId]'
        if src == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', src, { type = 'inform', description = msg }) end
        return
    end

    local farmId = args[1]
    local zone = Utils.GetFarmZoneById(farmId)
    if not zone then
        local msg = 'Invalid farm zone: ' .. farmId
        if src == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = msg }) end
        return
    end

    MySQL.execute.await('DELETE FROM farm_ownership WHERE farm_zone = ?', { farmId })

    local msg = ('Unassigned %s — now open access.'):format(zone.label)
    Utils.Log('[Admin] ' .. msg)
    if src == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = msg }) end
end, true)

--- /farmreset [farmId] — Reset all fields and clear animals for a farm zone
RegisterCommand('farmreset', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, 'command.farmreset') then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No permission.' })
        return
    end

    if #args < 1 then
        local msg = 'Usage: /farmreset [farmId]'
        if src == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', src, { type = 'inform', description = msg }) end
        return
    end

    local farmId = args[1]
    local zone = Utils.GetFarmZoneById(farmId)
    if not zone then
        local msg = 'Invalid farm zone: ' .. farmId
        if src == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = msg }) end
        return
    end

    -- Reset fields to raw
    MySQL.execute.await([[
        UPDATE farm_fields SET
            status = 'raw', crop_type = NULL, growth_stage = 0,
            planted_at = NULL, stage_updated_at = NULL,
            good_weather_ticks = 0, bad_weather_ticks = 0,
            weather_quality_modifier = 1.0
        WHERE farm_zone = ?
    ]], { farmId })

    -- Remove all animals in this zone
    MySQL.execute.await('DELETE FROM farm_animals WHERE farm_zone = ?', { farmId })

    -- Reset breeding state for pens in this zone
    if zone.pens then
        for _, pen in ipairs(zone.pens) do
            MySQL.execute.await('DELETE FROM farm_pen_breeding WHERE pen_id = ?', { pen.id })
        end
    end

    local msg = ('Reset farm %s — fields cleared, animals removed.'):format(zone.label)
    Utils.Log('[Admin] ' .. msg)
    if src == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = msg }) end
end, true)

--- /farmstats [playerId] — View any player's farming data
RegisterCommand('farmstats', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, 'command.farmstats') then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'No permission.' })
        return
    end

    if #args < 1 then
        local msg = 'Usage: /farmstats [playerId]'
        if src == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', src, { type = 'inform', description = msg }) end
        return
    end

    local targetSrc = tonumber(args[1])
    if not targetSrc then
        local msg = 'Invalid player ID.'
        if src == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = msg }) end
        return
    end

    local citizenid = Utils.GetCitizenId(targetSrc)
    if not citizenid then
        local msg = 'Player not found or not loaded.'
        if src == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = msg }) end
        return
    end

    local data = MySQL.single.await('SELECT * FROM farm_player_data WHERE identifier = ?', { citizenid })
    if not data then
        local msg = 'No farming data for this player.'
        if src == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', src, { type = 'inform', description = msg }) end
        return
    end

    -- Count animals
    local animalCount = MySQL.scalar.await('SELECT COUNT(*) FROM farm_animals WHERE owner_identifier = ?', { citizenid }) or 0

    local lines = {
        ('--- Farm Stats: %s (%s) ---'):format(data.character_name or 'Unknown', citizenid),
        ('Level: %d | XP: %d'):format(data.level, data.xp),
        ('Crops Planted: %d | Harvested: %d'):format(data.total_crops_planted, data.total_crops_harvested),
        ('Animals Owned: %d | Production Collected: %d'):format(animalCount, data.total_production_collected),
        ('Challenges Completed: %d'):format(data.total_challenges_completed),
    }

    for _, line in ipairs(lines) do
        if src == 0 then
            print(line)
        else
            TriggerClientEvent('chat:addMessage', src, { args = { 'Farm Stats', line } })
        end
    end
end, true)
