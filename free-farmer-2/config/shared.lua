--[[
    free-farmer — Shared Configuration
    All crop, animal, farm zone, and system configs live here.
    Phase 2: Full crop roster (11 crops), harvest methods, perennial support, garden planters
]]

Config = {}

Config.Debug = false

-- =============================================================================
-- TIMING
-- =============================================================================

Config.GrowthTickInterval = 300        -- seconds between crop growth checks (5 min)
Config.PlanterGrowthTickInterval = 300  -- seconds between planter growth checks
Config.AnimalHealthTickInterval = 3600  -- seconds between animal health checks (1 hour)

-- =============================================================================
-- FARM ZONES (Grapeseed area placeholders — replace with your coordinates)
-- =============================================================================

Config.FarmZones = {
    {
        id = 'farm_grapeseed',
        label = 'Grapeseed Farm',
        blip = {
            coords = vec3(2015.0, 4785.0, 41.0),
            sprite = 480,
            color = 2,
            scale = 0.8,
            shortRange = true,
        },
        zoneRadius = 250.0,

        fields = {
            {
                id = 'grapeseed_field_a',
                label = 'North Field',
                fieldType = 'large',
                polygon = {
                    vec3(1960.0, 4820.0, 41.5),
                    vec3(2060.0, 4820.0, 41.5),
                    vec3(2060.0, 4870.0, 41.5),
                    vec3(1960.0, 4870.0, 41.5),
                },
                size = 5000.0,
                interactionPoint = vec4(1965.0, 4845.0, 41.5, 90.0),
                propSpawnPoints = {
                    vec4(1975.0, 4830.0, 41.5, 0.0),
                    vec4(1995.0, 4830.0, 41.5, 0.0),
                    vec4(2015.0, 4830.0, 41.5, 0.0),
                    vec4(2035.0, 4830.0, 41.5, 0.0),
                    vec4(2055.0, 4830.0, 41.5, 0.0),
                    vec4(1975.0, 4855.0, 41.5, 0.0),
                    vec4(1995.0, 4855.0, 41.5, 0.0),
                    vec4(2015.0, 4855.0, 41.5, 0.0),
                    vec4(2035.0, 4855.0, 41.5, 0.0),
                    vec4(2055.0, 4855.0, 41.5, 0.0),
                },
            },
            {
                id = 'grapeseed_field_b',
                label = 'South Field',
                fieldType = 'large',
                polygon = {
                    vec3(1960.0, 4740.0, 41.0),
                    vec3(2060.0, 4740.0, 41.0),
                    vec3(2060.0, 4790.0, 41.0),
                    vec3(1960.0, 4790.0, 41.0),
                },
                size = 5000.0,
                interactionPoint = vec4(1965.0, 4765.0, 41.0, 90.0),
                propSpawnPoints = {
                    vec4(1975.0, 4750.0, 41.0, 0.0),
                    vec4(1995.0, 4750.0, 41.0, 0.0),
                    vec4(2015.0, 4750.0, 41.0, 0.0),
                    vec4(2035.0, 4750.0, 41.0, 0.0),
                    vec4(2055.0, 4750.0, 41.0, 0.0),
                    vec4(1975.0, 4775.0, 41.0, 0.0),
                    vec4(1995.0, 4775.0, 41.0, 0.0),
                    vec4(2015.0, 4775.0, 41.0, 0.0),
                    vec4(2035.0, 4775.0, 41.0, 0.0),
                    vec4(2055.0, 4775.0, 41.0, 0.0),
                },
            },
            {
                id = 'grapeseed_field_c',
                label = 'Orchard Plot',
                fieldType = 'small',
                polygon = {
                    vec3(2070.0, 4790.0, 41.0),
                    vec3(2120.0, 4790.0, 41.0),
                    vec3(2120.0, 4830.0, 41.0),
                    vec3(2070.0, 4830.0, 41.0),
                },
                size = 2000.0,
                interactionPoint = vec4(2075.0, 4810.0, 41.0, 90.0),
                propSpawnPoints = {
                    vec4(2080.0, 4800.0, 41.0, 0.0),
                    vec4(2095.0, 4800.0, 41.0, 0.0),
                    vec4(2110.0, 4800.0, 41.0, 0.0),
                    vec4(2080.0, 4820.0, 41.0, 0.0),
                    vec4(2095.0, 4820.0, 41.0, 0.0),
                    vec4(2110.0, 4820.0, 41.0, 0.0),
                },
            },
        },

        equipment_shed = vec3(2010.0, 4800.0, 41.5),
        storage_barn = vec3(2020.0, 4800.0, 41.5),
        animal_barn = vec3(2030.0, 4800.0, 41.5),

        pens = {
            {
                id = 'grapeseed_pen_cow',
                label = 'Cattle Pen',
                animalType = 'cow',
                polygon = {
                    vec3(2070.0, 4840.0, 41.0),
                    vec3(2120.0, 4840.0, 41.0),
                    vec3(2120.0, 4870.0, 41.0),
                    vec3(2070.0, 4870.0, 41.0),
                },
                wanderRadius = 12.0,
                feedTrough = vec3(2075.0, 4845.0, 41.0),
                waterTrough = vec3(2115.0, 4865.0, 41.0),
            },
            {
                id = 'grapeseed_pen_chicken',
                label = 'Chicken Coop',
                animalType = 'chicken',
                polygon = {
                    vec3(2070.0, 4875.0, 41.0),
                    vec3(2100.0, 4875.0, 41.0),
                    vec3(2100.0, 4895.0, 41.0),
                    vec3(2070.0, 4895.0, 41.0),
                },
                wanderRadius = 8.0,
                feedTrough = vec3(2075.0, 4880.0, 41.0),
                waterTrough = vec3(2095.0, 4890.0, 41.0),
            },
        },
    },
    {
        id = 'farm_oneil',
        label = "O'Neil Ranch",
        blip = {
            coords = vec3(2440.0, 4970.0, 46.0),
            sprite = 480,
            color = 2,
            scale = 0.8,
            shortRange = true,
        },
        zoneRadius = 200.0,

        fields = {
            {
                id = 'oneil_field_a',
                label = 'West Field',
                fieldType = 'large',
                polygon = {
                    vec3(2380.0, 4940.0, 45.5),
                    vec3(2460.0, 4940.0, 45.5),
                    vec3(2460.0, 4990.0, 45.5),
                    vec3(2380.0, 4990.0, 45.5),
                },
                size = 4000.0,
                interactionPoint = vec4(2385.0, 4965.0, 45.5, 90.0),
                propSpawnPoints = {
                    vec4(2395.0, 4950.0, 45.5, 0.0),
                    vec4(2415.0, 4950.0, 45.5, 0.0),
                    vec4(2435.0, 4950.0, 45.5, 0.0),
                    vec4(2455.0, 4950.0, 45.5, 0.0),
                    vec4(2395.0, 4975.0, 45.5, 0.0),
                    vec4(2415.0, 4975.0, 45.5, 0.0),
                    vec4(2435.0, 4975.0, 45.5, 0.0),
                    vec4(2455.0, 4975.0, 45.5, 0.0),
                },
            },
            {
                id = 'oneil_field_b',
                label = 'East Meadow',
                fieldType = 'medium',
                polygon = {
                    vec3(2470.0, 4940.0, 46.0),
                    vec3(2530.0, 4940.0, 46.0),
                    vec3(2530.0, 4990.0, 46.0),
                    vec3(2470.0, 4990.0, 46.0),
                },
                size = 3000.0,
                interactionPoint = vec4(2475.0, 4965.0, 46.0, 90.0),
                propSpawnPoints = {
                    vec4(2480.0, 4950.0, 46.0, 0.0),
                    vec4(2500.0, 4950.0, 46.0, 0.0),
                    vec4(2520.0, 4950.0, 46.0, 0.0),
                    vec4(2480.0, 4975.0, 46.0, 0.0),
                    vec4(2500.0, 4975.0, 46.0, 0.0),
                    vec4(2520.0, 4975.0, 46.0, 0.0),
                },
            },
        },

        equipment_shed = vec3(2450.0, 4935.0, 46.0),
        storage_barn = vec3(2455.0, 4930.0, 46.0),
        animal_barn = vec3(2460.0, 4930.0, 46.0),

        pens = {
            {
                id = 'oneil_pen_pig',
                label = 'Pig Pen',
                animalType = 'pig',
                polygon = {
                    vec3(2470.0, 4995.0, 46.0),
                    vec3(2520.0, 4995.0, 46.0),
                    vec3(2520.0, 5020.0, 46.0),
                    vec3(2470.0, 5020.0, 46.0),
                },
                wanderRadius = 10.0,
                feedTrough = vec3(2475.0, 5000.0, 46.0),
                waterTrough = vec3(2515.0, 5015.0, 46.0),
            },
        },
    },
}

