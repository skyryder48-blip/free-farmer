# free-farmer — Coding Phase Plan (Corrected & Implementation-Ready)

**Based on:** Technical Specification v1.0  
**Framework:** QBX + ox_lib, oxmysql, ox_inventory, ox_target  
**Weather:** renewed-weathersync (kibook fork — exports-based API)  
**Farm Locations:** Start with 2-3, expand via config  
**Ownership:** Open-access by default, admin-assignable  

---

## Critical Technical Corrections (vs Original Spec)

These issues MUST be fixed during implementation — the spec's code samples are wrong in several places.

### 1. Server-Side Entity Creation
**Problem:** Spec calls `RequestModel()`/`HasModelLoaded()` server-side — these are **client-only natives**.  
**Fix:** With OneSync, server-side `CreateObject()`/`CreatePed()` handles model loading automatically. We MUST call `SetEntityOrphanMode(entity, 2)` to prevent server garbage collection when no players are nearby. Entity properties like `FreezeEntityPosition`, `SetEntityCollision`, etc. are also client-side — we set those via state bags and apply them on the owning client.

### 2. Animal AI — Must Be Client-Side
**Problem:** Spec puts `TaskStartScenarioInPlace`, `TaskWanderInArea`, `ClearPedTasks`, `SetBlockingOfNonTemporaryEvents` in server code — all are **client-only natives**.  
**Fix:** AI behavior runs on the client that currently owns the entity. We use state bags to communicate animal type/state, and a client-side AI controller reads those bags to apply the correct behavior when an animal enters scope.

### 3. ox_lib Zone API
**Problem:** Spec uses `exports.ox_lib:addSphereZone()` — that API doesn't exist.  
**Fix:** Correct API is `lib.zones.sphere()` / `lib.zones.poly()` / `lib.zones.box()` as imported modules (not exports). Must `require` or use the `lib` global.

### 4. SetPedScale Does NOT Exist in FiveM
**Problem:** Spec relies on `SetPedScale(ped, 0.6)` for animal growth stages — this native only exists in **RedM**, not FiveM/GTA V.  
**Fix:** Growth stages are tracked in the database and reflected via state bags. Visual distinction comes from behavior differences (calves move faster, etc.) and interaction label changes ("Calf" vs "Adult Cow"). We do NOT attempt to resize peds.

### 5. Weather Integration — No Server Events
**Problem:** Spec hooks `weathersync:server:weather:change` — renewed-weathersync doesn't fire server-side weather change events.  
**Fix:** Use `exports['Renewed-Weathersync']:getWeather()` (server export) to poll current weather during growth ticks. No event hooking needed — we just read weather state when we process crop growth.

### 6. Prop Spawning Architecture
**Problem:** Spec spawns props server-side with `CreateObject` for field visuals — works but has issues with model loading and entity limits.  
**Fix:** Hybrid approach: Server creates entities with `CreateObjectNoOffset` + `SetEntityOrphanMode(entity, 2)`, and client applies visual properties (freeze, collision disable) via `entityCreated` handler or state bag watcher. Alternative: client-side-only props for pure decoration (non-networked, zero entity cost) spawned when entering farm zone.

---

## Revised File Structure

```
free-farmer/
├── fxmanifest.lua
├── config/
│   └── shared.lua          -- ALL config (crops, animals, farms, XP, processing)
├── client/
│   ├── main.lua            -- Resource init, zone management, blips
│   ├── fields.lua          -- Field interactions (plow, plant, harvest via ox_target)
│   ├── animals.lua         -- Animal interactions + CLIENT-SIDE AI controller
│   ├── processing.lua      -- Processing station interactions
│   ├── xp.lua              -- Client XP display/notifications
│   └── utils.lua           -- Client helpers
├── server/
│   ├── main.lua            -- Resource init, DB bootstrap, player load/unload
│   ├── fields.lua          -- Field state management, growth ticks, prop spawning
│   ├── animals.lua         -- Animal CRUD, health ticks, production cycles, spawning
│   ├── breeding.lua        -- Breeding, pregnancy, birth logic
│   ├── weather.lua         -- Weather polling (renewed-weathersync exports)
│   ├── xp.lua              -- XP calculations, level-ups, unlocks
│   ├── challenges.lua      -- Challenge generation, progress tracking, completion
│   ├── leaderboard.lua     -- Score tracking, resets
│   ├── processing.lua      -- Processing recipe validation, item exchange
│   └── utils.lua           -- UUID generation, polygon math, DB helpers
├── sql/
│   └── install.sql         -- All tables
└── items/
    └── items.lua           -- ox_inventory item registration
```

