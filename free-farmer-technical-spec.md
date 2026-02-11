# free-farmer — Technical Specification Document v1.0

**Project:** free-farmer  
**Framework:** QBX (Qbox) with ox_lib, oxmysql, ox_inventory, ox_target  
**Server Style:** Hardcore Ultrarealistic Roleplay  
**Regional Theme:** Michigan & Wisconsin Agriculture  
**Target Performance:** 150-200 concurrent players, 25 concurrent farmers  
**Last Updated:** 2025-02-11

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Crop System - Field-Based Implementation](#2-crop-system---field-based-implementation)
3. [Livestock System - Physical Ped Implementation](#3-livestock-system---physical-ped-implementation)
4. [Breeding System](#4-breeding-system)
5. [XP & Progression System](#5-xp--progression-system)
6. [Challenge System](#6-challenge-system)
7. [Leaderboard System](#7-leaderboard-system)
8. [Processing Chains](#8-processing-chains)
9. [Performance Optimization Strategy](#9-performance-optimization-strategy)
10. [Database Schema](#10-database-schema)
11. [File Structure](#11-file-structure)
12. [Phase Development Plan](#12-phase-development-plan)

---

## 1. Architecture Overview

### 1.1 Core Design Principles

**Field-Based Crop Farming:**
- Crops represented by field zones (polygons), not individual plants
- 8-10 sample props per field for visual representation
- Server-side growth calculations on timed intervals
- Zero client-side performance impact when idle

**Physical Livestock System:**
- Individual animals as spawned ped entities
- Full species-based AI behaviors
- Storage system to protect animals when players offline
- Breeding mechanics for long-term farm development

**Zero Economy Integration:**
- No market systems, pricing, or sales logic
- Pure production mechanics only
- Integration points for external economy systems

**Challenge-Driven Progression:**
- Contract system for farming objectives
- Leaderboard tracking for competition
- XP-based skill progression

### 1.2 Performance Targets

```
Client Performance:
├── 0.00ms idle (no farm activity)
├── <0.08ms active farming (within farm zone)
└── <0.10ms with maximum entity load (100-150 entities)

Server Performance:
├── <0.03ms per active farmer
├── <0.10ms per growth tick (all fields)
└── <0.15ms per animal health tick (all animals)

Network:
├── Minimal events (use state bags for sync)
├── Batched database operations
└── Zone-based entity streaming
```

### 1.3 Farm Zone Structure

The server contains **6 farm locations**, each with:
- 3-6 field polygons for crop farming
- 4-8 animal pens for livestock
- Equipment shed (tractor/implement interactions)
- Storage barn (crop storage)
- Animal barn (livestock storage system)
- Processing stations (optional, per farm configuration)

---

## 2. Crop System - Field-Based Implementation

### 2.1 Crop Roster

**Row Crops (Large Field):**
- Corn (field corn for silage/grain)
- Soybeans
- Wheat/Hay (combined crop type)
- Potatoes

**Specialty Crops (Medium Field):**
- Pumpkins
- Cranberries (water-harvest mechanics)
- Sugar Beets

**Orchard/Bush Crops (Small Field):**
- Cherries (Michigan specialty)
- Apples
- Blueberries

### 2.2 Field Configuration Structure

```lua
Config.FarmZones = {
    {
        id = "farm_01_maple_valley",
        label = "Maple Valley Farm",
        blip = {
            coords = vec3(2447.5, 4955.7, 45.9),
            sprite = 480,
            color = 2,
            scale = 0.8,
            shortRange = true
        },
        zoneRadius = 200.0, -- Streaming distance for entities
        
        fields = {
            {
                id = "farm_01_field_a",
                label = "North Field",
                polygon = {
                    vec3(2400.0, 4900.0, 45.0),
                    vec3(2500.0, 4900.0, 45.0),
                    vec3(2500.0, 5000.0, 45.0),
                    vec3(2400.0, 5000.0, 45.0),
                },
                size = 10000.0, -- square meters (100m x 100m)
                fieldType = "large", -- large, medium, small
                
                -- Pre-calculated sample prop positions (8-10 per field)
                propSpawnPoints = {
                    vec3(2420.0, 4920.0, 45.2),
                    vec3(2440.0, 4920.0, 45.3),
                    vec3(2460.0, 4920.0, 45.1),
                    vec3(2480.0, 4920.0, 45.2),
                    vec3(2420.0, 4960.0, 45.4),
                    vec3(2440.0, 4960.0, 45.2),
                    vec3(2460.0, 4960.0, 45.3),
                    vec3(2480.0, 4960.0, 45.1),
                },
                
                -- Where player interacts to manage field
                interactionPoint = vec3(2410.0, 4950.0, 45.5),
            },
            -- ... 2-5 more fields per farm
        },
        
        equipment_shed = vec3(2455.0, 4945.0, 45.8),
        storage_barn = vec3(2460.0, 4950.0, 46.2),
        animal_barn = vec3(2465.0, 4955.0, 46.0),
        
        pens = {
            {
                id = "farm_01_pen_cow_a",
                label = "Cow Pen A",
                animalType = "cow",
                polygon = {
                    vec3(2470.0, 4960.0, 45.5),
                    vec3(2490.0, 4960.0, 45.5),
                    vec3(2490.0, 4980.0, 45.5),
                    vec3(2470.0, 4980.0, 45.5),
                },
                wanderRadius = 15.0,
                feedTrough = vec3(2472.0, 4962.0, 45.5),
                waterTrough = vec3(2488.0, 4978.0, 45.5),
            },
            -- ... more pens (chicken coop, pig pen, etc.)
        },
    },
    -- ... 5 more farm zones
}
```

### 2.3 Crop Configuration

```lua
Config.Crops = {
    corn = {
        label = "Corn",
        seedItem = "corn_seed",
        harvestItem = "corn",
        unlockLevel = 1,
        fieldTypes = {"large"}, -- Which field sizes can grow this crop
        
        growthStages = {
            {
                stage = 1,
                label = "Planted",
                duration = 3600, -- seconds (1 hour, configurable)
                prop = "prop_veg_crop_03_leaf",
                groundTexture = "brown_soil", -- Optional texture overlay
            },
            {
                stage = 2,
                label = "Sprouting",
                duration = 5400, -- 1.5 hours
                prop = "prop_veg_crop_03_pump",
                groundTexture = "light_green",
            },
            {
                stage = 3,
                label = "Growing",
                duration = 7200, -- 2 hours
                prop = "prop_veg_crop_04_leaf",
                groundTexture = "medium_green",
            },
            {
                stage = 4,
                label = "Mature",
                duration = 5400, -- 1.5 hours
                prop = "prop_veg_crop_05",
                groundTexture = "rich_green",
            },
            {
                stage = 5,
                label = "Harvestable",
                duration = nil, -- Indefinite until harvested
                prop = "prop_veg_crop_06",
                groundTexture = "golden",
            },
        },
        
        -- Yield calculations (per 100 sq meters)
        baseYield = {min = 80, max = 120},
        
        -- Soil quality impact
        soilDegradation = 8, -- How much soil quality decreases after harvest
        cropFamily = "grain", -- For rotation bonuses (grain, legume, vegetable, fruit)
        
        -- Weather preferences (multipliers)
        weatherPreferences = {
            rain = 1.1,     -- 10% bonus
            clear = 1.0,    -- Neutral
            overcast = 0.98,
            fog = 0.95,
            thunder = 0.85, -- 15% penalty
            snow = 0.7,     -- 30% penalty (shouldn't be planted in winter)
        },
        
        -- Quality thresholds (based on soil + weather + XP)
        qualityThresholds = {
            poor = 0.7,      -- <70% optimal conditions
            average = 0.85,  -- 70-85%
            good = 0.95,     -- 85-95%
            excellent = 1.0, -- >95%
        },
    },
    
    soybeans = {
        label = "Soybeans",
        seedItem = "soybean_seed",
        harvestItem = "soybeans",
        unlockLevel = 1,
        fieldTypes = {"large"},
        growthStages = {
            -- Similar structure to corn
        },
        baseYield = {min = 60, max = 90},
        soilDegradation = 3, -- Legumes improve soil (nitrogen fixing)
        cropFamily = "legume",
        weatherPreferences = {
            rain = 1.15,
            clear = 1.0,
            overcast = 1.0,
            fog = 0.95,
            thunder = 0.8,
            snow = 0.6,
        },
        qualityThresholds = {
            poor = 0.7,
            average = 0.85,
            good = 0.95,
            excellent = 1.0,
        },
    },
    
    wheat = {
        label = "Wheat",
        seedItem = "wheat_seed",
        harvestItem = "wheat",
        unlockLevel = 1,
        fieldTypes = {"large", "medium"},
        growthStages = {
            -- 5 stages similar to above
        },
        baseYield = {min = 70, max = 110},
        soilDegradation = 6,
        cropFamily = "grain",
        weatherPreferences = {
            rain = 1.08,
            clear = 1.02,
            overcast = 1.0,
            fog = 0.98,
            thunder = 0.88,
            snow = 0.75,
        },
        qualityThresholds = {
            poor = 0.7,
            average = 0.85,
            good = 0.95,
            excellent = 1.0,
        },
    },
    
    hay = {
        label = "Hay",
        seedItem = "hay_seed",
        harvestItem = "hay_bale",
        unlockLevel = 1,
        fieldTypes = {"large", "medium"},
        growthStages = {
            -- 4 stages (faster growing)
        },
        baseYield = {min = 50, max = 80}, -- Measured in bales
        soilDegradation = 4,
        cropFamily = "grain",
        weatherPreferences = {
            rain = 1.05,
            clear = 1.1, -- Prefers dry for harvesting
            overcast = 1.0,
            fog = 0.9,
            thunder = 0.75, -- Very bad for hay
            snow = 0.6,
        },
        qualityThresholds = {
            poor = 0.7,
            average = 0.85,
            good = 0.95,
            excellent = 1.0,
        },
    },
    
    potatoes = {
        label = "Potatoes",
        seedItem = "potato_seed",
        harvestItem = "potato",
        unlockLevel = 3,
        fieldTypes = {"large", "medium"},
        growthStages = {
            -- 5 stages
        },
        baseYield = {min = 100, max = 150},
        soilDegradation = 10, -- Heavy feeder
        cropFamily = "vegetable",
        weatherPreferences = {
            rain = 1.12,
            clear = 0.95,
            overcast = 1.05,
            fog = 1.0,
            thunder = 0.85,
            snow = 0.5,
        },
        qualityThresholds = {
            poor = 0.7,
            average = 0.85,
            good = 0.95,
            excellent = 1.0,
        },
    },
    
    pumpkins = {
        label = "Pumpkins",
        seedItem = "pumpkin_seed",
        harvestItem = "pumpkin",
        unlockLevel = 5,
        fieldTypes = {"medium"},
        growthStages = {
            -- 5 stages with larger pumpkin props
        },
        baseYield = {min = 30, max = 50}, -- Fewer but larger items
        soilDegradation = 9,
        cropFamily = "vegetable",
        weatherPreferences = {
            rain = 1.1,
            clear = 1.0,
            overcast = 1.02,
            fog = 0.95,
            thunder = 0.8,
            snow = 0.4,
        },
        qualityThresholds = {
            poor = 0.7,
            average = 0.85,
            good = 0.95,
            excellent = 1.0,
        },
    },
    
    cranberries = {
        label = "Cranberries",
        seedItem = "cranberry_plant",
        harvestItem = "cranberries",
        unlockLevel = 15,
        fieldTypes = {"small", "medium"},
        growthStages = {
            -- 4 stages (perennial, doesn't need replanting)
        },
        baseYield = {min = 50, max = 80},
        soilDegradation = 2, -- Perennial, minimal soil impact
        cropFamily = "fruit",
        harvestMethod = "water_flood", -- Special harvest mechanic
        weatherPreferences = {
            rain = 1.15,
            clear = 0.98,
            overcast = 1.05,
            fog = 1.08,
            thunder = 0.9,
            snow = 0.85, -- Can tolerate cold
        },
        qualityThresholds = {
            poor = 0.7,
            average = 0.85,
            good = 0.95,
            excellent = 1.0,
        },
    },
    
    cherries = {
        label = "Tart Cherries",
        seedItem = "cherry_tree",
        harvestItem = "cherries",
        unlockLevel = 20,
        fieldTypes = {"small"},
        growthStages = {
            -- 3 stages (tree-based, slower growth)
        },
        baseYield = {min = 40, max = 70},
        soilDegradation = 3, -- Perennial tree
        cropFamily = "fruit",
        harvestMethod = "tree_pick", -- Special harvest mechanic
        weatherPreferences = {
            rain = 1.05,
            clear = 1.1,
            overcast = 1.0,
            fog = 0.95,
            thunder = 0.75, -- Hail can damage
            snow = 0.9, -- Spring frost concern
        },
        qualityThresholds = {
            poor = 0.7,
            average = 0.85,
            good = 0.95,
            excellent = 1.0,
        },
    },
    
    sugarbeets = {
        label = "Sugar Beets",
        seedItem = "sugarbeet_seed",
        harvestItem = "sugar_beet",
        unlockLevel = 10,
        fieldTypes = {"large", "medium"},
        growthStages = {
            -- 5 stages
        },
        baseYield = {min = 90, max = 140},
        soilDegradation = 12, -- Very heavy feeder
        cropFamily = "vegetable",
        weatherPreferences = {
            rain = 1.08,
            clear = 1.0,
            overcast = 1.02,
            fog = 0.98,
            thunder = 0.88,
            snow = 0.7,
        },
        qualityThresholds = {
            poor = 0.7,
            average = 0.85,
            good = 0.95,
            excellent = 1.0,
        },
    },
    
    apples = {
        label = "Apples",
        seedItem = "apple_tree",
        harvestItem = "apple",
        unlockLevel = 18,
        fieldTypes = {"small", "medium"},
        growthStages = {
            -- 3 stages (tree-based)
        },
        baseYield = {min = 50, max = 85},
        soilDegradation = 3,
        cropFamily = "fruit",
        harvestMethod = "tree_pick",
        weatherPreferences = {
            rain = 1.05,
            clear = 1.08,
            overcast = 1.0,
            fog = 0.98,
            thunder = 0.8,
            snow = 0.92,
        },
        qualityThresholds = {
            poor = 0.7,
            average = 0.85,
            good = 0.95,
            excellent = 1.0,
        },
    },
    
    blueberries = {
        label = "Blueberries",
        seedItem = "blueberry_bush",
        harvestItem = "blueberries",
        unlockLevel = 12,
        fieldTypes = {"small"},
        growthStages = {
            -- 4 stages (bush-based)
        },
        baseYield = {min = 35, max = 60},
        soilDegradation = 2,
        cropFamily = "fruit",
        harvestMethod = "bush_pick",
        weatherPreferences = {
            rain = 1.12,
            clear = 1.0,
            overcast = 1.05,
            fog = 1.08,
            thunder = 0.85,
            snow = 0.88,
        },
        qualityThresholds = {
            poor = 0.7,
            average = 0.85,
            good = 0.95,
            excellent = 1.0,
        },
    },
}
```

### 2.4 Field State Management

**Database Table:**
```sql
CREATE TABLE IF NOT EXISTS `farm_fields` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `field_id` VARCHAR(50) NOT NULL UNIQUE,
    `farm_zone` VARCHAR(50) NOT NULL,
    
    -- Crop State
    `crop_type` VARCHAR(50) DEFAULT NULL,
    `growth_stage` INT DEFAULT 0,
    `planted_at` TIMESTAMP DEFAULT NULL,
    `stage_updated_at` TIMESTAMP DEFAULT NULL,
    
    -- Soil & Quality
    `soil_quality` INT DEFAULT 100,
    `last_harvest` TIMESTAMP DEFAULT NULL,
    `last_crop` VARCHAR(50) DEFAULT NULL,
    `last_crop_family` VARCHAR(50) DEFAULT NULL,
    `times_harvested` INT DEFAULT 0,
    `consecutive_same_crop` INT DEFAULT 0,
    
    -- Weather Impact
    `weather_quality_modifier` FLOAT DEFAULT 1.0,
    `good_weather_ticks` INT DEFAULT 0,
    `bad_weather_ticks` INT DEFAULT 0,
    
    -- Field Management
    `fertilized` BOOLEAN DEFAULT FALSE,
    `fertilizer_quality` VARCHAR(20) DEFAULT NULL,
    `last_fertilized` TIMESTAMP DEFAULT NULL,
    
    -- Metadata
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX(`field_id`),
    INDEX(`farm_zone`),
    INDEX(`crop_type`)
);
```

### 2.5 Visual Field Spawning System

**Server-Side (server/fields.lua):**
```lua
local activeFieldProps = {} -- {[fieldId] = {entityIds}}
local activeFieldZones = {} -- {[farmZoneId] = playerCount}

---@param fieldId string
---@return table|nil fieldState
function GetFieldState(fieldId)
    local result = MySQL.single.await('SELECT * FROM farm_fields WHERE field_id = ?', {fieldId})
    return result
end

---@param fieldId string
function SpawnFieldProps(fieldId)
    -- Prevent duplicate spawning
    if activeFieldProps[fieldId] then return end
    
    local fieldState = GetFieldState(fieldId)
    if not fieldState or not fieldState.crop_type or fieldState.growth_stage == 0 then
        return -- Empty/unplanted field
    end
    
    local fieldConfig = GetFieldConfig(fieldId)
    if not fieldConfig then return end
    
    local cropConfig = Config.Crops[fieldState.crop_type]
    if not cropConfig then return end
    
    local stageConfig = cropConfig.growthStages[fieldState.growth_stage]
    if not stageConfig then return end
    
    -- Spawn props at predetermined points
    local props = {}
    for i, spawnPoint in ipairs(fieldConfig.propSpawnPoints) do
        local propHash = GetHashKey(stageConfig.prop)
        RequestModel(propHash)
        while not HasModelLoaded(propHash) do Wait(10) end
        
        local prop = CreateObject(
            propHash,
            spawnPoint.x,
            spawnPoint.y,
            spawnPoint.z,
            true,  -- networked
            false, -- dynamic
            false  -- doorFlag
        )
        
        FreezeEntityPosition(prop, true)
        SetEntityAsMissionEntity(prop, true, true)
        SetEntityCollision(prop, false, false) -- Non-collidable decoration
        
        table.insert(props, prop)
        SetModelAsNoLongerNeeded(propHash)
    end
    
    activeFieldProps[fieldId] = props
    
    -- Set state bag for client awareness (optional visual enhancements)
    if #props > 0 then
        Entity(props[1]).state:set('fieldId', fieldId, true)
        Entity(props[1]).state:set('cropType', fieldState.crop_type, true)
        Entity(props[1]).state:set('growthStage', fieldState.growth_stage, true)
    end
end

---@param fieldId string
function DespawnFieldProps(fieldId)
    if not activeFieldProps[fieldId] then return end
    
    for _, prop in ipairs(activeFieldProps[fieldId]) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end
    
    activeFieldProps[fieldId] = nil
end

-- Farm zone tracking
RegisterNetEvent('free-farmer:playerEnteredFarmZone', function(farmZoneId)
    local src = source
    
    -- Increment player count
    activeFieldZones[farmZoneId] = (activeFieldZones[farmZoneId] or 0) + 1
    
    -- If first player, spawn all field props for this farm
    if activeFieldZones[farmZoneId] == 1 then
        local farmZone = GetFarmZoneById(farmZoneId)
        if farmZone then
            for _, field in ipairs(farmZone.fields) do
                SpawnFieldProps(field.id)
            end
        end
    end
end)

RegisterNetEvent('free-farmer:playerLeftFarmZone', function(farmZoneId)
    local src = source
    
    -- Decrement player count
    activeFieldZones[farmZoneId] = math.max(0, (activeFieldZones[farmZoneId] or 0) - 1)
    
    -- If no players remain, despawn all props
    if activeFieldZones[farmZoneId] == 0 then
        local farmZone = GetFarmZoneById(farmZoneId)
        if farmZone then
            for _, field in ipairs(farmZone.fields) do
                DespawnFieldProps(field.id)
            end
        end
    end
end)
```

**Client-Side (client/fields.lua):**
```lua
local currentFarmZone = nil

-- Detect farm zone entry/exit using ox_lib zones
CreateThread(function()
    for _, farmZone in ipairs(Config.FarmZones) do
        exports.ox_lib:addSphereZone({
            coords = farmZone.blip.coords,
            radius = farmZone.zoneRadius,
            onEnter = function()
                currentFarmZone = farmZone.id
                TriggerServerEvent('free-farmer:playerEnteredFarmZone', farmZone.id)
            end,
            onExit = function()
                if currentFarmZone == farmZone.id then
                    TriggerServerEvent('free-farmer:playerLeftFarmZone', farmZone.id)
                    currentFarmZone = nil
                end
            end
        })
    end
end)
```

### 2.6 Growth Tick System

**Server-Side (server/fields.lua):**
```lua
-- Configurable growth tick interval (default: 5 minutes)
Config.GrowthTickInterval = 300 -- seconds

CreateThread(function()
    while true do
        Wait(Config.GrowthTickInterval * 1000)
        
        -- Get all planted fields
        local fields = MySQL.query.await([[
            SELECT * FROM farm_fields 
            WHERE crop_type IS NOT NULL 
            AND growth_stage > 0
        ]])
        
        for _, field in ipairs(fields) do
            local cropConfig = Config.Crops[field.crop_type]
            if not cropConfig then goto continue end
            
            local currentStage = cropConfig.growthStages[field.growth_stage]
            if not currentStage or not currentStage.duration then
                goto continue -- Already at final stage or invalid
            end
            
            -- Calculate time since last update
            local timeSinceUpdate = os.time() - field.stage_updated_at
            
            -- Check if stage duration met
            if timeSinceUpdate >= currentStage.duration then
                local nextStageNum = field.growth_stage + 1
                local nextStage = cropConfig.growthStages[nextStageNum]
                
                if nextStage then
                    -- Progress to next stage
                    MySQL.update.await([[
                        UPDATE farm_fields 
                        SET growth_stage = ?, stage_updated_at = UNIX_TIMESTAMP()
                        WHERE field_id = ?
                    ]], {nextStageNum, field.field_id})
                    
                    -- Respawn props with new stage visuals
                    DespawnFieldProps(field.field_id)
                    SpawnFieldProps(field.field_id)
                    
                    -- Notify players near field
                    TriggerClientEvent('free-farmer:fieldStageUpdated', -1, field.field_id, nextStageNum)
                end
            end
            
            ::continue::
        end
    end
end)
```

### 2.7 Weather Integration (renewed-weathersync)

**Server-Side (server/weather.lua):**
```lua
local currentWeather = 'CLEAR'
local weatherHistory = {} -- Rolling 24-hour window

-- Hook into renewed-weathersync events
AddEventHandler('weathersync:server:RequestStateSync', function()
    -- Get initial weather state on resource start
    -- This may vary depending on renewed-weathersync API
end)

AddEventHandler('weathersync:server:weather:change', function(newWeather)
    currentWeather = newWeather
    
    -- Log weather change
    table.insert(weatherHistory, {
        weather = newWeather,
        timestamp = os.time()
    })
    
    -- Keep only last 24 entries (assume hourly changes)
    if #weatherHistory > 24 then
        table.remove(weatherHistory, 1)
    end
    
    -- Update all active crops with current weather modifier
    UpdateAllCropWeatherModifiers(newWeather)
end)

---@param weather string
function UpdateAllCropWeatherModifiers(weather)
    local fields = MySQL.query.await([[
        SELECT field_id, crop_type 
        FROM farm_fields 
        WHERE crop_type IS NOT NULL
    ]])
    
    for _, field in ipairs(fields) do
        local cropConfig = Config.Crops[field.crop_type]
        if cropConfig and cropConfig.weatherPreferences then
            local weatherMod = cropConfig.weatherPreferences[weather:lower()] or 1.0
            
            -- Track good vs bad weather ticks
            local goodTick = weatherMod >= 1.0 and 1 or 0
            local badTick = weatherMod < 0.9 and 1 or 0
            
            MySQL.update.await([[
                UPDATE farm_fields 
                SET 
                    weather_quality_modifier = ?,
                    good_weather_ticks = good_weather_ticks + ?,
                    bad_weather_ticks = bad_weather_ticks + ?
                WHERE field_id = ?
            ]], {weatherMod, goodTick, badTick, field.field_id})
        end
    end
end

---@param fieldId string
---@return number bonus
function CalculateWeatherYieldBonus(fieldId)
    local field = MySQL.single.await([[
        SELECT good_weather_ticks, bad_weather_ticks 
        FROM farm_fields 
        WHERE field_id = ?
    ]], {fieldId})
    
    if not field then return 1.0 end
    
    local totalTicks = field.good_weather_ticks + field.bad_weather_ticks
    if totalTicks == 0 then return 1.0 end
    
    local goodRatio = field.good_weather_ticks / totalTicks
    
    -- Weather bonus calculation
    if goodRatio >= 0.75 then
        return 1.15 -- 15% bonus for excellent weather
    elseif goodRatio >= 0.6 then
        return 1.08 -- 8% bonus for good weather
    elseif goodRatio >= 0.4 then
        return 1.0 -- Neutral
    elseif goodRatio >= 0.25 then
        return 0.92 -- 8% penalty for poor weather
    else
        return 0.85 -- 15% penalty for terrible weather
    end
end
```

### 2.8 Soil Quality & Crop Rotation System

**Soil Quality Degradation (after harvest):**
```lua
---@param fieldId string
---@param cropType string
function DegradeSoilQuality(fieldId, cropType)
    local field = MySQL.single.await('SELECT * FROM farm_fields WHERE field_id = ?', {fieldId})
    if not field then return end
    
    local cropConfig = Config.Crops[cropType]
    if not cropConfig then return end
    
    -- Check for crop rotation bonus
    local rotationBonus = 0
    if field.last_crop_family and field.last_crop_family ~= cropConfig.cropFamily then
        rotationBonus = 5 -- +5 soil quality for rotation
    end
    
    -- Check for consecutive same crop penalty
    local consecutivePenalty = 0
    if field.last_crop == cropType then
        consecutivePenalty = field.consecutive_same_crop * 2 -- Increasing penalty
    end
    
    -- Calculate new soil quality
    local degradation = cropConfig.soilDegradation + consecutivePenalty - rotationBonus
    local newSoilQuality = math.max(0, field.soil_quality - degradation)
    
    -- Update consecutive counter
    local consecutiveCount = (field.last_crop == cropType) and (field.consecutive_same_crop + 1) or 1
    
    MySQL.update.await([[
        UPDATE farm_fields 
        SET 
            soil_quality = ?,
            last_crop = ?,
            last_crop_family = ?,
            consecutive_same_crop = ?,
            times_harvested = times_harvested + 1
        WHERE field_id = ?
    ]], {newSoilQuality, cropType, cropConfig.cropFamily, consecutiveCount, fieldId})
end
```

### 2.9 Harvest Yield Calculation

**Server-Side (server/fields.lua):**
```lua
---@param fieldId string
---@param playerSrc number
---@return table result {success: boolean, yield: number, quality: string}
function CalculateHarvestYield(fieldId, playerSrc)
    local field = MySQL.single.await('SELECT * FROM farm_fields WHERE field_id = ?', {fieldId})
    if not field or not field.crop_type then
        return {success = false, yield = 0, quality = 'poor'}
    end
    
    local fieldConfig = GetFieldConfig(fieldId)
    local cropConfig = Config.Crops[field.crop_type]
    
    -- Base yield (per 100 sq meters)
    local baseYieldMin = cropConfig.baseYield.min
    local baseYieldMax = cropConfig.baseYield.max
    local baseYield = math.random(baseYieldMin, baseYieldMax)
    
    -- Scale by field size
    local fieldSizeMultiplier = fieldConfig.size / 100.0
    local totalYield = baseYield * fieldSizeMultiplier
    
    -- Apply modifiers
    local soilModifier = field.soil_quality / 100.0 -- 0.0 to 1.0
    local weatherModifier = CalculateWeatherYieldBonus(fieldId)
    local xpModifier = GetPlayerFarmingXPModifier(playerSrc) -- 1.0 to 1.5
    
    -- Final yield
    local finalYield = math.floor(totalYield * soilModifier * weatherModifier * xpModifier)
    
    -- Determine quality tier
    local conditionScore = (soilModifier + weatherModifier + (xpModifier - 1.0) * 2) / 3
    local quality = 'poor'
    
    if conditionScore >= cropConfig.qualityThresholds.excellent then
        quality = 'excellent'
    elseif conditionScore >= cropConfig.qualityThresholds.good then
        quality = 'good'
    elseif conditionScore >= cropConfig.qualityThresholds.average then
        quality = 'average'
    else
        quality = 'poor'
    end
    
    return {
        success = true,
        yield = finalYield,
        quality = quality,
        soilQuality = field.soil_quality,
        weatherBonus = weatherModifier,
        xpBonus = xpModifier
    }
end
```

---

## 3. Livestock System - Physical Ped Implementation

### 3.1 Animal Roster & Configuration

```lua
Config.Animals = {
    cow = {
        label = "Dairy Cow",
        pedModel = "a_c_cow",
        purchasePrice = 2500,
        unlockLevel = 5,
        
        growthStages = {
            {
                stage = "calf",
                label = "Calf",
                duration = 172800, -- 48 hours
                scale = 0.6,
                healthRegen = 2, -- Health regen per interval when healthy
            },
            {
                stage = "heifer",
                label = "Heifer",
                duration = 259200, -- 72 hours
                scale = 0.8,
                healthRegen = 3,
            },
            {
                stage = "adult",
                label = "Adult Cow",
                duration = nil, -- Permanent stage
                scale = 1.0,
                healthRegen = 5,
            },
        },
        
        production = {
            type = "milk",
            item = "raw_milk",
            cycleTime = 43200, -- 12 hours between milking
            baseYield = {min = 15, max = 25}, -- Liters
            qualityMultiplier = {
                poor = 0.7,
                average = 1.0,
                good = 1.2,
                excellent = 1.5
            },
        },
        
        needs = {
            feedItem = "hay",
            feedAmount = 2, -- Per feeding
            feedInterval = 21600, -- 6 hours
            waterInterval = 21600,
            alternativeFeed = {"grain", "silage"}, -- Optional better feed
        },
        
        health = {
            baseDecay = 2, -- Points per interval
            decayInterval = 3600, -- 1 hour
            sicknessThreshold = 30,
            deathThreshold = 0,
            hungerPenalty = 5, -- Extra decay if not fed
            thirstPenalty = 8,
        },
        
        breeding = {
            enabled = true,
            maleRequired = true,
            gestationTime = 604800, -- 7 days (cow pregnancy is ~9 months IRL)
            cooldownAfterBirth = 259200, -- 3 days before can breed again
            offspringMin = 1,
            offspringMax = 1,
        },
        
        ai = {
            behavior = "grazing", -- grazing, pecking, roaming, lounging
            wanderSpeed = 1.0, -- Movement speed
            idleTime = {min = 5000, max = 15000}, -- Time between movements
            grouping = true, -- Prefers staying near other cows
            groupRadius = 10.0,
        },
        
        penSize = 5, -- Max animals per pen
        storageDecay = 5, -- Health decay per day while stored
        storageSicknessTime = 259200, -- 3 days stored = sickness
    },
    
    chicken = {
        label = "Chicken",
        pedModel = "a_c_hen",
        purchasePrice = 50,
        unlockLevel = 1,
        
        growthStages = {
            {stage = "chick", label = "Chick", duration = 86400, scale = 0.5, healthRegen = 3},
            {stage = "adult", label = "Adult Chicken", duration = nil, scale = 1.0, healthRegen = 5},
        },
        
        production = {
            type = "eggs",
            item = "chicken_egg",
            cycleTime = 28800, -- 8 hours
            baseYield = {min = 1, max = 1},
            qualityMultiplier = {poor = 0.5, average = 1.0, good = 1.0, excellent = 1.0},
        },
        
        needs = {
            feedItem = "chicken_feed",
            feedAmount = 1,
            feedInterval = 28800,
            waterInterval = 28800,
            alternativeFeed = {"grain"},
        },
        
        health = {
            baseDecay = 3,
            decayInterval = 3600,
            sicknessThreshold = 40,
            deathThreshold = 0,
            hungerPenalty = 6,
            thirstPenalty = 10,
        },
        
        breeding = {
            enabled = true,
            maleRequired = true,
            gestationTime = 86400, -- 1 day (chickens lay eggs)
            cooldownAfterBirth = 21600, -- 6 hours
            offspringMin = 1,
            offspringMax = 3,
        },
        
        ai = {
            behavior = "pecking",
            wanderSpeed = 1.2,
            idleTime = {min = 3000, max = 8000},
            grouping = true,
            groupRadius = 5.0,
            flocking = true, -- Chickens move in flocks
        },
        
        penSize = 20,
        storageDecay = 8,
        storageSicknessTime = 172800, -- 2 days
    },
    
    turkey = {
        label = "Turkey",
        pedModel = "a_c_chickenhawk", -- Use closest available model
        purchasePrice = 80,
        unlockLevel = 8,
        
        growthStages = {
            {stage = "poult", label = "Poult", duration = 129600, scale = 0.6, healthRegen = 3}, -- 36 hours
            {stage = "adult", label = "Adult Turkey", duration = nil, scale = 1.2, healthRegen = 5},
        },
        
        production = {
            type = "eggs",
            item = "turkey_egg",
            cycleTime = 43200, -- 12 hours
            baseYield = {min = 1, max = 1},
            qualityMultiplier = {poor = 0.6, average = 1.0, good = 1.0, excellent = 1.0},
        },
        
        needs = {
            feedItem = "chicken_feed",
            feedAmount = 2,
            feedInterval = 32400, -- 9 hours
            waterInterval = 32400,
            alternativeFeed = {"grain"},
        },
        
        health = {
            baseDecay = 3,
            decayInterval = 3600,
            sicknessThreshold = 35,
            deathThreshold = 0,
            hungerPenalty = 6,
            thirstPenalty = 9,
        },
        
        breeding = {
            enabled = true,
            maleRequired = true,
            gestationTime = 172800, -- 2 days
            cooldownAfterBirth = 43200,
            offspringMin = 1,
            offspringMax = 2,
        },
        
        ai = {
            behavior = "pecking",
            wanderSpeed = 1.1,
            idleTime = {min = 4000, max = 10000},
            grouping = true,
            groupRadius = 6.0,
        },
        
        penSize = 15,
        storageDecay = 7,
        storageSicknessTime = 172800,
    },
    
    pig = {
        label = "Pig",
        pedModel = "a_c_pig",
        purchasePrice = 400,
        unlockLevel = 10,
        
        growthStages = {
            {stage = "piglet", label = "Piglet", duration = 172800, scale = 0.5, healthRegen = 3}, -- 48 hours
            {stage = "grower", label = "Grower Pig", duration = 259200, scale = 0.75, healthRegen = 4}, -- 72 hours
            {stage = "market", label = "Market Pig", duration = nil, scale = 1.0, healthRegen = 5},
        },
        
        production = {
            type = "none", -- Pigs raised for meat (existing butcher system)
            item = nil,
            cycleTime = nil,
            baseYield = nil,
        },
        
        needs = {
            feedItem = "pig_slop",
            feedAmount = 3,
            feedInterval = 21600, -- 6 hours
            waterInterval = 21600,
            alternativeFeed = {"grain", "vegetable_scraps"},
        },
        
        health = {
            baseDecay = 2,
            decayInterval = 3600,
            sicknessThreshold = 30,
            deathThreshold = 0,
            hungerPenalty = 6,
            thirstPenalty = 8,
        },
        
        breeding = {
            enabled = true,
            maleRequired = true,
            gestationTime = 345600, -- 4 days (actual ~4 months)
            cooldownAfterBirth = 172800,
            offspringMin = 4,
            offspringMax = 8, -- Pigs have large litters
        },
        
        ai = {
            behavior = "roaming",
            wanderSpeed = 0.9,
            idleTime = {min = 6000, max = 15000},
            grouping = true,
            groupRadius = 8.0,
        },
        
        penSize = 10,
        storageDecay = 6,
        storageSicknessTime = 259200,
    },
    
    goat = {
        label = "Goat",
        pedModel = "a_c_cow", -- Will need custom model or substitute
        purchasePrice = 350,
        unlockLevel = 12,
        
        growthStages = {
            {stage = "kid", label = "Kid", duration = 129600, scale = 0.5, healthRegen = 3}, -- 36 hours
            {stage = "adult", label = "Adult Goat", duration = nil, scale = 0.7, healthRegen = 5},
        },
        
        production = {
            type = "milk",
            item = "goat_milk",
            cycleTime = 43200, -- 12 hours
            baseYield = {min = 8, max = 15}, -- Less than cows
            qualityMultiplier = {poor = 0.7, average = 1.0, good = 1.2, excellent = 1.5},
        },
        
        needs = {
            feedItem = "hay",
            feedAmount = 1,
            feedInterval = 28800, -- 8 hours
            waterInterval = 28800,
            alternativeFeed = {"grain", "browse"}, -- Goats are browsers
        },
        
        health = {
            baseDecay = 2,
            decayInterval = 3600,
            sicknessThreshold = 35,
            deathThreshold = 0,
            hungerPenalty = 5,
            thirstPenalty = 7,
        },
        
        breeding = {
            enabled = true,
            maleRequired = true,
            gestationTime = 432000, -- 5 days
            cooldownAfterBirth = 129600,
            offspringMin = 1,
            offspringMax = 2,
        },
        
        ai = {
            behavior = "grazing",
            wanderSpeed = 1.1,
            idleTime = {min = 4000, max = 12000},
            grouping = true,
            groupRadius = 10.0,
            climbing = true, -- Goats like to climb/jump
        },
        
        penSize = 8,
        storageDecay = 6,
        storageSicknessTime = 259200,
    },
    
    sheep = {
        label = "Sheep",
        pedModel = "a_c_cow", -- Will need custom model
        purchasePrice = 300,
        unlockLevel = 15,
        
        growthStages = {
            {stage = "lamb", label = "Lamb", duration = 172800, scale = 0.6, healthRegen = 3}, -- 48 hours
            {stage = "adult", label = "Adult Sheep", duration = nil, scale = 0.8, healthRegen = 5},
        },
        
        production = {
            type = "wool",
            item = "raw_wool",
            cycleTime = 345600, -- 4 days (wool grows back)
            baseYield = {min = 3, max = 6}, -- Pounds of wool
            qualityMultiplier = {poor = 0.6, average = 1.0, good = 1.3, excellent = 1.6},
        },
        
        needs = {
            feedItem = "hay",
            feedAmount = 2,
            feedInterval = 28800,
            waterInterval = 28800,
            alternativeFeed = {"grain", "pasture_grass"},
        },
        
        health = {
            baseDecay = 2,
            decayInterval = 3600,
            sicknessThreshold = 30,
            deathThreshold = 0,
            hungerPenalty = 5,
            thirstPenalty = 7,
        },
        
        breeding = {
            enabled = true,
            maleRequired = true,
            gestationTime = 432000, -- 5 days
            cooldownAfterBirth = 129600,
            offspringMin = 1,
            offspringMax = 2,
        },
        
        ai = {
            behavior = "grazing",
            wanderSpeed = 0.9,
            idleTime = {min = 5000, max = 15000},
            grouping = true,
            groupRadius = 12.0,
            herding = true, -- Sheep move as a herd
        },
        
        penSize = 12,
        storageDecay = 5,
        storageSicknessTime = 259200,
    },
}
```

### 3.2 Animal Database Schema

```sql
CREATE TABLE IF NOT EXISTS `farm_animals` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `animal_uuid` VARCHAR(36) NOT NULL UNIQUE,
    
    -- Ownership
    `owner_identifier` VARCHAR(50) NOT NULL,
    `owner_name` VARCHAR(100) DEFAULT NULL,
    
    -- Animal Data
    `animal_type` VARCHAR(50) NOT NULL,
    `animal_name` VARCHAR(100) DEFAULT NULL, -- Player-given name
    `gender` ENUM('male', 'female') NOT NULL,
    
    -- Location
    `farm_zone` VARCHAR(50) NOT NULL,
    `pen_id` VARCHAR(50) DEFAULT NULL,
    `is_stored` BOOLEAN DEFAULT FALSE,
    `stored_at` TIMESTAMP DEFAULT NULL,
    
    -- Growth & Stats
    `growth_stage` VARCHAR(50) NOT NULL,
    `age` INT DEFAULT 0, -- In seconds
    `quality` VARCHAR(50) DEFAULT 'average', -- poor, average, good, excellent
    
    -- Health & Needs
    `health` INT DEFAULT 100,
    `last_fed` TIMESTAMP DEFAULT NULL,
    `last_watered` TIMESTAMP DEFAULT NULL,
    `is_sick` BOOLEAN DEFAULT FALSE,
    `sickness_type` VARCHAR(50) DEFAULT NULL,
    
    -- Production
    `production_ready` BOOLEAN DEFAULT FALSE,
    `last_produced` TIMESTAMP DEFAULT NULL,
    `total_production` INT DEFAULT 0,
    
    -- Breeding
    `is_pregnant` BOOLEAN DEFAULT FALSE,
    `pregnancy_start` TIMESTAMP DEFAULT NULL,
    `pregnancy_father_uuid` VARCHAR(36) DEFAULT NULL,
    `last_bred` TIMESTAMP DEFAULT NULL,
    `breeding_quality` VARCHAR(50) DEFAULT NULL, -- Genetics tracking
    
    -- Metadata
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX(`owner_identifier`),
    INDEX(`farm_zone`),
    INDEX(`pen_id`),
    INDEX(`is_stored`),
    INDEX(`animal_type`),
    INDEX(`gender`)
);
```

### 3.3 Animal AI Behavior System

**Server-Side (server/animals_ai.lua):**
```lua
local AnimalAI = {}

---@param ped number Entity handle
---@param animalType string
---@param penConfig table
function AnimalAI.ApplyBehavior(ped, animalType, penConfig)
    local config = Config.Animals[animalType]
    if not config or not config.ai then return end
    
    local ai = config.ai
    
    -- Set basic ped flags
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 17, true) -- Don't engage in combat
    
    -- Apply behavior pattern
    if ai.behavior == "grazing" then
        AnimalAI.GrazingBehavior(ped, penConfig, ai)
    elseif ai.behavior == "pecking" then
        AnimalAI.PeckingBehavior(ped, penConfig, ai)
    elseif ai.behavior == "roaming" then
        AnimalAI.RoamingBehavior(ped, penConfig, ai)
    elseif ai.behavior == "lounging" then
        AnimalAI.LoungingBehavior(ped, penConfig, ai)
    end
    
    -- Apply grouping behavior if enabled
    if ai.grouping then
        AnimalAI.EnableGrouping(ped, penConfig, ai)
    end
end

function AnimalAI.GrazingBehavior(ped, penConfig, ai)
    CreateThread(function()
        while DoesEntityExist(ped) do
            -- Look down and idle (grazing animation)
            TaskStartScenarioInPlace(ped, "WORLD_COW_GRAZING", 0, true)
            Wait(math.random(ai.idleTime.min, ai.idleTime.max))
            
            -- Wander to new spot
            ClearPedTasks(ped)
            local penCenter = GetPolygonCenter(penConfig.polygon)
            TaskWanderInArea(ped, penCenter.x, penCenter.y, penCenter.z, penConfig.wanderRadius, ai.wanderSpeed, ai.wanderSpeed)
            Wait(math.random(5000, 10000))
        end
    end)
end

function AnimalAI.PeckingBehavior(ped, penConfig, ai)
    CreateThread(function()
        while DoesEntityExist(ped) do
            -- Peck at ground
            TaskStartScenarioInPlace(ped, "WORLD_HEN_PECKING", 0, true)
            Wait(math.random(ai.idleTime.min, ai.idleTime.max))
            
            -- Quick burst movement to new spot
            ClearPedTasks(ped)
            local penCenter = GetPolygonCenter(penConfig.polygon)
            TaskGoToCoordAnyMeans(ped, 
                penCenter.x + math.random(-penConfig.wanderRadius, penConfig.wanderRadius),
                penCenter.y + math.random(-penConfig.wanderRadius, penConfig.wanderRadius),
                penCenter.z,
                ai.wanderSpeed, 0, 0, 786603, 0xbf800000)
            Wait(math.random(3000, 6000))
        end
    end)
end

function AnimalAI.RoamingBehavior(ped, penConfig, ai)
    CreateThread(function()
        while DoesEntityExist(ped) do
            local penCenter = GetPolygonCenter(penConfig.polygon)
            TaskWanderInArea(ped, penCenter.x, penCenter.y, penCenter.z, penConfig.wanderRadius, ai.wanderSpeed, ai.wanderSpeed)
            Wait(math.random(ai.idleTime.min, ai.idleTime.max))
            
            -- Occasional pause
            if math.random() < 0.3 then
                ClearPedTasks(ped)
                Wait(math.random(3000, 8000))
            end
        end
    end)
end

function AnimalAI.LoungingBehavior(ped, penConfig, ai)
    CreateThread(function()
        while DoesEntityExist(ped) do
            -- Sit/lay down
            TaskStartScenarioInPlace(ped, "WORLD_COW_GRAZING", 0, true) -- Closest to resting
            Wait(math.random(ai.idleTime.min, ai.idleTime.max))
            
            -- Occasionally get up and move
            if math.random() < 0.4 then
                ClearPedTasks(ped)
                local penCenter = GetPolygonCenter(penConfig.polygon)
                TaskGoToCoordAnyMeans(ped,
                    penCenter.x + math.random(-penConfig.wanderRadius, penConfig.wanderRadius),
                    penCenter.y + math.random(-penConfig.wanderRadius, penConfig.wanderRadius),
                    penCenter.z,
                    ai.wanderSpeed, 0, 0, 786603, 0xbf800000)
                Wait(math.random(5000, 10000))
            end
        end
    end)
end

function AnimalAI.EnableGrouping(ped, penConfig, ai)
    CreateThread(function()
        while DoesEntityExist(ped) do
            Wait(10000) -- Check every 10 seconds
            
            -- Find nearby animals of same type
            local nearbyAnimals = GetNearbyAnimals(ped, ai.groupRadius, penConfig.animalType)
            
            if #nearbyAnimals > 0 then
                -- Move toward the group center
                local groupCenter = CalculateGroupCenter(nearbyAnimals)
                TaskGoToCoordAnyMeans(ped, groupCenter.x, groupCenter.y, groupCenter.z, ai.wanderSpeed, 0, 0, 786603, 0xbf800000)
            end
        end
    end)
end

-- Flocking behavior for chickens
function AnimalAI.EnableFlocking(ped, penConfig, ai)
    CreateThread(function()
        while DoesEntityExist(ped) do
            Wait(5000)
            
            local nearbyChickens = GetNearbyAnimals(ped, ai.groupRadius, "chicken")
            if #nearbyChickens >= 3 then
                -- Move as a flock
                local flockCenter = CalculateGroupCenter(nearbyChickens)
                local offset = vector3(math.random(-2, 2), math.random(-2, 2), 0)
                TaskGoToCoordAnyMeans(ped, flockCenter.x + offset.x, flockCenter.y + offset.y, flockCenter.z, ai.wanderSpeed, 0, 0, 786603, 0xbf800000)
            end
        end
    end)
end

return AnimalAI
```

### 3.4 Animal Spawning & Despawning

**Server-Side (server/animals.lua):**
```lua
local spawnedAnimals = {} -- {[animalUuid] = pedNetId}
local activeFarmZones = {} -- {[farmZoneId] = playerCount}

---@param animalData table Database row
---@return number|nil netId
function SpawnAnimal(animalData)
    if animalData.is_stored then return nil end -- Don't spawn stored animals
    
    local penConfig = GetPenConfig(animalData.farm_zone, animalData.pen_id)
    if not penConfig then return nil end
    
    local animalConfig = Config.Animals[animalData.animal_type]
    if not animalConfig then return nil end
    
    local stageConfig = nil
    for _, stage in ipairs(animalConfig.growthStages) do
        if stage.stage == animalData.growth_stage then
            stageConfig = stage
            break
        end
    end
    if not stageConfig then return nil end
    
    -- Get random spawn point within pen polygon
    local spawnPos = GetRandomPointInPolygon(penConfig.polygon)
    
    -- Create ped
    local pedModel = GetHashKey(animalConfig.pedModel)
    RequestModel(pedModel)
    local timeout = 0
    while not HasModelLoaded(pedModel) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end
    
    if not HasModelLoaded(pedModel) then
        print("^1[free-farmer] Failed to load animal model: "..animalConfig.pedModel.."^7")
        return nil
    end
    
    -- Spawn ped with collision avoidance
    local ped = CreatePed(28, pedModel, spawnPos.x, spawnPos.y, spawnPos.z, math.random(0, 360), true, false)
    
    -- Apply properties
    SetEntityAsMissionEntity(ped, true, true)
    SetPedScale(ped, stageConfig.scale)
    
    -- Apply AI behavior
    local AnimalAI = require('server.animals_ai')
    AnimalAI.ApplyBehavior(ped, animalData.animal_type, penConfig)
    
    -- Keep animal within pen boundaries (invisible barrier)
    CreateThread(function()
        while DoesEntityExist(ped) do
            Wait(1000)
            local pedPos = GetEntityCoords(ped)
            if not IsPointInPolygon(pedPos, penConfig.polygon) then
                -- Animal escaped pen bounds, teleport back
                local centerPos = GetPolygonCenter(penConfig.polygon)
                SetEntityCoords(ped, centerPos.x, centerPos.y, centerPos.z, false, false, false, false)
            end
        end
    end)
    
    -- Store reference
    local netId = NetworkGetNetworkIdFromEntity(ped)
    spawnedAnimals[animalData.animal_uuid] = {
        netId = netId,
        entity = ped
    }
    
    -- Set state bags for client interaction
    Entity(ped).state:set('animalUuid', animalData.animal_uuid, true)
    Entity(ped).state:set('animalType', animalData.animal_type, true)
    Entity(ped).state:set('animalName', animalData.animal_name, true)
    Entity(ped).state:set('health', animalData.health, true)
    Entity(ped).state:set('quality', animalData.quality, true)
    Entity(ped).state:set('productionReady', animalData.production_ready, true)
    Entity(ped).state:set('isSick', animalData.is_sick, true)
    Entity(ped).state:set('gender', animalData.gender, true)
    Entity(ped).state:set('isPregnant', animalData.is_pregnant, true)
    
    SetModelAsNoLongerNeeded(pedModel)
    
    return netId
end

---@param animalUuid string
function DespawnAnimal(animalUuid)
    local animalData = spawnedAnimals[animalUuid]
    if animalData then
        local ped = animalData.entity
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
        spawnedAnimals[animalUuid] = nil
    end
end

-- Farm zone enter/exit handlers
RegisterNetEvent('free-farmer:playerEnteredFarmZone', function(farmZoneId)
    local src = source
    
    activeFarmZones[farmZoneId] = (activeFarmZones[farmZoneId] or 0) + 1
    
    if activeFarmZones[farmZoneId] == 1 then
        -- First player entered, spawn all animals for this farm
        local animals = MySQL.query.await([[
            SELECT * FROM farm_animals 
            WHERE farm_zone = ? AND is_stored = FALSE
        ]], {farmZoneId})
        
        for _, animal in ipairs(animals) do
            if not spawnedAnimals[animal.animal_uuid] then
                SpawnAnimal(animal)
            end
        end
    end
end)

RegisterNetEvent('free-farmer:playerLeftFarmZone', function(farmZoneId)
    local src = source
    
    activeFarmZones[farmZoneId] = math.max(0, (activeFarmZones[farmZoneId] or 0) - 1)
    
    if activeFarmZones[farmZoneId] == 0 then
        -- No players left, despawn all animals
        local animals = MySQL.query.await([[
            SELECT animal_uuid FROM farm_animals 
            WHERE farm_zone = ? AND is_stored = FALSE
        ]], {farmZoneId})
        
        for _, animal in ipairs(animals) do
            DespawnAnimal(animal.animal_uuid)
        end
    end
end)
```

### 3.5 Animal Storage System

**Client-Side Barn Interaction (client/animals.lua):**
```lua
-- Barn storage interface
CreateThread(function()
    for _, farmZone in ipairs(Config.FarmZones) do
        exports.ox_target:addBoxZone({
            coords = farmZone.animal_barn,
            size = vec3(3, 3, 2),
            rotation = 0,
            options = {
                {
                    name = 'barn_storage',
                    icon = 'fa-solid fa-warehouse',
                    label = 'Manage Barn Storage',
                    onSelect = function()
                        TriggerServerEvent('free-farmer:openBarnStorage', farmZone.id)
                    end
                }
            }
        })
    end
end)
```

**Server-Side Storage Logic (server/animals.lua):**
```lua
RegisterNetEvent('free-farmer:openBarnStorage', function(farmZoneId)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    
    -- Get player's animals at this farm
    local animals = MySQL.query.await([[
        SELECT * FROM farm_animals 
        WHERE owner_identifier = ? AND farm_zone = ?
        ORDER BY is_stored ASC, animal_type ASC
    ]], {player.PlayerData.citizenid, farmZoneId})
    
    local activeAnimals = {}
    local storedAnimals = {}
    
    for _, animal in ipairs(animals) do
        if animal.is_stored then
            table.insert(storedAnimals, animal)
        else
            table.insert(activeAnimals, animal)
        end
    end
    
    TriggerClientEvent('free-farmer:displayBarnStorage', src, {
        active = activeAnimals,
        stored = storedAnimals,
        farmZone = farmZoneId
    })
end)

RegisterNetEvent('free-farmer:storeAnimal', function(animalUuid)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    
    local animal = MySQL.single.await([[
        SELECT * FROM farm_animals 
        WHERE animal_uuid = ? AND owner_identifier = ?
    ]], {animalUuid, player.PlayerData.citizenid})
    
    if not animal then
        return lib.notify(src, {type = 'error', description = 'Animal not found'})
    end
    
    if animal.is_stored then
        return lib.notify(src, {type = 'error', description = 'Animal already stored'})
    end
    
    -- Store animal
    MySQL.update.await([[
        UPDATE farm_animals 
        SET is_stored = TRUE, stored_at = UNIX_TIMESTAMP(), pen_id = NULL
        WHERE animal_uuid = ?
    ]], {animalUuid})
    
    -- Despawn ped
    DespawnAnimal(animalUuid)
    
    lib.notify(src, {
        type = 'success',
        description = (animal.animal_name or 'Animal')..' stored in barn'
    })
end)

RegisterNetEvent('free-farmer:releaseAnimal', function(animalUuid, penId)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    
    local animal = MySQL.single.await([[
        SELECT * FROM farm_animals 
        WHERE animal_uuid = ? AND owner_identifier = ?
    ]], {animalUuid, player.PlayerData.citizenid})
    
    if not animal or not animal.is_stored then
        return lib.notify(src, {type = 'error', description = 'Animal not found or not stored'})
    end
    
    -- Check pen capacity
    local penConfig = GetPenConfig(animal.farm_zone, penId)
    if not penConfig then
        return lib.notify(src, {type = 'error', description = 'Invalid pen'})
    end
    
    local animalConfig = Config.Animals[animal.animal_type]
    local currentPenCount = MySQL.scalar.await([[
        SELECT COUNT(*) FROM farm_animals 
        WHERE pen_id = ? AND is_stored = FALSE
    ]], {penId})
    
    if currentPenCount >= animalConfig.penSize then
        return lib.notify(src, {type = 'error', description = 'Pen is full (max '..animalConfig.penSize..')'})
    end
    
    -- Release animal
    MySQL.update.await([[
        UPDATE farm_animals 
        SET is_stored = FALSE, stored_at = NULL, pen_id = ?
        WHERE animal_uuid = ?
    ]], {penId, animalUuid})
    
    -- Spawn ped
    local updatedAnimal = MySQL.single.await('SELECT * FROM farm_animals WHERE animal_uuid = ?', {animalUuid})
    SpawnAnimal(updatedAnimal)
    
    lib.notify(src, {
        type = 'success',
        description = (animal.animal_name or 'Animal')..' released to pen'
    })
end)
```

### 3.6 Storage Degradation System

```lua
-- Server-Side (server/animals.lua)
-- Runs every hour
CreateThread(function()
    while true do
        Wait(3600000) -- 1 hour
        
        local storedAnimals = MySQL.query.await('SELECT * FROM farm_animals WHERE is_stored = TRUE')
        
        for _, animal in ipairs(storedAnimals) do
            local animalConfig = Config.Animals[animal.animal_type]
            if not animalConfig then goto continue end
            
            local storedDuration = os.time() - animal.stored_at
            local daysMath = storedDuration / 86400
            
            -- Apply daily storage decay
            local healthDecay = math.floor(animalConfig.storageDecay * daysMath)
            local newHealth = math.max(0, animal.health - healthDecay)
            
            -- Check for storage-induced sickness
            local isSick = animal.is_sick
            local sicknessType = animal.sickness_type
            if storedDuration >= animalConfig.storageSicknessTime and not isSick then
                isSick = true
                sicknessType = 'storage_neglect'
            end
            
            -- Quality degradation after extended storage (>7 days)
            local newQuality = animal.quality
            if storedDuration > 604800 then
                -- Downgrade quality tier
                if animal.quality == 'excellent' then newQuality = 'good'
                elseif animal.quality == 'good' then newQuality = 'average'
                elseif animal.quality == 'average' then newQuality = 'poor'
                end
            end
            
            MySQL.update.await([[
                UPDATE farm_animals 
                SET 
                    health = ?,
                    is_sick = ?,
                    sickness_type = ?,
                    quality = ?
                WHERE animal_uuid = ?
            ]], {newHealth, isSick, sicknessType, newQuality, animal.animal_uuid})
            
            ::continue::
        end
    end
end)
```

### 3.7 Animal Health & Needs System

```lua
-- Server-Side (server/animals.lua)
-- Runs every hour
CreateThread(function()
    while true do
        Wait(3600000) -- 1 hour
        
        local activeAnimals = MySQL.query.await('SELECT * FROM farm_animals WHERE is_stored = FALSE')
        
        for _, animal in ipairs(activeAnimals) do
            local animalConfig = Config.Animals[animal.animal_type]
            if not animalConfig then goto continue end
            
            local healthConfig = animalConfig.health
            local needsConfig = animalConfig.needs
            local currentTime = os.time()
            
            -- Check feeding status
            local timeSinceFed = animal.last_fed and (currentTime - animal.last_fed) or 999999
            local isHungry = timeSinceFed > needsConfig.feedInterval
            
            -- Check water status
            local timeSinceWatered = animal.last_watered and (currentTime - animal.last_watered) or 999999
            local isThirsty = timeSinceWatered > needsConfig.waterInterval
            
            -- Calculate health decay
            local healthDecay = healthConfig.baseDecay
            if isHungry then healthDecay = healthDecay + healthConfig.hungerPenalty end
            if isThirsty then healthDecay = healthDecay + healthConfig.thirstPenalty end
            
            -- Apply health change
            local newHealth = math.max(0, animal.health - healthDecay)
            
            -- Check for sickness
            local isSick = animal.is_sick
            local sicknessType = animal.sickness_type
            if newHealth <= healthConfig.sicknessThreshold and not isSick then
                isSick = true
                sicknessType = 'malnutrition'
            end
            
            -- Check for death
            if newHealth <= healthConfig.deathThreshold then
                -- Animal died, remove from database
                MySQL.update.await('DELETE FROM farm_animals WHERE animal_uuid = ?', {animal.animal_uuid})
                DespawnAnimal(animal.animal_uuid)
                
                -- Notify owner if online
                local ownerSrc = GetPlayerByCitizenId(animal.owner_identifier)
                if ownerSrc then
                    lib.notify(ownerSrc, {
                        type = 'error',
                        title = 'Animal Died',
                        description = (animal.animal_name or 'Your '..animal.animal_type)..' has died from neglect.'
                    })
                end
                
                goto continue
            end
            
            -- Update animal state
            MySQL.update.await([[
                UPDATE farm_animals 
                SET health = ?, is_sick = ?, sickness_type = ?
                WHERE animal_uuid = ?
            ]], {newHealth, isSick, sicknessType, animal.animal_uuid})
            
            -- Update state bag if spawned
            if spawnedAnimals[animal.animal_uuid] then
                local ped = spawnedAnimals[animal.animal_uuid].entity
                if DoesEntityExist(ped) then
                    Entity(ped).state:set('health', newHealth, true)
                    Entity(ped).state:set('isSick', isSick, true)
                end
            end
            
            ::continue::
        end
    end
end)
```

### 3.8 Animal Interactions (Individual)

**Client-Side (client/animals.lua):**
```lua
-- Get all animal models for ox_target
local animalModels = {}
for animalType, config in pairs(Config.Animals) do
    table.insert(animalModels, config.pedModel)
end

exports.ox_target:addModel(animalModels, {
    {
        name = 'check_animal',
        icon = 'fa-solid fa-heartbeat',
        label = 'Check Animal',
        canInteract = function(entity)
            return Entity(entity).state.animalUuid ~= nil
        end,
        onSelect = function(data)
            local animalUuid = Entity(data.entity).state.animalUuid
            TriggerServerEvent('free-farmer:checkAnimal', animalUuid)
        end
    },
    {
        name = 'feed_animal',
        icon = 'fa-solid fa-seedling',
        label = 'Feed Animal',
        canInteract = function(entity)
            return Entity(entity).state.animalUuid ~= nil
        end,
        onSelect = function(data)
            local animalUuid = Entity(data.entity).state.animalUuid
            local animalType = Entity(data.entity).state.animalType
            TriggerServerEvent('free-farmer:feedAnimal', animalUuid, animalType)
        end
    },
    {
        name = 'water_animal',
        icon = 'fa-solid fa-droplet',
        label = 'Give Water',
        canInteract = function(entity)
            return Entity(entity).state.animalUuid ~= nil
        end,
        onSelect = function(data)
            local animalUuid = Entity(data.entity).state.animalUuid
            TriggerServerEvent('free-farmer:waterAnimal', animalUuid)
        end
    },
    {
        name = 'milk_cow',
        icon = 'fa-solid fa-fill-drip',
        label = 'Milk',
        canInteract = function(entity)
            local animalType = Entity(entity).state.animalType
            local productionReady = Entity(entity).state.productionReady
            return (animalType == 'cow' or animalType == 'goat') and productionReady
        end,
        onSelect = function(data)
            local animalUuid = Entity(data.entity).state.animalUuid
            TriggerServerEvent('free-farmer:milkAnimal', animalUuid)
        end
    },
    {
        name = 'collect_eggs',
        icon = 'fa-solid fa-egg',
        label = 'Collect Eggs',
        canInteract = function(entity)
            local animalType = Entity(entity).state.animalType
            local productionReady = Entity(entity).state.productionReady
            return (animalType == 'chicken' or animalType == 'turkey') and productionReady
        end,
        onSelect = function(data)
            local animalUuid = Entity(data.entity).state.animalUuid
            TriggerServerEvent('free-farmer:collectEggs', animalUuid)
        end
    },
    {
        name = 'shear_sheep',
        icon = 'fa-solid fa-scissors',
        label = 'Shear Wool',
        canInteract = function(entity)
            local animalType = Entity(entity).state.animalType
            local productionReady = Entity(entity).state.productionReady
            return animalType == 'sheep' and productionReady
        end,
        onSelect = function(data)
            local animalUuid = Entity(data.entity).state.animalUuid
            TriggerServerEvent('free-farmer:shearAnimal', animalUuid)
        end
    },
    {
        name = 'name_animal',
        icon = 'fa-solid fa-tag',
        label = 'Name Animal',
        canInteract = function(entity)
            return Entity(entity).state.animalUuid ~= nil
        end,
        onSelect = function(data)
            local animalUuid = Entity(data.entity).state.animalUuid
            
            local input = lib.inputDialog('Name Your Animal', {
                {type = 'input', label = 'Animal Name', description = 'Enter a name (optional)', placeholder = 'Bessie', required = false, max = 50}
            })
            
            if input and input[1] then
                TriggerServerEvent('free-farmer:nameAnimal', animalUuid, input[1])
            end
        end
    },
    {
        name = 'store_animal',
        icon = 'fa-solid fa-warehouse',
        label = 'Store in Barn',
        canInteract = function(entity)
            return Entity(entity).state.animalUuid ~= nil
        end,
        onSelect = function(data)
            local animalUuid = Entity(data.entity).state.animalUuid
            TriggerServerEvent('free-farmer:storeAnimal', animalUuid)
        end
    },
})
```

---

## 4. Breeding System

### 4.1 Breeding Configuration

Already included in animal configs above (`breeding` table), but here's the implementation:

### 4.2 Breeding Mechanics

**Server-Side (server/breeding.lua):**
```lua
RegisterNetEvent('free-farmer:initiateBreeding', function(femaleUuid, maleUuid)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    
    -- Verify ownership of both animals
    local female = MySQL.single.await([[
        SELECT * FROM farm_animals 
        WHERE animal_uuid = ? AND owner_identifier = ?
    ]], {femaleUuid, player.PlayerData.citizenid})
    
    local male = MySQL.single.await([[
        SELECT * FROM farm_animals 
        WHERE animal_uuid = ? AND owner_identifier = ?
    ]], {maleUuid, player.PlayerData.citizenid})
    
    if not female or not male then
        return lib.notify(src, {type = 'error', description = 'Animal not found'})
    end
    
    -- Verify same type
    if female.animal_type ~= male.animal_type then
        return lib.notify(src, {type = 'error', description = 'Animals must be same species'})
    end
    
    -- Verify genders
    if female.gender ~= 'female' or male.gender ~= 'male' then
        return lib.notify(src, {type = 'error', description = 'Incorrect genders for breeding'})
    end
    
    -- Verify both are adults
    local animalConfig = Config.Animals[female.animal_type]
    if female.growth_stage ~= 'adult' or male.growth_stage ~= 'adult' then
        return lib.notify(src, {type = 'error', description = 'Both animals must be adults'})
    end
    
    -- Verify female not pregnant
    if female.is_pregnant then
        return lib.notify(src, {type = 'error', description = 'Female is already pregnant'})
    end
    
    -- Verify breeding cooldown
    if female.last_bred then
        local timeSinceBreed = os.time() - female.last_bred
        if timeSinceBreed < animalConfig.breeding.cooldownAfterBirth then
            local hoursRemaining = math.ceil((animalConfig.breeding.cooldownAfterBirth - timeSinceBreed) / 3600)
            return lib.notify(src, {
                type = 'error',
                description = 'Female needs '..hoursRemaining..' more hours before breeding again'
            })
        end
    end
    
    -- Verify health
    if female.health < 70 or male.health < 70 then
        return lib.notify(src, {type = 'error', description = 'Both animals must be healthy (70+ health)'})
    end
    
    -- Calculate offspring quality (genetics)
    local offspringQuality = CalculateOffspringQuality(female.quality, male.quality)
    
    -- Start pregnancy
    MySQL.update.await([[
        UPDATE farm_animals 
        SET 
            is_pregnant = TRUE,
            pregnancy_start = UNIX_TIMESTAMP(),
            pregnancy_father_uuid = ?,
            breeding_quality = ?,
            last_bred = UNIX_TIMESTAMP()
        WHERE animal_uuid = ?
    ]], {maleUuid, offspringQuality, femaleUuid})
    
    lib.notify(src, {
        type = 'success',
        description = (female.animal_name or 'Female')..' is now pregnant!'
    })
    
    -- Update state bag if spawned
    if spawnedAnimals[femaleUuid] then
        local ped = spawnedAnimals[femaleUuid].entity
        if DoesEntityExist(ped) then
            Entity(ped).state:set('isPregnant', true, true)
        end
    end
end)

---@param femaleQuality string
---@param maleQuality string
---@return string offspringQuality
function CalculateOffspringQuality(femaleQuality, maleQuality)
    local qualityValues = {poor = 1, average = 2, good = 3, excellent = 4}
    local qualityNames = {'poor', 'average', 'good', 'excellent'}
    
    local femaleValue = qualityValues[femaleQuality] or 2
    local maleValue = qualityValues[maleQuality] or 2
    
    -- Average parent quality with slight randomness
    local avgValue = (femaleValue + maleValue) / 2
    local randomMod = math.random(-1, 1) * 0.5
    local finalValue = math.floor(avgValue + randomMod)
    finalValue = math.max(1, math.min(4, finalValue))
    
    return qualityNames[finalValue]
end
```

### 4.3 Pregnancy & Birth System

```lua
-- Server-Side (server/breeding.lua)
-- Runs every hour
CreateThread(function()
    while true do
        Wait(3600000) -- 1 hour
        
        local pregnantAnimals = MySQL.query.await([[
            SELECT * FROM farm_animals 
            WHERE is_pregnant = TRUE
        ]])
        
        for _, animal in ipairs(pregnantAnimals) do
            local animalConfig = Config.Animals[animal.animal_type]
            if not animalConfig or not animalConfig.breeding then goto continue end
            
            local pregnancyDuration = os.time() - animal.pregnancy_start
            
            -- Check if gestation complete
            if pregnancyDuration >= animalConfig.breeding.gestationTime then
                -- Give birth!
                local offspringCount = math.random(
                    animalConfig.breeding.offspringMin,
                    animalConfig.breeding.offspringMax
                )
                
                for i = 1, offspringCount do
                    local babyUuid = GenerateUUID()
                    local babyGender = math.random() < 0.5 and 'male' or 'female'
                    
                    -- Create offspring
                    MySQL.insert.await([[
                        INSERT INTO farm_animals (
                            animal_uuid, owner_identifier, animal_type, gender,
                            farm_zone, pen_id, growth_stage, quality, health
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 100)
                    ]], {
                        babyUuid,
                        animal.owner_identifier,
                        animal.animal_type,
                        babyGender,
                        animal.farm_zone,
                        animal.pen_id,
                        animalConfig.growthStages[1].stage, -- First growth stage (baby)
                        animal.breeding_quality, -- Inherited quality
                    })
                    
                    -- Spawn baby if pen is active
                    if not animal.is_stored then
                        local babyData = MySQL.single.await('SELECT * FROM farm_animals WHERE animal_uuid = ?', {babyUuid})
                        SpawnAnimal(babyData)
                    end
                end
                
                -- Update mother
                MySQL.update.await([[
                    UPDATE farm_animals 
                    SET 
                        is_pregnant = FALSE,
                        pregnancy_start = NULL,
                        pregnancy_father_uuid = NULL,
                        breeding_quality = NULL
                    WHERE animal_uuid = ?
                ]], {animal.animal_uuid})
                
                -- Update state bag
                if spawnedAnimals[animal.animal_uuid] then
                    local ped = spawnedAnimals[animal.animal_uuid].entity
                    if DoesEntityExist(ped) then
                        Entity(ped).state:set('isPregnant', false, true)
                    end
                end
                
                -- Notify owner
                local ownerSrc = GetPlayerByCitizenId(animal.owner_identifier)
                if ownerSrc then
                    lib.notify(ownerSrc, {
                        type = 'success',
                        title = 'New Arrivals!',
                        description = (animal.animal_name or 'Your '..animal.animal_type)..' gave birth to '..offspringCount..' offspring!'
                    })
                end
            end
            
            ::continue::
        end
    end
end)
```

### 4.4 Animal Growth (Age Progression)

```lua
-- Server-Side (server/animals.lua)
-- Runs every 6 hours
CreateThread(function()
    while true do
        Wait(21600000) -- 6 hours
        
        local animals = MySQL.query.await('SELECT * FROM farm_animals')
        
        for _, animal in ipairs(animals) do
            local animalConfig = Config.Animals[animal.animal_type]
            if not animalConfig then goto continue end
            
            -- Increment age
            local newAge = animal.age + 21600 -- Add 6 hours in seconds
            
            -- Check for growth stage advancement
            local currentStageIdx = nil
            for idx, stage in ipairs(animalConfig.growthStages) do
                if stage.stage == animal.growth_stage then
                    currentStageIdx = idx
                    break
                end
            end
            
            if currentStageIdx and animalConfig.growthStages[currentStageIdx + 1] then
                local currentStage = animalConfig.growthStages[currentStageIdx]
                
                if currentStage.duration and newAge >= currentStage.duration then
                    -- Advance to next stage
                    local nextStage = animalConfig.growthStages[currentStageIdx + 1]
                    
                    MySQL.update.await([[
                        UPDATE farm_animals 
                        SET age = ?, growth_stage = ?
                        WHERE animal_uuid = ?
                    ]], {newAge, nextStage.stage, animal.animal_uuid})
                    
                    -- Respawn with new scale
                    if not animal.is_stored and spawnedAnimals[animal.animal_uuid] then
                        DespawnAnimal(animal.animal_uuid)
                        local updatedAnimal = MySQL.single.await('SELECT * FROM farm_animals WHERE animal_uuid = ?', {animal.animal_uuid})
                        SpawnAnimal(updatedAnimal)
                    end
                    
                    -- Notify owner
                    local ownerSrc = GetPlayerByCitizenId(animal.owner_identifier)
                    if ownerSrc then
                        lib.notify(ownerSrc, {
                            type = 'info',
                            description = (animal.animal_name or 'Your '..animal.animal_type)..' has grown to '..nextStage.label
                        })
                    end
                else
                    MySQL.update.await('UPDATE farm_animals SET age = ? WHERE animal_uuid = ?', {newAge, animal.animal_uuid})
                end
            else
                MySQL.update.await('UPDATE farm_animals SET age = ? WHERE animal_uuid = ?', {newAge, animal.animal_uuid})
            end
            
            ::continue::
        end
    end
end)
```

---

## 5. XP & Progression System

### 5.1 XP Configuration

```lua
Config.XP = {
    maxLevel = 100,
    
    -- XP rewards per action
    actions = {
        plow_field = 5,
        plant_seeds = 8,
        water_crops = 3,
        fertilize_field = 6,
        harvest_crop = 15,
        
        feed_animal = 4,
        water_animal = 3,
        milk_animal = 10,
        collect_eggs = 8,
        shear_sheep = 12,
        breed_animals = 20,
        
        process_item = 10,
        complete_challenge = 50,
    },
    
    -- XP curve (exponential)
    xpPerLevel = function(level)
        return math.floor(100 * (level ^ 1.5))
    end,
    
    -- Yield multiplier based on level
    yieldMultiplier = function(level)
        return 1.0 + (level / 100) * 0.5 -- 1.0x at level 1, 1.5x at level 100
    end,
    
    -- Crop unlocks
    cropUnlocks = {
        [1] = {'corn', 'soybeans', 'wheat', 'hay', 'chicken'},
        [3] = {'potatoes'},
        [5] = {'pumpkins', 'cow'},
        [8] = {'turkey'},
        [10] = {'sugarbeets', 'pig'},
        [12] = {'blueberries', 'goat'},
        [15] = {'cranberries', 'sheep'},
        [18] = {'apples'},
        [20] = {'cherries'},
    },
}
```

### 5.2 XP Database Schema

```sql
CREATE TABLE IF NOT EXISTS `farm_player_data` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(50) NOT NULL UNIQUE,
    `character_name` VARCHAR(100) DEFAULT NULL,
    
    -- XP & Level
    `xp` INT DEFAULT 0,
    `level` INT DEFAULT 1,
    
    -- Stats
    `total_crops_harvested` INT DEFAULT 0,
    `total_crops_planted` INT DEFAULT 0,
    `total_animals_cared_for` INT DEFAULT 0,
    `total_production_collected` INT DEFAULT 0,
    `total_challenges_completed` INT DEFAULT 0,
    
    -- Unlocks
    `unlocked_crops` TEXT DEFAULT NULL, -- JSON array
    `unlocked_animals` TEXT DEFAULT NULL, -- JSON array
    
    -- Metadata
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX(`identifier`),
    INDEX(`level`)
);
```

### 5.3 XP Award System

**Server-Side (server/xp.lua):**
```lua
---@param src number Player source
---@param action string Action performed
---@param amount number? Optional custom amount
function AwardXP(src, action, amount)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    
    local xpAmount = amount or Config.XP.actions[action] or 0
    if xpAmount == 0 then return end
    
    -- Get player data
    local playerData = MySQL.single.await([[
        SELECT * FROM farm_player_data WHERE identifier = ?
    ]], {player.PlayerData.citizenid})
    
    if not playerData then
        -- Create new entry
        MySQL.insert.await([[
            INSERT INTO farm_player_data (identifier, character_name, xp, level)
            VALUES (?, ?, ?, ?)
        ]], {player.PlayerData.citizenid, player.PlayerData.charinfo.firstname..' '..player.PlayerData.charinfo.lastname, xpAmount, 1})
        
        lib.notify(src, {
            type = 'success',
            description = '+'..xpAmount..' Farming XP'
        })
        return
    end
    
    -- Add XP
    local newXP = playerData.xp + xpAmount
    local currentLevel = playerData.level
    local xpNeeded = Config.XP.xpPerLevel(currentLevel)
    
    -- Check for level up
    while newXP >= xpNeeded and currentLevel < Config.XP.maxLevel do
        currentLevel = currentLevel + 1
        newXP = newXP - xpNeeded
        xpNeeded = Config.XP.xpPerLevel(currentLevel)
        
        -- Level up notification
        lib.notify(src, {
            type = 'success',
            title = 'Level Up!',
            description = 'You reached Farming Level '..currentLevel
        })
        
        -- Check for unlocks
        CheckUnlocks(src, currentLevel)
    end
    
    -- Update database
    MySQL.update.await([[
        UPDATE farm_player_data 
        SET xp = ?, level = ?
        WHERE identifier = ?
    ]], {newXP, currentLevel, player.PlayerData.citizenid})
    
    -- Notify XP gain
    lib.notify(src, {
        type = 'success',
        description = '+'..xpAmount..' Farming XP'
    })
    
    -- Trigger client event for UI update
    TriggerClientEvent('free-farmer:xpUpdated', src, {
        xp = newXP,
        level = currentLevel,
        xpNeeded = xpNeeded
    })
end

---@param src number
---@param level number
function CheckUnlocks(src, level)
    local unlocks = Config.XP.cropUnlocks[level]
    if not unlocks then return end
    
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    
    -- Get current unlocks
    local playerData = MySQL.single.await([[
        SELECT unlocked_crops, unlocked_animals FROM farm_player_data WHERE identifier = ?
    ]], {player.PlayerData.citizenid})
    
    local unlockedCrops = json.decode(playerData.unlocked_crops) or {}
    local unlockedAnimals = json.decode(playerData.unlocked_animals) or {}
    
    local newUnlocks = {}
    
    for _, item in ipairs(unlocks) do
        if Config.Crops[item] then
            if not table.contains(unlockedCrops, item) then
                table.insert(unlockedCrops, item)
                table.insert(newUnlocks, Config.Crops[item].label)
            end
        elseif Config.Animals[item] then
            if not table.contains(unlockedAnimals, item) then
                table.insert(unlockedAnimals, item)
                table.insert(newUnlocks, Config.Animals[item].label)
            end
        end
    end
    
    -- Update database
    MySQL.update.await([[
        UPDATE farm_player_data 
        SET unlocked_crops = ?, unlocked_animals = ?
        WHERE identifier = ?
    ]], {json.encode(unlockedCrops), json.encode(unlockedAnimals), player.PlayerData.citizenid})
    
    -- Notify unlocks
    if #newUnlocks > 0 then
        lib.notify(src, {
            type = 'success',
            title = 'New Unlocks!',
            description = table.concat(newUnlocks, ', ')
        })
    end
end

---@param src number
---@return number multiplier
function GetPlayerFarmingXPModifier(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return 1.0 end
    
    local playerData = MySQL.single.await([[
        SELECT level FROM farm_player_data WHERE identifier = ?
    ]], {player.PlayerData.citizenid})
    
    if not playerData then return 1.0 end
    
    return Config.XP.yieldMultiplier(playerData.level)
end
```

---

## 6. Challenge System

### 6.1 Challenge Configuration

```lua
Config.Challenges = {
    refreshInterval = 86400, -- 24 hours
    maxActiveChallenges = 3,
    
    types = {
        {
            id = 'harvest_volume',
            label = 'Harvest Challenge',
            description = 'Harvest {amount} {crop}',
            difficulty = 'easy',
            xpReward = 100,
            leaderboardPoints = 10,
            requirements = function()
                local crops = {'corn', 'soybeans', 'wheat', 'potatoes'}
                local crop = crops[math.random(#crops)]
                local amount = math.random(200, 500)
                return {crop = crop, amount = amount}
            end,
            validate = function(playerData, progress, requirements)
                return progress.harvested[requirements.crop] >= requirements.amount
            end
        },
        {
            id = 'milk_production',
            label = 'Dairy Production',
            description = 'Produce {amount}L of milk',
            difficulty = 'medium',
            xpReward = 150,
            leaderboardPoints = 15,
            requirements = function()
                return {amount = math.random(100, 200)}
            end,
            validate = function(playerData, progress, requirements)
                return progress.milk_produced >= requirements.amount
            end
        },
        {
            id = 'egg_collection',
            label = 'Egg Collector',
            description = 'Collect {amount} eggs',
            difficulty = 'easy',
            xpReward = 80,
            leaderboardPoints = 8,
            requirements = function()
                return {amount = math.random(50, 100)}
            end,
            validate = function(playerData, progress, requirements)
                return progress.eggs_collected >= requirements.amount
            end
        },
        {
            id = 'quality_harvest',
            label = 'Quality Farmer',
            description = 'Harvest {amount} {quality} quality crops',
            difficulty = 'hard',
            xpReward = 250,
            leaderboardPoints = 25,
            requirements = function()
                return {amount = math.random(50, 100), quality = 'excellent'}
            end,
            validate = function(playerData, progress, requirements)
                return progress.quality_harvests[requirements.quality] >= requirements.amount
            end
        },
        {
            id = 'animal_care',
            label = 'Animal Caretaker',
            description = 'Care for animals {amount} times',
            difficulty = 'medium',
            xpReward = 120,
            leaderboardPoints = 12,
            requirements = function()
                return {amount = math.random(30, 60)}
            end,
            validate = function(playerData, progress, requirements)
                return (progress.animals_fed + progress.animals_watered) >= requirements.amount
            end
        },
        {
            id = 'breeding_program',
            label = 'Breeding Program',
            description = 'Successfully breed {amount} animals',
            difficulty = 'hard',
            xpReward = 300,
            leaderboardPoints = 30,
            requirements = function()
                return {amount = math.random(3, 6)}
            end,
            validate = function(playerData, progress, requirements)
                return progress.animals_bred >= requirements.amount
            end
        },
        {
            id = 'crop_rotation',
            label = 'Rotation Master',
            description = 'Plant and harvest {amount} different crop types',
            difficulty = 'medium',
            xpReward = 180,
            leaderboardPoints = 18,
            requirements = function()
                return {amount = math.random(3, 5)}
            end,
            validate = function(playerData, progress, requirements)
                local uniqueCrops = 0
                for crop, count in pairs(progress.crops_planted) do
                    if count > 0 and progress.crops_harvested[crop] > 0 then
                        uniqueCrops = uniqueCrops + 1
                    end
                end
                return uniqueCrops >= requirements.amount
            end
        },
    }
}
```

### 6.2 Challenge Database Schema

```sql
CREATE TABLE IF NOT EXISTS `farm_challenges` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `challenge_uuid` VARCHAR(36) NOT NULL UNIQUE,
    `identifier` VARCHAR(50) NOT NULL,
    
    -- Challenge Data
    `challenge_type` VARCHAR(50) NOT NULL,
    `requirements` TEXT NOT NULL, -- JSON
    `progress` TEXT DEFAULT NULL, -- JSON
    
    -- Status
    `is_active` BOOLEAN DEFAULT TRUE,
    `is_completed` BOOLEAN DEFAULT FALSE,
    `completed_at` TIMESTAMP DEFAULT NULL,
    
    -- Rewards
    `xp_reward` INT NOT NULL,
    `leaderboard_points` INT NOT NULL,
    
    -- Metadata
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `expires_at` TIMESTAMP NOT NULL,
    
    INDEX(`identifier`),
    INDEX(`is_active`),
    INDEX(`challenge_type`)
);
```

### 6.3 Challenge Generation System

**Server-Side (server/challenges.lua):**
```lua
-- Runs daily to refresh challenges
CreateThread(function()
    while true do
        Wait(Config.Challenges.refreshInterval * 1000)
        RefreshAllPlayerChallenges()
    end
end)

function RefreshAllPlayerChallenges()
    -- Get all players who need challenge refresh
    local players = MySQL.query.await([[
        SELECT DISTINCT identifier FROM farm_player_data
    ]])
    
    for _, player in ipairs(players) do
        -- Remove expired challenges
        MySQL.update.await([[
            UPDATE farm_challenges 
            SET is_active = FALSE
            WHERE identifier = ? AND expires_at < UNIX_TIMESTAMP() AND is_completed = FALSE
        ]], {player.identifier})
        
        -- Count active challenges
        local activeCount = MySQL.scalar.await([[
            SELECT COUNT(*) FROM farm_challenges
            WHERE identifier = ? AND is_active = TRUE AND is_completed = FALSE
        ]], {player.identifier})
        
        -- Generate new challenges if needed
        local neededChallenges = Config.Challenges.maxActiveChallenges - activeCount
        for i = 1, neededChallenges do
            GenerateChallenge(player.identifier)
        end
    end
end

---@param identifier string
function GenerateChallenge(identifier)
    -- Select random challenge type
    local challengeType = Config.Challenges.types[math.random(#Config.Challenges.types)]
    
    -- Generate requirements
    local requirements = challengeType.requirements()
    
    -- Create challenge
    local challengeUuid = GenerateUUID()
    local expiresAt = os.time() + Config.Challenges.refreshInterval
    
    MySQL.insert.await([[
        INSERT INTO farm_challenges (
            challenge_uuid, identifier, challenge_type, requirements,
            xp_reward, leaderboard_points, expires_at, progress
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        challengeUuid,
        identifier,
        challengeType.id,
        json.encode(requirements),
        challengeType.xpReward,
        challengeType.leaderboardPoints,
        expiresAt,
        json.encode({}) -- Empty progress
    })
end

---@param src number
---@param action string
---@param data table
function UpdateChallengeProgress(src, action, data)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    
    -- Get active challenges
    local challenges = MySQL.query.await([[
        SELECT * FROM farm_challenges
        WHERE identifier = ? AND is_active = TRUE AND is_completed = FALSE
    ]], {player.PlayerData.citizenid})
    
    for _, challenge in ipairs(challenges) do
        local requirements = json.decode(challenge.requirements)
        local progress = json.decode(challenge.progress) or {}
        
        -- Update progress based on action
        if action == 'harvest' then
            progress.harvested = progress.harvested or {}
            progress.harvested[data.crop] = (progress.harvested[data.crop] or 0) + data.amount
            
            if data.quality then
                progress.quality_harvests = progress.quality_harvests or {}
                progress.quality_harvests[data.quality] = (progress.quality_harvests[data.quality] or 0) + data.amount
            end
            
            progress.crops_harvested = progress.crops_harvested or {}
            progress.crops_harvested[data.crop] = (progress.crops_harvested[data.crop] or 0) + 1
        elseif action == 'plant' then
            progress.crops_planted = progress.crops_planted or {}
            progress.crops_planted[data.crop] = (progress.crops_planted[data.crop] or 0) + 1
        elseif action == 'milk' then
            progress.milk_produced = (progress.milk_produced or 0) + data.amount
        elseif action == 'collect_eggs' then
            progress.eggs_collected = (progress.eggs_collected or 0) + data.amount
        elseif action == 'feed_animal' then
            progress.animals_fed = (progress.animals_fed or 0) + 1
        elseif action == 'water_animal' then
            progress.animals_watered = (progress.animals_watered or 0) + 1
        elseif action == 'breed' then
            progress.animals_bred = (progress.animals_bred or 0) + 1
        end
        
        -- Check completion
        local challengeType = GetChallengeTypeById(challenge.challenge_type)
        if challengeType and challengeType.validate(nil, progress, requirements) then
            -- Challenge completed!
            MySQL.update.await([[
                UPDATE farm_challenges
                SET is_completed = TRUE, completed_at = UNIX_TIMESTAMP(), progress = ?
                WHERE challenge_uuid = ?
            ]], {json.encode(progress), challenge.challenge_uuid})
            
            -- Award rewards
            AwardXP(src, 'complete_challenge', challenge.xp_reward)
            
            -- Update leaderboard
            UpdateLeaderboardScore(player.PlayerData.citizenid, challenge.leaderboard_points)
            
            -- Notify player
            lib.notify(src, {
                type = 'success',
                title = 'Challenge Completed!',
                description = challengeType.label..' - +'..challenge.xp_reward..' XP'
            })
        else
            -- Update progress
            MySQL.update.await([[
                UPDATE farm_challenges SET progress = ? WHERE challenge_uuid = ?
            ]], {json.encode(progress), challenge.challenge_uuid})
        end
    end
end

function GetChallengeTypeById(id)
    for _, challengeType in ipairs(Config.Challenges.types) do
        if challengeType.id == id then
            return challengeType
        end
    end
    return nil
end
```

---

## 7. Leaderboard System

### 7.1 Leaderboard Database Schema

```sql
CREATE TABLE IF NOT EXISTS `farm_leaderboard` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(50) NOT NULL UNIQUE,
    `character_name` VARCHAR(100) DEFAULT NULL,
    
    -- Scores
    `total_score` INT DEFAULT 0,
    `weekly_score` INT DEFAULT 0,
    `monthly_score` INT DEFAULT 0,
    
    -- Stats
    `total_harvest_volume` INT DEFAULT 0,
    `total_animal_products` INT DEFAULT 0,
    `challenges_completed` INT DEFAULT 0,
    `excellent_quality_count` INT DEFAULT 0,
    
    -- Timestamps
    `last_updated` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `week_reset` TIMESTAMP DEFAULT NULL,
    `month_reset` TIMESTAMP DEFAULT NULL,
    
    INDEX(`total_score` DESC),
    INDEX(`weekly_score` DESC),
    INDEX(`monthly_score` DESC)
);
```

### 7.2 Leaderboard Update Logic

**Server-Side (server/leaderboard.lua):**
```lua
---@param identifier string
---@param points number
function UpdateLeaderboardScore(identifier, points)
    MySQL.execute.await([[
        INSERT INTO farm_leaderboard (identifier, total_score, weekly_score, monthly_score)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            total_score = total_score + VALUES(total_score),
            weekly_score = weekly_score + VALUES(weekly_score),
            monthly_score = monthly_score + VALUES(monthly_score)
    ]], {identifier, points, points, points})
end

---@param identifier string
---@param stat string
---@param amount number
function UpdateLeaderboardStat(identifier, stat, amount)
    local validStats = {
        'total_harvest_volume',
        'total_animal_products',
        'challenges_completed',
        'excellent_quality_count'
    }
    
    if not table.contains(validStats, stat) then return end
    
    MySQL.execute.await([[
        INSERT INTO farm_leaderboard (identifier, ]]..stat..[[)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE ]]..stat..[[ = ]]..stat..[[ + VALUES(]]..stat..[[)
    ]], {identifier, amount})
end

-- Reset weekly/monthly scores
CreateThread(function()
    while true do
        Wait(3600000) -- Check every hour
        
        local currentTime = os.time()
        
        -- Check for weekly reset (every Monday)
        local lastReset = MySQL.scalar.await('SELECT week_reset FROM farm_leaderboard LIMIT 1')
        if not lastReset or (currentTime - lastReset) >= 604800 then -- 7 days
            MySQL.execute.await('UPDATE farm_leaderboard SET weekly_score = 0, week_reset = UNIX_TIMESTAMP()')
        end
        
        -- Check for monthly reset (1st of month)
        local monthReset = MySQL.scalar.await('SELECT month_reset FROM farm_leaderboard LIMIT 1')
        if not monthReset or os.date('%d', currentTime) == '01' then
            MySQL.execute.await('UPDATE farm_leaderboard SET monthly_score = 0, month_reset = UNIX_TIMESTAMP()')
        end
    end
end)
```

### 7.3 Leaderboard NUI

**Server Callback (server/leaderboard.lua):**
```lua
lib.callback.register('free-farmer:getLeaderboard', function(source, leaderboardType)
    local scoreColumn = 'total_score'
    if leaderboardType == 'weekly' then
        scoreColumn = 'weekly_score'
    elseif leaderboardType == 'monthly' then
        scoreColumn = 'monthly_score'
    end
    
    local leaderboard = MySQL.query.await([[
        SELECT 
            identifier, character_name, ]]..scoreColumn..[[ as score,
            total_harvest_volume, total_animal_products, challenges_completed, excellent_quality_count
        FROM farm_leaderboard
        ORDER BY ]]..scoreColumn..[[ DESC
        LIMIT 50
    ]])
    
    return leaderboard
end)
```

**Client-Side NUI Trigger (client/leaderboard.lua):**
```lua
RegisterCommand('farmleaderboard', function()
    lib.callback('free-farmer:getLeaderboard', false, function(data)
        -- Open NUI with data
        SendNUIMessage({
            action = 'openLeaderboard',
            leaderboard = data
        })
        SetNuiFocus(true, true)
    end, 'total')
end)
```

---

## 8. Processing Chains

### 8.1 Processing Station Configuration

```lua
Config.ProcessingStations = {
    {
        id = 'grain_mill',
        label = 'Grain Mill',
        location = vec3(x, y, z),
        requiredLevel = 5,
        recipes = {
            {
                input = 'wheat',
                inputAmount = 10,
                output = 'flour',
                outputAmount = 8,
                processingTime = 30000, -- 30 seconds
            },
            {
                input = 'corn',
                inputAmount = 10,
                output = 'cornmeal',
                outputAmount = 8,
                processingTime = 30000,
            },
        }
    },
    {
        id = 'cheese_press',
        label = 'Cheese Press',
        location = vec3(x, y, z),
        requiredLevel = 10,
        recipes = {
            {
                input = 'raw_milk',
                inputAmount = 20,
                output = 'cheese_wheel',
                outputAmount = 1,
                processingTime = 60000, -- 1 minute
            },
            {
                input = 'goat_milk',
                inputAmount = 15,
                output = 'goat_cheese',
                outputAmount = 1,
                processingTime = 60000,
            },
        }
    },
    {
        id = 'butter_churn',
        label = 'Butter Churn',
        location = vec3(x, y, z),
        requiredLevel = 8,
        recipes = {
            {
                input = 'raw_milk',
                inputAmount = 10,
                output = 'butter',
                outputAmount = 2,
                processingTime = 45000,
            },
        }
    },
    {
        id = 'cider_press',
        label = 'Cider Press',
        location = vec3(x, y, z),
        requiredLevel = 15,
        recipes = {
            {
                input = 'apple',
                inputAmount = 15,
                output = 'apple_cider',
                outputAmount = 5,
                processingTime = 40000,
            },
        }
    },
    {
        id = 'drying_rack',
        label = 'Drying Rack',
        location = vec3(x, y, z),
        requiredLevel = 12,
        recipes = {
            {
                input = 'cranberries',
                inputAmount = 10,
                output = 'dried_cranberries',
                outputAmount = 6,
                processingTime = 120000, -- 2 minutes
            },
            {
                input = 'cherries',
                inputAmount = 10,
                output = 'dried_cherries',
                outputAmount = 6,
                processingTime = 120000,
            },
        }
    },
    {
        id = 'wool_processor',
        label = 'Wool Processing',
        location = vec3(x, y, z),
        requiredLevel = 20,
        recipes = {
            {
                input = 'raw_wool',
                inputAmount = 5,
                output = 'processed_wool',
                outputAmount = 4,
                processingTime = 50000,
            },
        }
    },
}
```

### 8.2 Processing Station Interactions

**Client-Side (client/processing.lua):**
```lua
CreateThread(function()
    for _, station in ipairs(Config.ProcessingStations) do
        exports.ox_target:addBoxZone({
            coords = station.location,
            size = vec3(2, 2, 2),
            options = {
                {
                    name = 'process_'..station.id,
                    icon = 'fa-solid fa-industry',
                    label = station.label,
                    onSelect = function()
                        TriggerServerEvent('free-farmer:openProcessingMenu', station.id)
                    end
                }
            }
        })
    end
end)
```

**Server-Side (server/processing.lua):**
```lua
RegisterNetEvent('free-farmer:openProcessingMenu', function(stationId)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    
    -- Get station config
    local station = GetProcessingStation(stationId)
    if not station then return end
    
    -- Check level requirement
    local playerData = MySQL.single.await('SELECT level FROM farm_player_data WHERE identifier = ?', {player.PlayerData.citizenid})
    if not playerData or playerData.level < station.requiredLevel then
        return lib.notify(src, {
            type = 'error',
            description = 'Requires Farming Level '..station.requiredLevel
        })
    end
    
    -- Build menu options
    local options = {}
    for _, recipe in ipairs(station.recipes) do
        table.insert(options, {
            title = recipe.output,
            description = recipe.inputAmount..' '..recipe.input..' → '..recipe.outputAmount..' '..recipe.output,
            icon = 'fa-solid fa-arrow-right',
            onSelect = function()
                TriggerServerEvent('free-farmer:processItem', stationId, recipe)
            end
        })
    end
    
    TriggerClientEvent('free-farmer:showProcessingMenu', src, {
        title = station.label,
        options = options
    })
end)

RegisterNetEvent('free-farmer:processItem', function(stationId, recipe)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    
    -- Verify inventory has input
    local hasInput = exports.ox_inventory:Search(src, 'count', recipe.input)
    if hasInput < recipe.inputAmount then
        return lib.notify(src, {
            type = 'error',
            description = 'Need '..recipe.inputAmount..' '..recipe.input
        })
    end
    
    -- Progress bar
    if lib.callback.await('free-farmer:doProcessingProgressBar', src, recipe.processingTime) then
        -- Remove input
        exports.ox_inventory:RemoveItem(src, recipe.input, recipe.inputAmount)
        
        -- Add output
        exports.ox_inventory:AddItem(src, recipe.output, recipe.outputAmount)
        
        -- Award XP
        AwardXP(src, 'process_item')
        
        lib.notify(src, {
            type = 'success',
            description = 'Processed '..recipe.outputAmount..' '..recipe.output
        })
    end
end)
```

---

## 9. Performance Optimization Strategy

### 9.1 Client Optimization

**Idle Performance (0.00ms target):**
- No threads running when player not at farm
- Zone-based activation via ox_lib zones
- All entity spawning server-side (native streaming)
- No constant distance checks or loops

**Active Farming (<0.08ms target):**
- Minimal ox_target interactions (pre-cached zones)
- State bag listeners for entity updates (not polling)
- Batched UI updates (not per-frame)

### 9.2 Server Optimization

**Growth/Health Tick System:**
- Single thread for all fields (batch database query)
- Single thread for all animals (batch database query)
- Configurable intervals (default: 5 min crops, 1 hour animals)
- No per-entity loops

**Entity Management:**
- Lazy spawning (only when players in zone)
- Cleanup when zone empty
- State bags for synchronization (low network overhead)

**Database Optimization:**
- Indexed queries on frequently accessed columns
- Batched writes where possible
- Connection pooling via oxmysql
- Prepared statements for all queries

### 9.3 Network Optimization

**Minimize Events:**
- Use state bags for entity state sync
- Use callbacks for server-to-client requests
- Batch notifications (don't spam)

**Entity Streaming:**
- Server-spawned entities use native GTA streaming
- Client doesn't create/delete entities (server handles)
- Automatic network optimization via FiveM netcode

---

## 10. Database Schema (Complete)

```sql
-- Field State
CREATE TABLE IF NOT EXISTS `farm_fields` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `field_id` VARCHAR(50) NOT NULL UNIQUE,
    `farm_zone` VARCHAR(50) NOT NULL,
    `crop_type` VARCHAR(50) DEFAULT NULL,
    `growth_stage` INT DEFAULT 0,
    `planted_at` INT DEFAULT NULL,
    `stage_updated_at` INT DEFAULT NULL,
    `soil_quality` INT DEFAULT 100,
    `last_harvest` INT DEFAULT NULL,
    `last_crop` VARCHAR(50) DEFAULT NULL,
    `last_crop_family` VARCHAR(50) DEFAULT NULL,
    `times_harvested` INT DEFAULT 0,
    `consecutive_same_crop` INT DEFAULT 0,
    `weather_quality_modifier` FLOAT DEFAULT 1.0,
    `good_weather_ticks` INT DEFAULT 0,
    `bad_weather_ticks` INT DEFAULT 0,
    `fertilized` BOOLEAN DEFAULT FALSE,
    `fertilizer_quality` VARCHAR(20) DEFAULT NULL,
    `last_fertilized` INT DEFAULT NULL,
    `created_at` INT DEFAULT UNIX_TIMESTAMP(),
    `updated_at` INT DEFAULT UNIX_TIMESTAMP(),
    INDEX(`field_id`),
    INDEX(`farm_zone`),
    INDEX(`crop_type`)
);

-- Animal Data
CREATE TABLE IF NOT EXISTS `farm_animals` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `animal_uuid` VARCHAR(36) NOT NULL UNIQUE,
    `owner_identifier` VARCHAR(50) NOT NULL,
    `owner_name` VARCHAR(100) DEFAULT NULL,
    `animal_type` VARCHAR(50) NOT NULL,
    `animal_name` VARCHAR(100) DEFAULT NULL,
    `gender` ENUM('male', 'female') NOT NULL,
    `farm_zone` VARCHAR(50) NOT NULL,
    `pen_id` VARCHAR(50) DEFAULT NULL,
    `is_stored` BOOLEAN DEFAULT FALSE,
    `stored_at` INT DEFAULT NULL,
    `growth_stage` VARCHAR(50) NOT NULL,
    `age` INT DEFAULT 0,
    `quality` VARCHAR(50) DEFAULT 'average',
    `health` INT DEFAULT 100,
    `last_fed` INT DEFAULT NULL,
    `last_watered` INT DEFAULT NULL,
    `is_sick` BOOLEAN DEFAULT FALSE,
    `sickness_type` VARCHAR(50) DEFAULT NULL,
    `production_ready` BOOLEAN DEFAULT FALSE,
    `last_produced` INT DEFAULT NULL,
    `total_production` INT DEFAULT 0,
    `is_pregnant` BOOLEAN DEFAULT FALSE,
    `pregnancy_start` INT DEFAULT NULL,
    `pregnancy_father_uuid` VARCHAR(36) DEFAULT NULL,
    `last_bred` INT DEFAULT NULL,
    `breeding_quality` VARCHAR(50) DEFAULT NULL,
    `created_at` INT DEFAULT UNIX_TIMESTAMP(),
    `updated_at` INT DEFAULT UNIX_TIMESTAMP(),
    INDEX(`owner_identifier`),
    INDEX(`farm_zone`),
    INDEX(`pen_id`),
    INDEX(`is_stored`),
    INDEX(`animal_type`),
    INDEX(`gender`)
);

-- Player XP & Progress
CREATE TABLE IF NOT EXISTS `farm_player_data` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(50) NOT NULL UNIQUE,
    `character_name` VARCHAR(100) DEFAULT NULL,
    `xp` INT DEFAULT 0,
    `level` INT DEFAULT 1,
    `total_crops_harvested` INT DEFAULT 0,
    `total_crops_planted` INT DEFAULT 0,
    `total_animals_cared_for` INT DEFAULT 0,
    `total_production_collected` INT DEFAULT 0,
    `total_challenges_completed` INT DEFAULT 0,
    `unlocked_crops` TEXT DEFAULT NULL,
    `unlocked_animals` TEXT DEFAULT NULL,
    `created_at` INT DEFAULT UNIX_TIMESTAMP(),
    `updated_at` INT DEFAULT UNIX_TIMESTAMP(),
    INDEX(`identifier`),
    INDEX(`level`)
);

-- Challenges
CREATE TABLE IF NOT EXISTS `farm_challenges` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `challenge_uuid` VARCHAR(36) NOT NULL UNIQUE,
    `identifier` VARCHAR(50) NOT NULL,
    `challenge_type` VARCHAR(50) NOT NULL,
    `requirements` TEXT NOT NULL,
    `progress` TEXT DEFAULT NULL,
    `is_active` BOOLEAN DEFAULT TRUE,
    `is_completed` BOOLEAN DEFAULT FALSE,
    `completed_at` INT DEFAULT NULL,
    `xp_reward` INT NOT NULL,
    `leaderboard_points` INT NOT NULL,
    `created_at` INT DEFAULT UNIX_TIMESTAMP(),
    `expires_at` INT NOT NULL,
    INDEX(`identifier`),
    INDEX(`is_active`),
    INDEX(`challenge_type`)
);

-- Leaderboard
CREATE TABLE IF NOT EXISTS `farm_leaderboard` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(50) NOT NULL UNIQUE,
    `character_name` VARCHAR(100) DEFAULT NULL,
    `total_score` INT DEFAULT 0,
    `weekly_score` INT DEFAULT 0,
    `monthly_score` INT DEFAULT 0,
    `total_harvest_volume` INT DEFAULT 0,
    `total_animal_products` INT DEFAULT 0,
    `challenges_completed` INT DEFAULT 0,
    `excellent_quality_count` INT DEFAULT 0,
    `last_updated` INT DEFAULT UNIX_TIMESTAMP(),
    `week_reset` INT DEFAULT NULL,
    `month_reset` INT DEFAULT NULL,
    INDEX(`total_score` DESC),
    INDEX(`weekly_score` DESC),
    INDEX(`monthly_score` DESC)
);
```

---

## 11. File Structure

```
free-farmer/
├── fxmanifest.lua
├── config/
│   ├── shared.lua          -- Crops, animals, XP, challenges, processing
│   ├── client.lua          -- Client-specific settings
│   └── server.lua          -- Server-specific settings (growth intervals, etc.)
├── client/
│   ├── main.lua            -- Initialization, zone management
│   ├── fields.lua          -- Field interactions, plowing, planting, harvesting
│   ├── animals.lua         -- Individual animal interactions
│   ├── equipment.lua       -- Tractor/implement system
│   ├── processing.lua      -- Processing station interactions
│   ├── challenges.lua      -- Challenge UI
│   └── leaderboard.lua     -- Leaderboard NUI
├── server/
│   ├── main.lua            -- Initialization
│   ├── fields.lua          -- Field state, growth ticks, spawning
│   ├── animals.lua         -- Animal spawning, health/needs system, storage
│   ├── animals_ai.lua      -- AI behavior system (modular)
│   ├── breeding.lua        -- Breeding & pregnancy system
│   ├── weather.lua         -- renewed-weathersync integration
│   ├── xp.lua              -- XP calculations, unlocks
│   ├── challenges.lua      -- Challenge generation, validation
│   ├── leaderboard.lua     -- Leaderboard tracking
│   ├── processing.lua      -- Processing station logic
│   └── utils.lua           -- Helper functions (polygon math, UUID generation, etc.)
├── sql/
│   └── install.sql         -- Database schema
└── web/                    -- Leaderboard NUI (HTML/CSS/JS)
    ├── index.html
    ├── style.css
    └── script.js
```

---

## 12. Phase Development Plan

### **Phase 1: Foundation (Weeks 1-2)**
**Deliverables:**
- Database schema implementation
- Farm zone configuration (6 locations with fields/pens)
- Field system: plowing, planting, growth, harvest (4 crops: corn, soybeans, wheat, hay)
- Crop prop spawning/despawning
- Basic XP system
- Soil quality tracking

### **Phase 2: Crop Expansion & Weather (Weeks 3-4)**
**Deliverables:**
- Remaining 6 crops (potatoes, pumpkins, cranberries, cherries, sugarbeets, apples, blueberries)
- Weather integration (renewed-weathersync)
- Crop rotation bonuses
- Equipment system (tractors with hybrid mode/attachment approach)
- Fertilizer system

### **Phase 3: Livestock Foundation (Weeks 5-6)**
**Deliverables:**
- Animal database & spawning system
- 3 animal types fully implemented: Cows, Chickens, Sheep
- AI behavior system (grazing, pecking, roaming)
- Individual animal interactions (feed, water, milk, collect eggs, shear)
- Animal health & needs system
- Storage system (barn)

### **Phase 4: Livestock Expansion & Breeding (Weeks 7-8)**
**Deliverables:**
- Remaining 3 animals: Turkeys, Pigs, Goats
- Breeding system (mating, pregnancy, birth)
- Quality/genetics system
- Animal growth stages
- Pen/herd management (feed troughs, bulk actions)

### **Phase 5: Progression & Polish (Weeks 9-10)**
**Deliverables:**
- Challenge system fully implemented
- Leaderboard NUI
- Processing chains (6 stations)
- XP unlocks polished
- Bug fixes, optimization
- Documentation

### **Total Timeline: 10 weeks**

---

## End of Technical Specification Document

This document serves as the complete technical blueprint for the **free-farmer** script. All systems have been designed with performance, realism, and modularity in mind. Development should proceed in phases to ensure each system is thoroughly tested before moving to the next.

**Next Steps:**
1. Review and approve this technical specification
2. Set up project repository structure
3. Begin Phase 1 implementation (database + field system)