-- =============================================================================
-- CROPS
-- =============================================================================
-- Props are GTA V vanilla crop/vegetation models. Replace with custom models if available.
-- fieldTypes: which field sizes this crop can be planted in
-- Weather preferences: multiplier applied per growth tick (1.0 = neutral)

Config.Crops = {
    -- =========================================================================
    -- ROW CROPS (large/medium fields, standard harvest)
    -- =========================================================================

    corn = {
        label = 'Corn',
        seedItem = 'corn_seed',
        harvestItem = 'corn',
        unlockLevel = 1,
        fieldTypes = { 'large', 'medium' },
        planterAllowed = true,
        harvestMethod = 'standard',
        isPerennial = false,

        growthStages = {
            { stage = 1, label = 'Planted',     duration = 3600,  prop = 'prop_plant_fern_01a' },
            { stage = 2, label = 'Sprouting',   duration = 5400,  prop = 'prop_veg_crop_03_leaf' },
            { stage = 3, label = 'Growing',     duration = 7200,  prop = 'prop_veg_crop_04_leaf' },
            { stage = 4, label = 'Maturing',    duration = 5400,  prop = 'prop_veg_crop_05' },
            { stage = 5, label = 'Harvestable', duration = nil,   prop = 'prop_veg_crop_06' },
        },

        baseYield = { min = 80, max = 120 },
        planterYield = { min = 3, max = 6 },
        cropFamily = 'grain',

        weatherPreferences = {
            clear = 1.0, overcast = 0.98, rain = 1.1,
            thunder = 0.85, foggy = 0.95, snow = 0.7, blizzard = 0.5,
        },

        qualityThresholds = {
            poor = 0.0, average = 0.70, good = 0.85, excellent = 0.95,
        },
    },

    soybeans = {
        label = 'Soybeans',
        seedItem = 'soybean_seed',
        harvestItem = 'soybeans',
        unlockLevel = 1,
        fieldTypes = { 'large' },
        planterAllowed = true,
        harvestMethod = 'standard',
        isPerennial = false,

        growthStages = {
            { stage = 1, label = 'Planted',     duration = 3000,  prop = 'prop_plant_fern_01a' },
            { stage = 2, label = 'Sprouting',   duration = 4800,  prop = 'prop_veg_crop_03_leaf' },
            { stage = 3, label = 'Growing',     duration = 6000,  prop = 'prop_veg_crop_04_leaf' },
            { stage = 4, label = 'Maturing',    duration = 4200,  prop = 'prop_bush_med_01' },
            { stage = 5, label = 'Harvestable', duration = nil,   prop = 'prop_veg_crop_05' },
        },

        baseYield = { min = 60, max = 90 },
        planterYield = { min = 2, max = 5 },
        cropFamily = 'legume',

        weatherPreferences = {
            clear = 1.0, overcast = 1.0, rain = 1.15,
            thunder = 0.8, foggy = 0.95, snow = 0.6, blizzard = 0.4,
        },

        qualityThresholds = {
            poor = 0.0, average = 0.70, good = 0.85, excellent = 0.95,
        },
    },

    wheat = {
        label = 'Wheat',
        seedItem = 'wheat_seed',
        harvestItem = 'wheat',
        unlockLevel = 1,
        fieldTypes = { 'large', 'medium' },
        planterAllowed = true,
        harvestMethod = 'standard',
        isPerennial = false,

        growthStages = {
            { stage = 1, label = 'Planted',     duration = 3200,  prop = 'prop_plant_fern_01a' },
            { stage = 2, label = 'Sprouting',   duration = 5000,  prop = 'prop_veg_crop_03_leaf' },
            { stage = 3, label = 'Growing',     duration = 6600,  prop = 'prop_veg_crop_04_leaf' },
            { stage = 4, label = 'Maturing',    duration = 5000,  prop = 'prop_veg_crop_05' },
            { stage = 5, label = 'Harvestable', duration = nil,   prop = 'prop_veg_crop_06' },
        },

        baseYield = { min = 70, max = 110 },
        planterYield = { min = 2, max = 4 },
        cropFamily = 'grain',

        weatherPreferences = {
            clear = 1.02, overcast = 1.0, rain = 1.08,
            thunder = 0.88, foggy = 0.98, snow = 0.75, blizzard = 0.55,
        },

        qualityThresholds = {
            poor = 0.0, average = 0.70, good = 0.85, excellent = 0.95,
        },
    },

    hay = {
        label = 'Hay',
        seedItem = 'hay_seed',
        harvestItem = 'hay_bale',
        unlockLevel = 1,
        fieldTypes = { 'large', 'medium' },
        planterAllowed = false,
        harvestMethod = 'standard',
        isPerennial = false,

        growthStages = {
            { stage = 1, label = 'Planted',     duration = 2400,  prop = 'prop_plant_fern_01a' },
            { stage = 2, label = 'Sprouting',   duration = 3600,  prop = 'prop_veg_crop_03_leaf' },
            { stage = 3, label = 'Growing',     duration = 4800,  prop = 'prop_veg_crop_04_leaf' },
            { stage = 4, label = 'Harvestable', duration = nil,   prop = 'prop_veg_crop_05' },
        },

        baseYield = { min = 50, max = 80 },
        planterYield = { min = 0, max = 0 },
        cropFamily = 'grain',

        weatherPreferences = {
            clear = 1.1, overcast = 1.0, rain = 1.05,
            thunder = 0.75, foggy = 0.9, snow = 0.6, blizzard = 0.4,
        },

        qualityThresholds = {
            poor = 0.0, average = 0.70, good = 0.85, excellent = 0.95,
        },
    },

    potatoes = {
        label = 'Potatoes',
        seedItem = 'potato_seed',
        harvestItem = 'potato',
        unlockLevel = 3,
        fieldTypes = { 'large', 'medium' },
        planterAllowed = true,
        harvestMethod = 'standard',
        isPerennial = false,

        growthStages = {
            { stage = 1, label = 'Planted',     duration = 3600,  prop = 'prop_plant_fern_01a' },
            { stage = 2, label = 'Sprouting',   duration = 5400,  prop = 'prop_veg_crop_03_leaf' },
            { stage = 3, label = 'Growing',     duration = 7200,  prop = 'prop_bush_med_01' },
            { stage = 4, label = 'Maturing',    duration = 5400,  prop = 'prop_veg_crop_04_leaf' },
            { stage = 5, label = 'Harvestable', duration = nil,   prop = 'prop_veg_crop_05' },
        },

        baseYield = { min = 100, max = 150 },
        planterYield = { min = 4, max = 8 },
        cropFamily = 'vegetable',

        weatherPreferences = {
            clear = 0.95, overcast = 1.05, rain = 1.12,
            thunder = 0.85, foggy = 1.0, snow = 0.5, blizzard = 0.3,
        },

        qualityThresholds = {
            poor = 0.0, average = 0.70, good = 0.85, excellent = 0.95,
        },
    },

    pumpkins = {
        label = 'Pumpkins',
        seedItem = 'pumpkin_seed',
        harvestItem = 'pumpkin',
        unlockLevel = 5,
        fieldTypes = { 'medium' },
        planterAllowed = true,
        harvestMethod = 'standard',
        isPerennial = false,

        growthStages = {
            { stage = 1, label = 'Planted',     duration = 4200,  prop = 'prop_plant_fern_01a' },
            { stage = 2, label = 'Sprouting',   duration = 6000,  prop = 'prop_veg_crop_03_leaf' },
            { stage = 3, label = 'Vining',      duration = 8400,  prop = 'prop_bush_med_01' },
            { stage = 4, label = 'Fruiting',    duration = 6000,  prop = 'prop_veg_crop_04_leaf' },
            { stage = 5, label = 'Harvestable', duration = nil,   prop = 'prop_veg_crop_05' },
        },

        baseYield = { min = 30, max = 50 },
        planterYield = { min = 1, max = 2 },
        cropFamily = 'vegetable',

        weatherPreferences = {
            clear = 1.0, overcast = 1.02, rain = 1.1,
            thunder = 0.8, foggy = 0.95, snow = 0.4, blizzard = 0.2,
        },

        qualityThresholds = {
            poor = 0.0, average = 0.70, good = 0.85, excellent = 0.95,
        },
    },

    sugarbeets = {
        label = 'Sugar Beets',
        seedItem = 'sugarbeet_seed',
        harvestItem = 'sugar_beet',
        unlockLevel = 8,
        fieldTypes = { 'large', 'medium' },
        planterAllowed = true,
        harvestMethod = 'standard',
        isPerennial = false,

        growthStages = {
            { stage = 1, label = 'Planted',     duration = 3600,  prop = 'prop_plant_fern_01a' },
            { stage = 2, label = 'Sprouting',   duration = 5400,  prop = 'prop_veg_crop_03_leaf' },
            { stage = 3, label = 'Growing',     duration = 7800,  prop = 'prop_veg_crop_04_leaf' },
            { stage = 4, label = 'Maturing',    duration = 6000,  prop = 'prop_bush_med_01' },
            { stage = 5, label = 'Harvestable', duration = nil,   prop = 'prop_veg_crop_05' },
        },

        baseYield = { min = 90, max = 140 },
        planterYield = { min = 3, max = 6 },
        cropFamily = 'vegetable',

        weatherPreferences = {
            clear = 1.0, overcast = 1.02, rain = 1.08,
            thunder = 0.88, foggy = 0.98, snow = 0.7, blizzard = 0.45,
        },

        qualityThresholds = {
            poor = 0.0, average = 0.70, good = 0.85, excellent = 0.95,
        },
    },

    -- =========================================================================
    -- FRUIT / BUSH CROPS (small fields, special harvest, perennial)
    -- =========================================================================

    blueberries = {
        label = 'Blueberries',
        seedItem = 'blueberry_bush',
        harvestItem = 'blueberries',
        unlockLevel = 10,
        fieldTypes = { 'small' },
        planterAllowed = true,
        harvestMethod = 'bush_pick',     -- Hand-pick from bush
        isPerennial = true,              -- Regrows after harvest
        regrowthStage = 3,               -- Reverts to this stage after harvest

        growthStages = {
            { stage = 1, label = 'Planted',     duration = 7200,  prop = 'prop_bush_med_01' },
            { stage = 2, label = 'Leafing',     duration = 10800, prop = 'prop_bush_lrg_02' },
            { stage = 3, label = 'Established', duration = 14400, prop = 'prop_bush_lrg_04b' },
            { stage = 4, label = 'Fruiting',    duration = 10800, prop = 'prop_bush_lrg_04c' },
            { stage = 5, label = 'Harvestable', duration = nil,   prop = 'prop_bush_lrg_04d' },
        },

        baseYield = { min = 35, max = 60 },
        planterYield = { min = 2, max = 4 },
        cropFamily = 'fruit',

        weatherPreferences = {
            clear = 1.0, overcast = 1.05, rain = 1.12,
            thunder = 0.85, foggy = 1.08, snow = 0.88, blizzard = 0.6,
        },

        qualityThresholds = {
            poor = 0.0, average = 0.70, good = 0.85, excellent = 0.95,
        },
    },

    cranberries = {
        label = 'Cranberries',
        seedItem = 'cranberry_plant',
        harvestItem = 'cranberries',
        unlockLevel = 15,
        fieldTypes = { 'small', 'medium' },
        planterAllowed = false,           -- Cranberries need water flooding
        harvestMethod = 'water_flood',    -- Special flooding harvest mechanic
        isPerennial = true,
        regrowthStage = 3,

        growthStages = {
            { stage = 1, label = 'Planted',     duration = 7200,  prop = 'prop_bush_med_01' },
            { stage = 2, label = 'Vining',      duration = 10800, prop = 'prop_bush_lrg_02' },
            { stage = 3, label = 'Established', duration = 14400, prop = 'prop_bush_lrg_04b' },
            { stage = 4, label = 'Fruiting',    duration = 12000, prop = 'prop_bush_lrg_04c' },
            { stage = 5, label = 'Harvestable', duration = nil,   prop = 'prop_bush_lrg_04d' },
        },

        baseYield = { min = 50, max = 80 },
        planterYield = { min = 0, max = 0 },
        cropFamily = 'fruit',

        weatherPreferences = {
            clear = 0.98, overcast = 1.05, rain = 1.15,
            thunder = 0.9, foggy = 1.08, snow = 0.85, blizzard = 0.55,
        },

        qualityThresholds = {
            poor = 0.0, average = 0.70, good = 0.85, excellent = 0.95,
        },
    },

    -- =========================================================================
    -- ORCHARD / TREE CROPS (small fields, tree pick, perennial)
    -- =========================================================================

    apples = {
        label = 'Apples',
        seedItem = 'apple_tree',
        harvestItem = 'apple',
        unlockLevel = 18,
        fieldTypes = { 'small', 'medium' },
        planterAllowed = false,           -- Trees can't grow in planters
        harvestMethod = 'tree_pick',      -- Pick from tree
        isPerennial = true,
        regrowthStage = 2,                -- Trees stay established, just regrow fruit

        growthStages = {
            { stage = 1, label = 'Sapling',     duration = 14400, prop = 'prop_plant_palm_01a' },
            { stage = 2, label = 'Young Tree',  duration = 21600, prop = 'prop_tree_birch_01' },
            { stage = 3, label = 'Flowering',   duration = 14400, prop = 'prop_tree_birch_02' },
            { stage = 4, label = 'Fruiting',    duration = 10800, prop = 'prop_tree_birch_03' },
            { stage = 5, label = 'Harvestable', duration = nil,   prop = 'prop_tree_birch_03b' },
        },

        baseYield = { min = 50, max = 85 },
        planterYield = { min = 0, max = 0 },
        cropFamily = 'fruit',

        weatherPreferences = {
            clear = 1.08, overcast = 1.0, rain = 1.05,
            thunder = 0.8, foggy = 0.98, snow = 0.92, blizzard = 0.65,
        },

        qualityThresholds = {
            poor = 0.0, average = 0.70, good = 0.85, excellent = 0.95,
        },
    },

    cherries = {
        label = 'Tart Cherries',
        seedItem = 'cherry_tree',
        harvestItem = 'cherries',
        unlockLevel = 20,
        fieldTypes = { 'small' },
        planterAllowed = false,
        harvestMethod = 'tree_pick',
        isPerennial = true,
        regrowthStage = 2,

        growthStages = {
            { stage = 1, label = 'Sapling',     duration = 14400, prop = 'prop_plant_palm_01a' },
            { stage = 2, label = 'Young Tree',  duration = 21600, prop = 'prop_tree_birch_01' },
            { stage = 3, label = 'Blossoming',  duration = 14400, prop = 'prop_tree_birch_02' },
            { stage = 4, label = 'Fruiting',    duration = 12000, prop = 'prop_tree_birch_03' },
            { stage = 5, label = 'Harvestable', duration = nil,   prop = 'prop_tree_birch_03b' },
        },

        baseYield = { min = 40, max = 70 },
        planterYield = { min = 0, max = 0 },
        cropFamily = 'fruit',

        weatherPreferences = {
            clear = 1.1, overcast = 1.0, rain = 1.05,
            thunder = 0.75, foggy = 0.95, snow = 0.9, blizzard = 0.6,
        },

        qualityThresholds = {
            poor = 0.0, average = 0.70, good = 0.85, excellent = 0.95,
        },
    },
}

