--[[
    free-farmer — Client XP & Stats
    Handles XP gain notifications, level-up events, /farmstats command
]]

local Utils = _G.FarmClientUtils

-- =============================================================================
-- XP GAIN NOTIFICATION
-- =============================================================================

RegisterNetEvent('free-farmer:client:xpGained', function(amount)
    lib.notify({
        title = 'Farming',
        description = ('+%d Farming XP'):format(amount),
        type = 'success',
        duration = 2000,
    })
end)

-- =============================================================================
-- LEVEL UP NOTIFICATION
-- =============================================================================

RegisterNetEvent('free-farmer:client:levelUp', function(newLevel, unlocks)
    -- Main level-up notification
    lib.notify({
        title = 'Level Up!',
        description = ('Farming Level %d'):format(newLevel),
        type = 'success',
        duration = 5000,
    })

    -- Show unlocks if any
    if unlocks and #unlocks > 0 then
        Wait(1000) -- Slight delay so notifications don't stack

        lib.notify({
            title = 'New Unlocks',
            description = table.concat(unlocks, ', '),
            type = 'inform',
            duration = 5000,
        })
    end
end)

-- =============================================================================
-- FARM STATS COMMAND
-- =============================================================================

RegisterCommand('farmstats', function()
    local stats = lib.callback.await('free-farmer:server:getPlayerFarmStats', false)

    if not stats then
        lib.notify({ title = 'Farming', description = 'No farming data found.', type = 'error' })
        return
    end

    local xpNeeded = Config.XP.xpPerLevel(stats.level)
    local yieldMod = Config.XP.yieldMultiplier(stats.level)

    local lines = {
        ('**Level:** %d / %d'):format(stats.level, Config.XP.maxLevel),
        ('**XP:** %d / %d'):format(stats.xp, xpNeeded),
        ('**Yield Bonus:** +%d%%'):format(math.floor((yieldMod - 1.0) * 100)),
        '',
        ('**Crops Planted:** %d'):format(stats.total_crops_planted),
        ('**Crops Harvested:** %d'):format(stats.total_crops_harvested),
        ('**Animals Cared For:** %d'):format(stats.total_animals_cared_for),
        ('**Products Collected:** %d'):format(stats.total_production_collected),
        ('**Challenges Completed:** %d'):format(stats.total_challenges_completed),
    }

    lib.alertDialog({
        header = 'Farming Stats',
        content = table.concat(lines, '  \n'),
        centered = true,
        cancel = false,
    })
end, false)
