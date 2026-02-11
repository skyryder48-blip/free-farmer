--[[
    free-farmer — Server Utilities
    UUID generation, config lookups, polygon math, logging helpers.
    Loaded first in server_scripts — all other server files depend on this.
]]

local Utils = {}

local RESOURCE_NAME = GetCurrentResourceName()

-- =============================================================================
-- LOGGING
-- =============================================================================

function Utils.Log(fmt, ...)
    print(('[^2%s^7] %s'):format(RESOURCE_NAME, fmt:format(...)))
end

function Utils.Error(fmt, ...)
    print(('[^1%s ERROR^7] %s'):format(RESOURCE_NAME, fmt:format(...)))
end

function Utils.Debug(fmt, ...)
    if Config.Debug then
        print(('[^3%s DEBUG^7] %s'):format(RESOURCE_NAME, fmt:format(...)))
    end
end

-- =============================================================================
-- PLAYER HELPERS
-- =============================================================================

---@param src number Player server ID
---@return string|nil citizenid
function Utils.GetCitizenId(src)
    local player = exports.qbx_core:GetPlayer(src)
    if player then
        return player.PlayerData.citizenid
    end
    return nil
end

---@param src number Player server ID
---@return string|nil name
function Utils.GetPlayerName(src)
    local player = exports.qbx_core:GetPlayer(src)
    if player then
        return ('%s %s'):format(
            player.PlayerData.charinfo.firstname,
            player.PlayerData.charinfo.lastname
        )
    end
    return nil
end

---@param citizenid string
---@return number|nil src
function Utils.GetPlayerByCitizenId(citizenid)
    local players = exports.qbx_core:GetQBPlayers()
    for src, player in pairs(players) do
        if player.PlayerData.citizenid == citizenid then
            return src
        end
    end
    return nil
end

-- =============================================================================
-- CONFIG LOOKUPS
-- =============================================================================

---@param farmZoneId string
---@return table|nil zone
function Utils.GetFarmZoneById(farmZoneId)
    for _, zone in ipairs(Config.FarmZones) do
        if zone.id == farmZoneId then
            return zone
        end
    end
    return nil
end

---@param fieldId string
---@return table|nil fieldConfig, table|nil zoneConfig
function Utils.GetFieldConfig(fieldId)
    for _, zone in ipairs(Config.FarmZones) do
        for _, field in ipairs(zone.fields) do
            if field.id == fieldId then
                return field, zone
            end
        end
    end
    return nil
end

---@param penId string
---@return table|nil penConfig, table|nil zoneConfig
function Utils.GetPenConfig(penId)
    for _, zone in ipairs(Config.FarmZones) do
        if zone.pens then
            for _, pen in ipairs(zone.pens) do
                if pen.id == penId then
                    return pen, zone
                end
            end
        end
    end
    return nil
end

---@param farmZoneId string
---@param animalType string
---@return table|nil penConfig
function Utils.GetPenByAnimalType(farmZoneId, animalType)
    local zone = Utils.GetFarmZoneById(farmZoneId)
    if not zone or not zone.pens then return nil end

    for _, pen in ipairs(zone.pens) do
        if pen.animalType == animalType then
            return pen
        end
    end
    return nil
end

-- =============================================================================
-- UUID GENERATION
-- =============================================================================

---@return string uuid
function Utils.GenerateUUID()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

-- =============================================================================
-- POLYGON MATH
-- =============================================================================

---@param polygon table Array of vec3 vertices
---@return vec3 center
function Utils.GetPolygonCenter(polygon)
    local sumX, sumY, sumZ = 0.0, 0.0, 0.0
    local count = #polygon

    for _, point in ipairs(polygon) do
        sumX = sumX + point.x
        sumY = sumY + point.y
        sumZ = sumZ + point.z
    end

    return vec3(sumX / count, sumY / count, sumZ / count)
end

---@param point vec3
---@param polygon table Array of vec3 vertices
---@return boolean
function Utils.IsPointInPolygon(point, polygon)
    local inside = false
    local n = #polygon
    local j = n

    for i = 1, n do
        local pi = polygon[i]
        local pj = polygon[j]

        if (pi.y > point.y) ~= (pj.y > point.y) then
            local intersectX = (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x
            if point.x < intersectX then
                inside = not inside
            end
        end

        j = i
    end

    return inside
end

---@param polygon table Array of vec3 vertices
---@return vec3
function Utils.GetRandomPointInPolygon(polygon)
    local center = Utils.GetPolygonCenter(polygon)

    -- Calculate bounding box
    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    local avgZ = center.z

    for _, p in ipairs(polygon) do
        if p.x < minX then minX = p.x end
        if p.x > maxX then maxX = p.x end
        if p.y < minY then minY = p.y end
        if p.y > maxY then maxY = p.y end
    end

    -- Try random points within bounding box until one is inside
    for _ = 1, 50 do
        local testPoint = vec3(
            math.random() * (maxX - minX) + minX,
            math.random() * (maxY - minY) + minY,
            avgZ
        )

        if Utils.IsPointInPolygon(testPoint, polygon) then
            return testPoint
        end
    end

    -- Fallback to center
    return center
end

-- =============================================================================
-- EXPORTS
-- =============================================================================

-- Expose under both names for compatibility with existing code
_G.FarmUtils = Utils
_G.FarmServerUtils = Utils

return Utils