-- =============================================================================
-- GARDEN PLANTER
-- =============================================================================
-- Portable planter box that players can place anywhere and grow individual crops.

Config.Planter = {
    item = 'garden_planter',                -- Item required to place a planter
    prop = 'prop_flowerpot_01a',            -- Base prop for empty planter
    maxPerPlayer = 5,                       -- Max planters per player
    pickupEnabled = true,                   -- Can players pick up their planter?
    interactionDistance = 1.5,              -- ox_target distance
    placementMaxDistance = 3.0,             -- Max distance from player when placing

    -- Growth is slightly slower than field crops (individual attention)
    growthTimeMultiplier = 1.2,

    -- Planter-specific crop props (smaller variants for the pot)
    -- Falls back to the crop's normal props if not defined here
    propOverrides = {
        -- cropType = { [stage] = 'prop_name' }
    },
}

-- =============================================================================
-- HARVEST METHODS
-- =============================================================================
-- Defines animation, duration, and label for each harvest method type.

Config.HarvestMethods = {
    standard = {
        label = 'Harvesting crop...',
        duration = 10000,
        anim = { dict = 'anim@mp_snowball', name = 'pickup_snowball' },
    },
    tree_pick = {
        label = 'Picking from tree...',
        duration = 12000,
        anim = { dict = 'amb@prop_human_movie_bulb@base', name = 'base' },
    },
    bush_pick = {
        label = 'Picking berries...',
        duration = 10000,
        anim = { dict = 'amb@world_human_gardener_plant@male@base', name = 'base' },
    },
    water_flood = {
        label = 'Flooding and collecting...',
        duration = 15000,
        anim = { dict = 'amb@world_human_gardener_plant@male@base', name = 'base' },
    },
}