**Key change from spec:** No separate `animals_ai.lua` server file. AI is entirely client-side inside `client/animals.lua`. No `web/` folder — leaderboard uses ox_lib context menus or input dialogs instead of NUI for simplicity in Phase 1, with optional NUI upgrade later.

---

## Phase 1: Foundation — Database, Zones, Field Crop Loop

**Goal:** A player can walk to a farm, plow a field, plant seeds, watch crops grow through visual stages, and harvest for items + XP. This validates the entire server-client architecture.

### Phase 1A: Project Skeleton + Database

**Files:** `fxmanifest.lua`, `sql/install.sql`, `config/shared.lua` (partial), `server/main.lua`, `client/main.lua`, `server/utils.lua`

**Tasks:**
1. **fxmanifest.lua** — Resource manifest with proper fx_version, game, dependencies (qbx_core, ox_lib, oxmysql, ox_inventory, ox_target), shared/client/server script declarations, `lua54 'yes'`
2. **install.sql** — All 5 database tables from spec (farm_fields, farm_animals, farm_player_data, farm_challenges, farm_leaderboard). Use `INT` for timestamps (UNIX epoch), not `TIMESTAMP` type, for simpler Lua math
3. **server/main.lua** — Resource start handler: verify DB tables exist, seed initial field rows for configured farms if not present, register ox_inventory items
4. **server/utils.lua** — `GenerateUUID()`, `GetFarmZoneById()`, `GetFieldConfig()`, `GetPenConfig()`, polygon math helpers (`GetRandomPointInPolygon`, `IsPointInPolygon`, `GetPolygonCenter`)
5. **client/main.lua** — Farm zone detection using `lib.zones.sphere()` for each farm; triggers server events on enter/exit; map blip creation

**Config structure (partial — crops + first 2 farms only):**
```lua
-- config/shared.lua
return {
    Debug = false,
    
    GrowthTickInterval = 300, -- seconds (5 minutes)
    AnimalHealthTickInterval = 3600, -- seconds (1 hour)
    
    FarmZones = {
        -- 2 farms to start, expandable
    },
    
    Crops = {
        -- corn, soybeans, wheat, hay for Phase 1
    },
    
    Animals = {}, -- Phase 3
    XP = {},      -- Phase 1B
    Processing = {}, -- Phase 5
    Challenges = {}, -- Phase 5
}
```

### Phase 1B: Field System — Plow → Plant → Grow → Harvest

**Files:** `server/fields.lua`, `client/fields.lua`, `server/weather.lua` (stub)

**Tasks:**

**Server — server/fields.lua:**
1. **Field prop spawning** — On farm zone enter (first player), query `farm_fields` for that zone, spawn crop props server-side using `CreateObjectNoOffset()` + `SetEntityOrphanMode(entity, 2)` at preconfigured spawn points. Track in `activeFieldProps[fieldId]` table. Despawn all when zone empties.
2. **Growth tick thread** — Single `CreateThread` loop at `Config.GrowthTickInterval`. Batch-query all planted fields, check elapsed time vs stage duration, advance stages where ready. On stage advance: despawn old props, spawn new stage props, update DB.
3. **Plow callback** — `lib.callback.register('free-farmer:plowField')`: validates player is at field, field is empty/harvested, returns success. Updates DB: sets field to "plowed" state (growth_stage = 0, crop_type = nil, ready for planting).
4. **Plant callback** — `lib.callback.register('free-farmer:plantField')`: validates field is plowed, player has seed item in ox_inventory, crop is unlocked at player's level. Removes seeds, sets crop_type + growth_stage = 1 + planted_at + stage_updated_at in DB. Spawns stage 1 props.
5. **Harvest callback** — `lib.callback.register('free-farmer:harvestField')`: validates field is at final growth stage. Calls `CalculateHarvestYield()` (soil quality × weather × XP modifier). Adds harvested items to ox_inventory. Calls `DegradeSoilQuality()`. Resets field state. Awards XP. Despawns props.

