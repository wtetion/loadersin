
-- ===== GLOBAL COLLECTGARBAGE HOOK (NEUTRALIZES ZOMBIE THREAD ERRORS) =====
if type(getgenv) == "function" then
    local old_cg = getgenv().collectgarbage
    getgenv().collectgarbage = function(opt, ...)
        if opt == "collect" or not opt then
            return gcinfo()
        end
        if type(old_cg) == "function" then
            local s, r = pcall(old_cg, opt, ...)
            if s then return r end
        end
        return gcinfo()
    end
end

-- ===== CLEANUP PREVIOUS INSTANCES & GHOST THREADS (SESSION TOKEN) =====
if getgenv().BG_Connections then
    for _, c in ipairs(getgenv().BG_Connections) do
        pcall(function() c:Disconnect() end)
    end
end
getgenv().BG_Connections = {}

-- Increment global session ID so ANY loop from ANY previous script execution immediately dies!
getgenv().BG_Running = false
getgenv().BG_SessionId = (getgenv().BG_SessionId or 0) + 1
local mySessionId = getgenv().BG_SessionId
getgenv().BG_Running = true

local function isSessionActive()
    return getgenv().BG_Running and (getgenv().BG_SessionId == mySessionId)
end

local function trackConnection(conn)
    table.insert(getgenv().BG_Connections, conn)
    return conn
end

-- ===== EXECUTOR & PROJECT REAL COMPATIBILITY LAYER =====
local function safe_cloneref(obj)
    if cloneref and type(cloneref) == "function" then
        local s, r = pcall(cloneref, obj)
        if s and r then return r end
    end
    return obj
end

local http_request = (type(request) == "function" and request)
    or (syn and type(syn.request) == "function" and syn.request)
    or (http and type(http.request) == "function" and http.request)
    or (fluxus and type(fluxus.request) == "function" and fluxus.request)
    or (type(http_request) == "function" and http_request)

local queue_teleport = (type(queue_on_teleport) == "function" and queue_on_teleport)
    or (syn and type(syn.queue_on_teleport) == "function" and syn.queue_on_teleport)
    or (fluxus and type(fluxus.queue_on_teleport) == "function" and fluxus.queue_on_teleport)

local function get_executor_name()
    if type(identifyexecutor) == "function" then
        local a, b = identifyexecutor()
        return tostring(a) .. (b and (" " .. tostring(b)) or "")
    elseif type(getexecutorname) == "function" then
        return tostring(getexecutorname())
    end
    return "Project Real / Universal"
end

local function safe_setfpscap(cap)
    if type(setfpscap) == "function" then
        pcall(setfpscap, cap)
    end
end

-- ===== SERVICES =====
local Players           = safe_cloneref(game:GetService("Players"))
local RunService        = safe_cloneref(game:GetService("RunService"))
local ReplicatedStorage = safe_cloneref(game:GetService("ReplicatedStorage"))
local HttpService       = safe_cloneref(game:GetService("HttpService"))
local TeleportService   = safe_cloneref(game:GetService("TeleportService"))
local Lighting          = safe_cloneref(game:GetService("Lighting"))
local VirtualUser       = safe_cloneref(game:GetService("VirtualUser"))
local TweenService      = safe_cloneref(game:GetService("TweenService"))
local UserInputService  = safe_cloneref(game:GetService("UserInputService"))

local plr  = Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()

-- JSON Helpers
local function json_encode(val)
    if json and type(json.encode) == "function" then
        local s, r = pcall(json.encode, val)
        if s and r then return r end
    end
    return HttpService:JSONEncode(val)
end

local function json_decode(str)
    if json and type(json.decode) == "function" then
        local s, r = pcall(json.decode, str)
        if s and r then return r end
    end
    return HttpService:JSONDecode(str)
end

-- Clean previous WindUI & Floating Toggle instances before loading
pcall(function()
    local hui = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    for _, v in pairs(hui:GetChildren()) do
        if v.Name:find("WindUI") or v.Name == "BG_FloatingToggle" then
            pcall(function() v:Destroy() end)
        end
    end
    for _, v in pairs(plr.PlayerGui:GetChildren()) do
        if v.Name:find("WindUI") or v.Name == "BG_FloatingToggle" then
            pcall(function() v:Destroy() end)
        end
    end
end)

-- ===== LOAD WINDUI LIBRARY =====
local WindUI
do
    local mirrors = {
        "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",
        "https://tree-hub.vercel.app/api/library/windui",
        "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
    }
    for _, url in ipairs(mirrors) do
        local ok, lib = pcall(function()
            return loadstring(game:HttpGet(url))()
        end)
        if ok and type(lib) == "table" and lib.CreateWindow then
            WindUI = lib
            break
        end
    end
    if not WindUI then
        error("[Beast Garden Hub] Failed to load WindUI.")
    end
end

-- ===== REGISTER YELLOW & BLACK THEME =====
WindUI:AddTheme({
    Name        = "YellowBlack",
    Accent      = "#FFD700",
    Dialog      = "#141414",
    Outline     = "#E5A910",
    Text        = "#FFFFFF",
    Placeholder = "#888888",
    Background  = "#0B0B0D",
    Button      = "#18181A",
    Icon        = "#FFD700",
})

-- ===== GAME DATA & REMOTES =====
local BG      = ReplicatedStorage:WaitForChild("BeastGarden", 15)
local Remotes = BG and BG:WaitForChild("Remotes", 10)
local Config  = require(BG:WaitForChild("Config", 10))

local R = {
    TillAction      = Remotes and Remotes:WaitForChild("TillAction", 5),
    SelectSeed      = Remotes and Remotes:WaitForChild("SelectSeed", 5),
    BuySeed         = Remotes and Remotes:WaitForChild("BuySeed", 5),
    SellProduce     = Remotes and Remotes:WaitForChild("SellProduce", 5),
    FarmAction      = Remotes and Remotes:WaitForChild("FarmAction", 5),
    QuestAction     = Remotes and Remotes:WaitForChild("QuestAction", 5),
    DailyAction     = Remotes and (Remotes:FindFirstChild("DailyAction") or Remotes:WaitForChild("DailyAction", 3)),
    MainQuestAction = Remotes and Remotes:FindFirstChild("MainQuestAction"),
    QuickWarp       = Remotes and Remotes:WaitForChild("QuickWarp", 5),
    Warp            = Remotes and Remotes:WaitForChild("Warp", 5),
    TeamSkill       = Remotes and Remotes:WaitForChild("TeamSkill", 5),
    CardShopAction  = Remotes and Remotes:WaitForChild("CardShopAction", 5),
    FrostChallenge  = Remotes and Remotes:WaitForChild("FrostChallenge", 5),
    ArenaAction     = Remotes and Remotes:WaitForChild("ArenaAction", 5),
    AnimalAction    = Remotes and Remotes:WaitForChild("AnimalAction", 5),
    RefineProduce   = Remotes and Remotes:WaitForChild("RefineProduce", 5),
    HatchEgg        = Remotes and Remotes:WaitForChild("HatchEgg", 5),
    EggAction       = Remotes and Remotes:WaitForChild("EggAction", 5),
    FizzAction      = Remotes and Remotes:WaitForChild("FizzAction", 5),
}

-- Default Tables (Auto-Overwritten by live syncWithGameConfig)
local ALL_SEEDS = {
    {id="Carrot",            name="Carrot",            rarity="Common",    price=2,    sell=5, inShop=true},
    {id="Strawberry",        name="Strawberry",        rarity="Common",    price=5,    sell=11, inShop=true},
    {id="LifeApple",         name="LifeApple",         rarity="Common",    price=10,   sell=22, inShop=true},
    {id="StonePumpkin",      name="StonePumpkin",      rarity="Common",    price=20,   sell=45, inShop=true},
    {id="Moonflower",        name="Moonflower",        rarity="Uncommon",  price=40,   sell=95, inShop=true},
    {id="ThunderCorn",       name="ThunderCorn",       rarity="Uncommon",  price=70,   sell=165, inShop=true},
    {id="GlowBerry",         name="GlowBerry",         rarity="Uncommon",  price=110,  sell=260, inShop=true},
    {id="FrostGrape",        name="FrostGrape",        rarity="Rare",      price=250,  sell=600, inShop=true},
    {id="CrystalMelon",      name="CrystalMelon",      rarity="Rare",      price=400,  sell=960, inShop=true},
    {id="LavaPepper",        name="LavaPepper",        rarity="Rare",      price=600,  sell=1450, inShop=true},
    {id="DragonFruit",       name="DragonFruit",       rarity="Epic",      price=880,  sell=2200, inShop=true},
    {id="SpiritPomegranate", name="SpiritPomegranate", rarity="Epic",      price=1050, sell=2600, inShop=true},
    {id="StarPeach",         name="StarPeach",         rarity="Legendary", price=1350, sell=3450, inShop=true},
    {id="CelestialLotus",    name="CelestialLotus",    rarity="Legendary", price=1500, sell=4000, inShop=true},
    {id="WorldTreeSeed",     name="WorldTreeSeed",     rarity="Mythic",    price=2800, sell=7800, inShop=true},
    {id="FizzLime",          name="FizzLime",          rarity="Legendary", price=0,    sell=9000, inShop=false},
    {id="FizzCherry",        name="FizzCherry",        rarity="Legendary", price=0,    sell=9000, inShop=false},
    {id="FizzEggplant",      name="FizzEggplant",      rarity="Mythic",    price=0,    sell=16000, inShop=false},
    {id="FizzPineapple",     name="FizzPineapple",     rarity="Mythic",    price=0,    sell=16000, inShop=false},
    {id="FizzDurian",        name="FizzDurian",        rarity="Mythic",    price=0,    sell=28000, inShop=false},
}

local ZONES = {
    {n=1, name="Z1-Meadow",  monsters={"HoneyGuard","Slime","KingSlime","WildBunny","PuddingSlime","SproutWalker","RoseMatriarch"}, boss="RoseMatriarch", pow=120},
    {n=2, name="Z2-Shroom",  monsters={"Shroomling","GlowMoth","NightMoth","SporeFox","LanternToad","ElderShroom","SporeTitan"}, boss="SporeTitan", pow=260},
    {n=3, name="Z3-Crystal", monsters={"CrystalGolem","CrystalBat","AmethystBat","CrystalTitan"}, boss="CrystalTitan", pow=520},
    {n=4, name="Z4-Storm",   monsters={"CloudWisp","StormHawk","ThunderWisp","TempestHawk","StormRoc","StormTitan"}, boss="StormRoc", pow=1260},
    {n=5, name="Z5-Lava",    monsters={"LavaSalamander","MagmaImp","AshGolem","InfernoImp","LavaDragonKing","MagmaTitan"}, boss="LavaDragonKing", pow=2700},
    {n=6, name="Z6-Desert",  monsters={"ThornLizard","GoldScorpion","RubyScorpion","SandDragonKing","DuneBehemoth"}, boss="SandDragonKing", pow=8000},
    {n=7, name="Z7-Abyss",   monsters={"TridentGuard","MagmaShark","AbyssGuard","AbyssBrute","Leviathan"}, boss="Leviathan", pow=16000},
    {n=8, name="Z8-Greed",   monsters={"HoardDrake","GoldWyvern","GildedSalamander","GreedDragon","HoardTyrant"}, boss="GreedDragon", pow=45000},
    {n=9, name="Z9-Clock",   monsters={"Z9_WindupSoldier","Z9_GearSpider","Z9_RepairBee","Z9_BoilerTortoise","Z9_Colossus","Z9_Forge","Z9_Engine","Z9_Sky"}, boss="Z9_Colossus", pow=100000},
}

local EGGS = {
    {id="BasicEgg",    name="Basic Egg",              price="300c"},
    {id="CrystalEgg",  name="Crystal Egg",            price="1,500c"},
    {id="MagicEgg",    name="Magic Egg",              price="5,000c"},
    {id="IceEgg",      name="Ice Egg",                price="120 Ice"},
    {id="InfernoEgg",  name="Inferno Egg",            price="30,000c"},
    {id="MiracleEgg",  name="Miracle Egg",            price="250,000c"},
}

local HOUSE_TIERS = {
    {id="House_Tier1_Cottage", level=1, name="บ้านกระท่อม", price=0},
    {id="House_Tier2_Farmhouse", level=8, name="บ้านฟาร์ม", price=25000},
    {id="House_Tier3_Manor", level=18, name="คฤหาสน์", price=150000}
}
local ORCHARD_TREES = {}