-- =============================================================================
-- XP & PROGRESSION
-- =============================================================================

Config.XP = {
    maxLevel = 100,

    actions = {
        plow_field      = 5,
        plant_seeds     = 8,
        harvest_crop    = 15,
        plant_planter   = 4,
        harvest_planter = 8,
        feed_animal     = 4,
        water_animal    = 3,
        milk_animal     = 10,
        collect_eggs    = 8,
        shear_sheep     = 12,
        breed_animals   = 20,
        process_item    = 10,
        complete_challenge = 50,
    },

    ---@param level number
    ---@return number xpRequired
    xpPerLevel = function(level)
        return math.floor(100 * (level ^ 1.5))
    end,

    ---@param level number
    ---@return number multiplier
    yieldMultiplier = function(level)
        return 1.0 + (level / 100) * 0.5
    end,

    -- Crops/animals unlocked at each level
    cropUnlocks = {
        [1]  = { 'corn', 'soybeans', 'wheat', 'hay' },
        [3]  = { 'potatoes' },
        [5]  = { 'pumpkins' },
        [8]  = { 'sugarbeets' },
        [10] = { 'blueberries' },
        [15] = { 'cranberries' },
        [18] = { 'apples' },
        [20] = { 'cherries' },
    },

    animalUnlocks = {
        [1]  = { 'chicken' },
        [5]  = { 'cow' },
        [8]  = { 'turkey' },
        [10] = { 'pig' },
        [12] = { 'goat' },
        [15] = { 'sheep' },
    },
}

