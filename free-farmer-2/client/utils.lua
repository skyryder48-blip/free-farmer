--[[
    free-farmer — Client Utilities
]]

local Utils = {}

--- Format seconds into human-readable time string
---@param seconds number
---@return string
function Utils.FormatTime(seconds)
    if seconds <= 0 then return 'Ready' end

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    if hours > 0 then
        return ('%dh %dm'):format(hours, minutes)
    elseif minutes > 0 then
        return ('%dm %ds'):format(minutes, secs)
    else
        return ('%ds'):format(secs)
    end
end

--- Capitalize first letter
---@param str string
---@return string
function Utils.Capitalize(str)
    if not str or #str == 0 then return '' end
    return str:sub(1, 1):upper() .. str:sub(2)
end

--- Quality color map for notifications
---@param quality string
---@return string hex color
function Utils.QualityColor(quality)
    local colors = {
        poor = '#CC3333',
        average = '#CCCC33',
        good = '#33CC33',
        excellent = '#33CCFF',
    }
    return colors[quality] or '#FFFFFF'
end

_G.FarmClientUtils = Utils

return Utils
