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
-- ANIMALS (Phase 3 — stub)
-- =============================================================================

Config.Animals = {}

-- =============================================================================
-- PROCESSING (Phase 5 — stub)
-- =============================================================================

Config.Processing = {}

-- =============================================================================
-- CHALLENGES (Phase 5 — stub)
-- =============================================================================

Config.Challenges = {}