-- =============================================================================
-- WEATHER MAPPING
-- =============================================================================
-- Maps renewed-weathersync weather strings to our config keys.
-- If a weather type isn't mapped, defaults to 'clear'.

Config.WeatherMap = {
    ['EXTRASUNNY'] = 'clear',
    ['CLEAR']      = 'clear',
    ['NEUTRAL']    = 'clear',
    ['SMOG']       = 'overcast',
    ['FOGGY']      = 'foggy',
    ['OVERCAST']   = 'overcast',
    ['CLOUDS']     = 'overcast',
    ['CLEARING']   = 'clear',
    ['RAIN']       = 'rain',
    ['THUNDER']    = 'thunder',
    ['SNOW']       = 'snow',
    ['BLIZZARD']   = 'blizzard',
    ['SNOWLIGHT']  = 'snow',
    ['XMAS']       = 'snow',
    ['HALLOWEEN']  = 'overcast',
}

-- =============================================================================
-- ANIMALS (Phase 3)
-- =============================================================================
-- Simplified breeding: offspring auto-produced when herd/flock is kept in good
-- condition for a sustained period. No gender pairing, no pregnancy tracking.
-- Just reward consistent, attentive care with herd growth.
--
-- breeding.minHerdSize: adults needed in pen before auto-breeding can trigger
-- breeding.healthThreshold: minimum health per adult animal
-- breeding.wellKeptDuration: seconds of continuous good conditions required
-- breeding.cooldown: seconds between births per pen
-- breeding.offspringMin / offspringMax: number of offspring per birth event

