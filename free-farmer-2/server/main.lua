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
