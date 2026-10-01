--[[
═══════════════════════════════════════════════════════════════════════════════
   AXEL HUB · ANIME BREAKER — AXELUI PREMIUM THEME
   Author: cook45 x clack
   UI Framework: AxelUI (bundled, with numbered step sliders)
   Core Architecture: Sticky Target Locking Engine + Event Hierarchy
   Target Place: Anime Breaker (109928390521457)
═══════════════════════════════════════════════════════════════════════════════
--]]

if _G.AnimeBreaker_HeartbeatConnection then
    pcall(function() _G.AnimeBreaker_HeartbeatConnection:Disconnect() end)
    _G.AnimeBreaker_HeartbeatConnection = nil
end
for _, key in ipairs({ "AnimeBreaker_AntiAFKConnection", "AnimeBreaker_RejoinConnection" }) do
    if _G[key] then pcall(function() _G[key]:Disconnect() end); _G[key] = nil end
end
if _G.AnimeBreaker_NoClipConn then
    pcall(function() _G.AnimeBreaker_NoClipConn:Disconnect() end)
    _G.AnimeBreaker_NoClipConn = nil
end
pcall(function()
    local CoreGui = game:GetService("CoreGui")
    local PlayerGui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    local function purge(p)
        if not p then return end
        for _, c in ipairs(p:GetChildren()) do
            if c.Name:find("WindUI") or c.Name:find("AngelHub") or c.Name:find("AnimeBreaker") then
                pcall(function() c:Destroy() end)
            end
        end
    end
    purge(CoreGui)
    if CoreGui:FindFirstChild("RobloxGui") then
        purge(CoreGui.RobloxGui)
    end
    purge(PlayerGui)
end)

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local SoundService      = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")
local lp                = Players.LocalPlayer

-- Framework Detection
local Library = nil
pcall(function()
    Library = require(ReplicatedStorage:WaitForChild("Framework"):WaitForChild("Library"))
end)
if not Library and type(filtergc) == "function" then
    Library = filtergc("table", { Keys = { "Remote", "PlayerData" } }, true)
end

-- ══════════════════════════════════════════════════════════
-- CONSTANTS & LOOKUPS
-- ══════════════════════════════════════════════════════════
local MAP_LIST = {"Lobby", "DBZ", "AOT", "Naruto", "Nanatsu", "SoloLeveling", "OnePiece"}

local ALL_RARITY_NAMES = {
    "Common", "Rare", "Epic", "Legendary", "Mythical", "Secret", "Broken", "Portal", "Loot Box", "Exclusive", "RGB"
}

local RARITY_LEVEL = {
    Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythical = 5, Secret = 6, Broken = 7,
    Portal = 8, ["Loot Box"] = 9, Exclusive = 10, RGB = 11
}

local TT_POTIONS = {
    "EnergyPotion1", "DamagePotion1", "GoldPotion1", "LuckPotion1", "DropPotion1",
    "EnergyPotion2", "DamagePotion2", "GoldPotion2", "LuckPotion2", "DropPotion2"
}

local PIRATE_JUICES = {
    "EnergyJuice1", "DamageJuice1", "GoldJuice1", "DropJuice1", "LuckJuice1"
}

local TT_TARGETS = {
    { Key = "Energy",  Name = "Relentless (Energy)" },
    { Key = "Damage",  Name = "Breaker (Damage)" },
    { Key = "Gold",    Name = "Scavenger (Gold)" },
    { Key = "AtkSPD",  Name = "Overdrive (AtkSPD)" },
}

local CRAFT_ITEMS = {
    Ring    = {"EnergyRing1","EnergyRing2","EnergyRing3","EnergyRing4","EnergyRing5","EnergyRing6"},
    Collar  = {"GoldCollar1","GoldCollar2","GoldCollar3","GoldCollar4","GoldCollar5","GoldCollar6"},
    Earring = {"DamageEarring1","DamageEarring2","DamageEarring3","DamageEarring4","DamageEarring5","DamageEarring6"}
}

local PROMO_CODES = {
    "RELEASE", "UPDATE1", "UPDATE2", "CRAFT", "LIKES10K", "LIKES20K", "SORRYFORSHUTDOWN"
}

local ALL_ENEMY_OPTIONS = {
    "All",
    "Master Inventor [ DBZ ]", "Namekian Healer [ DBZ ]", "Namekian Warrior [ DBZ ]", "Strongest Human [ DBZ ]",
    "Hidden Potential [ DBZ ]", "Saiyan Prince [ DBZ ]", "Destructive Fist [ DBZ ]", "Shadow Tactician [ DBZ ]",
    "Ace Captain [ AOT ]", "Ace Scout [ AOT ]", "Buzzcut Scout [ AOT ]", "Scout Potato [ AOT ]", 
    "Scout Scientist [ AOT ]", "Tactical Scout [ AOT ]",
    "Rogue Ninja [ Naruto ]", "Leaf Genin [ Naruto ]", "Sand Shinobi [ Naruto ]", "Nine Tails Clone [ Naruto ]",
    "Holy Knight [ Nanatsu ]", "Demon Soldier [ Nanatsu ]", "Red Demon [ Nanatsu ]", "Gray Demon [ Nanatsu ]",
    "Shadow Hunter [ SoloLeveling ]", "D-Rank Beast [ SoloLeveling ]", "C-Rank Beast [ SoloLeveling ]", "Igris Shadow [ SoloLeveling ]",
    "Marine Recruit [ OnePiece ]", "Marine Captain [ OnePiece ]", "Pacifista [ OnePiece ]", "Admiral Candidate [ OnePiece ]"
}

-- ══════════════════════════════════════════════════════════
-- CONFIGURATION
-- ══════════════════════════════════════════════════════════
local CFG = {
    -- Combat
    AutoClick           = false,
    ClickDelay          = 0.05,
    AutoTarget          = false,
    TargetMonsterFilter = "All",
    AutoFarm            = false,
    AutoCastSkill       = false,

    -- Smart Area Progression & Wall Breaking
    AutoBreakWall       = false,
    WallBreakMode       = "Timed",
    WallAttackDuration  = 30,
    WallFarmCooldown    = 180,
    AutoGoNewArea       = false,

    -- Auto Quests
    AutoQuests          = false,

    -- Priority 1: Time Trial Dungeon (The Hallway)
    AutoTimeTrialDungeon  = false,
    TTDifficulty          = {"Easy"},
    TTDifficulties        = {"Easy"},
    TTCustomExitStage     = false,
    TTExitStage           = 25,
    AutoUpgradeTT         = false,
    TTUpgradePriority     = "Upgrade All",
    AutoBuyTTShop         = false,
    TTShopSelection       = {},
    AutoBuyPirateShop     = false,
    PirateShopSelection   = {
        EnergyJuice1 = true, DamageJuice1 = true, GoldJuice1 = true, DropJuice1 = true, LuckJuice1 = true
    },

    -- Priority 2: Auto Raid (Safe Entry + Exit Room + No Teleport Bug)
    AutoRaid              = false,
    RaidTargetMap         = "DBZ",
    AutoFarmTicketIfNone  = false,
    AutoReturnHome        = false,
    RaidCustomExitRoom    = false,
    RaidExitRoom          = 5,

    -- Priority 3: Auto Join Portal (According to Tier)
    AutoPortal            = false,
    PortalSelectedTier    = "All",

    -- Auto Summon (Banners)
    AutoSummon            = false,
    SummonEgg             = "DBZ",
    SummonType            = "Pet",

    -- Auto Race Spin
    AutoRaceSpin          = false,
    AutoUnlockRace        = false,
    RaceStopRarity        = "Mythical",

    -- Auto Weapon
    AutoWeaponSummon      = false,
    AutoUnlockWeapon      = false,
    AutoWeaponPassive     = false,

    -- Auto Hero Passive
    AutoHeroPassive       = false,
    AutoUnlockHeroPassive = false,

    -- Balanced System Unlocker (Round-Robin)
    BalancedUnlocker      = false,

    -- Auto Equip Best (Global Boost + Individual + Title + Multi-systems)
    AutoEquipBest         = false,
    AutoEquipBoost        = "Energy",
    EquipBestCategories   = {"Weapon", "Warrior", "Avatar", "Accessory", "Mount", "Jewel", "Wing", "DevilFruit", "Crewmate", "Amulet"},
    EquipBestAvatar       = false,
    EquipBestAccessory    = false,
    EquipBestWeapon       = false,
    EquipBestWarrior      = false,
    EquipBestMount        = false,
    EquipBestJewel        = false,
    EquipBestWing         = false,
    EquipBestTitle        = false,
    TTSelectedPotionNames = {},
    TTSelectedUpgradeNames = {"Breaker (Damage +5%)", "Relentless (Energy +5%)", "Scavenger (Gold +5%)", "Overdrive (AtkSPD +2.5%)"},
    TTShopBuyAmountStr    = "1x",
    TTShopBuyAmount       = 1,
    PirateSelectedJuiceNames = {"Energy Juice I (1000)", "Damage Juice I (1000)", "Gold Juice I (1000)", "Drop Juice I (1000)", "Luck Juice I (1000)"},
    PirateShopBuyAmountStr = "1x",
    PirateShopBuyAmount   = 1,
    DeleteSelectedRarities = {"Common", "Rare", "Epic"},
    SellSelectedRarities  = {"Common", "Rare"},
    DeleteTargetCategories = {"Pets", "Weapons", "Wings", "Avatars", "Accessories", "Warriors", "Mounts", "Jewels"},

    -- Auto Upgrades & Progression
    AutoRankUp            = false,
    AutoUpgradeWarrior    = false,
    AutoUnlockWarrior     = false,
    WarriorUpgradePriority= "All (Balanced)",
    AutoOfflineUpgrades   = false,
    AutoUnlockOffline     = false,
    AutoUpgrade           = false,
    BalanceGlobalUpgrades = true,
    SelectedGlobalUpgrades= {"Warrior Upgrades", "Offline Upgrades", "Time Trial Upgrades", "Portal Upgrades", "Class Tree"},

    -- Merge & Crafting
    AutoMergeAll          = false,
    AutoCraft             = false,
    CraftMaxTier          = 6,
    CraftSelection        = { Ring = false, Collar = false, Earring = false },

    -- Auto Claim
    AutoClaimAll          = false,
    AutoClaimLikeRewards  = false,

    -- Auto Delete / Auto Sell (Thresholds)
    AutoDeletePets        = false,
    DeletePetsBelow       = "Rare",
    AutoDeleteWeapons     = false,
    DeleteWeaponsBelow    = "Rare",
    AutoDeleteWings       = false,
    DeleteWingsBelow      = "Rare",
    AutoDeleteAvatars     = false,
    DeleteAvatarsBelow    = "Rare",
    AutoDeleteAccessories = false,
    DeleteAccessoriesBelow= "Rare",
    AutoDeleteWarriors    = false,
    DeleteWarriorsBelow   = "Rare",
    AutoDeleteMounts      = false,
    DeleteMountsBelow     = "Rare",
    AutoDeleteJewels      = false,
    DeleteJewelsBelow     = "Rare",

    -- Player Movement & Hacks (Dash Speed & Hack)
    DashHack              = false,
    DashSpeed             = 150,
    JumpPower             = 100,
    InfHealth             = false,
    NoClip                = false,

    -- Anti-AFK & Rejoin
    AutoLoadConfig        = false,
    AntiAFK               = false,
    AutoRejoin            = false,
}

local RarityToggles = {
    Pet       = { Common = false, Rare = false, Epic = false, Legendary = false, Mythical = false, Secret = false, Broken = false },
    Weapon    = { Common = false, Rare = false, Epic = false, Legendary = false, Mythical = false, Secret = false, Broken = false },
    Wing      = { Common = false, Rare = false, Epic = false, Legendary = false, Mythical = false, Secret = false, Broken = false },
    Avatar    = { Common = false, Rare = false, Epic = false, Legendary = false, Mythical = false, Secret = false, Broken = false },
    Accessory = { Common = false, Rare = false, Epic = false, Legendary = false, Mythical = false, Secret = false, Broken = false },
    Warrior   = { Common = false, Rare = false, Epic = false, Legendary = false, Mythical = false, Secret = false, Broken = false },
    Mount     = { Common = false, Rare = false, Epic = false, Legendary = false, Mythical = false, Secret = false, Broken = false },
    Jewel     = { Common = false, Rare = false, Epic = false, Legendary = false, Mythical = false, Secret = false, Broken = false },
}

-- ══════════════════════════════════════════════════════════
-- SYSTEM TIMERS & STICKY TARGET LOCKING STATE
-- ══════════════════════════════════════════════════════════
local lastClick       = 0
local lastClaim       = 0
local lastLikeClaim   = 0
local lastUpgrade     = 0
local lastMerge       = 0
local lastEquipBest   = 0
local lastSell        = 0
local lastRankUp      = 0
local lastRaceSpin    = 0
local lastWarriorUp   = 0
local lastWeaponSpin  = 0
local lastHeroPassive = 0
local lastOfflineUp   = 0
local lastUnlockStep  = 0
local lastQuestTick   = 0
local lastPortalTick  = 0
local lastTTUpgrade   = 0
local lastTTShopBuy   = 0
local lastPirateShopBuy = 0

local raidEnteringTime = 0
local lastRaidStartAttempt = 0

local wallAttackStartTime = 0
local wallCooldownStartTime = 0
local isAttackingWall = false

-- STICKY TARGET LOCK: Once an enemy is chosen, stay locked until it is DEAD!
local currentLockedTargetUID = nil

local unlockSystemQueue = {
    { Id = "Gacha_Race", Name = "Race", CostKey = "Gold", CostAmt = 10000 },
    { Id = "Upgrade_Warrior Upgrades", Name = "Warrior Upgrades", CostKey = "Gold", CostAmt = 15000 },
    { Id = "Upgrade_Offline Upgrades", Name = "Offline Upgrades", CostKey = "Gold", CostAmt = 45000 },
    { Id = "Gacha_Weapon_T1", Name = "Weapon T1", CostKey = "Gold", CostAmt = 10935000 },
    { Id = "Gacha_Hero Passive", Name = "Hero Passive", CostKey = "Gold", CostAmt = 87480000 },
}
local unlockQueueIndex = 1

local noClipConn = nil

local function getChar() return lp.Character end
local function getRoot()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- Rarity lookup
local _GachaData = nil
local function getRarityOrder(id)
    if not _GachaData then
        pcall(function()
            _GachaData = require(ReplicatedStorage.Framework.Modules.Data.GachaData)
        end)
    end
    if not _GachaData then return 1 end
    for _, pools in pairs(_GachaData) do
        if type(pools) == "table" then
            for rarity, items in pairs(pools) do
                if type(items) == "table" then
                    for _, item in pairs(items) do
                        if item == id or (type(item) == "table" and item.Id == id) then
                            return RARITY_LEVEL[rarity] or 1
                        end
                    end
                end
            end
        end
    end
    return 1
end

local function isItemInList(list, item)
    if type(list) ~= "table" then return false end
    for k, v in pairs(list) do
        if v == item or (k == item and v == true) then
            return true
        end
    end
    return false
end

local function getCurrentMap()
    if Library and Library.PlayerData and Library.PlayerData.CurrentMap then
        return Library.PlayerData.CurrentMap
    end
    local attr = lp:GetAttribute("Map")
    if attr and attr ~= "" then return attr end
    return "DBZ"
end

local lastNewAreaTeleport = 0

local function getHighestUnlockedMap()
    local pd = Library and Library.PlayerData
    local unlocked = pd and (pd.UnlockedMap or pd.Maps) or {}
    local highest = "DBZ"
    local highestIdx = 2
    for idx, mapKey in ipairs(MAP_LIST) do
        if unlocked[mapKey] == true and idx >= highestIdx then
            highest = mapKey
            highestIdx = idx
        end
    end
    return highest
end

local function isNextMapUnlocked(curMap)
    local curIdx = table.find(MAP_LIST, curMap)
    if not curIdx or curIdx >= #MAP_LIST then return false end
    local nextMap = MAP_LIST[curIdx + 1]
    local pd = Library and Library.PlayerData
    local unlocked = pd and (pd.UnlockedMap or pd.Maps) or {}
    return unlocked[nextMap] == true
end

-- Gamemode Detectors
-- ROBUST EVENT & GAMEMODE DETECTION (InMode Attribute + Folder + Hierarchy)
local function getActiveGamemode()
    local mode = lp:GetAttribute("Mode")
    local inMode = lp:GetAttribute("InMode")
    if inMode and inMode ~= "" then
        return mode or "Gamemode", inMode
    end

    local gm = workspace:FindFirstChild("_GAMEMODE")
    if gm then
        for _, child in ipairs(gm:GetChildren()) do
            if child.Name == "Raid" or child.Name:find("Raid") then
                return "Raid", child.Name
            elseif child.Name == "Time Trial" or child.Name:find("Time") or child.Name:find("Trial") then
                return "Time Trial", child.Name
            elseif child.Name == "Portal" or child.Name:find("Portal") then
                return "Portal", child.Name
            end
        end
    end

    local char = getChar()
    if char then
        if char:GetAttribute("InRaid") or char:GetAttribute("Raid") then return "Raid", "Raid" end
        if char:GetAttribute("InTimeTrial") or char:GetAttribute("TimeTrial") then return "Time Trial", "Time Trial" end
        if char:GetAttribute("InPortal") or char:GetAttribute("Portal") then return "Portal", "Portal" end
    end
    return nil, nil
end

local getRaidStatus

local function isPlayerInRaid()
    local status, inMode = getRaidStatus()
    if status == "Running" or status == "Opened" then
        return true, inMode
    end
    return false, nil
end

local function isPlayerInTimeTrial()
    local mode, inMode = getActiveGamemode()
    if mode == "Time Trial" or (inMode and (inMode:lower():find("time") or inMode:lower():find("trial"))) then
        local gm = workspace:FindFirstChild("_GAMEMODE")
        local ttFolder = gm and (gm:FindFirstChild("Time Trial") or gm:FindFirstChild(inMode))
        return true, ttFolder or inMode
    end
    return false, nil
end

local function isPlayerInPortal()
    local mode, inMode = getActiveGamemode()
    if mode == "Portal" or (inMode and inMode:lower():find("portal")) then
        local gm = workspace:FindFirstChild("_GAMEMODE")
        local pFolder = gm and (gm:FindFirstChild("Portal") or gm:FindFirstChild(inMode))
        return true, pFolder or inMode
    end
    return false, nil
end

-- RECURSIVE & ROBUST ENEMY SCANNER (Normal Maps + Gamemodes + Bosses + Nested Folders)
local function getMapEnemies(mapName)
    local list = {}
    local serverEnemies = workspace:FindFirstChild("_ENEMIES") and workspace._ENEMIES:FindFirstChild("Server")
    local clientEnemies = workspace:FindFirstChild("_ENEMIES") and workspace._ENEMIES:FindFirstChild("Client")
    if not (serverEnemies and clientEnemies) then return list end

    local function scanFolder(folder)
        if not folder then return end
        for _, sEnemy in ipairs(folder:GetChildren()) do
            -- If it's a subfolder (like Portal_4012060006 or Gamemode room), scan recursively!
            if sEnemy:IsA("Folder") or sEnemy:IsA("Model") and not sEnemy:GetAttribute("HP") then
                scanFolder(sEnemy)
            else
                local uid = sEnemy.Name
                local hp = sEnemy:GetAttribute("HP") or 0
                local dead = sEnemy:GetAttribute("Dead")
                if hp > 0 and dead ~= true then
                    local cEnemy = clientEnemies:FindFirstChild(uid)
                    local root = cEnemy and (cEnemy:FindFirstChild("HumanoidRootPart") or cEnemy:FindFirstChildWhichIsA("BasePart"))
                    -- Fallback: check workspace._MAP or sEnemy itself if client root is nil
                    if not root and sEnemy:IsA("BasePart") then
                        root = sEnemy
                    end
                    if root then
                        table.insert(list, {
                            UID   = uid,
                            Name  = sEnemy:GetAttribute("Name") or sEnemy.Name,
                            HP    = hp,
                            MaxHP = sEnemy:GetAttribute("MaxHP") or hp,
                            Order = sEnemy:GetAttribute("Order") or 1,
                            Part  = root,
                            Model = cEnemy or sEnemy
                        })
                    end
                end
            end
        end
    end

    if mapName and mapName ~= "All" then
        local mapFolder = serverEnemies:FindFirstChild(mapName)
        if mapFolder then
            scanFolder(mapFolder)
        end
    else
        -- Scan all map folders
        for _, f in ipairs(serverEnemies:GetChildren()) do
            scanFolder(f)
        end
    end

    -- If searching for Gamemode and list is empty, scan ALL folders in serverEnemies as fallback!
    if #list == 0 and (mapName == "Gamemode" or mapName == "Raid" or mapName == "Time Trial" or mapName == "Portal") then
        local gmFolder = serverEnemies:FindFirstChild("Gamemode")
        if gmFolder then scanFolder(gmFolder) end
        -- Fallback check in case gamemode monsters spawn in a named map folder (e.g. DBZ, OnePiece)
        for _, f in ipairs(serverEnemies:GetChildren()) do
            if f.Name:lower():find("gamemode") or f.Name:lower():find("raid") or f.Name:lower():find("portal") or f.Name:lower():find("boss") then
                scanFolder(f)
            end
        end
    end

    return list
end

-- STICKY TARGET VALIDATION (Deep Search Across Server and Client)
local function isCurrentTargetStillAlive()
    if not currentLockedTargetUID then return false end

    local serverEnemies = workspace:FindFirstChild("_ENEMIES") and workspace._ENEMIES:FindFirstChild("Server")
    local clientEnemies = workspace:FindFirstChild("_ENEMIES") and workspace._ENEMIES:FindFirstChild("Client")
    if not (serverEnemies and clientEnemies) then return false end

    local sEnemy = serverEnemies:FindFirstChild(currentLockedTargetUID, true)
    if not sEnemy then return false end

    local hp = sEnemy:GetAttribute("HP") or 0
    local dead = sEnemy:GetAttribute("Dead")
    if hp <= 0 or dead == true then
        return false -- Target is dead!
    end

    local cEnemy = clientEnemies:FindFirstChild(currentLockedTargetUID)
    local root = cEnemy and (cEnemy:FindFirstChild("HumanoidRootPart") or cEnemy:FindFirstChildWhichIsA("BasePart"))
    if not root and sEnemy:IsA("BasePart") then
        root = sEnemy
    end
    if not root then return false end

    return true, currentLockedTargetUID, root, cEnemy or sEnemy
end


local lastIndexMapTeleport = 0

local AvatarData = nil
pcall(function()
    AvatarData = require(game:GetService("ReplicatedStorage").Framework.Modules.Data.AvatarData)
end)

local AVATAR_MAP_FALLBACK = {
    DBZ = {
        { Id = "Dende", Monster = "Namekian Healer" },
        { Id = "Bulma", Monster = "Master Inventor" },
        { Id = "Kuririn", Monster = "Strongest Human" },
        { Id = "Piccolo", Monster = "Namekian Warrior" },
        { Id = "Gohan", Monster = "Hidden Potential" },
        { Id = "Vegeta", Monster = "Saiyan Prince" }
    },
    AOT = {
        { Id = "Sasha", Monster = "Scout Potato" },
        { Id = "Connie", Monster = "Buzzcut Scout" },
        { Id = "Hange", Monster = "Scout Scientist" },
        { Id = "Armin", Monster = "Tactical Scout" },
        { Id = "Mikasa", Monster = "Ace Scout" },
        { Id = "Levi", Monster = "Ace Captain" }
    },
    Naruto = {
        { Id = "Shikamaru", Monster = "Shadow Tactician" },
        { Id = "Sakura", Monster = "Destructive Fist" },
        { Id = "Hinata", Monster = "Gentle Fist" },
        { Id = "Choji", Monster = "Akimichi Titan" },
        { Id = "Tsunade", Monster = "Slug Sannin" },
        { Id = "Kakashi", Monster = "Copy Ninja" }
    },
    Nanatsu = {
        { Id = "Gowther", Monster = "Goat Sin" },
        { Id = "Diane", Monster = "Serpent Sin" },
        { Id = "King", Monster = "Grizzly Sin" },
        { Id = "Ban", Monster = "Fox Sin" },
        { Id = "Merlin", Monster = "Boar Sin" },
        { Id = "Escanor", Monster = "Lion Sin" }
    },
    SoloLeveling = {
        { Id = "SungJinWoo", Monster = "Weakest Hunter" },
        { Id = "TaeShik", Monster = "Stealth Assassin" },
        { Id = "SongChiyul", Monster = "Veteran Hunter" },
        { Id = "WooJinChul", Monster = "Surveillance Chief" },
        { Id = "ChaHaeIn", Monster = "Sword Dancer" },
        { Id = "ThomasAndre", Monster = "The Goliath" }
    },
    OnePiece = {
        { Id = "Nami", Monster = "Cat Burglar" },
        { Id = "Usopp", Monster = "Sniper King" },
        { Id = "Sanji", Monster = "Black Leg" },
        { Id = "Zoro", Monster = "Pirate Hunter" },
        { Id = "Luffy", Monster = "Straw Hat" },
        { Id = "Ace", Monster = "Fire Fist" }
    }
}

local function getMissingAvatarMonstersForMap(targetMap)
    local missing = {}
    local pd = Library and Library.PlayerData
    local avIndex = pd and (pd.AvatarIndex or {}) or {}

    if AvatarData then
        for avId, data in pairs(AvatarData) do
            if data.Map == targetMap and data.Name then
                if not avIndex[avId] then
                    missing[data.Name:lower()] = avId
                end
            end
        end
    else
        local mapList = AVATAR_MAP_FALLBACK[targetMap] or {}
        for _, entry in ipairs(mapList) do
            if not avIndex[entry.Id] then
                missing[entry.Monster:lower()] = entry.Id
            end
        end
    end
    return missing
end

-- Verified Game Data: EXACT monsters that drop Raid Tickets in each world
-- Filtered strictly to mid-range sub-bosses (รอง Secret Boss)
local RAID_TICKET_DROPPERS = {
    DBZ = {
        Preferred = "Hidden Potential", -- Order 5 (Gohan, 1% drop chance) - รอง Secret Boss เลือดกลางๆ พอดี
        Allowed = { "Hidden Potential", "Namekian Warrior", "Strongest Human" } -- Order 3, 4, 5 all drop DBZRaidTicket!
    },
    AOT = {
        Preferred = "Ace Scout", -- Order 5 (Mikasa, 1% drop chance) - รอง Secret Boss เลือดกลางๆ พอดี
        Allowed = { "Ace Scout", "Tactical Scout", "Scout Scientist" } -- Order 3, 4, 5 all drop AOTRaidTicket!
    },
    Naruto = {
        Preferred = "Slug Sannin", -- Order 5 (Tsunade, 1% drop chance) - รอง Secret Boss
        Allowed = { "Slug Sannin", "Akimichi Titan", "Gentle Fist" } -- Order 3, 4, 5 all drop NarutoRaidTicket!
    },
    Nanatsu = {
        Preferred = "Boar Sin", -- Order 5 (Merlin, 1% drop chance) - รอง Secret Boss
        Allowed = { "Boar Sin", "Fox Sin", "Grizzly Sin" } -- Order 3, 4, 5 all drop NanatsuRaidTicket!
    },
    SoloLeveling = {
        Preferred = "Sword Dancer", -- Order 5 (ChaHaeIn, 1% drop chance) - รอง Secret Boss
        Allowed = { "Sword Dancer", "Surveillance Chief", "Veteran Hunter" } -- Order 3, 4, 5 all drop SoloLevelingRaidTicket!
    },
    OnePiece = {
        Preferred = "Straw Hat", -- Order 5 (Luffy, 1% drop chance) - รอง Secret Boss
        Allowed = { "Straw Hat", "Pirate Hunter", "Black Leg" } -- Order 3, 4, 5 all drop OnePieceRaidTicket!
    }
}

local function getRaidTicketsCount(targetMap)
    local pd = Library and Library.PlayerData
    local items = pd and pd.Items or {}
    local tMap = targetMap or "DBZ"
    local ticketName = tMap .. "RaidTicket"
    return items[ticketName] or items["RaidTicket"] or 0
end

local function isRaidTicketDropper(monsterName, mapName)
    local cfg = RAID_TICKET_DROPPERS[mapName]
    if not cfg then return false end
    local mLower = string.lower(monsterName or "")
    for _, allowed in ipairs(cfg.Allowed) do
        local aLower = string.lower(allowed)
        if mLower == aLower or string.find(mLower, aLower, 1, true) or string.find(aLower, mLower, 1, true) then
            return true
        end
    end
    return false
end

-- Selects ONLY monsters confirmed to drop Raid Tickets (เน้นตัวเลือดกลางๆ รอง Secret Boss)
local function getMidTierRaidTicketMonster(targetMap)
    local curMap = getCurrentMap()
    local enemies = getMapEnemies(targetMap)
    if #enemies == 0 then enemies = getMapEnemies(curMap) end
    if #enemies == 0 then enemies = getMapEnemies("All") end
    if #enemies == 0 then return nil end

    local cfg = RAID_TICKET_DROPPERS[targetMap] or RAID_TICKET_DROPPERS[curMap]
    if cfg then
        -- 1. Try to find the exact preferred sub-boss first (รอง Secret Boss)
        local prefName = string.lower(cfg.Preferred)
        for _, e in ipairs(enemies) do
            local eName = string.lower(e.Name)
            if eName == prefName or string.find(eName, prefName, 1, true) or string.find(prefName, eName, 1, true) then
                return e
            end
        end

        -- 2. Otherwise find ANY monster in the confirmed ticket-dropping list
        for _, allowed in ipairs(cfg.Allowed) do
            local aName = string.lower(allowed)
            for _, e in ipairs(enemies) do
                local eName = string.lower(e.Name)
                if eName == aName or string.find(eName, aName, 1, true) or string.find(aName, eName, 1, true) then
                    return e
                end
            end
        end
    end

    return nil
end

getRaidStatus = function()
    local lp = game:GetService("Players").LocalPlayer
    local inMode = lp:GetAttribute("InMode")
    local mode = lp:GetAttribute("Mode")
    if not (mode == "Raid" or (inMode and tostring(inMode):lower():find("raid"))) then
        return "None", nil
    end

    local rep = game:GetService("ReplicatedStorage")
    local gmRep = rep:FindFirstChild("Server") and rep.Server:FindFirstChild("Gamemode")
    local room = inMode and gmRep and gmRep:FindFirstChild(inMode)
    local status = room and room:GetAttribute("Status")
    if status == "Running" then
        return "Running", inMode
    elseif status == "Opened" then
        return "Opened", inMode
    end

    -- Fallback check: if server enemies folder has active enemies, it is Running
    local sEnemies = workspace:FindFirstChild("_ENEMIES") and workspace._ENEMIES:FindFirstChild("Server")
    local gmFolder = sEnemies and sEnemies:FindFirstChild("Gamemode")
    local rEnemies = inMode and gmFolder and gmFolder:FindFirstChild(inMode)
    if rEnemies and #rEnemies:GetChildren() > 0 then
        return "Running", inMode
    end

    return "Opened", inMode
end

local function selectTargetEnemy()
    -- 0. TOP PRIORITY: AUTO FARM MISSING AVATAR INDEX
    if CFG.AutoIndexFarm then
        local curMap = getCurrentMap()
        local chosenMap = CFG.IndexFarmWorld or "Current Map"
        local targetIndexMap = (chosenMap ~= "Current Map") and chosenMap or (curMap ~= "Lobby" and curMap or "DBZ")

        -- If target map is specified and we are not in that map, WARP IMMEDIATELY!
        if targetIndexMap and targetIndexMap ~= "Current Map" and curMap ~= targetIndexMap then
            if tick() - lastIndexMapTeleport >= 2.0 then
                lastIndexMapTeleport = tick()
                currentLockedTargetUID = nil
                pcall(function()
                    Library.Remote:Fire("TeleportSystem", "To", targetIndexMap)
                end)
            end
        end

        local missingAvatars = getMissingAvatarMonstersForMap(targetIndexMap)
        local hasAnyMissing = false
        for _ in pairs(missingAvatars) do
            hasAnyMissing = true
            break
        end

        if hasAnyMissing then
            -- Check if current locked target is already one of the missing avatar monsters and still alive
            if currentLockedTargetUID then
                local stillAlive, lUID, lPart, lModel = isCurrentTargetStillAlive()
                if stillAlive then
                    local sName = (lModel:GetAttribute("Name") or lModel.Name):lower()
                    for monsterNameLower, avId in pairs(missingAvatars) do
                        if sName == monsterNameLower or sName:find(monsterNameLower) or monsterNameLower:find(sName) then
                            if getgenv then getgenv()._CurrentLockedUID = lUID end
                            return lUID, lPart, lModel
                        end
                    end
                end
            end

            -- Find enemies belonging to targetIndexMap (or all current active map enemies)
            local targetEnemies = getMapEnemies(targetIndexMap)
            if #targetEnemies == 0 then
                targetEnemies = getMapEnemies(curMap)
            end
            if #targetEnemies == 0 then
                targetEnemies = getMapEnemies("All")
            end

            for _, e in ipairs(targetEnemies) do
                local eNameLower = e.Name:lower()
                for monsterNameLower, avId in pairs(missingAvatars) do
                    if eNameLower == monsterNameLower or eNameLower:find(monsterNameLower) or monsterNameLower:find(eNameLower) then
                        currentLockedTargetUID = e.UID
                        if getgenv then getgenv()._CurrentLockedUID = currentLockedTargetUID end
                        return e.UID, e.Part, e.Model
                    end
                end
            end
        end
    end

    -- 0.5. RAID TICKET FARMING (Strictly Mid-Tier Sub-Boss Droppers ONLY)
    if CFG.AutoRaid and CFG.AutoFarmTicketIfNone then
        local raidMap = CFG.RaidTargetMap or "DBZ"
        local tickets = getRaidTicketsCount(raidMap)
        if tickets <= 0 then
            -- Verify sticky target: MUST be in confirmed ticket-dropping list of raidMap!
            local stillAlive, lockedUID, lockedPart, lockedModel = isCurrentTargetStillAlive()
            if stillAlive and lockedModel then
                local mName = lockedModel:GetAttribute("Name") or lockedModel.Name
                if isRaidTicketDropper(mName, raidMap) then
                    if getgenv then getgenv()._CurrentLockedUID = lockedUID end
                    return lockedUID, lockedPart, lockedModel
                else
                    currentLockedTargetUID = nil -- Drop the lock on non-ticket mob
                end
            end

            -- Target preferred or allowed sub-boss in raidMap only
            local subBoss = getMidTierRaidTicketMonster(raidMap)
            if subBoss then
                currentLockedTargetUID = subBoss.UID
                if getgenv then getgenv()._CurrentLockedUID = currentLockedTargetUID end
                return subBoss.UID, subBoss.Part, subBoss.Model
            end

            -- If ticket sub-boss is temporarily dead, DO NOT FALL THROUGH to weak mobs!
            currentLockedTargetUID = nil
            if getgenv then getgenv()._CurrentLockedUID = nil end
            return nil, nil, nil
        end
    end

    -- 1. STICKY TARGET CHECK: If locked target is still alive, KEEP IT!
    local stillAlive, lockedUID, lockedPart, lockedModel = isCurrentTargetStillAlive()
    if stillAlive then
        if getgenv then getgenv()._CurrentLockedUID = lockedUID end
        return lockedUID, lockedPart, lockedModel
    end

    -- Target died or no target locked: unlock and find NEW target
    currentLockedTargetUID = nil
    if getgenv then getgenv()._CurrentLockedUID = nil end

    -- 2. GAMEMODE TARGETS (Raid / Time Trial / Portal / InMode Events)
    local mode, inMode = getActiveGamemode()
    if mode or inMode then
        local gmEnemies = getMapEnemies("Gamemode")
        if #gmEnemies == 0 then
            -- Fallback scan: check all monsters currently alive in entire server enemies
            local allEnemies = getMapEnemies("All")
            if #allEnemies > 0 then
                gmEnemies = allEnemies
            end
        end

        if #gmEnemies > 0 then
            table.sort(gmEnemies, function(a, b) return a.HP < b.HP end)
            currentLockedTargetUID = gmEnemies[1].UID
            if getgenv then getgenv()._CurrentLockedUID = currentLockedTargetUID end
            return gmEnemies[1].UID, gmEnemies[1].Part, gmEnemies[1].Model
        end
    end

    -- 3. NORMAL ZONE SELECTION
    local curMap = getCurrentMap()
    local highestUnlocked = getHighestUnlockedMap()
    local targetMap = curMap

-- (Raid Ticket Farming handled at Priority 0.5 above)

    -- Check if we have a pending unlock that needs gold!
    local pd = Library and Library.PlayerData
    local playerGold = pd and (pd.Gold or (pd.Items and pd.Items.Gold) or 0) or 0
    if currentPendingUnlock and playerGold < currentPendingUnlock.Cost then
        -- Farm gold in the target map or highest unlocked map
        targetMap = currentPendingUnlock.Map or highestUnlocked
        if curMap ~= targetMap and (os.clock() - lastNewAreaTeleport >= 3.0) then
            lastNewAreaTeleport = os.clock()
            pcall(function()
                Library.Remote:Fire("TeleportSystem", "To", targetMap)
            end)
        end
    elseif CFG.AutoGoNewArea and highestUnlocked and highestUnlocked ~= "Lobby" then
        targetMap = highestUnlocked
        -- Proactively travel to the latest unlocked map if not already there!
        if curMap ~= highestUnlocked and (os.clock() - lastNewAreaTeleport >= 3.0) then
            lastNewAreaTeleport = os.clock()
            pcall(function()
                Library.Remote:Fire("TeleportSystem", "To", highestUnlocked)
            end)
        end
    end

    local enemies = getMapEnemies(targetMap)
    if #enemies == 0 and targetMap ~= curMap then
        targetMap = curMap
        enemies = getMapEnemies(targetMap)
    end
    if #enemies == 0 then
        for _, m in ipairs(MAP_LIST) do
            local eList = getMapEnemies(m)
            if #eList > 0 then
                enemies = eList
                break
            end
        end
    end
    if #enemies == 0 then
        -- Final fallback: scan any alive monster in the server
        enemies = getMapEnemies("All")
    end
    if #enemies == 0 then return nil, nil, nil end

    -- 2. Filter by monster multi-selection (Matches both raw name and [ Map ] suffix)
    local selectedMonsters = CFG.TargetMonsterFilterMulti or (CFG.TargetMonsterFilter and { CFG.TargetMonsterFilter }) or {"All"}
    local isAll = isItemInList(selectedMonsters, "All")
    if not isAll and #selectedMonsters > 0 then
        local filtered = {}
        for _, e in ipairs(enemies) do
            for _, sel in pairs(selectedMonsters) do
                local rawSel = sel:gsub("%s*%[.-%]%s*", ""):lower()
                if e.Name:lower() == rawSel or e.Name:lower():find(rawSel) or (sel:lower():find(e.Name:lower())) then
                    table.insert(filtered, e)
                    break
                end
            end
        end
        if #filtered > 0 then
            table.sort(filtered, function(a, b) return a.HP < b.HP end)
            currentLockedTargetUID = filtered[1].UID
            if getgenv then getgenv()._CurrentLockedUID = currentLockedTargetUID end
            return filtered[1].UID, filtered[1].Part, filtered[1].Model
        end
    end

    -- Normal sorting
    if not CFG.AutoGoNewArea then
        table.sort(enemies, function(a, b) return a.HP > b.HP end)
    else
        table.sort(enemies, function(a, b) return a.HP < b.HP end)
    end

    currentLockedTargetUID = enemies[1].UID
    if getgenv then getgenv()._CurrentLockedUID = currentLockedTargetUID end
    return enemies[1].UID, enemies[1].Part, enemies[1].Model
end

local lastTeleportedUID = nil
local lastTeleportTick = 0

-- Smart AOE Centroid calculation: finds nearby enemies to maximize skill hitbox coverage
local function getSmartAoeTargetPosition(part)
    local pPos = part.Position
    local serverEnemies = workspace:FindFirstChild("_ENEMIES") and workspace._ENEMIES:FindFirstChild("Server")
    if not serverEnemies then return pPos end

    local sumPos = pPos
    local clusterCount = 1
    local aoeRadius = 25.0

    for _, obj in ipairs(serverEnemies:GetDescendants()) do
        if obj:IsA("BasePart") and (obj.Name:find("Root") or obj.Name == "HumanoidRootPart") then
            local dist = (obj.Position - pPos).Magnitude
            if dist > 0.5 and dist <= aoeRadius then
                sumPos = sumPos + obj.Position
                clusterCount = clusterCount + 1
            end
        end
    end

    return sumPos / clusterCount
end


local function setupDashListener()
    local function hookRoot(c)
        local r = c:WaitForChild("HumanoidRootPart", 5)
        if r then
            r.ChildAdded:Connect(function(child)
                if CFG.DashHack and (child:IsA("LinearVelocity") or child:IsA("BodyVelocity")) then
                    local hum = getHum()
                    local dir = (hum and hum.MoveDirection.Magnitude > 0) and hum.MoveDirection or r.CFrame.LookVector
                    if child:IsA("LinearVelocity") then
                        child.VectorVelocity = dir * (CFG.DashSpeed or 150)
                    elseif child:IsA("BodyVelocity") then
                        child.Velocity = dir * (CFG.DashSpeed or 150)
                        child.MaxForce = Vector3.new(1e6, 1e6, 1e6)
                    end
                end
            end)
        end
    end
    if lp.Character then hookRoot(lp.Character) end
    lp.CharacterAdded:Connect(hookRoot)
end
task.spawn(setupDashListener)

local function teleportToTarget(part, uid)
    local root = getRoot()
    if not (part and root) then return end

    local smartCenter = getSmartAoeTargetPosition(part)
    local targetPos = smartCenter + Vector3.new(0, 2.5, 3)
    local dist = (root.Position - smartCenter).Magnitude

    -- If target changed OR player is far away, immediately TP
    if uid ~= lastTeleportedUID or dist > 4.5 or dist < 1.5 then
        lastTeleportedUID = uid
        lastTeleportTick = tick()
        root.CFrame = CFrame.lookAt(targetPos, smartCenter)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end

    if uid then
        Library.Target = { uid }
    end
end

-- WALL BREAKING, QUESTS, UNLOCKS & MODES
-- ══════════════════════════════════════════════════════════
local function getMapWall(mapName)
    local mapFolder = workspace:FindFirstChild("_MAP") and workspace._MAP:FindFirstChild(mapName)
    local wall = mapFolder and mapFolder:FindFirstChild("Wall")
    local wallRoot = wall and (wall:FindFirstChild("Root") or wall:FindFirstChildWhichIsA("BasePart"))
    return wall, wallRoot
end

local function doAutoBreakWall()
    local curMap = getCurrentMap()
    local highestUnlocked = getHighestUnlockedMap()
    if highestUnlocked and highestUnlocked ~= "Lobby" and highestUnlocked ~= curMap then
        pcall(function()
            Library.Remote:Fire("TeleportSystem", "To", highestUnlocked)
        end)
        return
    end

    if isNextMapUnlocked(curMap) then
        local nextHighest = getHighestUnlockedMap()
        if nextHighest and nextHighest ~= "Lobby" and nextHighest ~= curMap then
            pcall(function()
                Library.Remote:Fire("TeleportSystem", "To", nextHighest)
            end)
            return
        end
    end

    local wall, wallRoot = getMapWall(curMap)
    local root = getRoot()

    if wallRoot and root then
        root.CFrame = wallRoot.CFrame * CFrame.new(0, 0, 8) * CFrame.Angles(0, math.pi, 0)
    end
    pcall(function()
        Library.Remote:Fire("WallSystem", "Click", curMap)
        Library.Remote:Fire("ClickSystem", "Execute", {})
    end)
end

local function handleSmartWallBreaking(now)
    if not CFG.AutoBreakWall then return false end
    local inRaid = isPlayerInRaid()
    local inTT = isPlayerInTimeTrial()
    local inPortal = isPlayerInPortal()
    if inRaid or inTT or inPortal then return false end

    local curMap = getCurrentMap()
    local highestUnlocked = getHighestUnlockedMap()

    -- 1. If we are not in the latest unlocked area, warp to latest area first!
    if highestUnlocked and highestUnlocked ~= "Lobby" and highestUnlocked ~= curMap then
        if now - lastNewAreaTeleport >= 2.0 then
            lastNewAreaTeleport = now
            pcall(function()
                Library.Remote:Fire("TeleportSystem", "To", highestUnlocked)
            end)
        end
        return false
    end

    -- 2. If the next map is already unlocked (wall broken), warp to the new latest area immediately!
    if isNextMapUnlocked(curMap) then
        local nextHighest = getHighestUnlockedMap()
        if nextHighest and nextHighest ~= "Lobby" and nextHighest ~= curMap then
            if now - lastNewAreaTeleport >= 2.0 then
                lastNewAreaTeleport = now
                pcall(function()
                    Library.Remote:Fire("TeleportSystem", "To", nextHighest)
                end)
            end
        end
        return false
    end

    -- 3. We are in the latest area and the wall is locked: break it!
    local wall, wallRoot = getMapWall(curMap)
    if not (wall and wallRoot) then return false end

    local function hitWall()
        local root = getRoot()
        if root then
            root.CFrame = wallRoot.CFrame * CFrame.new(0, 0, 6) * CFrame.Angles(0, math.pi, 0)
        end
        pcall(function()
            Library.Remote:Fire("WallSystem", "Click", curMap)
            Library.Remote:Fire("ClickSystem", "Execute", {})
            Library.Remote:Fire("ClickSystem", "CastSkill", {})
        end)
    end

    if CFG.WallBreakMode == "Continuous" then
        hitWall()
        return true
    elseif CFG.WallBreakMode == "Timed" then
        if not isAttackingWall and (now - wallCooldownStartTime >= CFG.WallFarmCooldown) then
            isAttackingWall = true
            wallAttackStartTime = now
        end

        if isAttackingWall then
            if (now - wallAttackStartTime <= CFG.WallAttackDuration) then
                hitWall()
                return true
            else
                isAttackingWall = false
                wallCooldownStartTime = now
            end
        end
    end
    return false
end

local function cleanupDuplicateCards()
    local pd = Library and Library.PlayerData
    if not (pd and pd.Cards) then return end

    local cardCounts = {}
    for uid, card in pairs(pd.Cards) do
        local id = card.Id or uid
        cardCounts[id] = cardCounts[id] or {}
        table.insert(cardCounts[id], { UID = uid, Card = card })
    end

    local toDelete = {}
    for id, list in pairs(cardCounts) do
        if #list > 1 then
            for i = 2, #list do
                local entry = list[i]
                if not entry.Card.Equipped and not entry.Card.Locked then
                    table.insert(toDelete, entry.UID)
                end
            end
        end
    end

    if #toDelete > 0 then
        Library.Remote:Fire("InventorySystem", "Delete", "Card", Library:Encode(toDelete))
    end
end

local lastQuestGachaSpin = 0
local lastQuestConsumableUse = 0

local lastSummonTick = 0

local function doAutoSummon()
    local pd = Library and Library.PlayerData
    if not (pd and Library.Remote) then return end

    local eggMap = CFG.SummonEgg or getCurrentMap()
    if eggMap == "Lobby" or not eggMap or eggMap == "" then eggMap = "DBZ" end
    local summonType = CFG.SummonType or "Pet"

    if summonType == "Race" then
        pcall(function()
            Library.Remote:Fire("GachaSystem", "Spin", "Race", "Default", {})
        end)
    elseif summonType == "Eye Technique" then
        pcall(function()
            Library.Remote:Fire("GachaSystem", "Spin", "Eye Technique", "Naruto", {})
        end)
    else
        pcall(function()
            Library.Remote:Fire("GachaSystem", "Spin", summonType, eggMap, {})
        end)
    end
end

local function handleAutoQuests(now)
    if not (CFG.AutoQuest or CFG.AutoQuests) then return end
    if now - lastQuestTick < 1.0 then return end
    lastQuestTick = now

    local pd = Library and Library.PlayerData
    if not (pd and Library.Remote) then return end

    -- 1. Check & Claim Active Quest
    local active = pd.ActiveQuest
    if active and active.Type and active.Id then
        pcall(function()
            Library.Remote:Fire("QuestSystem", "Check", active.Type, active.Id)
            Library.Remote:Fire("QuestSystem", "Claim", active.Type, active.Id)
        end)
    end

    -- 2. Inspect Quests for Objectives (Global, Main, Daily, Stage)
    local allQuestCategories = { "Global", "Main", "Daily", "Event" }
    local quests = pd.Quests or {}
    
    for _, cat in ipairs(allQuestCategories) do
        local qList = quests[cat]
        if type(qList) == "table" then
            for qId, qData in pairs(qList) do
                if type(qData) == "table" and qData.Objectives then
                    for _, obj in ipairs(qData.Objectives) do
                        local oType = tostring(obj.Type or "")
                        local goal = tonumber(obj.Goal) or 1
                        local prog = tonumber(obj.Progress) or 0

                        if prog < goal then
                            -- Gacha / Card Spin Quest
                            if oType == "SpinGacha" or oType:find("Gacha") or oType:find("Card") then
                                if now - lastQuestGachaSpin >= 0.5 then
                                    lastQuestGachaSpin = now
                                    local curMap = getCurrentMap()
                                    if curMap == "Lobby" or not curMap or curMap == "" then curMap = "DBZ" end
                                    pcall(function()
                                        Library.Remote:Fire("GachaSystem", "Spin", "Pet", curMap, {})
                                    end)
                                end
                            -- Consumable Quests (e.g. "Use Consumable")
                            elseif oType == "UseConsumable" or oType:find("Consumable") then
                                if now - lastQuestConsumableUse >= 0.5 then
                                    lastQuestConsumableUse = now
                                    if pd.Items then
                                        for itemId, count in pairs(pd.Items) do
                                            if count > 0 and (itemId:find("Potion") or itemId:find("Juice")) then
                                                pcall(function()
                                                    Library.Remote:Fire("ItemSystem", "Use", itemId, 1, false, true)
                                                end)
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- 3. Stage-based Quests sequential checking
    for stageNum = 1, 50 do
        local q = quests[tostring(stageNum)] or quests[stageNum]
        if q then
            if q.Completed and not q.Claimed then
                pcall(function()
                    Library.Remote:Fire("QuestSystem", "Claim", stageNum)
                end)
            end
        else
            pcall(function()
                Library.Remote:Fire("QuestSystem", "Accept", stageNum)
            end)
            break
        end
    end
end

local function doAutoQuests()
    local prior = CFG.AutoQuests
    CFG.AutoQuests = true
    lastQuestTick = 0
    local ok, reason = pcall(handleAutoQuests, tick())
    CFG.AutoQuests = prior
    if not ok then warn("[Axel Hub Quests] " .. tostring(reason)) end
end

local currentPendingUnlock = nil

local UNLOCK_SYSTEMS_CONFIG = {
    { Id = "Gacha_Race",                 Name = "Race Gacha",           Map = "DBZ",  Cost = 10000,       SettingKey = "AutoUnlockRace" },
    { Id = "Upgrade_Warrior Upgrades",    Name = "Warrior Upgrades",     Map = "DBZ",  Cost = 15000,       SettingKey = "AutoUnlockWarrior" },
    { Id = "Upgrade_Offline Upgrades",    Name = "Offline Upgrades",     Map = "DBZ",  Cost = 45000,       SettingKey = "AutoUnlockOffline" },
    { Id = "Gacha_Titan",                Name = "Titan Gacha",          Map = "AOT",  Cost = 4860000,     SettingKey = "AutoUnlockTitan" },
    { Id = "Gacha_Weapon_T1",            Name = "Weapon T1 Gacha",      Map = "AOT",  Cost = 10935000,    SettingKey = "AutoUnlockWeapon" },
    { Id = "Gacha_Hero Passive",         Name = "Hero Passive Gacha",   Map = "AOT",  Cost = 87480000,    SettingKey = "AutoUnlockHeroPassive" },
    { Id = "Gacha_Eye Technique",        Name = "Eye Technique Gacha",  Map = "Naruto", Cost = 2361960000, SettingKey = "AutoUnlockEye" },
    { Id = "Upgrade_Ninja Progression",   Name = "Ninja Progression",    Map = "Naruto", Cost = 3542940000, SettingKey = "AutoUnlockNinja" },
    { Id = "Upgrade_Red Cloud Totem",     Name = "Red Cloud Totem",      Map = "Naruto", Cost = 10628820000, SettingKey = "AutoUnlockRedCloud" },
    { Id = "Gacha_Sin",                  Name = "Sin Gacha",            Map = "Nanatsu", Cost = 5165606520000, SettingKey = "AutoUnlockSin" },
    { Id = "Gacha_Amulet Building",      Name = "Amulet Building",      Map = "Nanatsu", Cost = 20662426080000, SettingKey = "AutoUnlockAmulet" },
    { Id = "Upgrade_Commandment Totem",   Name = "Commandment Totem",    Map = "Nanatsu", Cost = 41324852160000, SettingKey = "AutoUnlockCommandment" },
    { Id = "Gacha_Hunter Rank",          Name = "Hunter Rank Gacha",    Map = "SoloLeveling", Cost = 135566177510880000, SettingKey = "AutoUnlockHunter" },
    { Id = "Upgrade_Portal Upgrades",     Name = "Portal Upgrades",      Map = "SoloLeveling", Cost = 271132355021760000, SettingKey = "AutoUnlockPortal" },
    { Id = "Gacha_Shadow Passive",       Name = "Shadow Passive Gacha", Map = "SoloLeveling", Cost = 542264710043520000, SettingKey = "AutoUnlockShadow" },
    { Id = "Upgrade_Ant Progression",     Name = "Ant Progression",      Map = "SoloLeveling", Cost = 813397065065280000, SettingKey = "AutoUnlockAnt" },
    { Id = "Upgrade_Class Tree",         Name = "Class Tree",          Map = "SoloLeveling", Cost = 1084529420087000000, SettingKey = "AutoUnlockClassTree" },
}

local function getNextUnlockTarget()
    local pd = Library and Library.PlayerData
    if not pd then return nil end
    local unlocked = pd.Unlocked or {}
    local unlockedMaps = pd.UnlockedMap or {}

    for _, sys in ipairs(UNLOCK_SYSTEMS_CONFIG) do
        local isEnabled = CFG[sys.SettingKey] or CFG.BalancedUnlocker
        if isEnabled and not unlocked[sys.Id] and (unlockedMaps[sys.Map] == true or sys.Map == "DBZ") then
            return sys
        end
    end
    return nil
end

local function handleBalancedUnlocks(now)
    if now - lastUnlockStep < 1.0 then return end
    lastUnlockStep = now

    local pd = Library and Library.PlayerData
    if not (pd and Library.Remote) then return end

    -- Unlock only when player has enough gold/currency. NEVER overrides farming target!
    currentPendingUnlock = nil

    local target = getNextUnlockTarget()
    if target then
        local playerGold = pd.Gold or (pd.Items and pd.Items.Gold) or 0
        if playerGold >= target.Cost then
            pcall(function()
                Library.Remote:Fire("UnlockSystem", "Validate", target.Id)
            end)
        end
    end

    -- Auto Unlock Titan
    if CFG.AutoUnlockTitan and not (pd.Unlocked and pd.Unlocked["Gacha_Titan"]) then
        local playerGold = pd.Gold or (pd.Items and pd.Items.Gold) or 0
        if playerGold >= 10000000 then -- 10M Gold
            pcall(function()
                Library.Remote:Fire("UnlockSystem", "Validate", "Gacha_Titan")
            end)
        end
    end
end

local function handleAutoUnlockSystems()
    local pd = Library and Library.PlayerData
    if not pd then return end
    local items = pd.Items or {}
    local unlocked = pd.Unlocked or {}

    local ud = nil
    pcall(function() ud = Library:GetData("UnlockData") end)
    if not ud then return end

    for unlockId, info in pairs(ud) do
        if not unlocked[unlockId] then
            local reqs = info.Requirements or {}
            local canAfford = true
            for curName, reqAmt in pairs(reqs) do
                if (items[curName] or 0) < reqAmt then
                    canAfford = false
                    break
                end
            end
            if canAfford then
                Library.Remote:Fire("UnlockSystem", "Validate", unlockId)
            end
        end
    end
end

local lastGamemodeExitAttempt = 0

local function getCurrentGamemodeStage()
    local lp = game:GetService("Players").LocalPlayer
    local inMode = lp:GetAttribute("InMode")

    -- 1. Check ReplicatedStorage.Server.Gamemode[inMode] attribute directly
    local srv = game:GetService("ReplicatedStorage"):FindFirstChild("Server")
    local gm = srv and srv:FindFirstChild("Gamemode")
    local roomInst = gm and inMode and gm:FindFirstChild(inMode)
    if roomInst then
        local stage = roomInst:GetAttribute("Stage") or roomInst:GetAttribute("StageSpawned")
        if tonumber(stage) then return tonumber(stage) end
    end

    -- 2. Check Workspace _GAMEMODE
    local gmFolder = workspace:FindFirstChild("_GAMEMODE")
    if gmFolder and inMode then
        local target = gmFolder:FindFirstChild(inMode) or gmFolder:FindFirstChild("Raid") or gmFolder:FindFirstChild("Time Trial")
        if target then
            local stage = target:GetAttribute("Stage") or target:GetAttribute("Room") or target:GetAttribute("Wave")
            if tonumber(stage) then return tonumber(stage) end
        end
    end

    -- 3. Check UI Gamemode screen ONLY if actively in mode
    if inMode then
        local gmScreen = Library and Library.GetScreen and Library:GetScreen("Gamemode")
        local startLabel = gmScreen and gmScreen:FindFirstChild("Content") and gmScreen.Content:FindFirstChild("Start") and gmScreen.Content.Start:FindFirstChild("Label")
        if startLabel and startLabel.Text and (startLabel.Text:find("Room") or startLabel.Text:find("Stage")) then
            local clean = string.gsub(startLabel.Text, "<[^>]+>", "")
            local num = string.match(clean, "%d+")
            if tonumber(num) then return tonumber(num) end
        end
    end

    return 1
end

local function executeGamemodeQuit()
    pcall(function()
        Library.Remote:Fire("GamemodeSystem", "Quit")
    end)
    pcall(function()
        local gmScreen = Library and Library.GetScreen and Library:GetScreen("Gamemode")
        local leaveBtn = gmScreen and gmScreen:FindFirstChild("Content") and gmScreen.Content:FindFirstChild("Leave")
        if leaveBtn and getconnections then
            for _, conn in ipairs(getconnections(leaveBtn.MouseButton1Click)) do
                conn:Fire()
            end
        end
    end)
end

local lastTimeTrialJoinAttempt = 0

local function getGamemodeEnemies()
    local list = {}
    local serverEnemies = workspace:FindFirstChild("_ENEMIES") and workspace._ENEMIES:FindFirstChild("Server")
    local clientEnemies = workspace:FindFirstChild("_ENEMIES") and workspace._ENEMIES:FindFirstChild("Client")
    if not serverEnemies then return list end

    local lp = game:GetService("Players").LocalPlayer
    local inMode = lp:GetAttribute("InMode")

    local function checkAndAdd(obj)
        if not obj then return end
        local hp = obj:GetAttribute("HP")
        local dead = obj:GetAttribute("Dead")
        if hp and hp > 0 and dead ~= true then
            local uid = obj.Name
            local cEnemy = clientEnemies and clientEnemies:FindFirstChild(uid)
            local root = nil
            if cEnemy then
                root = cEnemy.PrimaryPart or cEnemy:FindFirstChild("HumanoidRootPart") or cEnemy:FindFirstChildWhichIsA("BasePart")
            end
            if not root then
                if obj:IsA("BasePart") then
                    root = obj
                elseif obj:IsA("Model") then
                    root = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
                end
            end
            if root then
                table.insert(list, {
                    UID   = uid,
                    Name  = obj:GetAttribute("Name") or obj.Name,
                    HP    = hp,
                    MaxHP = obj:GetAttribute("MaxHP") or hp,
                    Part  = root,
                    Model = cEnemy or obj
                })
            end
        end
    end

    -- 1. Scan Server.Gamemode (and room subfolders)
    local gmFolder = serverEnemies:FindFirstChild("Gamemode")
    if gmFolder then
        if inMode and gmFolder:FindFirstChild(inMode) then
            for _, child in ipairs(gmFolder[inMode]:GetDescendants()) do
                checkAndAdd(child)
            end
        end
        for _, child in ipairs(gmFolder:GetDescendants()) do
            checkAndAdd(child)
        end
    end

    -- 2. Scan workspace._MAP.Gamemode
    local mapGm = workspace:FindFirstChild("_MAP") and workspace._MAP:FindFirstChild("Gamemode")
    if mapGm then
        for _, child in ipairs(mapGm:GetDescendants()) do
            checkAndAdd(child)
        end
    end

    -- 3. Scan matching subfolders
    for _, f in ipairs(serverEnemies:GetChildren()) do
        local fn = f.Name:lower()
        if fn:find("time") or fn:find("trial") or fn:find("hallway") or (inMode and fn:find(inMode:lower())) then
            for _, child in ipairs(f:GetDescendants()) do
                checkAndAdd(child)
            end
        end
    end

    return list
end

local function doJoinTimeTrial(diff)
    pcall(function()
        Library.Remote:Fire("GamemodeSystem", "Create", "Time Trial", "The Hallway", diff or "Easy", false)
        Library.Remote:Fire("GamemodeSystem", "Enter", "Time Trial", "The Hallway", diff or "Easy", true)
        Library.Remote:Fire("GamemodeSystem", "Start", "Time Trial", true)
    end)
end


local ttExitedDiffCooldown = {} -- Tracks completed difficulty cooldowns { [diff] = expiryTimestamp }
local ttCurrentActiveDiff = nil -- Currently running difficulty
local ttHasJoinedOnce = false

local function getSelectedTTDifficulties()
    local diffs = CFG.TTDifficulties or CFG.TTDifficulty
    if type(diffs) == "string" then
        return { diffs }
    elseif type(diffs) == "table" then
        local list = {}
        for _, d in pairs(diffs) do
            if type(d) == "string" and d ~= "" then
                table.insert(list, d)
            end
        end
        return #list > 0 and list or { "Easy" }
    end
    return { "Easy" }
end

local function getAvailableTimeTrialDiff()
    local gms = Library and Library.GamemodeService
    local pd = Library and Library.PlayerData
    local selected = getSelectedTTDifficulties()
    local nowTick = tick()

    -- Check each selected difficulty to find which one is currently OPEN & NOT on exit cooldown
    for _, diff in ipairs(selected) do
        -- 1. Check local session cooldown for this specific difficulty (Never re-enter until cooldown expires or new window)
        local exitCd = ttExitedDiffCooldown[diff]
        local isLocalCooldown = exitCd and (nowTick < exitCd)

        if not isLocalCooldown then
            local isOpen = true
            local timeLeft = 0
            if gms and gms.GetWindow then
                local success, win = pcall(function()
                    return gms.GetWindow("Time Trial", "The Hallway", diff)
                end)
                if success and win then
                    isOpen = win.Open == true
                    timeLeft = win.TimeLeft or 0
                end
            end

            -- Server-side cooldown check
            if isOpen and pd and pd.Gamemodes and pd.Gamemodes["Time Trial"] then
                local cd = pd.Gamemodes["Time Trial"].Cooldown
                if cd and nowTick < cd then
                    isOpen = false
                end
            end

            if isOpen then
                return diff -- Found an available difficulty ready to farm!
            end
        end
    end
    return nil
end

local function handleTimeTrialLoop(now)
    if not CFG.AutoTimeTrialDungeon then
        ttExitedDiffCooldown = {}
        ttCurrentActiveDiff = nil
        ttHasJoinedOnce = false
        return false
    end

    local inTT, ttFolder = isPlayerInTimeTrial()

    if not inTT then
        -- Outside Time Trial: look for any selected difficulty that is currently open & ready
        local openDiff = getAvailableTimeTrialDiff()
        if not openDiff then
            -- Neither difficulty is open right now, let player farm normal world while waiting!
            ttHasJoinedOnce = false
            return false
        end

        -- Teleport in ONCE (join the ready difficulty)
        if not ttHasJoinedOnce then
            if now - lastTimeTrialJoinAttempt >= 3.0 then
                lastTimeTrialJoinAttempt = now
                ttHasJoinedOnce = true
                ttCurrentActiveDiff = openDiff
                doJoinTimeTrial(openDiff)
            end
        end
        return false
    end

    -- Currently inside Time Trial dungeon!
    ttHasJoinedOnce = false

    if CFG.TTCustomExitStage then
        local currentStage = getCurrentGamemodeStage()
        if currentStage >= tonumber(CFG.TTExitStage) then
            if ttCurrentActiveDiff then
                -- Set 60-second cooldown for this specific difficulty so it won't re-enter, but can enter OTHER selected difficulties!
                ttExitedDiffCooldown[ttCurrentActiveDiff] = tick() + 60
            end
            if now - lastGamemodeExitAttempt >= 1.0 then
                lastGamemodeExitAttempt = now
                executeGamemodeQuit()
            end
            return true
        end
    end

    -- Target monsters inside Time Trial dungeon directly
    local gmEnemies = getGamemodeEnemies()
    if #gmEnemies > 0 then
        table.sort(gmEnemies, function(a, b) return a.HP < b.HP end)
        local target = gmEnemies[1]
        teleportToTarget(target.Part, target.UID)
        Library.Remote:Fire("ClickSystem", "Execute", { target.UID })
        Library.Remote:Fire("ClickSystem", "CastSkill", { target.UID })
    else
        -- Waiting for next room / wave in Time Trial - DO NOT attack overworld!
        currentLockedTargetUID = nil
    end
    return true
end

local lastInvasionJoinAttempt = 0

local function handleAutoMarineInvasion(now)
    if not CFG.AutoMarineInvasion then return false end
    local inInv = isPlayerInGamemode("Invasion") or isPlayerInGamemode("Marine Invasion")
    if not inInv then
        local gms = Library and Library.GamemodeService
        if gms and gms.GetWindow then
            local success, win = pcall(function()
                return gms.GetWindow("Invasion", "Marine Invasion", CFG.InvasionDifficulty or "Easy")
            end)
            if success and win and not win.Open then return false end
        end
        if now - lastInvasionJoinAttempt >= 5.0 then
            lastInvasionJoinAttempt = now
            pcall(function()
                Library.Remote:Fire("GamemodeSystem", "Enter", "Invasion", "Marine Invasion", CFG.InvasionDifficulty or "Easy", true)
            end)
        end
        return false
    end

    local gmEnemies = getGamemodeEnemies()
    if #gmEnemies > 0 then
        table.sort(gmEnemies, function(a, b) return a.HP < b.HP end)
        local target = gmEnemies[1]
        teleportToTarget(target.Part, target.UID)
        Library.Remote:Fire("ClickSystem", "Execute", { target.UID })
        Library.Remote:Fire("ClickSystem", "CastSkill", { target.UID })
    end
    return true
end


local lastRaidCreateAttempt = 0

local function handleAutoReturnHome()
    local pg = lp and lp:FindFirstChild("PlayerGui")
    local results = pg and pg:FindFirstChild("Results")
    if results and results.Enabled then
        local content = results:FindFirstChild("Content")
        local buttons = content and content:FindFirstChild("Buttons")
        local returnBtn = buttons and buttons:FindFirstChild("Return")
        if returnBtn then
            returnBtn.Visible = true
            pcall(function()
                if firesignal then
                    firesignal(returnBtn.MouseButton1Click)
                    firesignal(returnBtn.Activated)
                end
                if getconnections then
                    for _, conn in ipairs(getconnections(returnBtn.MouseButton1Click)) do
                        conn:Fire()
                    end
                    for _, conn in ipairs(getconnections(returnBtn.Activated)) do
                        conn:Fire()
                    end
                end
            end)
            pcall(function()
                local GuiService = Library and Library:GetService("GuiService")
                if GuiService then
                    GuiService.SetScreens(true, { "SideGUI", "Utils" }, true)
                end
            end)
            results.Enabled = false
        end
    end
end

local function handleAutoRaidLoop(now)
    if not CFG.AutoRaid then return false end

    -- Check and auto click Return on Results screen when not fighting inside raid
    if CFG.AutoReturnHome ~= false then
        handleAutoReturnHome()
    end

    local raidStatus, inMode = getRaidStatus()

    -- Case 1: Room is Created & Waiting to Start (Status == "Opened")
    if raidStatus == "Opened" then
        currentLockedTargetUID = nil -- Strictly DO NOT attack any overworld monster!
        if now - lastRaidStartAttempt >= 1.0 then
            lastRaidStartAttempt = now
            pcall(function()
                Library.Remote:Fire("GamemodeSystem", "Start", "Raid", true)
            end)
        end
        return true -- HANDLED! Room is starting, do not fall through!
    end

    -- Case 2: Room is Actively Running in Battle (Status == "Running")
    if raidStatus == "Running" then
        if CFG.RaidCustomExitRoom then
            local currentRoom = getCurrentGamemodeStage()
            local exitTarget = tonumber(CFG.RaidExitRoom) or 5
            if currentRoom >= exitTarget and currentRoom > 1 then
                if now - lastGamemodeExitAttempt >= 1.0 then
                    lastGamemodeExitAttempt = now
                    executeGamemodeQuit()
                end
                return true
            end
        end

        -- Target monsters inside Raid room directly
        local gmEnemies = getGamemodeEnemies()
        if #gmEnemies > 0 then
            table.sort(gmEnemies, function(a, b) return a.HP < b.HP end)
            local target = gmEnemies[1]
            currentLockedTargetUID = target.UID
            teleportToTarget(target.Part, target.UID)
            if CFG.AutoClick then
                Library.Remote:Fire("ClickSystem", "Execute", { target.UID })
            end
            if CFG.AutoCastSkill then
                Library.Remote:Fire("ClickSystem", "CastSkill", { target.UID })
            end
        else
            -- Waiting for next room / wave to spawn inside raid
            -- DO NOT target overworld monsters!
            currentLockedTargetUID = nil
        end
        return true
    end

    -- Case 3: Outside Raid (raidStatus == "None")
    -- If a room was just created, wait for server to teleport us into raid! Do not interrupt with ticket checks!
    if now - lastRaidCreateAttempt < 4.0 then
        currentLockedTargetUID = nil
        return true
    end

    local targetMap = CFG.RaidTargetMap or "DBZ"
    local tickets = getRaidTicketsCount(targetMap)

    -- 3A. Out of tickets!
    if tickets <= 0 then
        -- If user did NOT enable AutoFarmTicketIfNone, stop immediately! Do not farm and do not teleport!
        if not CFG.AutoFarmTicketIfNone then
            currentLockedTargetUID = nil
            return true -- Handled: Auto Raid is waiting for tickets. Do NOT farm!
        end

        local curMap = getCurrentMap()
        if curMap ~= targetMap then
            currentLockedTargetUID = nil
            if now - lastTeleportAttempt >= 2.5 then
                lastTeleportAttempt = now
                pcall(function()
                    Library.Remote:Fire("TeleportSystem", "To", targetMap)
                end)
            end
            return true -- Yield frame while teleporting into targetMap
        end

        -- Farm mid-tier sub-boss monster ONLY (รอง Secret Boss) for ticket drops in targetMap
        local target = getMidTierRaidTicketMonster(targetMap)
        if target then
            currentLockedTargetUID = target.UID
            teleportToTarget(target.Part, target.UID)
            if CFG.AutoClick then
                Library.Remote:Fire("ClickSystem", "Execute", { target.UID })
            end
            if CFG.AutoCastSkill then
                Library.Remote:Fire("ClickSystem", "CastSkill", { target.UID })
            end
        else
            -- Sub-boss is temporarily dead (respawning) - DO NOT TOUCH WEAK MOBS!
            currentLockedTargetUID = nil
        end
        return true
    end

    -- 3B. We have tickets! Create the raid room
    if now - lastRaidStartAttempt >= 3.0 then
        lastRaidStartAttempt = now
        lastRaidCreateAttempt = now
        pcall(function()
            Library.Remote:Fire("GamemodeSystem", "Create", "Raid", targetMap, "Easy", false, true)
        end)
    end
    return true
end

local function handleAutoPortalLoop(now)
    if not CFG.AutoPortal then return false end
    local inPortal, portalFolder = isPlayerInPortal()

    if inPortal then
        local uid, part = selectTargetEnemy()
        if part and uid then
            teleportToTarget(part, uid)
            Library.Remote:Fire("ClickSystem", "Execute", { uid })
            Library.Remote:Fire("ClickSystem", "CastSkill", { uid })
        end
        return true
    end

    if now - lastPortalTick < 5.0 then return false end
    lastPortalTick = now

    local pd = Library and Library.PlayerData
    local items = pd and pd.Items or {}

    local tierOrder = {"Rank S", "Rank A", "Rank B", "Rank C"}
    if CFG.PortalSelectedTier and CFG.PortalSelectedTier ~= "All" then
        tierOrder = { CFG.PortalSelectedTier }
    end

    for _, tierName in ipairs(tierOrder) do
        local itemName = "Portal" .. tierName:gsub(" ", "")
        if (items[itemName] or 0) > 0 then
            Library.Remote:Fire("GamemodeSystem", "Enter", "Portal", tierName, "Easy", true)
            return true
        end
    end
    return false
end

local function handleAutoRankUp(now)
    if not CFG.AutoRankUp then return end
    if now - lastRankUp < 1.0 then return end
    lastRankUp = now

    local pd = Library and Library.PlayerData
    if not (pd and Library.Remote) then return end

    local shouldRebirth = true
    pcall(function()
        local rData = Library.GetData and Library:GetData("RebirthData")
        if rData and rData.Rank and rData.Rank.Types and rData.Rank.Types.Energy then
            local curLvl = (pd.Rebirth and pd.Rebirth.Rank_Energy) or 0
            local nextLvl = rData.Rank.Types.Energy.Levels[curLvl + 1]
            if nextLvl and nextLvl.Price then
                local currentEnergy = pd.Energy or (pd.Items and pd.Items.Energy) or 0
                if currentEnergy < nextLvl.Price then
                    shouldRebirth = false
                end
            elseif curLvl >= (rData.Rank.Types.Energy.MaxLevel or 20) then
                shouldRebirth = false
            end
        end
    end)

    if shouldRebirth then
        pcall(function()
            Library.Remote:Fire("RebirthSystem", "Release", "Rank", "Energy")
        end)
    end
end

local function getEquippedRaceInfo()
    local pd = Library and Library.PlayerData
    if not pd then return "Earthling", 1 end
    local equippedGacha = pd.GachaEquipped and pd.GachaEquipped[1]
    if not equippedGacha and pd.Gacha then
        for id, data in pairs(pd.Gacha) do
            if data.Equipped and id:find("Race") then
                equippedGacha = id
                break
            end
        end
    end

    local orderNum = 1
    if equippedGacha then
        local match = string.match(equippedGacha, "(%d+)$")
        if match then orderNum = tonumber(match) end
    end

    local raceNames = {
        [1] = "Earthling",
        [2] = "Namekian",
        [3] = "Majin",
        [4] = "Saiyan",
        [5] = "Frieza",
        [6] = "Angel"
    }
    local raceRarities = {
        [1] = 1, -- Common
        [2] = 2, -- Rare
        [3] = 3, -- Epic
        [4] = 4, -- Legendary
        [5] = 5, -- Mythical
        [6] = 6  -- Secret
    }
    return raceNames[orderNum] or "Earthling", raceRarities[orderNum] or 1
end

local function handleAutoRaceSpin(now)
    if not CFG.AutoRaceSpin then return end
    if now - lastRaceSpin < 0.5 then return end
    lastRaceSpin = now

    local pd = Library and Library.PlayerData
    if not (pd and Library.Remote) then return end

    local raceName, raceRarity = getEquippedRaceInfo()
    local targetThreshold = RARITY_LEVEL[CFG.RaceStopRarity] or 5

    -- Stop spinning if current race rarity >= threshold
    if raceRarity >= targetThreshold then
        return
    end

    local items = pd.Items or {}
    local raceCoins = items["RaceCoins"] or 0
    if raceCoins >= 20 then
        -- Correct remote signature: Category="Race", Type="Default"
        pcall(function()
            Library.Remote:Fire("GachaSystem", "Spin", "Race", "Default", {}, nil)
        end)
    end
end

-- BEGIN SRC2 BALANCED UPGRADE MERGE
local UPGRADE_SYSTEM_DATA = {
    ["Warrior Upgrades"] = {
        Currency = "WarriorCoins",
        Targets = {
            Energy      = { MaxLevel = 20 },
            Damage      = { MaxLevel = 20 },
            Gold        = { MaxLevel = 20 },
            AttackRange = { MaxLevel = 12 }
        }
    },
    ["Offline Upgrades"] = {
        Currency = "OfflineCoins",
        Targets = {
            Energy  = { MaxLevel = 20 },
            Gold    = { MaxLevel = 20 },
            MaxTime = { MaxLevel = 20 }
        }
    },
    ["Time Trial Upgrades"] = {
        Currency = "TrialShards",
        Targets = {
            Energy = { MaxLevel = 20 },
            Damage = { MaxLevel = 20 },
            Gold   = { MaxLevel = 20 },
            AtkSPD = { MaxLevel = 10 }
        }
    },
    ["Portal Upgrades"] = {
        Currency = "PortalCoins",
        Targets = {
            Energy            = { MaxLevel = 10 },
            Damage            = { MaxLevel = 10 },
            MaxEnemy          = { MaxLevel = 5 },
            WarriorDropChance = { MaxLevel = 5 }
        }
    },
    ["Class Tree"] = {
        Currency = "ClassCoins",
        Targets = {
            Start      = { MaxLevel = 1 },
            Energy     = { MaxLevel = 15 },
            Damage     = { MaxLevel = 15 },
            Gold       = { MaxLevel = 15 },
            CritChance = { MaxLevel = 10 },
            CritDMG    = { MaxLevel = 10 },
            WalkSPD    = { MaxLevel = 10 }
        }
    }
}

-- Upgrade metadata and single-level purchases are merged from src 2.
local UPGRADE_SYSTEM_NAMES = {
    "Warrior Upgrades", "Offline Upgrades", "Time Trial Upgrades",
    "Portal Upgrades", "Class Tree"
}

local UpgradeServiceRef = nil
if Library and type(Library.GetService) == "function" then
    local ok, service = pcall(function() return Library:GetService("UpgradeService") end)
    if ok then UpgradeServiceRef = service end
end

-- Try the module separately: an unavailable Library:GetService must not
-- prevent the module fallback or the live UpgradeData overrides.
pcall(function()
    local framework = ReplicatedStorage:FindFirstChild("Framework")
    local modules = framework and framework:FindFirstChild("Modules")
    local services = modules and modules:FindFirstChild("Services")
    local serviceModule = services and services:FindFirstChild("UpgradeService")
    if not UpgradeServiceRef and serviceModule then
        UpgradeServiceRef = require(serviceModule)
    end
end)

pcall(function()
    local framework = ReplicatedStorage:FindFirstChild("Framework")
    local modules = framework and framework:FindFirstChild("Modules")
    local dataDir = modules and modules:FindFirstChild("Data")
    local dataModule = dataDir and dataDir:FindFirstChild("UpgradeData")
    if not dataModule then return end
    local rawData = require(dataModule)
    if type(rawData) ~= "table" then return end
    for systemName, systemData in pairs(rawData) do
        if type(systemData) == "table" and type(systemData.Targets) == "table" then
            local config = UPGRADE_SYSTEM_DATA[systemName] or { Targets = {} }
            config.Currency = systemData.Currency or config.Currency
            for stat, targetData in pairs(systemData.Targets) do
                if type(targetData) == "table" then
                    local fallback = config.Targets[stat] or {}
                    config.Targets[stat] = {
                        MaxLevel = tonumber(targetData.MaxLevel) or fallback.MaxLevel or 999,
                        Currency = targetData.Currency or systemData.Currency or fallback.Currency
                    }
                end
            end
            UPGRADE_SYSTEM_DATA[systemName] = config
        end
    end
end)

local UpgradeRequestState = {}

local function getUpgradeLevel(upgrades, systemName, stat)
    local entry = upgrades[systemName .. "_" .. stat]
    if type(entry) == "table" then entry = entry.Level end
    return tonumber(entry) or 0
end

local function normalizeUpgradeSystems()
    local selected = CFG.SelectedGlobalUpgrades
    if type(selected) ~= "table" then selected = UPGRADE_SYSTEM_NAMES end
    local normalized = {}
    for _, systemName in ipairs(UPGRADE_SYSTEM_NAMES) do
        if table.find(selected, systemName) then
            table.insert(normalized, systemName)
        end
    end
    -- src 1 saved stat names here; src 2 selects named upgrade systems.
    -- Migrate old, non-empty stat selections to the all-systems selection.
    if #normalized == 0 and #selected > 0 then
        for _, stat in ipairs(selected) do
            if stat == "Energy" or stat == "Damage" or stat == "CritChance"
                or stat == "CritDamage" or stat == "CritDMG" then
                for _, systemName in ipairs(UPGRADE_SYSTEM_NAMES) do
                    table.insert(normalized, systemName)
                end
                break
            end
        end
    end
    CFG.SelectedGlobalUpgrades = normalized
    if CFG.BalanceGlobalUpgrades == nil then CFG.BalanceGlobalUpgrades = true end
    return normalized
end

local function buyBalancedUpgrade(systemName, targetList, now, buyMax)
    local pd = Library and Library.PlayerData
    if not (pd and Library.Remote) then return false end
    local upgrades, items = pd.Upgrades, pd.Items
    if type(upgrades) ~= "table" or type(items) ~= "table" then return false end
    local config = UPGRADE_SYSTEM_DATA[systemName]
    if not (config and config.Targets) then return false end
    now = type(now) == "number" and now or os.clock()

    local targets, seen = {}, {}
    if targetList == nil then
        for stat in pairs(config.Targets) do table.insert(targets, stat) end
        table.sort(targets)
    elseif type(targetList) == "table" then
        for _, stat in ipairs(targetList) do
            if config.Targets[stat] and not seen[stat] then
                seen[stat] = true
                table.insert(targets, stat)
            end
        end
    end
    if #targets == 0 then return false end

    local state = UpgradeRequestState[systemName]
    if not state then
        state = { NextIndex = 1 }
        UpgradeRequestState[systemName] = state
    end
    -- Warrior/Offline/TT and the global toggle can request the same system.
    -- Give it one request slot, even when the server updates immediately.
    if state.LastSentAt and now - state.LastSentAt < 0.35 then return false end
    if state.PendingStat then
        local current = getUpgradeLevel(upgrades, systemName, state.PendingStat)
        if current == state.PendingLevel and now - state.PendingAt < 1.5 then
            return false
        end
        -- A changed level confirms completion. An unconfirmed request may be
        -- retried after the timeout; the tie cursor lets other equal stats try.
        state.PendingStat = nil
    end

    local candidateStat, candidateIndex = nil, nil
    local minLevel = math.huge
    local start = ((state.NextIndex or 1) - 1) % #targets + 1
    for offset = 0, #targets - 1 do
        local index = (start + offset - 1) % #targets + 1
        local stat = targets[index]
        local target = config.Targets[stat]
        local level = getUpgradeLevel(upgrades, systemName, stat)
        local maxLevel = tonumber(target.MaxLevel) or 999
        if level < maxLevel then
            local unlocked = true
            if UpgradeServiceRef and type(UpgradeServiceRef.IsUnlocked) == "function" then
                local ok, value = pcall(function()
                    return UpgradeServiceRef.IsUnlocked(pd, systemName, stat)
                end)
                if ok then unlocked = value end
            end
            if unlocked then
                local price = nil
                if UpgradeServiceRef and type(UpgradeServiceRef.CalculatePrice) == "function" then
                    local ok, value = pcall(function()
                        return UpgradeServiceRef.CalculatePrice(systemName, stat, level)
                    end)
                    if ok then price = tonumber(value) end
                end
                local currency = target.Currency or config.Currency
                local balance = tonumber(items[currency]) or 0
                if (price == nil or balance >= price) and level < minLevel then
                    minLevel = level
                    candidateStat, candidateIndex = stat, index
                end
            end
        end
    end
    if not candidateStat then return false end

    state.PendingStat = candidateStat
    state.PendingLevel = minLevel
    state.PendingAt = now
    state.LastSentAt = now
    state.NextIndex = candidateIndex % #targets + 1
    local ok = pcall(function()
        if buyMax == true then
            -- Only the explicitly disabled Global Balance mode buys max.
            Library.Remote:Fire("UpgradeSystem", "Buy", systemName, candidateStat, true)
        else
            Library.Remote:Fire("UpgradeSystem", "Buy", systemName, candidateStat)
        end
    end)
    if not ok then state.PendingStat = nil end
    return ok
end

local function handleAutoGlobalUpgrades(now)
    if not CFG.AutoUpgrade or now - lastUpgrade < 0.4 then return end
    lastUpgrade = now
    for _, systemName in ipairs(normalizeUpgradeSystems()) do
        buyBalancedUpgrade(systemName, nil, now, CFG.BalanceGlobalUpgrades == false)
    end
end

-- END SRC2 BALANCED UPGRADE MERGE

local function handleAutoWarriorUpgrade(now)
    if not CFG.AutoUpgradeWarrior then return end
    if now - lastWarriorUp < 0.4 then return end
    lastWarriorUp = now

    local priority = CFG.WarriorUpgradePriority
    if priority == "All (Balanced)" then
        buyBalancedUpgrade("Warrior Upgrades", {"Energy", "Damage", "Gold", "AttackRange"}, now)
    else
        buyBalancedUpgrade("Warrior Upgrades", {priority}, now)
    end
end

local lastTitanSpin = 0
local lastHarborTick = 0
local lastCommandmentTick = 0
local lastJewelTick = 0

local function handleAutoTitanSpin(now)
    if not CFG.AutoTitanSpin then return end
    if now - lastTitanSpin < 0.6 then return end
    lastTitanSpin = now
    pcall(function()
        Library.Remote:Fire("GachaSystem", "Spin", "Titan", "Default", {}, nil)
    end)
end

local function handleAutoWeaponSpins(now)
    if not CFG.AutoWeaponSummon and not CFG.AutoWeaponPassive then return end
    if now - lastWeaponSpin < 0.8 then return end
    lastWeaponSpin = now

    local pd = Library and Library.PlayerData
    local items = pd and pd.Items or {}

    if CFG.AutoWeaponSummon and (items["WeaponCoinsT1"] or 0) > 0 then
        Library.Remote:Fire("GachaSystem", "Spin", "Weapon", "T1", {}, nil)
    end

    if CFG.AutoWeaponPassive and (items["WeaponPassiveCoins"] or 0) > 0 then
        -- Check if current weapon has matching target passive (Auto Lock)
        local target = CFG.TargetWeaponPassive or "Any"
        if target ~= "Any" and pd and pd.Equipped then
            local eqWepId = pd.Equipped.Weapon
            local wepData = eqWepId and pd.Weapons and pd.Weapons[eqWepId]
            local curPassive = wepData and (wepData.Passive or wepData.WeaponPassive or wepData.Skill)
            if curPassive and tostring(curPassive):lower():find(target:lower()) then
                CFG.AutoWeaponPassive = false -- Matched! Lock & stop spinning
                return
            end
        end
        Library.Remote:Fire("GachaSystem", "Spin", "WeaponPassive", "OnePiece", {}, nil)
    end
end

local function handleAutoHeroPassive(now)
    if not CFG.AutoHeroPassive then return end
    if now - lastHeroPassive < 0.8 then return end
    lastHeroPassive = now

    local pd = Library and Library.PlayerData
    local items = pd and pd.Items or {}

    if (items["HeroPassiveCoins"] or 0) > 0 then
        local target = CFG.TargetHeroPassive or "Any"
        if target ~= "Any" and pd then
            local curHeroPassive = pd.HeroPassive or (pd.Hero and pd.Hero.Passive)
            if curHeroPassive and tostring(curHeroPassive):lower():find(target:lower()) then
                CFG.AutoHeroPassive = false -- Matched! Lock & stop spinning
                return
            end
        end
        Library.Remote:Fire("GachaSystem", "Spin", "Hero Passive", "AOT", {}, nil)
    end
end

local function handleAutoOfflineUpgrades(now)
    if not CFG.AutoOfflineUpgrades then return end
    if now - lastOfflineUp < 0.45 then return end
    lastOfflineUp = now

    buyBalancedUpgrade("Offline Upgrades", {"Energy", "Gold", "MaxTime"}, now)
end

local function doEquipBestTitle()
    local pd = Library and Library.PlayerData
    if not (pd and pd.Titles) then return end
    local bestId = nil
    local bestOrder = -1
    for titleId, val in pairs(pd.Titles) do
        if val == true or type(val) == "table" then
            local order = tonumber(tostring(titleId):match("%d+")) or 1
            if order > bestOrder then
                bestOrder = order
                bestId = titleId
            end
        end
    end
    if bestId then
        Library.Remote:Fire("TitleSystem", "Equip", "Boost", bestId)
        Library.Remote:Fire("TitleSystem", "Equip", "Visual", bestId)
    end
end

-- isItemInList defined earlier

local lastInventoryCounts = {}

-- Checks if a category's item count or contents changed before re-equipping
local function hasCategoryChanged(cat, force)
    if force then return true end
    local pd = Library and Library.PlayerData
    if not pd then return false end
    local list = pd[cat .. "s"] or pd[cat]
    if not list or type(list) ~= "table" then return false end

    local count = 0
    for _ in pairs(list) do
        count = count + 1
    end

    if lastInventoryCounts[cat] ~= count then
        lastInventoryCounts[cat] = count
        return true -- New item acquired or inventory changed!
    end
    return false -- Same inventory, do not spam remote!
end

local hasEquippedAccessoryOnce = false

local function doEquipBestCategories(force)
    if not (Library and Library.Remote) then return end

    if CFG.AutoEquipBest and (force or hasCategoryChanged("GlobalBoost", force)) then
        pcall(function()
            Library.Remote:Fire("EquipBestSystem", "Apply", CFG.AutoEquipBoost or "Energy")
        end)
    end

    local cats = { "Weapon", "Warrior", "Avatar", "Accessory", "Mount", "Jewel", "Wing", "DevilFruit", "Crewmate", "Amulet" }
    for _, cat in ipairs(cats) do
        if isItemInList(CFG.EquipBestCategories, cat) then
            if cat == "Accessory" then
                -- Accessory only equips once unless a new accessory is obtained in inventory
                if not hasEquippedAccessoryOnce or hasCategoryChanged("Accessory", force) then
                    hasEquippedAccessoryOnce = true
                    pcall(function()
                        Library.Remote:Fire("InventorySystem", "EquipBest", "Accessory")
                    end)
                end
            else
                if hasCategoryChanged(cat, force) then
                    pcall(function()
                        Library.Remote:Fire("InventorySystem", "EquipBest", cat)
                    end)
                end
            end
        end
    end

    if CFG.EquipBestTitle and (force or hasCategoryChanged("Title", force)) then
        pcall(doEquipBestTitle)
    end
end

local TT_POTION_MAP = {
    ["Energy Potion I (200)"] = "EnergyPotion1",
    ["Damage Potion I (200)"] = "DamagePotion1",
    ["Gold Potion I (200)"]   = "GoldPotion1",
    ["Luck Potion I (300)"]   = "LuckPotion1",
    ["Drop Potion I (400)"]   = "DropPotion1",
    ["Energy Potion II (500)"] = "EnergyPotion2",
    ["Damage Potion II (500)"] = "DamagePotion2",
    ["Gold Potion II (500)"]   = "GoldPotion2",
    ["Luck Potion II (600)"]   = "LuckPotion2",
    ["Drop Potion II (1000)"]  = "DropPotion2"
}

local TT_UPGRADE_MAP = {
    ["Breaker (Damage +5%)"]    = "Damage",
    ["Relentless (Energy +5%)"]  = "Energy",
    ["Scavenger (Gold +5%)"]     = "Gold",
    ["Overdrive (AtkSPD +2.5%)"] = "AtkSPD"
}

local PIRATE_JUICE_MAP = {
    ["Energy Juice I (1000)"] = "EnergyJuice1",
    ["Damage Juice I (1000)"] = "DamageJuice1",
    ["Gold Juice I (1000)"]   = "GoldJuice1",
    ["Drop Juice I (1000)"]   = "DropJuice1",
    ["Luck Juice I (1000)"]   = "LuckJuice1"
}

local function doTimeTrialShopBuy()
    if not (Library and Library.Remote) then return end
    local selected = CFG.TTSelectedPotionNames
    if not selected or type(selected) ~= "table" then return end
    local amt = CFG.TTShopBuyAmount or 1
    for name, id in pairs(TT_POTION_MAP) do
        if isItemInList(selected, name) then
            pcall(function()
                Library.Remote:Fire("StockShopSystem", "Buy", "Time Trial", id, amt)
            end)
        end
    end
end

local function doPirateShopBuy()
    if not (Library and Library.Remote) then return end
    local amt = CFG.PirateShopBuyAmount or 1
    for name, id in pairs(PIRATE_JUICE_MAP) do
        if isItemInList(CFG.PirateSelectedJuiceNames, name) or isItemInList(CFG.PirateShopSelection, id) then
            pcall(function()
                Library.Remote:Fire("StockShopSystem", "Buy", "Pirate", id, amt)
            end)
        end
    end
end

local function doTimeTrialUpgrade(now)
    if not (Library and Library.Remote) then return end
    local selected = CFG.TTSelectedUpgradeNames or {}
    local targets = {}
    for name, key in pairs(TT_UPGRADE_MAP) do
        if isItemInList(selected, name) then
            table.insert(targets, key)
        end
    end
    table.sort(targets)
    if #targets > 0 then
        buyBalancedUpgrade("Time Trial Upgrades", targets, now)
    end
end



local function doMergeAll()
    pcall(function()
        if not (Library and Library.Remote) then return end
        for _, category in ipairs({"Weapon", "Wing", "Pet", "Warrior", "Avatar"}) do
            Library.Remote:Fire("MergeSystem", "MakeAll", category)
        end
    end)
end

local function doAutoCraft()
    pcall(function()
        if not (Library and Library.Remote) then return end
        for cat, list in pairs(CRAFT_ITEMS) do
            if CFG.CraftSelection and CFG.CraftSelection[cat] then
                for tier = 1, math.min(#list, CFG.CraftMaxTier or 6) do
                    Library.Remote:Fire("ExchangeSystem", "Make", "Crafting", cat, list[tier], 1)
                end
            end
        end
        Library.Remote:Fire("JewelSystem", "ClaimAll")
    end)
end

local function doClaimLikeRewards()
    pcall(function()
        Library.Remote:Fire("LikeRewardSystem", "ClaimAll", true)
        for i = 1, 20 do
            Library.Remote:Fire("LikeRewardSystem", "Claim", i, true)
        end
    end)
end

local function doClaimAll()
    pcall(function()
        doClaimLikeRewards()
        Library.Remote:Fire("AchievementSystem", "ClaimAll", true)
        Library.Remote:Fire("DailyRewardSystem", "ClaimAll", true)
        Library.Remote:Fire("IndexSystem", "ClaimAll", true)
        for _, chest in ipairs({"VIPChest","PremiumChest","GroupChest"}) do
            Library.Remote:Fire("ChestSystem", "Claim", chest, true)
        end
        for _, bp in ipairs({"Release","BloodRed"}) do
            Library.Remote:Fire("BattlepassSystem", "ClaimAll", bp, true)
        end
    end)
end

local function doRedeemAllCodes()
    if not (Library and Library.Remote) then return end
    for _, code in ipairs(PROMO_CODES) do
        local ok, reason = pcall(function()
            Library.Remote:Fire("CodeSystem", "Redeem", code)
        end)
        if not ok then warn("[Axel Hub Codes] " .. tostring(reason)) end
        task.wait(0.15)
    end
end

local function doRejoinCurrent()
    local ok, reason = pcall(function()
        if tostring(game.JobId or "") ~= "" then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, lp)
        else
            TeleportService:Teleport(game.PlaceId, lp)
        end
    end)
    if not ok then warn("[Axel Hub Rejoin] " .. tostring(reason)) end
end

local function doServerHop()
    local cursor = nil
    for _ = 1, 3 do
        local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId)
            .. "/servers/Public?sortOrder=Asc&limit=100"
            .. (cursor and ("&cursor=" .. HttpService:UrlEncode(cursor)) or "")
        local ok, response = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(url))
        end)
        if not ok or type(response) ~= "table" then break end
        for _, server in ipairs(response.data or {}) do
            if server.id and server.id ~= game.JobId
                and (tonumber(server.playing) or math.huge) < (tonumber(server.maxPlayers) or 0) then
                local moved, reason = pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, lp)
                end)
                if not moved then warn("[Axel Hub Server Hop] " .. tostring(reason)) end
                return
            end
        end
        cursor = response.nextPageCursor
        if not cursor then break end
    end
    warn("[Axel Hub Server Hop] No different public server was found.")
end

local function doAutoSell()
    if not CFG.AutoSell then return end
    local pd = Library and Library.PlayerData
    if not (pd and Library.Remote) then return end
    local sellRarities = CFG.SellSelectedRarities or {}
    local categories = {
        { Key = "Pet",       Plural = "Pets",        List = pd.Pets },
        { Key = "Weapon",    Plural = "Weapons",     List = pd.Weapons },
        { Key = "Wing",      Plural = "Wings",       List = pd.Wings },
        { Key = "Avatar",    Plural = "Avatars",     List = pd.Avatars },
        { Key = "Accessory", Plural = "Accessories", List = pd.Accessories },
        { Key = "Warrior",   Plural = "Warriors",    List = pd.Warriors },
        { Key = "Mount",     Plural = "Mounts",      List = pd.Mounts },
        { Key = "Jewel",     Plural = "Jewels",      List = pd.Jewels }
    }
    for _, cat in ipairs(categories) do
        if cat.List and (CFG.AutoSell or isItemInList(CFG.DeleteTargetCategories, cat.Plural)) then
            local toUnlock = {}
            local toSell = {}
            for uid, v in pairs(cat.List) do
                if not v.Equipped then
                    local rOrder = getRarityOrder(v.Id or uid)
                    local rName = ALL_RARITY_NAMES[rOrder] or "Common"
                    if isItemInList(sellRarities, rName) then
                        -- High rarity items are auto-locked by the game; unlock first!
                        if v.Locked then
                            table.insert(toUnlock, uid)
                        end
                        table.insert(toSell, uid)
                    end
                end
            end

            -- 1. Unlock locked items first
            if #toUnlock > 0 then
                pcall(function()
                    Library.Remote:Fire("InventorySystem", "Lock", cat.Key, Library:Encode(toUnlock))
                end)
            end

            -- 2. Execute sell and delete
            if #toSell > 0 then
                task.spawn(function()
                    if #toUnlock > 0 then task.wait(0.15) end
                    pcall(function()
                        Library.Remote:Fire("InventorySystem", "Sell", cat.Key, Library:Encode(toSell))
                    end)
                    pcall(function()
                        Library.Remote:Fire("InventorySystem", "Delete", cat.Key, Library:Encode(toSell))
                    end)
                end)
            end
        end
    end
end

local function doAutoDelete()
    local pd = Library and Library.PlayerData
    if not (pd and Library.Remote) then return end

    local categories = {
        { Key = "Pet",       Plural = "Pets",        Data = pd.Pets,        TKey = "AutoDeletePets",        RMap = RarityToggles.Pet },
        { Key = "Weapon",    Plural = "Weapons",     Data = pd.Weapons,     TKey = "AutoDeleteWeapons",     RMap = RarityToggles.Weapon },
        { Key = "Wing",      Plural = "Wings",       Data = pd.Wings,       TKey = "AutoDeleteWings",       RMap = RarityToggles.Wing },
        { Key = "Avatar",    Plural = "Avatars",     Data = pd.Avatars,     TKey = "AutoDeleteAvatars",     RMap = RarityToggles.Avatar },
        { Key = "Accessory", Plural = "Accessories", Data = pd.Accessories, TKey = "AutoDeleteAccessories", RMap = RarityToggles.Accessory },
        { Key = "Warrior",   Plural = "Warriors",    Data = pd.Warriors,    TKey = "AutoDeleteWarriors",    RMap = RarityToggles.Warrior },
        { Key = "Mount",     Plural = "Mounts",      Data = pd.Mounts,      TKey = "AutoDeleteMounts",      RMap = RarityToggles.Mount },
        { Key = "Jewel",     Plural = "Jewels",      Data = pd.Jewels,      TKey = "AutoDeleteJewels",      RMap = RarityToggles.Jewel }
    }

    for _, c in ipairs(categories) do
        -- Strictly check if this category's toggle is enabled
        if c.Data and (CFG[c.TKey] == true) then
            local toUnlock = {}
            local toDelete = {}
            for uid, v in pairs(c.Data) do
                if not v.Equipped then
                    local rOrder = getRarityOrder(v.Id or uid)
                    local rName = ALL_RARITY_NAMES[rOrder] or "Common"
                    -- Only delete if the user specifically checked this rarity in the category's multi-dropdown
                    local shouldDelete = (c.RMap and c.RMap[rName] == true)
                    if shouldDelete then
                        if v.Locked then
                            table.insert(toUnlock, uid)
                        end
                        table.insert(toDelete, uid)
                    end
                end
            end

            -- 1. Unlock locked items first
            if #toUnlock > 0 then
                pcall(function()
                    Library.Remote:Fire("InventorySystem", "Lock", c.Key, Library:Encode(toUnlock))
                end)
            end

            -- 2. Execute deletion
            if #toDelete > 0 then
                task.spawn(function()
                    if #toUnlock > 0 then task.wait(0.15) end
                    pcall(function()
                        Library.Remote:Fire("InventorySystem", "Delete", c.Key, Library:Encode(toDelete))
                    end)
                end)
            end
        end
    end
end

-- ══════════════════════════════════════════════════════════
-- MAIN HEARTBEAT LOOP (STRICT PRIORITY HIERARCHY)
-- ══════════════════════════════════════════════════════════
_G.AnimeBreaker_HeartbeatConnection = RunService.Heartbeat:Connect(function()
    local now = tick()

    -- 0. Instant Return on Results Screen (Skip Game Result countdown)
    if CFG.AutoReturnHome ~= false then
        handleAutoReturnHome()
    end

    -- 1. Player Movement & Hacks (Dash Hack & Infinite Health)
    local hum = getHum()
    local root = getRoot()
    if hum and root then
        if CFG.DashHack then
            local lv = root:FindFirstChildOfClass("LinearVelocity") or root:FindFirstChild("DashVelocity")
            if lv then
                local dir = (hum.MoveDirection.Magnitude > 0) and hum.MoveDirection or root.CFrame.LookVector
                if lv:IsA("LinearVelocity") then
                    lv.VectorVelocity = dir * (CFG.DashSpeed or 150)
                elseif lv:IsA("BodyVelocity") then
                    lv.Velocity = dir * (CFG.DashSpeed or 150)
                end
            end
        end
        if CFG.InfHealth then
            hum.Health = hum.MaxHealth
        end
    end

    -- 2. PRIORITY 1: TIME TRIAL DUNGEON
    if handleTimeTrialLoop(now) then
        return
    end

    -- 3. PRIORITY 2: AUTO RAID
    if handleAutoRaidLoop(now) then
        return
    end

    -- 4. PRIORITY 3: AUTO PORTAL
    if handleAutoPortalLoop(now) then
        return
    end

    -- 5. PRIORITY 4: NORMAL ZONE FARMING, WALL & QUESTS
    local wallHandled = handleSmartWallBreaking(now)

    if not wallHandled and CFG.AutoFarm then
        local uid, part = selectTargetEnemy()
        teleportToTarget(part, uid)
    end

    -- Auto Click
    if CFG.AutoClick and (now - lastClick >= CFG.ClickDelay) then
        lastClick = now
        local clickTgt = currentLockedTargetUID and { currentLockedTargetUID } or Library.Target
        Library.Remote:Fire("ClickSystem", "Execute", clickTgt)
    end

    -- Auto Cast Skill
    if CFG.AutoCastSkill and (now - lastClick >= 0.2) then
        local skillTgt = currentLockedTargetUID and { currentLockedTargetUID } or Library.Target
        Library.Remote:Fire("ClickSystem", "CastSkill", skillTgt)
    end

    -- Auto Quests
    handleAutoQuests(now)

    -- Balanced System Unlocker
    if CFG.BalancedUnlocker then
        handleBalancedUnlocks(now)
    end

    -- Automated Background Systems
    handleAutoRankUp(now)
    handleAutoRaceSpin(now)
    handleAutoWarriorUpgrade(now)
    handleAutoWeaponSpins(now)
    handleAutoHeroPassive(now)
    handleAutoOfflineUpgrades(now)

    -- Auto Summon
    if CFG.AutoSummon and (now - lastSummonTick >= 0.5) then
        lastSummonTick = now
        doAutoSummon()
    end

    -- Auto Titan
    handleAutoTitanSpin(now)

    -- Auto Harbor (Expedition)
    if CFG.AutoHarbor and (now - lastHarborTick >= 5.0) then
        lastHarborTick = now
        pcall(function()
            Library.Remote:Fire("ExpeditionSystem", "Claim", "Harbor")
            Library.Remote:Fire("ExpeditionSystem", "Start", "Harbor")
        end)
    end

    -- Auto Collect Commandments
    if CFG.AutoCommandments and (now - lastCommandmentTick >= 2.0) then
        lastCommandmentTick = now
        pcall(function()
            Library.Remote:Fire("SpawnItemSystem", "CollectAll")
        end)
    end



    -- Auto Marine Invasion
    if CFG.AutoMarineInvasion then
        handleAutoMarineInvasion(now)
    end

    -- All selected systems share the single-level upgrade engine.
    handleAutoGlobalUpgrades(now)

    -- Time Trial Upgrades & Shop
    if CFG.AutoUpgradeTT and (now - lastTTUpgrade >= 0.45) then
        lastTTUpgrade = now
        doTimeTrialUpgrade(now)
    end
    if CFG.AutoBuyTTShop and (now - lastTTShopBuy >= 3.0) then
        lastTTShopBuy = now
        doTimeTrialShopBuy()
    end
    if CFG.AutoBuyPirateShop and (now - lastPirateShopBuy >= 3.0) then
        lastPirateShopBuy = now
        doPirateShopBuy()
    end

    -- Merge & Crafting
    if CFG.AutoMergeAll and (now - lastMerge >= 2.0) then
        lastMerge = now
        doMergeAll()
    end
    if CFG.AutoCraft and (now - lastMerge >= 3.0) then
        doAutoCraft()
    end

    -- Equip Best
    if (CFG.AutoEquipBest or CFG.EquipBestAvatar or CFG.EquipBestWeapon or CFG.EquipBestTitle) and (now - lastEquipBest >= 3.0) then
        lastEquipBest = now
        doEquipBestCategories()
    end

    -- Auto Claims
    if CFG.AutoClaimAll and (now - lastClaim >= 5.0) then
        lastClaim = now
        doClaimAll()
    end
    if CFG.AutoClaimLikeRewards and (now - lastLikeClaim >= 10.0) then
        lastLikeClaim = now
        doClaimLikeRewards()
    end

    -- Auto Delete / Clean (Only runs if a category clean toggle is enabled)
    local anyCleanEnabled = CFG.AutoDeletePets or CFG.AutoDeleteWeapons or CFG.AutoDeleteWings
        or CFG.AutoDeleteAvatars or CFG.AutoDeleteAccessories or CFG.AutoDeleteWarriors
        or CFG.AutoDeleteMounts or CFG.AutoDeleteJewels or CFG.AutoSell

    if anyCleanEnabled and (now - lastSell >= 2.0) then
        lastSell = now
        doAutoDelete()
    end
end)

-- ══════════════════════════════════════════════════════════
-- AXELUI SETUP
-- ══════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════
-- CONFIGURATION MANAGER ENGINE (SAVE / AUTO-LOAD / LOAD / CREATE / DELETE)
-- ══════════════════════════════════════════════════════════
local AxelHubUI
local CONFIG_FOLDER = "AnimeBreakerConfigs"
if makefolder and isfolder and not isfolder(CONFIG_FOLDER) then
    pcall(makefolder, CONFIG_FOLDER)
end

local function getSavedConfigsList()
    local list = { "default" }
    if listfiles and isfolder and isfolder(CONFIG_FOLDER) then
        local files = listfiles(CONFIG_FOLDER)
        for _, file in ipairs(files) do
            local name = file:match("([^/\\\?%*%%:]+)%.json$")
            if name and not table.find(list, name) then
                table.insert(list, name)
            end
        end
    end
    return list
end

local function saveConfigFile(name)
    name = (name and name ~= "") and name or (CFG.SelectedConfigName or "default")
    if not writefile then return end
    if isfolder and not isfolder(CONFIG_FOLDER) then pcall(makefolder, CONFIG_FOLDER) end
    local filePath = CONFIG_FOLDER .. "/" .. name .. ".json"
    local ok, data = pcall(function() return HttpService:JSONEncode(CFG) end)
    if ok and data then
        pcall(writefile, filePath, data)
        print("[cook45] Config successfully saved to " .. filePath)
    end
end

local function loadConfigFile(name)
    name = (name and name ~= "") and name or (CFG.SelectedConfigName or "default")
    if not (readfile and isfile) then return end
    local filePath = CONFIG_FOLDER .. "/" .. name .. ".json"
    if not isfile(filePath) then return end
    local ok, content = pcall(readfile, filePath)
    if not ok or not content then return end
    local okJson, decoded = pcall(function() return HttpService:JSONDecode(content) end)
    if okJson and type(decoded) == "table" then
        for k, v in pairs(decoded) do
            CFG[k] = v
        end
        normalizeUpgradeSystems()
        if AxelHubUI then AxelHubUI:SyncConfig() end
        print("[Axel Hub] Config loaded from " .. filePath)
    end
end

local function deleteConfigFile(name)
    name = (name and name ~= "") and name or (CFG.SelectedConfigName or "default")
    if not delfile then return end
    local filePath = CONFIG_FOLDER .. "/" .. name .. ".json"
    if isfile and isfile(filePath) then
        pcall(delfile, filePath)
        print("[cook45] Config deleted: " .. filePath)
    end
end

local function checkAutoLoadConfig()
    if not (readfile and isfile and CFG.AutoLoadConfig) then return end
    local autoFile = CONFIG_FOLDER .. "/_autoload.txt"
    if isfile(autoFile) then
        local ok, cName = pcall(readfile, autoFile)
        if ok and cName and cName ~= "" then
            loadConfigFile(cName:gsub("%s+", ""))
            return
        end
    end
    loadConfigFile("default")
end
pcall(checkAutoLoadConfig)

-- Bundled AxelUI: a single file with no remote UI loader.
local AxelUI = (function()
-- AxelUI Library
-- A small, dependency-free Roblox/Luau UI library for executor scripts.
-- Features: font fallback, Lucide-style icons with text fallback, animated
-- window, hover/press effects, tabs, status cards, search, descriptions,
-- toggles, buttons, sliders, dropdowns, inputs, keybinds, labels and notifications.
-- Includes responsive desktop/mobile layout, theme and config support,
-- Oxide-compatible aliases, and Unload() cleanup for tracked connections.
-- Quick start is included in AxelUI_Library_Example.luau.

local AxelUI = {}
AxelUI.__index = AxelUI
AxelUI.TabMethods = {}
AxelUI.SectionMethods = {}

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LOW_END_TOUCH_CLIENT = UserInputService.TouchEnabled == true
local ACTIVE_FONT
local ACTIVE_ASSET_FOLDER
local GOLD_GRADIENT_ANIMATIONS = setmetatable({}, { __mode = "k" })

local function getSharedEnvironment()
    local environment = _G
    pcall(function()
        if type(getgenv) == "function" then environment = getgenv() end
    end)
    if type(environment) ~= "table" then environment = _G end
    return environment
end

local DEFAULT_THEME = {
    Background = Color3.fromRGB(12, 13, 17),
    Surface = Color3.fromRGB(17, 18, 23),
    Surface2 = Color3.fromRGB(23, 24, 30),
    Element = Color3.fromRGB(28, 29, 36),
    ElementHover = Color3.fromRGB(37, 38, 47),
    Border = Color3.fromRGB(49, 50, 61),
    Text = Color3.fromRGB(244, 245, 248),
    SubText = Color3.fromRGB(157, 160, 171),
    Muted = Color3.fromRGB(105, 108, 119),
    Accent = Color3.fromRGB(255, 193, 7),
    Accent2 = Color3.fromRGB(255, 224, 115),
    Accent3 = Color3.fromRGB(184, 126, 0),
    Success = Color3.fromRGB(91, 220, 139),
    Warning = Color3.fromRGB(255, 184, 74),
    Danger = Color3.fromRGB(255, 99, 111),
}

-- The icons are ordinary Roblox image assets, so the library does not need a
-- second remote dependency.  A caller can pass any rbxassetid/http URL too.
local ICONS = {
    dashboard = "7733970318",
    eggs = "8997385940",
    home = "7733960981",
    combat = "7734052758",
    player = "7743876054",
    settings = "7734053495",
    server = "7734053426",
    webhook = "7733992732",
    chart = "7733674319",
    shield = "7734056608",
    eye = "7733774602",
    move = "7734020989",
    target = "7743872758",
    wrench = "7734058803",
    search = "7734052925",
    info = "7733964719",
    check = "7733715400",
    x = "7743878496",
    copy = "7733764083",
    power = "7734042423",
    download = "7733770755",
    upload = "7743875428",
    refresh = "7734051052",
    chevron = "7733717755",
    -- Compatibility names used by Oxide-style scripts.
    crown = "8997385940",
    bolt = "7734042423",
    gear = "7734053495",
    globe = "7734053426",
    discord = "7733992732",
    users = "7743876054",
    cart = "7733770755",
    file = "7733764083",
    monitor = "7733774602",
    palette = "7733674319",
    bell = "7733964719",
    activity = "7733674319",
    cpu = "7733674319",
    gamepad = "7734052758",
    list = "7733970318",
    plus = "7733715400",
    minus = "7743878496",
    -- Expanded Oxide-style semantic icon set.
    menu = "10734896206",
    grid = "10734950309",
    sliders = "10734897102",
    swords = "10747384394",
    sword = "10747384394",
    crosshair = "10723434538",
    aim = "10723434538",
    fire = "10723415285",
    flame = "10723415285",
    star = "10734924532",
    sparkle = "10723422246",
    user = "10747387118",
    person = "77052607579460",
    team = "10747387298",
    group = "10747387298",
    visible = "10709790644",
    render = "10709790644",
    esp = "10709790644",
    eyeoff = "10709790497",
    hidden = "10709790497",
    world = "10709778567",
    compass = "10709790373",
    map = "84513890895579",
    arrows = "10723422998",
    heart = "10723415389",
    alert = "10723345067",
    warning = "10747387522",
    lock = "10723417148",
    unlock = "10723422607",
    folder = "10709791437",
    save = "10709791258",
    clipboard = "10709751190",
    play = "10723422607",
    volume = "10723421745",
    camera = "10709778567",
    clock = "10723345037",
    time = "10723345037",
    code = "10709751190",
    terminal = "10709751190",
    bug = "10723415903",
    layers = "10723417148",
    inventory = "14118896735",
    backpack = "10723415285",
    gift = "10723415389",
    gem = "10723421745",
    coin = "13522871708",
    skull = "10747384394",
    teleport = "10090587519",
    running = "10723422998",
    favorite = "10734924532",
    -- Friendly aliases used by the reference example. Keeping these mapped
    -- avoids a blank ImageLabel when a script uses a semantic icon name.
    utilities = "7734058803",
    configs = "7733764083",
    marketplace = "7733770755",
    shop = "7733770755",
    speed = "7733674319",
    timer = "10723345037",
    contrast = "7733674319",
    sun = "10734924532",
}

-- Semantic icon names are rendered with local vector primitives below. This
-- avoids missing-font tofu squares and makes built-in icons independent of
-- Roblox asset permissions. The values are retained as aliases for old scripts.
local BUILTIN_ICONS = {
    dashboard = true, grid = true, home = true, player = true, person = true, user = true, users = true,
    world = true, globe = true, map = true, compass = true, eye = true, eyeoff = true, visible = true, render = true, esp = true,
    utilities = true, wrench = true, configs = true, folder = true, file = true, shop = true, cart = true, marketplace = true,
    running = true, speed = true, arrows = true, move = true, teleport = true, target = true, crosshair = true, aim = true,
    shield = true, lock = true, unlock = true, star = true, sparkle = true, favorite = true, crown = true,
    clock = true, time = true, timer = true, chart = true, activity = true, cpu = true, monitor = true, gamepad = true,
    save = true, download = true, upload = true, refresh = true, server = true, settings = true, gear = true, sliders = true,
    power = true, check = true, x = true, plus = true, minus = true, bolt = true, fire = true, flame = true, swords = true, sword = true, combat = true,
    webhook = true, bell = true, info = true, alert = true, warning = true, search = true, copy = true, clipboard = true,
    chevron = true, list = true, palette = true, layers = true, contrast = true, heart = true, volume = true, camera = true,
    code = true, terminal = true, bug = true, inventory = true, backpack = true, gift = true, gem = true, coin = true, skull = true, eggs = true, discord = true, team = true, group = true,
    sun = true,
}

local function copyTheme(theme)
    local result = {}
    for key, value in pairs(DEFAULT_THEME) do result[key] = value end
    for key, value in pairs(theme or {}) do result[key] = value end
    return result
end

local function normalizeTheme(theme, base)
    local result = copyTheme(base or {})
    for key, value in pairs(theme or {}) do result[key] = value end
    -- Accept common names used by other Roblox UI libraries as aliases.
    if theme and theme.Panel and theme.Surface == nil then result.Surface = theme.Panel end
    if theme and theme.Row and theme.Surface2 == nil then result.Surface2 = theme.Row end
    if theme and theme.TextMain and theme.Text == nil then result.Text = theme.TextMain end
    if theme and theme.TextSub and theme.SubText == nil then result.SubText = theme.TextSub end
    if theme and theme.AccentLightYellow and theme.Accent == nil then result.Accent = theme.AccentLightYellow end
    if theme and theme.KnobAccent and theme.Accent2 == nil then result.Accent2 = theme.KnobAccent end
    if theme and theme.RedCancel and theme.Danger == nil then result.Danger = theme.RedCancel end
    if theme and theme.GreenActive and theme.Success == nil then result.Success = theme.GreenActive end
    return result
end

local function asset(value)
    if value == nil or value == "" then return nil end
    local text = tostring(value)
    local mapped = ICONS[string.lower(text)]
    if mapped then return "rbxassetid://" .. mapped end
    if text:match("^%d+$") then return "rbxassetid://" .. text end
    return text
end

local function imageSource(value, assetFolder)
    if type(value) == "table" then
        value = value.Image or value.Asset or value.Id or value.Source
    end
    local source = asset(value)
    if not source then return nil end
    if source:find("://", 1, true) then return source end
    local candidates = { source }
    if assetFolder and tostring(assetFolder) ~= "" then
        local root = tostring(assetFolder):gsub("[\\/]+$", "")
        table.insert(candidates, 1, root .. "/" .. source)
        table.insert(candidates, 2, root .. "\\" .. source)
    end
    for _, candidate in ipairs(candidates) do
        if type(getcustomasset) == "function" then
            local ok, custom = pcall(getcustomasset, candidate)
            if ok and custom then return custom end
        end
        if type(getsynasset) == "function" then
            local ok, custom = pcall(getsynasset, candidate)
            if ok and custom then return custom end
        end
    end
    -- A bare local filename cannot be assigned to ImageLabel.Image. Return nil
    -- so controls can render their deterministic fallback instead of becoming
    -- a silent blank square.
    return nil
end

local function imageThumbnailSource(source, width, height)
    local text = tostring(source or "")
    local id = text:match("^rbxassetid://(%d+)$") or text:match("^(%d+)$")
    if not id then return nil end
    return string.format("rbxthumb://type=Asset&id=%s&w=%d&h=%d", id, tonumber(width) or 420, tonumber(height) or 420)
end

local function fontFace(value, bold)
    local enumValue = value or ACTIVE_FONT or (bold and Enum.Font.GothamBold or Enum.Font.Gotham)
    local ok, result = pcall(function()
        if typeof(enumValue) == "EnumItem" then
            return Font.fromEnum(enumValue)
        end
        if type(enumValue) == "string" and Font and type(Font.new) == "function" then
            return Font.new(enumValue)
        end
        return enumValue
    end)
    return ok and result or (bold and Enum.Font.GothamBold or Enum.Font.Gotham)
end

local function new(className, properties, parent)
    local instance = Instance.new(className)
    local props = properties or {}
    for key, value in pairs(props) do
        pcall(function() instance[key] = value end)
    end
    -- ScreenGui uses Global ZIndex in this library. In that mode a parent's
    -- ZIndex is not inherited by its children; without this small inheritance
    -- rule a sidebar can render as a blank panel behind the next sibling.
    if parent and instance:IsA("GuiObject") then
        pcall(function()
            local parentZ = parent:IsA("GuiObject") and tonumber(parent.ZIndex) or 0
            if parentZ and parentZ > 0 then
                local ownZ = tonumber(instance.ZIndex) or 0
                if props.ZIndex == nil or ownZ <= parentZ then
                    instance.ZIndex = parentZ + 1 + math.max(0, ownZ)
                end
            end
        end)
    end
    if parent then instance.Parent = parent end
    return instance
end

local function corner(parent, radius)
    return new("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, parent)
end

local function stroke(parent, color, transparency, thickness)
    return new("UIStroke", {
        Color = color,
        Transparency = transparency or 0,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function pad(parent, left, right, top, bottom)
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or left or 0),
        PaddingTop = UDim.new(0, top or left or 0),
        PaddingBottom = UDim.new(0, bottom or top or left or 0),
    }, parent)
end

local function tween(instance, goal, duration, style, direction)
    if not instance or not instance.Parent then return end
    local ok, result = pcall(function()
        local info = TweenInfo.new(
            duration or 0.18,
            style or Enum.EasingStyle.Quart,
            direction or Enum.EasingDirection.Out
        )
        local animation = TweenService:Create(instance, info, goal)
        animation:Play()
        return animation
    end)
    return ok and result or nil
end

local function textLabel(parent, text, size, color, bold)
    return new("TextLabel", {
        BackgroundTransparency = 1,
        Text = tostring(text or ""),
        TextColor3 = color,
        TextSize = size or 13,
        FontFace = fontFace(nil, bold),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        RichText = true,
    }, parent)
end

local ICON_ALIASES = {
    dashboard = "grid", configs = "file", marketplace = "cart", shop = "cart", users = "user",
    person = "user", player = "user", team = "user", group = "user", globe = "world", compass = "world", map = "world",
    visible = "eye", render = "eye", esp = "eye", eyeoff = "eye", hidden = "eye", wrench = "settings",
    sliders = "settings", utilities = "settings", gear = "settings", speed = "gauge", activity = "gauge",
    wifi = "wifi",
    running = "move", arrows = "move", teleport = "move", aim = "target", crosshair = "target",
    favorite = "star", sparkle = "star", logo = "star", time = "clock", timer = "clock", chart = "gauge",
    download = "save", upload = "save", clipboard = "file", list = "file", inventory = "file",
    backpack = "file", server = "world", monitor = "grid", gamepad = "grid", contrast = "eye", refresh = "refresh",
    menu = "grid", power = "bolt", fire = "bolt", flame = "bolt", swords = "move", sword = "move",
    combat = "move", webhook = "bolt", info = "target", alert = "target", warning = "target",
    copy = "file", palette = "star", layers = "grid", camera = "eye", bug = "target", gift = "star",
    gem = "star", coin = "star", skull = "target", eggs = "star", discord = "world", heart = "star",
    volume = "bolt", check = "check", x = "close", plus = "plus", minus = "minus", save = "save",
    folder = "file", file = "file", eyeoff = "eye", lock = "shield", unlock = "shield",
    caret = "chevron", dropdown = "chevron", angle = "chevron", expand = "maximize", collapse = "minus",
}

local function canonicalIcon(value)
    local name = string.lower(tostring(value or "sparkle")):gsub("[%s%-]", "")
    if ICON_ALIASES[name] then name = ICON_ALIASES[name] end
    if name == "star" or name == "sparkle" or name == "logo" then return "star" end
    if name == "home" or name == "user" or name == "world" or name == "eye" or name == "settings"
        or name == "gauge" or name == "clock" or name == "move" or name == "target" or name == "grid"
        or name == "file" or name == "cart" or name == "shield" or name == "save" or name == "bolt"
        or name == "check" or name == "close" or name == "plus" or name == "minus" or name == "search"
        or name == "maximize" or name == "chevron" or name == "sun" or name == "resize" or name == "refresh"
        or name == "wifi" then
        return name
    end
    return "star"
end

local function vectorIcon(parent, name, size, tint)
    local dimension = math.max(8, tonumber(size) or 18)
    local scale = dimension / 24
    local root = new("Frame", {
        Name = "AxelVectorIcon",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(dimension, dimension),
    }, parent)
    local function segment(x1, y1, x2, y2, thickness)
        local dx, dy = (x2 - x1) * scale, (y2 - y1) * scale
        local length = math.sqrt(dx * dx + dy * dy)
        local angle = math.deg(math.atan2(dy, dx))
        local line = new("Frame", {
            Name = "AxelIconLine",
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = tint or Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Position = UDim2.fromOffset((x1 + x2) * 0.5 * scale, (y1 + y2) * 0.5 * scale),
            Rotation = angle,
            Size = UDim2.fromOffset(length, math.max(1, (thickness or 1.8) * scale)),
        }, root)
        corner(line, 2)
        return line
    end
    local function outline(x, y, w, h, radius)
        local shape = new("Frame", {
            Name = "AxelIconShape",
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset((x + w / 2) * scale, (y + h / 2) * scale),
            Size = UDim2.fromOffset(w * scale, h * scale),
        }, root)
        corner(shape, math.max(1, (radius or 4) * scale))
        stroke(shape, tint or Color3.new(1, 1, 1), 0, math.max(1, 1.7 * scale))
        return shape
    end
    local function dot(x, y, diameter, filled)
        local shape = new("Frame", {
            Name = "AxelIconDot",
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = tint or Color3.new(1, 1, 1),
            BackgroundTransparency = filled and 0 or 1,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(x * scale, y * scale),
            Size = UDim2.fromOffset(diameter * scale, diameter * scale),
        }, root)
        corner(shape, diameter * scale / 2)
        if not filled then stroke(shape, tint or Color3.new(1, 1, 1), 0, math.max(1, 1.7 * scale)) end
        return shape
    end

    if name == "search" then
        dot(10, 10, 12, false); segment(14.5, 14.5, 21, 21, 2)
    elseif name == "home" then
        segment(3, 11, 12, 3, 2); segment(12, 3, 21, 11, 2)
        segment(5, 10, 5, 21, 2); segment(19, 10, 19, 21, 2); segment(5, 21, 19, 21, 2)
        segment(10, 21, 10, 14, 2); segment(10, 14, 14, 14, 2); segment(14, 14, 14, 21, 2)
    elseif name == "user" then
        dot(12, 7, 7, false); segment(4, 21, 5, 18, 2); segment(5, 18, 9, 15, 2)
        segment(9, 15, 15, 15, 2); segment(15, 15, 19, 18, 2); segment(19, 18, 20, 21, 2)
        segment(4, 21, 20, 21, 2)
    elseif name == "world" then
        dot(12, 12, 19, false); segment(3, 12, 21, 12, 1.4); segment(12, 3, 12, 21, 1.4)
        segment(8, 4, 7, 12, 1.2); segment(7, 12, 8, 20, 1.2)
        segment(16, 4, 17, 12, 1.2); segment(17, 12, 16, 20, 1.2)
    elseif name == "wifi" then
        segment(3, 8, 7, 5, 1.8); segment(7, 5, 12, 3.5, 1.8); segment(12, 3.5, 17, 5, 1.8); segment(17, 5, 21, 8, 1.8)
        segment(7, 13, 9, 11, 1.8); segment(9, 11, 12, 10, 1.8); segment(12, 10, 15, 11, 1.8); segment(15, 11, 17, 13, 1.8)
        dot(12, 19, 3, true)
    elseif name == "eye" then
        segment(2, 12, 7, 6, 1.8); segment(7, 6, 12, 4, 1.8); segment(12, 4, 17, 6, 1.8)
        segment(17, 6, 22, 12, 1.8); segment(22, 12, 17, 18, 1.8); segment(17, 18, 12, 20, 1.8)
        segment(12, 20, 7, 18, 1.8); segment(7, 18, 2, 12, 1.8); dot(12, 12, 6, false)
    elseif name == "settings" then
        dot(12, 12, 7, false)
        for i = 0, 7 do
            local a = math.rad(i * 45)
            local x1, y1 = 12 + math.cos(a) * 6.5, 12 + math.sin(a) * 6.5
            local x2, y2 = 12 + math.cos(a) * 10, 12 + math.sin(a) * 10
            segment(x1, y1, x2, y2, 2.2)
        end
    elseif name == "gauge" then
        segment(3, 19, 4, 12, 1.8); segment(4, 12, 8, 6, 1.8); segment(8, 6, 12, 4, 1.8)
        segment(12, 4, 16, 6, 1.8); segment(16, 6, 20, 12, 1.8); segment(20, 12, 21, 19, 1.8)
        segment(3, 19, 21, 19, 1.8); segment(12, 17, 17, 10, 2)
    elseif name == "clock" then
        dot(12, 12, 19, false); segment(12, 6, 12, 12, 2); segment(12, 12, 17, 15, 2)
    elseif name == "move" then
        segment(12, 3, 12, 21, 1.8); segment(3, 12, 21, 12, 1.8)
        segment(12, 3, 8, 7, 1.8); segment(12, 3, 16, 7, 1.8)
        segment(12, 21, 8, 17, 1.8); segment(12, 21, 16, 17, 1.8)
        segment(3, 12, 7, 8, 1.8); segment(3, 12, 7, 16, 1.8)
        segment(21, 12, 17, 8, 1.8); segment(21, 12, 17, 16, 1.8)
    elseif name == "target" then
        dot(12, 12, 16, false); dot(12, 12, 6, false); segment(12, 1, 12, 5, 1.8)
        segment(12, 19, 12, 23, 1.8); segment(1, 12, 5, 12, 1.8); segment(19, 12, 23, 12, 1.8)
    elseif name == "grid" then
        for _, point in ipairs({{4,4},{14,4},{4,14},{14,14}}) do outline(point[1], point[2], 6, 6, 1.4) end
    elseif name == "file" then
        segment(6, 3, 15, 3, 1.8); segment(15, 3, 19, 7, 1.8); segment(19, 7, 19, 21, 1.8)
        segment(19, 21, 5, 21, 1.8); segment(5, 21, 5, 4, 1.8); segment(5, 4, 6, 3, 1.8)
        segment(15, 3, 15, 7, 1.5); segment(15, 7, 19, 7, 1.5)
        segment(8, 12, 16, 12, 1.4); segment(8, 16, 16, 16, 1.4)
    elseif name == "cart" then
        segment(3, 5, 6, 5, 1.8); segment(6, 5, 8, 16, 1.8); segment(8, 16, 19, 16, 1.8)
        segment(19, 16, 22, 8, 1.8); segment(7, 9, 21, 9, 1.8); dot(10, 20, 3, true); dot(18, 20, 3, true)
    elseif name == "shield" then
        segment(12, 3, 20, 6, 1.8); segment(20, 6, 19, 15, 1.8); segment(19, 15, 12, 21, 1.8)
        segment(12, 21, 5, 15, 1.8); segment(5, 15, 4, 6, 1.8); segment(4, 6, 12, 3, 1.8)
        segment(8, 12, 11, 15, 1.8); segment(11, 15, 16, 9, 1.8)
    elseif name == "save" then
        segment(4, 3, 20, 3, 1.8); segment(20, 3, 20, 21, 1.8); segment(20, 21, 4, 21, 1.8)
        segment(4, 21, 4, 3, 1.8); segment(8, 3, 8, 10, 1.5); segment(8, 10, 16, 10, 1.5)
        segment(16, 10, 16, 3, 1.5); segment(8, 15, 8, 19, 1.5); segment(8, 19, 16, 19, 1.5)
        segment(16, 19, 16, 15, 1.5)
    elseif name == "bolt" then
        segment(14, 2, 6, 13, 2); segment(6, 13, 12, 13, 2); segment(12, 13, 10, 22, 2)
        segment(10, 22, 19, 10, 2); segment(19, 10, 13, 10, 2); segment(13, 10, 14, 2, 2)
    elseif name == "check" then
        segment(4, 13, 10, 19, 2.4); segment(10, 19, 21, 5, 2.4)
    elseif name == "close" then
        segment(6, 6, 18, 18, 2); segment(18, 6, 6, 18, 2)
    elseif name == "plus" then
        segment(12, 4, 12, 20, 2); segment(4, 12, 20, 12, 2)
    elseif name == "minus" then
        segment(4, 12, 20, 12, 2)
    elseif name == "maximize" then
        outline(4, 4, 16, 16, 2)
    elseif name == "resize" then
        segment(6, 18, 18, 6, 1.8); segment(12, 18, 18, 12, 1.8); segment(12, 6, 18, 6, 1.8)
        segment(18, 6, 18, 12, 1.8)
    elseif name == "refresh" then
        segment(18, 8, 17, 5, 1.8); segment(17, 5, 20, 5, 1.8); segment(20, 5, 20, 8, 1.8)
        segment(19, 7, 17, 5, 1.8); segment(17, 5, 13, 4, 1.8); segment(13, 4, 8, 6, 1.8)
        segment(8, 6, 5, 10, 1.8); segment(5, 10, 5, 15, 1.8); segment(5, 15, 8, 19, 1.8)
        segment(8, 19, 13, 20, 1.8); segment(13, 20, 18, 17, 1.8); segment(18, 17, 20, 13, 1.8)
    elseif name == "chevron" then
        segment(6, 9, 12, 15, 1.8); segment(12, 15, 18, 9, 1.8)
    elseif name == "sun" then
        dot(12, 12, 8, false)
        for i = 0, 7 do
            local a = math.rad(i * 45)
            segment(12 + math.cos(a) * 7, 12 + math.sin(a) * 7, 12 + math.cos(a) * 10, 12 + math.sin(a) * 10, 1.7)
        end
    elseif name == "star" then
        segment(12, 2, 14, 9, 2); segment(14, 9, 22, 12, 2); segment(22, 12, 14, 14, 2)
        segment(14, 14, 12, 22, 2); segment(12, 22, 10, 14, 2); segment(10, 14, 2, 12, 2)
        segment(2, 12, 10, 9, 2); segment(10, 9, 12, 2, 2)
    end

    local function updateZIndex()
        for _, child in ipairs(root:GetDescendants()) do
            if child:IsA("GuiObject") then child.ZIndex = root.ZIndex + 1 end
        end
    end
    root:GetPropertyChangedSignal("ZIndex"):Connect(updateZIndex)
    updateZIndex()
    return root
end

local function setIconTint(object, color, duration)
    if not object then return end
    local instant = LOW_END_TOUCH_CLIENT or tonumber(duration) == 0
    local function apply(target, property, value)
        if instant then
            pcall(function() target[property] = value end)
        else
            tween(target, { [property] = value }, duration or 0.18)
        end
    end
    if object:IsA("ImageLabel") or object:IsA("ImageButton") then
        apply(object, "ImageColor3", color)
        local fallback = object.Parent and object.Parent:FindFirstChild("AxelVectorIcon")
        if fallback then setIconTint(fallback, color, duration) end
        return
    end
    if object:IsA("GuiObject") then
        for _, child in ipairs(object:GetDescendants()) do
            if child:IsA("GuiObject") and child.Name ~= "AxelVectorIcon" then apply(child, "BackgroundColor3", color) end
            if child:IsA("UIStroke") then apply(child, "Color", color) end
        end
    end
end

local function fadeIcon(object, duration)
    if not object then return end
    if object:IsA("ImageLabel") or object:IsA("ImageButton") then
        tween(object, { ImageTransparency = 1 }, duration or 0.2)
        local fallback = object.Parent and object.Parent:FindFirstChild("AxelVectorIcon")
        if fallback then fadeIcon(fallback, duration) end
        return
    end
    if object:IsA("GuiObject") then
        for _, child in ipairs(object:GetDescendants()) do
            if child:IsA("GuiObject") then tween(child, { BackgroundTransparency = 1 }, duration or 0.2) end
            if child:IsA("UIStroke") then tween(child, { Transparency = 1 }, duration or 0.2) end
        end
    end
end

local function watchImage(imageLabel, onLoaded, onTimeout, timeout, fallbackSources)
    if not imageLabel then return end
    local state = "pending"
    local timeoutSeconds = tonumber(timeout) or 5
    local fallbackIndex = 0
    local timeoutGeneration = 0
    local function refresh()
        if not imageLabel.Parent then return end
        local ok, loaded = pcall(function() return imageLabel.IsLoaded end)
        if ok and loaded and state ~= "loaded" then
            state = "loaded"
            if type(onLoaded) == "function" then pcall(onLoaded) end
        end
    end
    local function watchProperty(property)
        pcall(function()
            imageLabel:GetPropertyChangedSignal(property):Connect(refresh)
        end)
    end
    watchProperty("IsLoaded")
    watchProperty("Image")
    local function armTimeout()
        timeoutGeneration = timeoutGeneration + 1
        local generation = timeoutGeneration
        task.delay(timeoutSeconds, function()
            if not imageLabel.Parent or state ~= "pending" or generation ~= timeoutGeneration then return end
            while type(fallbackSources) == "table" and fallbackIndex < #fallbackSources do
                fallbackIndex = fallbackIndex + 1
                local candidate = fallbackSources[fallbackIndex]
                local current = ""
                pcall(function() current = imageLabel.Image end)
                if type(candidate) == "string" and candidate ~= "" and candidate ~= current then
                    local ok = pcall(function() imageLabel.Image = candidate end)
                    if ok then
                        state = "pending"
                        armTimeout()
                        refresh()
                        return
                    end
                end
            end
            state = "failed"
            if type(onTimeout) == "function" then pcall(onTimeout) end
        end)
    end
    armTimeout()
    refresh()
end

local function icon(parent, value, size, tint)
    local config = type(value) == "table" and value or nil
    local source = config and (config.Image or config.Asset or config.Id or config.Source) or value
    local sourceText = string.lower(tostring(source or "sparkle"))
    local iconSize = (config and tonumber(config.Size)) or tonumber(size) or 18
    local iconTint = (config and config.Color) or tint or Color3.new(1, 1, 1)
    local semantic = BUILTIN_ICONS[sourceText] ~= nil or sourceText:match("^[%a_%-]+$") ~= nil
    local forceImage = config and config.UseImage == true
    if semantic and not forceImage then return vectorIcon(parent, canonicalIcon(sourceText), iconSize, iconTint) end

    local image = imageSource(source, ACTIVE_ASSET_FOLDER)
    if image then
        local fallback = vectorIcon(parent, canonicalIcon(config and config.Fallback or "star"), iconSize, iconTint)
        fallback.Name = "AxelVectorIcon"
        fallback.Visible = true
        local imageLabel = new("ImageLabel", {
            BackgroundTransparency = 1,
            Image = image,
            ImageColor3 = iconTint,
            Size = UDim2.fromOffset(iconSize, iconSize),
            ScaleType = (config and config.ScaleType) or Enum.ScaleType.Fit,
            Visible = false,
        }, parent)
        if config and config.ImageRectOffset then imageLabel.ImageRectOffset = config.ImageRectOffset end
        if config and config.ImageRectSize then imageLabel.ImageRectSize = config.ImageRectSize end
        local function syncFallback()
            if not imageLabel.Parent or not fallback.Parent then return end
            fallback.Position = imageLabel.Position
            fallback.AnchorPoint = imageLabel.AnchorPoint
            fallback.Size = imageLabel.Size
            fallback.ZIndex = imageLabel.ZIndex + 1
        end
        imageLabel:GetPropertyChangedSignal("Position"):Connect(syncFallback)
        imageLabel:GetPropertyChangedSignal("AnchorPoint"):Connect(syncFallback)
        imageLabel:GetPropertyChangedSignal("Size"):Connect(syncFallback)
        imageLabel:GetPropertyChangedSignal("ZIndex"):Connect(syncFallback)
        watchImage(imageLabel, function()
            if imageLabel.Parent and fallback.Parent then imageLabel.Visible = true; fallback.Visible = false end
        end, function()
            if imageLabel.Parent and fallback.Parent then imageLabel.Visible = false; fallback.Visible = true end
        end)
        return imageLabel
    end
    return vectorIcon(parent, canonicalIcon(sourceText), iconSize, iconTint)
end

local function resolveParent()
    local parent
    pcall(function()
        if type(gethui) == "function" then parent = gethui() end
    end)
    if parent then return parent end
    local ok, coreGui = pcall(game.GetService, game, "CoreGui")
    if ok and coreGui then return coreGui end
    local player = Players.LocalPlayer
    return player and player:FindFirstChildOfClass("PlayerGui") or nil
end

local function connect(self, signal, callback)
    if not signal or type(callback) ~= "function" then return nil end
    local ok, connection = pcall(function() return signal:Connect(callback) end)
    if ok and connection then
        table.insert(self._connections, connection)
        return connection
    end
end

local function connectActivated(self, button, callback)
    if not button then return nil end
    local activatedSignal
    pcall(function() activatedSignal = button.Activated end)
    local connection = activatedSignal and connect(self, activatedSignal, callback)
    if not connection then
        connection = connect(self, button.MouseButton1Click, callback)
    end
    return connection
end

local function keyMatches(input, key)
    if not input or not key then return false end
    if typeof(key) == "EnumItem" then return input.KeyCode == key end
    local wanted = string.lower(tostring(key))
    return string.lower(tostring(input.KeyCode.Name)) == wanted
        or string.lower(tostring(input.UserInputType.Name)) == wanted
end

local function keyName(value)
    if typeof(value) == "EnumItem" then return value.Name end
    local text = tostring(value or "None")
    return text:gsub("^Enum%.[^.]+%.", "")
end

local function placePopup(popup, anchor, width, height, preferBelow, preferSide)
    if not popup or not anchor then return end
    local viewport = Vector2.new(1280, 720)
    pcall(function()
        if workspace.CurrentCamera then viewport = workspace.CurrentCamera.ViewportSize end
    end)
    local anchorPosition = anchor.AbsolutePosition
    local anchorSize = anchor.AbsoluteSize
    if preferSide then
        local fittedHeight = math.min(height, math.max(1, viewport.Y - 16))
        local right = anchorPosition.X + anchorSize.X + 8
        local left = anchorPosition.X - width - 8
        local sideX
        if right + width <= viewport.X - 8 then
            sideX = right
        elseif left >= 8 then
            sideX = left
        end
        if sideX then
            local sideY = math.clamp(
                anchorPosition.Y + (anchorSize.Y - fittedHeight) * 0.5,
                8,
                math.max(8, viewport.Y - fittedHeight - 8)
            )
            popup.Size = UDim2.fromOffset(width, fittedHeight)
            popup.Position = UDim2.fromOffset(sideX, sideY)
            return
        end
    end
    local x = math.clamp(anchorPosition.X, 8, math.max(8, viewport.X - width - 8))
    local below = anchorPosition.Y + anchorSize.Y + 4
    local availableBelow = viewport.Y - below - 8
    if preferBelow and availableBelow >= 30 then
        local fittedHeight = math.min(height, availableBelow)
        popup.Size = UDim2.fromOffset(width, fittedHeight)
        popup.Position = UDim2.fromOffset(x, below)
        return
    end
    local y = below + height <= viewport.Y - 8 and below or anchorPosition.Y - height - 4
    y = math.clamp(y, 8, math.max(8, viewport.Y - height - 8))
    popup.Position = UDim2.fromOffset(x, y)
end

local function dropdownPopupMetrics(anchor, count, mobile, multi)
    local viewport = Vector2.new(1280, 720)
    pcall(function()
        if workspace.CurrentCamera then viewport = workspace.CurrentCamera.ViewportSize end
    end)
    local optionHeight = mobile and 32 or 24
    local width = mobile and (multi and 160 or 154) or (multi and 140 or 136)
    local anchorWidth = 0
    pcall(function() anchorWidth = anchor.AbsoluteSize.X end)
    width = math.min(math.max(width, math.floor(anchorWidth)), math.max(120, viewport.X - 16))
    local maxHeight = mobile and 158 or 136
    local height = math.min(math.max(count, 1) * optionHeight + 8, maxHeight)
    return width, height, optionHeight
end

local function popupIsBelowAnchor(popup, anchor)
    if not popup or not anchor then return true end
    local popupY = popup.Position.Y.Offset
    local anchorMiddle = anchor.AbsolutePosition.Y + anchor.AbsoluteSize.Y * 0.5
    return popupY >= anchorMiddle
end

local function animatePopupOpen(popup, anchor)
    if not popup or not popup.Parent then return end
    local targetSize = popup.Size
    local targetPosition = popup.Position
    local slideDirection = popupIsBelowAnchor(popup, anchor) and -1 or 1
    local outline = popup:FindFirstChildOfClass("UIStroke")
    popup.Size = UDim2.fromOffset(targetSize.X.Offset, 0)
    popup.Position = UDim2.new(targetPosition.X.Scale, targetPosition.X.Offset, targetPosition.Y.Scale, targetPosition.Y.Offset + slideDirection * 8)
    popup.BackgroundTransparency = 0.16
    if outline then outline.Transparency = 0.62 end
    tween(popup, { Size = targetSize, Position = targetPosition, BackgroundTransparency = 0 }, 0.19, Enum.EasingStyle.Quint)
    if outline then tween(outline, { Transparency = 0.08 }, 0.19, Enum.EasingStyle.Quint) end
end

local function animatePopupClose(popup, anchor)
    if not popup or not popup.Parent then return end
    local width = popup.Size.X.Offset
    local position = popup.Position
    local slideDirection = popupIsBelowAnchor(popup, anchor) and -1 or 1
    local outline = popup:FindFirstChildOfClass("UIStroke")
    tween(popup, {
        Size = UDim2.fromOffset(width, 0),
        Position = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset + slideDirection * 7),
        BackgroundTransparency = 1,
    }, 0.15, Enum.EasingStyle.Quad)
    if outline then tween(outline, { Transparency = 1 }, 0.13, Enum.EasingStyle.Quad) end
    task.delay(0.17, function()
        if popup.Parent then popup:Destroy() end
    end)
end

local function pressAnimation(self, button, scaleObject, reducedHoverStyle)
    if not button then return end
    -- Match v7.2 on reduced-effects clients: skip decorative input hooks and
    -- tweens entirely. This keeps low-end/touch buttons cheap during presses.
    if self.ReduceEffects then return end
    local scale = scaleObject or new("UIScale", { Scale = 1 }, button)
    connect(self, button.MouseEnter, function()
        tween(scale, { Scale = 1.025 }, 0.13)
    end)
    connect(self, button.MouseLeave, function()
        tween(scale, { Scale = 1 }, 0.16)
    end)
    connect(self, button.MouseButton1Down, function()
        tween(scale, { Scale = 0.96 }, 0.07)
    end)
    connect(self, button.MouseButton1Up, function()
        tween(scale, { Scale = 1.025 }, 0.1)
    end)
end

local function addButtonGlass(self, button, restingTransparency)
    if not button then return end
    if self.ReduceEffects then return end
    restingTransparency = restingTransparency or 0
    connect(self, button.MouseEnter, function()
        tween(button, { BackgroundTransparency = math.max(restingTransparency, 0.12) }, 0.12)
    end)
    connect(self, button.MouseLeave, function()
        tween(button, { BackgroundTransparency = restingTransparency }, 0.16)
    end)
    connect(self, button.MouseButton1Down, function()
        tween(button, { BackgroundTransparency = math.max(restingTransparency, 0.24) }, 0.07)
    end)
    connect(self, button.MouseButton1Up, function()
        tween(button, { BackgroundTransparency = math.max(restingTransparency, 0.16) }, 0.1)
    end)
end

local function addGoldGradient(self, button)
    local gradient = new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, self.Theme.Accent3),
            ColorSequenceKeypoint.new(0.24, self.Theme.Accent),
            ColorSequenceKeypoint.new(0.52, self.Theme.Accent2),
            ColorSequenceKeypoint.new(0.78, self.Theme.Accent),
            ColorSequenceKeypoint.new(1, self.Theme.Accent3),
        }),
        -- Keep disabled gradients from washing out the button text. A fully
        -- transparent gradient still affects the text rendered by the button.
        Transparency = NumberSequence.new(0),
        Enabled = false,
        Rotation = 0,
        Offset = Vector2.new(-1, 0),
    }, button)
    if self.AnimateAccents then
        self._accentTweens = self._accentTweens or {}
        local ok, animation = pcall(function()
            return TweenService:Create(gradient, TweenInfo.new(2.8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true), {
                Offset = Vector2.new(1, 0),
            })
        end)
        if ok and animation then
            local entry = { Gradient = gradient, Tween = animation, Window = self }
            table.insert(self._accentTweens, entry)
            GOLD_GRADIENT_ANIMATIONS[gradient] = entry
        end
    end
    return gradient
end

local function setGoldGradientActive(gradient, active)
    if gradient then
        active = active == true
        pcall(function() gradient.Enabled = active end)
        local entry = GOLD_GRADIENT_ANIMATIONS[gradient]
        if entry and entry.Tween then
            pcall(function()
                local shouldPlay = active and entry.Window and entry.Window.AnimateAccents
                    and entry.Window._open
                if shouldPlay and entry.Tween.PlaybackState ~= Enum.PlaybackState.Playing then
                    entry.Tween:Play()
                elseif not shouldPlay and entry.Tween.PlaybackState == Enum.PlaybackState.Playing then
                    entry.Tween:Pause()
                end
            end)
        end
    end
end

local function setAccentAnimations(self, enabled)
    local shouldRun = enabled == true and self.AnimateAccents == true and self._open == true
    local shouldRunBorder = enabled == true and self.AnimatedBorder == true and self._open == true
    local function setTweenState(animation, play)
        if not animation then return end
        pcall(function()
            if play and animation.PlaybackState ~= Enum.PlaybackState.Playing then
                animation:Play()
            elseif not play and animation.PlaybackState == Enum.PlaybackState.Playing then
                animation:Pause()
            end
        end)
    end

    setTweenState(self._edgeTween, shouldRunBorder)
    for _, animation in ipairs(self._glintTweens or {}) do
        setTweenState(animation, shouldRun)
    end
    for _, entry in ipairs(self._accentTweens or {}) do
        setTweenState(entry.Tween, shouldRun and entry.Gradient and entry.Gradient.Enabled == true)
    end
end

local function setFpsSampling(self, enabled)
    if enabled then
        if self._fpsConnection or self._destroyed then return end
        self._fpsFrames = 0
        self._fpsElapsed = 0
        self._fpsConnection = RunService.RenderStepped:Connect(function(deltaTime)
            local windowVisible = self._open and self.Window and self.Window.Visible
            local restoreVisible = self.RestoreButton and self.RestoreButton.Visible
            if self._destroyed or not (windowVisible or restoreVisible) then return end
            self._fpsFrames = self._fpsFrames + 1
            self._fpsElapsed = self._fpsElapsed + math.max(tonumber(deltaTime) or 0, 0)
            if self._fpsElapsed >= 1 then
                local elapsed = self._fpsElapsed
                local fps = math.floor(self._fpsFrames / elapsed + 0.5)
                self._fpsFrames = 0
                self._fpsElapsed = 0
                if self.FpsValue then self.FpsValue.Text = tostring(fps) end
                if self.RestoreFpsText then self.RestoreFpsText.Text = tostring(fps) .. " FPS" end
                if self.RestorePingText then
                    local player = Players.LocalPlayer
                    local pingOk, pingSeconds = pcall(function()
                        return player and player:GetNetworkPing()
                    end)
                    self.RestorePingText.Text = pingOk and type(pingSeconds) == "number"
                        and (tostring(math.max(0, math.floor(pingSeconds * 1000 + 0.5))) .. " ms")
                        or "-- ms"
                end
            end
        end)
        return
    end

    self._fpsFrames = 0
    self._fpsElapsed = 0
    local connection = self._fpsConnection
    self._fpsConnection = nil
    if connection then pcall(function() connection:Disconnect() end) end
end

local function setTextColor(instance, color)
    if instance then pcall(function() instance.TextColor3 = color end) end
end

local function searchMatches(value, query)
    if query == "" then return true end
    value = string.lower(tostring(value or ""))
    if value:find(query, 1, true) then return true end
    -- Search multi-word queries in any order (e.g. "movement speed").
    for word in query:gmatch("%S+") do
        if not value:find(word, 1, true) then return false end
    end
    return true
end

function AxelUI:_registerSearch(row, query, titleLabel, options)
    if not row then return end
    local entry = {
        Text = string.lower(tostring(query or "")),
        Title = titleLabel,
        BaseTitleColor = titleLabel and titleLabel.TextColor3 or nil,
        Container = options and options.Container == true or false,
    }
    local ancestor = row.Parent
    while ancestor do
        local ancestorEntry = self._searchData[ancestor]
        if ancestorEntry and ancestorEntry.Container then
            entry.ContainerOwner = ancestor
            break
        end
        ancestor = ancestor.Parent
    end
    self._searchData[row] = entry
    table.insert(self._searchRows, row)
    connect(self, row.Destroying, function()
        self._searchData[row] = nil
        for index, registered in ipairs(self._searchRows) do
            if registered == row then table.remove(self._searchRows, index); break end
        end
    end)
    local text = string.lower(self.Search and self.Search.Text or "")
    local matches = searchMatches(entry.Text, text)
    row.Visible = text == "" or matches
    if titleLabel then
        titleLabel.TextColor3 = text ~= "" and matches and self.Theme.Accent2 or entry.BaseTitleColor
    end
    if text ~= "" then self:_refreshSearch(text) end
end

function AxelUI:_refreshSearch(text)
    text = string.lower(tostring(text or ""))
    local containerTextMatches, containerChildMatches = {}, {}
    if text ~= "" then
        for _, row in ipairs(self._searchRows) do
            local entry = self._searchData[row]
            if entry and entry.Container then containerTextMatches[row] = searchMatches(entry.Text, text) end
        end
        for _, row in ipairs(self._searchRows) do
            local entry = self._searchData[row]
            if entry and entry.ContainerOwner and searchMatches(entry.Text, text) then
                containerChildMatches[entry.ContainerOwner] = true
            end
        end
    end
    for _, row in ipairs(self._searchRows) do
        local entry = self._searchData[row]
        if row and row.Parent and entry then
            local matches = searchMatches(entry.Text, text)
            if entry.Container then
                matches = text == "" or containerTextMatches[row] or containerChildMatches[row] == true
            elseif entry.ContainerOwner and containerTextMatches[entry.ContainerOwner] then
                matches = true
            end
            row.Visible = text == "" or matches
            if entry.Title and entry.Title.Parent then
                local target = text ~= "" and matches and self.Theme.Accent2 or entry.BaseTitleColor
                tween(entry.Title, { TextColor3 = target or self.Theme.Text }, 0.12)
            end
        end
    end
end

function AxelUI:_registerFlag(flag, handle)
    if not flag or tostring(flag) == "" or not handle then return end
    self._flags[tostring(flag)] = handle
    handle.Flag = tostring(flag)
end

function AxelUI:_makeRow(parent, data, height)
    data = data or {}
    local rowHeight = height or 38
    if data.Description and rowHeight < 46 then rowHeight = 46 end
    local row = new("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = data.Primary and self.Theme.Accent or self.Theme.Surface2,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Text = "",
        Size = UDim2.new(1, 0, 0, rowHeight),
        LayoutOrder = data.LayoutOrder or 0,
    }, parent)
    corner(row, 8)
    local rowStroke = stroke(row, data.Primary and self.Theme.Accent2 or self.Theme.Border, 0.4, 1)
    local baseRowColor = data.Primary and self.Theme.Accent or self.Theme.Surface2
    local hoverRowColor = data.Primary and self.Theme.Accent2 or self.Theme.Element:Lerp(self.Theme.Accent, 0.18)
    local hoverGlass
    if not self.ReduceEffects then
        new("UIGradient", {
            Color = ColorSequence.new(data.Primary and self.Theme.Accent or self.Theme.Surface2, data.Primary and self.Theme.Accent2 or self.Theme.Element),
            Transparency = NumberSequence.new(0),
            Rotation = 0,
        }, row)
        hoverGlass = new("Frame", {
            BackgroundColor3 = self.Theme.Accent2,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            ZIndex = (tonumber(row.ZIndex) or 0) + 1,
        }, row)
        corner(hoverGlass, 8)
        new("UIGradient", {
            Color = ColorSequence.new(Color3.new(1, 1, 1), self.Theme.Accent2),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.34), NumberSequenceKeypoint.new(1, 0.9) }),
            Rotation = 0,
        }, hoverGlass)
    end
    local inner = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
    }, row)
    pad(inner, 10, 10, 6, 6)
    local textOffset = 0
    if data.Icon then
        local iconHolder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(0, 3) }, inner)
        local elementIcon = icon(iconHolder, data.Icon, 16, data.IconColor or self.Theme.Accent2)
        elementIcon.Position = UDim2.fromOffset(3, 3)
        textOffset = 27
    end
    local rightReserved = tonumber(data.RightReserved) or 145
    local rowTitleSize = self.IsMobile and 12 or 13
    local title = textLabel(inner, data.Name or "Element", rowTitleSize, data.Primary and self.Theme.Background or self.Theme.Text, true)
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.Size = UDim2.new(1, -rightReserved - textOffset, 0, data.Description and 17 or 26)
    title.Position = UDim2.fromOffset(textOffset, data.Description and 0 or 0)
    local descriptionLabel
    if data.Description then
        descriptionLabel = textLabel(inner, data.Description, 10, data.Primary and self.Theme.Background or self.Theme.SubText, false)
        descriptionLabel.TextWrapped = false
        descriptionLabel.TextTruncate = Enum.TextTruncate.AtEnd
        descriptionLabel.Size = UDim2.new(1, -rightReserved - textOffset, 0, 16)
        descriptionLabel.Position = UDim2.fromOffset(textOffset, 17)
    end
    pressAnimation(self, row, nil, {
        Color = data.Primary and self.Theme.Accent2 or self.Theme.ElementHover,
        Transparency = data.Primary and 0.025 or 0,
        StrokeColor = self.Theme.Accent2,
        StrokeTransparency = 0.035,
        StrokeThickness = 1.65,
    })
    if not self.ReduceEffects then
        connect(self, row.MouseEnter, function()
            tween(row, { BackgroundColor3 = hoverRowColor }, 0.12)
            tween(rowStroke, { Color = self.Theme.Accent2, Transparency = 0.06, Thickness = 1.35 }, 0.12)
            tween(hoverGlass, { BackgroundTransparency = 0.9 }, 0.12)
        end)
        connect(self, row.MouseLeave, function()
            tween(row, { BackgroundColor3 = baseRowColor }, 0.18)
            tween(rowStroke, { Color = data.Primary and self.Theme.Accent2 or self.Theme.Border, Transparency = 0.4, Thickness = 1 }, 0.18)
            tween(hoverGlass, { BackgroundTransparency = 1 }, 0.18)
        end)
    elseif self.HoverEffects then
        -- Keep hover motion event-driven and lightweight: reuse the row/stroke
        -- instead of adding per-row gradients or animated overlay layers.
        connect(self, row.MouseEnter, function()
            tween(row, { BackgroundColor3 = hoverRowColor }, 0.12)
            tween(rowStroke, { Color = self.Theme.Accent2, Transparency = 0.08, Thickness = 1.3 }, 0.12)
        end)
        connect(self, row.MouseLeave, function()
            tween(row, { BackgroundColor3 = baseRowColor }, 0.15)
            tween(rowStroke, { Color = data.Primary and self.Theme.Accent2 or self.Theme.Border, Transparency = 0.4, Thickness = 1 }, 0.15)
        end)
    end
    self:_registerSearch(row, (data.Name or "") .. " " .. (data.Description or ""), title)
    return row, inner, title, descriptionLabel
end

function AxelUI:_setActiveTab(tab, active)
    if not tab or not tab.Button then return end
    local color = active and self.Theme.Background or self.Theme.SubText
    local background = active and self.Theme.Accent or self.Theme.Surface
    tween(tab.Button, { BackgroundColor3 = background }, 0.18)
    tab.Button.BackgroundTransparency = active and 0.02 or 0
    setGoldGradientActive(tab.GoldGradient, active)
    if tab.TabStroke then
        tween(tab.TabStroke, { Transparency = active and 0.05 or 0.9, Color = active and self.Theme.Accent or self.Theme.Border }, 0.18)
    end
    setTextColor(tab.Title, color)
    if tab.Icon then setIconTint(tab.Icon, color, 0.18) end
    if tab.Indicator then
        tween(tab.Indicator, {
            BackgroundTransparency = active and 0 or 1,
            Size = UDim2.new(0, active and 3 or 0, 0.64, 0),
        }, 0.2, Enum.EasingStyle.Quint)
    end
end

function AxelUI:SelectTab(tab)
    if self._destroyed or not tab then return end
    if self._tabTween then pcall(function() self._tabTween:Cancel() end); self._tabTween = nil end
    local previous = self.ActiveTab
    local changed = previous ~= tab
    if changed and self._dropdownClose then pcall(self._dropdownClose) end
    local slide = tonumber(self.TabSlideOffset) or 18
    local direction = previous and tab.PageIndex and previous.PageIndex and tab.PageIndex < previous.PageIndex and -1 or 1
    for _, other in ipairs(self.Tabs) do
        local active = other == tab
        if active then
            other.Page.Visible = true
            if changed and self.TabAnimation then
                other.Page.Position = UDim2.fromOffset(slide * direction, 0)
                self._tabTween = tween(other.Page, { Position = UDim2.fromOffset(0, 0) }, self.TabAnimationDuration, Enum.EasingStyle.Quint)
            else
                other.Page.Position = UDim2.fromOffset(0, 0)
            end
        else
            other.Page.Visible = false
            other.Page.Position = UDim2.fromOffset(0, 0)
        end
        self:_setActiveTab(other, active)
    end
    self.ActiveTab = tab
    self.TabTitle.Text = tab.Name
    self.TabSubtitle.Text = tab.Description or ""
    if self.TabHeader then self.TabHeader.Visible = tab.HideHeader ~= true end
    if tab.LayoutPills then tab:LayoutPills() end
    if tab.Status then
        self:SetStatus(tab.Status.Text, tab.Status.Color)
    end
    -- Keep dashboard navigation in sync with the regular sidebar. Pills are
    -- optional; tabs without a matching TargetTab continue to work normally.
    for _, dashboard in ipairs(self.Tabs) do
        local linkedPill
        for _, pill in ipairs(dashboard.Pills or {}) do
            if pill.TargetTab == tab then linkedPill = pill; break end
        end
        if linkedPill and dashboard.ActivePill ~= linkedPill then
            dashboard:SelectPill(linkedPill, true)
        end
    end
    if self.GlowStroke then
        tween(self.GlowStroke, { Transparency = 0.34 }, 0.14)
        task.delay(0.18, function()
            if not self._destroyed then tween(self.GlowStroke, { Transparency = 0.58 }, 0.3) end
        end)
    end
end

function AxelUI:SetStatus(text, color)
    if not self.StatusText then return end
    local status = tostring(text or "Ready")
    self.StatusText.Text = status
    local tint = color or self.Theme.Success
    self.StatusDot.BackgroundColor3 = tint
    self.StatusText.TextColor3 = tint
    if self.RestoreStatusText then
        self.RestoreStatusText.Text = status
        self.RestoreStatusText.TextColor3 = tint
    end
    if self.RestoreStatusDot then self.RestoreStatusDot.BackgroundColor3 = tint end
end

function AxelUI:Notify(message, content, notificationType)
    if self._destroyed then return end
    local data
    if type(message) == "table" then
        data = message
    else
        data = { Title = message, Content = content, Type = notificationType }
    end
    local kind = string.lower(tostring(data.Type or "info"))
    local colors = {
        success = self.Theme.Success,
        warning = self.Theme.Warning,
        error = self.Theme.Danger,
        danger = self.Theme.Danger,
        info = self.Theme.Accent2,
    }
    local icons = { success = "check", warning = "info", error = "x", danger = "x", info = "info" }
    local accent = colors[kind] or self.Theme.Accent2
    local holder = self.NotificationHolder
    if not holder then return end
    local card = new("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 301,
    }, holder)
    corner(card, 7)
    stroke(card, accent, 0.28, 1)
    local stripe = new("Frame", { BackgroundColor3 = accent, BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, 0), ZIndex = 302 }, card)
    corner(stripe, 2)
    local iconHolder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(12, 12), ZIndex = 302 }, card)
    local typeIcon = icon(iconHolder, data.Icon or icons[kind] or "info", 16, accent); typeIcon.Position = UDim2.fromOffset(4, 4); typeIcon.ZIndex = 303
    local title = textLabel(card, data.Title or "Axel Hub", 12, self.Theme.Text, true); title.Position = UDim2.fromOffset(45, 8); title.Size = UDim2.new(1, -78, 0, 18); title.ZIndex = 302
    local body = textLabel(card, data.Content or "", 10, self.Theme.SubText, false); body.Position = UDim2.fromOffset(45, 27); body.Size = UDim2.new(1, -56, 0, 30); body.TextWrapped = true; body.TextYAlignment = Enum.TextYAlignment.Top; body.ZIndex = 302
    local close = new("TextButton", { AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -27, 0, 8), ZIndex = 302 }, card)
    local closeIcon = icon(close, "x", 11, self.Theme.Muted); closeIcon.Position = UDim2.fromOffset(4, 4); closeIcon.ZIndex = 303
    local scale = new("UIScale", { Scale = 0.88 }, card)
    local closed = false
    local function closeCard()
        if closed then return end
        closed = true
        tween(scale, { Scale = 0.88 }, 0.14)
        tween(card, { BackgroundTransparency = 1 }, 0.14)
        task.delay(0.16, function() if card.Parent then card:Destroy() end end)
    end
    connect(self, close.MouseButton1Click, closeCard)
    table.insert(self._notifications, card)
    tween(scale, { Scale = 1 }, 0.22, Enum.EasingStyle.Back)
    local duration = tonumber(data.Duration)
    if duration == nil then duration = 3.5 end
    if duration > 0 then task.delay(duration, closeCard) end
    return { Instance = card, Close = closeCard }
end

function AxelUI:SetOpen(visible)
    if self._destroyed or not self.Window then return end
    visible = visible == true
    self._open = visible
    -- Keep sampling while minimized so the floating restore card stays live.
    setFpsSampling(self, true)
    if visible then
        self.Window.Visible = true
        self.Window.BackgroundTransparency = self.GlassEnabled and self.GlassTransparency or 0
        if self.Scale then
            if self.AnimateOpenClose then
                self.Scale.Scale = 0.97
                tween(self.Scale, { Scale = 1 }, 0.14, Enum.EasingStyle.Quint)
            else
                self.Scale.Scale = 1
            end
        end
        if self.GlowStroke then
            tween(self.GlowStroke, { Transparency = 0.015, Thickness = 2 }, 0.14, Enum.EasingStyle.Quint)
            task.delay(0.62, function()
                if not self._destroyed and self._open then tween(self.GlowStroke, { Transparency = 0.2, Thickness = 1.5 }, 0.3) end
            end)
        end
        if self.RestoreButton and self.RestoreButton.Visible then
            tween(self.RestoreScale, { Scale = 0.65 }, 0.12)
            task.delay(0.13, function() if self._open and self.RestoreButton then self.RestoreButton.Visible = false end end)
        end
    else
        tween(self.GlowStroke, { Transparency = 0.72, Thickness = 1 }, 0.18)
        local function finishClose()
            if not self._destroyed and not self._open then
                self.Window.Visible = false
                if self.Scale then self.Scale.Scale = 1 end
                if self.RestoreButton then
                    self.RestoreButton.Position = UDim2.new(0.5, -94, 0.5, -24)
                    self.RestoreButton.Visible = true
                    self.RestoreButton.BackgroundTransparency = 0.08
                    local restoreStroke = self.RestoreButton:FindFirstChildOfClass("UIStroke")
                    if restoreStroke then restoreStroke.Transparency = 0.04 end
                    if self.RestoreScale then self.RestoreScale.Scale = 0.72; tween(self.RestoreScale, { Scale = 1 }, 0.28, Enum.EasingStyle.Back) end
                end
            end
        end
        if self.AnimateOpenClose then
            if self.Scale then tween(self.Scale, { Scale = 0.97 }, 0.12, Enum.EasingStyle.Quint, Enum.EasingDirection.In) end
            task.delay(0.13, finishClose)
        else
            finishClose()
        end
    end
    setAccentAnimations(self, visible)
    if self.TouchButton and self.TouchButton ~= self.RestoreButton then self.TouchButton.Visible = not visible end
end

function AxelUI:SetMaximized(value)
    if self._destroyed or not self.Window then return end
    value = value == true
    if value then
        self._restoreSize = self.Window.Size
        self._maximized = true
    else
        self._maximized = false
        self.Window.Size = self._restoreSize or self.DesktopSize or UDim2.fromOffset(926, 616)
    end
    self:_applyResponsive()
end

function AxelUI:SetToggleKeybind(key)
    self.ToggleKeybind = key or Enum.KeyCode.RightControl
end

-- Glass tints the window shell and page backdrop; header, sidebar, cards and
-- controls stay solid so their text and states remain readable.
function AxelUI:SetGlass(value, transparency)
    if type(value) == "table" then
        if value.Enabled ~= nil then self.GlassEnabled = value.Enabled == true end
        if value.Transparency ~= nil then transparency = value.Transparency end
    else
        self.GlassEnabled = value == true
    end
    if transparency ~= nil then
        self.GlassTransparency = math.clamp(tonumber(transparency) or 0, 0, 0.45)
    end
    if self.Window then
        self.Window.BackgroundTransparency = self.GlassEnabled and self.GlassTransparency or 0
    end
    if self.PageHolder then
        -- Match the v7.2 dark-glass treatment on the page itself; a fully
        -- transparent holder lets bright map scenery wash through the UI.
        self.PageHolder.BackgroundTransparency = self.GlassEnabled and self.GlassTransparency or 0
        for _, cap in ipairs(self.PageCornerCaps or {}) do
            cap.BackgroundTransparency = self.GlassEnabled and self.GlassTransparency or 0
        end
    end
    return self
end

local function sameColor(a, b)
    return a and b and math.abs(a.R - b.R) < 0.001 and math.abs(a.G - b.G) < 0.001 and math.abs(a.B - b.B) < 0.001
end

function AxelUI:SetTheme(theme)
    if not self.Gui then
        self._pendingTheme = normalizeTheme(theme, self._pendingTheme)
        return self
    end
    local old = self.Theme or copyTheme()
    local nextTheme = normalizeTheme(theme, old)
    local palette = {
        { old.Background, nextTheme.Background }, { old.Surface, nextTheme.Surface },
        { old.Surface2, nextTheme.Surface2 }, { old.Element, nextTheme.Element },
        { old.ElementHover, nextTheme.ElementHover }, { old.Border, nextTheme.Border },
        { old.Text, nextTheme.Text }, { old.SubText, nextTheme.SubText },
        { old.Muted, nextTheme.Muted }, { old.Accent, nextTheme.Accent },
        { old.Accent2, nextTheme.Accent2 }, { old.Accent3, nextTheme.Accent3 }, { old.Success, nextTheme.Success },
        { old.Warning, nextTheme.Warning }, { old.Danger, nextTheme.Danger },
    }
    self.Theme = nextTheme
    for _, object in ipairs(self.Gui:GetDescendants()) do
        for _, pair in ipairs(palette) do
            local before, after = pair[1], pair[2]
            pcall(function()
                if object:IsA("GuiObject") and sameColor(object.BackgroundColor3, before) then object.BackgroundColor3 = after end
                if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                    if sameColor(object.TextColor3, before) then object.TextColor3 = after end
                end
                if object:IsA("ImageLabel") or object:IsA("ImageButton") then
                    if sameColor(object.ImageColor3, before) then object.ImageColor3 = after end
                end
                if object:IsA("UIStroke") and sameColor(object.Color, before) then object.Color = after end
            end)
        end
        pcall(function()
            if object:IsA("UIGradient") then
                local remapped, changed = {}, false
                for _, keypoint in ipairs(object.Color.Keypoints) do
                    local color = keypoint.Value
                    for _, pair in ipairs(palette) do
                        if sameColor(color, pair[1]) then color = pair[2]; changed = true; break end
                    end
                    table.insert(remapped, ColorSequenceKeypoint.new(keypoint.Time, color))
                end
                if changed then object.Color = ColorSequence.new(remapped) end
            end
        end)
    end
    for _, entry in pairs(self._searchData or {}) do
        if entry.BaseTitleColor then
            for _, pair in ipairs(palette) do
                if sameColor(entry.BaseTitleColor, pair[1]) then entry.BaseTitleColor = pair[2]; break end
            end
        end
    end
    pcall(function() self.Window.BackgroundColor3 = self.Theme.Background end)
    pcall(function() self.GlowStroke.Color = self.Theme.Accent end)
    pcall(function()
        if self.EdgeGradient then
            self.EdgeGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, self.Theme.Accent3),
                ColorSequenceKeypoint.new(0.22, self.Theme.Accent),
                ColorSequenceKeypoint.new(0.5, self.Theme.Accent2),
                ColorSequenceKeypoint.new(0.78, self.Theme.Accent),
                ColorSequenceKeypoint.new(1, self.Theme.Accent3),
            })
        end
    end)
    self:_refreshSearch(self.Search and self.Search.Text or "")
    return self
end

function AxelUI:GetTheme()
    return copyTheme(self.Theme or self._pendingTheme)
end

function AxelUI:SetBackground(source, transparency, scaleType)
    if not self.Gui or not self.Window then return nil end
    local image = imageSource(source, self.AssetFolder)
    if not image then return self:ClearBackground() end
    if not self.BackgroundImage then
        self.BackgroundImage = new("ImageLabel", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 0,
        }, self.Window)
    end
    self.BackgroundImage.Image = image
    self.BackgroundImage.ImageTransparency = tonumber(transparency) or 0.72
    self.BackgroundImage.ScaleType = scaleType or Enum.ScaleType.Crop
    return self.BackgroundImage
end

function AxelUI:ClearBackground()
    if self.BackgroundImage then
        self.BackgroundImage:Destroy()
        self.BackgroundImage = nil
    end
end

local function cleanConfigName(name)
    local value = tostring(name or "default"):gsub("[^%w%-%_]", "_")
    return value == "" and "default" or value
end

local function configPath(window, name)
    local folder = tostring(window.ConfigFolder or "AxelUIConfigs")
    return folder .. "/" .. cleanConfigName(name) .. ".json"
end

function AxelUI:_saveConfig(name)
    if type(writefile) ~= "function" then return false, "writefile is unavailable" end
    local folder = tostring(self.ConfigFolder or "AxelUIConfigs")
    pcall(function()
        if type(makefolder) == "function" and (type(isfolder) ~= "function" or not isfolder(folder)) then makefolder(folder) end
    end)
    local values = {}
    for flag, handle in pairs(self._flags or {}) do
        if handle and type(handle.Get) == "function" then
            local ok, value = pcall(handle.Get, handle)
            if ok and (type(value) == "boolean" or type(value) == "number" or type(value) == "string" or type(value) == "table") then
                values[flag] = value
            end
        end
    end
    local okEncode, encoded = pcall(function() return HttpService:JSONEncode(values) end)
    if not okEncode then return false, tostring(encoded) end
    local okWrite, err = pcall(writefile, configPath(self, name), encoded)
    return okWrite, okWrite and nil or tostring(err)
end

function AxelUI:_loadConfig(name)
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return false, "readfile/isfile is unavailable" end
    local path = configPath(self, name)
    local exists = false
    pcall(function() exists = isfile(path) == true end)
    if not exists then return false, "config does not exist" end
    local okRead, content = pcall(readfile, path)
    if not okRead then return false, tostring(content) end
    local okDecode, values = pcall(function() return HttpService:JSONDecode(content) end)
    if not okDecode or type(values) ~= "table" then return false, "invalid config data" end
    for flag, value in pairs(values) do
        local handle = self._flags and self._flags[tostring(flag)]
        if handle and type(handle.Set) == "function" then pcall(handle.Set, handle, value, true) end
    end
    return true
end

function AxelUI:_listConfigs()
    if type(listfiles) ~= "function" then return {} end
    local result = {}
    local folder = tostring(self.ConfigFolder or "AxelUIConfigs")
    pcall(function()
        for _, path in ipairs(listfiles(folder)) do
            local name = tostring(path):match("([^/\\]+)%.json$")
            if name then table.insert(result, name) end
        end
    end)
    table.sort(result)
    return result
end

function AxelUI:SaveConfig(name)
    local target = self.Gui and self or self._activeWindow
    if target then return target:_saveConfig(name) end
    return false, "no active window"
end

function AxelUI:LoadConfig(name)
    local target = self.Gui and self or self._activeWindow
    if target then return target:_loadConfig(name) end
    return false, "no active window"
end

function AxelUI:ListConfigs()
    local target = self.Gui and self or self._activeWindow
    return target and target:_listConfigs() or {}
end

function AxelUI:DeleteConfig(name)
    local target = self.Gui and self or self._activeWindow
    if not target or type(delfile) ~= "function" then return false, "delfile is unavailable" end
    local ok, err = pcall(delfile, configPath(target, name))
    return ok, ok and nil or tostring(err)
end

function AxelUI:_applyResponsive()
    if self._destroyed or not self.Window then return end
    local viewport = Vector2.new(1280, 720)
    pcall(function()
        if workspace.CurrentCamera then viewport = workspace.CurrentCamera.ViewportSize end
    end)
    local mobile = viewport.X <= 760 or (UserInputService.TouchEnabled and viewport.X <= 900)
    self.IsMobile = mobile
    local desktopWidth

    if mobile then
        local maxWidth = math.max(180, math.min(480, viewport.X - 18))
        local maxHeight = math.max(220, math.min(720, viewport.Y - 26))
        local mobileSize = self.MobileSize
        local width = self._maximized and maxWidth or (mobileSize and math.clamp(mobileSize.X.Offset, math.min(300, maxWidth), maxWidth) or maxWidth)
        local height = self._maximized and maxHeight or (mobileSize and math.clamp(mobileSize.Y.Offset, math.min(360, maxHeight), maxHeight) or maxHeight)
        self.Window.Size = UDim2.fromOffset(width, height)
        self.Header.Position = UDim2.fromOffset(64, 0)
        self.Header.Size = UDim2.new(1, -64, 0, 50)
        self.Sidebar.Position = UDim2.fromOffset(0, 0)
        self.Sidebar.Size = UDim2.new(0, 64, 1, 0)
        self.TabList.Position = UDim2.fromOffset(8, 58)
        self.TabList.Size = UDim2.new(1, -16, 1, -66)
        self.PageHolder.Position = UDim2.fromOffset(64, 50)
        self.PageHolder.Size = UDim2.new(1, -64, 1, -50)
        self.NavTitle.Visible = false
        self.Footer.Visible = false
        self.ProfileCard.Visible = false
        self.Brand.Visible = false
        self.HeaderSubtitle.Visible = false
        self.DragHandle.Visible = self.Draggable
        self.DragHandle.Position = UDim2.new(1, -132, 0, 5)
        self.DragHandle.Size = UDim2.fromOffset(24, 40)
        self.ResizeHandle.Visible = self.Resizable and not self._maximized
        self.ResizeHandle.Size = UDim2.fromOffset(28, 28)
        self.FpsText.Visible = false
        self.FpsValue.Visible = false
        self.StatusSeparator.Visible = false
        self.StatusDot.Visible = false
        self.StatusText.Visible = false
        self.Search.Position = UDim2.fromOffset(8, 9)
        self.Search.Size = UDim2.new(1, -146, 0, 32)
        self.SearchIcon.Position = UDim2.fromOffset(18, 17)
        self.TabTitle.TextSize = 13
        self.TabSubtitle.Visible = false
        self.TabHeader.Size = UDim2.new(1, 0, 0, 38)
        self.TabTitle.Position = UDim2.fromOffset(16, 8)
        if self.RestoreButton then self.RestoreButton.Visible = not self._open end
        self.NotificationHolder.Size = UDim2.fromOffset(220, 0)
        self.NotificationHolder.Position = UDim2.new(1, -10, 0, 58)
    else
        local maxWidth = math.max(320, math.min(1440, viewport.X - 32))
        local maxHeight = math.max(280, math.min(1000, viewport.Y - 32))
        if self._maximized then
            desktopWidth = math.max(1, viewport.X - 32)
            self.Window.Size = UDim2.new(1, -32, 1, -32)
        else
            local desired = self.DesktopSize or UDim2.fromOffset(926, 616)
            local desiredWidth = desired.X.Scale == 0 and desired.X.Offset or self.Window.AbsoluteSize.X
            local desiredHeight = desired.Y.Scale == 0 and desired.Y.Offset or self.Window.AbsoluteSize.Y
            desktopWidth = math.clamp(desiredWidth, math.min(760, maxWidth), maxWidth)
            self.Window.Size = UDim2.fromOffset(
                desktopWidth,
                math.clamp(desiredHeight, math.min(480, maxHeight), maxHeight)
            )
        end
        self.Header.Position = UDim2.fromOffset(170, 0)
        self.Header.Size = UDim2.new(1, -170, 0, 58)
        self.Sidebar.Position = UDim2.fromOffset(0, 0)
        self.Sidebar.Size = UDim2.new(0, 170, 1, 0)
        self.TabList.Position = UDim2.fromOffset(8, 112)
        -- Reserve the profile card and footer at the bottom of the sidebar.
        -- The old -192 inset let the scroll viewport run behind the profile.
        self.TabList.Size = UDim2.new(1, -16, 1, -232)
        self.PageHolder.Position = UDim2.fromOffset(170, 58)
        self.PageHolder.Size = UDim2.new(1, -170, 1, -58)
        self.NavTitle.Visible = true
        self.Footer.Visible = true
        self.ProfileCard.Visible = true
        self.Brand.Visible = true
        self.HeaderSubtitle.Visible = true
        self.DragHandle.Visible = self.Draggable
        self.DragHandle.Position = UDim2.fromOffset(404, 0)
        self.DragHandle.Size = UDim2.new(1, -536, 1, 0)
        self.ResizeHandle.Visible = self.Resizable and not self._maximized
        self.ResizeHandle.Size = UDim2.fromOffset(24, 24)
        self.FpsText.Visible = true
        self.FpsValue.Visible = true
        self.StatusSeparator.Visible = true
        self.StatusDot.Visible = true
        self.StatusText.Visible = true
        self.Search.Position = UDim2.fromOffset(20, 14)
        self.Search.Size = UDim2.fromOffset(math.min(374, math.max(160, (desktopWidth or self.Window.AbsoluteSize.X) - 526)), 34)
        self.SearchIcon.Position = UDim2.fromOffset(31, 23)
        self.TabTitle.TextSize = 15
        self.TabSubtitle.Visible = true
        self.TabHeader.Size = UDim2.new(1, 0, 0, 46)
        self.TabTitle.Position = UDim2.fromOffset(22, 6)
        if self.RestoreButton then self.RestoreButton.Visible = not self._open end
        self.NotificationHolder.Size = UDim2.fromOffset(300, 0)
        self.NotificationHolder.Position = UDim2.new(1, -18, 0, 62)
    end

    -- Keep the rounded outer shell fully on-screen on short viewports and
    -- after a screen-orientation change, without resetting a valid drag.
    if not self._dragging then
        local absolute, size = self.Window.AbsolutePosition, self.Window.AbsoluteSize
        local left = math.clamp(absolute.X, 8, math.max(8, viewport.X - size.X - 8))
        local top = math.clamp(absolute.Y, 8, math.max(8, viewport.Y - size.Y - 8))
        if math.abs(left - absolute.X) > 1 or math.abs(top - absolute.Y) > 1 then
            self.Window.Position = UDim2.new(0.5, left + size.X / 2 - viewport.X / 2, 0.5, top + size.Y / 2 - viewport.Y / 2)
        end
    end

    for _, tab in ipairs(self.Tabs) do
        if tab.Title then tab.Title.Visible = not mobile end
        if tab.Subtitle then tab.Subtitle.Visible = not mobile end
        if tab.IconHolder then
            tab.IconHolder.Position = UDim2.fromOffset(mobile and 20 or 12, 7)
        end
        if tab.Hero and tab.PageBody and not tab.SubTabBar then
            local heroHeight = mobile and (tab.HeroMobileHeight or tab.HeroHeight or 104) or (tab.HeroHeight or 104)
            local heroTop = tab.HideHeader and (mobile and 16 or 18) or 50
            tab.Hero.Size = UDim2.new(1, mobile and -16 or -26, 0, heroHeight)
            tab.Hero.Position = UDim2.fromOffset(mobile and 8 or 13, heroTop)
            if tab.HeroWelcome and tab.HeroBanner then
                if mobile then
                    local welcomeHeight = math.min(82, math.max(68, heroHeight * 0.36))
                    tab.HeroWelcome.Position = UDim2.fromOffset(8, 0)
                    tab.HeroWelcome.Size = UDim2.new(1, -16, 0, welcomeHeight)
                    tab.HeroBanner.Position = UDim2.fromOffset(8, welcomeHeight + 4)
                    tab.HeroBanner.Size = UDim2.new(1, -16, 1, -(welcomeHeight + 4))
                else
                    tab.HeroWelcome.Position = UDim2.fromOffset(0, 0)
                    tab.HeroWelcome.Size = UDim2.new(0.35, 0, 1, 0)
                    tab.HeroBanner.Position = UDim2.new(0.35, 8, 0, 0)
                    tab.HeroBanner.Size = UDim2.new(0.65, -8, 1, 0)
                end
            end
            tab.PageBody.Position = UDim2.fromOffset(mobile and 8 or 13, heroTop + heroHeight + 10)
            tab.PageBody.Size = UDim2.new(1, mobile and -16 or -26, 1, -(heroTop + heroHeight + 20))
        end
        if tab.ColumnLayout then
            tab.ColumnLayout.FillDirection = mobile and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
            tab.ColumnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            tab.ColumnLayout.Padding = UDim.new(0, mobile and 8 or 10)
        end
        if tab.LeftBody then tab.LeftBody.Size = mobile and UDim2.new(1, 0, 0, 0) or UDim2.new(0.5, -5, 0, 0) end
        if tab.RightBody then tab.RightBody.Size = mobile and UDim2.new(1, 0, 0, 0) or UDim2.new(0.5, -5, 0, 0) end
        if tab.SubTabBar then
            local heroHeight = tab.Hero and (mobile and (tab.HeroMobileHeight or tab.HeroHeight or 104) or (tab.HeroHeight or 104)) or 0
            local heroTop = tab.HideHeader and (mobile and 16 or 18) or 50
            local pillY = heroHeight > 0 and (heroTop + heroHeight + 4) or 50
            tab.SubTabBar.Position = UDim2.fromOffset(mobile and 8 or 13, pillY)
            tab.SubTabBar.Size = UDim2.new(1, mobile and -16 or -26, 0, 42)
        end
        for _, subtab in ipairs(tab.SubTabs or {}) do
            if subtab.PageBody then
                local heroHeight = tab.Hero and (mobile and (tab.HeroMobileHeight or tab.HeroHeight or 104) or (tab.HeroHeight or 104)) or 0
                local heroTop = tab.HideHeader and (mobile and 16 or 18) or 50
                local contentY = heroHeight > 0 and (heroTop + heroHeight + 54) or 98
                local contentBottom = heroHeight > 0 and (heroTop + heroHeight + 64) or 108
                subtab.PageBody.Position = UDim2.fromOffset(mobile and 8 or 13, contentY)
                subtab.PageBody.Size = UDim2.new(1, mobile and -16 or -26, 1, -contentBottom)
            end
            if subtab.ColumnLayout then
                subtab.ColumnLayout.FillDirection = mobile and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
                subtab.ColumnLayout.Padding = UDim.new(0, mobile and 8 or 10)
            end
            if subtab.LeftBody then subtab.LeftBody.Size = mobile and UDim2.new(1, 0, 0, 0) or UDim2.new(0.5, -5, 0, 0) end
            if subtab.RightBody then subtab.RightBody.Size = mobile and UDim2.new(1, 0, 0, 0) or UDim2.new(0.5, -5, 0, 0) end
        end
        if tab.LayoutPills then tab:LayoutPills() end
    end
end

function AxelUI:SetFont(font)
    self._font = font
    ACTIVE_FONT = font
    if self.Gui then
        for _, object in ipairs(self.Gui:GetDescendants()) do
            if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                pcall(function()
                    local weight = object.FontFace and object.FontFace.Weight
                    local bold = weight and weight.Value >= Enum.FontWeight.SemiBold.Value or false
                    object.FontFace = fontFace(font, bold)
                end)
            end
        end
    end
    return self
end

local function preserveHeight(instance, height)
    if not instance then return end
    local size = instance.Size
    local nextHeight = math.max(0, height or 0)
    if size.Y.Scale ~= 0 or size.Y.Offset ~= nextHeight then
        instance.Size = UDim2.new(size.X.Scale, size.X.Offset, 0, nextHeight)
    end
end

local function bindVerticalLayout(window, parent, layout, extra, onSize)
    local function sync()
        local height = (layout.AbsoluteContentSize and layout.AbsoluteContentSize.Y or 0) + (extra or 0)
        preserveHeight(parent, height)
        if onSize then onSize(height) end
    end
    local syncQueued = false
    local function queueSync()
        if syncQueued then return end
        syncQueued = true
        task.defer(function()
            syncQueued = false
            if window._destroyed then return end
            sync()
        end)
    end
    local function watch(child)
        if not child or not child:IsA("GuiObject") then return end
        connect(window, child:GetPropertyChangedSignal("Size"), queueSync)
        connect(window, child:GetPropertyChangedSignal("Visible"), queueSync)
    end
    connect(window, layout:GetPropertyChangedSignal("AbsoluteContentSize"), queueSync)
    connect(window, parent.ChildAdded, function(child) watch(child); queueSync() end)
    connect(window, parent.ChildRemoved, queueSync)
    for _, child in ipairs(parent:GetChildren()) do watch(child) end
    queueSync()
    return sync
end

local function makePageColumns(window, page, topOffset)
    -- AddTab is called on the window, while AddSubTab is called on a tab.
    -- Normalize both owners here so layout helpers always receive the window
    -- (Theme, connection registry, mobile state), never the tab wrapper.
    if not window.Theme and window.Window and window.Window.Theme then
        window = window.Window
    end
    topOffset = topOffset or 50
    local pageBody = new("ScrollingFrame", {
        Active = true,
        AutomaticCanvasSize = Enum.AutomaticSize.None,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        ScrollBarImageColor3 = window.Theme.Accent,
        ScrollBarThickness = 3,
        Size = UDim2.new(1, -26, 1, -(topOffset + 10)),
        Position = UDim2.fromOffset(13, topOffset),
    }, page)
    pad(pageBody, 0, 5, 0, 10)
    local columns = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
    }, pageBody)
    local leftColumn = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0.5, -5, 0, 0),
        LayoutOrder = 1,
    }, columns)
    local rightColumn = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0.5, -5, 0, 0),
        LayoutOrder = 2,
    }, columns)
    local columnLayout = new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, columns)
    local leftLayout = new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, leftColumn)
    local rightLayout = new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, rightColumn)
    local function syncColumns()
        preserveHeight(leftColumn, leftLayout.AbsoluteContentSize.Y)
        preserveHeight(rightColumn, rightLayout.AbsoluteContentSize.Y)
        preserveHeight(columns, columnLayout.AbsoluteContentSize.Y)
        pageBody.CanvasSize = UDim2.new(0, 0, 0, columnLayout.AbsoluteContentSize.Y + 18)
    end
    local columnsSyncQueued = false
    local function queueSyncColumns()
        if columnsSyncQueued then return end
        columnsSyncQueued = true
        task.defer(function()
            columnsSyncQueued = false
            if window._destroyed then return end
            syncColumns()
        end)
    end
    connect(window, leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"), queueSyncColumns)
    connect(window, rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"), queueSyncColumns)
    connect(window, columnLayout:GetPropertyChangedSignal("AbsoluteContentSize"), queueSyncColumns)
    connect(window, leftColumn.ChildAdded, queueSyncColumns)
    connect(window, leftColumn.ChildRemoved, queueSyncColumns)
    connect(window, rightColumn.ChildAdded, queueSyncColumns)
    connect(window, rightColumn.ChildRemoved, queueSyncColumns)
    queueSyncColumns()
    return pageBody, columns, leftColumn, rightColumn, columnLayout, leftLayout, rightLayout
end

local function makeSubTabCard(window, parent, title)
    local card = new("Frame", {
        BackgroundColor3 = window.Theme.Surface,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Size = UDim2.new(1, -5, 0, 0),
    }, parent)
    corner(card, 8)
    stroke(card, window.Theme.Border, 0.28, 1)
    if not window.ReduceEffects then
        new("UIGradient", {
            Color = ColorSequence.new(window.Theme.Surface, window.Theme.Background),
            Transparency = NumberSequence.new(0),
            Rotation = 90,
        }, card)
    end
    local cardHeader = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32) }, card)
    pad(cardHeader, 12, 12, 6, 3)
    local cardTitle = textLabel(cardHeader, title, 13, window.Theme.Text, true)
    cardTitle.Size = UDim2.new(1, -10, 0, 20)
    local body = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 32),
        Size = UDim2.new(1, 0, 0, 0),
    }, card)
    pad(body, 10, 10, 2, 10)
    local layout = new("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, body)
    bindVerticalLayout(window, body, layout, 12, function(height)
        preserveHeight(card, 32 + height)
    end)
    return card, body, layout
end

function AxelUI:AddTab(data)
    data = type(data) == "table" and data or { Name = data }
    local tab = {
        Window = self,
        Name = tostring(data.Name or data.name or "Tab"),
        Description = tostring(data.Description or data.Subtitle or data.subtitle or ""),
        IconValue = data.Icon or data.icon,
        Status = nil,
        Sections = {},
    }
    setmetatable(tab, { __index = self.TabMethods })

    local button = new("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Theme.Surface,
        BorderSizePixel = 0,
        Text = "",
        Size = UDim2.new(1, 0, 0, 40),
    }, self.TabList)
    corner(button, 11)
    local tabStroke = stroke(button, self.Theme.Border, 0.62, 1)
    tab.GoldGradient = addGoldGradient(self, button)
    local indicator = new("Frame", {
        BackgroundColor3 = self.Theme.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0.18, 0),
        Size = UDim2.new(0, 3, 0.64, 0),
    }, button)
    corner(indicator, 2)
    local iconHolder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(12, 7) }, button)
    local tabIcon = icon(iconHolder, tab.IconValue or "dashboard", 18, self.Theme.SubText)
    tabIcon.Position = UDim2.fromOffset(3, 3)
    local title = textLabel(button, tab.Name, 12, self.Theme.SubText, true)
    title.Position = UDim2.fromOffset(43, 2)
    title.Size = UDim2.new(1, -75, 0, 21)
    title.TextTruncate = Enum.TextTruncate.AtEnd
    local subtitle = textLabel(button, tab.Description, 9, self.Theme.Muted, false)
    subtitle.Position = UDim2.fromOffset(43, 21)
    subtitle.Size = UDim2.new(1, -75, 0, 14)
    subtitle.TextTruncate = Enum.TextTruncate.AtEnd
    local badge
    if data.Badge ~= nil then
        badge = new("TextLabel", {
            BackgroundColor3 = self.Theme.Accent,
            TextColor3 = self.Theme.Background,
            Text = tostring(data.Badge),
            TextSize = 9,
            FontFace = fontFace(nil, true),
            Size = UDim2.fromOffset(28, 16),
            Position = UDim2.new(1, -38, 0, 11),
        }, button)
        corner(badge, 8)
    end
    tab.Button, tab.Title, tab.Subtitle, tab.IconHolder, tab.Icon, tab.Indicator, tab.Badge, tab.TabStroke = button, title, subtitle, iconHolder, tabIcon, indicator, badge, tabStroke

    local page = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Visible = false,
    }, self.PageHolder)
    local pageBody, columns, leftColumn, rightColumn, columnLayout, leftLayout, rightLayout = makePageColumns(self, page, 50)
    tab.Page, tab.Body, tab.Layout = page, leftColumn, leftLayout
    tab.Columns, tab.LeftBody, tab.RightBody = columns, leftColumn, rightColumn
    tab.PageBody = pageBody
    tab.ColumnLayout = columnLayout
    tab._nextSide = "Left"
    tab.SubTabs = {}
    table.insert(self.Tabs, tab)
    tab.PageIndex = #self.Tabs

    connect(self, button.MouseButton1Click, function() self:SelectTab(tab) end)
    connect(self, button.MouseEnter, function()
        if self.ActiveTab ~= tab then
            tween(button, { BackgroundColor3 = self.Theme.Surface:Lerp(self.Theme.Accent, 0.12) }, 0.14)
            if tab.TabStroke then tween(tab.TabStroke, { Transparency = 0.12, Color = self.Theme.Accent2, Thickness = 1.2 }, 0.14) end
        end
    end)
    connect(self, button.MouseLeave, function()
        if self.ActiveTab ~= tab then
            tween(button, { BackgroundColor3 = self.Theme.Surface }, 0.16)
            if tab.TabStroke then tween(tab.TabStroke, { Transparency = 0.62, Color = self.Theme.Border, Thickness = 1 }, 0.16) end
        end
    end)
    addButtonGlass(self, button, 0)
    pressAnimation(self, button)
    if #self.Tabs == 1 then self:SelectTab(tab) end
    if self._applyResponsive then self:_applyResponsive() end
    if self.EmptyState then self.EmptyState.Visible = false end
    return tab
end

function AxelUI.TabMethods:SetBadge(value, color)
    if not self.Badge then
        self.Badge = new("TextLabel", {
            BackgroundColor3 = self.Window.Theme.Accent,
            TextColor3 = self.Window.Theme.Background,
            TextSize = 9,
            FontFace = fontFace(nil, true),
            Size = UDim2.fromOffset(28, 16),
            Position = UDim2.new(1, -38, 0, 11),
        }, self.Button)
        corner(self.Badge, 8)
    end
    self.Badge.Text = tostring(value or "")
    self.Badge.Visible = value ~= nil and tostring(value) ~= ""
    if color then self.Badge.BackgroundColor3 = color end
end

function AxelUI.TabMethods:SetStatus(text, color)
    self.Status = { Text = tostring(text or "Ready"), Color = color or self.Window.Theme.Success }
    if self.Window.ActiveTab == self then self.Window:SetStatus(self.Status.Text, self.Status.Color) end
end

-- Split dashboard hero: a welcome block on the left and an image banner on the
-- right, matching the reference dashboard composition without extra wrappers.
function AxelUI.TabMethods:AddHero(data)
    data = data or {}
    local height = tonumber(data.Height) or 104
    local mobileHeight = tonumber(data.MobileHeight) or math.max(226, height + 122)
    local heroTop = self.Window.IsMobile and 16 or 18
    self.HideHeader = data.HideTabHeader ~= false
    if self.Window.ActiveTab == self and self.Window.TabHeader then self.Window.TabHeader.Visible = not self.HideHeader end
    local hero = new("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(13, heroTop),
        Size = UDim2.new(1, -26, 0, height),
        ClipsDescendants = true,
        ZIndex = 3,
    }, self.Page)
    local welcome = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.35, 0, 1, 0), ZIndex = 3 }, hero)
    local welcomeLabel = textLabel(welcome, data.WelcomeLabel or "Welcome to", 15, self.Window.Theme.SubText, false)
    welcomeLabel.Position = UDim2.fromOffset(8, 8); welcomeLabel.Size = UDim2.new(1, -16, 0, 22); welcomeLabel.ZIndex = 7
    local welcomeTitle = textLabel(welcome, data.WelcomeTitle or "Axel Hub", 38, self.Window.Theme.Text, true)
    welcomeTitle.Position = UDim2.fromOffset(8, 28); welcomeTitle.Size = UDim2.new(1, -12, 0, 46); welcomeTitle.TextTruncate = Enum.TextTruncate.AtEnd; welcomeTitle.ZIndex = 7
    local welcomeContent = textLabel(welcome, data.WelcomeContent or "Powerful tools. A smoother way to play.", 11, self.Window.Theme.SubText, false)
    welcomeContent.Position = UDim2.fromOffset(8, 76); welcomeContent.Size = UDim2.new(1, -12, 0, 20); welcomeContent.TextWrapped = true; welcomeContent.ZIndex = 7

    local banner = new("Frame", {
        BackgroundColor3 = self.Window.Theme.Element,
        BorderSizePixel = 0,
        Position = UDim2.new(0.35, 8, 0, 0),
        Size = UDim2.new(0.65, -8, 1, 0),
        ClipsDescendants = true,
        ZIndex = 3,
    }, hero)
    corner(banner, 11); stroke(banner, self.Window.Theme.Border, 0.14, 1)
    local source = imageSource(data.Image or data.Source or data.Asset, self.Window.AssetFolder)
    banner.BackgroundColor3 = source and self.Window.Theme.Element or Color3.fromRGB(61, 45, 24)
    new("UIGradient", { Color = source and ColorSequence.new(self.Window.Theme.Element, self.Window.Theme.Surface) or ColorSequence.new(Color3.fromRGB(107, 71, 26), self.Window.Theme.Background), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, source and 0.02 or 0.08), NumberSequenceKeypoint.new(1, source and 0.12 or 0.24) }), Rotation = 25 }, banner)
    local picture = new("ImageLabel", { BackgroundTransparency = 1, Image = source or "", ImageTransparency = tonumber(data.ImageTransparency) or 0.08, ScaleType = data.ScaleType or (data.ImageFit == true and Enum.ScaleType.Fit or Enum.ScaleType.Crop), Size = UDim2.fromScale(1, 1), ZIndex = 4 }, banner)
    local shade = new("Frame", { BackgroundColor3 = self.Window.Theme.Background, BackgroundTransparency = source and 0.28 or 0.04, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 5 }, banner)
    new("UIGradient", { Color = ColorSequence.new(self.Window.Theme.Background, self.Window.Theme.Element), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.04), NumberSequenceKeypoint.new(0.58, 0.22), NumberSequenceKeypoint.new(1, 0.78) }), Rotation = 0 }, shade)
    local bannerTextZ = math.max(tonumber(picture.ZIndex) or 0, tonumber(shade.ZIndex) or 0) + 2
    local fallback = textLabel(banner, data.FallbackText or "AXEL HUB", 11, source and self.Window.Theme.Muted or self.Window.Theme.Accent2, true)
    fallback.AnchorPoint = Vector2.new(0.5, 0.5); fallback.Position = UDim2.fromScale(0.78, 0.82); fallback.Size = UDim2.fromOffset(150, 18); fallback.TextXAlignment = Enum.TextXAlignment.Center; fallback.Visible = source == nil; fallback.ZIndex = bannerTextZ
    local fallbackIcon = icon(banner, "star", 32, self.Window.Theme.Accent2)
    fallbackIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    fallbackIcon.Position = UDim2.fromScale(0.78, 0.48)
    fallbackIcon.Visible = source == nil
    fallbackIcon.ZIndex = bannerTextZ
    if source then
        watchImage(picture, function()
            picture.Visible = true
            fallback.Visible = false
            fallbackIcon.Visible = false
        end, function()
            picture.Visible = false
            shade.BackgroundTransparency = 0.04
            fallback.Visible = true
            fallbackIcon.Visible = true
        end, 5, { imageThumbnailSource(source, 420, 420) })
    end
    local title = textLabel(banner, data.BannerTitle or data.Title or "Customize your experience", 14, self.Window.Theme.Text, true)
    title.Position = UDim2.fromOffset(14, 13); title.Size = UDim2.new(0.62, 0, 0, 22); title.ZIndex = bannerTextZ
    local content = textLabel(banner, data.Content or data.Description or "Simple. Powerful. Yours.", 10, self.Window.Theme.SubText, false)
    content.Position = UDim2.fromOffset(14, 38); content.Size = UDim2.new(0.58, 0, 0, 26); content.TextWrapped = true; content.ZIndex = bannerTextZ
    local action
    if data.Button or data.ActionText then
        action = new("TextButton", { AutoButtonColor = false, BackgroundColor3 = self.Window.Theme.Accent, BorderSizePixel = 0, Text = tostring(data.Button or data.ActionText), TextColor3 = self.Window.Theme.Background, TextSize = 10, FontFace = fontFace(nil, true), Size = UDim2.fromOffset(92, 27), Position = UDim2.fromOffset(14, math.max(62, height - 39)), ZIndex = 7 }, banner)
        action.ZIndex = bannerTextZ + 1
        corner(action, 8); pressAnimation(self.Window, action)
        connect(self.Window, action.MouseButton1Click, function() if type(data.Callback or data.callback) == "function" then task.spawn(function() pcall(data.Callback or data.callback) end) end end)
    end
    self.Hero, self.HeroWelcome, self.HeroBanner = hero, welcome, banner
    self.HeroWelcomeLabel, self.HeroWelcomeTitle, self.HeroWelcomeContent = welcomeLabel, welcomeTitle, welcomeContent
    self.HeroImage, self.HeroFallback, self.HeroHeight, self.HeroMobileHeight = picture, fallback, height, mobileHeight
    self.Window:_registerSearch(hero, tostring(data.Title or "") .. " " .. tostring(data.Content or ""))
    if self.Window.ActiveTab == self and self.Window.TabHeader then self.Window.TabHeader.Visible = not self.HideHeader end
    if self.Window._applyResponsive then self.Window:_applyResponsive() end
    return { Instance = hero, Banner = banner, Image = picture, Fallback = fallback, FallbackIcon = fallbackIcon, Title = title, Content = content, WelcomeTitle = welcomeTitle, Button = action }
end

-- Lightweight dashboard pills. Unlike AddSubTab, these keep one dashboard
-- body intact. A pill may filter dashboard sections and/or route to a sidebar
-- tab through TargetTab, which also keeps selection synchronized both ways.
function AxelUI.TabMethods:LayoutPills()
    if not self.PillBar or not self.PageBody then return end
    local mobile = self.Window.IsMobile
    local heroHeight = self.Hero and (mobile and (self.HeroMobileHeight or self.HeroHeight or 104) or (self.HeroHeight or 104)) or 0
    local heroTop = self.HideHeader and (mobile and 16 or 18) or 50
    -- Give the pills a little more room from the hero and from the card row
    -- below so the outlines don't look crowded or collide with nearby edges.
    local pillY = heroHeight > 0 and (heroTop + heroHeight + 4) or 50
    local bodyY = heroHeight > 0 and (heroTop + heroHeight + 48) or 92
    local bodyBottom = heroHeight > 0 and (heroTop + heroHeight + 58) or 102
    self.PillBar.Position = UDim2.fromOffset(mobile and 8 or 13, pillY)
    self.PillBar.Size = UDim2.new(1, mobile and -16 or -26, 0, 42)
    self.PageBody.Position = UDim2.fromOffset(mobile and 8 or 13, bodyY)
    self.PageBody.Size = UDim2.new(1, mobile and -16 or -26, 1, -bodyBottom)
end

function AxelUI.TabMethods:SelectPill(pill, silent)
    if not pill then return end
    for _, other in ipairs(self.Pills or {}) do
        local active = other == pill
        other.Active = active
        tween(other.Button, { BackgroundColor3 = active and self.Window.Theme.Accent or self.Window.Theme.Element }, 0.16)
        other.Button.BackgroundTransparency = active and 0.02 or 0
        setGoldGradientActive(other.GoldGradient, active)
        if other.Stroke then tween(other.Stroke, { Transparency = active and 0.02 or 0.38, Color = active and self.Window.Theme.Accent2 or self.Window.Theme.Border, Thickness = active and 1.15 or 0.75 }, 0.16) end
        setTextColor(other.Title, active and self.Window.Theme.Background or self.Window.Theme.Accent2)
    end
    self.ActivePill = pill
    local selectedFilter = string.lower(tostring(pill.Filter or pill.Name or "overview"))
    local showAll = selectedFilter == "" or selectedFilter == "overview" or selectedFilter == "all"
    for _, section in ipairs(self.Sections or {}) do
        local sectionFilter = section.PillFilter
        if section.Card and sectionFilter ~= nil then
            section.Card.Visible = showAll or string.lower(tostring(sectionFilter)) == selectedFilter
        elseif section.Card and not showAll then
            -- Unassigned sections are part of the overview, not unrelated
            -- category pages. This keeps each pill scoped to its own controls.
            section.Card.Visible = false
        elseif section.Card then
            section.Card.Visible = true
        end
    end
    if not silent and pill.TargetTab and self.Window.ActiveTab ~= pill.TargetTab then
        self.Window:SelectTab(pill.TargetTab)
    end
    if not silent and type(pill.Callback) == "function" then
        task.spawn(function() pcall(pill.Callback, pill) end)
    end
end

function AxelUI.TabMethods:AddPill(data)
    data = type(data) == "table" and data or { Name = data }
    if not self.PillBar then
        self.PillBar = new("ScrollingFrame", {
            Active = true,
            AutomaticCanvasSize = Enum.AutomaticSize.X,
            ScrollingEnabled = true,
            ScrollingDirection = Enum.ScrollingDirection.X,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(),
            ClipsDescendants = true,
            ScrollBarThickness = 0,
            Size = UDim2.new(1, -26, 0, 34),
            Position = UDim2.fromOffset(13, 50),
            ZIndex = 3,
        }, self.Page)
        new("UIPadding", {
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10),
            PaddingTop = UDim.new(0, 2),
            PaddingBottom = UDim.new(0, 2),
        }, self.PillBar)
        new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, self.PillBar)
        self.Pills = {}
    end
    local name = tostring(data.Name or data.Title or "Pill")
    local buttonWidth = math.max(70, math.min(132, #name * 7 + 28))
    local button = new("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window.Theme.Element,
        BorderSizePixel = 0,
        LayoutOrder = #self.Pills + 1,
        Text = name,
        TextColor3 = self.Window.Theme.Accent2,
        TextSize = 10,
        FontFace = fontFace(nil, true),
        TextXAlignment = Enum.TextXAlignment.Center,
        Size = UDim2.fromOffset(buttonWidth, 30),
        ZIndex = 4,
    }, self.PillBar)
    corner(button, 15)
    local pillStroke = stroke(button, self.Window.Theme.Border, 0.38, 0.75)
    local goldGradient = addGoldGradient(self.Window, button)
    local title = button
    local pill = {
        Tab = self,
        Button = button,
        Title = title,
        Stroke = pillStroke,
        GoldGradient = goldGradient,
        Name = name,
        Filter = data.Filter or data.Category or name,
        TargetTab = data.TargetTab or data.Tab,
        Callback = data.Callback or data.callback,
        Active = false,
    }
    table.insert(self.Pills, pill)
    connect(self.Window, button.MouseButton1Click, function() self:SelectPill(pill) end)
    connect(self.Window, button.MouseEnter, function()
        if not pill.Active then
            tween(pillStroke, { Transparency = 0.08, Color = self.Window.Theme.Accent2, Thickness = 1.15 }, 0.13)
            tween(button, { BackgroundColor3 = self.Window.Theme.Element:Lerp(self.Window.Theme.Accent, 0.14) }, 0.13)
        end
    end)
    connect(self.Window, button.MouseLeave, function()
        if not pill.Active then
            tween(pillStroke, { Transparency = 0.38, Color = self.Window.Theme.Border, Thickness = 0.75 }, 0.16)
            tween(button, { BackgroundColor3 = self.Window.Theme.Element }, 0.16)
        end
    end)
    addButtonGlass(self.Window, button, 0)
    pressAnimation(self.Window, button)
    if #self.Pills == 1 or data.Active or pill.TargetTab == self.Window.ActiveTab then self:SelectPill(pill) end
    self:LayoutPills()
    return pill
end

function AxelUI.TabMethods:SelectSubTab(subtab)
    if not subtab then return end
    for _, other in ipairs(self.SubTabs or {}) do
        local active = other == subtab
        other.Active = active
        if other.PageBody then other.PageBody.Visible = active end
        if other.Button then
            tween(other.Button, { BackgroundColor3 = active and self.Window.Theme.Accent or self.Window.Theme.Element }, 0.16)
            other.Button.BackgroundTransparency = active and 0.02 or 0
            setGoldGradientActive(other.GoldGradient, active)
            if other.Stroke then tween(other.Stroke, { Transparency = active and 0.02 or 0.38, Color = active and self.Window.Theme.Accent2 or self.Window.Theme.Border, Thickness = active and 1.15 or 0.75 }, 0.16) end
            setTextColor(other.Title, active and self.Window.Theme.Background or self.Window.Theme.Accent2)
        end
    end
    self.ActiveSubTab = subtab
end
function AxelUI.TabMethods:AddSubTab(data)
    data = type(data) == "table" and data or { Name = data }
    local subtab = {
        Tab = self,
        Window = self.Window,
        Name = tostring(data.Name or data.Title or "Subtab"),
        Description = tostring(data.Description or data.Subtitle or ""),
        Controls = {},
        Sections = {},
    }
    setmetatable(subtab, { __index = AxelUI.SectionMethods })

    if not self.SubTabBar then
        self.SubTabBar = new("ScrollingFrame", {
            Active = true,
            AutomaticCanvasSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(),
            Position = UDim2.fromOffset(13, 50),
            ClipsDescendants = true,
            ScrollBarThickness = 0,
            Size = UDim2.new(1, -26, 0, 42),
            Visible = true,
        }, self.Page)
        new("UIPadding", {
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10),
            PaddingTop = UDim.new(0, 2),
            PaddingBottom = UDim.new(0, 2),
        }, self.SubTabBar)
        new("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            Padding = UDim.new(0, 12),
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Center,
        }, self.SubTabBar)
    end

    local buttonWidth = math.max(70, math.min(132, #subtab.Name * 7 + 28))
    local button = new("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window.Theme.Element,
        BorderSizePixel = 0,
        LayoutOrder = #self.SubTabs + 1,
        Text = subtab.Name,
        TextColor3 = self.Window.Theme.Accent2,
        TextSize = 10,
        FontFace = fontFace(nil, true),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextWrapped = false,
        TextStrokeColor3 = self.Window.Theme.Background,
        TextStrokeTransparency = 0.72,
        Size = UDim2.fromOffset(buttonWidth, 30),
        ZIndex = 4,
    }, self.SubTabBar)
    corner(button, 15)
    local subtabStroke = stroke(button, self.Window.Theme.Border, 0.38, 0.75)
    local goldGradient = addGoldGradient(self.Window, button)
    local title = button
    subtab.Button, subtab.Title = button, title
    subtab.Stroke, subtab.GoldGradient = subtabStroke, goldGradient
local pageBody, columns, leftColumn, rightColumn, columnLayout, leftLayout, rightLayout
    if #self.SubTabs == 0 then
        pageBody, columns, leftColumn, rightColumn, columnLayout = self.PageBody, self.Columns, self.LeftBody, self.RightBody, self.ColumnLayout
        leftLayout, rightLayout = self.Layout, self.RightBody and self.RightBody:FindFirstChildOfClass("UIListLayout")
        local heroHeight = self.Hero and (self.Window.IsMobile and (self.HeroMobileHeight or self.HeroHeight or 104) or (self.HeroHeight or 104)) or 0
        local heroTop = self.HideHeader and (self.Window.IsMobile and 16 or 18) or 50
        local contentY = heroHeight > 0 and (heroTop + heroHeight + 54) or 98
        local contentBottom = heroHeight > 0 and (heroTop + heroHeight + 64) or 108
        self.PageBody.Position = UDim2.fromOffset(13, contentY)
        self.PageBody.Size = UDim2.new(1, -26, 1, -contentBottom)
    else
        pageBody, columns, leftColumn, rightColumn, columnLayout, leftLayout, rightLayout = makePageColumns(self.Window, self.Page, 98)
    end
    local card, body, layout
    if data.NoDefaultCard == true then
        -- Section-based pages already provide their own cards. Keep the
        -- column available for direct controls without adding an empty card.
        body, layout = leftColumn, leftLayout
    else
        card, body, layout = makeSubTabCard(self.Window, leftColumn, subtab.Name)
    end
    subtab.PageBody, subtab.Columns = pageBody, columns
    subtab.LeftBody, subtab.RightBody = leftColumn, rightColumn
    subtab.ColumnLayout, subtab.Layout = columnLayout, layout
    subtab.Body, subtab.Card = body, card
    subtab._nextSide = "Left"
    table.insert(self.SubTabs, subtab)

    connect(self.Window, button.MouseButton1Click, function() self:SelectSubTab(subtab) end)
    connect(self.Window, button.MouseEnter, function()
        if not subtab.Active then
            tween(subtabStroke, { Transparency = 0.08, Color = self.Window.Theme.Accent2, Thickness = 1.15 }, 0.13)
            tween(button, { BackgroundColor3 = self.Window.Theme.Element:Lerp(self.Window.Theme.Accent, 0.14) }, 0.13)
        end
    end)
    connect(self.Window, button.MouseLeave, function()
        if not subtab.Active then
            tween(subtabStroke, { Transparency = 0.38, Color = self.Window.Theme.Border, Thickness = 0.75 }, 0.16)
            tween(button, { BackgroundColor3 = self.Window.Theme.Element }, 0.16)
        end
    end)
    addButtonGlass(self.Window, button, 0)
    pressAnimation(self.Window, button)
    if #self.SubTabs == 1 then
        self:SelectSubTab(subtab)
    else
        self:SelectSubTab(self.ActiveSubTab or self.SubTabs[1])
    end
    if self.Window._applyResponsive then self.Window:_applyResponsive() end
    return subtab
end

function AxelUI.TabMethods:AddSection(data)
    data = type(data) == "table" and data or { Name = data }
    local section = {
        Tab = self,
        Window = self.Window,
        Name = tostring(data.Name or data.Title or "Section"),
        Description = tostring(data.Description or ""),
        PillFilter = data.Pill or data.Category or data.Filter,
        Controls = {},
        Collapsed = false,
    }
    setmetatable(section, { __index = AxelUI.SectionMethods })
    local requestedSide = string.lower(tostring(data.Side or data.Column or ""))
    local parent = self.LeftBody or self.Body
    if requestedSide == "right" then
        parent = self.RightBody or parent
    elseif requestedSide == "auto" then
        if self._nextSide == "Right" then
            parent = self.RightBody or parent
            self._nextSide = "Left"
        else
            self._nextSide = "Right"
        end
    end
    local card = new("Frame", {
        BackgroundColor3 = self.Window.Theme.Surface,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Size = UDim2.new(1, -5, 0, 0),
        LayoutOrder = data.LayoutOrder or 0,
    }, parent)
    corner(card, 9)
    stroke(card, self.Window.Theme.Border, 0.28, 1)
    if not self.Window.ReduceEffects then
        new("UIGradient", {
            Color = ColorSequence.new(self.Window.Theme.Surface, self.Window.Theme.Background),
            Transparency = NumberSequence.new(0),
            Rotation = 90,
        }, card)
    end
    local headerHeight = data.Description ~= "" and 48 or 35
    local header = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, headerHeight) }, card)
    pad(header, 12, 12, 8, 4)
    local title = textLabel(header, section.Name, 14, self.Window.Theme.Text, true)
    title.Size = UDim2.new(1, -52, 0, 18)
    local collapseButton = new("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Window.Theme.Element,
        BorderSizePixel = 0,
        Text = "",
        Size = UDim2.fromOffset(24, 22),
        Position = UDim2.new(1, -34, 0, 5),
    }, header)
    corner(collapseButton, 8)
    local collapseGlyph = icon(collapseButton, "plus", 14, self.Window.Theme.Accent2)
    collapseGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
    collapseGlyph.Position = UDim2.fromScale(0.5, 0.5)
    local collapseVertical = nil
    for _, part in ipairs(collapseGlyph:GetChildren()) do
        if part.Name == "AxelIconLine" and math.abs(part.Rotation) > 45 then
            collapseVertical = part
            break
        end
    end
    if collapseVertical then collapseVertical.Visible = false end
    if section.Description ~= "" then
        local description = textLabel(header, section.Description, 10, self.Window.Theme.SubText, false)
        description.Size = UDim2.new(1, -52, 0, 17)
        description.Position = UDim2.fromOffset(0, 20)
        description.TextWrapped = true
    end
    local body = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, headerHeight), Size = UDim2.new(1, 0, 0, 0) }, card)
    pad(body, 10, 10, 2, 6)
    local layout = new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, body)
    local syncBodyHeight
    syncBodyHeight = bindVerticalLayout(self.Window, body, layout, 12, function(height)
        if not section.Collapsed then
            preserveHeight(card, headerHeight + height)
        end
    end)
    section.Card, section.Body, section.Layout, section.Toggle = card, body, layout, collapseButton
    section.CollapseGlyph, section.CollapseVertical = collapseGlyph, collapseVertical
    function section:SetCollapsed(value)
        self.Collapsed = value == true
        if self.CollapseVertical then self.CollapseVertical.Visible = self.Collapsed end
        if self.Window.ReduceEffects then
            collapseButton.BackgroundColor3 = self.Collapsed and self.Window.Theme.Surface2 or self.Window.Theme.Element
        else
            tween(collapseButton, { BackgroundColor3 = self.Collapsed and self.Window.Theme.Surface2 or self.Window.Theme.Element }, 0.16)
        end
        if self.Collapsed then
            if self.Window.ReduceEffects then
                body.BackgroundTransparency = 1
            else
                tween(body, { BackgroundTransparency = 1 }, 0.12)
            end
            preserveHeight(card, headerHeight)
            if self.Window.ReduceEffects then
                body.Visible = false
            else
                task.delay(0.12, function() if body.Parent and self.Collapsed then body.Visible = false end end)
            end
        else
            body.Visible = true
            if self.Window.ReduceEffects then
                body.BackgroundTransparency = 1
            else
                tween(body, { BackgroundTransparency = 1 }, 0.14)
            end
            if syncBodyHeight then syncBodyHeight() end
        end
    end
    connect(self.Window, collapseButton.MouseButton1Click, function() section:SetCollapsed(not section.Collapsed) end)
    pressAnimation(self.Window, collapseButton)
    if not self.Window.ReduceEffects then
        connect(self.Window, collapseButton.MouseEnter, function()
            tween(collapseButton, { BackgroundColor3 = self.Window.Theme.Surface2 }, 0.12)
        end)
        connect(self.Window, collapseButton.MouseLeave, function()
            tween(collapseButton, { BackgroundColor3 = self.Window.Theme.Element }, 0.16)
        end)
    end
    self.Window:_registerSearch(card, section.Name .. " " .. section.Description, title, { Container = true })
    table.insert(self.Sections, section)
    if self.ActivePill then self:SelectPill(self.ActivePill, true) end
    return section
end

function AxelUI.SectionMethods:AddDescription(text)
    local label = textLabel(self.Body, text, 11, self.Window.Theme.SubText, false)
    local description = tostring(text or "")
    local lines = select(2, description:gsub("\n", "\n")) + 1
    label.Size = UDim2.new(1, 0, 0, math.max(26, lines * 16))
    label.TextWrapped = true
    self.Window:_registerSearch(label, text)
    return label
end

-- Common aliases used by other Roblox UI libraries.
function AxelUI.SectionMethods:AddText(data, content)
    if content ~= nil then
        return self:AddParagraph({ Title = data, Content = content })
    end
    if type(data) == "table" and (data.Title or data.Content or data.Body) then
        data.Content = data.Content or data.Body
        return self:AddParagraph(data)
    end
    return self:AddLabel(data)
end

function AxelUI.SectionMethods:AddTextLabel(data)
    return self:AddLabel(data)
end

function AxelUI.SectionMethods:AddLabel(data)
    data = type(data) == "table" and data or { Name = data }
    local label = textLabel(self.Body, data.Name or data.Text or "", data.TextSize or 12, data.Color or self.Window.Theme.SubText, data.Bold)
    label.Size = UDim2.new(1, 0, 0, data.Height or 20)
    if data.Description then label.Text = tostring(data.Name or "") .. "  <font color=\"#9699A5\">" .. tostring(data.Description) .. "</font>" end
    self.Window:_registerSearch(label, (data.Name or "") .. " " .. (data.Description or ""))
    return label
end

function AxelUI.SectionMethods:AddParagraph(data)
    data = data or {}
    local contentText = tostring(data.Content or "")
    local compact = data.Compact == true
    local tooltipText = tostring(data.Tooltip or "")
    local lineCount = select(2, contentText:gsub("\n", "\n")) + 1
    local contentHeight = tonumber(data.Height) or (compact
        and math.max(18, lineCount * 14, (#contentText > 90 and 42 or 0))
        or math.max(36, lineCount * 16, (#contentText > 90 and 52 or 0)))
    local wrapperHeight = compact and (31 + contentHeight) or (19 + contentHeight)
    local wrapperSize = compact
        and UDim2.new(math.clamp(tonumber(data.WidthScale) or 0.72, 0.4, 1), 0, 0, wrapperHeight)
        or UDim2.new(1, 0, 0, wrapperHeight)
    local wrapper = new("Frame", {
        BackgroundColor3 = compact and self.Window.Theme.Surface2 or self.Window.Theme.Background,
        BackgroundTransparency = compact and 0 or 1,
        BorderSizePixel = 0,
        Size = wrapperSize,
    }, self.Body)
    if compact then
        corner(wrapper, 8)
        stroke(wrapper, self.Window.Theme.Border, 0.24, 1)
    end
    local title = textLabel(wrapper, data.Title or data.Name or "Info", 12, self.Window.Theme.Accent2, true)
    title.Position = compact and UDim2.fromOffset(10, 6) or UDim2.fromOffset(0, 0)
    title.Size = UDim2.new(1, compact and -20 or 0, 0, 18)
    local content = textLabel(wrapper, data.Content or "", 11, self.Window.Theme.SubText, false)
    content.Position = compact and UDim2.fromOffset(10, 24) or UDim2.fromOffset(0, 19)
    content.Size = UDim2.new(1, compact and -20 or 0, 0, contentHeight)
    content.TextWrapped = true
    content.TextYAlignment = Enum.TextYAlignment.Top
    self.Window:_registerSearch(wrapper, tostring(data.Title or "") .. " " .. tostring(data.Content or ""))
    local tooltip
    if tooltipText ~= "" and self.Window.Gui then
        local tooltipHeight = math.clamp(math.max(38, math.ceil(#tooltipText / 42) * 15 + 14), 38, 82)
        tooltip = new("Frame", {
            BackgroundColor3 = self.Window.Theme.Element,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(252, tooltipHeight),
            Visible = false,
            ZIndex = 250,
        }, self.Window.Gui)
        corner(tooltip, 7)
        local tooltipStroke = stroke(tooltip, self.Window.Theme.Accent, 1, 1)
        local tooltipLabel = textLabel(tooltip, tooltipText, 10, self.Window.Theme.Text, false)
        tooltipLabel.Position = UDim2.fromOffset(9, 7)
        tooltipLabel.Size = UDim2.new(1, -18, 1, -14)
        tooltipLabel.TextWrapped = true
        tooltipLabel.TextYAlignment = Enum.TextYAlignment.Center
        tooltipLabel.TextTransparency = 1
        tooltipLabel.ZIndex = 251
        local hovering, hoverRevision = false, 0
        local function hideTooltip()
            hovering = false
            hoverRevision += 1
            if not tooltip or not tooltip.Visible then return end
            tween(tooltip, { BackgroundTransparency = 1 }, 0.1, Enum.EasingStyle.Quad)
            tween(tooltipStroke, { Transparency = 1 }, 0.1, Enum.EasingStyle.Quad)
            tween(tooltipLabel, { TextTransparency = 1 }, 0.1, Enum.EasingStyle.Quad)
            task.delay(0.12, function()
                if not hovering and tooltip and tooltip.Parent then tooltip.Visible = false end
            end)
        end
        connect(self.Window, wrapper.MouseEnter, function()
            hovering = true
            hoverRevision += 1
            local revision = hoverRevision
            task.delay(0.28, function()
                if not hovering or revision ~= hoverRevision or self.Window._destroyed or not self.Window._open
                    or not wrapper.Parent or not tooltip or not tooltip.Parent then return end
                placePopup(tooltip, wrapper, 252, tooltipHeight, false)
                tooltip.Visible = true
                tooltip.BackgroundTransparency = 1
                tooltipStroke.Transparency = 1
                tooltipLabel.TextTransparency = 1
                tween(tooltip, { BackgroundTransparency = 0.04 }, 0.12, Enum.EasingStyle.Quad)
                tween(tooltipStroke, { Transparency = 0.18 }, 0.12, Enum.EasingStyle.Quad)
                tween(tooltipLabel, { TextTransparency = 0 }, 0.12, Enum.EasingStyle.Quad)
            end)
        end)
        connect(self.Window, wrapper.MouseLeave, hideTooltip)
        connect(self.Window, self.Window.Window:GetPropertyChangedSignal("Visible"), function()
            if not self.Window.Window.Visible then hideTooltip() end
        end)
        connect(self.Window, wrapper.Destroying, function()
            if tooltip and tooltip.Parent then tooltip:Destroy() end
        end)
    end
    local handle = { Instance = wrapper, Title = title, Content = content, Tooltip = tooltip }
    function handle:Set(value) self.Content.Text = tostring(value or "") end
    function handle:Get() return self.Content.Text end
    function handle:SetVisibility(value) self.Instance.Visible = value == true end
    table.insert(self.Controls, handle)
    return handle
end

function AxelUI.SectionMethods:AddBanner(data)
    data = data or {}
    local height = tonumber(data.Height) or 112
    local holder = new("Frame", {
        BackgroundColor3 = self.Window.Theme.Element,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, height),
        ClipsDescendants = true,
    }, self.Body)
    corner(holder, 8); stroke(holder, self.Window.Theme.Border, 0.18, 1)
    local source = imageSource(data.Image or data.Source or data.Asset, self.Window.AssetFolder)
    local picture = new("ImageLabel", {
        BackgroundTransparency = 1,
        Image = source or "",
        ImageColor3 = Color3.new(1, 1, 1),
        ImageTransparency = tonumber(data.ImageTransparency) or 0.18,
        ScaleType = data.ScaleType or (data.ImageFit == true and Enum.ScaleType.Fit or Enum.ScaleType.Crop),
        Size = UDim2.fromScale(1, 1),
        ZIndex = 1,
    }, holder)
    local shade = new("Frame", {
        BackgroundColor3 = self.Window.Theme.Background,
        BackgroundTransparency = 0.22,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 2,
    }, holder)
    new("UIGradient", {
        Color = ColorSequence.new(self.Window.Theme.Background, self.Window.Theme.Element),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.05),
            NumberSequenceKeypoint.new(1, 0.78),
        }),
        Rotation = 0,
    }, shade)
    local fallback = textLabel(holder, data.FallbackText or "Image unavailable", 10, self.Window.Theme.SubText, true)
    fallback.AnchorPoint = Vector2.new(0.5, 0.5)
    fallback.Position = UDim2.fromScale(0.5, 0.72)
    fallback.Size = UDim2.new(1, -28, 0, 18)
    fallback.TextXAlignment = Enum.TextXAlignment.Center
    fallback.ZIndex = (tonumber(shade.ZIndex) or tonumber(picture.ZIndex) or 0) + 2
    fallback.Visible = source == nil
    if source then
        watchImage(picture, function()
            picture.Visible = true
            fallback.Visible = false
        end, function()
            picture.Visible = false
            shade.BackgroundTransparency = 0.08
            fallback.Visible = true
        end, 5, { imageThumbnailSource(source, 420, 420) })
    end
    local title = textLabel(holder, data.Title or data.Name or "Welcome", 14, self.Window.Theme.Text, true)
    local bannerTextZ = math.max(tonumber(picture.ZIndex) or 0, tonumber(shade.ZIndex) or 0) + 2
    title.Position = UDim2.fromOffset(14, 14); title.Size = UDim2.new(1, -28, 0, 22); title.ZIndex = bannerTextZ
    local content = textLabel(holder, data.Content or data.Description or "", 10, self.Window.Theme.SubText, false)
    content.Position = UDim2.fromOffset(14, 39); content.Size = UDim2.new(1, -170, 0, 34); content.TextWrapped = true; content.ZIndex = bannerTextZ
    local action
    if data.Button or data.ActionText then
        action = new("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = self.Window.Theme.Accent,
            BorderSizePixel = 0,
            Text = tostring(data.Button or data.ActionText),
            TextColor3 = self.Window.Theme.Background,
            TextSize = 10,
            FontFace = fontFace(nil, true),
            Size = UDim2.fromOffset(112, 28),
            Position = UDim2.new(1, -126, 0.5, -14),
            ZIndex = 4,
        }, holder)
        action.ZIndex = bannerTextZ + 1
        corner(action, 7); pressAnimation(self.Window, action)
        connect(self.Window, action.MouseButton1Click, function()
            if type(data.Callback or data.callback) == "function" then task.spawn(function() pcall(data.Callback or data.callback) end) end
        end)
    end
    self.Window:_registerSearch(holder, tostring(data.Title or "") .. " " .. tostring(data.Content or ""))
    return { Instance = holder, Image = picture, Fallback = fallback, Title = title, Content = content, Button = action }
end

AxelUI.SectionMethods.AddHero = AxelUI.SectionMethods.AddBanner

function AxelUI.SectionMethods:AddImage(data)
    data = type(data) == "table" and data or { Image = data }
    local height = tonumber(data.Height) or 120
    local holder = new("Frame", {
        BackgroundColor3 = self.Window.Theme.Background,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, height),
    }, self.Body)
    corner(holder, 6)
    stroke(holder, self.Window.Theme.Border, 0.22, 1)
    local source = imageSource(data.Image or data.Source or data.Asset, self.Window.AssetFolder)
    local picture = new("ImageLabel", {
        BackgroundTransparency = 1,
        Image = source or "",
        ImageColor3 = data.Tint or Color3.new(1, 1, 1),
        ScaleType = data.ScaleType or (data.ImageFit == false and Enum.ScaleType.Crop or Enum.ScaleType.Fit),
        Size = UDim2.new(1, -12, 1, data.Caption and -30 or -12),
        Position = UDim2.fromOffset(6, 6),
        ZIndex = 1,
    }, holder)
    corner(picture, 5)
    local fallback = textLabel(holder, data.FallbackText or "Image unavailable", 10, self.Window.Theme.SubText, true)
    fallback.AnchorPoint = Vector2.new(0.5, 0.5)
    fallback.Position = UDim2.fromScale(0.5, data.Caption and 0.44 or 0.5)
    fallback.Size = UDim2.new(1, -24, 0, 18)
    fallback.TextXAlignment = Enum.TextXAlignment.Center
    fallback.ZIndex = 2
    fallback.Visible = source == nil
    if source then
        watchImage(picture, function()
            picture.Visible = true
            fallback.Visible = false
        end, function()
            picture.Visible = false
            fallback.Visible = true
        end, 5, { imageThumbnailSource(source, 150, 150) })
    end
    if data.Caption then
        local caption = textLabel(holder, data.Caption, 10, self.Window.Theme.SubText, false)
        caption.Position = UDim2.new(0, 8, 1, -24)
        caption.Size = UDim2.new(1, -16, 0, 18)
        caption.TextXAlignment = Enum.TextXAlignment.Center
    end
    self.Window:_registerSearch(holder, tostring(data.Caption or data.Name or "Image"))
    return { Instance = holder, Image = picture, Fallback = fallback }
end

function AxelUI.SectionMethods:AddButton(data)
    data = data or {}
    data.Icon = data.Icon or "check"
    data.RightReserved = data.RightReserved or 48
    local row, inner = self.Window:_makeRow(self.Body, data, data.Height or 38)
    local buttonIcon = icon(inner, data.Icon or "check", 16, data.IconColor or self.Window.Theme.Accent2)
    buttonIcon.Position = UDim2.new(1, -30, 0.5, -8)
    connect(self.Window, row.MouseButton1Click, function()
        if type(data.Callback or data.callback) == "function" then
            task.spawn(function() pcall(data.Callback or data.callback) end)
        end
    end)
    table.insert(self.Controls, row)
    return row
end

-- Compact horizontal actions used by dashboard footers and quick-action cards.
-- It keeps the reference layout dense while preserving normal Button callbacks.
function AxelUI.SectionMethods:AddActionBar(data)
    data = data or {}
    local actions = data.Actions or data.Items or {}
    local bar = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, tonumber(data.Height) or 32),
        LayoutOrder = data.LayoutOrder or 0,
    }, self.Body)
    local layout = new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        Padding = UDim.new(0, tonumber(data.Gap) or 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, bar)
    local handles = {}
    local count = math.max(1, #actions)
    for index, item in ipairs(actions) do
        item = type(item) == "table" and item or { Name = item }
        local button = new("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = item.Primary and self.Window.Theme.Accent or self.Window.Theme.Element,
            BorderSizePixel = 0,
            LayoutOrder = index,
            Text = tostring(item.Name or item.Title or "Action"),
            TextColor3 = item.Primary and self.Window.Theme.Background or self.Window.Theme.Text,
            TextSize = tonumber(item.TextSize) or 10,
            FontFace = fontFace(nil, item.Bold ~= false),
            Size = UDim2.new(1 / count, -((tonumber(data.Gap) or 6) * (count - 1) / count), 0, tonumber(data.Height) or 32),
        }, bar)
        corner(button, 8)
        local actionStroke = stroke(button, item.Primary and self.Window.Theme.Accent2 or self.Window.Theme.Border, 0.24, 1)
        pressAnimation(self.Window, button)
        addButtonGlass(self.Window, button, 0)
        connect(self.Window, button.MouseEnter, function()
            local hoverColor = item.Primary and self.Window.Theme.Accent2 or self.Window.Theme.Element:Lerp(self.Window.Theme.Accent, 0.18)
            tween(button, { BackgroundColor3 = hoverColor }, 0.12)
            tween(actionStroke, { Transparency = 0.02, Color = self.Window.Theme.Accent2 }, 0.12)
        end)
        connect(self.Window, button.MouseLeave, function()
            tween(button, { BackgroundColor3 = item.Primary and self.Window.Theme.Accent or self.Window.Theme.Element }, 0.16)
            tween(actionStroke, { Transparency = 0.24, Color = item.Primary and self.Window.Theme.Accent2 or self.Window.Theme.Border }, 0.16)
        end)
        connect(self.Window, button.MouseButton1Click, function()
            if type(item.Callback or item.callback) == "function" then task.spawn(function() pcall(item.Callback or item.callback) end) end
        end)
        handles[index] = { Instance = button, Button = button, Name = button.Text }
    end
    table.insert(self.Controls, handles)
    return { Instance = bar, Layout = layout, Buttons = handles }
end

function AxelUI.SectionMethods:AddToggle(data)
    data = data or {}
    data.Icon = data.Icon or "power"
    data.RightReserved = data.RightReserved or 68
    local row, inner = self.Window:_makeRow(self.Body, data, data.Height or 40)
    local track = new("Frame", {
        BackgroundColor3 = self.Window.Theme.Element,
        Size = UDim2.fromOffset(42, 22),
        Position = UDim2.new(1, -52, 0.5, -11),
        ZIndex = 8,
    }, inner)
    corner(track, 11)
    local trackStroke = stroke(track, self.Window.Theme.Border, 0.28, 1)
    local knob = new("Frame", { BackgroundColor3 = self.Window.Theme.Text, Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(3, 3), ZIndex = 9 }, track)
    corner(knob, 8)
    local handle = { Value = data.Default == true, Row = row, Window = self.Window }
    function handle:Set(value, silent)
        self.Value = value == true
        local x = self.Value and 23 or 3
        local knobPosition = UDim2.fromOffset(x, 3)
        local trackColor = self.Value and self.Window.Theme.Accent or self.Window.Theme.Element
        local strokeColor = self.Value and self.Window.Theme.Accent2 or self.Window.Theme.Border
        local strokeTransparency = self.Value and 0.04 or 0.28
        local strokeThickness = self.Value and 1.5 or 1
        if self.Window.AnimateControls and not self.Window.ReduceEffects then
            -- Reduced-effects mode updates immediately, as in the known-good
            -- v7.2 toggle path. Full-effects mode keeps one short knob tween.
            tween(knob, { Position = knobPosition }, 0.13, Enum.EasingStyle.Quint)
            track.BackgroundColor3 = trackColor
            trackStroke.Color = strokeColor
            trackStroke.Transparency = strokeTransparency
            trackStroke.Thickness = strokeThickness
        else
            knob.Position = knobPosition
            knob.BackgroundColor3 = self.Window.Theme.Text
            track.BackgroundColor3 = trackColor
            trackStroke.Color = strokeColor
            trackStroke.Transparency = strokeTransparency
            trackStroke.Thickness = strokeThickness
        end
        if not silent and type(data.Callback or data.callback) == "function" then
            local callback = data.Callback or data.callback
            local callbackValue = self.Value
            task.spawn(function()
                -- Keep the v7.2 dispatch contract: yield once after input,
                -- then invoke the callback in a scheduled task.
                task.wait()
                if self.Window and self.Window._destroyed then return end
                pcall(callback, callbackValue)
            end)
        end
    end
    function handle:Get() return self.Value end
    local function activateToggle()
        if self.Window and self.Window._destroyed then return end
        handle:Set(not handle.Value)
    end
    local toggleConnection
    local activatedOk, activatedSignal = pcall(function() return row.Activated end)
    if activatedOk and activatedSignal then
        toggleConnection = connect(self.Window, activatedSignal, activateToggle)
    end
    if not toggleConnection then
        connect(self.Window, row.MouseButton1Click, activateToggle)
    end
    handle:Set(handle.Value, true)
    self.Window:_registerFlag(data.Flag, handle)
    table.insert(self.Controls, handle)
    return handle
end

function AxelUI.SectionMethods:AddSlider(data)
    data = data or {}
    data.Icon = data.Icon or "chart"
    data.RightReserved = data.RightReserved or 160
    local row, inner = self.Window:_makeRow(self.Body, data, data.Height or 40)
    local minimum = tonumber(data.Min or data.Minimum) or 0
    local maximum = math.max(minimum, tonumber(data.Max or data.Maximum) or 100)
    local value = math.clamp(tonumber(data.Default) or minimum, minimum, maximum)
    local precision = tonumber(data.Decimals)
    if precision == nil then precision = minimum % 1 == 0 and maximum % 1 == 0 and 0 or 1 end
    precision = math.clamp(math.floor(precision), 0, 4)
    local valuePower = 10 ^ precision
    local step = tonumber(data.Step)
    if not step or step <= 0 then step = nil end
    local function normalizeValue(number)
        number = math.clamp(tonumber(number) or minimum, minimum, maximum)
        if step then number = minimum + math.floor((number - minimum) / step + 0.5) * step end
        number = math.clamp(number, minimum, maximum)
        return math.floor(number * valuePower + 0.5) / valuePower
    end
    local function formatValue(number)
        local formatted = string.format("%." .. tostring(precision) .. "f", number)
        if precision > 0 then formatted = formatted:gsub("(%..-)0+$", "%1"):gsub("%.$", "") end
        return formatted .. tostring(data.Suffix or "")
    end
    local valueText = textLabel(inner, "", 11, self.Window.Theme.Accent2, true)
    valueText.Size = UDim2.fromOffset(44, 22)
    valueText.Position = UDim2.new(1, -158, 0.5, -11)
    valueText.TextXAlignment = Enum.TextXAlignment.Center
    valueText.BackgroundColor3 = self.Window.Theme.Element
    valueText.BackgroundTransparency = 0.08
    valueText.TextTruncate = Enum.TextTruncate.AtEnd
    corner(valueText, 6)
    stroke(valueText, self.Window.Theme.Border, 0.25, 1)
    valueText.Visible = data.ShowValue ~= false
    -- Global ZIndex requires this to stay above the row's nested frames.
    valueText.ZIndex = math.max(valueText.ZIndex, inner.ZIndex + 12)
    local bar = new("Frame", { BackgroundColor3 = self.Window.Theme.Element, Size = UDim2.fromOffset(92, 5), Position = UDim2.new(1, -106, 0.5, -2), ZIndex = 8 }, inner)
    corner(bar, 4)
    local fill = new("Frame", { BackgroundColor3 = self.Window.Theme.Accent, Size = UDim2.new(0, 0, 1, 0), ZIndex = 9 }, bar)
    corner(fill, 4)
    local thumb = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = self.Window.Theme.Accent2,
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        ZIndex = 10,
    }, bar)
    corner(thumb, 7); stroke(thumb, self.Window.Theme.Background, 0.12, 1)
    local dragArea = new("TextButton", {
        Active = true,
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        Position = UDim2.new(1, -112, 0.5, -10),
        Size = UDim2.fromOffset(108, 20),
        ZIndex = 30,
    }, inner)
    local handle = { Value = value, Row = row }
    local function setFromX(x, silent)
        local ratio = math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
        local nextValue = minimum + (maximum - minimum) * ratio
        nextValue = normalizeValue(nextValue)
        handle.Value = nextValue
        valueText.Text = formatValue(nextValue)
        local snappedRatio = math.clamp((nextValue - minimum) / math.max(0.0001, maximum - minimum), 0, 1)
        fill.Size = UDim2.new(snappedRatio, 0, 1, 0)
        thumb.Position = UDim2.new(snappedRatio, 0, 0.5, 0)
        if not silent and type(data.Callback or data.callback) == "function" then
            task.spawn(function() pcall(data.Callback or data.callback, nextValue) end)
        end
    end
    function handle:Set(nextValue, silent)
        nextValue = normalizeValue(nextValue)
        local ratio = (nextValue - minimum) / math.max(0.0001, maximum - minimum)
        handle.Value = nextValue
        valueText.Text = formatValue(nextValue)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        thumb.Position = UDim2.new(ratio, 0, 0.5, 0)
        if not silent and type(data.Callback or data.callback) == "function" then
            task.spawn(function() pcall(data.Callback or data.callback, nextValue) end)
        end
    end
    function handle:Get() return handle.Value end
    local sliding = false
    connect(self.Window, dragArea.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            setFromX(input.Position.X)
        end
    end)
    connect(self.Window, UserInputService.InputChanged, function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then setFromX(input.Position.X) end
    end)
    connect(self.Window, UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then sliding = false end
    end)
    handle:Set(value, true)
    self.Window:_registerFlag(data.Flag, handle)
    table.insert(self.Controls, handle)
    return handle
end

function AxelUI.SectionMethods:AddDropdown(data)
    data = data or {}
    data.Icon = data.Icon or "chevron"
    local mobile = self.Window.IsMobile == true
    local selectorWidth = mobile and 150 or 134
    local selectorHeight = mobile and 32 or 27
    data.RightReserved = data.RightReserved or (selectorWidth + 20)
    local row, inner = self.Window:_makeRow(self.Body, data, data.Height or 40)
    local selected = data.Default
    local options = data.Options or data.Items or {}
    if type(options) ~= "table" then options = { options } end
    local selector = new("TextButton", {
        Active = true,
        AutoButtonColor = false,
        BackgroundColor3 = self.Window.Theme.Element,
        BorderSizePixel = 0,
        Text = tostring(selected or "Select"),
        TextColor3 = self.Window.Theme.Text,
        TextSize = 11,
        FontFace = fontFace(nil, false),
        Size = UDim2.fromOffset(selectorWidth, selectorHeight),
        Position = UDim2.new(1, -(selectorWidth + 10), 0.5, -selectorHeight / 2),
        ZIndex = 8,
    }, inner)
    corner(selector, 5)
    local selectorStroke = stroke(selector, self.Window.Theme.Border, 0.38, 1)
    pad(selector, 9, 26, 0, 0)
    selector.TextXAlignment = Enum.TextXAlignment.Left
    selector.TextTruncate = Enum.TextTruncate.AtEnd
    local arrow = icon(selector, "chevron", 13, self.Window.Theme.SubText)
    arrow.AnchorPoint = Vector2.new(0.5, 0.5)
    arrow.Position = UDim2.new(1, -14, 0.5, 0)
    arrow.ZIndex = selector.ZIndex + 1
    local popup
    local handle = { Value = selected, Row = row }
    local function setSelectorOpen(isOpen)
        tween(selector, {
            BackgroundColor3 = isOpen and self.Window.Theme.Background or self.Window.Theme.Element,
            TextColor3 = isOpen and self.Window.Theme.Accent2 or self.Window.Theme.Text,
        }, 0.12)
        tween(selectorStroke, {
            Color = isOpen and self.Window.Theme.Accent or self.Window.Theme.Border,
            Transparency = isOpen and 0.04 or 0.38,
            Thickness = isOpen and 1.25 or 1,
        }, 0.12)
        setIconTint(arrow, isOpen and self.Window.Theme.Accent2 or self.Window.Theme.SubText, 0.12)
    end
    local function close()
        if popup then
            local closingPopup = popup
            popup = nil
            animatePopupClose(closingPopup, selector)
            tween(arrow, { Rotation = 0 }, 0.14)
            setSelectorOpen(false)
        end
        if self.Window._dropdownClose == close then self.Window._dropdownClose = nil end
    end
    local function open()
        if popup then close(); return end
        if self.Window._dropdownClose and self.Window._dropdownClose ~= close then pcall(self.Window._dropdownClose) end
        local popupWidth, popupHeight, optionHeight = dropdownPopupMetrics(selector, #options, self.Window.IsMobile == true, false)
        popup = new("ScrollingFrame", {
            Active = true,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = self.Window.Theme.Background,
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(),
            ScrollBarImageColor3 = self.Window.Theme.Accent,
            ScrollBarThickness = self.Window.IsMobile and 3 or 2,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            Size = UDim2.fromOffset(popupWidth, popupHeight),
            ZIndex = 50,
        }, self.Window.Gui)
        corner(popup, 7); stroke(popup, self.Window.Theme.Accent, 0.08, 1.15); pad(popup, 3, 3, 3, 3)
        placePopup(popup, selector, popupWidth, popupHeight, true, not self.Window.IsMobile)
        animatePopupOpen(popup, selector)
        setSelectorOpen(true)
        tween(arrow, { Rotation = 180 }, 0.16, Enum.EasingStyle.Quint)
        new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, popup)
        local function styleOption(button, option)
            local isSelected = tostring(option) == tostring(handle.Value)
            button.BackgroundColor3 = isSelected and self.Window.Theme.Accent or self.Window.Theme.Surface2
            button.TextColor3 = isSelected and self.Window.Theme.Background or self.Window.Theme.Text
        end
        if #options == 0 then
            new("TextLabel", {
                BackgroundTransparency = 1,
                FontFace = fontFace(nil, false),
                Size = UDim2.new(1, 0, 0, optionHeight),
                Text = "No options",
                TextColor3 = self.Window.Theme.SubText,
                TextSize = self.Window.IsMobile and 11 or 10,
                ZIndex = 51,
            }, popup)
        end
        for _, option in ipairs(options) do
            local optionButton = new("TextButton", {
                Active = true,
                AutoButtonColor = false,
                BackgroundColor3 = tostring(option) == tostring(handle.Value) and self.Window.Theme.Accent or self.Window.Theme.Surface2,
                BorderSizePixel = 0,
                Text = tostring(option),
                TextColor3 = tostring(option) == tostring(handle.Value) and self.Window.Theme.Background or self.Window.Theme.Text,
                TextSize = self.Window.IsMobile and 11 or 10,
                FontFace = fontFace(nil, false),
                Size = UDim2.new(1, 0, 0, optionHeight),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 51,
            }, popup)
            corner(optionButton, 4); pad(optionButton, 7, 7, 0, 0)
            pressAnimation(self.Window, optionButton)
            connect(self.Window, optionButton.MouseEnter, function()
                tween(optionButton, { BackgroundColor3 = self.Window.Theme.Element:Lerp(self.Window.Theme.Accent, 0.2), TextColor3 = self.Window.Theme.Accent2 }, 0.1)
            end)
            connect(self.Window, optionButton.MouseLeave, function() styleOption(optionButton, option) end)
            connectActivated(self.Window, optionButton, function()
                handle.Value = option; selector.Text = tostring(option); close()
                if type(data.Callback or data.callback) == "function" then task.spawn(function() pcall(data.Callback or data.callback, option) end) end
            end)
        end
        self.Window._dropdownClose = close
    end
    function handle:Set(value, silent)
        self.Value = value; selector.Text = tostring(value or "Select")
        if not silent and type(data.Callback or data.callback) == "function" then task.spawn(function() pcall(data.Callback or data.callback, value) end) end
    end
    function handle:Get() return self.Value end
    function handle:SetOptions(nextOptions)
        if popup then close() end
        if type(nextOptions) ~= "table" then nextOptions = { nextOptions } end
        options = nextOptions
        local stillAvailable = false
        for _, option in ipairs(options) do
            if option == handle.Value then
                stillAvailable = true
                break
            end
        end
        if not stillAvailable then
            handle.Value = options[1]
            selector.Text = tostring(handle.Value or "Select")
        end
    end
    handle.SetItems = handle.SetOptions
    connectActivated(self.Window, selector, open)
    pressAnimation(self.Window, selector)
    self.Window:_registerFlag(data.Flag, handle)
    table.insert(self.Controls, handle)
    return handle
end

function AxelUI.SectionMethods:AddMultiDropdown(data)
    data = data or {}
    data.Icon = data.Icon or "chevron"
    local mobile = self.Window.IsMobile == true
    local selectorWidth = mobile and 158 or 142
    local selectorHeight = mobile and 32 or 27
    data.RightReserved = data.RightReserved or (selectorWidth + 20)
    local row, inner = self.Window:_makeRow(self.Body, data, data.Height or 40)
    local options = data.Options or data.Items or {}
    if type(options) ~= "table" then options = { options } end
    local selected = {}
    local selectedSet = {}
    local function setValues(values)
        selected = {}
        selectedSet = {}
        if type(values) == "table" then
            for _, value in ipairs(values) do
                local text = tostring(value)
                if not selectedSet[text] then
                    selectedSet[text] = true
                    table.insert(selected, value)
                end
            end
        elseif values ~= nil and tostring(values) ~= "" then
            selectedSet[tostring(values)] = true
            table.insert(selected, values)
        end
    end
    setValues(data.Default or {})
    local function displayValue()
        if #selected == 0 then return "None" end
        local parts = {}
        for _, value in ipairs(selected) do table.insert(parts, tostring(value)) end
        local text = table.concat(parts, ", ")
        return #text > 22 and text:sub(1, 19) .. "..." or text
    end
    local selector = new("TextButton", {
        Active = true,
        AutoButtonColor = false,
        BackgroundColor3 = self.Window.Theme.Element,
        BorderSizePixel = 0,
        Text = displayValue(),
        TextColor3 = self.Window.Theme.Text,
        TextSize = 11,
        FontFace = fontFace(nil, false),
        Size = UDim2.fromOffset(selectorWidth, selectorHeight),
        Position = UDim2.new(1, -(selectorWidth + 10), 0.5, -selectorHeight / 2),
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 8,
    }, inner)
    corner(selector, 5)
    local selectorStroke = stroke(selector, self.Window.Theme.Border, 0.38, 1)
    pad(selector, 9, 27, 0, 0)
    selector.TextXAlignment = Enum.TextXAlignment.Left
    local popup
    local arrow = icon(selector, "chevron", 13, self.Window.Theme.SubText)
    arrow.AnchorPoint = Vector2.new(0.5, 0.5)
    arrow.Position = UDim2.new(1, -15, 0.5, 0)
    arrow.ZIndex = selector.ZIndex + 1
    local optionButtons = {}
    local handle = { Value = selected, Row = row }
    local function setSelectorOpen(isOpen)
        tween(selector, {
            BackgroundColor3 = isOpen and self.Window.Theme.Background or self.Window.Theme.Element,
            TextColor3 = isOpen and self.Window.Theme.Accent2 or self.Window.Theme.Text,
        }, 0.12)
        tween(selectorStroke, {
            Color = isOpen and self.Window.Theme.Accent or self.Window.Theme.Border,
            Transparency = isOpen and 0.04 or 0.38,
            Thickness = isOpen and 1.25 or 1,
        }, 0.12)
        setIconTint(arrow, isOpen and self.Window.Theme.Accent2 or self.Window.Theme.SubText, 0.12)
    end
    local function close()
        if popup then
            local closingPopup = popup
            popup = nil
            animatePopupClose(closingPopup, selector)
            tween(arrow, { Rotation = 0 }, 0.14)
            setSelectorOpen(false)
        end
        optionButtons = {}
        if self.Window._dropdownClose == close then self.Window._dropdownClose = nil end
    end
    local function refreshButtons(animatedValue)
        for value, button in pairs(optionButtons) do
            if button and button.Parent then
                local isSelected = selectedSet[tostring(value)] == true
                button.Text = (isSelected and "ON  " or "OFF  ") .. tostring(value)
                local background = isSelected and self.Window.Theme.Accent or self.Window.Theme.Surface2
                local textColor = isSelected and self.Window.Theme.Background or self.Window.Theme.Text
                if animatedValue ~= nil and tostring(value) == tostring(animatedValue) then
                    tween(button, { BackgroundColor3 = background, TextColor3 = textColor }, 0.1)
                else
                    button.BackgroundColor3 = background
                    button.TextColor3 = textColor
                end
            end
        end
    end
    local function open()
        if popup then close(); return end
        if self.Window._dropdownClose and self.Window._dropdownClose ~= close then pcall(self.Window._dropdownClose) end
        local popupWidth, popupHeight, optionHeight = dropdownPopupMetrics(selector, #options, self.Window.IsMobile == true, true)
        popup = new("ScrollingFrame", {
            Active = true,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = self.Window.Theme.Background,
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(),
            ScrollBarImageColor3 = self.Window.Theme.Accent,
            ScrollBarThickness = self.Window.IsMobile and 3 or 2,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            Size = UDim2.fromOffset(popupWidth, popupHeight),
            ZIndex = 60,
        }, self.Window.Gui)
        corner(popup, 7); stroke(popup, self.Window.Theme.Accent, 0.08, 1.15); pad(popup, 3, 3, 3, 3)
        placePopup(popup, selector, popupWidth, popupHeight, true, not self.Window.IsMobile)
        animatePopupOpen(popup, selector)
        setSelectorOpen(true)
        tween(arrow, { Rotation = 180 }, 0.16, Enum.EasingStyle.Quint)
        new("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }, popup)
        if #options == 0 then
            new("TextLabel", {
                BackgroundTransparency = 1,
                FontFace = fontFace(nil, false),
                Size = UDim2.new(1, 0, 0, optionHeight),
                Text = "No options",
                TextColor3 = self.Window.Theme.SubText,
                TextSize = self.Window.IsMobile and 11 or 10,
                ZIndex = 61,
            }, popup)
        end
        for _, option in ipairs(options) do
            local value = tostring(option)
            local optionButton = new("TextButton", {
                Active = true,
                AutoButtonColor = false,
                BackgroundColor3 = selectedSet[value] and self.Window.Theme.Accent or self.Window.Theme.Surface2,
                BorderSizePixel = 0,
                Text = (selectedSet[value] and "ON  " or "OFF  ") .. value,
                TextColor3 = selectedSet[value] and self.Window.Theme.Background or self.Window.Theme.Text,
                TextSize = self.Window.IsMobile and 11 or 10,
                FontFace = fontFace(nil, false),
                Size = UDim2.new(1, 0, 0, optionHeight),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 61,
            }, popup)
            corner(optionButton, 4); pad(optionButton, 7, 7, 0, 0)
            pressAnimation(self.Window, optionButton)
            connect(self.Window, optionButton.MouseEnter, function()
                tween(optionButton, { BackgroundColor3 = self.Window.Theme.Element:Lerp(self.Window.Theme.Accent, 0.2), TextColor3 = self.Window.Theme.Accent2 }, 0.1)
            end)
            connect(self.Window, optionButton.MouseLeave, function()
                local isSelected = selectedSet[value] == true
                tween(optionButton, {
                    BackgroundColor3 = isSelected and self.Window.Theme.Accent or self.Window.Theme.Surface2,
                    TextColor3 = isSelected and self.Window.Theme.Background or self.Window.Theme.Text,
                }, 0.12)
            end)
            optionButtons[value] = optionButton
            connectActivated(self.Window, optionButton, function()
                if selectedSet[value] then
                    selectedSet[value] = nil
                    for index, item in ipairs(selected) do
                        if tostring(item) == value then table.remove(selected, index); break end
                    end
                else
                    selectedSet[value] = true
                    table.insert(selected, option)
                end
                selector.Text = displayValue()
                refreshButtons(value)
                if type(data.Callback or data.callback) == "function" then
                    task.spawn(function() pcall(data.Callback or data.callback, selected) end)
                end
            end)
        end
        self.Window._dropdownClose = close
    end
    function handle:Set(values, silent)
        setValues(values)
        self.Value = selected
        selector.Text = displayValue()
        refreshButtons()
        if not silent and type(data.Callback or data.callback) == "function" then
            task.spawn(function() pcall(data.Callback or data.callback, selected) end)
        end
    end
    function handle:Get()
        local result = {}
        for index, value in ipairs(selected) do result[index] = value end
        return result
    end
    function handle:SetOptions(nextOptions)
        if popup then close() end
        options = type(nextOptions) == "table" and nextOptions or { nextOptions }
        local retained = {}
        for _, option in ipairs(options) do
            if selectedSet[tostring(option)] then table.insert(retained, option) end
        end
        self:Set(retained, true)
    end
    handle.SetItems = handle.SetOptions
    connectActivated(self.Window, selector, open)
    pressAnimation(self.Window, selector)
    self.Window:_registerFlag(data.Flag, handle)
    table.insert(self.Controls, handle)
    return handle
end

function AxelUI.SectionMethods:AddColorPicker(data)
    data = data or {}
    data.Icon = data.Icon or "chart"
    data.RightReserved = data.RightReserved or 54
    local row, inner = self.Window:_makeRow(self.Body, data, data.Height or 40)
    local initial = typeof(data.Default) == "Color3" and data.Default or self.Window.Theme.Accent
    local swatch = new("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = initial,
        BorderSizePixel = 0,
        Text = "",
        Size = UDim2.fromOffset(34, 22),
        Position = UDim2.new(1, -44, 0.5, -11),
        ZIndex = 8,
    }, inner)
    corner(swatch, 7); stroke(swatch, self.Window.Theme.Border, 0.15, 1)
    local popup
    local handle = { Value = initial, Row = row }
    local palette = {
        self.Window.Theme.Accent, self.Window.Theme.Accent2, self.Window.Theme.Success,
        self.Window.Theme.Warning, self.Window.Theme.Danger, self.Window.Theme.Text,
        Color3.fromRGB(116, 96, 255), Color3.fromRGB(62, 196, 214),
    }
    local function close()
        if popup then popup:Destroy(); popup = nil end
        if self.Window._dropdownClose == close then self.Window._dropdownClose = nil end
    end
    local function choose(color)
        handle.Value = color
        swatch.BackgroundColor3 = color
        close()
        if type(data.Callback or data.callback) == "function" then task.spawn(function() pcall(data.Callback or data.callback, color) end) end
    end
    local function open()
        close()
        popup = new("Frame", {
            BackgroundColor3 = self.Window.Theme.Surface,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(196, 122),
            ZIndex = 70,
        }, self.Window.Gui)
        corner(popup, 7); stroke(popup, self.Window.Theme.Border, 0.05, 1); pad(popup, 8, 8, 8, 8)
        placePopup(popup, swatch, 196, 122)
        local paletteHolder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 58), ZIndex = 71 }, popup)
        local grid = new("UIGridLayout", { CellPadding = UDim2.fromOffset(6, 6), CellSize = UDim2.fromOffset(26, 26), SortOrder = Enum.SortOrder.LayoutOrder }, paletteHolder)
        for _, color in ipairs(palette) do
            local colorButton = new("TextButton", { AutoButtonColor = false, BackgroundColor3 = color, BorderSizePixel = 0, Text = "", ZIndex = 72 }, paletteHolder)
            corner(colorButton, 6); stroke(colorButton, self.Window.Theme.Border, 0.2, 1)
            pressAnimation(self.Window, colorButton)
            connect(self.Window, colorButton.MouseButton1Click, function() choose(color) end)
        end
        local hexBox = new("TextBox", {
            BackgroundColor3 = self.Window.Theme.Element,
            BorderSizePixel = 0,
            ClearTextOnFocus = false,
            FontFace = fontFace(nil, false),
            PlaceholderColor3 = self.Window.Theme.Muted,
            PlaceholderText = "#RRGGBB",
            Size = UDim2.fromOffset(112, 25),
            Position = UDim2.fromOffset(0, 72),
            Text = "",
            TextColor3 = self.Window.Theme.Text,
            TextSize = 11,
            ZIndex = 72,
        }, popup)
        corner(hexBox, 5); stroke(hexBox, self.Window.Theme.Border, 0.2, 1); pad(hexBox, 7, 7, 0, 0)
        local applyHex = new("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = self.Window.Theme.Accent,
            BorderSizePixel = 0,
            FontFace = fontFace(nil, true),
            Position = UDim2.fromOffset(120, 72),
            Size = UDim2.fromOffset(60, 25),
            Text = "Apply",
            TextColor3 = self.Window.Theme.Background,
            TextSize = 10,
            ZIndex = 72,
        }, popup)
        corner(applyHex, 5); pressAnimation(self.Window, applyHex)
        local function commitHex()
            local value = hexBox.Text:gsub("#", ""):gsub("%s", "")
            if not value:match("^%x%x%x%x%x%x$") then
                tween(hexBox, { BackgroundColor3 = self.Window.Theme.Danger }, 0.1)
                task.delay(0.25, function() if hexBox.Parent then tween(hexBox, { BackgroundColor3 = self.Window.Theme.Element }, 0.16) end end)
                return
            end
            choose(Color3.fromRGB(tonumber(value:sub(1, 2), 16), tonumber(value:sub(3, 4), 16), tonumber(value:sub(5, 6), 16)))
        end
        connect(self.Window, applyHex.MouseButton1Click, commitHex)
        connect(self.Window, hexBox.FocusLost, function(enterPressed) if enterPressed then commitHex() end end)
        self.Window._dropdownClose = close
    end
    function handle:Set(color, silent)
        if typeof(color) ~= "Color3" then return end
        handle.Value = color
        swatch.BackgroundColor3 = color
        if not silent and type(data.Callback or data.callback) == "function" then task.spawn(function() pcall(data.Callback or data.callback, color) end) end
    end
    function handle:Get() return handle.Value end
    connect(self.Window, swatch.MouseButton1Click, open)
    pressAnimation(self.Window, swatch)
    self.Window:_registerFlag(data.Flag, handle)
    table.insert(self.Controls, handle)
    return handle
end

AxelUI.SectionMethods.AddColorpicker = AxelUI.SectionMethods.AddColorPicker

function AxelUI.SectionMethods:AddInput(data)
    data = data or {}
    data.Icon = data.Icon or "search"
    local fullWidth = data.FullWidth == true or data.Layout == "Stacked"
    data.RightReserved = data.RightReserved or (fullWidth and 18 or 170)
    local row, inner, title = self.Window:_makeRow(self.Body, data, data.Height or (fullWidth and 60 or 42))
    local titleX = title and title.Position.X.Offset or 27
    local box = new("TextBox", {
        BackgroundColor3 = self.Window.Theme.Element,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        ClipsDescendants = true,
        MultiLine = false,
        PlaceholderText = tostring(data.Placeholder or "Input"),
        PlaceholderColor3 = self.Window.Theme.Muted,
        Text = tostring(data.Default or ""),
        TextColor3 = self.Window.Theme.Text,
        TextSize = 11,
        TextWrapped = false,
        TextScaled = false,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        FontFace = fontFace(nil, false),
        Size = fullWidth and UDim2.new(1, -(titleX + 18), 0, 24) or UDim2.fromOffset(160, 25),
        Position = fullWidth and UDim2.new(0, titleX, 0, 28) or UDim2.new(1, -170, 0.5, -12),
        ZIndex = 8,
    }, inner)
    corner(box, 5)
    pad(box, 8, 8, 0, 0)
    local boxStroke = stroke(box, self.Window.Theme.Border, 0.35, 1)
    local handle = { Instance = box, Value = box.Text }
    function handle:Set(value, silent)
        self.Value = tostring(value or ""); box.Text = self.Value
        if not silent and type(data.Callback or data.callback) == "function" then task.spawn(function() pcall(data.Callback or data.callback, self.Value) end) end
    end
    function handle:Get() return box.Text end
    connect(self.Window, box.Focused, function()
        tween(boxStroke, { Color = self.Window.Theme.Accent, Transparency = 0.04, Thickness = 1.15 }, 0.12)
    end)
    connect(self.Window, box.FocusLost, function() handle:Set(box.Text) end)
    connect(self.Window, box.FocusLost, function()
        tween(boxStroke, { Color = self.Window.Theme.Border, Transparency = 0.35, Thickness = 1 }, 0.14)
    end)
    self.Window:_registerFlag(data.Flag, handle)
    table.insert(self.Controls, handle)
    return handle
end

AxelUI.SectionMethods.AddTextbox = AxelUI.SectionMethods.AddInput

function AxelUI.SectionMethods:AddKeybind(data)
    data = data or {}
    data.Icon = data.Icon or "settings"
    data.RightReserved = data.RightReserved or 110
    local row, inner = self.Window:_makeRow(self.Body, data, data.Height or 40)
    local initialKey = keyName(data.Default or "None")
    local keyButton = new("TextButton", { AutoButtonColor = false, BackgroundColor3 = self.Window.Theme.Element, BorderSizePixel = 0, Text = initialKey, TextColor3 = self.Window.Theme.Text, TextSize = 11, FontFace = fontFace(nil, false), Size = UDim2.fromOffset(100, 25), Position = UDim2.new(1, -110, 0.5, -12), ZIndex = 8 }, inner)
    corner(keyButton, 5)
    local handle = { Value = initialKey, Listening = false }
    function handle:Set(value, silent)
        self.Value = keyName(value)
        keyButton.Text = self.Value
        if not silent and type(data.OnChange) == "function" then task.spawn(function() pcall(data.OnChange, self.Value) end) end
    end
    function handle:Get() return self.Value end
    connect(self.Window, keyButton.MouseButton1Click, function()
        handle.Listening = true; keyButton.Text = "Press key..."
    end)
    connect(self.Window, UserInputService.InputBegan, function(input, processed)
        if handle.Listening and not processed then
            local key = input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode.Name or input.UserInputType.Name
            handle.Listening = false; handle:Set(key)
            if type(data.Callback or data.callback) == "function" then task.spawn(function() pcall(data.Callback or data.callback, key) end) end
        elseif not processed and keyMatches(input, handle.Value) then
            local press = data.OnPress or data.Press or data.onPress
            if type(press) == "function" then task.spawn(function() pcall(press, handle.Value) end) end
        end
    end)
    if (data.OnPress or data.Press or data.onPress) and keyName(data.Default or "None") == keyName(self.Window.ToggleKeybind) then
        self.Window._keybindOwner = handle
    end
    self.Window:_registerFlag(data.Flag, handle)
    table.insert(self.Controls, handle)
    return handle
end

function AxelUI.SectionMethods:AddStatus(data)
    data = data or {}
    data.Icon = data.Icon or "check"
    local copyable = data.Copyable == true or data.Copy == true
    local inlineValue = data.ValueInDescription == true
    local initialText = tostring(data.Text or data.Status or "Ready")
    if inlineValue then
        data.Description = data.Description or (tostring(data.ValuePrefix or "") .. initialText)
        data.RightReserved = tonumber(data.RightReserved) or (copyable and 36 or 8)
    else
        data.RightReserved = math.max(tonumber(data.RightReserved) or 180, copyable and 206 or 180)
    end
    local row, inner, _, descriptionLabel = self.Window:_makeRow(self.Body, data, data.Height or 34)
    local status = textLabel(inner, data.Text or data.Status or "Ready", 11, data.Color or self.Window.Theme.Success, true)
    local statusWidth = copyable and 176 or 180
    status.Size = UDim2.new(0, statusWidth, 0, 24)
    status.Position = UDim2.new(1, copyable and -206 or -180, 0, 0)
    status.TextXAlignment = Enum.TextXAlignment.Right
    status.TextTruncate = Enum.TextTruncate.AtEnd
    status.ZIndex = 8
    status.Visible = not inlineValue
    if inlineValue and descriptionLabel and data.ValueDescriptionColor then
        descriptionLabel.TextColor3 = data.ValueDescriptionColor
    end
    local copyIcon
    if copyable then
        copyIcon = icon(inner, "copy", 13, data.CopyColor or self.Window.Theme.Accent2)
        copyIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        copyIcon.Position = UDim2.new(1, -9, 0.5, 0)
        copyIcon.ZIndex = 9
    end
    local handle = {
        Instance = status,
        Row = row,
        Window = self.Window,
        Text = tostring(data.Text or data.Status or "Ready"),
        Color = data.Color or self.Window.Theme.Success,
        Copyable = copyable,
        CopyValue = data.CopyValue ~= nil and tostring(data.CopyValue) or tostring(data.Text or data.Status or "Ready"),
        CopyIcon = copyIcon,
        DescriptionInstance = descriptionLabel,
    }
    function handle:Set(value, color, copyValue, description)
        self.Text = tostring(value or "Ready")
        self.Color = color or self.Color
        self.CopyValue = copyValue ~= nil and tostring(copyValue) or self.Text
        status.Text = self.Text
        status.TextColor3 = self.Color
        if inlineValue and descriptionLabel then
            descriptionLabel.Text = tostring(description ~= nil and description or (tostring(data.ValuePrefix or "") .. self.Text))
            descriptionLabel.TextColor3 = data.ValueDescriptionColor or self.Color
        end
    end
    function handle:Get() return self.Text end
    function handle:Copy()
        if not self.Copyable then return false end
        local value = tostring(self.CopyValue or self.Text or "")
        if value == "" then
            pcall(function() self.Window:Notify("Copy unavailable", "There is no value to copy.", "warning") end)
            return false
        end
        local ok, result
        if type(data.CopyCallback) == "function" then
            ok, result = pcall(data.CopyCallback, value)
            ok = ok and result ~= false
        else
            local copier = setclipboard or toclipboard
            if type(copier) == "function" then
                ok, result = pcall(copier, value)
                ok = ok and result ~= false
            else
                ok = false
            end
        end
        if ok then
            pcall(function() self.Window:Notify(data.CopyTitle or "Copied", tostring(data.CopyLabel or data.Name or "Value") .. " copied to clipboard.", "success") end)
        else
            pcall(function() self.Window:Notify("Copy unavailable", "Clipboard access is unavailable.", "warning") end)
        end
        if type(data.Callback) == "function" then task.spawn(function() pcall(data.Callback, value, ok) end) end
        return ok
    end
    if copyable then connect(self.Window, row.MouseButton1Click, function() handle:Copy() end) end
    table.insert(self.Controls, handle)
    return handle
end

-- Profile card for session dashboards. It keeps the avatar, account name and
-- account metadata together, while allowing the caller to refresh the fields.
function AxelUI.SectionMethods:AddProfileCard(data)
    data = data or {}
    local window = self.Window
    local card = new("Frame", {
        BackgroundColor3 = window.Theme.Background,
        BorderSizePixel = 0,
        LayoutOrder = data.LayoutOrder or 0,
        Size = UDim2.new(1, 0, 0, 72),
    }, self.Body)
    corner(card, 8); stroke(card, window.Theme.Border, 0.22, 1)

    local avatarHolder = new("Frame", {
        BackgroundColor3 = window.Theme.Element,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Position = UDim2.new(0, 10, 0.5, -25),
        Size = UDim2.fromOffset(50, 50),
    }, card)
    corner(avatarHolder, 25); stroke(avatarHolder, data.AvatarBorderColor or window.Theme.Accent2, 0.18, 1)
    local avatar = new("ImageLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = "",
        ImageTransparency = 0,
        ScaleType = Enum.ScaleType.Crop,
        Size = UDim2.fromScale(1, 1),
        Visible = true,
        ZIndex = 7,
    }, avatarHolder)
    corner(avatar, 25)
    local avatarFallback = icon(avatarHolder, data.Icon or "user", 21, data.IconColor or window.Theme.Accent2)
    avatarFallback.AnchorPoint = Vector2.new(0.5, 0.5)
    avatarFallback.Position = UDim2.fromScale(0.5, 0.5)
    avatarFallback.ZIndex = 6

    local nameLabel = textLabel(card, "Player", 12, window.Theme.Text, true)
    nameLabel.Position = UDim2.fromOffset(72, 7)
    nameLabel.Size = UDim2.new(1, -82, 0, 17)
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    local usernameLabel = textLabel(card, "@player", 9, window.Theme.SubText, false)
    usernameLabel.Position = UDim2.fromOffset(72, 25)
    usernameLabel.Size = UDim2.new(1, -82, 0, 14)
    usernameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    local accountLabel = textLabel(card, "Account Age: -- days", 9, window.Theme.Accent2, true)
    accountLabel.Position = UDim2.fromOffset(72, 43)
    accountLabel.Size = UDim2.new(1, -82, 0, 14)
    accountLabel.TextTruncate = Enum.TextTruncate.AtEnd

    local handle = { Instance = card, Avatar = avatar, Name = nameLabel, Username = usernameLabel, Account = accountLabel }
    local avatarIdentity
    local function updateAvatar(values)
        local userId = tonumber(values.AvatarUserId or values.UserId or values.AccountId)
        local requestedImage = values.AvatarImage or values.Image
        local identity = tostring(requestedImage or userId or "")
        if identity == avatarIdentity then return end
        avatarIdentity = identity
        local source = imageSource(requestedImage, window.AssetFolder)
        local retries = {}
        if userId then
            local headshot = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId)
            local avatarImage = string.format("rbxthumb://type=Avatar&id=%d&w=150&h=150", userId)
            if not source then source = headshot elseif source ~= headshot then table.insert(retries, headshot) end
            if source ~= avatarImage then table.insert(retries, avatarImage) end
        end
        if source then
            avatar.Visible = true
            avatarFallback.Visible = true
            avatar.Image = source
            watchImage(avatar, function()
                avatar.Visible = true
                avatarFallback.Visible = false
            end, function()
                avatar.Visible = false
                avatarFallback.Visible = true
            end, 5, retries)
        else
            avatar.Image = ""
            avatar.Visible = false
            avatarFallback.Visible = true
        end
    end
    function handle:Set(values)
        values = type(values) == "table" and values or { DisplayName = values }
        local displayName = values.DisplayName or values.Name or "Player"
        local username = tostring(values.Username or values.UserName or values.Name or "player")
        if username:sub(1, 1) ~= "@" then username = "@" .. username end
        local userId = values.UserId or values.AccountId
        if userId ~= nil then username = username .. " · ID: " .. tostring(userId) end
        local age = values.AccountAge or values.Age
        local ageText = age == nil and "Account Age: --" or "Account Age: " .. tostring(age) .. (type(age) == "number" and " days" or "")
        nameLabel.Text = tostring(displayName)
        usernameLabel.Text = username
        accountLabel.Text = tostring(values.AccountText or ageText)
        accountLabel.TextColor3 = values.AccountColor or window.Theme.Accent2
        updateAvatar(values)
        self.DisplayName = tostring(displayName)
        self.UserId = userId and tostring(userId) or ""
        self.AccountAge = age
    end
    function handle:Get()
        return { DisplayName = self.DisplayName, UserId = self.UserId, AccountAge = self.AccountAge }
    end
    handle:Set(data)
    window:_registerSearch(card, tostring(data.DisplayName or data.Name or "") .. " " .. tostring(data.Username or data.UserName or "") .. " " .. tostring(data.UserId or ""))
    table.insert(self.Controls, handle)
    return handle
end

-- Compact 2-column status tiles for dashboard telemetry such as FPS, ping,
-- uptime and player counts. Each returned metric has the same Set/Get shape
-- as AddStatus, and can be fetched by Key or Name.
function AxelUI.SectionMethods:AddMetricGrid(data)
    data = data or {}
    local window = self.Window
    local items = data.Items or data.Metrics or {}
    if type(items) ~= "table" then items = {} end
    local columns = math.max(1, math.floor(tonumber(data.Columns) or 2))
    local gap = math.max(0, tonumber(data.Gap) or 8)
    local cellHeight = math.max(42, tonumber(data.CellHeight) or 50)
    local itemCount = #items
    local rowCount = math.max(1, math.ceil(itemCount / columns))
    local gridHeight = itemCount > 0 and (rowCount * cellHeight + math.max(0, rowCount - 1) * gap) or 0
    local grid = new("Frame", {
        BackgroundTransparency = 1,
        LayoutOrder = data.LayoutOrder or 0,
        Size = UDim2.new(1, 0, 0, gridHeight),
    }, self.Body)
    new("UIGridLayout", {
        CellPadding = UDim2.fromOffset(gap, gap),
        CellSize = UDim2.new(1 / columns, -gap * (columns - 1) / columns, 0, cellHeight),
        FillDirection = Enum.FillDirection.Horizontal,
        FillDirectionMaxCells = columns,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, grid)

    local handle = { Instance = grid, Metrics = {} }
    for index, item in ipairs(items) do
        item = type(item) == "table" and item or { Name = tostring(item), Value = "--" }
        local metricName = tostring(item.Name or item.Title or ("Metric " .. tostring(index)))
        local metricColor = item.Color or window.Theme.Accent2
        local tile = new("Frame", {
            BackgroundColor3 = window.Theme.Background,
            BorderSizePixel = 0,
            LayoutOrder = item.LayoutOrder or index,
        }, grid)
        corner(tile, 7); stroke(tile, window.Theme.Border, 0.22, 1)
        local metricIcon = icon(tile, item.Icon or "activity", 15, item.IconColor or metricColor)
        metricIcon.Position = UDim2.fromOffset(8, 6)
        -- Keep this icon above the tile under global ScreenGui ZIndex.
        metricIcon.ZIndex = (tonumber(tile.ZIndex) or 0) + 1
        local metricTitle = textLabel(tile, metricName, 9, window.Theme.SubText, false)
        metricTitle.Position = UDim2.fromOffset(26, 5)
        metricTitle.Size = UDim2.new(1, -32, 0, 15)
        metricTitle.TextTruncate = Enum.TextTruncate.AtEnd
        local metricValue = textLabel(tile, tostring(item.Value or item.Text or "--"), 13, metricColor, true)
        metricValue.Position = UDim2.fromOffset(8, 24)
        metricValue.Size = UDim2.new(1, -16, 0, 19)
        metricValue.TextTruncate = Enum.TextTruncate.AtEnd
        local metric = { Instance = metricValue, Tile = tile, Title = metricTitle, Icon = metricIcon, Text = metricValue.Text, Color = metricColor }
        function metric:Set(value, color)
            self.Text = tostring(value or "--")
            self.Color = color or self.Color
            metricValue.Text = self.Text
            metricValue.TextColor3 = self.Color
            if item.IconColor == nil then setIconTint(metricIcon, self.Color, window.ReduceEffects and 0 or nil) end
        end
        function metric:Get() return self.Text end
        local key = tostring(item.Key or metricName)
        handle.Metrics[key] = metric
        handle.Metrics[metricName] = metric
        table.insert(self.Controls, metric)
        window:_registerSearch(tile, metricName .. " " .. tostring(item.Description or ""))
    end
    function handle:Get(key)
        return self.Metrics[tostring(key or "")]
    end
    function handle:Set(key, value, color)
        local metric = self:Get(key)
        if metric then metric:Set(value, color) end
        return metric
    end
    table.insert(self.Controls, handle)
    return handle
end

function AxelUI.SectionMethods:AddDivider()
    return new("Frame", { BackgroundColor3 = self.Window.Theme.Border, BackgroundTransparency = 0.2, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1) }, self.Body)
end

AxelUI.SectionMethods.Text = AxelUI.SectionMethods.AddText
AxelUI.SectionMethods.Label = AxelUI.SectionMethods.AddLabel
AxelUI.SectionMethods.Paragraph = AxelUI.SectionMethods.AddParagraph
AxelUI.SectionMethods.Button = AxelUI.SectionMethods.AddButton
AxelUI.SectionMethods.AddActions = AxelUI.SectionMethods.AddActionBar
AxelUI.SectionMethods.ActionBar = AxelUI.SectionMethods.AddActionBar
AxelUI.SectionMethods.Toggle = AxelUI.SectionMethods.AddToggle
AxelUI.SectionMethods.Slider = AxelUI.SectionMethods.AddSlider
AxelUI.SectionMethods.Dropdown = AxelUI.SectionMethods.AddDropdown
AxelUI.SectionMethods.MultiDropdown = AxelUI.SectionMethods.AddMultiDropdown
AxelUI.SectionMethods.ColorPicker = AxelUI.SectionMethods.AddColorPicker
AxelUI.SectionMethods.Colorpicker = AxelUI.SectionMethods.AddColorPicker
AxelUI.SectionMethods.TextBox = AxelUI.SectionMethods.AddInput
AxelUI.SectionMethods.Textbox = AxelUI.SectionMethods.AddInput
AxelUI.SectionMethods.Input = AxelUI.SectionMethods.AddInput
AxelUI.SectionMethods.Bind = AxelUI.SectionMethods.AddKeybind
AxelUI.SectionMethods.Keybind = AxelUI.SectionMethods.AddKeybind
AxelUI.SectionMethods.Status = AxelUI.SectionMethods.AddStatus
AxelUI.SectionMethods.ProfileCard = AxelUI.SectionMethods.AddProfileCard
AxelUI.SectionMethods.MetricGrid = AxelUI.SectionMethods.AddMetricGrid
AxelUI.SectionMethods.Separator = AxelUI.SectionMethods.AddDivider
AxelUI.SectionMethods.CreateToggle = AxelUI.SectionMethods.AddToggle
AxelUI.SectionMethods.CreateSlider = AxelUI.SectionMethods.AddSlider
AxelUI.SectionMethods.CreateDropdown = AxelUI.SectionMethods.AddDropdown
AxelUI.SectionMethods.CreateMultiDropdown = AxelUI.SectionMethods.AddMultiDropdown
AxelUI.SectionMethods.CreateButton = AxelUI.SectionMethods.AddButton
AxelUI.SectionMethods.CreateInput = AxelUI.SectionMethods.AddInput
AxelUI.SectionMethods.CreateKeybind = AxelUI.SectionMethods.AddKeybind
AxelUI.SectionMethods.CreateColorPicker = AxelUI.SectionMethods.AddColorPicker
AxelUI.SectionMethods.CreateTextbox = AxelUI.SectionMethods.AddInput
AxelUI.SectionMethods.CreateStatus = AxelUI.SectionMethods.AddStatus
AxelUI.SectionMethods.CreateProfileCard = AxelUI.SectionMethods.AddProfileCard
AxelUI.SectionMethods.CreateMetricGrid = AxelUI.SectionMethods.AddMetricGrid
AxelUI.SectionMethods.CreateDivider = AxelUI.SectionMethods.AddDivider
AxelUI.SectionMethods.CreateImage = AxelUI.SectionMethods.AddImage
AxelUI.SectionMethods.CreateBanner = AxelUI.SectionMethods.AddBanner
AxelUI.SectionMethods.CreateActionBar = AxelUI.SectionMethods.AddActionBar
AxelUI.SectionMethods.CreateText = AxelUI.SectionMethods.AddText
AxelUI.SectionMethods.CreateParagraph = AxelUI.SectionMethods.AddParagraph
AxelUI.SectionMethods.CreateLabel = AxelUI.SectionMethods.AddLabel

function AxelUI.TabMethods:Section(data)
    return self:AddSection(data)
end

function AxelUI.TabMethods:CreateSection(data)
    return self:AddSection(data)
end

function AxelUI.TabMethods:CreateSubTab(data)
    return self:AddSubTab(data)
end

function AxelUI.TabMethods:Tab(data)
    return self:AddSubTab(data)
end

function AxelUI:Tab(data)
    return self:AddTab(data)
end

function AxelUI:CreateTab(data)
    return self:AddTab(data)
end

function AxelUI:Unload()
    if self._destroyed then return end
    self._destroyed = true
    setFpsSampling(self, false)
    if self._edgeTween then pcall(function() self._edgeTween:Cancel() end); self._edgeTween = nil end
    if self._tabTween then pcall(function() self._tabTween:Cancel() end); self._tabTween = nil end
    for _, entry in ipairs(self._accentTweens or {}) do
        if entry.Gradient then GOLD_GRADIENT_ANIMATIONS[entry.Gradient] = nil end
        if entry.Tween then pcall(function() entry.Tween:Cancel() end) end
    end
    for _, animation in ipairs(self._glintTweens or {}) do pcall(function() animation:Cancel() end) end
    self._accentTweens = {}
    self._glintTweens = {}
    for _, connection in ipairs(self._connections) do pcall(function() connection:Disconnect() end) end
    self._connections = {}
    if self._dropdownClose then pcall(self._dropdownClose) end
    if self.Gui then pcall(function() self.Gui:Destroy() end) end
    if self._globalKey and _G[self._globalKey] == self then _G[self._globalKey] = nil end
    local registry = self._windowRegistry
    if registry and self._globalKey and registry[self._globalKey] == self then
        registry[self._globalKey] = nil
        if next(registry) == nil and self._sharedEnvironment
            and self._sharedEnvironment.__AxelUI_WindowRegistry == registry then
            self._sharedEnvironment.__AxelUI_WindowRegistry = nil
        end
    end
    if AxelUI._activeWindow == self then
        AxelUI._activeWindow = nil
        ACTIVE_FONT = nil
        ACTIVE_ASSET_FOLDER = nil
    end
    self._flags = {}
    self._searchRows = {}
    self._searchData = setmetatable({}, { __mode = "k" })
    self._notifications = {}
    self.Tabs = {}
    self.ActiveTab = nil
    self._loadingOverlay = nil
    self.RestoreButton = nil
    self.TouchButton = nil
    self.Window = nil
    self.Gui = nil
    self._windowRegistry = nil
    self._sharedEnvironment = nil
    return true
end

function AxelUI:Destroy()
    return self:Unload()
end

-- Ask before removing the whole interface. Unload() remains the direct API for
-- scripts that intentionally tear down immediately; visible close controls use
-- this guarded version so an accidental click cannot destroy the UI.
function AxelUI:ConfirmUnload()
    if self._destroyed or not self.Gui then return false end
    if self._confirmOverlay and self._confirmOverlay.Parent then return true end
    local overlay = new("Frame", {
        BackgroundColor3 = self.Theme.Background,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 400,
    }, self.Gui)
    local dimmer = new("Frame", { Active = true, BackgroundColor3 = self.Theme.Background, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 401 }, overlay)
    local card = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = self.Theme.Surface,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(300, 142),
        ZIndex = 401,
    }, overlay)
    corner(card, 12)
    local cardStroke = stroke(card, self.Theme.Accent2, 0.28, 1.2)
    local cardScale = new("UIScale", { Scale = 0.84 }, card)
    local title = textLabel(card, "Unload Axel Hub?", 14, self.Theme.Text, true)
    title.Position = UDim2.fromOffset(18, 16); title.Size = UDim2.new(1, -36, 0, 22); title.ZIndex = 402
    local body = textLabel(card, "The UI and its listeners will be removed.", 10, self.Theme.SubText, false)
    body.Position = UDim2.fromOffset(18, 43); body.Size = UDim2.new(1, -36, 0, 18); body.ZIndex = 402
    local cancel = new("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Theme.Element,
        BorderSizePixel = 0,
        Text = "Cancel",
        TextColor3 = self.Theme.Text,
        TextSize = 10,
        FontFace = fontFace(nil, true),
        Size = UDim2.fromOffset(112, 30),
        Position = UDim2.fromOffset(18, 94),
        ZIndex = 402,
    }, card)
    corner(cancel, 8); stroke(cancel, self.Theme.Border, 0.2, 1); pressAnimation(self, cancel)
    local confirm = new("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Theme.Accent,
        BorderSizePixel = 0,
        Text = "Unload",
        TextColor3 = self.Theme.Background,
        TextSize = 10,
        FontFace = fontFace(nil, true),
        Size = UDim2.fromOffset(112, 30),
        Position = UDim2.new(1, -130, 0, 94),
        ZIndex = 402,
    }, card)
    corner(confirm, 8); pressAnimation(self, confirm)
    local closing = false
    local function closePrompt(unload)
        if closing then return end
        closing = true
        tween(dimmer, { BackgroundTransparency = 1 }, 0.14)
        tween(cardScale, { Scale = 0.88 }, 0.14, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        tween(cardStroke, { Transparency = 0.65, Thickness = 1 }, 0.14)
        task.delay(0.16, function()
            if overlay.Parent then overlay:Destroy() end
            self._confirmOverlay = nil
            if unload and not self._destroyed then self:Unload() end
        end)
    end
    self._confirmOverlay = overlay
    tween(dimmer, { BackgroundTransparency = 0.42 }, 0.16, Enum.EasingStyle.Quint)
    tween(cardScale, { Scale = 1 }, 0.28, Enum.EasingStyle.Back)
    tween(cardStroke, { Transparency = 0.04, Thickness = 1.6 }, 0.18, Enum.EasingStyle.Quint)
    connect(self, cancel.MouseButton1Click, function() closePrompt(false) end)
    connect(self, confirm.MouseButton1Click, function() closePrompt(true) end)
    return true
end

AxelUI.RequestUnload = AxelUI.ConfirmUnload

function AxelUI:Toggle()
    if not self.Window then return end
    self:SetOpen(not self._open)
end

function AxelUI.new(options)
    options = options or {}
    local glassOptions = type(options.Glass) == "table" and options.Glass or {}
    local globalKey = tostring(options.GuiName or options.Name or "AxelUI")
    local sharedEnvironment = getSharedEnvironment()
    local windowRegistry = sharedEnvironment.__AxelUI_WindowRegistry
    if type(windowRegistry) ~= "table" then
        windowRegistry = {}
        sharedEnvironment.__AxelUI_WindowRegistry = windowRegistry
    end
    local seenWindows = {}
    local previousWindows = {}
    if windowRegistry[globalKey] then table.insert(previousWindows, windowRegistry[globalKey]) end
    if _G[globalKey] then table.insert(previousWindows, _G[globalKey]) end
    if sharedEnvironment[globalKey] then table.insert(previousWindows, sharedEnvironment[globalKey]) end
    if AxelUI._activeWindow then table.insert(previousWindows, AxelUI._activeWindow) end
    for _, previous in ipairs(previousWindows) do
        if previous and not seenWindows[previous] then
            seenWindows[previous] = true
            local matchesName = previous == windowRegistry[globalKey]
                or previous == _G[globalKey]
                or previous == sharedEnvironment[globalKey]
                or (type(previous) == "table" and previous._globalKey == globalKey)
            if matchesName and type(previous) == "table" then
                local cleanup = type(previous.Unload) == "function" and previous.Unload or previous.Destroy
                if type(cleanup) == "function" then pcall(cleanup, previous) end
            end
        end
    end
    sharedEnvironment.__AxelUI_WindowRegistry = windowRegistry
    local guiParent = resolveParent()
    -- An executor may change the parent it exposes between runs. Remove only
    -- this window's old ScreenGui from every supported UI parent, not just the
    -- parent selected for the new window.
    local guiParents, seenParents = {}, {}
    local function addGuiParent(parent)
        if typeof(parent) == "Instance" and not seenParents[parent] then
            seenParents[parent] = true
            table.insert(guiParents, parent)
        end
    end
    addGuiParent(guiParent)
    pcall(function() if type(gethui) == "function" then addGuiParent(gethui()) end end)
    pcall(function() addGuiParent(game:GetService("CoreGui")) end)
    pcall(function()
        local player = Players.LocalPlayer
        if player then addGuiParent(player:FindFirstChildOfClass("PlayerGui")) end
    end)
    for _, parent in ipairs(guiParents) do
        local childrenOk, children = pcall(function() return parent:GetChildren() end)
        if childrenOk then
            for _, child in ipairs(children) do
                if child.Name == globalKey and child:IsA("ScreenGui") then
                    pcall(function() child:Destroy() end)
                end
            end
        end
    end
    local self = setmetatable({
        _connections = {},
        _searchRows = {},
        _searchData = setmetatable({}, { __mode = "k" }),
        _notifications = {},
        _destroyed = false,
        _open = true,
        StartMinimized = options.StartMinimized == true,
        _globalKey = globalKey,
        _sharedEnvironment = sharedEnvironment,
        _windowRegistry = windowRegistry,
        Theme = normalizeTheme(options.Theme, AxelUI._pendingTheme),
        Tabs = {},
        ActiveTab = nil,
        _font = options.Font,
        ToggleKeybind = options.ToggleKeybind or Enum.KeyCode.RightControl,
        DesktopSize = options.Size or UDim2.fromOffset(926, 616),
        MobileSize = nil,
        AssetFolder = options.AssetFolder or options.AssetRoot or "",
        ConfigFolder = options.ConfigFolder or "AxelUIConfigs",
        Draggable = options.Draggable ~= false,
        Resizable = options.Resizable ~= false,
        ShowResizeGrip = options.ShowResizeGrip == true,
        GlassEnabled = type(options.Glass) == "boolean" and options.Glass or glassOptions.Enabled == true,
        GlassTransparency = math.clamp(tonumber(glassOptions.Transparency or options.GlassTransparency) or 0.22, 0, 0.45),
        ReduceEffects = options.ReduceEffects == true or (options.ReduceEffects ~= false and LOW_END_TOUCH_CLIENT),
        HoverEffects = options.HoverEffects == true,
        -- These are one-shot input animations. ReduceEffects still suppresses
        -- persistent gradients, glints, and other decorative layers.
        AnimateControls = options.AnimateControls == true,
        AnimateAccents = options.AnimateAccents == true or (options.AnimateAccents ~= false and not LOW_END_TOUCH_CLIENT),
        AnimateOpenClose = options.AnimateOpenClose == true or (options.AnimateOpenClose ~= false and not LOW_END_TOUCH_CLIENT),
        AnimatedBorder = options.AnimatedBorder == true or glassOptions.AnimatedBorder == true
            or (options.AnimatedBorder ~= false and glassOptions.AnimatedBorder ~= false and not LOW_END_TOUCH_CLIENT),
        BorderAnimationDuration = math.clamp(tonumber(glassOptions.AnimationDuration or options.BorderAnimationDuration) or 3.2, 0.8, 15),
        TabAnimation = options.TabAnimation == true or (options.TabAnimation ~= false and not LOW_END_TOUCH_CLIENT),
        TabAnimationDuration = math.clamp(tonumber(options.TabAnimationDuration) or 0.2, 0.08, 0.7),
        TabSlideOffset = math.clamp(tonumber(options.TabSlideOffset) or 18, 4, 48),
        _flags = {},
        _accentTweens = {},
        _glintTweens = {},
    }, AxelUI)
    ACTIVE_FONT = options.Font
    ACTIVE_ASSET_FOLDER = self.AssetFolder
    self.TabMethods = AxelUI.TabMethods
    self.Gui = new("ScreenGui", { Name = globalKey, IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Global }, guiParent)
    _G[globalKey] = self
    windowRegistry[globalKey] = self
    AxelUI._activeWindow = self

    self.Window = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = self.Theme.Background, BackgroundTransparency = self.GlassEnabled and self.GlassTransparency or 0, BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.5), Size = self.DesktopSize, ClipsDescendants = true }, self.Gui)
    corner(self.Window, 18)
    local glitterLayer = new("Frame", { Name = "AxelGlitterLayer", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, self.Window)
    self.GlitterLayer = glitterLayer
    local glitterPoints = {
        {0.06, 0.15, 3}, {0.19, 0.34, 2}, {0.31, 0.12, 2}, {0.43, 0.71, 3},
        {0.56, 0.2, 2}, {0.68, 0.47, 3}, {0.81, 0.15, 2}, {0.93, 0.36, 3},
        {0.12, 0.62, 2}, {0.27, 0.86, 3}, {0.51, 0.46, 2}, {0.75, 0.83, 3},
        {0.88, 0.68, 2}, {0.37, 0.52, 2}, {0.64, 0.9, 2}, {0.04, 0.87, 2},
    }
    for index, point in ipairs(glitterPoints) do
        if self.AnimateAccents then
            local glint = new("Frame", {
                Name = "AxelGlint",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = self.Theme.Accent2,
                BackgroundTransparency = 0.92,
                BorderSizePixel = 0,
                Position = UDim2.fromScale(point[1], point[2]),
                Rotation = index % 2 == 0 and 45 or 0,
                Size = UDim2.fromOffset(point[3], point[3]),
                ZIndex = 3,
            }, glitterLayer)
            corner(glint, point[3])
            local glintTween = TweenService:Create(glint, TweenInfo.new(1.6 + (index % 5) * 0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.68 })
            table.insert(self._glintTweens, glintTween)
            if self._open then glintTween:Play() end
        end
    end
    self.GlowStroke = stroke(self.Window, self.Theme.Accent2, 0.38, 1.35)
    self.EdgeGradient = new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, self.Theme.Accent3),
            ColorSequenceKeypoint.new(0.22, self.Theme.Accent),
            ColorSequenceKeypoint.new(0.5, self.Theme.Accent2),
            ColorSequenceKeypoint.new(0.78, self.Theme.Accent),
            ColorSequenceKeypoint.new(1, self.Theme.Accent3),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.38),
            NumberSequenceKeypoint.new(0.22, 0.16),
            NumberSequenceKeypoint.new(0.5, 0.02),
            NumberSequenceKeypoint.new(0.78, 0.16),
            NumberSequenceKeypoint.new(1, 0.38),
        }),
        Offset = Vector2.new(-1, 0),
    }, self.GlowStroke)
    if self.AnimatedBorder then
        local edgeInfo = TweenInfo.new(self.BorderAnimationDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false)
        local edgeOk, edgeTween = pcall(function()
            return TweenService:Create(self.EdgeGradient, edgeInfo, { Offset = Vector2.new(1, 0) })
        end)
        if edgeOk and edgeTween then
            self._edgeTween = edgeTween
            if self._open then edgeTween:Play() end
        end
    end
    connect(self, self.Window.MouseEnter, function() tween(self.GlowStroke, { Transparency = 0.025, Thickness = 2 }, 0.18) end)
    connect(self, self.Window.MouseLeave, function() tween(self.GlowStroke, { Transparency = 0.24, Thickness = 1.45 }, 0.2) end)
    new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, self.Theme.Background),
            ColorSequenceKeypoint.new(0.55, self.Theme.Surface),
            ColorSequenceKeypoint.new(1, self.Theme.Background),
        }),
        Rotation = 25,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.14),
            NumberSequenceKeypoint.new(0.55, 0),
            NumberSequenceKeypoint.new(1, 0.14),
        }),
    }, self.Window)
    self.Scale = new("UIScale", { Scale = 0.9 }, self.Window)
    if options.Background or options.BackgroundImage then
        self:SetBackground(options.Background or options.BackgroundImage, options.BackgroundTransparency, options.BackgroundScaleType)
    end

    local header = new("Frame", { BackgroundColor3 = self.Theme.Surface, BackgroundTransparency = 0, BorderSizePixel = 0, Position = UDim2.fromOffset(170, 0), Size = UDim2.new(1, -170, 0, 58), ZIndex = 5 }, self.Window)
    self.Header = header
    corner(header, 18)
    -- Square the header's interior corners without covering the outer top-right radius.
    new("Frame", { BackgroundColor3 = self.Theme.Surface, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(18, 18), ZIndex = 6 }, header)
    new("Frame", { BackgroundColor3 = self.Theme.Surface, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -12), Size = UDim2.fromOffset(12, 12), ZIndex = 6 }, header)
    new("Frame", { BackgroundColor3 = self.Theme.Surface, BorderSizePixel = 0, Position = UDim2.new(1, -12, 1, -12), Size = UDim2.fromOffset(12, 12), ZIndex = 6 }, header)
    new("UIGradient", {
        Color = ColorSequence.new(self.Theme.Surface, self.Theme.Background),
        Transparency = NumberSequence.new(0),
        Rotation = 0,
    }, header)
    local dragHandle = new("TextButton", {
        Active = true,
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        Position = UDim2.fromOffset(404, 0),
        Size = UDim2.new(1, -536, 1, 0),
        ZIndex = 6,
    }, header)
    self.DragHandle = dragHandle
    local logoHolder = new("Frame", { BackgroundColor3 = self.Theme.Element, BorderSizePixel = 0, Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(16, 15), ClipsDescendants = true }, header)
    corner(logoHolder, 10)
    local logoScale = math.clamp(tonumber(options.LogoScale) or 1, 0.65, 1.4)
    local logoSize = math.min(30 * logoScale, 32)
    local logoIcon = icon(logoHolder, options.Logo or "star", logoSize, self.Theme.Accent2)
    logoIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    logoIcon.Position = UDim2.fromScale(0.5, 0.5)
    logoIcon.Size = UDim2.fromOffset(logoSize, logoSize)
    local brand = textLabel(header, options.Name or "Axel UI", 14, self.Theme.Text, true); brand.Position = UDim2.fromOffset(58, 15); brand.Size = UDim2.fromOffset(150, 20)
    local subtitle = textLabel(header, options.Subtitle or "Clean, animated interface", 10, self.Theme.SubText, false); subtitle.Position = UDim2.fromOffset(58, 35); subtitle.Size = UDim2.fromOffset(180, 16)
    self.Brand, self.HeaderSubtitle = brand, subtitle
    local search = new("TextBox", { BackgroundColor3 = self.Theme.Background, BorderSizePixel = 0, ClearTextOnFocus = false, PlaceholderText = "Search features, settings, or help...", PlaceholderColor3 = self.Theme.Muted, Text = "", TextColor3 = self.Theme.Text, TextSize = 12, FontFace = fontFace(nil, false), Size = UDim2.fromOffset(300, 34), Position = UDim2.fromOffset(16, 12) }, header)
    corner(search, 9); stroke(search, self.Theme.Border, 0.25, 1); pad(search, 34, 10, 0, 0)
    self.SearchIcon = icon(header, "search", 15, self.Theme.Muted); self.SearchIcon.Position = UDim2.fromOffset(31, 23)
    self.Search = search
    self.FpsText = textLabel(header, "FPS", 10, self.Theme.SubText, true); self.FpsText.Position = UDim2.new(1, -276, 0, 14); self.FpsText.Size = UDim2.fromOffset(29, 20); self.FpsText.TextXAlignment = Enum.TextXAlignment.Right
    self.FpsValue = textLabel(header, "--", 10, self.Theme.Accent2, true); self.FpsValue.Position = UDim2.new(1, -244, 0, 14); self.FpsValue.Size = UDim2.fromOffset(30, 20); self.FpsValue.TextXAlignment = Enum.TextXAlignment.Left
    self.StatusSeparator = textLabel(header, "|", 10, self.Theme.Muted, false); self.StatusSeparator.Position = UDim2.new(1, -211, 0, 14); self.StatusSeparator.Size = UDim2.fromOffset(8, 20); self.StatusSeparator.TextXAlignment = Enum.TextXAlignment.Center
    self.StatusDot = new("Frame", { BackgroundColor3 = self.Theme.Success, BorderSizePixel = 0, Size = UDim2.fromOffset(7, 7), Position = UDim2.new(1, -190, 0, 21) }, header); corner(self.StatusDot, 4)
    self.StatusText = textLabel(header, "Online", 10, self.Theme.Success, true); self.StatusText.Position = UDim2.new(1, -176, 0, 14); self.StatusText.Size = UDim2.fromOffset(60, 20); self.StatusText.TextXAlignment = Enum.TextXAlignment.Left
    local function headerControl(kind, offset, callback)
        local button = new("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = self.Theme.Background,
            BackgroundTransparency = 0.08,
            BorderSizePixel = 0,
            Text = "",
            Size = UDim2.fromOffset(28, 28),
            Position = UDim2.new(1, offset, 0, 15),
            ZIndex = 10,
        }, header)
        corner(button, 7)
        local buttonStroke = stroke(button, self.Theme.Border, 0.16, 1)
        local buttonIcon = icon(button, kind, 12, self.Theme.Text)
        buttonIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        buttonIcon.Position = UDim2.fromScale(0.5, 0.5)
        buttonIcon.ZIndex = 11
        addButtonGlass(self, button, 0.08)
        pressAnimation(self, button)
        connect(self, button.MouseEnter, function()
            tween(button, { BackgroundColor3 = self.Theme.Element:Lerp(self.Theme.Accent, 0.2) }, 0.12)
            tween(buttonStroke, { Color = self.Theme.Accent2, Transparency = 0.04, Thickness = 1.25 }, 0.12)
            setIconTint(buttonIcon, self.Theme.Accent2, 0.12)
        end)
        connect(self, button.MouseLeave, function()
            tween(button, { BackgroundColor3 = self.Theme.Background }, 0.16)
            tween(buttonStroke, { Color = self.Theme.Border, Transparency = 0.16, Thickness = 1 }, 0.16)
            setIconTint(buttonIcon, self.Theme.Text, 0.16)
        end)
        connect(self, button.MouseButton1Click, callback)
        return button
    end
    local minimizeButton = headerControl("minus", -102, function() self:SetOpen(false) end)
    local maximizeButton = headerControl("maximize", -70, function() self:SetMaximized(not self._maximized) end)
    local unloadButton = headerControl("close", -38, function() self:ConfirmUnload() end)
    self.MinimizeButton, self.MaximizeButton, self.UnloadButton = minimizeButton, maximizeButton, unloadButton

    local resizeHandle = new("TextButton", {
        Active = true,
        AutoButtonColor = false,
        BackgroundColor3 = self.Theme.Element,
        BackgroundTransparency = self.ShowResizeGrip and 0.12 or 1,
        BorderSizePixel = 0,
        Text = "",
        TextColor3 = self.Theme.Muted,
        TextTransparency = self.ShowResizeGrip and 0 or 1,
        TextSize = 12,
        FontFace = fontFace(nil, true),
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -3, 1, -3),
        Size = UDim2.fromOffset(24, 24),
        ZIndex = 20,
    }, self.Window)
    corner(resizeHandle, 5)
    local resizeIcon = icon(resizeHandle, "resize", 13, self.Theme.Muted)
    resizeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    resizeIcon.Position = UDim2.fromScale(0.5, 0.5)
    resizeIcon.Visible = self.ShowResizeGrip
    self.ResizeHandle = resizeHandle
    resizeHandle.Visible = self.Resizable
    connect(self, resizeHandle.MouseEnter, function()
        if not self.ShowResizeGrip then
            resizeIcon.Visible = true
            setIconTint(resizeIcon, self.Theme.SubText, 0.12)
            tween(resizeHandle, { BackgroundTransparency = 0.24 }, 0.12)
        end
    end)
    connect(self, resizeHandle.MouseLeave, function()
        if not self.ShowResizeGrip then
            resizeIcon.Visible = false
            tween(resizeHandle, { BackgroundTransparency = 1 }, 0.16)
        end
    end)
    connect(self, resizeHandle.InputBegan, function(input)
        if not self.Resizable or self._maximized then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self._resizing = true
            self._resizeStart = input.Position
            self._resizeSize = self.Window.AbsoluteSize
        end
    end)
    connect(self, dragHandle.InputBegan, function(input)
        if not self.Draggable then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self._dragging = true
            self._dragStart = input.Position
            self._windowStart = self.Window.Position
        end
    end)

    local sidebar = new("Frame", { BackgroundColor3 = self.Theme.Surface, BackgroundTransparency = 0, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0, 170, 1, 0), ZIndex = 6 }, self.Window)
    self.Sidebar = sidebar
    corner(sidebar, 18)
    self.SidebarRightTopCap = new("Frame", { BackgroundColor3 = self.Theme.Surface, BorderSizePixel = 0, Position = UDim2.new(1, -18, 0, 0), Size = UDim2.fromOffset(18, 18), ZIndex = 7 }, sidebar)
    self.SidebarRightBottomCap = new("Frame", { BackgroundColor3 = self.Theme.Surface, BorderSizePixel = 0, Position = UDim2.new(1, -18, 1, -18), Size = UDim2.fromOffset(18, 18), ZIndex = 7 }, sidebar)
    new("Frame", { BackgroundColor3 = self.Theme.Border, BackgroundTransparency = 0.25, BorderSizePixel = 0, Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0), ZIndex = 7 }, sidebar)
    logoHolder.Parent = sidebar; logoHolder.Position = UDim2.fromOffset(18, 16); logoHolder.Size = UDim2.fromOffset(38, 38); logoHolder.ZIndex = 8; logoIcon.ZIndex = 9
    brand.Parent = sidebar; brand.Position = UDim2.fromOffset(66, 15); brand.Size = UDim2.new(1, -78, 0, 20); brand.ZIndex = 8
    subtitle.Parent = sidebar; subtitle.Position = UDim2.fromOffset(66, 36); subtitle.Size = UDim2.new(1, -78, 0, 16); subtitle.ZIndex = 8
    new("Frame", { BackgroundColor3 = self.Theme.Border, BackgroundTransparency = 0.35, BorderSizePixel = 0, Position = UDim2.fromOffset(14, 70), Size = UDim2.new(1, -28, 0, 1) }, sidebar)
    local navTitle = textLabel(sidebar, "NAVIGATION", 9, self.Theme.Muted, true); navTitle.Position = UDim2.fromOffset(14, 84); navTitle.Size = UDim2.new(1, -28, 0, 16)
    self.NavTitle = navTitle
    self.TabList = new("ScrollingFrame", {
        Active = true,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        ClipsDescendants = true,
        Position = UDim2.fromOffset(8, 112),
        ScrollBarImageColor3 = self.Theme.Accent,
        ScrollBarImageTransparency = 0.15,
        ScrollBarThickness = 2,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Size = UDim2.new(1, -16, 1, -232),
    }, sidebar)
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, self.TabList)
    local profile = new("Frame", { BackgroundColor3 = self.Theme.Element, BackgroundTransparency = 0, BorderSizePixel = 0, Position = UDim2.new(0, 12, 1, -112), Size = UDim2.new(1, -24, 0, 52) }, sidebar)
    corner(profile, 11); stroke(profile, self.Theme.Border, 0.28, 1)
    local avatar = new("ImageLabel", { BackgroundColor3 = self.Theme.Background, BorderSizePixel = 0, Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(8, 9), Image = "", ScaleType = Enum.ScaleType.Crop }, profile)
    corner(avatar, 15)
    local avatarFallback = icon(profile, "user", 20, self.Theme.SubText)
    avatarFallback.Position = UDim2.fromOffset(13, 14); avatarFallback.ZIndex = avatar.ZIndex + 1
    local avatarRetries = {}
    pcall(function()
        local player = Players.LocalPlayer
        if player then
            avatar.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", player.UserId)
            table.insert(avatarRetries, string.format("rbxthumb://type=Avatar&id=%d&w=150&h=150", player.UserId))
        end
    end)
    watchImage(avatar, function()
        avatar.Visible = true
        avatarFallback.Visible = false
    end, function()
        avatar.Visible = false
        avatarFallback.Visible = true
    end, 5, avatarRetries)
    local localPlayer = Players.LocalPlayer
    local inGameUsername = localPlayer and tostring(localPlayer.Name or "player") or "player"
    local localDisplayName = localPlayer and tostring(localPlayer.DisplayName or localPlayer.Name or "Axel User") or "Axel User"
    local profileName = textLabel(profile, localDisplayName, 11, self.Theme.Text, true); profileName.Position = UDim2.fromOffset(46, 7); profileName.Size = UDim2.new(1, -54, 0, 17); profileName.TextTruncate = Enum.TextTruncate.AtEnd
    local profileUsername = textLabel(profile, "@" .. inGameUsername, 9, self.Theme.Danger, false); profileUsername.Position = UDim2.fromOffset(46, 27); profileUsername.Size = UDim2.new(1, -54, 0, 14); profileUsername.TextTruncate = Enum.TextTruncate.AtEnd
    local footer = textLabel(sidebar, options.Footer or "AxelUI Library", 9, self.Theme.Muted, false); footer.Position = UDim2.new(0, 14, 1, -50); footer.Size = UDim2.new(1, -28, 0, 40); footer.TextWrapped = true; footer.TextYAlignment = Enum.TextYAlignment.Top
    self.ProfileCard, self.ProfileAvatar, self.ProfileName, self.ProfileUsername = profile, avatar, profileName, profileUsername
    self._profileAvatarRetries = avatarRetries
    self.Footer = footer

    self.PageHolder = new("Frame", { BackgroundColor3 = self.Theme.Background, BackgroundTransparency = self.GlassEnabled and self.GlassTransparency or 0, BorderSizePixel = 0, Position = UDim2.fromOffset(170, 58), Size = UDim2.new(1, -170, 1, -58), ZIndex = 1, ClipsDescendants = true }, self.Window)
    corner(self.PageHolder, 18)
    -- Keep the subtle glitter in the glass backdrop only. Reparenting it below
    -- the page content prevents sparkles from appearing over opaque controls.
    self.GlitterLayer.Parent = self.PageHolder
    self.GlitterLayer.ZIndex = 1
    for _, glint in ipairs(self.GlitterLayer:GetChildren()) do
        if glint.Name == "AxelGlint" then glint.ZIndex = 1 end
    end
    self.PageCornerCaps = {
        new("Frame", { BackgroundColor3 = self.Theme.Background, BackgroundTransparency = self.GlassEnabled and self.GlassTransparency or 0, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(18, 18), ZIndex = 2 }, self.PageHolder),
        new("Frame", { BackgroundColor3 = self.Theme.Background, BackgroundTransparency = self.GlassEnabled and self.GlassTransparency or 0, BorderSizePixel = 0, Position = UDim2.new(1, -18, 0, 0), Size = UDim2.fromOffset(18, 18), ZIndex = 2 }, self.PageHolder),
        new("Frame", { BackgroundColor3 = self.Theme.Background, BackgroundTransparency = self.GlassEnabled and self.GlassTransparency or 0, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -18), Size = UDim2.fromOffset(18, 18), ZIndex = 2 }, self.PageHolder),
    }
    local tabHeader = new("Frame", { BackgroundColor3 = self.Theme.Surface, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 46) }, self.PageHolder)
    corner(tabHeader, 12)
    new("Frame", { BackgroundColor3 = self.Theme.Surface, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -12), Size = UDim2.fromOffset(12, 12) }, tabHeader)
    new("Frame", { BackgroundColor3 = self.Theme.Surface, BorderSizePixel = 0, Position = UDim2.new(1, -12, 1, -12), Size = UDim2.fromOffset(12, 12) }, tabHeader)
    self.TabHeader = tabHeader
    self.TabTitle = textLabel(tabHeader, "Dashboard", 15, self.Theme.Text, true); self.TabTitle.Position = UDim2.fromOffset(22, 6); self.TabTitle.Size = UDim2.new(1, -36, 0, 19)
    self.TabSubtitle = textLabel(tabHeader, "", 10, self.Theme.SubText, false); self.TabSubtitle.Position = UDim2.fromOffset(22, 24); self.TabSubtitle.Size = UDim2.new(1, -36, 0, 15)
    local separator = new("Frame", { BackgroundColor3 = self.Theme.Border, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1) }, tabHeader)
    local emptyState = new("Frame", {
        BackgroundColor3 = self.Theme.Surface,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.54, 0),
        Size = UDim2.new(1, -36, 0, 112),
        ZIndex = 4,
    }, self.PageHolder)
    corner(emptyState, 12); stroke(emptyState, self.Theme.Border, 0.22, 1)
    local emptyIcon = icon(emptyState, "info", 20, self.Theme.Accent2)
    emptyIcon.Position = UDim2.fromOffset(18, 28); emptyIcon.ZIndex = 5
    local emptyTitle = textLabel(emptyState, "Nothing to show yet", 13, self.Theme.Text, true)
    emptyTitle.Position = UDim2.fromOffset(54, 25); emptyTitle.Size = UDim2.new(1, -70, 0, 20); emptyTitle.ZIndex = 5
    local emptyHint = textLabel(emptyState, "Run AxelUI_Library_Example.luau, or add a page with window:AddTab(...).", 10, self.Theme.SubText, false)
    emptyHint.Position = UDim2.fromOffset(54, 49); emptyHint.Size = UDim2.new(1, -70, 0, 38); emptyHint.TextWrapped = true; emptyHint.ZIndex = 5
    self.EmptyState = emptyState

    self.NotificationHolder = new("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -18, 0, 62),
        Size = UDim2.fromOffset(300, 0),
        ZIndex = 300,
    }, self.Gui)
    new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right }, self.NotificationHolder)

    self.TouchButton = new("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = self.Theme.Element,
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        Text = "",
        Size = UDim2.fromOffset(188, 48),
        Position = UDim2.new(1, -206, 1, -62),
        Visible = false,
        ZIndex = 250,
    }, self.Gui)
    corner(self.TouchButton, 16)
    stroke(self.TouchButton, self.Theme.Accent, 0.12, 1.25)
    self.TouchButton.Name = "AxelRestoreButton"
    self.RestoreScale = new("UIScale", { Scale = 1 }, self.TouchButton)
    local touchStroke = self.TouchButton:FindFirstChildOfClass("UIStroke")
    if touchStroke then touchStroke.Thickness = 1.5; touchStroke.Transparency = 0.08 end
    local avatarPlate = new("Frame", { BackgroundColor3 = self.Theme.Background, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(32, 32), ZIndex = 251 }, self.TouchButton)
    corner(avatarPlate, 10)
    local restoreAvatar = new("ImageLabel", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Image = "", ScaleType = Enum.ScaleType.Crop, Visible = false, ZIndex = 252 }, avatarPlate)
    corner(restoreAvatar, 10)
    local touchIcon = icon(avatarPlate, "star", 19, self.Theme.Accent2)
    touchIcon.AnchorPoint = Vector2.new(0.5, 0.5); touchIcon.Position = UDim2.fromScale(0.5, 0.5); touchIcon.ZIndex = 253
    if self.ProfileAvatar then
        pcall(function() restoreAvatar.Image = self.ProfileAvatar.Image end)
        watchImage(self.ProfileAvatar, function()
            local imageOk, image = pcall(function() return self.ProfileAvatar.Image end)
            if imageOk and image ~= "" then
                restoreAvatar.Image = image
                restoreAvatar.Visible = true
                touchIcon.Visible = false
            end
        end, function()
            restoreAvatar.Visible = false
            touchIcon.Visible = true
        end, 5, self._profileAvatarRetries)
    end
    self.RestoreAvatar = restoreAvatar
    local launcherTitle = textLabel(self.TouchButton, "Axel Hub", 11, self.Theme.Text, true)
    launcherTitle.Position = UDim2.fromOffset(48, 7); launcherTitle.Size = UDim2.new(1, -58, 0, 16); launcherTitle.ZIndex = 252
    local statusDot = new("Frame", { BackgroundColor3 = self.Theme.Success, BorderSizePixel = 0, Position = UDim2.fromOffset(49, 29), Size = UDim2.fromOffset(6, 6), ZIndex = 252 }, self.TouchButton)
    corner(statusDot, 3)
    self.RestoreStatusDot = statusDot
    local launcherStatus = textLabel(self.TouchButton, "Online", 9, self.Theme.Success, false)
    launcherStatus.Position = UDim2.fromOffset(59, 24); launcherStatus.Size = UDim2.new(0, 41, 0, 16); launcherStatus.ZIndex = 252; launcherStatus.TextTruncate = Enum.TextTruncate.AtEnd
    self.RestoreStatusText = launcherStatus
    local launcherFps = textLabel(self.TouchButton, "-- FPS", 9, self.Theme.Accent2, true)
    launcherFps.Position = UDim2.fromOffset(102, 24); launcherFps.Size = UDim2.fromOffset(43, 16); launcherFps.ZIndex = 252; launcherFps.TextXAlignment = Enum.TextXAlignment.Right
    self.RestoreFpsText = launcherFps
    local launcherPing = textLabel(self.TouchButton, "-- ms", 9, self.Theme.SubText, false)
    launcherPing.Position = UDim2.new(1, -39, 0, 24); launcherPing.Size = UDim2.fromOffset(33, 16); launcherPing.ZIndex = 252; launcherPing.TextXAlignment = Enum.TextXAlignment.Right
    self.RestorePingText = launcherPing
    if typeof(options.RestoreButtonPosition) == "UDim2" then
        self.TouchButton.Position = options.RestoreButtonPosition
    elseif self.StartMinimized then
        self.TouchButton.Position = UDim2.new(0.5, -94, 0.5, -24)
    end
    self.RestoreButton = self.TouchButton
    addButtonGlass(self, self.TouchButton, 0.02)
    pressAnimation(self, self.TouchButton)
    connect(self, self.TouchButton.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.Touch then
            self._restoreDrag = { Start = input.Position, Origin = self.TouchButton.AbsolutePosition, Moved = false }
        end
    end)
    connect(self, self.TouchButton.MouseButton1Click, function()
        if self._restoreDragged then return end
        self:SetOpen(true)
    end)
    connect(self, search:GetPropertyChangedSignal("Text"), function()
        if self._dropdownClose then pcall(self._dropdownClose) end
        self:_refreshSearch(search.Text)
    end)
    connect(self, UserInputService.InputBegan, function(input, processed)
        if processed or self._destroyed then return end
        if keyMatches(input, self.ToggleKeybind) and not self._keybindOwner then self:Toggle() end
    end)
    connect(self, UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.Touch then
            self._dragging = false
            self._resizing = false
            if self._restoreDrag then
                if self._restoreDrag.Moved then
                    self._restoreDragged = true
                    task.delay(0.25, function() self._restoreDragged = false end)
                end
                self._restoreDrag = nil
            end
        end
    end)
    connect(self, UserInputService.InputChanged, function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        if self._restoreDrag and self.RestoreButton and self.RestoreButton.Visible then
            local delta = input.Position - self._restoreDrag.Start
            if math.abs(delta.X) + math.abs(delta.Y) > 6 then self._restoreDrag.Moved = true end
            if self._restoreDrag.Moved then
                local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
                local buttonSize = self.RestoreButton.AbsoluteSize
                local x = math.clamp(self._restoreDrag.Origin.X + delta.X, 8, math.max(8, viewport.X - buttonSize.X - 8))
                local y = math.clamp(self._restoreDrag.Origin.Y + delta.Y, 8, math.max(8, viewport.Y - buttonSize.Y - 8))
                self.RestoreButton.Position = UDim2.fromOffset(x, y)
            end
        elseif self._dragging and self._dragStart and self._windowStart then
            local delta = input.Position - self._dragStart
            self.Window.Position = UDim2.new(self._windowStart.X.Scale, self._windowStart.X.Offset + delta.X, self._windowStart.Y.Scale, self._windowStart.Y.Offset + delta.Y)
        elseif self._resizing and self._resizeStart and self._resizeSize then
            local delta = input.Position - self._resizeStart
            local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
            local minWidth = self.IsMobile and 300 or 760
            local minHeight = self.IsMobile and 360 or 480
            local maxWidth = self.IsMobile and math.max(minWidth, math.min(480, viewport.X - 18)) or math.max(minWidth, math.min(1440, viewport.X - 24))
            local maxHeight = self.IsMobile and math.max(minHeight, math.min(720, viewport.Y - 26)) or math.max(minHeight, math.min(1000, viewport.Y - 24))
            local width = math.clamp(self._resizeSize.X + delta.X, math.min(minWidth, maxWidth), maxWidth)
            local height = math.clamp(self._resizeSize.Y + delta.Y, math.min(minHeight, maxHeight), maxHeight)
            self.Window.Size = UDim2.fromOffset(width, height)
            if self.IsMobile then
                self.MobileSize = self.Window.Size
            else
                self.DesktopSize = self.Window.Size
            end
        end
    end)
    pcall(function()
        if workspace.CurrentCamera then
            connect(self, workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), function() self:_applyResponsive() end)
        end
    end)
    self:_applyResponsive()

    local overlay = new("Frame", { Active = true, BackgroundColor3 = self.Theme.Background, BackgroundTransparency = 0.02, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 100 }, self.Window)
    local loaderCard = new("Frame", { BackgroundColor3 = self.Theme.Surface, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(326, 156), ZIndex = 101 }, overlay)
    corner(loaderCard, 12); stroke(loaderCard, self.Theme.Accent, 0.42, 1)
    new("UIGradient", { Color = ColorSequence.new(self.Theme.Surface, self.Theme.Background), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.12) }), Rotation = 35 }, loaderCard)
    local loaderScale = new("UIScale", { Scale = 0.78 }, loaderCard)
    local overlayIcon = icon(loaderCard, options.Logo or "star", 34, self.Theme.Accent2); overlayIcon.Position = UDim2.fromOffset(26, 27); overlayIcon.ZIndex = 102
    local loadingTitle = textLabel(loaderCard, options.LoadingText or options.Name or "Axel Hub", 16, self.Theme.Text, true); loadingTitle.Position = UDim2.fromOffset(78, 20); loadingTitle.Size = UDim2.new(1, -96, 0, 24); loadingTitle.ZIndex = 102
    local loadingText = textLabel(loaderCard, options.LoadingSubtitle or "Preparing your workspace", 10, self.Theme.SubText, false); loadingText.Position = UDim2.fromOffset(78, 46); loadingText.Size = UDim2.new(1, -96, 0, 18); loadingText.ZIndex = 102
    local loadingBar = new("Frame", { BackgroundColor3 = self.Theme.Element, BorderSizePixel = 0, Size = UDim2.new(1, -44, 0, 5), Position = UDim2.fromOffset(22, 104), ZIndex = 102 }, loaderCard); corner(loadingBar, 4)
    local loadingFill = new("Frame", { BackgroundColor3 = self.Theme.Accent, BorderSizePixel = 0, Size = UDim2.new(0, 0, 1, 0), ZIndex = 103 }, loadingBar); corner(loadingFill, 4)
    local loadingHint = textLabel(loaderCard, "Loading modules", 9, self.Theme.Muted, false); loadingHint.Position = UDim2.fromOffset(22, 119); loadingHint.Size = UDim2.new(1, -44, 0, 16); loadingHint.ZIndex = 102
    self._loadingOverlay = overlay
    self._loadingFinished = false
    self._loadingStartedAt = os.clock()
    if self.ReduceEffects then
        self.Scale.Scale = 1
        loaderScale.Scale = 1
        loadingFill.Size = UDim2.fromScale(1, 1)
    else
        tween(self.Scale, { Scale = 1 }, 0.45, Enum.EasingStyle.Back)
        tween(loaderScale, { Scale = 1 }, 0.48, Enum.EasingStyle.Back)
        tween(loadingFill, { Size = UDim2.fromScale(1, 1) }, 0.72, Enum.EasingStyle.Quint)
    end
    function self:FinishLoading()
        if self._destroyed or self._loadingFinished then return false end
        self._loadingFinished = true
        local minDisplay = self.ReduceEffects and 0.12 or 0.72
        local remaining = math.max(0, minDisplay - (os.clock() - (self._loadingStartedAt or os.clock())))
        task.delay(remaining, function()
            if self._destroyed or not overlay.Parent then return end
            if self.ReduceEffects then
                overlay:Destroy()
                self._loadingOverlay = nil
                return
            end
            tween(loaderScale, { Scale = 0.94 }, 0.16, Enum.EasingStyle.Quad)
            tween(overlay, { BackgroundTransparency = 1 }, 0.28)
            tween(loaderCard, { BackgroundTransparency = 1 }, 0.22)
            fadeIcon(overlayIcon, 0.2)
            tween(loadingTitle, { TextTransparency = 1 }, 0.2)
            tween(loadingText, { TextTransparency = 1 }, 0.2)
            tween(loadingHint, { TextTransparency = 1 }, 0.2)
            tween(loadingBar, { BackgroundTransparency = 1 }, 0.2)
            tween(loadingFill, { BackgroundTransparency = 1 }, 0.2)
            task.delay(0.3, function()
                if overlay.Parent then overlay:Destroy() end
                if self._loadingOverlay == overlay then self._loadingOverlay = nil end
            end)
        end)
        return true
    end
    if options.ManualLoading ~= true then
        local loadingTimeout = math.clamp(tonumber(options.LoadingTimeout) or 1.5, 1, 30)
        task.delay(loadingTimeout, function()
            if not self._loadingFinished and not self._destroyed then self:FinishLoading() end
        end)
    end

    if self.StartMinimized then
        self._open = false
        setAccentAnimations(self, false)
        self.Window.Visible = false
        self.RestoreButton.Visible = true
        self.RestoreButton.BackgroundTransparency = 0.08
        self.RestoreScale.Scale = 0.72
        local restoreStroke = self.RestoreButton:FindFirstChildOfClass("UIStroke")
        if restoreStroke then restoreStroke.Transparency = 0.04 end
        tween(self.RestoreScale, { Scale = 1 }, 0.34, Enum.EasingStyle.Back)
    end
    -- The sampler also feeds the floating restore card in minimized mode.
    setFpsSampling(self, true)

    function self:CreateTab(data) return self:AddTab(data) end
    function self:WindowToggle() return self:Toggle() end
    self._globalKey = globalKey
    return self
end

function AxelUI:RegisterIcon(name, source)
    if name and source then ICONS[string.lower(tostring(name))] = tostring(source) end
    return self
end

function AxelUI:RegisterIcons(map)
    for name, source in pairs(map or {}) do self:RegisterIcon(name, source) end
    return self
end

AxelUI.Version = 8.27
AxelUI.BuildId = "8.27.0-old-window-cleanup"

function AxelUI.CreateWindow(first, second)
    return AxelUI.new(second or first)
end

return AxelUI
end)()

-- Axel Hub UI for the Anime Breaker feature engine. The engine's original
-- callbacks and priority loop are kept in the bundled script.
local function createAxelAnimeBreakerUI(AxelUI, CFG, getLibrary, getMap, getHighestMap, getTarget, cleanup)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local player = Players.LocalPlayer
    local startedAt = os.clock()
    local theme = {
        Accent = Color3.fromRGB(255, 193, 7),
        Accent2 = Color3.fromRGB(255, 224, 115),
        Accent3 = Color3.fromRGB(184, 126, 0),
        Background = Color3.fromRGB(10, 10, 12),
        Surface = Color3.fromRGB(17, 17, 19),
        Surface2 = Color3.fromRGB(24, 24, 27),
        Element = Color3.fromRGB(30, 29, 28),
        Border = Color3.fromRGB(58, 59, 67),
    }
    local icons = {
        ["layout-dashboard"] = "dashboard", ["list-ordered"] = "list",
        swords = "combat", clock = "clock", sparkles = "star", backpack = "inventory",
        ["flask-conical"] = "flask", compass = "move", ["trash-2"] = "x",
        user = "player", settings = "settings",
    }
    local tabInfo = {
        Dashboard = { "Dashboard", "Live player and quest data" },
        ["Activity Order"] = { "Activity Order", "Automation priority" },
        Farming = { "Farming", "Combat and world progression" },
        ["Events & Raids"] = { "Events & Raids", "Dungeons, raids and portals" },
        ["Spins & Gacha"] = { "Spins & Gacha", "Summons and passive rolls" },
        ["Equip & Upgrade"] = { "Equipment", "Gear, upgrades and crafting" },
        ["Consumables & Shops"] = { "Shops", "Consumables and trial upgrades" },
        ["Harbor & Maps"] = { "Harbor & Travel", "Rewards and world navigation" },
        ["Auto Delete & Clean"] = { "Inventory Cleanup", "Rarity filters and inventory" },
        ["Player & Server"] = { "Player & Server", "Movement and session tools" },
        Configuration = { "Configuration", "Profiles and saved settings" },
    }
    local titles = {
        ["Auto Farm (TP to Enemy)"] = "Smart Enemy Farm",
        ["Auto Click (Spam Attack)"] = "Precision Auto Attack",
        ["Click Delay (s × 100)"] = "Attack Interval (× 0.01s)",
        ["Auto Target Enemy"] = "Smart Target Selection",
        ["Target Monster Filter (Multi-Select)"] = "Enemy Selection",
        ["Auto Farm Index (Missing Avatars)"] = "Missing Avatar Index Farm",
        ["Auto Go New Area"] = "New Area Progression",
        ["Auto Break Wall Gate"] = "Wall Gate Progression",
        ["Auto Time Trial Loop"] = "Time Trial Cycle",
        ["Auto Raid Loop"] = "Raid Cycle",
        ["Auto Join Portal by Tier"] = "Tier Based Portal Farm",
        ["Auto Marine Invasion"] = "Marine Invasion Cycle",
        ["Balanced System Unlocker (Round-Robin)"] = "Balanced System Unlocker",
        ["Priority Order Breakdown"] = "Activity Priority",
        ["TP to Target Enemy NOW"] = "Teleport to Locked Target",
        ["Cast Skill NOW"] = "Cast Equipped Skill",
        ["Break / Click Wall NOW"] = "Break Current Wall",
        ["Check & Claim Quests NOW"] = "Check and Claim Quests",
        ["Claim All Rewards NOW"] = "Claim Available Rewards",
        ["Redeem All Known Codes"] = "Redeem Available Codes",
        ["Redeem All Promo Codes"] = "Redeem Available Codes",
        ["Player Movement & Hacks"] = "Player Movement",
        ["Player Stats"] = "Live Player Stats",
        ["Current Quest"] = "Quest Progress",
        ["New Config Name"] = "New Profile Name",
        ["Auto Load Config on Startup"] = "Load Profile at Startup",
    }
    local descriptions = {
        ["Auto Farm (TP to Enemy)"] = "Keeps a target locked until defeat, then selects the next enemy.",
        ["Auto Click (Spam Attack)"] = "Attacks the current target at your selected interval.",
        ["Click Delay (s × 100)"] = "Set the attack interval: 5 means 0.05 seconds.",
        ["Auto Target Enemy"] = "Chooses an available enemy in the current or latest area.",
        ["Auto Farm Index (Missing Avatars)"] = "Farms enemies that drop avatars missing from your index.",
        ["Auto Go New Area"] = "Moves your farm to the newest unlocked area.",
        ["Auto Break Wall Gate"] = "Breaks the next wall to continue world progression.",
        ["Auto Quests (Accept & Complete)"] = "Accepts, progresses and claims quests while enabled.",
        ["Auto Time Trial Loop"] = "Queues available trials and clears stages until the exit condition.",
        ["Auto Raid Loop"] = "Runs raid rooms, collects rewards and repeats.",
        ["Auto Join Portal by Tier"] = "Enters portals that match your chosen tier.",
        ["Auto Marine Invasion"] = "Joins the invasion, clears enemies and exits when complete.",
        ["Balanced System Unlocker (Round-Robin)"] = "Rotates affordable unlocks across your progression systems.",
        ["Auto Return Home"] = "Returns immediately after a completed raid or trial.",
        ["Auto Claim All"] = "Claims available achievements, dailies, chests and passes.",
        ["Redeem All Promo Codes"] = "Attempts each saved promotional code once.",
        ["Redeem All Known Codes"] = "Attempts each saved promotional code once.",
    }

    local function titleFor(data)
        local original = tostring(data.Title or data.Name or "Feature")
        return titles[original] or original:gsub(" NOW$", ""):gsub("1%-Click", "Quick")
    end
    local function descFor(data)
        local original = tostring(data.Title or data.Name or "")
        local description = descriptions[original] or data.Desc or ""
        return description ~= "" and tostring(description) or nil
    end
    local function configValue(path)
        if type(path) ~= "string" then return nil end
        local value = CFG
        for key in path:gmatch("[^.]+") do
            if type(value) ~= "table" then return nil end
            value = value[key]
        end
        return value
    end
    local function copyText(value)
        local copier = setclipboard or toclipboard
        if type(copier) ~= "function" then return false end
        local ok, result = pcall(copier, tostring(value))
        return ok and result ~= false
    end
    local function executorName()
        local scopes = {}
        pcall(function()
            if type(getgenv) == "function" then table.insert(scopes, getgenv()) end
        end)
        table.insert(scopes, _G)
        for _, scope in ipairs(scopes) do
            if type(scope) == "table" then
                for _, key in ipairs({ "identifyexecutor", "getexecutorname", "identify_executor" }) do
                    if type(scope[key]) == "function" then
                        local ok, name, version = pcall(scope[key])
                        if ok and name and tostring(name) ~= "" then
                            return tostring(name) .. (version and tostring(version) ~= "" and (" " .. tostring(version)) or "")
                        end
                    end
                end
            end
        end
        return "Unknown executor"
    end
    local function elapsedText(seconds)
        local total = math.max(0, math.floor(seconds))
        return string.format("%02d:%02d:%02d", math.floor(total / 3600), math.floor(total / 60) % 60, total % 60)
    end

    local raw = AxelUI.CreateWindow({
        Name = "Axel Hub", Subtitle = "Made by Ud0", Footer = "Axel Hub · Anime Breaker",
        GuiName = "AxelHubAnimeBreaker", ToggleKeybind = "RightControl",
        Logo = "star", Size = UDim2.fromOffset(926, 616), Theme = theme,
        Glass = { Enabled = true, Transparency = 0.24, AnimatedBorder = true },
        TabAnimation = true, AnimateControls = true,
        ManualLoading = true, LoadingSubtitle = "Preparing Axel Hub",
    })
    raw.StatusDot.BackgroundTransparency = 0
    raw:SetStatus("Loading", raw.Theme.Warning)
    local ui = { Raw = raw, Controls = {}, ToggleEntries = {}, Closed = false }

    local home = raw:AddTab({ Name = "Home", Subtitle = "Overview", Icon = "home" })
    home:AddHero({
        Image = "rbxassetid://86949082023913", ScaleType = Enum.ScaleType.Fit,
        WelcomeLabel = "Welcome back,", WelcomeTitle = player and player.DisplayName or "Player",
        WelcomeContent = "Axel Hub · Anime Breaker", BannerTitle = "Join Axel Hub on Discord",
        Content = "Copy the invite to join the Axel Hub community.",
        Button = "Copy Discord", Height = 104,
        Callback = function()
            local invite = "https://discord.gg/axelhub"
            if copyText(invite) then
                raw:Notify("Discord", "Invite copied to clipboard.", "Success")
            else
                raw:Notify("Discord invite", invite, "Info")
            end
        end,
    })
    home:AddPill({ Name = "Overview", TargetTab = home, Active = true })
    local profile = home:AddSection({ Name = "Player Profile", Side = "Left", Pill = "Overview" })
    local profileCard = profile:AddProfileCard({
        DisplayName = player and player.DisplayName or "Player",
        Username = player and player.Name or "player",
        UserId = player and player.UserId,
        AccountAge = player and player.AccountAge,
    })
    if player and player.UserId > 0 then
        task.spawn(function()
            local ok, thumbnail = pcall(function()
                return Players:GetUserThumbnailAsync(player.UserId,
                    Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
            end)
            if ok and type(thumbnail) == "string" and thumbnail ~= "" and not raw._destroyed then
                profileCard:Set({ DisplayName = player.DisplayName, Username = player.Name,
                    UserId = player.UserId, AccountAge = player.AccountAge, AvatarImage = thumbnail })
            end
        end)
    end

    local metrics = home:AddSection({ Name = "Real-Time System Metrics",
        Description = "Performance and players in this server.", Side = "Left", Pill = "Overview" }):AddMetricGrid({ Items = {
        { Key = "FPS", Name = "FPS", Icon = "activity", Value = "--", Color = raw.Theme.Accent2 },
        { Key = "Ping", Name = "Ping", Icon = "wifi", Value = "-- ms", Color = raw.Theme.Accent2 },
        { Key = "Uptime", Name = "Uptime", Icon = "clock", Value = "00:00:00", Color = raw.Theme.Accent2 },
        { Key = "Users", Name = "Users", Icon = "users", Value = "--", Color = raw.Theme.Accent2 },
    } })
    local place = home:AddSection({ Name = "Place & Server ID",
        Description = "Current game and server identifiers.", Side = "Right", Pill = "Overview" })
    local gameName = tostring(game.Name or "Roblox")
    local gameStatus = place:AddStatus({ Name = "Game", Description = gameName, Icon = "gamepad",
        Text = gameName, ValueInDescription = true, Color = raw.Theme.Accent2,
        ValueDescriptionColor = raw.Theme.Accent2 })
    place:AddStatus({ Name = "Place ID", Description = tostring(game.PlaceId), Icon = "map",
        Text = tostring(game.PlaceId), ValueInDescription = true, Color = raw.Theme.Accent2 })
    local jobId = tostring(game.JobId or "")
    place:AddStatus({ Name = "Server Job ID", Description = jobId ~= "" and jobId or "Unavailable",
        Icon = "server", Text = jobId, ValueInDescription = true,
        Copyable = true, CopyValue = jobId, CopyLabel = "Server Job ID", Color = raw.Theme.SubText })
    task.spawn(function()
        local ok, details = pcall(function()
            return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
        end)
        if ok and type(details) == "table" and type(details.Name) == "string" and not raw._destroyed then
            gameStatus:Set(details.Name, raw.Theme.Accent2, nil, details.Name)
        end
    end)

    local features = home:AddSection({ Name = "Feature Status",
        Description = "Live Anime Breaker automation.", Side = "Right", Pill = "Overview" })
    local featureRows = {}
    for _, item in ipairs({
        { "Enemy Farm", "AutoFarm", "target" }, { "Auto Attack", "AutoClick", "combat" },
        { "Quests", "AutoQuests", "list" }, { "Time Trial", "AutoTimeTrialDungeon", "clock" },
        { "Raid", "AutoRaid", "shield" }, { "Portal", "AutoPortal", "star" },
        { "Auto Equip", "AutoEquipBest", "inventory" }, { "Rewards", "AutoClaimAll", "gift" },
    }) do
        featureRows[item[2]] = features:AddStatus({ Name = item[1], Icon = item[3],
            Text = "Disabled", Color = raw.Theme.Muted })
    end
    local activeFeatures = features:AddStatus({ Name = "Functions Active", Icon = "grid",
        Text = "0 / 0", Color = raw.Theme.Accent2 })

    local progress = home:AddSection({ Name = "Game Progress",
        Description = "Current map and account resources.", Side = "Left", Pill = "Overview" })
    local mapStatus = progress:AddStatus({ Name = "Current Map", Icon = "map",
        Text = "--", Color = raw.Theme.Accent2 })
    local highestStatus = progress:AddStatus({ Name = "Highest Map", Icon = "move",
        Text = "--", Color = raw.Theme.Accent2 })
    local goldStatus = progress:AddStatus({ Name = "Gold", Icon = "coin",
        Text = "--", Color = raw.Theme.Accent2 })
    local energyStatus = progress:AddStatus({ Name = "Energy", Icon = "bolt",
        Text = "--", Color = raw.Theme.Accent2 })
    local targetStatus = progress:AddStatus({ Name = "Locked Target", Icon = "target",
        Text = "Searching", Color = raw.Theme.Accent2 })
    local executorStatus = home:AddSection({ Name = "Roblox Executor",
        Description = "Executor active in this session.", Side = "Left", Pill = "Overview" }):AddStatus({
        Name = "Executor", Description = executorName(), Icon = "terminal",
        Text = executorName(), ValueInDescription = true,
        Color = raw.Theme.Accent2, ValueDescriptionColor = raw.Theme.Accent2 })
    local management = home:AddSection({ Name = "Server Management",
        Description = "Copy the current server ID.", Side = "Right", Pill = "Overview" })
    management:AddButton({ Name = "Copy Job ID to Clipboard", Icon = "copy", Callback = function()
        local id = tostring(game.JobId or "")
        raw:Notify("Server ID", id ~= "" and copyText(id) and "Job ID copied to clipboard."
            or "Job ID unavailable to copy.", id ~= "" and "Info" or "Error")
    end })
    local guiControls = home:AddSection({ Name = "GUI Controls",
        Description = "Hide or close the interface.", Side = "Left", Pill = "Overview" })
    guiControls:AddButton({ Name = "Hide Axel Hub", Icon = "eye", Callback = function() raw:SetOpen(false) end })
    guiControls:AddButton({ Name = "Close Axel Hub", Icon = "power", Callback = function() raw:ConfirmUnload() end })

    local originalUnload = raw.Unload
    raw.Unload = function(self)
        if ui.Closed then return end
        ui.Closed = true
        if ui.OverviewConnection then ui.OverviewConnection:Disconnect() end
        if type(cleanup) == "function" then pcall(cleanup) end
        originalUnload(self)
    end

    local tabMethods = {}
    function ui:Tab(data)
        local info = tabInfo[data.Title] or { data.Title, "Premium features" }
        local tab = raw:AddTab({ Name = info[1], Subtitle = info[2], Icon = icons[data.Icon] or data.Icon or "star" })
        home:AddPill({ Name = info[1], TargetTab = tab })
        return setmetatable({ Raw = tab, UI = self, Current = nil, NextSide = "Left" }, { __index = tabMethods })
    end
    function tabMethods:Section(data)
        local name = titleFor(data)
        self.Current = self.Raw:AddSection({ Name = name, Side = self.NextSide })
        self.NextSide = self.NextSide == "Left" and "Right" or "Left"
        return self.Current
    end
    function tabMethods:CurrentSection()
        if not self.Current then self:Section({ Title = "Premium Features" }) end
        return self.Current
    end
    function tabMethods:Paragraph(data)
        local handle = self:CurrentSection():AddParagraph({ Title = titleFor(data), Content = data.Desc or "" })
        function handle:SetDesc(value) self:Set(value) end
        return handle
    end
    function tabMethods:Button(data)
        return self:CurrentSection():AddButton({ Name = titleFor(data), Description = descFor(data),
            Icon = "check", Callback = data.Callback })
    end
    function tabMethods:Toggle(data)
        local handle = self:CurrentSection():AddToggle({ Name = titleFor(data),
            Description = descFor(data), Default = data.Value == true,
            Callback = data.Callback })
        table.insert(self.UI.ToggleEntries, { Handle = handle, ConfigKey = data.ConfigKey })
        table.insert(self.UI.Controls, { Handle = handle, ConfigKey = data.ConfigKey })
        return handle
    end
    function tabMethods:Slider(data)
        local range = data.Value or {}
        local handle = self:CurrentSection():AddSlider({ Name = titleFor(data),
            Description = descFor(data), Min = range.Min, Max = range.Max,
            Default = range.Default, Step = data.Step, Callback = data.Callback })
        table.insert(self.UI.Controls, { Handle = handle, ConfigKey = data.ConfigKey,
            Transform = data.Title == "Click Delay (s × 100)" and 100 or nil })
        return handle
    end
    function tabMethods:Dropdown(data)
        local params = { Name = titleFor(data), Description = descFor(data),
            Options = data.Values, Default = data.Value, Callback = data.Callback }
        local section = self:CurrentSection()
        local handle = data.Multi and section:AddMultiDropdown(params) or section:AddDropdown(params)
        function handle:Refresh(values) self:SetOptions(values) end
        table.insert(self.UI.Controls, { Handle = handle, ConfigKey = data.ConfigKey })
        return handle
    end
    function tabMethods:Input(data)
        return self:CurrentSection():AddInput({ Name = titleFor(data),
            Description = descFor(data), Default = data.Default, Placeholder = data.Placeholder,
            Callback = data.Callback })
    end
    function ui:SyncConfig()
        for _, entry in ipairs(self.Controls) do
            local value = configValue(entry.ConfigKey)
            if value ~= nil then
                if entry.Transform then value *= entry.Transform end
                entry.Handle:Set(value, true)
            end
        end
    end
    function ui:FinishLoading()
        if self.Ready or raw._destroyed then return end
        self.Ready = true
        self:SyncConfig()
        raw:SelectTab(home)
        if home.Pills and home.Pills[1] then home:SelectPill(home.Pills[1], true) end
        if home.PillBar then home.PillBar.CanvasPosition = Vector2.new(0, 0) end
        raw:_applyResponsive()
        task.defer(function()
            RunService.RenderStepped:Wait()
            if raw._destroyed then return end
            raw:SetStatus("Online", raw.Theme.Success)
            raw:FinishLoading()
        end)
    end

    local elapsed = 0
    ui.OverviewConnection = RunService.Heartbeat:Connect(function(delta)
        if raw._destroyed then return end
        elapsed += delta
        if elapsed < 0.75 or raw.ActiveTab ~= home then return end
        elapsed = 0
        local playerCount = #Players:GetPlayers()
        local maxPlayers = Players.MaxPlayers
        metrics:Set("FPS", tostring(raw.FpsValue and raw.FpsValue.Text or "--") .. " FPS", raw.Theme.Accent2)
        local ping = "-- ms"
        if player then
            local ok, seconds = pcall(function() return player:GetNetworkPing() end)
            if ok and type(seconds) == "number" then
                ping = tostring(math.max(0, math.floor(seconds * 1000 + 0.5))) .. " ms"
            end
        end
        metrics:Set("Ping", ping, raw.Theme.Accent2)
        metrics:Set("Uptime", elapsedText(os.clock() - startedAt), raw.Theme.Accent2)
        metrics:Set("Users", tostring(playerCount) .. (maxPlayers > 0 and ("/" .. tostring(maxPlayers)) or ""), raw.Theme.Accent2)
        local detected = executorName()
        executorStatus:Set(detected, raw.Theme.Accent2, nil, detected)
        local active = 0
        for _, entry in ipairs(ui.ToggleEntries) do
            local value = configValue(entry.ConfigKey)
            if value == nil then value = entry.Handle:Get() end
            if value == true then active += 1 end
        end
        activeFeatures:Set(tostring(active) .. " / " .. tostring(#ui.ToggleEntries), raw.Theme.Accent2)
        for key, row in pairs(featureRows) do
            local enabled = CFG[key] == true
            row:Set(enabled and "Enabled" or "Disabled", enabled and raw.Theme.Success or raw.Theme.Muted)
        end
        local library = getLibrary()
        local pd = library and library.PlayerData
        local items = pd and pd.Items or {}
        mapStatus:Set(tostring(getMap()), raw.Theme.Accent2)
        highestStatus:Set(tostring(getHighestMap()), raw.Theme.Accent2)
        goldStatus:Set(tostring(pd and pd.Gold or items.Gold or 0), raw.Theme.Accent2)
        energyStatus:Set(tostring(pd and pd.Energy or items.Energy or 0), raw.Theme.Accent2)
        targetStatus:Set(tostring(getTarget() or "Searching"), raw.Theme.Accent2)
    end)
    return ui
end

local Window = createAxelAnimeBreakerUI(
    AxelUI, CFG, function() return Library end, getCurrentMap, getHighestUnlockedMap,
    function() return currentLockedTargetUID end,
    function()
        if _G.AnimeBreaker_HeartbeatConnection then
            _G.AnimeBreaker_HeartbeatConnection:Disconnect()
            _G.AnimeBreaker_HeartbeatConnection = nil
        end
        disableNoClip()
        for _, key in ipairs({ "AnimeBreaker_AntiAFKConnection", "AnimeBreaker_RejoinConnection" }) do
            if _G[key] then _G[key]:Disconnect(); _G[key] = nil end
        end
    end
)
AxelHubUI = Window

if lp then
    _G.AnimeBreaker_AntiAFKConnection = lp.Idled:Connect(function()
        if not CFG.AntiAFK then return end
        pcall(function()
            local virtualUser = game:GetService("VirtualUser")
            virtualUser:CaptureController()
            virtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end)
    local coreGui = game:GetService("CoreGui")
    _G.AnimeBreaker_RejoinConnection = coreGui.DescendantAdded:Connect(function(item)
        if not CFG.AutoRejoin or item.Name ~= "ErrorPrompt" then return end
        task.delay(3, function()
            if CFG.AutoRejoin and item.Parent then doRejoinCurrent() end
        end)
    end)
end

local TabDash = Window:Tab({ Title = "Dashboard", Icon = "layout-dashboard" })
do
    TabDash:Section({ Title = "Live Player Tracker" })
    local statPara = TabDash:Paragraph({
        Title = "Player Stats",
        Desc = "Loading player metrics..."
    })

    task.spawn(function()
        while task.wait(0.5) do
            local pd = Library and Library.PlayerData
            local items = pd and pd.Items or {}
            local gold = pd and pd.Gold or items["Gold"] or 0
            local energy = pd and pd.Energy or items["Energy"] or 0
            local curMap = getCurrentMap()
            local rank = (pd and pd.Rebirth and pd.Rebirth.Rank_Energy) or (pd and pd.Rank) or 1
            statPara:SetDesc(string.format(
                "Player: %s  |  Map: %s\nGold: %s  |  Energy: %s  |  Rank: %s\nHighest Map: %s  |  Locked Target: %s",
                lp.Name, curMap, tostring(gold), tostring(energy), tostring(rank),
                getHighestUnlockedMap(),
                tostring(currentLockedTargetUID or "None (Searching...)")
            ))
        end
    end)

    TabDash:Section({ Title = "Active Quest Status" })
    local qPara = TabDash:Paragraph({
        Title = "Current Quest",
        Desc = "Tracking quests..."
    })

    task.spawn(function()
        while task.wait(1.0) do
            local pd = Library and Library.PlayerData
            if pd then
                local active = pd.ActiveQuest
                local quests = pd.Quests or {}
                local text = nil
                if active and active.Id and active.Type then
                    local cat = quests[active.Type]
                    local qData = cat and cat[active.Id]
                    if qData and qData.Objectives then
                        local parts = {}
                        for _, obj in ipairs(qData.Objectives) do
                            local oType = tostring(obj.Type or "")
                            local goal = tonumber(obj.Goal) or 1
                            local prog = tonumber(obj.Progress) or 0
                            table.insert(parts, string.format("%s: %d/%d (%d%%)", oType, prog, goal, math.floor(prog / goal * 100)))
                        end
                        text = string.format("[%s] %s\n%s", active.Type, active.Id, table.concat(parts, " | "))
                    else
                        text = string.format("[%s] %s [In Progress]", active.Type, active.Id)
                    end
                end
                if not text then
                    for catName, catList in pairs(quests) do
                        if type(catList) == "table" then
                            for qId, qData in pairs(catList) do
                                if type(qData) == "table" and qData.Objectives then
                                    for _, obj in ipairs(qData.Objectives) do
                                        local goal = tonumber(obj.Goal) or 1
                                        local prog = tonumber(obj.Progress) or 0
                                        if prog < goal then
                                            text = string.format("[%s] %s\n%s: %d/%d (%d%%)", catName, qId, tostring(obj.Type or ""), prog, goal, math.floor(prog / goal * 100))
                                            break
                                        end
                                    end
                                end
                                if text then break end
                            end
                        end
                        if text then break end
                    end
                end
                qPara:SetDesc(text or "All current quests completed!")
            else
                qPara:SetDesc("Tracking quests...")
            end
        end
    end)

    TabDash:Button({
        Title = "Check & Claim Quests NOW",
        Desc = "Immediately checks quest progress and claims completed rewards",
        Callback = doAutoQuests
    })

    TabDash:Section({ Title = "Quick Combat Actions" })
    TabDash:Button({
        Title = "TP to Target Enemy NOW",
        Desc = "Teleports directly in front of the active locked monster",
        Callback = function()
            local uid, part = selectTargetEnemy()
            teleportToTarget(part, uid)
        end
    })
    TabDash:Button({
        Title = "Cast Skill NOW",
        Desc = "Manually triggers ability skill execution",
        Callback = function()
            local skillTgt = currentLockedTargetUID and { currentLockedTargetUID } or Library.Target
            Library.Remote:Fire("ClickSystem", "CastSkill", skillTgt)
        end
    })
    TabDash:Button({
        Title = "Break / Click Wall NOW",
        Desc = "Teleports to current world wall and fires wall click",
        Callback = doAutoBreakWall
    })
    TabDash:Button({
        Title = "Claim All Rewards NOW",
        Desc = "Claims Achievements, Dailies, Battlepass, Likes and Chests",
        Callback = doClaimAll
    })
    TabDash:Button({
        Title = "Redeem All Known Codes",
        Desc = "Redeems all active promo codes for free boosts",
        Callback = doRedeemAllCodes
    })
end

-- ══════════════════════════════════════════════════════════
-- TAB 2: 🔀 ACTIVITY ORDER (PRIORITY HIERARCHY)
-- ══════════════════════════════════════════════════════════
local TabOrder = Window:Tab({ Title = "Activity Order", Icon = "list-ordered" })
do
    TabOrder:Section({ Title = "Execution Priority Hierarchy" })
    TabOrder:Paragraph({
        Title = "Priority Order Breakdown",
        Desc = "1. Time Trial Dungeon: Clears hallway dungeon until target stage or completion\n2. Auto Raid: Safe entry, ticket farm, room clearance, custom room exit\n3. Auto Portal: Uses S > A > B > C rank portals and auto farms dungeon\n4. Normal Farm / Wall / Quests: Standard continuous progression"
    })

    TabOrder:Section({ Title = "Balanced System Unlocker" })
    TabOrder:Toggle({
        Title = "Balanced System Unlocker (Round-Robin)",
        Desc = "Rotates unlocking Race, Warrior, Weapon, Hero Passive without exhausting money",
        ConfigKey = "BalancedUnlocker",
        Value = CFG.BalancedUnlocker,
        Callback = function(v) CFG.BalancedUnlocker = v end
    })
    TabOrder:Button({
        Title = "Unlock All Available Systems NOW",
        Desc = "Immediately checks affordable system unlocks and executes them",
        Callback = handleAutoUnlockSystems
    })
end

-- ══════════════════════════════════════════════════════════
-- TAB 3: ⚔️ FARMING (STICKY TARGET LOCKING + INTERACTIVE SLIDERS)
-- ══════════════════════════════════════════════════════════
local TabFarm = Window:Tab({ Title = "Farming", Icon = "swords" })
do
    TabFarm:Section({ Title = "Combat Controls" })
    TabFarm:Toggle({
        Title = "Auto Farm (TP to Enemy)",
        Desc = "Locks onto target enemy until DEAD, then smoothly moves to next",
        ConfigKey = "AutoFarm",
        Value = CFG.AutoFarm,
        Callback = function(v)
            CFG.AutoFarm = v
            if not v then currentLockedTargetUID = nil end
        end
    })
    TabFarm:Toggle({
        Title = "Auto Click (Spam Attack)",
        Desc = "Fires click attack executions continuously",
        ConfigKey = "AutoClick",
        Value = CFG.AutoClick,
        Callback = function(v) CFG.AutoClick = v end
    })
    TabFarm:Slider({
        Title = "Click Delay (s × 100)",
        Desc = "Adjust click speed (1 = 0.01s, 5 = 0.05s, 20 = 0.20s)",
        Step = 1,
        ConfigKey = "ClickDelay",
        Value = { Min = 1, Max = 50, Default = math.floor(CFG.ClickDelay * 100) },
        Callback = function(v) CFG.ClickDelay = v / 100 end
    })
    TabFarm:Toggle({
        Title = "Auto Target Enemy",
        Desc = "Locks onto best available target in current or newest zone",
        ConfigKey = "AutoTarget",
        Value = CFG.AutoTarget,
        Callback = function(v) CFG.AutoTarget = v end
    })
    TabFarm:Toggle({
        Title = "Auto Cast Skill",
        Desc = "Automatically casts equipped hero skills on cooldown",
        ConfigKey = "AutoCastSkill",
        Value = CFG.AutoCastSkill,
        Callback = function(v) CFG.AutoCastSkill = v end
    })
    TabFarm:Dropdown({
        Title = "Target Monster Filter (Multi-Select)",
        Desc = "Select one or multiple monsters to farm",
        Multi = true,
        Values = ALL_ENEMY_OPTIONS,
        ConfigKey = "TargetMonsterFilterMulti",
        Value = CFG.TargetMonsterFilterMulti or {"All"},
        Callback = function(v)
            CFG.TargetMonsterFilterMulti = v
            currentLockedTargetUID = nil
        end
    })

    TabFarm:Section({ Title = "Auto Farm Index (Missing Avatars)" })
    TabFarm:Toggle({
        Title = "Auto Farm Index (Missing Avatars)",
        Desc = "Warps to chosen map and targets monsters dropping Avatars still missing in Index",
        ConfigKey = "AutoIndexFarm",
        Value = CFG.AutoIndexFarm,
        Callback = function(v)
            CFG.AutoIndexFarm = v
            currentLockedTargetUID = nil
            if v then
                CFG.AutoFarm = true
                CFG.AutoClick = true
                local targetMap = CFG.IndexFarmWorld or "Current Map"
                if targetMap ~= "Current Map" and getCurrentMap() ~= targetMap then
                    pcall(function()
                        Library.Remote:Fire("TeleportSystem", "To", targetMap)
                    end)
                end
            end
        end
    })
    TabFarm:Dropdown({
        Title = "Index Map Selection",
        Desc = "Select world to warp & farm missing avatar index",
        Values = {"Current Map", "DBZ", "AOT", "Naruto", "Nanatsu", "SoloLeveling", "OnePiece"},
        ConfigKey = "IndexFarmWorld",
        Value = CFG.IndexFarmWorld or "Current Map",
        Callback = function(v)
            CFG.IndexFarmWorld = v
            currentLockedTargetUID = nil
            if CFG.AutoIndexFarm and v ~= "Current Map" and getCurrentMap() ~= v then
                pcall(function()
                    Library.Remote:Fire("TeleportSystem", "To", v)
                end)
            end
        end
    })

    TabFarm:Section({ Title = "Zone Progression & Wall Breaking" })
    TabFarm:Toggle({
        Title = "Auto Go New Area",
        Desc = "ON: Farm new unlocked area from lowest HP. OFF: Farm highest HP monster of old zone!",
        ConfigKey = "AutoGoNewArea",
        Value = CFG.AutoGoNewArea,
        Callback = function(v)
            CFG.AutoGoNewArea = v
            currentLockedTargetUID = nil
        end
    })
    TabFarm:Toggle({
        Title = "Auto Break Wall Gate",
        Desc = "Warp to latest area, break wall, and warp into newly unlocked area immediately!",
        ConfigKey = "AutoBreakWall",
        Value = CFG.AutoBreakWall,
        Callback = function(v)
            CFG.AutoBreakWall = v
            if v then
                local highest = getHighestUnlockedMap()
                if highest and highest ~= "Lobby" and highest ~= getCurrentMap() then
                    pcall(function()
                        Library.Remote:Fire("TeleportSystem", "To", highest)
                    end)
                end
            end
        end
    })
    TabFarm:Dropdown({
        Title = "Wall Break Mode",
        Desc = "Timed (switches between wall and mob farming) or Continuous",
        Values = {"Timed", "Continuous"},
        ConfigKey = "WallBreakMode",
        Value = CFG.WallBreakMode,
        Callback = function(v) CFG.WallBreakMode = v end
    })
    TabFarm:Slider({
        Title = "Wall Attack Duration (s)",
        Desc = "Seconds spent attacking wall before retreating to farm",
        Step = 5,
        ConfigKey = "WallAttackDuration",
        Value = { Min = 5, Max = 180, Default = CFG.WallAttackDuration },
        Callback = function(v) CFG.WallAttackDuration = v end
    })
    TabFarm:Slider({
        Title = "Farm Cooldown (s)",
        Desc = "Seconds spent farming monsters before retrying wall",
        Step = 10,
        ConfigKey = "WallFarmCooldown",
        Value = { Min = 10, Max = 600, Default = CFG.WallFarmCooldown },
        Callback = function(v) CFG.WallFarmCooldown = v end
    })

    TabFarm:Section({ Title = "Auto Quests" })
    TabFarm:Toggle({
        Title = "Auto Quests (Accept & Complete)",
        Desc = "STRICT: If OFF, will NEVER accept quests, do objectives, or spin cards!",
        ConfigKey = "AutoQuests",
        Value = CFG.AutoQuests,
        Callback = function(v) CFG.AutoQuests = v end
    })
end

-- ══════════════════════════════════════════════════════════
-- TAB 4: ⏱️ EVENTS & RAIDS
-- ══════════════════════════════════════════════════════════
local TabEvents = Window:Tab({ Title = "Events & Raids", Icon = "clock" })
do
    TabEvents:Section({ Title = "Time Trial Dungeon Automation" })
    TabEvents:Toggle({
        Title = "Auto Time Trial Loop",
        Desc = "Automatically joins open difficulties, sweeps mobs, and loops progression",
        ConfigKey = "AutoTimeTrialDungeon",
        Value = CFG.AutoTimeTrialDungeon,
        Callback = function(v)
            CFG.AutoTimeTrialDungeon = v
            if not v then
                currentLockedTargetUID = nil
            end
        end
    })
    TabEvents:Dropdown({
        Title = "Difficulty Selection (Multi)",
        Desc = "Choose difficulty tiers to automatically queue into",
        Multi = true,
        Values = {"Easy", "Normal", "Hard"},
        ConfigKey = "TTDifficulties",
        Value = CFG.TTDifficulties or (type(CFG.TTDifficulty) == "table" and CFG.TTDifficulty) or { "Easy" },
        Callback = function(v)
            CFG.TTDifficulties = v
            CFG.TTDifficulty = v
        end
    })
    TabEvents:Toggle({
        Title = "Target Stage Exit",
        Desc = "Automatically leaves time trial upon reaching specified stage",
        ConfigKey = "TTCustomExitStage",
        Value = CFG.TTCustomExitStage,
        Callback = function(v) CFG.TTCustomExitStage = v end
    })
    TabEvents:Slider({
        Title = "Target Exit Stage (1-50)",
        Desc = "Stage number to trigger early dungeon exit",
        Step = 1,
        ConfigKey = "TTExitStage",
        Value = { Min = 1, Max = 50, Default = CFG.TTExitStage },
        Callback = function(v) CFG.TTExitStage = v end
    })
    TabEvents:Button({
        Title = "Join Time Trial Instantly",
        Desc = "Immediately teleports and launches highest ready difficulty tier",
        Callback = function()
            local openDiff = getAvailableTimeTrialDiff() or (getSelectedTTDifficulties()[1]) or "Easy"
            doJoinTimeTrial(openDiff)
            CFG.AutoTimeTrialDungeon = true
            CFG.AutoFarm = true
            CFG.AutoClick = true
        end
    })
    TabEvents:Button({
        Title = "Leave Time Trial",
        Desc = "Safely exits current active Time Trial session",
        Callback = function()
            Library.Remote:Fire("GamemodeSystem", "Quit", true)
        end
    })

    TabEvents:Section({ Title = "Infinite Raid Automation" })
    TabEvents:Toggle({
        Title = "Auto Raid Loop",
        Desc = "Automatically enters raid, sweeps rooms, auto-collects rewards, and loops",
        ConfigKey = "AutoRaid",
        Value = CFG.AutoRaid,
        Callback = function(v)
            CFG.AutoRaid = v
            if v then
                local targetMap = CFG.RaidTargetMap or "DBZ"
                if getCurrentMap() ~= targetMap then
                    pcall(function()
                        Library.Remote:Fire("TeleportSystem", "To", targetMap)
                    end)
                end
            else
                currentLockedTargetUID = nil
            end
        end
    })
    TabEvents:Dropdown({
        Title = "Raid Dimension / World",
        Desc = "Target world map for raid dungeon battles",
        Values = {"DBZ", "AOT", "Naruto", "Nanatsu", "SoloLeveling", "OnePiece"},
        ConfigKey = "RaidTargetMap",
        Value = CFG.RaidTargetMap,
        Callback = function(v)
            CFG.RaidTargetMap = v
            if CFG.AutoRaid and getCurrentMap() ~= v then
                currentLockedTargetUID = nil
                pcall(function()
                    Library.Remote:Fire("TeleportSystem", "To", v)
                end)
            end
        end
    })
    TabEvents:Toggle({
        Title = "Auto Farm Raid Tickets",
        Desc = "Warps to target world and farms ticket-dropping sub-bosses when out of tickets",
        ConfigKey = "AutoFarmTicketIfNone",
        Value = CFG.AutoFarmTicketIfNone,
        Callback = function(v)
            CFG.AutoFarmTicketIfNone = v
            if not v then
                currentLockedTargetUID = nil
                local root = getRoot()
                if root then
                    local bv = root:FindFirstChild("CombatVelocity")
                    if bv then bv:Destroy() end
                end
            else
                local targetMap = CFG.RaidTargetMap or "DBZ"
                if getCurrentMap() ~= targetMap then
                    pcall(function()
                        Library.Remote:Fire("TeleportSystem", "To", targetMap)
                    end)
                end
            end
        end
    })
    TabEvents:Toggle({
        Title = "Instant Return (Skip Results)",
        Desc = "Instantly clicks Return on Results screen to skip the 10-second countdown",
        ConfigKey = "AutoReturnHome",
        Value = CFG.AutoReturnHome,
        Callback = function(v) CFG.AutoReturnHome = v end
    })
    TabEvents:Toggle({
        Title = "Custom Stage Exit",
        Desc = "Leaves raid early once reaching target room stage",
        ConfigKey = "RaidCustomExitRoom",
        Value = CFG.RaidCustomExitRoom,
        Callback = function(v) CFG.RaidCustomExitRoom = v end
    })
    TabEvents:Slider({
        Title = "Target Exit Room (1-30)",
        Desc = "Room stage number to exit raid back to world",
        Step = 1,
        ConfigKey = "RaidExitRoom",
        Value = { Min = 1, Max = 30, Default = CFG.RaidExitRoom },
        Callback = function(v) CFG.RaidExitRoom = v end
    })
    TabEvents:Button({
        Title = "Launch Raid Instantly",
        Desc = "Creates and launches target raid session immediately",
        Callback = function()
            CFG.AutoRaid = true
            CFG.AutoFarm = true
            CFG.AutoClick = true
            local mapName = CFG.RaidTargetMap or "DBZ"
            pcall(function()
                Library.Remote:Fire("GamemodeSystem", "Create", "Raid", mapName, "Easy", true)
                task.wait(0.5)
                Library.Remote:Fire("GamemodeSystem", "Start", "Raid")
            end)
        end
    })
    TabEvents:Button({
        Title = "Leave Raid Dungeon",
        Desc = "Safely exits current active raid session",
        Callback = function()
            Library.Remote:Fire("GamemodeSystem", "Quit", true)
        end
    })

    TabEvents:Section({ Title = "Auto Portal Dungeons" })
    TabEvents:Toggle({
        Title = "Auto Join Portal by Tier",
        Desc = "Uses portal items and enters portal dungeons based on tier",
        ConfigKey = "AutoPortal",
        Value = CFG.AutoPortal,
        Callback = function(v) CFG.AutoPortal = v end
    })
    TabEvents:Dropdown({
        Title = "Portal Tier Selection",
        Desc = "Select tier or 'All'",
        Values = {"All", "Rank C", "Rank B", "Rank A", "Rank S"},
        ConfigKey = "PortalSelectedTier",
        Value = CFG.PortalSelectedTier,
        Callback = function(v) CFG.PortalSelectedTier = v end
    })
    TabEvents:Section({ Title = "Auto Marine Invasion (1-Click Loop)" })
    TabEvents:Toggle({
        Title = "Auto Marine Invasion",
        Desc = "Auto checks window, enters Marine Invasion, clears mobs, auto leaves",
        ConfigKey = "AutoMarineInvasion",
        Value = CFG.AutoMarineInvasion,
        Callback = function(v) CFG.AutoMarineInvasion = v end
    })
    TabEvents:Dropdown({
        Title = "Invasion Difficulty",
        Desc = "Select difficulty tier",
        Values = {"Easy", "Medium", "Hard", "Nightmare"},
        ConfigKey = "InvasionDifficulty",
        Value = CFG.InvasionDifficulty or "Easy",
        Callback = function(v) CFG.InvasionDifficulty = v end
    })
    TabEvents:Toggle({
        Title = "Invasion Auto Leave",
        Desc = "Automatically leaves invasion after completion / rewards",
        ConfigKey = "InvasionAutoLeave",
        Value = CFG.InvasionAutoLeave,
        Callback = function(v) CFG.InvasionAutoLeave = v end
    })
    TabEvents:Button({
        Title = "Enter Marine Invasion NOW",
        Desc = "Enters Marine Invasion event immediately",
        Callback = function()
            Library.Remote:Fire("GamemodeSystem", "Enter", "Invasion", "Marine Invasion", CFG.InvasionDifficulty or "Easy", true)
        end
    })
end

-- ══════════════════════════════════════════════════════════
-- TAB 5: 🎲 SPINS & GACHA
-- ══════════════════════════════════════════════════════════
local TabSpins = Window:Tab({ Title = "Spins & Gacha", Icon = "sparkles" })
do
    TabSpins:Section({ Title = "Card / Egg Summon" })
    TabSpins:Toggle({
        Title = "Auto Summon Enabled",
        Desc = "Continuously spins eggs or cards",
        ConfigKey = "AutoSummon",
        Value = CFG.AutoSummon,
        Callback = function(v) CFG.AutoSummon = v end
    })
    TabSpins:Dropdown({
        Title = "Summon World",
        Desc = "Select banner world",
        Values = {"DBZ", "AOT", "Naruto", "Nanatsu", "SoloLeveling", "OnePiece"},
        ConfigKey = "SummonEgg",
        Value = CFG.SummonEgg,
        Callback = function(v) CFG.SummonEgg = v end
    })
    TabSpins:Dropdown({
        Title = "Summon Type",
        Desc = "Pet, Race or Eye Technique",
        Values = {"Pet", "Race", "Eye Technique"},
        ConfigKey = "SummonType",
        Value = CFG.SummonType,
        Callback = function(v) CFG.SummonType = v end
    })
    TabSpins:Button({
        Title = "Summon 1x Fast",
        Desc = "Spins selected banner 1 time",
        Callback = doAutoSummon
    })
    TabSpins:Button({
        Title = "Summon 10x Fast",
        Desc = "Spins selected banner 10 times in rapid succession",
        Callback = function()
            for i = 1, 10 do
                doAutoSummon()
                task.wait(0.1)
            end
        end
    })

    TabSpins:Section({ Title = "Race Spin (Stop by Rarity)" })
    TabSpins:Toggle({
        Title = "Auto Race Spin",
        Desc = "Rerolls player race with RaceCoins until target rarity reached",
        ConfigKey = "AutoRaceSpin",
        Value = CFG.AutoRaceSpin,
        Callback = function(v) CFG.AutoRaceSpin = v end
    })
    TabSpins:Toggle({
        Title = "Auto Unlock Race First (10k Gold)",
        Desc = "Unlocks Race Gacha in DBZ before rolling",
        ConfigKey = "AutoUnlockRace",
        Value = CFG.AutoUnlockRace,
        Callback = function(v) CFG.AutoUnlockRace = v end
    })
    TabSpins:Dropdown({
        Title = "Race Stop Rarity",
        Desc = "Stops spinning when race meets or exceeds rarity",
        Values = ALL_RARITY_NAMES,
        ConfigKey = "RaceStopRarity",
        Value = CFG.RaceStopRarity,
        Callback = function(v) CFG.RaceStopRarity = v end
    })

    TabSpins:Section({ Title = "Titan Banner" })
    TabSpins:Toggle({
        Title = "Auto Titan Spin",
        Desc = "Continuously spins Titan banner via remote",
        ConfigKey = "AutoTitanSpin",
        Value = CFG.AutoTitanSpin,
        Callback = function(v) CFG.AutoTitanSpin = v end
    })
    TabSpins:Toggle({
        Title = "Auto Unlock Titan (10M Gold)",
        Desc = "Unlocks Titan banner when player has 10M Gold (no forced farming)",
        ConfigKey = "AutoUnlockTitan",
        Value = CFG.AutoUnlockTitan,
        Callback = function(v) CFG.AutoUnlockTitan = v end
    })

    TabSpins:Section({ Title = "Weapon & Hero Passive Spins (Auto-Lock)" })
    TabSpins:Toggle({
        Title = "Auto Weapon Summon (T1)",
        Desc = "Spins Weapon T1 banner using WeaponCoinsT1",
        ConfigKey = "AutoWeaponSummon",
        Value = CFG.AutoWeaponSummon,
        Callback = function(v) CFG.AutoWeaponSummon = v end
    })
    TabSpins:Toggle({
        Title = "Auto Unlock Weapon T1 First (10.93M Gold @ AOT)",
        Desc = "Unlocks Gacha_Weapon_T1 when gold is reached",
        ConfigKey = "AutoUnlockWeapon",
        Value = CFG.AutoUnlockWeapon,
        Callback = function(v) CFG.AutoUnlockWeapon = v end
    })
    TabSpins:Toggle({
        Title = "Auto Weapon Passive Spin",
        Desc = "Spins Weapon Passive in OnePiece (Auto-locks on target)",
        ConfigKey = "AutoWeaponPassive",
        Value = CFG.AutoWeaponPassive,
        Callback = function(v) CFG.AutoWeaponPassive = v end
    })
    TabSpins:Dropdown({
        Title = "Target Weapon Passive",
        Desc = "Select desired passive (auto-locks & stops spinning when hit)",
        Values = {"Any", "Supreme Grade", "Black Blade", "Soul Breaker", "World Breaker", "Divine", "Cosmic", "Glitch", "Mastery", "Berserk", "Sharpness", "Executioner"},
        ConfigKey = "TargetWeaponPassive",
        Value = CFG.TargetWeaponPassive or "Any",
        Callback = function(v) CFG.TargetWeaponPassive = v end
    })
    TabSpins:Toggle({
        Title = "Auto Hero Passive Spin",
        Desc = "Spins Hero Passive with HeroPassiveCoins (Auto-locks on target)",
        ConfigKey = "AutoHeroPassive",
        Value = CFG.AutoHeroPassive,
        Callback = function(v) CFG.AutoHeroPassive = v end
    })
    TabSpins:Dropdown({
        Title = "Target Hero Passive",
        Desc = "Select desired hero passive (auto-locks & stops spinning when hit)",
        Values = {"Any", "Godly", "Secret", "Mythical", "Legendary", "Epic", "Golden", "Titan", "Shadow", "Speedster", "Overlord", "Immortal"},
        ConfigKey = "TargetHeroPassive",
        Value = CFG.TargetHeroPassive or "Any",
        Callback = function(v) CFG.TargetHeroPassive = v end
    })
    TabSpins:Toggle({
        Title = "Auto Unlock Hero Passive First (87.48M Gold @ AOT)",
        Desc = "Unlocks Gacha_Hero Passive when gold is reached",
        ConfigKey = "AutoUnlockHeroPassive",
        Value = CFG.AutoUnlockHeroPassive,
        Callback = function(v) CFG.AutoUnlockHeroPassive = v end
    })
end

-- ══════════════════════════════════════════════════════════
-- TAB 6: 🎒 EQUIPMENT & UPGRADES
-- ══════════════════════════════════════════════════════════
local TabEquip = Window:Tab({ Title = "Equip & Upgrade", Icon = "backpack" })
do
    TabEquip:Section({ Title = "Auto Equip Best Items & Titles" })
    TabEquip:Toggle({
        Title = "Equip Best (Global Boost)",
        Desc = "Applies highest stats across gear for selected boost",
        ConfigKey = "AutoEquipBest",
        Value = CFG.AutoEquipBest,
        Callback = function(v) CFG.AutoEquipBest = v end
    })
    TabEquip:Dropdown({
        Title = "Global Target Boost",
        Desc = "Select prioritized stat",
        Values = {"Energy","Gold","Damage","Drop","GachaLuck","GachaSpins","AtkSPD","CritDMG","CritChance"},
        ConfigKey = "AutoEquipBoost",
        Value = CFG.AutoEquipBoost,
        Callback = function(v) CFG.AutoEquipBoost = v end
    })
    TabEquip:Toggle({
        Title = "Equip Best Title (Highest Stat & Visual)",
        Desc = "Equips player's strongest unlocked title",
        ConfigKey = "EquipBestTitle",
        Value = CFG.EquipBestTitle,
        Callback = function(v) CFG.EquipBestTitle = v end
    })
    TabEquip:Dropdown({
        Title = "Equip Best Categories (Multi-Select)",
        Desc = "Select categories to include in Auto Equip Best",
        Multi = true,
        Values = { "Weapon", "Warrior", "Avatar", "Accessory", "Mount", "Jewel", "Wing", "DevilFruit", "Crewmate", "Amulet" },
        ConfigKey = "EquipBestCategories",
        Value = CFG.EquipBestCategories or { "Weapon", "Warrior", "Avatar", "Accessory", "Mount", "Jewel", "Wing", "DevilFruit", "Crewmate", "Amulet" },
        Callback = function(v)
            CFG.EquipBestCategories = v
        end
    })
    TabEquip:Button({
        Title = "Equip Best (Selected Categories) NOW",
        Desc = "Immediately applies best equipment for chosen categories and titles",
        Callback = doEquipBestCategories
    })

    TabEquip:Section({ Title = "Warrior Upgrades & Priority" })
    TabEquip:Toggle({
        Title = "Auto Upgrade Warrior",
        Desc = "Upgrades warrior attributes automatically",
        ConfigKey = "AutoUpgradeWarrior",
        Value = CFG.AutoUpgradeWarrior,
        Callback = function(v) CFG.AutoUpgradeWarrior = v end
    })
    TabEquip:Toggle({
        Title = "Auto Unlock Warrior First (15k Gold @ DBZ)",
        Desc = "Unlocks Warrior Upgrades system first",
        ConfigKey = "AutoUnlockWarrior",
        Value = CFG.AutoUnlockWarrior,
        Callback = function(v) CFG.AutoUnlockWarrior = v end
    })
    TabEquip:Dropdown({
        Title = "Warrior Stat Priority",
        Desc = "All balances available stats one level at a time",
        Values = {"All (Balanced)", "Energy", "Damage", "Gold", "AttackRange"},
        ConfigKey = "WarriorUpgradePriority",
        Value = CFG.WarriorUpgradePriority,
        Callback = function(v) CFG.WarriorUpgradePriority = v end
    })

    TabEquip:Section({ Title = "Progression Upgrades" })
    TabEquip:Toggle({
        Title = "Auto Rank Up (Rebirth Immediately)",
        Desc = "Automatically rebirths / ranks up as soon as Energy requirement is met",
        ConfigKey = "AutoRankUp",
        Value = CFG.AutoRankUp,
        Callback = function(v)
            CFG.AutoRankUp = v
            if v then
                task.spawn(function()
                    handleAutoRankUp(os.clock() + 2)
                end)
            end
        end
    })
    TabEquip:Toggle({
        Title = "Auto Offline Upgrades (Balanced)",
        Desc = "Balances Energy, Gold and MaxTime one level at a time",
        ConfigKey = "AutoOfflineUpgrades",
        Value = CFG.AutoOfflineUpgrades,
        Callback = function(v) CFG.AutoOfflineUpgrades = v end
    })
    TabEquip:Toggle({
        Title = "Auto Unlock Offline Upgrades First (45k Gold @ DBZ)",
        Desc = "Farms gold & unlocks offline upgrade system first",
        ConfigKey = "AutoUnlockOffline",
        Value = CFG.AutoUnlockOffline,
        Callback = function(v) CFG.AutoUnlockOffline = v end
    })
    TabEquip:Toggle({
        Title = "Auto Upgrade Selected Systems",
        Desc = "Upgrades the chosen Warrior, Offline, TT, Portal or Class Tree systems",
        ConfigKey = "AutoUpgrade",
        Value = CFG.AutoUpgrade,
        Callback = function(v) CFG.AutoUpgrade = v end
    })
    TabEquip:Dropdown({
        Title = "Select Upgrade Systems",
        Desc = "Choose which systems Auto Upgrade will purchase from",
        Multi = true,
        Values = UPGRADE_SYSTEM_NAMES,
        ConfigKey = "SelectedGlobalUpgrades",
        Value = CFG.SelectedGlobalUpgrades,
        Callback = function(v) CFG.SelectedGlobalUpgrades = v end
    })
    TabEquip:Toggle({
        Title = "Balanced Upgrades (Lowest Level First)",
        Desc = "Lowest available level first; one level per purchase. Off = buy max",
        ConfigKey = "BalanceGlobalUpgrades",
        Value = CFG.BalanceGlobalUpgrades,
        Callback = function(v) CFG.BalanceGlobalUpgrades = v end
    })

    TabEquip:Section({ Title = "Merge & Crafting" })
    TabEquip:Toggle({
        Title = "Auto Merge All (Weapons, Wings, Pets)",
        Desc = "Automatically merges duplicates in inventory",
        ConfigKey = "AutoMergeAll",
        Value = CFG.AutoMergeAll,
        Callback = function(v) CFG.AutoMergeAll = v end
    })
    TabEquip:Button({
        Title = "Merge All NOW",
        Desc = "Immediately merges duplicates",
        Callback = doMergeAll
    })
    TabEquip:Toggle({
        Title = "Auto Craft Enabled (Jewels)",
        Desc = "Crafts jewelry upgrades in ExchangeSystem",
        ConfigKey = "AutoCraft",
        Value = CFG.AutoCraft,
        Callback = function(v) CFG.AutoCraft = v end
    })
    TabEquip:Slider({
        Title = "Max Craft Tier (1-6)",
        Desc = "Highest tier of jewel to craft",
        Step = 1,
        ConfigKey = "CraftMaxTier",
        Value = { Min = 1, Max = 6, Default = CFG.CraftMaxTier },
        Callback = function(v) CFG.CraftMaxTier = v end
    })
    TabEquip:Toggle({ Title = "Craft Rings", ConfigKey = "CraftSelection.Ring", Value = CFG.CraftSelection.Ring, Callback = function(v) CFG.CraftSelection.Ring = v end })
    TabEquip:Toggle({ Title = "Craft Collars", ConfigKey = "CraftSelection.Collar", Value = CFG.CraftSelection.Collar, Callback = function(v) CFG.CraftSelection.Collar = v end })
    TabEquip:Toggle({ Title = "Craft Earrings", ConfigKey = "CraftSelection.Earring", Value = CFG.CraftSelection.Earring, Callback = function(v) CFG.CraftSelection.Earring = v end })
    TabEquip:Button({
        Title = "Craft All Available NOW",
        Desc = "Immediately crafts all selected jewel categories",
        Callback = doAutoCraft
    })
end

-- ══════════════════════════════════════════════════════════
-- TAB 7: 🧪 CONSUMABLES & SHOPS (MULTI-BUY SHOPS RESTORED!)
-- ══════════════════════════════════════════════════════════
local TabCons = Window:Tab({ Title = "Consumables & Shops", Icon = "flask-conical" })
do


    TabCons:Section({ Title = "Time Trial Potion Shop (Multi-Buy Selection)" })
    TabCons:Toggle({
        Title = "Auto Buy TT Shop Potions",
        Desc = "Automatically buys selected potions from TT shop",
        ConfigKey = "AutoBuyTTShop",
        Value = CFG.AutoBuyTTShop,
        Callback = function(v) CFG.AutoBuyTTShop = v end
    })

    local TT_POTION_NAMES = {
        "Energy Potion I (200)",
        "Damage Potion I (200)",
        "Gold Potion I (200)",
        "Luck Potion I (300)",
        "Drop Potion I (400)",
        "Energy Potion II (500)",
        "Damage Potion II (500)",
        "Gold Potion II (500)",
        "Luck Potion II (600)",
        "Drop Potion II (1000)"
    }
    TabCons:Dropdown({
        Title = "Select TT Potions (Multi-Select)",
        Desc = "Choose which potions to auto purchase",
        Multi = true,
        Values = TT_POTION_NAMES,
        ConfigKey = "TTSelectedPotionNames",
        Value = CFG.TTSelectedPotionNames or {},
        Callback = function(v)
            CFG.TTSelectedPotionNames = v
        end
    })
    TabCons:Dropdown({
        Title = "TT Shop Multi-Buy Multiplier",
        Desc = "Amount to purchase each cycle",
        Values = {"1x", "5x", "10x", "Max"},
        ConfigKey = "TTShopBuyAmountStr",
        Value = CFG.TTShopBuyAmountStr or "1x",
        Callback = function(v)
            CFG.TTShopBuyAmountStr = v
            if v == "1x" then CFG.TTShopBuyAmount = 1
            elseif v == "5x" then CFG.TTShopBuyAmount = 5
            elseif v == "10x" then CFG.TTShopBuyAmount = 10
            elseif v == "Max" then CFG.TTShopBuyAmount = 999 end
        end
    })
    TabCons:Button({
        Title = "Buy Selected TT Potions NOW",
        Desc = "Immediately purchases all selected potions from TT shop",
        Callback = doTimeTrialShopBuy
    })

    TabCons:Section({ Title = "Time Trial Stat Upgrades (TrialShards)" })
    TabCons:Toggle({
        Title = "Auto Time Trial Upgrades",
        Desc = "Balances selected TT stats one level at a time using TrialShards",
        ConfigKey = "AutoUpgradeTT",
        Value = CFG.AutoUpgradeTT,
        Callback = function(v) CFG.AutoUpgradeTT = v end
    })
    local TT_UPGRADE_NAMES = {
        "Breaker (Damage +5%)",
        "Relentless (Energy +5%)",
        "Scavenger (Gold +5%)",
        "Overdrive (AtkSPD +2.5%)"
    }
    TabCons:Dropdown({
        Title = "Select TT Upgrades (Multi-Select)",
        Desc = "Choose which TT upgrades to purchase",
        Multi = true,
        Values = TT_UPGRADE_NAMES,
        ConfigKey = "TTSelectedUpgradeNames",
        Value = CFG.TTSelectedUpgradeNames or TT_UPGRADE_NAMES,
        Callback = function(v)
            CFG.TTSelectedUpgradeNames = v
        end
    })
    TabCons:Button({
        Title = "Upgrade TT Stats NOW",
        Desc = "Purchases one level of the lowest selected Time Trial stat",
        Callback = doTimeTrialUpgrade
    })

    TabCons:Section({ Title = "Pirate Juice Shop (One Piece Multi-Buy)" })
    TabCons:Toggle({
        Title = "Auto Buy Pirate Juices",
        Desc = "Automatically buys selected juices from Pirate shop",
        ConfigKey = "AutoBuyPirateShop",
        Value = CFG.AutoBuyPirateShop,
        Callback = function(v) CFG.AutoBuyPirateShop = v end
    })

    local PIRATE_JUICE_NAMES = {
        "Energy Juice I (1000)",
        "Damage Juice I (1000)",
        "Gold Juice I (1000)",
        "Drop Juice I (1000)",
        "Luck Juice I (1000)"
    }
    TabCons:Dropdown({
        Title = "Select Pirate Juices (Multi-Select)",
        Desc = "Choose which juices to buy",
        Multi = true,
        Values = PIRATE_JUICE_NAMES,
        ConfigKey = "PirateSelectedJuiceNames",
        Value = CFG.PirateSelectedJuiceNames or PIRATE_JUICE_NAMES,
        Callback = function(v)
            CFG.PirateSelectedJuiceNames = v
        end
    })
    TabCons:Dropdown({
        Title = "Juice Multi-Buy Multiplier",
        Desc = "Amount to buy each cycle",
        Values = {"1x", "5x", "10x", "Max"},
        ConfigKey = "PirateShopBuyAmountStr",
        Value = CFG.PirateShopBuyAmountStr or "1x",
        Callback = function(v)
            CFG.PirateShopBuyAmountStr = v
            if v == "1x" then CFG.PirateShopBuyAmount = 1
            elseif v == "5x" then CFG.PirateShopBuyAmount = 5
            elseif v == "10x" then CFG.PirateShopBuyAmount = 10
            elseif v == "Max" then CFG.PirateShopBuyAmount = 999 end
        end
    })
    TabCons:Button({
        Title = "Buy Selected Pirate Juices NOW",
        Desc = "Immediately purchases chosen juices",
        Callback = doPirateShopBuy
    })
end

-- ══════════════════════════════════════════════════════════
-- TAB 8: 🏛️ HARBOR & MAPS
-- ══════════════════════════════════════════════════════════
local TabHarbor = Window:Tab({ Title = "Harbor & Maps", Icon = "compass" })
do
    TabHarbor:Section({ Title = "Reward Claimers" })
    TabHarbor:Toggle({
        Title = "Auto Claim All",
        Desc = "Claims Achievements, Dailies, Battlepass, Chests",
        ConfigKey = "AutoClaimAll",
        Value = CFG.AutoClaimAll,
        Callback = function(v) CFG.AutoClaimAll = v end
    })
    TabHarbor:Toggle({
        Title = "Auto Claim Like Rewards",
        Desc = "Claims 20 like milestone rewards automatically",
        ConfigKey = "AutoClaimLikeRewards",
        Value = CFG.AutoClaimLikeRewards,
        Callback = function(v) CFG.AutoClaimLikeRewards = v end
    })
    TabHarbor:Button({
        Title = "Claim All Rewards NOW",
        Desc = "Immediately executes claim on all reward systems",
        Callback = doClaimAll
    })
    TabHarbor:Button({
        Title = "Redeem All Promo Codes",
        Desc = "Redeems all known active promotional codes",
        Callback = doRedeemAllCodes
    })

    TabHarbor:Section({ Title = "1-Click Multi-Tasking Automations" })
    TabHarbor:Toggle({
        Title = "Auto Harbor (Expedition)",
        Desc = "Automatically claims and starts Harbor expeditions",
        ConfigKey = "AutoHarbor",
        Value = CFG.AutoHarbor,
        Callback = function(v) CFG.AutoHarbor = v end
    })
    TabHarbor:Toggle({
        Title = "Auto Collect Commandments",
        Desc = "Automatically collects Commandments & spawned items",
        ConfigKey = "AutoCommandments",
        Value = CFG.AutoCommandments,
        Callback = function(v) CFG.AutoCommandments = v end
    })


    TabHarbor:Section({ Title = "World Teleports" })
    for _, mapKey in ipairs(MAP_LIST) do
        local mk = mapKey
        TabHarbor:Button({
            Title = "Teleport to " .. mk,
            Desc = "Instantly teleports to world " .. mk,
            Callback = function()
                Library.Remote:Fire("TeleportSystem", "To", mk)
            end
        })
    end
    TabHarbor:Button({
        Title = "Buy All Maps In Order",
        Desc = "Unlocks and purchases all available world maps",
        Callback = function()
            for _, mk in ipairs(MAP_LIST) do
                Library.Remote:Fire("TeleportSystem", "Buy", mk)
                task.wait(0.4)
            end
        end
    })
end

-- ══════════════════════════════════════════════════════════
-- TAB 9: ⚙️ AUTO DELETE & SELL (ALL 11 RARITY LEVELS)
-- ══════════════════════════════════════════════════════════
local TabDelete = Window:Tab({ Title = "Auto Delete & Clean", Icon = "trash-2" })
do
    TabDelete:Section({ Title = "Auto Clean / Delete Settings (Multi-Dropdown)" })
    local deleteCategories = {
        { Key = "Pet",       Label = "Pets",        TKey = "AutoDeletePets",        DKey = "DeletePetsBelow" },
        { Key = "Weapon",    Label = "Weapons",     TKey = "AutoDeleteWeapons",     DKey = "DeleteWeaponsBelow" },
        { Key = "Wing",      Label = "Wings",       TKey = "AutoDeleteWings",       DKey = "DeleteWingsBelow" },
        { Key = "Avatar",    Label = "Avatars",     TKey = "AutoDeleteAvatars",     DKey = "DeleteAvatarsBelow" },
        { Key = "Accessory", Label = "Accessories", TKey = "AutoDeleteAccessories", DKey = "DeleteAccessoriesBelow" },
        { Key = "Warrior",   Label = "Warriors",    TKey = "AutoDeleteWarriors",    DKey = "DeleteWarriorsBelow" },
        { Key = "Mount",     Label = "Mounts",      TKey = "AutoDeleteMounts",      DKey = "DeleteMountsBelow" },
        { Key = "Jewel",     Label = "Jewels",      TKey = "AutoDeleteJewels",      DKey = "DeleteJewelsBelow" },
    }
    for _, c in ipairs(deleteCategories) do
        TabDelete:Toggle({
            Title = "Auto Clean " .. c.Label,
            ConfigKey = c.TKey,
            Value = CFG[c.TKey],
            Callback = function(v) CFG[c.TKey] = v end
        })
        TabDelete:Dropdown({
            Title = c.Label .. " Rarities (Multi-Select)",
            Desc = "Rarities to delete for " .. c.Label,
            Multi = true,
            Values = ALL_RARITY_NAMES,
            Value = {},
            Callback = function(v)
                for _, r in ipairs(ALL_RARITY_NAMES) do
                    RarityToggles[c.Key][r] = isItemInList(v, r)
                end
            end
        })
    end
end

-- ══════════════════════════════════════════════════════════
-- TAB 10: ℹ️ PLAYER & SERVER
-- ══════════════════════════════════════════════════════════
local TabPlayer = Window:Tab({ Title = "Player & Server", Icon = "user" })
do
    TabPlayer:Section({ Title = "Player Movement & Hacks" })
    TabPlayer:Toggle({
        Title = "Dash Hack",
        Desc = "Multiplies dash velocity and boosts movement during dashes",
        ConfigKey = "DashHack",
        Value = CFG.DashHack,
        Callback = function(v) CFG.DashHack = v end
    })
    TabPlayer:Slider({
        Title = "Dash Speed",
        Desc = "Custom dash speed velocity (50 - 500)",
        Step = 10,
        ConfigKey = "DashSpeed",
        Value = { Min = 50, Max = 500, Default = CFG.DashSpeed or 150 },
        Callback = function(v) CFG.DashSpeed = v end
    })
    TabPlayer:Slider({
        Title = "Jump Power",
        Desc = "Player jump height (50 - 500)",
        Step = 5,
        ConfigKey = "JumpPower",
        Value = { Min = 50, Max = 500, Default = CFG.JumpPower },
        Callback = function(v) CFG.JumpPower = v end
    })
    TabPlayer:Toggle({
        Title = "Infinite Health",
        Desc = "Constantly locks health to maximum",
        ConfigKey = "InfHealth",
        Value = CFG.InfHealth,
        Callback = function(v) CFG.InfHealth = v end
    })
    TabPlayer:Toggle({
        Title = "No Clip",
        Desc = "Disables collision on all character parts",
        ConfigKey = "NoClip",
        Value = CFG.NoClip,
        Callback = function(v)
            CFG.NoClip = v
            if v then enableNoClip() else disableNoClip() end
        end
    })
    TabPlayer:Button({
        Title = "Teleport to Spawn",
        Desc = "Returns character to spawn origin",
        Callback = function()
            local root = getRoot()
            if root then root.CFrame = CFrame.new(0, 10, 0) end
        end
    })

    TabPlayer:Section({ Title = "Anti-AFK & Server Actions" })
    TabPlayer:Toggle({
        Title = "Anti-AFK (Prevent 20m Kick)",
        Desc = "Bypasses Roblox 20 minute inactivity kick",
        ConfigKey = "AntiAFK",
        Value = CFG.AntiAFK,
        Callback = function(v) CFG.AntiAFK = v end
    })
    TabPlayer:Toggle({
        Title = "Auto Rejoin on Disconnect",
        Desc = "Automatically reconnects if disconnected",
        ConfigKey = "AutoRejoin",
        Value = CFG.AutoRejoin,
        Callback = function(v) CFG.AutoRejoin = v end
    })
    TabPlayer:Button({
        Title = "Rejoin Current Server NOW",
        Desc = "Re-executes connection to current place instance",
        Callback = doRejoinCurrent
    })
    TabPlayer:Button({
        Title = "Rejoin New Server (Hop)",
        Desc = "Finds another active server and teleports",
        Callback = doServerHop
    })

    local pingVal = 50
    pcall(function()
        if lp and lp.GetNetworkPing then
            pingVal = math.floor((lp:GetNetworkPing() or 0.05) * 1000)
        end
    end)
    TabPlayer:Section({ Title = "System Information" })
    TabPlayer:Paragraph({
        Title = "Session Information",
        Desc = string.format("Place ID: %s\nJob ID: %s\nPing: ~%d ms\nDevelopers: cook45 x clack (25+ yrs exp)",
            tostring(game.PlaceId),
            tostring(game.JobId):sub(1, 16) .. "...",
            pingVal
        )
    })
end


-- ══════════════════════════════════════════════════════════
-- TAB 11: ⚙️ CONFIGURATION MANAGER
-- ══════════════════════════════════════════════════════════
local TabConfig = Window:Tab({ Title = "Configuration", Icon = "settings" })
do
    TabConfig:Section({ Title = "Profile Management" })

    local configList = getSavedConfigsList()
    local DropdownConfig = TabConfig:Dropdown({
        Title = "Select Profile",
        Desc = "Choose a configuration profile to load, save, or delete",
        Values = configList,
        ConfigKey = "SelectedConfigName",
        Value = CFG.SelectedConfigName or "default",
        Callback = function(v)
            CFG.SelectedConfigName = v
        end
    })

    TabConfig:Toggle({
        Title = "Auto Load Config on Startup",
        Desc = "Automatically loads selected configuration when script launches",
        ConfigKey = "AutoLoadConfig",
        Value = CFG.AutoLoadConfig,
        Callback = function(v)
            CFG.AutoLoadConfig = v
            if writefile then
                pcall(writefile, CONFIG_FOLDER .. "/_autoload.txt", CFG.SelectedConfigName or "default")
            end
        end
    })

    TabConfig:Button({
        Title = "Save to Selected Config",
        Desc = "Writes current toggle states and parameters to file",
        Callback = function()
            saveConfigFile(CFG.SelectedConfigName or "default")
        end
    })

    TabConfig:Button({
        Title = "Load Selected Config",
        Desc = "Restores all settings from the selected file profile",
        Callback = function()
            loadConfigFile(CFG.SelectedConfigName or "default")
        end
    })

    TabConfig:Section({ Title = "Create & Delete Configs" })

    local newNameInput = ""
    TabConfig:Input({
        Title = "New Config Name",
        Desc = "Type a name for a new profile",
        Default = "",
        Placeholder = "e.g. SpeedFarming",
        Callback = function(txt)
            newNameInput = txt
        end
    })

    TabConfig:Button({
        Title = "Create New Config Profile",
        Desc = "Creates a new config file and adds it to the profile list",
        Callback = function()
            if newNameInput and newNameInput ~= "" then
                saveConfigFile(newNameInput)
                CFG.SelectedConfigName = newNameInput
                local updatedList = getSavedConfigsList()
                pcall(function() DropdownConfig:Refresh(updatedList); DropdownConfig:Set(CFG.SelectedConfigName or "default", true) end)
            end
        end
    })

    TabConfig:Button({
        Title = "Delete Selected Config Profile",
        Desc = "Removes the selected config file permanently",
        Callback = function()
            if CFG.SelectedConfigName and CFG.SelectedConfigName ~= "default" then
                deleteConfigFile(CFG.SelectedConfigName)
                CFG.SelectedConfigName = "default"
                local updatedList = getSavedConfigsList()
                pcall(function() DropdownConfig:Refresh(updatedList); DropdownConfig:Set(CFG.SelectedConfigName or "default", true) end)
            end
        end
    })

    TabConfig:Button({
        Title = "Refresh Profiles List",
        Desc = "Reloads all config files found in directory",
        Callback = function()
            local updatedList = getSavedConfigsList()
            pcall(function() DropdownConfig:Refresh(updatedList); DropdownConfig:Set(CFG.SelectedConfigName or "default", true) end)
        end
    })
end

Window:FinishLoading()
print("[Axel Hub] Anime Breaker loaded with AxelUI. Sticky target locking active.")