Config.Animals = {
    cow = {
        label = 'Dairy Cow',
        pedModel = 'a_c_cow',
        purchasePrice = 2500,
        unlockLevel = 5,

        growthStages = {
            { stage = 'calf',   label = 'Calf',      duration = 172800 }, -- 48h
            { stage = 'heifer', label = 'Heifer',     duration = 259200 }, -- 72h
            { stage = 'adult',  label = 'Adult Cow',  duration = nil },
        },

        production = {
            type = 'milk',
            item = 'raw_milk',
            cycleTime = 43200, -- 12h between milking
            baseYield = { min = 15, max = 25 },
            qualityMultiplier = { poor = 0.7, average = 1.0, good = 1.2, excellent = 1.5 },
        },

        needs = {
            feedItem = 'hay_bale',
            feedAmount = 2,
            feedInterval = 21600,  -- 6h
            waterInterval = 21600,
            alternativeFeed = { 'grain' },
        },

        health = {
            baseDecay = 2,
            sicknessThreshold = 30,
            deathThreshold = 0,
            hungerPenalty = 5,
            thirstPenalty = 8,
        },

        breeding = {
            minHerdSize = 2,
            healthThreshold = 70,
            wellKeptDuration = 172800, -- 48h
            cooldown = 86400,          -- 24h between births
            offspringMin = 1,
            offspringMax = 1,
        },

        ai = {
            behavior = 'grazing',
            wanderSpeed = 1.0,
            idleTime = { min = 5000, max = 15000 },
        },

        penSize = 5,
        storageDecay = 5,            -- health loss per day while stored
        storageSicknessTime = 259200, -- 3 days stored = sickness
    },

    chicken = {
        label = 'Chicken',
        pedModel = 'a_c_hen',
        purchasePrice = 50,
        unlockLevel = 1,

        growthStages = {
            { stage = 'chick', label = 'Chick',          duration = 86400 }, -- 24h
            { stage = 'adult', label = 'Adult Chicken',   duration = nil },
        },

        production = {
            type = 'eggs',
            item = 'chicken_egg',
            cycleTime = 28800, -- 8h
            baseYield = { min = 1, max = 1 },
            qualityMultiplier = { poor = 0.5, average = 1.0, good = 1.0, excellent = 1.0 },
        },

        needs = {
            feedItem = 'chicken_feed',
            feedAmount = 1,
            feedInterval = 28800,  -- 8h
            waterInterval = 28800,
            alternativeFeed = { 'grain' },
        },

        health = {
            baseDecay = 3,
            sicknessThreshold = 40,
            deathThreshold = 0,
            hungerPenalty = 6,
            thirstPenalty = 10,
        },

        breeding = {
            minHerdSize = 3,
            healthThreshold = 60,
            wellKeptDuration = 172800, -- 48h
            cooldown = 43200,          -- 12h
            offspringMin = 1,
            offspringMax = 3,
        },

        ai = {
            behavior = 'pecking',
            wanderSpeed = 1.2,
            idleTime = { min = 3000, max = 8000 },
        },

        penSize = 20,
        storageDecay = 8,
        storageSicknessTime = 172800,
    },

    turkey = {
        label = 'Turkey',
        pedModel = 'a_c_chickenhawk', -- closest GTA V model
        purchasePrice = 80,
        unlockLevel = 8,

        growthStages = {
            { stage = 'poult', label = 'Poult',          duration = 129600 }, -- 36h
            { stage = 'adult', label = 'Adult Turkey',    duration = nil },
        },

        production = {
            type = 'eggs',
            item = 'turkey_egg',
            cycleTime = 43200, -- 12h
            baseYield = { min = 1, max = 1 },
            qualityMultiplier = { poor = 0.6, average = 1.0, good = 1.0, excellent = 1.0 },
        },

        needs = {
            feedItem = 'chicken_feed',
            feedAmount = 2,
            feedInterval = 32400,  -- 9h
            waterInterval = 32400,
            alternativeFeed = { 'grain' },
        },

        health = {
            baseDecay = 3,
            sicknessThreshold = 35,
            deathThreshold = 0,
            hungerPenalty = 6,
            thirstPenalty = 9,
        },

        breeding = {
            minHerdSize = 3,
            healthThreshold = 65,
            wellKeptDuration = 172800, -- 48h
            cooldown = 43200,          -- 12h
            offspringMin = 1,
            offspringMax = 2,
        },

        ai = {
            behavior = 'pecking',
            wanderSpeed = 1.1,
            idleTime = { min = 4000, max = 10000 },
        },

        penSize = 15,
        storageDecay = 7,
        storageSicknessTime = 172800,
    },

    pig = {
        label = 'Pig',
        pedModel = 'a_c_pig',
        purchasePrice = 400,
        unlockLevel = 10,

        growthStages = {
            { stage = 'piglet', label = 'Piglet',      duration = 172800 }, -- 48h
            { stage = 'grower', label = 'Grower Pig',   duration = 259200 }, -- 72h
            { stage = 'adult',  label = 'Market Pig',   duration = nil },
        },

        production = {
            type = 'none', -- Pigs raised for meat (external butcher system)
            item = nil,
            cycleTime = nil,
            baseYield = nil,
        },

        needs = {
            feedItem = 'pig_slop',
            feedAmount = 3,
            feedInterval = 21600,  -- 6h
            waterInterval = 21600,
            alternativeFeed = { 'grain' },
        },

        health = {
            baseDecay = 2,
            sicknessThreshold = 30,
            deathThreshold = 0,
            hungerPenalty = 6,
            thirstPenalty = 8,
        },

        breeding = {
            minHerdSize = 2,
            healthThreshold = 70,
            wellKeptDuration = 172800, -- 48h
            cooldown = 86400,          -- 24h
            offspringMin = 3,
            offspringMax = 6,
        },

        ai = {
            behavior = 'roaming',
            wanderSpeed = 0.9,
            idleTime = { min = 6000, max = 15000 },
        },

        penSize = 10,
        storageDecay = 6,
        storageSicknessTime = 259200,
    },

    goat = {
        label = 'Goat',
        pedModel = 'a_c_deer', -- Substitute model (deer silhouette)
        purchasePrice = 350,
        unlockLevel = 12,

        growthStages = {
            { stage = 'kid',   label = 'Kid',         duration = 129600 }, -- 36h
            { stage = 'adult', label = 'Adult Goat',   duration = nil },
        },

        production = {
            type = 'milk',
            item = 'goat_milk',
            cycleTime = 43200, -- 12h
            baseYield = { min = 8, max = 15 },
            qualityMultiplier = { poor = 0.7, average = 1.0, good = 1.2, excellent = 1.5 },
        },

        needs = {
            feedItem = 'hay_bale',
            feedAmount = 1,
            feedInterval = 28800,  -- 8h
            waterInterval = 28800,
            alternativeFeed = { 'grain' },
        },

        health = {
            baseDecay = 2,
            sicknessThreshold = 35,
            deathThreshold = 0,
            hungerPenalty = 5,
            thirstPenalty = 7,
        },

        breeding = {
            minHerdSize = 2,
            healthThreshold = 65,
            wellKeptDuration = 172800, -- 48h
            cooldown = 64800,          -- 18h
            offspringMin = 1,
            offspringMax = 2,
        },

        ai = {
            behavior = 'grazing',
            wanderSpeed = 1.1,
            idleTime = { min = 4000, max = 12000 },
        },

        penSize = 8,
        storageDecay = 6,
        storageSicknessTime = 259200,
    },

    sheep = {
        label = 'Sheep',
        pedModel = 'a_c_cow', -- Substitute model (no native sheep in GTA V)
        purchasePrice = 300,
        unlockLevel = 15,

        growthStages = {
            { stage = 'lamb',  label = 'Lamb',         duration = 172800 }, -- 48h
            { stage = 'adult', label = 'Adult Sheep',   duration = nil },
        },

        production = {
            type = 'wool',
            item = 'raw_wool',
            cycleTime = 345600, -- 4 days
            baseYield = { min = 3, max = 6 },
            qualityMultiplier = { poor = 0.6, average = 1.0, good = 1.3, excellent = 1.6 },
        },

        needs = {
            feedItem = 'hay_bale',
            feedAmount = 2,
            feedInterval = 28800,  -- 8h
            waterInterval = 28800,
            alternativeFeed = { 'grain' },
        },

        health = {
            baseDecay = 2,
            sicknessThreshold = 30,
            deathThreshold = 0,
            hungerPenalty = 5,
            thirstPenalty = 7,
        },

        breeding = {
            minHerdSize = 2,
            healthThreshold = 65,
            wellKeptDuration = 172800, -- 48h
            cooldown = 64800,          -- 18h
            offspringMin = 1,
            offspringMax = 2,
        },

        ai = {
            behavior = 'grazing',
            wanderSpeed = 0.9,
            idleTime = { min = 5000, max = 15000 },
        },

        penSize = 12,
        storageDecay = 5,
        storageSicknessTime = 259200,
    },
}