-- ==============================================================================
-- 🔄 DYNAMIC GAME CONFIG INTROSPECTION (NO HARDCODING — ADAPTS TO ALL GAME UPDATES)
-- ==============================================================================
local function syncWithGameConfig()
    if not Config then return end

    -- 1. Dynamic Crop & Seed Engine
    local dynamicSeeds = {}
    local sorted = (type(Config.SortedCropIds) == "function" and Config.SortedCropIds()) or {}
    local seenSeeds = {}

    local function addCropData(id, c)
        if not seenSeeds[id] and c then
            seenSeeds[id] = true
            table.insert(dynamicSeeds, {
                id     = id,
                name   = c.name or id,
                rarity = c.rarity or c.tier or "Common",
                price  = c.seedPrice or c.price or 0,
                sell   = c.sellPrice or c.sell or 0,
                inShop = (c.inShop ~= false) and ((c.seedPrice or c.price or 0) > 0)
            })
        end
    end

    for _, id in ipairs(sorted) do
        addCropData(id, Config.Crops and Config.Crops[id])
    end
    if Config.Crops then
        for id, c in pairs(Config.Crops) do
            addCropData(id, c)
        end
    end
    if #dynamicSeeds > 0 then
        ALL_SEEDS = dynamicSeeds
    end

    -- 2. Dynamic Zone Monsters & Bosses
    if Config.ZoneMonsters then
        local dynamicZones = {}
        for i, mobs in ipairs(Config.ZoneMonsters) do
            local bossName = (Config.ZoneBoss and Config.ZoneBoss[i]) or (mobs and mobs[#mobs]) or ("Boss_Z" .. i)
            local zoneTitle = "Z" .. i .. "-Zone" .. i
            table.insert(dynamicZones, {
                n        = i,
                name     = zoneTitle,
                monsters = mobs,
                boss     = bossName,
                pow      = i * 1500
            })
        end
        if #dynamicZones > 0 then
            ZONES = dynamicZones
        end
    end

    -- 3. Dynamic Egg Tiers
    if Config.Eggs then
        local dynamicEggs = {}
        for k, v in pairs(Config.Eggs) do
            table.insert(dynamicEggs, {
                id    = k,
                name  = v.name or k,
                price = (v.price and (tostring(v.price) .. (v.currency == "iceCrystals" and " Ice" or "c"))) or "0c",
                order = v.order or 99,
                curr  = v.currency or "coins"
            })
        end
        table.sort(dynamicEggs, function(a, b) return (a.order or 99) < (b.order or 99) end)
        if #dynamicEggs > 0 then
            EGGS = dynamicEggs
        end
    end

    -- 4. Dynamic House Tiers
    if Config.HouseTiers then
        HOUSE_TIERS = Config.HouseTiers
    end

    -- 5. Dynamic Orchard Fruit Trees
    if Config.Orchard and Config.Orchard.Trees then
        ORCHARD_TREES = Config.Orchard.Trees
    end
end
pcall(syncWithGameConfig)

local function getMonstersForZone(zoneNum)
    local list = {}
    local seen = {}

    -- 1. Scan live models in workspace.Map.Monsters first for 100% real accuracy
    pcall(function()
        local m = workspace:FindFirstChild("Map")
        local monstersFolder = m and m:FindFirstChild("Monsters")
        if monstersFolder then
            for _, mdl in ipairs(monstersFolder:GetChildren()) do
                if mdl:IsA("Model") and not mdl:GetAttribute("DiedAt") then
                    local z = mdl:GetAttribute("Zone")
                    if tonumber(z) == tonumber(zoneNum) then
                        local mId = mdl:GetAttribute("MonsterId") or mdl.Name
                        if mId and not seen[mId] then
                            seen[mId] = true
                            table.insert(list, mId)
                        end
                    end
                end
            end
        end
    end)

    -- 2. If workspace didn't have all, merge with verified database
    for _, z in ipairs(ZONES) do
        if z.n == tonumber(zoneNum) then
            for _, m in ipairs(z.monsters) do
                if not seen[m] then
                    seen[m] = true
                    table.insert(list, m)
                end
            end
            if z.boss and not seen[z.boss] then
                seen[z.boss] = true
                table.insert(list, z.boss)
            end
            break
        end
    end
    table.sort(list)
    return list
end

local WARPS = {
    {id="Farm",          label="Farm Plot"},
    {id="Market",        label="Market & Shop"},
    {id="SeedShop",      label="Seed Shop"},
    {id="Hatchery",      label="Egg Hatchery"},
    {id="BeastWorkshop", label="Beast Workshop"},
    {id="NorthGate",     label="North Gate"},
    {id="FarmBook",      label="Farm Book"},
}

local ALL_CARDS_OPTS = {}
if Config and Config.Cards then
    for cid, c in pairs(Config.Cards) do
        local r = c.rarity or "Common"
        local n = c.name or cid
        table.insert(ALL_CARDS_OPTS, string.format("[%s] %s (%s)", r, n, cid))
    end
    table.sort(ALL_CARDS_OPTS)
end

local POS_QUEST_NPC     = Vector3.new(-29.4, 7.6, -70.8)
local POS_HATCHERY_PAD  = Vector3.new(-47.566, 3.2, -46.687)
local POS_CARD_SHOP     = Vector3.new(72.88, 3.2, -2.85)
local POS_SEED_SHOP     = Vector3.new(-72.88, 3.5, -2.85)
local POS_TOWN_WARP     = Vector3.new(0, 3, -22)
local POS_ARENA_BOARD   = Vector3.new(25.3, 4.55, -59.5)
local POS_FROST_STATUE  = Vector3.new(-28, 2.1, -6)

local function toVector3(val)
    if typeof(val) == "Vector3" then
        return val
    elseif type(val) == "string" then
        local x, y, z = val:match("([%d%.%-]+)%s*,%s*([%d%.%-]+)%s*,%s*([%d%.%-]+)")
        if x and y and z then
            return Vector3.new(tonumber(x), tonumber(y), tonumber(z))
        end
    end
    return nil
end

-- ===== GLOBAL STATE TABLE =====
local S = {
    -- Movement & Lock
    moveMode          = "Teleport",
    tweenSpeed        = 150,

    -- Gold Egg Priority #1
    autoGoldEgg       = false,

    -- Farm & Market
    autoFarm          = false,
    cropInterval      = 20,
    autoBuySeed       = false,
    autoBuyBeds       = false,
    plantSeedId       = "Carrot",
    selectedSeeds     = {"Carrot"},
    buyAmount         = 5,
    autoWaterSprinkler= false,
    sprinklerType     = "Rainbow",
    autoBuySprinkler  = false,
    selectedSprinklersToBuy = { ["Rainbow"] = true, ["Gold"] = true },
    autoSellOn        = false,
    autoSellSecs      = 45,
    sellMode          = "ALL",
    autoPenCollect      = false,
    penCollectInterval  = 45,
    autoPenBest         = false,
    autoPenFeed         = false,
    penFeedInterval     = 25,
    penFeedMode         = "Feed All Safe (Common/Uncommon)",
    autoHarvestFruit    = false,
    fruitInterval       = 30,
    autoUpgradeHouse    = false,
    autoEquipBestAll    = false,
    autoRefineProduce   = false,

    -- Combat & Boss
    autoFarmMobs      = false,
    autoTargetMonster = false,
    combatFloat       = true,
    combatFloatHeight = 11,
    warpZone          = 1,
    selectedMonsters  = {},
    mobPriority       = "Closest First",
    autoTeamSkill     = false,
    selectedBosses    = {},
    autoBossHunt      = false,
    autoBossServerHop = false,

    -- Quests & Dungeons
    autoMainQuest     = false,
    autoQuestOn       = false,
    questInterval     = 30,
    autoColosseum     = false,
    arenaMode         = "start",
    autoTower         = false,
    towerFloor        = 1,
    autoDungeon       = false,
    selectedDungeon   = "All Dungeons (วนทุกดัน)",
    dungeonTargetMode = "Clear All Mobs + Boss (กวาดมอนทุกตัว + บอส)",
    dungeonInterval   = 40,

    -- Pets & Gacha
    autoCardPull      = false,
    stopOnCards       = {},
    autoBuyCardTicket = false,
    autoBuyEgg        = false,
    buyEggType        = "BasicEgg",
    selectedEggsToBuy = { ["BasicEgg"] = true },
    buyEggAmount      = 1,
    buyEggInterval    = 5,
    hatchEggType      = "BasicEgg",
    hatchEggAmount    = 1,
    autoHatchEgg      = false,
    autoOpenAllEggs   = false,
    autoFillIncubator   = false,
    selectedEggsToPlace = { ["BasicEgg"] = true, ["CrystalEgg"] = true },
    autoBestTeam      = false,
    autoBestGuard     = false,
    fizzTradeSeedId   = "FizzLime",
    autoFizzTrade     = false,

    -- Performance & Anti-AFK
    lowGraphic        = false,
    rendering3D       = true,
    antiAFK           = false,
    fpsCap            = 60,

    -- Webhook & Activity
    webhookUrl        = "",
    webhookAutoLog    = false,
    webhookInterval   = 120,
    currentActivity   = "Ready",
    currentLocation   = "Farm Plot",

    -- Config System
    configName        = "default",
    autoLoadConfig    = false,
}
getgenv().BG_Settings = S

-- UI references
local logCodeElement = nil
local mobFilterDropdown = nil
local goldEggStatusPara = nil

-- Forward declarations to eliminate nil call errors
local isGoldEggActive = nil
local getGoldEggStatusString = nil
local getDecoratedLogString = nil
local doRealFarmCycle = nil
local buySeedsAtShop = nil
local buySeedsBatch = nil
local getSeedStockRemaining = nil
local doSellCycle = nil
local doPenCoinCollect = nil
local doEquipBestAll = nil
local doFruitTreeHarvest = nil
local doUpgradeHouse = nil
local doRefineAllProduce = nil
local doBuyBedGroups = nil
local doPenFeedCycle = nil
local doCardPullCycle = nil

-- ===== HELPER FUNCTIONS =====
local function invoke(remote, ...)
    if not remote then return false, "No remote" end
    local args = {...}
    local ok, a, b, c = pcall(function() return remote:InvokeServer(table.unpack(args)) end)
    return ok and a, b, c
end

local function fire(remote, ...)
    if not remote then return end
    local args = {...}
    pcall(function() remote:FireServer(table.unpack(args)) end)
end

local function notify(title, msg)
    pcall(function()
        WindUI:Notify({ Title = title, Content = msg or "", Duration = 3 })
    end)
end

local function parseMultiDropdown(sel)
    local items = {}
    if type(sel) == "table" then
        for k, v in pairs(sel) do
            if type(k) == "number" and type(v) == "string" then
                table.insert(items, v)
            elseif type(k) == "string" and (v == true or v == "true" or type(v) == "table") then
                table.insert(items, k)
            elseif type(v) == "string" then
                table.insert(items, v)
            end
        end
    elseif type(sel) == "string" and sel ~= "" then
        table.insert(items, sel)
    end
    return items
end

local function getHRP()
    char = plr.Character or plr.CharacterAdded:Wait()
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- Movement Engine
local activeTween = nil
local function moveToCFrame(targetCF, onFinish)
    local root = getHRP()
    if not root then return end

    if S.moveMode == "Tween" then
        if activeTween then
            activeTween:Cancel()
            activeTween = nil
        end
        local currentPos = root.Position
        local targetPos = targetCF.Position
        local dist = (currentPos - targetPos).Magnitude
        local speed = math.clamp(S.tweenSpeed or 150, 40, 500)
        local dur = math.max(0.08, dist / speed)

        local ti = TweenInfo.new(dur, Enum.EasingStyle.Linear)
        activeTween = TweenService:Create(root, ti, {CFrame = targetCF})
        activeTween:Play()
        activeTween.Completed:Once(function()
            activeTween = nil
            if onFinish then onFinish() end
        end)
    else
        root.CFrame = targetCF
        if onFinish then onFinish() end
    end
end

-- 90° Combat Facing Positioner (Single Clean Warp, No Repeated Snaps) + Safe Float/Hover Engine
local currentCombatTarget = nil
local lastCombatWarpTime = 0
local combatHoverBV = nil

local function enableCombatHover(enable)
    local root = getHRP()
    if not root then return end
    if enable then
        if not combatHoverBV or not combatHoverBV.Parent then
            combatHoverBV = Instance.new("BodyVelocity")
            combatHoverBV.Name = "BG_CombatHover"
            combatHoverBV.Velocity = Vector3.new(0, 0, 0)
            combatHoverBV.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            combatHoverBV.Parent = root
        end
    else
        if combatHoverBV then
            pcall(function() combatHoverBV:Destroy() end)
            combatHoverBV = nil
        end
    end
end

local function moveAndFaceMonster(targetPart, targetModel)
    local root = getHRP()
    if not root or not targetPart then return end

    local model = targetModel or targetPart:FindFirstAncestorOfClass("Model")
    local mobPos = targetPart.Position
    local dist = (root.Position - mobPos).Magnitude

    local isFloat = (S.combatFloat ~= false)
    local hoverHeight = tonumber(S.combatFloatHeight) or 11

    if isFloat then
        enableCombatHover(true)
    else
        enableCombatHover(false)
    end

    -- If already engaged and within attack range, DO NOT re-teleport! Only smoothly orient facing downwards
    local maxEngageDist = isFloat and 14 or 12
    if currentCombatTarget == model and dist <= maxEngageDist and (tick() - lastCombatWarpTime < 4) then
        currentCombatTarget = model
        root.CFrame = CFrame.lookAt(root.Position, mobPos)
        return
    end

    currentCombatTarget = model
    lastCombatWarpTime = tick()

    local targetPos
    if isFloat then
        -- Hover above monster in the air (Safely out of monster/boss melee & ground slam range, pets still shred!)
        targetPos = mobPos + Vector3.new(0, hoverHeight, 2.0)
    else
        targetPos = mobPos + Vector3.new(0, 2.5, 4.0)
    end
    local combatCF = CFrame.lookAt(targetPos, mobPos)

    root.CFrame = combatCF
end

-- ===== FIZZ GOLDEN EGG STATE DETECTION =====
isGoldEggActive = function()
    local fState = BG and BG:GetAttribute("FizzState")
    local fEggMode = BG and BG:GetAttribute("FizzEggMode")
    local fEnds = tonumber(BG and BG:GetAttribute("FizzEnds")) or 0
    local fDropAt = tonumber(BG and BG:GetAttribute("FizzDropAt")) or 0
    local fHolder = tonumber(BG and BG:GetAttribute("FizzHolder")) or 0
    local now = workspace:GetServerTimeNow()

    if fHolder and fHolder > 0 then return true end
    if fState and (fState == "live" or fState == "warn" or (fState ~= "idle" and fState ~= "none")) then return true end
    if fEggMode and fEggMode ~= "none" and fEggMode ~= "idle" then return true end
    if fEnds > now and now >= fDropAt then return true end
    return false
end

getGoldEggStatusString = function()
    local fState = (BG and BG:GetAttribute("FizzState")) or "idle"
    local fHolder = tonumber(BG and BG:GetAttribute("FizzHolder")) or 0
    local fEnds = tonumber(BG and BG:GetAttribute("FizzEnds")) or 0
    local fNext = tonumber(BG and BG:GetAttribute("FizzNextAt")) or 0
    local now = workspace:GetServerTimeNow()

    if fHolder == plr.UserId then
        return "🌟 YOU are holding the Gold Egg! (Farming Tickets...)"
    elseif fHolder > 0 then
        local holderPlr = Players:GetPlayerByUserId(fHolder)
        local hName = holderPlr and holderPlr.Name or tostring(fHolder)
        return "🥚 Held by player: " .. hName .. " (Chasing & casting...)"
    elseif isGoldEggActive() then
        return "🥚 Gold Egg is dropped in Arena! (Grabbing now...)"
    elseif fNext > now then
        local sec = math.floor(fNext - now)
        return string.format("⏳ Next Gold Egg event in: %02d:%02d", math.floor(sec/60), sec%60)
    end
    return "💤 Idle (Waiting for event)"
end

-- ===== LIVE DATA CACHE & SERVER SYNCHRONIZATION =====
local CachedData = {
    coins = 0,
    farmXP = 0,
    farmLevel = 1,
    selectedSeed = nil,
    seeds = {},
    produce = {},
    pen = {},
    animals = {},
    penBank = { bank = 0, goods = {} },
}

trackConnection(Remotes.DataChanged.OnClientEvent:Connect(function(d)
    if type(d) == "table" then
        for k, v in pairs(d) do
            CachedData[k] = v
        end
        if type(getDecoratedLogString) == "function" then
            local ok, logStr = pcall(getDecoratedLogString)
            if ok and logCodeElement and logCodeElement.SetCode and type(logStr) == "string" then
                pcall(function() logCodeElement:SetCode(logStr) end)
            end
        end
    end
end))
getgenv().CachedData = CachedData

task.spawn(function()
    task.wait(0.3)
    pcall(function() Remotes.RequestData:FireServer() end)
end)

local function formatCommas(val)
    local n = math.floor(tonumber(val) or 0)
    local s = tostring(n)
    return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

-- Live Inventories & Stats
local function getInventorySeeds()
    if CachedData.seeds and next(CachedData.seeds) ~= nil then
        return CachedData.seeds
    end
    local counts = {}
    pcall(function()
        local slots = plr.PlayerGui.FarmHUD.ScaledRoot.Hotbar.Slots
        for _, slot in ipairs(slots:GetChildren()) do
            for _, lbl in ipairs(slot:GetChildren()) do
                if lbl:IsA("TextLabel") and lbl.Text:match("^x(%d+)") then
                    local n = tonumber(lbl.Text:match("^x(%d+)"))
                    if n and n > 0 then
                        counts[slot.Name] = n
                    end
                end
            end
        end
    end)
    return counts
end

local function getSeedWorth(seedId)
    if not seedId or seedId == "" then return 0 end
    for _, s in ipairs(ALL_SEEDS) do
        if s.id == seedId then
            local p = tonumber(s.price) or 0
            if p > 0 then return p end
            return tonumber(s.sell) or 0
        end
    end
    if Config and Config.Crops and Config.Crops[seedId] then
        local c = Config.Crops[seedId]
        local p = tonumber(c.seedPrice or c.price) or 0
        if p > 0 then return p end
        return tonumber(c.sellPrice or c.sell) or 0
    end
    return 0
end

local function getSortedSeeds(seedList)
    local list = {}
    local seen = {}
    for _, s in ipairs(seedList or {}) do
        if s and s ~= "" and not seen[s] then
            seen[s] = true
            table.insert(list, s)
        end
    end
    table.sort(list, function(a, b)
        local worthA = getSeedWorth(a)
        local worthB = getSeedWorth(b)
        if worthA ~= worthB then
            return worthA > worthB -- Most expensive seed first!
        end
        return tostring(a) < tostring(b)
    end)
    return list
end

local function getInventoryEggs()
    local counts = {}
    pcall(function()
        local eggBagUI = plr.PlayerGui:FindFirstChild("EggBagUI")
        if eggBagUI then
            for _, obj in ipairs(eggBagUI:GetDescendants()) do
                if obj.Name:find("^Egg_") and obj:IsA("Frame") then
                    local eggId = obj.Name:gsub("^Egg_", "")
                    local countLbl = obj:FindFirstChild("Count", true)
                    if countLbl and countLbl:IsA("TextLabel") then
                        local n = tonumber(countLbl.Text:match("%d+")) or 0
                        if n > 0 then
                            counts[eggId] = n
                        end
                    end
                end
            end
        end
    end)
    return counts
end

local function getPlayerStats()
    local coinsNum = CachedData.coins or tonumber(plr:GetAttribute("Coins")) or 0
    local farmLevel = CachedData.farmLevel or plr:GetAttribute("FarmLevel") or 1
    local coins = formatCommas(coinsNum)
    local level = "Lv " .. tostring(farmLevel)
    local xp = formatCommas(CachedData.farmXP or 0) .. " XP"
    local teamPower = plr:GetAttribute("TeamPower") or 0
    local fizzTickets = plr:GetAttribute("FizzTickets") or 0
    local mqStep = plr:GetAttribute("MQStep") or 1
    local seeds = getInventorySeeds()
    local eggs = getInventoryEggs()
    local produce = CachedData.produce or {}
    local penCoins = formatCommas(CachedData.penBank and CachedData.penBank.bank or 0)

    return {
        coins = coins,
        coinsNum = coinsNum,
        level = level,
        xp = xp,
        teamPower = teamPower,
        fizzTickets = fizzTickets,
        farmLevel = farmLevel,
        mqStep = mqStep,
        seeds = seeds,
        produce = produce,
        eggs = eggs,
        penCoins = penCoins
    }
end

getDecoratedLogString = function()
    local stats = getPlayerStats()
    local timeStr = os.date("%H:%M:%S")

    -- Seed summary
    local seedList = {}
    for sName, sCount in pairs(stats.seeds or {}) do
        table.insert(seedList, sName .. " x" .. sCount)
    end
    local seedStr = #seedList > 0 and table.concat(seedList, ", ") or "None"

    -- Produce summary
    local prodList = {}
    for pName, pCount in pairs(stats.produce or {}) do
        table.insert(prodList, pName .. " x" .. pCount)
    end
    local prodStr = #prodList > 0 and table.concat(prodList, ", ") or "None"

    -- Egg summary
    local eggList = {}
    for eName, eCount in pairs(stats.eggs or {}) do
        table.insert(eggList, eName .. " x" .. eCount)
    end
    local eggStr = #eggList > 0 and table.concat(eggList, ", ") or "None"

    local lines = {
        "========================================",
        "      BEAST GARDEN HUB — PRO LOGS       ",
        "========================================",
        string.format(" Player    : %s", plr.Name),
        string.format(" Location  : %s", S.currentLocation or "Farm Plot"),
        string.format(" Activity  : %s", S.currentActivity or "Idle"),
        string.format(" Coins     : %s 💰", stats.coins),
        string.format(" Level     : %s (%s)", stats.level, stats.xp),
        string.format(" Team Pow  : %s ⚡", tostring(stats.teamPower)),
        string.format(" MainQuest : Step %s 📜", tostring(stats.mqStep)),
        string.format(" Fizz Tix  : %s 🎟️", tostring(stats.fizzTickets)),
        string.format(" Pen Bank  : %s 🪙", tostring(stats.penCoins)),
        string.format(" Seeds     : %s", seedStr),
        string.format(" Produce   : %s", prodStr),
        string.format(" Eggs Bag  : %s", eggStr),
        string.format(" Log Time  : %s", timeStr),
        string.format(" Executor  : %s", get_executor_name()),
        "========================================"
    }
    return table.concat(lines, "\n")
end

local function logActivity(act, loc)
    S.currentActivity = act or S.currentActivity
    if loc then S.currentLocation = loc end

    local logStr = getDecoratedLogString()
    if logCodeElement and logCodeElement.SetCode then
        pcall(function() logCodeElement:SetCode(logStr) end)
    end
end

-- Discord Webhook Sender
local function sendDiscordWebhook(title, customDesc)
    if not S.webhookUrl or S.webhookUrl == "" or not S.webhookUrl:find("https://") then
        return false, "No valid Webhook URL"
    end

    local stats = getPlayerStats()

    local seedList = {}
    for sName, sCount in pairs(stats.seeds or {}) do table.insert(seedList, sName .. " x" .. sCount) end
    local seedStr = #seedList > 0 and table.concat(seedList, ", ") or "None"

    local prodList = {}
    for pName, pCount in pairs(stats.produce or {}) do table.insert(prodList, pName .. " x" .. pCount) end
    local prodStr = #prodList > 0 and table.concat(prodList, ", ") or "None"

    local eggList = {}
    for eName, eCount in pairs(stats.eggs or {}) do table.insert(eggList, eName .. " x" .. eCount) end
    local eggStr = #eggList > 0 and table.concat(eggList, ", ") or "None"

    local embed = {
        title = title or "Beast Garden Hub — Live Status Report",
        color = 16766720,
        description = customDesc or ("**Current Action**: `" .. (S.currentActivity or "Farming") .. "` at **" .. (S.currentLocation or "Farm Plot") .. "**"),
        fields = {
            { name = "👤 Player",        value = "`" .. plr.Name .. "`",                     inline = true },
            { name = "💰 Wallet Coins",   value = "`" .. stats.coins .. " Coins`",            inline = true },
            { name = "⭐ Level & XP",    value = "`" .. stats.level .. " (" .. stats.xp .. ")`", inline = true },
            { name = "⚡ Team Power",     value = "`" .. tostring(stats.teamPower) .. " Power`", inline = true },
            { name = "🎟️ Fizz Tickets",  value = "`" .. tostring(stats.fizzTickets) .. " Tickets`", inline = true },
            { name = "🪙 Pen Coins",     value = "`" .. tostring(stats.penCoins) .. " Coins`", inline = true },
            { name = "📜 Main Quest",    value = "`Step " .. tostring(stats.mqStep) .. "`",   inline = true },
            { name = "📍 Zone",          value = "`" .. (S.currentLocation or "Farm Plot") .. "`", inline = true },
            { name = "🌱 Seeds in Bag",   value = "`" .. seedStr .. "`",                       inline = false },
            { name = "🍓 Produce in Bag", value = "`" .. prodStr .. "`",                       inline = false },
            { name = "🥚 Eggs in Bag",    value = "`" .. eggStr .. "`",                        inline = false },
            { name = "💻 Executor",       value = "`" .. get_executor_name() .. "`",          inline = false },
        },
        footer = {
            text = "made by ud0 Custom • discord.gg/axel hub",
            icon_url = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=150&height=150&format=png"
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    local payload = {
        username = "Beast Garden Hub [ud0]",
        avatar_url = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=150&height=150&format=png",
        embeds = { embed }
    }

    local body = json_encode(payload)
    local headers = { ["Content-Type"] = "application/json" }

    if http_request then
        local success, res = pcall(function()
            return http_request({
                Url = S.webhookUrl,
                Method = "POST",
                Headers = headers,
                Body = body
            })
        end)
        if success and res then
            local status = res.StatusCode or res.status_code or 200
            if status >= 200 and status < 300 then
                return true, "Success (HTTP " .. status .. ")"
            else
                return false, "HTTP Error: " .. status
            end
        else
            return false, tostring(res)
        end
    end
    return false, "HTTP request not available"
end

-- ===== CONFIG SYSTEM (JSON) =====
local CONFIG_FOLDER = "BeastGarden_ud0_Configs"
if makefolder and not (isfolder and isfolder(CONFIG_FOLDER)) then
    pcall(makefolder, CONFIG_FOLDER)
end

local function getAllConfigs()
    local list = {}
    if listfiles and isfolder and isfolder(CONFIG_FOLDER) then
        for _, path in ipairs(listfiles(CONFIG_FOLDER)) do
            local name = path:match("([%w_%-]+)%.json$")
            if name and name ~= "autoload" then
                table.insert(list, name)
            end
        end
    end
    if #list == 0 then table.insert(list, "default") end
    return list
end

local function saveConfig(name)
    if not writefile then return notify("Config", "Filesystem not supported") end
    name = (name and name ~= "") and name or "default"
    local cfg = {
        moveMode          = S.moveMode,
        tweenSpeed        = S.tweenSpeed,
        autoGoldEgg       = S.autoGoldEgg,
        autoFarm          = S.autoFarm,
        cropInterval      = S.cropInterval,
        autoBuySeed       = S.autoBuySeed,
        autoBuyBeds       = S.autoBuyBeds,
        plantSeedId       = S.plantSeedId,
        selectedSeeds     = S.selectedSeeds,
        buyAmount         = S.buyAmount,
        autoSellOn        = S.autoSellOn,
        autoSellSecs      = S.autoSellSecs,
        sellMode          = S.sellMode,
        autoFarmMobs      = S.autoFarmMobs,
        autoTargetMonster = S.autoTargetMonster,
        warpZone          = S.warpZone,
        selectedMonsters  = S.selectedMonsters,
        mobPriority       = S.mobPriority,
        autoTeamSkill     = S.autoTeamSkill,
        selectedBosses    = S.selectedBosses,
        autoBossHunt      = S.autoBossHunt,
        autoBossServerHop = S.autoBossServerHop,
        autoQuestOn       = S.autoQuestOn,
        questInterval     = S.questInterval,
        autoColosseum     = S.autoColosseum,
        arenaMode         = S.arenaMode,
        autoTower         = S.autoTower,
        towerFloor        = S.towerFloor,
        autoDungeon       = S.autoDungeon,
        selectedDungeon   = S.selectedDungeon,
        dungeonTargetMode = S.dungeonTargetMode,
        dungeonInterval   = S.dungeonInterval,
        autoCardPull      = S.autoCardPull,
        stopOnCards       = S.stopOnCards,
        autoBuyCardTicket = S.autoBuyCardTicket,
        autoBuyEgg        = S.autoBuyEgg,
        buyEggType        = S.buyEggType,
        selectedEggsToBuy = S.selectedEggsToBuy,
        buyEggAmount      = S.buyEggAmount,
        buyEggInterval    = S.buyEggInterval,
        hatchEggType      = S.hatchEggType,
        hatchEggAmount    = S.hatchEggAmount,
        autoHatchEgg      = S.autoHatchEgg,
        autoPenCollect      = S.autoPenCollect,
        penCollectInterval  = S.penCollectInterval,
        autoPenBest         = S.autoPenBest,
        autoPenFeed         = S.autoPenFeed,
        penFeedMode         = S.penFeedMode,
        autoHarvestFruit    = S.autoHarvestFruit,
        fruitInterval       = S.fruitInterval,
        autoUpgradeHouse    = S.autoUpgradeHouse,
        autoEquipBestAll    = S.autoEquipBestAll,
        autoRefineProduce   = S.autoRefineProduce,
        autoMainQuest     = S.autoMainQuest,
        fizzTradeSeedId   = S.fizzTradeSeedId,
        autoFizzTrade     = S.autoFizzTrade,
        autoOpenAllEggs     = S.autoOpenAllEggs,
        autoFillIncubator   = S.autoFillIncubator,
        selectedEggsToPlace = S.selectedEggsToPlace,
        autoBestTeam      = S.autoBestTeam,
        autoBestGuard     = S.autoBestGuard,
        lowGraphic        = S.lowGraphic,
        rendering3D       = S.rendering3D,
        antiAFK           = S.antiAFK,
        fpsCap            = S.fpsCap,
        webhookUrl        = S.webhookUrl,
        webhookAutoLog    = S.webhookAutoLog,
        webhookInterval   = S.webhookInterval,
    }
    local jsonStr = json_encode(cfg)
    local ok, err = pcall(writefile, CONFIG_FOLDER .. "/" .. name .. ".json", jsonStr)
    if ok then
        notify("Config Saved", "Saved as " .. name .. ".json")
    else
        notify("Config Error", "Failed: " .. tostring(err))
    end
end

local function loadConfig(name)
    if not readfile or not isfile then return notify("Config", "Filesystem not supported") end
    name = (name and name ~= "") and name or "default"
    local filePath = CONFIG_FOLDER .. "/" .. name .. ".json"
    if not isfile(filePath) then return notify("Config", "Config not found: " .. name) end

    local ok, content = pcall(readfile, filePath)
    if not ok or not content then return notify("Config", "Failed to read config") end

    local sDecode, data = pcall(json_decode, content)
    if not sDecode or type(data) ~= "table" then return notify("Config", "Invalid JSON format") end

    for k, v in pairs(data) do
        if S[k] ~= nil then S[k] = v end
    end
    notify("Config Loaded", "Loaded " .. name .. ".json")
    logActivity("Config Applied: " .. name, S.currentLocation)
end

local function deleteConfig(name)
    if not delfile or not isfile then return end
    name = (name and name ~= "") and name or "default"
    local filePath = CONFIG_FOLDER .. "/" .. name .. ".json"
    if isfile(filePath) then
        pcall(delfile, filePath)
        notify("Config Deleted", "Removed " .. name .. ".json")
    end
end

if isfile and isfile(CONFIG_FOLDER .. "/autoload.json") then
    pcall(function()
        local raw = readfile(CONFIG_FOLDER .. "/autoload.json")
        local d = json_decode(raw)
        if d and d.autoload then loadConfig(d.autoload) end
    end)
end

-- ===== PROXIMITY-AWARE SEED SHOP & FARM ENGINE =====
local function getMyPlot()
    local m = workspace:FindFirstChild("Map")
    local b = m and m:FindFirstChild("Blockout")
    local plots = b and b:FindFirstChild("Plots")
    if not plots then return nil end

    for _, p in ipairs(plots:GetChildren()) do
        if p:GetAttribute("OwnerUserId") == plr.UserId then
            return p
        end
    end
    return nil
end

local function getMyPlotCenter()
    local myPlot = getMyPlot()
    if not myPlot then return nil end
    local beds = myPlot:FindFirstChild("CropBeds")
    if beds then
        local sum = Vector3.new(0, 0, 0)
        local count = 0
        for _, b in ipairs(beds:GetChildren()) do
            local cf = b:GetPivot()
            sum = sum + cf.Position
            count = count + 1
        end
        if count > 0 then
            return sum / count + Vector3.new(0, 1.5, 0)
        end
    end
    local ground = myPlot:FindFirstChild("PlotGround") or myPlot.PrimaryPart or myPlot:FindFirstChildOfClass("BasePart")
    return ground and (ground.Position + Vector3.new(0, 3, 0))
end

local isBuyingSeeds = false

getSeedStockRemaining = function(seedId)
    local cd = CachedData or getgenv().CachedData or {}
    local restockId = (Config and Config.RestockId and Config.RestockId(workspace:GetServerTimeNow())) or cd.stockId or 0
    local roll = (cd.stockId == restockId and cd.stockRoll) or 0
    local fLevel = cd.farmLevel or 1
    if not Config or not Config.SeedStock then return 999 end

    local currentStock = Config.SeedStock(restockId, plr.UserId, roll, fLevel)
    if not currentStock or not currentStock[seedId] then
        return 0
    end

    local totalStock = tonumber(currentStock[seedId]) or 0
    local bought = (cd.stockId == restockId and cd.stockBought and cd.stockBought[seedId]) or 0
    return math.max(0, totalStock - bought)
end

buySeedsBatch = function(seedItems, isForce)
    if isBuyingSeeds then return false end
    if not seedItems or #seedItems == 0 then return false end

    -- Pre-filter: only items that actually have stock > 0
    local validItems = {}
    for _, item in ipairs(seedItems) do
        local rem = getSeedStockRemaining(item.id)
        if rem > 0 then
            table.insert(validItems, {
                id = item.id,
                amount = math.min(item.amount or 5, rem)
            })
        end
    end

    if #validItems == 0 then
        if isForce then
            notify("Seed Shop", "เมล็ดที่เลือกทั้งหมดไม่มีสินค้าในสต็อก (รอร้านค้ารีสต็อก)!")
        end
        return false
    end

    isBuyingSeeds = true
    logActivity(string.format("Warping to Seed Shop (Buying %d in-stock types)...", #validItems), "Seed Shop")
    invoke(R.QuickWarp, "SeedShop")
    task.wait(1.2)

    local cd = CachedData or getgenv().CachedData or {}
    local anySuccess = false
    local boughtSummary = {}

    for _, item in ipairs(validItems) do
        local toBuy = math.min(item.amount, getSeedStockRemaining(item.id))
        if toBuy > 0 then
            local ok, msg = invoke(R.BuySeed, item.id, toBuy)
            if ok then
                anySuccess = true
                cd.stockBought = cd.stockBought or {}
                cd.stockBought[item.id] = (cd.stockBought[item.id] or 0) + toBuy
                table.insert(boughtSummary, string.format("%s x%d", item.id, toBuy))
            end
            task.wait(0.3)
        end
    end

    if anySuccess then
        local msg = "ซื้อเมล็ดสำเร็จ: " .. table.concat(boughtSummary, ", ")
        notify("Seed Shop", msg)
        logActivity(msg, "Seed Shop")
    elseif isForce then
        notify("Seed Shop", "Failed to purchase seeds from shop")
    end

    task.wait(0.3)
    invoke(R.QuickWarp, "Farm")
    task.wait(0.8)
    local center = getMyPlotCenter()
    local root = getHRP()
    if center and root then
        root.CFrame = CFrame.new(center)
    end
    task.wait(0.4)
    if validItems[1] then
        fire(R.SelectSeed, validItems[1].id)
    end

    isBuyingSeeds = false
    return anySuccess
end

buySeedsAtShop = function(seedId, amount, isForce)
    seedId = seedId or S.plantSeedId or "Carrot"
    amount = amount or S.buyAmount or 5

    local inStock = getSeedStockRemaining(seedId)
    if inStock <= 0 then
        if isForce then
            notify("Seed Shop", string.format("เมล็ด %s สินค้าหมดสต็อก (รอร้านค้ารี)!", seedId))
        end
        return false
    end

    return buySeedsBatch({ { id = seedId, amount = math.min(amount, inStock) } }, isForce)
end

local function getMyPlotCells()
    local cells = {}
    local myPlot = getMyPlot()
    if not myPlot then return cells end

    if myPlot:FindFirstChild("CropBeds") then
        local seen = {}
        for _, bed in pairs(myPlot.CropBeds:GetChildren()) do
            for _, child in pairs(bed:GetChildren()) do
                if child.Name:find("^Cell_") then
                    local r, c = child.Name:match("(%d+)_(%d+)")
                    if r and c and not seen[r .. "_" .. c] then
                        seen[r .. "_" .. c] = true
                        table.insert(cells, {
                            part = child,
                            bed = bed.Name,
                            row = tonumber(r),
                            col = tonumber(c),
                            pos = child.Position
                        })
                    end
                end
            end
        end
    end
    return cells
end

local function getMyPlotBeds()
    local myPlot = getMyPlot()
    if not myPlot then return {} end
    local cropBeds = myPlot:FindFirstChild("CropBeds")
    if not cropBeds then return {} end

    local beds = {}
    for _, bed in ipairs(cropBeds:GetChildren()) do
        local cells = {}
        local seen = {}
        for _, ch in ipairs(bed:GetChildren()) do
            if ch.Name:find("^Cell_") then
                local r, c = ch.Name:match("(%d+)_(%d+)")
                if r and c and not seen[r .. "_" .. c] then
                    seen[r .. "_" .. c] = true
                    table.insert(cells, {
                        name = ch.Name,
                        part = ch,
                        row = tonumber(r),
                        col = tonumber(c),
                        pos = ch.Position
                    })
                end
            end
        end
        table.insert(beds, {
            name = bed.Name,
            center = bed:GetPivot().Position,
            cells = cells
        })
    end
    table.sort(beds, function(a, b)
        local nA = tonumber(a.name:match("%d+")) or 0
        local nB = tonumber(b.name:match("%d+")) or 0
        return nA < nB
    end)
    return beds
end

-- ==============================================================================
-- 🚜 AUTO BUY CROP BED GROUPS ENGINE (ซื้อแปลงผักทั้งกลุ่ม 3x3 เมื่อเงินถึง)
-- ==============================================================================
local isBuyingBeds = false
doBuyBedGroups = function(force)
    if isBuyingBeds then return end
    if not force and not S.autoBuyBeds then return end
    isBuyingBeds = true

    local myPlot = getMyPlot()
    if not myPlot then isBuyingBeds = false return end
    local cropBeds = myPlot:FindFirstChild("CropBeds")
    if not cropBeds then isBuyingBeds = false return end

    local currentCoins = CachedData.coins or plr:GetAttribute("Coins") or 0
    local farmLevel = CachedData.farmLevel or plr:GetAttribute("FarmLevel") or 1
    local maxClusters = (Config and Config.BedClusters and Config.BedClusters(farmLevel)) or 16

    local boughtAny = false
    for i = 1, maxClusters do
        if not getgenv().BG_Running then break end
        if not force and not S.autoBuyBeds then break end
        if S.autoGoldEgg and isGoldEggActive and isGoldEggActive() then break end

        -- Check if Bed_i is already owned
        if not cropBeds:FindFirstChild("Bed_" .. i) then
            local price = (Config and Config.BedGroupPrice and Config.BedGroupPrice(i)) or 999999
            if currentCoins >= price then
                local r0, c0 = Config.BedOrigin(i)
                if r0 and c0 then
                    -- Warp to bed position
                    local worldPos = Config.SoilGrid and Config.SoilGrid.CellWorld and Config.SoilGrid.CellWorld(myPlot, r0 + 1, c0 + 1)
                    local root = getHRP()
                    if worldPos and root then
                        root.CFrame = CFrame.new(worldPos + Vector3.new(0, 2.5, 0))
                        task.wait(0.35)
                    end

                    logActivity("Buying Bed Group #" .. i .. " (" .. formatCommas(price) .. " coins)...", "Farm Plot")
                    local ok, res = invoke(R.TillAction, "buyGroup", { r0, c0 })
                    if ok and type(res) == "table" and res.ok then
                        boughtAny = true
                        currentCoins = currentCoins - price
                        notify("Bed Unlocked!", res.msg or ("Unlocked Bed Group #" .. i .. " (9 Beds)!"))
                        logActivity(res.msg or ("Unlocked Bed Group #" .. i), "Farm Plot")
                        task.wait(0.4)
                    else
                        if force and type(res) == "table" and res.msg then
                            notify("Crop Bed", res.msg)
                        end
                        break
                    end
                end
            else
                -- Not enough coins for this bed group yet
                break
            end
        end
    end

    if boughtAny and S.autoFarm then
        local center = getMyPlotCenter()
        local root = getHRP()
        if center and root then
            root.CFrame = CFrame.new(center)
            task.wait(0.3)
        end
    end

    isBuyingBeds = false
end

-- Real Farm Cycle: Bed-by-Bed Proximity Sweep (100% Reach & Coverage, Zero Missed Spots)
local isFarming = false
doRealFarmCycle = function()
    if isFarming then return end
    isFarming = true

    local myPlot = getMyPlot()
    local farmCenter = getMyPlotCenter()
    local root = getHRP()

    if farmCenter and root then
        local distFromCenter = (root.Position - farmCenter).Magnitude
        if distFromCenter > 35 then
            invoke(R.QuickWarp, "Farm")
            task.wait(0.8)
            root = getHRP()
            if root then root.CFrame = CFrame.new(farmCenter) end
            task.wait(0.4)
        end
    end

    local beds = getMyPlotBeds()
    if #beds > 0 then
        -- Find crops folder for our plot
        local plotName = myPlot and myPlot.Name or "Plot_1"
        local mapFolder = workspace:FindFirstChild("Map")
        local cropsRoot = mapFolder and mapFolder:FindFirstChild("Crops")
        local plotCrops = cropsRoot and cropsRoot:FindFirstChild(plotName)

        -- Phase 1: Pre-scan all beds to identify work needed
        local bedsToProcess = {}
        local totalSeedsNeeded = 0
        local totalRipeCount = 0
        local totalEmptyCount = 0

        for _, bed in ipairs(beds) do
            local ripeCells = {}
            local emptyCells = {}
            for _, cell in ipairs(bed.cells) do
                local cropModel = plotCrops and plotCrops:FindFirstChild("Crop_" .. cell.row .. "_" .. cell.col)
                if cropModel then
                    local stage = cropModel:GetAttribute("Stage") or 0
                    if stage >= 3 then
                        table.insert(ripeCells, cell)
                        totalRipeCount = totalRipeCount + 1
                    end
                else
                    table.insert(emptyCells, cell)
                    totalEmptyCount = totalEmptyCount + 1
                end
            end
            if #ripeCells > 0 or #emptyCells > 0 then
                table.insert(bedsToProcess, {
                    name = bed.name,
                    center = bed.center,
                    ripeCells = ripeCells,
                    emptyCells = emptyCells
                })
                totalSeedsNeeded = totalSeedsNeeded + #ripeCells + #emptyCells
            end
        end

        logActivity(string.format("Farm Sweep: %d Beds Need Work (%d Ripe, %d Empty)", #bedsToProcess, totalRipeCount, totalEmptyCount), "Farm Plot")

        if #bedsToProcess > 0 and getgenv().BG_Running then
            -- Phase 2: Check inventory seeds and buy if needed
            local rawSeeds = (S.selectedSeeds and #S.selectedSeeds > 0 and S.selectedSeeds) or { S.plantSeedId or "Carrot" }
            local seedsToUse = getSortedSeeds(rawSeeds)
            if #seedsToUse == 0 then seedsToUse = { "Carrot" } end

            local seedsInBag = getInventorySeeds()
            local bagCounts = {}
            local totalHave = 0
            for _, sId in ipairs(seedsToUse) do
                local c = tonumber(seedsInBag[sId]) or 0
                bagCounts[sId] = c
                totalHave = totalHave + c
            end

            if totalHave < totalSeedsNeeded and S.autoBuySeed then
                local neededTotal = totalSeedsNeeded - totalHave
                local buyQueue = {}

                -- Inspect selected seeds in tier order (most expensive first)
                -- If a seed has NO stock in shop: SKIP IT WITHOUT WARPING!
                -- Only queue seeds that actually have remaining stock!
                for _, sId in ipairs(seedsToUse) do
                    if totalHave >= totalSeedsNeeded then break end
                    local inStock = getSeedStockRemaining(sId)
                    if inStock > 0 then
                        local toBuy = math.min(neededTotal, inStock, S.buyAmount or 5)
                        if toBuy > 0 then
                            table.insert(buyQueue, { id = sId, amount = toBuy })
                            totalHave = totalHave + toBuy
                            neededTotal = totalSeedsNeeded - totalHave
                        end
                    end
                end

                -- ONLY WARP TO SEED SHOP IF WE HAVE AT LEAST ONE SEED IN STOCK TO BUY!
                if #buyQueue > 0 then
                    buySeedsBatch(buyQueue, false)
                    seedsInBag = getInventorySeeds()
                    totalHave = 0
                    for _, sId in ipairs(seedsToUse) do
                        local c = tonumber(seedsInBag[sId]) or 0
                        bagCounts[sId] = c
                        totalHave = totalHave + c
                    end
                end
            end

            -- Phase 3: Bed-by-Bed Proximity Harvest & Plant Sweep
            local seedNamesStr = table.concat(seedsToUse, " > ")
            local seedPointer = 1
            local playerMoved = false

            for _, bed in ipairs(bedsToProcess) do
                if not S.autoFarm or not getgenv().BG_Running then break end
                if S.autoGoldEgg and isGoldEggActive and isGoldEggActive() then break end

                root = getHRP()
                if not root then break end

                -- Step to bed center if player is further than 7 studs (ensures all 9 cells are within ~5.6 studs!)
                local distToBed = (root.Position - bed.center).Magnitude
                if distToBed > 7 then
                    root.CFrame = CFrame.new(bed.center + Vector3.new(0, 1.5, 0))
                    playerMoved = true
                    task.wait(0.06)
                end

                -- Sub-pass A: Harvest all ripe cells in this bed
                local newlyEmptied = {}
                for _, cell in ipairs(bed.ripeCells) do
                    if not S.autoFarm or not getgenv().BG_Running then break end
                    if S.autoGoldEgg and isGoldEggActive and isGoldEggActive() then break end

                    local ok, res = invoke(R.TillAction, "use", { cell.row, cell.col }, nil)
                    if ok and type(res) == "table" and res.ok then
                        table.insert(newlyEmptied, cell)
                    else
                        table.insert(newlyEmptied, cell)
                    end
                    task.wait(0.03)
                end

                -- Combine existing empty cells and newly harvested cells for planting
                local cellsToPlant = {}
                for _, c in ipairs(bed.emptyCells) do table.insert(cellsToPlant, c) end
                for _, c in ipairs(newlyEmptied) do table.insert(cellsToPlant, c) end

                -- Sub-pass B: Plant all empty cells in this bed
                for _, cell in ipairs(cellsToPlant) do
                    if not S.autoFarm or not getgenv().BG_Running then break end
                    if S.autoGoldEgg and isGoldEggActive and isGoldEggActive() then break end

                    while seedPointer <= #seedsToUse and (bagCounts[seedsToUse[seedPointer]] or 0) <= 0 do
                        seedPointer = seedPointer + 1
                    end

                    local chosenSeed
                    if seedPointer <= #seedsToUse then
                        chosenSeed = seedsToUse[seedPointer]
                        bagCounts[chosenSeed] = bagCounts[chosenSeed] - 1
                    else
                        chosenSeed = seedsToUse[1] or S.plantSeedId or "Carrot"
                    end

                    fire(R.SelectSeed, chosenSeed)
                    invoke(R.TillAction, "use", { cell.row, cell.col }, chosenSeed)
                    task.wait(0.03)
                end
            end

            -- Phase 4: Smooth return to center after sweep
            if playerMoved and farmCenter then
                root = getHRP()
                if root then
                    root.CFrame = CFrame.new(farmCenter)
                    task.wait(0.1)
                end
            end
        end
    end

    isFarming = false
end

-- ==============================================================================
-- 🪙 ANIMAL PEN COIN COLLECTION ENGINE (CONFIGURABLE INTERVAL & AUTO WARP)
-- ==============================================================================
local isCollectingCoins = false
doPenCoinCollect = function(force)
    if isCollectingCoins then return end
    if not force and not S.autoPenCollect then return end
    isCollectingCoins = true

    local myPlot = getMyPlot()
    if not myPlot then isCollectingCoins = false return end

    local chest = myPlot:FindFirstChild("PenChest")
    local chestBody = chest and (chest:FindFirstChild("Body") or chest.PrimaryPart or chest:FindFirstChildOfClass("BasePart"))
    local root = getHRP()
    if not chestBody or not root then isCollectingCoins = false return end

    -- Warp directly in front of Pen Chest
    local chestTargetCF = CFrame.lookAt(chestBody.Position + Vector3.new(0, 2.5, 3.0), chestBody.Position)
    root.CFrame = chestTargetCF
    task.wait(0.35)

    -- Abort if toggle was turned off during warp
    if not force and not S.autoPenCollect then
        isCollectingCoins = false
        return
    end

    local ok, msg = invoke(R.FarmAction, "penCollect")
    local msgStr = (type(msg) == "string" and msg) or (ok and "Collected Pen Coins!" or "No coins to collect")
    if ok and type(msg) == "string" and msg ~= "" and msg:find("%+") then
        notify("Pen Coins", msg)
        logActivity(msg, "Animal Pen")
    elseif force then
        notify("Pen Coins", msgStr)
    end

    task.wait(0.3)
    -- If crop farming is active, return smoothly to center of crop beds
    if S.autoFarm then
        local center = getMyPlotCenter()
        if center then
            root = getHRP()
            if root then root.CFrame = CFrame.new(center) end
        end
    end
    isCollectingCoins = false
end

-- ==============================================================================
-- 🐾 EQUIP BEST ANIMALS (ALL SLOTS: PEN MONEY + GUARD + COMBAT TEAM)
-- ==============================================================================
local isEquippingBest = false
doEquipBestAll = function(force)
    if isEquippingBest then return end
    if not force and not S.autoEquipBestAll then return end
    isEquippingBest = true

    local myPlot = getMyPlot()
    local chest = myPlot and myPlot:FindFirstChild("PenChest")
    local chestBody = chest and (chest:FindFirstChild("Body") or chest.PrimaryPart or chest:FindFirstChildOfClass("BasePart"))
    local root = getHRP()

    -- Single clean warp to Animal Yard
    if chestBody and root then
        local penTargetCF = CFrame.lookAt(chestBody.Position + Vector3.new(0, 2.5, 4.0), chestBody.Position)
        root.CFrame = penTargetCF
        task.wait(0.4)
    end

    logActivity("Filling Empty Slots & Equipping Best Animals...", "Animal Pen")

    -- Ensure latest player data is loaded
    if not CachedData or not CachedData.animals or next(CachedData.animals) == nil then
        pcall(function() Remotes.RequestData:FireServer() end)
        task.wait(0.3)
    end

    -- 1. Pen Enclosure: Fill ALL unlocked slots with the best money-making animals
    local maxPenSlots = 3
    if Config and type(Config.PenSlotsFor) == "function" then
        maxPenSlots = Config.PenSlotsFor(CachedData.farmLevel or 1, CachedData.houseTier or 1) or 3
    end

    -- Try native penBest first
    pcall(function() invoke(R.FarmAction, "penBest") end)
    task.wait(0.4)

    -- If pen still has empty slots, inspect all owned animals and fill every empty slot!
    local currentPen = {}
    if CachedData and type(CachedData.pen) == "table" then
        for _, uid in ipairs(CachedData.pen) do
            table.insert(currentPen, uid)
        end
    end

    if #currentPen < maxPenSlots and CachedData and type(CachedData.animals) == "table" then
        local candidates = {}
        for uid, a in pairs(CachedData.animals) do
            if not table.find(currentPen, uid) then
                local rate = 0
                if Config and type(Config.PenRate) == "function" then
                    rate = Config.PenRate(a, CachedData.penLv or 1) or 0
                else
                    rate = (a.lv or 1) * 10
                end
                table.insert(candidates, { uid = uid, a = a, rate = rate })
            end
        end

        table.sort(candidates, function(x, y) return x.rate > y.rate end)

        local needed = maxPenSlots - #currentPen
        for i = 1, math.min(needed, #candidates) do
            local cand = candidates[i]
            if not table.find(currentPen, cand.uid) then
                local ok, msg = invoke(R.FarmAction, "penToggle", cand.uid)
                if ok then
                    table.insert(currentPen, cand.uid)
                end
                task.wait(0.35)
            end
        end
    end

    -- 2. Guard Enclosure (Farm Defenders) - Fill guards with remaining animals
    invoke(R.AnimalAction, "best", "guard")
    task.wait(0.4)

    -- 3. Hunting Team (Monster Combat) - Fill team with best combat animals
    invoke(R.AnimalAction, "best", "team")
    task.wait(0.3)

    local penCount = #currentPen
    local isFullBonus = (penCount >= maxPenSlots and " • Full Capacity x2 Active!") or ""
    local summary = string.format("คอกสัตว์: %d/%d ตัว%s | ทีมล่า: %d ตัว", penCount, maxPenSlots, isFullBonus, (CachedData.team and #CachedData.team) or 0)
    notify("Equip Best All", summary)
    logActivity(summary, "Animal Pen")

    if S.autoFarm then
        local center = getMyPlotCenter()
        if center then
            root = getHRP()
            if root then root.CFrame = CFrame.new(center) end
        end
    end
    isEquippingBest = false
end

-- ==============================================================================
-- 🍎 ORCHARD FRUIT TREE HARVEST ENGINE (treeHarvest)
-- ==============================================================================
local isHarvestingFruit = false
doFruitTreeHarvest = function(force)
    if isHarvestingFruit then return end
    if not force and not S.autoHarvestFruit then return end
    isHarvestingFruit = true

    local myPlot = getMyPlot()
    local treesFolder = myPlot and myPlot:FindFirstChild("Trees")
    if not treesFolder or #treesFolder:GetChildren() == 0 then
        if force then notify("Orchard", "No fruit trees planted on your plot!") end
        isHarvestingFruit = false
        return
    end

    local root = getHRP()
    local count = 0
    for _, treeModel in ipairs(treesFolder:GetChildren()) do
        if not getgenv().BG_Running then break end
        if S.autoGoldEgg and isGoldEggActive and isGoldEggActive() then break end

        local treeKey = treeModel:GetAttribute("TreeKey") or treeModel.Name:match("Tree_(.+)") or treeModel.Name
        local pivot = treeModel:GetPivot()

        if root and pivot then
            root.CFrame = pivot + Vector3.new(0, 2.5, 3.0)
            task.wait(0.3)
        end

        local ok, res = invoke(R.FarmAction, "treeHarvest", treeKey)
        if ok and type(res) == "string" and res ~= "" then
            count = count + 1
            notify("Orchard Fruit", res)
            logActivity(res, "Orchard")
        end
        task.wait(0.2)
    end

    if force and count == 0 then
        notify("Orchard", "All fruit trees checked (no ripe fruits).")
    end

    if S.autoFarm then
        local center = getMyPlotCenter()
        if center then
            root = getHRP()
            if root then root.CFrame = CFrame.new(center) end
        end
    end
    isHarvestingFruit = false
end

-- ==============================================================================
-- 🏡 HOUSE UPGRADE ENGINE (house)
-- ==============================================================================
local isUpgradingHouse = false
doUpgradeHouse = function(force)
    if isUpgradingHouse then return end
    if not force and not S.autoUpgradeHouse then return end
    isUpgradingHouse = true

    local myPlot = getMyPlot()
    local plotName = myPlot and myPlot.Name
    local builds = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Builds")
    local plotBuilds = builds and plotName and builds:FindFirstChild(plotName)
    local houseModel = plotBuilds and plotBuilds:FindFirstChild("House")

    local curTier = (houseModel and (houseModel:GetAttribute("HouseTier") or houseModel:GetAttribute("Tier"))) or 1
    local nextTier = curTier + 1
    local tiers = (Config and Config.HouseTiers) or HOUSE_TIERS

    if not tiers or not tiers[nextTier] then
        if force then notify("House Upgrade", "House is already at MAX tier (" .. curTier .. ")!") end
        isUpgradingHouse = false
        return
    end

    local nextInfo = tiers[nextTier]
    local pLevel = CachedData.farmLevel or 1
    local pCoins = CachedData.coins or 0

    if pLevel < (nextInfo.level or 0) then
        if force then notify("House Upgrade", string.format("Level %d needed (You: Lv.%d)", nextInfo.level, pLevel)) end
        isUpgradingHouse = false
        return
    end

    if pCoins < (nextInfo.price or 0) then
        if force then notify("House Upgrade", string.format("%d coins needed (You: %d)", nextInfo.price, pCoins)) end
        isUpgradingHouse = false
        return
    end

    -- Warp to House Upgrade Spot
    local root = getHRP()
    if houseModel and root then
        local upgradeSpot = houseModel:FindFirstChild("UpgradeSpot")
        local targetCF = (upgradeSpot and upgradeSpot.CFrame) or houseModel:GetPivot()
        root.CFrame = targetCF + Vector3.new(0, 3.0, 0)
        task.wait(0.4)
    end

    local ok, res = invoke(R.FarmAction, "house")
    local resStr = (type(res) == "string" and res) or (ok and ("Upgraded to " .. (nextInfo.name or ("Tier " .. nextTier))) or "Failed to upgrade house")
    notify("House Upgrade", resStr)
    logActivity("House: " .. resStr, "Farm Plot")

    if S.autoFarm then
        local center = getMyPlotCenter()
        if center then
            root = getHRP()
            if root then root.CFrame = CFrame.new(center) end
        end
    end
    isUpgradingHouse = false
end

-- ==============================================================================
-- 🧪 ALCHEMY PRODUCE REFINE ENGINE (RefineProduce)
-- ==============================================================================
local isRefiningProduce = false
doRefineAllProduce = function(force)
    if isRefiningProduce then return end
    if not force and not S.autoRefineProduce then return end
    isRefiningProduce = true

    local ok, msg = invoke(R.RefineProduce, { produce = "all" })
    local msgStr = (type(msg) == "string" and msg) or (ok and "Refined produce into Essence!" or "No refinable produce")
    if ok or force then
        notify("Alchemy Tower", msgStr)
        logActivity("Alchemy: " .. msgStr, "Farm Plot")
    end
    isRefiningProduce = false
end

-- ===== REAL WORKING AUTO BUY EGG ENGINE (HATCHERY SHOPPAD WARP & RETURN) =====
local isBuyingEgg = false
local function doBuyEggCycle(force)
    if isBuyingEgg then return end
    isBuyingEgg = true

    pcall(function()
        local qty = S.buyEggAmount or S.hatchEggAmount or 1
        local cd = getgenv().CachedData or {}
        local myCoins = tonumber(cd.coins) or 0
        local myIce = tonumber(cd.iceCrystals) or 0

        -- Collect list of eggs to buy
        local eggsToBuy = {}
        if S.selectedEggsToBuy and next(S.selectedEggsToBuy) ~= nil then
            for eggKey, enabled in pairs(S.selectedEggsToBuy) do
                if enabled then
                    local cleanEggId = eggKey:match("^([%w_]+)") or eggKey
                    table.insert(eggsToBuy, cleanEggId)
                end
            end
        else
            local targetEgg = S.buyEggType or S.hatchEggType or "BasicEgg"
            local cleanEggId = targetEgg:match("^([%w_]+)") or targetEgg
            table.insert(eggsToBuy, cleanEggId)
        end

        if #eggsToBuy == 0 then
            isBuyingEgg = false
            return
        end

        -- Check if at least one egg can be afforded
        local anyAffordable = force
        for _, eggId in ipairs(eggsToBuy) do
            local eggDef = Config and Config.Eggs and Config.Eggs[eggId]
            local price = eggDef and eggDef.price or 300
            local totalCost = price * qty
            local curr = eggDef and eggDef.currency or "coins"
            if (curr == "coins" and myCoins >= totalCost) or (curr == "iceCrystals" and myIce >= totalCost) then
                anyAffordable = true
                break
            end
        end

        if not anyAffordable then
            isBuyingEgg = false
            return
        end

        -- Save previous position
        local root = getHRP()
        local prevCF = root and root.CFrame

        -- Warp to Hatchery ShopPad (Required by game server)
        if root then
            root.CFrame = CFrame.new(POS_HATCHERY_PAD)
            task.wait(0.35)
        end

        -- Buy each affordable egg
        for _, eggId in ipairs(eggsToBuy) do
            local eggDef = Config and Config.Eggs and Config.Eggs[eggId]
            local price = eggDef and eggDef.price or 300
            local totalCost = price * qty
            local curr = eggDef and eggDef.currency or "coins"

            local canAfford = force or (curr == "coins" and myCoins >= totalCost) or (curr == "iceCrystals" and myIce >= totalCost)
            if canAfford then
                logActivity(string.format("🥚 Buying %dx %s (%s)", qty, eggId, formatCommas(totalCost)), "Hatchery")
                local ok, res1, res2 = pcall(function()
                    return invoke(R.HatchEgg, eggId, qty)
                end)
                if ok and curr == "coins" then
                    myCoins = myCoins - totalCost
                end
                task.wait(0.25)
            end
        end

        -- Return to previous position seamlessly
        root = getHRP()
        if root and prevCF then
            root.CFrame = prevCF
            task.wait(0.2)
        end
    end)

    isBuyingEgg = false
end

-- Auto Place Eggs in Incubator (Non-blocking)
local isFillingIncubator = false
local function doFillIncubatorCycle(force)
    if isFillingIncubator then return end
    isFillingIncubator = true

    pcall(function()
        local eggBag = getgenv().CachedData and getgenv().CachedData.eggBag or {}
        local eggsToPlace = {}
        if S.selectedEggsToPlace and next(S.selectedEggsToPlace) ~= nil then
            for eggId, isSel in pairs(S.selectedEggsToPlace) do
                if isSel then
                    local cleanEggId = eggId:match("^([%w_]+)") or eggId
                    table.insert(eggsToPlace, cleanEggId)
                end
            end
        else
            table.insert(eggsToPlace, "BasicEgg")
        end

        for slot = 1, 5 do
            if not S.autoFillIncubator and not force then break end
            for _, eggId in ipairs(eggsToPlace) do
                local count = eggBag[eggId] or 0
                if count > 0 or force then
                    local ok, res = invoke(R.EggAction, "fill", eggId, slot)
                    if ok then
                        eggBag[eggId] = math.max(0, count - 1)
                        task.wait(0.4)
                        break
                    end
                end
            end
            task.wait(0.35)
        end
    end)

    isFillingIncubator = false
end

-- ==============================================================================
-- 🥩 ANIMAL PEN FEEDING ENGINE (penFeed)
-- ==============================================================================
local isFeedingPen = false
doPenFeedCycle = function(force)
    if isFeedingPen then return end
    if not force and not S.autoPenFeed then return end
    isFeedingPen = true

    local cd = CachedData or getgenv().CachedData or {}
    local penList = cd.pen
    if not penList or type(penList) ~= "table" or #penList == 0 then
        if force then notify("Animal Pen", "ไม่มีสัตว์อยู่ในคอกเลย!") end
        isFeedingPen = false
        return
    end

    local produce = cd.produce
    if not produce or type(produce) ~= "table" or next(produce) == nil then
        if force then notify("Animal Pen", "ไม่มีผลผลิตในกระเป๋าสำหรับให้อาหาร!") end
        isFeedingPen = false
        return
    end

    local feedMaxRemote = (Config and Config.Pen and Config.Pen.FeedMax) or 50
    local targetMode = S.penFeedMode or "Feed All Safe (Common/Uncommon)"
    local penLv = cd.penLv or 1
    local totalPiecesFed = 0
    local animalsFedCount = 0

    for _, uid in ipairs(penList) do
        if not getgenv().BG_Running then break end
        if S.autoGoldEgg and isGoldEggActive and isGoldEggActive() then break end

        local a = cd.animals and cd.animals[uid]
        if a then
            local maxFd = (Config and Config.PenFoodMax and Config.PenFoodMax(a, penLv)) or 1000
            local curFd = tonumber(a.fd) or 0
            local neededFd = maxFd - curFd

            if neededFd > 10 then
                local feedable = {}
                for cropId, count in pairs(produce) do
                    local n = tonumber(count) or 0
                    if n > 0 then
                        local cDef = Config and Config.Crops and Config.Crops[cropId]
                        local rarity = cDef and cDef.rarity or "Common"
                        local price = (cDef and cDef.sellPrice) or 0
                        local foodAmt, expAmt, isFav = 15, 3, false
                        if Config and type(Config.PenFood) == "function" then
                            foodAmt, expAmt, isFav = Config.PenFood(cropId, a.s)
                        end

                        local isAllowed = false
                        if targetMode:find("Common/Uncommon") or targetMode:find("Non-Legendary") then
                            isAllowed = (rarity == "Common" or rarity == "Uncommon")
                        elseif targetMode:find("Rare") then
                            isAllowed = (rarity == "Common" or rarity == "Uncommon" or rarity == "Rare")
                        elseif targetMode == cropId then
                            isAllowed = true
                        end

                        if isAllowed then
                            table.insert(feedable, {
                                id = cropId,
                                count = n,
                                food = foodAmt or 15,
                                exp = expAmt or 3,
                                fav = isFav or false,
                                price = price
                            })
                        end
                    end
                end

                table.sort(feedable, function(x, y)
                    if x.fav ~= y.fav then return x.fav end
                    return x.price < y.price
                end)

                for _, item in ipairs(feedable) do
                    if item.count > 0 and neededFd > 10 then
                        local piecesNeeded = math.ceil(neededFd / math.max(1, item.food))
                        local toFeed = math.min(item.count, piecesNeeded, feedMaxRemote)

                        if toFeed > 0 then
                            local ok, res = invoke(R.FarmAction, "penFeed", uid, { c = item.id, n = toFeed })
                            if ok then
                                item.count = item.count - toFeed
                                produce[item.id] = math.max(0, (produce[item.id] or toFeed) - toFeed)
                                local gained = toFeed * item.food
                                neededFd = neededFd - gained
                                a.fd = curFd + gained
                                curFd = a.fd
                                totalPiecesFed = totalPiecesFed + toFeed
                                animalsFedCount = animalsFedCount + 1
                                task.wait(0.2)
                            else
                                task.wait(0.15)
                            end
                        end
                    end
                end
            end
        end
    end

    if totalPiecesFed > 0 then
        local summary = string.format("ให้อาหารสัตว์ %d ตัว สำเร็จ (ใช้ผลผลิต %d ชิ้น)", animalsFedCount, totalPiecesFed)
        notify("Animal Pen", summary)
        logActivity(summary, "Animal Pen")
    elseif force then
        notify("Animal Pen", "สัตว์ในคอกทุกตัวอิ่มแล้ว หรือไม่มีผลผลิตที่ตรงเงื่อนไข")
    end

    isFeedingPen = false
end

-- ==============================================================================
-- 🃏 CARD GACHA ENGINE (WARP TO CARD SHRINE -> BUY TICKET -> PULL 10X -> RETURN)
-- ==============================================================================
local isPullingCards = false
doCardPullCycle = function(force)
    if isPullingCards then return end
    if not force and not S.autoCardPull then return end
    isPullingCards = true

    local root = getHRP()
    if not root then isPullingCards = false return end

    local prevCF = root.CFrame

    logActivity("Warping to Card Shrine...", "Card Shop")
    root.CFrame = CFrame.new(POS_CARD_SHOP)
    task.wait(0.4)

    if S.autoBuyCardTicket then
        local cd = CachedData or getgenv().CachedData or {}
        local myCoins = tonumber(cd.coins) or 0
        if force or myCoins >= 2500 then
            local okTicket, resTicket = invoke(R.CardShopAction, "buyticket")
            if okTicket and type(resTicket) == "string" and resTicket ~= "" then
                notify("Card Ticket", resTicket)
                logActivity(resTicket, "Card Shop")
            end
            task.wait(0.5)
        end
    end

    local ok, res = invoke(R.CardShopAction, "pull", 10)
    if not ok then
        task.wait(0.3)
        ok, res = invoke(R.CardShopAction, "pull", 1)
    end

    if ok and type(res) == "table" and type(res.cards) == "table" then
        local numCards = #res.cards
        notify("Card Shop", string.format("Pulled %d cards successfully!", numCards))
        logActivity(string.format("Pulled %d cards", numCards), "Card Shop")

        for _, c in ipairs(res.cards) do
            local cid = (type(c) == "table" and (c.id or c.name)) or tostring(c)
            for stopTarget in pairs(S.stopOnCards or {}) do
                if cid:find(stopTarget, 1, true) or stopTarget:find(cid, 1, true) then
                    S.autoCardPull = false
                    notify("Card Pull", "Obtained target card: " .. stopTarget .. "! Stopped.")
                    logActivity("Obtained: " .. stopTarget, "Card Shop")
                    break
                end
            end
        end
    elseif ok and type(res) == "string" and res ~= "" then
        notify("Card Shop", res)
        logActivity(res, "Card Shop")
    elseif force then
        notify("Card Shop", (type(res) == "string" and res) or (ok and "Pulled cards!" or "No card tickets or cards available"))
    end

    task.wait(0.4)
    if S.autoFarm then
        local center = getMyPlotCenter()
        if center then
            root = getHRP()
            if root then root.CFrame = CFrame.new(center) end
        end
    elseif prevCF then
        root = getHRP()
        if root then root.CFrame = prevCF end
    end

    isPullingCards = false
end

-- Market Selling Engine (Auto Warps to Market -> Sells -> Warps back to Farm or Zone)
local function getSellableProduceCount(sellMode)
    sellMode = sellMode or S.sellMode or "ALL"
    local total = 0
    local cd = CachedData or getgenv().CachedData or {}

    -- 1. Normal Produce
    if sellMode ~= "MUTANT" and cd.produce and type(cd.produce) == "table" then
        for _, count in pairs(cd.produce) do
            total = total + (tonumber(count) or 0)
        end
    end

    -- 2. Mutant Produce (sold when sellMode == "ALL" or "MUTANT")
    if (sellMode == "ALL" or sellMode == "MUTANT") and cd.mutant and type(cd.mutant) == "table" then
        for _, count in pairs(cd.mutant) do
            total = total + (tonumber(count) or 0)
        end
    end

    return total
end

local isSelling = false
doSellCycle = function(sellMode, force)
    if isSelling then return end
    sellMode = sellMode or S.sellMode or "NORMAL"

    -- NO STOCK CHECK: If no produce in inventory, do NOT warp! Avoid wasting time!
    local produceCount = getSellableProduceCount(sellMode)
    if produceCount <= 0 then
        if force then
            notify("Market", "No produce in stock to sell!")
        end
        return
    end

    isSelling = true
    logActivity(string.format("Selling at Market (%s • %d produce)...", sellMode, produceCount), "Market")

    invoke(R.QuickWarp, "Market")
    task.wait(1.4)

    local ok, msg = invoke(R.SellProduce, sellMode)
    local msgStr = (type(msg) == "string" and msg) or (ok and "Sold produce successfully!" or "No produce to sell")
    notify("Market Sell", msgStr)
    logActivity("Sell: " .. msgStr, "Market")

    task.wait(0.4)
    if S.autoFarmMobs then
        invoke(R.Warp, S.warpZone)
        task.wait(1.0)
        logActivity("Returned to Zone " .. tostring(S.warpZone), "Zone " .. tostring(S.warpZone))
    else
        invoke(R.QuickWarp, "Farm")
        task.wait(1.2)
        logActivity("Returned to Farm", "Farm Plot")
    end
    isSelling = false
end

getgenv().BG_API = {
    doPenCoinCollect        = doPenCoinCollect,
    doPenFeedCycle          = doPenFeedCycle,
    doCardPullCycle         = doCardPullCycle,
    doEquipBestAll          = doEquipBestAll,
    doFruitTreeHarvest      = doFruitTreeHarvest,
    doUpgradeHouse          = doUpgradeHouse,
    doRefineAllProduce      = doRefineAllProduce,
    doRealFarmCycle         = doRealFarmCycle,
    doBuyBedGroups          = doBuyBedGroups,
    doBuyEggCycle           = doBuyEggCycle,
    doFillIncubatorCycle    = doFillIncubatorCycle,
    buySeedsAtShop          = buySeedsAtShop,
    buySeedsBatch           = buySeedsBatch,
    getSeedStockRemaining   = getSeedStockRemaining,
    syncWithGameConfig      = syncWithGameConfig,
    doSellCycle             = doSellCycle,
    getSellableProduceCount = getSellableProduceCount,
    S                       = S,
}

-- ===== REAL WORKING COMBAT & MONSTER ENGINE (WITH TARGET PRIORITY & FALLBACK) =====
local function getBestTargetMonster(zoneOverride, customFilter)
    local root = getHRP()
    if not root then return nil end

    local m = workspace:FindFirstChild("Map")
    local monstersFolder = m and m:FindFirstChild("Monsters")
    if not monstersFolder then return nil end

    local targetZone = zoneOverride or S.warpZone
    local allCandidates = {}
    local targetCandidates = {}

    local hasTargetFilter = (customFilter ~= nil) or (S.autoTargetMonster and (next(S.selectedMonsters) ~= nil))

    for _, mdl in ipairs(monstersFolder:GetChildren()) do
        if mdl:IsA("Model") and not mdl:GetAttribute("DiedAt") then
            local monsterId = mdl:GetAttribute("MonsterId") or mdl.Name
            local zone = mdl:GetAttribute("Zone")
            local targetPart = mdl.PrimaryPart or mdl:FindFirstChild("Root") or mdl:FindFirstChildOfClass("BasePart")

            if targetPart and monsterId then
                local zoneMatch = (not targetZone) or (tonumber(zone) == tonumber(targetZone))

                if zoneMatch then
                    local isBoss = false
                    for _, z in ipairs(ZONES) do
                        if z.boss == monsterId then isBoss = true break end
                    end

                    local dist = (root.Position - targetPart.Position).Magnitude
                    local hp = 100
                    pcall(function()
                        local hpText = mdl:FindFirstChild("HealthBar") and mdl.HealthBar:FindFirstChild("HPText", true)
                        if hpText then
                            local cur = hpText.Text:match("^(%d+)/")
                            if cur then hp = tonumber(cur) end
                        end
                    end)

                    local item = {
                        model = mdl,
                        part = targetPart,
                        monsterId = monsterId,
                        zone = zone,
                        dist = dist,
                        isBoss = isBoss,
                        health = hp
                    }

                    table.insert(allCandidates, item)

                    if customFilter then
                        local flt = tostring(customFilter):lower()
                        local srcFile = mdl:GetAttribute("SourceFile")
                        local questAs = mdl:GetAttribute("QuestAs")
                        local isTarget = (monsterId and monsterId:lower():find(flt) ~= nil)
                            or (mdl.Name and mdl.Name:lower():find(flt) ~= nil)
                            or (questAs and questAs:lower():find(flt) ~= nil)
                            or (srcFile and tostring(srcFile):lower():find(flt) ~= nil)
                        if isTarget then
                            table.insert(targetCandidates, item)
                        end
                    elseif hasTargetFilter then
                        local isTarget = (S.selectedMonsters[monsterId] == true)
                            or (S.selectedMonsters[monsterId:lower()] == true)
                            or (S.selectedMonsters[mdl.Name] == true)
                            or (S.selectedMonsters[mdl.Name:lower()] == true)
                            or (mdl:GetAttribute("QuestAs") and S.selectedMonsters[mdl:GetAttribute("QuestAs")])
                            or (mdl:GetAttribute("QuestAs") and S.selectedMonsters[mdl:GetAttribute("QuestAs"):lower()])

                        if isTarget then
                            table.insert(targetCandidates, item)
                        end
                    end
                end
            end
        end
    end

    -- Priority 1: Target monsters (ตี monster target ก่อน)
    -- Priority 2: Fallback to all zone monsters if targets ran out (ถ้าเกิดว่าหมดจะไปตีตัวอื่น)
    local chosenPool = (hasTargetFilter and #targetCandidates > 0) and targetCandidates or allCandidates
    if #chosenPool == 0 then return nil end

    -- If currently fighting a monster in our chosen pool, stick to it until it's dead!
    if currentCombatTarget and not currentCombatTarget:GetAttribute("DiedAt") then
        for _, c in ipairs(chosenPool) do
            if c.model == currentCombatTarget then
                return c
            end
        end
    end

    -- Sort chosen pool according to S.mobPriority
    if S.mobPriority == "Boss First" then
        table.sort(chosenPool, function(a, b)
            if a.isBoss ~= b.isBoss then return a.isBoss end
            return a.dist < b.dist
        end)
    elseif S.mobPriority == "Lowest HP First" then
        table.sort(chosenPool, function(a, b) return a.health < b.health end)
    elseif S.mobPriority == "Highest HP First" then
        table.sort(chosenPool, function(a, b) return a.health > b.health end)
    else
        table.sort(chosenPool, function(a, b) return a.dist < b.dist end)
    end

    return chosenPool[1]
end

-- Check if any selected boss is alive in workspace
local function getAliveSelectedBoss()
    local m = workspace:FindFirstChild("Map")
    local monstersFolder = m and m:FindFirstChild("Monsters")
    if not monstersFolder or next(S.selectedBosses) == nil then return nil end

    for _, mdl in ipairs(monstersFolder:GetChildren()) do
        if mdl:IsA("Model") and not mdl:GetAttribute("DiedAt") then
            local mId = mdl:GetAttribute("MonsterId")
            if mId and S.selectedBosses[mId] then
                local rootPart = mdl.PrimaryPart or mdl:FindFirstChild("Root")
                if rootPart then
                    return {
                        model = mdl,
                        part = rootPart,
                        monsterId = mId,
                        zone = mdl:GetAttribute("Zone")
                    }
                end
            end
        end
    end
    return nil
end

-- Zone Camp Boundary Markers & Camp Teleport Positions
local zoneCampZ = {
    [1] = -158, [2] = -438, [3] = -718, [4] = -998, [5] = -1278,
    [6] = -1558, [7] = -1838, [8] = -2118, [9] = -2398
}

local zoneCampPositions = {
    [1] = Vector3.new(0, 3.5, -158),
    [2] = Vector3.new(0, 7.5, -438),
    [3] = Vector3.new(0, 13.5, -718),
    [4] = Vector3.new(0, 27.5, -998),
    [5] = Vector3.new(0, 48.0, -1278),
    [6] = Vector3.new(0, 65.0, -1558),
    [7] = Vector3.new(0, 85.0, -1838),
    [8] = Vector3.new(0, 105.0, -2118),
    [9] = Vector3.new(0, 130.0, -2398),
}

-- Safe Zone Warp Helper (Must stand at town warp pad before invoking Warp remote)
local function warpToZoneSafely(zoneNum)
    local root = getHRP()
    if not root then return false end
    if root.Position.X > 900 then
        -- Currently inside a dungeon! Do not warp away to town
        return true
    end

    local num = tonumber(zoneNum) or 1
    local campZ = zoneCampZ[num] or -158
    local campPos = zoneCampPositions[num] or Vector3.new(0, 5, campZ)

    -- If already in zone: Must be past Town NorthGate (Z <= -130) and within 85 studs of zone camp
    if root.Position.Z <= -130 and math.abs(root.Position.Z - campZ) < 85 then
        return true
    end

    -- Cancel active movement tween so it doesn't drag us back
    if activeTween then
        pcall(function() activeTween:Cancel() end)
        activeTween = nil
    end

    -- 1. Direct teleport to Town Warp Pad
    root.CFrame = CFrame.new(POS_TOWN_WARP)
    task.wait(0.2)

    -- 2. Fire Warp Prompt if present
    local hubSpawn = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Blockout") and workspace.Map.Blockout:FindFirstChild("Hub") and workspace.Map.Blockout.Hub:FindFirstChild("HubSpawn")
    local warpPrompt = hubSpawn and hubSpawn:FindFirstChildWhichIsA("ProximityPrompt")
    if warpPrompt then pcall(fireproximityprompt, warpPrompt) end
    task.wait(0.1)

    -- 3. Invoke Warp remote with "Z" prefix
    pcall(function()
        return invoke(R.Warp, "Z" .. tostring(num))
    end)
    task.wait(0.4)

    -- 4. Fallback Verification: Ensure character actually made it to the target zone
    root = getHRP()
    if root and (root.Position.Z > -130 or math.abs(root.Position.Z - campZ) > 85) then
        root.CFrame = CFrame.new(campPos)
        task.wait(0.25)
    end

    return true
end

-- Unified Auto Farm Monsters Step (Single Warp, Smooth Engagements)
local lastZoneWarpTick = 0
local function doSingleMobStep()
    local root = getHRP()
    if root and root.Position.X > 900 then
        -- Inside dungeon, don't execute regular zone mob step
        return
    end

    local target = getBestTargetMonster(S.warpZone)
    if target and target.part and not target.model:GetAttribute("DiedAt") then
        moveAndFaceMonster(target.part, target.model)
        if S.autoTeamSkill then invoke(R.TeamSkill) end
        task.wait(0.25)
    else
        enableCombatHover(false)
        currentCombatTarget = nil
        root = getHRP()
        local campZ = zoneCampZ[S.warpZone] or -158
        local isAlreadyInZone = root and (math.abs(root.Position.Z - campZ) < 140)

        if root and not isAlreadyInZone and (tick() - lastZoneWarpTick > 10) then
            lastZoneWarpTick = tick()
            warpToZoneSafely(S.warpZone)
        else
            task.wait(0.3)
        end
    end
end

-- Boss Hunt Step (Single Warp to Boss, No Spam)
local currentBossTarget = nil
local function doSingleBossStep()
    local root = getHRP()
    if root and root.Position.X > 900 then return end

    local boss = getAliveSelectedBoss()
    if boss and boss.part and not boss.model:GetAttribute("DiedAt") then
        if currentBossTarget ~= boss.model then
            currentBossTarget = boss.model
            if boss.zone then
                warpToZoneSafely(boss.zone)
            end
        end
        moveAndFaceMonster(boss.part, boss.model)
        if S.autoTeamSkill then invoke(R.TeamSkill) end
        task.wait(0.2)
    else
        enableCombatHover(false)
        currentBossTarget = nil
        if S.autoBossServerHop and next(S.selectedBosses) ~= nil then
            logActivity("No Boss Alive -> Server Hopping...", "Boss Hop")
            notify("Auto Boss", "No selected boss alive! Hopping servers...")
            serverHop()
            task.wait(10)
        end
    end
end

-- Server Hopping
local isHopping = false
function serverHop()
    if isHopping then return end
    isHopping = true
    notify("Server Hop", "Searching public servers...")
    logActivity("Searching Server for Hop...", "Server Hop")

    if queue_teleport then
        local scriptPath = "D:/My/Desktop/script/BeastGarden_Hub.lua"
        pcall(function()
            queue_teleport([[
                repeat task.wait() until game:IsLoaded()
                task.wait(2)
                if isfile and isfile("]] .. scriptPath .. [[") then
                    loadfile("]] .. scriptPath .. [[")()
                end
            ]])
        end)
    end

    local placeId = game.PlaceId
    local currentJob = game.JobId
    local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"

    task.spawn(function()
        local success, body
        if http_request then
            local res = http_request({ Url = url, Method = "GET" })
            if res and res.Body then success, body = true, res.Body end
        else
            success, body = pcall(function() return game:HttpGet(url) end)
        end

        if success and body then
            local sDecode, data = pcall(json_decode, body)
            if sDecode and data and data.data then
                for _, s in ipairs(data.data) do
                    if s.id ~= currentJob and s.playing and s.maxPlayers and s.playing < s.maxPlayers then
                        notify("Server Hop", "Joining (" .. s.playing .. "/" .. s.maxPlayers .. ")...")
                        TeleportService:TeleportToPlaceInstance(placeId, s.id, plr)
                        task.wait(6)
                        isHopping = false
                        return
                    end
                end
            end
        end
        TeleportService:Teleport(placeId, plr)
        task.wait(6)
        isHopping = false
    end)
end

-- ==============================================================================
-- 📜 COMPREHENSIVE QUEST ENGINE: MAIN QUEST & ZONE/DAILY QUEST AUTOMATION
-- ==============================================================================

-- Helper: Open Traveling Merchant (Quest NPC) & ProximityPrompt
local function openQuestMerchant()
    local root = getHRP()
    if root then
        root.CFrame = CFrame.new(POS_QUEST_NPC)
        task.wait(0.4)
    end

    local npc = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("QuestNPCs") and workspace.Map.QuestNPCs:FindFirstChild("QuestNPC_Z0")
    local prompt = npc and npc:FindFirstChild("Body") and npc.Body:FindFirstChildWhichIsA("ProximityPrompt")
    if prompt then
        pcall(fireproximityprompt, prompt)
        task.wait(0.35)
    end
end

-- Helper: Safe Zone Quest Definition & Target Extractor
local function getZoneQuestDef(zoneNum, qIdx)
    if not Config or not Config.ZoneQuest then return nil end
    local def = nil
    if type(Config.ZoneQuest) == "function" then
        local s, r = pcall(Config.ZoneQuest, zoneNum, qIdx)
        if s then def = r end
    elseif type(Config.ZoneQuest) == "table" then
        local zTable = Config.ZoneQuest[zoneNum] or Config.ZoneQuest[tostring(zoneNum)]
        if type(zTable) == "table" then
            def = zTable[qIdx] or zTable[tostring(qIdx)] or zTable[1] or zTable
        else
            def = zTable
        end
    end
    return def
end

local function getQuestTargetNeed(def)
    if not def then return 10 end
    return def.n or def.count or def.goal or def.amount or def.max or def.need or 10
end

local function getQuestTargetMob(def)
    if not def then return nil end
    return def.monster or def.mob or def.target or def.monsterId or def.id
end

-- Helper: Auto-Claim & Auto-Accept Zone Quests (Hub + Zones 1..9)
local lastMerchantVisit = 0
local lastQuestClaimDebounce = {}

local function closeQuestUI()
    pcall(function()
        local qp = plr.PlayerGui:FindFirstChild("QuestPanels")
        local qFrame = qp and qp:FindFirstChild("Quest", true)
        if qFrame then qFrame.Visible = false end
    end)
    pcall(function()
        plr:SetAttribute("HudOpen", "")
    end)
end

local function processZoneQuests(targetZoneToAccept, mode)
    openQuestMerchant()

    local qp = plr.PlayerGui:FindFirstChild("QuestPanels")
    local qFrame = qp and qp:FindFirstChild("Quest", true)
    local zqData = getgenv().CachedData and getgenv().CachedData.zq or {}

    -- 1. CLAIM ALL COMPLETED ZONE QUESTS
    local claimedAny = false
    for zoneNum = 0, 9 do
        local zKey = "Z" .. zoneNum
        local zInfo = zqData[zKey]
        local isReady = false

        if zInfo and zInfo.on then
            local def = getZoneQuestDef(zoneNum, zInfo.i)
            local need = getQuestTargetNeed(def)
            if (zInfo.p or 0) >= need then
                isReady = true
            end
        end

        local claimBtn = qFrame and qFrame:FindFirstChild("Claim_" .. zoneNum, true)
        if claimBtn and claimBtn.Visible then
            isReady = true
        end

        if isReady then
            logActivity(string.format("Claiming Zone %d Quest", zoneNum), "Town")
            invoke(R.QuestAction, zoneNum, "claim")
            lastQuestClaimDebounce[zoneNum] = tick()
            if claimBtn then pcall(firesignal, claimBtn.Activated) end
            if zInfo then
                zInfo.on = false
                zInfo.p = 0 -- Reset progress immediately to stop claim loop!
            end
            claimedAny = true
            task.wait(0.3)
        end
    end

    -- 2. ACCEPT QUESTS
    if mode == "all" or mode == "accept_all" then
        local activeCount = 0
        for zn = 0, 9 do
            local info = zqData["Z" .. zn]
            if info and info.on then activeCount = activeCount + 1 end
        end

        local maxActive = tonumber(Config and Config.QuestMaxActive) or 3
        if activeCount < maxActive then
            local zonesToTry = {}
            if S.warpZone and S.warpZone > 0 then
                table.insert(zonesToTry, S.warpZone)
            end
            for zn = 0, 9 do
                if zn ~= S.warpZone then table.insert(zonesToTry, zn) end
            end

            for _, zoneNum in ipairs(zonesToTry) do
                if activeCount >= maxActive then break end
                local zKey = "Z" .. zoneNum
                local zInfo = zqData[zKey]
                local acceptBtn = qFrame and qFrame:FindFirstChild("Accept_" .. zoneNum, true)
                local canAccept = (acceptBtn and acceptBtn.Visible) or (zInfo and not zInfo.on)

                if canAccept then
                    logActivity(string.format("Accepting Zone %d Quest", zoneNum), "Town")
                    local ok, success = pcall(function()
                        return invoke(R.QuestAction, zoneNum, "accept")
                    end)
                    if acceptBtn then pcall(firesignal, acceptBtn.Activated) end
                    if ok and success then
                        if zInfo then
                            zInfo.on = true
                            zInfo.p = 0
                        end
                        activeCount = activeCount + 1
                    end
                    task.wait(0.3)
                end
            end
        end
    elseif targetZoneToAccept ~= nil then
        local zoneNum = tonumber(targetZoneToAccept)
        if zoneNum then
            local acceptBtn = qFrame and qFrame:FindFirstChild("Accept_" .. zoneNum, true)
            logActivity(string.format("Accepting Target Zone %d Quest", zoneNum), "Town")
            invoke(R.QuestAction, zoneNum, "accept")
            if acceptBtn then pcall(firesignal, acceptBtn.Activated) end
            local zInfo = zqData["Z" .. zoneNum]
            if zInfo then
                zInfo.on = true
                zInfo.p = 0
            end
            task.wait(0.3)
        end
    end

    -- Close Quest UI
    closeQuestUI()
    task.wait(0.2)

    -- 3. RESUME FARMING OR HUNTING (DO NOT REMAIN STUCK AT NPC!)
    local nextMonsterZone = nil
    for zn = 1, 9 do
        local zi = zqData["Z" .. zn]
        if zi and zi.on then
            local def = getZoneQuestDef(zn, zi.i)
            local need = getQuestTargetNeed(def)
            if (zi.p or 0) < need then
                nextMonsterZone = zn
                break
            end
        end
    end

    if nextMonsterZone then
        logActivity(string.format("Quest Accepted! Warping to Zone %d to hunt...", nextMonsterZone), "Quest")
        warpToZoneSafely(nextMonsterZone)
    elseif S.autoFarmMobs and S.warpZone then
        logActivity(string.format("Resuming Mob Farm: Warping to Zone %d...", S.warpZone), "Combat")
        warpToZoneSafely(S.warpZone)
    elseif S.autoFarm then
        logActivity("Resuming Crop Farm: Returning to Farm...", "Farm Plot")
        invoke(R.QuickWarp, "Farm")
        lastFarmTime = 0
        task.wait(0.4)
        task.spawn(doRealFarmCycle)
    else
        invoke(R.QuickWarp, "Farm")
    end
end

-- Helper: Auto-Claim Daily Quests, Daily Login & Bonus Box
local function doDailyQuestCycle()
    local cd = getgenv().CachedData
    if cd and cd.quests then
        if type(cd.quests.list) == "table" then
            for i, q in ipairs(cd.quests.list) do
                if q.w == true or (q.done == true and not q.claimed) then
                    logActivity(string.format("Claiming Daily Quest #%d (%s)", i, tostring(q.id)), "Quests")
                    invoke(R.DailyAction, "quest", i)
                    task.wait(0.2)
                end
            end
        end

        if cd.quests.bonus == true or cd.quests.bw == true then
            logActivity("Claiming Daily Bonus Box", "Quests")
            invoke(R.DailyAction, "bonus")
            task.wait(0.2)
        end
    end

    pcall(function()
        invoke(R.DailyAction, "login")
    end)

    if cd and type(cd.weekly) == "table" then
        for i, w in ipairs(cd.weekly) do
            if w.w == true or w.done == true then
                invoke(R.DailyAction, "weekly", i)
                task.wait(0.2)
            end
        end
    end
end

-- Unified Auto Quest (Periodic Town & Quests Routine)
local isRunningQuest = false
local function doUnifiedQuestCycle()
    if isRunningQuest then return end
    isRunningQuest = true

    local s, err = pcall(function()
        logActivity("Running Unified Quest & Daily Claim...", "Town")
        -- 1. Daily Quests & Daily Login
        doDailyQuestCycle()
        task.wait(0.3)

        -- 2. Zone Quests (Claim all completed, Accept all available)
        processZoneQuests(nil, "all")
        notify("Quest", "Processed all daily & zone quests.")
    end)

    if not s and err then
        warn("[BG_QuestCycle] Error: " .. tostring(err))
    end
    isRunningQuest = false
end

-- ==============================================================================
-- 🎯 ACTIVE ZONE QUEST EXECUTION ENGINE (WARP TO ZONE -> HUNT MOB -> CLAIM)
-- ==============================================================================
local isExecutingQuest = false

local function doActiveZoneQuestStep()
    if isExecutingQuest then return false end
    local zqData = getgenv().CachedData and getgenv().CachedData.zq or {}

    -- 1. Check if ANY active quest is finished and ready to claim
    local hasClaimable = false
    local now = tick()
    for zoneNum = 0, 9 do
        local zKey = "Z" .. zoneNum
        local zInfo = zqData[zKey]
        if zInfo and zInfo.on and (now - (lastQuestClaimDebounce[zoneNum] or 0) > 6) then
            local def = getZoneQuestDef(zoneNum, zInfo.i)
            local need = getQuestTargetNeed(def)
            if (zInfo.p or 0) >= need then
                hasClaimable = true
                break
            end
        end
    end

    if hasClaimable then
        isExecutingQuest = true
        logActivity("Active Quest completed! Warping to Wandering Merchant to claim...", "Town")
        processZoneQuests(nil, "all")
        isExecutingQuest = false
        return true
    end

    -- 2. Check for active Monster Quests (Zone 1..9)
    local pendingMonsterQuest = nil
    for zoneNum = 1, 9 do
        local zKey = "Z" .. zoneNum
        local zInfo = zqData[zKey]
        if zInfo and zInfo.on then
            local def = getZoneQuestDef(zoneNum, zInfo.i)
            local need = getQuestTargetNeed(def)
            if (zInfo.p or 0) < need then
                pendingMonsterQuest = {
                    zone = zoneNum,
                    info = zInfo,
                    def = def,
                    need = need,
                    cur = zInfo.p or 0
                }
                break
            end
        end
    end

    -- 3. Check for active Farm Quest (Zone 0)
    local pendingFarmQuest = nil
    local z0Info = zqData["Z0"]
    if z0Info and z0Info.on then
        local def = getZoneQuestDef(0, z0Info.i)
        local need = getQuestTargetNeed(def)
        if (z0Info.p or 0) < need then
            pendingFarmQuest = {
                zone = 0,
                info = z0Info,
                def = def,
                need = need,
                cur = z0Info.p or 0
            }
        end
    end

    -- If no quest is active at all, go visit merchant with cooldown!
    if not pendingMonsterQuest and not pendingFarmQuest then
        local now = tick()
        if now - lastMerchantVisit >= 45 then
            lastMerchantVisit = now
            isExecutingQuest = true
            processZoneQuests(nil, "all")
            isExecutingQuest = false
            -- Return false so the main loop continues mob/crop farming immediately!
            return false
        end
        return false
    end

    isExecutingQuest = true

    -- Priority A: Execute Monster Quest in Zone 1..9 (Warp to zone, kill target monster)
    if pendingMonsterQuest then
        local zNum = pendingMonsterQuest.zone
        local def = pendingMonsterQuest.def
        local targetMob = getQuestTargetMob(def)

        warpToZoneSafely(zNum)

        local target = getBestTargetMonster(zNum, targetMob)
        if target and target.part and not target.model:GetAttribute("DiedAt") then
            moveAndFaceMonster(target.part, target.model)
            if S.autoTeamSkill then invoke(R.TeamSkill) end
            task.wait(0.25)
        else
            enableCombatHover(false)
            -- Move to zone camp spot to enter mob spawn range
            local campPos = zoneCampPositions[zNum]
            if campPos then
                moveToCFrame(CFrame.new(campPos + Vector3.new(0, 3, 0)))
            end
            task.wait(0.35)
        end

        isExecutingQuest = false
        return true
    end

    -- Priority B: Execute Farm Quest (Zone 0)
    if pendingFarmQuest then
        local def = pendingFarmQuest.def
        local kind = def and def.kind or "harvest"
        if kind == "harvest" or kind == "plant" then
            if doRealFarmCycle then doRealFarmCycle() end
        elseif kind == "sell" then
            if getSellableProduceCount and getSellableProduceCount(S.sellMode) > 0 then
                doSellCycle(S.sellMode, false)
            end
        elseif kind == "arena" then
            if doColosseumStep then doColosseumStep(false) end
        end
        isExecutingQuest = false
        return true
    end

    isExecutingQuest = false
    return false
end

-- ==============================================================================
-- ⚔️ COLOSSEUM (ARENA) ENGINE (STAND AT BOARD -> JOIN DUEL -> FIGHT)
-- ==============================================================================
local isExecutingArena = false
local lastArenaCheck = 0

local function doColosseumStep(isManual)
    if isExecutingArena then return false end
    local now = tick()
    if not isManual and (now - lastArenaCheck < 25) then return false end
    lastArenaCheck = now
    isExecutingArena = true

    local s, err = pcall(function()
        logActivity("Heading to Colosseum Arena Board...", "Arena")

        -- 1. Equip best team
        invoke(R.AnimalAction, "best", "team")
        task.wait(0.25)

        -- 2. Warp to Colosseum Board Pad
        local root = getHRP()
        if root then
            moveToCFrame(CFrame.new(POS_ARENA_BOARD + Vector3.new(0, 1.5, 0)))
            task.wait(0.4)
        end

        -- 3. Fire BoardPad ProximityPrompt (registers standing at board)
        local board = workspace:FindFirstChild("ColosseumBoard", true)
        local pad = board and board:FindFirstChild("BoardPad")
        local prompt = pad and pad:FindFirstChildWhichIsA("ProximityPrompt")
        if prompt then
            pcall(fireproximityprompt, prompt)
            task.wait(0.35)
        end

        -- 4. Invoke ArenaAction
        local mode = S.arenaMode or "start"
        local ok, res, msg = pcall(function()
            return invoke(R.ArenaAction, mode, 1)
        end)

        if ok and res == true then
            logActivity("Joined Colosseum Match! Waiting for duel...", "Arena")
            -- Wait for duel to finish (monitor OpenPanel or timeout)
            local t0 = tick()
            while tick() - t0 < 35 and getgenv().BG_Running do
                local op = plr:GetAttribute("OpenPanel") or ""
                if not op:find("Arena") and tick() - t0 > 6 then
                    break
                end
                task.wait(0.5)
            end
            logActivity("Colosseum duel finished!", "Arena")
        else
            local errStr = tostring(msg or "")
            logActivity("Colosseum: " .. (errStr ~= "" and errStr or "Cannot join duel now"), "Arena")
        end
    end)

    if not s and err then
        warn("[BG_Colosseum] Error: " .. tostring(err))
    end
    isExecutingArena = false
    return true
end

-- ==============================================================================
-- 💧 AUTO WATERING & SPRINKLER ENGINE (GEAR USE & AUTO BUY)
-- ==============================================================================
local isExecutingSprinkler = false
local lastSprinklerCheck = 0

local function getActiveSprinklerRemaining()
    if Config and Config.SprinklerActive and CachedData then
        local nowServer = workspace:GetServerTimeNow()
        local def, activeType, remSecs = Config.SprinklerActive(CachedData, nowServer)
        if def and remSecs and remSecs > 0 then
            return activeType, remSecs
        end
    end
    return nil, 0
end

local function getSprinklerInventoryCount(sprinklerType)
    if CachedData and CachedData.gear and type(CachedData.gear) == "table" then
        return tonumber(CachedData.gear[sprinklerType]) or 0
    end
    return 0
end

local lastSprinklerRestockId = -1
local lastSprinklerStockCheckTick = 0

-- Check if any of user's selected sprinklers are in stock
local function getAvailableSprinklersToBuy()
    local list = {}
    local cd = CachedData or getgenv().CachedData or {}
    local myCoins = tonumber(cd.coins) or 0
    local myFarmLevel = tonumber(cd.farmLevel) or 1
    local now = workspace:GetServerTimeNow()
    local restockId = Config.RestockId and Config.RestockId(now) or 0

    local order = (Config.Sprinklers and Config.Sprinklers.Order) or {"Rainbow", "Gold", "Big", "Basic"}
    for _, t in ipairs(order) do
        -- Check if user selected this sprinkler in Multi-Dropdown
        local isSelected = false
        if S.selectedSprinklersToBuy then
            if type(S.selectedSprinklersToBuy) == "table" then
                if S.selectedSprinklersToBuy[t] == true or S.selectedSprinklersToBuy[t:lower()] == true then
                    isSelected = true
                else
                    for _, v in ipairs(S.selectedSprinklersToBuy) do
                        if tostring(v):lower():find(t:lower(), 1, true) then
                            isSelected = true
                            break
                        end
                    end
                end
            end
        end

        if isSelected then
            local def = Config.Sprinklers and Config.Sprinklers.Types and Config.Sprinklers.Types[t]
            if def and myFarmLevel >= (def.level or 1) and myCoins >= (def.price or 0) then
                local stock = 0
                if Config.GearStockLeft then
                    local s, st = pcall(Config.GearStockLeft, cd, t, restockId)
                    if s and type(st) == "number" then stock = st end
                end
                if stock > 0 then
                    local canAffordCount = math.floor(myCoins / def.price)
                    local buyCount = math.clamp(math.min(stock, canAffordCount), 1, 10)
                    table.insert(list, {
                        type = t,
                        name = def.name or t,
                        price = def.price,
                        stock = stock,
                        buyCount = buyCount
                    })
                end
            end
        end
    end
    return list
end

-- Buy sprinklers at shop with TP first
local function buySprinklersBatchAtShop(itemsToBuy, isManual)
    if not itemsToBuy or #itemsToBuy == 0 then return false end
    local root = getHRP()
    if not root then return false end

    local prevCFrame = root.CFrame

    logActivity(string.format("Stock available! Warping to Seed Shop (Buying %d sprinkler types)...", #itemsToBuy), "Watering")

    -- 1. Must TP to Seed Shop first before calling remote!
    invoke(R.QuickWarp, "SeedShop")
    task.wait(0.4)
    root = getHRP()
    if root then
        root.CFrame = CFrame.new(POS_SEED_SHOP)
    end
    task.wait(0.4)

    local anyBought = false
    local summary = {}

    for _, it in ipairs(itemsToBuy) do
        local ok, res, msg = invoke(R.FarmAction, "gearBuy", it.type, it.buyCount)
        if ok and res then
            anyBought = true
            table.insert(summary, string.format("%s x%d", it.name or it.type, it.buyCount))
        end
        task.wait(0.3)
    end

    if anyBought then
        local msg = "ซื้อสปริงเกลอร์สำเร็จ: " .. table.concat(summary, ", ")
        notify("Watering", msg)
        logActivity(msg, "Watering")
    elseif isManual then
        notify("Watering", "ไม่สามารถซื้อสปริงเกลอร์ได้ (เหรียญไม่พอ หรือหมดสต็อก)!")
    end

    task.wait(0.3)

    -- If auto water is not active, return to previous position
    if not S.autoWaterSprinkler and prevCFrame then
        root = getHRP()
        if root then
            root.CFrame = prevCFrame
        end
    end

    return anyBought
end

local function doWateringSprinklerStep(isManual)
    if isExecutingSprinkler then return false end
    if not isManual and (isExecutingDungeon or isExecutingArena or isExecutingFrost or isExecutingQuest or isRunningMainQuest or isFarming or isSelling) then
        return false
    end
    local now = tick()
    if not isManual and (now - lastSprinklerCheck < 15) then return false end
    lastSprinklerCheck = now
    isExecutingSprinkler = true

    local s, err = pcall(function()
        local serverNow = workspace:GetServerTimeNow()
        local currentRestockId = Config.RestockId and Config.RestockId(serverNow) or 0

        -- 1. AUTO BUY SPRINKLERS (When Restock Resets or Manual)
        if S.autoBuySprinkler or isManual then
            local shouldCheckStock = isManual or (currentRestockId ~= lastSprinklerRestockId)
            if shouldCheckStock then
                lastSprinklerStockCheckTick = now
                local itemsToBuy = getAvailableSprinklersToBuy()
                if #itemsToBuy > 0 then
                    lastSprinklerRestockId = currentRestockId
                    buySprinklersBatchAtShop(itemsToBuy, isManual)
                else
                    -- No stock available for selected sprinklers! DO NOTHING!
                    lastSprinklerRestockId = currentRestockId
                    if isManual then
                        notify("Watering", "สปริงเกลอร์ที่เลือกไม่มีสินค้าในสต็อก (รอร้านค้ารีสต็อก)!")
                    end
                end
            end
        end

        -- 2. AUTO WATER CROPS (Activate Best Available Sprinkler at Farm)
        if S.autoWaterSprinkler or isManual then
            local activeType, remSecs = getActiveSprinklerRemaining()
            if activeType and remSecs > 15 and not isManual then
                -- Already active and watering
                return
            end

            -- Find best available sprinkler in bag matching user preference or fallback
            local preferredType = S.sprinklerType or "Rainbow"
            local chosenType = nil

            if getSprinklerInventoryCount(preferredType) > 0 then
                chosenType = preferredType
            else
                -- Fallback to highest tier available in bag
                for _, t in ipairs({"Rainbow", "Gold", "Big", "Basic"}) do
                    if getSprinklerInventoryCount(t) > 0 then
                        chosenType = t
                        break
                    end
                end
            end

            if chosenType then
                invoke(R.QuickWarp, "Farm")
                task.wait(0.5)
                local ok, res, msg = invoke(R.FarmAction, "gearUse", chosenType)
                if ok and res then
                    logActivity(string.format("Watering: Activated %s Sprinkler! Crops speed boosted.", chosenType), "Watering")
                end
            elseif isManual and not S.autoBuySprinkler then
                notify("Watering", "ไม่มีสปริงเกลอร์ในกระเป๋า (เปิด Auto Buy หรือไปซื้อที่ร้านเมล็ด)!")
            end
        end
    end)

    if not s and err then
        warn("[BG_Watering] Error: " .. tostring(err))
    end
    isExecutingSprinkler = false
    return true
end

-- ==============================================================================
-- 🏰 AUTO DUNGEON ENGINE (ZONE 2, 3, 4 DUNGEON RUNS)
-- ==============================================================================
local isExecutingDungeon = false
local lastDungeonTime = 0
local dungeonIndexRotation = 1

local DUNGEON_DEFS = {
    {
        key = "Dungeon1_RootCave",
        zone = 2,
        name = "Zone 2: Root Cave (ถ้ำรากไม้)",
        portalPos = Vector3.new(144, 15, -540),
        boss = "ElderTreant",
        mobs = {"RootHorror"}
    },
    {
        key = "Dungeon3_CrystalMine",
        zone = 3,
        name = "Zone 3: Crystal Mine (เหมืองคริสตัล)",
        portalPos = Vector3.new(121, 21, -788),
        boss = "MagmaTitan",
        mobs = {"EmeraldGolem", "RubyBat"}
    },
    {
        key = "Dungeon2_CloudTemple",
        zone = 4,
        name = "Zone 4: Cloud Temple (วิหารเมฆา)",
        portalPos = Vector3.new(128, 39, -1110),
        boss = "StormTitan",
        mobs = {"TempleGuardian"}
    }
}

local function getSelectedDungeonDef(userChoice)
    local choice = tostring(userChoice or S.selectedDungeon or ""):lower()
    if choice:find("root") or choice:find("ราก") or choice:find("zone 2") then
        return DUNGEON_DEFS[1]
    elseif choice:find("crystal") or choice:find("คริสตัล") or choice:find("zone 3") then
        return DUNGEON_DEFS[2]
    elseif choice:find("cloud") or choice:find("เมฆ") or choice:find("zone 4") then
        return DUNGEON_DEFS[3]
    else
        local d = DUNGEON_DEFS[dungeonIndexRotation]
        dungeonIndexRotation = (dungeonIndexRotation % #DUNGEON_DEFS) + 1
        return d
    end
end

local function findPortalPlane(dungKey)
    local blockout = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Blockout")
    if blockout then
        local p = blockout:FindFirstChild("DungeonPortal_" .. dungKey, true)
        local plane = p and p:FindFirstChild("PortalPlane")
        if plane then return plane end
    end
    for _, v in ipairs(workspace:GetDescendants()) do
        if v.Name == "PortalPlane" and v:IsA("BasePart") then
            local parent = v.Parent
            if parent and parent.Name:find(dungKey) then
                return v
            end
        end
    end
    return nil
end

local function doDungeonCycle(targetDungeonKey, isManual)
    if isExecutingDungeon then return false end
    local now = tick()
    if not isManual and (now - lastDungeonTime < (S.dungeonInterval or 40)) then return false end
    lastDungeonTime = now
    isExecutingDungeon = true

    local s, err = pcall(function()
        local dung = getSelectedDungeonDef(targetDungeonKey)
        if not dung then
            isExecutingDungeon = false
            return
        end

        local root = getHRP()
        if not root then
            isExecutingDungeon = false
            return
        end

        -- Check if already inside dungeon
        local alreadyInside = (root.Position.X > 900)
        if not alreadyInside then
            logActivity(string.format("Auto Dungeon: Preparing to enter %s...", dung.name), "Dungeon")

            -- 1. Warp to Dungeon Zone Safely
            warpToZoneSafely(dung.zone)
            task.wait(0.5)

            -- 2. Move to PortalPlane & Touch
            local plane = findPortalPlane(dung.key)
            if not plane then
                root.CFrame = CFrame.new(dung.portalPos)
                task.wait(0.8)
                plane = findPortalPlane(dung.key)
            end

            if plane then
                root.CFrame = CFrame.new(plane.Position)
                task.wait(0.15)

                -- Jump once at portal door to trigger physics touch
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.Jump = true
                    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
                end
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:SetKeyDown("0x20")
                    task.wait(0.05)
                    VirtualUser:SetKeyUp("0x20")
                end)

                if firetouchinterest then
                    pcall(firetouchinterest, root, plane, 0)
                    task.wait(0.1)
                    pcall(firetouchinterest, root, plane, 1)
                end
                task.wait(1.2)

                -- Re-verify or jump again if not inside yet
                root = getHRP()
                if not (root and root.Position.X > 900) then
                    root.CFrame = CFrame.new(plane.Position)
                    task.wait(0.1)
                    if hum then
                        hum.Jump = true
                        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
                    end
                    task.wait(0.8)
                end
            else
                logActivity("Dungeon portal plane not found (streamed out?)", "Dungeon")
                isExecutingDungeon = false
                return
            end
        end

        -- 3. Verify inside dungeon (X > 900)
        root = getHRP()
        if not (root and root.Position.X > 900) then
            logActivity("Did not enter dungeon (insufficient power or blocked)", "Dungeon")
            isExecutingDungeon = false
            return
        end

        local expectedX = (dung.zone == 2 and 1500) or (dung.zone == 4 and 1900) or (dung.zone == 3 and 2300) or 1500
        logActivity(string.format("Inside %s! Clearing dungeon monsters & boss...", dung.name), "Dungeon")

        -- 4. Dungeon Combat Loop (Clear all mobs room-by-room or boss)
        local t0 = tick()
        while tick() - t0 < 120 and getgenv().BG_Running do
            root = getHRP()
            if not (root and root.Position.X > 900) then
                break
            end

            local m = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Monsters")
            local candidateMobs = {}

            if m then
                for _, mob in ipairs(m:GetChildren()) do
                    if not mob:GetAttribute("DiedAt") then
                        local mId = mob:GetAttribute("MonsterId")
                        local p = mob.PrimaryPart or mob:FindFirstChild("Root") or mob:FindFirstChildOfClass("BasePart")
                        if p and math.abs(p.Position.X - expectedX) < 150 then
                            local dist = (p.Position - root.Position).Magnitude
                            local isBoss = (mId == dung.boss)
                            table.insert(candidateMobs, {
                                model = mob,
                                part = p,
                                mId = mId,
                                dist = dist,
                                isBoss = isBoss
                            })
                        end
                    end
                end
            end

            if #candidateMobs > 0 then
                local isBossOnly = (S.dungeonTargetMode == "Boss Only" or tostring(S.dungeonTargetMode):find("Boss Only"))
                if isBossOnly then
                    table.sort(candidateMobs, function(a, b)
                        if a.isBoss ~= b.isBoss then return a.isBoss end
                        return a.dist < b.dist
                    end)
                else
                    -- Normal: Room-by-room sweep by distance
                    table.sort(candidateMobs, function(a, b)
                        return a.dist < b.dist
                    end)
                end

                local target = candidateMobs[1]
                moveAndFaceMonster(target.part, target.model)
                if S.autoTeamSkill then invoke(R.TeamSkill) end
                task.wait(0.35)
            else
                enableCombatHover(false)
                logActivity(string.format("Dungeon %s cleared! Returning to Farm...", dung.name), "Dungeon")
                break
            end
        end

        enableCombatHover(false)

        -- 5. Return to Farm
        task.wait(0.5)
        invoke(R.QuickWarp, "Farm")
        task.wait(1.0)
    end)

    if not s and err then
        warn("[BG_Dungeon] Error: " .. tostring(err))
    end
    isExecutingDungeon = false
    return true
end

-- ==============================================================================
-- ❄️ AUTO FROST TOWER / AZUREUS CHALLENGE (SLAY Z3 BOSS -> FROST GATE -> AZUREUS)
-- ==============================================================================
local isExecutingFrost = false
local lastFrostCheck = 0

local function isFrostGateOpen()
    local gateExp = tonumber(plr:GetAttribute("FrostGate")) or 0
    return (gateExp > workspace:GetServerTimeNow())
end

local function doFrostTowerStep(isManual)
    if isExecutingFrost then return false end
    local now = tick()
    if not isManual and (now - lastFrostCheck < 25) then return false end
    lastFrostCheck = now
    isExecutingFrost = true

    local s, err = pcall(function()
        local tier = math.clamp(tonumber(S.towerFloor) or 1, 1, 4)
        local gateOpen = isFrostGateOpen()

        -- 1. If FrostGate is not open, we MUST kill MagmaTitan in Dungeon 3 (เหมืองคริสตัลลึก) first!
        if not gateOpen then
            logActivity("Frost Tower: Unlocking Frost Gate... Clearing Dungeon 3 (เหมืองคริสตัลลึก)...", "Frost Tower")
            local savedTargetMode = S.dungeonTargetMode
            S.dungeonTargetMode = "Boss Only"
            pcall(function() doDungeonCycle("Dungeon3_CrystalMine", true) end)
            S.dungeonTargetMode = savedTargetMode
            task.wait(1.5)
            gateOpen = isFrostGateOpen()
        end

        if not gateOpen then
            logActivity("Frost Tower: Frost Gate did not open yet. Will retry Dungeon 3 next cycle.", "Frost Tower")
            isExecutingFrost = false
            return
        end

        -- 2. Frost Gate is active! Warp to Frost Gate Spot
        local gateSpot = plr:GetAttribute("FrostGateSpot")
        local root = getHRP()
        if gateSpot and typeof(gateSpot) == "CFrame" and root then
            logActivity("Frost Tower: Frost Gate is OPEN! Warping to Azureus Apparition...", "Frost Tower")
            moveToCFrame(gateSpot + Vector3.new(0, 3, 0))
            task.wait(0.6)

            -- Fire proximity prompt if present on apparition
            pcall(function()
                local gateFx = workspace:FindFirstChild("FrostGateFx")
                if gateFx then
                    for _, p in ipairs(gateFx:GetDescendants()) do
                        if p:IsA("ProximityPrompt") then
                            fireproximityprompt(p)
                            break
                        end
                    end
                end
            end)
            task.wait(0.4)
        end

        -- 3. Invoke FrostChallenge "start"
        logActivity(string.format("Challenging Azureus (Tier %d)...", tier), "Frost Tower")
        local ok, res, msg = pcall(function()
            return invoke(R.FrostChallenge, "start", tier)
        end)

        if ok and res == true then
            logActivity(string.format("Entered Frost Arena Tier %d! Slaying Azureus...", tier), "Frost Tower")
            local t0 = tick()
            while tick() - t0 < 90 and getgenv().BG_Running do
                if not plr:GetAttribute("FrostFight") and tick() - t0 > 6 then
                    break
                end
                local t = getBestTargetMonster(nil, "Azureus")
                if t and t.part and not t.model:GetAttribute("DiedAt") then
                    moveAndFaceMonster(t.part, t.model)
                    if S.autoTeamSkill then invoke(R.TeamSkill) end
                end
                task.wait(0.3)
            end
            enableCombatHover(false)
            logActivity("Frost Tower: Azureus slain! Returning to Farm...", "Frost Tower")
            task.wait(1.0)
            pcall(function() invoke(R.FrostChallenge, "gateback") end)
            task.wait(0.5)
            invoke(R.QuickWarp, "Farm")
        else
            local errStr = tostring(msg or "")
            logActivity("Frost Tower: " .. (errStr ~= "" and errStr or "Challenge rejected"), "Frost Tower")
        end
    end)

    if not s and err then
        warn("[BG_Frost] Error: " .. tostring(err))
    end
    isExecutingFrost = false
    return true
end

-- ===== AUTO MAIN QUEST COMPLETER (EXECUTES STORY QUESTS AUTOMATICALLY) =====
local isRunningMainQuest = false
local function doMainQuestStep()
    if isRunningMainQuest then return end
    isRunningMainQuest = true

    local s, err = pcall(function()
        local mqStep = plr:GetAttribute("MQStep") or 1
        local stepData = Config and Config.MainQuest and Config.MainQuest.Steps and Config.MainQuest.Steps[mqStep]
        if not stepData then
            return
        end

        local kind = stepData.kind or ""
        local title = stepData.title or ("Step " .. tostring(mqStep))
        logActivity(string.format("MQ %d [%s]: %s", mqStep, kind, title), S.currentLocation or "Main Quest")

        -- 1. Visit / Seen / Dialog
        if kind == "visit" or kind == "seen" or kind == "dialog" then
            invoke(R.MainQuestAction, "go")
            task.wait(1.0)
            local hrp = getHRP()
            if hrp then
                for _, prompt in ipairs(workspace:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                        local pPart = prompt.Parent and (prompt.Parent:IsA("BasePart") and prompt.Parent or prompt.Parent:FindFirstChildWhichIsA("BasePart"))
                        if pPart and (pPart.Position - hrp.Position).Magnitude <= (prompt.MaxActivationDistance + 4) then
                            pcall(fireproximityprompt, prompt)
                            task.wait(0.4)
                        end
                    end
                end
            end
            task.wait(1.0)

        -- 2. Hatch / Open Egg
        elseif kind == "hatch" then
            invoke(R.MainQuestAction, "go")
            task.wait(0.8)
            invoke(R.EggAction, "openAll")
            task.wait(0.5)
            invoke(R.HatchEgg, stepData.eggId or "BasicEgg", 1)
            task.wait(1.2)

        -- 3. Defeat Monster
        elseif kind == "defeat" then
            local targetZone = stepData.zone or 1
            local t0 = tick()
            while plr:GetAttribute("MQStep") == mqStep and tick() - t0 < 15 and S.autoMainQuest and getgenv().BG_Running do
                local target = getBestTargetMonster(targetZone, stepData.monster or stepData.target)
                if target and target.part and not target.model:GetAttribute("DiedAt") then
                    moveAndFaceMonster(target.part, target.model)
                    if S.autoTeamSkill then invoke(R.TeamSkill) end
                else
                    invoke(R.MainQuestAction, "go")
                end
                task.wait(0.3)
            end

        -- 4. Zone Unlock (Discover Camp)
        elseif kind == "zoneunlock" then
            local zNum = stepData.zone or 1
            local campPositions = {
                [1] = Vector3.new(0, 3.5, -158),
                [2] = Vector3.new(0, 7.5, -438),
                [3] = Vector3.new(0, 13.5, -718),
                [4] = Vector3.new(0, 27.5, -998),
                [5] = Vector3.new(0, 48.0, -1278),
            }
            local campPos = campPositions[zNum]
            if not campPos then
                pcall(function()
                    for _, z in ipairs(workspace.Map.Blockout.Zones:GetChildren()) do
                        if z.Name:find("Zone" .. tostring(zNum)) then
                            local ca = z:FindFirstChild("CampArea", true)
                            if ca then campPos = ca.Position + Vector3.new(0, 2, 0) end
                        end
                    end
                end)
            end
            local root = getHRP()
            if campPos and root then
                root.CFrame = CFrame.new(campPos)
                task.wait(1.0)
            else
                invoke(R.MainQuestAction, "go")
                task.wait(1.2)
            end

        -- 5. Team Skill in Combat
        elseif kind == "teamskill" then
            local target = getBestTargetMonster(stepData.zone or 1)
            if target and target.part and not target.model:GetAttribute("DiedAt") then
                moveAndFaceMonster(target.part, target.model)
                task.wait(0.3)
                invoke(R.TeamSkill)
            else
                invoke(R.MainQuestAction, "go")
                task.wait(1.0)
            end

        -- 6. Zone Quest Accept / Complete / Claim (SMART FULL ZQ ENGINE)
        elseif kind == "zqaccept" or kind == "zqclaim" then
            local targetZone = stepData.zone or 1
            local zKey = "Z" .. targetZone
            local zqData = getgenv().CachedData and getgenv().CachedData.zq and getgenv().CachedData.zq[zKey]
            local isOn = zqData and zqData.on == true
            local pCount = zqData and zqData.p or 0
            local def = getZoneQuestDef(targetZone, zqData and zqData.i or 1)
            local needCount = getQuestTargetNeed(def)

            -- Phase A: Quest NOT ACCEPTED -> Accept it at Quest NPC
            if not isOn then
                logActivity(string.format("MQ Step %d: Accepting Zone %d Quest at Merchant...", mqStep, targetZone), "Town")
                processZoneQuests(targetZone, "target_only")
                task.wait(0.6)

            -- Phase B: Quest ACCEPTED but NOT FINISHED -> Go defeat monsters in that zone
            elseif pCount < needCount then
                logActivity(string.format("MQ Step %d: Defeating Zone %d Monsters (%d/%d)...", mqStep, targetZone, pCount, needCount), "Zone " .. targetZone)
                warpToZoneSafely(targetZone)
                local t0 = tick()
                while plr:GetAttribute("MQStep") == mqStep and tick() - t0 < 14 and S.autoMainQuest and getgenv().BG_Running do
                    local curZQ = getgenv().CachedData and getgenv().CachedData.zq and getgenv().CachedData.zq[zKey]
                    if curZQ and (curZQ.p or 0) >= needCount then break end

                    local target = getBestTargetMonster(targetZone, getQuestTargetMob(def))
                    if target and target.part and not target.model:GetAttribute("DiedAt") then
                        moveAndFaceMonster(target.part, target.model)
                        if S.autoTeamSkill then invoke(R.TeamSkill) end
                    else
                        local campPos = zoneCampPositions[targetZone]
                        if campPos then
                            moveToCFrame(CFrame.new(campPos + Vector3.new(0, 3, 0)))
                        else
                            invoke(R.MainQuestAction, "go")
                        end
                    end
                    task.wait(0.3)
                end

            -- Phase C: Quest FINISHED -> Claim reward at Quest NPC
            else
                logActivity(string.format("MQ Step %d: Claiming Zone %d Quest Reward!", mqStep, targetZone), "Town")
                openQuestMerchant()
                task.wait(0.3)
                invoke(R.QuestAction, targetZone, "claim")
                local qp = plr.PlayerGui:FindFirstChild("QuestPanels")
                local claimBtn = qp and qp:FindFirstChild("Claim_" .. targetZone, true)
                if claimBtn then pcall(firesignal, claimBtn.Activated) end
                task.wait(0.8)
            end

        -- 7. Power Requirement (Equip Best Pets & Cards)
        elseif kind == "power" then
            invoke(R.AnimalAction, "best", "team")
            task.wait(0.3)
            invoke(R.AnimalAction, "best", "cards")
            task.wait(0.6)

        -- 8. Farm Level Requirement (Farm Crops / Plant Seeds)
        elseif kind == "level" then
            doRealFarmCycle()
            task.wait(1.0)

        -- 9. Fuse Beasts at Workshop
        elseif kind == "fuse" then
            invoke(R.MainQuestAction, "go")
            task.wait(1.2)
            local fuseUI = plr.PlayerGui:FindFirstChild("FuseUI")
            local recipeChicken = fuseUI and fuseUI:FindFirstChild("Recipe_Chicken", true)
            if recipeChicken then
                pcall(firesignal, recipeChicken.Activated)
                task.wait(0.4)
                local picks = fuseUI:FindFirstChild("Picks", true)
                if picks then
                    for _, child in ipairs(picks:GetChildren()) do
                        if child.Name == "FusePick" and child:GetAttribute("Picked") ~= true then
                            pcall(firesignal, child.Activated)
                            task.wait(0.2)
                        end
                    end
                end
                task.wait(0.4)
                local fuseGo = fuseUI:FindFirstChild("FuseGo", true)
                if fuseGo then pcall(firesignal, fuseGo.Activated) end
            end
            task.wait(1.8)

        -- 10. Refine Produce to Essence at Alchemy Tower
        elseif kind == "refine" then
            local pad = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Blockout", true) and workspace.Map.Blockout:FindFirstChild("Shop_AlchemyTower", true)
            local padPart = pad and (pad:FindFirstChild("ShopPad") or pad)
            local root = getHRP()
            if padPart and root then
                root.CFrame = padPart.CFrame + Vector3.new(0, 3, 0)
                task.wait(0.6)
                invoke(R.RefineProduce, { produce = { Strawberry = 10, Carrot = 5 } })
            end
            task.wait(1.5)

        -- 11. Infuse Essence at Alchemy Tower
        elseif kind == "infuse" then
            local pad = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Blockout", true) and workspace.Map.Blockout:FindFirstChild("Shop_AlchemyTower", true)
            local padPart = pad and (pad:FindFirstChild("ShopPad") or pad)
            local root = getHRP()
            if padPart and root then
                root.CFrame = padPart.CFrame + Vector3.new(0, 3, 0)
                task.wait(0.6)
                invoke(R.AnimalAction, "infuse", "a1", "ATK")
            end
            task.wait(1.5)

        -- 12. Animal Pen (Best / Toggle)
        elseif kind == "pen" then
            invoke(R.QuickWarp, "Farm")
            task.wait(0.6)
            local okPen = invoke(R.FarmAction, "penBest")
            if not okPen then
                invoke(R.FarmAction, "penToggle", "a8")
                invoke(R.FarmAction, "penToggle", "a1")
            end
            task.wait(1.0)

        -- 13. Pen Collect Coins
        elseif kind == "pencollect" then
            local myPlot = getMyPlot()
            local chest = myPlot and myPlot:FindFirstChild("PenChest")
            local body = chest and chest:FindFirstChild("Body")
            local root = getHRP()
            if body and root then
                root.CFrame = body.CFrame + Vector3.new(0, 3, 2)
                task.wait(0.4)
                invoke(R.FarmAction, "penCollect")
            end
            task.wait(1.0)

        -- 14. Pen Upgrade
        elseif kind == "penup" then
            invoke(R.QuickWarp, "Farm")
            task.wait(0.6)
            invoke(R.FarmAction, "penUp")
            task.wait(1.0)

        -- 15. Card Gacha Pull
        elseif kind == "cardpull" then
            invoke(R.MainQuestAction, "go")
            task.wait(0.8)
            invoke(R.CardShopAction, "buyticket")
            invoke(R.CardShopAction, "pull", 1)
            task.wait(1.2)

        -- 16. Equip Card
        elseif kind == "equipcard" then
            invoke(R.AnimalAction, "best", "cards")
            task.wait(0.4)
            invoke(R.AnimalAction, "equipcard", "a1", "M_SproutWalker")
            task.wait(0.8)

        -- 17. Plant Tree
        elseif kind == "treeplace" then
            invoke(R.QuickWarp, "Farm")
            task.wait(0.8)
            invoke(R.FarmAction, "treePlace", "Apple", { x = -15, z = -15 })
            task.wait(1.2)

        -- 18. Buy Gear (Sprinkler)
        elseif kind == "gearbuy" then
            local pad = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Blockout", true) and workspace.Map.Blockout:FindFirstChild("Shop_SeedShop", true)
            local padPart = pad and (pad:FindFirstChild("ShopPad") or pad)
            local root = getHRP()
            if padPart and root then
                root.CFrame = padPart.CFrame + Vector3.new(0, 3, 0)
                task.wait(0.5)
                invoke(R.FarmAction, "gearBuy", "Basic", 1)
            end
            task.wait(1.2)

        -- 19. Use Gear (Sprinkler)
        elseif kind == "gearuse" then
            invoke(R.QuickWarp, "Farm")
            task.wait(0.8)
            invoke(R.FarmAction, "gearUse", "Basic")
            task.wait(1.2)

        -- 20. Buy Seeds
        elseif kind == "buyseed" then
            local sId = stepData.seedId or "Carrot"
            buySeedsAtShop(sId, stepData.need or 5)
            task.wait(1.2)

        -- 21. Plant or Harvest Crops
        elseif kind == "plant" or kind == "harvest" then
            doRealFarmCycle()
            task.wait(1.2)

        -- 22. Buy Egg at Hatchery
        elseif kind == "buyegg" then
            invoke(R.QuickWarp, "Hatchery")
            task.wait(0.8)
            invoke(R.HatchEgg, stepData.eggId or "BasicEgg", 1)
            task.wait(1.2)

        -- 23. Place Egg in Incubator
        elseif kind == "placeegg" then
            invoke(R.EggAction, "fill", stepData.eggId or "BasicEgg", 1)
            task.wait(1.2)

        -- 24. Sell Produce at Market
        elseif kind == "sell" then
            doSellCycle("NORMAL")
            task.wait(1.2)

        -- 25. Star Up Animal
        elseif kind == "starup" then
            invoke(R.AnimalAction, "starup", "a1")
            task.wait(1.2)

        -- 26. Level Up Animal
        elseif kind == "level" then
            invoke(R.AnimalAction, "levelup", "a1", 1)
            task.wait(1.2)

        -- Fallback
        else
            invoke(R.MainQuestAction, "go")
            task.wait(1.2)
        end
    end)

    if not s and err then
        warn("[BG_MainQuest] Error: " .. tostring(err))
    end
    isRunningMainQuest = false
end

-- ===== FIZZ GOLDEN EGG ENGINE (PRIORITY #1) =====
local eggHoverBV = nil
local function cleanupEggHover()
    if eggHoverBV then
        pcall(function() eggHoverBV:Destroy() end)
        eggHoverBV = nil
    end
end

local function doGoldEggCycle()
    if not S.autoGoldEgg then
        cleanupEggHover()
        return
    end
    local root = getHRP()
    if not root then return end

    local fCenter = toVector3(BG:GetAttribute("FizzCenter")) or Vector3.new(0, 4, -40)
    local fHolder = tonumber(BG:GetAttribute("FizzHolder")) or 0
    local fEggPos = toVector3(BG:GetAttribute("FizzEggPos")) or fCenter

    -- Case A: WE ARE HOLDING THE GOLD EGG! (HOVER AT Y+30 UNTIL WIN/ROUND END)
    if fHolder == plr.UserId then
        logActivity("🌟 Holding Gold Egg! Hovering at Y+30 (Safe Ticket Farming)", "Fizz Arena")
        local hoverPos = Vector3.new(fCenter.X, fCenter.Y + 30, fCenter.Z)

        if not eggHoverBV or not eggHoverBV.Parent then
            cleanupEggHover()
            eggHoverBV = Instance.new("BodyVelocity")
            eggHoverBV.Name = "BG_GoldEggHover"
            eggHoverBV.Velocity = Vector3.new(0, 0, 0)
            eggHoverBV.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            eggHoverBV.Parent = root
            root.CFrame = CFrame.new(hoverPos)
        end

        -- Keep holding at Y+30 while event is active and we are the holder
        while isGoldEggActive() and tonumber(BG:GetAttribute("FizzHolder")) == plr.UserId and getgenv().BG_Running and S.autoGoldEgg do
            if (root.Position - hoverPos).Magnitude > 3 then
                root.CFrame = CFrame.new(hoverPos)
            end
            task.wait(0.5)
        end

        -- Event ended or lost egg: cleanup hover
        cleanupEggHover()

        -- If autoFizzTrade enabled and we have enough tickets, warp once to Fizz Booth and trade!
        if S.autoFizzTrade then
            local tickets = plr:GetAttribute("FizzTickets") or 0
            local seedId = S.fizzTradeSeedId or "FizzLime"
            local costs = { FizzLime = 3, FizzCherry = 3, FizzEggplant = 5, FizzPineapple = 5, FizzDurian = 8 }
            local cost = costs[seedId] or 3
            if tickets >= cost then
                logActivity("Warping to Fizz Booth to Trade " .. seedId .. "...", "Fizz Booth")
                root.CFrame = CFrame.new(-22.5, 6.0, -76.0)
                task.wait(0.5)
                local ok, res, msg = invoke(R.FizzAction, "trade", { n = 1, id = seedId })
                local msgStr = (type(msg) == "string" and msg) or (ok and ("Bought " .. seedId) or "Trade failed")
                notify("Fizz Shop", msgStr)
                logActivity(msgStr, "Fizz Booth")
                task.wait(0.5)
            end
        end

        logActivity("Gold Egg round complete! Resuming other tasks...", "Fizz Arena")
        return
    end

    cleanupEggHover()

    -- Step 1: Ensure character is in Fizz Arena by warping once
    local distToCenter = (root.Position - fCenter).Magnitude
    if distToCenter > 60 then
        logActivity("Warping to Fizz Arena...", "Fizz Arena")
        invoke(R.FizzAction, "go")
        task.wait(0.3)
        root = getHRP()
        if not root then return end
        if (root.Position - fCenter).Magnitude > 60 then
            root.CFrame = CFrame.new(fCenter + Vector3.new(0, 2.5, 0))
            task.wait(0.2)
        end
    end

    -- Case B: ANOTHER PLAYER IS HOLDING THE EGG!
    if fHolder > 0 and fHolder ~= plr.UserId then
        local targetPlr = Players:GetPlayerByUserId(fHolder)
        local hName = targetPlr and targetPlr.Name or tostring(fHolder)
        logActivity("Chasing Egg Holder (" .. hName .. ")...", "Fizz Arena")

        local tChar = targetPlr and targetPlr.Character
        local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart")
        if tHrp then
            root.CFrame = CFrame.lookAt(tHrp.Position + Vector3.new(0, 1.2, 2.5), tHrp.Position)
        else
            root.CFrame = CFrame.new(fEggPos + Vector3.new(0, 2, 0))
        end

        invoke(R.FizzAction, "cast", fHolder)
        task.wait(0.3)
        return
    end

    -- Case C: EGG IS FREE ON THE GROUND!
    logActivity("🥚 Grabbing Gold Egg!", "Fizz Arena")
    root.CFrame = CFrame.new(fEggPos + Vector3.new(0, 1.2, 0))
    task.wait(0.2)
end

-- ===== MASTER MULTI-TASK & BACKGROUND AUTOMATION TIMERS =====
local lastQuestCheck        = tick()
local lastCropCheck         = tick()
local lastSellCheck         = tick()
local lastPenCollectCheck   = tick()
local lastPenFeedCheck      = tick()
local lastCardPullCheck     = tick()
local lastFruitHarvestCheck = tick()
local lastEquipBestCheck    = tick()
local lastHouseUpgradeCheck = tick()
local lastRefineCheck       = tick()
local lastBedBuyCheck       = tick()
local lastEggBuyCheck       = tick()
local lastEggFillCheck      = tick()
local lastEggOpenCheck      = tick()

if type(getgenv().BG_API) == "table" then
    getgenv().BG_API.doActiveZoneQuestStep   = doActiveZoneQuestStep
    getgenv().BG_API.doColosseumStep         = doColosseumStep
    getgenv().BG_API.doFrostTowerStep        = doFrostTowerStep
    getgenv().BG_API.doDungeonCycle          = doDungeonCycle
    getgenv().BG_API.doWateringSprinklerStep = doWateringSprinklerStep
    getgenv().BG_API.getAvailableSprinklersToBuy = getAvailableSprinklersToBuy
    getgenv().BG_API.buySprinklersBatchAtShop = buySprinklersBatchAtShop
    getgenv().BG_API.warpToZoneSafely        = warpToZoneSafely
    getgenv().BG_API.doUnifiedQuestCycle     = doUnifiedQuestCycle
end

task.spawn(function()
    while task.wait(0.2) do
        if not isSessionActive() then break end

        -- Mutex: Prevent any overlapping teleports or conflicting workflows
        if isFarming or isSelling or isExecutingDungeon or isExecutingArena or isExecutingFrost or isExecutingQuest or isRunningMainQuest or isExecutingSprinkler then
            task.wait(0.25)
            continue
        end

        local loopRoot = getHRP()
        if loopRoot and loopRoot.Position.X > 900 then
            -- Inside dungeon: Prevent background tasks from hijacking position
            task.wait(0.25)
            continue
        end

        local now = tick()

        -- PRIORITY 1: GOLD EGG EVENT (PREEMPTS EVERYTHING WHILE ACTIVE)
        if S.autoGoldEgg and isGoldEggActive() then
            doGoldEggCycle()

        -- PRIORITY 2: HUNT ACTIVE SELECTED BOSS (WHEN ALIVE IN WS)
        elseif S.autoBossHunt and getAliveSelectedBoss() ~= nil then
            doSingleBossStep()

        -- PRIORITY 3: PERIODIC CROP FARMING & ANIMAL FEED (QUICK HARVEST + REPLANT ~1.5s)
        elseif S.autoFarm and (now - lastCropCheck >= (S.cropInterval or 20)) then
            lastCropCheck = now
            doRealFarmCycle()

            -- AUTO WATER CROPS (SPRINKLERS)
            if S.autoWaterSprinkler or S.autoBuySprinkler then
                task.spawn(function() doWateringSprinklerStep(false) end)
            end

            -- AUTO FEED ANIMALS WITH FRESH PRODUCE BEFORE SELLING
            if S.autoPenFeed then
                doPenFeedCycle(false)
            end

            if S.autoSellOn and getSellableProduceCount(S.sellMode) > 0 then
                doSellCycle(S.sellMode, false)
            elseif S.autoPenCollect and not isCollectingCoins then
                if (now - (lastPenCollectCheck or 0) >= 10) then
                    lastPenCollectCheck = now
                    task.spawn(function() doPenCoinCollect(false) end)
                end
            end

        -- PRIORITY 3.5: AUTO WATERING / SPRINKLER (CROP GROWTH BOOST & RESTOCK BUY)
        elseif (S.autoWaterSprinkler or S.autoBuySprinkler) and (now - (lastSprinklerCheck or 0) >= 15) then
            doWateringSprinklerStep(false)

        -- PRIORITY 4: COLOSSEUM / ARENA MATCH (DUEL AGAINST TRAINERS/PLAYERS)
        elseif S.autoColosseum and (now - lastArenaCheck >= 25) then
            doColosseumStep(false)

        -- PRIORITY 5: FROST TOWER / AZUREUS CHALLENGE
        elseif S.autoTower and (now - lastFrostCheck >= 35) then
            doFrostTowerStep(false)

        -- PRIORITY 6: AUTO DUNGEON GRIND (ZONE 2, 3, 4 DUNGEON PORTALS)
        elseif S.autoDungeon and (now - lastDungeonTime >= (S.dungeonInterval or 40)) then
            doDungeonCycle(S.selectedDungeon, false)

        -- PRIORITY 7: AUTO ZONE QUEST EXECUTION (WARP TO ZONE, HUNT MOBS, CLAIM AT NPC)
        elseif S.autoQuestOn and doActiveZoneQuestStep() then
            task.wait(0.2)

        -- PRIORITY 8: AUTO MAIN QUEST (STORY PROGRESSION UNTIL FINISHED)
        elseif S.autoMainQuest and doMainQuestStep() then
            task.wait(0.2)

        -- STANDALONE AUTO SELL (WHEN CROP FARMING IS NOT ACTIVE)
        elseif S.autoSellOn and not S.autoFarm and (now - lastSellCheck >= (S.autoSellSecs or 45)) then
            lastSellCheck = now
            if getSellableProduceCount(S.sellMode) > 0 then
                doSellCycle(S.sellMode, false)
            end

        -- PRIORITY 9: MOB FARMING (BASE CONTINUOUS GRIND)
        elseif S.autoFarmMobs then
            doSingleMobStep()
        end
    end
end)

-- ===== SECONDARY INDEPENDENT AUTOMATION LOOP (BUY EGGS, INCUBATORS, PEN COINS, FRUIT, HOUSE) =====

task.spawn(function()
    while task.wait(0.8) do
        if not isSessionActive() then break end
        if S.autoGoldEgg and isGoldEggActive and isGoldEggActive() then
            -- Pause background plot actions while fighting for / holding the Gold Egg
            continue
        end

        -- MUTEX GUARD: Pause secondary plot actions while in Dungeon, Arena, Frost, Quest, or Farm cycles
        if isExecutingDungeon or isExecutingArena or isExecutingFrost or isExecutingQuest or isRunningMainQuest or isFarming or isSelling then
            continue
        end

        local secRoot = getHRP()
        if secRoot and secRoot.Position.X > 900 then
            continue
        end

        local now = tick()

        -- 1. Auto Buy Eggs Timer (Background non-blocking remote invocation)
        if (S.autoBuyEgg or S.autoHatchEgg) and (now - lastEggBuyCheck >= (S.buyEggInterval or 5)) then
            lastEggBuyCheck = now
            doBuyEggCycle(false)
        end

        -- 2. Auto Place Eggs in Incubator Timer (Non-blocking)
        if S.autoFillIncubator and (now - lastEggFillCheck >= 8) then
            lastEggFillCheck = now
            doFillIncubatorCycle(false)
        end

        -- 3. Auto Collect Hatched Pets Timer (Non-blocking)
        if S.autoOpenAllEggs and (now - lastEggOpenCheck >= 4) then
            lastEggOpenCheck = now
            invoke(R.EggAction, "openAll")
        end

        -- 4. Pen Coin Collection Timer (Configurable interval, auto-warp to PenChest)
        if S.autoPenCollect and (now - lastPenCollectCheck >= (S.penCollectInterval or 45)) and not isFarming and not isSelling then
            lastPenCollectCheck = now
            doPenCoinCollect(false)
        end

        -- 5. Auto Feed Animals Timer (Uses safe crops to feed hungry animals in pen)
        if S.autoPenFeed and (now - lastPenFeedCheck >= (S.penFeedInterval or 25)) and not isFarming and not isSelling then
            lastPenFeedCheck = now
            doPenFeedCycle(false)
        end

        -- 6. Auto Card Gacha Timer (Warp to Card Shrine -> Buy Ticket & Pull 10x -> Return)
        if S.autoCardPull and (now - lastCardPullCheck >= (S.cardPullInterval or 6)) and not isFarming and not isSelling then
            lastCardPullCheck = now
            doCardPullCycle(false)
        end

        -- 5. Fruit Tree Harvest Timer
        if S.autoHarvestFruit and (now - lastFruitHarvestCheck >= (S.fruitInterval or 30)) and not isFarming and not isSelling then
            lastFruitHarvestCheck = now
            doFruitTreeHarvest(false)
        end

        -- 6. Equip Best Animals All Slots Timer
        if S.autoEquipBestAll and (now - lastEquipBestCheck >= (S.equipBestInterval or 60)) and not isFarming and not isSelling then
            lastEquipBestCheck = now
            doEquipBestAll(false)
        end

        -- 7. House Upgrade Timer (Checks if level and coins sufficient, warps and upgrades)
        if S.autoUpgradeHouse and (now - lastHouseUpgradeCheck >= 30) and not isFarming and not isSelling then
            lastHouseUpgradeCheck = now
            doUpgradeHouse(false)
        end

        -- 8. Auto Refine Produce into Essence Timer
        if S.autoRefineProduce and (now - lastRefineCheck >= 30) and not isFarming and not isSelling then
            lastRefineCheck = now
            doRefineAllProduce(false)
        end

        -- 9. Auto Buy Bed Groups Timer (Checks if coins sufficient for next 3x3 bed group, warps and buys)
        if S.autoBuyBeds and (now - lastBedBuyCheck >= 20) and not isFarming and not isSelling then
            lastBedBuyCheck = now
            doBuyBedGroups(false)
        end
    end
end)

-- Performance & Low Graphics
local lowGraphicConn = nil
local function applyLowGraphics(enable)
    S.lowGraphic = enable
    if enable then
        pcall(function()
            settings().Rendering.QualityLevel = 1
            UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
        end)
        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            Lighting.Brightness = 1
            for _, v in pairs(Lighting:GetChildren()) do
                if v:IsA("PostEffect") or v:IsA("Atmosphere") or v:IsA("Sky")
                    or v:IsA("BloomEffect") or v:IsA("BlurEffect")
                    or v:IsA("ColorCorrectionEffect") or v:IsA("SunRaysEffect")
                    or v:IsA("DepthOfFieldEffect") then
                    v.Enabled = false
                end
            end
        end)
        local function cleanItem(v)
            if v:IsA("BasePart") and not v:IsA("MeshPart") then
                v.Material = Enum.Material.SmoothPlastic
                v.Reflectance = 0
                v.CastShadow = false
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v.Transparency = 1
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                v.Enabled = false
            end
        end
        for _, v in pairs(workspace:GetDescendants()) do cleanItem(v) end
        if not lowGraphicConn then
            lowGraphicConn = trackConnection(workspace.DescendantAdded:Connect(function(v)
                if S.lowGraphic then task.defer(cleanItem, v) end
            end))
        end
        notify("Low Graphics", "Enabled: Textures & shadows stripped.")
    else
        if lowGraphicConn then
            lowGraphicConn:Disconnect()
            lowGraphicConn = nil
        end
        notify("Low Graphics", "Disabled.")
    end
end

local function set3DRendering(enabled)
    S.rendering3D = enabled
    pcall(function() RunService:Set3dRenderingEnabled(enabled) end)
    notify("3D Rendering", enabled and "3D Viewport On" or "3D Viewport Paused (0% GPU)")
end

-- Anti-AFK
local function initAntiAFK()
    trackConnection(plr.Idled:Connect(function()
        if S.antiAFK then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end))
end
initAntiAFK()

-- Timers for background tasks
local afkTimer, webhookTimer, cardTimer = 0, 0, 0
trackConnection(RunService.Heartbeat:Connect(function(dt)
    if not getgenv().BG_Running then return end

    -- Anti-AFK heartbeat pulse
    if S.antiAFK then
        afkTimer = afkTimer + dt
        if afkTimer >= 25.0 then
            afkTimer = 0
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end

    -- Webhook status update
    if S.webhookAutoLog and S.webhookUrl and S.webhookUrl:find("https://") then
        webhookTimer = webhookTimer + dt
        if webhookTimer >= (S.webhookInterval or 120) then
            webhookTimer = 0
            task.spawn(function()
                sendDiscordWebhook("Beast Garden Status Update")
            end)
        end
    end

    -- Update Gold Egg Paragraph in UI if visible
    if goldEggStatusPara and goldEggStatusPara.SetDesc then
        pcall(function() goldEggStatusPara:SetDesc(getGoldEggStatusString()) end)
    end
end))

-- ===== BUILD WINDUI WINDOW =====
local Win = WindUI:CreateWindow({
    Title       = "Beast Garden Hub",
    Author      = "made by ud0 Custom",
    Icon        = "rbxassetid://86949082023913",
    Folder      = "BeastGarden_ud0",
    Size        = UDim2.fromOffset(640, 500),
    Transparent = true,
    Theme       = "YellowBlack",
    Keybind     = Enum.KeyCode.RightControl,
})
pcall(function() Win:SetToggleKey(Enum.KeyCode.RightControl) end)
getgenv().BG_Win = Win

-- ONLY green discord.gg/axel hub tag (NO CLOCK TAG)
Win:Tag({
    Title = "discord.gg/axel hub",
    Color = Color3.fromHex("#00FF66")
})

-- ==============================================================================
-- TAB 1: 🌾 FARM & MARKET
-- ==============================================================================
local tFarm = Win:Tab({Title = "Farm & Market", Icon = "sprout"})

tFarm:Section({Title = "Crop Farming"})

tFarm:Toggle({
    Title = "Auto Farm Crops (Harvest + Plant)",
    Value = false,
    Callback = function(v)
        S.autoFarm = v
        if v then task.spawn(doRealFarmCycle) end
        logActivity(v and "Auto Farm Active" or "Auto Farm Stopped")
    end
})

tFarm:Slider({
    Title = "Crop Sweep Interval (Seconds)",
    Step = 5,
    Value = {Min = 10, Max = 120, Default = 20},
    Min = 10, Max = 120, Default = 20,
    Callback = function(v) S.cropInterval = v end
})

do
    local plantOpts = {}
    local sortedList = {}
    for _, s in ipairs(ALL_SEEDS) do
        if s.price > 0 or s.inShop then
            table.insert(sortedList, s)
        end
    end
    table.sort(sortedList, function(a, b)
        local wA = (a.price > 0 and a.price) or a.sell or 0
        local wB = (b.price > 0 and b.price) or b.sell or 0
        return wA > wB
    end)
    for _, s in ipairs(sortedList) do
        table.insert(plantOpts, s.id .. " (" .. s.rarity .. ")")
    end
    tFarm:Dropdown({
        Title = "Seed to Plant (Multi Selection - Top Tier First)",
        Values = plantOpts,
        Value = {"Carrot (Common)"},
        Multi = true,
        Callback = function(sel)
            local raw = {}
            for _, item in ipairs(parseMultiDropdown(sel)) do
                local sId = item:match("^([%w_]+)") or item
                if sId and sId ~= "" then
                    table.insert(raw, sId)
                end
            end
            S.selectedSeeds = getSortedSeeds(raw)
            if #S.selectedSeeds > 0 then
                S.plantSeedId = S.selectedSeeds[1]
            end
        end
    })
end

tFarm:Toggle({
    Title = "Auto Buy Seeds (When Out)",
    Value = false,
    Callback = function(v) S.autoBuySeed = v end
})

tFarm:Slider({
    Title = "Seed Buy Amount",
    Step = 1,
    Value = {Min = 1, Max = 50, Default = 5},
    Min = 1, Max = 50, Default = 5,
    Callback = function(v) S.buyAmount = v end
})

tFarm:Button({
    Title = "Buy Selected Seeds Now (Warp to Shop)",
    Callback = function()
        task.spawn(function()
            local rawSeeds = (S.selectedSeeds and #S.selectedSeeds > 0 and S.selectedSeeds) or { S.plantSeedId or "Carrot" }
            local seedsToBuy = getSortedSeeds(rawSeeds)
            local buyQueue = {}
            for _, sId in ipairs(seedsToBuy) do
                local rem = getSeedStockRemaining(sId)
                if rem > 0 then
                    table.insert(buyQueue, { id = sId, amount = math.min(rem, S.buyAmount or 5) })
                end
            end

            if #buyQueue > 0 then
                buySeedsBatch(buyQueue, true)
            else
                notify("Seed Shop", "เมล็ดที่เลือกทั้งหมดไม่มีสินค้าในสต็อก (รอร้านค้ารีสต็อก)!")
            end
        end)
    end
})

tFarm:Button({
    Title = "Harvest & Plant Now",
    Callback = function() task.spawn(doRealFarmCycle) end
})

tFarm:Toggle({
    Title = "Auto Buy Crop Bed Groups (เมื่อเงินถึง - วาร์ปซื้อทีละ 3x3)",
    Value = false,
    Callback = function(v)
        S.autoBuyBeds = v
        if v then task.spawn(function() doBuyBedGroups(true) end) end
    end
})

tFarm:Button({
    Title = "Buy Available Bed Groups Now (Warp & Buy 3x3)",
    Callback = function() task.spawn(function() doBuyBedGroups(true) end) end
})

tFarm:Divider()
tFarm:Section({Title = "💧 Watering & Sprinklers (รดน้ำ & สปริงเกลอร์เร่งโต)"})

tFarm:Toggle({
    Title = "Auto Water Crops (รดน้ำอัตโนมัติด้วยสปริงเกลอร์)",
    Value = false,
    Callback = function(v)
        S.autoWaterSprinkler = v
        if v then task.spawn(function() doWateringSprinklerStep(true) end) end
        logActivity(v and "Auto Watering Active" or "Auto Watering Stopped")
    end
})

tFarm:Dropdown({
    Title = "Sprinkler Tier to Use (ระดับที่ใช้วางรดน้ำในแปลง)",
    Values = {"Rainbow (สายรุ้ง +70%)", "Gold (ทอง +50%)", "Big (ใหญ่ +40%)", "Basic (ไม้ +30%)"},
    Value = "Rainbow (สายรุ้ง +70%)",
    Callback = function(v)
        local raw = tostring(v):match("^(%a+)") or "Rainbow"
        S.sprinklerType = raw
    end
})

tFarm:Button({
    Title = "Water Crops Now (เปิดสปริงเกลอร์รดน้ำทันที)",
    Callback = function() task.spawn(function() doWateringSprinklerStep(true) end) end
})

tFarm:Dropdown({
    Title = "Sprinklers to Buy (เลือกซื้อหลายอย่าง - Multi)",
    Values = {"Rainbow (สายรุ้ง +70%)", "Gold (ทอง +50%)", "Big (ใหญ่ +40%)", "Basic (ไม้ +30%)"},
    Value = {"Rainbow (สายรุ้ง +70%)", "Gold (ทอง +50%)"},
    Multi = true,
    Callback = function(sel)
        S.selectedSprinklersToBuy = {}
        for _, item in ipairs(parseMultiDropdown(sel)) do
            local raw = tostring(item):match("^(%a+)")
            if raw and raw ~= "" then
                S.selectedSprinklersToBuy[raw] = true
            end
        end
        lastSprinklerRestockId = -1
    end
})

tFarm:Toggle({
    Title = "Auto Buy Sprinklers (ตรวจซื้ออัตโนมัติเมื่อสต็อกรีเซ็ต)",
    Value = false,
    Callback = function(v)
        S.autoBuySprinkler = v
        if v then
            lastSprinklerRestockId = -1
            task.spawn(function() doWateringSprinklerStep(false) end)
        end
    end
})

tFarm:Button({
    Title = "Buy Available Sprinklers Now (TP ร้านค้า & ซื้อสต็อกทันที)",
    Callback = function() task.spawn(function() doWateringSprinklerStep(true) end) end
})

tFarm:Divider()
tFarm:Section({Title = "Market Selling (ขายผลผลิตทั้งหมดที่ตลาด)"})

tFarm:Toggle({
    Title = "Auto Sell ALL at Market (Auto Warp)",
    Value = false,
    Callback = function(v)
        S.autoSellOn = v
        if v and getSellableProduceCount("ALL") > 0 then
            task.spawn(function() doSellCycle("ALL", false) end)
        end
    end
})

tFarm:Slider({
    Title = "Sell Interval (Seconds)",
    Step = 5,
    Value = {Min = 15, Max = 180, Default = 45},
    Min = 15, Max = 180, Default = 45,
    Callback = function(v) S.autoSellSecs = v end
})

tFarm:Button({
    Title = "Sell ALL Produce Now (Warp to Market)",
    Callback = function() task.spawn(function() doSellCycle("ALL", true) end) end
})

tFarm:Divider()
tFarm:Section({Title = "Animal Enclosure & Auto Equip (คอกสัตว์ & จัดสัตว์เทพสุด)"})

tFarm:Toggle({
    Title = "Auto Collect Enclosure Coins",
    Value = false,
    Callback = function(v)
        S.autoPenCollect = v
        if not v then
            isCollectingCoins = false
        elseif not isFarming and not isSelling then
            task.spawn(function() doPenCoinCollect(false) end)
        end
    end
})

tFarm:Slider({
    Title = "Coin Collect Interval (Seconds)",
    Step = 5,
    Value = {Min = 15, Max = 300, Default = 45},
    Min = 15, Max = 300, Default = 45,
    Callback = function(v) S.penCollectInterval = v end
})

tFarm:Button({
    Title = "Collect Enclosure Coins Now (Warp to Chest)",
    Callback = function() task.spawn(function() doPenCoinCollect(true) end) end
})

tFarm:Toggle({
    Title = "Auto Equip Best Animals (All Slots - Pen + Guard + Team)",
    Value = false,
    Callback = function(v)
        S.autoEquipBestAll = v
        if v then task.spawn(function() doEquipBestAll(true) end) end
    end
})

tFarm:Button({
    Title = "Equip Best Animals Now (Fill All Pen Slots + Guard + Team)",
    Callback = function() task.spawn(function() doEquipBestAll(true) end) end
})

tFarm:Toggle({
    Title = "Auto Feed Animals (ให้อาหารสัตว์)",
    Value = false,
    Callback = function(v)
        S.autoPenFeed = v
        if v and not isFarming and not isSelling then
            task.spawn(function() doPenFeedCycle(false) end)
        end
    end
})

tFarm:Dropdown({
    Title = "Feed Crop Mode",
    Values = {
        "Feed All Safe (Common/Uncommon)",
        "Feed All (Up to Rare)",
        "Carrot",
        "Strawberry",
        "LifeApple",
        "StonePumpkin",
        "Moonflower",
        "ThunderCorn",
        "GlowBerry"
    },
    Value = "Feed All Safe (Common/Uncommon)",
    Callback = function(sel)
        S.penFeedMode = (type(sel) == "table" and sel[1]) or sel
    end
})

tFarm:Button({
    Title = "Feed All Animals Now",
    Callback = function()
        task.spawn(function() doPenFeedCycle(true) end)
    end
})

tFarm:Divider()
tFarm:Section({Title = "Orchard Fruit Trees & House Upgrade (สวนผลไม้ & อัพเกรดบ้าน)"})

tFarm:Toggle({
    Title = "Auto Harvest Fruit Trees",
    Value = false,
    Callback = function(v) S.autoHarvestFruit = v end
})

tFarm:Slider({
    Title = "Fruit Harvest Interval (Seconds)",
    Step = 5,
    Value = {Min = 15, Max = 180, Default = 30},
    Min = 15, Max = 180, Default = 30,
    Callback = function(v) S.fruitInterval = v end
})

tFarm:Button({
    Title = "Harvest Fruit Trees Now",
    Callback = function() task.spawn(function() doFruitTreeHarvest(true) end) end
})

tFarm:Toggle({
    Title = "Auto Upgrade House (When Affordable)",
    Value = false,
    Callback = function(v) S.autoUpgradeHouse = v end
})

tFarm:Button({
    Title = "Upgrade House Now",
    Callback = function() task.spawn(function() doUpgradeHouse(true) end) end
})

-- ==============================================================================
-- TAB 2: ⚔️ COMBAT & BOSSES
-- ==============================================================================
local tCombat = Win:Tab({Title = "Combat & Bosses", Icon = "swords"})

tCombat:Section({Title = "Auto Farm Monsters (Dynamic Zone Filter)"})

do
    local zOpts = {}
    for _, z in ipairs(ZONES) do table.insert(zOpts, z.name) end
    tCombat:Dropdown({
        Title = "Target Zone",
        Values = zOpts,
        Value = zOpts[1],
        Callback = function(sel)
            if type(sel) == "table" then sel = sel[1] end
            for _, z in ipairs(ZONES) do
                if sel and sel:find(z.name, 1, true) then
                    S.warpZone = z.n
                    S.currentLocation = z.name
                    if mobFilterDropdown and mobFilterDropdown.Refresh then
                        local zoneMobs = getMonstersForZone(z.n)
                        mobFilterDropdown:Refresh(zoneMobs, {})
                        S.selectedMonsters = {}
                    end
                    break
                end
            end
        end
    })
end

local initialZoneMobs = getMonstersForZone(1)
mobFilterDropdown = tCombat:Dropdown({
    Title = "Target Monsters (Select Target - Multi)",
    Values = initialZoneMobs,
    Value = {},
    Multi = true,
    Callback = function(sel)
        S.selectedMonsters = {}
        for _, item in ipairs(parseMultiDropdown(sel)) do
            local clean = item:match("^([%w_]+)") or item
            S.selectedMonsters[clean] = true
            S.selectedMonsters[clean:lower()] = true
        end
    end
})

tCombat:Toggle({
    Title = "Auto Target Monster (ตีตัวเป้าหมายก่อน ถ้าหมดตีตัวอื่น)",
    Value = false,
    Callback = function(v) S.autoTargetMonster = v end
})

tCombat:Toggle({
    Title = "Auto Farm Monsters (Warp + Attack)",
    Value = false,
    Callback = function(v) S.autoFarmMobs = v end
})

tCombat:Toggle({
    Title = "🛡️ Safe Float / Hover Farm (ตัวลอยเหนือมอน ไม่โดนบอสตีตาย)",
    Value = true,
    Callback = function(v)
        S.combatFloat = v
        if not v then enableCombatHover(false) end
    end
})

tCombat:Slider({
    Title = "Hover Height (ความสูงตัวลอยเหนือมอน)",
    Step = 1,
    Value = {Min = 6, Max = 16, Default = 11},
    Min = 6, Max = 16, Default = 11,
    Callback = function(v) S.combatFloatHeight = v end
})

tCombat:Toggle({
    Title = "Auto Team Skill (3x DMG Burst)",
    Value = false,
    Callback = function(v) S.autoTeamSkill = v end
})

tCombat:Dropdown({
    Title = "Target Priority",
    Values = {"Closest First", "Boss First", "Lowest HP First", "Highest HP First"},
    Value = "Closest First",
    Callback = function(sel)
        S.mobPriority = (type(sel) == "table" and sel[1]) or sel
    end
})

tCombat:Dropdown({
    Title = "Movement Mode",
    Values = {"Teleport", "Tween"},
    Value = "Teleport",
    Callback = function(sel)
        S.moveMode = (type(sel) == "table" and sel[1]) or sel
    end
})

tCombat:Slider({
    Title = "Tween Speed",
    Step = 10,
    Value = {Min = 50, Max = 400, Default = 150},
    Min = 50, Max = 400, Default = 150,
    Callback = function(v) S.tweenSpeed = v end
})

tCombat:Divider()
tCombat:Section({Title = "Boss Hunting & Server Hop"})

do
    local bOpts = {}
    for _, z in ipairs(ZONES) do table.insert(bOpts, "Z" .. z.n .. " - " .. z.boss) end
    tCombat:Dropdown({
        Title = "Select Bosses to Hunt (Multi)",
        Values = bOpts,
        Value = {},
        Multi = true,
        Callback = function(sel)
            S.selectedBosses = {}
            for _, lbl in ipairs(parseMultiDropdown(sel)) do
                local b = lbl:match("- (.+)$") or lbl
                if b then S.selectedBosses[b] = true end
            end
        end
    })
end

tCombat:Toggle({
    Title = "Auto Hunt Boss",
    Value = false,
    Callback = function(v) S.autoBossHunt = v end
})

tCombat:Toggle({
    Title = "Server Hop When Boss Dead",
    Value = false,
    Callback = function(v) S.autoBossServerHop = v end
})

-- ==============================================================================
-- TAB 3: 📜 QUESTS & DUNGEONS
-- ==============================================================================
local tQD = Win:Tab({Title = "Quests & Dungeons", Icon = "scroll"})

tQD:Section({Title = "Main Quest Completer (เควสหลักอัตโนมัติ)"})

tQD:Toggle({
    Title = "Auto Main Quest (ทำตามเควสหลักจนเสร็จ)",
    Value = false,
    Callback = function(v)
        S.autoMainQuest = v
        if v then task.spawn(doMainQuestStep) end
    end
})

tQD:Button({
    Title = "Execute Next Main Quest Step Now",
    Callback = function()
        task.spawn(doMainQuestStep)
    end
})

tQD:Divider()
tQD:Section({Title = "Zone & Daily Quests (เควสโซน & เควสประจำวัน)"})

tQD:Toggle({
    Title = "Auto Quests & Daily Rewards (ทำเควส & ส่งเควสอัตโนมัติ)",
    Value = false,
    Callback = function(v)
        S.autoQuestOn = v
        if v then task.spawn(doUnifiedQuestCycle) end
    end
})

tQD:Slider({
    Title = "Quest Check Interval (Seconds)",
    Step = 5,
    Value = {Min = 15, Max = 120, Default = 30},
    Min = 15, Max = 120, Default = 30,
    Callback = function(v) S.questInterval = v end
})

tQD:Button({
    Title = "Claim & Accept All Quests Now (ส่งและรับเควสทั้งหมด)",
    Callback = function() task.spawn(doUnifiedQuestCycle) end
})

tQD:Button({
    Title = "Do Current Quest Step Now (วาร์ปไปตีมอนเควสทันที)",
    Callback = function() task.spawn(doActiveZoneQuestStep) end
})

tQD:Divider()
tQD:Section({Title = "Colosseum (Arena)"})

tQD:Dropdown({
    Title = "Arena Match Mode",
    Values = {"Ranked Match (start)", "Practice (practice)"},
    Value = "Ranked Match (start)",
    Callback = function(sel)
        if type(sel) == "table" then sel = sel[1] end
        S.arenaMode = sel:find("practice") and "practice" or "start"
    end
})

tQD:Toggle({
    Title = "Auto Colosseum Matches (ลงประลองอัตโนมัติ)",
    Value = false,
    Callback = function(v)
        S.autoColosseum = v
    end
})

tQD:Button({
    Title = "Join Arena Match Now (ลงแข่งทันที)",
    Callback = function()
        task.spawn(function()
            doColosseumStep(true)
        end)
    end
})

tQD:Button({
    Title = "Claim Arena Title (รับฉายาประลอง)",
    Callback = function() invoke(R.ArenaAction, "title") end
})

tQD:Divider()
tQD:Section({Title = "❄️ Auto Frost Boss / Azureus (ดันน้ำแข็ง - สับ Z3 ปลดล็อค)"})

tQD:Slider({
    Title = "Target Tier (1-4)",
    Step = 1,
    Value = {Min = 1, Max = 4, Default = 1},
    Min = 1, Max = 4, Default = 1,
    Callback = function(v) S.towerFloor = v end
})

tQD:Toggle({
    Title = "Auto Frost Boss (เคลียร์บอส Z3 -> เข้าตีดันน้ำแข็งอัตโนมัติ)",
    Value = false,
    Callback = function(v)
        S.autoTower = v
    end
})

tQD:Button({
    Title = "Start Azureus Hunt Now (สับบอส Z3 ทันที -> เข้าห้องน้ำแข็ง)",
    Callback = function()
        task.spawn(function()
            doFrostTowerStep(true)
        end)
    end
})

tQD:Button({
    Title = "Exit Tower / Gate Back (ออกจากห้องบอส)",
    Callback = function() invoke(R.FrostChallenge, "gateback") end
})

tQD:Divider()
tQD:Section({Title = "🏰 Auto Dungeon (ดันเจี้ยนประจำโซน 2, 3, 4)"})

tQD:Toggle({
    Title = "Auto Dungeon (ลงดันเจี้ยนอัตโนมัติ)",
    Value = false,
    Callback = function(v)
        S.autoDungeon = v
    end
})

tQD:Dropdown({
    Title = "Select Dungeon",
    Values = {"All Dungeons (วนทุกดัน)", "Zone 2: Root Cave (ถ้ำรากไม้)", "Zone 3: Crystal Mine (เหมืองคริสตัล)", "Zone 4: Cloud Temple (วิหารเมฆา)"},
    Value = "All Dungeons (วนทุกดัน)",
    Callback = function(sel)
        if type(sel) == "table" then sel = sel[1] end
        S.selectedDungeon = sel
    end
})

tQD:Dropdown({
    Title = "Dungeon Target Mode",
    Values = {"Clear All Mobs + Boss (กวาดมอนทุกตัว + บอส)", "Boss Only (ตีเฉพาะบอส)"},
    Value = "Clear All Mobs + Boss (กวาดมอนทุกตัว + บอส)",
    Callback = function(sel)
        if type(sel) == "table" then sel = sel[1] end
        S.dungeonTargetMode = sel
    end
})

tQD:Slider({
    Title = "Dungeon Cooldown / Interval (Sec)",
    Step = 5,
    Value = {Min = 15, Max = 180, Default = 40},
    Min = 15, Max = 180, Default = 40,
    Callback = function(v) S.dungeonInterval = v end
})

tQD:Button({
    Title = "Enter Selected Dungeon Now (ลงดันเจี้ยนทันที)",
    Callback = function()
        task.spawn(function()
            doDungeonCycle(S.selectedDungeon, true)
        end)
    end
})

-- ==============================================================================
-- TAB 4: 🐾 PETS, CARDS & GOLD EGG
-- ==============================================================================
local tPets = Win:Tab({Title = "Pets & Cards", Icon = "paw-print"})

tPets:Section({Title = "🥚 Fizz Gold Egg Event (Priority #1)"})

tPets:Toggle({
    Title = "Auto Gold Egg (Priority #1 Warp & Grab)",
    Value = false,
    Callback = function(v)
        S.autoGoldEgg = v
        if not v then
            cleanupEggHover()
        end
        if v then
            if isGoldEggActive() then
                notify("Gold Egg", "Gold Egg event is LIVE! Warping immediately...")
                task.spawn(doGoldEggCycle)
            else
                local fNext = tonumber(BG:GetAttribute("FizzNextAt")) or 0
                local now = workspace:GetServerTimeNow()
                local sec = math.max(0, math.floor(fNext - now))
                notify("Gold Egg", string.format("Auto Gold Egg Active! Next event in %02d:%02d (will auto-warp).", math.floor(sec/60), sec%60))
            end
        end
    end
})

tPets:Button({
    Title = "Warp to Gold Egg Arena Now",
    Callback = function()
        local ok, msg = invoke(R.FizzAction, "go")
        if not ok then
            local root = getHRP()
            local center = toVector3(BG:GetAttribute("FizzCenter")) or Vector3.new(0, 4, -40)
            if root then root.CFrame = CFrame.new(center + Vector3.new(0, 2, 0)) end
        end
        notify("Gold Egg", "Warped to Fizz Arena!")
    end
})

goldEggStatusPara = tPets:Paragraph({
    Title = "Gold Egg Status",
    Desc  = getGoldEggStatusString()
})

tPets:Divider()
tPets:Section({Title = "Fizz Seed Exchange Shop (ร้านแลกไข่ซ่า)"})

tPets:Dropdown({
    Title = "Select Fizz Seed to Trade",
    Values = {
        "FizzLime (มะนาวซ่า - 3 ตั๋ว | +120 HP)",
        "FizzCherry (เชอร์รี่ซ่า - 3 ตั๋ว | +120 DEF)",
        "FizzEggplant (มะเขือไข่ซ่า - 5 ตั๋ว | +208 SPD)",
        "FizzPineapple (สับปะรดซ่า - 5 ตั๋ว | +208 CRIT)",
        "FizzDurian (ทุเรียนซ่า - 8 ตั๋ว | +272 ATK)"
    },
    Value = "FizzLime (มะนาวซ่า - 3 ตั๋ว | +120 HP)",
    Callback = function(sel)
        if type(sel) == "table" then sel = sel[1] end
        if sel then
            S.fizzTradeSeedId = sel:match("^(%w+)")
        end
    end
})

tPets:Toggle({
    Title = "Auto Trade When Tickets Sufficient",
    Value = false,
    Callback = function(v) S.autoFizzTrade = v end
})

tPets:Button({
    Title = "Trade 1 Seed Now",
    Callback = function()
        local sId = S.fizzTradeSeedId or "FizzLime"
        local ok, msg = invoke(R.FizzAction, "trade", { n = 1, id = sId })
        notify("Fizz Shop", ok and ("Traded 1x " .. sId .. "!") or ("Failed: " .. tostring(msg)))
    end
})

tPets:Divider()
tPets:Section({Title = "Card Gacha (Stop on Target Card)"})

tPets:Dropdown({
    Title = "Stop on Selected Cards (Multi)",
    Values = ALL_CARDS_OPTS,
    Value = {},
    Multi = true,
    Callback = function(sel)
        S.stopOnCards = {}
        for _, lbl in ipairs(parseMultiDropdown(sel)) do
            local cid = lbl:match("%(([%w_%-]+)%)$") or lbl
            S.stopOnCards[cid] = true
        end
    end
})

tPets:Toggle({
    Title = "Auto Pull Cards (10x - Auto Warp to Shop)",
    Value = false,
    Callback = function(v)
        S.autoCardPull = v
        if v and not isFarming and not isSelling then
            task.spawn(function() doCardPullCycle(false) end)
        end
    end
})

tPets:Toggle({
    Title = "Auto Buy Card Tickets (ซื้อตั๋วอัตโนมัติ)",
    Value = false,
    Callback = function(v) S.autoBuyCardTicket = v end
})

tPets:Button({
    Title = "Pull 10x Cards Now (Warp to Shop)",
    Callback = function()
        task.spawn(function()
            doCardPullCycle(true)
        end)
    end
})

tPets:Button({
    Title = "Buy 1x Card Ticket Now (Warp to Shop)",
    Callback = function()
        task.spawn(function()
            local root = getHRP()
            local prevCF = root and root.CFrame
            if root then
                root.CFrame = CFrame.new(POS_CARD_SHOP)
                task.wait(0.35)
            end
            local ok, res = invoke(R.CardShopAction, "buyticket")
            notify("Card Ticket", (type(res) == "string" and res) or (ok and "Bought 1x card ticket!" or "Failed to buy ticket"))
            task.wait(0.3)
            if S.autoFarm then
                local center = getMyPlotCenter()
                if center and root then root.CFrame = CFrame.new(center) end
            elseif prevCF and root then
                root.CFrame = prevCF
            end
        end)
    end
})

tPets:Divider()
tPets:Section({Title = "Auto Buy Eggs (ซื้อไข่อัตโนมัติ)"})

local EGG_BUY_OPTIONS = {
    "BasicEgg (Tier 1 - Farm, 300c)",
    "CrystalEgg (Tier 2 - Crystal, 1,500c)",
    "MagicEgg (Tier 3 - Magic, 5,000c)",
    "IceEgg (Tier 4 - Ice, 120 Ice)",
    "InfernoEgg (Tier 5 - Inferno, 30,000c)",
    "MiracleEgg (Tier 6 - Miracle, 250,000c)"
}

tPets:Dropdown({
    Title = "Select Eggs to Auto-Buy (เลือกไข่ที่ต้องการซื้อ)",
    Values = EGG_BUY_OPTIONS,
    Value = {"BasicEgg (Tier 1 - Farm, 300c)"},
    Multi = true,
    Callback = function(sel)
        S.selectedEggsToBuy = {}
        for _, item in ipairs(parseMultiDropdown(sel)) do
            local clean = item:match("^([%w_]+)") or item
            S.selectedEggsToBuy[clean] = true
            S.buyEggType = clean
            S.hatchEggType = clean
        end
    end
})

tPets:Slider({
    Title = "Buy Quantity per Batch (จำนวนซื้อต่อรอบ)",
    Step = 1,
    Value = {Min = 1, Max = 10, Default = 1},
    Min = 1, Max = 10, Default = 1,
    Callback = function(v)
        S.buyEggAmount = v
        S.hatchEggAmount = v
    end
})

tPets:Toggle({
    Title = "Auto Buy Selected Eggs (ซื้อไข่อัตโนมัติเมื่อเงินถึง)",
    Value = false,
    Callback = function(v)
        S.autoBuyEgg = v
        S.autoHatchEgg = v
        if v then task.spawn(function() doBuyEggCycle(false) end) end
    end
})

tPets:Button({
    Title = "Buy Selected Eggs Now (1x) (ซื้อไข่ทันที 1 ฟอง)",
    Callback = function()
        task.spawn(function()
            local oldAmt = S.buyEggAmount
            S.buyEggAmount = 1
            doBuyEggCycle(true)
            S.buyEggAmount = oldAmt
            notify("Hatchery", "Bought selected eggs!")
        end)
    end
})

tPets:Button({
    Title = "Buy Selected Eggs Now (5x) (ซื้อไข่ทันที 5 ฟอง)",
    Callback = function()
        task.spawn(function()
            local oldAmt = S.buyEggAmount
            S.buyEggAmount = 5
            doBuyEggCycle(true)
            S.buyEggAmount = oldAmt
            notify("Hatchery", "Bought selected eggs 5x!")
        end)
    end
})

tPets:Divider()
tPets:Section({Title = "Egg Incubators & Auto Hatch (ตู้ฟักไข่ & ฟักตัว)"})

local EGG_PLACE_OPTIONS = {
    "BasicEgg (Tier 1 - Farm)",
    "CrystalEgg (Tier 2 - Crystal)",
    "MagicEgg (Tier 3 - Magic)",
    "IceEgg (Tier 4 - Ice)",
    "InfernoEgg (Tier 5 - Inferno)",
    "MiracleEgg (Tier 6 - Miracle)"
}

tPets:Dropdown({
    Title = "Select Eggs to Auto-Place in Incubator",
    Values = EGG_PLACE_OPTIONS,
    Value = {"BasicEgg (Tier 1 - Farm)", "CrystalEgg (Tier 2 - Crystal)"},
    Multi = true,
    Callback = function(sel)
        S.selectedEggsToPlace = {}
        for _, item in ipairs(parseMultiDropdown(sel)) do
            local clean = item:match("^([%w_]+)") or item
            S.selectedEggsToPlace[clean] = true
        end
    end
})

tPets:Toggle({
    Title = "Auto Place Eggs in Incubator (นำไข่ใส่ตู้ฟักอัตโนมัติ)",
    Value = false,
    Callback = function(v)
        S.autoFillIncubator = v
        if v then task.spawn(function() doFillIncubatorCycle(false) end) end
    end
})

tPets:Toggle({
    Title = "Auto Collect Hatched Pets (Open All - ฟักและรับสัตว์เลี้ยง)",
    Value = false,
    Callback = function(v)
        S.autoOpenAllEggs = v
        if v then task.spawn(function() invoke(R.EggAction, "openAll") end) end
    end
})

tPets:Button({
    Title = "Place Selected Eggs in Incubator Now (ใส่ไข่ลงตู้ฟักทันที)",
    Callback = function()
        task.spawn(function()
            doFillIncubatorCycle(true)
            notify("Incubator", "Placed selected eggs into incubator!")
        end)
    end
})

tPets:Button({
    Title = "Open All Ready Pets Now (เปิดรับสัตว์เลี้ยงที่ฟักเสร็จทันที)",
    Callback = function()
        invoke(R.EggAction, "openAll")
        notify("Incubator", "Claimed all hatched pets!")
    end
})

tPets:Divider()
tPets:Section({Title = "Team & Animal Optimization (จัดสัตว์เทพสุดทุกช่อง)"})

tPets:Toggle({
    Title = "Auto Maintain Best Animals (All Slots - Pen + Guard + Team)",
    Value = false,
    Callback = function(v)
        S.autoEquipBestAll = v
        if v then task.spawn(function() doEquipBestAll(true) end) end
    end
})

tPets:Button({
    Title = "Warp to Pen & Equip Best All Slots Now",
    Callback = function() task.spawn(function() doEquipBestAll(true) end) end
})

tPets:Button({
    Title = "Equip Best Team Only (ทีมออกล่า)",
    Callback = function()
        local ok, msg = invoke(R.AnimalAction, "best", "team")
        notify("Pets", ok and (type(msg) == "string" and msg or "Equipped Best Team!") or "Failed")
    end
})

tPets:Button({
    Title = "Equip Best Guard Only (สัตว์เดินเล่นเฝ้าฟาร์ม)",
    Callback = function()
        local ok, msg = invoke(R.AnimalAction, "best", "guard")
        notify("Pets", ok and (type(msg) == "string" and msg or "Equipped Best Guard!") or "Failed")
    end
})

tPets:Button({
    Title = "Equip Best Pen Money-Makers Only (สัตว์คอกผลิตเงิน)",
    Callback = function()
        local ok, msg = invoke(R.FarmAction, "penBest")
        notify("Pets", ok and (type(msg) == "string" and msg or "Placed Best Pen Beasts!") or "Failed")
    end
})

tPets:Divider()
tPets:Section({Title = "Alchemy Tower (หอกลั่นโอสถกลายพันธุ์)"})

tPets:Toggle({
    Title = "Auto Refine Mutated Produce into Essence",
    Value = false,
    Callback = function(v) S.autoRefineProduce = v end
})

tPets:Button({
    Title = "Refine All Produce to Essence Now",
    Callback = function() task.spawn(function() doRefineAllProduce(true) end) end
})

-- ==============================================================================
-- TAB 5: 📡 DISCORD LOGS (DEDICATED TAB)
-- ==============================================================================
local tWebhook = Win:Tab({Title = "Discord Logs", Icon = "bell"})

tWebhook:Section({Title = "Webhook Settings"})

tWebhook:Input({
    Title       = "Discord Webhook URL",
    Value       = S.webhookUrl,
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback    = function(val) S.webhookUrl = val end
})

tWebhook:Toggle({
    Title = "Auto Send Activity Log",
    Value = false,
    Callback = function(v) S.webhookAutoLog = v end
})

tWebhook:Slider({
    Title = "Send Interval (Seconds)",
    Step = 10,
    Value = {Min = 30, Max = 600, Default = 120},
    Min = 30, Max = 600, Default = 120,
    Callback = function(v) S.webhookInterval = v end
})

tWebhook:Button({
    Title = "Test Webhook Connection",
    Callback = function()
        if not S.webhookUrl or S.webhookUrl == "" then
            return notify("Webhook", "Please input a URL first!")
        end
        task.spawn(function()
            local ok, msg = sendDiscordWebhook("Beast Garden Hub — Webhook Test", "Connected from **" .. plr.Name .. "** on **" .. get_executor_name() .. "**!")
            notify("Webhook", ok and "Sent to Discord!" or ("Failed: " .. tostring(msg)))
        end)
    end
})

tWebhook:Button({
    Title = "Send Log Snapshot Now",
    Callback = function()
        task.spawn(function()
            local ok = sendDiscordWebhook("Manual Activity Snapshot")
            notify("Webhook", ok and "Snapshot posted to Discord!" or "Failed")
        end)
    end
})

tWebhook:Divider()
tWebhook:Section({Title = "Live Monospace Activity Log"})

logCodeElement = tWebhook:Code({
    Title = "Status Box",
    Code  = getDecoratedLogString()
})

-- ==============================================================================
-- TAB 6: ⚙️ SETTINGS & MISC
-- ==============================================================================
local tSet = Win:Tab({Title = "Settings & Misc", Icon = "settings"})

tSet:Section({Title = "Multi-Function Priority Order"})
tSet:Paragraph({
    Title = "Concurrent Multi-Function Priority Hierarchy",
    Desc  = "1. 🥚 Gold Egg Event (Absolute Priority #1: Warps & Grabs/Chases Egg immediately)\n2. 👑 Boss Hunt (Warps to spawned Boss with TeamSkill 3x DMG)\n3. 📜 Quests (Periodic fast Town Warp & Claim/Accept, ~1.5s)\n4. 🌾 Crop Farm (Timed Harvest & Replant sweep, then yields)\n5. ⚔️ Mob Farm (Continuous Grinding when crops are growing and no boss/egg)\n✨ You can enable all functions simultaneously without conflicts!"
})

tSet:Divider()
tSet:Section({Title = "Performance & Anti-AFK"})

tSet:Toggle({
    Title = "Anti-AFK Protection",
    Value = false,
    Callback = function(v) S.antiAFK = v end
})

tSet:Toggle({
    Title = "Low Graphics (Remove Textures)",
    Value = false,
    Callback = function(v) applyLowGraphics(v) end
})

tSet:Toggle({
    Title = "Pause 3D Rendering (0% GPU AFK)",
    Value = false,
    Callback = function(v) set3DRendering(not v) end
})

tSet:Slider({
    Title = "FPS Cap Limit",
    Step = 5,
    Value = {Min = 15, Max = 240, Default = 60},
    Min = 15, Max = 240, Default = 60,
    Callback = function(v)
        S.fpsCap = v
        safe_setfpscap(v)
    end
})

tSet:Paragraph({
    Title = "Memory Diagnostics",
    Desc  = "Luau Client Memory: " .. tostring(math.floor(gcinfo())) .. " KB"
})

tSet:Divider()
tSet:Section({Title = "Quick Town Teleports"})

for _, w in ipairs(WARPS) do
    local wc = w
    tSet:Button({
        Title = "Warp to " .. wc.label,
        Callback = function()
            invoke(R.QuickWarp, wc.id)
            logActivity("Warped to " .. wc.label, wc.label)
        end
    })
end

tSet:Button({
    Title = "Warp to Quest NPC",
    Callback = function()
        local root = getHRP()
        if root then root.CFrame = CFrame.new(POS_QUEST_NPC) end
    end
})

tSet:Divider()
tSet:Section({Title = "Configuration (JSON)"})

tSet:Input({
    Title       = "Config File Name",
    Value       = S.configName or "default",
    Placeholder = "e.g. overnight_farm",
    Callback    = function(val) S.configName = val end
})

tSet:Button({
    Title = "Save Current Config",
    Callback = function() saveConfig(S.configName) end
})

local cfgDropdown
local cfgList = getAllConfigs()
cfgDropdown = tSet:Dropdown({
    Title = "Select Saved Config",
    Values = cfgList,
    Value = cfgList[1] or "default",
    Callback = function(sel)
        if type(sel) == "table" then sel = sel[1] end
        if sel then S.configName = sel end
    end
})

tSet:Button({
    Title = "Load Selected Config",
    Callback = function() loadConfig(S.configName) end
})

tSet:Button({
    Title = "Delete Selected Config",
    Callback = function()
        deleteConfig(S.configName)
        local updated = getAllConfigs()
        if cfgDropdown and cfgDropdown.SetValues then cfgDropdown:SetValues(updated) end
    end
})

tSet:Toggle({
    Title = "Auto-Load on Startup",
    Value = false,
    Callback = function(v)
        S.autoLoadConfig = v
        if v and writefile then
            pcall(writefile, CONFIG_FOLDER .. "/autoload.json", json_encode({ autoload = S.configName }))
            notify("Config", "Enabled auto-load for: " .. S.configName)
        elseif delfile and isfile and isfile(CONFIG_FOLDER .. "/autoload.json") then
            pcall(delfile, CONFIG_FOLDER .. "/autoload.json")
            notify("Config", "Disabled auto-load on startup.")
        end
    end
})

tSet:Divider()
tSet:Section({Title = "Hub Controls & Credits"})

local currentToggleKey = Enum.KeyCode.RightControl

local function restoreHubWindow()
    local hui = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    local wGui = hui:FindFirstChild("WindUI") or plr.PlayerGui:FindFirstChild("WindUI")
    if not wGui then return end

    local winFolder = wGui:FindFirstChild("Window")
    local frames = winFolder and winFolder:GetChildren() or {}
    local f1 = frames[1] -- Main window frame
    local f2 = frames[2] -- Minimized bar frame
    local f1_scale = f1 and f1:FindFirstChildWhichIsA("UIScale")
    local f2_scale = f2 and f2:FindFirstChildWhichIsA("UIScale")

    wGui.Enabled = true
    if f1 then
        f1.Visible = true
        if f1_scale then f1_scale.Scale = 1 end
    end
    if f2 then
        f2.Visible = false
        if f2_scale then f2_scale.Scale = 0 end
    end
    pcall(function()
        if Win and Win.Open then Win:Open() end
    end)
end

local function toggleHubWindow()
    local hui = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    local wGui = hui:FindFirstChild("WindUI") or plr.PlayerGui:FindFirstChild("WindUI")
    if not wGui then return end

    local winFolder = wGui:FindFirstChild("Window")
    local frames = winFolder and winFolder:GetChildren() or {}
    local f1 = frames[1]
    local f2 = frames[2]
    local f1_scale = f1 and f1:FindFirstChildWhichIsA("UIScale")

    local isFullyOpen = wGui.Enabled and f1 and f1.Visible and (not f1_scale or f1_scale.Scale > 0.5) and (not f2 or not f2.Visible)

    if isFullyOpen then
        wGui.Enabled = false
    else
        restoreHubWindow()
    end
end

tSet:Keybind({
    Title = "Toggle Hub UI Keybind",
    Value = "RightControl",
    Callback = function(key)
        if typeof(key) == "EnumItem" then
            currentToggleKey = key
        elseif typeof(key) == "string" and Enum.KeyCode[key] then
            currentToggleKey = Enum.KeyCode[key]
        end
    end
})

tSet:Button({
    Title = "👁️ Hide Hub Window (Press RightControl / Icon to Reopen)",
    Callback = function()
        toggleHubWindow()
    end
})

tSet:Button({
    Title = "🔄 Sync with Live Game Config (Auto-Update Data)",
    Callback = function()
        pcall(syncWithGameConfig)
        notify("Game Config", "Successfully synced all crops, zones, bosses, and eggs live from game memory!")
    end
})

tSet:Button({
    Title = "Server Hop Now",
    Callback = function() serverHop() end
})

tSet:Button({
    Title = "Rejoin Server",
    Callback = function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, plr)
    end
})

tSet:Button({
    Title = "Destroy Hub UI",
    Callback = function()
        getgenv().BG_Running = false
        enableCombatHover(false)
        if getgenv().BG_Connections then
            for _, c in ipairs(getgenv().BG_Connections) do pcall(function() c:Disconnect() end) end
        end
        set3DRendering(true)
        pcall(function()
            local hui = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")
            local tBtn = hui:FindFirstChild("BG_FloatingToggle") or plr.PlayerGui:FindFirstChild("BG_FloatingToggle")
            if tBtn then tBtn:Destroy() end
        end)
        WindUI:Destroy()
    end
})

tSet:Paragraph({
    Title = "Beast Garden Hub",
    Desc  = "Author: made by ud0 Custom\nDiscord: discord.gg/axel hub\nSystem: " .. get_executor_name()
})

-- ==============================================================================
-- FLOATING TOGGLE BUTTON ("Icon เผื่อกดกลับมา") + DRAG & HOTKEY CONTROLLER
-- ==============================================================================
task.spawn(function()
    local hui = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    local wGui = hui:FindFirstChild("WindUI") or plr.PlayerGui:FindFirstChild("WindUI")

    -- 1. Create Floating Toggle Icon
    local floatGui = Instance.new("ScreenGui")
    floatGui.Name = "BG_FloatingToggle"
    floatGui.ResetOnSpawn = false
    floatGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local floatBtn = Instance.new("ImageButton")
    floatBtn.Name = "ToggleBtn"
    floatBtn.Size = UDim2.fromOffset(48, 48)
    floatBtn.Position = UDim2.new(0, 18, 0.4, 0)
    floatBtn.BackgroundColor3 = Color3.fromHex("#0B0B0D")
    floatBtn.Image = "rbxassetid://86949082023913"
    floatBtn.AutoButtonColor = true
    floatBtn.Parent = floatGui

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Color3.fromHex("#FFD700")
    stroke.Parent = floatBtn

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = floatBtn

    -- Draggable Floating Button logic
    local btnDragging, btnDragStart, btnStartPos = false, nil, nil
    trackConnection(floatBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            btnDragging = true
            btnDragStart = input.Position
            btnStartPos = floatBtn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    btnDragging = false
                end
            end)
        end
    end))

    trackConnection(UserInputService.InputChanged:Connect(function(input)
        if btnDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - btnDragStart
            floatBtn.Position = UDim2.new(
                btnStartPos.X.Scale,
                btnStartPos.X.Offset + delta.X,
                btnStartPos.Y.Scale,
                btnStartPos.Y.Offset + delta.Y
            )
        end
    end))

    -- Toggle or Unminimize Window on Floating Button click
    floatBtn.MouseButton1Click:Connect(function()
        toggleHubWindow()
    end)

    pcall(function()
        floatGui.Parent = hui
    end)
    if not floatGui.Parent then
        floatGui.Parent = plr:WaitForChild("PlayerGui")
    end

    -- 2. Hook Minimized Bar (f2) so clicking it restores the main window instantly
    if wGui then
        local winFolder = wGui:FindFirstChild("Window")
        local frames = winFolder and winFolder:GetChildren() or {}
        local f1 = frames[1]
        local f2 = frames[2]

        if f2 then
            local miniBtn = f2:FindFirstChildWhichIsA("TextButton", true)
            if miniBtn then
                miniBtn.Size = UDim2.new(1, 0, 1, 0)
                trackConnection(miniBtn.MouseButton1Click:Connect(restoreHubWindow))
            end
            trackConnection(f2.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    restoreHubWindow()
                end
            end))
        end

        -- Enhance Window Dragging for Main Window Frame
        if f1 then
            local winDragging, winDragStart, winStartPos = false, nil, nil
            trackConnection(f1.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    local relY = input.Position.Y - f1.AbsolutePosition.Y
                    if relY <= 65 then
                        winDragging = true
                        winDragStart = input.Position
                        winStartPos = f1.Position
                        input.Changed:Connect(function()
                            if input.UserInputState == Enum.UserInputState.End then
                                winDragging = false
                            end
                        end)
                    end
                end
            end))

            trackConnection(UserInputService.InputChanged:Connect(function(input)
                if winDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    local delta = input.Position - winDragStart
                    f1.Position = UDim2.new(
                        winStartPos.X.Scale,
                        winStartPos.X.Offset + delta.X,
                        winStartPos.Y.Scale,
                        winStartPos.Y.Offset + delta.Y
                    )
                end
            end))
        end
    end

    -- 3. Global Keybind Listener for UI Toggle
    trackConnection(UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == currentToggleKey or input.KeyCode == Enum.KeyCode.RightControl or input.KeyCode == Enum.KeyCode.RightAlt or input.KeyCode == Enum.KeyCode.Insert then
            toggleHubWindow()
        end
    end))
end)

-- ===== INITIALIZATION DONE =====
task.wait(0.3)
logActivity("Hub Ready • Pro Edition", "Farm Plot")
notify("Beast Garden Hub", "Loaded successfully! Pro Edition.")