**Client — client/fields.lua:**
1. **Zone-based ox_target registration** — When entering a farm zone, register ox_target interaction points for each field. Options: Plow (if empty), Plant (if plowed), Check Field (always), Harvest (if harvestable). Use `lib.callback` to call server for each action.
2. **Progress bars** — Use `lib.progressBar` for plow (~8s), plant (~5s), harvest (~10s). Player must stay in area.
3. **Animation** — Play appropriate anim dict during progress bar (e.g., `world_human_gardener_plant` for planting)
4. **Field status display** — On "Check Field" interaction, server returns field data (crop type, stage, soil quality, weather condition), client shows via `lib.alertDialog` or notification

**Server — server/weather.lua (stub):**
1. **`GetCurrentWeather()` function** — Wraps `exports['Renewed-Weathersync']:getWeather()` with pcall for safety. Returns weather string or 'CLEAR' as fallback.
2. **Weather applied during growth tick** — Not a separate loop. When processing growth tick in `server/fields.lua`, call `GetCurrentWeather()` and update the field's weather tracking columns.

**Items (Phase 1 crops):**
- `corn_seed`, `corn`, `soybean_seed`, `soybeans`, `wheat_seed`, `wheat`, `hay_seed`, `hay_bale`
- Each seed consumed on planting. Harvest items have metadata for quality tier.

### Phase 1C: Basic XP System

**Files:** `server/xp.lua`, `client/xp.lua`

**Tasks:**

**Server — server/xp.lua:**
1. **`AwardXP(src, action, customAmount)`** — Core function called by all other systems. Gets/creates player row in `farm_player_data`. Adds XP, checks for level-up against `Config.XP.xpPerLevel(level)` curve. On level-up: check `Config.XP.cropUnlocks[level]` for new unlocks. Sends notification + client event for UI.
2. **`GetPlayerFarmingLevel(src)`** — Returns player's current farming level (used by plant/harvest validation).
3. **`GetPlayerFarmingXPModifier(src)`** — Returns yield multiplier based on level (1.0 → 1.5 over 100 levels).

**Client — client/xp.lua:**
1. **XP notification handler** — Receives XP gain events, shows via `lib.notify`
2. **Level-up handler** — Shows special notification on level-up with unlock info
3. **`/farmstats` command** — Shows current level, XP, XP to next level via `lib.alertDialog`

---

## Phase 2: Crop Expansion + Weather + Soil Depth

**Goal:** Full crop roster operational, weather meaningfully impacts crops, soil quality / crop rotation matters.

### Phase 2A: Remaining Crops + Seasonal/Field Type Validation

**Files:** Update `config/shared.lua`, update `server/fields.lua`, update `client/fields.lua`

**Tasks:**
1. **Add remaining 7 crops to config** — potatoes, pumpkins, cranberries, sugar beets, cherries, apples, blueberries. Each with full growth stage definitions, proper props, weather preferences, field type restrictions, unlock levels.
2. **Field type validation** — Server-side planting callback checks `cropConfig.fieldTypes` against `fieldConfig.fieldType`. Large fields for row crops, small for orchards, etc.
3. **Special harvest methods** — `harvestMethod` field: `tree_pick` (cherries/apples), `bush_pick` (blueberries), `water_flood` (cranberries). Different animations and progress durations per method.
4. **Perennial crop handling** — Crops with `harvestMethod` = tree/bush/water_flood don't reset to bare on harvest. They revert to a "regrowth" stage instead of fully clearing.

