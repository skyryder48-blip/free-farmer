--[[
    free-farmer — Item Definitions for ox_inventory
    
    Add these entries to your ox_inventory/data/items.lua file.
    Items are organized by category and phase.
    
    USAGE: Copy the relevant items into your ox_inventory items table.
]]

--[[

-- =============================================================================
-- PHASE 1: Seeds
-- =============================================================================

['corn_seed'] = {
    label = 'Corn Seeds',
    weight = 50,
    stack = true,
    close = true,
    description = 'A packet of field corn seeds for planting.',
},

['soybean_seed'] = {
    label = 'Soybean Seeds',
    weight = 50,
    stack = true,
    close = true,
    description = 'A packet of soybean seeds for planting.',
},

['wheat_seed'] = {
    label = 'Wheat Seeds',
    weight = 50,
    stack = true,
    close = true,
    description = 'A packet of winter wheat seeds for planting.',
},

['hay_seed'] = {
    label = 'Hay Seeds',
    weight = 50,
    stack = true,
    close = true,
    description = 'A packet of hay/alfalfa seeds for planting.',
},

-- =============================================================================
-- PHASE 1: Harvested Crops
-- =============================================================================

['corn'] = {
    label = 'Corn',
    weight = 200,
    stack = true,
    close = true,
    description = 'Freshly harvested field corn.',
},

['soybeans'] = {
    label = 'Soybeans',
    weight = 150,
    stack = true,
    close = true,
    description = 'Freshly harvested soybeans.',
},

['wheat'] = {
    label = 'Wheat',
    weight = 150,
    stack = true,
    close = true,
    description = 'Freshly harvested winter wheat.',
},

['hay_bale'] = {
    label = 'Hay Bale',
    weight = 2000,
    stack = true,
    close = true,
    description = 'A bale of fresh hay — essential for livestock feed.',
},

-- =============================================================================
-- PHASE 1: Garden Planter
-- =============================================================================

['garden_planter'] = {
    label = 'Garden Planter',
    weight = 5000,
    stack = false,
    close = true,
    description = 'A portable garden planter box. Place it anywhere to grow individual crops.',
    client = {
        event = 'free-farmer:client:usePlanter',
    },
},

-- =============================================================================
-- PHASE 2: Additional Seeds (add when implementing Phase 2)
-- =============================================================================

['potato_seed'] = {
    label = 'Potato Seeds',
    weight = 80,
    stack = true,
    close = true,
    description = 'Seed potatoes for planting.',
},

['pumpkin_seed'] = {
    label = 'Pumpkin Seeds',
    weight = 50,
    stack = true,
    close = true,
    description = 'A packet of pumpkin seeds.',
},

['sugarbeet_seed'] = {
    label = 'Sugar Beet Seeds',
    weight = 50,
    stack = true,
    close = true,
    description = 'Sugar beet seeds for planting.',
},

['cranberry_plant'] = {
    label = 'Cranberry Plant',
    weight = 200,
    stack = true,
    close = true,
    description = 'A young cranberry plant ready for planting.',
},

['cherry_tree'] = {
    label = 'Cherry Tree Sapling',
    weight = 500,
    stack = true,
    close = true,
    description = 'A tart cherry tree sapling — Michigan specialty.',
},

['apple_tree'] = {
    label = 'Apple Tree Sapling',
    weight = 500,
    stack = true,
    close = true,
    description = 'An apple tree sapling ready for planting.',
},

['blueberry_bush'] = {
    label = 'Blueberry Bush',
    weight = 300,
    stack = true,
    close = true,
    description = 'A blueberry bush cutting for planting.',
},

-- =============================================================================
-- PHASE 2: Additional Harvested Crops
-- =============================================================================

['potato'] = {
    label = 'Potato',
    weight = 300,
    stack = true,
    close = true,
    description = 'Freshly dug Wisconsin chip potatoes.',
},

['pumpkin'] = {
    label = 'Pumpkin',
    weight = 3000,
    stack = true,
    close = true,
    description = 'A large harvest pumpkin.',
},

['sugar_beet'] = {
    label = 'Sugar Beet',
    weight = 400,
    stack = true,
    close = true,
    description = 'Michigan sugar beets — processed into sugar.',
},

['cranberries'] = {
    label = 'Cranberries',
    weight = 150,
    stack = true,
    close = true,
    description = 'Fresh Wisconsin cranberries.',
},

['cherries'] = {
    label = 'Tart Cherries',
    weight = 150,
    stack = true,
    close = true,
    description = 'Michigan tart cherries from Traverse City.',
},

['apple'] = {
    label = 'Apple',
    weight = 200,
    stack = true,
    close = true,
    description = 'A fresh Michigan apple.',
},

['blueberries'] = {
    label = 'Blueberries',
    weight = 100,
    stack = true,
    close = true,
    description = 'Freshly picked Michigan blueberries.',
},

-- =============================================================================
-- PHASE 3: Animal Feed
-- =============================================================================

['chicken_feed'] = {
    label = 'Chicken Feed',
    weight = 200,
    stack = true,
    close = true,
    description = 'A bag of chicken feed — cracked corn and grain mix.',
},

['pig_slop'] = {
    label = 'Pig Slop',
    weight = 500,
    stack = true,
    close = true,
    description = 'A bucket of pig slop — vegetable scraps and grain.',
},

['grain'] = {
    label = 'Grain',
    weight = 300,
    stack = true,
    close = true,
    description = 'Mixed grain — universal livestock supplement.',
},

-- =============================================================================
-- PHASE 3: Animal Products
-- =============================================================================

['raw_milk'] = {
    label = 'Raw Milk',
    weight = 500,
    stack = true,
    close = true,
    description = 'Fresh raw cow milk — handle with care.',
},

['goat_milk'] = {
    label = 'Goat Milk',
    weight = 400,
    stack = true,
    close = true,
    description = 'Fresh goat milk — creamy and nutritious.',
},

['chicken_egg'] = {
    label = 'Chicken Egg',
    weight = 60,
    stack = true,
    close = true,
    description = 'A fresh farm egg.',
},

['turkey_egg'] = {
    label = 'Turkey Egg',
    weight = 80,
    stack = true,
    close = true,
    description = 'A large turkey egg.',
},

['raw_wool'] = {
    label = 'Raw Wool',
    weight = 1000,
    stack = true,
    close = true,
    description = 'Raw sheep wool — needs processing before use.',
},

-- =============================================================================
-- PHASE 5: Processed Goods
-- =============================================================================

['flour'] = {
    label = 'Flour',
    weight = 150,
    stack = true,
    close = true,
    description = 'Finely milled wheat flour.',
},

['cornmeal'] = {
    label = 'Cornmeal',
    weight = 150,
    stack = true,
    close = true,
    description = 'Ground cornmeal from field corn.',
},

['cheese_wheel'] = {
    label = 'Cheese Wheel',
    weight = 2000,
    stack = true,
    close = true,
    description = 'A wheel of aged farm cheese.',
},

['goat_cheese'] = {
    label = 'Goat Cheese',
    weight = 500,
    stack = true,
    close = true,
    description = 'Creamy goat cheese — tangy and rich.',
},

['butter'] = {
    label = 'Butter',
    weight = 250,
    stack = true,
    close = true,
    description = 'Fresh churned farm butter.',
},

['apple_cider'] = {
    label = 'Apple Cider',
    weight = 500,
    stack = true,
    close = true,
    description = 'Fresh-pressed Michigan apple cider.',
},

['dried_cranberries'] = {
    label = 'Dried Cranberries',
    weight = 80,
    stack = true,
    close = true,
    description = 'Sun-dried Wisconsin cranberries.',
},

['dried_cherries'] = {
    label = 'Dried Cherries',
    weight = 80,
    stack = true,
    close = true,
    description = 'Dried Michigan tart cherries.',
},

['processed_wool'] = {
    label = 'Processed Wool',
    weight = 600,
    stack = true,
    close = true,
    description = 'Clean, carded wool ready for crafting.',
},

]]