-- =============================================================================
-- PROCESSING STATIONS (Phase 5)
-- =============================================================================
-- Each station has a location, level requirement, and recipes.
-- Coordinates are placeholders — update to your map positions.

Config.ProcessingStations = {
    {
        id = 'grain_mill',
        label = 'Grain Mill',
        location = vec3(2025.0, 4810.0, 41.5),
        blip = { sprite = 648, color = 46, scale = 0.6 },
        prop = 'prop_generator_03b',
        requiredLevel = 5,
        recipes = {
            {
                id = 'wheat_to_flour',
                label = 'Mill Flour',
                input = 'wheat',
                inputAmount = 10,
                output = 'flour',
                outputAmount = 8,
                processingTime = 30000,
                xpReward = 10,
            },
            {
                id = 'corn_to_cornmeal',
                label = 'Mill Cornmeal',
                input = 'corn',
                inputAmount = 10,
                output = 'cornmeal',
                outputAmount = 8,
                processingTime = 30000,
                xpReward = 10,
            },
        },
    },
    {
        id = 'cheese_press',
        label = 'Cheese Press',
        location = vec3(2035.0, 4810.0, 41.5),
        blip = { sprite = 648, color = 5, scale = 0.6 },
        prop = 'prop_generator_03b',
        requiredLevel = 10,
        recipes = {
            {
                id = 'milk_to_cheese',
                label = 'Press Cheese Wheel',
                input = 'raw_milk',
                inputAmount = 20,
                output = 'cheese_wheel',
                outputAmount = 1,
                processingTime = 60000,
                xpReward = 15,
            },
            {
                id = 'goat_to_cheese',
                label = 'Press Goat Cheese',
                input = 'goat_milk',
                inputAmount = 15,
                output = 'goat_cheese',
                outputAmount = 1,
                processingTime = 60000,
                xpReward = 15,
            },
        },
    },
    {
        id = 'butter_churn',
        label = 'Butter Churn',
        location = vec3(2040.0, 4810.0, 41.5),
        blip = { sprite = 648, color = 28, scale = 0.6 },
        prop = 'prop_barrel_01a',
        requiredLevel = 8,
        recipes = {
            {
                id = 'milk_to_butter',
                label = 'Churn Butter',
                input = 'raw_milk',
                inputAmount = 10,
                output = 'butter',
                outputAmount = 2,
                processingTime = 45000,
                xpReward = 12,
            },
        },
    },
    {
        id = 'cider_press',
        label = 'Cider Press',
        location = vec3(2045.0, 4810.0, 41.5),
        blip = { sprite = 648, color = 17, scale = 0.6 },
        prop = 'prop_barrel_01a',
        requiredLevel = 15,
        recipes = {
            {
                id = 'apple_to_cider',
                label = 'Press Apple Cider',
                input = 'apple',
                inputAmount = 15,
                output = 'apple_cider',
                outputAmount = 5,
                processingTime = 40000,
                xpReward = 12,
            },
        },
    },
    {
        id = 'drying_rack',
        label = 'Drying Rack',
        location = vec3(2050.0, 4810.0, 41.5),
        blip = { sprite = 648, color = 27, scale = 0.6 },
        prop = 'prop_woodpile_02a',
        requiredLevel = 12,
        recipes = {
            {
                id = 'cranberries_dried',
                label = 'Dry Cranberries',
                input = 'cranberries',
                inputAmount = 10,
                output = 'dried_cranberries',
                outputAmount = 6,
                processingTime = 120000,
                xpReward = 14,
            },
            {
                id = 'cherries_dried',
                label = 'Dry Cherries',
                input = 'cherries',
                inputAmount = 10,
                output = 'dried_cherries',
                outputAmount = 6,
                processingTime = 120000,
                xpReward = 14,
            },
        },
    },
    {
        id = 'wool_processor',
        label = 'Wool Processing',
        location = vec3(2055.0, 4810.0, 41.5),
        blip = { sprite = 648, color = 4, scale = 0.6 },
        prop = 'prop_generator_03b',
        requiredLevel = 20,
        recipes = {
            {
                id = 'wool_to_processed',
                label = 'Process Wool',
                input = 'raw_wool',
                inputAmount = 5,
                output = 'processed_wool',
                outputAmount = 4,
                processingTime = 50000,
                xpReward = 16,
            },
        },
    },
}