### Phase 2B: Weather Integration (Full)

**Files:** Update `server/weather.lua`, update `server/fields.lua`

**Tasks:**
1. **Weather polling during growth tick** — Each growth tick calls `GetCurrentWeather()`, maps weather string to crop-specific preference multiplier, increments `good_weather_ticks` or `bad_weather_ticks`.
2. **`CalculateWeatherYieldBonus(fieldId)`** — Ratio of good/bad ticks over crop's lifetime determines harvest yield modifier (0.85× to 1.15×).
3. **Weather-to-config mapping** — Map renewed-weathersync weather strings (`CLEAR`, `OVERCAST`, `RAIN`, `THUNDER`, `FOGGY`, `SNOW`, `BLIZZARD`, etc.) to our config keys.

### Phase 2C: Soil Quality + Crop Rotation

**Files:** Update `server/fields.lua`

**Tasks:**
1. **`DegradeSoilQuality(fieldId, cropType)`** — Already designed in spec, implement as-is. Consecutive same-crop penalty, crop family rotation bonus, legume (soybean) soil improvement.
2. **Soil quality impacts yield** — `soilModifier = field.soil_quality / 100.0` already in harvest calc.
3. **Soil recovery** — Leaving a field fallow (empty) for N growth ticks slowly recovers soil quality. Add `fallow_recovery_rate` to config.
4. **Fertilizer system** — `fertilize_field` interaction. Requires fertilizer item. Sets `fertilized = true` + `fertilizer_quality`. Fertilized fields get a yield bonus and reduced soil degradation for that crop cycle.
5. **Quality system** — Harvest quality (poor/average/good/excellent) based on combined condition score. Quality stored as item metadata. Different quality = different item label suffix in ox_inventory.

---

## Phase 3: Livestock Foundation

**Goal:** Players can purchase animals, place them in pens, feed/water them, and collect production (milk, eggs, wool). Animals have AI behaviors and health consequences.

### Phase 3A: Animal Spawning + Database

**Files:** Update `config/shared.lua` (animals), `server/animals.lua`, `client/animals.lua`

**Tasks:**

**Server — server/animals.lua:**
1. **Animal purchase** — NPC or ox_target interaction at barn. Server creates DB row in `farm_animals` with UUID, owner citizenid, type, random gender, starting growth stage, pen assignment. Checks pen capacity.
2. **Animal spawning** — On farm zone enter (first player), query `farm_animals WHERE farm_zone = ? AND is_stored = FALSE`. For each: `CreatePed()` server-side + `SetEntityOrphanMode(ped, 2)`. Set state bags: `animalUuid`, `animalType`, `animalName`, `health`, `quality`, `productionReady`, `isSick`, `gender`, `growthStage`, `isPregnant`.
3. **Animal despawning** — On farm zone exit (last player), delete all spawned animal entities for that zone. Track in `spawnedAnimals[uuid] = {entity, netId}`.
4. **Pen boundary enforcement** — Server-side thread: every 30s, check each spawned animal's position. If outside pen polygon, teleport back to pen center.

**Client — client/animals.lua (AI Controller):**
1. **State bag watcher** — `AddStateBagChangeHandler('animalType', ...)`: when an animal entity enters client scope with state bags, apply AI behavior.
2. **Behavior application** — Based on `animalType` state bag, apply appropriate client-side tasks:
   - Cows: `TaskStartScenarioInPlace(ped, "WORLD_COW_GRAZING")` cycling with `TaskWanderInArea`
   - Chickens: `TaskStartScenarioInPlace(ped, "WORLD_CHICKEN_PECKING")` with quick burst movement  
   - Pigs: `TaskWanderInArea` with idle pauses
