--[[
    free-farmer — Server Weather Integration
    Wraps renewed-weathersync exports for weather polling.
    No event hooking — we read weather state on demand during growth ticks.
]]

local Utils = _G.FarmUtils

---@return string weatherKey Config-compatible weather key (e.g., 'clear', 'rain')
function GetCurrentWeather()
    local ok, rawWeather = pcall(function()
        return exports['Renewed-Weathersync']:getWeather()
    end)

    if not ok or not rawWeather then
        Utils.Debug('[Weather] Failed to get weather from Renewed-Weathersync, defaulting to clear')
        return 'clear'
    end

    -- Map raw weather string to our config keys
    local mapped = Config.WeatherMap[rawWeather:upper()]
    if not mapped then
        Utils.Debug('[Weather] Unknown weather type: %s, defaulting to clear', tostring(rawWeather))
        return 'clear'
    end

    return mapped
end

-- Expose as global for other server files
_G.GetCurrentWeather = GetCurrentWeather
