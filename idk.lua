-- Axel Hub bootstrap
-- Prefer a preloaded Oxide library; otherwise fetch the current library.
local LIB_URL = "https://raw.githubusercontent.com/xulfo/OxideUiLibary2/main/UiLibary/Libary.lua"

local function fetchLibrarySource(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" and #body > 1000 then
        return body
    end
    return nil
end

local function loadLibrary()
    local existing = rawget(_G, "OxideLib")
    -- Reuse only the library build that includes tab icon support.
    if type(existing) == "table"
        and type(existing.CreateWindow) == "function"
        and tonumber(existing.Version) and tonumber(existing.Version) >= 2.6 then
        return existing
    end

    local source = fetchLibrarySource(LIB_URL)
    if not source then
        local bust = LIB_URL .. "?cb=" .. tostring(os.time())
        source = fetchLibrarySource(bust)
    end
    if type(source) ~= "string" then
        error("[Axel Hub] Failed to fetch Oxide UI library", 0)
    end

    local chunk, err = loadstring(source)
    if type(chunk) ~= "function" then
        error("[Axel Hub] Oxide UI compile error: " .. tostring(err), 0)
    end

    local ok, lib = pcall(chunk)
    if not ok or type(lib) ~= "table" or type(lib.CreateWindow) ~= "function" then
        error("[Axel Hub] Invalid Oxide UI library", 0)
    end
    return lib
end

local Library
local libraryOk, libraryResult = pcall(loadLibrary)
if not libraryOk then error(libraryResult, 0) end
Library = libraryResult

-- === HUB STRIP POINT - when executed through the hub ScriptLoader, which injects
--     "local Library = _G.OxideLib" above this line instead. ===
-- ==============================================================================

-- ==============================================================================
-- RE-EXECUTION GUARD + RESOURCE TRACKING
-- ==============================================================================
do
    local prev = _G.OxideStealAnEgg
    if prev and type(prev.Unload) == "function" then pcall(prev.Unload) end
end
local HUB = { conns = {}, drawings = {}, highlights = {}, dead = false }
-- A new character needs a short server/client replication window before the
-- Suji Auto Steal route is allowed to claim a field egg.  This prevents the
-- first post-death scan from running against the old Backpack/field replica.
HUB.AutoStealResumeAt = 0
HUB.IsAutoStealResumeReady = function()
    return os.clock() >= (tonumber(HUB.AutoStealResumeAt) or 0)
end
_G.OxideStealAnEgg = HUB
local function track(conn) table.insert(HUB.conns, conn); return conn end
local function trackDrawing(d) if d then table.insert(HUB.drawings, d) end; return d end

-- Axel Hub branding: use the bundled Oxide library with an Axel yellow accent.
pcall(function()
    if type(Library.SetTheme) == "function" then
        Library:SetTheme({
            Accent = Color3.fromRGB(255, 193, 7),
            AccentDim = Color3.fromRGB(74, 58, 8),
            AccentText = Color3.fromRGB(20, 20, 20),
            KnobAccent = Color3.fromRGB(255, 193, 7),
        })
    end
end)

local Window = Library:CreateWindow({
    Logo = "rbxassetid://86949082023913",
    LogoZoom = 1.15,
    GuiName = "AxelHub",
    ReplaceExisting = true,

    Name = "Axel Hub | Steal an Egg",
    BrandSubtitle = "Made by secret agent",
    StatusText = "Axel is ready",
    LoadingAnimation = false,
    LoadingText = "Axel Hub",
    LoadingDuration = 0.0,
})

-- ==============================================================================
-- CONFIG / FLAG PERSISTENCE
-- ==============================================================================
local HAS_CONFIG = type(Library.SaveConfig) == "function"
    and type(Library.LoadConfig) == "function"
    and type(Library.ListConfigs) == "function"
local CONFIG_NAME = "stealanegg"

local dropdownResync = {}
local function registerResync(handle, applyFn)
    if handle and applyFn then
        table.insert(dropdownResync, function() applyFn(handle:Get()) end)
    end
end
local function ResyncAll()
    for _, fn in ipairs(dropdownResync) do pcall(fn) end
end

-- ==============================================================================
-- SERVICES & LOCALS
-- ==============================================================================
local Players             = game:GetService("Players")
local RS                  = game:GetService("ReplicatedStorage")
local ReplicatedStorage   = RS
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local Workspace           = game:GetService("Workspace")
local Lighting            = game:GetService("Lighting")
local TeleportService     = game:GetService("TeleportService")
local VirtualUser         = game:GetService("VirtualUser")

local LP = Players.LocalPlayer or Players.LocalPlayerAdded:Wait()
local LocalPlayer = LP
local function GetCamera()
    return Workspace.CurrentCamera or Workspace:FindFirstChildOfClass("Camera")
end


-- Anti-Robux Purchase Prompt Shield: immediately dismisses accidental Robux purchase prompts
pcall(function()
    local coreGui = game:GetService("CoreGui")
    track(coreGui.ChildAdded:Connect(function(child)
        if child.Name == "PurchasePrompt" then
            task.wait(0.04)
            pcall(function()
                local cancel = child:FindFirstChild("CancelButton", true)
                if cancel and typeof(cancel) == "Instance" and cancel:IsA("GuiButton") then
                    pcall(function() cancel:Activate() end)
                end
            end)
        end
    end))
end)

local function Notify(title, content, kind, dur)
    pcall(function()
        Window:Notify({ Title = title, Content = content, Type = kind or "Info", Duration = dur or 2.5 })
    end)
end

local function safeCallback(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            pcall(Notify, "Oxide HUB", "Error: " .. tostring(err), "Error", 4)
        end
    end
end

-- ==============================================================================
-- CLIENT AC NEUTRALIZER & UGI CONSTANT WIPER (Layer 1 + Layer 2)
-- ==============================================================================
local function bypassClientDetections()
    if typeof(filtergc) ~= "function" or typeof(debug) ~= "table" or typeof(debug.getupvalues) ~= "function" then
        return false, "no filtergc"
    end
    local ok, fn = pcall(function()
        return filtergc("function", {
            Constants = { "gmatch", "GetFullName" },
        }, true)
    end)
    if not ok or type(fn) ~= "function" then
        return false, "filter miss"
    end
    local setMeta = (typeof(setrawmetatable) == "function" and setrawmetatable)
        or (typeof(setmetatable) == "function" and setmetatable)
    if not setMeta then
        return false, "no setmeta"
    end
    local blocked = 0
    local okUv, ups = pcall(debug.getupvalues, fn)
    if not okUv or type(ups) ~= "table" then
        return false, "no upvalues"
    end
    for _, tbl in pairs(ups) do
        if typeof(tbl) == "table" then
            local okSet = pcall(setMeta, tbl, {
                __newindex = function() end,
            })
            if okSet then
                blocked = blocked + 1
            end
        end
    end
    return blocked > 0, blocked
end

pcall(bypassClientDetections)

-- Runtime AC Detection Table Freezer (Neutralizes violation storage)
pcall(function()
    local getgc = getgc or (debug and debug.getgc)
    local setmeta = setrawmetatable or setmetatable
    local getmeta = getrawmetatable or getmetatable

    if getgc and setmeta then
        for _, obj in ipairs(getgc(true)) do
            if typeof(obj) == "table" and not (getmeta and getmeta(obj)) then
                local mainrun = false
                for _, v in pairs(obj) do
                    if v == obj then
                        mainrun = true
                        break
                    end
                end
                if mainrun then
                    for _, v in pairs(obj) do
                        if typeof(v) == "number" and v >= 1 and v <= 3 and obj[v] == nil then
                            pcall(setmeta, obj, { __newindex = function() end })
                            break
                        end
                    end
                end
            end
        end
    end
end)

-- UGI Constant Wiper (neutralizes ReplicatedFirst.UGI watchdog)
pcall(function()
    local getconstants = getconstants or (debug and debug.getconstants)
    local setconstant = setconstant or (debug and debug.setconstant)
    local islclosure = islclosure or function(Function)
        return not pcall(setfenv, getfenv(Function))
    end

    if getgc and getconstants and setconstant then
        for _, Function in ipairs(getgc(true)) do
            if typeof(Function) == "function" and islclosure(Function) then
                local ok, Source = pcall(debug.info, Function, "s")
                if ok and type(Source) == "string" and Source:find("ReplicatedFirst", 1, true) and Source:find("UGI", 1, true) then
                    local okC, Constants = pcall(getconstants, Function)
                    if okC and type(Constants) == "table" then
                        for Index, Constant in next, Constants do
                            if type(Constant) == "string" and Constant == "Humanoid" then
                                pcall(setconstant, Function, Index, "")
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- Secondary Layer: X-14 Stack Scrubber & Token Neutralizer
pcall(function()
    local getconstants = getconstants or (debug and debug.getconstants)
    local islclosure = islclosure or function(fn) return not pcall(setfenv, getfenv(fn)) end
    local HookFn = hookfunction or replaceclosure or hookfunc
    if getgc and getconstants and HookFn and debug and debug.getstack and debug.setstack then
        for _, fn in ipairs(getgc(true)) do
            if typeof(fn) == "function" and islclosure(fn) then
                local ok, consts = pcall(getconstants, fn)
                if ok and type(consts) == "table" and table.find(consts, "X-14") then
                    local cb = nil
                    cb = HookFn(fn, function(...)
                        local stack = debug.getstack(1)
                        if type(stack) == "table" then
                            for idx, val in pairs(stack) do
                                if val == "X-14" then
                                    pcall(debug.setstack, 1, idx, nil)
                                end
                            end
                        end
                        if cb then return cb(...) end
                    end)
                end
            end
        end
    end
end)

-- Layer 3: Anti-Tamper State Table Sanitizer (19-upvalue detection neutralization)
pcall(function()
    local getgc = getgc or (debug and debug.getgc)
    local islclosure = islclosure or function(v) return not pcall(setfenv, getfenv(v)) end
    local getupvalues = getupvalues or (debug and debug.getupvalues)
    local getupvalue = getupvalue or (debug and debug.getupvalue)
    local setupvalue = setupvalue or (debug and debug.setupvalue)
    local clonefunction = clonefunction or function(f) return function(...) return f(...) end end

    if getgc and getupvalues and getupvalue and setupvalue then
        for _, v in ipairs(getgc(true)) do
            if typeof(v) == "function" and islclosure(v) then
                local ok, upvs = pcall(getupvalues, v)
                if ok and upvs and #upvs == 19 then
                    local ok2, u2 = pcall(getupvalue, v, 2)
                    if ok2 and typeof(u2) == "function" then
                        local old = clonefunction(u2)
                        pcall(setupvalue, v, 2, function(a, b)
                            if b and typeof(b) == "table" then
                                pcall(setmetatable, b, {})
                            end
                            return old(a, b)
                        end)
                    end
                end
            end
        end
    end
end)

-- ==============================================================================
-- CHARACTER & MOVEMENT HELPERS
-- ==============================================================================
local function findChar() return LP.Character end
local function findHum()
    local ch = LP.Character
    return ch and ch:FindFirstChildOfClass("Humanoid")
end
local function findHRP()
    local ch = LP.Character
    return ch and (ch:FindFirstChild("HumanoidRootPart") or ch.PrimaryPart or ch:FindFirstChildWhichIsA("BasePart"))
end

local GetCharacter = findChar
local GetHumanoid  = findHum
local GetHRP       = findHRP

local function GetRootCFrame()
    local hrp = findHRP()
    return hrp and hrp.CFrame
end

-- ==============================================================================
-- BAC TELEMETRY PACKET SPOOFER
-- ==============================================================================
local bxor = bit32.bxor
local unpack = table.unpack

local function isGuid(n)
    return #n==36 and n:sub(9,9)=="-" and n:sub(14,14)=="-" and n:sub(19,19)=="-" and n:sub(24,24)=="-" and n:gsub("-",""):match("^%x+$")~=nil
end

local remoteSet, anyRemote = {}, nil

local function scanRemotes()
    for _, s in ipairs(game:GetChildren()) do
        local ok, list = pcall(s.GetDescendants, s)
        if ok and list then
            for _, o in ipairs(list) do
                if o:IsA("RemoteEvent") and isGuid(o.Name) then
                    remoteSet[o] = true
                    anyRemote = anyRemote or o
                end
            end
        end
    end
end

scanRemotes()

local function parseCounter(v)
    if type(v) ~= "string" then return end
    local n = v:match("^X%-(%d+)$")
    return n and tonumber(n)
end

local function looksLikeState(t, r)
    if type(t) ~= "table" then return false end
    local hR, hM = false, false
    local ok = pcall(function()
        for _, v in pairs(t) do
            if v == r then hR = true
            elseif type(v) == "string" and v:match("^X%-%d+$") then hM = true end
        end
    end)
    return ok and hR and hM
end

local function findState(r)
    for l=2,24 do
        local _, fn = pcall(debug.info, l, "f")
        if type(fn) == "function" then
            local _, ups = pcall(debug.getupvalues, fn)
            if type(ups) == "table" then
                for _, v in pairs(ups) do
                    if looksLikeState(v, r) then return v end
                    if type(v) == "table" then
                        local nested
                        pcall(function()
                            for _, x in pairs(v) do
                                if looksLikeState(x, r) then nested = x; return end
                            end
                        end)
                        if nested then return nested end
                    end
                end
            end
        end
    end
end

local function mapState(st, a1, a2)
    local m = {}
    for k, v in pairs(st) do
        if type(v) == "string" then
            if v:match("^X%-%d+$") then m.marker = m.marker or k
            elseif a1 and v == a1 then m.arg1 = m.arg1 or k
            elseif a2 and v == a2 then m.arg2 = m.arg2 or k end
        end
    end
    return m
end

local model = nil

local function digits(n)
    n = n % 1000
    return math.floor(n/100), math.floor(n/10)%10, n%10
end

local function encode(m, c)
    local d1, d2, d3 = digits(c)
    return m.prefix .. string.char(bxor(d1, m.k1), bxor(d2, m.k2), bxor(d3, m.k3))
end

local function learn(r, a1, a2)
    local st = findState(r)
    if not st then return end
    local map = mapState(st, a1, a2)
    if not map.marker then return end
    local c = parseCounter(rawget(st, map.marker))
    if not c then return end
    local d1, d2, d3 = digits(c)
    local m = {
        state = st, map = map, remote = r,
        prefix = a1:sub(1, 9),
        k1 = bxor(a1:byte(10), d1),
        k2 = bxor(a1:byte(11), d2),
        k3 = bxor(a1:byte(12), d3),
        offset = c - os.time(),
        arg2 = a2
    }
    if encode(m, c) == a1 then return m end
end

local function liveCounter(m)
    if m.state and m.map.marker then
        local _, raw = pcall(rawget, m.state, m.map.marker)
        local c = parseCounter(raw)
        if c and math.abs((c - os.time()) - m.offset) <= 5 then
            return c
        end
    end
    return os.time() + m.offset
end

local function refreshArg2(m)
    if m.state and m.map.arg2 then
        local _, v = pcall(rawget, m.state, m.map.arg2)
        if type(v) == "string" then m.arg2 = v end
    end
    return m.arg2
end

local HookFn = hookfunction or replaceclosure or hookfunc or detour_function

if anyRemote and HookFn then
    local oldFire
    oldFire = HookFn(anyRemote.FireServer, function(self, ...)
        local args = table.pack(...)
        if not remoteSet[self] then
            return oldFire(self, unpack(args, 1, args.n))
        end

        local a1 = args[1]

        if type(a1) == "string" and #a1 == 12 then
            if not model then
                model = learn(self, a1, args[2])
            else
                local c = parseCounter(rawget(model.state, model.map.marker))
                if c and encode(model, c) ~= a1 then
                    local m = learn(self, a1, args[2])
                    if m then m.spoofed = model.spoofed; model = m end
                end
            end
            return oldFire(self, unpack(args, 1, args.n))
        end

        if model and type(a1) == "string" and #a1 == 4 then
            local c = liveCounter(model)
            args[1] = encode(model, c)
            args[2] = refreshArg2(model)
            model.spoofed = (model.spoofed or 0) + 1
            return oldFire(self, unpack(args, 1, math.max(args.n, 2)))
        end

        return oldFire(self, unpack(args, 1, args.n))
    end)
end

task.spawn(function()
    while not HUB.dead do
        task.wait(10)
        local alive = false
        for r in pairs(remoteSet) do
            if r:IsDescendantOf(game) then alive = true; break end
        end
        if not alive then
            table.clear(remoteSet)
            anyRemote = nil
            model = nil
            scanRemotes()
        end
    end
end)

-- Real-time Memory Evidence Scrubber for Character Integrity
task.spawn(function()
    if not getgc then return end
    local st = nil

    local function findIntegrityTable()
        local ok, objs = pcall(getgc, true)
        if ok and objs then
            for _, o in pairs(objs) do
                if type(o) == "table" then
                    local hit = false
                    pcall(function()
                        hit = (rawget(o, "ValidationLocked") ~= nil and rawget(o, "Evidence") ~= nil)
                            or (rawget(o, "ThreatLevel") ~= nil and rawget(o, "LastObservedSample") ~= nil)
                    end)
                    if hit then return o end
                end
            end
        end
        return nil
    end

    track(LP.CharacterAdded:Connect(function()
        task.wait(1)
        st = findIntegrityTable()
    end))

    while not HUB.dead do
        if not st then
            st = findIntegrityTable()
        end

        if st then
            pcall(function()
                local ev = rawget(st, "Evidence")
                if type(ev) == "table" then
                    if (tonumber(ev.Speed)    or 0) > 0 then rawset(ev, "Speed", 0) end
                    if (tonumber(ev.Teleport) or 0) > 0 then rawset(ev, "Teleport", 0) end
                    if (tonumber(ev.Flight)   or 0) > 0 then rawset(ev, "Flight", 0) end
                end
                if rawget(st, "ThreatLevel") ~= "Trusted" then rawset(st, "ThreatLevel", "Trusted") end
                if rawget(st, "ValidationLocked") == true then rawset(st, "ValidationLocked", false) end
                if rawget(st, "FirstSuspiciousAt") ~= nil then rawset(st, "FirstSuspiciousAt", nil) end
                if rawget(st, "KickQueued") == true then rawset(st, "KickQueued", false) end
                if rawget(st, "TamperScore") ~= nil then rawset(st, "TamperScore", 0) end
                if rawget(st, "InvalidHeartbeatCount") ~= nil then rawset(st, "InvalidHeartbeatCount", 0) end

                local los = rawget(st, "LastObservedSample")
                if los ~= nil then
                    if rawget(st, "LastGameplayTrustedSample") == nil then rawset(st, "LastGameplayTrustedSample", los) end
                    if rawget(st, "LastValidatedSample") == nil then rawset(st, "LastValidatedSample", los) end
                    if rawget(st, "LastValidatedGroundedSample") == nil then rawset(st, "LastValidatedGroundedSample", los) end
                    if rawget(st, "LastConfirmedGroundSample") == nil then rawset(st, "LastConfirmedGroundSample", los) end
                    if rawget(st, "LastGoodSample") == nil then rawset(st, "LastGoodSample", los) end
                end
            end)
        end
        task.wait(0.2)
    end
end)

-- ==============================================================================
-- GAME NETWORKING & MODULE INTEGRATION
-- ==============================================================================
local EggState, PlotState, AreasData, RarityData, AssetsData, EggToolDisplay, AreaEggSlotIdentity
pcall(function() EggState = require(RS.Client.EggState) end)
pcall(function() PlotState = require(RS.Client.PlotState) end)
pcall(function() AreasData = require(RS.Data.Areas) end)
pcall(function() RarityData = require(RS.Data.Rarity) end)
pcall(function() AssetsData = require(RS.Data.Assets) end)
local SaveModule
pcall(function() SaveModule = require(RS.Shared.Save) end)

-- Resolve an inventory/placement record to the live asset catalog.  The game
-- stores the income rate on the catalog entry (EarningRate) and the hatch
-- duration under catalogEntry.Egg.GrowthTime, rather than copying either
-- value onto every inventory record.  Keeping this as a HUB method avoids
-- spending another main-chunk local register on the Luau executor.
function HUB.WebLogFindAssetInfo(record)
    if type(record) ~= "table" or not AssetsData then return nil end
    local dir = AssetsData.Directory or AssetsData
    if type(dir) ~= "table" then return nil end

    local placement = type(record.Placement) == "table" and record.Placement or nil
    local ids = {
        record.AssetCategory,
        record.Category,
        record.EggName,
        record.AssetId,
        record.EggId,
        record.Id,
        record.Name,
        placement and placement.AssetCategory,
        placement and placement.Category,
        placement and placement.AssetId,
    }
    for _, id in ipairs(ids) do
        if id ~= nil then
            local info = dir[id]
            if info == nil then
                local wanted = string.lower(tostring(id))
                for key, value in pairs(dir) do
                    if string.lower(tostring(key)) == wanted then
                        info = value
                        break
                    end
                end
            end
            if type(info) == "table" then return info end
        end
    end
    return nil
end

-- Upgrade data/modules used by the Auto Upgrade system.
-- Resolve by name recursively so this works even when the UI/script layout differs
-- from the original source that exposed BaseUpgradeModule/TreadmillsData directly.
local BaseUpgradeModule, TreadmillsData
local function TryRequireModuleByNames(names)
    for _, root in ipairs({RS, game:GetService("ReplicatedStorage")}) do
        for _, name in ipairs(names) do
            local obj = nil
            pcall(function() obj = root:FindFirstChild(name, true) end)
            if obj and obj:IsA("ModuleScript") then
                local ok, value = pcall(require, obj)
                if ok and type(value) == "table" then
                    return value
                end
            end
        end
    end
    return nil
end
pcall(function()
    BaseUpgradeModule = TryRequireModuleByNames({"BaseUpgradeModule", "HomesteadUpgrade", "HomesteadUpgrades", "BaseUpgrades"})
end)
pcall(function()
    TreadmillsData = TryRequireModuleByNames({"TreadmillsData", "Treadmills", "TreadmillData", "TreadmillUpgrades"})
end)
pcall(function() EggToolDisplay = require(RS.Shared.Eggs.EggToolDisplay) end)
pcall(function()
    AreaEggSlotIdentity = (RS:FindFirstChild("Shared") and RS.Shared:FindFirstChild("Util") and require(RS.Shared.Util.AreaEggSlotIdentity))
        or (RS:FindFirstChild("Util") and require(RS.Util.AreaEggSlotIdentity))
        or (RS:FindFirstChild("Shared") and RS.Shared:FindFirstChild("Utils") and require(RS.Shared.Utils.AreaEggSlotIdentity))
end)


-- ==============================================================================
-- AXEL HUB WEB LOG TELEMETRY
-- Sends live account/game statistics to the Axel Hub Web Log dashboard.
-- WEBLOG_URL is the public endpoint. WEBLOG_API_KEY is the personal key shown after signing in to Axel Hub.
-- ============================================================================
do
    -- Web Log connection / runtime config.
    -- Edit these values directly in the script, or override them before execution:
    --
    -- getgenv().AxelWebLogConfig = {
    --     Enabled = true,
    --     URL = "https://axelhub-weblog.originalpro.workers.dev/api/telemetry",
    --     Key = "axel_your_personal_telemetry_key",
    --     Interval = 5,
    --     Debug = false,
    --     LocalFallback = false,
    -- }
    --
    -- The config is exposed through BOTH getgenv().AxelWebLogConfig and _G.AxelWebLogConfig.
    -- Missing fields automatically fall back to the defaults below.
    local _axelGlobal = (getgenv and getgenv()) or _G
    local _sharedConfig = rawget(_axelGlobal, "AxelWebLogConfig")
    if type(_sharedConfig) ~= "table" then
        _sharedConfig = rawget(_G, "AxelWebLogConfig")
    end
    if type(_sharedConfig) ~= "table" then
        _sharedConfig = {}
    end

    local AXEL_WEBLOG_DEFAULTS = {
        Enabled = true,
        URL = "https://axelhub-weblog.originalpro.workers.dev/api/telemetry",
        -- Never ship another user's key as a fallback.  The signed-in user's
        -- key must come from AxelWebLogConfig.Key (or the legacy global).
        Key = "PASTE_YOUR_PERSONAL_TELEMETRY_KEY",
        Interval = 5,
        Debug = true,
        LocalFallback = false,
    }

    local function webLogConfigValue(name)
        local value = _sharedConfig[name]
        if value == nil then
            value = AXEL_WEBLOG_DEFAULTS[name]
        end
        return value
    end

    local function webLogSetConfigField(name, value)
        _sharedConfig[name] = value
        pcall(function() _G.AxelWebLogConfig = _sharedConfig end)
        pcall(function()
            if getgenv then getgenv().AxelWebLogConfig = _sharedConfig end
        end)
    end

    -- Publish the mutable config immediately so it can be edited while the script is running.
    _G.AxelWebLogConfig = _sharedConfig
    pcall(function()
        if getgenv then getgenv().AxelWebLogConfig = _sharedConfig end
    end)

    -- Backwards compatibility with the old two-variable setup.
    if _sharedConfig.URL == nil and _axelGlobal.AXEL_WEBLOG_URL ~= nil then
        _sharedConfig.URL = _axelGlobal.AXEL_WEBLOG_URL
    end
    if _sharedConfig.Key == nil and _axelGlobal.AXEL_WEBLOG_KEY ~= nil then
        _sharedConfig.Key = _axelGlobal.AXEL_WEBLOG_KEY
    end

    local function webLogConfigSnapshot()
        return {
            Enabled = webLogConfigValue("Enabled") ~= false,
            URL = tostring(webLogConfigValue("URL") or AXEL_WEBLOG_DEFAULTS.URL),
            Key = tostring(webLogConfigValue("Key") or ""),
            Interval = math.max(1, tonumber(webLogConfigValue("Interval")) or AXEL_WEBLOG_DEFAULTS.Interval),
            Debug = webLogConfigValue("Debug") == true,
            LocalFallback = webLogConfigValue("LocalFallback") ~= false,
        }
    end

    -- Production Premium entitlement is supplied as the normal `Premiums`
    -- global by the script loader, following the pattern used by King Legacy.
    -- Keep getgenv().Premiums out of the production gate; the test prelude is
    -- kept separately under examples/ and only assigns this normal variable.
    HUB.IsWebLogPremium = function()
        return Premiums == true
    end

    -- Each Web Log user has a private telemetry key. The server isolates account data by that key.
    local webLogPrintedSite = false

    -- Device is intentionally limited to two labels for the dashboard.
    -- Touch-only clients are Mobile; keyboard-equipped clients are PC.
    local function webLogGetDevice()
        local touch = false
        local keyboard = false
        pcall(function() touch = UserInputService.TouchEnabled == true end)
        pcall(function() keyboard = UserInputService.KeyboardEnabled == true end)
        if touch and not keyboard then
            return "Mobile"
        end
        return "PC"
    end

    local HttpService = game:GetService("HttpService")
    local WebLogRequest = (syn and syn.request)
        or (http and http.request)
        or http_request
        or request
        or (fluxus and fluxus.request)
        or krnl_request
        or (electron and electron.request)

    local webLogEggsStolen = 0
    local webLogLastEggs = nil
    local webLogLastPets = nil
    local webLogLastAt = nil
    local webLogLastPetRate = 0
    local webLogLastEggRate = 0
    local webLogLatestStolenEgg = nil
    local webLogActivity = "Idle"
    local webLogActivityDetail = "Waiting for activity"
    local webLogCurrentArea = ""
    local webLogLastActivityAt = os.clock()
    -- Event telemetry is kept separately from the game's passive label so the
    -- Rift/Boss adapters can publish a precise status (including translations)
    -- without changing the inventory payload shape.
    local webLogEventName = nil
    local webLogEventDetail = ""
    local webLogEventStatus = "idle"
    local webLogEventUpdatedAt = 0

    local function webLogCountTable(t)
        if type(t) ~= "table" then return 0 end
        local n = 0
        for _ in pairs(t) do n += 1 end
        return n
    end

    local function webLogDirectNumber(root, keys)
        if type(root) ~= "table" then return nil end
        for _, key in ipairs(keys) do
            local v = root[key]
            if type(v) == "number" then return v end
            if type(v) == "string" then
                local n = tonumber(v)
                if n then return n end
            end
        end
        return nil
    end

    -- Read the small set of values needed by the Web Log from nested save
    -- records.  Game builds move these fields between EggInventory, Stats and
    -- an item Data table, so keep this resolver deliberately defensive.
    local function webLogDeepNumber(root, keys, depth, seen)
        if type(root) ~= "table" or (depth or 0) > 5 then return nil end
        seen = seen or {}
        if seen[root] then return nil end
        seen[root] = true
        local direct = webLogDirectNumber(root, keys)
        if direct ~= nil then return direct end
        for _, child in pairs(root) do
            if type(child) == "table" then
                local found = webLogDeepNumber(child, keys, (depth or 0) + 1, seen)
                if found ~= nil then return found end
            end
        end
        return nil
    end

    local function webLogDeepValue(root, keys, depth, seen)
        if type(root) ~= "table" or (depth or 0) > 5 then return nil end
        seen = seen or {}
        if seen[root] then return nil end
        seen[root] = true
        for _, key in ipairs(keys) do
            local value = root[key]
            if type(value) == "number" or type(value) == "string" then return value end
        end
        for _, child in pairs(root) do
            if type(child) == "table" then
                local found = webLogDeepValue(child, keys, (depth or 0) + 1, seen)
                if found ~= nil then return found end
            end
        end
        return nil
    end

    local function webLogDurationSeconds(value)
        if type(value) == "number" then return math.max(0, value) end
        local text = tostring(value or "")
        local h = tonumber(text:match("(%d+)%s*[hH]")) or 0
        local m = tonumber(text:match("(%d+)%s*[mM]")) or 0
        local s = tonumber(text:match("(%d+)%s*[sS]")) or 0
        if h + m + s > 0 then return h * 3600 + m * 60 + s end
        local mm, ss = text:match("^(%d+):(%d%d)$")
        if mm then return tonumber(mm) * 60 + tonumber(ss) end
        local hh, min, sec = text:match("^(%d+):(%d%d):(%d%d)$")
        if hh then return tonumber(hh) * 3600 + tonumber(min) * 60 + tonumber(sec) end
        return tonumber(text)
    end

    local function webLogGetHatchMeta(record)
        if type(record) ~= "table" then return nil, nil end
        local assetInfo = HUB.WebLogFindAssetInfo(record)
        local remainingKeys = {
            "HatchTimeRemaining", "HatchRemaining", "TimeRemaining", "RemainingTime",
            "SecondsRemaining", "HatchSecondsRemaining", "TimeLeft", "HatchCountdown"
        }
        local endKeys = {
            "HatchEndTime", "HatchFinishTime", "HatchReadyAt", "ReadyAt", "FinishAt",
            "GrowEndTime", "GrowthEndTime", "HatchTimestamp", "HatchAt"
        }
        local duration = webLogDurationSeconds(webLogDeepValue(record, remainingKeys, 0))
        local rawEndValue = webLogDeepValue(record, endKeys, 0)
        local endValue = tonumber(rawEndValue) or webLogDurationSeconds(rawEndValue)
        local now = os.time()
        pcall(function()
            if Workspace and Workspace.GetServerTimeNow then
                now = Workspace:GetServerTimeNow()
            end
        end)
        local endAt
        if duration and duration >= 0 and duration < 864000 then
            endAt = now + duration
        elseif endValue then
            local value = endValue
            if value > 100000000000 then value = value / 1000 end
            -- A few versions store hatch time as a duration under HatchAt.
            endAt = value > 1000000000 and value or now + math.max(0, value)
        end
        if endAt == nil then
            local placedAt = webLogDeepNumber(record, { "PlacedAt", "CreatedAt", "StartedAt", "HatchStartedAt" }, 0)
            local hatchDuration = webLogDurationSeconds(webLogDeepNumber(record, { "HatchDuration", "GrowthTime", "GrowTime", "HatchTime" }, 0))
            if (not hatchDuration or hatchDuration <= 0) and assetInfo then
                hatchDuration = webLogDurationSeconds(webLogDeepNumber(assetInfo, {
                    "GrowthTime", "GrowTime", "HatchDuration", "HatchTime"
                }, 0))
            end
            if placedAt and hatchDuration and hatchDuration > 0 then
                if placedAt > 100000000000 then placedAt = placedAt / 1000 end
                if placedAt > 1000000000 then endAt = placedAt + hatchDuration end
            end
        end
        if endAt == nil then return nil, nil end
        return endAt, math.max(0, endAt - now)
    end

    local function webLogGetRecordMoneyRate(record)
        if type(record) ~= "table" then return nil end
        local rate = webLogDeepNumber(record, {
            "EarningRate", "IncomePerSecond", "MoneyPerSecond", "CashPerSecond", "ProductionPerSecond",
            "EarningsPerSecond", "IncomePerSec", "MoneyPerSec", "CashPerSec", "RatePerSecond"
        }, 0)
        if (not rate or rate <= 0) then
            local assetInfo = HUB.WebLogFindAssetInfo(record)
            if assetInfo then
                rate = webLogDeepNumber(assetInfo, {
                    "EarningRate", "IncomePerSecond", "MoneyPerSecond", "CashPerSecond",
                    "ProductionPerSecond", "EarningsPerSecond", "IncomePerSec", "MoneyPerSec",
                    "CashPerSec", "RatePerSecond"
                }, 0)
            end
        end
        return rate and rate > 0 and rate or nil
    end
    -- Reuse the same deep record/catalog resolver for Auto Steal's value-first
    -- sorter.  This keeps Web Log and the route on one earning-rate source.
    HUB.WebLogGetRecordMoneyRate = webLogGetRecordMoneyRate

    -- Robust upgrade-level resolver used by Web Log.
    -- Some builds keep the value under nested save keys, plot attributes,
    -- NumberValue/IntValue instances, or names such as "Treadmill_4".
    local function webLogNormalizeKey(v)
        return tostring(v or ""):lower():gsub("[^%w]", "")
    end

    local function webLogMatchesLevelKey(actual, keys)
        local n = webLogNormalizeKey(actual)
        for _, key in ipairs(keys) do
            local k = webLogNormalizeKey(key)
            if n == k or n:find(k, 1, true) or k:find(n, 1, true) then
                return true
            end
        end
        return false
    end

    local function webLogInstanceNumber(root, keys)
        if not root or typeof(root) ~= "Instance" then return nil end
        local attrs = root:GetAttributes()
        for attrName, attrValue in pairs(attrs) do
            if webLogMatchesLevelKey(attrName, keys) then
                local n = tonumber(attrValue)
                if n ~= nil then return n end
            end
        end
        if (root:IsA("IntValue") or root:IsA("NumberValue")) and webLogMatchesLevelKey(root.Name, keys) then
            return tonumber(root.Value)
        end
        local name = tostring(root.Name or "")
        if webLogMatchesLevelKey(name, keys) then
            local n = name:match("[Ll]evel[^%d]*(%d+)") or name:match("[Tt]ier[^%d]*(%d+)")
            if n then return tonumber(n) end
            n = name:match("_(%d+)$") or name:match("%-(%d+)$")
            if n then return tonumber(n) end
        end
        return nil
    end

    local function webLogScanInstanceLevel(root, keys, maxNodes)
        if not root or typeof(root) ~= "Instance" then return nil end
        local found
        local ok = pcall(function()
            local nodes = 0
            found = webLogInstanceNumber(root, keys)
            if found ~= nil then return end
            for _, obj in ipairs(root:GetDescendants()) do
                nodes += 1
                if nodes > (maxNodes or 3000) then break end
                found = webLogInstanceNumber(obj, keys)
                if found ~= nil then return end
            end
        end)
        return ok and found or nil
    end

    local function webLogFindNumber(root, keys)
        if type(root) ~= "table" then return 0 end
        local direct = webLogDirectNumber(root, keys)
        if direct ~= nil then return direct end
        for _, child in pairs(root) do
            if type(child) == "table" then
                local nested = webLogDirectNumber(child, keys)
                if nested ~= nil then return nested end
            end
        end
        return 0
    end

    -- Sum only fields that explicitly look like a per-second rate from the
    -- inventory records used by Auto Sell. This avoids treating item price/value
    -- as a rate by mistake.
    local function webLogSumPerSecondFromInventory(inv)
        if type(inv) ~= "table" then return 0 end
        local total = 0
        local rateKeys = {
            "IncomePerSecond", "MoneyPerSecond", "ProductionPerSecond",
            "ValuePerSecond", "PetsPerSecond", "EggsPerSecond",
            "PerSecond", "PerSec", "IncomePerSec", "ProductionPerSec"
        }

        for _, item in pairs(inv) do
            if type(item) == "table" then
                local value = webLogDirectNumber(item, rateKeys)
                if value == nil then
                    local stats = item.Stats or item.Stat or item.Income or item.Production
                    if type(stats) == "table" then
                        value = webLogDirectNumber(stats, rateKeys)
                    end
                end
                if value ~= nil and value > 0 then
                    total += value
                end
            end
        end
        return total
    end

    local function webLogGetCurrentEvent()
        local known = {
            "Hungry Monster", "Admin Abuse", "Sakura", "Monster Event", "Dragon Event",
            "Brainrot", "The Rift", "Rift Boss", "Rift", "Abyss", "Monster", "Dragon", "Event"
        }
        local keys = {
            "CurrentEvent", "CurrentEventName", "ActiveEvent", "EventName",
            "Event", "EventId", "EventID", "ActiveEventName"
        }

        local function normalize(v)
            if v == nil then return nil end
            v = tostring(v):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
            return v ~= "" and v or nil
        end

        local function consider(v)
            v = normalize(v)
            if not v then return nil end
            local lower = string.lower(v)
            if lower == "no event" or lower == "none" or lower == "nil" then return nil end
            if lower == "rift" or lower == "the rift" then return "The Rift" end
            if lower == "rift boss" or lower == "the rift boss" then return "The Rift Boss" end
            for _, k in ipairs(known) do
                if lower == string.lower(k) then return k end
            end
            return v
        end

        local function readInstance(inst)
            if not inst then return nil end
            local ok, attrs = pcall(inst.GetAttributes, inst)
            if ok and type(attrs) == "table" then
                for _, key in ipairs(keys) do
                    local got = consider(attrs[key])
                    if got then return got end
                end
            end
            for _, key in ipairs(keys) do
                local okChild, child = pcall(inst.FindFirstChild, inst, key, true)
                if okChild and child then
                    local okValue, value = pcall(function()
                        return child:IsA("StringValue") and child.Value or child:GetAttribute("Value")
                    end)
                    if okValue then
                        local got = consider(value)
                        if got then return got end
                    end
                end
            end
            return nil
        end

        for _, inst in ipairs({LP, LP.Character, Workspace, RS}) do
            local got = readInstance(inst)
            if got then return got end
        end

        -- The game often exposes the active event through a visible UI label.
        local gui = LP:FindFirstChildOfClass("PlayerGui")
        if gui then
            local found
            pcall(function()
                local scanned = 0
                for _, obj in ipairs(gui:GetDescendants()) do
                    scanned += 1
                    if scanned > 1200 then break end
                    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                        local text = tostring(obj.Text or "")
                        for _, k in ipairs(known) do
                            if string.find(string.lower(text), string.lower(k), 1, true) then
                                found = k
                                return
                            end
                        end
                    end
                end
            end)
            if found then return found end
        end

        return "No Event"
    end

    local function webLogGetInventoryCapacity(save, inventoryName, defaultCount)
        local keys = inventoryName == "Egg" and {
            "EggCapacity", "EggInventoryCapacity", "MaxEggs", "MaxEggInventory", "EggLimit", "MaxEggCapacity"
        } or {
            "PetCapacity", "InventoryCapacity", "MaxPets", "MaxInventory", "PetLimit", "MaxPetCapacity"
        }

        local found = webLogFindNumber(save, keys)
        if found > 0 then return found end

        -- Fallback: look for UI text such as "89 / 100" or "89/100".
        local gui = LP:FindFirstChildOfClass("PlayerGui")
        if gui then
            local best = 0
            local ok = pcall(function()
                for _, obj in ipairs(gui:GetDescendants()) do
                    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                        local txt = tostring(obj.Text or "")
                        local cur, cap = txt:match("(%d+)%s*/%s*(%d+)")
                        if cur and cap and tonumber(cap) > best then
                            best = tonumber(cap)
                        end
                    end
                end
            end)
            if ok and best > 0 then return best end
        end
        return defaultCount
    end

    local WEBLOG_RARITY_COLORS = {
        Titan='#FF2D55', Divine='#FF1493', Transcendent='#FF1493', Superior='#FF1493',
        Eternal='#8B5CF6', Limited='#F43F5E', Secret='#7C3AED', Exotic='#A855F7',
        Cosmic='#06B6D4', Exclusive='#14B8A6', Admin='#EF4444', Mythic='#EC4899',
        Mythical='#EC4899', Prismatic='#F59E0B', Rainbow='#F59E0B', ['Squishy God']='#F59E0B',
        BrainrotGod='#F59E0B', Legendary='#FBBF24', Epic='#A855F7', Rare='#3B82F6',
        SuperRare='#60A5FA', Celestial='#22D3EE', Uncommon='#22C55E', Basic='#94A3B8',
        Common='#9CA3AF', Unknown='#6B7280'
    }

    local function webLogGetAssetName(category)
        if type(category) ~= 'string' or category == '' then return 'Unknown Egg' end
        if AssetsData then
            local dir = AssetsData.Directory or AssetsData
            local info = type(dir) == 'table' and dir[category]
            if type(info) == 'table' then
                local name = info.DisplayName or info.Name or info.PetName or info.AssetName
                if type(name) == 'string' and name ~= '' then return name end
            end
        end
        return category
    end

    -- Only send an image when the game explicitly labels it as egg art. The
    -- generic Icon/Image fields often point at the hatched pet, so forwarding
    -- them makes a web log card show an animal instead of its egg.
    local function webLogGetEggImageUrl(record)
        if type(record) ~= 'table' then return '' end
        local function normalizeIcon(value)
            local contentId = tostring(value or '')
            local assetId = contentId:match('^rbxassetid://(%d+)$') or contentId:match('^(%d+)$')
            if assetId then return 'rbxassetid://' .. assetId end
            if contentId:match('^rbxthumb://') then return contentId end
            return ''
        end
        local function iconFrom(info)
            if type(info) ~= 'table' then return '' end
            local egg = type(info.Egg) == 'table' and info.Egg or {}
            local explicit = info.EggIcon or info.EggImage or info.EggThumbnail
                or egg.EggIcon or egg.EggImage or egg.EggThumbnail
            local markedEgg = info.IsEgg == true or egg.IsEgg == true
                or tostring(info.AssetType or info.CategoryType or ''):lower():find('egg', 1, true)
            return normalizeIcon(explicit or (markedEgg and (info.Icon or info.Image or info.Thumbnail or egg.Icon or egg.Image or egg.Thumbnail)))
        end

        local direct = iconFrom(record)
        if direct ~= '' then return direct end
        local dir = AssetsData and (AssetsData.Directory or AssetsData)
        if type(dir) ~= 'table' then return '' end
        for _, id in ipairs({ record.AssetCategory, record.Category, record.EggName, record.AssetId, record.EggId, record.Id, record.Name }) do
            if id ~= nil then
                local info = dir[id]
                if info == nil then
                    local wanted = string.lower(tostring(id))
                    for key, value in pairs(dir) do
                        if string.lower(tostring(key)) == wanted then info = value break end
                    end
                end
                local icon = iconFrom(info)
                if icon ~= '' then return icon end
            end
        end
        return ''
    end

    local WEBLOG_RARITY_SCORE = {
        Titan=1000, Divine=950, Transcendent=925, Superior=900, Eternal=875,
        Limited=850, Secret=825, Exotic=800, Cosmic=775, Exclusive=750,
        Admin=725, Mythic=700, Mythical=700, Prismatic=675, Rainbow=650,
        ['Squishy God']=625, BrainrotGod=625, Legendary=600, Epic=500, Rare=400,
        SuperRare=350, Celestial=325, Uncommon=200, Basic=100, Common=50,
    }

    local function webLogCanonicalRarity(value)
        if type(value) == 'table' then
            value = value.DisplayName or value.Name or value._id or value.Id
                or value.RarityName or value.Value or value.Rarity
        end
        if value == nil then return nil end
        local text = tostring(value)
        if text == '' or text == 'nil' then return nil end
        local key = string.lower(text):gsub('[%s_%-]+', '')
        local aliases = {
            titan='Titan', divine='Divine', transcendent='Transcendent', superior='Superior',
            eternal='Eternal', ethereal='Eternal', etheral='Eternal', limited='Limited', secret='Secret', exotic='Exotic', cosmic='Cosmic',
            exclusive='Exclusive', admin='Admin', mythic='Mythic', mythical='Mythical', prismatic='Prismatic',
            rainbow='Rainbow', ['squishygod']='Squishy God', brainrotgod='BrainrotGod', legendary='Legendary',
            epic='Epic', rare='Rare', superrare='SuperRare', celestial='Celestial', uncommon='Uncommon',
            basic='Basic', common='Common',
        }
        return aliases[key] or text
    end

    local function webLogFindRarityInTable(root, depth)
        if type(root) ~= 'table' or (depth or 0) > 2 then return nil end
        local directKeys = { 'Rarity', 'RarityName', 'RarityType', 'RarityId', 'DisplayRarity' }
        for _, key in ipairs(directKeys) do
            local v = root[key]
            local name = webLogCanonicalRarity(v)
            if name and WEBLOG_RARITY_SCORE[name] then return name end
            if type(v) == 'table' then
                local nested = webLogFindRarityInTable(v, (depth or 0) + 1)
                if nested then return nested end
            end
        end
        local attrs = root.Attributes
        if type(attrs) == 'table' then
            local nested = webLogFindRarityInTable(attrs, (depth or 0) + 1)
            if nested then return nested end
        end
        return nil
    end

    local function webLogLookupRarityByCatalog(record)
        local identifiers = {
            record and record.AssetCategory, record and record.Category, record and record.EggName,
            record and record.AssetId, record and record.EggId, record and record.Id, record and record.Name,
        }
        local dir = AssetsData and (AssetsData.Directory or AssetsData)
        if type(dir) == 'table' then
            for _, id in ipairs(identifiers) do
                if id ~= nil then
                    local info = dir[id]
                    if info == nil then
                        local wanted = string.lower(tostring(id))
                        for k, v in pairs(dir) do
                            if string.lower(tostring(k)) == wanted then info = v; break end
                        end
                    end
                    local rarity = webLogFindRarityInTable(info, 0)
                    if rarity then return rarity end
                end
            end
        end
        return nil
    end

    local function webLogLookupRarityByNumber(record)
        local number = nil
        if type(record) == 'table' then
            number = tonumber(record.RarityNumber or record.RarityId or record.Rarity)
            if type(record.Rarity) == 'table' then number = tonumber(record.Rarity.RarityNumber or record.Rarity.Id or record.Rarity.id) end
            local attrs = record.Attributes
            if number == nil and type(attrs) == 'table' then number = tonumber(attrs.RarityNumber or attrs.RarityId or attrs.Rarity) end
        end
        if number == nil or not RarityData then return nil end
        local tab = RarityData.Rarities or RarityData
        if type(tab) ~= 'table' then return nil end
        for k, v in pairs(tab) do
            if type(v) == 'table' then
                local n = tonumber(v.RarityNumber or v.Number or v.Id or v._id)
                if n and n == number then
                    local name = webLogCanonicalRarity(v.DisplayName or v.Name or v._id or k)
                    if name then return name end
                end
            end
            if tonumber(k) == number then
                local name = webLogCanonicalRarity(v)
                if name then return name end
            end
        end
        return nil
    end

    local function webLogGetRarity(record)
        local name = webLogFindRarityInTable(record, 0)
        name = name or webLogLookupRarityByCatalog(record)
        name = name or webLogLookupRarityByNumber(record)
        name = name or 'Unknown'

        local color = WEBLOG_RARITY_COLORS[name]
        if not color then
            local lower = string.lower(name)
            for k,v in pairs(WEBLOG_RARITY_COLORS) do
                if string.lower(k) == lower then color = v; name = k; break end
            end
        end
        return name, color or WEBLOG_RARITY_COLORS.Unknown
    end

    local function webLogGetMutation(record)
        if type(record) ~= 'table' then return 'Normal' end
        local muts = record.Mutations
        if type(muts) == 'table' then
            local out = {}
            for _, m in ipairs(muts) do if type(m) == 'string' and m ~= '' then table.insert(out, m) end end
            if #out > 0 then return table.concat(out, ', ') end
        end
        local m = record.Mutation or record.BaseMutation
        return type(m) == 'string' and m ~= '' and m or 'Normal'
    end

    -- Resolve the amount an egg is expected to give at its final grow-up.
    -- Prefer explicit final/grow/hatch/payout fields on the saved egg, then
    -- inspect its asset definition. This is deliberately separate from Price so
    -- the Web Log does not confuse purchase price with final value.
    local function webLogGetFinalEggValue(record)
        if type(record) ~= 'table' then return nil end
        local preferredKeys = {
            'FinalValue', 'FinalWorth', 'GrowUpValue', 'GrowValue', 'GrowthValue',
            'HatchValue', 'HatchWorth', 'PetValue', 'AnimalValue', 'RewardValue',
            'Payout', 'PayoutValue', 'SellValue', 'SellWorth', 'Worth', 'Value'
        }
        local function read(root, depth, seen)
            if type(root) ~= 'table' or (depth or 0) > 4 then return nil end
            seen = seen or {}
            if seen[root] then return nil end
            seen[root] = true
            for _, key in ipairs(preferredKeys) do
                local v = root[key]
                local n
                if type(v) == 'number' then n = v
                elseif type(v) == 'string' then n = tonumber(v) end
                if n and n >= 0 and n < math.huge then return n end
                if type(v) == 'table' then
                    local nested = read(v, (depth or 0) + 1, seen)
                    if nested ~= nil then return nested end
                end
            end
            for _, key in ipairs({'Pet', 'Animal', 'Result', 'Reward', 'Hatch', 'Grow', 'Growth', 'Output'}) do
                local v = root[key]
                if type(v) == 'table' then
                    local nested = read(v, (depth or 0) + 1, seen)
                    if nested ~= nil then return nested end
                end
            end
            return nil
        end

        local direct = read(record, 0)
        if direct ~= nil then return direct end

        local dir = AssetsData and (AssetsData.Directory or AssetsData)
        if type(dir) == 'table' then
            local ids = {
                record.AssetCategory, record.Category, record.EggName,
                record.AssetId, record.EggId, record.Id, record.Name
            }
            for _, id in ipairs(ids) do
                if id ~= nil then
                    local info = dir[id]
                    if info == nil then
                        local wanted = string.lower(tostring(id))
                        for k, v in pairs(dir) do
                            if string.lower(tostring(k)) == wanted then info = v break end
                        end
                    end
                    local assetValue = read(info, 0)
                    if assetValue ~= nil then return assetValue end
                end
            end
        end
        return nil
    end

    -- Share the same final-value resolver with Auto Steal.  This keeps the
    -- Web Log card and the steal priority on one source of truth: explicit
    -- final/grow/hatch/sell value first, never the purchase Price field.
    HUB.WebLogGetFinalEggValue = webLogGetFinalEggValue


    local WEBLOG_AREA_ALIASES = {
        -- NormalizeAreaIdKey("Angels & Darks") removes punctuation and
        -- produces "angelsdarks". Keep older spellings for old records.
        angelsdarks = "Angels & Darks",
        angelsanddarks = "Angels & Darks",
        angelsdemons = "Angels & Darks",
        angelsanddemons = "Angels & Darks",
        lightdark = "Angels & Darks",
    }

    local function webLogAreaLabel(area)
        local raw = tostring(area or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if raw == "" then return "Unknown Area" end
        local key = string.lower(raw):gsub("[^%w]+", "")
        return WEBLOG_AREA_ALIASES[key] or raw
    end

    local function webLogSetLastStolenEgg(record)
        if type(record) ~= 'table' then return end
        local rarity, color = webLogGetRarity(record)
        webLogLatestStolenEgg = {
            name = webLogGetAssetName(record.AssetCategory or record.EggName or record.Name),
            imageUrl = webLogGetEggImageUrl(record),
            rarity = rarity,
            rarityColor = color,
            mutation = webLogGetMutation(record),
            finalValue = webLogGetFinalEggValue(record),
            area = webLogAreaLabel(GetEggAreaId(record) or record.AreaId),
            stolenAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }
    end

    local function webLogSetActivity(activity, detail)
        webLogActivity = tostring(activity or "Idle")
        webLogActivityDetail = tostring(detail or "")
        webLogLastActivityAt = os.clock()
    end

    local function webLogSetArea(area)
        webLogCurrentArea = webLogAreaLabel(area)
    end

    local function webLogSetEvent(name, detail, status)
        local value = tostring(name or ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        webLogEventName = value ~= "" and value or nil
        webLogEventDetail = tostring(detail or "")
        webLogEventStatus = tostring(status or (webLogEventName and "active" or "idle"))
        webLogEventUpdatedAt = os.clock()
    end

    local function webLogBuildEggItems(inv)
        if type(inv) ~= "table" then return {} end
        local out = {}
        local grouped = {}
        for uid, eggData in pairs(inv) do
            if type(eggData) == "table" then
                local name = webLogGetAssetName(eggData.AssetCategory or eggData.EggName or eggData.Name)
                local rarity, color = webLogGetRarity(eggData)
                local mutation = webLogGetMutation(eggData)
                local hatchEndAt, hatchRemainingSeconds = webLogGetHatchMeta(eggData)
                local moneyPerSecond = webLogGetRecordMoneyRate(eggData)
                local key = tostring(name) .. "|" .. tostring(rarity) .. "|" .. tostring(mutation)
                if not grouped[key] then
                    grouped[key] = {
                        name = name,
                        imageUrl = webLogGetEggImageUrl(eggData),
                        rarity = rarity,
                        rarityColor = color,
                        mutation = mutation,
                        finalValue = webLogGetFinalEggValue(eggData),
                        moneyPerSecond = moneyPerSecond,
                        hatchEndAt = hatchEndAt,
                        hatchRemainingSeconds = hatchRemainingSeconds,
                        count = 0
                    }
                    table.insert(out, grouped[key])
                else
                    local fv = webLogGetFinalEggValue(eggData)
                    if grouped[key].finalValue == nil and fv ~= nil then
                        grouped[key].finalValue = fv
                    end
                    if grouped[key].imageUrl == '' then grouped[key].imageUrl = webLogGetEggImageUrl(eggData) end
                    if grouped[key].moneyPerSecond == nil and moneyPerSecond ~= nil then grouped[key].moneyPerSecond = moneyPerSecond end
                    if hatchEndAt ~= nil and (grouped[key].hatchEndAt == nil or hatchEndAt < grouped[key].hatchEndAt) then
                        grouped[key].hatchEndAt = hatchEndAt
                        grouped[key].hatchRemainingSeconds = hatchRemainingSeconds
                    end
                end
                grouped[key].count += math.max(1, tonumber(eggData.Amount or eggData.Quantity or eggData.Count) or 1)
            end
        end
        table.sort(out, function(a,b) return tostring(a.name) < tostring(b.name) end)
        if #out > 80 then
            while #out > 80 do table.remove(out) end
        end
        return out
    end

    local function webLogGetPlayer()
        local player = LP
        if player and player.Parent then return player end
        local ok, current = pcall(function() return Players.LocalPlayer end)
        if ok and current then
            LP = current
            return current
        end
        return nil
    end

    local function webLogFindNumberDeep(root, keys, depth, seen)
        if type(root) ~= "table" or (depth or 0) > 7 then return nil end
        seen = seen or {}
        if seen[root] then return nil end
        seen[root] = true

        local direct = webLogDirectNumber(root, keys)
        if direct ~= nil then return direct end
        for _, child in pairs(root) do
            if type(child) == "table" then
                local found = webLogFindNumberDeep(child, keys, (depth or 0) + 1, seen)
                if found ~= nil then return found end
            end
        end
        return nil
    end

    local function webLogExtractLevelText(text, context, keywords)
        text = tostring(text or ""):gsub("%s+", " ")
        context = tostring(context or ""):lower()
        local lower = text:lower()
        local relevant = false
        for _, word in ipairs(keywords) do
            if lower:find(word, 1, true) or context:find(word, 1, true) then
                relevant = true
                break
            end
        end
        if not relevant then return nil end
        local level = text:match("[Ll]evel%s*[:#%-]?%s*(%d+)")
            or text:match("[Tt]ier%s*[:#%-]?%s*(%d+)")
            or text:match("[%[%(]%s*(%d+)%s*[%]%)]")
        return level and tonumber(level) or nil
    end

    local function webLogFindContextualLevel(root, kind, depth, seen)
        if type(root) ~= "table" or (depth or 0) > 8 then return nil end
        seen = seen or {}
        if seen[root] then return nil end
        seen[root] = true

        local contextWords = kind == "treadmill"
            and {"treadmill", "training", "speed"}
            or {"base", "homestead", "plot"}

        for key, child in pairs(root) do
            if type(child) == "table" then
                local keyText = tostring(key):lower()
                local contextual = false
                for _, word in ipairs(contextWords) do
                    if keyText:find(word, 1, true) then contextual = true break end
                end
                if contextual then
                    local n = webLogDirectNumber(child, {"Level", "Tier", "UpgradeLevel", "UpgradeTier"})
                    if n ~= nil then return n end
                    n = webLogFindNumberDeep(child, {"Level", "Tier"}, 0)
                    if n ~= nil then return n end
                end
                local nested = webLogFindContextualLevel(child, kind, (depth or 0) + 1, seen)
                if nested ~= nil then return nested end
            end
        end
        return nil
    end

    local function webLogScanContextualInstanceLevel(root, kind, maxNodes)
        if not root or typeof(root) ~= "Instance" then return nil end
        local words = kind == "treadmill" and {"treadmill", "training", "speed"} or {"base", "homestead", "plot"}
        local found
        local ok = pcall(function()
            local nodes = 0
            for _, obj in ipairs(root:GetDescendants()) do
                nodes += 1
                if nodes > (maxNodes or 3500) then break end
                local parentText = obj.Parent and tostring(obj.Parent.Name):lower() or ""
                local objText = tostring(obj.Name or ""):lower()
                local contextual = false
                for _, word in ipairs(words) do
                    if parentText:find(word, 1, true) or objText:find(word, 1, true) then contextual = true break end
                end
                if contextual then
                    if obj:IsA("IntValue") or obj:IsA("NumberValue") then
                        if objText == "level" or objText == "tier" or objText:find("upgrade", 1, true) then
                            found = tonumber(obj.Value)
                            if found ~= nil then return end
                        end
                    end
                    local attrs = obj:GetAttributes()
                    for attrName, attrValue in pairs(attrs) do
                        local a = tostring(attrName):lower():gsub("[^%w]", "")
                        if a == "level" or a == "tier" or a == "upgradelevel" or a == "upgradetier" then
                            local n = tonumber(attrValue)
                            if n ~= nil then found = n return end
                        end
                    end
                end
            end
        end)
        return ok and found or nil
    end

    local function webLogGetUpgradeLevel(save, kind)
        local baseKeys = {
            "BaseLevel", "BaseTier", "HomesteadLevel", "HomesteadTier",
            "PlotLevel", "PlotTier", "BaseUpgradeLevel", "BaseUpgradeTier"
        }
        local treadmillKeys = {
            "TreadmillLevel", "TreadmillTier", "TreadmillUpgradeLevel",
            "TreadmillUpgradeTier", "TrainingLevel", "TrainingTier", "SpeedTier",
            "Treadmill", "Training"
        }
        local keys = kind == "treadmill" and treadmillKeys or baseKeys

        -- SaveModule is the most authoritative source when the game exposes it.
        local found = webLogFindNumberDeep(save, keys, 0)
        if found ~= nil then return math.max(0, math.floor(found)) end

        -- PlotState can expose the live plot as a Lua table or as its backing Instance.
        local contextual = webLogFindContextualLevel(save, kind, 0)
        if contextual ~= nil then return math.max(0, math.floor(contextual)) end

        local plotObj
        pcall(function()
            plotObj = PlotState and PlotState.ResolvePlot and PlotState.ResolvePlot()
        end)
        if type(plotObj) == "table" then
            found = webLogFindNumberDeep(plotObj, keys, 0)
            if found ~= nil then return math.max(0, math.floor(found)) end
            for k, v in pairs(plotObj) do
                if webLogMatchesLevelKey(k, keys) then
                    local n = tonumber(v)
                    if n ~= nil then return math.max(0, math.floor(n)) end
                end
            end
        end

        local plotFolder = plotObj and plotObj.PlotFolder
        if plotFolder and typeof(plotFolder) == "Instance" then
            found = webLogScanInstanceLevel(plotFolder, keys, 3500)
            if found ~= nil then return math.max(0, math.floor(found)) end
            found = webLogScanContextualInstanceLevel(plotFolder, kind, 3500)
            if found ~= nil then return math.max(0, math.floor(found)) end
        end

        -- Fallback: search the player GUI for explicit "Level N" / "Tier N" labels.
        local gui = LP and LP:FindFirstChildOfClass("PlayerGui")
        if gui then
            local keywords = kind == "treadmill" and {"treadmill", "training", "speed"} or {"base", "homestead", "plot"}
            local result
            pcall(function()
                local scanned = 0
                for _, obj in ipairs(gui:GetDescendants()) do
                    scanned += 1
                    if scanned > 3500 then break end
                    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                        local parentName = obj.Parent and obj.Parent.Name or ""
                        result = webLogExtractLevelText(obj.Text, parentName, keywords)
                        if result ~= nil then return end
                        if obj.Parent and obj.Parent:IsA("GuiObject") then
                            result = webLogExtractLevelText(obj.Parent.Name, obj.Text, keywords)
                            if result ~= nil then return end
                        end
                    end
                end
            end)
            if result ~= nil then return math.max(0, math.floor(result)) end
        end

        return 0
    end

    local function webLogGetSnapshot()
        local player = webLogGetPlayer()
        if not player then return nil, "local_player_not_ready" end

        local accountName = tostring(player.Name or "")
        local displayName = tostring(player.DisplayName or accountName)
        if accountName == "" or accountName == "nil" then
            return nil, "account_name_not_ready"
        end
        if displayName == "" or displayName == "nil" then displayName = accountName end

        local save
        pcall(function()
            if SaveModule and type(SaveModule.Get) == "function" then
                save = SaveModule.Get()
            end
        end)

        local eggInventory = type(save) == "table" and save.EggInventory or {}
        local petInventory = type(save) == "table" and save.Inventory or {}
        local money = type(save) == "table" and tonumber(save.Money) or 0
        local moneyPerSecond = webLogFindNumberDeep(save, {
            "MoneyPerSecond", "IncomePerSecond", "CashPerSecond", "EarningsPerSecond",
            "MoneyPerSec", "IncomePerSec", "CashPerSec", "MoneyRate", "CashRate"
        }, 0) or 0

        local speed = webLogFindNumber(save, {
            "Speed", "CurrentSpeed", "SpeedPower", "SpeedValue"
        })
        if speed == nil then
            local hum = findHum()
            speed = hum and tonumber(hum.WalkSpeed) or 0
        end

        -- Speed is the live signal used by the game while treadmill training
        -- is active. Keep a short rise window so the dashboard reflects the
        -- same activity even when the UI callback has not updated yet.
        local now = os.clock()
        local speedState = HUB.WebLogSpeedState or { last = nil, trainingUntil = 0 }
        local speedNow = tonumber(speed) or 0
        local speedRose = speedState.last ~= nil and speedNow > tonumber(speedState.last) + 0.01
        if speedRose then speedState.trainingUntil = now + 4 end
        speedState.last = speedNow
        speedState.current = speedNow
        HUB.WebLogSpeedState = speedState

        -- Prefer explicit per-second values stored on inventory records.
        local petsPerSecond = webLogSumPerSecondFromInventory(petInventory)
        local eggsPerSecond = webLogSumPerSecondFromInventory(eggInventory)

        -- Fallback for eggs: successful steals are directly observable by this hub.
        if eggsPerSecond <= 0 and webLogLastEggs ~= nil and webLogLastAt ~= nil then
            local dt = now - webLogLastAt
            if dt > 0 then
                eggsPerSecond = math.max(0, (webLogEggsStolen - webLogLastEggs) / dt)
            end
        end

        -- Fallback for pets: use successful hatch count if no per-second inventory
        -- field exists in the game data.
        local petsHatched = webLogFindNumber(save, {
            "PetsHatched", "PetHatchedCount", "HatchedPets"
        })
        if petsPerSecond <= 0 and webLogLastPets ~= nil and webLogLastAt ~= nil then
            local dt = now - webLogLastAt
            if dt > 0 then
                petsPerSecond = math.max(0, (petsHatched - webLogLastPets) / dt)
            end
        end

        webLogLastEggs = webLogEggsStolen
        webLogLastPets = petsHatched
        webLogLastAt = now
        webLogLastEggRate = eggsPerSecond
        webLogLastPetRate = petsPerSecond

        local eggCount = webLogCountTable(eggInventory)
        local petCount = webLogCountTable(petInventory)

        -- Resolve the actual upgrade values for the Web Log instead of sending 0.
        local baseLevel = webLogGetUpgradeLevel(save, "base")
        local treadmillLevel = webLogGetUpgradeLevel(save, "treadmill")

        local activity = webLogActivity
        local activityDetail = webLogActivityDetail
        if speedState.trainingUntil > now then
            activity = "Training on Treadmill"
            activityDetail = "Speed increased; treadmill training detected"
        end

        return {
            account = accountName,
            username = accountName,
            displayName = displayName,
            device = webLogGetDevice(),
            pc = nil,
            money = money or 0,
            moneyPerSecond = math.max(0, tonumber(moneyPerSecond) or 0),
            speed = speed or 0,
            baseLevel = baseLevel,
            treadmillLevel = treadmillLevel,
            eggInventory = eggCount,
            eggCapacity = webLogGetInventoryCapacity(save, "Egg", eggCount),
            petInventory = petCount,
            petCapacity = webLogGetInventoryCapacity(save, "Pet", petCount),
            eggItems = webLogBuildEggItems(eggInventory),
            eggsStolen = webLogEggsStolen,
            petsHatched = petsHatched,
            currentEvent = webLogEventName or webLogGetCurrentEvent(),
            currentArea = webLogCurrentArea ~= "" and webLogCurrentArea or (webLogLatestStolenEgg and webLogLatestStolenEgg.area or ""),
            activity = activity,
            activityDetail = activityDetail,
            eventDetail = webLogEventDetail,
            eventStatus = webLogEventStatus,
            eventUpdatedAt = webLogEventUpdatedAt,
            latestStolenEgg = webLogLatestStolenEgg,
            jobId = game.JobId,
            placeId = tostring(game.PlaceId),
            uptimeSeconds = math.floor(os.clock()),
        }
    end

    local function webLogSend()
        -- Gate every send path (periodic loop, public Send API, and fallback)
        -- before reading snapshots or making any HTTP request.
        if not HUB.IsWebLogPremium() then
            return false, "premium_required"
        end
        local cfg = webLogConfigSnapshot()
        if not cfg.Enabled then
            return false, "disabled"
        end
        local weblogUrl = cfg.URL
        local weblogKey = cfg.Key
        if type(WebLogRequest) ~= "function" then
            if not webLogPrintedSite then
                webLogPrintedSite = true
                warn("[Axel Web Log] No executor HTTP request function found. Use an executor that exposes syn.request/http_request/request.")
            end
            return false, "http_request_unavailable"
        end
        local payload, snapshotErr = webLogGetSnapshot()
        if type(payload) ~= "table" then
            if snapshotErr and snapshotErr ~= "account_name_not_ready" and not webLogPrintedSite then
                warn("[Axel Web Log] Snapshot unavailable: " .. tostring(snapshotErr))
            end
            return false, snapshotErr
        end
        local body
        local okEncode = pcall(function() body = HttpService:JSONEncode(payload) end)
        if not okEncode or type(body) ~= "string" then return false end

        if weblogKey == "PASTE_YOUR_PERSONAL_TELEMETRY_KEY" or weblogKey == "" then
            if cfg.Debug then
                warn("[Axel Web Log] Missing personal telemetry key. Set getgenv().AxelWebLogConfig.Key.")
            end
            return false, "missing_telemetry_key"
        end

        -- Ask the endpoint to return a body so executors that expose only a sparse
        -- response table still give us a reliable success status (204 is also
        -- accepted below).
        -- Use the WebLog endpoint from the live config. `url` belongs to the
        -- Discord webhook tab and is not available in this scope; referencing
        -- it here made every telemetry cycle fail before the HTTP request.
        local sendUrl = weblogUrl
        if not sendUrl:find("?", 1, true) then
            sendUrl = sendUrl .. "?wait=true"
        elseif not sendUrl:lower():find("wait=", 1, true) then
            sendUrl = sendUrl .. "&wait=true"
        end
        local function doPost(postUrl)
            return WebLogRequest({
                Url = postUrl,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["x-axel-api-key"] = weblogKey,
                },
                Body = body,
            })
        end

        local ok, response = pcall(doPost, sendUrl)
        -- Cloudflare fallback uses the public Axel Hub WebLog endpoint.
        if not ok and cfg.LocalFallback and not weblogUrl:find("127%.0%.0%.1:3000", 1, false) and not weblogUrl:find("localhost:3000", 1, false) then
            local fallbackUrl = "https://axelhub-weblog.originalpro.workers.dev/api/telemetry"
            local okFallback, fallbackResponse = pcall(doPost, fallbackUrl)
            if okFallback then
                ok, response = true, fallbackResponse
                weblogUrl = fallbackUrl
            end
        end
        if not ok then
            warn("[Axel Web Log] POST failed: " .. tostring(response))
            return false, response
        end
        local status = type(response) == "table"
            and tonumber(response.StatusCode or response.status or response.Status or response.code)
            or nil
        if status and (status < 200 or status >= 300) then
            local rawError = type(response) == "table" and response.Body or nil
            warn("[Axel Web Log] Server rejected telemetry (HTTP " .. tostring(status) .. ")" .. (type(rawError) == "string" and (": " .. rawError) or ""))
            return false, response
        end
        if not webLogPrintedSite then
            webLogPrintedSite = true
            local raw = type(response) == "table" and response.Body or nil
            if type(raw) == "string" then
                local siteId = raw:match('"siteId"%s*:%s*"([%w_%-]+)"')
                local receivedAccount = raw:match('"account"%s*:%s*"([^"\n]-)"')
                if receivedAccount then
                    print("[Axel Web Log] Account sent: " .. receivedAccount)
                else
                    print("[Axel Web Log] Account sent: " .. tostring(payload.account))
                end
                print("[Axel Web Log] Dashboard: " .. weblogUrl:gsub("/api/telemetry$", ""))
            end
        end
        return ok, response
    end

    _G.AxelWebLog = {
        Send = webLogSend,
        GetConfig = function()
            return webLogConfigSnapshot()
        end,
        SetConfig = function(name, value)
            if type(name) ~= "string" then return false end
            if AXEL_WEBLOG_DEFAULTS[name] == nil then return false end
            webLogSetConfigField(name, value)
            return true
        end,
        SetActivity = function(activity, detail)
            webLogSetActivity(activity, detail)
        end,
        GetActivityAge = function()
            return math.max(0, os.clock() - webLogLastActivityAt)
        end,
        AddEggStolen = function(amount)
            webLogEggsStolen += tonumber(amount) or 1
        end,
        SetLastStolenEgg = function(record)
            webLogSetLastStolenEgg(record)
        end,
        SetArea = function(area)
            webLogSetArea(area)
        end,
        SetEvent = function(name, detail, status)
            webLogSetEvent(name, detail, status)
        end,
    }

    task.spawn(function()
        task.wait(2)
        while not HUB.dead do
            pcall(webLogSend)
            local cfg = webLogConfigSnapshot()
            task.wait(cfg.Interval)
        end
    end)
end

-- Suji resolves remotes from Shared.Remotes first and only then falls back to
-- the replicated folders.  The old Axel adapter only checked one direct
-- child under Packages.Networking, so a game update that moved the remotes
-- into a group table made every action silently return "remote unavailable".
-- Keep the resolver on HUB to avoid adding locals to the large top-level
-- compiler scope, and cache only live Instances.
HUB.NetworkRemoteCache = HUB.NetworkRemoteCache or {}
HUB.ResolveNetworkRemote = function(requested)
    local request = tostring(requested or "")
    if request == "" then return nil end

    local cached = HUB.NetworkRemoteCache[request]
    if cached and cached.Parent then return cached end

    local compact = request:gsub("^%a+[/:]", "")
    local tokens = {}
    for token in compact:gmatch("[^/:]+") do
        tokens[#tokens + 1] = string.lower(token)
    end
    local remoteName = tokens[#tokens] or ""
    local groupName = tokens[#tokens - 1] or ""
    if remoteName == "" then return nil end

    local wantedKind = string.lower(request:match("^(%a+)[/:]") or "")
    local function isRemote(value)
        return typeof(value) == "Instance"
            and (value:IsA("RemoteFunction") or value:IsA("RemoteEvent"))
            and (wantedKind == "" or (wantedKind == "rf" and value:IsA("RemoteFunction"))
                or (wantedKind == "re" and value:IsA("RemoteEvent")))
    end
    local function accept(value)
        if isRemote(value) then
            HUB.NetworkRemoteCache[request] = value
            return value
        end
        return nil
    end

    -- Direct paths used by older builds.
    local packages = RS:FindFirstChild("Packages")
    local networking = packages and packages:FindFirstChild("Networking")
    if networking then
        local direct = accept(networking:FindFirstChild(request))
            or accept(networking:FindFirstChild(remoteName))
        if direct then return direct end
    end
    local network = RS:FindFirstChild("Network")
    if network then
        local direct = accept(network:FindFirstChild(groupName ~= "" and (groupName .. ": " .. remoteName) or remoteName))
            or accept(network:FindFirstChild(remoteName))
        if direct then return direct end
    end

    -- This is the same source-of-truth used by Suji.  Its keys are not
    -- necessarily the same as the physical Instance path.
    local best, bestScore = nil, -math.huge
    pcall(function()
        local remotes = require(RS.Shared.Remotes)
        if type(remotes) ~= "table" then return end
        for group, entries in pairs(remotes) do
            if type(entries) ~= "table" then continue end
            local groupKey = string.lower(tostring(group))
            local groupMatch = groupName == "" or groupKey == groupName
                or groupKey:find(groupName, 1, true) ~= nil
                or groupName:find(groupKey, 1, true) ~= nil
            for remote, instance in pairs(entries) do
                if isRemote(instance) then
                    local key = string.lower(tostring(remote))
                    if key == remoteName or key:find(remoteName, 1, true) ~= nil
                        or remoteName:find(key, 1, true) ~= nil then
                        local score = (key == remoteName and 100 or 40) + (groupMatch and 50 or 0)
                        if score > bestScore then
                            best, bestScore = instance, score
                        end
                    end
                end
            end
        end
    end)
    if best then
        HUB.NetworkRemoteCache[request] = best
        return best
    end

    -- Final compatibility pass for builds that expose the Instance but not
    -- the Shared.Remotes table. Prefer a remote whose parent chain contains
    -- the requested group; do not pick a wrong-kind remote.
    pcall(function()
        for _, instance in ipairs(RS:GetDescendants()) do
            if isRemote(instance) then
                local key = string.lower(tostring(instance.Name or ""))
                if key == remoteName then
                    local parentMatch = false
                    local parent = instance.Parent
                    for _ = 1, 5 do
                        if not parent then break end
                        local parentKey = string.lower(tostring(parent.Name or ""))
                        if groupName ~= "" and (parentKey == groupName or parentKey:find(groupName, 1, true) ~= nil) then
                            parentMatch = true
                            break
                        end
                        parent = parent.Parent
                    end
                    if parentMatch then
                        best, bestScore = instance, 100
                        break
                    elseif not best then
                        best = instance
                    end
                end
            end
        end
    end)
    if best then
        HUB.NetworkRemoteCache[request] = best
        return best
    end
    return nil
end

local function GetNetRemote(name)
    return HUB.ResolveNetworkRemote(name)
end

local function GetLocalSlot()
    if PlotState and PlotState.ResolveLocalSlot then
        local ok, slot = pcall(PlotState.ResolveLocalSlot)
        if ok and slot then return slot end
    end
    return 1
end

local function GetLocalPlotCenter()
    local plotObj
    pcall(function()
        plotObj = PlotState and PlotState.ResolvePlot and PlotState.ResolvePlot()
    end)
    local pt
    pcall(function()
        local center = type(plotObj) == "table" and plotObj.CenterPoint
            or (typeof(plotObj) == "Instance" and plotObj:FindFirstChild("CenterPoint", true))
        if typeof(center) == "Vector3" then
            pt = center
        elseif typeof(center) == "CFrame" then
            pt = center.Position
        elseif typeof(center) == "Instance" and center:IsA("BasePart") then
            pt = center.Position
        end
        if not pt and typeof(plotObj) == "Instance" then
            local pivot = plotObj:GetPivot()
            pt = pivot and pivot.Position
        end
    end)
    -- PlotState can be one frame behind after respawn/map rebuild. Resolve the
    -- player's numbered plot directly before using the legacy coordinate
    -- fallback; otherwise placement can be sent to Plot 1 while the player is
    -- actually on Plot 7.
    if not pt then
        local slot = GetLocalSlot()
        local index
        if typeof(slot) == "Instance" then
            index = tonumber(slot.Name:match("%d+"))
        elseif type(slot) == "table" then
            index = tonumber(slot.Id or slot.Index or slot.Slot or slot.Number
                or (slot.Name and tostring(slot.Name):match("%d+")))
        else
            index = tonumber(tostring(slot):match("%d+"))
        end
        pcall(function()
            local plots = Workspace:FindFirstChild("Plots")
            local plot = plots and index and plots:FindFirstChild(tostring(index))
            local center = plot and plot:FindFirstChild("CenterPoint", true)
            if center and center:IsA("BasePart") then
                pt = center.Position
            elseif plot then
                pt = plot:GetPivot().Position
            end
        end)
    end
    if pt then
        return Vector3.new(pt.X, math.max(pt.Y, 70.4), pt.Z), CFrame.new(pt.X, math.max(pt.Y, 70.4), pt.Z)
    end
    return Vector3.new(464.7, 70.4, -364.0), CFrame.new(464.7, 70.4, -364.0)
end

local MAIN_ROAD_Z = -364.5

HUB.GetSafePlotReturnRoute = function(targetPos, y)
    local slot = GetLocalSlot()
    local index
    if typeof(slot) == "Instance" then
        index = tonumber(slot.Name:match("%d+"))
    elseif type(slot) == "table" then
        index = tonumber(slot.Id or slot.Index or slot.Slot or slot.Number or (slot.Name and tostring(slot.Name):match("%d+")))
    else
        index = tonumber(tostring(slot):match("%d+"))
    end
    if index ~= 1 and index ~= 7 then return nil end

    local plot
    pcall(function()
        local resolved = PlotState and PlotState.ResolvePlot and PlotState.ResolvePlot()
        if typeof(resolved) == "Instance" then
            plot = resolved
        elseif type(resolved) == "table" then
            plot = resolved.Model or resolved.Plot or resolved.Folder or resolved.Instance
        end
    end)
    if not plot and Workspace and Workspace:FindFirstChild("Plots") then
        plot = Workspace.Plots:FindFirstChild(tostring(index))
    end
    if not plot then return nil end

    local center = targetPos
    local size = Vector3.new(80, 20, 80)
    pcall(function()
        if plot:IsA("Model") then
            local cf, boxSize = plot:GetBoundingBox()
            center, size = cf.Position, boxSize
        elseif plot:IsA("BasePart") then
            center, size = plot.Position, plot.Size
        else
            local cp = plot:FindFirstChild("CenterPoint", true)
            if cp and cp:IsA("BasePart") then center = cp.Position end
        end
    end)

    local halfX = math.max(size.X * 0.5, 30)
    local halfZ = math.max(size.Z * 0.5, 30)
    local roadSide = MAIN_ROAD_Z <= center.Z and -1 or 1
    local outsideZ = center.Z + roadSide * (halfZ + 14)
    local insideZ = center.Z + roadSide * math.max(halfZ - 6, 10)
    local gate, gateScore
    pcall(function()
        for _, part in ipairs(plot:GetDescendants()) do
            if part:IsA("BasePart") then
                local name = string.lower(part.Name)
                if name:find("entrance", 1, true) or name:find("entry", 1, true)
                    or name:find("gate", 1, true) or name:find("door", 1, true)
                    or name:find("walkway", 1, true) then
                    local pos = part.Position
                    if math.abs(pos.X - center.X) <= halfX + 20 and math.abs(pos.Z - center.Z) <= halfZ + 20 then
                        local score = math.abs(pos.X - center.X) + math.abs(pos.Z - (center.Z + roadSide * halfZ))
                        if not gateScore or score < gateScore then gate, gateScore = part, score end
                    end
                end
            end
        end
    end)
    if gate then
        local gatePos = gate.Position
        return {
            Vector3.new(targetPos.X, y, outsideZ),
            Vector3.new(gatePos.X, y, outsideZ),
            Vector3.new(gatePos.X, y, gatePos.Z),
            Vector3.new(targetPos.X, y, gatePos.Z),
            targetPos + Vector3.new(0, 1.2, 0)
        }
    end
    return {
        Vector3.new(targetPos.X, y, outsideZ),
        Vector3.new(center.X, y, outsideZ),
        Vector3.new(center.X, y, insideZ),
        Vector3.new(targetPos.X, y, insideZ),
        targetPos + Vector3.new(0, 1.2, 0)
    }
end

-- ==============================================================================
-- CLEAN ROAD & FLIGHT PATH NAVIGATION (Anti-Trap & Zero Kick Engine)
-- ==============================================================================
-- Field travel defaults to the reference script's WARP flow. Boss Rift
-- combat has its own native tween controller and does not use this setting.
local stealMovementMethod    = "Teleport" -- "Teleport", "Fly Glide", "Safe Walk"
local avoidTrapsEnabled       = true
local autoClaimMonsterChests  = false
local autoFeedMonster         = false
-- These values must be declared before the movement primitives below. Luau
-- lexical scope starts at the declaration; declaring them later made
-- MoveToPoint/TravelToDestination read unrelated globals (nil) and return
-- before Auto Steal could take its first step.
local autoStealEnabled         = false
local glideSpeed               = 750
-- Set only for the carry -> base leg.  Auto Treadmill must never inspect or
-- mount while this guard is active, even if the character briefly passes the
-- treadmill trigger volume during delivery.
local carryingEggReturnActive = false





-- Dynamic treadmill-safe return routing.
-- The base return path is allowed to detour around the actual treadmill position
-- so the character does not pass over/through it and accidentally start training.
local TREADMILL_RETURN_CLEARANCE = 105
local TREADMILL_RETURN_LANE = 125

local function FindTreadmillPart()
    local plotObj = nil
    pcall(function()
        plotObj = PlotState and PlotState.ResolvePlot and PlotState.ResolvePlot()
    end)
    local roots = {}
    if type(plotObj) == "table" then
        for _, key in ipairs({"PlotFolder", "Model", "Folder", "Instance"}) do
            local root = plotObj[key]
            if typeof(root) == "Instance" then table.insert(roots, root) end
        end
    elseif typeof(plotObj) == "Instance" then
        table.insert(roots, plotObj)
    end

    -- The plot resolver is not ready during the first few frames after a
    -- respawn/server join.  Keep the local-plot search first, then use the
    -- build/plots containers as a short-lived fallback so Auto Treadmill does
    -- not silently give up before the plot module has finished replicating.
    local function addRoot(root)
        if typeof(root) ~= "Instance" then return end
        for _, existing in ipairs(roots) do
            if existing == root then return end
        end
        table.insert(roots, root)
    end
    pcall(function()
        local plots = Workspace:FindFirstChild("Plots")
        local slot = GetLocalSlot()
        local index
        if typeof(slot) == "Instance" then
            index = tonumber(slot.Name:match("%d+"))
        elseif type(slot) == "table" then
            index = tonumber(slot.Id or slot.Index or slot.Slot or slot.Number
                or (slot.Name and tostring(slot.Name):match("%d+")))
        else
            index = tonumber(tostring(slot):match("%d+"))
        end
        -- Prefer the local numbered plot before scanning the shared Plots
        -- container, otherwise the first replicated treadmill may belong to
        -- another player while PlotState is still warming up.
        addRoot(plots and index and plots:FindFirstChild(tostring(index)))
        addRoot(plots)
        addRoot(Workspace:FindFirstChild("__OBJECTS"))
        local build = Workspace:FindFirstChild("__OBJECTS")
        addRoot(build and build:FindFirstChild("Build"))
    end)

    for _, root in ipairs(roots) do
        local exact = root:FindFirstChild("TreadmillBottom", true)
        if exact and exact:IsA("BasePart") then return exact end
        for _, exactName in ipairs({"TreadmillStand", "TreadmillSeat", "TreadmillTop", "TrainingTreadmill"}) do
            local stand = root:FindFirstChild(exactName, true)
            if stand and stand:IsA("BasePart") then return stand end
            if stand and stand:IsA("Model") then
                local primary = stand.PrimaryPart or stand:FindFirstChildWhichIsA("BasePart", true)
                if primary then return primary end
            end
        end
        local model = root:FindFirstChild("Treadmill", true)
        if model then
            if model:IsA("BasePart") then return model end
            if model:IsA("Model") then
                local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
                if primary then return primary end
            end
        end
        for _, item in ipairs(root:GetDescendants()) do
            local name = string.lower(item.Name or "")
            if item:IsA("BasePart") and (name == "treadmillbottom" or name == "treadmillstand"
                or name == "treadmillseat" or name == "treadmilltop") then
                return item
            end
            if item:IsA("Model") and name:find("treadmill", 1, true) then
                local primary = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)
                if primary then return primary end
            end
        end
    end

    -- Last fallback for builds that put the live treadmill render directly
    -- under Workspace rather than under Plots/Build. Prefer the candidate
    -- nearest to the character so another player's treadmill is not selected.
    local root = findHRP()
    local best, bestDistance = nil, math.huge
    pcall(function()
        for _, item in ipairs(Workspace:GetDescendants()) do
            local name = string.lower(item.Name or "")
            if item:IsA("BasePart") and (name == "treadmillbottom" or name == "treadmillstand"
                or name == "treadmillseat" or name == "treadmilltop") then
                local distance = root and (item.Position - root.Position).Magnitude or 0
                if distance < bestDistance then
                    best, bestDistance = item, distance
                end
            end
        end
    end)
    return best
end

local function GetTreadmillRoutePosition()
    local treadmill = FindTreadmillPart()
    return treadmill and treadmill.Position or nil
end

local function PointSegmentDistanceXZ(point, a, b)
    local p = Vector2.new(point.X, point.Z)
    local v = Vector2.new(b.X - a.X, b.Z - a.Z)
    local w = Vector2.new(a.X, a.Z)
    local len2 = v:Dot(v)
    if len2 <= 0.0001 then
        return (p - w).Magnitude, 0
    end
    local t = math.clamp((p - w):Dot(v) / len2, 0, 1)
    local closest = w + v * t
    return (p - closest).Magnitude, t
end

local function GetTreadmillSafeWaypoints(startPos, targetPos, y)
    local treadmill = GetTreadmillRoutePosition()
    if not treadmill then
        return nil
    end

    local dist = PointSegmentDistanceXZ(treadmill, startPos, targetPos)
    if dist >= TREADMILL_RETURN_CLEARANCE then
        return nil
    end

    -- Choose the side of the treadmill that produces the farther detour from it.
    local candidates = {
        Vector3.new(treadmill.X, y, treadmill.Z + TREADMILL_RETURN_LANE),
        Vector3.new(treadmill.X, y, treadmill.Z - TREADMILL_RETURN_LANE),
    }
    local best, bestScore = nil, -math.huge
    for _, candidate in ipairs(candidates) do
        local d1 = (candidate - treadmill).Magnitude
        local d2 = PointSegmentDistanceXZ(treadmill, startPos, candidate)
        local d3 = PointSegmentDistanceXZ(treadmill, candidate, targetPos)
        local score = math.min(d1, d2, d3) + ((candidate - startPos).Magnitude + (targetPos - candidate).Magnitude) * 0.001
        if score > bestScore then
            bestScore = score
            best = candidate
        end
    end
    return best
end

-- Return two waypoints instead of one.  The second point keeps the final
-- approach parallel to the treadmill, so the direct leg into the pen cannot
-- cut back through its trigger volume (the old one-point detour could do that).
local function GetTreadmillSafeRoute(startPos, targetPos, y)
    local first = GetTreadmillSafeWaypoints(startPos, targetPos, y)
    if not first then return nil end
    local treadmill = FindTreadmillPart()
    if not treadmill then return { first } end
    local laneZ = first.Z
    local second = Vector3.new(targetPos.X, y, laneZ)
    if (second - first).Magnitude < 3 then return { first } end
    return { first, second }
end

local function restoreCollisions()
    -- Collision ownership is handled by each scoped movement lease.  Suji's
    -- glide never toggles the player's body collision, so a shared helper must
    -- not rewrite character parts while another route is carrying an egg.
    -- The individual lease owners restore only the client render parts they
    -- actually changed.
end

-- Auto Boss Rift needs to pass through the arena geometry, but no-clip must be
-- scoped to the boss run.  Preserve each part's original CanCollide value so
-- leaving the arena restores the character exactly as it was before entry.
local riftBossNoClip = {
    active = false,
    character = nil,
    original = {},
    heartbeat = nil,
    descendantAdded = nil,
}

local function rememberAndDisableBossCollision(part)
    if not part or not part:IsA("BasePart") then return end
    -- Keep the Humanoid on the floor.  The Suji route ignores client render
    -- blockers instead of turning the character into a falling ghost.
    if riftBossNoClip.character and part:IsDescendantOf(riftBossNoClip.character) then return end
    if riftBossNoClip.original[part] == nil then
        riftBossNoClip.original[part] = part.CanCollide
    end
    pcall(function() part.CanCollide = false end)
end

local function stopRiftBossNoClip()
    riftBossNoClip.active = false
    if riftBossNoClip.heartbeat then
        pcall(function() riftBossNoClip.heartbeat:Disconnect() end)
        riftBossNoClip.heartbeat = nil
    end
    if riftBossNoClip.descendantAdded then
        pcall(function() riftBossNoClip.descendantAdded:Disconnect() end)
        riftBossNoClip.descendantAdded = nil
    end
    local keepAutoStealNoClip = HUB.AutoStealNoClip and HUB.AutoStealNoClip.active == true
    for part, original in pairs(riftBossNoClip.original) do
        if part and part.Parent then
            local autoState = HUB.AutoStealNoClip
            if keepAutoStealNoClip and autoState and autoState.original[part] == false and original == true then
                -- Auto Steal started after the boss owner and captured the
                -- boss' false value. Promote the boss' real original value so
                -- Auto Steal can restore it when its own toggle is closed.
                autoState.original[part] = original
            end
            local riftState = HUB.RiftNoClip
            if keepRiftNoClip and riftState and riftState.original[part] == false and original == true then
                -- Rift Egg movement may have started after the boss owner and
                -- captured the boss' false value. Preserve the real original
                -- until the Rift owner releases its no-clip state.
                riftState.original[part] = original
            end
            pcall(function() part.CanCollide = (keepAutoStealNoClip or keepRiftNoClip) and false or original end)
        end
    end
    riftBossNoClip.original = {}
    riftBossNoClip.character = nil
end

local function startRiftBossNoClip()
    local character = LP.Character
    if not character or not character.Parent then return false end

    if riftBossNoClip.character ~= character then
        -- A boss death can replace the character while the arena flag remains
        -- active. Restore old parts, then bind the no-clip guard to the respawn.
        local keepAutoStealNoClip = HUB.AutoStealNoClip and HUB.AutoStealNoClip.active == true
        local keepRiftNoClip = HUB.RiftNoClip and HUB.RiftNoClip.active == true
        for part, original in pairs(riftBossNoClip.original) do
            if part and part.Parent then
                local autoState = HUB.AutoStealNoClip
                if keepAutoStealNoClip and autoState and autoState.original[part] == false and original == true then
                    autoState.original[part] = original
                end
                local riftState = HUB.RiftNoClip
                if keepRiftNoClip and riftState and riftState.original[part] == false and original == true then
                    riftState.original[part] = original
                end
                pcall(function() part.CanCollide = (keepAutoStealNoClip or keepRiftNoClip) and false or original end)
            end
        end
        riftBossNoClip.original = {}
        if riftBossNoClip.descendantAdded then
            pcall(function() riftBossNoClip.descendantAdded:Disconnect() end)
            riftBossNoClip.descendantAdded = nil
        end
        riftBossNoClip.character = character
    end

    riftBossNoClip.active = true
    for _, part in ipairs(character:GetDescendants()) do
        rememberAndDisableBossCollision(part)
    end
    if not riftBossNoClip.descendantAdded then
        riftBossNoClip.descendantAdded = track(character.DescendantAdded:Connect(function(descendant)
            if riftBossNoClip.active and character == riftBossNoClip.character then
                rememberAndDisableBossCollision(descendant)
            end
        end))
    end
    if not riftBossNoClip.heartbeat then
        riftBossNoClip.heartbeat = track(RunService.Heartbeat:Connect(function()
            if not riftBossNoClip.active or HUB.dead then return end
            local current = LP.Character
            if current and current ~= riftBossNoClip.character then
                startRiftBossNoClip()
                return
            end
            if current then
                for _, part in ipairs(current:GetDescendants()) do
                    rememberAndDisableBossCollision(part)
                end
            end
        end))
    end
    return true
end


local function NeutralizeTraps()
    local debris = Workspace:FindFirstChild("__DEBRIS")
    if not debris then return end
    for _, d in ipairs(debris:GetChildren()) do
        if d.Name == "PlayerTrap" and d:GetAttribute("Owner") ~= LP.Name then
            if d:IsA("BasePart") then
                d.CanTouch = false
                d.CanQuery = false
            end
            for _, c in ipairs(d:GetChildren()) do
                if c:IsA("BasePart") then
                    c.CanTouch = false
                    c.CanQuery = false
                    if c.Name == "Hitbox" then
                        c.CFrame = CFrame.new(0, -999, 0)
                    end
                end
            end
            local tt = d:FindFirstChildWhichIsA("TouchTransmitter", true)
            if tt then pcall(function() tt:Destroy() end) end
        end
    end
end

-- Outbound egg travel watcher.  Some game builds change WalkSpeed/Speed while
-- the route is already in progress; in that case the old route can miss the
-- egg or be redirected into a trigger.  Keep the watcher in HUB so it does
-- not add more main-chunk locals to executors with the 200-register limit.
HUB.EggTravelSpeedWatch = HUB.EggTravelSpeedWatch or {
    active = false,
    detected = false,
    cancelled = false,
    baseline = nil,
    lastSampleAt = 0,
    jumpAt = 0,
    cooldownUntil = 0,
    armedAt = 0,
}

function GetEggTravelSpeedSample()
    local sample = {
        walkSpeed = nil,
        playerSpeed = nil,
        characterSpeed = nil,
        saveSpeed = nil,
    }
    local hum = findHum()
    if hum then sample.walkSpeed = tonumber(hum.WalkSpeed) end

    local function readAttr(obj, names)
        if not obj then return nil end
        for _, name in ipairs(names) do
            local value
            pcall(function() value = tonumber(obj:GetAttribute(name)) end)
            if value ~= nil then return value end
        end
        return nil
    end

    sample.playerSpeed = readAttr(LP, {"Speed", "CurrentSpeed", "SpeedValue"})
    sample.characterSpeed = readAttr(LP.Character, {"Speed", "CurrentSpeed", "SpeedValue"})

    -- SaveModule is used only as a fallback for builds that expose the speed
    -- stat in saved data instead of an attribute or Humanoid property.
    if type(GetCurrentSave) == "function" then
        local ok, save = pcall(GetCurrentSave)
        if ok and type(save) == "table" then
            for _, key in ipairs({"Speed", "CurrentSpeed", "SpeedPower", "SpeedValue"}) do
                local value = tonumber(save[key])
                if value ~= nil then
                    sample.saveSpeed = value
                    break
                end
            end
        end
    end
    return sample
end

function BeginEggTravelSpeedWatch()
    local watch = HUB.EggTravelSpeedWatch
    -- Release/reset paths intentionally keep this object reusable.  Older
    -- cleanup code cleared the field itself, so a later Auto Steal run could
    -- fail before its first movement step with `attempt to index nil`.
    if type(watch) ~= "table" then
        watch = {}
        HUB.EggTravelSpeedWatch = watch
    end
    watch.active = true
    watch.detected = false
    watch.cancelled = false
    watch.baseline = GetEggTravelSpeedSample()
    watch.baselineDoubleSpeed = false
    pcall(function()
        if type(HUB.IsDoubleSpeedVisible) == "function" then
            watch.baselineDoubleSpeed = HUB.IsDoubleSpeedVisible() == true
        end
    end)
    watch.lastSampleAt = 0
    watch.jumpAt = 0
    watch.armedAt = os.clock()
end

function JumpAfterEggSpeedRise()
    local watch = HUB.EggTravelSpeedWatch
    if not watch or watch.detected then return end
    local now = os.clock()
    if now < (watch.cooldownUntil or 0) then return end
    local hum = findHum()
    if hum then
        local state
        pcall(function() state = hum:GetState() end)
        if state == Enum.HumanoidStateType.Jumping
            or state == Enum.HumanoidStateType.Freefall
            or state == Enum.HumanoidStateType.FallingDown
            or state == Enum.HumanoidStateType.Ragdoll
            or state == Enum.HumanoidStateType.Physics then
            return
        end
    end
    watch.detected = true
    watch.cancelled = true
    watch.jumpAt = now
    -- Do not allow a changing replica/stat to trigger another jump at the
    -- same starting point immediately after the recovery landing.
    watch.cooldownUntil = now + 1.5
    if hum then
        pcall(function() hum.Jump = true end)
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
    end
end

-- A speed-rise jump is only a recovery signal.  Do not refresh/approach the
-- egg while the character is still airborne: the server's movement validator
-- can treat that follow-up CFrame as an anti-teleport violation.  The raycast
-- fallback is important because Auto Steal no-clip can make FloorMaterial
-- report Air even when the character is visually over the ground.
function WaitForEggTravelLanding(timeout)
    local deadline = os.clock() + (tonumber(timeout) or 3.0)
    local groundedSince = nil
    while os.clock() < deadline and not HUB.dead do
        local hum = findHum()
        local root = findHRP()
        if hum and root then
            local state = nil
            local grounded = false
            pcall(function()
                state = hum:GetState()
                grounded = hum.FloorMaterial ~= Enum.Material.Air
            end)
            if not grounded then
                pcall(function()
                    local hit = Workspace:FindPartOnRayWithIgnoreList(
                        Ray.new(root.Position, Vector3.new(0, -10, 0)),
                        {LP.Character}
                    )
                    grounded = hit ~= nil
                end)
            end
            local airborne = state == Enum.HumanoidStateType.Jumping
                or state == Enum.HumanoidStateType.Freefall
                or state == Enum.HumanoidStateType.FallingDown
                or state == Enum.HumanoidStateType.Ragdoll
                or state == Enum.HumanoidStateType.Physics
            local verticalSpeed = math.abs(root.AssemblyLinearVelocity.Y)
            if grounded and not airborne and verticalSpeed <= 14 then
                groundedSince = groundedSince or os.clock()
                if os.clock() - groundedSince >= 0.12 then
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    pcall(function()
                        hum.Jump = false
                        hum:Move(Vector3.zero, false)
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                    end)
                    return true
                end
            else
                groundedSince = nil
            end
        else
            groundedSince = nil
        end
        task.wait(0.05)
    end
    return false
end

function CheckEggTravelSpeedRise()
    local watch = HUB.EggTravelSpeedWatch
    if not watch or not watch.active then return false end
    -- This watcher belongs only to the outbound Auto Steal/Rift egg leg.  The
    -- same helper is called defensively by legacy road/fly/safe-walk routes;
    -- letting a stale watcher cancel those routes is what made every feature
    -- appear frozen after one interrupted egg run.
    if not HUB.StealGlide or HUB.StealGlide.speedGuard ~= true then
        return false
    end
    local now = os.clock()
    -- Let Humanoid/no-clip state settle before taking the first baseline
    -- comparison; otherwise the handoff itself looks like a speed rise.
    if now - (watch.armedAt or 0) < 0.25 then return false end
    if now < (watch.cooldownUntil or 0) then return false end
    if watch.cancelled then return true end
    if now - (watch.lastSampleAt or 0) < 0.1 then return false end
    watch.lastSampleAt = now

    -- The treadmill can publish its speed attribute one or two frames after
    -- the character has already stepped onto it.  In that window the numeric
    -- baseline is still unchanged, so accept a *newly appeared* speed marker
    -- only when the root is actually inside the treadmill footprint.  A marker
    -- that was already visible before the route is ignored because some game
    -- builds leave it mounted in PlayerGui after dismounting.
    if HUB.StealGlide and HUB.StealGlide.speedGuard == true then
        local treadmill = FindTreadmillPart()
        local root = findHRP()
        local speedMarkerChanged = false
        pcall(function()
            speedMarkerChanged = type(HUB.IsDoubleSpeedVisible) == "function"
                and HUB.IsDoubleSpeedVisible() == true
                and watch.baselineDoubleSpeed ~= true
        end)
        if speedMarkerChanged and treadmill and root then
            local localRoot = treadmill.CFrame:PointToObjectSpace(root.Position)
            local halfX = (tonumber(treadmill.Size.X) or 0) * 0.5 + 2
            local halfZ = (tonumber(treadmill.Size.Z) or 0) * 0.5 + 2
            if math.abs(localRoot.X) <= halfX
                and math.abs(localRoot.Z) <= halfZ
                and math.abs(localRoot.Y) <= 8 then
                JumpAfterEggSpeedRise()
                return true
            end
        end
    end

    local current = GetEggTravelSpeedSample()
    local baseline = watch.baseline or {}
    local thresholds = {
        walkSpeed = 0.5,
        playerSpeed = 0.5,
        characterSpeed = 0.5,
        saveSpeed = 0.1,
    }
    for key, threshold in pairs(thresholds) do
        local before = tonumber(baseline[key])
        local after = tonumber(current[key])
        -- A few builds publish the Speed attribute only after the route has
        -- started.  Treat nil -> a positive value as a rise too; otherwise
        -- the first anti-TP correction is missed completely.
        if after ~= nil and ((before == nil and after > 0)
            or (before ~= nil and after > before + threshold)) then
            JumpAfterEggSpeedRise()
            return true
        end
    end
    return false
end

function EndEggTravelSpeedWatch()
    local watch = HUB.EggTravelSpeedWatch
    local detected = watch and watch.detected == true
    if watch then
        watch.active = false
        watch.baseline = nil
        watch.cancelled = false
    end
    return detected
end

-- Run one governed movement leg with the treadmill-path recovery enabled.
-- The watcher is deliberately scoped to the leg: a stale watcher must never
-- make an unrelated route jump or hold the central movement lease forever.
HUB.MoveEggRouteGuarded = function(target, speed, shouldCancel, retryCount)
    local glide = HUB.StealGlide
    if not glide or type(glide.To) ~= "function" then return false end
    local previousGuard = glide.speedGuard == true
    local attempts = math.max(1, math.floor(tonumber(retryCount) or 2))
    local moved = false
    glide.speedGuard = true
    for attempt = 1, attempts do
        if shouldCancel and shouldCancel() then break end
        BeginEggTravelSpeedWatch()
        local ok = glide.To(target, speed, shouldCancel)
        local speedRose = EndEggTravelSpeedWatch()
        if speedRose then
            -- JumpAfterEggSpeedRise already fired. Never send another route
            -- frame while the Humanoid is airborne; that is the anti-TP case
            -- seen when the character steps onto the treadmill path.
            if not WaitForEggTravelLanding(2.5) then break end
            if attempt < attempts then task.wait(0.06) end
        else
            moved = ok == true
            break
        end
    end
    glide.speedGuard = previousGuard
    pcall(EndEggTravelSpeedWatch)
    return moved
end

function RefreshFieldEggByUid(uid)
    local wantedUid = tostring(uid or "")
    if wantedUid == "" then return nil end
    -- A refresh can publish an empty/partial snapshot for a few frames. Give
    -- the live stream a short rebind window before deciding that the selected
    -- egg disappeared; this keeps an enabled Auto Steal alive after refresh.
    for attempt = 1, 6 do
        local ok, snap = pcall(HUB.ReadSujiFieldEggSnapshot, true)
        if ok and type(snap) == "table" and type(snap.Records) == "table" then
            for _, item in ipairs(snap.Records) do
                if item and tostring(item.Uid or "") == wantedUid
                    and (item.State == "Slot" or item.State == "Dropped") then
                    return item
                end
            end
        end
        if attempt < 6 then task.wait(0.1) end
    end
    return nil
end

-- Auto Steal movement settings copied from Suji's __SAEGlide table. Keep these
-- values together so the outbound route cannot drift from the reference
-- implementation while the other automation routes keep their old settings.
local AUTO_STEAL_SAFE_SPEED = 600

-- Suji-style glide governor. The important anti-TP part is the per-frame
-- horizontal step limit plus ground-following; a single large CFrame jump is
-- never allowed. Keep the mutable state in HUB so this does not add another
-- large group of main-chunk locals (the executor limit is 200).
HUB.StealGlide = HUB.StealGlide or {
    Speed = glideSpeed,
    ArriveRadius = 6,
    -- Suji's final egg approach: begin easing 14 studs before the target and
    -- reach the fixed 60 studs/s handoff speed at the interaction point.
    ApproachDistance = 14,
    ApproachSpeed = 60,
    GroundSmooth = 8,
    ServerCap = 850,
    ServerCapCarry = 1000,
    WalkSpeedFactor = 5.2,
    lastStepAt = 0,
    groundY = nil,
    evidence = nil,
    nextEvidenceScanAt = 0,
    owner = nil,
    speedGuard = false,
}

HUB.StealGlide.EffectiveSpeed = function(requested)
    local state = HUB.StealGlide
    local hum = findHum()
    local walkSpeed = hum and tonumber(hum.WalkSpeed) or 16
    local walkCap = math.max(120, walkSpeed * (state.WalkSpeedFactor or 5.2))
    local requestedSpeed = tonumber(requested) or tonumber(state.Speed) or 600
    local serverCap = carryingEggReturnActive == true
        and (state.ServerCapCarry or 1000)
        or (state.ServerCap or 850)
    return math.min(math.max(50, requestedSpeed), serverCap, walkCap)
end

HUB.StealGlide.Govern = function(fromPos, toPos, speed, dt)
    local elapsed = os.clock() - (HUB.StealGlide.lastStepAt or 0)
    HUB.StealGlide.lastStepAt = os.clock()
    if elapsed <= 0 or elapsed > 0.2 then elapsed = math.min(dt or 0.016, 0.05) end
    local stepLimit = HUB.StealGlide.EffectiveSpeed(speed) * math.min(elapsed, 0.05) * 1.15
    local dx = toPos.X - fromPos.X
    local dz = toPos.Z - fromPos.Z
    local distance = math.sqrt(dx * dx + dz * dz)
    if distance > stepLimit and distance > 0.001 then
        return Vector3.new(fromPos.X + dx / distance * stepLimit, fromPos.Y, fromPos.Z + dz / distance * stepLimit)
    end
    return toPos
end

HUB.StealGlide.RaycastParams = function()
    local state = HUB.StealGlide
    if state.raycastParams and state.raycastCharacter == LP.Character then
        return state.raycastParams
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local excluded = { LP.Character }
    pcall(function()
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character and player.Character ~= LP.Character then
                table.insert(excluded, player.Character)
            end
        end
        for _, child in ipairs(Workspace:GetChildren()) do
            if child.Name == "ClientRenderedAssets" or child.Name == "PlacedEggRenders"
                or child.Name == "AreaEggSlotsClient" or child.Name == "__ClientTreadmillRenders"
                or child:IsA("Tool") then
                table.insert(excluded, child)
            end
        end
    end)
    params.FilterDescendantsInstances = excluded
    state.raycastParams = params
    state.raycastCharacter = LP.Character
    return params
end

HUB.StealGlide.GroundY = function(position, fallbackY)
    local root = findHRP()
    local y = tonumber(fallbackY) or (root and root.Position.Y) or 70.4
    local hit
    pcall(function()
        hit = Workspace:Raycast(Vector3.new(position.X, y + 60, position.Z), Vector3.new(0, -220, 0), HUB.StealGlide.RaycastParams())
    end)
    if hit then
        local hum = findHum()
        local rootPart = findHRP()
        local standingOffset = (hum and hum.HipHeight or 2) + (rootPart and rootPart.Size.Y * 0.5 or 2)
        y = hit.Position.Y + standingOffset
    end
    return y
end

-- No-clip removes the character's own floor contact as well as wall contact.
-- Suji keeps the root on the last valid ground sample; without this guard a
-- stopped/aborted glide can fall through the map before the next action starts.
HUB.StealGlide.KeepGrounded = function(root)
    if not root or not root.Parent then return false end
    local state = HUB.StealGlide
    local now = os.clock()
    if now - (state.lastGroundRecoveryAt or 0) < 0.15 then return false end
    local bossMovementActive = state.owner == "boss"
        or LP:GetAttribute("InBossArena") == true
        or (HUB.Orchestrator and HUB.Orchestrator.owner == "boss")
        or (riftBossNoClip and riftBossNoClip.active == true)
    local groundY = state.GroundY(root.Position, root.Position.Y)
    if not groundY then return false end

    local currentY = root.Position.Y
    if currentY < groundY - 6 then
        state.lastGroundRecoveryAt = now
        local position = Vector3.new(root.Position.X, groundY, root.Position.Z)
        pcall(function()
            root.CFrame = CFrame.new(position) * (root.CFrame - root.Position)
            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
            root.AssemblyAngularVelocity = Vector3.zero
            local hum = findHum()
            if hum then
                hum.PlatformStand = false
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
        end)
        return true
    end

    -- If the character has already gone below the map, the downward ray can
    -- miss the map entirely. Recover overworld routes to Suji's park XYZ, but
    -- never pull an active Rift Boss route out of its arena to the overworld.
    if currentY < 10 and not bossMovementActive then
        local park = type(HUB.StealGlide.ParkPosition) == "function" and HUB.StealGlide.ParkPosition() or nil
        if park then
            -- ParkPosition is the marker's center, not the HumanoidRootPart's
            -- standing height.  Re-sample the floor and add the normal hip/root
            -- offset before recovering; placing the root at the marker center
            -- can put it inside the floor and start another fall.
            local parkY = state.GroundY(park, park.Y)
            local parkPosition = Vector3.new(park.X, parkY, park.Z)
            state.lastGroundRecoveryAt = now
            pcall(function()
                root.CFrame = CFrame.new(parkPosition) * (root.CFrame - root.Position)
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                local hum = findHum()
                if hum then
                    hum.PlatformStand = false
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end
            end)
            return true
        end
    end
    return false
end

HUB.StealGlide.WallBlocked = function(fromPos, toPos)
    local delta = Vector3.new(toPos.X - fromPos.X, 0, toPos.Z - fromPos.Z)
    if delta.Magnitude < 1 then return false end
    local lowHit
    local highHit
    pcall(function()
        local params = HUB.StealGlide.RaycastParams()
        local rayDirection = delta.Unit * (delta.Magnitude + 2)
        -- Match Suji's obstacle test: a low hit alone is climbable. Only
        -- treat the route as blocked when the same obstacle also reaches the
        -- higher probe, which prevents floors, curbs, and egg pads from
        -- cancelling the first movement step.
        lowHit = Workspace:Raycast(fromPos + Vector3.new(0, 3, 0), rayDirection, params)
        if lowHit and lowHit.Normal.Y < 0.3 then
            highHit = Workspace:Raycast(fromPos + Vector3.new(0, 9, 0), rayDirection, params)
        end
    end)
    return lowHit ~= nil and lowHit.Normal.Y < 0.3
        and highHit ~= nil and highHit.Normal.Y < 0.3
end

-- Suji clears the movement evidence before the next glide step. This is
-- optional and safely no-ops on executors that do not expose getconnections.
HUB.StealGlide.ResetMovementEvidence = function()
    local state = HUB.StealGlide
    local now = os.clock()
    if now < (state.nextEvidenceScanAt or 0) then return end
    local evidence = state.evidence
    if not evidence and now >= (state.nextEvidenceScanAt or 0) then
        state.nextEvidenceScanAt = now + 2
        pcall(function()
            if typeof(getconnections) ~= "function" or not (debug and debug.getupvalues) then return end
            for _, signal in ipairs({ RunService.PostSimulation, RunService.Heartbeat, RunService.PreSimulation, RunService.Stepped }) do
                local ok, connections = pcall(getconnections, signal)
                if ok and type(connections) == "table" then
                    for _, connection in ipairs(connections) do
                        local fn = connection.Function
                        if type(fn) == "function" then
                            local upOk, values = pcall(debug.getupvalues, fn)
                            if upOk and type(values) == "table" then
                                for _, value in pairs(values) do
                                    if type(value) == "table" and type(value.Evidence) == "table"
                                        and value.Evidence.Speed ~= nil and value.ThreatLevel ~= nil
                                        and value.MovementMode ~= nil and value.Character ~= nil then
                                        evidence = value
                                        break
                                    end
                                end
                            end
                        end
                        if evidence then break end
                    end
                end
                if evidence then break end
            end
        end)
        state.evidence = evidence
    end
    if evidence and evidence.Evidence then
        pcall(function()
            evidence.Evidence.Speed = 0
            evidence.Evidence.Teleport = 0
            evidence.Evidence.Flight = 0
            evidence.ThreatLevel = "Trusted"
            evidence.LastViolationReason = nil
            evidence.FirstSuspiciousAt = nil
            evidence.UncertainUntil = nil
            evidence.CorrectionContext = nil
            evidence.ImpulseContext = nil
        end)
    end
end

local function MoveToPoint(target, speed, easeOut, shouldCancel, arriveRadius, ignoreWallCheck, onStep)
    if HUB.AutoStealMovementActive == true and autoStealEnabled ~= true
        and HUB.StealGlide.owner ~= "rift" and HUB.StealGlide.owner ~= "place"
        and HUB.StealGlide.owner ~= "boss" and not carryingEggReturnActive then
        return false
    end
    local hrp = findHRP()
    if not hrp or not target then return false end
    local sujiOwner = HUB.StealGlide.owner
    if type(HUB.CanMovementOwnerProceed) == "function"
        and not HUB.CanMovementOwnerProceed(sujiOwner) then
        return false
    end
    local sujiActive = sujiOwner == "auto" or sujiOwner == "rift" or sujiOwner == "place"
        or sujiOwner == "boss"
        or (HUB.AutoStealMovementActive == true and autoStealEnabled == true)
    -- Suji movement checks grounded state before starting. The optional
    -- outbound speed guard is consulted only when the caller explicitly arms
    -- `HUB.StealGlide.speedGuard`; return/plot movement never jumps for this.
    if not sujiActive and CheckEggTravelSpeedRise() then return false end

    arriveRadius = math.max(1, tonumber(arriveRadius) or 1.0)
    local start = hrp.Position
    local dist = (target - start).Magnitude
    if dist < arriveRadius then
        if arriveRadius > 1 then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            return true
        end
        hrp.CFrame = CFrame.new(target.X, math.max(target.Y, 70.0), target.Z)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        return true
    end

    speed = math.clamp(tonumber(speed) or tonumber(glideSpeed) or 750, 50, 1000)
    if sujiActive and sujiOwner ~= "boss" then
        speed = math.min(speed, AUTO_STEAL_SAFE_SPEED)
    end

    local t0 = os.clock()
    local totalDist = dist
    local movementBudget = totalDist / 50 + 5
    local bestRemain = math.huge
    local lastProgressAt = t0
    if sujiActive then
        -- Suji's To() uses distance / effective speed * 1.6 + 25s.  Keep the
        -- same budget for both the outbound and carried return leg.
        movementBudget = totalDist / math.max(speed, 50) * 1.6 + 25
    end
    HUB.StealGlide.lastStepAt = os.clock()
    while not HUB.dead do
        if type(HUB.CanMovementOwnerProceed) == "function"
            and not HUB.CanMovementOwnerProceed(sujiOwner) then
            return false
        end
        if sujiOwner == "manual" and HUB.MovementLease
            and HUB.MovementLease.owner == "manual" then
            HUB.MovementLease.lastAt = os.clock()
        end
        -- Suji rebinds the live root on every movement step.  A respawn or
        -- character replacement must never leave this loop writing the old
        -- HumanoidRootPart, which looks like standing still/warping in place.
        hrp = findHRP()
        if not hrp then return false end
        if HUB.AutoStealMovementActive == true and autoStealEnabled ~= true
            and HUB.StealGlide.owner ~= "rift" and HUB.StealGlide.owner ~= "place"
            and HUB.StealGlide.owner ~= "boss" and not carryingEggReturnActive then
            return false
        end
        if shouldCancel and shouldCancel() then
            return false
        end
        local dt = RunService.Heartbeat:Wait()
        if type(HUB.CanMovementOwnerProceed) == "function"
            and not HUB.CanMovementOwnerProceed(sujiOwner) then
            return false
        end
        if sujiActive then
            HUB.StealGlide.ResetMovementEvidence()
            -- Outbound Auto Steal/Rift travel opts into the same recovery
            -- watcher as the reference flow. If the game raises any exposed
            -- speed value, jump and let the caller re-arm after landing.
            if HUB.StealGlide.speedGuard == true and CheckEggTravelSpeedRise() then
                return false
            end
        end
        if not sujiActive and CheckEggTravelSpeedRise() then return false end
        local curPos = hrp.Position
        if onStep then pcall(onStep, hrp, curPos) end
        local horizontalTarget = Vector3.new(target.X, curPos.Y, target.Z)
        local horizontalDelta = horizontalTarget - curPos
        -- Suji's glide arrives by X/Z distance.  Field records can expose the
        -- egg's visual/top Y, so using full 3D distance here made the route
        -- keep chasing height after reaching the area and look stationary.
        local remain = sujiActive
            and Vector3.new(target.X - curPos.X, 0, target.Z - curPos.Z).Magnitude
            or (target - curPos).Magnitude
        if remain < arriveRadius then break end
        -- Match Suji's stuck guard.  A server correction or a streamed gate
        -- can otherwise leave this coroutine writing the same position until
        -- the much longer movement budget expires, which looks like Auto
        -- Steal never started moving.
        -- At the Suji-compatible effective cap (often 120 studs/s), one
        -- heartbeat advances less than 3 studs. A 3-stud progress threshold
        -- therefore declared a healthy route stuck after 2.5 seconds and
        -- made Auto Steal appear to stand/jump at the starting point.
        if sujiActive and remain < bestRemain - 0.25 then
            bestRemain = remain
            lastProgressAt = os.clock()
        elseif sujiActive and os.clock() - lastProgressAt > 2.5 then
            return false
        end
        local stepSpeed = speed
        if easeOut then
            if sujiActive then
                -- Match Suji's actual approach curve: the route starts
                -- easing 14 studs out and reaches 60 studs/s at the egg.
                -- A hard switch on the last frame made the character look
                -- stalled and could race the egg-prompt handshake.
                local approachDistance = tonumber(HUB.StealGlide.ApproachDistance) or 14
                local approachSpeed = tonumber(HUB.StealGlide.ApproachSpeed) or 60
                if remain < approachDistance then
                    local approach = math.clamp(remain / approachDistance, 0, 1)
                    stepSpeed = approachSpeed + (stepSpeed - approachSpeed) * approach
                end
            else
                local progress = 1 - math.clamp(remain / totalDist, 0, 1)
                stepSpeed = math.max(speed * (1 - progress * 0.8), 35)
            end
        end
        local nextPos
        if sujiActive and horizontalDelta.Magnitude > 0.001 then
            local governed = HUB.StealGlide.Govern(curPos, horizontalTarget, stepSpeed, dt)
            -- Suji only applies the two-ray wall rejection on its direct
            -- segment.  Its PathfindingService waypoint runner keeps moving
            -- through the no-clip corridor; rejecting every waypoint here
            -- causes the character to repeatedly write the same position at
            -- gates/arches (the reported "warp in place" symptom).
            if not ignoreWallCheck and HUB.StealGlide.WallBlocked(curPos, governed) then return false end
            local groundY = HUB.StealGlide.GroundY(governed, curPos.Y)
            local smoothY = curPos.Y + (groundY - curPos.Y) * math.min(1, dt * (HUB.StealGlide.GroundSmooth or 8))
            if horizontalDelta.Magnitude < 3 then
                smoothY = curPos.Y + (math.max(target.Y, 70.0) - curPos.Y) * math.min(1, dt * 8)
            end
            nextPos = Vector3.new(governed.X, smoothY, governed.Z)
        else
            local toTarget = target - curPos
            local step = math.min(stepSpeed * dt, remain)
            local dir = toTarget.Unit
            nextPos = curPos + dir * step
        end
        local moveDelta = nextPos - curPos
        local dir = moveDelta.Magnitude > 0.001 and moveDelta.Unit or Vector3.new(1, 0, 0)
        hrp.CFrame = CFrame.lookAt(nextPos, nextPos + dir)
        if sujiActive then
            -- Keep physics velocity consistent with the governed CFrame step.
            -- A fixed 16 studs/s made the carried return visibly drift slowly
            -- after a guard knockback even when the route speed was higher.
            local guidedSpeed = math.min(math.max(stepSpeed, 16), 120)
            hrp.AssemblyLinearVelocity = Vector3.new(dir.X * guidedSpeed, 0, dir.Z * guidedSpeed)
        else
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
        hrp.AssemblyAngularVelocity = Vector3.zero
        if os.clock() - t0 > movementBudget then break end
    end

    if shouldCancel and shouldCancel() then
        return false
    end
    if not sujiActive and CheckEggTravelSpeedRise() then
        return false
    end
    if arriveRadius > 1 then
        local remaining = Vector3.new(target.X - hrp.Position.X, 0, target.Z - hrp.Position.Z).Magnitude
        if remaining <= arriveRadius + 1 then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            return true
        end
    end
    local finalTarget = Vector3.new(target.X, math.max(target.Y, 70.0), target.Z)
    -- If the server corrected the character during the segment, do not snap
    -- the remaining distance in one frame. Report failure so the caller can
    -- refresh/retry from the corrected position instead.
    if (hrp.Position - finalTarget).Magnitude > 2.5 then
        return false
    end
    if type(HUB.CanMovementOwnerProceed) == "function"
        and not HUB.CanMovementOwnerProceed(sujiOwner) then
        return false
    end
    if not sujiActive then
        hrp.CFrame = CFrame.new(finalTarget)
    end
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    return true
end

-- Auto Steal's outbound leg follows Suji's To() contract: use the egg record's
-- exact XYZ, move on the ground at the governed effective speed, and stop
-- inside the same 6-stud arrival radius.  This helper is intentionally used
-- only by the marked Auto Steal target or Rift field source; Rift placement,
-- trading, Auto Treadmill, and Auto Place keep their existing routes.
HUB.StealGlide.ParkPosition = function()
    local state = HUB.StealGlide
    if typeof(state.parkPosition) == "Vector3" then
        return state.parkPosition
    end
    local park
    pcall(function()
        local build = Workspace:FindFirstChild("__OBJECTS")
        build = build and build:FindFirstChild("Build")
        local mainMap = build and build:FindFirstChild("MainMap")
        if mainMap then
            for _, item in ipairs(mainMap:GetDescendants()) do
                if item:IsA("TextLabel") and tostring(item.Text):find("SAFE ZONE", 1, true) then
                    local part = item:FindFirstAncestorWhichIsA("BasePart")
                    if part then
                        park = part.Position
                        break
                    end
                end
            end
        end
        if not park then
            local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
            park = spawn and spawn.Position
        end
    end)
    state.parkPosition = park
    return park
end

-- Suji starts an Auto Steal run from the safe-zone center instead of sending
-- the character directly from an arbitrary spawn/road position to the egg.
-- That short staging leg is important for the game's movement validator and
-- also prevents the first egg glide from starting inside a wall/arch.
HUB.StealGlide.SafeCenter = function()
    local state = HUB.StealGlide
    if typeof(state.safeCenter) == "Vector3" then
        return state.safeCenter
    end

    local park = HUB.StealGlide.ParkPosition()
    if typeof(park) ~= "Vector3" then return nil end

    local center = park
    local root = findHRP()
    if root then
        local dx = root.Position.X - park.X
        local dz = root.Position.Z - park.Z
        local distance = math.sqrt(dx * dx + dz * dz)
        if distance > 1 then
            local offset = math.min(20, distance * 0.5, 22)
            center = Vector3.new(park.X + dx / distance * offset, park.Y, park.Z + dz / distance * offset)
        end
    end

    local groundY = HUB.StealGlide.GroundY(center, center.Y)
    state.safeCenter = Vector3.new(center.X, groundY, center.Z)
    return state.safeCenter
end

HUB.StealGlide.WaitAtSafeCenter = function(speed)
    local center = HUB.StealGlide.SafeCenter()
    if typeof(center) ~= "Vector3" then return true end
    local root = findHRP()
    if not root then return false end
    local distance = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z).Magnitude
    if distance > 8 then
        -- Staging is always the Suji tween/glide handoff.  Teleport mode is
        -- reserved for the actual outbound target leg, so toggling Auto Steal
        -- or restarting a route cannot warp the character during setup.
        local moved = HUB.MoveEggRouteGuarded
            and HUB.MoveEggRouteGuarded(center, speed or HUB.StealGlide.Speed or 600, nil, 2)
        if not moved then
            -- Suji retries the short safe-center handoff with pinGlide when
            -- the first direct segment is interrupted by streaming/collision.
            local recovered = HUB.StealGlide.PinGlide
                and HUB.StealGlide.PinGlide(center + Vector3.new(0, 3, 0), speed, nil)
            local after = findHRP()
            if not recovered and (not after or Vector3.new(after.Position.X - center.X, 0, after.Position.Z - center.Z).Magnitude > 10) then
                return false
            end
        end
    end
    task.wait(0.12)
    return true
end

-- Suji's movement worker self-heals when the server stops accepting the glide:
-- it drops the glide lease, lets the Humanoid walk back through the safe-center
-- corridor, then starts the target route again.  Without that recovery, one
-- rejected CFrame leaves the character at the plot while the retry loop keeps
-- writing the same corrected XYZ (the "standing still" symptom).
HUB.StealGlide.RecoverStalled = function(shouldCancel)
    if carryingEggReturnActive then return false end
    if type(HUB.BossMovementOwnsCharacter) == "function"
        and HUB.BossMovementOwnsCharacter() then
        return false
    end
    local root = findHRP()
    local hum = findHum()
    if not root or not hum then return false end
    pcall(HUB.StealGlide.ResetMovementEvidence)
    pcall(HUB.StealGlide.KeepGrounded, root)

    local center = HUB.StealGlide.SafeCenter()
    if typeof(center) ~= "Vector3" then return false end
    local distance = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z).Magnitude
    if distance <= 10 then return true end

    local previousSpeed = tonumber(hum.WalkSpeed) or 16
    local walkSpeed = math.max(previousSpeed, 24)
    pcall(function() hum.WalkSpeed = walkSpeed end)
    pcall(function()
        hum:MoveTo(Vector3.new(center.X, root.Position.Y, center.Z))
    end)

    local deadline = os.clock() + 4.0
    local reached = false
    while os.clock() < deadline and not HUB.dead do
        if type(HUB.BossMovementOwnsCharacter) == "function"
            and HUB.BossMovementOwnsCharacter() then
            break
        end
        if shouldCancel and shouldCancel() then break end
        root = findHRP()
        if not root then break end
        local remaining = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z).Magnitude
        if remaining <= 10 then
            reached = true
            break
        end
        task.wait(0.12)
        if type(HUB.BossMovementOwnsCharacter) == "function"
            and HUB.BossMovementOwnsCharacter() then
            break
        end
        pcall(function() hum:MoveTo(Vector3.new(center.X, root.Position.Y, center.Z)) end)
    end
    pcall(function() hum.WalkSpeed = previousSpeed end)
    if reached then
        pcall(function()
            hum.Jump = false
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end)
        task.wait(0.12)
    end
    return reached
end

-- Guard knockback can leave a residual horizontal impulse after the Humanoid
-- reports Grounded. Clear that impulse for a short bounded window before the
-- exact UID is re-carried or the return glide starts; do not teleport here.
HUB.StealGlide.StabilizeAfterGuardHit = function()
    local deadline = os.clock() + 0.35
    local root
    while os.clock() < deadline and not HUB.dead do
        local hum = findHum()
        root = findHRP()
        if hum then
            pcall(function()
                hum.PlatformStand = false
                hum.AutoRotate = true
                hum.Jump = false
                hum:Move(Vector3.zero, false)
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end)
        end
        if root then
            pcall(function()
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end)
        end
        task.wait(0.05)
    end
    return root ~= nil
end

HUB.StealGlide.To = function(target, speed, shouldCancel, onStep)
    if not target or typeof(target) ~= "Vector3" then return false end
    local root = findHRP()
    if not root then return false end
    local owner = HUB.StealGlide.owner
    if owner == "boss" then
        if not HUB.Orchestrator or HUB.Orchestrator.owner ~= "boss" then return false end
    elseif type(HUB.CanMovementOwnerProceed) == "function"
        and not HUB.CanMovementOwnerProceed(owner) then
        return false
    end
    local routeEpoch = HUB.AutoStealControllerEpoch
    local autoOwner = autoStealEnabled == true and HUB.AutoStealMovementActive == true
    local carryOwner = owner == "auto" and carryingEggReturnActive == true
    if owner ~= "rift" and owner ~= "place" and owner ~= "manual" and owner ~= "boss" and not autoOwner and not carryOwner then return false end
    local routeCancelled = function()
        if owner == "auto" and routeEpoch ~= HUB.AutoStealControllerEpoch and not carryingEggReturnActive then
            return true
        end
        return shouldCancel and shouldCancel() or false
    end
    if owner == "boss" then
        pcall(startRiftBossNoClip)
    elseif owner == "rift" or owner == "place" then
        pcall(HUB.StartRiftNoClip)
    else
        pcall(HUB.StartAutoStealNoClip)
    end
    local noClipActive = (HUB.AutoStealNoClip and HUB.AutoStealNoClip.active == true)
        or (HUB.RiftNoClip and HUB.RiftNoClip.active == true)
        or (riftBossNoClip and riftBossNoClip.active == true)

    local actualSpeed = HUB.StealGlide.EffectiveSpeed(speed)
    -- Use the same grounded Suji glide for Auto Steal, Rift field sourcing,
    -- and the carried return leg.  The old carry leg fell back to Axel's
    -- road planner as soon as Auto Steal was toggled off, so it could skip the
    -- Safe Center handoff or stop at a plot wall.
    local directClear = true
    if not noClipActive then
        pcall(function()
            local from = root.Position + Vector3.new(0, 4, 0)
            local to = Vector3.new(target.X, root.Position.Y + 4, target.Z)
            directClear = Workspace:Raycast(from, to - from, HUB.StealGlide.RaycastParams()) == nil
        end)
    end

    -- Match Suji's first routing decision for overworld routes. The SAFE
    -- ZONE/SpawnLocation detour is never valid inside a Rift Boss arena (or
    -- for the boss's own route to its explicit entry staging point).
    if not directClear and owner ~= "boss" and LP:GetAttribute("InBossArena") ~= true then
        local park = HUB.StealGlide.ParkPosition()
        if park
            and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(park.X, 0, park.Z)).Magnitude > 40
            and (Vector3.new(target.X, 0, target.Z) - Vector3.new(park.X, 0, park.Z)).Magnitude > 40 then
            if not MoveToPoint(park, actualSpeed, false, routeCancelled, 8, noClipActive) then
                return false
            end
            root = findHRP()
            if not root then return false end
            -- The next segment now starts from Suji's park XYZ; let the
            -- normal direct attempt run and fall back to PathfindingService if
            -- the park-to-egg segment is still obstructed.
            directClear = true
        end
    end

    if directClear and MoveToPoint(target, actualSpeed, true, routeCancelled, HUB.StealGlide.ArriveRadius or 6, noClipActive, onStep) then
        return true
    end
    if routeCancelled() then return false end

    -- Suji rebinds the live HumanoidRootPart before its path fallback. A
    -- respawn during the direct segment must not make PathfindingService
    -- compute from the destroyed character's old XYZ.
    root = findHRP()
    if not root then return false end

    -- Same fallback used by Suji when the direct line is blocked.  Waypoints
    -- are still fed through MoveToPoint, so every segment keeps the grounded
    -- governor and no single CFrame jump is introduced.
    local pathService
    local path
    local pathOk = pcall(function()
        pathService = game:GetService("PathfindingService")
        path = pathService:CreatePath({
            AgentRadius = 3,
            AgentHeight = 5,
            AgentCanJump = true,
            WaypointSpacing = 8,
        })
        path:ComputeAsync(root.Position, target)
    end)
    if not pathOk or not path or path.Status ~= Enum.PathStatus.Success then
        -- Suji's no-clip route still keeps a governed direct fallback when
        -- PathfindingService cannot solve a gate/arch.  Without this, the
        -- caller retries the same blocked start point and appears to warp in
        -- place forever.
        return MoveToPoint(target, actualSpeed, true, routeCancelled, HUB.StealGlide.ArriveRadius or 6, true, onStep)
    end

    local waypoints = path:GetWaypoints()
    for _, waypoint in ipairs(waypoints) do
        if routeCancelled() then return false end
        -- The Suji/no-clip glide remains grounded through path waypoints.
        -- Firing Humanoid.Jump for every PathWaypointAction.Jump made the
        -- character hop repeatedly at the same XYZ while the governed CFrame
        -- route was already taking care of the obstacle.
        if not MoveToPoint(waypoint.Position, actualSpeed, false, routeCancelled, 4, true, onStep) then
            return MoveToPoint(target, actualSpeed, true, routeCancelled, HUB.StealGlide.ArriveRadius or 6, true, onStep)
        end
    end
    local finalRoot = findHRP()
    return finalRoot ~= nil
        and Vector3.new(target.X - finalRoot.Position.X, 0, target.Z - finalRoot.Position.Z).Magnitude <= 7
end

-- Suji's last step is an exact XYZ close-approach after the governed glide has
-- already reached the target area.  Keep that correction small and grounded:
-- it fixes the final interaction/placement position without turning a long
-- route into a one-frame teleport that the server can reject.
HUB.StealGlide.SnapNearXYZ = function(target, yOffset, maxHorizontalDistance)
    if typeof(target) ~= "Vector3" then return false end
    if type(HUB.CanMovementOwnerProceed) == "function"
        and not HUB.CanMovementOwnerProceed(HUB.StealGlide and HUB.StealGlide.owner) then
        return false
    end
    local root = findHRP()
    if not root then return false end

    local dx = target.X - root.Position.X
    local dz = target.Z - root.Position.Z
    local radius = math.max(1, tonumber(maxHorizontalDistance) or 12)
    if dx * dx + dz * dz > radius * radius then return false end

    local offset = tonumber(yOffset) or 0
    pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = CFrame.new(target.X, target.Y + offset, target.Z) * root.CFrame.Rotation
    end)
    return true
end

-- Suji's pin-glide fallback is a short governed retry, not a teleport.  It is
-- used when a gate/streaming correction makes the first long segment report
-- failure even though the character is already close to the selected egg.
HUB.StealGlide.PinGlide = function(target, speed, shouldCancel)
    if typeof(target) ~= "Vector3" then return false end
    if type(HUB.CanMovementOwnerProceed) == "function"
        and not HUB.CanMovementOwnerProceed(HUB.StealGlide and HUB.StealGlide.owner) then
        return false
    end
    local root = findHRP()
    if not root then return false end
    local distance = Vector3.new(root.Position.X - target.X, 0, root.Position.Z - target.Z).Magnitude
    if distance <= 10 then return true end
    local routeSpeed = math.min(HUB.StealGlide.EffectiveSpeed(speed), AUTO_STEAL_SAFE_SPEED)
    return MoveToPoint(target + Vector3.new(0, 3, 0), routeSpeed, true, shouldCancel, 10, true)
end

-- Reference WARP movement: stream the destination, perform one guarded
-- character PivotTo, briefly anchor to prevent the physics solver from
-- undoing the handoff, then clear velocity and return to Humanoid control.
-- This is intentionally a single teleport operation; it never follows a
-- target's changing position every Heartbeat.
HUB.StealTeleport = HUB.StealTeleport or {
    active = false,
    nonce = 0,
}

-- Invalidate an outbound Auto Steal teleport immediately.  Incrementing only
-- the route epoch is not enough when RequestStreamAroundAsync/PivotTo is
-- already in progress: the old teleport could finish after the toggle was
-- turned off and after a new route had started.
HUB.StealTeleport.Cancel = function()
    HUB.StealTeleport.nonce = (HUB.StealTeleport.nonce or 0) + 1
    local root = findHRP()
    local humanoid = findHum()
    if root then
        root.Anchored = false
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
    if humanoid then
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
        pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
    end
    HUB.StealTeleport.active = false
end

HUB.StealTeleport.To = function(target, shouldCancel, yOffset)
    if typeof(target) ~= "Vector3" then return false end
    if HUB.StealTeleport.active then return false end

    local owner = HUB.StealGlide and HUB.StealGlide.owner
    if type(HUB.CanMovementOwnerProceed) == "function"
        and not HUB.CanMovementOwnerProceed(owner) then
        return false
    end
    if shouldCancel and shouldCancel() then return false end

    local character = LP.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not character or not root or not humanoid then return false end

    HUB.StealTeleport.nonce = (HUB.StealTeleport.nonce or 0) + 1
    local nonce = HUB.StealTeleport.nonce
    HUB.StealTeleport.active = true

    local wasAnchored = root.Anchored
    local wasAutoRotate = humanoid.AutoRotate
    local finished = false
    local function cleanup()
        local currentRoot = findHRP()
        local currentHumanoid = findHum()
        if currentRoot then
            currentRoot.Anchored = wasAnchored
            currentRoot.AssemblyLinearVelocity = Vector3.zero
            currentRoot.AssemblyAngularVelocity = Vector3.zero
        end
        if currentHumanoid then
            currentHumanoid.AutoRotate = wasAutoRotate
            currentHumanoid.PlatformStand = false
            pcall(function() currentHumanoid:ChangeState(Enum.HumanoidStateType.Running) end)
        end
        if HUB.StealTeleport.nonce == nonce then
            HUB.StealTeleport.active = false
        end
    end

    local speedGuardTripped = false
    local function checkOutboundSpeedGuard()
        if HUB.StealGlide and HUB.StealGlide.speedGuard == true
            and type(CheckEggTravelSpeedRise) == "function"
            and CheckEggTravelSpeedRise() then
            speedGuardTripped = true
            return true
        end
        return false
    end

    local ok = pcall(function()
        -- Teleport is a single PivotTo, but RequestStreamAroundAsync can yield.
        -- Check before/after that yield so a treadmill speed rise still causes
        -- the same jump-and-retry recovery as the grounded glide route.
        if checkOutboundSpeedGuard() then return end
        pcall(function() LP:RequestStreamAroundAsync(target) end)
        if shouldCancel and shouldCancel() then return end
        if checkOutboundSpeedGuard() then return end
        if HUB.StealTeleport.nonce ~= nonce or HUB.dead then return end

        local destination = target + Vector3.new(0, tonumber(yOffset) or 0.4, 0)
        local rotation = root.CFrame.Rotation
        humanoid.AutoRotate = false
        humanoid.PlatformStand = false
        root.Anchored = true
        character:PivotTo(CFrame.new(destination) * rotation)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        finished = true
        task.wait(0.05)
        checkOutboundSpeedGuard()
    end)
    cleanup()

    if not ok or speedGuardTripped or not finished or shouldCancel and shouldCancel() then return false end
    local finalRoot = findHRP()
    if not finalRoot then return false end
    local horizontal = Vector3.new(
        finalRoot.Position.X - target.X,
        0,
        finalRoot.Position.Z - target.Z
    ).Magnitude
    return horizontal <= 10
        and math.abs(finalRoot.Position.Y - (target.Y + (tonumber(yOffset) or 0.4))) <= 12
end

-- Teleport mode also uses the outbound treadmill-path recovery.  Keep the
-- watcher scoped to this exact egg leg: if the speed rises, JumpAfter... has
-- already fired, then wait for a grounded Humanoid before retrying the same
-- UID instead of continuing with another PivotTo while airborne.
HUB.MoveEggTeleportGuarded = function(target, shouldCancel, yOffset, retryCount)
    local glide = HUB.StealGlide
    if not glide or type(HUB.StealTeleport) ~= "table"
        or type(HUB.StealTeleport.To) ~= "function" then
        return false
    end
    local previousGuard = glide.speedGuard == true
    local attempts = math.max(1, math.floor(tonumber(retryCount) or 2))
    local moved = false
    glide.speedGuard = true
    for attempt = 1, attempts do
        if shouldCancel and shouldCancel() then break end
        BeginEggTravelSpeedWatch()
        local ok = HUB.StealTeleport.To(target, shouldCancel, yOffset)
        local speedRose = EndEggTravelSpeedWatch()
        if speedRose then
            if not WaitForEggTravelLanding(2.5) then break end
            if attempt < attempts then task.wait(0.06) end
        else
            moved = ok == true
            break
        end
    end
    glide.speedGuard = previousGuard
    pcall(EndEggTravelSpeedWatch)
    return moved
end

local function FlyToPoint(target, speed, easeOut)
    if type(HUB.CanMovementOwnerProceed) == "function"
        and not HUB.CanMovementOwnerProceed(HUB.StealGlide and HUB.StealGlide.owner) then
        return false
    end
    if HUB.AutoStealMovementActive == true and autoStealEnabled ~= true and not carryingEggReturnActive then
        return false
    end
    -- Auto Steal uses the grounded Suji-style governor even when the UI is set
    -- to Fly Glide. Flying CFrame/velocity deltas are the path most likely to
    -- be classified as anti-TP by the server.
    if HUB.AutoStealMovementActive == true and autoStealEnabled == true then
        return MoveToPoint(target, speed, easeOut)
    end
    local hrp = findHRP()
    if not hrp or not target then return false end
    if CheckEggTravelSpeedRise() then return false end
    local start = hrp.Position
    local dist = (target - start).Magnitude
    if dist < 1.0 then
        hrp.CFrame = CFrame.new(target.X, math.max(target.Y, 70.0), target.Z)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        return true
    end

    speed = math.clamp(tonumber(speed) or tonumber(glideSpeed) or 750, 50, 1000)
    if HUB.AutoStealMovementActive == true and not carryingEggReturnActive then
        speed = math.min(speed, AUTO_STEAL_SAFE_SPEED)
    end
    local moveTime = math.max(dist / speed, 0.02)
    if easeOut then
        moveTime = moveTime * 1.25
    end

    local t0 = os.clock()
    local delta = target - start
    local dir = delta.Magnitude > 0.001 and delta.Unit or Vector3.new(1, 0, 0)

    while os.clock() - t0 < moveTime and not HUB.dead do
        if type(HUB.CanMovementOwnerProceed) == "function"
            and not HUB.CanMovementOwnerProceed(HUB.StealGlide and HUB.StealGlide.owner) then
            return false
        end
        if HUB.StealGlide and HUB.StealGlide.owner == "manual"
            and HUB.MovementLease and HUB.MovementLease.owner == "manual" then
            HUB.MovementLease.lastAt = os.clock()
        end
        if HUB.AutoStealMovementActive == true and autoStealEnabled ~= true and not carryingEggReturnActive then
            return false
        end
        local dt = RunService.Heartbeat:Wait()
        if type(HUB.CanMovementOwnerProceed) == "function"
            and not HUB.CanMovementOwnerProceed(HUB.StealGlide and HUB.StealGlide.owner) then
            return false
        end
        if CheckEggTravelSpeedRise() then return false end
        local linearAlpha = math.clamp((os.clock() - t0) / moveTime, 0, 1)

        local a = linearAlpha
        if easeOut then
            a = math.sin(linearAlpha * (math.pi / 2))
        end

        local cur = start:Lerp(target, a)
        hrp.CFrame = CFrame.lookAt(cur, cur + dir)

        local curSpeed = speed
        if easeOut then
            curSpeed = math.max(speed * (1 - linearAlpha * 0.8), 35)
        end
        hrp.AssemblyLinearVelocity = Vector3.new(dir.X * curSpeed, math.clamp(dir.Y * curSpeed, -15, 150), dir.Z * curSpeed)
        hrp.AssemblyAngularVelocity = Vector3.zero
    end

    if CheckEggTravelSpeedRise() then return false end
    local finalTarget = Vector3.new(target.X, math.max(target.Y, 70.0), target.Z)
    if (hrp.Position - finalTarget).Magnitude > 2.5 then
        return false
    end
    hrp.CFrame = CFrame.new(finalTarget)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    return true
end

local SAFE_BOUNDARY_X = 580 -- right before entering the safe zone
local SAFE_ZONE_SPEED = 245 -- 245 studs/s safe entry speed

local function TravelRoadPath(targetPos, speed, isApproach)
    if type(HUB.CanMovementOwnerProceed) == "function"
        and not HUB.CanMovementOwnerProceed(HUB.StealGlide and HUB.StealGlide.owner) then
        return false
    end
    local hrp = findHRP()
    if not hrp or not targetPos then return false end
    if avoidTrapsEnabled then pcall(NeutralizeTraps) end

    local startPos = hrp.Position
    local safeY = math.max(startPos.Y, targetPos.Y, 70.4)
    local isReturningToBase = (targetPos.X < 560)
    local baseEntryRoute = isReturningToBase and HUB.GetSafePlotReturnRoute(targetPos, safeY)

    if isReturningToBase and startPos.X > SAFE_BOUNDARY_X then
        -- 1. Sprint to main road at full speed (750 studs/s)
        local p1 = Vector3.new(startPos.X, safeY, MAIN_ROAD_Z)
        if not MoveToPoint(p1, speed, false) then return false end

        -- 2. Sprint along main road at full speed until 20 studs BEFORE safe zone
        local pSafeApproach = Vector3.new(SAFE_BOUNDARY_X, safeY, MAIN_ROAD_Z)
        if not MoveToPoint(pSafeApproach, speed, false) then return false end

        -- 3. Slow down to 245 studs/s before entering the safe zone.
        --    Never route directly through the actual treadmill.
        local pBaseRoad = Vector3.new(targetPos.X, safeY, MAIN_ROAD_Z)
        local treadmillRoute = GetTreadmillSafeRoute(Vector3.new(SAFE_BOUNDARY_X, safeY, MAIN_ROAD_Z), pBaseRoad, safeY)
        if treadmillRoute then
            for _, waypoint in ipairs(treadmillRoute) do
                if not MoveToPoint(waypoint, SAFE_ZONE_SPEED, false) then return false end
            end
        end
        if not MoveToPoint(pBaseRoad, SAFE_ZONE_SPEED, false) then return false end

        -- 4. Enter Plot 1/7 through orthogonal turns so the final leg does
        -- not cut the road-side wall. Other plots use the original endpoint.
        if baseEntryRoute then
            for _, waypoint in ipairs(baseEntryRoute) do
                if not MoveToPoint(waypoint, SAFE_ZONE_SPEED, waypoint == baseEntryRoute[#baseEntryRoute] and isApproach == true or false) then return false end
            end
        else
            if not MoveToPoint(targetPos + Vector3.new(0, 1.2, 0), SAFE_ZONE_SPEED, isApproach == true) then return false end
        end
        return true
    else
        local p1 = Vector3.new(startPos.X, safeY, MAIN_ROAD_Z)
        local p2 = Vector3.new(targetPos.X, safeY, MAIN_ROAD_Z)
        local p3 = targetPos + Vector3.new(0, 1.2, 0)

        if not MoveToPoint(p1, speed, false) then return false end
        -- Even when the player starts inside the safe zone, the road leg can
        -- still cross the treadmill trigger.  Apply the same two-point lane
        -- bypass on this shorter return path; the old branch only protected
        -- returns that began outside SAFE_BOUNDARY_X.
        local treadmillRoute = isReturningToBase and GetTreadmillSafeRoute(p1, p2, safeY)
        if treadmillRoute then
            for _, waypoint in ipairs(treadmillRoute) do
                if not MoveToPoint(waypoint, SAFE_ZONE_SPEED, false) then return false end
            end
        end
        if not MoveToPoint(p2, isReturningToBase and SAFE_ZONE_SPEED or speed, false) then return false end
        if baseEntryRoute then
            for index, waypoint in ipairs(baseEntryRoute) do
                if not MoveToPoint(waypoint, SAFE_ZONE_SPEED, index == #baseEntryRoute and isApproach == true or false) then return false end
            end
        else
            if not MoveToPoint(p3, speed, isApproach == true) then return false end
        end
        return true
    end
end

local function TravelFlyDirect(targetPos, speed, isApproach)
    local hrp = findHRP()
    if not hrp or not targetPos then return false end
    if avoidTrapsEnabled then pcall(NeutralizeTraps) end

    local startPos = hrp.Position
    local isReturningToBase = (targetPos.X < 560)
    local flyAltitude = math.max(startPos.Y, targetPos.Y, 70.4) + 28
    local baseEntryRoute = isReturningToBase and HUB.GetSafePlotReturnRoute(targetPos, 70.4)

    if isReturningToBase and startPos.X > SAFE_BOUNDARY_X then
        -- Fly at full speed (750 studs/s) until right before safe zone
        local pSky1 = Vector3.new(startPos.X, flyAltitude, startPos.Z)
        local pSkySafe = Vector3.new(SAFE_BOUNDARY_X, flyAltitude, MAIN_ROAD_Z)
        if not FlyToPoint(pSky1, speed, false) then return false end
        if not FlyToPoint(pSkySafe, speed, false) then return false end

        -- Descend and slow down to 245 studs/s before entering safe zone
        local pGroundSafe = Vector3.new(SAFE_BOUNDARY_X, 70.4, MAIN_ROAD_Z)
        if not FlyToPoint(pGroundSafe, SAFE_ZONE_SPEED, false) then return false end

        local pBaseRoad = Vector3.new(targetPos.X, 70.4, MAIN_ROAD_Z)
        local treadmillRoute = GetTreadmillSafeRoute(Vector3.new(SAFE_BOUNDARY_X, 70.4, MAIN_ROAD_Z), pBaseRoad, 70.4)
        if treadmillRoute then
            for _, waypoint in ipairs(treadmillRoute) do
                if not MoveToPoint(waypoint, SAFE_ZONE_SPEED, false) then return false end
            end
        end
        if not MoveToPoint(pBaseRoad, SAFE_ZONE_SPEED, false) then return false end

        if baseEntryRoute then
            for index, waypoint in ipairs(baseEntryRoute) do
                if not MoveToPoint(waypoint, SAFE_ZONE_SPEED, index == #baseEntryRoute and isApproach == true or false) then return false end
            end
        else
            if not MoveToPoint(targetPos + Vector3.new(0, 1.2, 0), SAFE_ZONE_SPEED, isApproach == true) then return false end
        end
        return true
    else
        local totalDist = (targetPos - startPos).Magnitude
        if totalDist < 25 then
            FlyToPoint(Vector3.new(targetPos.X, math.max(targetPos.Y, 70.0) + 1.2, targetPos.Z), speed, isApproach == true)
            return true
        end

        local pSky1 = Vector3.new(startPos.X, flyAltitude, startPos.Z)
        local pSky2 = Vector3.new(targetPos.X, flyAltitude, targetPos.Z)
        local pGround = Vector3.new(targetPos.X, math.max(targetPos.Y, 70.0) + 1.2, targetPos.Z)

        if not FlyToPoint(pSky1, speed, false) then return false end
        if baseEntryRoute then
            local pRoadSky = Vector3.new(targetPos.X, flyAltitude, MAIN_ROAD_Z)
            if not FlyToPoint(pRoadSky, speed, false) then return false end
            if not FlyToPoint(Vector3.new(targetPos.X, 70.4, MAIN_ROAD_Z), SAFE_ZONE_SPEED, false) then return false end
            for index, waypoint in ipairs(baseEntryRoute) do
                if not MoveToPoint(waypoint, SAFE_ZONE_SPEED, index == #baseEntryRoute and isApproach == true or false) then return false end
            end
        else
            if not FlyToPoint(pSky2, speed, false) then return false end
            if not FlyToPoint(pGround, speed, isApproach == true) then return false end
        end
        return true
    end
end

local function TravelSafeWalk(targetPos)
    if type(HUB.CanMovementOwnerProceed) == "function"
        and not HUB.CanMovementOwnerProceed(HUB.StealGlide and HUB.StealGlide.owner) then
        return false
    end
    if HUB.AutoStealMovementActive == true and autoStealEnabled ~= true and not carryingEggReturnActive then
        return false
    end
    local hum = findHum()
    local hrp = findHRP()
    if not hum or not hrp or not targetPos then return false end
    if avoidTrapsEnabled then pcall(NeutralizeTraps) end

    local startPos = hrp.Position
    local p1 = Vector3.new(startPos.X, startPos.Y, MAIN_ROAD_Z)
    local p2 = Vector3.new(targetPos.X, targetPos.Y, MAIN_ROAD_Z)
    local p3 = targetPos + Vector3.new(0, 1.2, 0)
    local baseEntryRoute = targetPos.X < 560 and HUB.GetSafePlotReturnRoute(targetPos, math.max(startPos.Y, targetPos.Y, 70.4))
    local route = {p1}
    local treadmillRoute = GetTreadmillSafeRoute(p1, p2, math.max(startPos.Y, targetPos.Y, 70.4))
    if treadmillRoute then
        for _, waypoint in ipairs(treadmillRoute) do
            table.insert(route, waypoint)
        end
    end
    table.insert(route, p2)
    if baseEntryRoute then
        for _, waypoint in ipairs(baseEntryRoute) do
            table.insert(route, waypoint)
        end
    else
        table.insert(route, p3)
    end

    for _, pt in ipairs(route) do
        if type(HUB.CanMovementOwnerProceed) == "function"
            and not HUB.CanMovementOwnerProceed(HUB.StealGlide and HUB.StealGlide.owner) then
            return false
        end
        if HUB.StealGlide and HUB.StealGlide.owner == "manual"
            and HUB.MovementLease and HUB.MovementLease.owner == "manual" then
            HUB.MovementLease.lastAt = os.clock()
        end
        if HUB.AutoStealMovementActive == true and autoStealEnabled ~= true and not carryingEggReturnActive then
            return false
        end
        if HUB.dead then break end
        if CheckEggTravelSpeedRise() then return false end
        if HUB.AutoStealMovementActive == true and not carryingEggReturnActive then
            HUB.StealGlide.ResetMovementEvidence()
        end
        hum:MoveTo(pt)
        local t0 = os.clock()
        while (hrp.Position - pt).Magnitude > 4.5 and os.clock() - t0 < 5 and not HUB.dead do
            if type(HUB.CanMovementOwnerProceed) == "function"
                and not HUB.CanMovementOwnerProceed(HUB.StealGlide and HUB.StealGlide.owner) then
                return false
            end
            if HUB.StealGlide and HUB.StealGlide.owner == "manual"
                and HUB.MovementLease and HUB.MovementLease.owner == "manual" then
                HUB.MovementLease.lastAt = os.clock()
            end
            if CheckEggTravelSpeedRise() then return false end
            task.wait(0.05)
        end
        if (hrp.Position - pt).Magnitude > 4.5 then
            return false
        end
    end
    if HUB.AutoStealMovementActive == true and autoStealEnabled ~= true and not carryingEggReturnActive then
        return false
    end
    return true
end

local function TravelDirectSegment(targetPos, speed, easeOut)
    if stealMovementMethod == "Teleport" and HUB.StealTeleport
        and type(HUB.StealTeleport.To) == "function" then
        return HUB.StealTeleport.To(targetPos, nil, 0.4)
    end
    if stealMovementMethod == "Fly Glide" then
        return FlyToPoint(targetPos, speed, easeOut)
    end
    -- Legacy non-teleport modes keep the deterministic glide primitive.
    -- Humanoid MoveTo can steer back toward the treadmill collision volume
    -- while the egg is held.
    return MoveToPoint(targetPos, speed, easeOut)
end

local function TravelCarryingEggToBase(targetPos, speed, isApproach)
    local hrp = findHRP()
    if not hrp or not targetPos then return false end
    -- Keep the carry lock so the treadmill worker cannot take ownership, but
    -- use the exact same movement planner as the outbound leg.  The old
    -- carry-only route inserted a special treadmill detour, which made the
    -- return path visibly different and could leave the player off the road.
    local carrySpeed = math.min(tonumber(speed) or 450, 1000)
    if stealMovementMethod == "Fly Glide" then
        return TravelFlyDirect(targetPos, carrySpeed, isApproach)
    elseif stealMovementMethod == "Safe Walk" then
        return TravelSafeWalk(targetPos)
    end
    return TravelRoadPath(targetPos, carrySpeed, isApproach)
end

local function TravelToDestination(targetPos, speed, isApproach)
    if type(HUB.CanMovementOwnerProceed) == "function"
        and not HUB.CanMovementOwnerProceed(HUB.StealGlide and HUB.StealGlide.owner) then
        return false
    end
    -- Outbound routes must follow the user's Glide / Travel Speed slider. Some
    -- callers pass a conservative fallback (for example 300) for Rift/base
    -- handoffs; do not let that fallback override the configured travel speed.
    -- The carry leg keeps its explicit safe speed to avoid anti-TP correction.
    local travelSpeed = speed
    if not carryingEggReturnActive then
        travelSpeed = math.clamp(tonumber(glideSpeed) or tonumber(speed) or 750, 50, 1000)
    end
    local result
    local governedOwner = HUB.StealGlide
        and (HUB.StealGlide.owner == "rift" or HUB.StealGlide.owner == "place")
    if carryingEggReturnActive then
        -- The return leg always follows the Suji tween/glide path, even when
        -- Teleport is selected for the outbound target leg.
        result = TravelCarryingEggToBase(targetPos, travelSpeed, isApproach)
    elseif stealMovementMethod == "Teleport" and HUB.StealTeleport
        and type(HUB.StealTeleport.To) == "function" then
        result = HUB.StealTeleport.To(targetPos, nil, 0.4)
    elseif governedOwner and HUB.MoveEggRouteGuarded then
        -- Rift machine/trade movement uses the same grounded owner as field
        -- sourcing. This prevents a late speed marker from steering the
        -- character onto the treadmill path during the trade handoff.
        result = HUB.MoveEggRouteGuarded(targetPos, travelSpeed, nil, 2)
    elseif stealMovementMethod == "Fly Glide" then
        result = TravelFlyDirect(targetPos, travelSpeed, isApproach)
    elseif stealMovementMethod == "Safe Walk" then
        result = TravelSafeWalk(targetPos)
    else
        -- Legacy glide fallback for an unrecognised/older saved method.
        result = TravelRoadPath(targetPos, travelSpeed, isApproach)
    end
    if HUB.AutoStealMovementActive == true and autoStealEnabled ~= true and not carryingEggReturnActive then
        return false
    end
    if HUB.EggTravelSpeedWatch and HUB.EggTravelSpeedWatch.cancelled then return false end
    return result
end

-- ==============================================================================
-- Every carried return uses the same two-stage handoff: first settle at the
-- game's Safe Center, then enter the local plot. Going directly from a field
-- egg/Rift machine to the plot could cut through the plot wall, trigger the
-- treadmill, or leave the character in a stale movement owner after respawn.
HUB.ReturnViaSafeCenter = function(plotCenter, speed, shouldCancel)
    if typeof(plotCenter) ~= "Vector3" then return false end
    if type(HUB.CanMovementOwnerProceed) == "function"
        and not HUB.CanMovementOwnerProceed(HUB.StealGlide and HUB.StealGlide.owner) then
        return false
    end
    local root = findHRP()
    if not root then return false end

    local requestedSpeed = tonumber(speed) or tonumber(glideSpeed) or 600
    local directOwner = HUB.StealGlide.owner == "auto" or HUB.StealGlide.owner == "rift"
        or HUB.StealGlide.owner == "place"
    local autoOwner = autoStealEnabled == true and HUB.AutoStealMovementActive == true

    local moveStage = function(target)
        if shouldCancel and shouldCancel() then return false end
        if directOwner or autoOwner then
            if HUB.MoveEggRouteGuarded then
                return HUB.MoveEggRouteGuarded(target, requestedSpeed, shouldCancel, 2)
            end
            return HUB.StealGlide.To(target, requestedSpeed, shouldCancel)
        end
        if stealMovementMethod == "Teleport" then
            -- Teleport is never used for a carried return, including a
            -- manual/legacy owner that reaches this fallback branch.
            if HUB.MoveEggRouteGuarded then
                return HUB.MoveEggRouteGuarded(target, requestedSpeed, shouldCancel, 2)
            end
            return HUB.StealGlide.To(target, requestedSpeed, shouldCancel)
        end
        return TravelToDestination(target, requestedSpeed, true)
    end

    local safeCenter = HUB.StealGlide.SafeCenter()
    if typeof(safeCenter) == "Vector3" then
        local distanceToSafe = Vector3.new(
            root.Position.X - safeCenter.X,
            0,
            root.Position.Z - safeCenter.Z
        ).Magnitude
        if distanceToSafe > 8 then
            if not moveStage(safeCenter) then return false end
            task.wait(0.08)
            if carryingEggReturnActive and not WaitForEggTravelLanding(2.5) then
                return false
            end
        end

        -- Match Suji's close handoff before entering the plot. The long leg
        -- remains governed; this only corrects a small final XYZ offset at the
        -- safe center after the character has arrived and settled.
        local settledRoot = findHRP()
        if settledRoot then
            local settledDistance = Vector3.new(
                settledRoot.Position.X - safeCenter.X,
                0,
                settledRoot.Position.Z - safeCenter.Z
            ).Magnitude
            if settledDistance <= 8 then
                HUB.StealGlide.SnapNearXYZ(safeCenter, 1.2, 8)
            end
        end
    end

    for _ = 1, 5 do
        if shouldCancel and shouldCancel() then return false end
        local currentRoot = findHRP()
        if not currentRoot then return false end
        local distanceToPlot = Vector3.new(
            currentRoot.Position.X - plotCenter.X,
            0,
            currentRoot.Position.Z - plotCenter.Z
        ).Magnitude
        if distanceToPlot <= 8 then
            HUB.StealGlide.SnapNearXYZ(plotCenter, 1.2, 8)
            return true
        end
        if not moveStage(plotCenter) then return false end
        task.wait(0.35)

        local afterMoveRoot = findHRP()
        if afterMoveRoot then
            local afterMoveDistance = Vector3.new(
                afterMoveRoot.Position.X - plotCenter.X,
                0,
                afterMoveRoot.Position.Z - plotCenter.Z
            ).Magnitude
            if afterMoveDistance <= 12 then
                HUB.StealGlide.SnapNearXYZ(plotCenter, 1.2, 12)
                return true
            end
        end
    end

    local finalRoot = findHRP()
    if finalRoot and Vector3.new(
        finalRoot.Position.X - plotCenter.X,
        0,
        finalRoot.Position.Z - plotCenter.Z
    ).Magnitude <= 12 then
        HUB.StealGlide.SnapNearXYZ(plotCenter, 1.2, 12)
        return true
    end
    return false
end

-- RARITY & AREA DICTIONARIES (Dynamic scoring for Rare Egg Hunter)
-- ==============================================================================
local RARITY_SCORE_MAP = {
    ["Titan"]           = 1100,
    ["Divine"]          = 1000,
    ["Transcendent"]    = 1000,
    ["Superior"]        = 1000,
    ["Eternal"]         = 900,
    ["Limited"]         = 900,
    ["Secret"]          = 800,
    ["Exotic"]          = 800,
    ["Cosmic"]          = 700,
    ["Exclusive"]       = 700,
    ["Admin"]           = 700,
    ["Mythic"]          = 600,
    ["Mythical"]        = 600,
    ["Prismatic"]       = 600,
    ["Rainbow"]         = 600,
    ["Squishy God"]     = 600,
    ["BrainrotGod"]     = 600,
    ["Legendary"]       = 500,
    ["Epic"]            = 400,
    ["Rare"]            = 300,
    ["SuperRare"]       = 200,
    ["Celestial"]       = 200,
    ["Uncommon"]        = 200,
    ["Basic"]           = 100,
    ["Common"]          = 100,
}

-- Auto Steal priority uses the egg's real final value when the current game
-- build exposes it.  New/partial records can omit that value, so fall back to
-- the canonical rarity score instead of dropping the egg from the scan.
-- The boolean tells the sorter whether the number is an actual egg value or a
-- rarity fallback; values from different sources must not be compared as if
-- they were the same unit.
function HUB.GetAutoStealEggValue(record, rarityScore)
    -- Suji's "highest value" mode is based on the live earning-rate field
    -- (the value shown as $/s), not the egg's future hatch/sell payout.  Read
    -- that field first, including the shared Assets catalog, so the scanner
    -- cannot prefer a lower-income egg just because its hatch value is larger.
    local rate
    if type(HUB.WebLogGetRecordMoneyRate) == "function" then
        pcall(function() rate = HUB.WebLogGetRecordMoneyRate(record) end)
        rate = tonumber(rate)
        if rate and rate > 0 and rate < math.huge then return rate, true end
    end
    if type(record) == "table" then
        local rateKeys = {
            "EarningRate", "IncomePerSecond", "MoneyPerSecond", "CashPerSecond",
            "ProductionPerSecond", "EarningsPerSecond", "IncomePerSec", "MoneyPerSec",
            "CashPerSec", "RatePerSecond"
        }
        for _, key in ipairs(rateKeys) do
            local n = tonumber(record[key])
            if n and n > 0 and n < math.huge then rate = n break end
        end
    end
    if not rate and type(HUB.WebLogFindAssetInfo) == "function" then
        local ok, info = pcall(HUB.WebLogFindAssetInfo, record)
        if ok and type(info) == "table" then
            for _, key in ipairs({
                "EarningRate", "IncomePerSecond", "MoneyPerSecond", "CashPerSecond",
                "ProductionPerSecond", "EarningsPerSecond", "IncomePerSec", "MoneyPerSec",
                "CashPerSec", "RatePerSecond"
            }) do
                local n = tonumber(info[key])
                if n and n > 0 and n < math.huge then rate = n break end
            end
        end
    end
    if rate then return rate, true end

    -- Keep the old final-value resolver as a fallback for game revisions that
    -- do not publish an earning rate on either the field record or catalog.
    local value
    if type(HUB.WebLogGetFinalEggValue) == "function" then
        pcall(function() value = HUB.WebLogGetFinalEggValue(record) end)
    end
    value = tonumber(value)
    -- Hatch/sell value is useful only as a fallback.  Mark it as unknown for
    -- the value-first comparator so a record with a real $/s rate always wins
    -- over a record that only exposes a future payout number.
    if value and value > 0 and value < math.huge then return value, false end
    return tonumber(rarityScore) or 100, false
end

-- Rift quest priority only decides which missing field ingredient is sourced
-- first; the normal place/hatch/trade lifecycle handles all three quest slots.
local RIFT_QUEST_RARITY_PRIORITY = {
    Eternal = 4000,
    Secret = 3000,
    Titan = 2000,
    Divine = 1000,
}

RIFT_IDENTITY_FIELDS = {
    "AssetCategory", "Category", "EggName", "PetName", "AnimalName", "AssetName",
    "DisplayName", "Name", "AssetId", "EggId", "PetId", "AnimalId", "ItemId", "Id",
    "Rarity", "RarityName", "RarityType", "RarityId", "Tier",
    "Attributes", "attributes", "Stats", "stats",
    "Asset", "Pet", "Animal", "PetData", "AnimalData", "AssetData", "Data", "Info",
    "Config", "Properties", "Metadata",
}

function riftIdentityKey(value)
    return string.lower(tostring(value or "")):gsub("&", "and"):gsub("[^%w]+", "")
end

-- Inventory snapshots are not consistent across game updates: a hatched pet
-- may expose its name directly, through PetData/AssetData, or only through a
-- catalog id. Collect the common identity fields without walking arbitrary
-- tables deeply (which also keeps this path safe for large save snapshots).
function riftCollectIdentityValues(value, output, seen, depth)
    if value == nil then return end
    local kind = type(value)
    if kind == "string" or kind == "number" then
        output[#output + 1] = value
        return
    end
    if kind ~= "table" or depth > 2 or seen[value] then return end
    seen[value] = true
    for _, field in ipairs(RIFT_IDENTITY_FIELDS) do
        local child = value[field]
        if child ~= nil then
            riftCollectIdentityValues(child, output, seen, depth + 1)
        end
    end
end

function riftIdentityKeys(value)
    local values, keys = {}, {}
    riftCollectIdentityValues(value, values, {}, 0)
    for _, item in ipairs(values) do
        local key = riftIdentityKey(item)
        if key ~= "" then keys[key] = true end
    end
    return keys
end

function riftRequirementLabel(requirement)
    if type(requirement) ~= "table" then return tostring(requirement or "") end
    local values = {}
    riftCollectIdentityValues(requirement, values, {}, 0)
    return tostring(values[1] or "")
end

local function riftRequirementPriority(requirement, candidate)
    local best = 0
    local function inspect(value)
        local text = string.lower(tostring(value or "")):gsub("[^%a]+", " ")
        for rarity, score in pairs(RIFT_QUEST_RARITY_PRIORITY) do
            local token = string.lower(rarity)
            if text == token or text:match("%f[%a]" .. token .. "%f[%A]") then
                best = math.max(best, score)
            end
        end
    end
    local record = candidate and (candidate.record or candidate)
    inspect(riftRequirementLabel(requirement))
    if type(record) == "table" then
        inspect(record.Rarity)
        inspect(record.RarityName)
        inspect(record.RarityType)
        inspect(record.Tier)
        inspect(record.DisplayName)
        inspect(record.Name)
        inspect(record.EggName)
    end
    return best
end

local AREA_COORDINATES = {
    ["Base / Plot"]      = Vector3.new(491.7, 70.4, -364.4),
    ["Stands & Shops"]   = Vector3.new(539.5, 68.0, -364.5),
    ["Forest"]           = Vector3.new(596.0, 68.0, -328.0),
    ["Lake"]             = Vector3.new(744.0, 68.5, -408.0),
    ["Desert"]           = Vector3.new(948.0, 69.5, -323.0),
    ["Jungle"]           = Vector3.new(1188.0, 68.5, -408.0),
    ["Snow"]             = Vector3.new(1492.0, 69.0, -315.0),
    ["Volcano"]          = Vector3.new(1882.0, 68.0, -398.0),
    ["Abyss Ocean"]      = Vector3.new(2280.0, 68.0, -326.0),
    ["Prehistoric"]      = Vector3.new(2812.0, 69.0, -398.0),
    ["Cosmic"]           = Vector3.new(3390.0, 68.0, -324.0),
    ["Cherry Blossom"]   = Vector3.new(4028.0, 68.5, -396.0),
    ["Titan Temple"]     = Vector3.new(4796.0, 69.5, -328.0),
    ["Monster Event"]    = Vector3.new(539.5, 68.0, -411.3),
    ["Dragon Event"]     = Vector3.new(539.5, 68.0, -318.0),
}

local AREA_NAMES = {
    "Forest", "Lake", "Desert", "Jungle", "Snow", "Volcano",
    "Abyss Ocean", "Prehistoric", "Cosmic", "Cherry Blossom", "Titan Temple",
    -- The UI label is the game's new biome name.  The live field record still
    -- emits AreaId = "Light Dark", which is normalized below.
    "Angels & Darks", "Monster Event", "Dragon Event"
}

-- Keep the area list in sync with the live Areas directory so a new biome can
-- be selected without a hard-coded update.  The values are IDs, matching
-- Suji's filter (not the UI display label).
pcall(function()
    local areasDir = AreasData and (AreasData.Directory or AreasData)
    local seen = {}
    for _, name in ipairs(AREA_NAMES) do seen[name] = true end
    if type(areasDir) == "table" then
        for areaId, areaInfo in pairs(areasDir) do
            local areaKey = type(areaId) == "string"
                and string.lower(areaId):gsub("[^%w]+", "")
                or ""
            local isLightDarkAlias = areaKey == "lightdark"
                or areaKey == "angelsdarks"
                or areaKey == "angelsanddarks"
                or areaKey == "angelsdemons"
                or areaKey == "angelsanddemons"
            if type(areaId) == "string" and areaId ~= "" and type(areaInfo) == "table"
                and areaInfo.DropTable ~= nil and not seen[areaId] and not isLightDarkAlias then
                table.insert(AREA_NAMES, areaId)
                seen[areaId] = true
            end
        end
    end
end)

-- The live field value is exactly "Light Dark" while the UI displays
-- "Angels & Darks". Keep old labels/configs working as aliases.
AREA_ID_ALIASES = {
    -- NormalizeAreaIdKey("Angels & Darks") => "angelsdarks".
    angelsdarks = "lightdark",
    angelsanddarks = "lightdark",
    angelsdemons = "lightdark",
    angelsanddemons = "lightdark",
    lightdark = "lightdark",
}

function NormalizeAreaIdKey(value)
    return string.lower(tostring(value or "")):gsub("[^%w]+", "")
end

-- The live field snapshot normally exposes AreaId. Keep fallbacks for updates
-- that move the same biome value to a display-name or biome field.
function GetEggAreaId(record)
    if type(record) ~= "table" then return nil end
    local fields = {
        "AreaId", "AreaID", "AreaName", "Area", "Biome", "BiomeName", "BiomeId",
        "Zone", "ZoneName", "Location", "LocationName", "Map", "MapId", "MapName",
        "Region", "WorldArea",
    }
    for _, field in ipairs(fields) do
        local value = record[field]
        if type(value) == "table" then
            value = value.AreaId or value.AreaID or value.Id or value.Name
                or value.DisplayName or value.NameId
        end
        if type(value) == "string" then
            value = value:gsub("^%s+", ""):gsub("%s+$", "")
            if value ~= "" then return value end
        elseif value ~= nil then
            return value
        end
    end

    -- A few live map replicas omit AreaId entirely and only send the egg XYZ.
    -- Infer the nearest known biome as a conservative fallback so an area
    -- checkbox does not turn into an unexplained no-match after refresh. Keep
    -- the radius tight and never classify an unknown point by a distant area.
    local position = GetFieldEggPosition(record)
    if position and type(AREA_COORDINATES) == "table" then
        local nearest, nearestDistance
        for areaName, center in pairs(AREA_COORDINATES) do
            if areaName ~= "Base / Plot" and areaName ~= "Stands & Shops"
                and areaName ~= "Monster Event" and areaName ~= "Dragon Event"
                and typeof(center) == "Vector3" then
                local dx = position.X - center.X
                local dz = position.Z - center.Z
                local distance = math.sqrt(dx * dx + dz * dz)
                if distance <= 105 and (not nearestDistance or distance < nearestDistance) then
                    nearest, nearestDistance = areaName, distance
                end
            end
        end
        if nearest then return nearest end
    end
    return nil
end

local RARITY_NAMES = {
    "Titan", "Divine", "Superior", "Eternal", "Limited",
    "Secret", "Exotic", "Cosmic", "Exclusive", "Mythical", "Rainbow",
    "Squishy God", "Legendary", "Epic", "Rare", "Uncommon", "Common"
}

-- Rift recipes use asset categories (pet/egg names), not rarity labels. Keep a
-- useful default list and extend it from the live asset catalog when available.
local RIFT_CATEGORY_OPTIONS = {
    "Ankylosaurus", "Beluga Whale", "Bladehide", "Centapede", "Chillin Chilli",
    "Dodo", "Eternal Lunar Dragon", "Gorilla King", "King Mammoth", "Koi",
    "Kraken", "La Vacca Saturno Saturnita", "Mantaris", "Penguin", "Red Panda",
    "Rhinotaur", "Snowy Owl", "Spideron", "T-Rex", "Triceratops",
}
pcall(function()
    local dir = AssetsData and (AssetsData.Directory or AssetsData)
    local seen = {}
    for _, name in ipairs(RIFT_CATEGORY_OPTIONS) do seen[name] = true end
    if type(dir) == "table" then
        for key, info in pairs(dir) do
            local label = type(info) == "table" and (info.DisplayName or info.Name or info.PetName) or key
            label = tostring(label or key)
            if label ~= "" and not seen[label] then
                table.insert(RIFT_CATEGORY_OPTIONS, label)
                seen[label] = true
                if #RIFT_CATEGORY_OPTIONS >= 80 then break end
            end
        end
    end
    table.sort(RIFT_CATEGORY_OPTIONS)
end)

-- The seller accepts asset categories as well as rarities. Keep one
-- catalog-backed option list for both seller controls so newly added game
-- assets remain selectable without another script update.
local SELL_CATEGORY_OPTIONS = {}
pcall(function()
    local seen = {}
    for _, name in ipairs(RIFT_CATEGORY_OPTIONS) do
        name = tostring(name)
        if name ~= "" and not seen[name] then
            table.insert(SELL_CATEGORY_OPTIONS, name)
            seen[name] = true
        end
    end
    local dir = AssetsData and (AssetsData.Directory or AssetsData)
    if type(dir) == "table" then
        for key, info in pairs(dir) do
            local label = type(info) == "table"
                and (info.DisplayName or info.Name or info.PetName or info.EggName)
                or key
            label = tostring(label or key or "")
            if label ~= "" and not seen[label] then
                table.insert(SELL_CATEGORY_OPTIONS, label)
                seen[label] = true
            end
        end
    end
    table.sort(SELL_CATEGORY_OPTIONS)
end)

local MUTATION_FILTERS = {
    "Normal Only", "Mutated Only", "Parasite / Infested", "Rainbow Only", "Gold Only", "Silver Only", "Monstrous"
}

-- ==============================================================================
-- AUTOMATION STATE & PERSISTENT RETURN POSITION
-- ==============================================================================
local rareEggHunter             = true
local stealParasiteOnly         = false
local stealBigEggsOnly          = false
local selectedStealRarities     = {}
local selectedStealAreas        = {}
local selectedMutationTypes     = {}
-- Keep handles so a loaded UI config cannot leave the visible MultiSelect
-- state different from the values used by the worker.
    -- Never reuse handles from a previous script reload. A stale handle can
    -- return an empty table for one scan and accidentally turn Area filtering
    -- into "all maps" even though the new UI visibly shows selected areas.
    HUB.StealFilterHandles          = {}

-- Oxide builds have returned MultiSelect values as a string array, a
-- {label = true} map, or an indexed boolean map. Normalize all three shapes
-- before the Auto Steal worker applies a rarity/area restriction.
function HUB.NormalizeStealFilterSelection(selection, options)
    local normalized, seen = {}, {}
    if type(selection) ~= "table" then return normalized, false end
    local recognized = next(selection) == nil
    local zeroBased = selection[0] ~= nil

    local function optionLabel(candidate)
        if candidate == nil or type(options) ~= "table" then return nil end
        local raw = tostring(candidate)
        local key = string.lower(raw):gsub("[^%w]+", "")
        for _, option in ipairs(options) do
            local optionKey = string.lower(tostring(option)):gsub("[^%w]+", "")
            if key == optionKey then return option end
        end
        -- A saved/UI selection may contain the live catalog `_id` instead of
        -- the display label (for example Etheral -> Eternal). Resolve it
        -- through the catalog aliases before treating the option as unknown.
        if options == RARITY_NAMES and type(HUB.LiveRarityAliases) == "table" then
            local liveCanonical = HUB.LiveRarityAliases[key]
            if liveCanonical then
                local canonicalKey = string.lower(tostring(liveCanonical)):gsub("[^%w]+", "")
                for _, option in ipairs(options) do
                    local optionKey = string.lower(tostring(option)):gsub("[^%w]+", "")
                    if optionKey == canonicalKey then return option end
                end
            end
        end
        if options == RARITY_NAMES then
            local compactAlias = {
                etheral = "eternal", ethereal = "eternal", eternal = "eternal",
                mythic = "mythical",
            }
            local canonicalKey = compactAlias[key]
            if canonicalKey then
                for _, option in ipairs(options) do
                    local optionKey = string.lower(tostring(option)):gsub("[^%w]+", "")
                    if optionKey == canonicalKey then return option end
                end
            end
        end
        -- The new biome's UI label and live map id are different strings.
        if options == AREA_NAMES then
            local canonical = AREA_ID_ALIASES[key] or key
            for _, option in ipairs(options) do
                local optionKey = NormalizeAreaIdKey(option)
                if (AREA_ID_ALIASES[optionKey] or optionKey) == canonical then
                    return option
                end
            end
        end
        return nil
    end

    local function add(candidate)
        local label = optionLabel(candidate)
        if not label then return false end
        recognized = true
        if not seen[label] then
            seen[label] = true
            normalized[#normalized + 1] = label
        end
        return true
    end

    for key, value in pairs(selection) do
        local label, active
        if type(value) == "string" and value ~= "" then
            label = value
            active = true
        elseif value == true then
            if type(key) == "string" then
                label = key
                active = true
            elseif type(key) == "number" and type(options) == "table" then
                -- Support both one-based and zero-based indexed selections
                -- when the UI exposes index zero in its state table.
                label = zeroBased and options[key + 1] or options[key]
                active = label ~= nil
            end
        elseif value == false then
            -- Oxide's MultiSelect can return every option as a boolean map.
            -- A map containing only false values is still a real, intentional
            -- empty selection.  It must clear the previous filter instead of
            -- being treated as an unreadable value and leaving old rarities or
            -- areas active in the worker.
            if type(key) == "string" then
                label = key
            elseif type(key) == "number" and type(options) == "table" then
                label = zeroBased and options[key + 1] or options[key]
            end
            active = false
        elseif type(value) == "number" and type(key) == "string" then
            -- A few MultiSelect builds use 1/0 instead of true/false.
            label = key
            active = value ~= 0
        elseif type(value) == "table" then
            active = value.Selected == true or value.Enabled == true
                or value.Checked == true or value.Active == true
                or value.Value == true
            label = value.Name or value.Label or value.Text or value.Option
            if type(value.Value) == "string" then
                label = value.Value
                active = active or value.Selected ~= false
            end
            if not label and type(key) == "string" then
                label = key
            end
        end
        if label ~= nil and optionLabel(label) ~= nil then
            recognized = true
            if active then add(label) end
        end
    end
    return normalized, recognized
end

function HUB.StealFilterSignature(selection)
    local keys = {}
    if type(selection) ~= "table" then return "" end
    for key, value in pairs(selection) do
        local label
        if type(value) == "string" and value ~= "" then
            label = value
        elseif value == true and type(key) == "string" then
            label = key
        end
        if label then
            keys[#keys + 1] = string.lower(tostring(label)):gsub("[^%w]+", "")
        end
    end
    table.sort(keys)
    return table.concat(keys, "|")
end

-- A changed dropdown selection invalidates the current target route. The
-- worker dismounts only an active Auto Steal target; a plain map refresh is
-- data-only and must not make a treadmill user jump in place.
HUB.AutoStealFilterRefreshRequested = false
HUB.AutomationWakeEpoch = HUB.AutomationWakeEpoch or 0
HUB.FieldEggSnapshotState = HUB.FieldEggSnapshotState or {
    signature = "",
    revision = 0,
    lastAt = 0,
    lastGoodAt = 0,
    nextRefreshAt = 0,
    dirty = true,
    refreshing = false,
    signalAt = 0,
    rebuildUntil = 0,
    lastError = "",
}
-- A map refresh is a data event, not a movement command.  Keep a small
-- settling window so an empty/partial replica cannot make Auto Treadmill
-- dismount and remount while Auto Steal is still deciding whether a selected
-- rarity/area target exists.
HUB.AutoStealTargetScanState = HUB.AutoStealTargetScanState or {
    noMatchSince = 0,
    noMatchRevision = -1,
    lastMatchAt = 0,
    lastCount = 0,
}
HUB.WakeAutomation = function(reason)
    HUB.AutomationWakeEpoch = (tonumber(HUB.AutomationWakeEpoch) or 0) + 1
    HUB.AutomationWakeReason = tostring(reason or "state changed")
end
HUB.InvalidateFieldEggSnapshot = function(reason)
    local tracker = HUB.FieldEggSnapshotState
    if type(tracker) ~= "table" then return false end
    local now = os.clock()
    -- Drop the previous live replica immediately. Keeping it here made a
    -- map/Rift refresh look like the old round when the server reused the
    -- same UID/coordinates; the empty-response grace path then returned the
    -- stale list and the orchestrator never rebuilt its target set.
    HUB.LiveFieldEggSnapshot = nil
    HUB.LiveFieldEggIndex = {}
    tracker.signature = ""
    tracker.dirty = true
    tracker.nextRefreshAt = 0
    tracker.signalAt = now
    tracker.rebuildUntil = now + 0.4
    tracker.lastError = tostring(reason or "field egg replica changed")
    local targetScan = HUB.AutoStealTargetScanState
    if targetScan then
        targetScan.noMatchSince = 0
        targetScan.noMatchRevision = -1
        targetScan.lastCount = 0
    end
    -- A failed target is only ignored for the current field replica. Do not
    -- carry that suppression into a new round where the same UID can spawn
    -- again.
    if HUB.IgnoredFieldEggs then
        for uid in pairs(HUB.IgnoredFieldEggs) do
            HUB.IgnoredFieldEggs[uid] = nil
        end
    end
    -- A map/Rift refresh is also a live Auto Steal rescan trigger.  Do this at
    -- the signal itself, not only when the next snapshot happens to differ;
    -- some servers reuse the same UID/coordinates for a new round.
    if autoStealEnabled == true then
        HUB.AutoStealFilterRefreshRequested = true
    end
    HUB.WakeAutomation("field egg refresh requested")
    return true
end
HUB.MarkFieldEggSnapshot = function(snapshot)
    if type(snapshot) ~= "table" or type(snapshot.Records) ~= "table" then return false end
    -- Keep a live, unfiltered copy even when Auto Steal is disabled.  Suji
    -- refreshes the field replica independently from the movement toggle;
    -- the orchestrator decides later whether this snapshot may start a route.
    local now = os.clock()
    HUB.LiveFieldEggSnapshot = snapshot
    HUB.LiveFieldEggIndex = {}
    HUB.FieldEggSnapshotChangedAt = now
    local parts = {}
    for key, record in pairs(snapshot.Records) do
        if type(record) == "table" then
            local uid = tostring(record.Uid or record.UID or record.EggUid or record.EggUID or key)
            HUB.LiveFieldEggIndex[uid] = record
            local state = tostring(record.State or record.Status or "")
            local area = tostring(record.AreaId or record.AreaName or record.Area or record.Biome or "")
            local category = tostring(record.AssetCategory or record.Category or record.EggName or record.Name or "")
            local position = GetFieldEggPosition(record)
            local xyz = position and string.format("%.1f,%.1f,%.1f", position.X, position.Y, position.Z) or ""
            parts[#parts + 1] = table.concat({ uid, state, area, category, xyz }, "~")
        end
    end
    table.sort(parts)
    local signature = table.concat(parts, "|")
    local tracker = HUB.FieldEggSnapshotState
    local changed = tracker.signature ~= signature
    tracker.lastAt = now
    tracker.lastGoodAt = now
    tracker.nextRefreshAt = now + 0.15
    tracker.dirty = false
    tracker.refreshing = false
    if next(snapshot.Records) ~= nil then tracker.rebuildUntil = 0 end
    tracker.lastError = ""
    if changed then
        tracker.signature = signature
        tracker.revision = (tonumber(tracker.revision) or 0) + 1
        -- A new field snapshot is a wake-up signal, not a second movement
        -- worker. The priority loop will rescan the selected filters on its
        -- next pass and cancel only an obsolete outbound target.
        HUB.WakeAutomation("field egg snapshot refreshed")
        if autoStealEnabled == true then HUB.AutoStealFilterRefreshRequested = true end
    end
    return changed
end
HUB.IsFieldEggSnapshotSettling = function()
    local tracker = HUB.FieldEggSnapshotState
    if type(tracker) ~= "table" then return false end
    return tracker.refreshing == true
        or tracker.dirty == true
        or os.clock() < (tonumber(tracker.rebuildUntil) or 0)
end
HUB.NoteAutoStealTargetScan = function(count)
    local state = HUB.AutoStealTargetScanState
    if type(state) ~= "table" then return end
    local now = os.clock()
    local tracker = HUB.FieldEggSnapshotState
    local revision = tracker and tonumber(tracker.revision) or 0
    count = tonumber(count) or 0
    state.lastCount = count
    if count > 0 then
        state.lastMatchAt = now
        state.noMatchSince = 0
        state.noMatchRevision = revision
        return
    end
    if state.noMatchRevision ~= revision or (tonumber(state.noMatchSince) or 0) <= 0 then
        state.noMatchRevision = revision
        state.noMatchSince = now
    end
end
HUB.IsAutoStealNoMatchSettled = function()
    local state = HUB.AutoStealTargetScanState
    if type(state) ~= "table" or (tonumber(state.noMatchSince) or 0) <= 0 then return false end
    if type(HUB.IsFieldEggSnapshotSettling) == "function" and HUB.IsFieldEggSnapshotSettling() then
        return false
    end
    -- Two short, stable reads are enough to avoid a stale/partial map frame;
    -- keep this below the normal worker interval so a real no-match falls back
    -- to Rift/Treadmill quickly.
    return os.clock() - state.noMatchSince >= 0.15
end
HUB.RequestAutoStealFilterRefresh = function()
    HUB.AutoStealFilterRefreshRequested = true
    HUB.AutoStealControllerEpoch = (tonumber(HUB.AutoStealControllerEpoch) or 0) + 1
    local targetScan = HUB.AutoStealTargetScanState
    if targetScan then
        targetScan.noMatchSince = 0
        targetScan.noMatchRevision = -1
        targetScan.lastCount = 0
    end
    HUB.WakeAutomation("Auto Steal filters changed")
end

HUB.ApplyAutoStealFilterSelection = function(kind, selection, options)
    local normalized, recognized = HUB.NormalizeStealFilterSelection(selection, options)
    if not recognized then return false end
    local previous
    if kind == "rarity" then
        previous = HUB.StealFilterSignature(selectedStealRarities)
        selectedStealRarities = normalized
    elseif kind == "area" then
        previous = HUB.StealFilterSignature(selectedStealAreas)
        selectedStealAreas = normalized
    elseif kind == "mutation" then
        previous = HUB.StealFilterSignature(selectedMutationTypes)
        selectedMutationTypes = normalized
    else
        return false
    end
    if previous ~= HUB.StealFilterSignature(normalized) then
        HUB.RequestAutoStealFilterRefresh()
    end
    return true
end

local stealDelay                = 1.5
local ignoredEggs               = {} -- [uid] = timestamp (prevents loops on failed eggs)
-- Expose the local table through HUB so refresh signals can clear it without
-- moving this declaration ahead of the snapshot invalidator.
HUB.IgnoredFieldEggs = ignoredEggs

-- Auto Treadmill handoff state: train only while there is no matching egg.
local autoTreadmillEnabled      = false
local treadmillTrainingActive   = false
HUB.TreadmillMounted            = HUB.TreadmillMounted == true
HUB.TreadmillMountedAt          = tonumber(HUB.TreadmillMountedAt) or 0
local treadmillHandoffBusy      = false
HUB.TreadmillHandoffAt          = 0
local treadmillLastNoMatchAt    = 0
local treadmillControllerEpoch  = 0
local treadmillResetRequested   = false
-- Incremented every time Auto Steal is toggled.  A route that was already
-- inside MoveToPoint must stop when the feature is turned off, even if the
-- user turns it back on before the old coroutine returns.
HUB.AutoStealControllerEpoch = HUB.AutoStealControllerEpoch or 0

-- Auto Steal uses a scoped no-clip while its movement controller is active.
-- Keep the original collision values so disabling Auto Steal (or unloading the
-- hub) never leaves the character permanently non-collidable.  This manager is
-- separate from the Rift Boss no-clip owner because both toggles may be on.
HUB.AutoStealNoClip = {
    active = false,
    character = nil,
    original = {},
    heartbeat = nil,
    descendantAdded = nil,
    nextRenderSweepAt = 0,
}

function HUB.StopAutoStealNoClip()
    local state = HUB.AutoStealNoClip
    if not state then return end
    state.active = false
    if state.heartbeat then
        pcall(function() state.heartbeat:Disconnect() end)
        state.heartbeat = nil
    end
    if state.descendantAdded then
        pcall(function() state.descendantAdded:Disconnect() end)
        state.descendantAdded = nil
    end

    -- Re-seat before restoring collision so a no-clip abort cannot restore a
    -- character that is already below the map.
    pcall(function()
        local current = LP.Character
        local root = current and current:FindFirstChild("HumanoidRootPart")
        HUB.StealGlide.KeepGrounded(root)
    end)

    -- If the boss owner is still active, leave collision disabled.  When Auto
    -- Steal started first, update the boss owner's saved value so stopping the
    -- boss later restores the player's real pre-no-clip collision state.
    local boss = riftBossNoClip
    local rift = HUB.RiftNoClip
    for part, original in pairs(state.original) do
        if part and part.Parent then
            if boss and boss.active then
                if boss.original[part] == false and original == true then
                    boss.original[part] = original
                end
                pcall(function() part.CanCollide = false end)
            elseif rift and rift.active then
                if rift.original[part] == false and original == true then
                    rift.original[part] = original
                end
                pcall(function() part.CanCollide = false end)
            else
                pcall(function() part.CanCollide = original end)
            end
        end
    end
    state.original = {}
    state.character = nil
end

function HUB.StartAutoStealNoClip()
    if (not autoStealEnabled and HUB.StealGlide.owner ~= "manual" and not carryingEggReturnActive) or HUB.dead then return false end
    local state = HUB.AutoStealNoClip
    local character = LP.Character
    if not state or not character or not character.Parent then return false end

    if state.character ~= character then
        if state.character then HUB.StopAutoStealNoClip() end
        state.character = character
    end
    state.active = true

    local function disableCollision(part)
        if not part or not part:IsA("BasePart") then return end
        -- Suji never turns the player's body into a ghost.  Doing that makes
        -- the Humanoid lose the floor and is the reason the character falls
        -- through the map when Auto Steal is enabled.
        if character and part:IsDescendantOf(character) then return end
        if state.original[part] == nil then
            state.original[part] = part.CanCollide
        end
        pcall(function() part.CanCollide = false end)
    end

    local function sweepSujiRenderCollisions()
        local now = os.clock()
        if now < (state.nextRenderSweepAt or 0) then return end
        state.nextRenderSweepAt = now + 0.5
        pcall(function()
            for _, child in ipairs(Workspace:GetChildren()) do
                local eligible = child:IsA("Tool")
                    or child.Name == "AreaEggSlotsClient"
                    or child.Name == "PlacedEggRenders"
                    or child.Name == "__ClientTreadmillRenders"
                    or child.Name == "ClientRenderedAssets"
                if eligible then
                    if child:IsA("BasePart") then
                        disableCollision(child)
                    end
                    for _, part in ipairs(child:GetDescendants()) do
                        disableCollision(part)
                    end
                end
            end
        end)
    end
    -- Discard a stale character listener from an older activation.  The
    -- periodic render sweep is enough for newly-created client egg visuals and
    -- avoids touching character descendants after a respawn.
    if state.descendantAdded then
        pcall(function() state.descendantAdded:Disconnect() end)
        state.descendantAdded = nil
    end
    sweepSujiRenderCollisions()
    if not state.heartbeat then
        state.heartbeat = track(RunService.Heartbeat:Connect(function()
            if not state.active or HUB.dead then return end
            if not autoStealEnabled and HUB.StealGlide.owner ~= "manual" and not carryingEggReturnActive then
                HUB.StopAutoStealNoClip()
                return
            end
            local current = LP.Character
            if current and current ~= state.character then
                HUB.StartAutoStealNoClip()
                return
            end
            if current then
                sweepSujiRenderCollisions()
                -- Suji's glide loop owns the root's Y/ground sample. A second
                -- recovery heartbeat can raycast the roof/arch above the
                -- player and write the root back to the same XYZ, producing
                -- the invisible-wall/warp-in-place symptom.
            end
        end))
    end
    return true
end

-- Rift Egg uses the same short-lived no-clip lease as the live quest route:
-- travel to the field egg/pen/Rift machine, place or trade, then restore the
-- character's original collision state.  It is a separate owner from Auto
-- Steal and Rift Boss so one feature cannot turn the other's no-clip off.
HUB.RiftNoClip = {
    active = false,
    character = nil,
    original = {},
    heartbeat = nil,
    descendantAdded = nil,
}

function HUB.StopRiftNoClip()
    local state = HUB.RiftNoClip
    if not state then return end
    state.active = false
    if state.heartbeat then
        pcall(function() state.heartbeat:Disconnect() end)
        state.heartbeat = nil
    end
    if state.descendantAdded then
        pcall(function() state.descendantAdded:Disconnect() end)
        state.descendantAdded = nil
    end

    local boss = riftBossNoClip
    local auto = HUB.AutoStealNoClip
    for part, original in pairs(state.original) do
        if part and part.Parent then
            if boss and boss.active then
                if boss.original[part] == false and original == true then
                    boss.original[part] = original
                end
                pcall(function() part.CanCollide = false end)
            elseif auto and auto.active then
                if auto.original[part] == false and original == true then
                    auto.original[part] = original
                end
                pcall(function() part.CanCollide = false end)
            else
                pcall(function() part.CanCollide = original end)
            end
        end
    end
    state.original = {}
    state.character = nil
end

function HUB.StartRiftNoClip()
    if HUB.dead then return false end
    local state = HUB.RiftNoClip
    local character = LP.Character
    if not state or not character or not character.Parent then return false end

    if state.character ~= character then
        if state.character then HUB.StopRiftNoClip() end
        state.character = character
    end
    state.active = true

    local function disableCollision(part)
        if not part or not part:IsA("BasePart") then return end
        -- Keep character collision intact so Rift travel cannot drop the
        -- Humanoid through the floor when the no-clip lease is armed.
        if character and part:IsDescendantOf(character) then return end
        if state.original[part] == nil then
            state.original[part] = part.CanCollide
        end
        pcall(function() part.CanCollide = false end)
    end

    for _, part in ipairs(character:GetDescendants()) do
        disableCollision(part)
    end
    if not state.descendantAdded then
        state.descendantAdded = track(character.DescendantAdded:Connect(function(descendant)
            if state.active and state.character == character then
                disableCollision(descendant)
            end
        end))
    end
    if not state.heartbeat then
        state.heartbeat = track(RunService.Heartbeat:Connect(function()
            if not state.active or HUB.dead then return end
            local current = LP.Character
            if current and current ~= state.character then
                HUB.StartRiftNoClip()
                return
            end
            if current then
                for _, part in ipairs(current:GetDescendants()) do
                    disableCollision(part)
                end
            end
        end))
    end
    return true
end

-- Forward declarations used by the passive Web Log status reporter below.
-- Keeping these as locals prevents the coroutine from resolving stale globals
-- before the automation controls are initialized later in this file.
local isPlayerCarryingEgg
local autoHatchEnabled
local autoPlantEnabled
local autoSellEggs
local autoSellPets
local PlantAllCarriedEggsInPen
local HatchAllReadyEggs
local eventState
local GetMatchingFieldEggs
local StealSpecificEggRobust
local ReleaseTreadmillForAction

-- Saved Return Position (automatically captured on first steal activation)
local savedReturnCFrame         = nil

-- Passive Web Log status keeps the dashboard useful between explicit actions.
task.spawn(function()
    while not HUB.dead do
        task.wait(1)
        if _G.AxelWebLog and _G.AxelWebLog.GetActivityAge and _G.AxelWebLog.SetActivity then
            local age = 99
            pcall(function() age = _G.AxelWebLog.GetActivityAge() end)
            if age >= 2.5 then
                local carryingEgg = false
                pcall(function() carryingEgg = isPlayerCarryingEgg and isPlayerCarryingEgg() == true end)
                local speedTraining = false
                pcall(function()
                    local state = HUB.WebLogSpeedState
                    speedTraining = state and tonumber(state.trainingUntil) and state.trainingUntil > os.clock()
                end)
                if carryingEggReturnActive or carryingEgg then
                    _G.AxelWebLog.SetActivity("Returning to Base", "Carrying an egg back to the base pen")
                elseif eventState.boss.enabled and (LP:GetAttribute("InBossArena") == true
                    or (eventState.boss.windowOpen == true and eventState.boss.defeatedWindow ~= eventState.boss.windowKey)
                    or eventState.boss.status == "starting"
                    or eventState.boss.status == "joining"
                    or eventState.boss.status == "fighting"
                    or eventState.boss.status == "arming"
                    or eventState.boss.status == "armed"
                    or eventState.boss.status == "leaving"
                    or eventState.boss.status == "respawning") then
                    _G.AxelWebLog.SetActivity("Rift Boss", eventState.boss.detail ~= "" and eventState.boss.detail or "Rift Boss is active")
                    if type(_G.AxelWebLog.SetArea) == "function" then pcall(_G.AxelWebLog.SetArea, "Rift Boss Arena") end
                elseif eventState.rift.enabled and (eventState.rift.acquiring or eventState.rift.placing
                    or eventState.rift.status == "sourcing"
                    or eventState.rift.status == "hatching"
                    or eventState.rift.status == "trading"
                    or eventState.rift.status == "reward"
                    or eventState.rift.status == "traded"
                    or eventState.rift.status == "refreshed") then
                    _G.AxelWebLog.SetActivity("The Rift", eventState.rift.detail ~= "" and eventState.rift.detail or "Rift quest is active")
                    if type(_G.AxelWebLog.SetArea) == "function" then pcall(_G.AxelWebLog.SetArea, "The Rift") end
                elseif speedTraining or (autoTreadmillEnabled and treadmillTrainingActive) then
                    _G.AxelWebLog.SetActivity("Training on Treadmill", speedTraining and "Speed increased; treadmill training detected" or "Auto Treadmill is active")
                    if type(_G.AxelWebLog.SetArea) == "function" then pcall(_G.AxelWebLog.SetArea, "Base / Plot") end
                elseif autoTreadmillEnabled then
                    _G.AxelWebLog.SetActivity("Scanning for Egg", "Auto Treadmill is waiting for a matching egg")
                    if type(_G.AxelWebLog.SetArea) == "function" then pcall(_G.AxelWebLog.SetArea, "Base / Plot") end
                elseif autoHatchEnabled then
                    _G.AxelWebLog.SetActivity("Hatching Eggs", "Auto Hatch is checking ready eggs")
                elseif autoPlantEnabled then
                    _G.AxelWebLog.SetActivity("Planting Eggs", "Auto Place is checking carried eggs")
                elseif autoSellEggs or autoSellPets then
                    _G.AxelWebLog.SetActivity("Selling", "Auto Sell is active")
                elseif autoStealEnabled then
                    _G.AxelWebLog.SetActivity("Searching for Egg", "Auto Steal is scanning for the best target")
                elseif eventState.boss.enabled and eventState.boss.detail ~= "" then
                    _G.AxelWebLog.SetActivity("Rift Boss", eventState.boss.detail)
                    if type(_G.AxelWebLog.SetArea) == "function" then pcall(_G.AxelWebLog.SetArea, "Rift Boss Arena") end
                elseif eventState.rift.enabled and eventState.rift.detail ~= "" then
                    _G.AxelWebLog.SetActivity("The Rift", eventState.rift.detail)
                    if type(_G.AxelWebLog.SetArea) == "function" then pcall(_G.AxelWebLog.SetArea, "The Rift") end
                else
                    _G.AxelWebLog.SetActivity("Idle", "No automation is currently active")
                end
            end
        end
    end
end)

autoHatchEnabled                = false
autoPlantEnabled                = false
local hatchCheckDelay           = 2.0

local autoUpgradeBase           = false
local autoUpgradeTreadmill      = false
local autoTrainSpeed            = false
local autoBuyTrails             = false
local autoEquipBestPets         = false
local autoClaimRewards          = false

autoSellPets                    = false
autoSellEggs                    = false
local selectedSellPetRarities   = {}
local selectedSellEggRarities   = {}
local selectedSellPetCategories = {}
local selectedSellEggCategories = {}

local SELL_REQUEST_DELAY = 0.1

local noKnockbackEnabled        = true
local batAuraEnabled            = false
local batAuraRadius             = 20
local batAuraDelay              = 0.2
local antiRagdollEnabled        = true

-- ============================================================================
-- THE RIFT / RIFT BOSS ADAPTER
-- ============================================================================
-- The game exposes these actions through Shared.Remotes. Axel keeps a small,
-- defensive adapter: remotes are resolved by group/name, every call is
-- protected with pcall, and the existing Axel Steal controller remains the
-- highest-priority owner.
eventState = {
    rift = { enabled = false, placeEgg = true, refresh = false, keepCats = {}, keepMode = "All 3 ticked", maxKg = 0, last = nil, roundSignature = "", traded = 0, pending = {}, placing = false, acquiring = false, scanSettling = false, fieldActionReady = false, previewAt = 0, status = "off", detail = "", lastActionAt = 0, lastHatchAt = 0, awaitingReward = false, rewardBeforeInventory = nil, rewardPayload = nil, rewardWaitUntil = 0 },
    boss = {
        enabled = false, shop = false, claim = false, shopItems = {}, status = "off", detail = "",
        controllerEpoch = 0, controllerPollAt = 0, windowOpen = false, inArena = false,
        hasEnteredArena = false, armPathSeen = false, armHealth = nil, armHealthSource = "", armHealthPositiveSeen = false,
        armHealthZeroSeen = false, armHealthZeroCandidateRevision = -1,
        armHealthZeroCandidateAt = 0, armInstance = nil,
        lastHealthAt = 0, leaveCompleted = false,
        hopLocked = false, sessionDefeated = false, defeatedAt = 0, hopAfterLeaveAt = 0,
        hopQueued = false, hopEnabled = false, hopExplicit = false, hopBusy = false,
        hopScheduleBusy = false, lastHopAt = 0,
        safeStageWindow = "", safeStageAt = 0, roundClosedObserved = false, arenaInstance = nil,
        -- One frozen combat leg.  The hand's position is captured once for
        -- movement; only its HP is sampled again.  This prevents an animated
        -- UpperHand1.R from becoming a per-pass movement target.
        combatLeg = nil,
        previousMovementOwner = nil,
        liveSnapshot = nil, snapshotAt = 0, snapshotRevision = 0,
        snapshotInFlight = false, snapshotError = "",
    },
    lastPoll = 0,
}
local eventRemoteCache = {}
local automationActionBusy = false
-- A protected worker can be interrupted after setting the shared busy flag.
-- Keep the timestamp on HUB so recovery can distinguish a live route from an
-- orphaned lock without adding more locals to the large controller.
HUB.AutomationBusyAt = 0

-- Keep the boss health proof separate from the generic event snapshot. The
-- only accepted health source is the live Boss.UpperHand1.R path; a zero
-- schedule/replication snapshot before arena entry must never arm a hop.
HUB.RecordRiftBossHealth = function(value, source)
    local boss = eventState and eventState.boss
    if not boss then return nil end
    -- The caller must pass the numeric value read from the exact
    -- Boss.UpperHand1.R instance. Reject tables so a generic BossHealth
    -- payload can never enter this proof state by accident.
    local health = tonumber(value)
    if health == nil then return nil end

    local exactBossHand = tostring(source or "") == "Boss.UpperHand1.R"
    -- Only the exact arm path can change the proof state. Snapshot/event
    -- payloads may contain a generic BossHealth value from another phase.
    if not exactBossHand then return nil end
    local active = boss.hasEnteredArena == true
        and boss.inArena == true
        and LP:GetAttribute("InBossArena") == true
    boss.armHealth = health
    boss.armHealthSource = tostring(source or "unknown")
    boss.lastHealthAt = os.clock()
    if active and health > 0 then
        boss.armHealthPositiveSeen = true
        boss.armHealthZeroSeen = false
        -- A transient/old zero must not survive a later live positive read.
        boss.armHealthZeroCandidateRevision = -1
        boss.armHealthZeroCandidateAt = 0
    elseif active and health == 0 and boss.armHealthPositiveSeen == true
        and boss.armHealthZeroSeen ~= true then
        -- Match Suji: zero is only a candidate first. The hand UI can briefly
        -- show 0 while the server is still finishing the phase transition.
        -- Require a stable zero window before leaving or arming a hop.
        if (tonumber(boss.armHealthZeroCandidateAt) or 0) <= 0 then
            boss.armHealthZeroCandidateAt = os.clock()
            boss.armHealthZeroCandidateRevision = tonumber(boss.snapshotRevision) or 0
        end
    end
    return health
end

HUB.ResetRiftBossRoundProof = function(boss)
    boss = boss or (eventState and eventState.boss)
    if not boss then return end
    boss.hasEnteredArena = false
    boss.armPathSeen = false
    boss.armHealth = nil
    boss.armHealthSource = ""
    boss.armHealthPositiveSeen = false
    boss.armHealthZeroSeen = false
    boss.armHealthZeroCandidateRevision = -1
    boss.armHealthZeroCandidateAt = 0
    boss.armInstance = nil
    boss.lastHealthAt = 0
    boss.liveSnapshot = nil
    boss.snapshotAt = 0
    boss.snapshotRevision = 0
    boss.snapshotInFlight = false
    boss.snapshotError = ""
    boss.defeatedWindow = nil
    boss.sessionDefeated = false
    boss.hopLocked = false
    boss.hopQueued = false
    boss.hopAfterLeaveAt = 0
    boss.leaveCompleted = false
    boss.leaving = false
    boss.lastSwing = 0
    boss.roundClosedObserved = false
    boss.previousMovementOwner = nil
    boss.safeStageWindow = ""
    boss.safeStageAt = 0
    boss.combatLeg = nil
    boss.lastEnter = 0
    -- A new arena proof starts with no server-hop transaction from the old
    -- arena. The helper is assigned immediately after this function and the
    -- guard keeps this reset safe during early bootstrap as well.
    if type(HUB.ClearRiftBossHopState) == "function" then
        HUB.ClearRiftBossHopState()
    end
end

-- A boss defeat may be observed by both the read-only poll and the action
-- worker.  Keep the hop queue/permit as one disposable transaction: Auto Boss
-- Rift alone must never inherit a permit from a previous round or coroutine.
HUB.ClearRiftBossHopState = function()
    local boss = eventState and eventState.boss
    if boss then
        boss.hopQueued = false
        boss.hopAfterLeaveAt = 0
        boss.hopBusy = false
        boss.hopScheduleBusy = false
    end
    local state = HUB.ServerHopState
    if state and type(state.HopPermit) == "table"
        and state.HopPermit.reason == "boss" then
        state.HopPermit = nil
    end
end

-- Central movement orchestrator.  UI toggles remain the user's desired state;
-- this layer only suspends lower-priority workers while one route owns the
-- character.  Ending an owner clears the suspension and therefore restores
-- every toggle exactly as it was before the handoff.
HUB.Orchestrator = HUB.Orchestrator or {
    owner = nil,
    epoch = 0,
    desired = { steal = false, treadmill = false, rift = false, boss = false },
    suspended = {},
    priority = { treadmill = 1, steal = 2, rift = 3, boss = 4 },
}
HUB.Orchestrator.Conflicts = {
    boss = { steal = true, treadmill = true, rift = true },
    rift = { steal = true, treadmill = true },
    steal = { treadmill = true },
    treadmill = {},
}
HUB.Orchestrator.SetDesired = function(route, enabled)
    local state = HUB.Orchestrator
    route = tostring(route or "")
    if state.desired[route] ~= nil then state.desired[route] = enabled == true end
end
HUB.Orchestrator.Allows = function(route)
    local state = HUB.Orchestrator
    return state.suspended[tostring(route or "")] ~= true
end
HUB.Orchestrator.Begin = function(owner)
    local state = HUB.Orchestrator
    owner = tostring(owner or "")
    if owner == "" then return false end
    local active = state.owner
    if active and active ~= owner
        and (state.priority[active] or 0) > (state.priority[owner] or 0) then
        return false
    end
    state.owner = owner
    state.epoch = (tonumber(state.epoch) or 0) + 1
    state.suspended = {}
    for route, blocked in pairs(state.Conflicts[owner] or {}) do
        if blocked then state.suspended[route] = true end
    end
    return true
end
HUB.Orchestrator.End = function(owner)
    local state = HUB.Orchestrator
    if owner ~= nil and state.owner ~= tostring(owner) then return false end
    state.owner = nil
    state.epoch = (tonumber(state.epoch) or 0) + 1
    state.suspended = {}
    return true
end
HUB.Orchestrator.GetState = function()
    local state = HUB.Orchestrator
    return state.owner, state.epoch, state.suspended, state.desired
end

-- Boss arena movement is an exclusive owner. The central priority worker sets
-- Orchestrator.owner before it starts Boss Rift movement; all other governed
-- routes must yield until that owner is released. A confirmed carried-egg
-- delivery is exempt only for its existing auto/rift/place route, since the
-- central scheduler deliberately waits for that delivery before Boss work.
HUB.BossMovementOwnsCharacter = function()
    return LP:GetAttribute("InBossArena") == true
        or (HUB.Orchestrator and HUB.Orchestrator.owner == "boss")
        or (riftBossNoClip and riftBossNoClip.active == true)
end
HUB.CanMovementOwnerProceed = function(owner)
    owner = owner ~= nil and tostring(owner) or ""
    local leaseOwner = HUB.MovementLease and HUB.MovementLease.owner
    if owner == "manual" or owner == "manual-fly" then
        return leaseOwner == owner and not HUB.BossMovementOwnsCharacter()
    end
    if leaseOwner == "manual" or leaseOwner == "manual-fly" then return false end
    if owner == "boss" then
        return HUB.Orchestrator and HUB.Orchestrator.owner == "boss"
            and leaseOwner == "priority" or false
    end
    if not HUB.BossMovementOwnsCharacter() then return true end
    return carryingEggReturnActive == true
        and (owner == "auto" or owner == "rift" or owner == "place")
end

-- One movement owner at a time.  The priority worker owns this lease for the
-- whole Suji-style Boss -> Auto Steal -> Rift -> Treadmill decision, while manual buttons
-- and delayed resume tasks must wait instead of writing HumanoidRootPart or
-- changing a no-clip lease underneath the active route.
HUB.MovementLease = HUB.MovementLease or { owner = nil, depth = 0, lastAt = 0 }
HUB.AcquireMovementLease = function(owner)
    local lease = HUB.MovementLease
    owner = tostring(owner or "")
    if owner == "" then return false end
    if lease.owner == nil then lease.depth = 0 end
    if lease.owner ~= nil and (tonumber(lease.depth) or 0) <= 0 then
        lease.owner, lease.depth = nil, 0
    end
    if lease.owner ~= nil and lease.owner ~= owner then return false end
    lease.owner = owner
    lease.depth = (tonumber(lease.depth) or 0) + 1
    lease.lastAt = os.clock()
    return true
end
HUB.ReleaseMovementLease = function(owner)
    local lease = HUB.MovementLease
    if lease.owner ~= tostring(owner or "") then return false end
    lease.depth = math.max(0, (tonumber(lease.depth) or 1) - 1)
    lease.lastAt = os.clock()
    if lease.depth == 0 then lease.owner = nil end
    return true
end
HUB.RunManualMovement = function(callback)
    if type(HUB.BossMovementOwnsCharacter) == "function"
        and HUB.BossMovementOwnsCharacter() then
        return false, "boss_owns_movement"
    end
    if HUB.MovementLease and HUB.MovementLease.owner ~= nil then
        return false, "movement_busy"
    end
    if type(callback) ~= "function" or not HUB.AcquireMovementLease("manual") then
        return false, "movement_busy"
    end
    local previousOwner = HUB.StealGlide and HUB.StealGlide.owner
    if HUB.StealGlide then HUB.StealGlide.owner = "manual" end
    local ok, result = pcall(callback)
    if HUB.StealGlide then HUB.StealGlide.owner = previousOwner end
    HUB.ReleaseMovementLease("manual")
    if not ok then
        if type(HUB.ReportAutomationError) == "function" then
            HUB.ReportAutomationError("Manual movement", result)
        end
        return false, result
    end
    return true, result
end
HUB.HasMovementAutomationIntent = function()
    local boss = eventState and eventState.boss
    local rift = eventState and eventState.rift
    return carryingEggReturnActive == true
        or HUB.AutoStealMovementActive == true
        or treadmillTrainingActive == true
        or treadmillHandoffBusy == true
        or HUB.ShelterMovementIntent == true
        or autoStealEnabled == true
        or autoTreadmillEnabled == true
        or autoPlantEnabled == true
        or autoFeedMonster == true
        or (boss and boss.enabled == true)
        or (rift and rift.enabled == true)
end

-- Recover only a genuinely orphaned lease. A route that is still carrying an
-- egg, mounted on the treadmill, inside Rift, or inside the boss arena must
-- keep its owner; a failed coroutine with no live route must not block every
-- other feature forever.
HUB.RecoverMovementLease = function()
    local lease = HUB.MovementLease
    if type(lease) ~= "table" then return false end
    if lease.owner == nil then lease.depth = 0; return false end
    if (tonumber(lease.depth) or 0) <= 0 then
        lease.owner, lease.depth = nil, 0
        return true
    end
    local age = os.clock() - (tonumber(lease.lastAt) or os.clock())
    if lease.owner == "manual-fly" and HUB.movementState
        and HUB.movementState.flying == true then
        return false
    end
    if lease.owner == "priority" then
        -- The priority worker refreshes lastAt while it is alive.  If the
        -- coroutine is interrupted by an executor/remote error, the old code
        -- protected this owner forever and every feature became motionless.
        -- Never clear a live decision, but recover an owner that is no longer
        -- marked busy after a short grace period.
        if automationActionBusy then
            local busyAt = tonumber(HUB.AutomationBusyAt) or 0
            local busyAge = busyAt > 0 and (os.clock() - busyAt) or math.huge
            -- A normal boss/egg/rift leg can take several seconds. Recover
            -- only after a generous grace period; an unset timestamp means a
            -- worker died before it could publish its start marker.
            if busyAt > 0 and busyAge < 30 then return false end
            if busyAt <= 0 and age < 3 then return false end
            automationActionBusy = false
            HUB.AutomationBusyAt = 0
        end
        if age >= 2 then
            lease.owner, lease.depth, lease.lastAt = nil, 0, os.clock()
            return true
        end
        return false
    end
    -- A completed helper can leave its lease behind when an executor aborts a
    -- coroutine during a remote call.  The priority worker must not wait ten
    -- seconds (or forever) behind a lease that has no live owner state.
    if lease.owner == "auto-steal"
        and not HUB.SujiRouteState
        and not carryingEggReturnActive
        and age >= 2 then
        lease.owner, lease.depth, lease.lastAt = nil, 0, os.clock()
        return true
    end
    if lease.owner == "treadmill"
        and not treadmillHandoffBusy
        and age >= 10 then
        lease.owner, lease.depth, lease.lastAt = nil, 0, os.clock()
        return true
    end
    if lease.owner == "plant" or lease.owner == "monster" then
        local busyAt = tonumber(HUB.AutomationBusyAt) or 0
        local busyAge = busyAt > 0 and (os.clock() - busyAt) or math.huge
        local busyExpired = (busyAt > 0 and busyAge >= 30) or (busyAt <= 0 and age >= 3)
        if (not automationActionBusy or busyExpired) and age >= 2 then
            if busyExpired then
                automationActionBusy = false
                HUB.AutomationBusyAt = 0
            end
            lease.owner, lease.depth, lease.lastAt = nil, 0, os.clock()
            return true
        end
        return false
    end
    if age < 10 then return false end
    local boss = eventState and eventState.boss
    local rift = eventState and eventState.rift
    local liveRoute = carryingEggReturnActive == true
        or treadmillHandoffBusy == true
        or treadmillTrainingActive == true
        or HUB.SujiRouteState ~= nil
        or (boss and (boss.inArena == true or boss.leaving == true))
        or (rift and (rift.acquiring == true or rift.placing == true))
    if liveRoute then return false end

    lease.owner, lease.depth, lease.lastAt = nil, 0, os.clock()
    return true
end

-- Recover route flags as well as the movement lease. A coroutine can be
-- interrupted after it sets `SujiRouteState`/`treadmillHandoffBusy`, leaving no
-- exception for the lease watchdog to observe. Those orphaned flags were the
-- reason the UI could remain enabled while every feature stood still.
HUB.RecoverStaleAutomationState = function()
    local now = os.clock()
    if HUB.StealGlide and HUB.StealGlide.owner == "boss"
        and (not HUB.Orchestrator or HUB.Orchestrator.owner ~= "boss")
        and LP:GetAttribute("InBossArena") ~= true then
        -- A protected Boss error can release the orchestrator while leaving
        -- the temporary route/no-clip owner behind. Clear only after the game
        -- confirms we are outside the arena, so lower-priority routes can resume.
        pcall(stopRiftBossNoClip)
        HUB.StealGlide.owner = nil
    end
    local route = HUB.SujiRouteState
    local carrying = false
    pcall(function() carrying = isPlayerCarryingEgg() == true end)
    if route and not carrying then
        local routeAge = now - (tonumber(route.startedAt) or now)
        if routeAge >= 30 then
            HUB.SujiRouteState = nil
            carryingEggReturnActive = false
            HUB.AutoStealMovementActive = false
            HUB.StealGlide.speedGuard = false
            HUB.StealGlide.owner = nil
            pcall(EndEggTravelSpeedWatch)
            pcall(HUB.StopAutoStealNoClip)
            if HUB.Orchestrator and HUB.Orchestrator.owner == "steal" then
                HUB.Orchestrator.End("steal")
            end
            if HUB.MovementLease and HUB.MovementLease.owner == "auto-steal" then
                HUB.MovementLease.owner, HUB.MovementLease.depth = nil, 0
                HUB.MovementLease.lastAt = now
            end
        end
    end

    local handoffAt = tonumber(HUB.TreadmillHandoffAt) or 0
    if treadmillHandoffBusy and handoffAt > 0 and now - handoffAt >= 30 then
        treadmillHandoffBusy = false
        treadmillTrainingActive = false
        HUB.TreadmillMounted = false
        treadmillResetRequested = true
        if HUB.MovementLease and HUB.MovementLease.owner == "treadmill" then
            HUB.MovementLease.owner, HUB.MovementLease.depth = nil, 0
            HUB.MovementLease.lastAt = now
        end
    end

    local busyAt = tonumber(HUB.AutomationBusyAt) or 0
    if automationActionBusy and busyAt > 0 and now - busyAt >= 30
        and (not HUB.MovementLease or HUB.MovementLease.owner == nil)
        and not carryingEggReturnActive and not treadmillHandoffBusy
        and not treadmillTrainingActive then
        automationActionBusy = false
        HUB.AutomationBusyAt = 0
    end
end

-- Do not hide a controller-wide exception inside the scheduler. The previous
-- loop wrapped the complete decision tree in pcall and then discarded the
-- error, which made every toggle look dead when one shared adapter failed.
HUB.ReportAutomationError = function(scope, err)
    local message = tostring(err or "unknown error")
    local state = HUB.AutomationErrorState or { last = "", at = 0 }
    HUB.AutomationErrorState = state
    local now = os.clock()
    if state.last == tostring(scope) .. ":" .. message and now - (state.at or 0) < 5 then
        return
    end
    state.last, state.at = tostring(scope) .. ":" .. message, now
    warn("[Axel Hub] " .. tostring(scope) .. ": " .. message)
end

HUB.IsRiftMovementActive = function()
    local rift = eventState and eventState.rift
    if not rift or rift.enabled ~= true then return false end
    local lastActionAt = tonumber(rift.lastActionAt) or 0
    local actionAge = lastActionAt > 0 and (os.clock() - lastActionAt) or math.huge
    if rift.acquiring == true or rift.placing == true then
        -- `acquiring/placing` is a live guard only while the Rift worker has
        -- refreshed its heartbeat. If an executor aborts during a remote call,
        -- these flags used to stay true forever and block every other route.
        if actionAge <= 30 then return true end
        rift.acquiring, rift.placing = false, false
        rift.status, rift.detail = "waiting", "Rift route lock expired; retrying"
        return false
    end
    local status = tostring(rift.status or "")
    local active = status == "sourcing"
        or status == "placing"
        or status == "hatching"
        or status == "trading"
        or status == "reward"
    if not active then return false end

    -- A protected Rift remote can abort after it has published an active
    -- status. That status is not movement ownership by itself; if no action
    -- refreshed it recently, release it so Auto Steal/Treadmill can continue.
    -- Live acquiring/placing was handled above and remains protected.
    if lastActionAt > 0 and actionAge <= 0.75 then
        return true
    end
    rift.status, rift.detail = "waiting", "Rift route timed out; releasing movement"
    rift.acquiring, rift.placing = false, false
    return false
end

function eventRemote(groupName, remoteName, kind)
    local cacheKey = tostring(kind or "RF") .. ":" .. tostring(groupName) .. ":" .. tostring(remoteName)
    local cached = eventRemoteCache[cacheKey]
    if cached and cached.Parent then return cached end

    local found
    pcall(function()
        local remotes = require(RS.Shared.Remotes)
        local group = remotes[groupName]
        if type(group) ~= "table" then
            for key, value in pairs(remotes) do
                if string.lower(tostring(key)) == string.lower(tostring(groupName)) and type(value) == "table" then
                    group = value
                    break
                end
            end
        end
        if type(group) == "table" then
            found = group[remoteName]
            if not found then
                for key, value in pairs(group) do
                    if string.lower(tostring(key)) == string.lower(tostring(remoteName)) then
                        found = value
                        break
                    end
                end
            end
        end
    end)

    if found and typeof(found) == "Instance" then
        eventRemoteCache[cacheKey] = found
        return found
    end

    -- Older builds expose the same remotes as slash-delimited children.
    local fallback = GetNetRemote((kind or "RF") .. "/" .. tostring(groupName) .. "/" .. tostring(remoteName))
    if fallback then
        eventRemoteCache[cacheKey] = fallback
        return fallback
    end
    pcall(function()
        local network = RS:FindFirstChild("Network")
        local candidate = network and network:FindFirstChild(tostring(groupName) .. ": " .. tostring(remoteName))
        if candidate then eventRemoteCache[cacheKey] = candidate; found = candidate end
    end)
    return found
end

function invokeEventRemote(groupName, remoteName, ...)
    local remote = eventRemote(groupName, remoteName, "RF")
    if not remote or not remote:IsA("RemoteFunction") then return nil, "remote unavailable" end
    local args = { ... }
    local ok, result = pcall(function() return remote:InvokeServer(table.unpack(args)) end)
    if not ok then
        -- A map refresh can replace a RemoteFunction while the old Instance
        -- still has a Parent. Rebind once so the enabled worker recovers
        -- without requiring a script restart.
        eventRemoteCache["RF:" .. tostring(groupName) .. ":" .. tostring(remoteName)] = nil
        HUB.NetworkRemoteCache["RF/" .. tostring(groupName) .. "/" .. tostring(remoteName)] = nil
        local rebound = eventRemote(groupName, remoteName, "RF")
        if rebound and rebound ~= remote and rebound:IsA("RemoteFunction") then
            ok, result = pcall(function() return rebound:InvokeServer(table.unpack(args)) end)
        end
    end
    return ok and result or nil, ok and nil or tostring(result)
end

-- Rift Boss decisions must use a fresh BossEvent snapshot. The normal event
-- poll is intentionally slow for WebLog/status work; it must never be the
-- source used to decide that the boss is dead while the arena fight is live.
-- A forced read skips the cached copy and waits for the current server reply.
HUB.ReadRiftBossSnapshotRealtime = function(force)
    local boss = eventState and eventState.boss
    if not boss or boss.enabled ~= true then return nil end
    local now = os.clock()
    local inArena = LP:GetAttribute("InBossArena") == true
    local minInterval = inArena and 0.10 or 0.25
    local cached = boss.liveSnapshot
    if force ~= true and type(cached) == "table"
        and now - (tonumber(boss.snapshotAt) or 0) < minInterval then
        return cached
    end
    -- Never return an old health snapshot while a fresh request is in flight.
    -- The next controller pass will retry instead of treating stale data as a
    -- boss-death signal.
    if boss.snapshotInFlight == true then return nil end
    boss.snapshotInFlight = true
    local snapshot, snapshotError = invokeEventRemote("BossEvent", "AskSnapshot")
    boss.snapshotInFlight = false
    boss.snapshotAt = os.clock()
    if type(snapshot) == "table" then
        boss.liveSnapshot = snapshot
        boss.snapshotRevision = (tonumber(boss.snapshotRevision) or 0) + 1
        boss.snapshotError = ""
        return snapshot
    end
    boss.snapshotError = tostring(snapshotError or "snapshot unavailable")
    return nil
end

-- Suji's steal scanner reads the server snapshot directly. The client
-- EggState replica can lag one frame or omit a freshly spawned egg, which made
-- Auto Steal report no match even though the egg was visible in Suji. Keep the
-- server snapshot first and use EggState only for older builds.
-- Convert the live snapshot to the small record shape used by Suji.  Keeping
-- both the original fields and Suji's aliases is important: the picker reads
-- Category/Position while the carry request still needs the original UID and
-- slot metadata.  Without this normalization, a server that only exposes
-- AssetCategory + BottomCFrame makes the scanner return an empty list and all
-- higher-level workers appear idle.
HUB.NormalizeSujiFieldEggSnapshot = function(snapshot)
    if type(snapshot) ~= "table" or type(snapshot.Records) ~= "table" then
        return nil
    end
    local normalized = {}
    for key, value in pairs(snapshot) do
        if key ~= "Records" then normalized[key] = value end
    end
    normalized.Records = {}

    -- Use pairs so a refreshed server payload keyed by UID is handled just
    -- like Suji's array payload; ipairs alone silently returned zero eggs.
    for key, raw in pairs(snapshot.Records) do
        if type(raw) == "table" then
            local record = {}
            -- Preserve the complete live record.  The compact alias table used
            -- to drop Rarity/RarityId, Value, and other catalog fields; when a
            -- server refresh returned only those fields, the filter resolved
            -- every egg as Common and Auto Steal found no target despite the UI
            -- showing selected rarities.
            for rawKey, rawValue in pairs(raw) do record[rawKey] = rawValue end
            record.Uid = raw.Uid or raw.UID or raw.EggUid or raw.EggUID or key
            record.AreaId = raw.AreaId or raw.AreaName or raw.Area or raw.Biome or raw.BiomeName
            record.Position = GetFieldEggPosition(raw) or GetFieldEggPosition(record)
            record.Category = raw.AssetCategory or raw.Category or raw.EggName or raw.Name
            record.AssetCategory = raw.AssetCategory or raw.Category or raw.EggName or raw.Name
            record.Mutations = HUB.SujiMutationList(raw.Mutations)
            local rawState = raw.State or raw.Status
            local stateName = string.lower(tostring(rawState or ""))
            if stateName == "slot" then
                record.State = "Slot"
            elseif stateName == "dropped" then
                record.State = "Dropped"
            elseif stateName == "carried" then
                record.State = "Carried"
            else
                record.State = rawState
            end
            record.HasParasite = raw.HasParasite == true or raw.BaseMutation == "Parasite"
                or table.find(record.Mutations, "Parasite") ~= nil
                or table.find(record.Mutations, "Monstrous") ~= nil
            if raw.Weight ~= nil then record.Weight = raw.Weight end
            if raw.Kg ~= nil then record.Kg = raw.Kg end
            normalized.Records[#normalized.Records + 1] = record
        end
    end
    return normalized
end

HUB.ReadSujiFieldEggSnapshot = function(...)
    local tracker = HUB.FieldEggSnapshotState
    local now = os.clock()
    local cached = HUB.LiveFieldEggSnapshot
    local force = select(1, ...)

    -- Keep one live replica for every consumer.  The background scanner forces
    -- a poll; route/picker calls reuse the recent result instead of invoking
    -- the server several times in the same frame.
    if force ~= true and type(cached) == "table"
        and type(cached.Records) == "table"
        and tracker and tracker.dirty ~= true
        and now < (tonumber(tracker.nextRefreshAt) or 0) then
        return cached
    end
    if tracker and tracker.refreshing == true then
        -- The background Suji snapshot poll and a route refresh can overlap at
        -- a respawn boundary. Returning nil immediately made the orchestrator
        -- interpret that single in-flight read as "no egg" and switch to the
        -- fallback movement. Wait briefly for that same one reader to publish
        -- its fresh replica instead of starting a second movement decision.
        for _ = 1, 8 do
            if tracker.refreshing ~= true then break end
            task.wait(0.04)
        end
        cached = HUB.LiveFieldEggSnapshot
        if tracker.refreshing == true then return cached end
    end
    if tracker then tracker.refreshing = true end

    local normalized
    if force == true or (tracker and tracker.dirty == true) then
        -- Do not let a parented-but-stale RemoteFunction survive a map stream
        -- rebuild.  eventRemote will resolve the current instance again.
        eventRemoteCache["RF:Eggs:RequestAreaEggSnapshot"] = nil
        HUB.NetworkRemoteCache["RF/Eggs/RequestAreaEggSnapshot"] = nil
    end
    local remote = eventRemote("Eggs", "RequestAreaEggSnapshot", "RF")
    local remoteOk, rawSnapshot = false, nil
    if remote and remote:IsA("RemoteFunction") then
        remoteOk, rawSnapshot = pcall(function() return remote:InvokeServer() end)
        if not remoteOk or type(rawSnapshot) ~= "table" or type(rawSnapshot.Records) ~= "table" then
            -- A map refresh can leave the old RemoteFunction parented while its
            -- server stream is already dead. Clear both caches and bind again.
            eventRemoteCache["RF:Eggs:RequestAreaEggSnapshot"] = nil
            HUB.NetworkRemoteCache["RF/Eggs/RequestAreaEggSnapshot"] = nil
            remote = eventRemote("Eggs", "RequestAreaEggSnapshot", "RF")
            if remote and remote:IsA("RemoteFunction") then
                remoteOk, rawSnapshot = pcall(function() return remote:InvokeServer() end)
            end
        end
        if remoteOk and type(rawSnapshot) == "table" and type(rawSnapshot.Records) == "table" then
            normalized = HUB.NormalizeSujiFieldEggSnapshot(rawSnapshot)
        end
    end

    -- A map can answer with an empty table for a few frames while its egg
    -- stream is rebuilding. Do not erase the last good list on that response;
    -- mark it dirty so the next short poll catches newly respawned eggs.
    if normalized and #normalized.Records == 0 and type(cached) == "table"
        and type(cached.Records) == "table" and #cached.Records > 0
        and now - (tonumber(tracker and tracker.lastGoodAt) or 0) < 1.5 then
        if tracker then
            tracker.refreshing = false
            tracker.dirty = true
            tracker.nextRefreshAt = now + 0.12
            tracker.lastError = "map refresh returned an empty field snapshot"
        end
        return cached
    end

    if not normalized and EggState and type(EggState.ReadFieldEggs) == "function" then
        local stateOk, stateSnapshot = pcall(EggState.ReadFieldEggs)
        if stateOk and type(stateSnapshot) == "table" and type(stateSnapshot.Records) == "table" then
            normalized = HUB.NormalizeSujiFieldEggSnapshot(stateSnapshot)
        end
    end
    if normalized and #normalized.Records == 0 and type(cached) == "table"
        and type(cached.Records) == "table" and #cached.Records > 0
        and now - (tonumber(tracker and tracker.lastGoodAt) or 0) < 1.5 then
        if tracker then
            tracker.refreshing = false
            tracker.dirty = true
            tracker.nextRefreshAt = now + 0.12
            tracker.lastError = "fallback returned an empty field snapshot"
        end
        return cached
    end
    if normalized then
        pcall(HUB.MarkFieldEggSnapshot, normalized)
        return normalized
    end
    if tracker then
        tracker.refreshing = false
        tracker.dirty = true
        tracker.nextRefreshAt = now + 0.25
        tracker.lastError = "field egg snapshot unavailable"
    end
    return cached
end

-- Egg respawns and map-stream rebuilds are visible in these client containers.
-- Wake the same single snapshot path immediately; the forced poll remains a
-- fallback for game revisions that do not expose useful ChildAdded signals.
HUB.BindFieldEggRefreshSignals = function()
    if HUB.FieldEggRefreshSignalsBound then return true end
    HUB.FieldEggRefreshSignalsBound = true
    local tracker = HUB.FieldEggSnapshotState
    HUB.FieldEggRefreshWatched = HUB.FieldEggRefreshWatched or {}
    local watched = {
        ClientRenderedAssets = true,
        PlacedEggRenders = true,
        AreaEggSlotsClient = true,
    }
    local function signal(reason)
        local now = os.clock()
        if tracker and now - (tonumber(tracker.signalAt) or 0) < 0.08 then return end
        HUB.InvalidateFieldEggSnapshot(reason)
    end
    local function watchContainer(container)
        if not container or not container.Parent or HUB.FieldEggRefreshWatched[container] then return end
        -- Keep this marker in HUB, not as an Instance attribute.  Attributes
        -- survive script re-execution and would prevent a new run from
        -- rebinding its refresh listeners.
        HUB.FieldEggRefreshWatched[container] = true
        table.insert(HUB.conns, container.DescendantAdded:Connect(function()
            signal("field egg respawn/add")
        end))
        table.insert(HUB.conns, container.DescendantRemoving:Connect(function()
            signal("field egg removed/refresh")
        end))
    end
    for _, container in ipairs(Workspace:GetChildren()) do
        if watched[container.Name] then watchContainer(container) end
    end
    -- Egg render containers can be nested below a map/stream folder.  Bind the
    -- live instance as well; otherwise a refreshed map is only noticed by the
    -- slower polling loop and Auto Steal appears idle until the script is run
    -- again.
    for name in pairs(watched) do
        local nested = Workspace:FindFirstChild(name, true)
        if nested then watchContainer(nested) end
    end
    table.insert(HUB.conns, Workspace.ChildAdded:Connect(function(child)
        if watched[child.Name] then
            watchContainer(child)
            signal("field egg container rebuilt")
        end
    end))
    table.insert(HUB.conns, Workspace.ChildRemoved:Connect(function(child)
        if watched[child.Name] then signal("field egg container removed") end
    end))
    table.insert(HUB.conns, Workspace.DescendantAdded:Connect(function(instance)
        if watched[instance.Name] then
            watchContainer(instance)
            signal("nested field egg container rebuilt")
        end
    end))
    table.insert(HUB.conns, Workspace.DescendantRemoving:Connect(function(instance)
        if watched[instance.Name] then signal("nested field egg container removed") end
    end))
    return true
end

-- Match Suji's field-carry handshake first.  Different game revisions have
-- exposed the same action under either Eggs:RequestAreaEggCarry or the newer
-- EggWorld/AskFieldEggCarry path; both are tried before the client module
-- fallback.  Returning the server result is important: callers must not start
-- the return route until the requested UID was actually accepted.
function HUB.TryCarryFieldEgg(uid, slotKey)
    local wantedUid = tostring(uid or "")
    if wantedUid == "" then return false, "missing uid" end

    local candidates = {
        eventRemote("Eggs", "RequestAreaEggCarry", "RF"),
        eventRemote("EggWorld", "AskFieldEggCarry", "RF"),
        GetNetRemote("RF/Eggs/RequestAreaEggCarry"),
        GetNetRemote("RF/EggWorld/AskFieldEggCarry"),
        GetNetRemote("RF/EggWorld/RequestAreaEggCarry"),
    }
    local seen = {}
    local lastMessage = "remote unavailable"
    -- Suji first asks the game to carry by the exact UID with no slot hint.
    -- The slot key is only a compatibility retry for FirstArea eggs; sending
    -- it as the first request can make the server resolve a nearby slot.
    local payloads = {{ Uid = uid, FirstAreaSlotKey = nil }}
    if slotKey ~= nil then
        payloads[#payloads + 1] = { Uid = uid, FirstAreaSlotKey = slotKey }
    end

    for _, payload in ipairs(payloads) do
        for _, remote in ipairs(candidates) do
            if remote and typeof(remote) == "Instance" and remote:IsA("RemoteFunction") and not seen[remote] then
                seen[remote] = true
                local ok, result, message = pcall(function()
                    return remote:InvokeServer(payload)
                end)
                if ok and result == true then
                    return true, result
                end
                if type(message) == "string" and message ~= "" then
                    lastMessage = message
                elseif ok and result ~= nil then
                    lastMessage = tostring(result)
                elseif not ok then
                    lastMessage = tostring(result)
                end
            end
        end
        -- The main remote may return a rejection that is only resolved by the
        -- module wrapper; try the next payload before declaring the UID lost.
        seen = {}
    end

    -- Keep the client wrapper as a compatibility fallback.  Some builds do
    -- not expose the RemoteFunction in the replicated tree even though the
    -- EggState module can still perform the official request.
    if EggState and type(EggState.CarryFieldEgg) == "function" then
        local moduleSlotKeys = { false }
        if slotKey ~= nil then moduleSlotKeys[#moduleSlotKeys + 1] = slotKey end
        for _, moduleSlotKey in ipairs(moduleSlotKeys) do
            if moduleSlotKey == false then moduleSlotKey = nil end
            local ok, result, message = pcall(function()
                return EggState.CarryFieldEgg(uid, moduleSlotKey)
            end)
            if ok and result == true then
                return true, result
            end
            if type(message) == "string" and message ~= "" then
                lastMessage = message
            elseif ok and result ~= nil then
                lastMessage = tostring(result)
            elseif not ok then
                lastMessage = tostring(result)
            end
        end
    end

    return false, lastMessage
end

function fireEventRemote(groupName, remoteName, ...)
    local remote = eventRemote(groupName, remoteName, "RE")
    if not remote or not remote:IsA("RemoteEvent") then return false end
    local args = { ... }
    return pcall(function() remote:FireServer(table.unpack(args)) end)
end

-- AskLeave is not exposed with the same class on every Rift build.  Some
-- versions publish BossEvent.AskLeave as a RemoteFunction while others publish
-- it as a RemoteEvent.  Calling only InvokeServer made the leave leg silently
-- do nothing on the latter build, even though the exit tween completed.
-- Resolve/invoke the function first, then fall back to the event.  A successful
-- RemoteFunction call returns true even when the server intentionally returns
-- nil, so we do not accidentally fire the leave request twice.
HUB.RequestRiftBossLeave = function()
    local remote = eventRemote("BossEvent", "AskLeave", "RF")
    local invoked = false
    if remote and remote:IsA("RemoteFunction") then
        invoked = pcall(function() remote:InvokeServer() end)
        if invoked then return true end
        eventRemoteCache["RF:BossEvent:AskLeave"] = nil
        HUB.NetworkRemoteCache["RF/BossEvent/AskLeave"] = nil
        local rebound = eventRemote("BossEvent", "AskLeave", "RF")
        if rebound and rebound ~= remote and rebound:IsA("RemoteFunction") then
            invoked = pcall(function() rebound:InvokeServer() end)
            if invoked then return true end
        end
    end
    return fireEventRemote("BossEvent", "AskLeave")
end

function riftTradeResultAccepted(result)
    if result == true then return true end
    if type(result) == "string" then
        local status = string.lower(result)
        return status == "success" or status == "accepted" or status == "completed"
    end
    if type(result) ~= "table" then return false end
    return result.Success == true or result.Accepted == true or result.Ok == true
        or result.Completed == true or result.Status == "Success"
end

function riftTradeQuestOffers(offers)
    if type(offers) ~= "table" or #offers < 3 then return false, nil end

    -- Suji's live Rift flow sends the three inventory UIDs directly to the
    -- Rift:AskTradeIn RemoteFunction. Keep this exact request shape: trying
    -- several guessed payloads can make a valid quest look declined and can
    -- also submit unnecessary duplicate requests on newer builds.
    local remote = eventRemote("Rift", "AskTradeIn", "RF")
    if not remote or not remote:IsA("RemoteFunction") then return false, nil end
    local ok, result = pcall(function()
        return remote:InvokeServer(offers)
    end)
    -- Some game revisions return {Success = true}/{Accepted = true} instead
    -- of the literal boolean.  The old equality check discarded a successful
    -- trade, so no reward UID was queued for placement.
    return ok and riftTradeResultAccepted(result), result
end

function publishEvent(name, detail, status)
    if _G.AxelWebLog and type(_G.AxelWebLog.SetEvent) == "function" then
        pcall(_G.AxelWebLog.SetEvent, name, detail, status)
    end
end

function selectedEventCategory(selected, value)
    if type(selected) ~= "table" then return false end
    if selected[value] == true then return true end
    for _, item in pairs(selected) do
        if tostring(item) == tostring(value) then return true end
    end
    return false
end

function readSaveTable()
    local save
    pcall(function() if SaveModule and type(SaveModule.Get) == "function" then save = SaveModule.Get() end end)
    return type(save) == "table" and save or {}
end

-- Compare a quest category against every identifier shape used by the live
-- save/field snapshot/catalog.  Rift requirements are display names, while
-- Axel records often expose an internal AssetCategory id.
function riftCategoryMatches(record, requirement)
    if type(record) ~= "table" or requirement == nil then return false end
    local wanted = riftIdentityKeys(requirement)
    if next(wanted) == nil then return false end
    local values = {}
    riftCollectIdentityValues(record, values, {}, 0)
    local dir = AssetsData and (AssetsData.Directory or AssetsData)
    local checkedCatalog = {}
    for _, value in ipairs(values) do
        if wanted[riftIdentityKey(value)] then return true end
        if type(dir) == "table" and value ~= nil then
            local info = dir[value]
            if not info then
                for catalogKey, catalogValue in pairs(dir) do
                    if riftIdentityKey(catalogKey) == riftIdentityKey(value) then info = catalogValue; break end
                end
            end
            if type(info) == "table" and not checkedCatalog[info] then
                checkedCatalog[info] = true
                local labels = {}
                riftCollectIdentityValues(info, labels, {}, 0)
                for _, label in ipairs(labels) do
                    if wanted[riftIdentityKey(label)] then return true end
                end
            end
        end
    end
    return false
end

-- The Rift inventory hand-in in the reference flow is intentionally strict:
-- the server requirement is an AssetCategory and a pet is eligible when its
-- Inventory record has the same Category. Eggs stay separate: bag/placed eggs
-- use AssetCategory and live field eggs use the field snapshot's Category.
function riftInventoryCategoryMatches(item, requirement)
    if type(item) ~= "table" or requirement == nil then return false end
    local wanted = riftIdentityKey(riftRequirementLabel(requirement))
    if wanted == "" then return false end
    -- The live inventory flow matches pet records by Category. Do not fall back to an
    -- egg's AssetCategory here, otherwise an unhatched egg could be offered as
    -- a pet UID after an inventory refresh.
    local category = item.Category
    if category == nil then return false end
    if riftIdentityKey(category) == wanted then return true end
    -- Some Save replicas keep the internal Category id while Rift requirements
    -- arrive as the catalog/display name. Bridge only the Category field
    -- through Assets; do not use an egg's AssetCategory as a pet match.
    return riftCategoryMatches({ Category = category }, requirement)
end

function riftEggCategoryMatches(egg, requirement)
    if type(egg) ~= "table" or requirement == nil then return false end
    local wanted = riftIdentityKey(riftRequirementLabel(requirement))
    -- Egg inventory replicas have used both AssetCategory and Category.  Read
    -- the same identity aliases as the live quest requirement so a newly
    -- hatched/bag egg is still found for placement.
    local category = egg.AssetCategory or egg.Category or egg.EggName or egg.Name
    if wanted ~= "" and category ~= nil and riftIdentityKey(category) == wanted then
        return true
    end
    -- A Rift requirement can be the display name while EggInventory stores the
    -- internal AssetCategory (or the reverse).  Use the same catalog identity
    -- bridge as Suji's live asset map before rejecting the bag egg.
    return riftCategoryMatches(egg, requirement)
end

-- Field-egg records use Category. Inventory pets use Category too, but the
-- field scanner must not use the inventory matcher: an unhatched field egg
-- has no pet Inventory record and is identified by its own Category value.
function riftFieldEggCategoryMatches(record, requirement)
    if type(record) ~= "table" or requirement == nil then return false end
    local wanted = riftIdentityKey(riftRequirementLabel(requirement))
    local category = record.Category or record.AssetCategory
    if wanted ~= "" and category ~= nil and riftIdentityKey(category) == wanted then
        return true
    end
    -- The field snapshot can expose the internal category while the quest
    -- requirement exposes the display label (and vice versa).  Keep Rift Egg
    -- sourcing on the same catalog identity bridge as bag/placed eggs so a
    -- no-match scan does not strand the Rift controller in "waiting".
    return riftCategoryMatches(record, requirement)
end

-- Suji's field snapshot exposes Position, while some client builds expose a
-- BoundsCFrame/BottomCFrame instead. Normalize both shapes before routing.
function GetFieldEggPosition(record)
    if type(record) ~= "table" then return nil end
    local position = record.Position
    if typeof(position) == "Vector3" then return position end
    if typeof(position) == "CFrame" then return position.Position end
    if type(position) == "table" then
        -- Suji accepts both Vector3-shaped replicas and packed array
        -- positions. Preserve the live XYZ instead of rebuilding a point from
        -- area coordinates or a visual model pivot.
        local x = tonumber(position.X or position.x or position[1])
        local y = tonumber(position.Y or position.y or position[2]) or 0
        local z = tonumber(position.Z or position.z or position[3])
        if x and z then return Vector3.new(x, y, z) end
    end
    for _, field in ipairs({ "BottomCFrame", "BoundsCFrame", "CFrame" }) do
        local cframe = record[field]
        if typeof(cframe) == "CFrame" then return cframe.Position end
    end
    return nil
end

-- Find the nearest visible quest egg using AxelHub's normal field scanner.
-- The caller applies the restored Eternal > Secret > Titan > Divine
-- priority when more than one quest ingredient is currently sourceable.
function riftFindFieldEgg(requirement)
    if type(GetMatchingFieldEggs) ~= "function" then return nil end
    if eventState and eventState.rift then
        eventState.rift.scanSettling = false
    end
    -- Rift sourcing follows the quest category, not the optional normal-steal
    -- "big eggs only" filter.  Keep the Axel matcher/path, but do not let an
    -- unrelated Steal toggle hide the required ingredient.
    local normalBigEggFilter = stealBigEggsOnly
    stealBigEggsOnly = false
    local ok, all = pcall(GetMatchingFieldEggs, {}, {}, {})
    stealBigEggsOnly = normalBigEggFilter
    if not ok or type(all) ~= "table" then
        if eventState and eventState.rift then eventState.rift.scanSettling = true end
        return nil
    end
    -- An empty response immediately after a map stream rebuild is not a real
    -- "nothing to source" result.  Let the central controller wait for the
    -- next warm snapshot instead of falling through to Treadmill in the same
    -- tick and causing a dismount/jump loop.
    if #all == 0 and type(HUB.IsFieldEggSnapshotSettling) == "function"
        and HUB.IsFieldEggSnapshotSettling() then
        if eventState and eventState.rift then eventState.rift.scanSettling = true end
        return nil
    end
    local hrp = findHRP()
    local origin = hrp and hrp.Position or Vector3.zero
    local best, bestDistance
    for _, candidate in ipairs(all) do
        local record = candidate and (candidate.record or candidate)
        if riftFieldEggCategoryMatches(record, requirement) then
            local position = GetFieldEggPosition(record)
            if position then
                local distance = (Vector3.new(position.X, 0, position.Z) - Vector3.new(origin.X, 0, origin.Z)).Magnitude
                if not best or distance < bestDistance then
                    best, bestDistance = candidate, distance
                end
            end
        end
    end
    return best
end

function riftItemWeight(item)
    local weight = tonumber(item and (item.Weight or item.Kg or item.SizeKg or item.MassKg)) or 0
    if weight > 0 then return weight end
    -- Decode the game's packed inventory record before comparing the quest
    -- weight cap when the live build provides that decoder.
    pcall(function()
        local assetItems = require(RS.Shared.Util.AssetItems)
        if type(assetItems) == "table" and type(assetItems.Decode) == "function"
            and type(assetItems.WeightKg) == "function" then
            weight = tonumber(assetItems.WeightKg(assetItems.Decode(item))) or 0
        end
    end)
    return weight
end

function riftMachinePosition()
    local machine
    pcall(function() machine = Workspace:FindFirstChild("RiftMachine", true) end)
    if not machine then return nil end
    local attachment = machine:FindFirstChild("Attachment", true)
    if attachment and attachment:IsA("Attachment") then return attachment.WorldPosition end
    if machine:IsA("BasePart") then return machine.Position end
    if machine:IsA("Model") then return machine:GetPivot().Position end
    local part = machine:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

function riftIsPlacedEgg(egg)
    return type(egg) == "table" and egg.Placement ~= nil
end

-- Save replicas have appeared with numeric keys, string keys, and mixed keys
-- after a hatch/trade update.  Find by UID value rather than assuming the
-- representation used by the iterator is also the representation used by the
-- next save read.
function getRiftEggInventoryEntry(save, uid)
    local eggs = type(save) == "table" and save.EggInventory
    if type(eggs) ~= "table" then return nil, nil end

    local wanted = tostring(uid or "")
    if wanted == "" then return nil, nil end

    local function recordUid(key, egg)
        if type(egg) ~= "table" then return key end
        return egg.Uid or egg.UID or egg.EggUid or egg.EggUID
            or egg.AssetUid or egg.AssetUID or key
    end

    local directKey = eggs[uid] ~= nil and uid or (eggs[wanted] ~= nil and wanted or nil)
    local direct = directKey ~= nil and eggs[directKey] or nil
    if direct ~= nil then return directKey, direct, recordUid(directKey, direct) end

    local numeric = tonumber(wanted)
    if numeric ~= nil and eggs[numeric] ~= nil then
        return numeric, eggs[numeric], recordUid(numeric, eggs[numeric])
    end

    for key, egg in pairs(eggs) do
        if tostring(key) == wanted or tostring(recordUid(key, egg)) == wanted then
            return key, egg, recordUid(key, egg)
        end
    end
    return nil, nil
end

function riftFindPlacedEgg(requirement, save, used)
    local eggs = save and save.EggInventory
    if type(eggs) ~= "table" then return nil end
    for uid, egg in pairs(eggs) do
        local key = tostring(uid)
        local requestUid = type(egg) == "table" and (egg.Uid or egg.UID or egg.EggUid or egg.EggUID
            or egg.AssetUid or egg.AssetUID or uid) or uid
        local requestKey = tostring(requestUid)
        if type(egg) == "table" and not (used and (used[key] or used[requestKey])) and riftIsPlacedEgg(egg)
            and riftEggCategoryMatches(egg, requirement) then
            return requestUid, egg
        end
    end
    return nil
end

function riftFindBagEgg(requirement, save, used)
    local eggs = save and save.EggInventory
    if type(eggs) ~= "table" then return nil end
    for uid, egg in pairs(eggs) do
        local key = tostring(uid)
        local requestUid = type(egg) == "table" and (egg.Uid or egg.UID or egg.EggUid or egg.EggUID
            or egg.AssetUid or egg.AssetUID or uid) or uid
        local requestKey = tostring(requestUid)
        if type(egg) == "table" and not (used and (used[key] or used[requestKey])) and not riftIsPlacedEgg(egg)
            and egg.Locked ~= true and riftEggCategoryMatches(egg, requirement) then
            return requestUid, egg
        end
    end
    return nil
end

-- Rift offers are taken from the pet inventory. An egg is never handed to the
-- Rift directly: a matching bag egg is placed first and then hatched, so the
-- resulting pet can satisfy the quest on the next pass.
function findRiftOffering(requirement, save, used)
    local equipped = {}
    if type(save and save.EquippedAssets) == "table" then
        for _, uid in pairs(save.EquippedAssets) do equipped[tostring(uid)] = true end
    end

    local containers = {
        save and save.Inventory,
        save and save.PetInventory,
        save and save.PetSatchel,
        save and save.Pets,
    }
    local seenContainers = {}
    local bestUid, bestItem, bestWeight
    for _, container in ipairs(containers) do
        if type(container) == "table" and not seenContainers[container] then
            seenContainers[container] = true
            for uid, item in pairs(container) do
                local key = tostring(uid)
                if type(item) == "table" and not (used and used[key]) and not equipped[key]
                    and item.IsFavorite ~= true and item.Favorite ~= true
                    and item.InFuse ~= true and item.Locked ~= true
                    and riftInventoryCategoryMatches(item, requirement) then
                    local weight = riftItemWeight(item)
                    local withinWeight = eventState.rift.maxKg <= 0 or weight <= 0 or weight <= eventState.rift.maxKg
                    if withinWeight and (not bestUid or weight < bestWeight) then
                        bestUid, bestItem, bestWeight = key, item, weight
                    end
                end
            end
        end
    end
    return bestUid, bestItem
end

function riftEggGrowthTime(egg)
    local category = type(egg) == "table" and (egg.AssetCategory or egg.Category or egg.EggName or egg.Name)
    local seconds = type(egg) == "table" and tonumber(egg.GrowthTime)
    if seconds then return seconds end
    pcall(function()
        local dir = AssetsData and (AssetsData.Directory or AssetsData)
        local info = type(dir) == "table" and dir[category]
        local eggInfo = type(info) == "table" and (info.Egg or info)
        seconds = type(eggInfo) == "table" and tonumber(eggInfo.GrowthTime) or nil
    end)
    return seconds or 120
end

function riftEggReady(uid, egg)
    if EggState and type(EggState.IsReadyToHatch) == "function" then
        local ok, ready = pcall(EggState.IsReadyToHatch, uid)
        if ok and ready == true then return true end
        if ok and ready == false then return false end
    end
    if type(egg) ~= "table" then return false end
    if egg.Ready == true or egg.IsReady == true or egg.ReadyToHatch == true then return true end

    -- Match Suji's fallback for replicas that do not expose Ready flags:
    -- Placement.PlacedAt + the catalog growth time is the authoritative timer.
    local placement = type(egg.Placement) == "table" and egg.Placement
    local placedAt = placement and tonumber(placement.PlacedAt)
    if placedAt then
        local now = os.time()
        pcall(function() now = Workspace:GetServerTimeNow() end)
        if placedAt + riftEggGrowthTime(egg) > now + 1 then return false end
    end

    local finishAt = tonumber(egg.HatchEndTime or egg.HatchAt or egg.ReadyAt or egg.FinishAt)
    return finishAt ~= nil and finishAt <= os.time() or placedAt ~= nil
end

function riftHatchPlacedEgg(uid, egg)
    if not riftEggReady(uid, egg) then return false, "growing" end
    -- Follow the reference Rift flow: request the server hatch first, then
    -- complete it after the short replication delay. EggState is only a
    -- fallback for builds that do not expose the request remote.
    local hatchResult, hatchErr = invokeEventRemote("Eggs", "RequestHatchEgg", uid)
    -- Some revisions return nil from a successful request.  The protected
    -- invocation itself is the acknowledgement; only an explicit false or a
    -- transport/remote error means that the request was rejected.
    local started = hatchErr == nil and hatchResult ~= false
    if not started and EggState and type(EggState.BeginHatch) == "function" then
        pcall(function() started = EggState.BeginHatch(uid) == true end)
    end
    if not started then return false, "hatch request declined" end
    task.wait(0.3)
    local completeResult, completeErr = invokeEventRemote("Eggs", "RequestCompleteHatchEgg", uid)
    -- The live request completes successfully even when the remote returns
    -- no value; only an invocation error should trigger the local fallback.
    local completed = completeErr == nil and completeResult ~= false
    if not completed and EggState and type(EggState.FinishHatch) == "function" then
        pcall(function() completed = EggState.FinishHatch(uid) ~= false end)
    end
    if not completed then return false, "hatch completion declined" end

    -- FinishHatch returns before the save replica always contains the new
    -- animal. Wait for the planted egg to disappear so the next Rift pass
    -- reads the newly hatched pet instead of retrying the old egg snapshot.
    local deadline = os.clock() + 4
    while os.clock() < deadline and not HUB.dead do
        local refreshed = readSaveTable()
        local _, current = getRiftEggInventoryEntry(refreshed, uid)
        if not current or not riftIsPlacedEgg(current) then break end
        task.wait(0.25)
    end
    eventState.rift.lastHatchAt = os.clock()
    return true, "hatched"
end

function riftGetPenParts()
    local plotObj
    pcall(function() plotObj = PlotState and PlotState.ResolvePlot and PlotState.ResolvePlot() end)
    local petArea = plotObj and plotObj.PetArea
    local center = plotObj and plotObj.CenterPoint
    if typeof(petArea) ~= "Instance" or not petArea:IsA("BasePart") then petArea = nil end
    if typeof(center) ~= "Instance" or not center:IsA("BasePart") then center = nil end
    if not petArea or not center then
        local slot = GetLocalSlot()
        local index
        if typeof(slot) == "Instance" then
            index = tonumber(slot.Name:match("%d+"))
        elseif type(slot) == "table" then
            index = tonumber(slot.Id or slot.Index or slot.Slot or slot.Number
                or (slot.Name and tostring(slot.Name):match("%d+")))
        else
            index = tonumber(tostring(slot):match("%d+"))
        end
        pcall(function()
            local plots = Workspace:FindFirstChild("Plots")
            local plot = plots and index and plots:FindFirstChild(tostring(index))
            if plot then
                petArea = petArea or plot:FindFirstChild("PetArea", true)
                center = center or plot:FindFirstChild("CenterPoint", true)
            end
        end)
        if typeof(petArea) ~= "Instance" or not petArea:IsA("BasePart") then petArea = nil end
        if typeof(center) ~= "Instance" or not center:IsA("BasePart") then center = nil end
    end
    return petArea, center
end

function riftPlacedLocalPositions(save)
    local positions = {}
    local eggs = save and save.EggInventory
    if type(eggs) ~= "table" then return positions end
    for _, egg in pairs(eggs) do
        local placement = type(egg) == "table" and egg.Placement
        local localCFrame = type(placement) == "table" and placement.LocalCFrame
        if typeof(localCFrame) == "CFrame" then
            table.insert(positions, localCFrame.Position)
        elseif type(localCFrame) == "table" and tonumber(localCFrame[1]) and tonumber(localCFrame[3]) then
            table.insert(positions, Vector3.new(tonumber(localCFrame[1]), 0, tonumber(localCFrame[3])))
        end
    end
    return positions
end

function riftPlacementCandidates(save)
    local candidates = {}
    local petArea, center = riftGetPenParts()
    local occupied = riftPlacedLocalPositions(save)
    if petArea and center then
        local halfX = math.max(0, petArea.Size.X * 0.5 - 4)
        local halfZ = math.max(0, petArea.Size.Z * 0.5 - 4)
        local y = petArea.Size.Y * 0.5
        for x = -halfX, halfX, 3.5 do
            for z = -halfZ, halfZ, 3.5 do
                local world = petArea.CFrame * CFrame.new(x, y, z)
                local localCFrame = center.CFrame:ToObjectSpace(CFrame.new(world.Position))
                local free = true
                for _, placed in ipairs(occupied) do
                    if (Vector3.new(localCFrame.X, 0, localCFrame.Z) - Vector3.new(placed.X, 0, placed.Z)).Magnitude < 3 then
                        free = false
                        break
                    end
                end
                if free then table.insert(candidates, localCFrame) end
            end
        end
        -- Try the slots nearest the pen center first. The old x/z iteration
        -- began at a corner and could generate hundreds of candidates; when
        -- placement was rejected it waited on every one, holding the Rift
        -- movement lease for 20+ seconds before the anti/return state reset.
        table.sort(candidates, function(a, b)
            return a.Position.Magnitude < b.Position.Magnitude
        end)
    end
    return candidates
end

function isEggToolForPlacement(tool)
    if not tool or not tool:IsA("Tool") then return false end
    local name = string.lower(tostring(tool.Name or ""))
    local isEgg = tool:GetAttribute("IsEgg") == true
        or tool:GetAttribute("ItemType") == "AssetEgg"
        or tool:GetAttribute("AssetCategory") == "Egg"
        or name:find("egg", 1, true) ~= nil
        or name:match("[Kk]g%s*%)") ~= nil
    if not isEgg and EggToolDisplay and type(EggToolDisplay.IsEggTool) == "function" then
        pcall(function() isEgg = EggToolDisplay.IsEggTool(tool) == true end)
    end
    return isEgg
end

HUB.GetEggToolUid = function(tool)
    if not tool or not tool:IsA("Tool") then return nil end
    local uid
    if EggToolDisplay and type(EggToolDisplay.GetToolUid) == "function" then
        pcall(function() uid = EggToolDisplay.GetToolUid(tool) end)
    end
    uid = uid or tool:GetAttribute("Uid") or tool:GetAttribute("UID")
        or tool:GetAttribute("EggUid") or tool:GetAttribute("EggUID")
        or tool:GetAttribute("AssetUid") or tool:GetAttribute("AssetUID")
        or tool:GetAttribute("RecordUid") or tool:GetAttribute("RecordUID")
    return uid ~= nil and tostring(uid) or nil
end

-- Save.Get() can lag behind the real Backpack for a few frames after a Rift
-- hatch/refresh.  Suji checks the live Tool replica as a second source.  Merge
-- that source into a shallow save copy so Rift can place the exact inventory
-- UID without ever mutating the game's Save table or choosing a random egg.
HUB.ReadRiftInventoryRealtime = function()
    local source = readSaveTable()
    local save = {}
    for key, value in pairs(source) do save[key] = value end
    save.EggInventory = {}
    for key, egg in pairs(source.EggInventory or {}) do save.EggInventory[key] = egg end

    local containers = {
        LP:FindFirstChildOfClass("Backpack"),
        LP.Character,
    }
    for _, container in ipairs(containers) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if isEggToolForPlacement(tool) then
                    local uid = HUB.GetEggToolUid(tool)
                    if uid then
                        local key, existing = getRiftEggInventoryEntry(save, uid)
                        local merged = {}
                        if type(existing) == "table" then
                            for field, value in pairs(existing) do merged[field] = value end
                        end
                        local category = tool:GetAttribute("AssetCategory")
                            or tool:GetAttribute("Category")
                            or tool:GetAttribute("EggName")
                            or tool:GetAttribute("AssetId")
                            or tool:GetAttribute("EggId")
                        merged.Uid = merged.Uid or uid
                        merged.AssetCategory = merged.AssetCategory or category
                        merged.Category = merged.Category or category
                        merged.Name = merged.Name or tool.Name
                        merged.ToolName = tool.Name
                        -- A live Backpack/Character egg is the unplaced source
                        -- for this pass. Clear a stale Placement left in the
                        -- Save replica so Rift can place this exact UID now.
                        merged.Placement = nil
                        save.EggInventory[key or uid] = merged
                    end
                end
            end
        end
    end
    return save
end

function getEquippedEggUid()
    local character = LP.Character
    if not character then return nil end
    for _, tool in ipairs(character:GetChildren()) do
        if isEggToolForPlacement(tool) then
            local uid = HUB.GetEggToolUid(tool)
            if uid ~= nil then return tostring(uid) end
        end
    end
    return nil
end

-- RequestEquipTool is asynchronous on some builds. Never send a placement
-- request until the exact requested UID is visible in the equipped Tool;
-- otherwise a previous egg can be placed while the new request is still
-- replicating.
function equipEggExact(uid)
    local wanted = tostring(uid or "")
    if wanted == "" then return false end
    if getEquippedEggUid() == wanted then return true end

    local character = LP.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then pcall(function() humanoid:UnequipTools() end) end
    task.wait(0.08)

    local requestUids = { uid }
    if type(uid) ~= "string" then requestUids[#requestUids + 1] = wanted end
    for _, requestUid in ipairs(requestUids) do
        for _ = 1, 3 do
            invokeEventRemote("Eggs", "RequestEquipTool", requestUid)
            local deadline = os.clock() + 0.7
            while os.clock() < deadline and not HUB.dead do
                if getEquippedEggUid() == wanted then return true end
                task.wait(0.08)
            end
        end
    end
    return getEquippedEggUid() == wanted
end

function requestRiftPlaceEgg(uid, localCFrame)
    local requestUids = { uid }
    local wanted = tostring(uid or "")
    if wanted ~= "" and type(uid) ~= "string" then requestUids[#requestUids + 1] = wanted end
    if wanted ~= "" and type(uid) == "string" and tonumber(uid) ~= nil then
        requestUids[#requestUids + 1] = tonumber(uid)
    end

    -- This is the same request shape used by the live Rift flow. The inventory
    -- key/UID is kept as-is first; some revisions reject a stringified numeric
    -- key even though the equivalent string is visible in Save.Get().
    for _, requestUid in ipairs(requestUids) do
        local result, err = invokeEventRemote("Eggs", "RequestPlaceEgg", {
            Uid = requestUid,
            LocalCFrame = localCFrame,
        })
        if err == nil and result == true then return true end
    end
    return false
end

-- Suji's placement primitive: use the exact inventory UID and a free slot
-- derived from PetArea/CenterPoint.  Random offsets are deliberately not used
-- here; on the live game they can be accepted by the client while the server
-- rejects the placement or applies it to another egg.
HUB.SujiPlaceEggInPen = function(uid, allowEquip)
    local wanted = tostring(uid or "")
    if wanted == "" then return false, "missing uid" end

    local save = HUB.ReadRiftInventoryRealtime()
    local key, egg, recordUid = getRiftEggInventoryEntry(save, uid)
    if type(egg) == "table" and riftIsPlacedEgg(egg) then return true, "skip" end

    local root = findHRP()
    local center = GetLocalPlotCenter()
    if not root or typeof(center) ~= "Vector3" then return false, "far" end
    local distance = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z).Magnitude
    if distance > 35 then return false, "far" end

    local requestUid = recordUid or key or uid
    local candidates = riftPlacementCandidates(save)
    -- Some game revisions do not expose PetArea/CenterPoint through the plot
    -- adapter even though the official PlantEgg request still works. Keep the
    -- exact UID flow, but give that official fallback one neutral local slot
    -- instead of returning "rejected" without ever sending a placement call.
    if #candidates == 0 then
        local petArea, center = riftGetPenParts()
        if not petArea or not center then
            candidates = { CFrame.new() }
        end
    end
    -- A placement request is a bounded retry, not a scan of every free cell.
    -- The first slots are ordered nearest the pen center above; this keeps the
    -- exact UID handshake responsive and releases the orchestrator quickly
    -- when a server build rejects the current slot schema.
    local equipAttempted = false
    local exactEquipped = false
    for candidateIndex, localCFrame in ipairs(candidates) do
        if candidateIndex > 4 then break end
        local placed = requestRiftPlaceEgg(requestUid, localCFrame)
        if not placed and tostring(requestUid) ~= wanted then
            placed = requestRiftPlaceEgg(uid, localCFrame)
        end
        -- PlantEgg is the canonical client flow on the reference build. Try
        -- the exact UID before doing the slower equip retry; this also works
        -- when the live Tool has not replicated its UID attribute yet.
        if not placed and allowEquip == true and EggState and type(EggState.PlantEgg) == "function" then
            pcall(function() placed = EggState.PlantEgg(uid, localCFrame) == true end)
        end
        -- Equip at most once per placement operation. Calling equipEggExact on
        -- every candidate multiplied its internal retries and was the reason
        -- a rejected placement held the anti/lease state for ~20 seconds.
        if not placed and allowEquip == true and not equipAttempted then
            equipAttempted = true
            exactEquipped = equipEggExact(uid) == true
        end
        if not placed and exactEquipped then
            placed = requestRiftPlaceEgg(uid, localCFrame)
            if not placed and EggState and type(EggState.PlantEgg) == "function" then
                pcall(function() placed = EggState.PlantEgg(uid, localCFrame) == true end)
            end
        end

        local deadline = os.clock() + 0.55
        while os.clock() < deadline and not HUB.dead do
            local refreshed = HUB.ReadRiftInventoryRealtime()
            local _, refreshedEgg = getRiftEggInventoryEntry(refreshed, uid)
            if riftIsPlacedEgg(refreshedEgg) then return true, "placed" end
            if placed then break end
            task.wait(0.08)
        end
        if placed then return true, "placed" end
    end

    -- Last-resort client wrapper for builds where RequestPlaceEgg is hidden or
    -- returns no value. It is still exact-UID and is only attempted at the
    -- local plot, so it cannot plant a different carried egg.
    if allowEquip == true and EggState and type(EggState.PlantEgg) == "function" then
        local offsets = { CFrame.new(), CFrame.new(2, 0, 0), CFrame.new(-2, 0, 0) }
        if exactEquipped or (not equipAttempted and equipEggExact(uid)) then
            for _, offset in ipairs(offsets) do
                local ok, result = pcall(EggState.PlantEgg, uid, offset)
                if ok and result == true then
                    return true, "placed"
                end
                task.wait(0.12)
            end
        end
    end
    return false, "rejected"
end

-- Place a bag egg using the game's normal request lifecycle.  The movement
-- lease is the same Suji-style Rift owner used for field sourcing, so placing
-- a quest egg cannot race Auto Steal or the treadmill fallback.
function riftPlaceEggInPen(uid, label)
    local rift = eventState.rift
    local save = HUB.ReadRiftInventoryRealtime()
    local _, egg = getRiftEggInventoryEntry(save, uid)
    if type(egg) ~= "table" then return false, "egg is no longer in the bag" end
    if riftIsPlacedEgg(egg) then return true, "already placed" end

    local plotCenter = GetLocalPlotCenter()
    local hrp = findHRP()
    if not hrp or not plotCenter then return false, "base pen is not ready" end

    local wasReturning = carryingEggReturnActive
    local noClipWasActive = HUB.RiftNoClip and HUB.RiftNoClip.active == true
    local previousGlideOwner = HUB.StealGlide.owner
    HUB.StealGlide.owner = "rift"
    if not noClipWasActive then HUB.StartRiftNoClip() end
    carryingEggReturnActive = true
    rift.placing = true
    local ok, result = pcall(function()
        ReleaseTreadmillForAction()
        if (hrp.Position - plotCenter).Magnitude > 30 then
            if not HUB.ReturnViaSafeCenter(plotCenter, math.min(glideSpeed, 300), nil) then
                return false, "walking to the pen"
            end
            task.wait(0.10)
        end

    local placementSlots = riftPlacementCandidates(save)
    -- Some builds do not expose PetArea/CenterPoint until the first placement
    -- request. Keep the exact UID flow but still send one neutral slot, matching
    -- the canonical Suji placement fallback.
    if #placementSlots == 0 then placementSlots = { CFrame.new() } end
    local equipAttempted = false
    local exactEquipped = false
    for candidateIndex, localCFrame in ipairs(placementSlots) do
            if candidateIndex > 4 then break end
            -- Suji sends the inventory UID directly to RequestPlaceEgg. Do
            -- this before the optional equip fallback so a missing/late Tool
            -- visual cannot prevent an egg already present in EggInventory
            -- from being placed for the Rift quest.
            local placed = requestRiftPlaceEgg(uid, localCFrame)
            -- Keep the canonical PlantEgg path available before the optional
            -- equip retry; it can place an inventory UID even while the Tool
            -- replica is one frame behind.
            if not placed and EggState and type(EggState.PlantEgg) == "function" then
                pcall(function() placed = EggState.PlantEgg(uid, localCFrame) == true end)
            end
            -- One bounded equip attempt for the whole placement operation,
            -- never once per candidate slot.
            if not placed and not equipAttempted then
                equipAttempted = true
                exactEquipped = equipEggExact(uid) == true
            end
            if not placed and exactEquipped then
                placed = requestRiftPlaceEgg(uid, localCFrame)
                if not placed and EggState and type(EggState.PlantEgg) == "function" then
                    pcall(function() placed = EggState.PlantEgg(uid, localCFrame) == true end)
                end
            end
            -- Placement is replicated asynchronously. Wait for the exact UID
            -- to show a Placement record instead of treating a local request
            -- return value as success and immediately moving on to trading.
            local placementDeadline = os.clock() + 0.55
            while os.clock() < placementDeadline and not HUB.dead do
                task.wait(0.08)
                local refreshed = HUB.ReadRiftInventoryRealtime()
                local _, refreshedEgg = getRiftEggInventoryEntry(refreshed, uid)
                if riftIsPlacedEgg(refreshedEgg) then
                    return true, label .. " placed"
                end
            end
            -- Keep a successful client-side PlantEgg result as a last-resort
            -- fallback for builds that do not mirror Placement back locally.
            if placed then return true, label .. " placed" end
        end
        return false, label .. " — the pen is full or placement was rejected"
    end)
    rift.placing = false
    carryingEggReturnActive = wasReturning
    HUB.StealGlide.owner = previousGlideOwner
    if not noClipWasActive then HUB.StopRiftNoClip() end
    if not ok then return false, tostring(result) end
    return result
end

-- A Rift reward can arrive in EggInventory without a pending UID when the
-- save replica updates before the Rift response is processed.  Keep this
-- matcher deliberately strict so normal field eggs are never moved by the
-- reward-placement pass.
HUB.RiftEggLooksLikeRiftEgg = function(egg)
    if type(egg) ~= "table" then return false end
    if egg.IsRiftEgg == true or egg.RiftEgg == true or egg.IsRift == true then return true end
    local names = {
        egg.Name, egg.EggName, egg.AssetCategory, egg.Category, egg.AssetName,
        egg.ItemName, egg.ToolName, egg.AssetId, egg.EggId, egg.Event,
        egg.EventName, egg.EventType, egg.Source,
    }
    local joined = {}
    for _, value in ipairs(names) do
        if value ~= nil then joined[#joined + 1] = string.lower(tostring(value)) end
    end
    local text = table.concat(joined, " ")
    return text:find("rift", 1, true) ~= nil and text:find("egg", 1, true) ~= nil
end

HUB.RiftFindUnplacedRiftEgg = function(save, excluded)
    local eggs = save and save.EggInventory
    if type(eggs) ~= "table" then return nil end
    for uid, egg in pairs(eggs) do
        local key = tostring(uid)
        local itemUid = type(egg) == "table" and (egg.Uid or egg.UID or egg.EggUid or egg.EggUID
            or egg.AssetUid or egg.AssetUID or uid) or uid
        local itemKey = tostring(itemUid)
        if type(egg) == "table"
            and not (excluded and (excluded[key] or excluded[itemKey]))
            and not riftIsPlacedEgg(egg)
            and egg.Locked ~= true
            and HUB.RiftEggLooksLikeRiftEgg(egg) then
            return itemUid, egg
        end
    end
    return nil
end

-- Drain every Rift Egg that is currently available before the controller is
-- allowed to fall back to its normal Rift/Steal/Treadmill flow.  Pending
-- reward UIDs are preferred, then the live Backpack/Character inventory is
-- scanned so a replication race cannot strand a Rift Egg until the next run.
function riftPlacePendingEggs()
    local rift = eventState.rift
    if not rift.placeEgg then return false end
    local didPlace = false
    local attempted = {}
    for _ = 1, 8 do
        local save = HUB.ReadRiftInventoryRealtime()
        local uid
        if type(rift.pending) == "table" then
            for pendingUid in pairs(rift.pending) do
                local _, pendingEgg = getRiftEggInventoryEntry(save, pendingUid)
                if type(pendingEgg) == "table" and not riftIsPlacedEgg(pendingEgg)
                    and pendingEgg.Locked ~= true then
                    uid = pendingUid
                    break
                end
                rift.pending[pendingUid] = nil
            end
        end
        if not uid then uid = HUB.RiftFindUnplacedRiftEgg(save, attempted) end
        if not uid then break end

        local key = tostring(uid)
        if attempted[key] then break end
        attempted[key] = true
        if type(rift.pending) == "table" then rift.pending[key] = true end
        rift.status, rift.detail = "placing", "Placing the Rift Egg in the base pen"
        publishEvent("The Rift", rift.detail, rift.status)
        local placed = riftPlaceEggInPen(uid, "Rift Egg")
        if placed then
            if type(rift.pending) == "table" then
                rift.pending[uid] = nil
                rift.pending[key] = nil
            end
            didPlace = true
        else
            -- Re-read after the failed request.  A pending UID can be a
            -- one-frame snapshot from before hatch/equip; retaining the
            -- `placing` status for that stale UID used to leave the Rift
            -- owner locked forever, so Auto Steal/Treadmill stood still.
            local liveSave = HUB.ReadRiftInventoryRealtime()
            local _, liveEgg = getRiftEggInventoryEntry(liveSave, uid)
            if type(liveEgg) == "table" and not riftIsPlacedEgg(liveEgg) then
                -- The exact egg is still really in Backpack/Character. Keep
                -- Rift ownership only for this valid retry.
                rift.status, rift.detail = "placing", "Rift egg is still in the Backpack; retrying base placement"
                publishEvent("The Rift", rift.detail, rift.status)
                return true
            end
            if type(rift.pending) == "table" then
                rift.pending[uid] = nil
                rift.pending[key] = nil
            end
        end
    end
    return didPlace
end

function riftRecipeAllowed(state)
    local keep = eventState.rift.keepCats
    local hasKeep = false
    for _, value in pairs(keep or {}) do if value then hasKeep = true; break end end
    if not hasKeep then return true end
    local total, selected = 0, 0
    for _, requirement in pairs(state.Requirements or {}) do
        if requirement ~= nil then
            total += 1
            if selectedEventCategory(keep, riftRequirementLabel(requirement)) then selected += 1 end
        end
    end
    return eventState.rift.keepMode == "Any ticked" and selected > 0 or total > 0 and selected == total
end

-- After Rift:AskFinishReveal the reward can take several replication frames to
-- enter EggInventory.  Keep the pre-trade key set and queue only newly-created
-- unplaced UIDs; this is the exact UID that the next pass must place.
function collectRiftRewardUids(value, output, depth, rewardContext)
    if type(value) ~= "table" or type(output) ~= "table" or (depth or 0) > 5 then return end
    local level = (depth or 0) + 1
    for key, item in pairs(value) do
        local name = string.lower(tostring(key or "")):gsub("[^%w]", "")
        local childContext = rewardContext == true
            or name:find("reward", 1, true) ~= nil
            or name:find("new", 1, true) ~= nil
            or name == "egg" or name == "eggs" or name == "item" or name == "result"
            or name == "egguid" or name == "assetuid" or name == "rewarduid"
            or name == "newegguid" or name == "resultuid" or name == "itemuid"
        if childContext and item ~= nil and type(item) ~= "table"
            and (name == "uid" or name == "egguid" or name == "assetuid"
                or name == "rewarduid" or name == "newegguid" or name == "resultuid"
                or name == "itemuid") then
            local uid = tostring(item)
            if uid ~= "" then output[uid] = true end
        elseif type(item) == "table" then
            collectRiftRewardUids(item, output, level, childContext)
        end
    end
end

function queueNewRiftRewardEggs(beforeInventory, directRewardUids, maxWait)
    local rift = eventState.rift
    local direct = {}
    collectRiftRewardUids(directRewardUids, direct, 0, false)
    local deadline = os.clock() + math.max(0.15, tonumber(maxWait) or 4.0)
    local lastQueuedAt = 0
    local queued = 0
    while os.clock() < deadline and not HUB.dead do
        local current = HUB.ReadRiftInventoryRealtime()
        for uid, egg in pairs(current.EggInventory or {}) do
            local key = tostring(uid)
            local itemUid = type(egg) == "table" and (egg.Uid or egg.UID or egg.EggUid or egg.EggUID
                or egg.AssetUid or egg.AssetUID or uid) or uid
            local itemKey = tostring(itemUid)
            if (direct[key] or direct[itemKey] or (not beforeInventory[key] and not beforeInventory[itemKey]))
                and type(egg) == "table" and not riftIsPlacedEgg(egg)
                and not rift.pending[itemKey] then
                rift.pending[itemKey] = true
                queued += 1
                lastQueuedAt = os.clock()
            end
        end
        -- Allow a short second window for the rest of a multi-egg reward to
        -- replicate, then let the placement pass own the movement.
        if queued > 0 and os.clock() - lastQueuedAt >= 0.35 then break end
        task.wait(0.2)
    end
    return queued
end

-- Keep the post-trade reward handoff live across replication frames.  The
-- reward may arrive after AskFinishReveal returns, so a single inventory read
-- can miss it and leave the Rift Egg unplaced until the next script run.
function riftResumeRewardPlacement(allowActions, maxWait)
    local rift = eventState.rift
    if not allowActions or rift.awaitingReward ~= true then return false end
    local queued = queueNewRiftRewardEggs(
        rift.rewardBeforeInventory or {},
        rift.rewardPayload,
        maxWait or 0.55
    )
    if queued > 0 then
        rift.awaitingReward = false
        rift.rewardBeforeInventory = nil
        rift.rewardPayload = nil
        rift.rewardWaitUntil = 0
        -- Place in this same Rift-owned pass, immediately after the reward is
        -- visible in Backpack. This prevents Auto Treadmill/Auto Steal from
        -- taking the movement lease between trade and placement.
        return riftPlacePendingEggs()
    end
    if os.clock() < (tonumber(rift.rewardWaitUntil) or 0) then
        rift.status, rift.detail = "reward", "Waiting for the Rift Egg reward to replicate"
        publishEvent("The Rift", rift.detail, rift.status)
        return true
    end
    rift.awaitingReward = false
    rift.rewardBeforeInventory = nil
    rift.rewardPayload = nil
    rift.rewardWaitUntil = 0
    return false
end

function riftRoundSignature(state)
    if type(state) ~= "table" then return "" end
    local parts = {
        tostring(state.RoundId or state.RiftRoundId or state.Round or state.RoundNumber
            or state.CurrentRound or state.RoundKey or state.RoundIndex
            or state.CycleId or state.Cycle or state.CycleNumber or state.QuestId
            or state.EventId or state.EventRoundId or state.RunId or state.ResetCount
            or state.Generation or state.Revision or state.Version or state.StateId or ""),
        tostring(state.ResetAt or state.RoundResetAt or state.RefreshedAt
            or state.RefreshId or state.RefreshVersion or state.UpdatedAt
            or state.Timestamp or state.EndAt or ""),
    }
    local requirements = type(state.Requirements) == "table" and state.Requirements or {}
    for key, requirement in pairs(requirements) do
        parts[#parts + 1] = tostring(key) .. "=" .. riftRequirementLabel(requirement)
    end
    table.sort(parts)
    return table.concat(parts, "|")
end

function riftCycle(allowActions)
    local rift = eventState.rift
    if not rift.enabled then return false end
    rift.scanSettling = false
    -- Rebuild this handoff flag from the current Rift snapshot every pass so
    -- a stale field target cannot keep Auto Steal blocked after it disappears.
    rift.fieldActionReady = false
    local state = select(1, invokeEventRemote("Rift", "AskState"))
    if type(state) ~= "table" then
        rift.status, rift.detail = "waiting", "Axel tracker is waiting for Rift data"
        publishEvent("The Rift", rift.detail, rift.status)
        return false
    end
    rift.last = state
    local currentRound = riftRoundSignature(state)
    if currentRound ~= "" and rift.roundSignature ~= "" and rift.roundSignature ~= currentRound then
        -- A new Rift round invalidates old reward UIDs and field coordinates.
        -- Rebuild both replicas before sourcing the next requirement.
        rift.pending = {}
        rift.lastHatchAt = 0
        rift.acquiring = false
        rift.placing = false
        rift.awaitingReward = false
        rift.rewardBeforeInventory = nil
        rift.rewardPayload = nil
        rift.rewardWaitUntil = 0
        rift.lastActionAt = 0
        rift.status, rift.detail = "refreshed", "Rift round changed; rescanning eggs and inventory"
        HUB.InvalidateFieldEggSnapshot("Rift round reset")
        HUB.WakeAutomation("Rift round reset")
    end
    if currentRound ~= "" then rift.roundSignature = currentRound end
    if allowActions and riftResumeRewardPlacement(allowActions, 0.55) then
        return true
    end
    if state.Unlocked == false then
        rift.status, rift.detail = "locked", "Rift gate is still locked"
        publishEvent("The Rift", rift.detail, rift.status)
        return false
    end
    if state.PendingReward then
        if allowActions then select(1, invokeEventRemote("Rift", "AskFinishReveal")) end
        rift.status, rift.detail = "reward", "Claiming the Rift drop"
        publishEvent("The Rift", rift.detail, rift.status)
        return true
    end
    if allowActions and riftPlacePendingEggs() then
        return true
    end
    if allowActions and type(rift.pending) == "table" and next(rift.pending) ~= nil then
        -- A pending reward that could not be placed must not leave the unified
        -- controller thinking Rift owns movement. Let Auto Treadmill resume and
        -- retry the pending egg on the next Rift poll.
        return false
    end
    local requirements = type(state.Requirements) == "table" and state.Requirements or {}
    -- Rift payloads are arrays in the current build, but older refreshes have
    -- returned a UID/category keyed map. Normalize that shape once so the
    -- controller does not stay forever in "waiting for three quest slots".
    if #requirements < 3 then
        local packed = {}
        for key, value in pairs(requirements) do
            if type(value) == "table" or type(value) == "string" then
                packed[#packed + 1] = { key = key, value = value }
            end
        end
        table.sort(packed, function(a, b)
            local ak, bk = tonumber(a.key), tonumber(b.key)
            if ak and bk then return ak < bk end
            if ak then return true end
            if bk then return false end
            return tostring(a.key) < tostring(b.key)
        end)
        requirements = {}
        for _, entry in ipairs(packed) do requirements[#requirements + 1] = entry.value end
    end
    if #requirements < 3 then
        rift.status, rift.detail = "waiting", "Waiting for three quest slots"
        publishEvent("The Rift", rift.detail, rift.status)
        return true
    end
    if not riftRecipeAllowed(state) then
        local free = tonumber(state.FreeRefreshesRemaining) or 0
        if allowActions and rift.refresh and free > 0 then
            local refreshed = select(1, invokeEventRemote("Rift", "AskRefresh"))
            rift.status, rift.detail = refreshed == true and "refreshed" or "waiting", "Recipe was outside the keep list"
        else
            rift.status, rift.detail = "waiting", "Recipe is outside the keep list"
        end
        publishEvent("The Rift", rift.detail, rift.status)
        return true
    end

    local save = HUB.ReadRiftInventoryRealtime()
    -- Give the replicated pet inventory one short refresh window after a
    -- quest egg finishes hatching. This is the hand-off point where the old
    -- implementation could see the egg disappear but still miss the animal.
    if (rift.lastHatchAt or 0) > 0 and os.clock() - rift.lastHatchAt < 1.5 then
        task.wait(0.2)
        save = HUB.ReadRiftInventoryRealtime()
    end
    local offers = {}
    local usedOffers = {}
    local usedPlaced = {}
    local usedBag = {}
    local readyCount, growingCount = 0, 0
    local firstField, firstFieldPriority, firstMissing
    for i = 1, 3 do
        local requirement = requirements[i]
        local uid = findRiftOffering(requirement, save, usedOffers)
        if not uid then
            local placedUid, placedEgg = riftFindPlacedEgg(requirement, save, usedPlaced)
            if placedUid then
                usedPlaced[tostring(placedUid)] = true
                if riftEggReady(placedUid, placedEgg) then
                    if allowActions then
                        rift.status, rift.detail = "hatching", "Opening a ready quest egg before sourcing another"
                        publishEvent("The Rift", rift.detail, rift.status)
                        local hatched = riftHatchPlacedEgg(placedUid, placedEgg)
                        if hatched then return true end
                        -- Keep the slot blocked when the ready request races
                        -- replication; never trade with only two offers.
                        growingCount += 1
                    else
                        rift.status, rift.detail = "ready", "A placed quest egg is ready to hatch"
                        publishEvent("The Rift", rift.detail, rift.status)
                        return true
                    end
                else
                    growingCount += 1
                end
            else
                local bagUid = riftFindBagEgg(requirement, save, usedBag)
                if bagUid then
                    usedBag[tostring(bagUid)] = true
                    if allowActions then
            rift.status, rift.detail = "placing", "Placing " .. riftRequirementLabel(requirement) .. " in the base pen"
                        publishEvent("The Rift", rift.detail, rift.status)
                        local placed = riftPlaceEggInPen(bagUid, riftRequirementLabel(requirement) .. " egg")
                        if placed then return true end
                        -- Confirm that the exact UID is still live before
                        -- keeping Rift as the movement owner.  If the field
                        -- snapshot was stale, the old unconditional retry
                        -- left the controller in `placing` forever and made
                        -- Auto Steal/Treadmill look completely dead.
                        local liveSave = HUB.ReadRiftInventoryRealtime()
                        local _, liveEgg = getRiftEggInventoryEntry(liveSave, bagUid)
                        if type(liveEgg) == "table" and not riftIsPlacedEgg(liveEgg) then
                            rift.status, rift.detail = "placing", "Quest egg is in the Backpack; retrying exact UID placement"
                            publishEvent("The Rift", rift.detail, rift.status)
                            return true
                        end
                        -- The matching record disappeared or is already
                        -- placed. Continue the same scan so the controller can
                        -- source the current field target/fallback this pass.
                        rift.status, rift.detail = "waiting", "Quest egg snapshot expired; refreshing Rift inventory"
                        publishEvent("The Rift", rift.detail, rift.status)
                    else
                        rift.status, rift.detail = "waiting", "A " .. tostring(requirement) .. " egg is ready to place"
                        publishEvent("The Rift", rift.detail, rift.status)
                        return true
                    end
                end
                local target = riftFindFieldEgg(requirement)
                local targetPriority = target and riftRequirementPriority(requirement, target) or 0
                if target and (not firstField or targetPriority > firstFieldPriority) then
                    firstField = { requirement = requirement, target = target }
                    firstFieldPriority = targetPriority
                end
                if not target and not firstMissing then firstMissing = requirement end
            end
        else
            usedOffers[tostring(uid)] = true
            offers[i] = uid
            readyCount += 1
        end
    end

    if rift.scanSettling then
        rift.status, rift.detail = "scanning", "Map refresh is settling; rescanning Rift eggs"
        publishEvent("The Rift", rift.detail, rift.status)
        return false
    end

    if firstField then
        local selectedReq = firstField.requirement
        local selected = firstField.target
        -- Publish the concrete field target before allowActions starts the
        -- route. The scheduler can then give Rift the movement lease before
        -- normal Auto Steal selects an unrelated egg.
        rift.fieldActionReady = true
        if allowActions and not rift.acquiring and not carryingEggReturnActive
            and HUB.SujiRouteState == nil
            and type(StealSpecificEggRobust) == "function" then
            local record = selected.record or selected
            rift.acquiring = true
            rift.lastRequirement = tostring(selectedReq)
            rift.status, rift.detail = "sourcing", "Quest route: collecting " .. riftRequirementLabel(selectedReq)
            publishEvent("The Rift", rift.detail, rift.status)
            local noClipWasActive = HUB.RiftNoClip and HUB.RiftNoClip.active == true
            if not noClipWasActive then HUB.StartRiftNoClip() end
            -- The reference route owns the glide while Rift is sourcing an
            -- egg. Keep the temporary owner scoped to this call so Auto Steal,
            -- Boss, and Treadmill cannot inherit Rift movement afterward.
            local previousRiftGlideOwner = HUB.StealGlide.owner
            HUB.StealGlide.owner = "rift"
            local ok, collected = pcall(StealSpecificEggRobust, {
                record = record,
                _axelUseSujiEggRoute = true,
                _axelRiftSource = true,
            }, true)
            HUB.StealGlide.owner = previousRiftGlideOwner
            if not noClipWasActive then HUB.StopRiftNoClip() end
            rift.acquiring = false
            -- The sourcing trip is complete. Release Rift's temporary owner
            -- now so the next scheduler pass starts from a clean flow; do not
            -- leave the conflict table to be cleared one tick later.
            if HUB.SujiRouteState == nil and not carryingEggReturnActive
                and HUB.Orchestrator and HUB.Orchestrator.owner == "rift" then
                HUB.Orchestrator.End("rift")
            end
            if ok and collected == true then
                rift.status, rift.detail = "sourced", "Quest egg returned to base; waiting for it to hatch"
                publishEvent("The Rift", rift.detail, rift.status)
            else
                rift.status, rift.detail = "waiting", "Quest route could not secure " .. riftRequirementLabel(selectedReq) .. "; retrying"
                publishEvent("The Rift", rift.detail, rift.status)
            end
        else
            rift.status, rift.detail = "sourcing", "Quest route is ready for " .. riftRequirementLabel(selectedReq)
            publishEvent("The Rift", rift.detail, rift.status)
        end
        return true
    end

    if firstMissing or growingCount > 0 then
        rift.status, rift.detail = "waiting", firstMissing
            and "Quest ingredient not visible: " .. tostring(firstMissing)
            or "Waiting for a planted quest egg to hatch"
        publishEvent("The Rift", rift.detail, rift.status)
        return true
    end
    if not allowActions then
        rift.status, rift.detail = "ready", "Recipe ready; Steal has priority"
        publishEvent("The Rift", rift.detail, rift.status)
        return true
    end

    local machinePos = riftMachinePosition()
    local tradeNoClipWasActive = HUB.RiftNoClip and HUB.RiftNoClip.active == true
    local previousTradeOwner = HUB.StealGlide.owner
    HUB.StealGlide.owner = "rift"
    if allowActions and not tradeNoClipWasActive then HUB.StartRiftNoClip() end
    if allowActions and machinePos then
        local hrp = findHRP()
        if not hrp or (hrp.Position - machinePos).Magnitude > 10 then
            rift.status, rift.detail = "trading", "Moving to the Rift machine with inventory animals ready"
            publishEvent("The Rift", rift.detail, rift.status)
            if not TravelToDestination(machinePos + Vector3.new(0, 1.2, 0), math.min(glideSpeed, 300), true) then
                HUB.StealGlide.owner = previousTradeOwner
                if not tradeNoClipWasActive then HUB.StopRiftNoClip() end
                rift.status, rift.detail = "waiting", "Rift machine route unavailable; returning to fallback"
                publishEvent("The Rift", rift.detail, rift.status)
                return false
            end
            task.wait(0.15)
        end
    end
    local beforeInventory = {}
    for uid in pairs(save.EggInventory or {}) do beforeInventory[tostring(uid)] = true end
    local tradeCallOk, traded, tradeResult = pcall(riftTradeQuestOffers, offers)
    if not tradeCallOk then traded, tradeResult = false, nil end
    HUB.StealGlide.owner = previousTradeOwner
    if allowActions and not tradeNoClipWasActive then HUB.StopRiftNoClip() end
    if traded then
        rift.traded += 1
        task.wait(0.30)
        -- The reward UID is returned by AskFinishReveal on some revisions and
        -- by AskTradeIn on others. Keep both responses until EggInventory has
        -- replicated, then place the exact UID.
        local finishResult = select(1, invokeEventRemote("Rift", "AskFinishReveal"))
        -- Pass the accepted response too.  Some builds replicate the reward
        -- under an existing inventory key, so a before/after key comparison
        -- alone cannot identify the UID that must be placed.
        local rewardPayload = {
            TradeResult = tradeResult,
            FinishResult = { Reward = finishResult },
        }
        rift.awaitingReward = true
        rift.rewardBeforeInventory = beforeInventory
        rift.rewardPayload = rewardPayload
        rift.rewardWaitUntil = os.clock() + 6.0
        -- Keep these results on the Rift state instead of adding more locals
        -- to this already large controller function (Luau has a 200-register
        -- limit per function).
        rift.rewardPlacementResult = riftResumeRewardPlacement(true, 4.0)
        rift.rewardStillPending = next(rift.pending or {}) ~= nil
        if rift.rewardStillPending then
            rift.status, rift.detail = "placing", "Quest complete; placing the exact Rift Egg in the base pen"
        elseif rift.awaitingReward == true then
            rift.status, rift.detail = "reward", "Quest complete; waiting for the Rift Egg reward to replicate"
        elseif rift.rewardPlacementResult then
            rift.status, rift.detail = "traded", "Quest complete; Rift Egg placement confirmed"
        else
            rift.status, rift.detail = "traded", "Quest complete; reward placement will retry on the next Rift scan"
        end
        publishEvent("The Rift", rift.detail, rift.status)
        return true
    end
    rift.status, rift.detail = "waiting", "Quest hand-in was declined"
    publishEvent("The Rift", rift.detail, rift.status)
    return true
end

-- The Rift controller's Beam is the authoritative Crystal Tower selector.
-- Suji first reads the player's BossCrystalBeamOrigin and resolves
-- Beam.Attachment1.Parent to the exact Hitbox.  Some revisions stream the
-- origin under BossArena instead, so keep that exact-first lookup and add a
-- narrow arena fallback; never fall back to an arbitrary visual part.
function resolveRiftBeamHitbox(arena, root, towerRoots)
    local function resolveAttachment(attachment)
        if not attachment or not attachment:IsA("Attachment") then return nil end
        local part = attachment.Parent
        for _ = 1, 6 do
            if not part then return nil end
            if part:IsA("BasePart") then break end
            part = part.Parent
        end
        if not part or not part:IsA("BasePart") then return nil end
        local name = string.lower(tostring(part.Name or ""))
        if name ~= "hitbox" then return nil end
        for _, towerRoot in ipairs(towerRoots or {}) do
            if part:IsDescendantOf(towerRoot) then return part end
        end
        return arena and part:IsDescendantOf(arena) and part or nil
    end

    local function readOrigin(container)
        local origin = container and container:FindFirstChild("BossCrystalBeamOrigin", true)
        local beam = origin and origin:FindFirstChildWhichIsA("Beam", true)
        local hitbox = beam and resolveAttachment(beam.Attachment1)
        return hitbox, beam
    end

    local hitbox, beam = readOrigin(root)
    if hitbox then return hitbox, beam end

    hitbox, beam = readOrigin(arena)
    if hitbox then return hitbox, beam end

    -- Do not score arbitrary arena VFX Beams as a target.  Message (7)/Suji
    -- only trusts BossCrystalBeamOrigin; if it is not streamed yet, the
    -- caller uses the known CrystalTowers/Hitbox fallback instead.
    return nil
end

-- Resolve only the authoritative hand path.  The live game normally exposes
-- Boss -> UpperHand1 -> R; an older build used a literal `UpperHand1.R`
-- child.  Check those exact shapes only -- never scan every descendant for a
-- same-named visual or use the hand's position as a continuous path.
local function getExactBossHand(bossModel)
    if not bossModel then return nil end
    local upperHand = bossModel:FindFirstChild("UpperHand1")
    local rightHand = upperHand and upperHand:FindFirstChild("R")
    if rightHand then return rightHand end
    -- The reference client uses this literal name recursively.  Keep the
    -- lookup narrow to that one exact name; do not scan for other hand-like
    -- parts or use a generic BossHealth object.
    return bossModel:FindFirstChild("UpperHand1.R", true)
end

local function getRiftBossModel(arena)
    local function findBossWithExactHand(root)
        if not root then return nil end
        local first = root:FindFirstChild("Boss", true)
        if getExactBossHand(first) then return first end
        -- During the Crystal -> hand transition, Roblox can keep an old Boss
        -- shell before streaming the live Boss model.  Do one narrow hierarchy
        -- scan for a model named Boss that actually owns UpperHand1.R instead
        -- of accepting the first visual shell and waiting forever.
        for _, node in ipairs(root:GetDescendants()) do
            if node.Name == "Boss" and getExactBossHand(node) then
                return node
            end
        end
        return nil
    end

    local arenaBoss = arena and arena:FindFirstChild("Boss", true)
    local exactArenaBoss = findBossWithExactHand(arena)
    if exactArenaBoss then return exactArenaBoss end

    -- During the phase transition some builds reparent the live Boss beside
    -- BossArena while the old arena shell remains streamed. Prefer the model
    -- that actually contains the exact hand path, otherwise retain the arena
    -- model so the spawning/phase state can still be observed.
    if LP:GetAttribute("InBossArena") == true then
        local exactWorldBoss = findBossWithExactHand(Workspace)
        if exactWorldBoss then return exactWorldBoss end
    end
    return arenaBoss
end

function bossArenaTarget(arena)
    if not arena then return nil, "Rift Boss arena not found" end
    local towers = arena:FindFirstChild("CrystalTowers", true)
    local towerRoots = {}
    if towers then
        towerRoots[1] = towers
    else
        -- A few event revisions renamed the container to CrystalTower,
        -- Crystals, or nested it under another arena folder. Find all likely
        -- containers without falling through to the boss hand too early.
        for _, descendant in ipairs(arena:GetDescendants()) do
            local name = string.lower(tostring(descendant.Name or ""))
            if (descendant:IsA("Folder") or descendant:IsA("Model"))
                and (name:find("crystal", 1, true) or name:find("tower", 1, true)) then
                towerRoots[#towerRoots + 1] = descendant
            end
        end
    end
    local bossModel = getRiftBossModel(arena)
    -- The authoritative path remains exactly Boss -> UpperHand1.R; the
    -- model fallback only handles streaming/reparenting and never accepts a
    -- generic BossHealth value.
    -- Keep one exact hand reference for the phase transition below.  On the
    -- live build this object is streamed in after the last Crystal Tower is
    -- destroyed; its appearance is the reliable signal that the next target
    -- is Boss.UpperHand1.R rather than another tower visual.
    local hand = getExactBossHand(bossModel)
    if bossModel and bossModel:GetAttribute("Spawning") == true then
        return nil, "boss is spawning"
    end
    -- PhaseTwoAt is only a phase hint and is not a target gate.  Some builds
    -- replicate it before the last Crystal Tower is destroyed; using it here
    -- made the old flow skip the Beam/tower leg and wait forever for a hand
    -- target that was not yet streamed.  Always prefer a live Crystal Tower;
    -- the exact Boss.UpperHand1.R below is selected only after no live tower
    -- remains.
    if #towerRoots > 0 then
        local nearest, nearestDistance, nearestLabel, nearestKnownLive
        local root = findHRP()
        local origin = root and root.Position or Vector3.zero
        local seen = {}
        local function readCrystalHealth(instance)
            local current = instance
            for _ = 1, 5 do
                if not current or current == arena then break end
                local destroyed = current:GetAttribute("Destroyed")
                    or current:GetAttribute("IsDestroyed")
                    or current:GetAttribute("Dead")
                if destroyed == true then return 0 end
                local hp = tonumber(current:GetAttribute("Health"))
                    or tonumber(current:GetAttribute("HP"))
                    or tonumber(current:GetAttribute("CurrentHealth"))
                    or tonumber(current:GetAttribute("HitPoints"))
                if hp ~= nil then return hp end
                for _, valueName in ipairs({"Health", "HP", "CurrentHealth", "HitPoints"}) do
                    local valueObject = current:FindFirstChild(valueName)
                    if valueObject and (valueObject:IsA("NumberValue") or valueObject:IsA("IntValue")) then
                        return tonumber(valueObject.Value)
                    end
                end
                current = current.Parent
            end
            return nil
        end

        -- Match the game's own boss controller: during phase one the Beam
        -- points at the active Crystal Tower. Prefer that exact Hitbox before
        -- doing the Suji-compatible nearest-live-Hitbox fallback below.
        local guideHitbox, guideBeam = resolveRiftBeamHitbox(arena, root, towerRoots)
        local guidePosition
        pcall(function()
            -- The Beam selects the live Hitbox; it is not the movement path.
            -- Match message (7)/Suji and move toward the Hitbox's stable
            -- position instead of following the animated Attachment1 point.
            if guideHitbox and guideHitbox:IsA("BasePart") then
                guidePosition = guideHitbox.Position
            end
        end)
        if guideHitbox and guidePosition then
            local guideHealth = readCrystalHealth(guideHitbox)
            -- If the old tower has no replicated numeric HP, do not keep
            -- striking it after the exact boss hand has spawned.  The hand is
            -- the phase-two target and the approach function grounds its
            -- elevated position for the bat swing.
            if hand and (guideHealth == nil or guideHealth <= 0) then
                -- Fall through to the exact Boss.UpperHand1.R target below.
                guidePosition = nil
            elseif guideHealth == nil or guideHealth > 0 then
                return guidePosition, "crystal tower (beam target)", guideHealth ~= nil and guideHealth > 0, guideHitbox
            end
            -- A stale Beam can remain pointed at a destroyed Hitbox for a
            -- few frames. Match the reference flow: do not keep a dead
            -- Hitbox as a movement target; continue to the live-tower scan,
            -- then the exact hand if phase two has already streamed in.
        end

        -- Suji fallback: only live CrystalTowers/Hitbox parts are eligible,
        -- then choose the nearest one. Scoring arbitrary BaseParts here can
        -- select a visual shell or tower 2 and leave the player striking the
        -- wrong object forever when the Beam is briefly not replicated.
        for _, towerRoot in ipairs(towerRoots) do
            for _, descendant in ipairs(towerRoot:GetDescendants()) do
                if descendant:IsA("BasePart")
                    and string.lower(tostring(descendant.Name or "")) == "hitbox"
                    and not seen[descendant] then
                    seen[descendant] = true
                    local hp = readCrystalHealth(descendant)
                    if hp ~= nil and hp > 0 then
                        local distance = (descendant.Position - origin).Magnitude
                        if not nearest or distance < nearestDistance then
                            nearest, nearestDistance = descendant, distance
                            nearestKnownLive = true
                            nearestLabel = "crystal tower " .. tostring(descendant.Parent and descendant.Parent.Name or "tower")
                        end
                    end
                end
            end
        end
        if nearest then return nearest.Position, nearestLabel, nearestKnownLive == true, nearest end
    end

    -- The hand target follows the same exact hierarchy as the HP authority.
    -- Never select a same-named visual outside Boss.
    if hand then
        local ok, pos = pcall(function()
            if hand:IsA("Bone") then return hand.TransformedWorldCFrame.Position end
            if hand:IsA("BasePart") then return hand.Position end
            if hand:IsA("Attachment") then return hand.WorldPosition end
            if hand:IsA("Model") then
                local pivotOk, pivot = pcall(function() return hand:GetPivot() end)
                if pivotOk and pivot then return pivot.Position end
            end
            local handPart = hand:FindFirstChildWhichIsA("BasePart", true)
            if handPart then return handPart.Position end
            return nil
        end)
        if ok and pos then
            -- Never reject the exact hand because its animated Y is above the
            -- HumanoidRootPart. riftBossApproachPosition deliberately keeps
            -- movement on the arena floor while preserving this hand's X/Z.
            return pos, "boss hand", true, hand
        end
        return nil, "Boss.UpperHand1.R spawned; waiting for its position"
    end

    -- Do not fall back to Boss.PrimaryPart/Cube.030 here.  Those are visual
    -- shells, not the damage target, and the fallback made the route loop at
    -- the crystal area while the exact hand was still streaming.  Suji waits
    -- for the live hand replica; the next realtime pass will select it.
    return nil, "waiting for exact Boss.UpperHand1.R"
end

-- Approach the beam/hand target with horizontal clearance. Crystal combat must
-- use tween movement only: preserve the player's current Y for the whole leg
-- and never derive a new Y from an animated tower/hand position.
function riftBossApproachPosition(target, label, root)
    if typeof(target) ~= "Vector3" or not root then return nil end
    local flat = Vector3.new(root.Position.X - target.X, 0, root.Position.Z - target.Z)
    if flat.Magnitude < 0.1 then flat = Vector3.new(0, 0, 1) end
    local approach = Vector3.new(target.X, target.Y, target.Z) + flat.Unit * 9
    -- Stop short of the hitbox. The bat already has range; exact positioning
    -- causes needless corrections and can move the avatar through the tower.
    return Vector3.new(approach.X, root.Position.Y, approach.Z)
end

-- Boss entry gets a short, explicit staging handoff.  The previous route
-- started portal movement from whichever worker last owned the HumanoidRootPart
-- (often the treadmill), so the portal/arena move could be swallowed or leave
-- the character stuck at a crystal.  Boss owns this one leg and keeps its
-- no-clip guard active until the portal request begins.
function stageRiftBossAtSafeCenter(cancelled)
    local center = HUB.StealGlide and HUB.StealGlide.SafeCenter
        and HUB.StealGlide.SafeCenter()
    if typeof(center) ~= "Vector3" then return true end
    local root = findHRP()
    if not root then return false end
    local distance = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z).Magnitude
    if distance <= 10 then return true end

    local previousOwner = HUB.StealGlide.owner
    HUB.StealGlide.owner = "boss"
    startRiftBossNoClip()
    local ok, moved = pcall(function()
        -- Boss entry must use the same native tween as the combat leg.  The
        -- generic StealGlide route writes CFrame on every heartbeat and can
        -- look like a repeated TP when the arena is streaming.
        return HUB.TweenRiftBossTo(center, math.min(glideSpeed, 600), cancelled)
    end)
    HUB.StealGlide.owner = previousOwner
    if not ok or moved ~= true then return false end
    task.wait(0.08)
    return findHRP() ~= nil
end

HUB.GetBossHandHealth = function(arena)
    -- This is intentionally the only health source accepted by the boss
    -- proof: Boss -> UpperHand1.R. Do not use a similarly named hand, a parent
    -- model, BossHealth, or a destroyed flag as an implicit zero.
    local bossModel = getRiftBossModel(arena)
    local hand = getExactBossHand(bossModel)
    if not hand then return nil end
    if eventState and eventState.boss then
        eventState.boss.armPathSeen = true
        -- Keep this reference for diagnostics only.  Rift can recreate the
        -- exact R object while streaming or animating the same arena round;
        -- resetting the positive->zero proof on every new Instance made the
        -- leave route impossible to arm.  The round/window/map reset above
        -- is the boundary that clears proof, not object identity.
        eventState.boss.armInstance = hand
    end

    local function readNumberText(value)
        local text = tostring(value or "")
        local number = text:match("([%d%.]+)%s*/") or text:match("^%s*([%d%.]+)")
        return tonumber(number)
    end
    if hand:IsA("NumberValue") or hand:IsA("IntValue") then
        return tonumber(hand.Value)
    end
    if hand:IsA("StringValue") then
        return readNumberText(hand.Value)
    end
    for _, key in ipairs({ "Health", "HP", "CurrentHealth", "HitPoints" }) do
        local value = tonumber(hand:GetAttribute(key))
        if value ~= nil then return value end
        local valueObject = hand:FindFirstChild(key, true)
        if valueObject and (valueObject:IsA("NumberValue") or valueObject:IsA("IntValue")) then
            return tonumber(valueObject.Value)
        end
        if valueObject and valueObject:IsA("StringValue") then
            local valueNumber = readNumberText(valueObject.Value)
            if valueNumber ~= nil then return valueNumber end
        end
        if valueObject then
            for _, label in ipairs(valueObject:GetDescendants()) do
                if label:IsA("TextLabel") or label:IsA("TextButton") or label:IsA("TextBox") then
                    local textValue
                    pcall(function() textValue = label.Text end)
                    local valueNumber = readNumberText(textValue)
                    if valueNumber ~= nil then return valueNumber end
                end
            end
        end
    end
    -- Some revisions put the live `0/Max HP` text directly on the exact R
    -- instance (or on a differently named label), rather than under a child
    -- named Health/HP.  It is still safe to inspect because the search stays
    -- entirely inside Boss.UpperHand1.R.
    if hand:IsA("TextLabel") or hand:IsA("TextButton") or hand:IsA("TextBox") then
        local directText
        pcall(function() directText = hand.Text end)
        local directNumber = readNumberText(directText)
        if directNumber ~= nil then return directNumber end
    end
    for _, label in ipairs(hand:GetDescendants()) do
        if label:IsA("TextLabel") or label:IsA("TextButton") or label:IsA("TextBox") then
            local labelText
            pcall(function() labelText = label.Text end)
            local labelNumber = readNumberText(labelText)
            local labelName = string.lower(tostring(label.Name or ""))
            local textName = string.lower(tostring(labelText or ""))
            if labelNumber ~= nil and (labelName:find("health", 1, true)
                or labelName == "hp" or textName:find("hp", 1, true)
                or tostring(labelText or ""):find("/", 1, true)) then
                return labelNumber
            end
        end
    end
    return nil
end

HUB.IsBossArenaDefeated = function(snapshot, arena)
    local boss = eventState and eventState.boss
    if not boss then return false end
    -- The defeat check is only valid for the snapshot fetched by the current
    -- controller pass. A cached/foreign table must not be able to trigger the
    -- leave or hop path. If a realtime request overlaps, accept only the
    -- immediately preceding live snapshot; this prevents a single failed
    -- request from blocking leave on the exact zero frame, while still
    -- rejecting an old cached round.
    local snapshotFresh = type(snapshot) == "table" and snapshot == boss.liveSnapshot
    if not snapshotFresh and snapshot == nil
        and type(boss.liveSnapshot) == "table"
        and os.clock() - (tonumber(boss.snapshotAt) or 0) <= 0.5 then
        snapshotFresh = true
    end
    if not snapshotFresh then return false end
    -- A pre-entry BossHealth=0 is not a kill.  The delayed-hop decision is
    -- valid only after this client has actually entered this arena window.
    if boss.hasEnteredArena ~= true or boss.inArena ~= true
        or LP:GetAttribute("InBossArena") ~= true then
        return false
    end
    -- Read the exact hand first so a positive sample can arm the round proof.
    -- Suji also requires the live BossEvent snapshot to report zero before
    -- treating the hand's local UI value as a completed kill.
    local handHealth = HUB.GetBossHandHealth(arena)
    local snapshotHealth = tonumber(snapshot.BossHealth)
    if snapshotHealth == nil or snapshotHealth > 0 then
        -- Do not carry a local/UI zero forward while the server still reports
        -- live boss HP; Suji waits for the server snapshot to reach zero too.
        boss.armHealthZeroSeen = false
        boss.armHealthZeroCandidateAt = 0
        return false
    end
    -- The hand can be destroyed/reparented on the same replication step that
    -- publishes HP=0.  Once this round has already observed the exact
    -- positive -> exact zero transition, allow a very short hand-disappearance
    -- window so the leave worker can run.  Missing R before that proof is
    -- never treated as zero.
    if handHealth == nil then
        if boss.armHealthPositiveSeen ~= true then
            return false
        end
        local candidateAt = tonumber(boss.armHealthZeroCandidateAt) or 0
        if candidateAt <= 0 then
            boss.armHealthZeroCandidateAt = os.clock()
            return false
        end
        if os.clock() - candidateAt < 2 then return false end
        boss.armHealth = 0
        boss.armHealthSource = "Boss.UpperHand1.R"
        boss.armHealthZeroSeen = true
        return true
    end
    HUB.RecordRiftBossHealth(handHealth, "Boss.UpperHand1.R")
    if handHealth ~= 0 then return false end
    local candidateAt = tonumber(boss.armHealthZeroCandidateAt) or 0
    if candidateAt <= 0 or os.clock() - candidateAt < 2 then
        return false
    end
    boss.armHealthZeroSeen = true
    return boss.armHealthPositiveSeen == true and boss.armHealthZeroSeen == true
end

-- Movement never polls or follows the hand instance.  `Boss.UpperHand1.R`
-- is read by the realtime HP proof above; the combat tween is allowed to
-- finish at its frozen destination, then the next fresh snapshot decides
-- whether to keep swinging or begin the leave flow.

-- The BatSwing remote only damages the Rift crystal/hand while the Area Bat is
-- equipped. Equip a tool with IsBat before every attack instead of firing the
-- remote blindly.
function ensureBossBat()
    local character = LP.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end

    -- Match Suji's authoritative bat test.  Some builds do not expose
    -- IsBat/ItemType and do not put "Bat" in the Tool name; the GearName
    -- catalog is the signal that the equipped item has BatControllerData.
    local gears
    pcall(function()
        local data = RS and RS:FindFirstChild("Data")
        local module = data and data:FindFirstChild("Gears")
        if module then gears = require(module) end
    end)

    local function isBat(tool)
        if not tool or not tool:IsA("Tool") then return false end
        if tool:GetAttribute("IsBat") == true or tool:GetAttribute("ItemType") == "Bat" then return true end
        if string.lower(tostring(tool.Name or "")):find("bat", 1, true) ~= nil then return true end
        local gearName = tool:GetAttribute("GearName")
        if typeof(gearName) ~= "string" or type(gears) ~= "table" then return false end
        local ok, exists = pcall(function()
            return type(gears.GearNameExists) == "function"
                and gears.GearNameExists(gearName) == true
        end)
        if not ok or not exists or type(gears.Directory) ~= "table" then return false end
        local entry = gears.Directory[gearName]
        return type(entry) == "table" and entry.BatControllerData ~= nil
    end

    local function findEquippedBat()
        local current = LP.Character
        if not current then return nil end
        for _, child in ipairs(current:GetChildren()) do
            if isBat(child) then return child end
        end
        return nil
    end

    local equipped = findEquippedBat()
    if equipped then return equipped end

    local backpack = LP:FindFirstChildOfClass("Backpack")
    local bat
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if isBat(tool) then
                bat = tool
                break
            end
        end
    end

    if bat then
        for _ = 1, 5 do
            pcall(function() humanoid:EquipTool(bat) end)
            task.wait(0.1)
            local nowEquipped = findEquippedBat()
            if isBat(nowEquipped) then return nowEquipped end
        end
        return false
    end

    -- If the bat is not in Backpack yet, ask the Index service to grant/equip
    -- the current area's bat, exactly as the game's own client does.
    local remote = GetNetRemote("RF/Index/RequestEquipAreaBat") or eventRemote("Index", "RequestEquipAreaBat", "RF")
    if remote and remote:IsA("RemoteFunction") then
        pcall(function() remote:InvokeServer() end)
    else
        local event = eventRemote("Index", "RequestEquipAreaBat", "RE")
        if event and event:IsA("RemoteEvent") then
            pcall(function() event:FireServer() end)
        else
            pcall(function() invokeEventRemote("Index", "RequestEquipAreaBat") end)
        end
    end
    for _ = 1, 8 do
        task.wait(0.12)
        local after = findEquippedBat()
        if isBat(after) then return after end
    end
    return false
end

-- Rift combat uses one cancellable native tween per leg. The generic glide
-- writes HumanoidRootPart.CFrame each Heartbeat; repeating that near a tower
-- can look like a TP loop, lift the character, and desync bat hits. This route
-- has no final snap or precision correction: it tweens once to a horizontal
-- point near the captured target, then stays there and swings even if the
-- beam/hand animation changes. Only a real beam target/phase change creates a
-- new leg; the hand itself is never a per-frame position target. The tween
-- keeps the root unanchored so the server does not restore the old position
-- when the crystal-to-hand leg ends.
HUB.RiftBossTweenState = HUB.RiftBossTweenState or {
    generation = 0,
    tween = nil,
    root = nil,
    wasAnchored = false,
}
HUB.CancelRiftBossTween = function()
    local state = HUB.RiftBossTweenState
    if type(state) ~= "table" then return end
    state.generation = (tonumber(state.generation) or 0) + 1
    local active = state.tween
    local activeRoot = state.root
    local wasAnchored = state.wasAnchored == true
    state.tween = nil
    state.root = nil
    state.wasAnchored = false
    if active then pcall(function() active:Cancel() end) end
    if activeRoot and activeRoot.Parent then
        pcall(function()
            activeRoot.Anchored = wasAnchored
            activeRoot.AssemblyLinearVelocity = Vector3.zero
            activeRoot.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

HUB.TweenRiftBossTo = function(target, speed, shouldCancel, onStep)
    if typeof(target) ~= "Vector3" then return false end
    if not HUB.Orchestrator or HUB.Orchestrator.owner ~= "boss"
        or type(HUB.CanMovementOwnerProceed) ~= "function"
        or not HUB.CanMovementOwnerProceed("boss") then return false end
    local state = HUB.RiftBossTweenState
    if type(state) ~= "table" then
        state = { generation = 0, tween = nil, root = nil, wasAnchored = false }
        HUB.RiftBossTweenState = state
    end
    if state.tween then
        -- A new leg must never inherit the previous leg's anchored root.
        -- Normally legs are sequential, but a streamed portal/leave retry or
        -- a controller epoch change can interrupt one. Restore the old root
        -- before replacing the state so the character cannot remain frozen or
        -- be controlled by two movement paths at once.
        local oldTween = state.tween
        local oldRoot = state.root
        local oldWasAnchored = state.wasAnchored == true
        pcall(function() oldTween:Cancel() end)
        if oldRoot and oldRoot.Parent then
            pcall(function()
                oldRoot.Anchored = oldWasAnchored
                oldRoot.AssemblyLinearVelocity = Vector3.zero
                oldRoot.AssemblyAngularVelocity = Vector3.zero
            end)
        end
        state.tween = nil
        state.root = nil
        state.wasAnchored = false
    end
    state.generation = (tonumber(state.generation) or 0) + 1
    local generation = state.generation
    state.tween = nil

    local root = findHRP()
    if not root then return false end
    -- Combat is a horizontal tween only. GroundY/hand Y is intentionally not
    -- consulted here: animated Crystal Tower/UpperHand1.R positions can point
    -- at a ledge or a transient frame and make the avatar float/fall.
    local destination = Vector3.new(target.X, root.Position.Y, target.Z)
    local delta = destination - root.Position
    local horizontalDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
    local distance = delta.Magnitude
    -- Already close enough to swing; don't micro-correct or snap to the point.
    if horizontalDistance <= 8 and math.abs(delta.Y) <= 3 then return true end
    if shouldCancel and shouldCancel() then return false end

    local travelSpeed = tonumber(speed) or 120
    if HUB.StealGlide and type(HUB.StealGlide.EffectiveSpeed) == "function" then
        local speedOk, effective = pcall(HUB.StealGlide.EffectiveSpeed, travelSpeed)
        if speedOk and tonumber(effective) then travelSpeed = effective end
    end
    -- Suji's boss route uses its own effective movement speed (120-600).
    -- The old 150 cap made a normal arena leg look like a 5-second delay.
    travelSpeed = math.clamp(travelSpeed, 120, 600)
    local duration = math.clamp(distance / travelSpeed, 0.08, 4)
    local tweenService = game:GetService("TweenService")
    local tweenOk, tween = pcall(function()
        return tweenService:Create(
            root,
            TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
            { CFrame = CFrame.new(destination) * root.CFrame.Rotation }
        )
    end)
    if not tweenOk or not tween then return false end

    state.tween = tween
    state.root = root
    state.wasAnchored = root.Anchored == true
    pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        -- Keep the character unanchored while TweenService owns the CFrame.
        -- Anchoring the HumanoidRootPart made the server retain the previous
        -- network position and snap the player back as soon as the tween
        -- ended.  No-clip already removes arena collision; zeroing velocity
        -- keeps this a grounded tween without adding a second movement writer.
        root.Anchored = false
    end)
    tween:Play()
    while state.generation == generation and tween.PlaybackState == Enum.PlaybackState.Playing do
        if not HUB.Orchestrator or HUB.Orchestrator.owner ~= "boss"
            or not HUB.CanMovementOwnerProceed("boss")
            or (shouldCancel and shouldCancel()) or findHRP() ~= root or not root.Parent then
            pcall(function() tween:Cancel() end)
            break
        end
        if onStep then pcall(onStep, root, root.Position) end
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
        RunService.Heartbeat:Wait()
    end
    local completed = state.generation == generation
        and tween.PlaybackState == Enum.PlaybackState.Completed
    if state.generation == generation then
        pcall(function()
            root.Anchored = state.wasAnchored == true
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
        state.tween = nil
        state.root = nil
        state.wasAnchored = false
    end
    -- A server correction can arrive on the first frame after an unanchored
    -- tween completes.  Do not mark the combat leg complete when the avatar
    -- was pulled back; the caller will retry from the corrected position and
    -- can then transition to the exact Boss.UpperHand1.R target normally.
    if completed then
        task.wait(0.03)
        local settledRoot = findHRP()
        if not settledRoot then
            completed = false
        else
            local settledDelta = Vector3.new(
                settledRoot.Position.X - destination.X,
                0,
                settledRoot.Position.Z - destination.Z
            ).Magnitude
            if settledDelta > 18 then completed = false end
        end
    end
    return completed
end

function swingBossBat(_target)
    local boss = eventState.boss
    -- Match Suji's SwingCooldown.  Position is already governed by the single
    -- tween leg; do not add a second full-3D range gate here because the exact
    -- hand can be elevated while the Suji floor approach is intentionally at
    -- the HumanoidRootPart Y.
    if os.clock() - (boss.lastSwing or 0) < 0.6 then return false end
    local equipped = ensureBossBat()
    if not equipped then
        boss.status, boss.detail = "arming", "Equipping the Area Bat"
        publishEvent("The Rift Boss", boss.detail, boss.status)
        return false
    end
    boss.lastSwing = os.clock()
    boss.swingCount = (boss.swingCount or 0) + 1
    -- Suji's live path uses the equipped Tool activation only.  Do not add a
    -- second BatSwing remote call: on newer builds that path is ignored or can
    -- consume the swing twice while the tool activation is the real hit.
    local activated = pcall(function() equipped:Activate() end)
    return activated == true
end

-- Resolve the live exit guide before touching BossArenaLeaveTeleport.  On the
-- current Rift build the exit is shown by a Beam and Attachment1 can be a
-- streamed attachment under the teleport pad rather than a child named
-- Hitbox.  Reading only the pad's first descendant made the route stop short
-- or keep writing the old crystal position after the boss died.
HUB.GetBossArenaLeaveBeamPosition = function(arena, exit)
    local function partPosition(instance)
        if not instance then return nil end
        if instance:IsA("BasePart") then return instance.Position end
        if instance:IsA("Attachment") then return instance.WorldPosition end
        if instance:IsA("Model") then
            local ok, pivot = pcall(function() return instance:GetPivot() end)
            if ok and pivot then return pivot.Position end
        end
        local part = instance:FindFirstChildWhichIsA("BasePart", true)
        return part and part.Position or nil
    end
    local function beamPosition(beam)
        if not beam or not beam:IsA("Beam") or beam.Enabled == false then return nil end
        local attachment = beam.Attachment1
        if not attachment or not attachment:IsA("Attachment") then return nil end
        return attachment.WorldPosition, attachment
    end

    local exitPosition = partPosition(exit)

    -- Suji follows the live BossCrystalBeamOrigin after the boss is cleared.
    -- Resolve this first: a stale named Beam under the arena can otherwise win
    -- the scan and pull the player back toward a Crystal Tower instead of the
    -- current leave point.
    -- The live origin is usually attached to the player's HumanoidRootPart;
    -- only some streamed builds reparent it under BossArena.  Prefer the
    -- player path exactly like Suji, then use the arena copy as fallback.
    local root = findHRP()
    local origin = (root and root:FindFirstChild("BossCrystalBeamOrigin", true))
        or (arena and arena:FindFirstChild("BossCrystalBeamOrigin", true))
    local guide = origin and origin:FindFirstChildWhichIsA("Beam", true)
    local guidePosition, guideAttachment = beamPosition(guide)
    if guidePosition then
        local parent = guideAttachment and guideAttachment.Parent
        local isOnExit = exit and parent and parent:IsDescendantOf(exit)
        local leaveNamed = false
        local ancestor = parent
        for _ = 1, 8 do
            if not ancestor then break end
            local ancestorName = string.lower(tostring(ancestor.Name or ""))
            if ancestorName:find("leave", 1, true)
                or ancestorName:find("exit", 1, true)
                or ancestorName:find("teleport", 1, true) then
                leaveNamed = true
                break
            end
            if arena and ancestor == arena then break end
            ancestor = ancestor.Parent
        end
        local insideArena = arena and parent and parent:IsDescendantOf(arena)
        if isOnExit or leaveNamed or not insideArena then
            return guidePosition
        end
    end

    local beams = {}
    if exit then
        for _, descendant in ipairs(exit:GetDescendants()) do
            if descendant:IsA("Beam") then beams[#beams + 1] = descendant end
        end
    end
    if arena then
        for _, descendant in ipairs(arena:GetDescendants()) do
            if descendant:IsA("Beam") then beams[#beams + 1] = descendant end
        end
    end

    -- Prefer a beam explicitly named for the leave/exit/teleport route, or a
    -- beam whose Attachment1 is physically parented to the exit pad.
    for _, beam in ipairs(beams) do
        local beamName = string.lower(tostring(beam.Name or ""))
        local position, attachment = beamPosition(beam)
        if position then
            local parent = attachment and attachment.Parent
            local isOnExit = exit and parent and parent:IsDescendantOf(exit)
            local isLeaveBeam = beamName:find("leave", 1, true)
                or beamName:find("exit", 1, true)
                or beamName:find("teleport", 1, true)
            if isOnExit or isLeaveBeam then return position end
        end
    end

    return exitPosition
end

-- Walk to the arena's exit pad after a kill.  Keep the boss movement owner and
-- no-clip lease active while following the live leave Beam; otherwise Auto
-- Steal/Treadmill can reclaim the HumanoidRootPart during this short handoff.
function leaveRiftBoss()
    if LP:GetAttribute("InBossArena") ~= true then
        stopRiftBossNoClip()
        return true
    end
    local function resolveLeaveObjects()
        local arena = Workspace:FindFirstChild("BossArena", true)
        -- The leave pad is not always parented under BossArena.  Suji looks
        -- it up from the live Workspace so streamed/reparented arena builds
        -- still get a real exit target.
        local exit = Workspace:FindFirstChild("BossArenaLeaveTeleport", true)
        if not exit and arena then
            exit = arena:FindFirstChild("BossArenaLeaveTeleport", true)
        end
        -- Keep the same narrow exit-only fallback used by the reference flow
        -- for builds that renamed the pad. Never pick a generic BasePart: that
        -- was the old cause of tweening back to a crystal/arena wall.
        if not exit then
            local exitNames = {
                BossArenaExit = true,
                ArenaExit = true,
                ExitTeleport = true,
                LeaveTeleport = true,
            }
            local roots = { arena, Workspace }
            for _, root in ipairs(roots) do
                if root then
                    for _, node in ipairs(root:GetDescendants()) do
                        if exitNames[node.Name] then
                            exit = node
                            break
                        end
                    end
                end
                if exit then break end
            end
        end
        return arena, exit
    end

    local arena, exit = resolveLeaveObjects()
    local previousOwner = HUB.StealGlide.owner
    HUB.StealGlide.owner = "boss"
    startRiftBossNoClip()
    local moved = false
    -- Ask once before resolving the guide.  On builds that stream the leave
    -- Beam only after the server receives AskLeave, waiting until after the
    -- first movement attempt leaves us following a stale crystal target.
    pcall(HUB.RequestRiftBossLeave)

    -- Capture the exit Beam/pad once per leave attempt. The old loop read the
    -- live Beam every Heartbeat and cancelled/restarted the tween whenever its
    -- animated endpoint moved, recreating the same position-TP loop as combat.
    -- Leave tracking is the arena attribute + AskLeave handshake; movement is
    -- one native tween leg.
    local deadline = os.clock() + 20
    local lastAskAt = 0
    local leaveTarget = nil
    local leaveMoveStarted = false
    local leaveRetryAt = 0
    while LP:GetAttribute("InBossArena") == true and os.clock() < deadline and not HUB.dead do
        arena, exit = resolveLeaveObjects()
        if not leaveTarget and os.clock() >= leaveRetryAt then
            leaveTarget = HUB.GetBossArenaLeaveBeamPosition(arena, exit)
        end
        if leaveTarget and not leaveMoveStarted then
            leaveMoveStarted = true
            local root = findHRP()
            local distance = root and (root.Position - leaveTarget).Magnitude or math.huge
            if distance <= 9 then
                moved = true
            else
                HUB.StealGlide.owner = "boss"
                local ok, result = pcall(function()
                    -- Keep the exit leg on the same native TweenService path
                    -- as combat. Capture the destination once; do not sample
                    -- the live Beam from inside the tween.
                    return HUB.TweenRiftBossTo(
                        leaveTarget + Vector3.new(0, 2, 0),
                        math.min(glideSpeed, 600),
                        function()
                            return LP:GetAttribute("InBossArena") ~= true or HUB.dead
                        end,
                        function(currentRoot, currentPosition)
                            if LP:GetAttribute("InBossArena") == true and currentRoot then
                                swingBossBat(currentPosition or currentRoot.Position)
                            end
                        end
                    )
                end)
                moved = ok and result == true
                HUB.StealGlide.owner = previousOwner
                if not moved then
                    -- Retry only after the streamed exit settles, never every
                    -- frame at the same position.
                    leaveMoveStarted = false
                    leaveTarget = nil
                    leaveRetryAt = os.clock() + 0.8
                end
            end
        end

        -- Touching the live leave pad is primary. AskLeave is repeated as the
        -- compatibility path for builds where the pad arrives a few frames
        -- after the Beam, matching Suji's retry behavior. RequestRiftBossLeave
        -- supports both RemoteFunction and RemoteEvent versions of AskLeave.
        if moved or os.clock() - lastAskAt >= 0.35 then
            pcall(HUB.RequestRiftBossLeave)
            lastAskAt = os.clock()
        end
        if LP:GetAttribute("InBossArena") == true then
            -- Also swing between movement attempts (including when the live
            -- exit Beam has not streamed yet) until the arena flag clears.
            pcall(function() swingBossBat(leaveTarget) end)
        end
        if LP:GetAttribute("InBossArena") ~= true then break end
        task.wait(0.05)
    end

    HUB.StealGlide.owner = previousOwner
    local left = false
    if LP:GetAttribute("InBossArena") ~= true then
        -- Require a short stable outside-arena observation. A single
        -- replicated false frame during the exit handoff must not arm a hop
        -- before the server has actually completed the arena transition.
        local confirmUntil = os.clock() + 0.30
        left = true
        while os.clock() < confirmUntil and not HUB.dead do
            if LP:GetAttribute("InBossArena") == true then
                left = false
                break
            end
            task.wait(0.03)
        end
        if HUB.dead then left = false end
    end
    pcall(function() HUB.CancelRiftBossTween() end)
    if left then stopRiftBossNoClip() end
    return left
end

-- Suji walks to the event portal before asking the server to enter.  Sending
-- AskEnter from the current plot/base position is rejected by some builds and
-- leaves the boss controller apparently enabled but motionless.
HUB.GetBossArenaPortalPosition = function()
    local portal = Workspace:FindFirstChild("BossArenaTeleport", true)
    if not portal then return nil end
    if portal:IsA("BasePart") then return portal.Position end
    if portal:IsA("Attachment") then return portal.WorldPosition end
    if portal:IsA("Model") then
        local ok, pivot = pcall(function() return portal:GetPivot() end)
        if ok and pivot then return pivot.Position end
    end
    local part = portal:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

-- `Open == true` is a schedule signal, not proof that this client has a boss
-- target. Some servers keep that flag true between event replicas. Treating it
-- as movement ownership made the central controller suspend Auto Steal, Rift,
-- and Treadmill while the character had nowhere to go. Require a real portal,
-- arena target, or an active arena attribute before Boss can claim ownership.
function hasRiftBossWorldTarget(boss, inArena)
    if inArena == true or LP:GetAttribute("InBossArena") == true then
        return true
    end
    local portal = HUB.GetBossArenaPortalPosition()
    if portal then return true end
    local arena = Workspace:FindFirstChild("BossArena", true)
    if arena then
        -- This is only an ownership pre-check.  Do not call
        -- bossArenaTarget here: that function reads the live hand/beam
        -- position and this pre-check runs repeatedly before the action leg.
        -- Position selection belongs exclusively to bossCycle's frozen leg.
        local bossModel = getRiftBossModel(arena)
        if bossModel and getExactBossHand(bossModel) then
            return true
        end
        if arena:FindFirstChild("CrystalTowers", true)
            or arena:FindFirstChild("CrystalTower", true) then
            return true
        end
    end
    -- Keep a just-issued join handoff alive for a few seconds while the arena
    -- model streams in; outside that window a stale status must not block every
    -- lower-priority worker.
    local lastEnter = tonumber(boss and boss.lastEnter) or 0
    return boss and boss.status == "joining" and lastEnter > 0
        and os.clock() - lastEnter <= 4
end

-- A respawn clears the equipped Tool.  Re-arm the Area Bat as soon as the new
-- character exists so the next Rift swing does not silently do nothing.
function shouldKeepRiftBossNoClip(boss, inArena)
    boss = boss or eventState.boss
    if not boss or boss.enabled ~= true or boss.sessionDefeated == true then
        return false
    end
    if inArena == true or LP:GetAttribute("InBossArena") == true then
        return true
    end
    if not hasRiftBossWorldTarget(boss, false) then
        return false
    end
    local status = tostring(boss.status or "")
    if boss.windowOpen ~= true
        and status ~= "joining"
        and status ~= "fighting"
        and status ~= "leaving"
        and status ~= "respawning" then
        return false
    end
    if boss.windowOpen == true then
        return true
    end
    return status == "joining"
        or status == "fighting"
        or status == "leaving"
        or status == "respawning"
end

function watchRiftBossCharacter(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or eventState.boss._deathCharacter == character then return end
    eventState.boss._deathCharacter = character
    track(humanoid.Died:Connect(function()
        -- Do not let the first post-death snapshot start Auto Steal while the
        -- new Character/Backpack and the field replica are still rebinding.
        -- Rift status polling remains read-only during this cooldown.
        HUB.AutoStealResumeAt = os.clock() + 2.0
        -- The boss run is over for this character. Restore collision before
        -- the respawn creates a new character, so no-clip cannot leak into
        -- normal egg routing.
        stopRiftBossNoClip()
        eventState.boss.status = "respawning"
        eventState.boss.detail = "Respawn detected; restoring the Area Bat"
        publishEvent("The Rift Boss", eventState.boss.detail, eventState.boss.status)
        task.spawn(function()
            for _ = 1, 12 do
                if HUB.dead or not eventState.boss.enabled then return end
                task.wait(0.45)
                if ensureBossBat() then
                    eventState.boss.status = "armed"
                    eventState.boss.detail = "Area Bat ready; Rift combat can resume"
                    publishEvent("The Rift Boss", eventState.boss.detail, eventState.boss.status)
                    return
                end
            end
        end)
    end))
end

track(LP.CharacterAdded:Connect(function(character)
    HUB.AutoStealResumeAt = os.clock() + 2.0
    task.spawn(function()
        task.wait(0.35)
        watchRiftBossCharacter(character)
        -- CharacterAdded can fire before InBossArena is replicated. Keep a
        -- short re-arm window so a player death cannot leave the new character
        -- collidable inside the active Rift Boss arena.
        for _ = 1, 20 do
            if HUB.dead or not eventState.boss.enabled or LP.Character ~= character then return end
            if character.Parent and shouldKeepRiftBossNoClip(eventState.boss, false) then
                startRiftBossNoClip()
                return
            end
            task.wait(0.25)
        end
    end)
end))
if LP.Character then watchRiftBossCharacter(LP.Character) end

function completeRiftBossRun(boss, windowKey, allowActions, inArena)
    pcall(function() HUB.CancelRiftBossTween() end)
    boss.combatLeg = nil
    -- This function is reached only after the exact arm proof. Keep the
    -- assertion here as a second barrier because read-only polling and the
    -- action worker can observe the same snapshot in adjacent frames.
    if boss.armHealthZeroSeen ~= true or boss.armHealthPositiveSeen ~= true then
        return false
    end
    -- Keep no-clip armed through BossArenaLeaveTeleport.  The previous code
    -- released it before walking to the exit, so the character could collide
    -- with the arena wall exactly when the boss died.
    if not inArena then stopRiftBossNoClip() end
    boss.defeatedWindow = windowKey
    -- A read-only poll can notice the kill before the action worker gets a
    -- movement lease.  Do not mark the round complete while still inside the
    -- arena, otherwise the action worker will skip BossArenaLeaveTeleport.
    boss.sessionDefeated = not inArena
    -- Keep every hop locked until the arena exit has completed. In particular,
    -- a low/zero BossHealth replica must never start a hop while the player is
    -- still fighting or standing inside the arena.
    boss.hopLocked = true
    boss.defeatedAt = os.clock()
    boss.hopAfterLeaveAt = 0
    boss.leaveCompleted = false
    -- A defeated boss may queue a hop only when the dedicated Rift Boss Hop
    -- toggle is enabled at this exact moment. Auto Boss Rift itself is
    -- single-server; never inherit a stale queue from an earlier toggle state.
    local bossHopEnabledNow = boss.enabled == true
        and boss.hopEnabled == true and boss.hopExplicit == true
    -- Remove any permit left by an earlier worker before deciding this round.
    -- The dedicated toggle is the only source of a new boss-hop permit.
    if type(HUB.ClearRiftBossHopState) == "function" then
        HUB.ClearRiftBossHopState()
    end
    boss.hopQueued = bossHopEnabledNow
    if not bossHopEnabledNow then
        boss.hopAfterLeaveAt = 0
    end
    local hopState = HUB.ServerHopState
    if hopState then
        local pendingRarityHop = hopState.AutoHop == true
            and hopState.AutoHopExplicit == true
            and hopState.HopOnNoMatch == true
            and hopState.NoMatchActive == true
        if not pendingRarityHop then
            hopState.NoMatchActive = false
            hopState.MatchFound = true
        end
    end
    if inArena and allowActions and not boss.leaving then
        boss.leaving = true
        boss.status, boss.detail = "leaving", "Boss cleared; moving to the arena exit"
        publishEvent("The Rift Boss", boss.detail, boss.status)
        local left = leaveRiftBoss()
        boss.leaving = false
        if left then
            boss.inArena = false
            boss.windowOpen = false
            boss.hopLocked = false
            boss.leaveCompleted = true
            -- Close this exact boss round after the exit has been confirmed.
            -- Without this latch, the next controller snapshot can see an open
            -- window and treat the just-cleared arena as a fresh run, which is
            -- the source of the accidental re-entry/re-server behaviour.
            boss.sessionDefeated = true
            boss.roundClosedObserved = false
            -- Re-check the dedicated hop toggle after the leave handshake.  A
            -- toggle change during the exit route must win over the queue that
            -- was captured when HP reached zero.
            if boss.enabled ~= true or boss.hopExplicit ~= true or boss.hopEnabled ~= true then
                if type(HUB.ClearRiftBossHopState) == "function" then
                    HUB.ClearRiftBossHopState()
                else
                    boss.hopQueued = false
                    boss.hopAfterLeaveAt = 0
                end
            end
            if boss.hopQueued then
                boss.hopAfterLeaveAt = os.clock()
                boss.status = "resuming"
                boss.detail = "Arena exit complete; boss HP is zero; waiting for Rift Boss hop delay"
            else
                -- Auto Fight Rift Boss is deliberately single-server. Do not
                -- arm a delayed hop just because the boss reached zero HP.
                boss.hopAfterLeaveAt = 0
                boss.status = "resuming"
                boss.detail = "Arena exit complete; boss HP is zero; staying in this server"
            end
            if boss.hopQueued and type(HUB.ScheduleRiftBossHop) == "function" then
                HUB.ScheduleRiftBossHop()
            end
        else
            boss.leaveCompleted = false
            -- Keep the round active so the next action pass retries the exit
            -- instead of yielding forever at the defeated arena.
            boss.sessionDefeated = false
            boss.status = "waiting"
            boss.detail = "Exit not ready; retrying the arena exit"
        end
    else
        boss.leaveCompleted = not inArena
        if inArena and not allowActions then
            boss.sessionDefeated = false
            boss.hopAfterLeaveAt = 0
            boss.status = "leaving"
            boss.detail = "Boss clear detected; waiting for the leave worker"
        elseif boss.hopQueued then
            boss.status, boss.detail = "defeated", "Boss clear confirmed; waiting for Rift Boss hop delay"
            if not inArena and boss.hopAfterLeaveAt <= 0 then
                boss.hopAfterLeaveAt = os.clock()
            end
        else
            boss.hopAfterLeaveAt = 0
            boss.status, boss.detail = "resuming", "Boss clear confirmed; staying in this server"
        end
        if boss.hopQueued and not inArena and type(HUB.ScheduleRiftBossHop) == "function" then
            HUB.ScheduleRiftBossHop()
        end
    end
    publishEvent("The Rift Boss", boss.detail, boss.status)
    return true
end

function bossCycle(allowActions, expectedEpoch)
    local boss = eventState.boss
    if not boss.enabled then
        pcall(function() HUB.CancelRiftBossTween() end)
        stopRiftBossNoClip()
        return false
    end
    local controllerEpoch = expectedEpoch or boss.controllerEpoch
    local function cancelled()
        return HUB.dead or not boss.enabled or controllerEpoch ~= boss.controllerEpoch
    end
    if cancelled() then return false end
    local inArena = LP:GetAttribute("InBossArena") == true
    -- Keep the boss-hop queue synchronized even when the hop toggle changes
    -- between controller polls. Auto Fight may remain enabled, but HP=0 must
    -- never turn that fight-only mode into a server hop.
    local bossHopToggleOn = boss.hopEnabled == true and boss.hopExplicit == true
    if not bossHopToggleOn then
        -- Auto Fight Rift Boss is single-server by default. Normalize both
        -- flags here on every controller pass so a stale saved/coroutine
        -- value cannot turn HP==0 into a hop when only the fight toggle is on.
        boss.hopEnabled = false
        boss.hopExplicit = false
        if type(HUB.ClearRiftBossHopState) == "function" then
            HUB.ClearRiftBossHopState()
        end
    end
    -- Some builds reuse the same event/window key after the arena has been
    -- refreshed. A completed previous run must therefore be reset on the
    -- next real arena entry, otherwise its old positive->zero proof can make
    -- the next round leave or hop without observing this round's HP.
    if inArena and boss.inArena ~= true and boss.leaveCompleted == true then
        HUB.ResetRiftBossRoundProof(boss)
    end
    boss.inArena = inArena
    if inArena then boss.hasEnteredArena = true end
    -- Re-assert no-clip before asking the event remote. A transient/missing
    -- snapshot must not prevent collision protection during a live arena run.
    local joiningRecently = boss.status == "joining"
        and os.clock() - (boss.lastEnter or 0) < 3
    if shouldKeepRiftBossNoClip(boss, inArena or joiningRecently) then
        startRiftBossNoClip()
    else
        stopRiftBossNoClip()
    end
    -- Always read the current server snapshot for this controller turn. Do
    -- not let the 4-second status poll or a previous turn decide boss HP.
    local snapshot = HUB.ReadRiftBossSnapshotRealtime(true)
    local snapshotAvailable = type(snapshot) == "table"
    if not snapshotAvailable and not inArena then
        boss.status, boss.detail = "waiting", "Waiting for arena telemetry"
        publishEvent("The Rift Boss", boss.detail, boss.status)
        -- A failed/overlapping snapshot is not proof that the arena closed.
        -- Never hop from this branch: the next realtime pass must confirm both
        -- the exact-hand defeat proof and the completed leave state first.
        return false
    end
    -- A snapshot request is telemetry, not the movement owner. Suji keeps the
    -- current arena route alive when one request overlaps/returns nil; local
    -- Crystal/Hand replicas still provide the frozen target for this one leg.
    -- Do not clear windowOpen or cancel combatLeg just because telemetry was
    -- late for a single frame.
    local open
    if snapshotAvailable then
        open = snapshot.Open == true
        boss.windowOpen = open
    else
        open = boss.windowOpen == true
    end
    -- Sample the live arena instance once for this pass. Repeated recursive
    -- FindFirstChild calls can see different stream states in one frame and
    -- falsely reset a completed round while BossArena is being rebuilt.
    local liveArena = Workspace:FindFirstChild("BossArena", true)
    -- Some Rift builds reuse the same OpensAt/EventId after a map refresh.
    -- Require an observed closed window (or a newly streamed BossArena) before
    -- clearing the completed-round latch. This prevents an immediate re-entry
    -- after leave while still allowing the next real round to start.
    if not inArena and open and boss.sessionDefeated == true
        and (boss.roundClosedObserved == true
            or (boss.arenaInstance ~= nil
                and liveArena ~= nil
                and liveArena ~= boss.arenaInstance)) then
        HUB.ResetRiftBossRoundProof(boss)
    end
    if not boss.arenaInstance or inArena then
        boss.arenaInstance = liveArena
    end
    -- ClosesAt is often a live countdown and must never identify a round.
    -- Using it here reset combatLeg on every realtime snapshot, which made
    -- the hand look like a continuously followed movement target. Prefer a
    -- stable event/spawn/open identifier and fall back to one session key.
    local rawWindowKey = snapshotAvailable and snapshot.EventId or boss.windowKey
    if type(rawWindowKey) ~= "string" and type(rawWindowKey) ~= "number" then
        rawWindowKey = snapshotAvailable and snapshot.BossSpawnsAt or nil
    end
    if type(rawWindowKey) ~= "string" and type(rawWindowKey) ~= "number" then
        rawWindowKey = snapshotAvailable and snapshot.OpensAt or nil
    end
    if type(rawWindowKey) ~= "string" and type(rawWindowKey) ~= "number" then
        rawWindowKey = "current"
    end
    local windowKey = tostring(rawWindowKey)
    if boss.safeStageWindow ~= windowKey then
        boss.safeStageWindow = windowKey
        boss.safeStageAt = 0
    end
    if boss.windowKey ~= windowKey then
        local previousWindowKey = boss.windowKey
        boss.windowKey = windowKey
        boss.defeatedWindow = nil
        -- A changed EventId/opens-at is a new Rift Boss round. Reset only the
        -- per-round state here; do not require the user to toggle the feature
        -- off/on after the previous boss was defeated.
        if previousWindowKey ~= nil then
            boss.sessionDefeated = false
            boss.hopLocked = false
            boss.hasEnteredArena = false
            boss.armPathSeen = false
            boss.armHealth = nil
            boss.armHealthSource = ""
            boss.armHealthPositiveSeen = false
            boss.armHealthZeroSeen = false
            boss.armHealthZeroCandidateRevision = -1
            boss.armHealthZeroCandidateAt = 0
            boss.armInstance = nil
            boss.lastHealthAt = 0
            boss.liveSnapshot = nil
            boss.snapshotAt = 0
            boss.snapshotRevision = 0
            boss.snapshotInFlight = false
            boss.snapshotError = ""
            boss.leaveCompleted = false
            boss.hopQueued = false
            boss.hopAfterLeaveAt = 0
            boss.defeatedAt = 0
            boss.leaving = false
            boss.lastSwing = 0
            boss.roundClosedObserved = false
            boss.lastEnter = 0
            boss.combatLeg = nil
            if type(HUB.ClearRiftBossHopState) == "function" then
                HUB.ClearRiftBossHopState()
            end
        end
    end
    if not open and not inArena then
        if boss.sessionDefeated == true then boss.roundClosedObserved = true end
        boss.status, boss.detail = "waiting", "Rift arena window is closed"
        publishEvent("The Rift Boss", boss.detail, boss.status)
        if boss.hopQueued then HUB.ScheduleRiftBossHop() end
        return false
    end
    if boss.sessionDefeated == true and not inArena then
        boss.status, boss.detail = "resuming", "Boss cleared; staying in this server"
        publishEvent("The Rift Boss", boss.detail, boss.status)
        if boss.hopQueued then HUB.ScheduleRiftBossHop() end
        return true
    end
    if not inArena and open then
        if boss.defeatedWindow == windowKey then
            boss.status = boss.hopQueued and "waiting" or "resuming"
            boss.detail = boss.hopQueued
                and "Boss cleared; waiting for the configured Rift Boss hop delay"
                or "Boss cleared; staying in this server"
            publishEvent("The Rift Boss", boss.detail, boss.status)
            if boss.hopQueued then HUB.ScheduleRiftBossHop() end
            return true
        end
        if allowActions and not isPlayerCarryingEgg() and not cancelled() then
            -- A previous Auto Treadmill session can leave the player mounted
            -- while the boss window opens. Release it before AskEnter so the
            -- arena movement/teleport is not swallowed by treadmill state.
            ReleaseTreadmillForAction()
            -- Keep the collision guard armed for the join/teleport handoff as
            -- well as the fight itself. A short outside-arena frame must not
            -- put the character back into solid arena geometry.
            startRiftBossNoClip()
            boss.previousMovementOwner = HUB.StealGlide.owner
            HUB.StealGlide.owner = "boss"
            if boss.safeStageAt <= 0 then
                boss.status, boss.detail = "starting", "Moving to the Rift Boss safe position"
                if stageRiftBossAtSafeCenter(cancelled) then boss.safeStageAt = os.clock() end
            end
            local portalPos = boss.safeStageAt > 0 and HUB.GetBossArenaPortalPosition() or nil
            local atPortal = boss.safeStageAt > 0
            if portalPos then
                local root = findHRP()
                atPortal = root and (root.Position - portalPos).Magnitude <= 10
                if not atPortal then
                    atPortal = HUB.TweenRiftBossTo(
                        portalPos + Vector3.new(0, 3, 0),
                        math.min(glideSpeed, 600),
                        cancelled
                    ) == true
                end
            end
            if atPortal and os.clock() - (boss.lastEnter or 0) >= 1.2 then
                select(1, invokeEventRemote("BossEvent", "AskEnter"))
                boss.lastEnter = os.clock()
            elseif not atPortal then
                boss.status, boss.detail = "starting", "Moving to Rift Boss portal"
            end
            if atPortal then
                boss.status, boss.detail = "joining", "Entering the Rift arena"
            end
            HUB.StealGlide.owner = boss.previousMovementOwner
            boss.previousMovementOwner = nil
        else
        boss.status, boss.detail = "ready", "Arena open; Rift Boss route has priority"
        end
        publishEvent("The Rift Boss", boss.detail, boss.status)
        return true
    end
    local arena = Workspace:FindFirstChild("BossArena", true)
    -- Do not trust the generic BossHealth alone. The Beam/crystal phase must
    -- be finished first, then the final boss-hand HP must be zero before using
    -- BossArenaLeaveTeleport.
    -- Never complete (and therefore never arm delayed hop) from an open-window
    -- snapshot while outside the arena.  The live flow proves the arm was
    -- active in this round first, then accepts UpperHand1.R == 0.
    if inArena and HUB.IsBossArenaDefeated(snapshot, arena) then
        return completeRiftBossRun(boss, windowKey, allowActions, inArena)
    end

    -- The player may spend a few frames travelling to the beam target. Read
    -- the boss snapshot again before any swing so a kill that happened during
    -- that travel cannot turn into one extra Crystal Tower attack.
    local combatLegAlreadyMoved = type(boss.combatLeg) == "table"
        and boss.combatLeg.moved == true
    if inArena and allowActions and not combatLegAlreadyMoved and not cancelled() then
        local latest = HUB.ReadRiftBossSnapshotRealtime(true)
        if type(latest) == "table" then
            if HUB.IsBossArenaDefeated(latest, arena) then
                return completeRiftBossRun(boss, windowKey, allowActions, true)
            end
        end
    end

    -- Capture one movement leg.  Keep this patch scoped to boss movement: the
    -- live hand target is refreshed here, while all other hub features keep
    -- using their original controllers.
    local combatLeg = boss.combatLeg
    local target, label
    if type(combatLeg) == "table"
        and combatLeg.phase == "boss"
        and typeof(combatLeg.position) == "Vector3" then
        local liveTarget, liveLabel, _, liveRef = bossArenaTarget(arena)
        if liveTarget and liveLabel == "boss hand" then
            local targetChanged = liveRef ~= combatLeg.ref
                or (liveTarget - combatLeg.position).Magnitude > 8
            if targetChanged then
                pcall(function() HUB.CancelRiftBossTween() end)
                combatLeg.position = liveTarget
                combatLeg.ref = liveRef
                combatLeg.moved = false
            end
            target, label = liveTarget, liveLabel
        else
            -- The hand disappeared or the phase changed. Do not keep the
            -- player parked at the old hand position indefinitely.
            pcall(function() HUB.CancelRiftBossTween() end)
            boss.combatLeg = nil
            combatLeg = nil
        end
    else
        local candidate, candidateLabel, _, candidateRef = bossArenaTarget(arena)
        if type(combatLeg) == "table" and combatLeg.phase == "crystal" then
            if candidate and candidateRef == combatLeg.ref then
                -- Same Crystal/Hitbox leg: retain the original destination
                -- even if its beam attachment animates between snapshots.
                target, label = combatLeg.position, combatLeg.label
            elseif candidate then
                -- The beam selected a different Crystal/Hitbox or the hand
                -- phase began. Start one new tween leg for that real target.
                boss.combatLeg = nil
                target, label = candidate, candidateLabel
            else
                -- Allow a short streaming grace period, then clear a dead
                -- Crystal leg. This prevents the character from standing at
                -- the old tower while the hand target is being replicated.
                local ref = combatLeg.ref
                local refDead = not ref or not ref.Parent
                if ref and ref.Parent then
                    pcall(function()
                        refDead = refDead
                            or ref:GetAttribute("Destroyed") == true
                            or ref:GetAttribute("IsDestroyed") == true
                            or ref:GetAttribute("Dead") == true
                        for _, key in ipairs({ "Health", "HP", "CurrentHealth", "HitPoints" }) do
                            local value = tonumber(ref:GetAttribute(key))
                            if value ~= nil and value <= 0 then refDead = true break end
                        end
                    end)
                end
                if refDead then
                    pcall(function() HUB.CancelRiftBossTween() end)
                    boss.combatLeg = nil
                    combatLeg = nil
                else
                    combatLeg.missingSince = combatLeg.missingSince or os.clock()
                    if os.clock() - combatLeg.missingSince >= 0.75 then
                        pcall(function() HUB.CancelRiftBossTween() end)
                        boss.combatLeg = nil
                        combatLeg = nil
                    else
                        target, label = combatLeg.position, combatLeg.label
                    end
                end
            end
        else
            target, label = candidate, candidateLabel
        end
        if target then
            local phase = label == "boss hand" and "boss" or "crystal"
            combatLeg = boss.combatLeg
            if type(combatLeg) ~= "table"
                or combatLeg.phase ~= phase
                or combatLeg.label ~= label
                or typeof(combatLeg.position) ~= "Vector3" then
                combatLeg = {
                    phase = phase,
                    position = target,
                    label = label,
                    ref = candidateRef,
                    moved = false,
                }
                boss.combatLeg = combatLeg
            end
        end
    end
    if not target then
        boss.status = "fighting"
        boss.detail = "Waiting for the live Crystal Tower or Boss.UpperHand1.R target"
        publishEvent("The Rift Boss", boss.detail, boss.status)
        return true
    end
    if target and allowActions and not cancelled() then
        ReleaseTreadmillForAction()
        -- Equip before relocating so a tool swap cannot interrupt the attack
        -- once we are inside the crystal's hit range.
        if not ensureBossBat() then
            boss.status, boss.detail = "arming", "Equipping the Area Bat"
            publishEvent("The Rift Boss", boss.detail, boss.status)
            return true
        end
        -- Boss exclusively owns this movement leg. Combat uses a single native
        -- tween instead of the generic per-heartbeat CFrame glide; keep the
        -- grounded approach and boss no-clip lease active together.
        local previousBossOwner = HUB.StealGlide.owner
        boss.previousMovementOwner = previousBossOwner
        HUB.StealGlide.owner = "boss"
        local moveOk = false
        local swingTarget = target
        if combatLeg and combatLeg.moved == true then
            -- The leg is complete. Stay at the tween result and keep swinging;
            -- never re-tween to the animated hand/tower position.
            moveOk = true
            if findHRP() then swingBossBat(swingTarget) end
        else
            local root = findHRP()
            local approach = riftBossApproachPosition(target, label, root)
            if approach and not cancelled() then
                -- One native tween only. HP is checked by the realtime
                -- snapshot before/after this leg, not by a position follower
                -- or a heartbeat CFrame correction.
                local moveCallOk, moveResult = pcall(
                    HUB.TweenRiftBossTo,
                    approach,
                    math.min(glideSpeed, 600),
                    cancelled,
                    nil
                )
                moveOk = moveCallOk and moveResult == true
                if moveOk and combatLeg then combatLeg.moved = true end

                -- Confirm the live snapshot after the one captured tween leg.
                -- Do not retarget or run a close-range correction loop here.
                local afterMoveSnapshot = HUB.ReadRiftBossSnapshotRealtime(true)
                if afterMoveSnapshot and HUB.IsBossArenaDefeated(afterMoveSnapshot, arena) then
                    HUB.StealGlide.owner = previousBossOwner
                    boss.previousMovementOwner = nil
                    boss.combatLeg = nil
                    return completeRiftBossRun(boss, windowKey, true, true)
                end

                if moveOk and findHRP() then
                    swingBossBat(swingTarget)
                end
            end
        end
        HUB.StealGlide.owner = previousBossOwner
        boss.previousMovementOwner = nil
    end
    if cancelled() then return false end
    boss.status, boss.detail = "fighting", label or "Striking the Rift target"
    publishEvent("The Rift Boss", boss.detail, boss.status)
    return true
end

function IsRiftBossPriorityActive()
    local boss = eventState and eventState.boss
    if not boss or not boss.enabled then return false end
    if LP:GetAttribute("InBossArena") == true then return true end
    if boss.sessionDefeated == true then return false end
    if not hasRiftBossWorldTarget(boss, false) then return false end
    if boss.windowOpen == true and boss.defeatedWindow ~= boss.windowKey then return true end
    local status = tostring(boss.status or "")
    return status == "joining" or status == "fighting" or status == "leaving"
        or status == "respawning"
end

-- Boss HP is only meaningful to the hop controller while Auto Boss Rift is
-- enabled. When that toggle is off, this path is intentionally blind: a boss
-- killed by another player cannot arm or trigger a server change.
function isBossHopReady(state)
    local boss = eventState and eventState.boss
    if not boss then
        return false
    end
    -- This is a live gate, not just a queue check.  If the user disabled
    -- Auto Hop Server for Rift Boss after HP reached zero, invalidate any
    -- queued/delayed hop immediately so no old coroutine can teleport later.
    if boss.enabled ~= true or boss.hopExplicit ~= true or boss.hopEnabled ~= true then
        boss.hopQueued = false
        boss.hopAfterLeaveAt = 0
        boss.hopBusy = false
        if state and type(state.HopPermit) == "table" and state.HopPermit.reason == "boss" then
            state.HopPermit = nil
        end
        return false
    end
    if boss.hopQueued ~= true then
        return false
    end
    -- A hop permit is valid only for the same completed round that produced
    -- it.  These checks deliberately reject stale config/queue state from an
    -- older script instance or a server transition before any teleport call.
    if boss.hasEnteredArena ~= true
        or boss.defeatedAt == nil or tonumber(boss.defeatedAt) <= 0
        or boss.defeatedWindow == nil or boss.windowKey == nil
        or tostring(boss.defeatedWindow) ~= tostring(boss.windowKey)
        or tostring(boss.armHealthSource or "") ~= "Boss.UpperHand1.R"
        or tonumber(boss.armHealth) ~= 0 then
        return false
    end
    -- Delayed Rift Boss hop is armed only after the exact arm path has
    -- reported a positive HP during this round and then reached 0.  A generic
    -- BossHealth=0 snapshot, an open event window, or an old queue is not
    -- enough.  Also require that BossArenaLeaveTeleport has completed.
    if boss.armHealthPositiveSeen ~= true or boss.armHealthZeroSeen ~= true
        or boss.sessionDefeated ~= true or boss.leaveCompleted ~= true then
        return false
    end
    if boss.inArena == true or LP:GetAttribute("InBossArena") == true then return false end
    local afterLeave = tonumber(boss.hopAfterLeaveAt) or 0
    if afterLeave <= 0 then return false end
    local delay = tonumber(state and state.BossPostDefeatDelay) or 0
    return os.clock() >= afterLeave + math.max(0, delay)
end

function IsRiftBossHopBlocked(reason)
    local boss = eventState and eventState.boss
    if reason == "boss" then
        return not isBossHopReady(HUB.ServerHopState)
    end
    if not boss then return false end
    -- The dedicated Boss Hop toggle owns automatic server changes while it
    -- is enabled.  This blocks the separate rarity/no-match worker from
    -- hopping before a Boss Rift exists or before the boss proof is complete.
    if boss.hopExplicit == true and boss.hopEnabled == true then
        return true
    end
    if not boss.enabled then return false end
    -- Auto Boss Rift owns the server while enabled. Rarity/no-match hopping
    -- must not escape this run, even when an old saved no-match permit exists.
    if reason == "no-match" then return true end
    -- Auto Boss Rift blocks unrelated automatic hops while it owns the session.
    return true
end

function HUB.TriggerRiftBossHop()
    local state = HUB.ServerHopState
    local boss = eventState and eventState.boss
    if not boss or boss.hopExplicit ~= true or boss.hopEnabled ~= true
        or boss.hopBusy == true then
        if type(HUB.ClearRiftBossHopState) == "function" then
            HUB.ClearRiftBossHopState()
        end
        return false
    end
    -- Not ready can simply mean the post-defeat delay is still running.
    -- Preserve the queue so the scheduler can retry instead of clearing it.
    if not isBossHopReady(state) then return false end
    boss.hopBusy = true
    task.spawn(function()
        if HUB.dead or not boss.enabled or not isBossHopReady(state) then
            boss.hopBusy = false
            return
        end
        local ok = select(1, HUB.HopOnce("boss"))
        if not ok then
            boss.hopBusy = false
            boss.hopAfterLeaveAt = os.clock() + 5
        end
    end)
    return true
end

function HUB.ScheduleRiftBossHop()
    local state = HUB.ServerHopState
    local boss = eventState and eventState.boss
    if not boss or boss.hopQueued ~= true or boss.hopScheduleBusy == true then
        return false
    end
    boss.hopScheduleBusy = true
    local epoch = tonumber(boss.controllerEpoch) or 0
    task.spawn(function()
        while not HUB.dead
            and boss.enabled == true
            and boss.hopQueued == true
            and boss.hopBusy ~= true
            and (tonumber(boss.controllerEpoch) or 0) == epoch do
            if isBossHopReady(state) and HUB.TriggerRiftBossHop() then
                break
            end
            task.wait(0.25)
        end
        boss.hopScheduleBusy = false
    end)
    return true
end

function runBossShop()
    if not eventState.boss.shop then return end
    local mastery
    pcall(function() mastery = require(RS.Data.BossMastery) end)
    local save = readSaveTable()
    local tokens = tonumber(save.BossTokens) or (type(save.Currencies) == "table" and tonumber(save.Currencies.BossTokens)) or 0
    if type(mastery) ~= "table" or type(mastery.GetShopProducts) ~= "function" then return end
    local productsOk, products = pcall(mastery.GetShopProducts, type(save.BossMastery) == "table" and save.BossMastery or {})
    if not productsOk or type(products) ~= "table" then return end
    for _, product in ipairs(products) do
        local id = product and product.Id
        if id and selectedEventCategory(eventState.boss.shopItems, id) and tokens >= (tonumber(product.Price) or math.huge) then
            local ok = select(1, invokeEventRemote("BossMastery", "AskBuyShopItem", id))
            if ok == true then tokens -= tonumber(product.Price) or 0 end
        end
    end
end

function claimBossMilestones()
    if not eventState.boss.claim then return end
    local mastery
    pcall(function() mastery = require(RS.Data.BossMastery) end)
    local save = readSaveTable()
    if type(mastery) ~= "table" then return end
    local data = type(save.BossMastery) == "table" and save.BossMastery or {}
    local kills = tonumber(data.Mastery) or 0
    local claimed = type(data.ClaimedMilestoneIds) == "table" and data.ClaimedMilestoneIds or {}
    for _, milestone in ipairs(mastery.Milestones or {}) do
        if milestone.Id and (tonumber(milestone.Kills) or math.huge) <= kills and not claimed[milestone.Id] then
            invokeEventRemote("BossMastery", "AskClaimMilestone", milestone.Id)
        end
    end
    if type(mastery.ClaimableInfiniteCount) == "function" then
        local ok, count = pcall(mastery.ClaimableInfiniteCount, data)
        if ok and tonumber(count) and tonumber(count) > 0 then
            invokeEventRemote("BossMastery", "AskClaimMilestone", mastery.InfiniteMilestoneId or "Infinite")
        end
    end
end

-- Keep the event poll independent from the action worker so Web Log always
-- shows Rift/Boss state, even while Auto Steal is temporarily in control.
task.spawn(function()
    while not HUB.dead do
        -- Polling is read-only status work.  Never let it race the action
        -- controller while that controller is travelling or handing in a
        -- Rift recipe.
        if not automationActionBusy and (not HUB.MovementLease or HUB.MovementLease.owner == nil) then
            if eventState.rift.enabled then pcall(riftCycle, false) end
            -- Boss snapshots/actions belong to the single priority
            -- orchestrator below. A second four-second bossCycle reader can
            -- observe the same arena while the action leg is running and
            -- cancel/reselect movement, which recreates the old TP loop.
        end
        if eventState.boss.shop then pcall(runBossShop) end
        if eventState.boss.claim then pcall(claimBossMilestones) end
        -- Keep maintenance responsive while Rift/Boss is enabled.  The old
        -- four-second sleep was visible as a delayed boss status/target check;
        -- shop/claim-only sessions can keep the slower maintenance cadence.
        local maintenanceInterval = (eventState.boss.enabled
            or eventState.rift.enabled
            or eventState.boss.shop
            or eventState.boss.claim) and 0.5 or 4
        task.wait(maintenanceInterval)
    end
end)

-- ==============================================================================
-- EGG STEALING, PLANTING & HATCHING CORE LOGIC (Strict Rarity Matching)
-- ==============================================================================
-- Canonical rarity normalization. The game has used several shapes/aliases for
-- rarity values, so the filter must compare the final display rarity rather than
-- trusting one exact field name/casing.
HUB.RarityCanonical = {
    titan = "Titan", divine = "Divine", transcendent = "Transcendent", superior = "Superior",
    eternal = "Eternal", ethereal = "Eternal", etheral = "Eternal", limited = "Limited", secret = "Secret", exotic = "Exotic",
    cosmic = "Cosmic", exclusive = "Exclusive", admin = "Admin", mythic = "Mythical",
    mythical = "Mythical", prismatic = "Prismatic", rainbow = "Rainbow", ["squishy god"] = "Squishy God",
    brainrotgod = "BrainrotGod", legendary = "Legendary", epic = "Epic", rare = "Rare",
    superrare = "SuperRare", ["super rare"] = "SuperRare", celestial = "Celestial",
    uncommon = "Uncommon", basic = "Basic", common = "Common",
}

-- Suji reads the live Rarity catalog's `_id` and keeps its DisplayName for the
-- UI.  The game currently has builds where `_id` is `Etheral` while the
-- DisplayName is `Eternal`; keep that relationship instead of assuming the
-- display label is the server value.
HUB.LiveRarityAliases = {}
HUB.LiveRarityScores = {}

HUB.RarityKey = function(value)
    local text = tostring(value or ""):lower()
    text = text:gsub("[%s_%-]+", "")
    return text
end

HUB.CanonicalRarity = function(value)
    if type(value) == "table" then
        value = value.DisplayName or value.Name or value._id or value.Id
            or value.RarityName or value.RarityId or value.RarityKey or value.Key or value.Value
    end
    if value == nil then return nil end

    local n = tonumber(value)
    if n then
        -- Only use numeric rarity values when the game exposes RarityNumber.
        -- Numeric IDs without a catalog match should not be guessed.
        return nil, n * 100
    end

    local key = HUB.RarityKey(value)
    local liveName = HUB.LiveRarityAliases[key]
    if liveName then
        return liveName, HUB.LiveRarityScores[liveName]
    end
    return HUB.RarityCanonical[key] or tostring(value), nil
end

-- The live game and older configs have used both "Mythic" and "Mythical".
-- Normalize the selection itself as well as the record, so a selected rarity
-- cannot become a different target because the UI/catalog used another spelling.
HUB.SelectedRarityKey = function(value)
    local name = select(1, HUB.CanonicalRarity(value))
    return HUB.RarityKey(name or value)
end

-- Suji builds its rarity filter from the live Rarity module.  Keep the
-- familiar fallback options above, then add any current game rarity that is
-- present in that module.  Canonical keys prevent aliases such as Mythic /
-- Mythical and Ethereal / Eternal from becoming separate filter choices.
pcall(function()
    local rarityDir = RarityData and (RarityData.Rarities or RarityData)
    if type(rarityDir) ~= "table" then return end

    local seen = {}
    for _, name in ipairs(RARITY_NAMES) do
        seen[HUB.SelectedRarityKey(name)] = true
    end

    for rarityId, rarityInfo in pairs(rarityDir) do
        if type(rarityInfo) == "table" then
            local rawId = rarityInfo._id or rarityInfo.Id or rarityInfo.RarityId or rarityId
            local display = rarityInfo.DisplayName or rarityInfo.Name or rawId
            local displayKey = HUB.RarityKey(display)
            local displayCanonical = HUB.RarityCanonical[displayKey] or tostring(display)
            local rawKey = HUB.RarityKey(rawId)
            if rawKey ~= "" then HUB.LiveRarityAliases[rawKey] = displayCanonical end
            if displayKey ~= "" then HUB.LiveRarityAliases[displayKey] = displayCanonical end
            local rarityNumber = tonumber(rarityInfo.RarityNumber or rarityInfo.Number)
            if rarityNumber then HUB.LiveRarityScores[displayCanonical] = rarityNumber * 100 end
            local canonical = select(1, HUB.CanonicalRarity(display))
            local key = HUB.SelectedRarityKey(canonical or display)
            if key ~= "" and not seen[key] then
                table.insert(RARITY_NAMES, canonical or tostring(display))
                seen[key] = true
            end
        end
    end
end)

HUB.FindRarityDirectoryEntry = function(directory, key)
    if type(directory) ~= "table" or key == nil then return nil end
    local direct = directory[key]
    if direct ~= nil then return direct end
    local target = tostring(key):lower()
    for k, v in pairs(directory) do
        if tostring(k):lower() == target then return v end
    end
    return nil
end

HUB.ReadRarityValue = function(container)
    if type(container) ~= "table" then return nil end

    local candidates = {
        container.Rarity,
        container.RarityName,
        container.RarityType,
        container.RarityId,
    }
    for _, value in ipairs(candidates) do
        local name, score = HUB.CanonicalRarity(value)
        if name then
            local numeric = (type(value) == "table" and tonumber(value.RarityNumber))
            return name, (numeric and numeric * 100) or score
        end
    end

    local attrs = container.Attributes
    if type(attrs) == "table" then
        local name, score = HUB.CanonicalRarity(attrs.Rarity or attrs.RarityName or attrs.RarityType or attrs.RarityId)
        if name then return name, score end
    end

    return nil
end

HUB.GetEggRarityInfo = function(egg)
    if type(egg) ~= "table" then return "Common", 100 end

    -- Match Suji's source of truth: resolve the field record's Category from
    -- the live Assets catalog first. A stale/partial field record can carry a
    -- misleading Rarity field, while the catalog entry for Category is the
    -- same value used by the game's own rarity filter.
    if AssetsData then
        local assetsDir = AssetsData.Directory or AssetsData
        -- Suji indexes the live field record by AssetCategory.  Some game
        -- builds also expose a generic Category field; checking that first
        -- could resolve the wrong catalog entry and make a selected rarity
        -- appear to match an unrelated egg.  Keep AssetCategory first.
        local identifiers = {
            egg.AssetCategory, egg.Category, egg.EggName, egg.AssetId,
            egg.EggId, egg.Id, egg.Name,
        }
        for _, id in ipairs(identifiers) do
            local aInfo = HUB.FindRarityDirectoryEntry(assetsDir, id)
            local name, score = HUB.ReadRarityValue(aInfo)
            if name then
                return name, RARITY_SCORE_MAP[name] or score or 100
            end
        end
    end

    -- Keep explicit live-record data as a fallback for new assets that have
    -- not reached the local catalog yet.
    local directName, directScore = HUB.ReadRarityValue(egg)
    if directName then
        return directName, RARITY_SCORE_MAP[directName] or directScore or 100
    end

    -- Last-resort lookup through the area's configured rarity.
    if AreasData then
        local areasDir = AreasData.Directory or AreasData
        local areaData = HUB.FindRarityDirectoryEntry(areasDir, GetEggAreaId(egg))
        local name, score = HUB.ReadRarityValue(areaData)
        if name then
            if RarityData then
                local raritiesTable = RarityData.Rarities or RarityData
                local rInfo = HUB.FindRarityDirectoryEntry(raritiesTable, name)
                if not rInfo and type(raritiesTable) == "table" then
                    local wanted = HUB.SelectedRarityKey(name)
                    for rarityKeyId, rarityEntry in pairs(raritiesTable) do
                        if type(rarityEntry) == "table" then
                            local rawId = rarityEntry._id or rarityEntry.Id or rarityKeyId
                            local display = rarityEntry.DisplayName or rarityEntry.Name
                            if HUB.SelectedRarityKey(rawId) == wanted
                                or (display and HUB.SelectedRarityKey(display) == wanted) then
                                rInfo = rarityEntry
                                break
                            end
                        end
                    end
                end
                local rName, rScore = HUB.ReadRarityValue(rInfo)
                if not rName and type(rInfo) == "table" then
                    -- The live Rarity entry itself can expose only `_id`
                    -- (for example `Etheral`) plus DisplayName. Resolve that
                    -- catalog record exactly like Suji before falling back.
                    rName, rScore = HUB.CanonicalRarity(
                        rInfo.DisplayName or rInfo._id or rInfo.Name or rInfo.RarityId
                    )
                end
                if rName then name, score = rName, rScore end
            end
            return name, RARITY_SCORE_MAP[name] or score or 100
        end
    end

    return "Common", 100
end

-- These small predicates are globals to keep their bindings out of the
-- top-level local-register pool of the single-file Luau build.
function isRarityAllowed(rarityName, filter)
    if type(filter) ~= "table" then return true end

    -- MultiSelect implementations differ: some return {Rare=true}, others
    -- return {"Rare"}. Treat both as the same selection model.
    local selected = {}
    local selectedCount = 0
    for k, v in pairs(filter) do
        if type(v) == "string" and v ~= "" then
            local key = HUB.SelectedRarityKey(v)
            if key ~= "" then
                selected[key] = true
                selectedCount += 1
            end
        elseif v == true and type(k) == "string" then
            local key = HUB.SelectedRarityKey(k)
            if key ~= "" then
                selected[key] = true
                selectedCount += 1
            end
        end
    end

    -- Empty selection means "no rarity restriction".
    if selectedCount == 0 then return true end

    local current = HUB.SelectedRarityKey(rarityName)
    return selected[current] == true
end

function selectionHasValues(selection)
    if type(selection) ~= "table" then return false end
    for key, value in pairs(selection) do
        if type(value) == "string" and value ~= "" then return true end
        if value == true and type(key) == "string" and key ~= "" then return true end
    end
    return false
end

-- Keep this as a global helper instead of another top-level local binding;
-- the single-file Luau build is close to its 200-register chunk limit.
function isAssetCategorySelected(item, selection)
    if not selectionHasValues(selection) then return false end
    for key, value in pairs(selection) do
        local category = type(value) == "string" and value or (value == true and key)
        if category and riftCategoryMatches(item, category) then
            return true
        end
    end
    return false
end

function isSellSelectionMatch(item, categorySelection, raritySelection)
    local categorySelected = selectionHasValues(categorySelection)
    local raritySelected = selectionHasValues(raritySelection)
    if categorySelected and isAssetCategorySelected(item, categorySelection) then
        return true
    end
    if raritySelected then
        local rarityName = select(1, HUB.GetEggRarityInfo(item))
        return isRarityAllowed(rarityName, raritySelection)
    end
    -- An empty seller selection means "sell nothing". This also
    -- prevents a fresh/reloaded UI from selling items before the user picks a
    -- category or rarity.
    return false
end

function isAreaAllowed(areaId, filter)
    if not filter or type(filter) ~= "table" then return true end

    if filter[areaId] == true then return true end
    local aLower = string.lower(tostring(areaId or ""))
    -- AreaIds can be stored as display text or as a compact internal id.
    -- Keep the friendly dropdown label while matching the live "Light Dark"
    -- AreaId returned by EggState.ReadFieldEggs().
    local aKey = NormalizeAreaIdKey(areaId)
    local canonicalKey = AREA_ID_ALIASES[aKey] or aKey
    local selectedCount = 0
    for k, v in pairs(filter) do
        local selected = type(v) == "string" and v or (type(k) == "string" and v == true and k)
        if selected then
            selectedCount += 1
            local selectedLower = string.lower(tostring(selected))
            local selectedKey = NormalizeAreaIdKey(selected)
            if selectedLower == aLower or (AREA_ID_ALIASES[selectedKey] or selectedKey) == canonicalKey then
                return true
            end
        end
    end
    return selectedCount == 0
end

-- Suji converts both array-style and map-style mutation replicas to one list.
-- The live snapshot can return `{Rainbow = true}`; using `#muts`/`ipairs`
-- directly on that shape silently loses the selected mutation filter.
HUB.SujiMutationList = function(value)
    if type(value) ~= "table" then return {} end
    local result = {}
    for key, item in pairs(value) do
        if type(item) == "string" and item ~= "" then
            result[#result + 1] = item
        elseif item == true and type(key) == "string" then
            result[#result + 1] = key
        end
    end
    return result
end

function isMutationAllowed(muts, record, filter)
    muts = HUB.SujiMutationList(muts)
    local isParasite = (record and record.HasParasite == true)
        or (type(muts) == "table" and (table.find(muts, "Parasite") or table.find(muts, "Monstrous")))
        or (record and (record.BaseMutation == "Parasite" or record.BaseMutation == "Monstrous"))

    if stealParasiteOnly and not isParasite then
        return false
    end

    if not filter or type(filter) ~= "table" then return true end
    if not selectionHasValues(filter) then return true end

    local hasMut = type(muts) == "table" and #muts > 0
    local allowed = false
    for _, opt in pairs(filter) do
        if type(opt) == "string" then
            if opt == "Normal Only" and not hasMut and not isParasite then
                allowed = true
            elseif opt == "Mutated Only" and (hasMut or isParasite) then
                allowed = true
            elseif (opt == "Parasite / Infested" or opt == "Monstrous") and isParasite then
                allowed = true
            elseif opt == "Silver Only" and type(muts) == "table" and table.find(muts, "Silver") then
                allowed = true
            elseif opt == "Gold Only" and type(muts) == "table" and (table.find(muts, "Gold") or table.find(muts, "Golden")) then
                allowed = true
            elseif opt == "Rainbow Only" and type(muts) == "table" and table.find(muts, "Rainbow") then
                allowed = true
            end
        end
    end
    return allowed
end

-- Keep this helper on HUB instead of adding another local function to the
-- already large top-level scope.  Luau limits a single local scope to 200
-- registers, and this predicate does not need closure capture.
HUB.IsBigEgg = function(record)
    if not record then return false end
    local scale = tonumber(record.AssetScale) or 1
    local nestScale = tonumber(record.NestScale) or 1
    -- A default NestScale of 1 is normal-sized; treating it as "big" makes
    -- the Big Egg filter match every field egg.
    return scale >= 1.35 or nestScale > 1.0
end

-- Final gate for Auto Steal. The scanner already applies this filter, but the
-- field snapshot can change between scan and pickup. Rechecking immediately
-- before movement and again after refreshing the UID prevents a stale target
-- (for example Mythical) from being carried after the user selected another
-- rarity. Rift quest sourcing does not set this marker and is intentionally
-- exempt from the normal Auto Steal filters.
HUB.IsSelectedAutoStealRecordAllowed = function(record)
    if type(record) ~= "table" then return false end
    local rarityName = select(1, HUB.GetEggRarityInfo(record))
    local mutations = HUB.SujiMutationList(record.Mutations)
    return isAreaAllowed(GetEggAreaId(record), selectedStealAreas)
        and isRarityAllowed(rarityName, selectedStealRarities)
        and isMutationAllowed(mutations, record, selectedMutationTypes)
        and (not stealBigEggsOnly or HUB.IsBigEgg(record))
end

-- Some UI builds update the visual MultiSelect before invoking its callback.
-- Read the live handles before every scan so a config that visibly says
-- "4 selected" cannot still be treated as an empty filter (which means all
-- rarities).  Both array and {Name = true} selection shapes are supported by
-- the matching functions above.
function HUB.SyncAutoStealFilters()
    local handles = HUB.StealFilterHandles
    if type(handles) ~= "table" then return end

    local rarityHandle = handles.rarity
    if rarityHandle and type(rarityHandle.Get) == "function" then
        local ok, value = pcall(function() return rarityHandle:Get() end)
        if ok and type(value) == "table"
            and (selectionHasValues(value) or not selectionHasValues(selectedStealRarities)) then
            HUB.ApplyAutoStealFilterSelection("rarity", value, RARITY_NAMES)
        end
    end

    local areaHandle = handles.area
    if areaHandle and type(areaHandle.Get) == "function" then
        local ok, value = pcall(function() return areaHandle:Get() end)
        if ok and type(value) == "table"
            and (selectionHasValues(value) or not selectionHasValues(selectedStealAreas)) then
            HUB.ApplyAutoStealFilterSelection("area", value, AREA_NAMES)
        end
    end

    local mutationHandle = handles.mutation
    if mutationHandle and type(mutationHandle.Get) == "function" then
        local ok, value = pcall(function() return mutationHandle:Get() end)
        if ok and type(value) == "table"
            and (selectionHasValues(value) or not selectionHasValues(selectedMutationTypes)) then
            HUB.ApplyAutoStealFilterSelection("mutation", value, MUTATION_FILTERS)
        end
    end
end

GetMatchingFieldEggs = function(areasFilter, raritiesFilter, mutationsFilter)
    if type(HUB.ReadSujiFieldEggSnapshot) ~= "function"
        and (not EggState or type(EggState.ReadFieldEggs) ~= "function") then
        return {}
    end
    -- Calls from Auto Steal/Treadmill pass the current filter tables; Rift
    -- sourcing deliberately passes fresh {} tables to scan every field egg.
    -- Only replace the former group so Rift quest sourcing stays independent
    -- from the normal Auto Steal rarity/area selection.
    local useLiveStealFilters = areasFilter == selectedStealAreas
        and raritiesFilter == selectedStealRarities
        and mutationsFilter == selectedMutationTypes
    pcall(HUB.SyncAutoStealFilters)
    if useLiveStealFilters then
        areasFilter, raritiesFilter, mutationsFilter = selectedStealAreas, selectedStealRarities, selectedMutationTypes
    end
    -- The central worker selects from the current round.  Refresh signals mark
    -- the shared replica dirty and the background poll refreshes it; reusing
    -- that short-lived cache here avoids three duplicate RemoteFunction calls
    -- for the same Rift quest while still picking up a new map egg quickly.
    local ok, snapshot = pcall(HUB.ReadSujiFieldEggSnapshot)
    if not ok or type(snapshot) ~= "table" or type(snapshot.Records) ~= "table" then return {} end

    local matched = {}
    -- An empty Area MultiSelect means no Area restriction: scan every biome.
    -- Keep this explicit at the scanner level so a blank/restored dropdown
    -- cannot accidentally become an Area filter.
    local allAreas = not selectionHasValues(areasFilter)
    for _, record in pairs(snapshot.Records) do
        local recordPosition = GetFieldEggPosition(record)
        local recordUid = tostring(record and record.Uid or "")
        -- Suji excludes the player's own FirstArea display slots. They are
        -- not stealable field eggs and selecting one leaves the route parked
        -- at the same position while the real field eggs remain untouched.
        if recordUid:find("FirstAreaEgg_", 1, true) == 1 then
            continue
        end
        if (record.State == "Slot" or record.State == "Dropped") and recordPosition then
            local isIgnored = ignoredEggs[record.Uid] and (os.clock() - ignoredEggs[record.Uid] < 2.5)
            if not isIgnored and (not stealBigEggsOnly or HUB.IsBigEgg(record)) then
                local areaOk = allAreas or isAreaAllowed(GetEggAreaId(record), areasFilter)
                local rarityName, baseScore = HUB.GetEggRarityInfo(record)
                local rarityOk = isRarityAllowed(rarityName, raritiesFilter)
                local muts = HUB.SujiMutationList(record.Mutations)
                local mutOk = isMutationAllowed(muts, record, mutationsFilter)

                -- Strict filter check: only insert if all selected filters match!
                if areaOk and rarityOk and mutOk then
                    local mutBonus = 0
                    for _, m in ipairs(muts) do
                        if m == "Rainbow" then mutBonus = mutBonus + 35
                        elseif m == "Gold" or m == "Golden" then mutBonus = mutBonus + 20
                        elseif m == "Silver" then mutBonus = mutBonus + 10 end
                    end

                    if record.HasParasite == true or (type(muts) == "table" and (table.find(muts, "Parasite") or table.find(muts, "Monstrous"))) then
                        mutBonus = mutBonus + 800
                    end

                    if HUB.IsBigEgg(record) then
                        mutBonus = mutBonus + 600
                    end

                    local eggValue, valueKnown = HUB.GetAutoStealEggValue(record, baseScore)

                    table.insert(matched, {
                        record = record,
                        rarity = rarityName,
                        rarityScore = baseScore,
                        value = eggValue,
                        valueKnown = valueKnown,
                        score = baseScore + mutBonus
                    })
                end
            end
        end
    end

    -- Always take the highest-value egg first.  If the game does not expose a
    -- final value for a record, use canonical rarity as the fallback order;
    -- mutation/size bonuses only break ties.  This keeps Auto Steal value-first
    -- even when the legacy Rare Egg Hunter toggle is off or restored oddly.
    if #matched > 1 then
        table.sort(matched, function(a, b)
            if a.valueKnown ~= b.valueKnown then return a.valueKnown end
            if a.value ~= b.value then return a.value > b.value end
            if a.rarityScore ~= b.rarityScore then return a.rarityScore > b.rarityScore end
            if a.score ~= b.score then return a.score > b.score end
            local auid = tostring(a.record and a.record.Uid or "")
            local buid = tostring(b.record and b.record.Uid or "")
            return auid < buid
        end)
    end

    if useLiveStealFilters and type(HUB.NoteAutoStealTargetScan) == "function" then
        HUB.NoteAutoStealTargetScan(#matched)
    end
    return matched
end

-- Suji keeps the field-egg replica warm even when stealing is turned off.
-- This is deliberately a snapshot-only loop: it never selects a target,
-- moves the character, equips an egg, or claims a prompt.  The Central
-- Orchestrator remains the only owner allowed to start Auto Steal/Rift/
-- Treadmill movement, so toggles can be changed independently without
-- requiring a script restart after the next map refresh.
if not HUB.FieldEggScanLoopStarted then
    HUB.FieldEggScanLoopStarted = true
    pcall(HUB.BindFieldEggRefreshSignals)
    task.spawn(function()
        while not HUB.dead do
            -- Keep the shared replica warm so respawns without a ChildAdded
            -- signal are visible without rerunning the script. The reader's
            -- short cache prevents duplicate remote calls from each worker.
            pcall(HUB.ReadSujiFieldEggSnapshot)
            task.wait(0.12)
        end
        HUB.FieldEggScanLoopStarted = false
    end)
end

HUB.EnsureSavedReturnPosition = function()
    if not savedReturnCFrame then
        local hrp = findHRP()
        if hrp then
            savedReturnCFrame = hrp.CFrame
        end
    end
end

isPlayerCarryingEgg = function()
    -- The Rift snapshot is authoritative.  Do not use DropHeldEgg.Enabled as
    -- the first gate: in several game builds that GUI remains enabled while it
    -- is merely mounted in PlayerGui, which made every automation worker think
    -- an egg was being carried and left the character parked at the plot.
    local char = LP.Character
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") then
                local toolName = string.lower(tostring(item.Name or ""))
                if item:GetAttribute("IsBat") == true
                    or item:GetAttribute("ItemType") == "Bat"
                    or toolName:find("bat", 1, true) then
                    continue
                end
                -- A character-held egg must be explicitly identified.  Never
                -- treat an arbitrary tool with a generic UID/AssetCategory as
                -- a carried egg; inventory tools belong in Backpack and the
                -- old broad check blocked the unified controller forever.
                local isEgg = item:GetAttribute("IsEgg") == true
                    or item:GetAttribute("ItemType") == "AssetEgg"
                    or toolName:find("egg", 1, true) ~= nil
                    or toolName:match("[Kk]g%s*%)") ~= nil
                if not isEgg and EggToolDisplay and type(EggToolDisplay.IsEggTool) == "function" then
                    pcall(function() isEgg = EggToolDisplay.IsEggTool(item) == true end)
                end
                if isEgg then return true end
            elseif item:IsA("Model") then
                local name = string.lower(tostring(item.Name or ""))
                if name:find("egg", 1, true) and (item:GetAttribute("IsEgg") == true or item:GetAttribute("Uid") ~= nil) then
                    return true
                end
            end
        end
    end
    return false
end

-- The field-carry request is UID based, but the fallback ProximityPrompt can
-- otherwise select the first nearby egg. Keep an identity-aware prompt lookup
-- so a crowded nest can never equip a different rarity/area egg just because
-- its prompt happened to be enumerated first.
HUB.GetPromptWorldPosition = function(prompt)
    local node = prompt
    for _ = 1, 8 do
        if not node then break end
        if node:IsA("Attachment") then return node.WorldPosition end
        if node:IsA("BasePart") then return node.Position end
        node = node.Parent
    end
    return nil
end

HUB.PromptMatchesFieldEgg = function(prompt, record)
    if not prompt or type(record) ~= "table" then return false end
    local wantedUid = tostring(record.Uid or "")
    if wantedUid == "" then return false end

    local uidSeen = false
    local uidMatch = false
    local nestSeen = false
    local nestMatch = false
    local uidKeys = { "Uid", "UID", "EggUid", "EggUID", "AssetUid", "AssetUID", "RecordUid", "RecordUID" }
    local nestKeys = { "NestId", "NestID", "SlotKey", "FirstAreaSlotKey" }
    local wantedNest = tostring(record.NestId or record.NestID or record.SlotKey or "")
    local node = prompt

    for _ = 1, 8 do
        if not node then break end
        for _, key in ipairs(uidKeys) do
            local value = node:GetAttribute(key)
            if value ~= nil then
                uidSeen = true
                if tostring(value) == wantedUid then uidMatch = true end
            end
        end
        for _, key in ipairs(nestKeys) do
            local value = node:GetAttribute(key)
            if value ~= nil then
                nestSeen = true
                if wantedNest ~= "" and tostring(value) == wantedNest then nestMatch = true end
            end
        end
        if tostring(node.Name or "") == wantedUid then
            uidSeen = true
            uidMatch = true
        end
        node = node.Parent
    end

    -- If the game exposes an identity, it is authoritative. If it does not,
    -- the caller still applies a tight position gate around the chosen record.
    if uidSeen then return uidMatch end
    if nestSeen then return nestMatch end
    return true
end

HUB.FindFieldEggPrompt = function(record, targetPosition, maxDistance)
    if type(record) ~= "table" then return nil end
    local wantedPosition = targetPosition or GetFieldEggPosition(record)
    if typeof(wantedPosition) ~= "Vector3" then return nil end
    local limit = tonumber(maxDistance) or 7
    local best, bestDistance

    for _, prompt in ipairs(Workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Name == "CarryAreaEgg" and prompt.Enabled then
            local actionText = string.lower(tostring(prompt.ActionText or ""))
            local objectText = string.lower(tostring(prompt.ObjectText or ""))
            if not actionText:find("skip", 1, true) and not actionText:find("robux", 1, true)
                and not objectText:find("skip", 1, true) and not objectText:find("robux", 1, true)
                and HUB.PromptMatchesFieldEgg(prompt, record) then
                local position = HUB.GetPromptWorldPosition(prompt)
                if position then
                    local distance = (position - wantedPosition).Magnitude
                    if distance <= limit and (not bestDistance or distance < bestDistance) then
                        best, bestDistance = prompt, distance
                    end
                end
            end
        end
    end
    return best
end

-- Confirm the carried object UID whenever the client exposes one. A boolean
-- DropHeldEgg signal alone is not enough: it can be raised for a different egg
-- if a nearby prompt won a race with the requested field UID.
HUB.GetCarriedEggUid = function()
    -- Match Suji: read the live field replica first and require the local
    -- player as carrier.  A record with a missing/foreign CarrierUserId is not
    -- proof that this client is holding the egg.
    if EggState and type(EggState.ReadFieldEggs) == "function" then
        local ok, snapshot = pcall(EggState.ReadFieldEggs)
        if ok and type(snapshot) == "table" and type(snapshot.Records) == "table" then
            for _, record in ipairs(snapshot.Records) do
                if type(record) == "table" and record.State == "Carried" then
                    local carrier = record.CarrierUserId or record.CarrierId or record.CarriedBy
                    if carrier ~= nil and tostring(carrier) == tostring(LP.UserId) then
                        return record.Uid and tostring(record.Uid) or nil
                    end
                end
            end
        end
    end

    local character = LP.Character
    if not character then return nil end
    local uidKeys = { "Uid", "UID", "EggUid", "EggUID", "AssetUid", "AssetUID", "RecordUid", "RecordUID" }

    for _, item in ipairs(character:GetChildren()) do
        local isTool = item:IsA("Tool")
        local isModel = item:IsA("Model")
        if isTool or isModel then
            local itemName = string.lower(tostring(item.Name or ""))
            if isTool and (item:GetAttribute("IsBat") == true or item:GetAttribute("ItemType") == "Bat" or itemName:find("bat", 1, true)) then
                continue
            end

            local looksLikeEgg = item:GetAttribute("IsEgg") == true
                or item:GetAttribute("ItemType") == "AssetEgg"
                or item:GetAttribute("AssetCategory") == "Egg"
                or itemName:find("egg", 1, true) ~= nil
                or itemName:match("[Kk]g%s*%)") ~= nil
            if isTool and not looksLikeEgg and EggToolDisplay and type(EggToolDisplay.IsEggTool) == "function" then
                pcall(function() looksLikeEgg = EggToolDisplay.IsEggTool(item) == true end)
            end
            -- Uids are also used by pets/tools.  Only inspect a character
            -- child as a carried egg after its own egg identity is confirmed.
            if not looksLikeEgg then continue end

            local uid
            for _, key in ipairs(uidKeys) do
                local value = item:GetAttribute(key)
                if value ~= nil then uid = value break end
            end
            if not uid and isTool and EggToolDisplay and type(EggToolDisplay.GetToolUid) == "function" then
                pcall(function() uid = EggToolDisplay.GetToolUid(item) end)
            end
            if uid ~= nil then return tostring(uid) end

            for _, descendant in ipairs(item:GetDescendants()) do
                for _, key in ipairs(uidKeys) do
                    local value = descendant:GetAttribute(key)
                    if value ~= nil then return tostring(value) end
                end
            end
        end
    end

    return nil
end

HUB.IsExactCarriedEgg = function(record)
    if type(record) ~= "table" or record.Uid == nil then return false end
    -- Keep v51's carry proof: the live field carrier UID is authoritative when
    -- the game exposes it; otherwise the game's own carry predicate is the
    -- fallback.  Requiring a Tool first made valid carries look empty on builds
    -- that represent the held egg as a Model or replicate the Tool one frame
    -- later, which caused an immediate drop/return-to-base.
    local actualUid = HUB.GetCarriedEggUid()
    if actualUid ~= nil then
        return actualUid == tostring(record.Uid)
    end
    return isPlayerCarryingEgg() == true
end

-- Suji gates the guard phase and the return leg on the live Character carry,
-- not only on the field replica.  The replica can lag or omit the Tool UID on
-- some builds, but a stale `State = Carried` without a live egg must never
-- qualify as a carry.
HUB.IsSelectedCarriedEgg = function(record)
    if type(record) ~= "table" or record.Uid == nil then return false end
    return HUB.IsExactCarriedEgg(record) == true
end

-- A carried Tool can still exist for a few frames while the humanoid is in a
-- guard knockback/ragdoll state.  Do not begin the base return until the exact
-- UID is equipped and the character has settled on the ground.
HUB.IsReadyToReturnEgg = function(record)
    if not HUB.IsSelectedCarriedEgg(record) then return false end
    local hum = findHum()
    local root = findHRP()
    if not hum or not root then return false end

    local state
    pcall(function() state = hum:GetState() end)
    if state == Enum.HumanoidStateType.Jumping
        or state == Enum.HumanoidStateType.Freefall
        or state == Enum.HumanoidStateType.FallingDown
        or state == Enum.HumanoidStateType.Ragdoll
        or state == Enum.HumanoidStateType.Physics then
        return false
    end

    local ragdollEnd = LP:GetAttribute("RagdollEndTime")
    if tonumber(ragdollEnd) and Workspace and Workspace.GetServerTimeNow then
        local ok, serverNow = pcall(function() return Workspace:GetServerTimeNow() end)
        if ok and tonumber(ragdollEnd) - tonumber(serverNow) > 0 then return false end
    end

    local velocity = root.AssemblyLinearVelocity
    return math.abs(velocity.Y) <= 14
        and Vector3.new(velocity.X, 0, velocity.Z).Magnitude <= 32
end

function PlantAllCarriedEggsInPen(includeBagEggs)
    if HUB.dead then return 0 end
    if type(HUB.CanMovementOwnerProceed) == "function"
        and not HUB.CanMovementOwnerProceed(HUB.StealGlide and HUB.StealGlide.owner) then
        return 0
    end
    if _G.AxelWebLog and _G.AxelWebLog.SetActivity then
        _G.AxelWebLog.SetActivity("Planting Eggs", includeBagEggs and "Placing selected egg inventory in the base pen" or "Placing carried eggs in the base pen")
    end

    local character = LP.Character
    local backpack = LP:FindFirstChildOfClass("Backpack")
    if not character then return 0 end

    local eggUids, seen = {}, {}
    local function addUid(uid)
        if uid == nil then return end
        local key = tostring(uid)
        if key ~= "" and not seen[key] then
            seen[key] = true
            table.insert(eggUids, uid)
        end
    end
    local function addTool(tool)
        if not isEggToolForPlacement(tool) then return end
        local uid
        if EggToolDisplay and type(EggToolDisplay.GetToolUid) == "function" then
            pcall(function() uid = EggToolDisplay.GetToolUid(tool) end)
        end
        uid = uid or tool:GetAttribute("Uid") or tool:GetAttribute("UID")
            or tool:GetAttribute("EggUid") or tool:GetAttribute("EggUID")
            or tool:GetAttribute("AssetUid") or tool:GetAttribute("AssetUID")
        addUid(uid)
    end

    -- Never use a stale field-replica UID after the carried visual disappeared.
    -- A dropped egg must go through SujiReCarryEgg before it is eligible for
    -- placement; otherwise an old UID can make the route plant too early.
    if isPlayerCarryingEgg() then
        addUid(HUB.GetCarriedEggUid and HUB.GetCarriedEggUid())
        -- A guard hit can remove the field replica's CarrierUserId for a few
        -- frames while the exact egg Tool is already back in Character.
        addUid(getEquippedEggUid())
    end
    for _, tool in ipairs(character:GetChildren()) do addTool(tool) end
    if includeBagEggs and backpack then
        for _, tool in ipairs(backpack:GetChildren()) do addTool(tool) end
    end

    local save = readSaveTable()
    if includeBagEggs and type(save.EggInventory) == "table" then
        for uid, egg in pairs(save.EggInventory) do
            local key = tostring(uid)
            if type(egg) == "table" and not egg.Placement and not HUB.InventoryItemProtected(egg, key, save) and not seen[key] then
                addUid(egg.Uid or egg.UID or egg.EggUid or egg.EggUID or egg.AssetUid or egg.AssetUID or uid)
            end
        end
    end
    if #eggUids == 0 then return 0 end

    local plotCenter = GetLocalPlotCenter()
    local root = findHRP()
    if not plotCenter or not root then return 0 end

    local wasReturning = carryingEggReturnActive
    local previousOwner = HUB.StealGlide.owner
    local noClipWasActive = HUB.RiftNoClip and HUB.RiftNoClip.active == true
    if not previousOwner then HUB.StealGlide.owner = "place" end
    if not noClipWasActive then HUB.StartRiftNoClip() end
    carryingEggReturnActive = true
    local plantedCount = 0
    local ok = pcall(function()
        if (root.Position - plotCenter).Magnitude > 30 then
            if not HUB.ReturnViaSafeCenter(plotCenter, math.min(glideSpeed, 600), nil) then
                return false
            end
            task.wait(0.2)
        end

        for _, eggUid in ipairs(eggUids) do
            if HUB.dead then break end
            local placed, status = HUB.SujiPlaceEggInPen(eggUid, true)
            if status == "far" then
                local center = GetLocalPlotCenter()
                -- Planting is part of the carried return flow; it must keep
                -- the tween/glide handoff even when outbound travel is WARP.
                local movedToCenter = center
                    and HUB.StealGlide.To(center, math.min(glideSpeed, 600), nil) == true
                if movedToCenter then
                    placed, status = HUB.SujiPlaceEggInPen(eggUid, true)
                end
            end
            if placed and status ~= "skip" then plantedCount += 1 end
            task.wait(0.12)
        end
    end)
    carryingEggReturnActive = wasReturning
    HUB.StealGlide.owner = previousOwner
    if not noClipWasActive then HUB.StopRiftNoClip() end
    return ok and plantedCount or plantedCount
end

-- Suji's Auto Steal flow is intentionally kept as a separate small set of
-- helpers.  Keeping it out of the legacy Rift/Treadmill function prevents the
-- two routes from sharing stale movement/carry state and avoids another large
-- local-register closure.
HUB.ResetAutoStealState = function()
    -- If an egg is already attached, let the current carry -> base leg finish
    -- safely.  Clearing its owner in the middle of the delivery would strand
    -- the egg and leave carryingEggReturnActive latched forever.
    local carryingNow = false
    pcall(function()
        carryingNow = isPlayerCarryingEgg and isPlayerCarryingEgg() == true
    end)
    if carryingNow then
        carryingEggReturnActive = true
        HUB.AutoStealMovementActive = true
        return false
    end

    if (HUB.StealTeleport and HUB.StealTeleport.active == true)
        or (HUB.StealGlide and HUB.StealGlide.owner == "auto")
        or (type(HUB.SujiRouteState) == "table" and HUB.SujiRouteState.autoRoute == true) then
        pcall(function() HUB.StealTeleport.Cancel() end)
    end

    carryingEggReturnActive = false
    HUB.AutoStealMovementActive = false
    HUB.StealGlide.speedGuard = false
    pcall(EndEggTravelSpeedWatch)
    HUB.SujiRouteState = nil
    if HUB.StealGlide.owner == "auto" then
        HUB.StealGlide.owner = nil
    end
    -- Resetting Auto Steal must also release its controller ownership.  The
    -- old cleanup cleared only the glide fields, leaving Orchestrator.suspended
    -- and an auto-steal movement lease behind; Auto Treadmill then saw a valid
    -- toggle but could never acquire movement.
    if HUB.Orchestrator and HUB.Orchestrator.owner == "steal" then
        HUB.Orchestrator.End("steal")
    end
    if HUB.MovementLease and HUB.MovementLease.owner == "auto-steal" then
        HUB.MovementLease.owner, HUB.MovementLease.depth = nil, 0
        HUB.MovementLease.lastAt = os.clock()
    end
    savedReturnCFrame = nil
    pcall(function() HUB.StealGlide.ResetMovementEvidence() end)
    for uid in pairs(ignoredEggs) do
        ignoredEggs[uid] = nil
    end
    return true
end

-- Hand movement back to the lower-priority controller when the selected
-- rarity/area scan is empty. Auto Steal remains enabled for the next scan, but
-- its old route owner/no-clip lease must not keep the character parked at the
-- plot while Rift or Auto Treadmill is waiting for work.
HUB.ReleaseAutoStealForFallback = function()
    local carryingNow = false
    pcall(function() carryingNow = isPlayerCarryingEgg() == true end)
    if carryingNow then return false end
    if (HUB.StealTeleport and HUB.StealTeleport.active == true)
        or (HUB.StealGlide and HUB.StealGlide.owner == "auto")
        or (type(HUB.SujiRouteState) == "table" and HUB.SujiRouteState.autoRoute == true) then
        pcall(function() HUB.StealTeleport.Cancel() end)
    end
    if carryingEggReturnActive then
        -- A route exception can leave the return flag latched after the exact
        -- Tool has already disappeared. Do not let that stale flag block the
        -- priority worker forever; a live route gets a short grace period.
        local route = HUB.SujiRouteState
        local routeAge = route and (os.clock() - (tonumber(route.startedAt) or os.clock())) or math.huge
        if route and routeAge < 8 then return false end
        carryingEggReturnActive = false
    end
    HUB.AutoStealMovementActive = false
    HUB.StealGlide.speedGuard = false
    pcall(EndEggTravelSpeedWatch)
    HUB.SujiRouteState = nil
    if HUB.StealGlide.owner == "auto" then HUB.StealGlide.owner = nil end
    pcall(HUB.StopAutoStealNoClip)
    if HUB.Orchestrator and HUB.Orchestrator.owner == "steal" then
        HUB.Orchestrator.End("steal")
    end
    if HUB.MovementLease and HUB.MovementLease.owner == "auto-steal" then
        HUB.MovementLease.owner, HUB.MovementLease.depth = nil, 0
        HUB.MovementLease.lastAt = os.clock()
    end
    pcall(HUB.WakeAutomation, "Auto Steal released for fallback")
    return true
end

-- When Auto Steal is switched off, its route must become completely inert
-- before the lower-priority treadmill is considered.  The old controller
-- cleared the visible glide flag but could leave a stale owner, speed watcher,
-- or suspended Orchestrator slot behind.  That made Auto Treadmill appear to
-- be enabled while every movement attempt was rejected.  This helper is
-- intentionally idempotent and only clears Auto Steal-owned state; a live
-- carried egg or a live Rift route is never interrupted here.
HUB.ReconcileAutoStealForTreadmill = function()
    if autoStealEnabled == true or carryingEggReturnActive == true then
        return false
    end
    local carrying = false
    pcall(function() carrying = isPlayerCarryingEgg() == true end)
    if carrying then return false end

    if (HUB.StealTeleport and HUB.StealTeleport.active == true)
        or (HUB.StealGlide and HUB.StealGlide.owner == "auto")
        or (type(HUB.SujiRouteState) == "table" and HUB.SujiRouteState.autoRoute == true) then
        pcall(function() HUB.StealTeleport.Cancel() end)
    end

    HUB.AutoStealMovementActive = false
    HUB.StealGlide.speedGuard = false
    pcall(EndEggTravelSpeedWatch)
    pcall(HUB.StopAutoStealNoClip)
    if HUB.StealGlide.owner == "auto" then
        HUB.StealGlide.owner = nil
    end
    -- A route can finish between the carry detector and the next scheduler
    -- tick.  Once no egg is live-carried, discard that old route snapshot so
    -- it cannot keep the central movement controller in the Steal state.
    HUB.SujiRouteState = nil
    if HUB.Orchestrator and HUB.Orchestrator.owner == "steal" then
        HUB.Orchestrator.End("steal")
    end
    if HUB.MovementLease and HUB.MovementLease.owner == "auto-steal" then
        HUB.MovementLease.owner, HUB.MovementLease.depth = nil, 0
        HUB.MovementLease.lastAt = os.clock()
    end

    -- A previous treadmill disable callback may have left this one-shot reset
    -- token set.  It is safe to clear it only when no treadmill handoff is
    -- currently running; the live handoff still owns its own cancellation.
    if autoTreadmillEnabled and not treadmillHandoffBusy then
        treadmillResetRequested = false
    end
    return true
end

HUB.SujiEggPosition = function(record, fallback)
    -- Keep the live Suji XYZ source for every outbound target refresh. This
    -- preserves Position.Y as well as X/Z and supports the game's packed
    -- replica/CFrame fallbacks.
    local position = record and GetFieldEggPosition(record)
    return typeof(position) == "Vector3" and position or fallback
end

-- The reference WARP route starts from a Lake field position before it takes
-- the exact selected target. This is a real starter handshake, not just a
-- visual waypoint: move to Lake, carry the starter, trigger one bounce/guard
-- request, then stash that starter before the selected UID is warped to.
HUB.FindSujiLakeStarter = function()
    local ok, snapshot = pcall(HUB.ReadSujiFieldEggSnapshot, true)
    if not ok or type(snapshot) ~= "table" or type(snapshot.Records) ~= "table" then
        return nil
    end
    local root = findHRP()
    local origin = root and root.Position or Vector3.zero
    local lake, corridor = {}, {}
    for _, item in ipairs(snapshot.Records) do
        if type(item) == "table" then
            local stateName = string.lower(tostring(item.State or item.Status or ""))
            local available = stateName == "slot" or stateName == "dropped" or item.State == 1
            local uid = tostring(item.Uid or "")
            local ignoredUntil = ignoredEggs[uid]
            local position = GetFieldEggPosition(item)
            if available and uid ~= "" and position
                and not (ignoredUntil and os.clock() < ignoredUntil) then
                local area = string.lower(tostring(GetEggAreaId(item) or ""))
                local isLake = area:find("lake", 1, true) ~= nil
                    or uid:lower():find("lake", 1, true) ~= nil
                local distance = Vector3.new(position.X - origin.X, 0, position.Z - origin.Z).Magnitude
                local candidate = { record = item, position = position, distance = distance }
                if isLake then
                    lake[#lake + 1] = candidate
                elseif position.X >= 545 and position.X < 850 then
                    -- Same corridor fallback as function.txt for builds that
                    -- omit AreaId from the live field record.
                    corridor[#corridor + 1] = candidate
                end
            end
        end
    end
    table.sort(lake, function(a, b) return a.distance < b.distance end)
    table.sort(corridor, function(a, b) return a.distance < b.distance end)
    return lake[1] or corridor[1]
end

HUB.CarrySujiLakeStarter = function(record, targetPosition, slotKey, shouldCancel)
    if type(record) ~= "table" or record.Uid == nil then return false end
    for attempt = 1, 20 do
        if shouldCancel and shouldCancel() then return false end
        if HUB.IsExactCarriedEgg(record) then return true end
        pcall(HUB.TryCarryFieldEgg, record.Uid, slotKey)
        local prompt = HUB.FindFieldEggPrompt(record, targetPosition, 10)
        if prompt then
            prompt.HoldDuration = 0
            pcall(function() fireproximityprompt(prompt) end)
        end
        task.wait(attempt <= 4 and 0.08 or 0.14)
    end
    return HUB.IsExactCarriedEgg(record)
end

HUB.TriggerSujiLakeBounce = function(record, shouldCancel)
    if type(record) ~= "table" or record.Uid == nil then return false end
    local strike
    for _, candidate in ipairs({
        eventRemote("GuardPatrol", "ForestStrike", "RF"),
        eventRemote("GuardPatrol", "ForestStrike", "RE"),
        GetNetRemote("RF/GuardPatrol/ForestStrike"),
        GetNetRemote("RE/GuardPatrol/ForestStrike"),
    }) do
        if candidate and typeof(candidate) == "Instance"
            and (candidate:IsA("RemoteFunction") or candidate:IsA("RemoteEvent")) then
            strike = candidate
            break
        end
    end
    if not strike then return false end
    local root = findHRP()
    local humanoid = findHum()
    if not root or not humanoid then return false end
    local baselinePosition = root.Position
    local startedAt = os.clock()
    local sentAgain = false
    local function sendStrike()
        local currentRoot = findHRP()
        if not currentRoot then return false end
        local payload = {
            EggUid = record.Uid,
            GuardCFrame = currentRoot.CFrame * CFrame.new(0, 0, -3),
        }
        local ok = pcall(function()
            if strike:IsA("RemoteFunction") then
                strike:InvokeServer(payload)
            else
                strike:FireServer(payload)
            end
        end)
        return ok
    end
    sendStrike()
    while os.clock() - startedAt < 2.5 and not HUB.dead do
        if shouldCancel and shouldCancel() then return false end
        local currentRoot = findHRP()
        local currentHumanoid = findHum()
        if not currentRoot or not currentHumanoid then return false end
        local delta = currentRoot.Position - baselinePosition
        local velocity = currentRoot.AssemblyLinearVelocity
        local state
        pcall(function() state = currentHumanoid:GetState() end)
        local ragdolled = type(HUB.SujiRagdollLeft) == "function" and HUB.SujiRagdollLeft() > 0
        local bounced = ragdolled
            or state == Enum.HumanoidStateType.Physics
            or state == Enum.HumanoidStateType.Ragdoll
            or state == Enum.HumanoidStateType.FallingDown
            or velocity.Y >= 10
            or (delta.Y >= 1.5 and velocity.Magnitude >= 16)
            or delta.Magnitude >= 2
            or velocity.Magnitude >= 20
        if bounced then return true end
        if not sentAgain and os.clock() - startedAt >= 0.5 then
            sentAgain = true
            sendStrike()
        end
        task.wait(0.05)
    end
    return false
end

HUB.StashSujiStarterTools = function()
    local character = LP.Character
    local backpack = LP:FindFirstChildOfClass("Backpack")
    if not character or not backpack then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then pcall(function() humanoid:UnequipTools() end) end
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Tool") then
            pcall(function() item.Parent = backpack end)
        end
    end
    return true
end

HUB.StageSujiLakeForTeleport = function(routeState)
    if not routeState or routeState.lakeStaged == true then return true end
    local routeCancelled = function()
        return HUB.SujiRouteCancelled(routeState)
    end
    -- Only an explicitly matching live UID may use function.txt's carried
    -- fast path. The old IsExactCarriedEgg fallback accepted any carried egg
    -- when the UID was not replicated, which skipped the Lake reset and sent
    -- the next trip straight to the target.
    local actualUid = type(HUB.GetCarriedEggUid) == "function" and HUB.GetCarriedEggUid() or nil
    local targetUid = routeState.record and tostring(routeState.record.Uid or "") or ""
    local liveCarryVisual = type(HUB.SujiHoldingEggTool) == "function"
        and HUB.SujiHoldingEggTool() == true
    if actualUid ~= nil then
        if tostring(actualUid) == targetUid and targetUid ~= "" and liveCarryVisual then
            routeState.lakePrimed = true
            routeState.lakeStaged = true
            return true
        end
        -- The field replica can keep State=Carried for a few frames after the
        -- Tool/Model has already dropped. Do not let that stale UID bypass the
        -- Lake reset. A different UID blocks only while a live carry visual is
        -- still present.
        if not liveCarryVisual then
            actualUid = nil
        end
        -- A different live carried UID belongs to an unfinished previous
        -- delivery. Never teleport over it or let Rift/Auto Steal overlap.
        if actualUid ~= nil then return false end
    elseif type(HUB.SujiHoldingEggTool) == "function" and HUB.SujiHoldingEggTool() then
        -- A tool without a visible UID is still a live carry. Wait for the
        -- previous route to settle instead of treating it as a fresh target.
        return false
    end
    local starter = HUB.FindSujiLakeStarter()
    if not starter or typeof(starter.position) ~= "Vector3" then
        if _G.AxelWebLog and _G.AxelWebLog.SetActivity then
            pcall(_G.AxelWebLog.SetActivity, "Stealing Egg", "Waiting for Lake starter")
        end
        return false
    end
    local root = findHRP()
    if not root then return false end
    local lakePosition = starter.position + Vector3.new(0, 0.4, 0)
    local distance = Vector3.new(root.Position.X - lakePosition.X, 0, root.Position.Z - lakePosition.Z).Magnitude
    if distance > 8 then
        -- Lake is always a governed tween/glide leg. Teleport is reserved
        -- for the selected outbound target after this handoff completes.
        local moved = HUB.MoveEggRouteGuarded
            and HUB.MoveEggRouteGuarded(lakePosition, HUB.StealGlide.Speed or 600, routeCancelled, 2)
        if not moved then return false end
    end
    local starterRecord = RefreshFieldEggByUid(starter.record.Uid) or starter.record
    routeState.lakeStarterRecord = starterRecord
    -- If the selected target itself is the Lake starter, keep that exact UID
    -- in hand and let the normal target guard leg finish it after the warp.
    if tostring(starterRecord.Uid) ~= tostring(routeState.record and routeState.record.Uid or "") then
        local starterSlotKey
        if AreaEggSlotIdentity and AreaEggSlotIdentity.LooksLikeFirstAreaUid
            and AreaEggSlotIdentity.LooksLikeFirstAreaUid(starterRecord.Uid) then
            starterSlotKey = AreaEggSlotIdentity.SlotKey(GetEggAreaId(starterRecord), starterRecord.NestId)
        end
        if not HUB.CarrySujiLakeStarter(starterRecord, lakePosition, starterSlotKey, routeCancelled) then
            return false
        end
        -- Match function.txt: the starter is used to establish the bounce,
        -- then it is stashed before the exact target leg begins.
        if not HUB.TriggerSujiLakeBounce(starterRecord, routeCancelled) then
            return false
        end
        HUB.StashSujiStarterTools()
        -- Do not start the selected target leg while the starter UID is still
        -- reported as carried. This wait is the reset boundary that was
        -- missing when the second trip teleported directly to its target.
        local releaseDeadline = os.clock() + 1.5
        local starterReleased = false
        while os.clock() < releaseDeadline and not HUB.dead do
            local currentUid = type(HUB.GetCarriedEggUid) == "function" and HUB.GetCarriedEggUid() or nil
            if currentUid == nil
                and (type(HUB.SujiHoldingEggTool) ~= "function" or not HUB.SujiHoldingEggTool()) then
                starterReleased = true
                break
            end
            task.wait(0.06)
        end
        if not starterReleased then return false end
    end
    routeState.lakePrimed = true
    routeState.lakeStaged = true
    return true
end

HUB.SujiCarrying = function(record)
    if record then
        -- Keep the selected UID gate, while allowing the live Character Tool
        -- fallback used by Suji on builds that do not expose Tool UID data.
        return HUB.IsSelectedCarriedEgg(record)
    end
    return isPlayerCarryingEgg()
end

HUB.SujiRouteCancelled = function(expectedState)
    local state = HUB.SujiRouteState
    if not state then return true end
    -- A previous coroutine must not resume against a newly enabled route. The
    -- shared state is replaced on every fresh flow, so identity is the hard
    -- boundary between the old and new Auto Steal runs.
    if expectedState ~= nil and state ~= expectedState then return true end
    if expectedState and expectedState.autoRoute
        and expectedState.controllerEpoch ~= HUB.AutoStealControllerEpoch
        and not carryingEggReturnActive then
        return true
    end
    if HUB.dead then return true end
    if state.autoRoute and autoStealEnabled ~= true and not carryingEggReturnActive then return true end
    if state.riftRoute and not eventState.rift.enabled then return true end
    -- Suji does not perform a synchronous UID refresh on the first movement
    -- frame.  The old Axel check did, and a transient/empty replica made
    -- `RefreshFieldEggByUid` return nil before the glide had taken one step;
    -- that immediately cancelled To() and left the player at the base.
    -- Start the first probe after the same 1.5s grace period and only mark the
    -- egg gone when a valid non-empty snapshot confirms that this UID is no
    -- longer a Slot/Dropped record.  A failed remote call is not evidence that
    -- the selected egg disappeared.
    local now = os.clock()
    if not HUB.IsExactCarriedEgg(state.record) and now >= (state.nextEggCheck or 0) then
        state.nextEggCheck = now + 1.5
        local ok, snapshot = pcall(HUB.ReadSujiFieldEggSnapshot, true)
        if ok and type(snapshot) == "table" and type(snapshot.Records) == "table"
            and #snapshot.Records > 0 then
            local stillAvailable = false
            local uidSeen = false
            local wantedUid = tostring(state.record and state.record.Uid or "")
            for _, item in ipairs(snapshot.Records) do
                if item and tostring(item.Uid or "") == wantedUid then
                    uidSeen = true
                    -- State names vary during the carry handshake.  Only an
                    -- explicit terminal state means the egg is gone; a live
                    -- UID in Carried/Claimed/streaming state must not cancel
                    -- the route before the server exposes the Tool.
                    local stateName = string.lower(tostring(item.State or item.Status or ""))
                    if stateName ~= "removed" and stateName ~= "destroyed"
                        and stateName ~= "consumed" and stateName ~= "expired" then
                        stillAvailable = true
                    end
                    break
                end
            end
            if uidSeen and not stillAvailable then state.eggTaken = true end
        end
    end
    return state.eggTaken == true
end

HUB.SujiCarryPump = function(state)
    while not state.stopCarryPump and not HUB.SujiRouteCancelled(state) do
        local root = findHRP()
        if root and not HUB.IsExactCarriedEgg(state.record) then
            local distance = Vector3.new(root.Position.X - state.targetPos.X, 0, root.Position.Z - state.targetPos.Z).Magnitude
            if distance <= 7.5 then
                local ok = HUB.SujiCarryFieldEgg(state.record.Uid, state.slotKey)
                if ok or HUB.IsExactCarriedEgg(state.record) then
                    state.carryDone = true
                    break
                end
            end
        end
        task.wait(0.05)
    end
end

HUB.SujiCarryFieldEgg = function(uid, slotKey)
    return HUB.TryCarryFieldEgg(uid, slotKey)
end

-- A dropped/rejected egg is a new Suji outbound cycle.  In Teleport mode the
-- target PivotTo is allowed only after the character has returned to the safe
-- center and the Lake starter boundary has been rebuilt.  Keeping this as one
-- helper prevents the carry-retry and final-retry branches from accidentally
-- warping straight from the old/knockback position to the egg.
HUB.RestartSujiTeleportFromSafePosition = function(routeState, targetPos, shouldCancel)
    if stealMovementMethod ~= "Teleport" then return true end
    if shouldCancel and shouldCancel() then return false end

    local owner = HUB.StealGlide and HUB.StealGlide.owner
    if owner ~= "auto" and owner ~= "rift" then
        return false
    end
    if not HUB.StealGlide.WaitAtSafeCenter(HUB.StealGlide.Speed or 600) then
        return false
    end
    if not WaitForEggTravelLanding(3.0) then return false end
    if shouldCancel and shouldCancel() then return false end

    if routeState then
        routeState.lakeStaged = false
        routeState.lakePrimed = false
        routeState.targetPos = targetPos or routeState.targetPos
        local stagedOk, stagedResult = pcall(function()
            return HUB.StageSujiLakeForTeleport(routeState)
        end)
        if not stagedOk or stagedResult ~= true then return false end
    end
    return true
end

HUB.SujiCarryAttempts = function(record, targetPos, slotKey, shouldCancel)
    local lastMessage = "carry rejected"
    for attempt = 1, 16 do
        if shouldCancel and shouldCancel() then return false, "aborted" end
        if HUB.IsExactCarriedEgg(record) then return true end

        local ok, message = HUB.SujiCarryFieldEgg(record.Uid, slotKey)
        if ok or HUB.IsExactCarriedEgg(record) then return true end
        lastMessage = tostring(message or lastMessage)

        -- Suji retries the physical CarryAreaEgg prompt after the UID
        -- handshake.  Some revisions accept the prompt but do not expose the
        -- RemoteFunction/module result; without this fallback Axel treated a
        -- successful guard recovery as a failed carry and returned empty.
        local prompt = HUB.FindFieldEggPrompt(record, targetPos, 10)
        if prompt then
            prompt.HoldDuration = 0
            pcall(function() fireproximityprompt(prompt) end)
            task.wait(0.08)
            if HUB.IsExactCarriedEgg(record) then return true end
        end

        local lowerMessage = string.lower(lastMessage)
        if lowerMessage:find("not found", 1, true) or lowerMessage:find("already carrying", 1, true) then
            break
        end

        if lowerMessage:find("closer", 1, true) or attempt % 3 == 0 then
            local refreshed = RefreshFieldEggByUid(record.Uid)
            if not refreshed then return false, "taken" end
            record = refreshed
            targetPos = HUB.SujiEggPosition(record, targetPos)
            local root = findHRP()
            local movementStillAllowed = type(HUB.CanMovementOwnerProceed) ~= "function"
                or HUB.CanMovementOwnerProceed(HUB.StealGlide and HUB.StealGlide.owner)
            if lowerMessage:find("closer", 1, true) and root and targetPos and movementStillAllowed then
                -- Never correct a rejected carry with a raw CFrame write.  That
                -- old snap was the hidden second teleport: after a dropped
                -- egg, the next carry attempt could jump straight to a stale
                -- position and bypass the Suji route/landing gate.
                local repositioned = false
                if stealMovementMethod == "Teleport"
                    and type(HUB.MoveEggTeleportGuarded) == "function" then
                    -- A dropped egg must restart at Safe Center, then rebuild
                    -- Lake, before the exact target teleport is allowed.
                    local routeState = HUB.SujiRouteState
                    if HUB.RestartSujiTeleportFromSafePosition(routeState, targetPos, shouldCancel) then
                        local refreshedTarget = RefreshFieldEggByUid(record.Uid)
                        if refreshedTarget then
                            record = refreshedTarget
                            targetPos = HUB.SujiEggPosition(refreshedTarget, targetPos)
                            if routeState then
                                routeState.record = refreshedTarget
                                routeState.targetPos = targetPos
                            end
                            repositioned = HUB.MoveEggTeleportGuarded(
                                targetPos,
                                shouldCancel,
                                0.4,
                                1
                            ) == true
                        end
                    end
                elseif type(HUB.MoveEggRouteGuarded) == "function" then
                    repositioned = HUB.MoveEggRouteGuarded(
                        targetPos,
                        HUB.StealGlide.Speed or 600,
                        shouldCancel,
                        1
                    ) == true
                elseif HUB.StealGlide and type(HUB.StealGlide.To) == "function" then
                    repositioned = HUB.StealGlide.To(
                        targetPos,
                        HUB.StealGlide.Speed or 600,
                        shouldCancel
                    ) == true
                end
                if not repositioned and shouldCancel and shouldCancel() then
                    return false, "aborted"
                end
            end
        end
        task.wait(attempt >= 4 and 0.6 or 0.3)
    end
    return false, lastMessage
end

-- Delivery has a different cancellation rule from the outbound scan.  Once an
-- egg was successfully carried, turning Auto Steal/Rift off must not abandon
-- it halfway through the return leg.  Only death or an explicit loss of the
-- return guard may stop the retry loop.
HUB.SujiDeliveryCancelled = function()
    return HUB.dead == true or carryingEggReturnActive ~= true
end

-- Suji re-runs the exact carry handshake when the server rejects the first
-- delivery.  The field record is authoritative when it still exists; if the
-- egg has already replicated into EggInventory, equip that same UID instead of
-- accepting whichever egg happens to be nearest.
HUB.SujiReCarryEgg = function(record, targetPos, slotKey, shouldCancel)
    if type(record) ~= "table" or record.Uid == nil then return false end
    if HUB.IsSelectedCarriedEgg(record) then return true end
    local reCarryCancelled = shouldCancel or HUB.SujiDeliveryCancelled

    local refreshed = RefreshFieldEggByUid(record.Uid)
    if refreshed then
        record = refreshed
        targetPos = HUB.SujiEggPosition(record, targetPos)
        local root = findHRP()
        if typeof(targetPos) == "Vector3" and root
            and (root.Position - targetPos).Magnitude > 8 then
            if _G.AxelWebLog and _G.AxelWebLog.SetActivity then
                pcall(_G.AxelWebLog.SetActivity, "Re-carrying Egg", "Returning to the same selected egg after delivery rejection")
            end
            if HUB.StealGlide.owner == "rift" then
                HUB.StartRiftNoClip()
            else
                HUB.StartAutoStealNoClip()
            end
            -- A re-carry after guard knockback/delivery rejection must begin
            -- from Suji's safe-center XYZ. Going straight from the corrected
            -- knockback position to the egg can cross the treadmill trigger
            -- or reuse a stale route and make the character stand in place.
            local owner = HUB.StealGlide.owner
            if owner == "auto" or owner == "rift" then
                if not HUB.StealGlide.WaitAtSafeCenter(HUB.StealGlide.Speed or 600)
                    or not WaitForEggTravelLanding(3.0) then
                    return false
                end
                local centered = RefreshFieldEggByUid(record.Uid)
                if not centered then return false end
                record = centered
                targetPos = HUB.SujiEggPosition(record, targetPos)
            end
            if stealMovementMethod == "Teleport" and HUB.StealTeleport
                and type(HUB.StealTeleport.To) == "function" then
                -- Re-carry is a new Suji outbound leg, not a direct recovery
                -- teleport.  Re-enter the Lake reset first, refresh the same
                -- UID, then perform one guarded target leg.  Without this
                -- boundary a dropped egg reused the old targetPos and jumped
                -- straight to the egg as soon as the return path failed.
                local previousRouteState = HUB.SujiRouteState
                local recoveryState = previousRouteState
                local installedRecoveryState = false
                if not recoveryState
                    or not recoveryState.record
                    or tostring(recoveryState.record.Uid or "") ~= tostring(record.Uid) then
                    recoveryState = {
                        record = record,
                        targetPos = targetPos,
                        autoRoute = false,
                        riftRoute = false,
                        controllerEpoch = HUB.AutoStealControllerEpoch,
                        lakeStaged = false,
                        lakePrimed = false,
                        nextEggCheck = os.clock() + 1.5,
                    }
                    HUB.SujiRouteState = recoveryState
                    installedRecoveryState = true
                end

                local previousRecord = recoveryState.record
                local previousTargetPos = recoveryState.targetPos
                local previousLakeStaged = recoveryState.lakeStaged
                local previousLakePrimed = recoveryState.lakePrimed
                recoveryState.record = record
                recoveryState.targetPos = targetPos
                -- Force the Lake/reset boundary for this recovery leg even if
                -- the first outbound trip had already staged it.
                recoveryState.lakeStaged = false
                recoveryState.lakePrimed = false

                local stagedOk = false
                local stagedCallOk, stagedResult = pcall(function()
                    return HUB.StageSujiLakeForTeleport(recoveryState)
                end)
                stagedOk = stagedCallOk and stagedResult == true

                local moved = false
                if stagedOk then
                    local refreshedTarget = RefreshFieldEggByUid(record.Uid)
                    if refreshedTarget then
                        record = refreshedTarget
                        targetPos = HUB.SujiEggPosition(refreshedTarget, targetPos)
                        recoveryState.record = record
                        recoveryState.targetPos = targetPos
                        moved = HUB.MoveEggTeleportGuarded(
                            targetPos,
                            reCarryCancelled,
                            0.4,
                            2
                        ) == true
                    end
                end

                -- Restore the caller's route bookkeeping.  The active route
                -- keeps its owner; a standalone recovery must not leave a
                -- synthetic SujiRouteState behind for the scheduler.
                recoveryState.record = previousRecord
                recoveryState.targetPos = previousTargetPos
                recoveryState.lakeStaged = previousLakeStaged
                recoveryState.lakePrimed = previousLakePrimed
                if installedRecoveryState then
                    HUB.SujiRouteState = previousRouteState
                end
                if not moved then return false end
            else
                HUB.StealGlide.To(targetPos, HUB.StealGlide.Speed or 600, HUB.SujiDeliveryCancelled)
            end
        end
        local recarried = HUB.SujiCarryAttempts(record, targetPos, slotKey, HUB.SujiDeliveryCancelled)
        if recarried then return true end
    end

    -- A failed delivery can leave the exact egg in the Backpack while the
    -- field snapshot has already removed its Carried record.  Equip only the
    -- requested UID and wait for the character replica before continuing.
    local save = readSaveTable()
    local _, inventoryEgg = getRiftEggInventoryEntry(save, record.Uid)
    if type(inventoryEgg) == "table" and not inventoryEgg.Placement then
        if equipEggExact(record.Uid) then
            local deadline = os.clock() + 1.5
            while os.clock() < deadline and not reCarryCancelled() do
                if HUB.IsExactCarriedEgg(record) then return true end
                task.wait(0.08)
            end
        end
    end
    return HUB.IsExactCarriedEgg(record)
end

-- Plant and verify the same UID.  A successful remote call is not enough: the
-- save replica can reject/race the request, which was the source of the
-- "delivery failed" loop.  Keep the carried guard active while retrying.
HUB.IsAtLocalPlot = function(maxDistance)
    local center = GetLocalPlotCenter()
    local root = findHRP()
    if typeof(center) ~= "Vector3" or not root then return false end
    local distance = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z).Magnitude
    return distance <= (tonumber(maxDistance) or 32)
end

HUB.SujiPlantDeliveredEgg = function(record)
    for _ = 1, 3 do
        if HUB.dead then return false end
        -- Placement is only legal at the local plot. Repeat the guard on
        -- every retry so a server correction cannot place an egg on the road.
        if not HUB.IsAtLocalPlot(32) then return false end
        if _G.AxelWebLog and _G.AxelWebLog.SetActivity then
            pcall(_G.AxelWebLog.SetActivity, "Delivering Egg", "Placing the selected egg and waiting for server confirmation")
        end

        if not HUB.IsExactCarriedEgg(record) then
            local save = readSaveTable()
            local _, inventoryEgg = getRiftEggInventoryEntry(save, record and record.Uid)
            if type(inventoryEgg) == "table" and riftIsPlacedEgg(inventoryEgg) then return true end
            -- The visual disappeared: the egg may have fallen. Do not place
            -- another equipped egg; the caller must recarry this UID first.
            return false
        end

        -- Place the requested UID only.  A broad Character scan can see a
        -- different carried Tool for one frame after knockback and was the
        -- reason Axel sometimes released/placed the wrong egg near the base.
        -- Suji's exact inventory UID primitive already handles equip/retry.
        local planted = 0
        local directPlaced = select(1, HUB.SujiPlaceEggInPen(record.Uid, true))
        if directPlaced then planted = 1 end
        task.wait(0.18)
        local save = readSaveTable()
        local _, inventoryEgg = getRiftEggInventoryEntry(save, record and record.Uid)
        if type(inventoryEgg) == "table" and riftIsPlacedEgg(inventoryEgg) then
            return true
        end
        task.wait(0.18)
    end
    local save = readSaveTable()
    local _, inventoryEgg = getRiftEggInventoryEntry(save, record and record.Uid)
    return type(inventoryEgg) == "table" and riftIsPlacedEgg(inventoryEgg) == true
end

HUB.SujiReturnCarriedEgg = function(record, shouldCancel, slotKey, targetPos)
    local center = GetLocalPlotCenter()
    if typeof(center) ~= "Vector3" then return false end

    local isPlaced = function()
        local save = readSaveTable()
        local _, inventoryEgg = getRiftEggInventoryEntry(save, record and record.Uid)
        return type(inventoryEgg) == "table" and riftIsPlacedEgg(inventoryEgg) == true
    end
    local nearCenter = function()
        local root = findHRP()
        if not root then return false end
        return Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z).Magnitude <= 32
    end

    -- Keep the return owner through route, plant, and any re-carry.  Suji uses
    -- several short handshakes instead of abandoning the egg after one failed
    -- RequestPlaceEgg/DropHeldEgg replication.
    for attempt = 1, 4 do
        if HUB.dead or (shouldCancel and shouldCancel()) then return false end

        if not HUB.SujiCarrying(record) then
            -- Never plant from the field/road. First check whether the exact
            -- UID was already confirmed in the plot; otherwise recarry that
            -- same UID, like Suji's delivery retry flow.
            if isPlaced() then return true end
            if not HUB.SujiReCarryEgg(record, targetPos, slotKey) then
                task.wait(0.25)
                continue
            end
        end
        if not HUB.SujiCarrying(record) then
            task.wait(0.2)
            continue
        end

        if _G.AxelWebLog and _G.AxelWebLog.SetActivity then
            local detail = attempt == 1 and "Returning to base through Safe Center" or "Retrying carry and delivery"
            pcall(_G.AxelWebLog.SetActivity, "Returning to Base", detail)
        end

        local reached = HUB.ReturnViaSafeCenter(center, HUB.StealGlide.Speed or 600, HUB.SujiDeliveryCancelled)
        if reached then
            local deadline = os.clock() + 2.5
            while os.clock() < deadline and not HUB.dead do
                if (findHRP() and (findHRP().Position - center).Magnitude <= 32)
                    or not HUB.SujiCarrying(record) then
                    break
                end
                task.wait(0.08)
            end
            if nearCenter() and HUB.SujiPlantDeliveredEgg(record) then return true end
        end

        -- If the delivery request raced replication, re-carry the exact UID
        -- and repeat the same safe-center return. Never switch to a lower
        -- priority route while this guard is active.
        if HUB.SujiCarrying(record) then
            task.wait(attempt >= 2 and 0.35 or 0.2)
        else
            local recarried = HUB.SujiReCarryEgg(record, targetPos, slotKey)
            if not recarried then task.wait(0.3) end
        end
    end
    if nearCenter() then
        return HUB.SujiPlantDeliveredEgg(record)
    end
    return isPlaced()
end

-- Suji's guard bypass is a single-hit handshake: carry once, let the guard
-- consume that hit, wait until the Humanoid is standing again, then re-carry
-- the same UID exactly once before starting the return.  The old route could
-- re-carry immediately while the guard was still active, so the second hit
-- removed the egg and the player reached the base empty-handed.
-- Guard recovery must wait for the patrol to return to its idle point before
-- sending the second carry handshake.  A fixed short delay is not reliable
-- after Anti Guard: the first hit can finish its ragdoll while the guard is
-- still alerted, which produces the reported two-hit/drop cycle.
HUB.WaitForSujiGuardSleep = function(record, targetPos)
    -- The Humanoid recovery gate below already proves the ragdoll is over.
    -- Keep only a short guard-idle debounce here; the old 1s minimum made
    -- every successful re-carry feel slow even when the guard was already
    -- back at its EggPoint.
    local minimumAt = os.clock() + 0.45
    local deadline = os.clock() + 2.5
    while os.clock() < deadline and not HUB.dead do
        local asleep = true
        local guardModel
        pcall(function()
            local guardAreas = Workspace:FindFirstChild("__OBJECTS")
                and Workspace.__OBJECTS:FindFirstChild("Areas")
                and Workspace.__OBJECTS.Areas:FindFirstChild("GuardAreas")
            local areaFolder = guardAreas and record and record.AreaId
                and guardAreas:FindFirstChild(tostring(record.AreaId))
            if areaFolder then
                guardModel = areaFolder:FindFirstChild("Guard")
                    or areaFolder:FindFirstChild("ForestGuardAuthored")
                    or areaFolder:FindFirstChildWhichIsA("Model", true)
            end
            if not guardModel and typeof(targetPos) == "Vector3" then
                local nearest, nearestDistance
                for _, model in ipairs(Workspace:GetDescendants()) do
                    if model:IsA("Model") and string.lower(tostring(model.Name or "")):find("guard", 1, true) then
                        local root = model.PrimaryPart
                            or model:FindFirstChild("HumanoidRootPart")
                            or model:FindFirstChildWhichIsA("BasePart", true)
                        if root then
                            local distance = (root.Position - targetPos).Magnitude
                            if distance < 90 and (not nearestDistance or distance < nearestDistance) then
                                nearest, nearestDistance = model, distance
                            end
                        end
                    end
                end
                guardModel = nearest
            end
            if guardModel then
                local alert = guardModel:GetAttribute("Alert")
                    or guardModel:GetAttribute("Alerted")
                    or guardModel:GetAttribute("IsAlerted")
                    or guardModel:GetAttribute("Chasing")
                local sleeping = guardModel:GetAttribute("Sleeping")
                    or guardModel:GetAttribute("IsSleeping")
                    or guardModel:GetAttribute("Asleep")
                    or guardModel:GetAttribute("Sleep")
                local guardHumanoid = guardModel:FindFirstChildOfClass("Humanoid")
                local guardRoot = guardModel.PrimaryPart
                    or guardModel:FindFirstChild("HumanoidRootPart")
                    or guardModel:FindFirstChildWhichIsA("BasePart", true)
                local eggPoint = guardModel:FindFirstChild("EggPoint", true)
                if sleeping == true then
                    asleep = true
                elseif alert == true then
                    asleep = false
                elseif guardHumanoid and guardHumanoid.MoveDirection.Magnitude > 0.12 then
                    asleep = false
                elseif guardRoot and eggPoint and (guardRoot.Position - eggPoint.Position).Magnitude > 12 then
                    asleep = false
                end
            end
        end)
        if asleep and os.clock() >= minimumAt then return true end
        task.wait(0.14)
    end
    -- Never hold the whole controller forever if this map revision has no
    -- exposed guard model; the minimum cooldown still prevents an immediate
    -- second hit.
    return true
end

-- Suji only treats a non-bat Tool as a temporary carry visual.  The field
-- replica/UID remains the authority, so this helper is used only to decide
-- whether the old visual must be dropped before the re-carry handshake.
HUB.SujiHoldingEggTool = function()
    local character = LP.Character
    if character then
        for _, tool in ipairs(character:GetChildren()) do
            if isEggToolForPlacement(tool) then return true end
        end
    end
    -- Suji also accepts the game's live carry predicate for revisions that
    -- represent the carried egg as a Model instead of a Tool.
    if type(isPlayerCarryingEgg) == "function" then
        local ok, carrying = pcall(isPlayerCarryingEgg)
        if ok and carrying == true then return true end
    end
    return false
end

HUB.SujiRagdollLeft = function()
    local endTime = LP:GetAttribute("RagdollEndTime")
    if endTime == nil then return 0 end
    local now = 0
    pcall(function() now = Workspace:GetServerTimeNow() end)
    return tonumber(endTime) and tonumber(endTime) - tonumber(now) or 0
end

-- Suji's guard phase is passive.  The game guard creates the hit/ragdoll;
-- the client must not fabricate a guard-strike request or clear the ragdoll
-- early.  Those two shortcuts were the source of the one-hit-only behaviour
-- and the empty-hand return after a knockback.
-- Humanoid state can report Running one or two frames before the guard's
-- knockback impulse has finished. Suji waits for a short stable window rather
-- than trusting one state read; this prevents the second carry handshake from
-- being sent while the character is still ragdolled.
HUB.WaitForSujiHumanoidRecovery = function(minimumAt, timeout)
    local deadline = os.clock() + (tonumber(timeout) or 3.5)
    local stable = 0
    local notBefore = tonumber(minimumAt) or 0
    while os.clock() < deadline and not HUB.dead do
        local hum = findHum()
        local root = findHRP()
        local state
        local ragdollLeft = HUB.SujiRagdollLeft()
        pcall(function() state = hum and hum:GetState() end)
        local airborne = state == Enum.HumanoidStateType.Jumping
            or state == Enum.HumanoidStateType.Freefall
            or state == Enum.HumanoidStateType.FallingDown
            or state == Enum.HumanoidStateType.Ragdoll
            or state == Enum.HumanoidStateType.Physics
            or state == Enum.HumanoidStateType.GettingUp
        local velocity = root and root.AssemblyLinearVelocity or Vector3.zero
        local ready = hum ~= nil and root ~= nil
            and hum.PlatformStand ~= true
            and not airborne
            and math.abs(velocity.Y) <= 14
            and Vector3.new(velocity.X, 0, velocity.Z).Magnitude <= 24
            and (LP:GetAttribute("RagdollEndTime") == nil or ragdollLeft <= -0.7)
        if ready and os.clock() >= notBefore then
            stable += 1
            if stable >= 4 then
                pcall(function()
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    hum.Jump = false
                    hum:Move(Vector3.zero, false)
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end)
                return true
            end
        else
            stable = 0
        end
        task.wait(0.06)
    end
    return false
end

HUB.SujiGuardHitOnce = function(record, targetPos, slotKey, carryAcknowledged)
    if type(record) ~= "table" or record.Uid == nil then return false end
    local wantedUid = tostring(record.Uid)
    local selectedEggCarried = function()
        -- The live field replica can confirm the exact UID before the visual
        -- Tool is parented to Character.  Check that authoritative signal
        -- first; requiring a Tool before it caused the guard phase to be
        -- skipped and the route to return immediately after the first grab.
        if HUB.IsExactCarriedEgg(record) then return true end
        -- A stale field replica can say Carried for a few frames after the
        -- guard has already removed the Tool.  The live Character Tool is the
        -- first gate, otherwise the route can incorrectly start returning.
        if not HUB.SujiHoldingEggTool() then return false end
        -- Suji uses the live Character Tool while the field CarrierUserId is
        -- being replicated.  After the exact UID carry request succeeded, a
        -- generic egg Tool is valid evidence when the build exposes no Tool
        -- UID; do not mistake that short replica gap for a guard hit.
        local carriedUid = HUB.GetCarriedEggUid()
        if carriedUid ~= nil then return tostring(carriedUid) == wantedUid end
        return true
    end
    if not selectedEggCarried() then
        -- The carry remote can acknowledge the UID before the Character
        -- Tool/CarrierUserId is replicated. Do not treat that frame as a
        -- failed carry and immediately enter the return leg; wait for the
        -- same UID to become visible first, like Suji's carry confirmation.
        if carryAcknowledged ~= true then return false, "carry-not-acknowledged" end
        local carryDeadline = os.clock() + 1.5
        while os.clock() < carryDeadline and not HUB.dead do
            if selectedEggCarried() then break end
            task.wait(0.06)
        end
        -- Never send a return movement from an acknowledgement alone. If the
        -- exact egg never appears, the caller will retry that UID instead of
        -- returning empty-handed.
        if not selectedEggCarried() then return false, "carry-not-visible" end
    end

    -- The standalone Anti-Ragdoll toggle is a normal player utility, but it
    -- must not interrupt Suji's one real guard-hit window.  Pause only for
    -- this guarded egg phase and restore the user's setting on every exit.
    local antiRagdollWasEnabled = antiRagdollEnabled
    antiRagdollEnabled = false
    local function restoreAntiRagdoll()
        antiRagdollEnabled = antiRagdollWasEnabled
    end

    -- Do not let the outbound speed watcher issue another jump while the
    -- character is being knocked down and re-carried.  Suji treats this as a
    -- separate guarded recovery phase.
    if HUB.StealGlide then HUB.StealGlide.speedGuard = false end
    pcall(EndEggTravelSpeedWatch)

    -- Match Suji: stay beside the selected egg and observe the real guard
    -- hit.  Do not call a guessed strike remote.  The field Tool disappearing
    -- is also a valid hit signal because the server drops it during the same
    -- knockback transaction.
    local hum = findHum()
    local startHealth = hum and tonumber(hum.Health) or 100
    local oldRagdollEnd = LP:GetAttribute("RagdollEndTime")
    local hit = false
    local watchUntil = os.clock() + 4.0
    while not hit and os.clock() < watchUntil and not HUB.dead do
        if not selectedEggCarried() then
            -- A missing field CarrierUserId can be a short replication gap;
            -- Suji does not call that a guard hit while the egg Tool is still
            -- attached.  Count it as a hit only when the selected UID is
            -- actually gone/replaced, so the route cannot re-arm ragdoll from
            -- a transient telemetry read.
            hit = true
            break
        end
        local ragdollEnd = LP:GetAttribute("RagdollEndTime")
        local ragdollLeft = HUB.SujiRagdollLeft()
        if ragdollLeft > 0 or (oldRagdollEnd ~= nil
            and ragdollEnd ~= oldRagdollEnd and ragdollLeft > -0.7) then
            hit = true
            break
        end
        hum = findHum()
        local state
        local health = startHealth
        pcall(function()
            state = hum and hum:GetState()
            health = hum and tonumber(hum.Health) or startHealth
        end)
        if health < startHealth - 1.5
            or state == Enum.HumanoidStateType.Physics
            or state == Enum.HumanoidStateType.Ragdoll
            or state == Enum.HumanoidStateType.FallingDown then
            hit = true
            break
        end
        task.wait(0.05)
    end

    if not hit then
        -- A guard is not present in every area/build. If the exact carry is
        -- still live after the same bounded Suji observation window, it is safe
        -- to deliver it; only a missing carry is a failed route. This avoids
        -- the old grab->release->return path while preserving normal areas
        -- where no guard hit is generated.
        restoreAntiRagdoll()
        if selectedEggCarried() then return true, "no-hit" end
        return false, "no-hit-carry-lost"
    end

    -- This is the Suji knockback boundary. Never move or clear ragdoll before
    -- the server has finished it. If the live timer exists, use it as the
    -- clock instead of adding a fixed 0.65s delay; the recovery gate below
    -- still refuses to re-carry until the Humanoid is fully standing.
    local ragdollLeftNow = HUB.SujiRagdollLeft()
    if ragdollLeftNow > 0 then
        task.wait(math.min(math.max(ragdollLeftNow + 0.06, 0.12), 0.4))
    else
        task.wait(0.12)
    end
    -- Some revisions report Humanoid.Running before the server ragdoll timer
    -- expires.  Wait for that timer as well as the Humanoid state; otherwise
    -- the re-carry handshake can be sent while the guard is still attacking.
    local ragdollAttribute = LP:GetAttribute("RagdollEndTime")
    if ragdollAttribute ~= nil and HUB.SujiRagdollLeft() > -0.7 then
        local ragdollDeadline = os.clock() + 3.5
        while os.clock() < ragdollDeadline and not HUB.dead do
            if HUB.SujiRagdollLeft() <= -0.7 then break end
            task.wait(0.05)
        end
        if HUB.dead or HUB.SujiRagdollLeft() > -0.7 then
            restoreAntiRagdoll()
            return false
        end
    end

    -- Match Suji's explicit Humanoid reset.  Waiting for FloorMaterial alone
    -- is not enough: a guard can leave the Humanoid in Physics while the root
    -- is already over the floor, which made Axel skip re-carry and return.
    local standDeadline = os.clock() + 3.2
    while os.clock() < standDeadline and not HUB.dead do
        local currentHumanoid = findHum()
        local currentState
        pcall(function() currentState = currentHumanoid and currentHumanoid:GetState() end)
        if currentState ~= Enum.HumanoidStateType.Physics
            and currentState ~= Enum.HumanoidStateType.Ragdoll
            and currentState ~= Enum.HumanoidStateType.FallingDown then
            break
        end
        pcall(function()
            currentHumanoid.PlatformStand = false
            currentHumanoid.AutoRotate = true
            currentHumanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
        task.wait(0.12)
    end
    -- Do not use FloorMaterial as the only reset gate.  Auto Steal no-clip
    -- can legitimately report Air while the character is standing; wait for
    -- the Humanoid state, ragdoll timer, and velocity to be stable together.
    local recovered = HUB.WaitForSujiHumanoidRecovery(os.clock() + 0.15, 3.8)
    if not recovered then
        restoreAntiRagdoll()
        return false, "humanoid-not-recovered"
    end
    task.wait(0.05)
    pcall(HUB.StealGlide.StabilizeAfterGuardHit)
    if HUB.dead then
        restoreAntiRagdoll()
        return false
    end
    pcall(HUB.WaitForSujiGuardSleep, record, targetPos)
    if HUB.dead then
        restoreAntiRagdoll()
        return false
    end

    -- If the server did not remove the old visual during ragdoll, drop it only
    -- after the guard is idle.  This keeps the same one-hit Suji handshake and
    -- prevents an immediate second hit during the ragdoll window.
    if selectedEggCarried() then
        pcall(HUB.DropHeldEgg)
        local dropDeadline = os.clock() + 1.0
        while os.clock() < dropDeadline and not HUB.dead do
            if not selectedEggCarried() then break end
            task.wait(0.05)
        end
    end
    if HUB.dead then
        restoreAntiRagdoll()
        return false
    end

    -- Re-read the same UID after the drop. Suji uses the refreshed dropped
    -- position for the next carry handshake; retrying against the first scan's
    -- coordinate is what made Axel request the carry while still out of range.
    local refreshed = RefreshFieldEggByUid(record.Uid)
    if refreshed then
        record = refreshed
        targetPos = HUB.SujiEggPosition(refreshed, targetPos)
    end
    local root = findHRP()
    if root and typeof(targetPos) == "Vector3"
        and Vector3.new(root.Position.X - targetPos.X, 0, root.Position.Z - targetPos.Z).Magnitude > 8 then
        -- The guard-hit recovery is also a fresh outbound leg.  Do not call
        -- StealTeleport.To here: that bypassed Safe Center/Lake staging and
        -- was the exact "egg dropped -> instantly warp back" bug.  Re-enter
        -- the same selected-UID flow and let its movement guard own the leg.
        local recoveryCancelled = function()
            return HUB.dead == true or HUB.SujiRagdollLeft() > 0
        end
        local recarried = false
        local recarryOk, recarryResult = pcall(function()
            return HUB.SujiReCarryEgg(record, targetPos, slotKey, recoveryCancelled)
        end)
        recarried = recarryOk and recarryResult == true
        if not recarried then
            restoreAntiRagdoll()
            return false, "recarry-failed"
        end
    end

    -- Re-carry the exact UID only after the ragdoll boundary and refreshed
    -- position are valid.  Suji's retry helper refreshes the live record and
    -- repositions only when the server says the request is too far away.
    local recarried = select(1, HUB.SujiCarryAttempts(record, targetPos, slotKey, function()
        return HUB.dead == true or HUB.SujiRagdollLeft() > 0
    end))
    local confirmDeadline = os.clock() + 0.8
    while os.clock() < confirmDeadline and not HUB.dead do
        if selectedEggCarried() then break end
        task.wait(0.05)
    end
    restoreAntiRagdoll()
    if recarried == true and selectedEggCarried() then
        return true, "recarried"
    end
    return false, "recarry-failed"
end

HUB.SujiStealEgg = function(targetItem)
    local record = targetItem and (targetItem.record or targetItem)
    if type(record) ~= "table" or record.Uid == nil then return false end
    local autoRoute = targetItem._axelAutoStealTarget == true
    local riftRoute = targetItem._axelRiftSource == true
    local manualRoute = targetItem._axelManualRoute == true
    if not autoRoute and not riftRoute and not manualRoute then return false end
    -- The field route is single-owner.  A second Rift/Auto Steal caller must
    -- wait for the current trip to clear its state instead of teleporting into
    -- the same target while the first route is carrying/returning.
    if HUB.SujiRouteState ~= nil then return false end
    -- The normal Auto Steal route is strictly opt-in. A stale queued target
    -- must not continue following the selected rarity/area after the toggle
    -- is turned off; Rift/manual callers have their own explicit ownership.
    if autoRoute and autoStealEnabled ~= true then return false end
    if autoRoute and not HUB.IsAutoStealResumeReady() then return false end
    if autoRoute and HUB.Orchestrator and not HUB.Orchestrator.Allows("steal") then return false end
    if (autoRoute or manualRoute) and not HUB.IsSelectedAutoStealRecordAllowed(record) then return false end

    -- Discord notification means the egg was actually accepted by the carry
    -- handshake.  Do not wait for the later return/plant phase: a guard hit,
    -- placement retry, or plot replication delay must not hide a successful
    -- theft from the notification channel.
    local webhookNotified = false
    local function notifyEggCollected()
        if webhookNotified or not (autoRoute or manualRoute) then return end
        if type(HUB.SendEggStolenWebhook) ~= "function" then return end
        webhookNotified = true
        task.spawn(function()
            local callOk, sent, detail = pcall(HUB.SendEggStolenWebhook, targetItem)
            if not callOk then
                warn("[Axel Discord Webhook] Send error: " .. tostring(sent))
            elseif sent ~= true then
                warn("[Axel Discord Webhook] Send skipped/failed: " .. tostring(detail or sent))
            end
        end)
    end

    local previousOwner = HUB.StealGlide.owner
    local previousReturning = carryingEggReturnActive
    local function stopRouteNoClip()
        if riftRoute then
            pcall(HUB.StopRiftNoClip)
        elseif autoRoute then
            pcall(HUB.StopAutoStealNoClip)
        end
    end
    HUB.StealGlide.owner = riftRoute and "rift" or (manualRoute and "manual" or "auto")
    local routeState = {
        record = record,
        startedAt = os.clock(),
        autoRoute = autoRoute,
        riftRoute = riftRoute,
        controllerEpoch = HUB.AutoStealControllerEpoch,
        eggTaken = false,
        -- Give the first glide the same grace period as Suji's `func40`.
        -- Checking the field snapshot before the first step can cancel a
        -- perfectly valid target when the remote replica is one frame behind.
        nextEggCheck = os.clock() + 1.5,
        targetPos = nil,
        slotKey = nil,
        lakeStaged = false,
        carryDone = false,
        stopCarryPump = false,
    }
    HUB.SujiRouteState = routeState
    local routeCancelled = function()
        return HUB.SujiRouteCancelled(routeState)
    end

    -- Every aborted trip must release the same movement resources as a
    -- completed trip. Previously some early returns cleared only the route
    -- snapshot, leaving Rift/Auto Steal no-clip or its temporary owner alive;
    -- the next scheduler pass could then skip the safe-center/Lake reset.
    local function abortEggRoute()
        routeState.stopCarryPump = true
        carryingEggReturnActive = previousReturning
        HUB.AutoStealMovementActive = false
        HUB.SujiRouteState = nil
        HUB.StealGlide.owner = previousOwner
        stopRouteNoClip()
    end

    local targetPos = HUB.SujiEggPosition(record)
    if typeof(targetPos) ~= "Vector3" then
        abortEggRoute()
        return false
    end
    routeState.targetPos = targetPos

    -- Suji releases a previous treadmill owner before claiming the egg and
    -- never starts a glide while the dismount jump is still airborne.
    if type(ReleaseTreadmillForAction) == "function" then
        ReleaseTreadmillForAction()
    end
    if not WaitForEggTravelLanding(3.0) then
        abortEggRoute()
        return false
    end

    if AreaEggSlotIdentity and AreaEggSlotIdentity.LooksLikeFirstAreaUid
        and AreaEggSlotIdentity.LooksLikeFirstAreaUid(record.Uid) then
        routeState.slotKey = AreaEggSlotIdentity.SlotKey(GetEggAreaId(record), record.NestId)
    end

    HUB.AutoStealMovementActive = true
    if riftRoute then
        HUB.StartRiftNoClip()
    else
        HUB.StartAutoStealNoClip()
    end
    -- Match Suji's start handoff: one movement owner first travels to the
    -- configured safe-center XYZ, then the egg record is read again. Starting
    -- the carry pump before this handoff allowed it to race Treadmill/Rift
    -- movement and made the character jump in place or use an old target.
    pcall(EndEggTravelSpeedWatch)
    if not HUB.StealGlide.WaitAtSafeCenter(HUB.StealGlide.Speed or 600) then
        abortEggRoute()
        return false
    end
    task.wait(0.12)

    -- Rebind the selected UID after reaching the start XYZ. This prevents a
    -- refresh during the center handoff from sending the route to stale
    -- coordinates or silently selecting a different egg.
    record = RefreshFieldEggByUid(record.Uid)
    if record then
        routeState.record = record
        targetPos = HUB.SujiEggPosition(record, targetPos)
        routeState.targetPos = targetPos
    else
        abortEggRoute()
        return false
    end

    if _G.AxelWebLog and _G.AxelWebLog.SetActivity then
        pcall(_G.AxelWebLog.SetActivity, riftRoute and "The Rift" or "Stealing Egg", "Suji route: moving to the selected egg")
    end

    -- Refresh the same UID and retry from the corrected position. Teleport mode
    -- follows the reference WARP leg: one exact destination PivotTo per
    -- attempt, never a per-frame follow of the egg's changing position.
    local useTeleportTravel = stealMovementMethod == "Teleport"
        and HUB.StealTeleport and type(HUB.StealTeleport.To) == "function"
    local function restartTeleportTravelFlow()
        if not useTeleportTravel then return true end
        -- A failed/airborne teleport is a new outbound leg.  Reset the
        -- Suji Lake boundary before the next target movement; otherwise the
        -- retry would use the old targetPos directly and look like a random
        -- warp when the first travel attempt was corrected by the server.
        routeState.lakeStaged = false
        routeState.lakePrimed = false
        local ok, staged = pcall(function()
            return HUB.StageSujiLakeForTeleport(routeState)
        end)
        return ok and staged == true
    end
    -- Both Auto Steal and Rift field sourcing use one serialized WARP flow.
    -- The Lake starter is fully released before the selected quest/steal UID
    -- is allowed to enter the target leg.
    if useTeleportTravel and not restartTeleportTravelFlow() then
        abortEggRoute()
        return false
    end

    task.spawn(HUB.SujiCarryPump, routeState)

    local moved = false
    for attempt = 1, 3 do
        -- Refresh the same UID before each retry.  The field stream can move
        -- an egg's Position/AreaId after the first scan; Suji follows the
        -- refreshed record instead of gliding toward the old coordinates.
        local refreshedBeforeMove = RefreshFieldEggByUid(record.Uid)
        if refreshedBeforeMove then
            record = refreshedBeforeMove
            routeState.record = refreshedBeforeMove
            targetPos = HUB.SujiEggPosition(refreshedBeforeMove, targetPos)
            routeState.targetPos = targetPos
        end
        local stepMoved
        if useTeleportTravel then
            stepMoved = HUB.MoveEggTeleportGuarded(
                targetPos,
                routeCancelled,
                0.4,
                2
            )
        elseif HUB.MoveEggRouteGuarded then
            stepMoved = HUB.MoveEggRouteGuarded(
                targetPos,
                HUB.StealGlide.Speed or 600,
                routeCancelled,
                2
            )
        else
            stepMoved = HUB.StealGlide.To(targetPos, HUB.StealGlide.Speed or 600, routeCancelled)
        end
        if stepMoved == true then
            moved = true
            break
        elseif attempt < 3 then
            -- If the outbound leg was corrected/interrupted, restart from
            -- Suji's safe-center XYZ instead of sending the next retry from
            -- the old knockback or treadmill-path position.
            if not HUB.StealGlide.WaitAtSafeCenter(HUB.StealGlide.Speed or 600) then break end
            if not WaitForEggTravelLanding(3.0) then break end
            local retryRecord = RefreshFieldEggByUid(record.Uid)
            if not retryRecord then break end
            record = retryRecord
            routeState.record = retryRecord
            targetPos = HUB.SujiEggPosition(retryRecord, targetPos)
            routeState.targetPos = targetPos
            if useTeleportTravel and not restartTeleportTravelFlow() then break end
            task.wait(0.15)
        end
    end
    if not moved and not routeState.carryDone and not routeCancelled() then
        if useTeleportTravel then
            -- The final retry is still a new Suji cycle. Return to Safe
            -- Center first, wait for the landing handoff, rebuild Lake, then
            -- allow one exact target teleport. Never send a last-second warp
            -- from the interrupted/knockback position.
            if HUB.RestartSujiTeleportFromSafePosition(routeState, targetPos, routeCancelled) then
                local refreshedFinal = RefreshFieldEggByUid(record.Uid)
                if refreshedFinal then
                    record = refreshedFinal
                    routeState.record = refreshedFinal
                    targetPos = HUB.SujiEggPosition(refreshedFinal, targetPos)
                    routeState.targetPos = targetPos
                    moved = HUB.MoveEggTeleportGuarded(
                        targetPos,
                        routeCancelled,
                        0.4,
                        2
                    ) == true
                end
            end
        else
            -- Match Suji's short pin-glide recovery after a blocked/streaming
            -- segment. It keeps the same target UID and uses governed movement.
            local pinTarget = targetPos + Vector3.new(0, 3, 0)
            local pinOk = HUB.StealGlide.PinGlide(pinTarget, HUB.StealGlide.Speed or 600, routeCancelled)
            local pinRoot = findHRP()
            moved = pinOk == true or (pinRoot and Vector3.new(pinRoot.Position.X - targetPos.X, 0, pinRoot.Position.Z - targetPos.Z).Magnitude <= 12)
        end
    end
    routeState.stopCarryPump = true
    task.wait(0.05)
    pcall(EndEggTravelSpeedWatch)

    -- A failed route is recoverable on the next scan. Teleport mode has no
    -- Heartbeat follow loop and no extra last-second CFrame correction.
    if not moved and not routeState.carryDone then
        ignoredEggs[record.Uid] = os.clock() + 4
        abortEggRoute()
        return false
    end

    -- Suji performs a final close approach before the retry handshake. The
    -- WARP leg is already at the exact target, so do not issue a second CFrame
    -- correction that could fight the carry handshake.
    local root = findHRP()
    if not useTeleportTravel and root and (root.Position - targetPos).Magnitude > 4.5 and not routeState.carryDone then
        HUB.StealGlide.SnapNearXYZ(targetPos, 2.5, 12)
    end

    -- Match Suji's carry/guard handshake.  The server acknowledgement is the
    -- first carry gate; then wait for the live Tool when the build exposes one,
    -- let the guard consume exactly one hit, wait for Humanoid recovery, and
    -- re-carry the same UID before any return movement is allowed.
    local carryAcknowledged = routeState.carryDone == true
    local carried = HUB.IsSelectedCarriedEgg(record)
    if not carried and carryAcknowledged then
        local carryDeadline = os.clock() + 1.5
        while os.clock() < carryDeadline and not HUB.dead do
            if HUB.IsSelectedCarriedEgg(record) then
                carried = true
                break
            end
            task.wait(0.08)
        end
        -- Some game revisions acknowledge the UID before exposing a Tool or
        -- carrier field. Keep Suji's server-ack fallback, but only after the
        -- replication window above; SujiReturnCarriedEgg will still refuse to
        -- place anything unless the same UID becomes carryable.
        if not carried then carried = carryAcknowledged end
    end
    if not carried and moved then
        carried = select(1, HUB.SujiCarryAttempts(record, targetPos, routeState.slotKey, routeCancelled))
    end
    local guardRetryAfterCarryReplication = false
    if carried and type(HUB.SujiGuardHitOnce) == "function" then
        -- Do not gate the guard phase on the field CarrierUserId alone.  Suji
        -- starts the one-hit wait as soon as the carry handshake is accepted;
        -- the Tool/replica can appear a frame later.  The guard helper still
        -- refuses to proceed without live carry evidence.
        local guardHandled, guardReason = HUB.SujiGuardHitOnce(record, targetPos, routeState.slotKey, carryAcknowledged)
        if not guardHandled then
            carried = false
            -- If only replication lag prevented the first guard observation,
            -- recarry the same UID and run the guard wait again. Do not repeat
            -- the guard phase after a real hit/recovery failure: that would
            -- invite a second guard hit instead of following Suji's one-hit
            -- boundary.
            guardRetryAfterCarryReplication = guardReason == "carry-not-visible"
                or guardReason == "carry-not-acknowledged"
        end
    end
    -- After the guard hit the field replica may briefly remove the Tool.  The
    -- guard helper normally re-carries it, but keep the same UID retry here as
    -- the final delivery gate; never substitute a nearby egg.
    if not carried and (moved or carryAcknowledged) then
        for recovery = 1, 2 do
            if HUB.dead then break end
            local recarried = HUB.SujiReCarryEgg(record, targetPos, routeState.slotKey)
            if recarried and HUB.IsSelectedCarriedEgg(record) then
                carried = true
                break
            end
            task.wait(recovery == 1 and 0.25 or 0.45)
        end
    end
    if carried and guardRetryAfterCarryReplication
        and type(HUB.SujiGuardHitOnce) == "function" then
        local guardHandled = HUB.SujiGuardHitOnce(record, targetPos, routeState.slotKey, true)
        if not guardHandled then carried = false end
    end
    if not carried then
        ignoredEggs[record.Uid] = os.clock() + 12
        abortEggRoute()
        return false
    end

    -- This is the authoritative "stolen" point.  The selected UID has been
    -- accepted/carried; send once before starting the independent return and
    -- placement flow.
    notifyEggCollected()

    carryingEggReturnActive = true
    HUB.AutoStealMovementActive = true
    if _G.AxelWebLog and _G.AxelWebLog.SetActivity then
        pcall(_G.AxelWebLog.SetActivity, "Returning to Base", "Suji route: carrying the selected egg")
    end
    -- Outbound cancellation must not abort delivery: Suji keeps the return
    -- guard alive even if the user toggles the source route off mid-carry.
    local returned = HUB.SujiReturnCarriedEgg(record, nil, routeState.slotKey, routeState.targetPos)
    if returned then
        -- SujiReturnCarriedEgg already owns the exact placement handshake.
        -- Do not run a second broad "plant all" pass here: after a guard hit it
        -- can observe another Character Tool and release the wrong egg near the
        -- base. Verify the selected UID only, and retry only that UID while the
        -- character is still inside the local plot.
        local exactPlaced = false
        for _ = 1, 3 do
            local save = readSaveTable()
            local _, placedEgg = getRiftEggInventoryEntry(save, record.Uid)
            if type(placedEgg) == "table" and riftIsPlacedEgg(placedEgg) then
                exactPlaced = true
                break
            end
            if HUB.IsAtLocalPlot(32) then
                exactPlaced = select(1, HUB.SujiPlaceEggInPen(record.Uid, true)) == true
                if exactPlaced then break end
            end
            task.wait(0.18)
        end
        if not exactPlaced then returned = false end
        task.wait(0.15)
        if _G.AxelWebLog and _G.AxelWebLog.SetActivity then
            pcall(_G.AxelWebLog.SetActivity, "Egg Delivered", "Returned to base and planted the selected egg")
        end
    elseif HUB.IsAtLocalPlot(32) then
        -- If the return handshake reached the plot but placement replication
        -- raced, make one exact-UID placement attempt instead of ending with a
        -- carried egg/no-op state.
        local exactPlaced = select(1, HUB.SujiPlaceEggInPen(record.Uid, true))
        if exactPlaced then returned = true end
    end

    -- A delivery rejection must stay in the same Suji return flow.  Retry the
    -- exact UID before releasing the route; otherwise the next scheduler tick
    -- can start Treadmill/Rift while this egg is still attached and leave the
    -- player standing at the base with no delivery.
    if not returned and HUB.SujiCarrying(record) then
        for _ = 1, 2 do
            if HUB.dead then break end
            task.wait(0.25)
            returned = HUB.SujiReturnCarriedEgg(record, nil, routeState.slotKey, routeState.targetPos)
            if returned then break end
        end
    end

    carryingEggReturnActive = previousReturning
    HUB.AutoStealMovementActive = false
    HUB.SujiRouteState = nil
    HUB.StealGlide.owner = previousOwner
    stopRouteNoClip()
    local exactStillCarrying = false
    pcall(function() exactStillCarrying = HUB.SujiCarrying(record) == true end)
    if not exactStillCarrying and not carryingEggReturnActive
        and HUB.Orchestrator and HUB.Orchestrator.owner == "steal" then
        HUB.Orchestrator.End("steal")
    end
    if autoRoute and autoTreadmillEnabled then QueueAutoTreadmillResume() end
    return returned
end


-- One authoritative egg route.  Every automatic field-egg pickup, including
-- Rift sourcing, enters the same Suji sequence: Safe Center -> exact egg UID
-- -> carry retry -> Safe Center -> local Plot -> exact placement confirmation.
StealSpecificEggRobust = function(targetItem, allowManual)
    if type(HUB.SujiStealEgg) ~= "function" then return false end
    return HUB.SujiStealEgg(targetItem) == true
end

-- Keep the steal webhook sender outside the large UI/config closure below.
-- Defining it inside that closure made Luau allocate the closure together
-- with too many captured locals and caused: "Out of local registers".
HUB.SendEggStolenWebhook = function(targetItem)
    local runtime = HUB.WebhookRuntime
    if not runtime then return false, "webhook runtime is not ready" end
    local record = targetItem and (targetItem.record or targetItem)
    if type(record) ~= "table" then return false, "missing egg record" end

    local animalOn, rarityOn, eggOn, countOn = runtime.GetNotificationFlags()
    if not animalOn and not rarityOn and not eggOn and not countOn then
        return false, "all notifications disabled"
    end

    local count = runtime.NextStealCount()
    local rarity, score = runtime.GetTargetRarity(record)
    local animalName = runtime.GetTargetAnimalName(record)
    local mutationText = runtime.GetTargetMutationText(record)
    local eggName = runtime.GetAssetDisplayName(record.AssetCategory or record.EggName or record.Name)
    local emoji = runtime.Emoji
    local fields = {}

    if animalOn then
        table.insert(fields, { name = "[" .. emoji.Animal .. "] Animal", value = tostring(animalName), inline = true })
    end
    if eggOn then
        table.insert(fields, { name = "[" .. emoji.Egg .. "] Egg", value = tostring(eggName), inline = true })
    end
    if rarityOn then
        table.insert(fields, { name = "[" .. emoji.Rarity .. "] Rarity", value = tostring(rarity), inline = true })
        table.insert(fields, { name = "[" .. emoji.Score .. "] Score", value = tostring(math.floor(score)), inline = true })
    end

    table.insert(fields, { name = "[" .. emoji.Mutation .. "] Mutation", value = mutationText, inline = true })
    table.insert(fields, { name = "[" .. emoji.Area .. "] Area", value = tostring(GetEggAreaId(record) or "Unknown"), inline = true })
    if countOn then
        table.insert(fields, { name = "[" .. emoji.Count .. "] Stolen Count", value = tostring(count), inline = true })
    end
    table.insert(fields, { name = "[" .. emoji.Discord .. "] Discord", value = "discord.gg/axelhub", inline = false })

    return runtime.Post(runtime.Build("AXEL HUB", "", fields, runtime.GetRarityColor(rarity)))
end

HUB.StealBestEggOnceBody = function(allowManual, _legacyMovementIgnored, preselectedTarget)
    -- Auto Steal must be an explicit toggle. The treadmill fallback used to
    -- call this helper without the toggle, which caused unexpected stealing.
    if allowManual ~= true and autoStealEnabled ~= true then
        return false
    end
    -- Auto Hatch is an independent worker. Do not force-hatch from Auto Steal.
    if autoHatchEnabled then
        pcall(HatchAllReadyEggs)
    end
    if _G.AxelWebLog and _G.AxelWebLog.SetActivity then pcall(_G.AxelWebLog.SetActivity, "Searching for Egg", "Finding the best matching egg") end
    -- The priority worker may already have selected a target using the live
    -- Suji snapshot. Reuse that exact record instead of scanning a second
    -- time, otherwise a one-frame replica change can make the route abort or
    -- select a different rarity/area than the checkbox the user chose.
    local eggs = preselectedTarget and { preselectedTarget }
        or GetMatchingFieldEggs(selectedStealAreas, selectedStealRarities, selectedMutationTypes)
    if #eggs == 0 then
        HUB.ReleaseAutoStealForFallback()
        -- A missing rarity arms the optional rarity hop. If Auto Boss Rift
        -- owns this server, TriggerHopOnNoMatch keeps it queued until the
        -- boss is defeated and the configured delay has elapsed.
        if autoTreadmillEnabled then
            treadmillLastNoMatchAt = os.clock()
            if _G.AxelWebLog and _G.AxelWebLog.SetActivity then
                pcall(_G.AxelWebLog.SetActivity, "Scanning for Egg", "No matching rarity; Auto Treadmill fallback")
            end
        elseif _G.AxelWebLog and _G.AxelWebLog.SetActivity then
            pcall(_G.AxelWebLog.SetActivity, "Searching for Egg", "No matching rarity; Auto Server Hop may search")
        end
        -- A manual one-shot must never arm the automatic rarity hop.  The
        -- automatic worker still goes through the central explicit-toggle
        -- guard, so this call cannot hop merely because a scan is empty.
        if allowManual ~= true then
            HUB.TriggerHopOnNoMatch()
        end
        return false
    end

    local target = eggs[1]
    -- Mark the route so the Suji handoff can enforce the exact selected
    -- filters at the final carry handshake. Rift quest candidates remain
    -- unmarked.
    target._axelAutoStealTarget = allowManual ~= true
    target._axelManualRoute = allowManual == true
    -- Use the same complete Suji-compatible route as the reference flow after
    -- target selection: safe-center staging, grounded speed-rise recovery,
    -- exact UID refresh, guard-hit re-carry, safe-center return, and planting.
    -- This is intentionally the normal Auto Steal path; the small direct
    -- Suji helper is reserved for callers that explicitly use it.
    target._axelUseSujiEggRoute = true
    local hopState = HUB.ServerHopState
    if hopState then
        HUB.ClearNoMatchHopState()
        hopState.MatchFound = true
    end
    if _G.AxelWebLog and _G.AxelWebLog.SetActivity then
        local targetRecord = target and (target.record or target)
        local area = targetRecord and GetEggAreaId(targetRecord) or "Unknown Area"
        pcall(_G.AxelWebLog.SetActivity, "Stealing Egg", "Moving to " .. tostring(area))
        if type(_G.AxelWebLog.SetArea) == "function" then pcall(_G.AxelWebLog.SetArea, area) end
    end
    local success = StealSpecificEggRobust(target, allowManual == true)

    if success and _G.AxelWebLog and type(_G.AxelWebLog.AddEggStolen) == "function" then pcall(_G.AxelWebLog.AddEggStolen, 1) end

    if success and _G.AxelWebLog and type(_G.AxelWebLog.SetLastStolenEgg) == "function" then pcall(_G.AxelWebLog.SetLastStolenEgg, target.record or target) end

    return success
end

-- Manual buttons, delayed treadmill callbacks, and the priority worker all use
-- the same entry point.  A direct manual click cannot interrupt an automatic
-- carry/return leg, while the treadmill handoff is allowed to call the body as
-- a nested step under its own lease.
HUB.StealBestEggOnce = function(allowManual, _legacyMovementIgnored, preselectedTarget)
    local lease = HUB.MovementLease
    local nested = allowManual ~= true
        and lease
        and (lease.owner == "priority" or (lease.owner == "treadmill" and _legacyMovementIgnored == true))
    local acquired = false
    if not nested then
        if not HUB.AcquireMovementLease("auto-steal") then return false end
        acquired = true
    end
    local ok, result = pcall(HUB.StealBestEggOnceBody, allowManual, _legacyMovementIgnored, preselectedTarget)
    if acquired then HUB.ReleaseMovementLease("auto-steal") end
    return ok and result == true
end

-- ==============================================================================
-- AUTO TREADMILL -> EGG HANDOFF
-- ==============================================================================
HUB.GetTreadmillStandPosition = function()
    local treadmill = FindTreadmillPart()
    if not treadmill then return nil end
    return treadmill.Position + Vector3.new(0, 4, 0)
end

-- Keep this as a table method instead of a local function in the main chunk.
-- The executor's Luau compiler can otherwise count the large treadmill handoff
-- closure as one function and fail with "Out of local registers".
HUB.IsDoubleSpeedVisible = function()
    local playerGui = LP:FindFirstChild("PlayerGui")
    if not playerGui then
        return false
    end

    local doubleSpeed = nil
    local elements = playerGui:FindFirstChild("Elements")
    local left = elements and elements:FindFirstChild("Left")
    local tools = left and left:FindFirstChild("Tools")
    if tools then
        doubleSpeed = tools:FindFirstChild("DoubleYourSpeed")
    end
    if doubleSpeed and doubleSpeed.Visible == true then
        return true
    end
    -- Some game revisions place the same indicator below a nested Tools
    -- container.  Keep the direct path fast, then search only the player's
    -- GUI for the exact indicator name.
    local visible = false
    pcall(function()
        for _, item in ipairs(playerGui:GetDescendants()) do
            if item.Name == "DoubleYourSpeed" and item:IsA("GuiObject") and item.Visible == true then
                visible = true
                break
            end
        end
    end)
    return visible
end

-- Live speed confirmation for the treadmill handoff.  The Web Log snapshot
-- is intentionally too slow to use as the only mount signal, so combine the
-- same live speed sources used by the activity reporter with the UI marker.
HUB.ReadTreadmillSpeedState = function()
    local state = {}
    pcall(function()
        local sample = GetEggTravelSpeedSample()
        if type(sample) == "table" then
            for _, key in ipairs({"walkSpeed", "playerSpeed", "characterSpeed", "saveSpeed"}) do
                state[key] = tonumber(sample[key])
            end
        end
    end)
    local webState = HUB.WebLogSpeedState
    if type(webState) == "table" then
        state.webSpeed = tonumber(webState.current or webState.last)
    end
    return state
end

HUB.TreadmillSpeedRose = function(before, after)
    if type(before) ~= "table" or type(after) ~= "table" then return false end
    local thresholds = {
        walkSpeed = 0.5,
        playerSpeed = 0.5,
        characterSpeed = 0.5,
        saveSpeed = 0.1,
        webSpeed = 0.1,
    }
    for key, threshold in pairs(thresholds) do
        local oldValue = tonumber(before[key])
        local newValue = tonumber(after[key])
        if oldValue ~= nil and newValue ~= nil and newValue > oldValue + threshold then
            return true
        end
    end
    return false
end

HUB.WaitForTreadmillSpeedRise = function(before, timeout)
    local deadline = os.clock() + (tonumber(timeout) or 1.8)
    while os.clock() < deadline and not HUB.dead do
        if HUB.IsDoubleSpeedVisible() then return true end
        local after = HUB.ReadTreadmillSpeedState()
        if HUB.TreadmillSpeedRose(before, after) then return true end
        task.wait(0.06)
    end
    return false
end

-- Keep the dismount helper on HUB as well. Some executors count local helper
-- functions declared near the large treadmill controller against one 200-local
-- limit even when the helper itself is small.
HUB.DismountTreadmill = function()
    local input = game:GetService("VirtualInputManager")
    pcall(input.SendKeyEvent, input, true, Enum.KeyCode.Space, false, game)
    task.wait(0.05)
    pcall(input.SendKeyEvent, input, false, Enum.KeyCode.Space, false, game)
    local humanoid = findHum()
    if humanoid then
        humanoid.Jump = true
        pcall(humanoid.ChangeState, humanoid, Enum.HumanoidStateType.Jumping)
    end
end

HUB.StopTreadmillTraining = function()
    if _G.AxelWebLog and _G.AxelWebLog.SetActivity then pcall(_G.AxelWebLog.SetActivity, "Leaving Treadmill", "Resetting movement state") end
    local wasMounted = HUB.TreadmillMounted == true or treadmillTrainingActive == true
    treadmillTrainingActive = false
    HUB.TreadmillMounted = false
    HUB.TreadmillMountedAt = 0

    -- A disabled toggle/config restore can call this cleanup even though the
    -- player never mounted a treadmill. Sending Space in that case is the
    -- reported jump-in-place bug. Only issue the game's unequip/jump handshake
    -- when this controller actually confirmed a mount.
    if not wasMounted then
        if HUB.MovementLease and HUB.MovementLease.owner == "treadmill"
            and not treadmillHandoffBusy then
            HUB.ReleaseMovementLease("treadmill")
        end
        return false
    end

    -- Unequip first, then perform one jump so the character is no longer
    -- treated as mounted. Do not use the DoubleYourSpeed UI as a loop
    -- condition: that indicator can remain visible after dismounting.
    pcall(function()
        -- Suji uses RequestUnequip.  Keep the older AskDoff name only as a
        -- compatibility fallback; using the wrong remote makes the next
        -- Auto Treadmill handoff silently fail after Auto Steal is disabled.
        local names = {
            "RF/Treadmills/RequestUnequip",
            "RF/Treadmill/RequestUnequip",
            "RF/Treadmill/AskDoff",
        }
        for _, name in ipairs(names) do
            local rf = GetNetRemote(name)
            if rf then
                local ok = pcall(function() rf:InvokeServer() end)
                if ok then break end
            end
        end
    end)

    HUB.DismountTreadmill()
    task.wait(0.12)

    -- Give the character one final state reset before travelling to an egg.
    local h = findHum()
    if h then
        h.Jump = false
        pcall(function() h:ChangeState(Enum.HumanoidStateType.Running) end)
    end
end

-- AskWearStill is normally enough, but the networking tree has had two
-- treadmill path names across game revisions. Keep the lookup/retry here so
-- the main handoff does not fail silently when the first remote is not ready.
HUB.WearTreadmill = function()
    local names = {
        "RF/Treadmill/AskWearStill",
        "RF/Treadmills/AskWearStill",
        "RF/Treadmills/RequestEquipStatic",
        "RF/Treadmill/RequestEquipStatic",
        "RF/Treadmill/RequestWear",
    }
    for _, name in ipairs(names) do
        local rf = GetNetRemote(name)
        if rf then
            local ok, result = pcall(function()
                return rf:InvokeServer()
            end)
            -- Suji treats AskWearStill as a fire-and-confirm request: some
            -- game revisions return false/nil even though the server accepted
            -- the mount. Static/RequestWear remotes still use false as a real
            -- rejection, so continue to the compatibility fallback for them.
            if ok and (result ~= false or string.find(name, "AskWearStill", 1, true)) then
                return true
            end
        end
    end
    return false
end

-- Higher-priority actions (egg pickup, Rift sourcing, and Boss entry) must
-- release a previous treadmill mount before they start moving.  This is kept
-- separate from the Auto Treadmill toggle so a later re-enable can arm a
-- fresh session without inheriting the old mounted state.
ReleaseTreadmillForAction = function()
    -- `DoubleYourSpeed` is a telemetry/UI indicator on some builds and can
    -- stay visible after leaving the treadmill. It is not proof that the
    -- character is mounted. Using it here made every Auto Steal retry call
    -- DismountTreadmill(), which pressed Space and caused jumping in place.
    if not treadmillTrainingActive and HUB.TreadmillMounted ~= true then
        -- The training helper normally releases this lease itself.  If it was
        -- interrupted between the wear/confirm calls, release only its own
        -- orphaned lease so Auto Steal can acquire the priority controller.
        if HUB.MovementLease and HUB.MovementLease.owner == "treadmill"
            and not treadmillHandoffBusy then
            HUB.ReleaseMovementLease("treadmill")
        end
        return true
    end
    HUB.StopTreadmillTraining()
    treadmillTrainingActive = false
    if HUB.MovementLease and HUB.MovementLease.owner == "treadmill"
        and not treadmillHandoffBusy then
        HUB.ReleaseMovementLease("treadmill")
    end
    task.wait(0.12)
    return true
end

HUB.RunAutoTreadmillTraining = function(controllerEpoch)
    -- This function may be called by HandleAutoTreadmillHandoff while
    -- treadmillHandoffBusy is already true. Do not reject that internal call.
    if IsRiftBossPriorityActive() then
        ReleaseTreadmillForAction()
        return false
    end
    if not autoTreadmillEnabled or treadmillResetRequested or carryingEggReturnActive or isPlayerCarryingEgg() then
        return false
    end
    if controllerEpoch and controllerEpoch ~= treadmillControllerEpoch then
        return false
    end

    -- A cancelled Auto Steal route can leave only its movement flag/lease
    -- behind.  Reconcile it before the lower-priority treadmill controller
    -- takes over; this is also safe when the user toggles Auto Steal off while
    -- the central worker is between two movement frames.
    if autoStealEnabled ~= true and not carryingEggReturnActive then
        HUB.ReconcileAutoStealForTreadmill()
    end

    -- Never mount the treadmill while a matching target is currently
    -- available.  Do not even call the egg scanner when Auto Steal is off:
    -- its filter tables can be nil during the first UI frame, and an error
    -- there used to abort the whole treadmill handoff.
    local matching = {}
    if autoStealEnabled == true then
        local scanOk, scanResult = pcall(GetMatchingFieldEggs, selectedStealAreas, selectedStealRarities, selectedMutationTypes)
        if not scanOk then return false end
        matching = type(scanResult) == "table" and scanResult or {}
        if #matching > 0 then return false end
        -- Do not mount while the live field replica is still rebuilding. A
        -- transient empty response is not a confirmed no-match; waiting one
        -- short scan window prevents the treadmill dismount/remount bounce.
        if type(HUB.IsFieldEggSnapshotSettling) == "function"
            and HUB.IsFieldEggSnapshotSettling() then
            return false
        end
        if type(HUB.IsAutoStealNoMatchSettled) == "function"
            and not HUB.IsAutoStealNoMatchSettled() then
            return false
        end
    end

    local pos = HUB.GetTreadmillStandPosition()
    local root = findHRP()
    if not pos or not root then
        return false
    end

    if _G.AxelWebLog and _G.AxelWebLog.SetActivity then
        pcall(_G.AxelWebLog.SetActivity, "Scanning for Egg", "No matching rarity; returning to Auto Treadmill")
    end

    if (root.Position - pos).Magnitude > 12 then
        local reached = TravelToDestination(pos, math.min(glideSpeed, 300), true)
        if not reached then
            -- A plot can be registered before its road-entry route is
            -- available. Finish the short final leg directly instead of
            -- retrying the same road planner forever.
            local current = findHRP()
            local directTarget = current and Vector3.new(pos.X, current.Position.Y, pos.Z) or pos
            reached = MoveToPoint(directTarget, math.min(glideSpeed, 300), true, nil, 8, true)
        end
        if not reached then return false end
        task.wait(0.08)
        if not autoTreadmillEnabled or treadmillResetRequested then
            return false
        end
        if controllerEpoch and controllerEpoch ~= treadmillControllerEpoch then
            return false
        end
    end

    -- Re-check after travelling: an egg may have spawned while we were moving.
    if autoStealEnabled == true then
        local scanOk, scanResult = pcall(GetMatchingFieldEggs, selectedStealAreas, selectedStealRarities, selectedMutationTypes)
        if not scanOk then return false end
        matching = type(scanResult) == "table" and scanResult or {}
        if #matching > 0 then return false end
    end

    -- AskWearStill can return successfully before the treadmill state is
    -- replicated. Use the speed/UI signal as telemetry when it is available,
    -- but do not treat a missing marker as a failed mount: some revisions do
    -- not expose DoubleYourSpeed or publish Speed until a later server tick.
    -- The remote response is the authoritative action acknowledgement, just
    -- as in Suji's original flow.
    for attempt = 1, 3 do
        local baseline = HUB.ReadTreadmillSpeedState()
        local armed = HUB.WearTreadmill()
        HUB.TreadmillMounted = armed == true
        local speedConfirmed = false
        if armed then
            speedConfirmed = HUB.WaitForTreadmillSpeedRise(baseline, 0.30) == true
        end
        if armed then
            treadmillTrainingActive = true
            HUB.TreadmillMounted = true
            HUB.TreadmillMountedAt = os.clock()
            if _G.AxelWebLog and _G.AxelWebLog.SetActivity then
                local detail = speedConfirmed
                    and "Speed increased; treadmill entry confirmed"
                    or "Treadmill entry accepted; waiting for live speed telemetry"
                pcall(_G.AxelWebLog.SetActivity, "Training on Treadmill", detail)
            end
            return true
        end

        treadmillTrainingActive = false
        HUB.TreadmillMounted = false
        if attempt < 3 then
            WaitForEggTravelLanding(2.0)
            task.wait(0.12)
            local retryRoot = findHRP()
            if retryRoot and (retryRoot.Position - pos).Magnitude > 12 then
                local retryTarget = Vector3.new(pos.X, retryRoot.Position.Y, pos.Z)
                local retryMoved = MoveToPoint(retryTarget, math.min(glideSpeed, 300), true, nil, 8, true)
                if not retryMoved then break end
            end
        end
    end
    return false
end

function GetMatchingEggCount()
    if autoStealEnabled ~= true then return 0 end
    local ok, eggs = pcall(GetMatchingFieldEggs, selectedStealAreas, selectedStealRarities, selectedMutationTypes)
    if not ok or type(eggs) ~= "table" then
        return 0
    end
    return #eggs
end

function IsAutoTreadmillHandoffCurrent(controllerEpoch)
    return autoTreadmillEnabled
        and not treadmillResetRequested
        and controllerEpoch == treadmillControllerEpoch
end

-- Keep the matching-egg branch separate from the no-match branch. The old
-- all-in-one closure captured enough top-level locals to exceed Luau's 200
-- local-register limit during compilation.
function RunAutoTreadmillMatchHandoff(controllerEpoch)
    local hopState = HUB.ServerHopState
    if hopState then
        HUB.ClearNoMatchHopState()
        hopState.MatchFound = true
    end
    if not IsAutoTreadmillHandoffCurrent(controllerEpoch) then
        return false
    end
    if treadmillTrainingActive then
        HUB.StopTreadmillTraining()
        task.wait(0.12)
    end

    if not IsAutoTreadmillHandoffCurrent(controllerEpoch) then
        return false
    end
    -- Treadmill handoff keeps the legacy movement route; only the explicit
    -- Auto Steal worker uses the Suji-style direct XYZ glide.
    local stolen = HUB.StealBestEggOnce(false, true)
    treadmillLastNoMatchAt = 0
    return stolen == true
end

function RunAutoTreadmillNoMatchHandoff(controllerEpoch)
    if not IsAutoTreadmillHandoffCurrent(controllerEpoch) then
        return false
    end
    if autoStealEnabled == true
        and type(HUB.IsAutoStealNoMatchSettled) == "function"
        and not HUB.IsAutoStealNoMatchSettled() then
        return false
    end
    treadmillLastNoMatchAt = os.clock()

    HUB.TriggerHopOnNoMatch()

    -- A stale UI mount indicator or a lost server state must not wedge
    -- the controller after toggling Auto Treadmill off and on again.
    local stand = HUB.GetTreadmillStandPosition()
    local root = findHRP()
    if treadmillTrainingActive and stand and root and (root.Position - stand).Magnitude > 18 then
        treadmillTrainingActive = false
    end
    -- Do not use the DoubleYourSpeed UI as the mount authority. It is absent
    -- on some revisions and can remain visible for a few frames after a
    -- dismount. The confirmed wear request plus the local treadmill position
    -- is the stable Suji-style state; higher-priority routes explicitly call
    -- ReleaseTreadmillForAction when they need the treadmill released.
    if not treadmillTrainingActive then
        return HUB.RunAutoTreadmillTraining(controllerEpoch)
    end

    return true
end

function RunAutoTreadmillHandoffBody(controllerEpoch)
    if not IsAutoTreadmillHandoffCurrent(controllerEpoch) or isPlayerCarryingEgg() then
        return false
    end

    -- State 1: matching egg exists -> treadmill OFF -> grab/return -> rescan.
    local matches = {}
    if autoStealEnabled == true then
        local scanOk, scanResult = pcall(GetMatchingFieldEggs, selectedStealAreas, selectedStealRarities, selectedMutationTypes)
        if not scanOk then return false end
        matches = type(scanResult) == "table" and scanResult or {}
    end
    if autoStealEnabled == true and #matches > 0 then
        return RunAutoTreadmillMatchHandoff(controllerEpoch)
    end

    -- State 2: nothing matches -> treadmill ON.
    return RunAutoTreadmillNoMatchHandoff(controllerEpoch)
end

function HandleAutoTreadmillHandoff()
    -- Auto Treadmill is also a standalone mode. Repair an orphaned Auto
    -- Steal owner before checking Orchestrator permissions so disabling the
    -- steal toggle immediately gives the treadmill its movement slot.
    if autoStealEnabled ~= true and not carryingEggReturnActive then
        HUB.ReconcileAutoStealForTreadmill()
    end
    if HUB.Orchestrator and not HUB.Orchestrator.Allows("treadmill") then
        return false
    end
    if IsRiftBossPriorityActive() then
        if treadmillTrainingActive or HUB.IsDoubleSpeedVisible() then
            ReleaseTreadmillForAction()
        end
        return false
    end
    if type(HUB.IsRiftMovementActive) == "function" and HUB.IsRiftMovementActive() then
        return false
    end
    if not autoTreadmillEnabled or treadmillHandoffBusy or HUB.dead or carryingEggReturnActive then
        return false
    end

    local lease = HUB.MovementLease
    local nested = lease and lease.owner == "priority"
    local acquired = false
    if not nested then
        if not HUB.AcquireMovementLease("treadmill") then return false end
        acquired = true
    end

    local controllerEpoch = treadmillControllerEpoch
    treadmillResetRequested = false
    treadmillHandoffBusy = true
    HUB.TreadmillHandoffAt = os.clock()
    local ok, result = pcall(RunAutoTreadmillHandoffBody, controllerEpoch)
    treadmillHandoffBusy = false
    HUB.TreadmillHandoffAt = 0
    if acquired then HUB.ReleaseMovementLease("treadmill") end
    if not autoTreadmillEnabled then
        treadmillTrainingActive = false
        treadmillLastNoMatchAt = 0
    end
    return ok and result or false
end

-- Re-arm Auto Treadmill after a higher-priority route completes. The token
-- prevents overlapping callbacks from restarting movement with stale state.
function QueueAutoTreadmillResume()
    if not autoTreadmillEnabled or HUB.dead then return false end
    local resume = HUB.TreadmillResumeState or { token = 0 }
    HUB.TreadmillResumeState = resume
    resume.token = (tonumber(resume.token) or 0) + 1
    local token = resume.token
    task.spawn(function()
        task.wait(0.08)
        if HUB.dead or token ~= resume.token or not autoTreadmillEnabled then return end
        if autoStealEnabled ~= true and not carryingEggReturnActive then
            pcall(HUB.ReconcileAutoStealForTreadmill)
        end
        -- A toggle handoff must not wait behind an owner that has already
        -- finished.  Release only stale Steal/Rift ownership; live Boss/Rift
        -- movement remains higher priority and is intentionally respected.
        if HUB.Orchestrator then
            local owner = HUB.Orchestrator.owner
            if owner == "steal" and not autoStealEnabled and not carryingEggReturnActive and not HUB.SujiRouteState then
                HUB.Orchestrator.End("steal")
            elseif owner == "rift"
                and type(HUB.IsRiftMovementActive) == "function"
                and not HUB.IsRiftMovementActive() then
                HUB.Orchestrator.End("rift")
            end
            if not HUB.Orchestrator.Allows("treadmill") then return end
        end
        if HUB.MovementLease and HUB.MovementLease.owner == "auto-steal"
            and not carryingEggReturnActive and not HUB.SujiRouteState then
            HUB.MovementLease.owner, HUB.MovementLease.depth = nil, 0
            HUB.MovementLease.lastAt = os.clock()
        end
        if carryingEggReturnActive or isPlayerCarryingEgg() or IsRiftBossPriorityActive() then return end
        if HUB.MovementLease and HUB.MovementLease.owner ~= nil then return end
        if type(HUB.IsRiftMovementActive) == "function" and HUB.IsRiftMovementActive() then return end
        treadmillResetRequested = false
        treadmillLastNoMatchAt = 0
        if type(HandleAutoTreadmillHandoff) == "function" then
            pcall(HandleAutoTreadmillHandoff)
        end
    end)
    return true
end

function HatchAllReadyEggs()
    if _G.AxelWebLog and _G.AxelWebLog.SetActivity then _G.AxelWebLog.SetActivity("Hatching Eggs", "Checking ready eggs") end
    -- Adapted from the Ready-Egg flow, but uses this hub's existing UI state
    -- (`autoHatchEnabled`) instead of the other UI's H.isOn()/flag system.
    if not autoHatchEnabled or HUB.dead then
        return 0
    end

    -- Use the same live save reader as the Rift route.  SaveModule.Get can
    -- briefly return nil during a map/plot refresh; the shared reader keeps
    -- the worker alive and lets the next pass see the new inventory.
    local save = readSaveTable()
    local eggInventory = save.EggInventory
    if type(eggInventory) ~= "table" then
        return 0
    end

    local hatchedAny = 0
    local attempted = {}

    for inventoryKey, egg in pairs(eggInventory) do
        if HUB.dead or not autoHatchEnabled then
            break
        end

        -- Inventory replicas use string keys, numeric keys, or store the
        -- authoritative UID inside the egg record.  Never skip a placed egg
        -- merely because the table key changed after a refresh.
        if type(egg) == "table" and riftIsPlacedEgg(egg) then
            local uid = egg.Uid or egg.UID or egg.EggUid or egg.EggUID
                or egg.AssetUid or egg.AssetUID or inventoryKey
            local uidKey = tostring(uid or "")
            if uidKey ~= "" and not attempted[uidKey] and riftEggReady(uid, egg) then
                attempted[uidKey] = true
                local ok, result = pcall(riftHatchPlacedEgg, uid, egg)
                if ok and result == true then
                    hatchedAny += 1
                    task.wait(0.35)
                elseif not ok then
                    HUB.ReportAutomationError("Auto Hatch", result)
                end
            end
        end
    end

    return hatchedAny
end

-- ==============================================================================
-- BASE, HOMESTEAD & REWARDS AUTOMATION LOGIC
-- ==============================================================================
function GetCurrentSave()
    local save = nil
    pcall(function()
        if SaveModule and type(SaveModule.Get) == "function" then
            save = SaveModule.Get()
        end
    end)
    return type(save) == "table" and save or nil
end

function UpgradeHomesteadBase()
    -- Match the game's upgrade route: nearby plot purchase first, then the
    -- homestead tier raise. The server remains the source of truth for money
    -- and the next available tier.
    local requested = false
    local re1 = GetNetRemote("RE/Homestead/AskNearbyPurchase")
    if re1 then
        local ok = pcall(function()
            if re1:IsA("RemoteFunction") then re1:InvokeServer() else re1:FireServer() end
        end)
        requested = ok or requested
    end

    local re2 = GetNetRemote("RE/Homestead/AskBaseTierRaise")
        or GetNetRemote("RE/Plots/RequestBaseUpgrade")
        or GetNetRemote("RE/Plots/REQUEST_BASE_UPGRADE")
    if re2 then
        local ok = pcall(function()
            if re2:IsA("RemoteFunction") then re2:InvokeServer() else re2:FireServer() end
        end)
        requested = ok or requested
    end
    return requested == true
end

function UpgradeTreadmillTier()
    local rf = GetNetRemote("RF/Treadmill/AskTierRaise")
        or GetNetRemote("RF/Treadmills/REQUEST_UPGRADE")
        or GetNetRemote("RF/Treadmills/RequestUpgrade")
    if not rf then return false end

    -- The game sends the tier raise without a client-computed tier/id. This also
    -- works when the live upgrade table has changed between game versions.
    local ok = pcall(function()
        if rf:IsA("RemoteFunction") then rf:InvokeServer() else rf:FireServer() end
    end)
    return ok == true
end

function HUB.EquipBestPets()
    local rf = GetNetRemote("RF/Haul/WearBest") or GetNetRemote("RF/PenRoster/ConfirmEquipBestBadge")
    if rf then pcall(function() rf:InvokeServer() end) end
end

function HUB.GetMyMonsterPosition()
    local myMonster = Workspace:FindFirstChild("MonsterParasiteMonsters") and Workspace.MonsterParasiteMonsters:FindFirstChild("Monster_" .. LP.UserId)
    if myMonster then
        local pos = (myMonster.PrimaryPart and myMonster.PrimaryPart.Position) or myMonster:GetPivot().Position
        return pos
    end
    local standPad = Workspace:FindFirstChild("Stands") and Workspace.Stands:FindFirstChild("Pads") and Workspace.Stands.Pads:FindFirstChild("Monster")
    if standPad then return standPad.Position end
    return Vector3.new(545.1, 68.0, -413.4)
end

function HUB.ClaimMonsterChests()
    pcall(function()
        local rf1 = GetNetRemote("RF/MonsterParasite/AskChestClaim")
        if rf1 then rf1:InvokeServer() end
        local rf2 = GetNetRemote("RF/MonsterParasite/AskChestTake")
        if rf2 then rf2:InvokeServer() end
    end)
end

function HUB.FeedMonsterParasite()
    if type(HUB.CanMovementOwnerProceed) == "function"
        and not HUB.CanMovementOwnerProceed("monster") then
        return false
    end
    local rf = GetNetRemote("RF/MonsterParasite/AskFeed")
    if not rf then return false end

    local hrp = findHRP()
    if not hrp then return false end

    local mPos = HUB.GetMyMonsterPosition()
    local dist = (hrp.Position - mPos).Magnitude
    local savedSpot = nil

    if dist > 12 then
        savedSpot = hrp.CFrame
        TravelToDestination(mPos + Vector3.new(0, 1.2, 0), glideSpeed or 200, true)
        task.wait(0.08)
    end

    local ok, res = pcall(function() return rf:InvokeServer() end)

    if savedSpot then
        task.wait(0.1)
        TravelToDestination(savedSpot.Position, glideSpeed or 200, true)
        local h = findHRP()
        if h and (type(HUB.CanMovementOwnerProceed) ~= "function"
            or HUB.CanMovementOwnerProceed("monster")) then
            h.CFrame = savedSpot
        end
    end

    return ok and res
end

function HUB.DropHeldEgg()
    -- Keep the exact Tool reference before the server drop.  Suji clears the
    -- client-side DropFieldEgg visual as well as the replicated carry state;
    -- otherwise a ragdoll can leave a ghost egg attached to Character and the
    -- next carry request is rejected as "already carrying".
    local character = LP.Character
    local oldTool = character and character:FindFirstChildOfClass("Tool")
    if oldTool and oldTool:GetAttribute("IsBat") == true then oldTool = nil end
    local rf = GetNetRemote("RF/EggWorld/AskFieldEggDrop")
    if rf then pcall(function() rf:InvokeServer() end) end
    -- Suji passes an explicit nil payload to the client DropFieldEgg
    -- primitive. Calling the function with no argument can be ignored by the
    -- newer module and leaves the old egg Tool attached through ragdoll.
    if EggState and EggState.DropFieldEgg then
        pcall(function() EggState.DropFieldEgg(nil) end)
    end
    local deadline = os.clock() + 0.4
    while os.clock() < deadline and not HUB.dead do
        if not HUB.GetCarriedEggUid() and not HUB.SujiHoldingEggTool() then break end
        task.wait(0.05)
    end
    if oldTool and oldTool.Parent == character
        and not HUB.GetCarriedEggUid() then
        pcall(function() oldTool:Destroy() end)
    end
end

function HUB.BuyAffordableTrails()
    local rf = GetNetRemote("RF/Trailwear/AskPurchase")
    local TrailsData = RS:FindFirstChild("Data") and RS.Data:FindFirstChild("Trails") and require(RS.Data.Trails)
    local save = nil
    pcall(function() save = SaveModule and SaveModule.Get and SaveModule.Get() end)
    if not rf or not TrailsData or not save then return false end

    local myMoney = tonumber(save.Money) or tonumber(save.Cash) or tonumber(save.Coins) or 0
    local inv = type(save.TrailInventory) == "table" and save.TrailInventory or {}

    -- Pick one best affordable trail per pass.  The previous unordered loop
    -- could request several items with a stale balance and often missed the
    -- actual best trail because the directory key is the id on some builds.
    local bestId, bestScore, bestPrice
    for key, t in pairs(TrailsData.Directory or TrailsData) do
        if type(t) == "table" then
            local id = t._id or t.Id or t.id or key
            local owned = inv[id] ~= nil and inv[id] ~= false
            if not owned then
                for _, ownedItem in pairs(inv) do
                    if type(ownedItem) == "table"
                        and tostring(ownedItem._id or ownedItem.Id or ownedItem.id or "") == tostring(id) then
                        owned = true
                        break
                    end
                end
            end
            local price = tonumber(t.Price or t.Cost or t.CashPrice)
            if id and not owned and price and price <= myMoney then
                local score = tonumber(t.Speed or t.SpeedMultiplier or t.Multiplier
                    or t.WalkSpeed or t.Boost or t.Value or t.Tier or t.Order) or price
                if not bestId or score > bestScore or (score == bestScore and price > bestPrice) then
                    bestId, bestScore, bestPrice = id, score, price
                end
            end
        end
    end

    if not bestId then return false end
    local ok, result = pcall(function()
        if rf:IsA("RemoteFunction") then
            return rf:InvokeServer(bestId)
        end
        rf:FireServer(bestId)
        return true
    end)
    return ok and result ~= false
end

function HUB.SetNoKnockback(enabled)
    noKnockbackEnabled = enabled
    if enabled then
        pcall(function()
            local rigSync = GetNetRemote("RE/RigSync/Refresh")
            if rigSync and getconnections then
                for _, conn in ipairs(getconnections(rigSync.OnClientEvent)) do
                    pcall(function() conn:Disconnect() end)
                end
            end
        end)
    end
end

-- Auto-enable defensive features by default (user request)
pcall(function() if avoidTrapsEnabled then NeutralizeTraps() end end)
pcall(function() if noKnockbackEnabled then HUB.SetNoKnockback(true) end end)

function HUB.SellInventoryBatch(uids)
    if type(uids) ~= "table" or #uids == 0 then return false end
    local rf = GetNetRemote("RF/PetSatchel/SellInventory")
        or GetNetRemote("RF/SellService/SellInventory")
        or eventRemote("SellService", "SellInventory", "RF")
        or eventRemote("PetSatchel", "SellInventory", "RF")
    if not rf or not rf:IsA("RemoteFunction") then return false end
    local ok, result = pcall(function() return rf:InvokeServer(uids) end)
    return ok and result ~= false
end

-- Current builds use one combined selection remote for pets and eggs.
-- Prefer that protocol before the older one-item/batch fallbacks.
function HUB.SellInventorySelection(eggUids, assetUids)
    eggUids = type(eggUids) == "table" and eggUids or {}
    assetUids = type(assetUids) == "table" and assetUids or {}
    if #eggUids == 0 and #assetUids == 0 then return false end
    local re = GetNetRemote("RE/AssetInventory/SellSelection")
        or eventRemote("AssetInventory", "SellSelection", "RE")
    if not re or not re:IsA("RemoteEvent") then return false end
    local ok = pcall(function()
        re:FireServer({ Assets = assetUids, Eggs = eggUids })
    end)
    return ok
end

function HUB.SellSingleInventoryItem(uid)
    local re = GetNetRemote("RE/AssetInventory/SellAsset")
        or eventRemote("AssetInventory", "SellAsset", "RE")
        or GetNetRemote("RE/PetSatchel/SellPet")
        or GetNetRemote("RE/SellService/SellPet")
        or eventRemote("PetSatchel", "SellPet", "RE")
        or eventRemote("SellService", "SellPet", "RE")
    if not re or not re:IsA("RemoteEvent") then return false end
    local payload = type(uid) == "table" and uid or { uid }
    local ok = pcall(function()
        -- The legacy fallback sends AssetInventory:SellAsset as an array
        -- of UIDs, even when the array contains only one item.
        re:FireServer(payload)
    end)
    return ok
end

function HUB.InventoryItemProtected(item, uid, save)
    if type(item) ~= "table" then return true end
    local attrs = item.attributes or item.Attributes or item.Attribute
    local function marked(name)
        return item[name] == true or (type(attrs) == "table" and attrs[name] == true)
    end
    if uid and type(save) == "table" then
        for _, equippedUid in pairs(save.EquippedAssets or {}) do
            if tostring(equippedUid) == tostring(uid) then return true end
        end
        local rift = eventState and eventState.rift
        if rift and rift.enabled then
            if rift.pending and rift.pending[tostring(uid)] then return true end
            for _, requirement in ipairs((rift.last and rift.last.Requirements) or {}) do
                if riftCategoryMatches(item, requirement) then return true end
            end
        end
    end
    return marked("Locked") or marked("locked") or marked("Favorite") or marked("favorite")
        or marked("Fused") or marked("fused") or marked("Equipped") or marked("equipped")
        or marked("Placed") or marked("placed") or marked("Plotted") or marked("plotted")
end

function HUB.SellSelectedPets()
    if _G.AxelWebLog and _G.AxelWebLog.SetActivity then _G.AxelWebLog.SetActivity("Selling Pets", "Batch seller is clearing selected pet inventory") end
    if not SaveModule then return 0 end
    local save = readSaveTable()
    local inv = save.Inventory
    if type(inv) ~= "table" then return 0 end
    local uids = {}
    for uid, petData in pairs(inv) do
        if type(petData) == "table" and not HUB.InventoryItemProtected(petData, uid, save) then
            if isSellSelectionMatch(petData, selectedSellPetCategories, selectedSellPetRarities) then
                table.insert(uids, uid)
            end
        end
    end
    if #uids == 0 then return 0 end
    if HUB.SellInventorySelection({}, uids) then return #uids end
    if HUB.SellInventoryBatch(uids) then return #uids end
    local sold = 0
    for _, uid in ipairs(uids) do
        if HUB.SellSingleInventoryItem(uid) then sold += 1 end
        task.wait(SELL_REQUEST_DELAY)
    end
    return sold
end

function HUB.SellSelectedEggs()
    if _G.AxelWebLog and _G.AxelWebLog.SetActivity then _G.AxelWebLog.SetActivity("Selling Eggs", "Seller is clearing selected egg inventory") end
    local save = readSaveTable()
    local inv = save.EggInventory
    if type(inv) ~= "table" then return 0 end
    local uids = {}
    for uid, eggData in pairs(inv) do
        if type(eggData) == "table" and not HUB.InventoryItemProtected(eggData, uid, save) and not eggData.Placement then
            if isSellSelectionMatch(eggData, selectedSellEggCategories, selectedSellEggRarities) then
                table.insert(uids, uid)
            end
        end
    end
    if #uids == 0 then return 0 end
    if HUB.SellInventorySelection(uids, {}) then return #uids end
    if HUB.SellInventoryBatch(uids) then return #uids end

    -- Older Axel builds sell the currently worn egg. Keep this fallback so the
    -- The same filter works when the batch SellInventory RF is absent.
    local wear = GetNetRemote("RF/EggWorld/AskWearTool")
    local sold = 0
    for _, uid in ipairs(uids) do
        if wear then pcall(function() wear:InvokeServer(uid) end) end
        if HUB.SellSingleInventoryItem({ uid }) then sold += 1 end
        task.wait(SELL_REQUEST_DELAY)
    end
    return sold
end

function HUB.DeleteOwnPetRenders()
    local count = 0
    local function sweep(container)
        if not container then return end
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Model") or child:IsA("BasePart") then
                pcall(function()
                    child:Destroy()
                    count = count + 1
                end)
            end
        end
    end
    sweep(Workspace:FindFirstChild("Pets"))
    sweep(Workspace:FindFirstChild("RenderedPets"))
    return count
end

-- ============================================================================
-- VISUALS / PERFORMANCE + OFFLINE REWARD ADAPTER
-- ============================================================================
-- Keep these systems isolated from the normal automation workers.  Each
-- toggle remembers the values it changes and restores them when disabled or
-- when the hub is unloaded.
function HUB.InstallVisualRewardAdapters()
    local hideLowState = {
        enabled = false,
        conns = {},
        touched = {},
        boundContainers = {},
        prevQuality = nil,
        prevDecor = nil,
    }

    local function disconnectAll(list)
        for _, connection in ipairs(list or {}) do
            pcall(function() connection:Disconnect() end)
        end
        table.clear(list or {})
    end

    local function rememberHidden(instance, kind, value)
        if hideLowState.touched[instance] == nil then
            hideLowState.touched[instance] = { kind = kind, value = value }
        end
    end

    local function hideLowOne(instance)
        if not instance or not instance:IsA("Instance") then return end
        if instance:IsA("BasePart") then
            rememberHidden(instance, "localTransparency", instance.LocalTransparencyModifier)
            instance.LocalTransparencyModifier = 1
        elseif instance:IsA("Decal") or instance:IsA("Texture") then
            rememberHidden(instance, "transparency", instance.Transparency)
            instance.Transparency = 1
        elseif instance:IsA("BillboardGui") or instance:IsA("SurfaceGui") then
            if instance.Enabled then rememberHidden(instance, "enabled", true) end
            instance.Enabled = false
        elseif instance:IsA("ParticleEmitter") or instance:IsA("Trail")
            or instance:IsA("PointLight") or instance:IsA("SurfaceLight")
            or instance:IsA("SpotLight") or instance:IsA("PostEffect") then
            if instance.Enabled then rememberHidden(instance, "enabled", true) end
            instance.Enabled = false
        end
    end

    local function bindLowContainer(container)
        if not container or hideLowState.boundContainers[container] then return end
        hideLowState.boundContainers[container] = true
        for _, instance in ipairs(container:GetDescendants()) do
            pcall(hideLowOne, instance)
        end
        hideLowState.conns[#hideLowState.conns + 1] = container.DescendantAdded:Connect(function(instance)
            task.defer(function()
                if hideLowState.enabled then pcall(hideLowOne, instance) end
            end)
        end)
    end

    local function isLowContainer(instance)
        return instance and (
            instance.Name == "ClientRenderedAssets"
            or instance.Name == "PlacedEggRenders"
            or instance.Name == "__ClientTreadmillRenders"
        )
    end

    local function bindTerrainBillboards(terrain)
        if not terrain then return end
        for _, instance in ipairs(terrain:GetDescendants()) do
            if instance:IsA("BillboardGui") then pcall(hideLowOne, instance) end
        end
        hideLowState.conns[#hideLowState.conns + 1] = terrain.DescendantAdded:Connect(function(instance)
            task.defer(function()
                if hideLowState.enabled and instance:IsA("BillboardGui") then
                    pcall(hideLowOne, instance)
                end
            end)
        end)
    end

    HUB.SetHideLow = function(enabled)
        enabled = enabled == true
        if hideLowState.enabled == enabled then return end
        hideLowState.enabled = enabled
        disconnectAll(hideLowState.conns)
        hideLowState.boundContainers = {}

        if not enabled then
            pcall(function()
                settings().Rendering.QualityLevel = hideLowState.prevQuality or Enum.QualityLevel.Automatic
            end)
            pcall(function()
                local terrain = Workspace:FindFirstChildOfClass("Terrain")
                if terrain and hideLowState.prevDecor ~= nil then terrain.Decoration = hideLowState.prevDecor end
            end)
            for instance, saved in pairs(hideLowState.touched) do
                pcall(function()
                    if not instance or not instance.Parent then return end
                    if saved.kind == "localTransparency" then
                        instance.LocalTransparencyModifier = saved.value
                    elseif saved.kind == "transparency" then
                        instance.Transparency = saved.value
                    elseif saved.kind == "enabled" then
                        instance.Enabled = saved.value
                    end
                end)
            end
            hideLowState.touched = {}
            hideLowState.prevQuality = nil
            hideLowState.prevDecor = nil
            return
        end

        for _, instance in ipairs(Workspace:GetChildren()) do
            if isLowContainer(instance) then bindLowContainer(instance) end
        end
        hideLowState.conns[#hideLowState.conns + 1] = Workspace.ChildAdded:Connect(function(instance)
            task.defer(function()
                if hideLowState.enabled and isLowContainer(instance) then bindLowContainer(instance) end
            end)
        end)
        bindTerrainBillboards(Workspace:FindFirstChildOfClass("Terrain"))
        pcall(function()
            local terrain = Workspace:FindFirstChildOfClass("Terrain")
            if terrain then
                hideLowState.prevDecor = terrain.Decoration
                terrain.Decoration = false
            end
        end)
        hideLowState.conns[#hideLowState.conns + 1] = Lighting.DescendantAdded:Connect(function(instance)
            task.defer(function()
                if hideLowState.enabled and instance:IsA("PostEffect") then pcall(hideLowOne, instance) end
            end)
        end)
        pcall(function()
            local rendering = settings().Rendering
            hideLowState.prevQuality = rendering.QualityLevel
            rendering.QualityLevel = Enum.QualityLevel.Level01
        end)
        pcall(function()
            for _, instance in ipairs(Lighting:GetDescendants()) do
                if instance:IsA("PostEffect") then pcall(hideLowOne, instance) end
            end
        end)
    end

    local hideNamesState = { enabled = false, conns = {}, humanoids = {}, guis = {} }

    local function applyHiddenNames(character)
        if not hideNamesState.enabled or not character then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            if hideNamesState.humanoids[humanoid] == nil then
                hideNamesState.humanoids[humanoid] = humanoid.DisplayDistanceType
            end
            pcall(function() humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end)
        end
        for _, instance in ipairs(character:GetDescendants()) do
            if instance:IsA("BillboardGui") then
                if hideNamesState.guis[instance] == nil then hideNamesState.guis[instance] = instance.Enabled end
                instance.Enabled = false
            end
        end
    end

    HUB.SetHideNames = function(enabled)
        enabled = enabled == true
        if hideNamesState.enabled == enabled then return end
        hideNamesState.enabled = enabled
        disconnectAll(hideNamesState.conns)
        if not enabled then
            for humanoid, displayType in pairs(hideNamesState.humanoids) do
                pcall(function() if humanoid.Parent then humanoid.DisplayDistanceType = displayType end end)
            end
            for gui, wasEnabled in pairs(hideNamesState.guis) do
                pcall(function() if gui.Parent then gui.Enabled = wasEnabled end end)
            end
            hideNamesState.humanoids = {}
            hideNamesState.guis = {}
            return
        end

        local function watchPlayer(player)
            if player.Character then applyHiddenNames(player.Character) end
            hideNamesState.conns[#hideNamesState.conns + 1] = player.CharacterAdded:Connect(function(character)
                task.delay(0.5, function()
                    if hideNamesState.enabled then applyHiddenNames(character) end
                end)
            end)
        end
        for _, player in ipairs(Players:GetPlayers()) do watchPlayer(player) end
        hideNamesState.conns[#hideNamesState.conns + 1] = Players.PlayerAdded:Connect(watchPlayer)
        hideNamesState.conns[#hideNamesState.conns + 1] = task.spawn(function()
            while hideNamesState.enabled and not HUB.dead do
                task.wait(3)
                for _, player in ipairs(Players:GetPlayers()) do
                    if player.Character then pcall(applyHiddenNames, player.Character) end
                end
            end
        end)
    end

    local shelterState = { enabled = false, token = 0, thread = nil }
    HUB.SetShelterFromDragonWave = function(enabled)
        enabled = enabled == true
        shelterState.enabled = enabled
        HUB.ShelterMovementIntent = enabled
        shelterState.token += 1
        local token = shelterState.token
        if not enabled then return end
        if shelterState.thread then return end
        shelterState.thread = task.spawn(function()
            while shelterState.enabled and shelterState.token == token and not HUB.dead do
                local wave = Workspace:GetAttribute("Event_DragonWave") == true
                    or Workspace:GetAttribute("DragonWave") == true
                local carrying = false
                pcall(function() carrying = isPlayerCarryingEgg() == true end)
                local busy = carryingEggReturnActive or carrying or eventState.rift.acquiring
                    or (eventState.boss.enabled and LP:GetAttribute("InBossArena") == true)
                    or automationActionBusy
                    or (HUB.MovementLease and HUB.MovementLease.owner ~= nil)
                if wave and not busy and HUB.AcquireMovementLease("shelter") then
                    local shelterPos = GetLocalPlotCenter()
                    if shelterPos then
                        if _G.AxelWebLog and _G.AxelWebLog.SetActivity then
                            pcall(_G.AxelWebLog.SetActivity, "Dragon Wave Shelter", "Returning to the base pen")
                        end
                        automationActionBusy = true
                        HUB.AutomationBusyAt = os.clock()
                        pcall(TravelToDestination, shelterPos + Vector3.new(0, 1.2, 0), math.min(glideSpeed, 300), true)
                        automationActionBusy = false
                        HUB.AutomationBusyAt = 0
                    end
                    HUB.ReleaseMovementLease("shelter")
                end
                task.wait(1)
            end
            if shelterState.token == token then shelterState.thread = nil end
        end)
    end

    local autoClaimOfflineReward = false
    local offlineNextClaimAt = 0

    local function pendingOfflineMoney(save)
        local nested = save and (save.OfflineAssets or save.AwayEarnings)
        return tonumber(save and save.PendingOfflineMoney)
            or tonumber(type(nested) == "table" and nested.PendingOfflineMoney)
            or 0
    end

    local function claimOfflineReward(force)
        local save = readSaveTable()
        if not force and pendingOfflineMoney(save) <= 0 then return false end
        local remote = GetNetRemote("RF/OfflineAssets/Redeem")
        if remote and remote:IsA("RemoteFunction") then
            local ok = pcall(function() remote:InvokeServer({ Kind = "Claim" }) end)
            if ok then return true end
        elseif remote and remote:IsA("RemoteEvent") then
            local ok = pcall(function() remote:FireServer({ Kind = "Claim" }) end)
            if ok then return true end
        end
        -- Older builds call the same endpoint through the shared remotes
        -- table; keep the AwayEarnings endpoint as a final compatibility path.
        local result = select(1, invokeEventRemote("OfflineAssets", "Redeem", { Kind = "Claim" }))
        if result ~= nil then return result == true end
        local fallback = GetNetRemote("RF/AwayEarnings/AskCollect")
        if fallback and fallback:IsA("RemoteFunction") then
            return pcall(function() fallback:InvokeServer() end)
        end
        return false
    end

    HUB.ClaimOfflineReward = claimOfflineReward
    HUB.SetAutoClaimOffline = function(enabled)
        autoClaimOfflineReward = enabled == true
        offlineNextClaimAt = 0
    end

    task.spawn(function()
        while not HUB.dead do
            if autoClaimOfflineReward and os.clock() >= offlineNextClaimAt then
                local save = readSaveTable()
                local pending = pendingOfflineMoney(save)
                if pending > 0 then
                    pcall(claimOfflineReward, false)
                    offlineNextClaimAt = os.clock() + 6
                else
                    offlineNextClaimAt = os.clock() + 10
                end
            end
            task.wait(1)
        end
    end)
end

HUB.InstallVisualRewardAdapters()

function HUB.ClaimAllAvailableRewards()
    pcall(function() if HUB.ClaimOfflineReward then HUB.ClaimOfflineReward(true) end end)
    pcall(function()
        local rf1 = GetNetRemote("RF/AwayEarnings/AskCollect")
        if rf1 then rf1:InvokeServer() end
    end)
    pcall(function()
        local rf2 = GetNetRemote("RF/Codex/AskRedeemAll")
        if rf2 then rf2:InvokeServer() end
    end)
    pcall(function()
        local rf3 = GetNetRemote("RF/GroupPerk/RedeemPerk")
        if rf3 then rf3:InvokeServer() end
    end)
    pcall(HUB.ClaimMonsterChests)
end


-- ==============================================================================
-- SERVER HOP CORE (register-safe / src1 only)
-- ==============================================================================
-- A hop must carry a permit created by the guarded automatic-hop path. This
-- prevents a stale coroutine/config flag from reaching TeleportService when a
-- different feature is enabled or re-enabled.
-- Store the manual token on HUB so this large top-level chunk does not spend
-- another local register on a value that is only used by the hop guard.
HUB.ManualHopToken = {}
HUB.ServerHopState = {
    AutoHop = false,
    -- This second gate is set only by the explicit Auto Server Hop UI toggle.
    -- It prevents stale/configured state from teleporting the player by itself.
    AutoHopExplicit = false,
    MaxHops = 20,
    HopDelay = 10,
    BossPostDefeatDelay = 15,
    HopCount = 0,
    Busy = false,
    -- Rarity/no-match hopping requires both explicit hop toggles. When Auto
    -- Boss Rift is active, an explicitly requested no-match hop is held until
    -- the boss is done.
    HopOnNoMatch = false,
    NoMatchActive = false,
    MatchFound = false,
    LastHopAt = 0,
    AutoEnabledAt = 0,
    VisitedServers = {},
    HopSession = {},
    HopPermit = nil,
}
if type(HUB.ServerHopState.BossPostDefeatDelay) ~= "number" then
    HUB.ServerHopState.BossPostDefeatDelay = 15
end

-- Clear only transient movement/event state around a server transition. The
-- feature toggles and hop settings stay enabled, while stale route owners,
-- carry flags, no-clip leases, and old boss/Rift windows are discarded. This
-- lets the same script instance re-arm cleanly when the executor does not
-- reload the script after TeleportService changes the server.
HUB.ResetTransientAutomationState = function(reason)
    -- Reset the shared worker marker before clearing route state. If a previous
    -- coroutine died during a remote call, leaving this flag true prevents all
    -- lower-priority loops from ever taking the next movement turn.
    automationActionBusy = false
    HUB.AutomationBusyAt = 0
    pcall(HUB.Orchestrator.End)
    pcall(function()
        HUB.MovementLease.owner = nil
        HUB.MovementLease.depth = 0
    end)
    pcall(function() HUB.AutoStealControllerEpoch = (tonumber(HUB.AutoStealControllerEpoch) or 0) + 1 end)
    pcall(function() HUB.SujiRouteState = nil end)
    pcall(function() HUB.AutoStealMovementActive = false end)
    pcall(function() HUB.StealGlide.owner = nil end)
    pcall(function() HUB.StealGlide.safeCenter = nil end)
    pcall(function() HUB.StealGlide.parkPosition = nil end)
    pcall(function() HUB.StealGlide.raycastParams = nil end)
    pcall(function() HUB.StealGlide.raycastCharacter = nil end)
    pcall(EndEggTravelSpeedWatch)
    pcall(function() carryingEggReturnActive = false end)
    pcall(function() HUB.StopAutoStealNoClip() end)
    pcall(function() HUB.StopRiftNoClip() end)
    pcall(function() stopRiftBossNoClip() end)

    treadmillControllerEpoch += 1
    treadmillHandoffBusy = false
    HUB.TreadmillHandoffAt = 0
    treadmillTrainingActive = false
    HUB.TreadmillMounted = false
    treadmillResetRequested = true
    if HUB.TreadmillResumeState then
        HUB.TreadmillResumeState.token = (tonumber(HUB.TreadmillResumeState.token) or 0) + 1
    end

    if type(eventState) == "table" then
        if type(eventState.rift) == "table" then
            eventState.rift.acquiring = false
            eventState.rift.placing = false
            eventState.rift.scanSettling = false
            eventState.rift.fieldActionReady = false
            eventState.rift.previewAt = 0
            eventState.rift.pending = {}
            eventState.rift.status = eventState.rift.enabled and "idle" or "off"
            eventState.rift.detail = tostring(reason or "rearmed")
            eventState.rift.lastActionAt = 0
        end
        if type(eventState.boss) == "table" then
            eventState.boss.controllerEpoch = (tonumber(eventState.boss.controllerEpoch) or 0) + 1
            eventState.boss.windowOpen = false
            eventState.boss.inArena = false
            eventState.boss.hasEnteredArena = false
            eventState.boss.armPathSeen = false
            eventState.boss.armHealth = nil
            eventState.boss.armHealthSource = ""
            eventState.boss.armHealthPositiveSeen = false
            eventState.boss.armHealthZeroSeen = false
            eventState.boss.armHealthZeroCandidateRevision = -1
            eventState.boss.armHealthZeroCandidateAt = 0
            eventState.boss.armInstance = nil
            eventState.boss.lastHealthAt = 0
            eventState.boss.liveSnapshot = nil
            eventState.boss.snapshotAt = 0
            eventState.boss.snapshotRevision = 0
            eventState.boss.snapshotInFlight = false
            eventState.boss.snapshotError = ""
            eventState.boss.leaveCompleted = false
            eventState.boss.hopLocked = false
            eventState.boss.sessionDefeated = false
            eventState.boss.defeatedAt = 0
            eventState.boss.hopAfterLeaveAt = 0
            eventState.boss.hopQueued = false
            eventState.boss.hopBusy = false
            eventState.boss.roundClosedObserved = false
            eventState.boss.arenaInstance = nil
            eventState.boss.previousMovementOwner = nil
            eventState.boss.status = eventState.boss.enabled and "waiting" or "off"
            eventState.boss.detail = tostring(reason or "rearmed")
        end
    end

    local hopState = HUB.ServerHopState
    if hopState then
        hopState.HopPermit = nil
        hopState.NoMatchActive = false
        hopState.MatchFound = false
        hopState.Busy = false
    end
end

-- Re-arm the movement leases and controllers after a server hop or character
-- replacement. This is deliberately separate from the feature toggles: the
-- user's selected Auto Steal/Rift/Treadmill settings survive the transition.
track(LP.CharacterAdded:Connect(function()
    -- Re-arm immediately, before the delayed Backpack/GUI wait. Otherwise the
    -- old character's lease, raycast filter, or busy flag can keep the central
    -- controller frozen for the whole first scan after respawn.
    pcall(HUB.ResetTransientAutomationState, "character replaced")
    pcall(HUB.InvalidateFieldEggSnapshot, "character respawn/map replica reset")
    HUB.AutoStealResumeAt = os.clock() + 2.0
    task.spawn(function()
        task.wait(0.8)
        if HUB.dead then return end
        HUB.ResetTransientAutomationState("character rearmed")
        if autoStealEnabled then pcall(HUB.StartAutoStealNoClip) end
        if autoTreadmillEnabled then pcall(QueueAutoTreadmillResume) end
    end)
end))

pcall(function()
    track(TeleportService.TeleportInitFailed:Connect(function(player)
        if player ~= LP or HUB.dead then return end
        HUB.ResetTransientAutomationState("teleport failed")
        if autoStealEnabled then pcall(HUB.StartAutoStealNoClip) end
    end))
end)

function HUB.ServerHopRequest(url)
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if type(req) == "function" then
        local ok, res = pcall(req, {
            Url = url,
            Method = "GET",
            Headers = { ["Content-Type"] = "application/json" },
        })
        if ok and res then
            local status = tonumber(res.StatusCode or res.Status or 200) or 0
            if status >= 200 and status < 300 and type(res.Body) == "string" then
                return res.Body
            end
        end
    end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" then return body end
    return nil
end

-- Keep this as a HUB method instead of another top-level local binding. The
-- full script already has a large top-level local scope; adding one more local
-- function can exceed Luau's 200-register limit at compile time.
HUB.IsAutomaticHopPermit = function(state, permit)
    if type(permit) ~= "table"
        or permit.session ~= state.HopSession
        or state.HopPermit ~= permit
        or (tonumber(permit.expiresAt) or 0) < os.clock() then
        return false
    end
    if permit.reason == "boss" then
        return isBossHopReady(state)
    end
    return permit.reason == "no-match"
        and state.AutoHop == true
        and state.AutoHopExplicit == true
        and state.HopOnNoMatch == true
        and state.NoMatchActive == true
        and state.MatchFound ~= true
        and autoStealEnabled == true
        and not IsRiftBossHopBlocked("no-match")
end

function HUB.JoinServer(placeId, jobId, authorization)
    local state = HUB.ServerHopState
    local manual = authorization == HUB.ManualHopToken
    if not manual then
        -- Final defense at the actual join boundary. Even if an old coroutine
        -- retained a permit reference, Auto Boss Rift alone cannot consume a
        -- boss-hop permit unless the dedicated toggle is still on now.
        if type(authorization) == "table" and authorization.reason == "boss" then
            local boss = eventState and eventState.boss
            if not boss or boss.enabled ~= true
                or boss.hopEnabled ~= true or boss.hopExplicit ~= true then
                if type(HUB.ClearRiftBossHopState) == "function" then
                    HUB.ClearRiftBossHopState()
                end
                return false, "Rift Boss hop is not explicitly enabled"
            end
        end
        if not HUB.IsAutomaticHopPermit(state, authorization) then
            return false, "server hop blocked by guard"
        end
        -- Consume the one-shot permit before calling TeleportService.
        state.HopPermit = nil
    end
    placeId = tonumber(placeId)
    if not placeId or placeId <= 0 then return false, "invalid place id" end
    if not jobId or tostring(jobId) == "" then return false, "missing server id" end
    HUB.ResetTransientAutomationState(manual and "manual server hop" or "automatic server hop")
    -- Keep the hop lock held until TeleportService accepts the request. The
    -- transient reset above clears stale state, but must not open a second hop
    -- worker during this short handoff window.
    state.Busy = true
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, tostring(jobId), LP)
    end)
    if not ok then
        state.Busy = false
        return false, tostring(err)
    end
    return true
end

function HUB.ManualJoinServer(placeId, jobId)
    return HUB.JoinServer(placeId, jobId, HUB.ManualHopToken)
end

function HUB.FindOpenPublicServer(placeId)
    placeId = tonumber(placeId)
    if not placeId then return nil, "invalid place id" end
    local hs = game:GetService("HttpService")
    local currentJob = tostring(game.JobId or "")
    local hopState = HUB.ServerHopState
    local visited = type(hopState.VisitedServers) == "table" and hopState.VisitedServers or {}
    local fallback
    local cursor = ""
    local base = "https://games.roblox.com/v1/games/" .. tostring(placeId) .. "/servers/Public?sortOrder=Asc&limit=100"
    for _ = 1, 5 do
        local url = base
        if cursor ~= "" then url = url .. "&cursor=" .. hs:UrlEncode(cursor) end
        local body = HUB.ServerHopRequest(url)
        if not body then return nil, "server list request failed" end
        local ok, data = pcall(hs.JSONDecode, hs, body)
        if not ok or type(data) ~= "table" then return nil, "invalid server list" end
        for _, server in ipairs(data.data or {}) do
            local id = tostring(server.id or "")
            local playing = tonumber(server.playing) or 0
            local maxPlayers = tonumber(server.maxPlayers) or 0
            if id ~= "" and id ~= currentJob and (maxPlayers <= 0 or playing < maxPlayers) then
                local target = { placeId = placeId, jobId = id, playing = playing, maxPlayers = maxPlayers }
                if not fallback then fallback = target end
                if not visited[id] then return target end
            end
        end
        cursor = tostring(data.nextPageCursor or "")
        if cursor == "" then break end
    end
    if fallback then return fallback end
    return nil, "no open server found"
end

function HUB.HopOnce(reason)
    local state = HUB.ServerHopState
    if state.Busy then return false, "busy" end
    if reason == nil then
        return false, "manual hop must use the manual action path"
    end
    if reason ~= "no-match" and reason ~= "boss" then
        return false, "unknown automatic hop blocked"
    end
    if reason == "no-match" then
        if not autoStealEnabled or state.AutoHop ~= true
            or state.AutoHopExplicit ~= true or state.HopOnNoMatch ~= true then
            HUB.ClearNoMatchHopState()
            return false, "rarity hop disabled"
        end
        if state.NoMatchActive ~= true then
            return false, "no matching rarity was not detected"
        end
        if state.MatchFound then
            HUB.ClearNoMatchHopState()
            return false, "matching egg already found"
        end
    elseif not isBossHopReady(state) then
        return false, "Rift Boss HP is not zero or leave is not complete"
    end
    -- One central guard covers every automatic hop route. A server change is
    -- never allowed while an egg is being delivered, while Rift is placing an
    -- egg, or while the player is still inside the boss arena. Manual
    -- "Server Hop Now" (reason=nil) remains available by user action.
    local carrying = false
    pcall(function()
        carrying = type(isPlayerCarryingEgg) == "function" and isPlayerCarryingEgg() == true
    end)
    local busyAction = carryingEggReturnActive
        or carrying
        or eventState.rift.acquiring or eventState.rift.placing
        or LP:GetAttribute("InBossArena") == true
    if busyAction then return false, "active action is holding the server" end
    -- Rarity hops are also blocked while Auto Boss Rift owns the session.
    if IsRiftBossHopBlocked(reason) then
        return false, "Rift Boss run is holding the server"
    end
    if state.HopCount >= state.MaxHops then
        state.AutoHop = false
        return false, "hop limit reached"
    end
    state.Busy = true
    local target, err = HUB.FindOpenPublicServer(game.PlaceId)
    if not target then
        state.Busy = false
        return false, tostring(err or "no server")
    end
    -- The boss can be defeated while the public-server list request is in
    -- flight. Re-check before TeleportToPlaceInstance so a stale hop task
    -- cannot escape to another server after the kill.
    if IsRiftBossHopBlocked(reason) then
        state.Busy = false
        return false, "Rift Boss was defeated; hop cancelled"
    end
    local permit = {
        session = state.HopSession,
        reason = reason,
        expiresAt = os.clock() + 2,
    }
    if not HUB.IsAutomaticHopPermit(state, permit) then
        state.Busy = false
        return false, "server hop blocked by guard"
    end
    state.HopPermit = permit
    local ok, joinErr = HUB.JoinServer(target.placeId, target.jobId, permit)
    if ok then
        state.VisitedServers = type(state.VisitedServers) == "table" and state.VisitedServers or {}
        state.VisitedServers[target.jobId] = os.clock()
        state.HopCount += 1
        state.LastHopAt = os.clock()
        state.Busy = false
        return true, "Teleporting"
    end
    state.Busy = false
    return false, tostring(joinErr or "teleport failed")
end

function HUB.ManualHopOnce()
    local state = HUB.ServerHopState
    if state.Busy then return false, "busy" end
    state.Busy = true
    local target, err = HUB.FindOpenPublicServer(game.PlaceId)
    if not target then
        state.Busy = false
        return false, tostring(err or "no server")
    end
    local ok, joinErr = HUB.ManualJoinServer(target.placeId, target.jobId)
    if ok then
        state.VisitedServers[target.jobId] = os.clock()
        state.HopCount += 1
        state.LastHopAt = os.clock()
        state.Busy = false
        return true, "Teleporting"
    end
    state.Busy = false
    return false, tostring(joinErr or "teleport failed")
end

-- Clear a queued rarity hop as soon as any of its required conditions stop
-- being true. This prevents an old no-match coroutine/permit from hopping after
-- Auto Steal or either hop toggle has been turned off.
HUB.ClearNoMatchHopState = function()
    local state = HUB.ServerHopState
    if not state then return end
    state.NoMatchActive = false
    state.MatchFound = false
    if type(state.HopPermit) == "table" and state.HopPermit.reason == "no-match" then
        state.HopPermit = nil
    end
end

-- Clear every automatic-hop transaction without changing the user's toggle
-- intent.  This is called at boot and on Rift Boss toggle transitions so an
-- old permit/queue cannot survive a re-execution or a persisted UI config.
HUB.ClearAutomaticHopCache = function(reason)
    local state = HUB.ServerHopState
    if state then
        state.HopPermit = nil
        state.HopSession = {}
        state.NoMatchActive = false
        state.MatchFound = false
        state.Busy = false
    end
    local boss = eventState and eventState.boss
    if boss then
        boss.hopQueued = false
        boss.hopBusy = false
        boss.hopAfterLeaveAt = 0
        if boss.sessionDefeated ~= true then
            boss.hopLocked = false
        end
        if reason then boss.hopCacheReason = tostring(reason) end
    end
end

-- The first run must never inherit a permit from an older execution/config.
pcall(HUB.ClearAutomaticHopCache, "startup")

function HUB.TriggerHopOnNoMatch()
    local state = HUB.ServerHopState
    if not autoStealEnabled or carryingEggReturnActive then
        HUB.ClearNoMatchHopState()
        return false
    end
    if not state.AutoHop or state.AutoHopExplicit ~= true or state.HopOnNoMatch ~= true then
        HUB.ClearNoMatchHopState()
        return false
    end
    if state.MatchFound then
        HUB.ClearNoMatchHopState()
        return false
    end
    if state.HopCount >= state.MaxHops then
        state.AutoHop = false
        HUB.ClearNoMatchHopState()
        return false
    end

    -- Arm the rarity hop even while the boss owns movement. The server-hop
    -- worker will release it after BossPostDefeatDelay has elapsed.
    state.NoMatchActive = true
    state.MatchFound = false
    if IsRiftBossHopBlocked("no-match") then
        local boss = eventState and eventState.boss
        local detail = "Waiting for Rift Boss before rarity hop"
        if boss and boss.hopLocked then
            local delay = tonumber(state.BossPostDefeatDelay) or 15
            local elapsed = os.clock() - (tonumber(boss.defeatedAt) or os.clock())
            detail = string.format("Boss defeated; rarity hop in %ds", math.max(0, math.ceil(delay - elapsed)))
        end
        if _G.AxelWebLog and _G.AxelWebLog.SetActivity then
            pcall(_G.AxelWebLog.SetActivity, "Rift Boss", detail)
        end
        return true
    end

    if state.Busy or os.clock() - state.LastHopAt < state.HopDelay then return true end
    task.spawn(function()
        if state.NoMatchActive and autoStealEnabled and state.AutoHop
            and state.AutoHopExplicit == true and state.HopOnNoMatch
            and not IsRiftBossHopBlocked("no-match") and not state.Busy then
            pcall(HUB.HopOnce, "no-match")
        end
    end)
    return true
end

task.spawn(function()
    while not HUB.dead do
        local state = HUB.ServerHopState
        -- Rarity hops run only after Auto Server Hop is explicitly enabled
        -- and a no-match scan has armed this worker.
        if state.AutoHop and state.AutoHopExplicit == true
            and state.HopOnNoMatch == true
            and not IsRiftBossHopBlocked()
            and not state.MatchFound and (not state.HopOnNoMatch or state.NoMatchActive) then
            if state.HopCount >= state.MaxHops then
                state.AutoHop = false
            elseif not state.Busy then
                local now = os.clock()
                local anchor = math.max(state.LastHopAt or 0, state.AutoEnabledAt or 0)
                if now - anchor >= state.HopDelay then
                    task.spawn(function()
                        local ok = pcall(HUB.HopOnce, state.HopOnNoMatch and "no-match" or "auto")
                        if not ok then
                            state.Busy = false
                        end
                    end)
                end
            end
        end
        task.wait(0.25)
    end
end)

-- ==============================================================================
-- WORKER LOOPS
-- ==============================================================================
-- 1. Unified priority controller, matching Suji's effective owner order:
--    active Rift Boss -> selected Auto Steal target -> active Rift quest
--    -> Auto Treadmill. The Boss route gets the first chance whenever its
--    window is active, including the join/leave handoff. Auto Steal is
--    considered only after the boss route has released control and only when
--    its toggle is explicitly enabled with a matching rarity+area egg. Rift
--    and Treadmill are fallbacks. Keeping movement in one coroutine prevents
--    enabled features from fighting over HumanoidRootPart.
task.spawn(function()
    while not HUB.dead do
        local wakeEpoch = HUB.AutomationWakeEpoch
        pcall(HUB.RecoverStaleAutomationState)
        pcall(HUB.RecoverMovementLease)
        -- Auto Treadmill must keep working when Auto Steal is OFF. Reconcile
        -- the previous steal route before the owner/permission checks below;
        -- otherwise a stale speed watcher or Orchestrator suspension can make
        -- the character stand at the plot indefinitely.
        if autoStealEnabled ~= true and not carryingEggReturnActive then
            pcall(HUB.ReconcileAutoStealForTreadmill)
        end
        -- A route can finish or be toggled off while its last callback is
        -- inside a protected remote call.  Clear only an owner with no live
        -- route state; otherwise its conflict table keeps Auto Steal and
        -- Auto Treadmill suspended and the character simply stands at base.
        local orchestratorOwner = HUB.Orchestrator and HUB.Orchestrator.owner
        if orchestratorOwner == "rift" then
            local rift = eventState and eventState.rift
            if not rift or rift.enabled ~= true
                or (type(HUB.IsRiftMovementActive) == "function" and not HUB.IsRiftMovementActive()) then
                HUB.Orchestrator.End("rift")
            end
        elseif orchestratorOwner == "steal" then
            -- Steal is a one-trip owner, not a permanent toggle owner. Once
            -- the exact carry/return route has cleared, release it even when
            -- Auto Steal remains enabled so Rift can claim a clean next turn.
            if not carryingEggReturnActive and not HUB.SujiRouteState then
                HUB.Orchestrator.End("steal")
            end
        elseif orchestratorOwner == "treadmill" then
            if not autoTreadmillEnabled and not treadmillTrainingActive and not treadmillHandoffBusy then
                HUB.Orchestrator.End("treadmill")
            end
        elseif orchestratorOwner == "boss" then
            -- Boss may leave its owner behind when a protected arena remote
            -- errors after the leave teleport.  Do not let that stale conflict
            -- block Auto Steal/Rift/Treadmill once no boss route is active.
            if not IsRiftBossPriorityActive() then
                HUB.Orchestrator.End("boss")
            end
        end
        -- A cancelled/errored outbound route can leave only the reusable speed
        -- watcher active. It must never gate Rift, Treadmill, plant, or the next
        -- Auto Steal attempt once the outbound arm has been released.
        if HUB.EggTravelSpeedWatch
            and HUB.EggTravelSpeedWatch.active == true
            and (not HUB.StealGlide or HUB.StealGlide.speedGuard ~= true) then
            pcall(EndEggTravelSpeedWatch)
        end
        -- A failed route must never leave the controller parked at the plot.
        -- If no live Suji route and no carried visual remain, release the
        -- stale return/movement flags before the next priority decision.
        if carryingEggReturnActive and not isPlayerCarryingEgg() and not HUB.SujiRouteState then
            carryingEggReturnActive = false
        end
        if HUB.AutoStealMovementActive and HUB.StealGlide.owner == "auto"
            and not carryingEggReturnActive and not HUB.SujiRouteState then
            HUB.AutoStealMovementActive = false
            HUB.StealGlide.speedGuard = false
            pcall(EndEggTravelSpeedWatch)
            pcall(HUB.StopAutoStealNoClip)
            HUB.StealGlide.owner = nil
        end
        local carryCheckOk, carryingNow = pcall(function()
            return carryingEggReturnActive == true or isPlayerCarryingEgg() == true
        end)
        if not carryCheckOk then
            HUB.ReportAutomationError("Priority carry check", carryingNow)
            carryingNow = true
        end
        if not carryingNow
            and HUB.MovementLease
            and HUB.MovementLease.owner == "manual-fly"
            and type(HUB.HasMovementAutomationIntent) == "function"
            and HUB.HasMovementAutomationIntent() then
            -- A long-lived manual fly lease must yield as soon as any enabled
            -- automation needs the character; otherwise the priority worker
            -- would correctly refuse the lease but appear permanently idle.
            stopFly()
            Notify("Fly", "Paused to let automation own movement", "Info")
        end
        if not carryingNow
            and HUB.AcquireMovementLease("priority") then
            automationActionBusy = true
            HUB.AutomationBusyAt = os.clock()
            local workerOk, workerError = xpcall(function()
                local actionTaken = false

                -- A completed/disabled Boss route releases its temporary
                -- suspension before the next lower-priority decision. This
                -- restores the user's Auto Steal/Treadmill/Rift intent without
                -- touching the UI toggles themselves.
                if not IsRiftBossPriorityActive()
                    and HUB.Orchestrator.owner == "boss" then
                    HUB.Orchestrator.End("boss")
                end

                -- A rarity/area checkbox can change while Auto Steal is
                -- already scanning or while Auto Treadmill owns the character.
                -- Cancel only the stale Auto Steal route, dismount with the
                -- normal jump, and do not scan the new target until Humanoid is
                -- grounded. This is the same landing gate used by Suji.
                if autoStealEnabled == true
                    and HUB.AutoStealFilterRefreshRequested == true
                    and LP:GetAttribute("InBossArena") ~= true
                    and not carryingEggReturnActive
                    and not isPlayerCarryingEgg() then
                    HUB.AutoStealFilterRefreshRequested = false
                    -- A field refresh is only a rescan signal.  The previous
                    -- code dismounted every time any egg spawned/despawned,
                    -- even when no selected rarity/area matched; that caused
                    -- the jump -> treadmill -> jump loop.  Release the old
                    -- route only when Auto Steal actually owns a live target.
                    if HUB.SujiRouteState ~= nil
                        or HUB.AutoStealMovementActive == true
                        or HUB.StealGlide.owner == "auto" then
                        pcall(HUB.ReleaseAutoStealForFallback)
                        pcall(ReleaseTreadmillForAction)
                        if not WaitForEggTravelLanding(3.0) then
                            actionTaken = true
                        end
                    end
                    task.wait(0.05)
                end

                -- Priority 1: Rift Boss. Poll the boss controller even before a
                -- portal/arena is visible. The old gate required a discovered
                -- world target first, so the initial AskSnapshot/AskEnter was
                -- skipped and Auto Boss Rift looked enabled but never entered.
                -- Once a round is defeated, the boss route yields until the
                -- next round key is observed.
                local bossState = eventState.boss
                local bossNow = os.clock()
                local bossPriorityActive = IsRiftBossPriorityActive()
                local bossPollInterval = LP:GetAttribute("InBossArena") == true and 0.10 or 0.20
                local bossPollDue = bossState.enabled == true
                    and bossState.sessionDefeated ~= true
                    and bossNow - (tonumber(bossState.controllerPollAt) or 0) >= bossPollInterval
                if not actionTaken and bossState.enabled == true
                    and (bossPriorityActive or bossPollDue) then
                    local bossOk, bossDidWork = true, true
                    if bossPollDue then
                        bossState.controllerPollAt = bossNow
                        HUB.Orchestrator.Begin("boss")
                        local bossEpoch = bossState.controllerEpoch
                        bossOk, bossDidWork = pcall(bossCycle, true, bossEpoch)
                    end
                    if not bossOk then
                        HUB.ReportAutomationError("Rift Boss", bossDidWork)
                        -- A failed protected call must not leave the boss
                        -- owner/telemetry in an active state forever. Keep the
                        -- arena owner if the game still says we are inside it;
                        -- otherwise release the route and let the next priority
                        -- pass choose Auto Steal/Rift/Treadmill.
                        if LP:GetAttribute("InBossArena") ~= true then
                            local failedBoss = eventState.boss
                            pcall(HUB.CancelRiftBossTween)
                            if HUB.StealGlide and HUB.StealGlide.owner == "boss" then
                                HUB.StealGlide.owner = failedBoss.previousMovementOwner
                            end
                            failedBoss.previousMovementOwner = nil
                            failedBoss.inArena = false
                            failedBoss.leaving = false
                            failedBoss.status = "waiting"
                            failedBoss.detail = "Rift Boss route error; movement released"
                            HUB.Orchestrator.End("boss")
                        end
                    end
                    local bossStatus = eventState.boss.status
                    actionTaken = bossOk and (bossDidWork == true or
                        bossStatus == "starting"
                        or bossStatus == "joining"
                        or bossStatus == "fighting"
                        or bossStatus == "arming"
                        or bossStatus == "leaving"
                        or bossStatus == "armed"
                        or bossStatus == "respawning")
                    if not actionTaken and bossPollDue and LP:GetAttribute("InBossArena") ~= true then
                        HUB.Orchestrator.End("boss")
                    end
                end

                -- Preview Rift before Priority 2. The preview is read-only;
                -- it only tells the scheduler whether Rift has a concrete
                -- field egg to source. Without this preview, Auto Steal could
                -- claim an unrelated egg first and make Rift miss its field
                -- handoff.
                if not actionTaken and eventState.rift.enabled
                    and HUB.Orchestrator.Allows("rift")
                    and not eventState.rift.acquiring
                    and not eventState.rift.placing
                    and HUB.SujiRouteState == nil
                    and os.clock() - (eventState.rift.previewAt or 0) >= 0.20 then
                    eventState.rift.previewAt = os.clock()
                    pcall(riftCycle, false)
                end

                -- Priority 2: Auto Steal is opt-in and uses the selected
                -- rarity+area target. It is not allowed to start from a stale
                -- queued call, and it does not take movement from a live arena
                -- or from a Rift field target that is ready to be sourced.
                local autoStealScanHadMatch = false
                if not actionTaken and autoStealEnabled == true
                    and HUB.IsAutoStealResumeReady()
                    and HUB.Orchestrator.Allows("steal")
                    and HUB.SujiRouteState == nil
                    and eventState.rift.fieldActionReady ~= true
                    and LP:GetAttribute("InBossArena") ~= true then
                    local scanOk, matches = pcall(GetMatchingFieldEggs, selectedStealAreas, selectedStealRarities, selectedMutationTypes)
                    if not scanOk then HUB.ReportAutomationError("Auto Steal scan", matches) end
                    if scanOk and type(matches) == "table" and #matches > 0 then
                        autoStealScanHadMatch = true
                        -- Claim the central owner before entering the complete
                        -- carry/guard/return route.  The old scheduler only
                        -- checked Allows("steal") but never called Begin(), so
                        -- a previous Rift owner could leave its suspension table
                        -- in place and the character would remain motionless at
                        -- the plot even though Auto Steal had a valid target.
                        local stealBegan = HUB.Orchestrator.Begin("steal")
                        if not stealBegan then
                            HUB.ReportAutomationError("Auto Steal owner", "movement owner is still active")
                            actionTaken = false
                        else
                        -- Pass the already-selected Suji record through the
                        -- movement route. Do not rescan here: a second scan
                        -- can see a different snapshot and make Auto Steal
                        -- appear to stand still or carry an unselected egg.
                            local stealOk, stole = pcall(HUB.StealBestEggOnce, false, true, matches[1])
                            if not stealOk then HUB.ReportAutomationError("Auto Steal route", stole) end
                            -- Keep Auto Steal's priority for the whole retry while
                            -- a valid selected rarity/area target still exists,
                            -- but release the slot when the route actually failed.
                            -- Otherwise one rejected carry could make the whole
                            -- controller look idle and block Rift/Treadmill.
                            actionTaken = stealOk and stole == true
                            local stillCarrying = false
                            pcall(function() stillCarrying = carryingEggReturnActive or isPlayerCarryingEgg() end)
                            if not actionTaken and not stillCarrying then
                                pcall(HUB.ReleaseAutoStealForFallback)
                            end
                            -- A failed route that still has the selected egg in
                            -- Character must keep the whole scheduler tick in
                            -- the delivery owner; otherwise the same tick can
                            -- start Rift/Treadmill and interrupt the return.
                            -- The next pass will resume the exact-UID delivery
                            -- retry instead of looking idle at the plot.
                            if stillCarrying then
                                actionTaken = true
                            else
                                HUB.Orchestrator.End("steal")
                            end
                            if not stillCarrying and not carryingEggReturnActive
                                and not HUB.SujiRouteState
                                and HUB.Orchestrator.owner == "steal" then
                                -- Finish this trip before the next scheduler
                                -- pass can choose Rift or Auto Steal again.
                                HUB.Orchestrator.End("steal")
                            end
                        end
                    else
                        -- No selected rarity/area match: release any stale Auto
                        -- Steal owner before Rift/Treadmill gets the turn.
                        pcall(HUB.ReleaseAutoStealForFallback)
                    end
                end

                -- Priority 3: let the Rift quest own movement while it has a
                -- concrete action, but only after Boss and Auto Steal yield.
                if not actionTaken and eventState.rift.enabled
                    and HUB.Orchestrator.Allows("rift")
                    and HUB.SujiRouteState == nil
                    and os.clock() - (eventState.rift.lastActionAt or 0) >= 0.20 then
                    HUB.Orchestrator.Begin("rift")
                    eventState.rift.lastActionAt = os.clock()
                    local riftOk, riftDidWork = pcall(riftCycle, true)
                    if not riftOk then
                        HUB.ReportAutomationError("Rift route", riftDidWork)
                        -- Do not leave sourcing/placing/hatching/trading as a
                        -- permanent movement lock after a remote/replica error.
                        -- The next Rift poll rebuilds its live pending state.
                        local failedRift = eventState.rift
                        failedRift.acquiring = false
                        failedRift.placing = false
                        failedRift.status = "waiting"
                        failedRift.detail = "Rift route error; movement released"
                        HUB.Orchestrator.End("rift")
                    end
                    local rift = eventState.rift
                    actionTaken = riftOk and (rift.scanSettling == true
                        or (riftDidWork == true and (
                            rift.acquiring or rift.placing
                            or rift.status == "placing"
                            or rift.status == "hatching"
                            or rift.status == "trading"
                            or rift.status == "reward"
                            or rift.status == "traded"
                            or rift.status == "sourced"
                            or rift.status == "refreshed"
                            or rift.status == "scanning"
                        )))
                    if not actionTaken then HUB.Orchestrator.End("rift") end
                end

                if not actionTaken then
                    -- Waiting/empty Rift state is not a movement action. Make
                    -- the fallback explicit so the character cannot remain at
                    -- the plot after a no-match scan.
                    pcall(HUB.ReleaseAutoStealForFallback)
                    -- A speed watcher is valid only inside a live outbound
                    -- egg route. Clear it before the rarity/treadmill
                    -- fallback so an old speed sample cannot issue a jump
                    -- when there is no selected egg at all.
                    if HUB.SujiRouteState == nil and not carryingEggReturnActive then
                        HUB.StealGlide.speedGuard = false
                        pcall(EndEggTravelSpeedWatch)
                    end
                end

                -- A rarity hop is considered only for an explicit no-match
                -- request. Without both hop toggles enabled, this branch is
                -- skipped and no rarity-hop state is armed.
                local hopState = HUB.ServerHopState
                if not actionTaken and autoStealEnabled == true
                    and HUB.IsAutoStealResumeReady()
                    and not autoStealScanHadMatch
                    and (type(HUB.IsFieldEggSnapshotSettling) ~= "function"
                        or not HUB.IsFieldEggSnapshotSettling())
                    and (type(HUB.IsAutoStealNoMatchSettled) ~= "function"
                        or HUB.IsAutoStealNoMatchSettled())
                    and hopState and hopState.AutoHop == true
                    and hopState.AutoHopExplicit == true and hopState.HopOnNoMatch == true then
                    pcall(HUB.TriggerHopOnNoMatch)
                end

                -- Priority 4: train only when no higher-priority action exists.
                if not actionTaken and autoTreadmillEnabled
                    and HUB.Orchestrator.Allows("treadmill") then
                    local treadmillOk, treadmillResult = pcall(HandleAutoTreadmillHandoff)
                    if not treadmillOk then HUB.ReportAutomationError("Auto Treadmill", treadmillResult) end
                    -- Do not consume the scheduler tick when the handoff was
                    -- blocked by a stale Rift/lease state.  The old
                    -- unconditional assignment made the controller look busy
                    -- while never retrying the treadmill route.
                    actionTaken = treadmillOk and treadmillResult == true
                end

                -- Auto Treadmill may still own movement as the configured
                -- fallback when no explicit no-match hop is enabled.
            end, function(err)
                if debug and type(debug.traceback) == "function" then
                    return debug.traceback(tostring(err), 2)
                end
                return tostring(err)
            end)
            if not workerOk then
                HUB.ReportAutomationError("Priority worker", workerError)
                pcall(HUB.ReleaseAutoStealForFallback)
                pcall(HUB.StopTreadmillTraining)
            end
            HUB.ReleaseMovementLease("priority")
            automationActionBusy = false
            HUB.AutomationBusyAt = 0
        else
            automationActionBusy = false
            HUB.AutomationBusyAt = 0
        end
        -- Keep the controller responsive to a map refresh or a toggle change.
        -- The old sleep used the user steal gap (up to 10s), which made a
        -- perfectly valid re-enable look dead until the script was rerun.
        local bossStatus = tostring(eventState.boss.status or "")
        local bossMovementLive = eventState.boss.enabled == true
            and (LP:GetAttribute("InBossArena") == true
                or bossStatus == "starting"
                or bossStatus == "joining"
                or bossStatus == "fighting"
                or bossStatus == "leaving")
        local fastAutomationLive = autoStealEnabled == true
            or autoTreadmillEnabled == true
            or eventState.rift.enabled == true
        local interval = bossMovementLive and 0.10
            or (fastAutomationLive and 0.12
                or math.min(0.25, tonumber(stealDelay) or 0.25))
        if HUB.AutomationWakeEpoch ~= wakeEpoch then interval = 0.05 end
        task.wait(interval)
    end
end)

-- 2. Auto Hatch & Auto Plant Loop
task.spawn(function()
    while not HUB.dead do
        local movementFree = not automationActionBusy
            and (not HUB.MovementLease or HUB.MovementLease.owner == nil)
            and not carryingEggReturnActive
            and not isPlayerCarryingEgg()
        if autoHatchEnabled and movementFree then
            pcall(HatchAllReadyEggs)
        end
        -- Auto Place is a lower-priority maintenance action.  It must not
        -- start a base return while Auto Steal/Rift/Boss is selecting or
        -- carrying a target, and it now takes the same movement lease as the
        -- unified controller so a one-frame race cannot park the character at
        -- the plot.
        if autoPlantEnabled and movementFree
            and not HUB.AutoStealMovementActive
            and not treadmillTrainingActive
            and not HUB.IsDoubleSpeedVisible()
            and not (eventState and eventState.rift and eventState.rift.enabled)
            and not (type(HUB.IsRiftMovementActive) == "function" and HUB.IsRiftMovementActive())
            and not IsRiftBossPriorityActive() then
            if HUB.AcquireMovementLease("plant") then
                automationActionBusy = true
                HUB.AutomationBusyAt = os.clock()
                pcall(function() PlantAllCarriedEggsInPen(true) end)
                automationActionBusy = false
                HUB.AutomationBusyAt = 0
                HUB.ReleaseMovementLease("plant")
            end
        end
        task.wait(hatchCheckDelay)
    end
end)

-- 3. Base, Homestead, Sales & Event Upgrades Loop
task.spawn(function()
    while not HUB.dead do
        if autoUpgradeBase then
            pcall(function()
                if UpgradeHomesteadBase() then task.wait(0.35) end
            end)
        end
        if autoUpgradeTreadmill then
            pcall(function()
                if UpgradeTreadmillTier() then task.wait(0.35) end
            end)
        end
        if autoBuyTrails then pcall(HUB.BuyAffordableTrails) end
        if autoEquipBestPets then pcall(HUB.EquipBestPets) end
        if autoClaimRewards then pcall(HUB.ClaimAllAvailableRewards) end
        if autoClaimMonsterChests then pcall(HUB.ClaimMonsterChests) end
        -- Monster feeding has a travel leg.  Treat it like every other
        -- movement action; otherwise its return-to-previous-position CFrame
        -- can race the Suji worker and leave the character at Plot/Base.
        if autoFeedMonster
            and not automationActionBusy
            and (not HUB.MovementLease or HUB.MovementLease.owner == nil)
            and not carryingEggReturnActive
            and not isPlayerCarryingEgg()
            and not autoStealEnabled
            and not IsRiftBossPriorityActive()
            and not (type(HUB.IsRiftMovementActive) == "function" and HUB.IsRiftMovementActive())
            and HUB.AcquireMovementLease("monster") then
            automationActionBusy = true
            HUB.AutomationBusyAt = os.clock()
            pcall(HUB.FeedMonsterParasite)
            automationActionBusy = false
            HUB.AutomationBusyAt = 0
            HUB.ReleaseMovementLease("monster")
        end
        if autoSellPets then pcall(HUB.SellSelectedPets) end
        if autoSellEggs then pcall(HUB.SellSelectedEggs) end
        task.wait(2.5)
    end
end)

-- 4. Bat / Slap Aura Loop
task.spawn(function()
    local batRe = GetNetRemote("RE/BatSwing/Trigger")
    while not HUB.dead do
        if batAuraEnabled and batRe then
            local hrp = findHRP()
            if hrp then
                local foundNearby = false
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LP and p.Character then
                        local oHrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if oHrp and (oHrp.Position - hrp.Position).Magnitude <= batAuraRadius then
                            foundNearby = true
                            break
                        end
                    end
                end
                if foundNearby then
                    pcall(function() batRe:FireServer() end)
                end
            end
        end
        task.wait(batAuraDelay)
    end
end)

-- 5. Trap Neutralizer Loop
task.spawn(function()
    local debris = Workspace:FindFirstChild("__DEBRIS")
    if debris then
        track(debris.ChildAdded:Connect(function(child)
            if avoidTrapsEnabled and child.Name == "PlayerTrap" then
                task.wait(0.05)
                if child:GetAttribute("Owner") ~= LP.Name then
                    if child:IsA("BasePart") then child.CanTouch = false end
                    for _, c in ipairs(child:GetChildren()) do
                        if c:IsA("BasePart") then c.CanTouch = false end
                    end
                end
            end
        end))
    end

    while not HUB.dead do
        if avoidTrapsEnabled or autoStealEnabled then
            pcall(NeutralizeTraps)
        end
        task.wait(1.5)
    end
end)

-- ==============================================================================
-- VISUALS & ESP
-- ==============================================================================
-- Keep the ESP state global so the executor's main chunk does not allocate
-- another local register after the 200-register limit has been reached.
esp = {
    enabled         = false,
    eggs            = true,
    traps           = false,
    players         = false,
    guards          = false,
    rareEggsOnly    = false,
    showPetIcons    = true,
    maxDistance     = 800,

    eggColor        = Color3.fromRGB(255, 200, 50),
    rareEggColor    = Color3.fromRGB(255, 60, 220),
    trapColor       = Color3.fromRGB(255, 60, 60),
    playerColor     = Color3.fromRGB(100, 220, 100),
    guardColor      = Color3.fromRGB(255, 60, 60),
}

-- Keep ESP runtime bookkeeping in one table.  Luau allocates every top-level
-- local in the main chunk; grouping these related values avoids the 200-local
-- register limit on executors while preserving the same behavior.
espRuntime = {
    hasDrawing = type(Drawing) == "table" and type(Drawing.new) == "function",
    trackedObjects = {},
    billboards = {},
    container = nil,
}

function HUB.GetEspContainer()
    if espRuntime.container and espRuntime.container.Parent then return espRuntime.container end
    local p = nil
    pcall(function() p = (gethui and gethui()) end)
    if not p then pcall(function() p = game:GetService("CoreGui") end) end
    if not p then p = LP:FindFirstChild("PlayerGui") or Workspace end

    pcall(function()
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("Folder") and c.Name == "SAE_Esp_Holder" then c:Destroy() end
        end
    end)
    espRuntime.container = Instance.new("Folder")
    espRuntime.container.Name = "SAE_Esp_Holder"
    pcall(function() espRuntime.container.Parent = p end)
    return espRuntime.container
end

function HUB.UpdateEggBillboard(key, pos, icon)
    local bb = espRuntime.billboards[key]
    if not bb or not bb.gui or not bb.gui.Parent then
        local holder = HUB.GetEspContainer()
        local part = Instance.new("Part")
        part.Name = "EspAnchor"
        part.Size = Vector3.new(1, 1, 1)
        part.Transparency = 1
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.CFrame = CFrame.new(pos)
        part.Parent = holder

        local gui = Instance.new("BillboardGui")
        gui.Name = "EggIconBillboard"
        gui.Adornee = part
        gui.Size = UDim2.fromOffset(28, 28)
        gui.StudsOffset = Vector3.new(-2.2, 1.2, 0)
        gui.AlwaysOnTop = true
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.Parent = part

        local img = Instance.new("ImageLabel")
        img.Name = "PetImage"
        img.Size = UDim2.fromScale(1, 1)
        img.BackgroundTransparency = 1
        img.ScaleType = Enum.ScaleType.Fit
        img.Image = icon or ""
        img.Parent = gui

        bb = {
            part = part,
            gui = gui,
            img = img
        }
        espRuntime.billboards[key] = bb
    else
        bb.part.CFrame = CFrame.new(pos)
        bb.img.Image = icon or ""
        bb.gui.Enabled = (icon ~= nil and icon ~= "")
    end
    return bb
end

function HUB.CreateDrawingObject()
    if not espRuntime.hasDrawing then return {} end
    local o = {}
    o.name = trackDrawing(Drawing.new("Text"))
    o.name.Size = 13; o.name.Center = true; o.name.Outline = true; o.name.Visible = false

    o.dist = trackDrawing(Drawing.new("Text"))
    o.dist.Size = 11; o.dist.Center = true; o.dist.Outline = true; o.dist.Visible = false

    o.box = trackDrawing(Drawing.new("Square"))
    o.box.Thickness = 1.5; o.box.Filled = false; o.box.Visible = false

    return o
end

track(RunService.RenderStepped:Connect(function()
    if HUB.dead or not esp.enabled then
        for _, obj in pairs(espRuntime.trackedObjects) do
            if obj.name then obj.name.Visible = false end
            if obj.dist then obj.dist.Visible = false end
            if obj.box then obj.box.Visible = false end
        end
        for _, bb in pairs(espRuntime.billboards) do
            if bb.gui then bb.gui.Enabled = false end
        end
        return
    end

    local hrp = findHRP()
    local myPos = hrp and hrp.Position or Vector3.zero
    local renderItems = {}
    local activeBbKeys = {}

    -- Eggs ESP
    if esp.eggs and EggState and EggState.ReadFieldEggs then
        local ok, snap = pcall(EggState.ReadFieldEggs)
        if ok and snap and snap.Records then
            for _, egg in ipairs(snap.Records) do
                if egg.State == "Slot" and egg.BoundsCFrame then
                    local pos = egg.BoundsCFrame.Position
                    local dist = (pos - myPos).Magnitude
                    if esp.maxDistance <= 0 or dist <= esp.maxDistance then
                        local muts = egg.Mutations or {}
                        local isRare = #muts > 0
                        if not esp.rareEggsOnly or isRare then
                            local mutText = isRare and (" [" .. table.concat(muts, ",") .. "]") or ""
                            local rName = HUB.GetEggRarityInfo(egg)
                            local label = (egg.AssetCategory or "Egg") .. " (" .. rName .. ")" .. mutText
                            local cat = egg.AssetCategory
                            local aInfo = AssetsData and (AssetsData.Directory or AssetsData) and (AssetsData.Directory or AssetsData)[cat]
                            local petIcon = aInfo and (aInfo.Icon or (aInfo.Egg and aInfo.Egg.Icon)) or ""

                            local itemColor = isRare and esp.rareEggColor or esp.eggColor

                            table.insert(renderItems, {
                                Key = egg.Uid,
                                Pos = pos,
                                Name = label,
                                Color = itemColor,
                                Dist = dist,
                            })

                            if esp.showPetIcons and petIcon ~= "" then
                                activeBbKeys[egg.Uid] = true
                                HUB.UpdateEggBillboard(egg.Uid, pos, petIcon)
                            end
                        end
                    end
                end
            end
        end
    end

    -- Traps ESP
    if esp.traps then
        local debris = Workspace:FindFirstChild("__DEBRIS")
        if debris then
            for _, trap in ipairs(debris:GetChildren()) do
                if trap.Name == "PlayerTrap" and trap:IsA("BasePart") then
                    local pos = trap.Position
                    local dist = (pos - myPos).Magnitude
                    if esp.maxDistance <= 0 or dist <= esp.maxDistance then
                        local owner = trap:GetAttribute("Owner") or "Enemy"
                        table.insert(renderItems, {
                            Key = trap,
                            Pos = pos + Vector3.new(0, 1.5, 0),
                            Name = "[TRAP] @" .. owner,
                            Color = esp.trapColor,
                            Dist = dist,
                        })
                    end
                end
            end
        end
    end

    -- Players ESP
    if esp.players then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                local oHrp = p.Character:FindFirstChild("HumanoidRootPart")
                if oHrp then
                    local dist = (oHrp.Position - myPos).Magnitude
                    if esp.maxDistance <= 0 or dist <= esp.maxDistance then
                        table.insert(renderItems, {
                            Key = p,
                            Pos = oHrp.Position,
                            Name = p.DisplayName .. " (@" .. p.Name .. ")",
                            Color = esp.playerColor,
                            Dist = dist,
                        })
                    end
                end
            end
        end
    end

    -- Hide unreferenced billboards
    for k, bb in pairs(espRuntime.billboards) do
        if not activeBbKeys[k] and bb.gui then
            bb.gui.Enabled = false
        end
    end

    local cam = GetCamera()
    local activeKeys = {}
    for _, item in ipairs(renderItems) do
        activeKeys[item.Key] = true
        local obj = espRuntime.trackedObjects[item.Key]
        if not obj then
            obj = HUB.CreateDrawingObject()
            espRuntime.trackedObjects[item.Key] = obj
        end

        local screenPos, onScreen = nil, false
        if cam then
            screenPos, onScreen = cam:WorldToViewportPoint(item.Pos)
        end
        if onScreen and espRuntime.hasDrawing and screenPos then
            if obj.name then
                obj.name.Text = item.Name
                obj.name.Position = Vector2.new(screenPos.X, screenPos.Y - 14)
                obj.name.Color = item.Color
                obj.name.Visible = true
            end
            if obj.dist then
                obj.dist.Text = math.floor(item.Dist) .. " studs"
                obj.dist.Position = Vector2.new(screenPos.X, screenPos.Y + 2)
                obj.dist.Color = Color3.fromRGB(220, 220, 220)
                obj.dist.Visible = true
            end
        else
            if obj.name then obj.name.Visible = false end
            if obj.dist then obj.dist.Visible = false end
            if obj.box then obj.box.Visible = false end
        end
    end

    for k, obj in pairs(espRuntime.trackedObjects) do
        if not activeKeys[k] then
            if obj.name then obj.name.Visible = false end
            if obj.dist then obj.dist.Visible = false end
            if obj.box then obj.box.Visible = false end
        end
    end
end))

-- Fullbright
HUB.fullbrightState = {
    enabled = false,
    ambient = Lighting.Ambient,
    outdoor = Lighting.OutdoorAmbient,
    brightness = Lighting.Brightness,
    clockTime = Lighting.ClockTime,
}

-- Keep movement helpers global so the large top-level chunk stays below Luau's
-- 200-local-register limit. They are only called by this script's UI callbacks.
function SetFullbright(v)
    HUB.fullbrightState.enabled = v
    if v then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
    else
        Lighting.Ambient = HUB.fullbrightState.ambient
        Lighting.OutdoorAmbient = HUB.fullbrightState.outdoor
        Lighting.Brightness = HUB.fullbrightState.brightness
        Lighting.ClockTime = HUB.fullbrightState.clockTime
    end
end

-- ==============================================================================
-- MOVEMENT & PLAYER MODIFIERS
-- ==============================================================================
HUB.movementState = {
    walkSpeedEnabled = false,
    walkSpeed = 24,
    jumpPowerEnabled = false,
    jumpPower = 60,
    infiniteJump = false,
    flying = false,
    flySpeed = 60,
    antiAFK = false,
    antiAfkConn = nil,
}

function ApplyWalkSpeed(v)
    HUB.movementState.walkSpeed = v
    local hum = findHum()
    if hum and HUB.movementState.walkSpeedEnabled then hum.WalkSpeed = v end
end

function ApplyJumpPower(v)
    HUB.movementState.jumpPower = v
    local hum = findHum()
    if hum and HUB.movementState.jumpPowerEnabled then
        hum.UseJumpPower = true
        hum.JumpPower = v
    end
end

track(RunService.Stepped:Connect(function()
    if HUB.dead then return end
    local hum = findHum()
    if hum then
        if HUB.movementState.walkSpeedEnabled then hum.WalkSpeed = HUB.movementState.walkSpeed end
        if HUB.movementState.jumpPowerEnabled then hum.UseJumpPower = true; hum.JumpPower = HUB.movementState.jumpPower end
    end
end))

track(UserInputService.JumpRequest:Connect(function()
    if HUB.dead then return end
    local hum = findHum()
    if hum then
        hum.Jump = true
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end))

function startFly()
    if HUB.movementState.flying then return true end
    if (type(HUB.HasMovementAutomationIntent) == "function"
            and HUB.HasMovementAutomationIntent())
        or (type(HUB.CanMovementOwnerProceed) == "function"
            and type(HUB.BossMovementOwnsCharacter) == "function"
            and HUB.BossMovementOwnsCharacter())
        or (type(IsRiftBossPriorityActive) == "function" and IsRiftBossPriorityActive()) then
        return false
    end
    local hrp = findHRP()
    local hum = findHum()
    if not (hrp and hum) then return false end
    if not HUB.AcquireMovementLease("manual-fly") then return false end
    HUB._flyMovementLease = true
    HUB.movementState.flying = true
    local flyState = { hrp = hrp }
    HUB._fly = flyState
    local setupOk = pcall(function()
        hrp.Anchored = true
        local bodyGyro = Instance.new("BodyGyro")
        bodyGyro.MaxTorque = Vector3.new(1, 1, 1) * 1e5
        bodyGyro.P = 1e5
        bodyGyro.CFrame = hrp.CFrame
        bodyGyro.Parent = hrp
        flyState.gyro = bodyGyro
        flyState.conn = track(RunService.RenderStepped:Connect(function(dt)
            if not HUB.movementState.flying then return end
            if HUB.dead or not hrp.Parent or findHRP() ~= hrp then
                stopFly()
                return
            end
            if (type(HUB.CanMovementOwnerProceed) == "function"
                    and not HUB.CanMovementOwnerProceed("manual-fly"))
                or (type(HUB.HasMovementAutomationIntent) == "function"
                    and HUB.HasMovementAutomationIntent())
                or (type(IsRiftBossPriorityActive) == "function" and IsRiftBossPriorityActive()) then
                stopFly()
                Notify("Fly", "Paused to avoid movement conflict", "Info")
                return
            end
            if HUB.MovementLease and HUB.MovementLease.owner == "manual-fly" then
                HUB.MovementLease.lastAt = os.clock()
            end
            local cam = GetCamera()
            if not cam then return end
            local look = cam.CFrame.LookVector
            local right = cam.CFrame.RightVector
            local flatLook = Vector3.new(look.X, 0, look.Z)
            flatLook = flatLook.Magnitude > 0.001 and flatLook.Unit or Vector3.new(0, 0, -1)
            local flatRight = Vector3.new(right.X, 0, right.Z)
            flatRight = flatRight.Magnitude > 0.001 and flatRight.Unit or Vector3.new(1, 0, 0)

            local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + flatLook end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - flatLook end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - flatRight end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + flatRight end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end

            if dir.Magnitude > 0 then
                hrp.CFrame = hrp.CFrame + dir.Unit * HUB.movementState.flySpeed * math.min(dt, 0.1)
            end
            bodyGyro.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + look)
        end))
    end)
    if not setupOk then
        stopFly()
        return false
    end
    return true
end

function stopFly()
    HUB.movementState.flying = false
    local f = HUB._fly
    if f then
        pcall(function() f.conn:Disconnect() end)
        pcall(function() f.hrp.Anchored = false end)
        pcall(function() f.gyro:Destroy() end)
        HUB._fly = nil
    end
    if HUB._flyMovementLease then
        HUB._flyMovementLease = false
        pcall(HUB.ReleaseMovementLease, "manual-fly")
    end
end

function SetAntiAFK(v)
    HUB.movementState.antiAFK = v
    if v and not HUB.movementState.antiAfkConn then
        HUB.movementState.antiAfkConn = track(LocalPlayer.Idled:Connect(function()
            if HUB.movementState.antiAFK then
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end
        end))
    elseif not v and HUB.movementState.antiAfkConn then
        pcall(function() HUB.movementState.antiAfkConn:Disconnect() end)
        HUB.movementState.antiAfkConn = nil
    end
end

-- ==============================================================================
-- UI CREATION - MAIN TABS
-- ==============================================================================
(function()
local EggsTab     = Window:AddTab({ Name = "Eggs", Subtitle = "Steal, hatch & plant", Icon = "crown" })
local BaseTab     = Window:AddTab({ Name = "Base", Subtitle = "Homestead & training", Icon = "bolt" })
local CombatTab   = Window:AddTab({ Name = "Combat", Subtitle = "Bat, slaps & defense", Icon = "combat" })
local PlayerTab   = Window:AddTab({ Name = "Player", Subtitle = "Movement & teleports", Icon = "player" })
local SettingsTab = Window:AddTab({ Name = "Settings", Subtitle = "Configs & unloader", Icon = "gear" })
local ServerTab   = Window:AddTab({ Name = "Server", Subtitle = "Server hop", Icon = "globe" })



-- -----------------------------------------------------------------------------
-- SERVER HOP DYNAMIC ISLAND GUI
-- -----------------------------------------------------------------------------
do
    function HUB.OpenServerHopGui()
        local existing = HUB.ServerHopGuiInstance
        if existing and existing.Parent then
            return existing
        end

        local services = {
            Players = Players,
            TeleportService = TeleportService,
            HttpService = game:GetService("HttpService"),
            CoreGui = game:GetService("CoreGui"),
            TweenService = game:GetService("TweenService"),
        }

        local Theme = {
            Background = Color3.fromRGB(15, 15, 17),
            Panel = Color3.fromRGB(24, 24, 26),
            AccentLightYellow = Color3.fromRGB(252, 233, 158),
            AccentMuted = Color3.fromRGB(180, 165, 110),
            TextMain = Color3.fromRGB(250, 250, 250),
            TextSub = Color3.fromRGB(170, 170, 170),
            RedCancel = Color3.fromRGB(180, 60, 60),
            GreenActive = Color3.fromRGB(252, 233, 158),
        }

        local gui = Instance.new("ScreenGui")
        gui.Name = "AxelHubServerHop"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        pcall(function() gui.Parent = services.CoreGui end)
        if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
        HUB.ServerHopGuiInstance = gui

        local islandScale = Instance.new("UIScale")
        local island = Instance.new("Frame")
        island.Name = "IslandFrame"
        island.Size = UDim2.new(0, 220, 0, 48)
        island.Position = UDim2.new(0.5, -110, 0, 16)
        island.BackgroundColor3 = Theme.Background
        island.BorderSizePixel = 0
        island.Active = true
        island.Draggable = true
        island.ClipsDescendants = true
        island.Parent = gui
        islandScale.Parent = island
        local function resizeIslandForViewport()
            local camera = GetCamera()
            local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
            local touchOnly = UserInputService.TouchEnabled == true and UserInputService.KeyboardEnabled ~= true
            local scale = touchOnly and math.min((viewport.X - 24) / 400, (viewport.Y - 116) / 520) or 1
            islandScale.Scale = math.clamp(scale, 0.72, 1)
        end
        resizeIslandForViewport()
        local camera = GetCamera()
        if camera then track(camera:GetPropertyChangedSignal("ViewportSize"):Connect(resizeIslandForViewport)) end

        local islandCorner = Instance.new("UICorner")
        islandCorner.CornerRadius = UDim.new(1, 0)
        islandCorner.Parent = island
        local islandGlow = Instance.new("UIStroke")
        islandGlow.Color = Theme.AccentLightYellow
        islandGlow.Transparency = 0.2
        islandGlow.Thickness = 1.5
        islandGlow.Parent = island

        local topBar = Instance.new("Frame")
        topBar.Size = UDim2.new(1, 0, 0, 48)
        topBar.BackgroundTransparency = 1
        topBar.Parent = island

        local avatar = Instance.new("ImageLabel")
        avatar.Size = UDim2.new(0, 32, 0, 32)
        avatar.Position = UDim2.new(0, 10, 0.5, -16)
        avatar.BackgroundTransparency = 1
        avatar.Image = "rbxassetid://86949082023913"
        avatar.Parent = topBar
        Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -95, 1, 0)
        title.Position = UDim2.new(0, 50, 0, 0)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.Text = "Axel Hub Hop"
        title.TextColor3 = Theme.AccentLightYellow
        title.TextSize = 14
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = topBar

        local toggle = Instance.new("TextButton")
        toggle.Size = UDim2.new(0, 32, 0, 32)
        toggle.Position = UDim2.new(1, -38, 0.5, -16)
        toggle.BackgroundColor3 = Theme.Panel
        toggle.BorderSizePixel = 0
        toggle.Font = Enum.Font.GothamBold
        toggle.Text = "+"
        toggle.TextColor3 = Theme.AccentLightYellow
        toggle.TextSize = 18
        toggle.Parent = topBar
        Instance.new("UICorner", toggle).CornerRadius = UDim.new(1, 0)

        local content = Instance.new("Frame")
        content.Size = UDim2.new(1, -24, 1, -64)
        content.Position = UDim2.new(0, 12, 0, 54)
        content.BackgroundColor3 = Theme.Background
        content.BorderSizePixel = 0
        content.Visible = false
        content.Parent = island

        local info = Instance.new("Frame")
        info.Size = UDim2.new(1, 0, 0, 115)
        info.BackgroundColor3 = Theme.Panel
        info.BorderSizePixel = 0
        info.Parent = content
        Instance.new("UICorner", info).CornerRadius = UDim.new(0, 12)
        local infoStroke = Instance.new("UIStroke")
        infoStroke.Color = Theme.AccentMuted
        infoStroke.Thickness = 1
        infoStroke.Parent = info

        local infoList = Instance.new("UIListLayout")
        infoList.SortOrder = Enum.SortOrder.LayoutOrder
        infoList.Padding = UDim.new(0, 6)
        infoList.HorizontalAlignment = Enum.HorizontalAlignment.Center
        infoList.Parent = info
        local infoPad = Instance.new("UIPadding")
        infoPad.PaddingTop = UDim.new(0, 12)
        infoPad.PaddingLeft = UDim.new(0, 12)
        infoPad.PaddingRight = UDim.new(0, 12)
        infoPad.Parent = info

        local function createTextRow(textStr)
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 0, 20)
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.GothamMedium
            label.Text = textStr
            label.TextColor3 = Theme.TextSub
            label.TextSize = 12
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Parent = info
        end
        createTextRow("🌟 Target: Best Ping Server")
        createTextRow("🛡️ Safe & Undetected Hop")
        createTextRow("✨ Powered by Axel Hub")

        local jobRow = Instance.new("Frame")
        jobRow.Size = UDim2.new(1, 0, 0, 36)
        jobRow.Position = UDim2.new(0, 0, 0, 127)
        jobRow.BackgroundTransparency = 1
        jobRow.Parent = content

        local jobInput = Instance.new("TextBox")
        jobInput.Size = UDim2.new(0.68, 0, 1, 0)
        jobInput.Position = UDim2.new(0, 0, 0, 0)
        jobInput.BackgroundColor3 = Theme.Panel
        jobInput.BorderSizePixel = 0
        jobInput.Font = Enum.Font.GothamMedium
        jobInput.PlaceholderText = "Enter Job ID ..."
        jobInput.Text = ""
        jobInput.TextColor3 = Theme.TextMain
        jobInput.PlaceholderColor3 = Theme.TextSub
        jobInput.TextSize = 12
        jobInput.ClearTextOnFocus = false
        jobInput.Parent = jobRow
        Instance.new("UICorner", jobInput).CornerRadius = UDim.new(0, 10)
        local jobInputStroke = Instance.new("UIStroke")
        jobInputStroke.Color = Theme.AccentMuted
        jobInputStroke.Parent = jobInput

        local joinJobButton = Instance.new("TextButton")
        joinJobButton.Size = UDim2.new(0.30, 0, 1, 0)
        joinJobButton.Position = UDim2.new(0.70, 0, 0, 0)
        joinJobButton.BackgroundColor3 = Theme.Panel
        joinJobButton.BorderSizePixel = 0
        joinJobButton.Font = Enum.Font.GothamBold
        joinJobButton.Text = "Join Job ID"
        joinJobButton.TextColor3 = Theme.AccentLightYellow
        joinJobButton.TextSize = 12
        joinJobButton.Parent = jobRow
        Instance.new("UICorner", joinJobButton).CornerRadius = UDim.new(0, 10)
        local joinJobStroke = Instance.new("UIStroke")
        joinJobStroke.Color = Theme.AccentLightYellow
        joinJobStroke.Parent = joinJobButton

        local buttons = Instance.new("Frame")
        buttons.Size = UDim2.new(1, 0, 0, 36)
        buttons.Position = UDim2.new(0, 0, 0, 173)
        buttons.BackgroundTransparency = 1
        buttons.Parent = content

        local function makeButton(text, x, width)
            local button = Instance.new("TextButton")
            button.Size = UDim2.new(width or 0.23, 0, 1, 0)
            button.Position = UDim2.new(x, 0, 0, 0)
            button.BackgroundColor3 = Theme.Panel
            button.BorderSizePixel = 0
            button.Font = Enum.Font.GothamBold
            button.Text = text
            button.TextColor3 = Theme.TextMain
            button.TextSize = 11
            button.Parent = buttons
            Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)
            local stroke = Instance.new("UIStroke")
            stroke.Color = Theme.AccentMuted
            stroke.Parent = button
            return button, stroke
        end

        local resetButton = makeButton("Refresh", 0, 0.23)
        local rejoinButton = makeButton("Rejoin", 0.255, 0.23)
        local fewestButton = makeButton("Fewest", 0.51, 0.23)
        local autoButton, autoStroke = makeButton("Auto: OFF", 0.765, 0.235)
        autoButton.TextColor3 = Theme.RedCancel
        autoStroke.Color = Theme.RedCancel

        local listContainer = Instance.new("Frame")
        listContainer.Size = UDim2.new(1, 0, 1, -221)
        listContainer.Position = UDim2.new(0, 0, 0, 221)
        listContainer.BackgroundColor3 = Theme.Panel
        listContainer.BorderSizePixel = 0
        listContainer.Parent = content
        Instance.new("UICorner", listContainer).CornerRadius = UDim.new(0, 12)
        local listStroke = Instance.new("UIStroke")
        listStroke.Color = Theme.AccentMuted
        listStroke.Parent = listContainer

        local list = Instance.new("ScrollingFrame")
        list.Size = UDim2.new(1, -16, 1, -16)
        list.Position = UDim2.new(0, 8, 0, 8)
        list.BackgroundTransparency = 1
        list.BorderSizePixel = 0
        list.CanvasSize = UDim2.new(0, 0, 0, 0)
        list.ScrollBarThickness = 3
        list.ScrollBarImageColor3 = Theme.AccentLightYellow
        list.Parent = listContainer
        local listLayout = Instance.new("UIListLayout")
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Padding = UDim.new(0, 6)
        listLayout.Parent = list

        local notifyFrame = Instance.new("Frame")
        notifyFrame.Size = UDim2.new(0, 260, 0, 45)
        notifyFrame.Position = UDim2.new(0, 16, 1, 80)
        notifyFrame.BackgroundColor3 = Theme.Background
        notifyFrame.BorderSizePixel = 0
        notifyFrame.Parent = gui
        Instance.new("UIStroke", notifyFrame).Color = Theme.AccentLightYellow
        Instance.new("UICorner", notifyFrame).CornerRadius = UDim.new(0, 12)
        local notifyLabel = Instance.new("TextLabel")
        notifyLabel.Size = UDim2.new(1, -24, 1, 0)
        notifyLabel.Position = UDim2.new(0, 12, 0, 0)
        notifyLabel.BackgroundTransparency = 1
        notifyLabel.Font = Enum.Font.GothamMedium
        notifyLabel.Text = ""
        notifyLabel.TextColor3 = Theme.AccentLightYellow
        notifyLabel.TextSize = 13
        notifyLabel.TextXAlignment = Enum.TextXAlignment.Left
        notifyLabel.Parent = notifyFrame

        local servers = {}
        local expanded = false

        local function notifyLeft(text)
            notifyLabel.Text = tostring(text)
            services.TweenService:Create(notifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, 16, 1, -60)
            }):Play()
            task.delay(3, function()
                if notifyFrame.Parent then
                    services.TweenService:Create(notifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                        Position = UDim2.new(0, 16, 1, 80)
                    }):Play()
                end
            end)
        end

        local function getHopServers()
            servers = {}
            local cursor = ""
            local fetchedCount = 0
            for _ = 1, 5 do
                local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100"
                if cursor ~= "" then url = url .. "&cursor=" .. services.HttpService:UrlEncode(cursor) end
                local body = HUB.ServerHopRequest(url)
                if not body then break end
                local ok, data = pcall(services.HttpService.JSONDecode, services.HttpService, body)
                if not ok or type(data) ~= "table" then break end
                for _, server in ipairs(data.data or {}) do
                    local id = tostring(server.id or "")
                    local playing = tonumber(server.playing) or 0
                    local maxPlayers = tonumber(server.maxPlayers) or 0
                    if id ~= "" and id ~= tostring(game.JobId) and playing < maxPlayers then
                        servers[#servers + 1] = {id = id, playing = playing, maxPlayers = maxPlayers}
                        fetchedCount += 1
                        if fetchedCount >= 100 then break end
                    end
                end
                cursor = tostring(data.nextPageCursor or "")
                if cursor == "" or fetchedCount >= 100 then break end
            end
        end

        local function joinFewestServer()
            if #servers == 0 then
                getHopServers()
            end
            local target = nil
            for _, server in ipairs(servers) do
                if type(server) == "table" and server.id then
                    if not target or (tonumber(server.playing) or math.huge) < (tonumber(target.playing) or math.huge) then
                        target = server
                    end
                end
            end
            if not target then
                notifyLeft("No open server found")
                return false
            end
            notifyLeft("Fewest Server · " .. tostring(target.playing) .. "/" .. tostring(target.maxPlayers))
            local ok, err = HUB.ManualJoinServer(game.PlaceId, target.id)
            if not ok then
                notifyLeft("Fewest Server failed")
            end
            return ok
        end

        local function rebuildList()
            for _, child in ipairs(list:GetChildren()) do
                if child:IsA("Frame") then child:Destroy() end
            end
            for i, server in ipairs(servers) do
                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, -8, 0, 42)
                row.BackgroundColor3 = Theme.Background
                row.BorderSizePixel = 0
                row.Parent = list
                Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
                local rowStroke = Instance.new("UIStroke")
                rowStroke.Color = Theme.AccentMuted
                rowStroke.Transparency = 0.45
                rowStroke.Parent = row

                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, -82, 1, 0)
                label.Position = UDim2.new(0, 12, 0, 0)
                label.BackgroundTransparency = 1
                label.Font = Enum.Font.GothamMedium
                label.Text = "Server " .. tostring(i) .. " · " .. tostring(server.playing) .. "/" .. tostring(server.maxPlayers)
                label.TextColor3 = Theme.TextMain
                label.TextSize = 12
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Parent = row

                local join = Instance.new("TextButton")
                join.Size = UDim2.new(0, 60, 0, 26)
                join.Position = UDim2.new(1, -68, 0.5, -13)
                join.BackgroundColor3 = Theme.Panel
                join.BorderSizePixel = 0
                join.Font = Enum.Font.GothamBold
                join.Text = "Join"
                join.TextColor3 = Theme.AccentLightYellow
                join.TextSize = 12
                join.Parent = row
                Instance.new("UICorner", join).CornerRadius = UDim.new(0, 8)
                local joinStroke = Instance.new("UIStroke")
                joinStroke.Color = Theme.AccentLightYellow
                joinStroke.Parent = join

                join.Activated:Connect(function()
                    notifyLeft("Joining Safe Server...")
                    HUB.ManualJoinServer(game.PlaceId, server.id)
                end)
            end
            list.CanvasSize = UDim2.new(0, 0, 0, math.max(0, #servers * 48))
        end

        joinJobButton.Activated:Connect(function()
            local jobId = tostring(jobInput.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if jobId == "" then
                notifyLeft("Enter a Job ID first")
                return
            end
            notifyLeft("Joining Job ID...")
            task.spawn(function()
                local ok, err = HUB.ManualJoinServer(game.PlaceId, jobId)
                if not ok then
                    notifyLeft("Join failed: " .. tostring(err or "unknown error"))
                end
            end)
        end)

        fewestButton.Activated:Connect(function()
            notifyLeft("Scanning Fewest Server...")
            task.spawn(function()
                getHopServers()
                joinFewestServer()
            end)
        end)

        resetButton.Activated:Connect(function()
            notifyLeft("Scanning Safe Servers...")
            task.spawn(function()
                getHopServers()
                rebuildList()
                notifyLeft("Found " .. tostring(#servers) .. " servers")
            end)
        end)

        rejoinButton.Activated:Connect(function()
            notifyLeft("Rejoining Game...")
            pcall(function()
                services.TeleportService:Teleport(game.PlaceId, LP)
            end)
        end)

        autoButton.Activated:Connect(function()
            local state = HUB.ServerHopState
            state.AutoHop = not state.AutoHop
            state.AutoHopExplicit = state.AutoHop == true
            state.HopPermit = nil
            if state.AutoHop then
                state.AutoEnabledAt = os.clock()
                state.LastHopAt = os.clock()
                autoButton.Text = "Auto: ON"
                autoButton.TextColor3 = Theme.Background
                autoButton.BackgroundColor3 = Theme.GreenActive
                autoStroke.Color = Theme.GreenActive
                notifyLeft("Auto Hop Active · " .. tostring(state.HopDelay) .. "s")
            else
                HUB.ClearNoMatchHopState()
                state.Busy = false
                autoButton.Text = "Auto: OFF"
                autoButton.TextColor3 = Theme.RedCancel
                autoButton.BackgroundColor3 = Theme.Panel
                autoStroke.Color = Theme.RedCancel
                notifyLeft("Auto Hop Inactive")
            end
        end)

        toggle.Activated:Connect(function()
            expanded = not expanded
            if expanded then
                toggle.Text = "-"
                islandCorner.CornerRadius = UDim.new(0, 16)
                services.TweenService:Create(island, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0, 400, 0, 520),
                    Position = UDim2.new(0.5, -200, 0, 16)
                }):Play()
                task.wait(0.05)
                content.Visible = true
            else
                toggle.Text = "+"
                content.Visible = false
                services.TweenService:Create(island, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0, 220, 0, 48),
                    Position = UDim2.new(0.5, -110, 0, 16)
                }):Play()
                task.wait(0.2)
                islandCorner.CornerRadius = UDim.new(1, 0)
            end
        end)

        task.spawn(function()
            getHopServers()
            rebuildList()
            while gui.Parent and not HUB.dead do
                local state = HUB.ServerHopState
                autoButton.Text = state.AutoHop and "Auto: ON" or "Auto: OFF"
                if state.AutoHop then
                    autoButton.TextColor3 = Theme.Background
                    autoButton.BackgroundColor3 = Theme.GreenActive
                    autoStroke.Color = Theme.GreenActive
                else
                    autoButton.TextColor3 = Theme.RedCancel
                    autoButton.BackgroundColor3 = Theme.Panel
                    autoStroke.Color = Theme.RedCancel
                end
                task.wait(0.25)
            end
        end)

        return gui
    end
end

-- -----------------------------------------------------------------------------
-- SERVER TAB
-- -----------------------------------------------------------------------------
do
    local ServerHopSub = ServerTab:AddSubTab("Server Hop")
    local ServerHopStatus = ServerHopSub:AddParagraph({
        Title = "Server Hop",
        Content = "0 hops this session · waiting",
    })

    ServerHopSub:AddToggle({
        Name = "Enable Auto Server Hop",
        Default = false,
        Flag = "server_autohop",
        Callback = safeCallback(function(v)
            local state = HUB.ServerHopState
            state.AutoHop = v == true
            state.AutoHopExplicit = v == true
            state.HopPermit = nil
            state.NoMatchActive = false
            state.MatchFound = false
            if state.AutoHop then
                state.AutoEnabledAt = os.clock()
                state.LastHopAt = os.clock()
            else
                state.Busy = false
            end
            if state.HopCount >= state.MaxHops then
                state.AutoHop = false
            end
        end)
    })

    ServerHopSub:AddToggle({
        Name = "Hop on No Matching Egg",
        Default = false,
        Flag = "server_hop_no_match",
        Callback = function(v)
            HUB.ServerHopState.HopOnNoMatch = v == true
            HUB.ServerHopState.HopPermit = nil
            HUB.ServerHopState.NoMatchActive = false
            HUB.ServerHopState.MatchFound = false
        end,
    })

    ServerHopSub:AddSlider({
        Name = "Max Hops",
        Min = 1,
        Max = 100,
        Default = HUB.ServerHopState.MaxHops,
        Suffix = "",
        Flag = "server_max_hops",
        Callback = function(v)
            HUB.ServerHopState.MaxHops = math.max(1, math.floor(tonumber(v) or 1))
            if HUB.ServerHopState.HopCount >= HUB.ServerHopState.MaxHops then
                HUB.ServerHopState.AutoHop = false
            end
        end,
    })

    ServerHopSub:AddSlider({
        Name = "Check Delay",
        Min = 5,
        Max = 120,
        Default = HUB.ServerHopState.HopDelay,
        Suffix = "s",
        Flag = "server_hop_delay",
        Callback = function(v)
            HUB.ServerHopState.HopDelay = math.max(5, math.floor(tonumber(v) or 5))
        end,
    })

    ServerHopSub:AddButton({
        Name = "Open Axel Hub Server Hop",
        Primary = true,
        Callback = safeCallback(function()
            HUB.OpenServerHopGui()
        end),
    })

    ServerHopSub:AddButton({
        Name = "Server Hop Now",
        Callback = safeCallback(function()
            task.spawn(function()
                local ok, msg = HUB.ManualHopOnce()
                Notify("Server Hop", tostring(msg or (ok and "Teleporting." or "Failed")), ok and "Success" or "Error")
            end)
        end)
    })

    ServerHopSub:AddButton({
        Name = "Rejoin Current Server",
        Callback = safeCallback(function()
            local ok, err = HUB.ManualJoinServer(game.PlaceId, game.JobId)
            if not ok then Notify("Server", tostring(err), "Error") end
        end)
    })

    task.spawn(function()
        while not HUB.dead do
            task.wait(0.5)
            if ServerHopStatus and ServerHopStatus.Set then
                local state = HUB.ServerHopState
                local suffix = state.HopCount == 1 and " hop" or " hops"
                local mode = state.HopOnNoMatch and (state.NoMatchActive and "no-match waiting" or state.MatchFound and "match found" or "no-match armed") or "manual"
                local enabled = state.AutoHop and "on" or "off"
                pcall(ServerHopStatus.Set, ServerHopStatus, enabled .. " · " .. tostring(state.HopCount) .. suffix .. " · " .. mode)
            end
        end
    end)
end

-- -----------------------------------------------------------------------------
-- TAB 1: EGGS
-- -----------------------------------------------------------------------------
local StealSub = EggsTab:AddSubTab("Auto Steal")
local HatchSub = EggsTab:AddSubTab("Auto Hatch & Plant")
local EggEspSub = EggsTab:AddSubTab("Egg Tracker ESP")

-- SubTab: Auto Steal
StealSub:AddToggle({
    Name = "Auto Steal Eggs", Default = false, Flag = "steal_auto",
    Callback = safeCallback(function(v)
        autoStealEnabled = v == true
        HUB.Orchestrator.SetDesired("steal", autoStealEnabled)
        HUB.AutoStealControllerEpoch = (tonumber(HUB.AutoStealControllerEpoch) or 0) + 1
        local carryingNow = false
        pcall(function() carryingNow = isPlayerCarryingEgg() == true end)

        if autoStealEnabled then
            -- Re-enable always starts from a clean Suji scan/route state. If
            -- an egg is already attached, ResetAutoStealState deliberately
            -- preserves the delivery owner until it reaches the base.
            HUB.ResetAutoStealState()
            HUB.RequestAutoStealFilterRefresh()
            -- Keep the outbound and return routes from being blocked by map
            -- collision while Auto Steal owns movement.
            HUB.StartAutoStealNoClip()
        else
            -- Cancel outbound movement and clear every stale Suji owner. A
            -- live carried egg is the one exception: keep no-clip/movement
            -- alive until the current delivery finishes safely.
            HUB.ResetAutoStealState()
            HUB.AutoStealFilterRefreshRequested = false
            -- Wake the central worker immediately after the toggle changes;
            -- waiting for the normal scan interval made Auto Treadmill look
            -- disabled even though its toggle was still on.
            pcall(HUB.WakeAutomation, "Auto Steal disabled")
            if not carryingNow and HUB.Orchestrator and HUB.Orchestrator.owner == "steal" then
                HUB.Orchestrator.End("steal")
            end
            if not carryingNow and HUB.MovementLease and HUB.MovementLease.owner == "auto-steal" then
                HUB.MovementLease.owner, HUB.MovementLease.depth = nil, 0
                HUB.MovementLease.lastAt = os.clock()
            end
            if not carryingNow then
                HUB.StopAutoStealNoClip()
            end
        end
        -- A fresh enable starts a fresh scan cycle.  Do not leave an old
        -- treadmill fallback marked as active after the user toggles Steal.
        if not autoStealEnabled then
            treadmillLastNoMatchAt = 0
            -- Cancel a no-match hop that may already be waiting in the delay
            -- queue. Turning Auto Steal off must never teleport the player.
            local hopState = HUB.ServerHopState
            if hopState then
                hopState.NoMatchActive = false
                hopState.HopPermit = nil
            end
            if not isPlayerCarryingEgg() then
                -- A matching egg is irrelevant while Auto Steal is OFF. The
                -- previous controller left the scheduler at Plot/Base with
                -- treadmillTrainingActive=false and never kicked off the
                -- lower-priority fallback again. Start one clean handoff so
                -- the normal priority loop can return to Auto Treadmill.
                pcall(HUB.ReconcileAutoStealForTreadmill)
                treadmillTrainingActive = false
                treadmillResetRequested = false
                if autoTreadmillEnabled and type(QueueAutoTreadmillResume) == "function" then
                    task.spawn(function()
                        task.wait(0.15)
                        if not autoStealEnabled and autoTreadmillEnabled
                            and not carryingEggReturnActive and not isPlayerCarryingEgg() then
                            pcall(QueueAutoTreadmillResume)
                        end
                    end)
                end
            end
        end
        if autoStealEnabled then
            HUB.EnsureSavedReturnPosition()
            -- Suji dismounts immediately, then lets one worker decide the
            -- next action. Starting a second treadmill coroutine here races
            -- the shared movement owner and can leave the character at Plot.
            if not isPlayerCarryingEgg() then
                pcall(ReleaseTreadmillForAction)
            end
        end
        Notify("Auto Steal", autoStealEnabled and "Enabled" or "Disabled", autoStealEnabled and "Success" or "Error")
    end)
})
StealSub:AddDropdown({
    Name = "Steal Movement Method", Options = { "Fly Glide", "Safe Walk", "Anti Guard", "Teleport" }, Default = "Teleport", Flag = "steal_method",
    Callback = function(v)
        -- Migrate an older saved "Tween Glide" value to the new reference
        -- WARP route instead of silently re-enabling the old travel writer.
        stealMovementMethod = v == "Tween Glide" and "Teleport" or v
    end
})
StealSub:AddToggle({
    Name = "Steal Infested / Parasite Eggs Only", Default = false, Flag = "steal_parasite_only",
    Callback = function(v)
        stealParasiteOnly = v
        Notify("Parasite Eggs", v and "Targeting Infested Eggs Only" or "All Filtered Eggs", v and "Success" or "Info")
    end
})
StealSub:AddToggle({
    Name = "Prioritize Highest Egg Value", Default = true, Flag = "rare_hunter",
    Callback = function(v) rareEggHunter = v end
})
HUB.StealFilterHandles.rarity = StealSub:AddMultiDropdown({
    Name = "Filter by Rarity (Multi-Select)", Options = RARITY_NAMES, Default = {}, Flag = "steal_rarities",
    Callback = function(selectedList)
        HUB.ApplyAutoStealFilterSelection("rarity", selectedList, RARITY_NAMES)
    end
})
registerResync(HUB.StealFilterHandles.rarity, function(selectedList)
    HUB.ApplyAutoStealFilterSelection("rarity", selectedList, RARITY_NAMES)
end)
HUB.StealFilterHandles.area = StealSub:AddMultiDropdown({
    Name = "Filter by Area (Multi-Select)", Options = AREA_NAMES, Default = {}, Flag = "steal_areas",
    Callback = function(selectedList)
        HUB.ApplyAutoStealFilterSelection("area", selectedList, AREA_NAMES)
    end
})
registerResync(HUB.StealFilterHandles.area, function(selectedList)
    HUB.ApplyAutoStealFilterSelection("area", selectedList, AREA_NAMES)
end)
HUB.StealFilterHandles.mutation = StealSub:AddMultiDropdown({
    Name = "Filter by Mutation (Multi-Select)", Options = MUTATION_FILTERS, Default = {}, Flag = "steal_muts",
    Callback = function(selectedList)
        HUB.ApplyAutoStealFilterSelection("mutation", selectedList, MUTATION_FILTERS)
    end
})
registerResync(HUB.StealFilterHandles.mutation, function(selectedList)
    HUB.ApplyAutoStealFilterSelection("mutation", selectedList, MUTATION_FILTERS)
end)
StealSub:AddSlider({
    Name = "Glide / Travel Speed", Min = 50, Max = 1000, Default = 750, Suffix = " studs/s", Flag = "glide_speed",
    Callback = function(v)
        glideSpeed = tonumber(v) or 750
        -- Suji reads one shared speed override for both outbound and carried
        -- return legs. Keep the movement adapter in sync with the UI slider;
        -- otherwise the return silently stayed at its old 600 fallback.
        if HUB.StealGlide then HUB.StealGlide.Speed = glideSpeed end
    end
})
StealSub:AddSlider({
    Name = "Steal Delay Gap", Min = 0.5, Max = 10, Default = 1.5, Suffix = "s", Flag = "steal_gap",
    Callback = function(v) stealDelay = v end
})
StealSub:AddButton({
    Name = "Steal Best Available Egg Once", Primary = true,
    Callback = safeCallback(function()
        local ok = HUB.StealBestEggOnce(true)
        Notify("Steal Egg", ok and "Stealing target egg" or "No matching egg found for selected filters", ok and "Success" or "Info")
    end)
})

-- SubTab: Auto Hatch & Plant
HatchSub:AddToggle({
    Name = "Auto Hatch Ready Eggs", Default = false, Flag = "hatch_auto",
    Callback = safeCallback(function(v)
        autoHatchEnabled = v == true
        HUB.WakeAutomation("Auto Hatch toggle")
        Notify("Auto Hatch", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end)
})
HatchSub:AddToggle({
    Name = "Auto Place Egg (Base Pen)", Default = false, Flag = "plant_auto",
    Callback = function(v)
        autoPlantEnabled = v
        Notify("Auto Place Egg", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end
})
HatchSub:AddSlider({
    Name = "Hatch Check Delay", Min = 0.5, Max = 10, Default = 2.0, Suffix = "s", Flag = "hatch_gap",
    Callback = function(v) hatchCheckDelay = v end
})
HatchSub:AddButton({
    Name = "Hatch All Ready Eggs Now", Primary = true,
    Callback = safeCallback(function()
        local count = HatchAllReadyEggs() or 0
        Notify("Hatch", "Hatched " .. tostring(count) .. " egg(s)", count > 0 and "Success" or "Info")
    end)
})
HatchSub:AddButton({
    Name = "Place Carried Eggs in Pen Now",
    Callback = safeCallback(function()
        local leaseOk, count = HUB.RunManualMovement(function()
            return PlantAllCarriedEggsInPen()
        end)
        if leaseOk then
            Notify("Plant Eggs", "Planted " .. tostring(count or 0) .. " egg(s) in pen", "Success")
        else
            Notify("Plant Eggs", "Movement is busy; try again when the current route finishes", "Info")
        end
    end)
})

-- SubTab: Egg Tracker ESP
EggEspSub:AddToggle({
    Name = "Egg ESP Enabled", Default = false, Flag = "esp_eggs_enabled",
    Callback = safeCallback(function(v)
        esp.enabled = v
        Notify("Egg ESP", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end)
})
EggEspSub:AddToggle({
    Name = "Show 3D Pet Image Badges", Default = true, Flag = "esp_pet_icons",
    Callback = function(v) esp.showPetIcons = v end
})
EggEspSub:AddToggle({
    Name = "Trap ESP (Highlights Enemy Traps)", Default = false, Flag = "esp_traps",
    Callback = function(v) esp.traps = v end
})
EggEspSub:AddToggle({
    Name = "Show Mutated / Rare Eggs Only", Default = false, Flag = "esp_eggs_rare_only",
    Callback = function(v) esp.rareEggsOnly = v end
})
EggEspSub:AddSlider({
    Name = "Max ESP Distance", Min = 100, Max = 2500, Default = 800, Suffix = " studs", Flag = "esp_max_dist",
    Callback = function(v) esp.maxDistance = v end
})

-- -----------------------------------------------------------------------------
-- TAB 2: BASE & UPGRADES
-- -----------------------------------------------------------------------------
do
local UpgradesSub = BaseTab:AddSubTab("Homestead & Treadmill")
local PetsSub     = BaseTab:AddSubTab("Pets & Satchel")
local SalesSub    = BaseTab:AddSubTab("Auto Sell")
local EventsSub   = BaseTab:AddSubTab("Events & Bosses")
local MonsterEventSub = BaseTab:AddSubTab("Monster Parasite Event")
local RewardsSub  = BaseTab:AddSubTab("Claim Rewards")

-- SubTab: Homestead & Treadmill
UpgradesSub:AddToggle({
    Name = "Auto Upgrade Base / Plot", Default = false, Flag = "up_base_auto",
    Callback = function(v) autoUpgradeBase = v end
})
UpgradesSub:AddToggle({
    Name = "Auto Upgrade Treadmill Tier", Default = false, Flag = "up_tread_auto",
    Callback = function(v) autoUpgradeTreadmill = v end
})
UpgradesSub:AddToggle({
    Name = "Auto Treadmill", Default = false, Flag = "auto_treadmill",
    Callback = safeCallback(function(v)
        local enabled = v == true
        treadmillControllerEpoch += 1
        local controllerEpoch = treadmillControllerEpoch
        HUB.Orchestrator.SetDesired("treadmill", enabled)
        if type(HUB.WakeAutomation) == "function" then
            HUB.WakeAutomation(enabled and "Auto Treadmill enabled" or "Auto Treadmill disabled")
        end

        if not enabled then
            -- Hard reset the treadmill controller. The main worker will fall
            -- back to Auto Steal on its next tick, starting a fresh scan cycle.
            autoTreadmillEnabled = false
            treadmillResetRequested = true
            treadmillLastNoMatchAt = 0
            if not isPlayerCarryingEgg() then
                task.spawn(function()
                    HUB.StopTreadmillTraining()
                    -- Do not let an old disable coroutine wipe the state of a
                    -- newer enable that happened during dismounting.
                    if controllerEpoch == treadmillControllerEpoch and not autoTreadmillEnabled then
                        treadmillHandoffBusy = false
                        treadmillResetRequested = false
                    end
                end)
            end
        else
            autoTreadmillEnabled = true
            treadmillResetRequested = false
            treadmillTrainingActive = false
            HUB.TreadmillMounted = false
            treadmillLastNoMatchAt = 0
            if autoStealEnabled then
                HUB.EnsureSavedReturnPosition()
            end
            -- The unified Suji scheduler performs the first handoff on its
            -- next tick. Do not launch a parallel worker from the toggle.
        end
        Notify("Auto Treadmill", enabled and "Enabled - Reset scan" or "Disabled - Reset scan", enabled and "Success" or "Info")
    end)
})
UpgradesSub:AddToggle({
    Name = "Auto Buy Speed Trails", Default = false, Flag = "auto_buy_trails",
    Callback = function(v) autoBuyTrails = v end
})
UpgradesSub:AddButton({
    Name = "Upgrade Base Now", Primary = true,
    Callback = safeCallback(function()
        local ok = UpgradeHomesteadBase()
        Notify("Base Upgrade", ok and "Upgrade requested" or "Not affordable / unavailable", ok and "Success" or "Warning")
    end)
})
UpgradesSub:AddButton({
    Name = "Upgrade Treadmill Now",
    Callback = safeCallback(function()
        local ok = UpgradeTreadmillTier()
        Notify("Treadmill Upgrade", ok and "Upgrade requested" or "Not affordable / unavailable", ok and "Success" or "Warning")
    end)
})

-- SubTab: Pets & Satchel
PetsSub:AddToggle({
    Name = "Auto Equip Best Pets", Default = false, Flag = "equip_best_pets",
    Callback = function(v) autoEquipBestPets = v end
})
PetsSub:AddButton({
    Name = "Equip Best Pets Now", Primary = true,
    Callback = safeCallback(function()
        HUB.EquipBestPets()
        Notify("Pets", "Equipped best pets", "Success")
    end)
})

-- SubTab: Auto Sell
SalesSub:AddToggle({
    Name = "Auto Sell Selected Pets", Default = false, Flag = "auto_sell_pets",
    Callback = function(v) autoSellPets = v end
})
SalesSub:AddMultiDropdown({
    Name = "Select Pets to Sell (by type)", Options = SELL_CATEGORY_OPTIONS, Default = {}, Flag = "sell_pet_categories",
    Callback = function(selectedList)
        selectedSellPetCategories = type(selectedList) == "table" and selectedList or {}
    end
})
SalesSub:AddMultiDropdown({
    Name = "Filter Pet Sell Rarities", Options = RARITY_NAMES, Default = {}, Flag = "sell_pet_rarities",
    Callback = function(selectedList) selectedSellPetRarities = selectedList end
})
SalesSub:AddToggle({
    Name = "Auto Sell Selected Eggs", Default = false, Flag = "auto_sell_eggs",
    Callback = function(v) autoSellEggs = v end
})
SalesSub:AddMultiDropdown({
    Name = "Select Eggs to Sell (by type)", Options = SELL_CATEGORY_OPTIONS, Default = {}, Flag = "sell_egg_categories",
    Callback = function(selectedList)
        selectedSellEggCategories = type(selectedList) == "table" and selectedList or {}
    end
})
SalesSub:AddMultiDropdown({
    Name = "Filter Egg Sell Rarities", Options = RARITY_NAMES, Default = {}, Flag = "sell_egg_rarities",
    Callback = function(selectedList) selectedSellEggRarities = selectedList end
})
SalesSub:AddButton({
    Name = "Sell Selected Pets Now", Primary = true,
    Callback = safeCallback(function()
        HUB.SellSelectedPets()
        Notify("Sales", "Sold matching pets", "Success")
    end)
})
SalesSub:AddButton({
    Name = "Sell Selected Eggs Now",
    Callback = safeCallback(function()
        HUB.SellSelectedEggs()
        Notify("Sales", "Sold matching eggs", "Success")
    end)
})

-- SubTab: Events & Bosses
EventsSub:AddParagraph({
    Title = "Rift Event",
    Content = "Reads the three Rift requirements, finds matching pets/eggs, places and hatches quest eggs, then trades and claims the reward.\nOptional filters keep selected recipes and refresh unwanted ones while free refreshes remain.",
})
EventsSub:AddToggle({
    Name = "Auto Rift Trade", Default = false, Flag = "event_rift_trade",
    Callback = safeCallback(function(v)
        eventState.rift.enabled = v == true
        HUB.Orchestrator.SetDesired("rift", eventState.rift.enabled)
        if type(HUB.WakeAutomation) == "function" then
            HUB.WakeAutomation(eventState.rift.enabled and "Rift enabled" or "Rift disabled")
        end
        if eventState.rift.enabled then
            -- Auto Rift Trade owns the complete quest lifecycle.  Keep the
            -- placement step armed when an older saved config left the
            -- optional flag disabled; the user can still turn it off after
            -- enabling the main Rift toggle.
            eventState.rift.placeEgg = true
        end
        eventState.rift.lastActionAt = 0
        eventState.rift.fieldActionReady = false
        eventState.rift.previewAt = 0
        eventState.rift.status = eventState.rift.enabled and "starting" or "off"
        eventState.rift.detail = ""
        if not eventState.rift.enabled then
            eventState.rift.acquiring = false
            eventState.rift.placing = false
            HUB.StopRiftNoClip()
            HUB.Orchestrator.End("rift")
        end
        if eventState.rift.enabled then
            Notify("The Rift", "Suji flow: Rift field target (when ready) → Auto Steal → Rift trade → Auto Treadmill", "Success")
        else
            publishEvent("No Event", "Rift automation disabled", "idle")
        end
    end)
})
EventsSub:AddToggle({
    Name = "Place Rift Egg", Default = true, Flag = "event_rift_place",
    Callback = function(v) eventState.rift.placeEgg = v == true end
})
EventsSub:AddToggle({
    Name = "Auto Refresh Rift", Default = false, Flag = "event_rift_refresh",
    Callback = function(v) eventState.rift.refresh = v == true end
})
EventsSub:AddMultiDropdown({
    Name = "Keep Rift Recipe Categories", Options = RIFT_CATEGORY_OPTIONS, Default = {}, Flag = "event_rift_keep",
    Callback = function(v) eventState.rift.keepCats = type(v) == "table" and v or {} end
})
EventsSub:AddDropdown({
    Name = "Keep Recipe When", Options = { "All 3 ticked", "Any ticked" }, Default = "All 3 ticked", Flag = "event_rift_keep_mode",
    Callback = function(v) eventState.rift.keepMode = tostring(v or "All 3 ticked") end
})
EventsSub:AddSlider({
    Name = "Max Rift Pet Weight", Min = 0, Max = 50000000, Default = 0, Suffix = " Kg", Flag = "event_rift_max_kg",
    Callback = function(v) eventState.rift.maxKg = math.max(0, tonumber(v) or 0) end
})
EventsSub:AddDivider()
EventsSub:AddParagraph({
    Title = "Rift Boss",
    Content = "Flow: realtime snapshot → safe center → portal → Beam-selected Crystal Tower → Boss.UpperHand1.R. The boss hand is sampled for HP only; movement uses one frozen tween leg. Leave and server hop are armed only after the exact HP proof and a confirmed arena exit.",
})
EventsSub:AddToggle({
    Name = "Auto Fight Rift Boss", Default = false, Flag = "event_boss_fight_v2",
    Callback = safeCallback(function(v)
        local boss = eventState.boss
        boss.controllerEpoch = (tonumber(boss.controllerEpoch) or 0) + 1
        boss.enabled = v == true
        boss.windowOpen = false
        boss.inArena = LP:GetAttribute("InBossArena") == true
        boss.windowKey = nil
        boss.defeatedWindow = nil
        boss.sessionDefeated = false
        boss.hopLocked = false
        boss.hopBusy = false
        boss.hopQueued = false
        boss.hopAfterLeaveAt = 0
        -- Auto Fight Rift Boss is a single-server feature.  The dedicated
        -- hop toggle must be armed again for this fresh fight run; do not
        -- inherit a saved/previous hop flag when only Auto Boss is enabled.
        boss.hopExplicit = false
        boss.hopEnabled = false
        boss.leaving = false
        boss.leaveCompleted = false
        boss.lastHopAt = 0
        boss.defeatedAt = 0
        boss.lastSwing = 0
        boss.lastEnter = 0
        boss.combatLeg = nil
        boss.liveSnapshot = nil
        boss.snapshotAt = 0
        boss.snapshotRevision = 0
        boss.snapshotInFlight = false
        boss.snapshotError = ""
        boss.hasEnteredArena = false
        boss.armPathSeen = false
        boss.armHealth = nil
        boss.armHealthSource = ""
        boss.armHealthPositiveSeen = false
        boss.armHealthZeroSeen = false
        boss.armHealthZeroCandidateRevision = -1
        boss.armHealthZeroCandidateAt = 0
        boss.armInstance = nil
        boss.roundClosedObserved = false
        boss.arenaInstance = nil
        boss.previousMovementOwner = nil
        boss.safeStageWindow = ""
        boss.safeStageAt = 0
        if type(HUB.ClearRiftBossHopState) == "function" then
            HUB.ClearRiftBossHopState()
        end
        if type(HUB.ClearAutomaticHopCache) == "function" then
            HUB.ClearAutomaticHopCache(boss.enabled and "Rift Boss enabled" or "Rift Boss disabled")
        end
        HUB.Orchestrator.SetDesired("boss", boss.enabled)
        if not boss.enabled then
            pcall(HUB.CancelRiftBossTween)
            pcall(stopRiftBossNoClip)
            HUB.Orchestrator.End("boss")
            boss.status = "off"
            boss.detail = ""
            publishEvent("No Event", "Rift Boss automation disabled", "idle")
            return
        end
        boss.status = "starting"
        boss.detail = "Rift Boss realtime flow armed"
        publishEvent("The Rift Boss", boss.detail, "active")
    end)
})
EventsSub:AddToggle({
    Name = "Auto Hop Server for Rift Boss", Default = false, Flag = "event_boss_hop_v2",
    Callback = safeCallback(function(v)
        local boss = eventState.boss
        -- A hop request is valid only when the user explicitly enables the
        -- dedicated toggle while Auto Fight Rift Boss is already running.
        -- This prevents a persisted UI value/callback from arming a hop when
        -- the user turned on Auto Boss Rift alone.
        if v == true and boss.enabled ~= true then
            boss.hopExplicit = false
            boss.hopEnabled = false
            boss.hopQueued = false
            boss.hopAfterLeaveAt = 0
            if type(HUB.ClearRiftBossHopState) == "function" then
                HUB.ClearRiftBossHopState()
            end
            return
        end
        boss.hopExplicit = v == true
        boss.hopEnabled = v == true
        boss.hopBusy = false
        boss.lastHopAt = 0
        if not boss.hopEnabled then
            boss.hopQueued = false
            boss.hopAfterLeaveAt = 0
            if type(HUB.ClearRiftBossHopState) == "function" then
                HUB.ClearRiftBossHopState()
            end
            if type(HUB.ClearAutomaticHopCache) == "function" then
                HUB.ClearAutomaticHopCache("Rift Boss hop disabled")
            end
            return
        end

        -- Enabling hop after a completed run is allowed, but only if the
        -- exact positive -> zero proof and confirmed arena exit already exist.
        -- Never create a permit from a generic snapshot or an in-arena state.
        if boss.enabled == true
            and boss.armHealthPositiveSeen == true
            and boss.armHealthZeroSeen == true
            and boss.sessionDefeated == true
            and boss.leaveCompleted == true
            and boss.inArena ~= true
            and LP:GetAttribute("InBossArena") ~= true then
            boss.hopQueued = true
            boss.hopAfterLeaveAt = boss.hopAfterLeaveAt > 0 and boss.hopAfterLeaveAt or os.clock()
            if type(HUB.ScheduleRiftBossHop) == "function" then
                HUB.ScheduleRiftBossHop()
            end
        end
    end)
})
EventsSub:AddSlider({
    Name = "Hop Delay After Rift Boss Defeat", Min = 0, Max = 300,
    Default = HUB.ServerHopState.BossPostDefeatDelay, Suffix = "s",
    Flag = "server_boss_post_defeat_delay_v2",
    Callback = function(v)
        HUB.ServerHopState.BossPostDefeatDelay = math.max(0, math.floor(tonumber(v) or 15))
    end,
})
EventsSub:AddToggle({
    Name = "Auto Buy Boss Shop", Default = false, Flag = "event_boss_shop",
    Callback = function(v) eventState.boss.shop = v == true end
})
EventsSub:AddMultiDropdown({
    Name = "Boss Shop Items (selected = buy)", Options = { "MutationConsumable", "SpeedBoost", "CashBooster", "TreadmillBoost" }, Default = {}, Flag = "event_boss_shop_items",
    Callback = function(v) eventState.boss.shopItems = type(v) == "table" and v or {} end
})
EventsSub:AddToggle({
    Name = "Auto Claim Boss Mastery", Default = false, Flag = "event_boss_claim",
    Callback = function(v) eventState.boss.claim = v == true end
})
MonsterEventSub:AddToggle({
    Name = "Auto Claim Monster Chests", Default = false, Flag = "auto_monster_chests",
    Callback = function(v) autoClaimMonsterChests = v end
})
MonsterEventSub:AddToggle({
    Name = "Auto Feed Monster Parasite", Default = false, Flag = "auto_feed_monster",
    Callback = function(v) autoFeedMonster = v end
})
MonsterEventSub:AddButton({
    Name = "Claim Monster Chest Now", Primary = true,
    Callback = safeCallback(function()
        HUB.ClaimMonsterChests()
        Notify("Monster Event", "Claimed monster chest", "Success")
    end)
})
MonsterEventSub:AddButton({
    Name = "Feed Monster Parasite Now",
    Callback = safeCallback(function()
        HUB.FeedMonsterParasite()
        Notify("Monster Event", "Fed monster parasite", "Success")
    end)
})

-- SubTab: Claim Rewards
RewardsSub:AddToggle({
    Name = "Auto Claim Money (Offline)", Default = false, Flag = "claim_auto_offline",
    Callback = safeCallback(function(v)
        HUB.SetAutoClaimOffline(v == true)
    end)
})
RewardsSub:AddToggle({
    Name = "Auto Claim Away Earnings & Codex", Default = false, Flag = "claim_auto_rewards",
    Callback = function(v) autoClaimRewards = v end
})
RewardsSub:AddButton({
    Name = "Claim Away Earnings & Codex Now", Primary = true,
    Callback = safeCallback(function()
        HUB.ClaimAllAvailableRewards()
        Notify("Rewards", "Claimed all ready rewards and earnings", "Success")
    end)
})
end

-- -----------------------------------------------------------------------------
-- TAB 3: COMBAT & DEFENSE
-- -----------------------------------------------------------------------------
do
local BatSub   = CombatTab:AddSubTab("Bat & Slap Aura")
local GuardSub = CombatTab:AddSubTab("Defense & Guards")

-- SubTab: Bat & Slap Aura
BatSub:AddToggle({
    Name = "Bat / Slap Aura", Default = false, Flag = "bat_aura_enabled",
    Callback = safeCallback(function(v)
        batAuraEnabled = v
        Notify("Bat Aura", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end)
})
BatSub:AddSlider({
    Name = "Aura Radius", Min = 5, Max = 50, Default = 20, Suffix = " studs", Flag = "bat_radius",
    Callback = function(v) batAuraRadius = v end
})
BatSub:AddSlider({
    Name = "Swing Delay", Min = 0.05, Max = 1.0, Default = 0.2, Suffix = "s", Flag = "bat_delay",
    Callback = function(v) batAuraDelay = v end
})
BatSub:AddButton({
    Name = "Swing Bat Once (Manual)", Primary = true,
    Callback = safeCallback(function()
        local re = GetNetRemote("RE/BatSwing/Trigger")
        if re then re:FireServer() end
        Notify("Bat", "Triggered bat swing", "Info")
    end)
})

-- SubTab: Defense & Guards
GuardSub:AddToggle({
    Name = "Anti-Trap (Full Immunity / Destroy Hitboxes)", Default = true, Flag = "avoid_traps",
    Callback = safeCallback(function(v)
        avoidTrapsEnabled = v
        if v then pcall(NeutralizeTraps) end
        Notify("Anti-Trap", v and "Immunity Active (Enemy Hitboxes Destroyed)" or "Anti-Trap Disabled", v and "Success" or "Error")
    end)
})

GuardSub:AddToggle({
    Name = "No Knockback / Ragdoll Immunity", Default = true, Flag = "no_knockback",
    Callback = safeCallback(function(v)
        HUB.SetNoKnockback(v)
        Notify("Knockback", v and "Ragdoll Immunity Active" or "Knockback Enabled", v and "Success" or "Error")
    end)
})

GuardSub:AddToggle({
    Name = "Anti-Ragdoll (Quick Standup)", Default = true, Flag = "anti_ragdoll",
    Callback = function(v) antiRagdollEnabled = v end
})

track(RunService.Heartbeat:Connect(function()
    if HUB.dead or not antiRagdollEnabled then return end
    local hum = findHum()
    if hum and hum:GetState() == Enum.HumanoidStateType.Physics then
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end))
end

-- -----------------------------------------------------------------------------
-- TAB 4: PLAYER & MOVEMENT
-- -----------------------------------------------------------------------------
do
local MoveSub     = PlayerTab:AddSubTab("Movement")
local AreaTpSub   = PlayerTab:AddSubTab("Area Travel")
local PlotTpSub   = PlayerTab:AddSubTab("Plot Travel")
local PlayerTpSub = PlayerTab:AddSubTab("Player Travel")
local PerfSub     = PlayerTab:AddSubTab("Visuals & Performance")

-- SubTab: Movement
MoveSub:AddToggle({
    Name = "Enable WalkSpeed", Default = false, Flag = "speed_enabled",
    Callback = safeCallback(function(v)
        HUB.movementState.walkSpeedEnabled = v
        if not v then
            local hum = findHum()
            if hum then hum.WalkSpeed = 16 end
        end
        Notify("WalkSpeed", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end)
})
MoveSub:AddSlider({
    Name = "WalkSpeed Value", Min = 16, Max = 10000, Default = 24, Suffix = " studs/s", Flag = "speed_val",
    Callback = function(v) ApplyWalkSpeed(v) end
})
MoveSub:AddToggle({
    Name = "Enable JumpPower", Default = false, Flag = "jump_enabled",
    Callback = safeCallback(function(v)
        HUB.movementState.jumpPowerEnabled = v
        if not v then
            local hum = findHum()
            if hum then hum.JumpPower = 50 end
        end
        Notify("JumpPower", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end)
})
MoveSub:AddSlider({
    Name = "JumpPower Value", Min = 50, Max = 300, Default = 60, Suffix = "", Flag = "jump_val",
    Callback = function(v) ApplyJumpPower(v) end
})
MoveSub:AddToggle({
    Name = "Infinite Jump", Default = false, Flag = "inf_jump",
    Callback = function(v) HUB.movementState.infiniteJump = v end
})
MoveSub:AddToggle({
    Name = "Smooth Fly (WASD + Space/Shift)", Default = false, Flag = "fly_enabled",
    Callback = safeCallback(function(v)
        if v then
            if startFly() then
                Notify("Fly", "Enabled", "Success")
            else
                Notify("Fly", "Disable movement automations first", "Info")
            end
        else
            stopFly()
            Notify("Fly", "Disabled", "Error")
        end
    end)
})
MoveSub:AddSlider({
    Name = "Fly Speed", Min = 20, Max = 250, Default = 60, Suffix = " studs/s", Flag = "fly_speed",
    Callback = function(v) HUB.movementState.flySpeed = v end
})
MoveSub:AddToggle({
    Name = "Anti-AFK (Bypass 20min Kick)", Default = false, Flag = "anti_afk",
    Callback = function(v) SetAntiAFK(v) end
})

-- SubTab: Area Travel
local selectedAreaTp = "Base / Plot"
local areaKeys = {}
for k in pairs(AREA_COORDINATES) do table.insert(areaKeys, k) end
table.sort(areaKeys)

AreaTpSub:AddDropdown({
    Name = "Select Area", Options = areaKeys, Items = areaKeys, Default = "Base / Plot", Flag = "tele_area",
    Callback = function(v) selectedAreaTp = v end
})
AreaTpSub:AddButton({
    Name = "Travel to Selected Area", Primary = true,
    Callback = safeCallback(function()
        local pos = AREA_COORDINATES[selectedAreaTp]
        if selectedAreaTp == "Base / Plot" then
            pos = GetLocalPlotCenter()
        end
        if pos then
            local leaseOk, moved = HUB.RunManualMovement(function()
                return TravelRoadPath(pos, glideSpeed or 200)
            end)
            if leaseOk and moved then
                Notify("Travel", "Arrived at " .. selectedAreaTp, "Success")
            else
                Notify("Travel", "Movement is busy or route failed", "Info")
            end
        else
            Notify("Travel", "Area position not found", "Error")
        end
    end)
})

-- SubTab: Plot Travel
local selectedPlotNum = "Plot 1"
local plotOptions = { "Plot 1", "Plot 2", "Plot 3", "Plot 4", "Plot 5", "Plot 6", "Plot 7", "My Plot" }

PlotTpSub:AddDropdown({
    Name = "Select Plot", Options = plotOptions, Items = plotOptions, Default = "My Plot", Flag = "tele_plot",
    Callback = function(v) selectedPlotNum = v end
})
PlotTpSub:AddButton({
    Name = "Travel to Plot", Primary = true,
    Callback = safeCallback(function()
        local slotNum = selectedPlotNum == "My Plot" and GetLocalSlot() or tonumber(selectedPlotNum:match("%d+")) or 1
        local plot = Workspace.Plots:FindFirstChild(tostring(slotNum))
        local targetPos = plot and (plot:FindFirstChild("CenterPoint") and plot.CenterPoint.Position or plot:GetPivot().Position)
        if targetPos then
            local leaseOk, moved = HUB.RunManualMovement(function()
                return TravelRoadPath(targetPos + Vector3.new(0, 2, 0), glideSpeed or 200)
            end)
            if leaseOk and moved then
                Notify("Plot", "Arrived at Plot " .. tostring(slotNum), "Success")
            else
                Notify("Plot", "Movement is busy or route failed", "Info")
            end
        else
            Notify("Plot", "Plot not found", "Error")
        end
    end)
})

do
    local _setupPlayerTravel = function()
    -- SubTab: Player Travel
    local selectedPlayerName = nil
    local function GetPlayerList()
        local names = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then table.insert(names, p.Name) end
        end
        table.sort(names)
        if #names == 0 then names = { "(no other players)" } end
        return names
    end

    local playerDropdown = PlayerTpSub:AddDropdown({
        Name = "Select Player", Options = GetPlayerList(), Items = GetPlayerList(), Default = nil, Flag = "tele_plr",
        Callback = function(v) selectedPlayerName = v end
    })

    PlayerTpSub:AddButton({
        Name = "Refresh Player List",
        Callback = function()
            playerDropdown:SetOptions(GetPlayerList())
            Notify("Players", "Refreshed player list", "Info")
        end
    })
    PlayerTpSub:AddButton({
        Name = "Travel to Player", Primary = true,
        Callback = safeCallback(function()
            if not selectedPlayerName then return end
            local targetPlr = Players:FindFirstChild(selectedPlayerName)
            local tHrp = targetPlr and targetPlr.Character and targetPlr.Character:FindFirstChild("HumanoidRootPart")
            if tHrp then
                local leaseOk, moved = HUB.RunManualMovement(function()
                    return TravelRoadPath(tHrp.Position + Vector3.new(0, 2, 0), glideSpeed or 200)
                end)
                if leaseOk and moved then
                    Notify("Player", "Arrived at " .. selectedPlayerName, "Success")
                else
                    Notify("Player", "Movement is busy or route failed", "Info")
                end
            else
                Notify("Player", "Player unavailable", "Error")
            end
        end)
    })

    end
    _setupPlayerTravel()
end

-- SubTab: Visuals & Performance
PerfSub:AddToggle({
    Name = "Fullbright (Daylight Visuals)", Default = false, Flag = "fullbright",
    Callback = function(v) SetFullbright(v) end
})
PerfSub:AddParagraph({
    Title = "Graphics Optimization",
    Content = "Hide low-value local graphics, effects, lights and billboards to reduce visual load and improve FPS. This changes visuals only and does not affect gameplay logic.",
})
PerfSub:AddToggle({
    Name = "Hide Low-Value Graphics (FPS Boost)", Default = false, Flag = "visual_hide_low",
    Callback = safeCallback(function(v)
        HUB.SetHideLow(v == true)
    end)
})
PerfSub:AddToggle({
    Name = "Hide Names", Default = false, Flag = "visual_hide_names",
    Callback = safeCallback(function(v)
        HUB.SetHideNames(v == true)
    end)
})
PerfSub:AddToggle({
    Name = "Shelter From Dragon Wave", Default = false, Flag = "visual_shelter_dragon",
    Callback = safeCallback(function(v)
        HUB.SetShelterFromDragonWave(v == true)
    end)
})
PerfSub:AddButton({
    Name = "Delete Own Pet Renders (FPS Boost)", Primary = true,
    Callback = safeCallback(function()
        local count = HUB.DeleteOwnPetRenders()
        Notify("Performance", "Removed " .. count .. " rendered pet model(s)", "Success")
    end)
})
end


-- =============================================================================
-- ==============================================================================
-- AXEL HUB WEBHOOK TAB
-- Scoped separately to avoid Luau's 200-local-register limit.
-- ==============================================================================
(function()
    local axelWebhookUrl = ""
    local axelWebhookEnabled = false
    local webhookNotifyAnimal = true
    local webhookNotifyRarity = true
    local webhookNotifyEgg = true
    local webhookNotifyCount = true
    local webhookStealCount = 0

    local function GetAxelWebhookRequest()
        return (syn and syn.request)
            or (http and http.request)
            or http_request
            or request
    end

    local function PostAxelWebhook(payload, force)
        if type(payload) ~= "table" then
            return false, "invalid payload"
        end

        if not force and not axelWebhookEnabled then
            return false, "webhook disabled"
        end

        -- Mobile paste/input controls can include a trailing newline or
        -- whitespace.  Discord rejects that URL, which previously looked like
        -- a successful toggle with no notification.
        local url = tostring(axelWebhookUrl or "")
            :gsub("[\r\n]", "")
            :gsub("^%s+", "")
            :gsub("%s+$", "")
            :gsub("/+$", "")
        axelWebhookUrl = url
        local validUrl = url:match("^https://discord%.com/api/webhooks/%d+/%S+$")
            or url:match("^https://discordapp%.com/api/webhooks/%d+/%S+$")
            or url:match("^https://canary%.discord%.com/api/webhooks/%d+/%S+$")
            or url:match("^https://ptb%.discord%.com/api/webhooks/%d+/%S+$")
        if not validUrl then
            if url:find("/api/telemetry", 1, true) then
                return false, "WebLog URL belongs in AxelWebLogConfig.URL, not the Discord Webhook URL field"
            end
            return false, "invalid webhook URL"
        end

        local req = GetAxelWebhookRequest()
        if type(req) ~= "function" then
            return false, "HTTP request function unavailable"
        end

        local okEncode, body = pcall(function()
            return game:GetService("HttpService"):JSONEncode(payload)
        end)
        if not okEncode then
            return false, "JSON encode failed"
        end

        -- `wait=true` makes Discord return a normal JSON response on success;
        -- 204 is still accepted for executors that keep the no-content reply.
        local sendUrl = url .. (url:find("?", 1, true) and "&" or "?") .. "wait=true"
        local lastError = "request failed"
        for attempt = 1, 2 do
            local okRequest, response = pcall(function()
                return req({
                    Url = sendUrl,
                    Method = "POST",
                    Headers = {
                        ["Content-Type"] = "application/json",
                        ["Accept"] = "application/json",
                    },
                    Body = body,
                })
            end)

            if okRequest then
                local status = type(response) == "table"
                    and tonumber(response.StatusCode or response.status or response.code)
                if not status or (status >= 200 and status < 300) then
                    return true, response
                end
                lastError = "HTTP " .. tostring(status)
                -- Retry rate limits and transient Discord/server errors once;
                -- do not duplicate a permanent 4xx rejection.
                if status ~= 429 and status < 500 then
                    return false, lastError
                end
            else
                lastError = tostring(response)
            end
            if attempt < 2 then task.wait(0.75) end
        end
        return false, lastError
    end

    -- Axel Hub logo from the URL supplied by the user.
    local AXEL_WEBHOOK_LOGO =
        "https://media.discordapp.net/attachments/1474749204973883508/1474749350461706361/axel_hub_2.png?ex=6aa2a6dc&is=6aa1555c&hm=a231cf00e3ecedb25eced50aec0042af2e1373be8298348665fa689d63acbbe2&=&format=webp&quality=lossless"

    -- Bottom banner/background.
    -- IMPORTANT: Discord needs a DIRECT image URL here (GIF/PNG/JPG/WEBP).
    -- A Canva share page such as canva.link/... is not an image URL and will not render.
    -- Put your animated GIF/WebP CDN URL here after uploading it somewhere public.
    local AXEL_WEBHOOK_BANNER = "https://www.image2url.com/r2/default/gifs/1788963639200-c2fed6c8-1d70-4d0a-9c80-6a6daec994aa.gif"

    -- Emoji used in the embed. Unicode emoji render reliably in Discord webhooks.
    -- The discord.com/assets/...svg links are not embeddable image markdown inside
    -- normal embed text, so use Unicode or Discord custom emoji syntax instead.
    local AXEL_EMOJI = {
        Egg      = "🥚",
        Animal   = "🐾",
        Rarity   = "💎",
        Score    = "🌟",
        Mutation = "🧬",
        Area     = "📍",
        Count    = "📦",
        Discord  = "🔗",
        Check    = "✅",
    }

    -- Discord embed color is driven by rarity.
    local RARITY_WEBHOOK_COLORS = {
        Titan        = 0xFF2D55,
        Divine       = 0xFF1493,
        Transcendent = 0xFF1493,
        Superior     = 0xFF1493,
        Eternal      = 0x8B5CF6,
        Limited      = 0xF43F5E,
        Secret       = 0x7C3AED,
        Exotic       = 0xA855F7,
        Cosmic       = 0x06B6D4,
        Exclusive    = 0x14B8A6,
        Admin        = 0xEF4444,
        Mythic       = 0xEC4899,
        Mythical     = 0xEC4899,
        Prismatic    = 0xF59E0B,
        Rainbow      = 0xF59E0B,
        ["Squishy God"] = 0xF59E0B,
        BrainrotGod  = 0xF59E0B,
        Legendary    = 0xFBBF24,
        Epic         = 0xA855F7,
        Rare         = 0x3B82F6,
        SuperRare    = 0x60A5FA,
        Celestial    = 0x22D3EE,
        Uncommon     = 0x22C55E,
        Basic        = 0x94A3B8,
        Common       = 0x9CA3AF,
        Unknown      = 0x6B7280,
    }

    local function GetWebhookRarityColor(rarity)
        local name = tostring(rarity or "Unknown")
        local key = RARITY_WEBHOOK_COLORS[name] and name
        if key then
            return RARITY_WEBHOOK_COLORS[key]
        end

        local lower = string.lower(name)
        for rarityName, color in pairs(RARITY_WEBHOOK_COLORS) do
            if string.lower(rarityName) == lower then
                return color
            end
        end

        return RARITY_WEBHOOK_COLORS.Unknown
    end

    local function BuildWebhookEmbed(title, description, fields, color)
        local embed = {
            author = {
                name = "AXEL HUB",
                icon_url = AXEL_WEBHOOK_LOGO,
            },
            title = tostring(title),
            description = tostring(description),
            color = tonumber(color) or 0xFFC107,
            fields = fields or {},
            footer = {
                text = "Axel Hub  •  Steal an Egg",
                icon_url = AXEL_WEBHOOK_LOGO,
            },
            thumbnail = {
                url = AXEL_WEBHOOK_LOGO,
            },
            timestamp = DateTime.now():ToIsoDate(),
        }

        -- Discord renders embed.image BELOW the fields, which matches the
        -- bottom-banner look in your reference. Animated GIF/WebP can animate
        -- there when the URL points directly to the media file.
        if type(AXEL_WEBHOOK_BANNER) == "string"
            and AXEL_WEBHOOK_BANNER ~= ""
            and (
                AXEL_WEBHOOK_BANNER:match("%.gif([?#]|$)")
                or AXEL_WEBHOOK_BANNER:match("%.webp([?#]|$)")
                or AXEL_WEBHOOK_BANNER:match("%.png([?#]|$)")
                or AXEL_WEBHOOK_BANNER:match("%.jpe?g([?#]|$)")
                or AXEL_WEBHOOK_BANNER:match("^https?://")
            ) then
            embed.image = {
                url = AXEL_WEBHOOK_BANNER,
            }
        end

        return {
            username = "Axel Hub",
            avatar_url = AXEL_WEBHOOK_LOGO,
            embeds = { embed },
        }
    end

    local function GetAssetDisplayName(category)
        if type(category) ~= "string" or category == "" then
            return "Unknown"
        end
        if AssetsData then
            local dir = AssetsData.Directory or AssetsData
            local info = type(dir) == "table" and dir[category]
            if type(info) == "table" then
                local name = info.DisplayName or info.Name or info.PetName or info.AssetName
                if type(name) == "string" and name ~= "" then
                    return name
                end
            end
        end
        return category
    end

    local function GetTargetAnimalName(record)
        if type(record) ~= "table" then
            return "Unknown"
        end

        local direct = record.AnimalName or record.PetName or record.Animal
            or record.ContainedAnimal or record.ResultName
        if type(direct) == "string" and direct ~= "" then
            return direct
        end

        return GetAssetDisplayName(record.AssetCategory or record.Category or record.Name)
    end

    local function GetTargetRarity(record)
        if type(record) ~= "table" then
            return "Unknown", 0
        end

        local ok, rarity, score = pcall(function()
            return HUB.GetEggRarityInfo(record)
        end)

        if ok then
            return tostring(rarity or "Common"), tonumber(score) or 100
        end

        return "Common", 100
    end

    local function GetTargetMutationText(record)
        if type(record) ~= "table" then
            return "Normal"
        end

        local mutations = record.Mutations
        if type(mutations) == "table" then
            local out = {}
            for _, mutation in ipairs(mutations) do
                if type(mutation) == "string" and mutation ~= "" then
                    table.insert(out, mutation)
                end
            end
            if #out > 0 then
                return table.concat(out, ", ")
            end
        end

        local mutation = record.Mutation or record.BaseMutation
        if type(mutation) == "string" and mutation ~= "" then
            return mutation
        end

        return "Normal"
    end

    local function SendAxelReady(force)
        return PostAxelWebhook(BuildWebhookEmbed(
            "[" .. AXEL_EMOJI.Check .. "] Webhook Connected",
            "",
            {
                { name = "Game", value = "Steal an Egg", inline = true },
                { name = "Player", value = tostring(LP.DisplayName or LP.Name), inline = true },
                { name = "Job ID", value = tostring(game.JobId), inline = false },
            },
            0xFFC107
        ), force)
    end

    -- Publish only small accessors to the outer sender. The sender itself is
    -- outside this UI closure, while these accessors keep the live toggle
    -- values and count without capturing the entire webhook setup scope.
    local runtime = HUB.WebhookRuntime or {}
    HUB.WebhookRuntime = runtime
    runtime.GetNotificationFlags = function()
        return webhookNotifyAnimal, webhookNotifyRarity, webhookNotifyEgg, webhookNotifyCount
    end
    runtime.NextStealCount = function()
        webhookStealCount += 1
        return webhookStealCount
    end
    runtime.GetAssetDisplayName = GetAssetDisplayName
    runtime.GetTargetAnimalName = GetTargetAnimalName
    runtime.GetTargetRarity = GetTargetRarity
    runtime.GetTargetMutationText = GetTargetMutationText
    runtime.GetRarityColor = GetWebhookRarityColor
    runtime.Build = BuildWebhookEmbed
    runtime.Post = PostAxelWebhook
    runtime.Emoji = AXEL_EMOJI

    local WebhookTab = Window:AddTab({
        Name = "Webhook",
        Subtitle = "Discord notifications",
        Icon = "!",
    })

    local WebhookMain = WebhookTab:AddSubTab("Webhook")
    local WebhookEvents = WebhookTab:AddSubTab("Notifications")

    WebhookMain:AddParagraph({
        Title = "Discord Webhook",
        Content = "Send a Discord notification when an egg is successfully collected.",
    })

    WebhookMain:AddInput({
        Name = "Webhook URL",
        Default = "",
        Flag = "axel_webhook_url",
        Callback = function(v)
            axelWebhookUrl = tostring(v or "")
        end,
    })

    WebhookMain:AddToggle({
        Name = "Enable Webhook",
        Default = false,
        Flag = "axel_webhook_enabled",
        Callback = function(v)
            axelWebhookEnabled = v == true
            Notify("Webhook", axelWebhookEnabled and "Enabled" or "Disabled",
                axelWebhookEnabled and "Success" or "Info")
            if axelWebhookEnabled then
                -- Send a real connection probe immediately. This makes a bad
                -- URL/request adapter visible instead of waiting until the
                -- next successful egg steal and silently swallowing the error.
                task.spawn(function()
                    task.wait(0.1)
                    local callOk, sent, detail = pcall(SendAxelReady, false)
                    if not callOk then
                        warn("[Axel Discord Webhook] Connection probe error: " .. tostring(sent))
                        Notify("Webhook", "Connection failed: " .. tostring(sent), "Error")
                    elseif sent ~= true then
                        warn("[Axel Discord Webhook] Connection probe failed: " .. tostring(detail or sent))
                        Notify("Webhook", "Connection failed: " .. tostring(detail or sent), "Error")
                    else
                        Notify("Webhook", "Connection test sent", "Success")
                    end
                end)
            end
        end,
    })

    WebhookMain:AddButton({
        Name = "Test Send Now",
        Primary = true,
        Callback = safeCallback(function()
            local ok, err = SendAxelReady(true)
            Notify("Webhook",
                ok and "Test sent successfully" or ("Send failed: " .. tostring(err)),
                ok and "Success" or "Error")
        end),
    })

    WebhookMain:AddDivider()

    WebhookEvents:AddToggle({
        Name = "Animal",
        Default = true,
        Flag = "webhook_animal",
        Callback = function(v) webhookNotifyAnimal = v == true end,
    })

    WebhookEvents:AddToggle({
        Name = "Rarity",
        Default = true,
        Flag = "webhook_rarity",
        Callback = function(v) webhookNotifyRarity = v == true end,
    })

    WebhookEvents:AddToggle({
        Name = "Egg",
        Default = true,
        Flag = "webhook_egg",
        Callback = function(v) webhookNotifyEgg = v == true end,
    })

    WebhookEvents:AddToggle({
        Name = "Stolen Count",
        Default = true,
        Flag = "webhook_count",
        Callback = function(v) webhookNotifyCount = v == true end,
    })
end)()

-- -----------------------------------------------------------------------------
-- TAB 5: SETTINGS & CONFIG
-- -----------------------------------------------------------------------------
do
local ConfigSub = SettingsTab:AddSubTab("Configuration")

if HAS_CONFIG then
    ConfigSub:AddInput({
        Name = "Config Name", Default = CONFIG_NAME, Flag = "cfg_name",
        Callback = function(v) if v and #v > 0 then CONFIG_NAME = v end end
    })
    ConfigSub:AddButton({
        Name = "Save Config", Primary = true,
        Callback = safeCallback(function()
            local ok, err = Library:SaveConfig(CONFIG_NAME)
            Notify("Config", ok and ("Saved config '" .. CONFIG_NAME .. "'") or ("Save failed: " .. tostring(err)), ok and "Success" or "Error")
        end)
    })
    ConfigSub:AddButton({
        Name = "Load Config",
        Callback = safeCallback(function()
            local ok, err = Library:LoadConfig(CONFIG_NAME)
            if ok then
                ResyncAll()
                Notify("Config", "Loaded config '" .. CONFIG_NAME .. "'", "Success")
            else
                Notify("Config", "Load failed: " .. tostring(err), "Error")
            end
        end)
    })
end

ConfigSub:AddKeybind({
    Name = "Toggle UI Keybind", Default = Enum.KeyCode.RightControl, Flag = "ui_toggle_key",
    OnPress = function()
        Window:Toggle()
    end
})

ConfigSub:AddDivider()

ConfigSub:AddButton({
    Name = "Unload Axel Hub",
    Callback = safeCallback(function()
        pcall(function() HUB.Unload() end)
    end)
})

    ConfigSub:AddParagraph({
        Title = "Axel Hub | Steal an Egg",
        Content = "Axel Hub · Steal an Egg\nYellow Axel Hub theme\nAutomated egg stealing, hatching, treadmill, rewards, pets, ESP, travel and settings."
    })
end

end)()

-- ==============================================================================
-- HUB CLEANUP & UNLOAD HANDLER
-- ==============================================================================
HUB.Unload = function()
    HUB.dead = true
    ServerHopLoopRunning = false
    pcall(function()
        HUB.MovementLease.owner = nil
        HUB.MovementLease.depth = 0
    end)
    pcall(function() if HUB.SetHideLow then HUB.SetHideLow(false) end end)
    pcall(function() if HUB.SetHideNames then HUB.SetHideNames(false) end end)
    pcall(function() if HUB.SetShelterFromDragonWave then HUB.SetShelterFromDragonWave(false) end end)
    pcall(function() if HUB.SetAutoClaimOffline then HUB.SetAutoClaimOffline(false) end end)
    stopRiftBossNoClip()
    pcall(HUB.Orchestrator.End)
    pcall(HUB.StopTreadmillTraining)
    eventState.boss.controllerEpoch += 1
    eventState.boss.enabled = false
    eventState.rift.enabled = false
    carryingEggReturnActive = false
    treadmillResetRequested = true

    for _, c in ipairs(HUB.conns) do pcall(function() c:Disconnect() end) end
    HUB.conns = {}

    for _, d in ipairs(HUB.drawings) do pcall(function() d:Remove() end) end
    HUB.drawings = {}

    for _, h in ipairs(HUB.highlights) do pcall(function() h:Destroy() end) end
    HUB.highlights = {}

    stopFly()
    SetFullbright(false)

    local hum = findHum()
    if hum then
        hum.PlatformStand = false
        hum.WalkSpeed = 16
        hum.JumpPower = 50
    end

    pcall(function() Window:Destroy() end)
    _G.OxideStealAnEgg = nil
end

Notify("Axel Hub", "Steal an Egg loaded successfully!", "Success", 3.5)