3. **Ped configuration** — On entity entering scope: `SetBlockingOfNonTemporaryEvents`, `SetPedFleeAttributes(0)`, `SetPedCombatAttributes(17, true)`, `FreezeEntityPosition(false)`
4. **ox_target on animal models** — Register target options per animal model: Check Animal, Feed, Water, Milk (cow/goat), Collect Eggs (chicken/turkey), Shear (sheep), Name, Store in Barn. Use `canInteract` to read state bags for conditional display.

**Start with 3 animals:** Cow (`a_c_cow`), Chicken (`a_c_hen`), Pig (`a_c_pig`)

### Phase 3B: Animal Health, Feeding, Production

**Files:** Update `server/animals.lua`

**Tasks:**
1. **Health tick thread** — Single `CreateThread` at `Config.AnimalHealthTickInterval` (1 hour). Batch-query all non-stored animals. For each: check time since last fed/watered, apply health decay + hunger/thirst penalties. Check sickness threshold. Check death threshold → delete from DB + despawn. Update state bags on spawned entities.
2. **Feed interaction** — Server callback: verify player has correct feed item in inventory, remove item, update `last_fed` timestamp. Award XP.
3. **Water interaction** — Server callback: verify at water trough location (or carrying water bucket), update `last_watered`. Award XP.
4. **Milk production** — Cows/goats: server checks `last_produced` timestamp vs `production.cycleTime`. If ready, sets `production_ready = true` via state bag. On milk interaction: progress bar, add `raw_milk` to inventory (yield based on health/quality), reset production timer. Award XP.
5. **Egg collection** — Same pattern for chickens/turkeys with `chicken_egg`/`turkey_egg`.

### Phase 3C: Animal Storage (Barn System)

**Files:** Update `server/animals.lua`, update `client/animals.lua`

**Tasks:**
1. **Store animal** — Server: set `is_stored = TRUE`, `stored_at = os.time()`, `pen_id = NULL`. Despawn entity. 
2. **Release animal** — Server: verify pen capacity, set `is_stored = FALSE`, assign pen_id. Spawn entity.
3. **Barn UI** — ox_target at animal barn location. Server callback returns list of active + stored animals. Client displays via `lib.registerContext` (ox_lib context menu) with Store/Release buttons per animal.
4. **Storage degradation thread** — Part of the hourly health tick. Stored animals: apply `storageDecay` health loss per day. After `storageSicknessTime`: set sick. Quality downgrades after 7 days stored.

---

## Phase 4: Livestock Expansion + Breeding

**Goal:** Remaining animal types, breeding system for long-term farm development.

### Phase 4A: Remaining Animals

**Files:** Update `config/shared.lua`, update `client/animals.lua`

**Tasks:**
1. **Add Turkey, Goat, Sheep configs** — Ped models: turkey (`a_c_chickenhawk` or closest), goat (will need substitute — likely `a_c_cow` scaled discussion → just use the model and note it visually), sheep (same). Each with production cycles, feed requirements, health settings, AI behavior type.
2. **Wool shearing** — Sheep production: `raw_wool` item on shearing interaction. Longer cycle time (4 days).
3. **Goat milk** — `goat_milk` item, similar to cow but lower yield.
4. **Turkey eggs** — `turkey_egg`, longer cycle than chicken.
5. **New feed items** — `chicken_feed`, `pig_slop`, ensure all feed items registered in ox_inventory.

### Phase 4B: Breeding System

**Files:** `server/breeding.lua`, update `client/animals.lua`

**Tasks:**
1. **Breed initiation** — Client: new ox_target option "Breed" appears on female adults when not pregnant. Opens selection dialog listing compatible males in same pen. Server validates: same species, correct genders, both adult, female not pregnant, breeding cooldown elapsed, both health ≥ 70.
2. **Pregnancy tracking** — Sets `is_pregnant`, `pregnancy_start`, `pregnancy_father_uuid`, `breeding_quality` (calculated from parent qualities). State bag update.
3. **Birth processing** — Part of hourly tick in `server/breeding.lua`. Query pregnant animals, check if gestation time elapsed. On birth: create N offspring (per species min/max), random gender, inherit `breeding_quality`, assign to same pen (if capacity allows, else auto-store in barn). Despawn/respawn mother to clear pregnancy state bag. Notify owner.
4. **Offspring quality genetics** — Average of parent quality values with ±0.5 random modifier. Quality tiers: poor(1), average(2), good(3), excellent(4).