-- =============================================================================
-- CHALLENGES (Phase 5)
-- =============================================================================
-- Daily challenge system. Players get 3 active challenges at a time.
-- Completing challenges awards XP and leaderboard points.

Config.Challenges = {
    refreshInterval = 86400, -- 24 hours
    maxActive = 3,

    types = {
        {
            id = 'harvest_volume',
            label = 'Harvest Challenge',
            description = 'Harvest %d %s',
            difficulty = 'easy',
            xpReward = 100,
            leaderboardPoints = 10,
            generateRequirements = function()
                local crops = { 'corn', 'soybeans', 'wheat', 'potato' }
                local crop = crops[math.random(#crops)]
                local amount = math.random(200, 500)
                return { action = 'harvest', crop = crop, amount = amount }
            end,
        },
        {
            id = 'milk_production',
            label = 'Dairy Production',
            description = 'Collect %d milk',
            difficulty = 'medium',
            xpReward = 150,
            leaderboardPoints = 15,
            generateRequirements = function()
                return { action = 'milk', amount = math.random(50, 150) }
            end,
        },
        {
            id = 'egg_collection',
            label = 'Egg Collector',
            description = 'Collect %d eggs',
            difficulty = 'easy',
            xpReward = 80,
            leaderboardPoints = 8,
            generateRequirements = function()
                return { action = 'collect_eggs', amount = math.random(20, 60) }
            end,
        },
        {
            id = 'animal_care',
            label = 'Animal Caretaker',
            description = 'Feed or water animals %d times',
            difficulty = 'medium',
            xpReward = 120,
            leaderboardPoints = 12,
            generateRequirements = function()
                return { action = 'care', amount = math.random(15, 40) }
            end,
        },
        {
            id = 'planting_spree',
            label = 'Planting Spree',
            description = 'Plant %d fields',
            difficulty = 'easy',
            xpReward = 90,
            leaderboardPoints = 9,
            generateRequirements = function()
                return { action = 'plant', amount = math.random(5, 15) }
            end,
        },
        {
            id = 'processing_master',
            label = 'Processing Master',
            description = 'Process %d items at stations',
            difficulty = 'medium',
            xpReward = 140,
            leaderboardPoints = 14,
            generateRequirements = function()
                return { action = 'process', amount = math.random(5, 15) }
            end,
        },
        {
            id = 'breeding_program',
            label = 'Breeding Program',
            description = 'Successfully breed %d animals',
            difficulty = 'hard',
            xpReward = 300,
            leaderboardPoints = 30,
            generateRequirements = function()
                return { action = 'breed', amount = math.random(2, 5) }
            end,
        },
    },
}