### Phase 4C: Animal Growth + Feed Troughs

**Files:** Update `server/animals.lua`, update `client/animals.lua`

**Tasks:**
1. **Growth progression** — Part of a 6-hour tick. Increment `age`, check if current stage `duration` exceeded. On stage advance: update DB, despawn/respawn entity (new state bags for growth_stage label).
2. **Feed trough bulk feeding** — ox_target at feed trough coordinates in pen config. Player adds feed items → server distributes to all animals in that pen, updating `last_fed` for each. More efficient than individual feeding.
3. **Water trough** — Same pattern: interact once, waters all animals in pen.

---

## Phase 5: Progression Systems + Processing + Polish

**Goal:** Challenge/contract system, leaderboard, processing chains, admin commands, final optimization.

### Phase 5A: Processing Chains

**Files:** `server/processing.lua`, `client/processing.lua`, update `config/shared.lua`

**Tasks:**
1. **6 processing stations configured** — Grain Mill (wheat→flour, corn→cornmeal), Cheese Press (raw_milk→cheese_wheel, goat_milk→goat_cheese), Butter Churn (raw_milk→butter), Cider Press (apple→apple_cider), Drying Rack (cranberries→dried_cranberries, cherries→dried_cherries), Wool Processor (raw_wool→processed_wool).
2. **Station interactions** — ox_target at each station location. Client opens recipe selection via `lib.registerContext`. Server validates level requirement, checks inventory for inputs, shows progress bar, removes inputs, adds outputs. Awards XP.
3. **All processing items** — Register all output items in ox_inventory.

### Phase 5B: Challenge System

**Files:** `server/challenges.lua`, update `client/main.lua`

**Tasks:**
1. **Challenge generation** — On player first farming action (or daily refresh), generate 3 active challenges from pool. Store in `farm_challenges` with requirements JSON and expiry.
2. **Progress tracking** — `UpdateChallengeProgress(src, action, data)` called from harvest, milk, egg, feed, breed, and plant callbacks. Updates progress JSON, checks completion.
3. **Completion rewards** — XP bonus + leaderboard points on completion.
4. **Player UI** — `/challenges` command shows active challenges via `lib.registerContext` with progress bars.

### Phase 5C: Leaderboard

**Files:** `server/leaderboard.lua`, update `client/main.lua`

**Tasks:**
1. **Score tracking** — `UpdateLeaderboardScore(identifier, points)` called on challenge completion and major farming actions.
2. **Weekly/monthly reset** — Hourly check thread resets `weekly_score`/`monthly_score` columns.
3. **Display** — `/farmleaderboard` command. Server callback returns top 50 sorted by selected period. Client displays via `lib.alertDialog` or `lib.registerContext`.

### Phase 5D: Admin Commands + Farm Assignment

**Files:** Update `server/main.lua`

**Tasks:**
1. **`/farmassign [farmId] [playerId]`** — Admin command (ace permission) to assign a farm to a player. Adds row to a `farm_ownership` table (or column on farm_fields). When assigned, only that player (and their added workers) can interact.
2. **`/farmunassign [farmId]`** — Removes assignment, returns to open access.
3. **`/farmreset [farmId]`** — Resets all fields to default state, clears animals.
4. **`/farmstatsadmin [playerId]`** — View any player's farming data.

### Phase 5E: Optimization Pass

**Tasks:**
1. **Audit all server threads** — Ensure no redundant DB queries. Batch where possible.
2. **Client idle verification** — Confirm 0.00ms when outside all farm zones. No running threads, no distance checks.
3. **Entity count audit** — Verify spawned entity counts stay within reasonable limits per farm zone.
4. **State bag efficiency** — Only update state bags that actually changed (don't re-set unchanged values).
5. **DB connection pooling** — Verify oxmysql is handling connection reuse properly.
6. **Stress test** — Simulate 25 concurrent farmers across multiple zones.

---

## Item Registry (All Phases)

### Seeds (Phase 1-2)
`corn_seed`, `soybean_seed`, `wheat_seed`, `hay_seed`, `potato_seed`, `pumpkin_seed`, `sugarbeet_seed`, `cranberry_plant`, `cherry_tree`, `apple_tree`, `blueberry_bush`

### Harvested Crops (Phase 1-2)
`corn`, `soybeans`, `wheat`, `hay_bale`, `potato`, `pumpkin`, `sugar_beet`, `cranberries`, `cherries`, `apple`, `blueberries`

### Animal Feed (Phase 3-4)
`hay` (reuse hay_bale), `chicken_feed`, `pig_slop`, `grain`, `silage`

### Animal Products (Phase 3-4)
`raw_milk`, `goat_milk`, `chicken_egg`, `turkey_egg`, `raw_wool`

### Processed Goods (Phase 5)
`flour`, `cornmeal`, `cheese_wheel`, `goat_cheese`, `butter`, `apple_cider`, `dried_cranberries`, `dried_cherries`, `processed_wool`

### Tools/Supplies (Phase 2)
`fertilizer`

---

## Development Order Summary

| Phase | Scope | Key Deliverable |
|-------|-------|----------------|
| **1A** | Skeleton + DB | Resource boots, tables created, zones detected |
| **1B** | Field crop loop | Plow → Plant → Grow → Harvest works end-to-end |
| **1C** | Basic XP | Farming actions award XP, levels up, unlocks tracked |
| **2A** | All crops | 11 total crops with field type + unlock restrictions |
| **2B** | Weather | renewed-weathersync integration affects yield |
| **2C** | Soil depth | Rotation bonuses, degradation, fertilizer, quality tiers |
| **3A** | Animal spawning | Cows/chickens/pigs in pens with AI behavior |
| **3B** | Animal needs | Feed/water/health/production cycles |
| **3C** | Barn storage | Store/release animals, storage degradation |
| **4A** | More animals | Turkey, goat, sheep + wool/goat milk |
| **4B** | Breeding | Mating, pregnancy, birth, genetics |
| **4C** | Growth + troughs | Age progression, bulk feeding |
| **5A** | Processing | 6 stations, 11 recipes |
| **5B** | Challenges | Daily contracts with progress tracking |
| **5C** | Leaderboard | Score tracking with period resets |
| **5D** | Admin tools | Farm assignment, reset commands |
| **5E** | Optimization | Performance audit, stress testing |

---

## Key Architecture Decisions

1. **Props: Server-spawned with OneSync** — Not client-side decoration. Server owns all crop/field entities for authoritative state. `SetEntityOrphanMode(entity, 2)` keeps them persistent.

2. **Animal AI: Client-side via state bags** — Server spawns the ped and sets state bags. The owning client reads bags and applies `Task*` natives. When ownership migrates, new owner re-applies behaviors.

3. **Single growth tick thread** — One server thread processes ALL fields every 5 minutes. No per-field threads. Batch DB query, iterate, batch updates where possible.

4. **Single health tick thread** — One server thread processes ALL animals every hour. Same batch pattern.

5. **lib.callback for all interactions** — Client uses `lib.callback` (not raw server events) for plow/plant/harvest/feed/milk etc. Server validates everything. No trusting client data.

6. **ox_inventory for all items** — Seeds, crops, feed, products, processed goods. Quality stored as item metadata.

7. **No economy integration** — Script produces items. Selling/pricing is handled by external systems or added later.

8. **Weather abstraction** — `server/weather.lua` wraps the weather resource export. If server switches weather resources, only this file changes.
