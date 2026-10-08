--[[
   ⚡ AXEL HUB · ANIME ZERO [FULL AUTONOMOUS KAITUN PRO]
   by cook45 x clack
   Supports: Lobby (114574503491412) & In-Match (109151342576374 AIO GAMEPLAY)
]]

-- ══════════════════════════════════════════════════
-- USER CONFIGURATION (ปรับแต่งการทำงานของระบบ)
-- ══════════════════════════════════════════════════
if type(getgenv) ~= "function" then
    getgenv = function() return _G end
end
  
local _DEFAULT_CONFIG = {
}

if type(getgenv().AZ_Config) == "table" then
    for k, v in pairs(_DEFAULT_CONFIG) do
        if getgenv().AZ_Config[k] == nil then
            getgenv().AZ_Config[k] = v
        end
    end
else
    getgenv().AZ_Config = _DEFAULT_CONFIG
end

-- ฟังก์ชันตรวจสอบการเปิดใช้งานภาษาอังกฤษแบบ 100% (อ่านค่าจาก getgenv().AZ_Config ของลูกค้าก่อนเสมอ)
local function isEnglishEnabled()
    local cfg = getgenv and getgenv().AZ_Config
    if cfg and cfg.EnglishUI ~= nil then
        return cfg.EnglishUI == true
    end
    if _DEFAULT_CONFIG and _DEFAULT_CONFIG.EnglishUI ~= nil then
        return _DEFAULT_CONFIG.EnglishUI == true
    end
    if getgenv and getgenv().EnglishUI ~= nil then
        return getgenv().EnglishUI == true
    end
    if _G and _G.EnglishUI ~= nil then
        return _G.EnglishUI == true
    end
    return false
end


-- ══════════════════════════════════════════════════
-- 0. PURGE OLD HUBS & CONNECTIONS
-- ══════════════════════════════════════════════════
if getgenv and type(getgenv()._AZKaitunCleanup) == "function" then
    pcall(getgenv()._AZKaitunCleanup)
    getgenv()._AZKaitunCleanup = nil
end
if _G.AZ_Connections then
    for _, c in ipairs(_G.AZ_Connections) do pcall(function() c:Disconnect() end) end
end
_G.AZ_Connections = {}



local Players           = game:GetService("Players")
local lp                = Players.LocalPlayer
if not lp then
    repeat
        task.wait(0.1)
        lp = Players.LocalPlayer
    until lp
end

pcall(function()
    local cg = game:GetService("CoreGui")
    local pg = lp and lp:FindFirstChild("PlayerGui")
    for _, parent in ipairs({ cg, pg }) do
        if parent then
            for _, c in ipairs(parent:GetChildren()) do
                if c.Name == "AZ_Hub" or c.Name == "AZ_Kaitun_HUD" or c.Name:find("Axel") then
                    pcall(function() c:Destroy() end)
                end
            end
        end
    end
end)

-- ★ PERSISTENT FILE & MEMORY ACCOUNT CACHE (Saves across teleports between Lobby and Match) ★
local HttpService = game:GetService("HttpService")
local CACHE_FILE = "AZ_Kaitun_Cache.json"

local function loadCachedData()
    local result = nil
    pcall(function()
        local rfile = readfile or (syn and syn.readfile)
        local ifile = isfile or (syn and syn.isfile)
        if ifile and rfile and ifile(CACHE_FILE) then
            local raw = rfile(CACHE_FILE)
            if raw and raw ~= "" then
                local data = HttpService:JSONDecode(raw)
                if type(data) == "table" then
                    result = data
                end
            end
        end
    end)
    return result
end

local _lastSaveTick = 0
local function saveCachedData()
    pcall(function()
        local wfile = writefile or (syn and syn.writefile)
        if wfile and _G.AZ_Cache then
            _lastSaveTick = tick()
            wfile(CACHE_FILE, HttpService:JSONEncode(_G.AZ_Cache))
        end
    end)
end

local loadedCache = loadCachedData()
if not _G.AZ_Cache then
    _G.AZ_Cache = loadedCache or {
        name = lp and lp.Name or "---",
        money = 0,
        gems = 0,
        level = 1,
        exp = "",
        character = "guts",
        charDisplay = "Dragon Eclipse",
        trait = "None",
        zenlessPity = 0,
        arcanePity = 0,
        mythicPity = 0,
        luckySpins = 0,
        rolls = 0,
        deliveryCleared = 0,
        currencies = { money = 0, gems = 0, zenlessPity = 0, arcanePity = 0, mythicPity = 0, rolls = 0, luckySpins = 0 },
        material = {},
        craftedAccessories = {},
        accessory = {},
        CharactersData = {},
        UnlockedCharacters = {},
        achievements = { progress = {} },
        checklist = {}
    }
else
    if loadedCache then
        for k, v in pairs(loadedCache) do
            if _G.AZ_Cache[k] == nil or _G.AZ_Cache[k] == 0 or _G.AZ_Cache[k] == "..." or _G.AZ_Cache[k] == "---" then
                _G.AZ_Cache[k] = v
            end
        end
    end
end
if lp and lp.Name and lp.Name ~= "" then
    _G.AZ_Cache.name = lp.Name
end
if getgenv then getgenv()._AZ_Cache = _G.AZ_Cache end

-- Forward declaration of UI object so setTask can access it everywhere
local axelhubkaitun = _G._AZ_AxelUI or {}
if getgenv then getgenv()._AZ_AxelUI = axelhubkaitun end

-- ══════════════════════════════════════════════════
-- 1. SERVICES
-- ══════════════════════════════════════════════════
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local TeleportService   = game:GetService("TeleportService")
local UserInputService  = game:GetService("UserInputService")
local VirtualUser       = game:GetService("VirtualUser")
local RS                = game:GetService("ReplicatedStorage")

-- 🔄 AUTO REJOIN ON DISCONNECT ENGINE (รองรับตัวรัน Real / Mobile / Medium / PC ทุกประเภท)
local function setupAutoRejoin()
    local GuiService = game:GetService("GuiService")
    local CoreGui = game:GetService("CoreGui")

    local function queueScriptReload()
        local qot = (syn and syn.queue_on_teleport) or queue_on_teleport or (Fluxus and Fluxus.queue_on_teleport)
        if qot then
            pcall(function()
                qot([[
                    task.wait(2)
                    pcall(function()
                        if readfile and isfile and isfile("AnimeZero_Hub.lua") then
                            loadstring(readfile("AnimeZero_Hub.lua"))()
                        end
                    end)
                ]])
            end)
        end
    end

    local isRejoining = false
    local function executeRejoin(reason)
        if isRejoining then return end
        isRejoining = true
        warn("[Axel Hub] 🔄 Auto Rejoin triggered! Reason: " .. tostring(reason))
        queueScriptReload()

        local lobbyPlaceId = 114574503491412
        local targetPlace = (game.PlaceId == lobbyPlaceId or game.PlaceId == 109151342576374) and lobbyPlaceId or game.PlaceId

        while true do
            pcall(function()
                if #Players:GetPlayers() <= 1 then
                    TeleportService:Teleport(targetPlace, lp)
                else
                    TeleportService:TeleportToPlaceInstance(targetPlace, game.JobId, lp)
                end
            end)
            task.wait(4)
            pcall(function()
                TeleportService:Teleport(targetPlace, lp)
            end)
            task.wait(5)
        end
    end

    -- 1. ตรวจจับ ErrorMessage จาก GuiService เมื่อหลุดการเชื่อมต่อหรือโดน Kick
    pcall(function()
        local c = GuiService.ErrorMessageChanged:Connect(function()
            local cfg = getgenv and getgenv().AZ_Config
            if cfg == nil or cfg.AutoRejoin ~= false then
                task.wait(1.5)
                executeRejoin("GuiService ErrorMessageChanged")
            end
        end)
        if _G.AZ_Connections then table.insert(_G.AZ_Connections, c) end
    end)

    -- 2. ตรวจจับ Dialog ErrorPrompt จาก CoreGui.RobloxPromptGui
    pcall(function()
        local rPrompt = CoreGui:FindFirstChild("RobloxPromptGui")
        local promptOverlay = rPrompt and rPrompt:FindFirstChild("promptOverlay")
        if promptOverlay then
            local c = promptOverlay.ChildAdded:Connect(function(child)
                local cfg = getgenv and getgenv().AZ_Config
                if (cfg == nil or cfg.AutoRejoin ~= false) and child.Name == "ErrorPrompt" then
                    task.wait(1.5)
                    executeRejoin("CoreGui ErrorPrompt Detected")
                end
            end)
            if _G.AZ_Connections then table.insert(_G.AZ_Connections, c) end
        end
    end)

    -- 3. ตรวจจับ Teleport ล้มเหลว (TeleportInitFailed)
    pcall(function()
        local c = TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
            local cfg = getgenv and getgenv().AZ_Config
            if cfg == nil or cfg.AutoRejoin ~= false then
                task.wait(2.0)
                executeRejoin("TeleportInitFailed: " .. tostring(errorMessage))
            end
        end)
        if _G.AZ_Connections then table.insert(_G.AZ_Connections, c) end
    end)
end
pcall(setupAutoRejoin)

-- ตรวจสอบอุปกรณ์อย่างชัดเจน (Mobile vs PC) เพื่อเลือก Input Fallback อย่างใดอย่างหนึ่ง ไม่สลับมั่ว
-- ตรวจสอบอุปกรณ์อย่างชัดเจน (Mobile vs PC) เพื่อเลือก Input Fallback อย่างใดอย่างหนึ่งตายตัว ไม่สลับไปมา
local isMobileDevice = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

-- ฟังก์ชันคลิกปุ่ม UI ตามประเภทอุปกรณ์อย่างตายตัว (เช็คอุปกรณ์แล้ว Fallback ไปตามอุปกรณ์นั้นเท่านั้น ไม่สลับไปมา)
local function clickGuiElementSafely(elem)
    if not elem then return end
    -- Universal standard สำหรับ Executor ทุกตัว: Activated signal
    if firesignal and elem:IsA("GuiButton") then
        pcall(function() firesignal(elem.Activated) end)
    end

    local vim = game:GetService("VirtualInputManager")
    if isMobileDevice then
        -- 📱 เฉพาะ MOBILE FALLBACK (TouchTap + SendTouchEvent เท่านั้น — ไม่แตะ Mouse/Keyboard)
        pcall(function()
            if firesignal and elem.TouchTap then
                firesignal(elem.TouchTap)
            end
        end)
        if vim and elem:IsA("GuiObject") then
            local pos = elem.AbsolutePosition
            local size = elem.AbsoluteSize
            local cx = pos.X + size.X / 2
            local cy = pos.Y + size.Y / 2
            pcall(function()
                vim:SendTouchEvent(1, 0, cx, cy)
                task.wait(0.02)
                vim:SendTouchEvent(1, 2, cx, cy)
            end)
        end
    else
        -- 💻 เฉพาะ PC FALLBACK (MouseButton1 + SendMouseButtonEvent เท่านั้น — ไม่แตะ Touch)
        pcall(function()
            if firesignal and elem:IsA("GuiButton") then
                firesignal(elem.MouseButton1Click)
                firesignal(elem.MouseButton1Down)
                task.wait(0.02)
                firesignal(elem.MouseButton1Up)
            end
        end)
        if vim and elem:IsA("GuiObject") then
            local pos = elem.AbsolutePosition
            local size = elem.AbsoluteSize
            local cx = pos.X + size.X / 2
            local cy = pos.Y + size.Y / 2
            pcall(function()
                vim:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
                task.wait(0.02)
                vim:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
            end)
        end
    end
end

local function checkIsMatch()
    return (game.PlaceId == 109151342576374) or (RS:FindFirstChild("performM1") ~= nil) or (workspace:FindFirstChild("enemies") ~= nil)
end
local isMatch = checkIsMatch()

-- ══════════════════════════════════════════════════
-- 2. GAME PACKETS, CONFIGS & DYNAMIC REFLECTION
-- ══════════════════════════════════════════════════
local function safeRequire(obj)
    if not obj then return nil end
    local ok, res = pcall(require, obj)
    if not ok and obj:IsA("ModuleScript") then
        pcall(function()
            local clone = obj:Clone()
            clone.Parent = obj.Parent
            local cOk, cRes = pcall(require, clone)
            if cOk then
                res = cRes
                ok = true
            end
            clone:Destroy()
        end)
    end
    return ok and res or nil
end

local lobbyPkts
local function getLobbyPackets()
    if isMatch then return nil end
    if not lobbyPkts then
        pcall(function()
            local l = RS:FindFirstChild("lobby") or RS:WaitForChild("lobby", 2)
            local p = l and (l:FindFirstChild("packets") or l:WaitForChild("packets", 2))
            if p then lobbyPkts = safeRequire(p) end
        end)
    end
    return lobbyPkts
end
lobbyPkts = getLobbyPackets()

local skillTreePkts = safeRequire(RS:FindFirstChild("lobby") and RS.lobby:FindFirstChild("modules") and RS.lobby.modules:FindFirstChild("skillTree") and RS.lobby.modules.skillTree:FindFirstChild("skillTreePackets"))
local accountNS     = safeRequire(RS:FindFirstChild("global") and RS.global:FindFirstChild("stores") and RS.global.stores:FindFirstChild("accountNamespace"))

-- Dynamic Game Engines & Reflection (อัปเดตตามเกมใหม่อัตโนมัติ 100% โดยไม่ต้อง Hardcode ป้องกัน error จากโมดูลที่ยังไม่พร้อม)
local mapsConstant    = safeRequire(RS:FindFirstChild("global") and RS.global:FindFirstChild("constants") and RS.global.constants:FindFirstChild("maps"))
local diffsConstant   = safeRequire(RS:FindFirstChild("global") and RS.global:FindFirstChild("constants") and RS.global.constants:FindFirstChild("difficulties"))
local charsConstant   = safeRequire(RS:FindFirstChild("global") and RS.global:FindFirstChild("constants") and RS.global.constants:FindFirstChild("characters"))
local charRollCfg     = safeRequire(RS:FindFirstChild("assets") and RS.assets:FindFirstChild("config") and RS.assets.config:FindFirstChild("characterRollConfig"))
local raidUnitCfg     = safeRequire(RS:FindFirstChild("assets") and RS.assets:FindFirstChild("config") and RS.assets.config:FindFirstChild("RaidUnitConfig"))
local codesCfg        = safeRequire(RS:FindFirstChild("assets") and RS.assets:FindFirstChild("config") and RS.assets.config:FindFirstChild("codesConfig"))
local matDropCfg      = safeRequire(RS:FindFirstChild("assets") and RS.assets:FindFirstChild("config") and RS.assets.config:FindFirstChild("materialDropConfig"))
local traitCfg        = safeRequire(RS:FindFirstChild("assets") and RS.assets:FindFirstChild("config") and RS.assets.config:FindFirstChild("Traits") and RS.assets.config.Traits:FindFirstChild("traitConfig"))
local titleCfg        = safeRequire(RS:FindFirstChild("assets") and RS.assets:FindFirstChild("config") and RS.assets.config:FindFirstChild("titleConfig"))
local accCraftCfg     = safeRequire(RS:FindFirstChild("assets") and RS.assets:FindFirstChild("config") and RS.assets.config:FindFirstChild("accessoryCraftConfig"))
local economyCfg      = safeRequire(RS:FindFirstChild("assets") and RS.assets:FindFirstChild("config") and RS.assets.config:FindFirstChild("economyConfig"))
local charProg        = safeRequire(RS:FindFirstChild("global") and RS.global:FindFirstChild("utils") and RS.global.utils:FindFirstChild("characterLevelProgression"))

local _reqId = 0
local function nextId()
    _reqId = (_reqId + 1) % 65535
    return _reqId
end

local State = {
    CurrentTask    = isMatch and "⚔️ กำลังฟาร์มในด่านต่อสู้..." or "กำลังเริ่มระบบ Axel Hub...",
    IsHealing      = false,
    IsDodging      = false
}

local function setTask(msg)
    State.CurrentTask = msg
    pcall(function()
        if axelhubkaitun and axelhubkaitun.SetCurrentAction then
            axelhubkaitun:SetCurrentAction(msg)
        end
    end)
end

-- ★ AUTO LOW FPS BOOSTER / ULTRA POTATO GRAPHICS (RAM 4GB & LOW-END PRO) ★
local function enableAutoLowFpsMode()
    pcall(function()
        -- 1. บังคับ Quality Level ต่ำสุด
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        
        -- 2. ปรับแต่ง Lighting ให้ประหยัดแรมสูงสุด
        local lighting = game:GetService("Lighting")
        lighting.GlobalShadows = false
        lighting.FogEnd = 9e9
        lighting.Brightness = 1
        pcall(function() lighting.Technology = Enum.Technology.Compatibility end)
        for _, obj in ipairs(lighting:GetChildren()) do
            if obj:IsA("PostEffect") or obj:IsA("Atmosphere") or obj:IsA("Clouds") or obj:IsA("BloomEffect") or obj:IsA("BlurEffect") or obj:IsA("ColorCorrectionEffect") or obj:IsA("SunRaysEffect") then
                pcall(function() obj.Enabled = false end)
            end
        end

        -- 3. ฟังก์ชันแปลงวัตถุเป็น Potato (SmoothPlastic, ไม่สะท้อน, ไร้เงา, ปิดเอฟเฟกต์)
        local function makePotato(obj)
            pcall(function()
                if obj:IsA("BasePart") then
                    obj.Material = Enum.Material.SmoothPlastic
                    obj.Reflectance = 0
                    obj.CastShadow = false
                elseif obj:IsA("Decal") or obj:IsA("Texture") then
                    obj.Transparency = 1
                elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") or obj:IsA("Beam") then
                    obj.Enabled = false
                elseif obj:IsA("Highlight") then
                    obj.Enabled = false
                elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
                    obj.Enabled = false
                elseif obj:IsA("MeshPart") then
                    obj.Material = Enum.Material.SmoothPlastic
                    obj.Reflectance = 0
                    obj.CastShadow = false
                end
            end)
        end

        for _, obj in ipairs(workspace:GetDescendants()) do
            makePotato(obj)
        end

        -- ติดตามมอนสเตอร์หรือเอฟเฟกต์ใหม่ที่เกิดมาระหว่างเล่น แปลงเป็น Potato ทันที
        table.insert(_G.AZ_Connections, workspace.DescendantAdded:Connect(function(obj)
            makePotato(obj)
        end))

        -- 4. ปรับ Terrain (หญ้า น้ำ)
        if workspace.Terrain then
            pcall(function()
                workspace.Terrain.WaterWaveSize = 0
                workspace.Terrain.WaterWaveSpeed = 0
                workspace.Terrain.WaterReflectance = 0
                workspace.Terrain.WaterTransparency = 0
            end)
        end
    end)
end

-- รัน Low FPS Mode ทันที
pcall(enableAutoLowFpsMode)

-- ★ BLACK SCREEN CONTROLLER (สำหรับเครื่อง RAM 4GB ปิด 3D Rendering ลด RAM/GPU เหลือ 0%) ★
local function setupBlackScreenFeature()
    local cfg = getgenv and getgenv().AZ_Config
    local isBlackScreenEnabled = (cfg and cfg.BlackScreen == true)

    local blackGui = Instance.new("ScreenGui")
    blackGui.Name = "AZ_BlackScreen_Overlay"
    blackGui.ResetOnSpawn = false
    blackGui.IgnoreGuiInset = true
    blackGui.DisplayOrder = 999999
    blackGui.Parent = getSafeUiParent()

    local blackFrame = Instance.new("Frame")
    blackFrame.Name = "BlackBackground"
    blackFrame.Size = UDim2.new(1, 0, 1, 0)
    blackFrame.Position = UDim2.new(0, 0, 0, 0)
    blackFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
    blackFrame.BorderSizePixel = 0
    blackFrame.Visible = isBlackScreenEnabled
    blackFrame.ZIndex = 10
    blackFrame.Parent = blackGui

    local infoText = Instance.new("TextLabel")
    infoText.Size = UDim2.new(1, 0, 0, 60)
    infoText.Position = UDim2.new(0, 0, 0.45, 0)
    infoText.BackgroundTransparency = 1
    infoText.Font = Enum.Font.FredokaOne
    infoText.TextColor3 = Color3.fromRGB(255, 220, 100)
    infoText.TextSize = 18
    infoText.Text = "⚡ AXEL HUB · BLACK SCREEN MODE ACTIVE\n(3D Rendering Disabled to Save Maximum RAM & Battery)"
    infoText.ZIndex = 11
    infoText.Parent = blackFrame

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ToggleBlackScreenBtn"
    toggleBtn.Size = UDim2.new(0, 140, 0, 32)
    toggleBtn.Position = UDim2.new(1, -150, 0, 15)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.TextSize = 12
    toggleBtn.Text = isBlackScreenEnabled and "🖥️ Show 3D Screen" or "🌑 Black Screen"
    toggleBtn.ZIndex = 12
    toggleBtn.Parent = blackGui

    local function apply3DRenderingState(active)
        pcall(function()
            if RunService.Set3dRenderingEnabled then
                RunService:Set3dRenderingEnabled(not active)
            end
        end)
    end

    if isBlackScreenEnabled then
        apply3DRenderingState(true)
    end

    toggleBtn.MouseButton1Click:Connect(function()
        isBlackScreenEnabled = not isBlackScreenEnabled
        blackFrame.Visible = isBlackScreenEnabled
        toggleBtn.Text = isBlackScreenEnabled and "🖥️ Show 3D Screen" or "🌑 Black Screen"
        apply3DRenderingState(isBlackScreenEnabled)
        if getgenv().AZ_Config then
            getgenv().AZ_Config.BlackScreen = isBlackScreenEnabled
        end
    end)
end

pcall(setupBlackScreenFeature)

-- ★ NO CLIP HANDLER ★
local lastNoClipTick = 0
local function applyNoClip()
    if tick() - lastNoClipTick < 0.5 then return end
    lastNoClipTick = tick()
    local char = lp.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then
            pcall(function() part.CanCollide = false end)
        end
    end
end

-- ดึงโค้ดโปรโมชั่นทั้งหมดจาก Game Config โดยตรงแบบไดนามิก (เกมเพิ่มโค้ดใหม่จะเคลมทันทีโดยอัตโนมัติ)
local function getDynamicPromoCodes(playerLevel)
    local codes = {}
    pcall(function()
        if codesCfg then
            for codeKey, data in pairs(codesCfg) do
                local minLvl = data.MinimumLevel or 1
                if (playerLevel or 100) >= minLvl then
                    table.insert(codes, data.Code or codeKey)
                end
            end
        end
    end)
    if #codes == 0 then
        codes = {
            "LETSGO", "HAVESOME", "FIRSTUPDATE", "HYPE", "AZISOUT", "Update1",
            "HOP3YOU3NJOY", "DABITHEGOAT", "RELEASE", "Update2", "UPDATETHREE"
        }
    end
    return codes
end

local function getAccState()
    if not accountNS then
        pcall(function()
            local g = RS:FindFirstChild("global")
            local st = g and g:FindFirstChild("stores")
            local ns = st and st:FindFirstChild("accountNamespace")
            if ns then accountNS = safeRequire(ns) end
        end)
    end
    local acc = nil
    if accountNS then
        pcall(function()
            acc = accountNS.getPlayerAccount(lp) or accountNS.getLocalPlayerAccount()
        end)
    end
    local s = acc and acc.state
    if s then
        -- Sync active data to persistent cache
        pcall(function()
            if s.currencies then
                local c = (type(s.currencies) == "table" and (s.currencies.entries or s.currencies.current or s.currencies)) or {}
                local function rVal(v) if type(v) == "table" and v.current ~= nil then return v.current end return v end
                local m = tonumber(rVal(c.money))
                local g = tonumber(rVal(c.gems))
                local zp = tonumber(rVal(c.zenlessPity))
                local ap = tonumber(rVal(c.arcanePity))
                local mp = tonumber(rVal(c.mythicPity))
                local rl = tonumber(rVal(c.rolls))
                local ls = tonumber(rVal(c.luckySpins))
                if m then _G.AZ_Cache.money = m; _G.AZ_Cache.currencies.money = m end
                if g then _G.AZ_Cache.gems = g; _G.AZ_Cache.currencies.gems = g end
                if zp then _G.AZ_Cache.zenlessPity = zp; _G.AZ_Cache.currencies.zenlessPity = zp end
                if ap then _G.AZ_Cache.arcanePity = ap; _G.AZ_Cache.currencies.arcanePity = ap end
                if mp then _G.AZ_Cache.mythicPity = mp; _G.AZ_Cache.currencies.mythicPity = mp end
                if rl then _G.AZ_Cache.rolls = rl; _G.AZ_Cache.currencies.rolls = rl end
                if ls then _G.AZ_Cache.luckySpins = ls; _G.AZ_Cache.currencies.luckySpins = ls end
            end
            if s.character ~= nil then
                local ch = tostring(readVal(s.character))
                if ch ~= "" then _G.AZ_Cache.character = ch end
            end
            if s.material then _G.AZ_Cache.material = s.material end
            if s.craftedAccessories then _G.AZ_Cache.craftedAccessories = s.craftedAccessories end
            if s.accessory then _G.AZ_Cache.accessory = s.accessory end
            if s.CharactersData then _G.AZ_Cache.CharactersData = s.CharactersData end
            if s.UnlockedCharacters then _G.AZ_Cache.UnlockedCharacters = s.UnlockedCharacters end
            if s.achievements then _G.AZ_Cache.achievements = s.achievements end
            if saveCachedData and (tick() - _lastSaveTick > 1) then
                saveCachedData()
            end
        end)
        return s
    end
    -- Fallback to persistent cache in Match or when accountNS is unavailable
    return _G.AZ_Cache
end

local function getAchievementProgress(key)
    local s = getAccState()
    local p = s and s.achievements and s.achievements.progress
    local entries = (type(p) == "table" and (p.entries or p)) or {}
    local v = entries[key]
    if type(v) == "table" then
        if v.get then return v:get() end
        if v.current ~= nil then return v.current end
        if v._value ~= nil then return v._value end
    end
    return tonumber(v) or 0
end

local function readVal(v)
    if type(v) == "table" and v.current ~= nil then return v.current end
    return v
end

local function getCurrency(name)
    local s = getAccState()
    if s and s.currencies and s.currencies[name] ~= nil then
        local v = readVal(s.currencies[name])
        local num = tonumber(v) or 0
        if _G.AZ_Cache then _G.AZ_Cache[name] = num end
        return num
    end
    if _G.AZ_Cache and _G.AZ_Cache[name] ~= nil then
        return tonumber(_G.AZ_Cache[name]) or 0
    end
    return 0
end

local function getCharacter()
    local s = getAccState()
    if s and s.character ~= nil then
        local c = readVal(s.character)
        if c and tostring(c) ~= "" then return tostring(c):lower() end
    end
    if s and s.UnlockedCharacters then
        local slots = (type(s.UnlockedCharacters) == "table" and (s.UnlockedCharacters.entries or s.UnlockedCharacters.current or s.UnlockedCharacters)) or {}
        local s1 = slots[1] or slots["1"] or slots["Slot1"]
        if s1 and s1.Character then
            local c = readVal(s1.Character)
            if c and tostring(c) ~= "" then return tostring(c):lower() end
        end
    end
    local char = lp.Character
    if char and char:FindFirstChild("CharacterName") then
        local val = tostring(char.CharacterName.Value):lower()
        if val ~= "" then return val end
    end
    return "guts"
end

local function getCharacterDisplayName(charKey)
    charKey = charKey or getCharacter()
    if not charKey or charKey == "" then return "None" end
    local low = tostring(charKey):lower()

    local KNOWN_NAMES = {
        guts = "Dragon Eclipse",
        saber = "Lights of Divinity",
        alucard = "Immortal Sovereign",
        sukuna = "Cursed King",
        shanks = "Divine Emperor",
        miyabi = "Cataclysm",
        hutao = "Flame Director",
        luffy = "Rubber Man",
        goku = "Cosmic Warrior",
        killua = "Thunder Prodigy",
        juuzou = "Twisted Agony",
        nagumo = "King's Gambit"
    }
    if KNOWN_NAMES[low] then
        return KNOWN_NAMES[low]
    end

    if charsConstant and charsConstant.charactersByName then
        local cDef = charsConstant.charactersByName[low]
        if cDef and cDef.displayName then
            return cDef.displayName
        end
    end
    if charsConstant and charsConstant[low] then
        local cDef = charsConstant[low]
        if cDef and cDef.displayName then
            return cDef.displayName
        end
    end

    return tostring(charKey):upper()
end

local function getPlayerTraitName()
    local s = getAccState()
    local curChar = tostring(getCharacter()):lower()
    if s and s.CharactersData and s.CharactersData[curChar] then
        local td = s.CharactersData[curChar].TraitData
        local tId = td and td.Trait and (type(td.Trait) == "table" and (td.Trait.current or td.Trait.value) or td.Trait)
        if tId and traitCfg then
            local tInfo = traitCfg[tId] or traitCfg[tostring(tId)]
            if tInfo and tInfo.Name then
                return tInfo.Name
            end
        end
    end
    return "None"
end

local function getPlayerExpProgress()
    local pg = lp:FindFirstChild("PlayerGui")
    local hud = pg and pg:FindFirstChild("HUD")
    if hud then
        local lvlBar = hud:FindFirstChild("LvlBar", true)
        if lvlBar then
            for _, d in ipairs(lvlBar:GetDescendants()) do
                if d:IsA("TextLabel") and d.Text:find("EXP") then
                    return d.Text
                end
            end
        end
    end

    local s = getAccState()
    if s and charProg and charProg.getProgress then
        local curChar = tostring(getCharacter()):lower()
        local cData = s.CharactersData and s.CharactersData[curChar]
        if cData then
            local prog = cData.Progression and (type(cData.Progression) == "table" and (cData.Progression.entries or cData.Progression.current or cData.Progression)) or cData.Progression
            local xpVal = prog and prog.Xp and (type(prog.Xp) == "table" and (prog.Xp.current or prog.Xp.value) or prog.Xp)
            local p = charProg.getProgress(tonumber(xpVal) or 0)
            if p and p.currentXp and p.requiredXp then
                return string.format("%d/%d EXP", p.currentXp, p.requiredXp)
            end
        end
    end
    return nil
end

local function getPlayerLevel()
    -- 1. ตรวจสอบจาก leaderstats (ไวที่สุด ตรงที่สุดทั้ง Lobby และ Match)
    local ls = lp:FindFirstChild("leaderstats")
    if ls and ls:FindFirstChild("Level") and ls.Level.Value and ls.Level.Value > 0 then
        if _G.AZ_Cache then _G.AZ_Cache.level = ls.Level.Value end
        return ls.Level.Value
    end

    -- 2. ตรวจสอบจาก UI HUD ในด่านโดยตรง (ตรงกับหน้าจอเกม 100%)
    local pg = lp:FindFirstChild("PlayerGui")
    local hud = pg and pg:FindFirstChild("HUD")
    if hud then
        local lvlBar = hud:FindFirstChild("LvlBar", true)
        if lvlBar then
            for _, d in ipairs(lvlBar:GetDescendants()) do
                if d:IsA("TextLabel") and d.Text ~= "" then
                    local num = d.Text:match("LEVEL%s*(%d+)") or d.Text:match("Lv%.?%s*(%d+)") or d.Text:match("Lvl%.?%s*(%d+)")
                    if num then
                        local n = tonumber(num)
                        if n and n > 0 then
                            if _G.AZ_Cache then _G.AZ_Cache.level = n end
                            return n
                        end
                    end
                end
            end
        end
    end

    -- 3. คำนวณจาก characterLevelProgression ตาม Progression.Xp ของตัวละครที่เล่นอยู่
    local s = getAccState()
    if s and charProg and charProg.getLevel then
        local curChar = tostring(getCharacter()):lower()
        local cData = s.CharactersData and s.CharactersData[curChar]
        if cData then
            local prog = cData.Progression and (type(cData.Progression) == "table" and (cData.Progression.entries or cData.Progression.current or cData.Progression)) or cData.Progression
            local xpVal = prog and prog.Xp and (type(prog.Xp) == "table" and (prog.Xp.current or prog.Xp.value) or prog.Xp)
            local lvl = charProg.getLevel(tonumber(xpVal) or 0)
            if lvl and lvl > 0 then
                if _G.AZ_Cache then _G.AZ_Cache.level = lvl end
                return lvl
            end
        end

        -- เผื่อคำนวณจาก currencies.xp
        if s.currencies then
            local curr = type(s.currencies) == "table" and (s.currencies.entries or s.currencies.current or s.currencies) or {}
            local xp = curr.xp and (type(curr.xp) == "table" and curr.xp.current or curr.xp) or 0
            local lvl = charProg.getLevel(tonumber(xp) or 0)
            if lvl and lvl > 0 then
                if _G.AZ_Cache then _G.AZ_Cache.level = lvl end
                return lvl
            end
        end
    end

    if _G.AZ_Cache and _G.AZ_Cache.level and _G.AZ_Cache.level > 0 then
        return _G.AZ_Cache.level
    end

    return 1
end

local function getCurrentArea()
    if isMatch then return "Combat Stage" end
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return "Lobby" end

    local areasFolder = workspace:FindFirstChild("Systems") and workspace.Systems:FindFirstChild("AreasTeleportLocation")
    if areasFolder then
        local closestArea = "Lobby"
        local closestDist = 80
        for _, a in ipairs(areasFolder:GetChildren()) do
            if a:IsA("BasePart") then
                local dist = (hrp.Position - a.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestArea = a.Name
                end
            end
        end
        return closestArea
    end
    return "Lobby"
end

-- ══════════════════════════════════════════════════
-- DYNAMIC CHARACTER & RARITY REFLECTION SYSTEM
-- ══════════════════════════════════════════════════
-- ค้นหาตัวละครตามระดับความหายากจาก characterRollConfig โดยตรง
local function getDynamicCharactersByRarity(rarityName)
    local chars = {}
    pcall(function()
        if charRollCfg and charRollCfg.rarities and charRollCfg.rarities[rarityName] and charRollCfg.rarities[rarityName].characters then
            for _, c in ipairs(charRollCfg.rarities[rarityName].characters) do
                table.insert(chars, tostring(c):lower())
            end
        end
    end)
    return chars
end

-- ตรวจสอบการครอบครองตัวละครใดๆ โดยอัตโนมัติ (รองรับทั้งชื่อจริงและ Display Name)
local function hasOwnedCharacter(charName)
    if not charName then return false end
    local target = tostring(charName):lower()
    local s = getAccState()
    if not s then return false end

    -- แมป DisplayName เข้ากับรหัสตัวละคร เช่น Flame Director -> hutao
    if charsConstant and charsConstant.charactersByName then
        for realName, cDef in pairs(charsConstant.charactersByName) do
            if cDef.displayName and cDef.displayName:lower() == target then
                target = realName:lower()
                break
            end
        end
    end

    -- 1. ตัวละครหลักที่สวมใส่อยู่
    if s.character and tostring(readVal(s.character)):lower() == target then return true end
    if getCharacter():lower() == target then return true end

    -- 2. ตัวละครใน UnlockedCharacters (Slot 1..4)
    if s.UnlockedCharacters then
        local slots = (type(s.UnlockedCharacters) == "table" and (s.UnlockedCharacters.entries or s.UnlockedCharacters.current or s.UnlockedCharacters)) or {}
        for _, slot in pairs(slots) do
            if type(slot) == "table" then
                local cVal = slot.Character and (type(slot.Character) == "table" and (slot.Character.current or slot.Character.value or slot.Character._value) or slot.Character)
                if tostring(cVal):lower() == target then return true end
            end
        end
    end

    -- 3. ตรวจสอบจากประวัติ CharactersData
    if s.CharactersData and s.CharactersData[target] then
        local cData = s.CharactersData[target]
        if cData.IsUltimateUnlocked and readVal(cData.IsUltimateUnlocked) == true then return true end
        if cData.Progression and cData.Progression.Xp and (tonumber(readVal(cData.Progression.Xp)) or 0) > 0 then return true end
        if cData.TraitData and cData.TraitData.Trait and (tonumber(readVal(cData.TraitData.Trait)) or 0) > 0 then return true end
        if cData.Progression and cData.Progression.Skills then
            for _, b in ipairs({"ATK", "CRIT", "DEF", "SPD"}) do
                if (tonumber(readVal(cData.Progression.Skills[b])) or 1) > 1 then return true end
            end
        end
    end

    return false
end

local function isLythTier(rName, cName)
    if rName then
        local rLow = tostring(rName):lower()
        if rLow:find("zenless") or rLow:find("lyth") or rLow:find("exclusive") then return true end
    end
    if cName then
        local cClean = tostring(cName):lower():gsub("[%s_%-]", "")
        if cClean == "miyabi" or cClean == "hutao" or cClean:find("cataclysm") or cClean:find("flamedirector") then
            return true
        end
    end
    return false
end

-- ค้นหาและดึงตัวละครระดับ LYTH (Zenless / Exclusive) ที่ผู้เล่นครอบครองอยู่ (ทั้งจาก Summon หรือ Raid)
local function getOwnedLythCharacter()
    -- 1. ตรวจสอบจากสล็อต 1..4 โดยตรง
    local s = getAccState()
    if s and s.UnlockedCharacters then
        local slots = (type(s.UnlockedCharacters) == "table" and (s.UnlockedCharacters.entries or s.UnlockedCharacters.current or s.UnlockedCharacters)) or {}
        for _, slot in pairs(slots) do
            if type(slot) == "table" then
                local cVal = slot.Character and (type(slot.Character) == "table" and (slot.Character.current or slot.Character.value or slot.Character._value) or slot.Character)
                if cVal and tostring(cVal) ~= "" then
                    local cName = tostring(cVal):lower()
                    if isLythTier(nil, cName) then
                        return cName
                    end
                end
            end
        end
    end

    -- 2. ตรวจสอบจากตู้หรือประวัติการครอบครอง
    local lythChars = getDynamicCharactersByRarity("Zenless")
    if #lythChars == 0 then lythChars = {"hutao", "miyabi"} end
    for _, c in ipairs(lythChars) do
        if hasOwnedCharacter(c) then return c end
    end
    if hasOwnedCharacter("miyabi") then return "miyabi" end
    if hasOwnedCharacter("hutao") then return "hutao" end
    return nil
end

-- ตรวจสอบว่าผู้เล่นมีตัวละครระดับ Lyth ในตัวแล้วหรือไม่ (ไม่ว่าจะได้จาก Summon หรือ Raid)
local function hasAnyLythCharacter()
    local c = getOwnedLythCharacter()
    return (c ~= nil), c
end

local function hasFlameDirector()
    return hasOwnedCharacter("hutao")
end

local function hasMiyabi()
    return hasOwnedCharacter("miyabi")
end

local MYTHIC_PLUS_IDS = {
    ["saber"] = true,
    ["guts"] = true,
    ["alucard"] = true,
    ["sukuna"] = true,
    ["shanks"] = true,
    ["miyabi"] = true,
    ["hutao"] = true
}

local MYTHIC_PLUS_DISPLAY = {
    ["lightsofdivinity"] = true,
    ["dragoneclipse"] = true,
    ["immortalsovereign"] = true,
    ["cursedking"] = true,
    ["divineemperor"] = true,
    ["cataclysm"] = true,
    ["flamedirector"] = true
}

local function getCharacterRarity(cName)
    if not cName or cName == "" then return "None" end
    local clean = tostring(cName):lower():gsub("[%s_%-]", "")

    if clean == "miyabi" or clean == "hutao" or clean:find("cataclysm") or clean:find("flamedirector") then
        return "Zenless"
    end
    if clean == "sukuna" or clean == "shanks" or clean:find("cursedking") or clean:find("divineemperor") then
        return "Arcane"
    end
    if clean == "saber" or clean == "guts" or clean == "alucard" or clean:find("dragoneclipse") or clean:find("lightsofdivinity") or clean:find("immortalsovereign") then
        return "Mythic"
    end
    if clean == "juuzou" or clean == "nagumo" or clean:find("twistedagony") or clean:find("kingsgambit") then
        return "Legendary"
    end
    if clean == "luffy" or clean == "goku" or clean == "killua" or clean:find("rubberman") or clean:find("cosmicwarrior") or clean:find("thunderprodigy") then
        return "Epic"
    end

    if charRollCfg and charRollCfg.rarities then
        for rName, rData in pairs(charRollCfg.rarities) do
            if rData.characters then
                for _, c in ipairs(rData.characters) do
                    if tostring(c):lower() == clean then
                        return rName
                    end
                end
            end
        end
    end

    return "Unknown"
end

local function isMythicOrHigher(rName, cName)
    if rName then
        local rLow = tostring(rName):lower()
        if rLow:find("myth") or rLow:find("arcane") or rLow:find("zenless") or rLow:find("lyth") or rLow:find("exclusive") then
            return true
        end
    end
    if cName then
        local cClean = tostring(cName):lower():gsub("[%s_%-]", "")
        if MYTHIC_PLUS_IDS[cClean] or MYTHIC_PLUS_DISPLAY[cClean] then
            return true
        end
        for id, _ in pairs(MYTHIC_PLUS_IDS) do
            if cClean:find(id, 1, true) then return true end
        end
        for dName, _ in pairs(MYTHIC_PLUS_DISPLAY) do
            if cClean:find(dName, 1, true) then return true end
        end
    end
    return false
end

-- (isLythTier ประกาศไว้ด้านบนแล้ว)

-- (getSlotCharacterInfo ถูกประกาศไว้ด้านบนแล้ว)

-- ค้นหาข้อมูลตัวละครระดับ Lyth ที่ได้จาก Summon (ไม่ใช่ Hu Tao จาก Raid)
local function getSummonLythInfo()
    local s = getAccState()
    if s and s.UnlockedCharacters then
        local slots = (type(s.UnlockedCharacters) == "table" and (s.UnlockedCharacters.entries or s.UnlockedCharacters.current or s.UnlockedCharacters)) or {}
        for slotKey, slot in pairs(slots) do
            if type(slot) == "table" then
                local cVal = slot.Character and (type(slot.Character) == "table" and (slot.Character.current or slot.Character.value or slot.Character._value) or slot.Character)
                if cVal and tostring(cVal) ~= "" then
                    local cName = tostring(cVal):lower()
                    local slotNum = tonumber(tostring(slotKey):match("%d+")) or 1
                    if isLythTier(nil, cName) and cName ~= "hutao" and not cName:find("flamedirector") then
                        return slotNum, cName
                    end
                end
            end
        end
    end
    if hasOwnedCharacter("miyabi") then
        return 2, "miyabi"
    end
    return nil, nil
end

-- ค้นหาตัวละครที่ดีที่สุดที่ครอบครองอยู่ในสล็อต 1..4 (Zenless/Lyth > Arcane > Mythic > Legendary)
-- กฎเหล็ก: ถ้ายังไม่มีตัวระดับ Lyth ให้เลือกตัวฟาร์มหลักใน Slot 1 เสมอ (ห้ามเอาตัวสุ่มค้างใน Slot 2 มาใช้เด็ดขาด!)
local function getBestOwnedCharacter()
    local ok, res = pcall(function()
        -- 1. ถ้าได้ Flame Director (Hu Tao) มาและยังไม่ได้ Awakening: ให้ใช้ Hu Tao เพื่อฟาร์มของทำ Awakening ให้เสร็จ
        if hasFlameDirector() and not isCharacterAwakened("hutao") then
            return "hutao"
        end

        -- 2. เมื่อ Hu Tao Awakening เสร็จแล้ว หรือในขั้นตอนฟาร์ม 100 Material ทุกอัน: ให้ใช้ Summon Lyth (เช่น Miyabi) เป็นตัวหลักเสมอ!
        local summonSlot, summonLyth = getSummonLythInfo()
        if summonLyth then
            return summonLyth
        end

        -- 3. ถ้าไม่มี Summon Lyth แต่มี Hu Tao (Awakened): ให้ใช้ Hu Tao
        if hasFlameDirector() then
            return "hutao"
        end

        -- ค. ตัวละครระดับ LYTH ทั่วไป (เช่น Hu Tao หลังจาก Awakening เสร็จแล้ว หรือตัว Lyth อื่น)
        local lyth = getOwnedLythCharacter()
        if lyth then return lyth end

        -- ง. ถ้ายังไม่มีตัวระดับ Lyth: ให้ใช้ตัวละครหลักใน Slot 1 เท่านั้น!
        local s1Char, s1Rarity = getSlotCharacterInfo(1)
        if s1Char and s1Char ~= "" then
            return s1Char:lower()
        end

        local s = getAccState()
        if not s or not s.UnlockedCharacters then return nil end
        local slots = (type(s.UnlockedCharacters) == "table" and (s.UnlockedCharacters.entries or s.UnlockedCharacters.current or s.UnlockedCharacters)) or {}
        local slot1 = slots.Slot1 or slots["1"]
        if slot1 then
            local cVal = slot1.Character and (type(slot1.Character) == "table" and (slot1.Character.current or slot1.Character.value or slot1.Character._value) or slot1.Character)
            if cVal and tostring(cVal) ~= "" then return tostring(cVal):lower() end
        end
        return nil
    end)
    if ok and res then return res end
    return nil
end

-- สลับสวมใส่ตัวละครโดยอัตโนมัติหากครอบครองอยู่ในสล็อต (1..4)
-- ★ ล็อค (Favourite / Lock) ตัวละครระดับ LYTH ทุกตัวในทุกสล็อตอัตโนมัติ เพื่อป้องกันการสุ่มทับหรือขายทิ้ง
local function autoLockLythSlots()
    if isMatch then return end
    if not lobbyPkts then lobbyPkts = getLobbyPackets() end
    if not lobbyPkts or not lobbyPkts.setCharacterSlotFavourite then return end
    local s = getAccState()
    if not s or not s.UnlockedCharacters then return end

    local slots = (type(s.UnlockedCharacters) == "table" and (s.UnlockedCharacters.entries or s.UnlockedCharacters.current or s.UnlockedCharacters)) or {}
    for slotKey, slot in pairs(slots) do
        if type(slot) == "table" then
            local cVal = slot.Character and (type(slot.Character) == "table" and (slot.Character.current or slot.Character.value or slot.Character._value) or slot.Character)
            local isFav = slot.Favourite and (type(slot.Favourite) == "table" and (slot.Favourite.current or slot.Favourite.value or slot.Favourite._value) or slot.Favourite)
            if cVal and tostring(cVal) ~= "" then
                local cName = tostring(cVal):lower()
                local slotNum = tonumber(tostring(slotKey):match("%d+"))
                if slotNum and isLythTier(nil, cName) and not isFav then
                    setTask(string.format("🔒 ล็อคตัวละครระดับ LYTH [%s] ใน Slot %d (ป้องกันการสุ่มทับ)...", cName:upper(), slotNum))
                    pcall(function()
                        lobbyPkts.setCharacterSlotFavourite:fire({
                            slot = slotNum,
                            favourite = true,
                            requestId = nextId()
                        })
                    end)
                    task.wait(0.2)
                end
            end
        end
    end
end

-- ★ สวมใส่ตัวละครสำรองใน GameSlot 2 เพื่อรับโบนัส Synergy Tag Team (+5% Damage in runs) ตลอดเวลา
-- กฎพิเศษ:
-- 1. ถ้ามีตัวระดับ LYTH 2 ตัวขึ้นไป (เช่น Summon Lyth อย่าง Miyabi + Raid Lyth อย่าง Hu Tao)
--    ให้สวมใส่ Lyth ทั้งสองตัวคู่กันใน GameSlot 1 และ GameSlot 2 ทันที! (Dual Lyth Tag Team)
-- 2. ถ้ามี Lyth ตัวเดียว: GameSlot 1 = Lyth, GameSlot 2 = Sub Summon (Slot 1) เพื่อเอาโบนัส +5% Damage
-- 3. ถ้ายังไม่มี Lyth: GameSlot 1 = Sub Summon (Slot 1), GameSlot 2 = Slot 2 เพื่อเอาโบนัส +5% Damage
local function ensureSupportGameSlot2Equipped(mainSlotNum)
    if isMatch then return end
    pcall(autoLockLythSlots)
    -- ป้องกันบั๊กสลับตัวผิด: ใน Anime Zero เมื่อสวมใส่ GameSlot 1 ตัวสำรองจะถูกตั้งอัตโนมัติ
    -- การยิง packet equipCharacterSlot ซ้ำสำหรับ GameSlot 2 จะทำให้เซิร์ฟเวอร์สลับตัวละคร (Swap)
    -- ส่งผลให้ตัวใน Slot 2 (เช่น Nagumo/Switchblade) ถูกถือลงด่านแทน Dragon Eclipse (Slot 1)
end

local function autoEquipCharacterIfOwned(charName, force)
    if not lobbyPkts then lobbyPkts = getLobbyPackets() end
    if not lobbyPkts or not lobbyPkts.equipCharacterSlot then return end
    local s = getAccState()
    if not s or not s.UnlockedCharacters then return end
    local target = charName:lower()
    if not force and getCharacter():lower() == target then
        return
    end

    local slots = (type(s.UnlockedCharacters) == "table" and (s.UnlockedCharacters.entries or s.UnlockedCharacters.current or s.UnlockedCharacters)) or {}
    for slotKey, slot in pairs(slots) do
        if type(slot) == "table" then
            local cVal = slot.Character and (type(slot.Character) == "table" and (slot.Character.current or slot.Character.value or slot.Character._value) or slot.Character)
            if tostring(cVal):lower() == target then
                local slotNum = tonumber(tostring(slotKey):match("%d+")) or 1
                -- ความปลอดภัยสูงสุด: ถ้าไม่ใช่ Slot 1 และตัวละครไม่ใช่ระดับ Lyth ห้ามสวมใส่เด็ดขาด!
                if slotNum ~= 1 and not isLythTier(nil, target) then
                    return
                end
                local dName = getCharacterDisplayName(target)
                setTask(string.format("🎮 สลับสวมใส่ [%s] จากสล็อต %d...", dName:upper(), slotNum))
                pcall(function()
                    lobbyPkts.equipCharacterSlot:fire({
                        slot = slotNum,
                        gameSlot = 1,
                        requestId = nextId()
                    })
                end)
                task.wait(0.4)
                if upgradeActiveSkillsIfPointsAvailable then
                    pcall(function() upgradeActiveSkillsIfPointsAvailable(target) end)
                end
                break
            end
        end
    end
end

-- มั่นใจ 100% ว่าสวมใส่ตัวละครที่ถูกต้องตามระบบ:
-- 1. ถ้ามีตัวละครระดับ LYTH แล้ว (เช่น Miyabi / Hutao) ต้องสวมใส่ตัว Lyth เสมอ 100%!
-- 2. ถ้ายังไม่มีตัวระดับ Lyth: ให้สวมใส่ตัวฟาร์มหลักใน Slot 1 (เช่น Dragon Eclipse / Guts)
-- ห้ามสลับไปใช้ตัวขยะ/ตัวสุ่มค้างใน Slot 2 เด็ดขาดจนกว่าจะได้ระดับ Lyth
local function ensureCorrectCharacterEquipped()
    if isMatch then return end
    if not lobbyPkts then lobbyPkts = getLobbyPackets() end
    if not lobbyPkts or not lobbyPkts.equipCharacterSlot then return end

    pcall(autoLockLythSlots)

    -- 1. ถ้ามี Hu Tao แต่ยังไม่ Awakening: สวมใส่ Hu Tao ลง GameSlot 1 เพื่อฟาร์มของ Awakening
    if hasFlameDirector() and not isCharacterAwakened("hutao") then
        autoEquipCharacterIfOwned("hutao")
        return
    end

    -- 2. ถ้า Hu Tao Awakening แล้ว แต่อยู่ในขั้นตอนหา 100 Material ทุกวัน: สวมใส่ Summon Lyth (เช่น Miyabi) ลง GameSlot 1 ทันที!
    local summonSlot, summonLyth = getSummonLythInfo()
    if summonLyth then
        autoEquipCharacterIfOwned(summonLyth)
        return
    end

    -- 3. ถ้าไม่มี Summon Lyth แต่มี Hu Tao: สวมใส่ต่อ Hu Tao
    if hasFlameDirector() then
        autoEquipCharacterIfOwned("hutao")
        return
    end

    -- ๔. ตัว Lyth อื่นๆ (เช่น จาก Summon / Raid)
    local hasLyth, lythChar = hasAnyLythCharacter()
    if hasLyth and lythChar then
        autoEquipCharacterIfOwned(lythChar)
        return
    end

    -- ๕. ถ้ายังไม่มีตัวระดับ Lyth: บังคับสวมใส่ตัวละครหลักใน Slot 1 (Dragon Eclipse / Guts) เสมอ 100%!
    local s1Char, s1Rarity = getSlotCharacterInfo(1)
    if not s1Char or s1Char == "" then s1Char = "guts" end

    local curChar = getCharacter():lower()
    local s = getAccState()
    local eqSlots = s and s.EquippedCharacterSlots
    local curG1 = eqSlots and eqSlots.Slot1 and (type(eqSlots.Slot1) == "table" and (eqSlots.Slot1.current or eqSlots.Slot1.value or eqSlots.Slot1._value) or eqSlots.Slot1)
    curG1 = tonumber(curG1)

    if curG1 ~= 1 or curChar ~= s1Char:lower() then
        local displayName = getCharacterDisplayName(s1Char) or "Dragon Eclipse"
        setTask(string.format("🎮 สวมใส่ตัวแบกหลัก Slot 1 [%s] เพื่อฟาร์มเงิน...", displayName:upper()))
        pcall(function()
            lobbyPkts.equipCharacterSlot:fire({
                slot = 1,
                gameSlot = 1,
                requestId = nextId()
            })
        end)
        task.wait(0.35)
        if upgradeActiveSkillsIfPointsAvailable and s1Char and s1Char ~= "" then
            pcall(function() upgradeActiveSkillsIfPointsAvailable(s1Char) end)
        end
    end
end
local ensureSlot1Equipped = ensureCorrectCharacterEquipped

-- (getSummonLythInfo ย้ายขึ้นไปอยู่ด้านบนก่อน getBestOwnedCharacter เรียบร้อยแล้ว)

-- นำตัวละคร Flame Director (Hu Tao) จาก Raid ไปใส่ในช่องที่ไม่ใช่ช่อง Lyth จาก Summon
-- ★ กฎเหล็ก: ห้ามทับช่องตัวระดับ Lyth ที่ได้จาก Summon (เช่น Miyabi) เด็ดขาด! ★
local function placeHuTaoInNonSummonSlot()
    if not hasFlameDirector() then return false end
    pcall(Webhook.notifyHuTao)
    if not lobbyPkts or not lobbyPkts.placeStoredUnit then
        lobbyPkts = getLobbyPackets()
    end
    if not lobbyPkts or not lobbyPkts.placeStoredUnit then return false end

    -- ตรวจสอบก่อนว่า Hu Tao อยู่ในสล็อตใดสล็อตหนึ่งอยู่แล้วหรือไม่
    local s = getAccState()
    if s and s.UnlockedCharacters then
        for slotKey, slot in pairs(s.UnlockedCharacters) do
            if type(slot) == "table" then
                local cVal = slot.Character and (type(slot.Character) == "table" and (slot.Character.current or slot.Character.value or slot.Character._value) or slot.Character)
                if tostring(cVal):lower() == "hutao" then
                    return true -- มี Hu Tao ในช่องอยู่แล้ว ไม่ต้องย้ายซ้ำ
                end
            end
        end
    end

    local summonSlot, summonLyth = getSummonLythInfo()

    -- ค้นหาช่องที่ Unlocked แล้ว และไม่ใช่ช่อง Summon Lyth (ห้ามทับช่อง Lyth จาก Summon เด็ดขาด!)
    -- ลำดับค้นหา: Slot 1 -> Slot 3 -> Slot 4 -> Slot 2
    local searchSlots = {1, 3, 4, 2}
    for _, slotNum in ipairs(searchSlots) do
        if slotNum ~= summonSlot then
            local cName, cRarity, isUnl = getSlotCharacterInfo(slotNum)
            if isUnl and (not isLythTier(cRarity, cName) or cName == "hutao") then
                setTask(string.format("📥 นำ Flame Director (Hu Tao) เข้า Slot %d (ไม่ทับช่อง %s)...", slotNum, summonLyth and summonLyth:upper() or "SUMMON LYTH"))
                pcall(function()
                    lobbyPkts.placeStoredUnit:fire({
                        character = "hutao",
                        slot = slotNum,
                        requestId = nextId()
                    })
                end)
                task.wait(0.5)
                pcall(autoLockLythSlots)
                pcall(ensureSupportGameSlot2Equipped)
                return true
            end
        end
    end
    return false
end
local placeHuTaoInNonLythSlot = placeHuTaoInNonSummonSlot

-- ดึงจำนวน Material ในตัวของผู้เล่น
local function getMaterialCount(idStr)
    local s = getAccState()
    if not s or not s.material then return 0 end
    local matTable = (type(s.material) == "table" and (s.material.entries or s.material.current or s.material)) or {}
    local v = matTable[tostring(idStr)]
    if type(v) == "table" and v.current ~= nil then v = v.current end
    return tonumber(v) or 0
end

-- 3. AUTO UNLOCK & AUTO EQUIP BEST TITLE STAT (คำนวณคะแนน Stat และสวมใส่ฉายาที่ดีที่สุดอัตโนมัติทุกครั้ง)
local function getTitleConfig()
    if not titleCfg then
        local a = RS:FindFirstChild("assets") or RS:WaitForChild("assets", 3)
        local c = a and (a:FindFirstChild("config") or a:WaitForChild("config", 3))
        local tc = c and (c:FindFirstChild("titleConfig") or c:WaitForChild("titleConfig", 3))
        if tc then titleCfg = safeRequire(tc) end
    end
    return titleCfg
end

local function calcTitleStatScore(titleData)
    if not titleData then return -1 end
    local score = 0
    local buffs = titleData.Buffs or {}
    for _, b in ipairs(buffs) do
        local bType = tostring(b.Type or "")
        local val = tonumber(b.Percent or b.Amount or 0) or 0
        if bType == "Damage" then
            score = score + val * 10
        elseif bType:find("Critical") then
            score = score + val * 8
        elseif bType == "Drop Rate" then
            score = score + val * 7
        elseif bType == "Cooldown Reduction" then
            score = score + val * 6
        elseif bType == "Coins" then
            score = score + val * 5
        elseif bType == "Exp" then
            score = score + val * 4
        elseif bType == "HP" then
            score = score + val * 2
        elseif bType == "Walk Speed" then
            score = score + val * 2
        else
            score = score + val
        end
    end
    local tier = tonumber(titleData.Tier) or 1
    score = score + tier * 0.1
    return score
end

local function formatTitleBuffs(titleData)
    if not titleData or not titleData.Buffs or #titleData.Buffs == 0 then return "ไม่มีบัฟ" end
    local parts = {}
    for _, b in ipairs(titleData.Buffs) do
        local bType = tostring(b.Type or "")
        local val = b.Percent or b.Amount or 0
        local sign = (b.Percent and "%") or ""
        table.insert(parts, string.format("%s +%s%s", bType, tostring(val), sign))
    end
    return table.concat(parts, ", ")
end

local function autoEquipBestTitle()
    local s = getAccState()
    if not s or not s.title then return end
    local titles = (type(s.title) == "table" and (s.title.entries or s.title.current or s.title)) or {}
    local curEquipped = tostring(readVal(s.equippedTitle) or "")

    local cfg = getTitleConfig()
    local bestId = nil
    local bestScore = -1
    local bestTitleData = nil

    for id, v in pairs(titles) do
        local isUnlocked = (type(v) == "table" and (v.current == true or v.value == true)) or (v == true)
        if isUnlocked then
            local strId = tostring(id)
            local tData = cfg and cfg[strId]
            local score = calcTitleStatScore(tData)
            if score <= 0 then
                score = (tonumber(strId) or 0) * 0.001
            end
            if score > bestScore then
                bestScore = score
                bestId = strId
                bestTitleData = tData
            end
        end
    end

    if bestId and bestId ~= curEquipped then
        local tName = bestTitleData and bestTitleData.Name or string.format("Title #%s", bestId)
        local buffsDesc = formatTitleBuffs(bestTitleData)
        setTask(string.format("👑 สวมใส่ฉายา Stat ดีที่สุด: %s [#%s] (%s)", tName, bestId, buffsDesc))
        pcall(function()
            lobbyPkts = getLobbyPackets()
            if lobbyPkts and lobbyPkts.equipTitle then lobbyPkts.equipTitle:fire(bestId) end
            if RS:FindFirstChild("EquipTitle") then RS.EquipTitle:FireServer(bestId) end
        end)
    end
end

-- 4. AUTO EVOLVE AWAKENING & MATERIALS CHECK
local function isCharacterAwakened(charName)
    local s = getAccState()
    if not s or not s.CharactersData then return false end
    local cData = s.CharactersData[charName:lower()]
    if cData and cData.IsUltimateUnlocked then
        return readVal(cData.IsUltimateUnlocked) == true
    end
    return false
end

local function getMissingAwakeningMaterials(charName)
    local evoCfg = RS:FindFirstChild("assets") and RS.assets:FindFirstChild("config") and RS.assets.config:FindFirstChild("evolutionConfig") and require(RS.assets.config.evolutionConfig)
    if not evoCfg or not evoCfg[charName:lower()] then return {} end

    local req = evoCfg[charName:lower()]
    local ultStr = req.ultimate or ""
    local missing = {}
    for mReq in ultStr:gmatch("[^|]+") do
        local mId, mAmt = mReq:match("^(%d+),(%d+)$")
        if mId and mAmt then
            local curCount = getMaterialCount(mId)
            local need = tonumber(mAmt)
            if curCount < need then
                missing[mId] = need - curCount
            end
        end
    end

    -- ตรวจสอบ Currencies ที่จำเป็น เช่น Gems หรือ Money สำหรับการ Evolve
    if req.currencies and type(req.currencies) == "table" then
        for _, c in ipairs(req.currencies) do
            local cType = c.currency
            local needAmt = tonumber(c.amount) or 0
            local curAmt = getCurrency(cType)
            if curAmt < needAmt then
                missing[cType] = needAmt - curAmt
            end
        end
    end

    return missing
end

local function autoEvolveAwakening(charName)
    if not charName then return false end
    local cClean = tostring(charName):lower():gsub("[%s_%-]", "")
    -- 🔒 ล็อคความปลอดภัย: ห้าม Evolve ตัวละคร Sub Summon หรือตัวที่ไม่ใช่ระดับ LYTH / Hu Tao เด็ดขาด!
    if not isLythTier(nil, cClean) and cClean ~= "hutao" and not cClean:find("flamedirector") and not cClean:find("miyabi") then
        return false
    end
    if isCharacterAwakened(cClean) then return true end
    local missing = getMissingAwakeningMaterials(cClean)
    if next(missing) == nil then
        local isEng = isEnglishEnabled()
        setTask(string.format(isEng and "⚡ Unlocking Awakening (Evolve) for %s!" or "⚡ ปลดล็อก Awakening (Evolve) ให้ %s!", cClean:upper()))
        pcall(function()
            if not lobbyPkts then lobbyPkts = getLobbyPackets() end
            if lobbyPkts and lobbyPkts.evolveCharacter then
                -- รูปแบบที่ถูกต้อง 100%: ส่ง string (charName) ตาม Schema ของ Server
                lobbyPkts.evolveCharacter:fire(cClean)
            end
            if RS:FindFirstChild("EvolveCharacter") then
                RS.EvolveCharacter:FireServer(cClean)
            end
        end)
        task.wait(1.0)
        if upgradeActiveSkillsIfPointsAvailable then
            pcall(function() upgradeActiveSkillsIfPointsAvailable(cClean) end)
        end
        local isAwk = isCharacterAwakened(cClean)
        if isAwk then
            pcall(function() Webhook.notifyAwakening(cClean) end)
        end
        return isAwk
    end
    return false
end

-- 5. AUTO EQUIP BEST ACCESSORY
local function getBestCraftedAccessory()
    local s = getAccState()
    if not s then return nil end
    local bestId = nil
    local bestNum = -1

    -- 1. จาก craftedAccessories (บันทึก item ID เช่น 101, 102, 114)
    if s.craftedAccessories then
        local crafted = (type(s.craftedAccessories) == "table" and (s.craftedAccessories.entries or s.craftedAccessories.current or s.craftedAccessories)) or {}
        for id, _ in pairs(crafted) do
            local num = tonumber(id) or 0
            if num > bestNum then
                bestNum = num
                bestId = tostring(id)
            end
        end
    end

    -- 2. จาก accessory inventory กระเป๋าเก็บไอเทม
    if s.accessory then
        local accInv = (type(s.accessory) == "table" and (s.accessory.entries or s.accessory.current or s.accessory)) or {}
        for id, _ in pairs(accInv) do
            local num = tonumber(id) or 0
            if num > bestNum then
                bestNum = num
                bestId = tostring(id)
            end
        end
    end

    return bestId
end

local function autoEquipBestAccessory()
    pcall(function()
        local s = getAccState()
        local bestId = getBestCraftedAccessory()
        if not bestId then return end
        local curEquipped = tostring(readVal(s and s.equippedAccessory) or "")
        if bestId ~= curEquipped then
            setTask(string.format("💍 สวมใส่ Best Accessory #%s อัตโนมัติ!", bestId))
            if lobbyPkts and lobbyPkts.setEquippedAccessory then
                lobbyPkts.setEquippedAccessory:fire(bestId)
                lobbyPkts.setEquippedAccessory:fire(tonumber(bestId))
            end
            if RS:FindFirstChild("SetEquippedAccessory") then
                RS.SetEquippedAccessory:FireServer(bestId)
            end
        end
    end)
end

-- ดึงข้อมูลด่านสำหรับดรอป Material แต่ละชนิดแบบไดนามิกจาก materialDropConfig (เฉพาะ Story Mode & Raid เท่านั้น! ไม่ลง Endless/Infinite)
local function getStageForMaterial(matId)
    matId = tostring(matId)
    local bestStage = nil
    local bestChance = 0

    pcall(function()
        if matDropCfg and matDropCfg.Tables then
            for mapKey, mapTable in pairs(matDropCfg.Tables) do
                local mapLow = mapKey:lower()
                -- ★ ตัดโหมด Infinite / Endless ออกทั้งหมด 100% ตามคำสั่ง ★
                if not (mapLow:find("infinite") or mapLow:find("endless")) then
                    for chIndex, dropList in ipairs(mapTable) do
                        if type(dropList) == "table" then
                            for _, entry in ipairs(dropList) do
                                if tostring(entry.Item) == matId then
                                    local c = 0
                                    if type(entry.Chance) == "table" then
                                        c = entry.Chance.Nightmare or entry.Chance.Hard or entry.Chance.Medium or entry.Chance.Easy or 0.1
                                    else
                                        c = tonumber(entry.Chance) or 0.1
                                    end
                                    if c > bestChance then
                                        bestChance = c
                                        local gm = "Story"
                                        local mName = mapKey
                                        if mapLow:find("raid") or mapLow:find("spirited") then
                                            gm = "Raid"
                                            mName = "BathTub"
                                        elseif mapLow == "hxh" then
                                            mName = "Hxh"
                                        elseif mapLow == "sakamoto" then
                                            mName = "Sakamoto"
                                        end
                                        bestStage = { gm = gm, map = mName, ch = chIndex, diff = 4 }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    if bestStage then
        return bestStage.gm, bestStage.map, bestStage.ch, bestStage.diff
    end

    if matId == "113" or matId == "114" then
        return "Raid", "BathTub", 1, 4
    end
    -- Fallback สำหรับ Story Mode: ด่าน HxH Ch.2 [Nightmare]
    return "Story", "Hxh", 2, 4
end

-- ==================================================
-- ACCESSORY RECIPE REFLECTION & CRAFTING STATE
-- ==================================================
local ACC_MAPPING = {
    [14] = { itemId = "114", name = "Blast Archer Wings", rarity = "Mythic" },
    [13] = { itemId = "113", name = "Blast Archer Crown", rarity = "Mythic" },
    [12] = { itemId = "112", name = "Flame Pirate Hat", rarity = "Legendary" },
    [11] = { itemId = "111", name = "Dark Captain Wings", rarity = "Legendary" },
    [10] = { itemId = "110", name = "Wind Spirit Wing", rarity = "Legendary" },
    [9]  = { itemId = "109", name = "Light Admiral Cloak", rarity = "Legendary" },
    [8]  = { itemId = "108", name = "Panther Hollow Mask", rarity = "Epic" },
    [7]  = { itemId = "107", name = "Diva Headphones", rarity = "Epic" },
    [6]  = { itemId = "106", name = "Kitsune Mask", rarity = "Rare" },
    [5]  = { itemId = "105", name = "SunGlasses", rarity = "Rare" },
    [4]  = { itemId = "104", name = "8th Brigade Fire Hat", rarity = "Rare" },
    [3]  = { itemId = "103", name = "Capsule Scarf", rarity = "Common" },
    [2]  = { itemId = "102", name = "Gentleman's Top Hat", rarity = "Common" },
    [1]  = { itemId = "101", name = "Leaf Shinobi Headband", rarity = "Common" },
}

local function isAccessoryOwnedOrCrafted(rId, recipeData)
    local s = getAccState()
    if not s then return false end

    local mapDef = ACC_MAPPING[tonumber(rId)]
    local targetItemId = tostring((recipeData and (recipeData.CarftID or recipeData.CraftID)) or (mapDef and mapDef.itemId) or (tonumber(rId) and (tonumber(rId) + 100)) or rId)
    local rIdStr = tostring(rId)

    -- 1. เช็คใน craftedAccessories
    local crafted = (type(s.craftedAccessories) == "table" and (s.craftedAccessories.entries or s.craftedAccessories.current or s.craftedAccessories)) or {}
    if crafted[targetItemId] ~= nil or crafted[rIdStr] ~= nil then
        return true
    end

    -- 2. เช็คใน inventory กระเป๋า Accessory
    if s.accessory then
        local accInv = (type(s.accessory) == "table" and (s.accessory.entries or s.accessory.current or s.accessory)) or {}
        local count1 = tonumber(accInv[targetItemId]) or (type(accInv[targetItemId]) == "table" and tonumber(accInv[targetItemId].current or accInv[targetItemId]._value)) or 0
        local count2 = tonumber(accInv[rIdStr]) or (type(accInv[rIdStr]) == "table" and tonumber(accInv[rIdStr].current or accInv[rIdStr]._value)) or 0
        if count1 > 0 or count2 > 0 or accInv[targetItemId] ~= nil or accInv[rIdStr] ~= nil then
            return true
        end
    end

    -- 3. เช็คที่กำลังสวมใส่อยู่
    local curEq = tostring(readVal(s.equippedAccessory) or "")
    if curEq == targetItemId or curEq == rIdStr then
        return true
    end

    return false
end

-- ══════════════════════════════════════════════════
-- DISCORD WEBHOOK NOTIFICATION SYSTEM (AXEL HUB)
-- ══════════════════════════════════════════════════
local Webhook = {
    _notifiedHuTao = false,
    _notifiedLyth = false,
    matCfgCache = nil
}

function Webhook.getMaterialName(idStr)
    local num = tonumber(idStr)
    if not num then return "Material #" .. tostring(idStr) end
    if not Webhook.matCfgCache then
        local mc = RS:FindFirstChild("assets") and RS.assets:FindFirstChild("config") and RS.assets.config:FindFirstChild("materialConfig")
        if mc then
            Webhook.matCfgCache = safeRequire(mc)
        end
    end
    if Webhook.matCfgCache and Webhook.matCfgCache[tostring(idStr)] then
        local entry = Webhook.matCfgCache[tostring(idStr)]
        return entry.Name or entry.DisplayName or ("Material #" .. tostring(idStr))
    end
    return "Material #" .. tostring(idStr)
end

function Webhook.formatCommas(val)
    local n = tonumber(val) or 0
    local formatted = tostring(math.floor(n))
    local k
    while true do
        formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

function Webhook.getInventorySnapshot()
    local s = getAccState()
    local snap = {
        materials = {},
        money = getCurrency and getCurrency("money") or 0,
        gems = getCurrency and getCurrency("gems") or 0,
        hasHuTao = hasFlameDirector and hasFlameDirector() or false,
    }
    if s and s.material then
        local matTable = (type(s.material) == "table" and (s.material.entries or s.material.current or s.material)) or {}
        for k, v in pairs(matTable) do
            local val = type(v) == "table" and (v.current or v.value or v._value) or v
            snap.materials[tostring(k)] = tonumber(val) or 0
        end
    end
    return snap
end

function Webhook.getMatchDropsDelta(startSnap)
    if not startSnap then return {} end
    local drops = {}
    local s = getAccState()
    if s and s.material then
        local matTable = (type(s.material) == "table" and (s.material.entries or s.material.current or s.material)) or {}
        for k, v in pairs(matTable) do
            local val = type(v) == "table" and (v.current or v.value or v._value) or v
            local curAmt = tonumber(val) or 0
            local oldAmt = startSnap.materials[tostring(k)] or 0
            if curAmt > oldAmt then
                table.insert(drops, {
                    id = tostring(k),
                    amount = curAmt - oldAmt
                })
            end
        end
    end
    if not startSnap.hasHuTao and hasFlameDirector and hasFlameDirector() then
        table.insert(drops, {
            id = "🔥 Flame Director (Hu Tao)",
            amount = 1,
            isCharacter = true
        })
    end
    return drops
end

function Webhook.getPityInfo()
    local s = getAccState()
    local curr = (s and s.currencies and (type(s.currencies) == "table" and (s.currencies.entries or s.currencies.current or s.currencies))) or {}
    local function readVal(v)
        if type(v) == "table" and v.current ~= nil then return v.current end
        return v
    end

    local zenlessPity = tonumber(readVal(curr.zenlessPity)) or (getCurrency and tonumber(getCurrency("zenlessPity"))) or 0
    local arcanePity = tonumber(readVal(curr.arcanePity)) or (getCurrency and tonumber(getCurrency("arcanePity"))) or 0
    local mythicPity = tonumber(readVal(curr.mythicPity)) or (getCurrency and tonumber(getCurrency("mythicPity"))) or 0
    local luckySpins = tonumber(readVal(curr.luckySpins)) or (getCurrency and tonumber(getCurrency("luckySpins"))) or 0
    local rolls = tonumber(readVal(curr.rolls)) or (getCurrency and tonumber(getCurrency("rolls"))) or 0

    local zenlessMax = 3500
    local arcaneMax = 350
    local mythicMax = 175

    local zenlessRem = math.max(0, zenlessMax - zenlessPity)
    local arcaneRem = math.max(0, arcaneMax - arcanePity)
    local mythicRem = math.max(0, mythicMax - mythicPity)

    local zenlessPct = math.min(100, math.floor((zenlessPity / zenlessMax) * 1000) / 10)
    local arcanePct = math.min(100, math.floor((arcanePity / arcaneMax) * 1000) / 10)
    local mythicPct = math.min(100, math.floor((mythicPity / mythicMax) * 1000) / 10)

    return {
        zenlessPity = zenlessPity,
        zenlessMax = zenlessMax,
        zenlessRem = zenlessRem,
        zenlessPct = zenlessPct,
        arcanePity = arcanePity,
        arcaneMax = arcaneMax,
        arcaneRem = arcaneRem,
        arcanePct = arcanePct,
        mythicPity = mythicPity,
        mythicMax = mythicMax,
        mythicRem = mythicRem,
        mythicPct = mythicPct,
        luckySpins = luckySpins,
        rolls = rolls
    }
end

function Webhook.getPlayerInfoField()
    local isEng = isEnglishEnabled and isEnglishEnabled()
    local pLvl = (getPlayerLevel and getPlayerLevel()) or 1
    local expInfo = (getPlayerExpProgress and getPlayerExpProgress()) or ""
    local lvlStr = (expInfo and expInfo ~= "") and string.format("Lv. %d (%s)", pLvl, expInfo) or ("Lv. " .. tostring(pLvl))
    
    local charDisplay = (getCharacterDisplayName and getCharacterDisplayName()) or (lp and lp.Name)
    local traitName = (getPlayerTraitName and getPlayerTraitName())
    local charStr = (traitName and traitName ~= "None" and traitName ~= "") and string.format("%s [%s]", charDisplay, traitName) or charDisplay
    
    local m = (getCurrency and getCurrency("money")) or 0
    local g = (getCurrency and getCurrency("gems")) or 0
    local curArea = (getCurrentArea and getCurrentArea()) or "---"
    local curTask = (State and State.CurrentTask) or (isEng and "Idle..." or "รอดำเนินการ...")

    if isEng then
        return {
            name = "👤 Player Profile",
            value = string.format(
                "• **Player:** ||%s||\n• **Level:** `%s`\n• **Main Character:** **%s**\n• **Coins:** 💰 `%s` Coins\n• **Gems:** 💎 `%s` Gems\n• **Current Location (Area):** 📍 `%s`\n• **Task Status:** `%s`",
                lp.Name,
                lvlStr,
                charStr,
                Webhook.formatCommas(m),
                Webhook.formatCommas(g),
                curArea,
                curTask
            ),
            inline = false
        }
    else
        return {
            name = "👤 ข้อมูลผู้เล่น (Player Profile)",
            value = string.format(
                "• **ชื่อผู้เล่น:** ||%s||\n• **เลเวล:** `%s`\n• **ตัวละครหลัก:** **%s**\n• **ยอดเงิน:** 💰 `%s` Coins\n• **เพชร:** 💎 `%s` Gems\n• **สถานที่ปัจจุบัน (Area):** 📍 `%s`\n• **สถานะการทำงาน:** `%s`",
                lp.Name,
                lvlStr,
                charStr,
                Webhook.formatCommas(m),
                Webhook.formatCommas(g),
                curArea,
                curTask
            ),
            inline = false
        }
    end
end

function Webhook.getPityField()
    local pity = Webhook.getPityInfo()
    local isEng = isEnglishEnabled and isEnglishEnabled()
    local hasLyth, lythName = false, nil
    if getSummonLythInfo then hasLyth, lythName = getSummonLythInfo() end
    if not hasLyth and getOwnedLythCharacter then lythName = getOwnedLythCharacter() end
    local isLythDone = (hasLyth or lythName) ~= nil

    local function makeProgressBar(current, maxVal, length)
        length = length or 10
        local pct = math.clamp(current / math.max(1, maxVal), 0, 1)
        local filled = math.floor(pct * length)
        local empty = length - filled
        return string.rep("▓", filled) .. string.rep("░", empty)
    end

    local lythText
    if isLythDone then
        if isEng then
            lythText = string.format("✅ **Status:** Already Owns LYTH Character (**%s**) (Guaranteed Complete!)", tostring(lythName or "LYTH"):upper())
        else
            lythText = string.format("✅ **สถานะ:** ครอบครองตัวละครระดับ LYTH แล้ว (**%s**) (การันตีสำเร็จ!)", tostring(lythName or "LYTH"):upper())
        end
    else
        local bar = makeProgressBar(pity.zenlessPity, pity.zenlessMax, 10)
        if isEng then
            lythText = string.format(
                "• **Progress:** `[%s]` `%s / %s` (%.1f%%)\n• **Required Summons:** 🎯 **`%s` more pulls until 100%% Guaranteed!** (LYTH Guaranteed)",
                bar,
                Webhook.formatCommas(pity.zenlessPity),
                Webhook.formatCommas(pity.zenlessMax),
                pity.zenlessPct,
                Webhook.formatCommas(pity.zenlessRem)
            )
        else
            lythText = string.format(
                "• **ความคืบหน้า:** `[%s]` `%s / %s` (%.1f%%)\n• **จำนวนที่ต้องสุ่ม:** 🎯 **อีก `%s` ครั้ง ถึงการันตี 100%%!** (LYTH Guaranteed)",
                bar,
                Webhook.formatCommas(pity.zenlessPity),
                Webhook.formatCommas(pity.zenlessMax),
                pity.zenlessPct,
                Webhook.formatCommas(pity.zenlessRem)
            )
        end
    end

    local arcaneBar = makeProgressBar(pity.arcanePity, pity.arcaneMax, 8)
    local mythicBar = makeProgressBar(pity.mythicPity, pity.mythicMax, 8)

    local valueStr
    if isEng then
        valueStr = string.format(
            "✨ **LYTH Main Banner (Zenless - Miyabi):**\n%s\n\n" ..
            "🔮 **Arcane Banner Pity:**\n• `[%s]` `%s / %s` (Need **`%s`** more pulls | %.1f%%)\n\n" ..
            "⭐ **Mythic Banner Pity:**\n• `[%s]` `%s / %s` (Need **`%s`** more pulls | %.1f%%)\n\n" ..
            "🎫 **Tickets & Spins:** 🎲 Lucky Spins: `%s` | 🎫 Rolls: `%s`",
            lythText,
            arcaneBar, Webhook.formatCommas(pity.arcanePity), Webhook.formatCommas(pity.arcaneMax), Webhook.formatCommas(pity.arcaneRem), pity.arcanePct,
            mythicBar, Webhook.formatCommas(pity.mythicPity), Webhook.formatCommas(pity.mythicMax), Webhook.formatCommas(pity.mythicRem), pity.mythicPct,
            Webhook.formatCommas(pity.luckySpins),
            Webhook.formatCommas(pity.rolls)
        )
    else
        valueStr = string.format(
            "✨ **ตู้สุ่มหลัก LYTH (Zenless - Miyabi):**\n%s\n\n" ..
            "🔮 **ตู้ Arcane Pity:**\n• `[%s]` `%s / %s` (ขาดอีก **`%s`** ครั้ง | %.1f%%)\n\n" ..
            "⭐ **ตู้ Mythic Pity:**\n• `[%s]` `%s / %s` (ขาดอีก **`%s`** ครั้ง | %.1f%%)\n\n" ..
            "🎫 **ตั๋วและสปิน:** 🎲 Lucky Spins: `%s` ครั้ง | 🎫 Rolls: `%s` ใบ",
            lythText,
            arcaneBar, Webhook.formatCommas(pity.arcanePity), Webhook.formatCommas(pity.arcaneMax), Webhook.formatCommas(pity.arcaneRem), pity.arcanePct,
            mythicBar, Webhook.formatCommas(pity.mythicPity), Webhook.formatCommas(pity.mythicMax), Webhook.formatCommas(pity.mythicRem), pity.mythicPct,
            Webhook.formatCommas(pity.luckySpins),
            Webhook.formatCommas(pity.rolls)
        )
    end

    return {
        name = isEng and "🎰 Summon & Pity Guarantee" or "🎰 ข้อมูลตู้สุ่ม & การันตีตัวละคร (Summon & Pity Guarantee)",
        value = valueStr,
        inline = false
    }
end

function Webhook.getKaitunChecklistState()
    local state = {}
    local isEng = isEnglishEnabled and isEnglishEnabled()

    -- 1. Delivery Quests (50/50)
    local pLvl = (getPlayerLevel and getPlayerLevel()) or 1
    local dCleared = (getAchievementProgress and getAchievementProgress("story.delivery.cleared")) or 0
    local dDone = (dCleared >= 50) or (pLvl >= 10) or (getgenv().AZ_Config and getgenv().AZ_Config.AutoDelivery50 == false)
    local dCount = dDone and 50 or math.min(dCleared, 50)
    local delivStatus = isEng and (dDone and "Completed" or "In Progress") or (dDone and "เสร็จสิ้น" or "กำลังทำ")
    state.delivery = {
        isDone = dDone,
        title = string.format("Delivery Quests (%d/50)", dCount),
        status = delivStatus,
        uiTitle = string.format("Delivery Quests (%d/50)", dCount),
        uiStatus = delivStatus
    }

    -- 2. Summon Lyth (Slot 2)
    local pity = Webhook.getPityInfo()
    local hasLyth, lythName = false, nil
    if getSummonLythInfo then hasLyth, lythName = getSummonLythInfo() end
    if not hasLyth and getOwnedLythCharacter then lythName = getOwnedLythCharacter() end
    local isLythDone = (hasLyth or lythName) ~= nil
    local lythDisp = tostring(lythName or "LYTH"):upper()

    if isLythDone then
        local sumStatus = isEng and "Owned" or "ครอบครองแล้ว"
        state.summon = {
            isDone = true,
            title = string.format("Summon Lyth (%s)", lythDisp),
            status = sumStatus,
            pityInfo = nil,
            uiTitle = string.format("Summon Lyth (%s)", lythDisp),
            uiStatus = sumStatus
        }
    else
        local sumStatus = isEng and string.format("%s until pity", Webhook.formatCommas(pity.zenlessRem)) or string.format("อีก %s การันตี", Webhook.formatCommas(pity.zenlessRem))
        local pityInfoStr = isEng and string.format("Pity: %s/%s | %s until pity (%.1f%%)",
                Webhook.formatCommas(pity.zenlessPity),
                Webhook.formatCommas(pity.zenlessMax),
                Webhook.formatCommas(pity.zenlessRem),
                pity.zenlessPct
            ) or string.format("Pity: %s/%s | อีก %s การันตี (%.1f%%)",
                Webhook.formatCommas(pity.zenlessPity),
                Webhook.formatCommas(pity.zenlessMax),
                Webhook.formatCommas(pity.zenlessRem),
                pity.zenlessPct
            )
        state.summon = {
            isDone = false,
            title = string.format("Summon Lyth (%s/%s)", Webhook.formatCommas(pity.zenlessPity), Webhook.formatCommas(pity.zenlessMax)),
            status = sumStatus,
            pityInfo = pityInfoStr,
            uiTitle = string.format("Summon Lyth (%s/%s)", Webhook.formatCommas(pity.zenlessPity), Webhook.formatCommas(pity.zenlessMax)),
            uiStatus = sumStatus
        }
    end

    -- 3. Awakening (LYTH)
    local checkLyth = lythName or (getOwnedLythCharacter and getOwnedLythCharacter())
    local isAwk = checkLyth and isCharacterAwakened and isCharacterAwakened(checkLyth)
    local awkStatus
    if checkLyth then
        if isEng then
            awkStatus = isAwk and "Awakened" or "Gathering Materials"
        else
            awkStatus = isAwk and "Awakened แล้ว" or "รอของครบ"
        end
    else
        awkStatus = isEng and "Awaiting Unit" or "รอสุ่มได้ตัว"
    end
    state.awakening = {
        isDone = (isAwk == true),
        title = string.format("Awakening (%s)", tostring(checkLyth or "LYTH"):upper()),
        status = awkStatus,
        uiTitle = string.format("Awakening (%s)", tostring(checkLyth or "LYTH"):upper()),
        uiStatus = awkStatus
    }

    -- 4. Craft Blast Archer Wings [#14]
    local hasWings = isAccessoryOwnedOrCrafted and isAccessoryOwnedOrCrafted(14, accCraftCfg and (accCraftCfg["14"] or accCraftCfg[14]))
    local wingsStatus = isEng and (hasWings and "Crafted" or "Not Crafted") or (hasWings and "คราฟต์แล้ว" or "ยังไม่คราฟต์")
    state.wings = {
        isDone = (hasWings == true),
        title = "Craft Blast Archer Wings [#14]",
        status = wingsStatus,
        uiTitle = "Craft Blast Archer Wings [#14]",
        uiStatus = wingsStatus
    }

    -- 5. Craft Blast Archer Crown [#13]
    local hasCrown = isAccessoryOwnedOrCrafted and isAccessoryOwnedOrCrafted(13, accCraftCfg and (accCraftCfg["13"] or accCraftCfg[13]))
    local crownStatus = isEng and (hasCrown and "Crafted" or "Not Crafted") or (hasCrown and "คราฟต์แล้ว" or "ยังไม่คราฟต์")
    state.crown = {
        isDone = (hasCrown == true),
        title = "Craft Blast Archer Crown [#13]",
        status = crownStatus,
        uiTitle = "Craft Blast Archer Crown [#13]",
        uiStatus = crownStatus
    }

    -- 6. Raid Flame Director (Hu Tao)
    local hasHuTao = hasFlameDirector and hasFlameDirector()
    local raidStatus = isEng and (hasHuTao and "Obtained" or "Farming Raid") or (hasHuTao and "ดรอปแล้ว" or "กำลังล่า Raid")
    state.raid = {
        isDone = (hasHuTao == true),
        title = "Raid Flame Director (Hu Tao)",
        status = raidStatus,
        uiTitle = "Raid Flame Director (Hu Tao)",
        uiStatus = raidStatus
    }

    -- 7. Awakening Flame Director
    local huTaoAwk = hasHuTao and isCharacterAwakened and isCharacterAwakened("hutao")
    local huTaoAwkStatus
    if hasHuTao then
        if isEng then
            huTaoAwkStatus = huTaoAwk and "Awakened" or "Gathering Materials"
        else
            huTaoAwkStatus = huTaoAwk and "Awakened แล้ว" or "รอของครบ"
        end
    else
        huTaoAwkStatus = isEng and "Incomplete" or "ยังไม่เสร็จ"
    end
    state.awakeFlame = {
        isDone = (huTaoAwk == true),
        title = "Awakening Flame Director",
        status = huTaoAwkStatus,
        uiTitle = "Awakening Flame Director",
        uiStatus = huTaoAwkStatus
    }

    -- 8. Farm Material 100 All Kinds (X/14)
    local matsDone = 0
    if getMaterialCount then
        for m = 101, 114 do
            if getMaterialCount(m) >= 100 then
                matsDone = matsDone + 1
            end
        end
    end
    local isMatsDone = (matsDone >= 14)
    local matStatus = isEng and (isMatsDone and "Completed" or "Farming") or (isMatsDone and "เสร็จสิ้น" or "กำลังฟาร์ม")
    state.materials = {
        isDone = isMatsDone,
        title = string.format("Farm Material 100 All Kinds (%d/14)", matsDone),
        status = matStatus,
        uiTitle = string.format("Farm Material 100 All Kinds (%d/14)", matsDone),
        uiStatus = matStatus
    }

    -- Fallback & Merge from persistent cache in Match or when data incomplete
    if _G.AZ_Cache and _G.AZ_Cache.checklist then
        for k, v in pairs(_G.AZ_Cache.checklist) do
            if state[k] == nil then
                state[k] = v
            end
        end
    end

    if _G.AZ_Cache then
        _G.AZ_Cache.checklist = state
        if saveCachedData and (tick() - _lastSaveTick > 1) then
            saveCachedData()
        end
    end

    return state
end

function Webhook.getKaitunChecklist()
    local state = Webhook.getKaitunChecklistState()
    local order = { "delivery", "summon", "awakening", "wings", "crown", "raid", "awakeFlame", "materials" }
    local items = {}

    for _, k in ipairs(order) do
        local item = state[k]
        if item then
            local icon = item.isDone and "✅" or "❌"
            local title = item.uiTitle or item.title
            local status = item.uiStatus or item.status
            local line = string.format("%s %s `[%s]`", icon, title, status)
            table.insert(items, line)
        end
    end

    return table.concat(items, "\n")
end

function Webhook.sendRaw(url, payload)
    if not url or url == "" or type(url) ~= "string" or not url:find("discord") then return false end
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if not req then return false end
    local HttpService = game:GetService("HttpService")
    local bodyJson = HttpService:JSONEncode(payload)
    local ok = pcall(function()
        req({
            Url = url,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = bodyJson
        })
    end)
    return ok
end

function Webhook.send(data)
    local cfg = getgenv().AZ_Config
    if not cfg or cfg.WebhookNotify == false then return end
    local url = cfg.WebhookURL
    if not url or url == "" or type(url) ~= "string" or not url:find("discord") then return end

    local embed = {
        title = data.title or "⚡ AXEL HUB NOTIFICATION",
        description = data.description or "",
        color = data.color or 10181046,
        fields = data.fields or {},
        footer = {
            text = "⚡ AXEL HUB · Autonomous Pro Kaitun | cook45 x clack",
            icon_url = "https://images-ext-1.discordapp.net/external/v3w9pL7Z0gW4f_4cQ6/https/media.discordapp.net/attachments/114574503491412/icon.png"
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    local payload = {
        username = "⚡ Axel Hub Notifications",
        avatar_url = "https://images-ext-1.discordapp.net/external/v3w9pL7Z0gW4f_4cQ6/https/media.discordapp.net/attachments/114574503491412/icon.png",
        embeds = { embed }
    }

    Webhook.sendRaw(url, payload)
end

function Webhook.notifyAwakening(charName)
    task.spawn(function()
        local isEng = isEnglishEnabled and isEnglishEnabled()
        Webhook.send({
            title = isEng and "🔥 AXEL HUB · AWAKENING COMPLETE" or "🔥 AXEL HUB · ปลุกพลังสำเร็จ (AWAKENING COMPLETE)",
            color = 10181046, -- Purple
            description = isEng and string.format("Character **%s** has been successfully Awakened!", charName:upper()) or string.format("ตัวละคร **%s** ทำการ Awakening (ปลุกพลัง) สำเร็จเรียบร้อยแล้ว!", charName:upper()),
            fields = {
                Webhook.getPlayerInfoField(),
                Webhook.getPityField(),
                {
                    name = isEng and "📋 Kaitun Checklist Progress" or "📋 ความคืบหน้าไอดีไก่ตัน (Kaitun Checklist)",
                    value = Webhook.getKaitunChecklist(),
                    inline = false
                }
            }
        })
    end)
end

function Webhook.notifyHuTao()
    if Webhook._notifiedHuTao then return end
    Webhook._notifiedHuTao = true
    task.spawn(function()
        local isEng = isEnglishEnabled and isEnglishEnabled()
        Webhook.send({
            title = isEng and "🎉 AXEL HUB · EXCLUSIVE CHARACTER DROP" or "🎉 AXEL HUB · ดรอปตัวละครแรร์ (EXCLUSIVE CHARACTER DROP)",
            color = 15158332, -- Crimson
            description = isEng and "Obtained **FLAME DIRECTOR (HU TAO)** from Bathtub Raid [NIGHTMARE] successfully!" or "ได้รับ **FLAME DIRECTOR (HU TAO)** จาก Bathtub Raid [NIGHTMARE] เรียบร้อยแล้ว!",
            fields = {
                Webhook.getPlayerInfoField(),
                Webhook.getPityField(),
                {
                    name = isEng and "📋 Kaitun Checklist Progress" or "📋 ความคืบหน้าไอดีไก่ตัน (Kaitun Checklist)",
                    value = Webhook.getKaitunChecklist(),
                    inline = false
                }
            }
        })
    end)
end

function Webhook.notifyLyth(charName)
    if Webhook._notifiedLyth then return end
    Webhook._notifiedLyth = true
    task.spawn(function()
        local isEng = isEnglishEnabled and isEnglishEnabled()
        Webhook.send({
            title = isEng and "✨ AXEL HUB · SUMMON LYTH OBTAINED" or "✨ AXEL HUB · สุ่มได้ตัวละครระดับเทพ (SUMMON LYTH OBTAINED)",
            color = 16766720, -- Gold
            description = isEng and string.format("Successfully summoned LYTH character **[%s]** in Slot 2!", tostring(charName):upper()) or string.format("สุ่มได้ตัวละครระดับ LYTH **[%s]** ใน Slot 2 เรียบร้อยแล้ว!", tostring(charName):upper()),
            fields = {
                Webhook.getPlayerInfoField(),
                Webhook.getPityField(),
                {
                    name = isEng and "📋 Kaitun Checklist Progress" or "📋 ความคืบหน้าไอดีไก่ตัน (Kaitun Checklist)",
                    value = Webhook.getKaitunChecklist(),
                    inline = false
                }
            }
        })
    end)
end

function Webhook.notifyAccessory(accName, accId)
    task.spawn(function()
        local isEng = isEnglishEnabled and isEnglishEnabled()
        Webhook.send({
            title = isEng and "⚒️ AXEL HUB · ACCESSORY CRAFTED" or "⚒️ AXEL HUB · คราฟต์เครื่องประดับสำเร็จ (ACCESSORY CRAFTED)",
            color = 3447003, -- Cyan/Blue
            description = isEng and string.format("Top-tier accessory **%s** [Recipe #%s] crafted successfully!", accName, tostring(accId)) or string.format("คราฟต์ไอเทมระดับท็อป **%s** [สูตร #%s] สำเร็จเรียบร้อยแล้ว!", accName, tostring(accId)),
            fields = {
                Webhook.getPlayerInfoField(),
                Webhook.getPityField(),
                {
                    name = isEng and "📋 Kaitun Checklist Progress" or "📋 ความคืบหน้าไอดีไก่ตัน (Kaitun Checklist)",
                    value = Webhook.getKaitunChecklist(),
                    inline = false
                }
            }
        })
    end)
end

function Webhook.notifyGodTrait(charName, traitName)
    task.spawn(function()
        local isEng = isEnglishEnabled and isEnglishEnabled()
        Webhook.send({
            title = isEng and "🌟 AXEL HUB · GOD TRAIT REROLLED" or "🌟 AXEL HUB · สุ่มได้ TRAIT เทพ (GOD TRAIT REROLLED)",
            color = 15844367, -- Gold
            description = isEng and string.format("Character **%s** successfully rolled God Trait **[%s]**!", charName:upper(), traitName) or string.format("ตัวละคร **%s** สุ่มได้ Trait เทพ **[%s]** สำเร็จเรียบร้อย!", charName:upper(), traitName),
            fields = {
                Webhook.getPlayerInfoField(),
                Webhook.getPityField(),
                {
                    name = isEng and "📋 Kaitun Checklist Progress" or "📋 ความคืบหน้าไอดีไก่ตัน (Kaitun Checklist)",
                    value = Webhook.getKaitunChecklist(),
                    inline = false
                }
            }
        })
    end)
end

-- ==================================================
-- DELIVERY QUEST STATE & AUTONOMOUS WARP RUNNER (50/50)
-- วาร์ปส่งเควสต์ แล้ว TP กลับมารับเควสต์ที่ Heiyun วนจนครบ 50/50
-- ==================================================
local currentDeliveryCount = 0
local currentDeliveryLimit = 50
local isDeliveryCapped = false
local currentDeliveryStatus = "none"
local currentDeliveryTarget = ""
local currentDeliveryLabel = ""
local heiyunPos = Vector3.new(-304.28, 3.5, 151.04)

local _deliveryHooked = false
local function ensureDeliveryHook()
    if _deliveryHooked then return end
    lobbyPkts = getLobbyPackets()
    if lobbyPkts and lobbyPkts.deliveryState then
        pcall(function()
            local function onState(d)
                if d then
                    if d.dailyCount ~= nil then currentDeliveryCount = tonumber(d.dailyCount) or currentDeliveryCount end
                    if d.dailyLimit ~= nil then currentDeliveryLimit = tonumber(d.dailyLimit) or currentDeliveryLimit end
                    if d.status ~= nil then currentDeliveryStatus = tostring(d.status) end
                    if d.target ~= nil then currentDeliveryTarget = tostring(d.target) end
                    if d.targetLabel ~= nil then currentDeliveryLabel = tostring(d.targetLabel) end
                    if d.status == "capped" or (currentDeliveryCount >= currentDeliveryLimit and currentDeliveryLimit > 0) then
                        isDeliveryCapped = true
                    end
                end
            end
            if lobbyPkts.deliveryState.on then
                lobbyPkts.deliveryState:on(onState)
                _deliveryHooked = true
            elseif lobbyPkts.deliveryState.OnClientEvent then
                lobbyPkts.deliveryState.OnClientEvent:Connect(onState)
                _deliveryHooked = true
            end
            if lobbyPkts.deliveryAction then
                lobbyPkts.deliveryAction:fire({ action = "refresh", requestId = nextId() })
            end
        end)
    end
end

pcall(ensureDeliveryHook)

local function autoCompleteDeliveryQuests50()
    if isMatch then return end
    lobbyPkts = getLobbyPackets()
    if not lobbyPkts or not lobbyPkts.deliveryAction or not lobbyPkts.deliveryState then return end
    if not (getgenv().AZ_Config and getgenv().AZ_Config.AutoDelivery50 == true) then return end
    
    ensureDeliveryHook()

    -- ถ้าเลเวล >= 10 หรือทำเควสต์ครบ 50 เควสต์แล้ว ถือว่าปลดล็อค Story โหมดเสร็จสมบูรณ์ ข้ามทันที!
    local pLvl = (getPlayerLevel and getPlayerLevel()) or 1
    local dCleared = (getAchievementProgress and getAchievementProgress("story.delivery.cleared")) or 0
    if pLvl >= 10 or dCleared >= 50 or isDeliveryCapped or (currentDeliveryCount >= currentDeliveryLimit and currentDeliveryLimit > 0) then
        isDeliveryCapped = true
        return
    end

    local function getTargetPosition(targetName)
        if not targetName or targetName == "" then return nil end
        local num = targetName:match("%d+")
        if num and workspace:FindFirstChild("Systems") and workspace.Systems:FindFirstChild("DeliverySpawns") then
            local sp = workspace.Systems.DeliverySpawns:FindFirstChild("Spawn" .. num)
            if sp and sp:IsA("BasePart") then
                return sp.Position
            end
        end
        local npcs = workspace:FindFirstChild("Systems") and workspace.Systems:FindFirstChild("NPCS")
        local npc = npcs and npcs:FindFirstChild(targetName)
        if npc then
            local root = npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart")
            if root then return root.Position end
        end
        local sNpcs = workspace:FindFirstChild("Systems") and workspace.Systems:FindFirstChild("ScatteredNPCS")
        local sNpc = sNpcs and sNpcs:FindFirstChild(targetName)
        if sNpc then
            local root = sNpc:FindFirstChild("HumanoidRootPart") or sNpc.PrimaryPart or sNpc:FindFirstChildWhichIsA("BasePart")
            if root then return root.Position end
        end
        local cLocal = workspace:FindFirstChild("CrowdLocal")
        local clNpc = cLocal and cLocal:FindFirstChild(targetName)
        if clNpc then
            local root = clNpc:FindFirstChild("HumanoidRootPart") or clNpc.PrimaryPart or clNpc:FindFirstChildWhichIsA("BasePart")
            if root then return root.Position end
        end
        return nil
    end

    local safetyTimeout = tick() + 3 -- สูงสุด 3 วิ ป้องกันค้าง Lobby เด็ดขาด
    while tick() < safetyTimeout do
        if isMatch then break end
        char = lp.Character
        hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then break end

        if isDeliveryCapped or (currentDeliveryCount >= currentDeliveryLimit and currentDeliveryLimit > 0) then
            setTask(string.format("✅ ทำ Delivery Quest ครบ %d/%d เควสต์แล้ว!", currentDeliveryCount, currentDeliveryLimit))
            break
        end

        local status = currentDeliveryStatus
        local target = currentDeliveryTarget
        local tLabel = currentDeliveryLabel ~= "" and currentDeliveryLabel or target

        if status == "none" or status == "" then
            setTask(string.format("📦 [STEP 1] TP ไปรับเควสต์ที่ Heiyun (%d/%d)...", currentDeliveryCount, currentDeliveryLimit))
            hrp.CFrame = CFrame.new(heiyunPos)
            if hrp.AssemblyLinearVelocity then hrp.AssemblyLinearVelocity = Vector3.zero end
            task.wait(0.15)
            pcall(function()
                lobbyPkts.deliveryAction:fire({ action = "request", requestId = nextId() })
            end)
            local reqWait = tick()
            while tick() - reqWait < 1.0 do
                if currentDeliveryStatus == "carrying" then break end
                task.wait(0.08)
            end
        elseif status == "carrying" then
            local targetPos = getTargetPosition(target)
            if targetPos then
                setTask(string.format("📦 [STEP 1] วาร์ปส่งของ Delivery ให้ %s (%d/%d)...", tLabel, currentDeliveryCount, currentDeliveryLimit))
                hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 1.5, 0))
                if hrp.AssemblyLinearVelocity then
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end
                local arriveWait = tick()
                while tick() - arriveWait < 1.2 do
                    if currentDeliveryStatus == "delivered" then break end
                    hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 1.5, 0))
                    task.wait(0.08)
                end
            else
                task.wait(0.2)
            end
        elseif status == "delivered" then
            setTask(string.format("📦 [STEP 1] รับรางวัล Delivery (%d/%d)...", currentDeliveryCount, currentDeliveryLimit))
            local prevCount = currentDeliveryCount
            pcall(function()
                lobbyPkts.deliveryAction:fire({ action = "claim", requestId = nextId() })
            end)
            local claimWait = tick()
            while tick() - claimWait < 0.8 do
                if currentDeliveryStatus == "none" or currentDeliveryCount > prevCount then break end
                task.wait(0.08)
            end
            -- TP กลับไปหา Heiyun ทันทีเพื่อเตรียมรับเควสต์ถัดไป
            hrp.CFrame = CFrame.new(heiyunPos)
            if hrp.AssemblyLinearVelocity then hrp.AssemblyLinearVelocity = Vector3.zero end
            task.wait(0.1)
        else
            task.wait(0.2)
        end
    end
end

local upgradeActiveSkillsIfPointsAvailable = nil

-- ==================================================
-- ==================================================
-- CHARACTER RARITY & SLOT SUMMON CONTROLLER
-- ตรวจสอบและสุ่มตัวละคร:
--  - ช่อง 1 (Sub Summon): สุ่มด้วย Normal Spin ให้ถึง Mythical - Lyth
--  - ช่อง 2: ปลดล็อค -> สุ่มหาตัวระดับ LYTH (Zenless / Miyabi) เท่านั้น!
-- ==================================================

local function getSlotUnlockCost(slotNum)
    if economyCfg and economyCfg.characterSlotUnlockCosts and economyCfg.characterSlotUnlockCosts[slotNum] then
        return tonumber(economyCfg.characterSlotUnlockCosts[slotNum]) or 25000
    end
    if slotNum == 2 then return 25000 end
    if slotNum == 3 then return 100000 end
    if slotNum == 4 then return 1000000 end
    return 25000
end

local function getSlotCharacterInfo(slotNum)
    local s = getAccState()
    if not s or not s.UnlockedCharacters then return nil, "None", false end
    local slotKey = "Slot" .. tostring(slotNum)
    local slotData = s.UnlockedCharacters[slotKey]
    if not slotData then return nil, "None", false end
    local isUnlocked = slotData.Unlocked and (readVal(slotData.Unlocked) == true)
    local charName = slotData.Character and tostring(readVal(slotData.Character)) or ""
    local rarity = getCharacterRarity(charName)
    return charName, rarity, isUnlocked
end

local function getRollCurrencyAvailable()
    local s = getAccState()
    local c = s and s.currencies
    local rollsLeft = c and c.rolls and tonumber(readVal(c.rolls)) or 0
    local moneyLeft = c and c.money and tonumber(readVal(c.money)) or 0
    if rollsLeft <= 0 then
        rollsLeft = tonumber(getCurrency("rolls")) or 0
    end
    if moneyLeft <= 0 then
        moneyLeft = tonumber(getCurrency("money")) or 0
    end
    if rollsLeft > 0 then return "rolls", rollsLeft end
    if moneyLeft >= 500 then return "money", moneyLeft end
    return nil, 0
end

local function getTargetSubSummonName()
    local cfg = getgenv().AZ_Config
    if not cfg then return nil end
    if type(cfg.AutoSubSummon) == "string" and cfg.AutoSubSummon ~= "" and cfg.AutoSubSummon ~= "true" then
        return cfg.AutoSubSummon
    end
    if type(cfg.TargetSubSummon) == "string" and cfg.TargetSubSummon ~= "" and cfg.TargetSubSummon ~= "true" then
        return cfg.TargetSubSummon
    end
    return nil
end

local function isMatchingCharacterName(curChar, targetName)
    if not curChar or not targetName then return false end
    local c1 = tostring(curChar):lower():gsub("[%s_%-]", "")
    local c2 = tostring(targetName):lower():gsub("[%s_%-]", "")
    if c1 == c2 or c1:find(c2, 1, true) or c2:find(c1, 1, true) then
        return true
    end
    local dName = getCharacterDisplayName(curChar):lower():gsub("[%s_%-]", "")
    if dName == c2 or dName:find(c2, 1, true) or c2:find(dName, 1, true) then
        return true
    end
    if charsConstant then
        local cDef = (charsConstant.charactersByName and charsConstant.charactersByName[tostring(curChar):lower()])
            or charsConstant[curChar] or charsConstant[tostring(curChar):lower()]
        if cDef and cDef.displayName then
            local dn = tostring(cDef.displayName):lower():gsub("[%s_%-]", "")
            if dn == c2 or dn:find(c2, 1, true) or c2:find(dn, 1, true) then
                return true
            end
        end
    end
    return false
end

local function isSlotDataStable()
    local s = getAccState()
    if not s or not s.UnlockedCharacters then return false end
    local s1 = s.UnlockedCharacters.Slot1
    if not s1 then return false end
    local cVal = s1.Character and (type(s1.Character) == "table" and (s1.Character.current or s1.Character.value or s1.Character._value) or s1.Character)
    return (cVal ~= nil and tostring(cVal) ~= "")
end

local function waitForSlotDataStable(timeout)
    timeout = timeout or 3.5
    local startT = tick()
    while tick() - startT < timeout do
        if isSlotDataStable() then return true end
        task.wait(0.2)
    end
    return isSlotDataStable()
end

local function isSlot1Satisfied(slot1Char, slot1Rarity)
    local cfg = getgenv().AZ_Config
    if not cfg then return true end
    if cfg.AutoSubSummon == false then return true end

    -- ถ้า Slot 1 เป็น Lyth อยู่แล้ว: พอใจ 100% ทันที
    if isLythTier(slot1Rarity, slot1Char) then return true end

    -- ถ้าผู้เล่นมีตัวระดับ Lyth ในตัวอยู่แล้ว: ไม่ต้องค้างใน Slot 1 อีก ถือว่าผ่านทันที!
    if hasAnyLythCharacter() then return true end

    -- ถ้าตัวปัจจุบันคือระดับ Mythic, Arcane, Zenless (Mythic-Lyth)
    if isMythicOrHigher(slot1Rarity, slot1Char) then
        local targetSub = getTargetSubSummonName()
        -- ถ้าไม่ได้ระบุชื่อเฉพาะ (เช่น AutoSubSummon = true) ให้เก็บ Mythic-Lyth ทันที 100%!
        if not targetSub or targetSub == "" or targetSub == true then
            return true
        end
        -- ถ้าระบุชื่อเฉพาะ ให้เช็คว่าตรงชื่อหรือไม่
        if isMatchingCharacterName(slot1Char, targetSub) then
            return true
        end
    end

    local targetSub = getTargetSubSummonName()
    if targetSub and type(targetSub) == "string" and targetSub ~= "" then
        return isMatchingCharacterName(slot1Char, targetSub)
    end

    return isMythicOrHigher(slot1Rarity, slot1Char)
end

local _lastRolledResult = nil
local _characterRolledHooked = false
local _lastLobbyPktsRef = nil  -- ติดตาม lobbyPkts ว่าเปลี่ยนไหม เพื่อ reset hook ถ้าเปลี่ยน
local function ensureCharacterRolledHook()
    -- ถ้า lobbyPkts เปลี่ยน (เช่น rejoin) ต้อง re-hook ใหม่
    if _lastLobbyPktsRef ~= lobbyPkts then
        _characterRolledHooked = false
        _lastLobbyPktsRef = lobbyPkts
    end
    if _characterRolledHooked then return end
    if not lobbyPkts then return end
    -- ลอง hook หลายวิธี: .on / .OnClientEvent / .Event
    pcall(function()
        local rolled = lobbyPkts.characterRolled
        if not rolled then return end
        local function cb(data)
            if type(data) == "table" and data.success then
                _lastRolledResult = data
            end
        end
        if rolled.on then
            rolled:on(cb)
            _characterRolledHooked = true
        elseif rolled.OnClientEvent then
            rolled.OnClientEvent:Connect(cb)
            _characterRolledHooked = true
        elseif rolled.Event then
            rolled.Event:Connect(cb)
            _characterRolledHooked = true
        end
        -- ถ้า hook ไม่ได้เลย ให้ตั้ง hooked = true เพื่อไม่ให้ loop retry ซ้ำ (ใช้ slot polling แทน)
        _characterRolledHooked = true
    end)
end

local function autoSummonSlotsManager()
    lobbyPkts = getLobbyPackets()
    if isMatch or not lobbyPkts or not lobbyPkts.rollCharacter then return false end
    if getgenv().AZ_Config and getgenv().AZ_Config.AutoSummon == false then return false end

    ensureCharacterRolledHook()

    -- ป้องกันปัญหาเช็คเร็วเกินไปตอนเพิ่งเข้า Lobby: รอให้ข้อมูลตัวละครในสล็อตซิงค์เรียบร้อยก่อน
    if not waitForSlotDataStable(3.5) then
        setTask("⏳ กำลังรอโหลดข้อมูลตัวละครในสล็อตจากเซิร์ฟเวอร์...")
        return false
    end

    -- ตรวจสอบข้อมูลสล็อต
    local slot1Char, slot1Rarity, slot1Unlocked = getSlotCharacterInfo(1)
    local slot2Char, slot2Rarity, slot2Unlocked = getSlotCharacterInfo(2)

    -- สวมใส่ GameSlot 2 ทันทีถ้า Slot 2 ปลดล็อคแล้ว เพื่อรับ Synergy Tag Team +5% Damage
    -- [SAFE] ป้องกันสลับตัว Slot 2 ผิดตัว

    -- ★ ถ้า Slot 2 ได้ระดับ LYTH เรียบร้อยแล้ว สวมใส่ Lyth ลง GameSlot 1 และ Slot 1 ลง GameSlot 2
    if isLythTier(slot2Rarity, slot2Char) then
        pcall(autoLockLythSlots)
        pcall(function()
            lobbyPkts.equipCharacterSlot:fire({ slot = 2, gameSlot = 1, requestId = nextId() })
            lobbyPkts.equipCharacterSlot:fire({ slot = 1, gameSlot = 2, requestId = nextId() })
        end)
        return true
    end

    -- 1. ตรวจสอบ Slot 1 (Sub Summon): สุ่มหาตัวที่กำหนด (เช่น "Dragon Eclipse") หรือระดับ Mythical - Lyth
    local targetSub = getTargetSubSummonName()
    if isSlot1Satisfied(slot1Char, slot1Rarity) then
        local dName = getCharacterDisplayName(slot1Char)
        -- ตัวละคร Slot 1 พอใจแล้ว (เป็น Mythic ขึ้นไป หรือตัวที่ตั้งค่าไว้) เก็บไว้ฟาร์มเงินทันที
    else
        -- ยืนยันข้อมูลอีก 0.5 วินาที เพื่อให้แน่ใจว่าไม่ได้เช็คเร็วเกินไปจนสุ่มทับตัวเดิม
        task.wait(0.5)
        local recheckChar, recheckRarity = getSlotCharacterInfo(1)
        if isSlot1Satisfied(recheckChar, recheckRarity) then
            return true
        end

        while true do
            if isMatch then break end
            local s1Char, s1Rarity = getSlotCharacterInfo(1)
            if isSlot1Satisfied(s1Char, s1Rarity) then
                local dName = getCharacterDisplayName(s1Char)
                setTask(string.format("✨ Slot 1 ได้ตัวระดับ [%s] (%s) แล้ว — ล็อคเก็บไว้ฟาร์มเงินทันที!", tostring(s1Rarity):upper(), dName:upper()))
                task.wait(0.5)
                break
            end

            local curr, balance = getRollCurrencyAvailable()
            if not curr then
                local req = targetSub and string.format("เป้าหมาย %s", targetSub:upper()) or "Slot 1 (Mythic-Lyth)"
                setTask(string.format("💰 เหรียญสุ่มไม่พอสำหรับ %s 👉 สวมใส่ Slot 1 [Dragon Eclipse] ไปลงเนื้อเรื่อง 1 [NIGHTMARE] หาเงิน...", req))
                pcall(ensureSlot1Equipped)
                return false
            end

            local goalDesc = targetSub and string.format("หาตัว [%s]", targetSub:upper()) or "ให้ถึงระดับ Mythic-Lyth"
            setTask(string.format("🎰 สุ่ม Slot 1 %s (%s เหลือ %d)...", goalDesc, curr:upper(), balance))

            _lastRolledResult = nil
            local prevChar = s1Char

            pcall(function()
                lobbyPkts.rollCharacter:fire({
                    spinType = "Normal",
                    paymentCurrency = curr,
                    slot = 1,
                    requestId = nextId()
                })
            end)

            -- ★ ป้องกันการสุ่มทับ: รอผลลัพธ์จากเซิร์ฟเวอร์แบบ Realtime ป้องกันการสุ่มเบิ้ลเด็ดขาด ★
            local waitStart = tick()
            local rolledSuccess = false
            while tick() - waitStart < 2.5 do
                task.wait(0.1)

                -- ก. เช็คจาก Remote Event packet ของเซิร์ฟเวอร์
                if _lastRolledResult and _lastRolledResult.slot == 1 then
                    local rChar = _lastRolledResult.character
                    local rRarity = _lastRolledResult.rarity
                    if isSlot1Satisfied(rChar, rRarity) or isMythicOrHigher(rRarity, rChar) then
                        local dName = getCharacterDisplayName(rChar)
                        setTask(string.format("✨ [สุ่มได้] Slot 1 ได้ระดับ [%s] (%s) — หยุดสุ่มทันที!", tostring(rRarity):upper(), dName:upper()))
                        task.wait(1.2)
                        rolledSuccess = true
                        break
                    else
                        break
                    end
                end

                -- ข. เช็คจาก State ของสล็อต
                local checkChar, checkRarity = getSlotCharacterInfo(1)
                if checkChar and checkChar ~= "" and checkChar ~= prevChar then
                    if isSlot1Satisfied(checkChar, checkRarity) or isMythicOrHigher(checkRarity, checkChar) then
                        local dName = getCharacterDisplayName(checkChar)
                        setTask(string.format("✨ [สล็อตอัปเดต] Slot 1 ได้ [%s] (%s) — หยุดสุ่มทันที!", tostring(checkRarity):upper(), dName:upper()))
                        task.wait(1.0)
                        rolledSuccess = true
                        break
                    else
                        break
                    end
                end
            end

            if rolledSuccess then
                break
            end

            task.wait(0.35)
        end
    end

    -- 2. ปลดล็อคช่อง 2 ถ้ายังไม่ปลดล็อค (ราคา $25K จาก economyConfig)
    local freshSlot2Char, freshSlot2Rarity, freshSlot2Unlocked = getSlotCharacterInfo(2)
    if not freshSlot2Unlocked then
        local m = getCurrency("money")
        local slot2Cost = getSlotUnlockCost(2)
        if m >= slot2Cost and lobbyPkts and lobbyPkts.unlockCharacterSlot then
            setTask(string.format("🔓 ปลดล็อค Character Slot 2 (ใช้ $%d)...", slot2Cost))
            pcall(function()
                lobbyPkts.unlockCharacterSlot:fire({ slot = 2, requestId = nextId() })
            end)
            task.wait(0.5)
            local _, _, nowUnlocked = getSlotCharacterInfo(2)
            if not nowUnlocked then
                setTask(string.format("💰 เงินไม่พอหรือยังปลดล็อคไม่สำเร็จ (%d/%d) — เตรียมเข้าด่าน 1 [NIGHTMARE] หาเงิน...", m, slot2Cost))
                return false
            end
            freshSlot2Unlocked = true
            pcall(ensureSupportGameSlot2Equipped)
        else
            setTask(string.format("💰 เงินไม่พอปลดล็อค Slot 2 (%d/%d) — เตรียมเข้าด่าน 1 [NIGHTMARE] หาเงิน...", m, slot2Cost))
            return false
        end
    end

    if not freshSlot2Unlocked then
        return false
    end

    -- มั่นใจ 100% ว่า GameSlot 2 สวมใส่ Slot 2 ทันทีเพื่อรับ Synergy Tag Team +5% Damage
    -- [SAFE] ป้องกันสลับตัว Slot 2 ผิดตัว

    -- 3. สุ่มช่อง 2 จนกว่าจะได้ระดับ LYTH (Zenless / Miyabi / Cataclysm) เท่านั้น!
    while true do
        if isMatch then break end
        local cur2Char, cur2Rarity, cur2Unlocked = getSlotCharacterInfo(2)

        -- สวมใส่ Slot 2 ลง GameSlot 2 ให้ตลอดเวลา
    -- [SAFE] ป้องกันสลับตัว Slot 2 ผิดตัว

        -- ตรวจสอบ: หยุดสุ่มเฉพาะเมื่อ Slot 2 ได้ระดับ LYTH เท่านั้น!
        if isLythTier(cur2Rarity, cur2Char) then
            pcall(autoLockLythSlots)
            setTask(string.format("✨ ช่อง 2 ครอบครองตัวละครระดับ LYTH [%s] เรียบร้อยแล้ว (ล็อคแล้ว)! สวมใส่ทันที!", tostring(cur2Char):upper()))
            pcall(function()
                lobbyPkts.equipCharacterSlot:fire({ slot = 2, gameSlot = 1, requestId = nextId() })
                lobbyPkts.equipCharacterSlot:fire({ slot = 1, gameSlot = 2, requestId = nextId() })
            end)
            task.wait(0.4)
            if upgradeActiveSkillsIfPointsAvailable and cur2Char then
                pcall(function() upgradeActiveSkillsIfPointsAvailable(cur2Char) end)
            end
            return true
        end

        local curr, balance = getRollCurrencyAvailable()
        if not curr then
            setTask("💰 เหรียญสุ่มเพื่อหา Slot 2 หมดแล้ว 👉 สวมใส่ Slot 1 [Dragon Eclipse] ไปลงเนื้อเรื่อง 1 [NIGHTMARE] หาเงินต่อ...")
            pcall(ensureSlot1Equipped)
            return false
        end

        setTask(string.format("🎰 สุ่ม Slot 2 ใน Lobby หาตัวระดับ LYTH (%s เหลือ %d)...", curr:upper(), balance))
        _lastRolledResult = nil
        local prev2Char = cur2Char

        pcall(function()
            lobbyPkts.rollCharacter:fire({
                spinType = "Normal",
                paymentCurrency = curr,
                slot = 2,
                requestId = nextId()
            })
        end)

        local waitStart2 = tick()
        local rolled2Success = false
        while tick() - waitStart2 < 2.5 do
            task.wait(0.1)
            if _lastRolledResult and _lastRolledResult.slot == 2 then
                local rChar = _lastRolledResult.character
                local rRarity = _lastRolledResult.rarity
                if isLythTier(rRarity, rChar) then
                    setTask(string.format("✨ [สุ่มได้] Slot 2 ได้ระดับ LYTH [%s] — หยุดสุ่มทันที!", tostring(rChar):upper()))
                    pcall(function() Webhook.notifyLyth(rChar) end)
                    task.wait(1.2)
                    rolled2Success = true
                    break
                else
                    break
                end
            end
            local check2Char, check2Rarity = getSlotCharacterInfo(2)
            if check2Char and check2Char ~= "" and check2Char ~= prev2Char then
                if isLythTier(check2Rarity, check2Char) then
                    setTask(string.format("✨ [สล็อตอัปเดต] Slot 2 ได้ระดับ LYTH [%s] — หยุดสุ่มทันที!", tostring(check2Char):upper()))
                    pcall(function() Webhook.notifyLyth(check2Char) end)
                    task.wait(1.0)
                    rolled2Success = true
                    break
                else
                    break
                end
            end
        end

        if rolled2Success then
            pcall(function()
                lobbyPkts.equipCharacterSlot:fire({ slot = 2, gameSlot = 1, requestId = nextId() })
            end)
            task.wait(0.5)
            local final2Char = select(1, getSlotCharacterInfo(2))
            if upgradeActiveSkillsIfPointsAvailable and final2Char then
                pcall(function() upgradeActiveSkillsIfPointsAvailable(final2Char) end)
            end
            pcall(function() ensureSupportGameSlot2Equipped(2) end)
            return true
        end

        task.wait(0.35)
    end

    return true
end

local function isSummonProgressionComplete()
    -- 1. ถ้าครอบครองตัวละครระดับ LYTH แล้ว (ทั้งในสล็อตหรือในกระเป๋า) ถือว่า Summon Progression เสร็จสมบูรณ์ 100%!
    if hasAnyLythCharacter() then return true end

    -- 2. ถ้าผู้เล่นปิด AutoSummon ชัดเจน (false) เท่านั้นถึงจะยอมให้ข้าม
    if getgenv().AZ_Config and getgenv().AZ_Config.AutoSummon == false then return true end

    local slot1Char, slot1Rarity = getSlotCharacterInfo(1)
    local slot2Char, slot2Rarity, slot2Unlocked = getSlotCharacterInfo(2)

    -- 3. ตรวจสอบ Slot 1 ก่อนว่าได้ตัวพึงพอใจหรือยัง (Mythic-Lyth หรือ Dragon Eclipse)
    if not isSlot1Satisfied(slot1Char, slot1Rarity) then return false end

    -- 4. ถ้า Slot 1 ผ่านแล้ว: ต้องปลดล็อค Slot 2 และสุ่ม Slot 2 จนกว่าจะได้ระดับ LYTH!
    if not slot2Unlocked then return false end
    if not isLythTier(slot2Rarity, slot2Char) then return false end

    return false
end

-- ==================================================
-- MASTER STRATEGIC DISPATCHER (ไดนามิกตามลำดับความสำคัญในเกม)
-- 1. ปลดล็อค Delivery Quests 50/50 เควสต์ วาร์ปส่งก่อนอันดับแรก!
-- 2. สุ่ม Sub Summon (ช่อง 1) ให้ถึง Mythic-Lyth -> ปลดล็อคช่อง 2 -> สุ่มช่อง 2 จนได้ LYTH (Zenless / Miyabi) เท่านั้น!
--    ★ ต้องสุ่มช่อง 2 จนได้ LYTH ให้เสร็จก่อน 100% ถึงจะไปขั้นตอนอื่นได้! ★
--    - ถ้ามีเงิน/โรล: นั่งสุ่มใน Lobby รัวๆ จนได้ LYTH ห้ามเข้าด่านเด็ดขาด!
--    - ถ้าเงิน/โรลหมด: ฟาร์มด่าน 1 HxH Ch.1 [NIGHTMARE] หาเงิน แล้วจบด่านออกมาตรวจเงิน/สุ่มต่อใน Lobby ทุกรอบ
-- 3. เมื่อได้ตัวระดับ LYTH เรียบร้อยแล้ว -> ถึงจะเริ่มปลดล็อค Story โหมด และฟาร์มของ Awakening ตัวละครหลัก [NIGHTMARE]
--    - จบด่านออกมาเช็ค ถ้าของครบ evolve เลย ถ้าไม่ครบฟาร์ม Story ต่อจนกว่าจะครบ
-- 4. ฟาร์มของคราฟต์ Accessory สูงสุด 2 ชิ้นเท่านั้น (Blast Archer Wings & Crown ตามรูป 1) จาก Story Mode [NIGHTMARE]
-- 5. ฟาร์ม Raid Bathtub [NIGHTMARE] หาตัวละคร Exclusive (Lyth / Flame Director)
--    - เมื่อได้มา: สลับใส่ช่อง 1 (ถ้าช่อง 1 เป็น Lyth อยู่แล้ว ให้ใส่ช่อง 2 แทน) + Awakening ตัว Lyth
-- 6. ฟาร์ม Material ทุกชนิดให้ครบ 100 ชิ้น ตาม Drop Config (รูป 4) ใน Story Mode [NIGHTMARE]
-- 7. Endgame / Fallback: ฟาร์ม Raid Spirit's Bathtub [NIGHTMARE] เต็มระบบ
-- ==================================================
local function getStrategicStageInfo()
    local s = getAccState()
    local p = s and s.achievements and s.achievements.progress
    local entries = (type(p) == "table" and (p.entries or p)) or {}
    local function readProg(key)
        local v = entries[key]
        if type(v) == "table" then
            if v.get then return v:get() end
            if v.current ~= nil then return v.current end
            if v._value ~= nil then return v._value end
        end
        return tonumber(v) or 0
    end

    -- --------------------------------------------------
    -- 1. ปลดล็อค Story โหมด: ส่ง Delivery Quests ให้ครบ 50/50 เควสต์ก่อนอันดับแรก!
    -- (ทำงานเฉพาะไอดีใหม่เลเวลต่ำกว่า 10 เท่านั้น หากเลเวล 10+ ปลดล็อค Story แล้ว ข้ามไปขั้นตอนถัดไปทันที)
    -- --------------------------------------------------
    if getgenv().AZ_Config and getgenv().AZ_Config.AutoDelivery50 == true then
        local pLvl = (getPlayerLevel and getPlayerLevel()) or 1
        local dCleared = readProg("story.delivery.cleared")
        if pLvl < 10 and dCleared < 50 and not isDeliveryCapped and currentDeliveryCount < currentDeliveryLimit and currentDeliveryLimit > 0 then
            return "Delivery", "Lobby", 0, 4, string.format("📦 [STEP 1] วาร์ปส่ง Delivery Quests (%d/%d) ปลดล็อค Story โหมด...", currentDeliveryCount, currentDeliveryLimit)
        end
    end

    -- --------------------------------------------------
    -- 2. SUMMON & SLOT 2 LYTH PROGRESSION FLOW:
    --    ★ ถ้ามีตัวระดับ LYTH แล้ว ข้ามไปขั้นตอนถัดไปทันที 100% ไม่ต้องสุ่มหา Lyth อีก! ★
    -- --------------------------------------------------
    local isEng = isEnglishEnabled()
    local hasLyth, lythChar = hasAnyLythCharacter()
    local isAutoSummonEnabled = (getgenv().AZ_Config == nil or getgenv().AZ_Config.AutoSummon ~= false)

    if not hasLyth and isAutoSummonEnabled then
        if not isSlotDataStable() then
            return nil, nil, 0, 4, isEng and "⏳ Loading character slot data..." or "⏳ กำลังรอโหลดข้อมูลตัวละครในสล็อต..."
        end

        local slot1Char, slot1Rarity = getSlotCharacterInfo(1)
        local slot2Char, slot2Rarity, slot2Unlocked = getSlotCharacterInfo(2)

        -- 2.1 ช่อง 1 (Sub Summon): ต้องได้ตัวที่กำหนด (เช่น "Dragon Eclipse") หรืออย่างน้อย Mythical - Lyth
        if not isSlot1Satisfied(slot1Char, slot1Rarity) then
            local curr, balance = getRollCurrencyAvailable()
            local targetSub = getTargetSubSummonName()
            local goalDesc = targetSub and string.format(isEng and "find [%s]" or "หาตัว [%s]", targetSub:upper()) or (isEng and "reach Mythic-Lyth tier" or "ให้ถึงระดับ Mythic-Lyth")
            if curr then
                return "Summon", "Lobby", 0, 4, string.format(isEng and "🎰 [STEP 2] Rolling Slot 1 in Lobby %s (%s left: %s)..." or "🎰 [STEP 2] สุ่ม Slot 1 ใน Lobby %s (%s เหลือ %s)...", goalDesc, curr:upper(), Webhook.formatCommas(balance))
            else
                local req = targetSub and string.format(isEng and "roll %s" or "สุ่มหา %s", targetSub:upper()) or (isEng and "roll Slot 1" or "สุ่ม Slot 1")
                return "Story", "Hxh", 1, 4, string.format(isEng and "💰 [STEP 2] Out of rolls/coins — Farming Ch.1 [NIGHTMARE] to %s..." or "💰 [STEP 2] โรล/เงินหมด — ฟาร์มด่าน 1 [NIGHTMARE] หาเงิน%s...", req)
            end
        end

        -- 2.2 ช่อง 2: ต้องปลดล็อคช่อง 2 ก่อนอันดับแรก! (ราคา $25K)
        if not slot2Unlocked then
            local m = getCurrency("money")
            local slot2Cost = getSlotUnlockCost(2)
            if m < slot2Cost then
                return "Story", "Hxh", 1, 4, string.format(isEng and "💰 [STEP 2] Farming Ch.1 [NIGHTMARE] to unlock Slot 2 (%s/%s)..." or "💰 [STEP 2] ฟาร์มด่าน 1 [NIGHTMARE] หาเงินปลดล็อค Slot 2 (%s/%s)...", Webhook.formatCommas(m), Webhook.formatCommas(slot2Cost))
            else
                -- มีเงินพอแล้ว ให้ไปเรียก autoSummonSlotsManager ปลดล็อคใน Lobby ทันที
                return "Summon", "Lobby", 0, 4, string.format(isEng and "🔓 [STEP 2] Have $%s — Unlocking Slot 2 in Lobby..." or "🔓 [STEP 2] มีเงินครบ $%s แล้ว — ปลดล็อค Slot 2 ใน Lobby...", Webhook.formatCommas(slot2Cost))
            end
        end

        -- 2.3 ช่อง 2: เมื่อปลดล็อคแล้ว สุ่มจนกว่าจะได้ระดับ LYTH (Zenless / Miyabi) เท่านั้น!
        if not isLythTier(slot2Rarity, slot2Char) then
            local curr, balance = getRollCurrencyAvailable()
            if curr then
                return "Summon", "Lobby", 0, 4, string.format(isEng and "🎰 [STEP 2] Rolling Slot 2 in Lobby for LYTH tier only (%s left: %s)..." or "🎰 [STEP 2] สุ่ม Slot 2 ใน Lobby หาตัวระดับ LYTH เท่านั้น (%s เหลือ %s)...", curr:upper(), Webhook.formatCommas(balance))
            else
                return "Story", "Hxh", 1, 4, isEng and "💰 [STEP 2] Out of rolls/coins — Farming Ch.1 [NIGHTMARE] for Slot 2 rolls..." or "💰 [STEP 2] โรล/เงินหมด — ฟาร์มด่าน 1 [NIGHTMARE] หาเงินมาสุ่ม Slot 2 ต่อ..."
            end
        end
    end

    -- ★ ตรวจสอบความปลอดภัยสูงสุด: ถ้าผู้เล่นยังไม่มีตัวระดับ LYTH ห้ามข้ามไปทำ Step 3 (Awakening), Step 4 (Accessory) หรือ Step 5 (Raid) เด็ดขาด! ★
    if not hasLyth and isAutoSummonEnabled then
        local curr, balance = getRollCurrencyAvailable()
        if curr then
            return "Summon", "Lobby", 0, 4, string.format(isEng and "🎰 [STEP 2] Rolling Slot 2 in Lobby for LYTH tier only (%s left: %s)..." or "🎰 [STEP 2] สุ่ม Slot 2 ใน Lobby หาตัวระดับ LYTH เท่านั้น (%s เหลือ %s)...", curr:upper(), Webhook.formatCommas(balance))
        else
            return "Story", "Hxh", 1, 4, isEng and "💰 [STEP 2] Out of rolls/coins — Farming Ch.1 [NIGHTMARE] for Slot 2 rolls..." or "💰 [STEP 2] โรล/เงินหมด — ฟาร์มด่าน 1 [NIGHTMARE] หาเงินมาสุ่ม Slot 2 ต่อ..."
        end
    end

    -- ปลดล็อค Story ด่านแรกเปิดทาง Raid (กรณีไอดีใหม่เอี่ยม)
    local hxhCleared = readProg("story.hxh.cleared")
    if hxhCleared < 1 then
        return "Story", "Hxh", 1, 4, isEng and "📖 [STEP 2.5] Unlock Story Mode: HxH Ch.1 [NIGHTMARE]" or "📖 [STEP 2.5] ปลดล็อค Story โหมด: HxH Ch.1 [NIGHTMARE]"
    end

    -- --------------------------------------------------
    -- 3. AUTO FARM MATERIAL FOR AWAKENING ACTIVE / MAIN CHARACTER [NIGHTMARE]
    --    ★ สุ่มตัวละครเสร็จแล้ว (มีตัวระดับ LYTH แล้ว) ถึงจะเริ่มฟาร์มของ Awakening ตัวละครหลัก! ★
    --    ฟาร์มของ Awakening ให้ตัวละครระดับ LYTH จาก Story Mode (ขึ้นอยู่กับตัวละครที่ใช้)
    --    จบด่านออกมาเช็ค ถ้าของคราฟครบ evolve เลย ถ้าไม่ครบฟาร์ม Story ต่อจนกว่าจะครบ
    -- --------------------------------------------------
    local isAutoAwakeningEnabled = (getgenv().AZ_Config == nil or getgenv().AZ_Config.AutoAwakening ~= false)
    local isLythAwakened = false
    if hasLyth then
        local mainLyth = lythChar or getOwnedLythCharacter()
        isLythAwakened = (mainLyth ~= nil and isCharacterAwakened(mainLyth))
    end

    if isAutoAwakeningEnabled and hasLyth and not isLythAwakened then
        local activeChar = (lythChar or getOwnedLythCharacter()):lower()
        local missingMat = getMissingAwakeningMaterials(activeChar)
        if next(missingMat) == nil then
            -- ของครบแล้ว! สั่ง Evolve ใน Lobby ทันที ไม่ต้องรอเข้าด่าน!
            local ok = autoEvolveAwakening(activeChar)
            if not ok then
                return nil, nil, 0, 4, string.format(isEng and "⚡ Materials ready — Unlocking Awakening for %s in Lobby..." or "⚡ ของครบแล้ว — กำลังปลดล็อก Awakening ให้ %s ใน Lobby...", activeChar:upper())
            end
        else
            for mId, needAmt in pairs(missingMat) do
                local gm, map, ch, diff = getStageForMaterial(mId)
                return gm, map, ch, 4, string.format(isEng and "⚡ [STEP 3] Farm Mat #%s (need %d) to Awaken %s [NIGHTMARE]" or "⚡ [STEP 3] ฟาร์ม Mat #%s (ขาด %d ชิ้น) เพื่อ Awakening %s [NIGHTMARE]", mId, needAmt, activeChar:upper())
            end
        end
    end

    -- ★ กฎเหล็ก: ถ้าได้ตัวระดับ LYTH แล้วแต่ยังไม่ได้ Evolve / Awakening ห้ามข้ามไป Step 4 หรือ Step 5 เด็ดขาด! ★
    if hasLyth and not isLythAwakened and isAutoAwakeningEnabled then
        local activeChar = (lythChar or getOwnedLythCharacter()):lower()
        return nil, nil, 0, 4, string.format(isEng and "⚡ [STEP 3] Awakening %s in progress..." or "⚡ [STEP 3] กำลังเตรียมการ Awakening ให้ %s...", activeChar:upper())
    end

    -- --------------------------------------------------
    -- 4. AUTO FARM MATERIAL FOR TOP 2 MYTHIC ACCESSORIES ONLY (14 & 13) [NIGHTMARE]
    --    ★ ต้องได้ตัวระดับ LYTH และ Evolve ปลดล็อค Awakening สำเร็จเรียบร้อยแล้วเท่านั้น ถึงจะเริ่มคราฟต์ Accessory! ★
    --    ฟาร์มของคราฟต์ Accessory สูงสุด 2 ชิ้นเท่านั้น (Blast Archer Wings & Crown ตามรูป 1)
    --    หาจาก Story Mode ได้ทั้งหมด ไม่ต้องลง Endless Mode
    --    คราฟต์ทีละอย่างละ 1 อันเท่านั้น ไม่เอาของขยะ
    -- --------------------------------------------------
    if accCraftCfg and hasLyth and isLythAwakened then
        local topRecipeList = { 14, 13 }
        for _, rId in ipairs(topRecipeList) do
            local recipe = accCraftCfg[tostring(rId)] or accCraftCfg[rId]
            if recipe and not isAccessoryOwnedOrCrafted(rId, recipe) then
                local misc = recipe.Misc
                if misc and type(misc) == "string" then
                    for req in misc:gmatch("[^|]+") do
                        local mId, mAmt = req:match("^(%d+),(%d+)$")
                        if mId and mAmt then
                            local needCount = tonumber(mAmt) or 1
                            local curCount = getMaterialCount(mId)
                            if curCount < needCount then
                                local gm, map, ch, diff = getStageForMaterial(mId)
                                local accName = (ACC_MAPPING[rId] and ACC_MAPPING[rId].name) or string.format("Acc #%d", rId)
                                return gm, map, ch, 4, string.format(isEng and "🔨 [STEP 4] Farm Mat #%s (%d/%d) to craft %s [#%d] [NIGHTMARE]" or "🔨 [STEP 4] ฟาร์ม Mat #%s (%d/%d ชิ้น) คราฟต์ %s [#%d] [NIGHTMARE]", mId, curCount, needCount, accName, rId)
                            end
                        end
                    end
                end
            end
        end
    end

    -- --------------------------------------------------
    -- 5. AUTO RAID ล่าตัวละคร EXCLUSIVE (LYTH): FLAME DIRECTOR (HU TAO) [NIGHTMARE]
    --    - ฟาร์ม Raid Bathtub จนกว่าจะได้ Flame Director (Hu Tao) เข้าตัว 100%
    --    - เมื่อได้มา: นำใส่ช่องที่ไม่มีตัวระดับ Lyth อยู่ (ห้ามทับ Lyth ตรง Summon เด็ดขาด!)
    --    - สลับมาช่วยฟาร์มของและ Awakening ให้ Flame Director (Hu Tao) ต่อจนเสร็จ
    -- --------------------------------------------------
    if not hasFlameDirector() then
        return "Raid", "BathTub", 1, 4, "🔥 [STEP 5] ฟาร์ม Raid Bathtub [NIGHTMARE] ล่า Flame Director (Hu Tao)..."
    else
        -- ตรวจสอบและนำ Hu Tao เข้าช่องที่ไม่ทับ Summon Lyth
        pcall(placeHuTaoInNonSummonSlot)

        -- ถ้า Hu Tao ยังไม่ได้ Awakening: สวมใส่ Hu Tao เพื่อฟาร์มของ Awakening
        if not isCharacterAwakened("hutao") then
            autoEquipCharacterIfOwned("hutao")
            pcall(ensureSupportGameSlot2Equipped)
            local missingMat = getMissingAwakeningMaterials("hutao")
            if next(missingMat) == nil then
                -- ของครบแล้ว! สั่ง Evolve Hu Tao ทันที
                local ok = autoEvolveAwakening("hutao")
                if not ok then
                    return nil, nil, 0, 4, "⚡ ของครบแล้ว — กำลังปลดล็อก Awakening ให้ FLAME DIRECTOR (HUTAO) ใน Lobby..."
                end
            else
                for mId, needAmt in pairs(missingMat) do
                    local gm, map, ch, diff = getStageForMaterial(mId)
                    return gm, map, ch, 4, string.format("⚡ [STEP 5] ฟาร์ม Mat #%s (ขาด %d ชิ้น) เพื่อ Awakening FLAME DIRECTOR (HUTAO) [NIGHTMARE]", mId, needAmt)
                end
            end
        else
            -- Awakening Hu Tao เสร็จสมบูรณ์แล้ว! สลับกลับมาใช้ตัว Summon Lyth (เช่น Miyabi) ทันที
            local _, summonLyth = getSummonLythInfo()
            if summonLyth then
                autoEquipCharacterIfOwned(summonLyth)
            end
        end
    end

    -- --------------------------------------------------
    -- 6. AUTO FARM MATERIAL 100 ทุกชนิดยาวๆ (ตาม Drop Config รูป 4) ใน Story Mode [NIGHTMARE]
    -- --------------------------------------------------
    local allMatIds = {}
    if matDropCfg and matDropCfg.Tables then
        for _, mapTable in pairs(matDropCfg.Tables) do
            for _, dropList in ipairs(mapTable) do
                if type(dropList) == "table" then
                    for _, entry in ipairs(dropList) do
                        if entry.Item then
                            allMatIds[tostring(entry.Item)] = true
                        end
                    end
                end
            end
        end
    end
    if not next(allMatIds) then
        for m = 101, 114 do allMatIds[tostring(m)] = true end
    end

    local sortedMats = {}
    for m, _ in pairs(allMatIds) do table.insert(sortedMats, m) end
    table.sort(sortedMats, function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)

    for _, mStr in ipairs(sortedMats) do
        local curCount = getMaterialCount(mStr)
        if curCount < 100 then
            local gm, map, ch, diff = getStageForMaterial(mStr)
            return gm, map, ch, 4, string.format("📦 [STEP 6] ฟาร์ม Material #%s (%d/100 ชิ้น) ตามลำดับยาวๆ [NIGHTMARE]", mStr, curCount)
        end
    end

    -- --------------------------------------------------
    -- 7. DEFAULT / ENDGAME: สำเร็จครบทุกขั้นตอน - ฟาร์ม Raid Spirit's Bathtub [NIGHTMARE] เต็มระบบ!
    -- --------------------------------------------------
    return "Raid", "BathTub", 1, 4, "🏆 สำเร็จครบทุกขั้นตอน — ฟาร์ม Raid Spirit's Bathtub [NIGHTMARE] Endgame เต็มระบบ!"
end

local getHighestUnlockedStageInfo = getStrategicStageInfo

-- ══════════════════════════════════════════════════
-- 3. ANTI-CHEAT & ANTI-AFK ENGINE
-- ══════════════════════════════════════════════════
if lp and lp.Idled then
    table.insert(_G.AZ_Connections, lp.Idled:Connect(function()
        pcall(function()
            if isMobileDevice then
                -- เฉพาะ Mobile: CaptureController และจำลอง Touch Event
                if VirtualUser then
                    pcall(function() VirtualUser:CaptureController() end)
                    pcall(function() VirtualUser:ClickButton2(Vector2.new(0, 0)) end)
                end
                local vim = game:GetService("VirtualInputManager")
                if vim then
                    pcall(function()
                        vim:SendTouchEvent(1, 0, 10, 10)
                        task.wait(0.05)
                        vim:SendTouchEvent(1, 2, 10, 10)
                    end)
                end
            else
                -- เฉพาะ PC: จำลอง MouseButton2
                if VirtualUser then
                    VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                    task.wait(0.2)
                    VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                end
            end
        end)
    end))
end

local lastAntiAFK = 0
local lastSkillTreeCombatTick = 0
table.insert(_G.AZ_Connections, RunService.Heartbeat:Connect(function()
    if tick() - lastAntiAFK > 40 then
        lastAntiAFK = tick()
        if lobbyPkts and lobbyPkts.enterAfk then
            pcall(function() lobbyPkts.enterAfk:fire() end)
        end
        if RS:FindFirstChild("EnterAfk") then
            pcall(function() RS.EnterAfk:FireServer() end)
        end
    end
end))

-- ══════════════════════════════════════════════════
-- 4. AUTO CLAIM LEVEL MILESTONES & AUTO REROLL TARGET TRAIT
-- ══════════════════════════════════════════════════
local function autoClaimLevelMilestones()
    if not lobbyPkts or not lobbyPkts.claimLevelMilestone then return end
    local s = getAccState()
    if not s then return end

    local pLvl = tonumber(readVal(s.level)) or getPlayerLevel()
    local claimed = (type(s.claimedLevelMilestones) == "table" and (s.claimedLevelMilestones.entries or s.claimedLevelMilestones.current or s.claimedLevelMilestones)) or {}

    local msCfg = RS:FindFirstChild("assets") and RS.assets:FindFirstChild("config") and RS.assets.config:FindFirstChild("levelMilestoneConfig") and require(RS.assets.config.levelMilestoneConfig)
    local order = (msCfg and msCfg.order) or { 0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100 }

    for _, reqLvl in ipairs(order) do
        if pLvl >= reqLvl then
            local isClaimed = claimed[tostring(reqLvl)] ~= nil or claimed[reqLvl] ~= nil
            if not isClaimed then
                setTask(string.format("🎁 เคลม Level Milestone [Lv. %d]...", reqLvl))
                pcall(function()
                    lobbyPkts.claimLevelMilestone:fire({
                        level = reqLvl,
                        requestId = nextId()
                    })
                end)
                task.wait(0.12)
            end
        end
    end
end

-- ดึง Trait เทพที่มีโอกาสดรอป <= 0.045% (0.04% และ 0.01%) จาก traitConfig โดยตรงแบบไดนามิก
local function getDynamicGodTraits()
    local godTraits = {}
    local traitNames = {}
    pcall(function()
        if traitCfg then
            for id, t in pairs(traitCfg) do
                if type(t) == "table" and t.Weight and t.Weight <= 0.045 then
                    local numId = tonumber(id) or id
                    godTraits[numId] = true
                    traitNames[numId] = string.format("%s (%.2f%%)", t.Name or ("Trait " .. tostring(id)), (t.Weight or 0) * 100)
                end
            end
        end
    end)
    if not next(godTraits) then
        godTraits = { [13] = true, [17] = true, [14] = true, [18] = true }
        traitNames = { [13] = "Ferocity (0.04%)", [17] = "Sniper (0.04%)", [14] = "Supernova (0.01%)", [18] = "Deadeye (0.01%)" }
    end
    return godTraits, traitNames
end

local function getCharacterCurrentTrait(charName)
    local s = getAccState()
    if not s or not s.CharactersData then return 0 end
    local cData = s.CharactersData[charName:lower()]
    if not cData or not cData.TraitData or not cData.TraitData.Trait then return 0 end
    return tonumber(readVal(cData.TraitData.Trait)) or 0
end

local function hasTargetTrait(charName)
    local tr = getCharacterCurrentTrait(charName)
    local godTraits, traitNames = getDynamicGodTraits()
    return godTraits[tr] == true, tr, traitNames[tr]
end

-- สุ่ม Trait 0.04% หรือ 0.01% ให้ตัวละครเป้าหมายจนเสร็จก่อนเข้าด่าน (ไดนามิกตาม Config ของเกม)
local function autoRerollTargetTrait()
    -- ตรวจสอบ Config ของผู้ใช้: ถ้าปิดไว้ (false) ให้ข้ามระบบสุ่ม Trait ทันที เพื่อให้ลูกค้าสุ่มเองตามคำสั่ง
    if not (getgenv().AZ_Config and getgenv().AZ_Config.AutoRerollTrait) then
        return
    end
    if not lobbyPkts or not lobbyPkts.rollTrait then return end
    local s = getAccState()
    if not s then return end

    -- เงื่อนไข:
    -- 1. ถ้ามีตัวละครระดับ Lyth (ไม่ว่าจะได้จากการ Summon ในตู้ เช่น Miyabi หรือดรอปจาก Raid เช่น Flame Director / Hutao):
    --    ให้มุ่งเป้าสุ่ม Trait ให้ตัว Lyth นั้นทันทีก่อนเสมอ!
    -- 2. สลับสวมใส่ตัวละคร Lyth นั้นทันที
    -- 3. ถ้ายังไม่มีตัว Lyth ให้เก็บหิน Rerolls ไว้
    local targetChar = getOwnedLythCharacter()
    if not targetChar then return end

    -- สลับสวมใส่ตัวละคร Lyth อัตโนมัติ
    pcall(function() autoEquipCharacterIfOwned(targetChar) end)

    local isHit, curTraitId, curTraitName = hasTargetTrait(targetChar)
    if isHit then
        return true
    end

    local godTraits, traitNames = getDynamicGodTraits()

    -- ต้องสุ่ม Trait ให้เสร็จก่อนเข้าด่าน!
    while true do
        local curS = getAccState()
        local traitRerollsLeft = 0
        if curS and curS.currencies and curS.currencies.traitRerolls then
            traitRerollsLeft = tonumber(readVal(curS.currencies.traitRerolls)) or 0
        end

        if traitRerollsLeft <= 0 then
            setTask(string.format("⚠️ Trait Rerolls หมดแล้ว (%s) — เตรียมเข้าด่านต่อ...", targetChar:upper()))
            break
        end

        local curTr = getCharacterCurrentTrait(targetChar)
        if godTraits[curTr] == true then
            local tName = traitNames[curTr] or tostring(curTr)
            setTask(string.format("✨ ได้รับ Trait เทพ [%s] ให้ %s สำเร็จ!", tName, targetChar:upper()))
            pcall(function() Webhook.notifyGodTrait(targetChar, tName) end)
            task.wait(0.5)
            break
        end

        setTask(string.format("🎲 สุ่ม Trait 0.04%% / 0.01%% ให้ %s (เหลือ %d โรล)...", targetChar:upper(), traitRerollsLeft))
        pcall(function()
            lobbyPkts.rollTrait:fire({
                character = targetChar,
                requestId = nextId()
            })
        end)
        task.wait(0.25)
    end
end

-- ══════════════════════════════════════════════════
-- 5. MINIMAL STATUS DISPLAY (โชว์เฉพาะสถานะตามคำสั่ง)
-- ══════════════════════════════════════════════════
-- ฟังก์ชันแปลข้อความ Task เป็นภาษาอังกฤษแบบสมบูรณ์
local function translateTaskToEnglish(msg)
    if not msg or type(msg) ~= "string" or msg == "" then return msg end

    local directMap = {
        ["กำลังซิงค์ข้อมูลบัญชีและระบบ Lobby จากเซิร์ฟเวอร์..."] = "Syncing account & lobby data from server...",
        ["⏳ กำลังซิงค์ข้อมูลบัญชีและระบบ Lobby จากเซิร์ฟเวอร์..."] = "⏳ Syncing account & lobby data from server...",
        ["กำลังฟาร์มในด่านต่อสู้อัตโนมัติ..."] = "Auto-farming in combat stage...",
        ["⚔️ กำลังฟาร์มในด่านต่อสู้อัตโนมัติ..."] = "⚔️ Auto-farming in combat stage...",
        ["กำลังเริ่มระบบ Axel Hub..."] = "Initializing Axel Hub...",
        ["กำลังฟาร์มด่านจบ รอรับของรางวัล..."] = "Stage completed, collecting rewards...",
        ["เงินและโรลสำหรับสุ่ม Slot 2 หมดแล้ว — สลับกลับ Slot 1 แล้วเตรียมเข้าด่าน 1 [NIGHTMARE] หาเงิน..."] = "Slot 2 spins empty — Switched to Slot 1 for gold [NIGHTMARE]...",
        ["⚠️ เงินและโรลสำหรับสุ่ม Slot 2 หมดแล้ว — สลับกลับ Slot 1 แล้วเตรียมเข้าด่าน 1 [NIGHTMARE] หาเงิน..."] = "⚠️ Slot 2 spins empty — Switched to Slot 1 for gold [NIGHTMARE]...",
        ["เลือดฟื้นฟูถึง 80% แล้ว — วาร์ปกลับลงมาลุยตีทันที!"] = "HP restored to 80% — Returning to combat!",
        ["⚔️ เลือดฟื้นฟูถึง 80% แล้ว — วาร์ปกลับลงมาลุยตีทันที!"] = "⚔️ HP restored to 80% — Returning to combat!",
        ["รอด่านเริ่ม หรือกำลังเริ่มการต่อสู้..."] = "Waiting for stage start...",
        ["รอเข้าด่านต่อสู้อัตโนมัติ..."] = "Entering combat stage...",
        ["กำลังเก็บของรางวัลและไอเทมในด่าน..."] = "Collecting stage drops...",
        ["🚪 แมตช์จบแล้ว (ปุ่ม Leave ปรากฏ) — กด Leave ออกกลับ Lobby ทันที!"] = "🚪 Match ended — Leaving to Lobby...",
        ["🚪 จบด่านแล้ว — กด Leave กลับ Lobby ทันทีเพื่อตรวจของคราฟและเควสต์!"] = "🚪 Stage ended — Leaving to Lobby for crafting & quests...",
        ["🚪 เคลียร์ห้องเสร็จแล้ว — วาร์ปเข้าลิฟต์และกดเปิดลิฟต์ทันที!"] = "🚪 Room cleared — Warping to elevator & activating...",
        ["🎬 กำลังโหลดฉากลิฟต์ / เปลี่ยนไปยังเซกเมนต์ถัดไป..."] = "🎬 Elevator transitioning to next segment...",
        ["🔍 รอคลื่นมอนสเตอร์เกิดในด่าน..."] = "🔍 Waiting for mob spawn wave...",
        ["🔍 กำลังรอคลื่นมอนสเตอร์ในห้อง..."] = "🔍 Waiting for mob wave in room...",
        ["⏳ กำลังรอแมพโหลดสมบูรณ์..."] = "⏳ Waiting for map to load...",
        ["💰 เก็บเหรียญ Coin (Cash) ที่ตกอยู่ในด่าน..."] = "💰 Collecting dropped coins...",
        ["⚡ ตรวจพบ Area 5/5 (บอส) — วาร์ปเข้าห้องบอสเปิดการต่อสู้!"] = "⚡ Boss Area 5/5 detected — Warping into boss fight!",
        ["⏳ ทุบกำแพงสำเร็จ! ยืนตรงกลางโซนใหม่ รอมอนสเตอร์เกิด (2 วิ)..."] = "⏳ Rubble broken! Waiting for mobs in new zone...",
        ["🎁 เคลียร์โค้ดและรับของรางวัลเริ่มต้น..."] = "🎁 Redeeming starter codes & rewards...",
        ["⏳ กำลังรอโหลดข้อมูลตัวละครในสล็อตจากเซิร์ฟเวอร์..."] = "⏳ Waiting for character slot data...",
    }
    if directMap[msg] then return directMap[msg] end

    -- เดินไปจุดกลางห้อง / วาร์ปเข้าจุดกลางห้อง
    local aDist, dDist = msg:match("เดินไปจุดกลางห้อง Area (%d+) %(ห่าง (.-) m%)")
    if aDist and dDist then return string.format("🏛️ Moving to center Area %s (%s m)...", aDist, dDist) end

    local wDist = msg:match("วาร์ปเข้าสู่จุดกลางห้อง Area (%d+)")
    if wDist then return string.format("🏛️ Warping to center Area %s...", wDist) end

    -- จบเวฟ / เคลียร์เวฟ
    local cw, mw = msg:match("จบเวฟ (%d+)/(%d+)")
    if cw and mw then return string.format("⏳ Wave %s/%s clear — Waiting for next spawn...", cw, mw) end

    local clrW = msg:match("เคลียร์เวฟ (.-) —")
    if clrW then return string.format("⏳ Wave %s clear — Waiting for next spawn...", clrW) end

    -- ยืนตรงกลางห้อง / โซน
    local stArea = msg:match("ยืนตรงกลางห้อง Area (%d+)")
    if stArea then return string.format("⏳ Standing at center Area %s waiting for mobs...", stArea) end

    local stZone = msg:match("ยืนตรงกลางโซน (%d+)")
    if stZone then return string.format("⏳ Standing at center Zone %s waiting for mobs...", stZone) end

    local brd = msg:match("ข้ามผ่าน Border (%d+)")
    if brd then return string.format("🚶 Passing Border %s to next zone...", brd) end

    local s1Target = msg:match("สลับกลับมาใช้ตัวฟาร์มหลัก Slot 1 %((.-)%)%.%.%.")
    if s1Target then return string.format("🔄 Switching back to main carry Slot 1 (%s)...", s1Target) end

    local eqChar, eqSlot = msg:match("สวมใส่ตัวละคร (.-) จากสล็อต (%d+)%.%.%.")
    if eqChar and eqSlot then return string.format("🔄 Equipping character %s from Slot %s...", eqChar, eqSlot) end

    local supChar, supSlot = msg:match("สวมใส่ตัวรอง %[(.-)%] %(Slot (%d+)%) ใน GameSlot 2")
    if supChar and supSlot then return string.format("🛡️ Equipped support [%s] (Slot %s) in GameSlot 2 (Tag Team +5%% Damage)...", supChar, supSlot) end

    local supSlotOnly = msg:match("สวมใส่ตัวรอง Slot (%d+) ใน GameSlot 2")
    if supSlotOnly then return string.format("🛡️ Equipped support Slot %s in GameSlot 2 (Tag Team +5%% Damage)...", supSlotOnly) end

    local lChar, lSlot = msg:match("ล็อคตัวละครระดับ LYTH %[(.-)%] ใน Slot (%d+)")
    if lChar and lSlot then return string.format("🔒 Locked LYTH [%s] in Slot %s (Protected)...", lChar, lSlot) end

    local s2Lyth = msg:match("ช่อง 2 ครอบครองตัวละครระดับ LYTH %[(.-)%]")
    if s2Lyth then return string.format("✨ Slot 2 owns LYTH [%s] (Locked)! Equipped!", s2Lyth) end

    local s2GotLyth = msg:match("ได้รับตัวละครระดับ LYTH %[(.-)%] ในช่อง 2 สำเร็จ")
    if s2GotLyth then return string.format("✨ Obtained LYTH [%s] in Slot 2! Equipped!", s2GotLyth) end

    local rSlot, rCurr, rBal = msg:match("สุ่ม Slot (%d+) ใน Lobby หาตัวระดับ LYTH %((.-) เหลือ (%d+)%)")
    if rSlot and rCurr and rBal then return string.format("🎰 Rolling Slot %s in Lobby for LYTH (%s left: %s)...", rSlot, rCurr, rBal) end

    local curM, needM = msg:match("เงินไม่พอปลดล็อค Slot 2 %((%d+)/(%d+)%)")
    if curM and needM then return string.format("💰 Gold for Slot 2 (%s/%s) — Entering Stage 1 [NIGHTMARE]...", curM, needM) end

    local curM2, needM2 = msg:match("เงินไม่พอหรือยังปลดล็อคไม่สำเร็จ %((%d+)/(%d+)%)")
    if curM2 and needM2 then return string.format("💰 Gold for Slot 2 (%s/%s) — Entering Stage 1 [NIGHTMARE]...", curM2, needM2) end

    local uSlot, uCost = msg:match("ปลดล็อค Character Slot (%d+) %(ใช้ %$(%d+)%)")
    if uSlot and uCost then return string.format("🔓 Unlocking Character Slot %s ($%s)...", uSlot, uCost) end

    local ultTarg = msg:match("ปล่อยอัลติเมท %(Ultimate%) ใส่บอส: (.-)!") or msg:match("ปล่อยอัลติเมท %(Ultimate%) เล็งตรงเป้าหมาย: (.-)!")
    if ultTarg then return string.format("💥 Casting Ultimate targeting: %s!", ultTarg) end

    local skNum, skTarg, skHp = msg:match("ปล่อยสกิล %[(%d+)/3%] ล็อคเป้าใส่: (.-) %(HP: (.-)%)")
    if skNum and skTarg and skHp then return string.format("⚔️ Skill [%s/3] locked on: %s (HP: %s)", skNum, skTarg, skHp) end

    local hpPct = msg:match("เลือดวิกฤต (.-)%%")
    if hpPct then return string.format("🩹 Critical HP (%s%%) — Hovering at safe height to heal...", hpPct) end

    local hpDrop = msg:match("เลือด (.-)%% %(<80%%%) — แวะเก็บกล่องฮีลเลือด")
    if hpDrop then return string.format("🩹 HP %s%% (<80%%) — Collecting health drop...", hpDrop) end

    if msg:find("แวะเก็บกล่องฮีลเลือด") then return "🩹 HP <80% — Collecting health drop..." end

    local step1Cur, step1Lim = msg:match("รับรางวัล Delivery %((%d+)/(%d+)%)")
    if step1Cur and step1Lim then return string.format("📦 [STEP 1] Delivery reward (%s/%s)...", step1Cur, step1Lim) end

    local step3Mat, step3Need, step3Char = msg:match("%[STEP 3%] ฟาร์ม Mat #(.-) %(ขาด (%d+) ชิ้น%) เพื่อ Awakening (.-) %[NIGHTMARE%]")
    if step3Mat and step3Need and step3Char then return string.format("⚡ [STEP 3] Farming Mat #%s (Need %s) for %s Awakening [NIGHTMARE]", step3Mat, step3Need, step3Char) end

    local step4Mat, step4Cur, step4Need, step4Acc, step4Id = msg:match("%[STEP 4%] ฟาร์ม Mat #(.-) %((%d+)/(%d+) ชิ้น%) คราฟต์ (.-) %[(.-)%] %[NIGHTMARE%]")
    if step4Mat and step4Cur and step4Need and step4Acc and step4Id then return string.format("🔨 [STEP 4] Farming Mat #%s (%s/%s) crafting %s [%s] [NIGHTMARE]", step4Mat, step4Cur, step4Need, step4Acc, step4Id) end

    if msg:find("%[STEP 5%]") and msg:find("Raid Bathtub") then
        return "🔥 [STEP 5] Farming Raid Bathtub [NIGHTMARE] Hunting Flame Director (Hu Tao)..."
    end

    local step5Mat, step5Need = msg:match("%[STEP 5%] ฟาร์ม Mat #(.-) %(ขาด (%d+) ชิ้น%) เพื่อ Awakening FLAME DIRECTOR")
    if step5Mat and step5Need then return string.format("⚡ [STEP 5] Farming Mat #%s (Need %s) for FLAME DIRECTOR Awakening [NIGHTMARE]", step5Mat, step5Need) end

    local step6Mat, step6Cur = msg:match("%[STEP 6%] ฟาร์ม Material #(.-) %((%d+)/100 ชิ้น%)")
    if step6Mat and step6Cur then return string.format("📦 [STEP 6] Farming Material #%s (%s/100) Sequence [NIGHTMARE]", step6Mat, step6Cur) end

    local milestoneLvl = msg:match("เคลม Level Milestone %[Lv%. (%d+)%]")
    if milestoneLvl then return string.format("🎁 Claiming Level Milestone [Lv. %s]...", milestoneLvl) end

    local trRoll, trLeft = msg:match("สุ่ม Trait 0%.04%% / 0%.01%% ให้ (.-) %(เหลือ (%d+) โรล%)")
    if trRoll and trLeft then return string.format("🎲 Rolling Trait 0.04%%/0.01%% for %s (%s rolls left)...", trRoll, trLeft) end

    local trGot, trTarget = msg:match("ได้รับ Trait เทพ %[(.-)%] ให้ (.-) สำเร็จ")
    if trGot and trTarget then return string.format("✨ Obtained God Trait [%s] for %s!", trGot, trTarget) end

    local trEmpty = msg:match("Trait Rerolls หมดแล้ว %((.-)%)")
    if trEmpty then return string.format("⚠️ Trait Rerolls empty (%s) — Continuing stage...", trEmpty) end

    local skTree, skCur, skNext, skChar = msg:match("อัปเกรด Skill Tree: (.-) %[(%d+) %-> (%d+)%] %((.-)%)")
    if skTree and skCur and skNext and skChar then return string.format("🌿 Skill Tree: %s [%s -> %s] (%s)", skTree, skCur, skNext, skChar) end

    local crAcc, crRec = msg:match("คราฟต์ระดับสูงสุด: (.-) %[สูตร #(%d+)%]")
    if crAcc and crRec then return string.format("🔨 Crafting top tier: %s [Recipe #%s]...", crAcc, crRec) end

    local stageMode, stageMap, stageCh = msg:match("เข้าด่านสูงสุด: (.-) (.-) Ch%.(%d+) %[NIGHTMARE%]")
    if stageMode and stageMap and stageCh then return string.format("🚀 Entering stage: %s %s Ch.%s [NIGHTMARE]...", stageMode, stageMap, stageCh) end

    local farmMob, fMobLvl, fMobHp = msg:match("ฟาร์ม (.-) %[(.-)%] %(HP: (.-)%)")
    if farmMob and fMobLvl and fMobHp then return string.format("⚔️ Farming %s [%s] (HP: %s)", farmMob, fMobLvl, fMobHp) end

    local farmSimpleMob, fsHp = msg:match("ฟาร์ม (.-) %(HP: (.-)%)")
    if farmSimpleMob and fsHp then return string.format("⚔️ Farming %s (HP: %s)", farmSimpleMob, fsHp) end

    local orbBoss, oBossHp = msg:match("ลอย Orbit ตีบอส (.-) %(HP: (.-)%)")
    if orbBoss and oBossHp then return string.format("⚔️ Orbiting & attacking boss %s (HP: %s)", orbBoss, oBossHp) end

    local orbMob, oMobHp = msg:match("ลอย Orbit ตีมอนสเตอร์ (.-) %(HP: (.-)%)")
    if orbMob and oMobHp then return string.format("⚔️ Orbiting & attacking %s (HP: %s)", orbMob, oMobHp) end

    if msg:find("ทุบกำแพงสำเร็จ") then
        local secWait = msg:match("%((%d+) วิ%)")
        return secWait and string.format("⏳ Rubble broken! Waiting for mobs (%ss)...", secWait) or "⏳ Rubble broken! Waiting for mobs..."
    end

    if msg:find("กำลังเดินเข้าจุดเกิด หรือเตรียมตัวต่อสู้") then return "⚔️ Moving to spawn point / Preparing combat..." end

    local warpGate = msg:match("วาร์ปไปหาประตู (.-) เพื่อทลายสิ่งกีดขวาง")
    if warpGate then return string.format("🌀 Warping to %s to break obstacle...", warpGate) end

    return msg
end

-- ══════════════════════════════════════════════════
-- 5. AUTONOMOUS KAITUN MONITOR UI (AXEL HUB x STARHUB DESIGN)
-- ══════════════════════════════════════════════════
local function getSafeUiParent()
    local parent = nil
    pcall(function()
        if RunService:IsStudio() then
            parent = lp:WaitForChild("PlayerGui")
        elseif gethui then
            parent = gethui()
        else
            parent = game:GetService("CoreGui")
        end
    end)
    if not parent then
        parent = lp:FindFirstChild("PlayerGui") or game:GetService("CoreGui")
    end
    return parent
end

pcall(function()
    local oldCore = game:GetService("CoreGui"):FindFirstChild("AxelHubKaitunUI")
    if oldCore then oldCore:Destroy() end
    if lp and lp:FindFirstChild("PlayerGui") and lp.PlayerGui:FindFirstChild("AxelHubKaitunUI") then
        lp.PlayerGui.AxelHubKaitunUI:Destroy()
    end
    if gethui then
        local oldHui = gethui():FindFirstChild("AxelHubKaitunUI")
        if oldHui then oldHui:Destroy() end
    end
end)

-- ฟังก์ชัน Escape ป้องกัน RichText แท็กพัง (เช่น <80%, >, &)
local function sanitizeForRichText(str)
    if not str then return "" end
    str = tostring(str)
    str = str:gsub("&", "&amp;")
    str = str:gsub("<", "&lt;")
    str = str:gsub(">", "&gt;")
    return str
end

-- Reuse the existing axelhubkaitun table
axelhubkaitun.ScreenGui = nil
axelhubkaitun.MainFrame = nil
axelhubkaitun.LogoImage = nil
axelhubkaitun.PlayerInfoLabels = {}
axelhubkaitun.DropsList = nil
axelhubkaitun.ChecklistItems = {}
axelhubkaitun.Drops = {}
axelhubkaitun.StageLabel = nil
axelhubkaitun.CreditLabel = nil
axelhubkaitun.Values = {
    Stage = isMatch and "Combat Stage" or "Lobby",
    Action = isMatch and "⚔️ กำลังฟาร์มในด่านต่อสู้อัตโนมัติ..." or "กำลังเริ่มระบบ Axel Hub..."
}
_G._AZ_AxelUI = axelhubkaitun
if getgenv then getgenv()._AZ_AxelUI = axelhubkaitun end

local ScreenGui = Instance.new("ScreenGui")
do
ScreenGui.Name = "AxelHubKaitunUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = getSafeUiParent()
axelhubkaitun.ScreenGui = ScreenGui

local FullscreenBg = Instance.new("Frame")
FullscreenBg.Name = "FullscreenBg"
FullscreenBg.Size = UDim2.new(1, 0, 1, 0)
FullscreenBg.Position = UDim2.new(0, 0, 0, 0)
FullscreenBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
FullscreenBg.BackgroundTransparency = 0.5
FullscreenBg.BorderSizePixel = 0
FullscreenBg.ZIndex = 1
FullscreenBg.Parent = ScreenGui
axelhubkaitun.FullscreenBg = FullscreenBg

local CreditLabel = Instance.new("TextLabel")
CreditLabel.Name = "CreditLabel"
CreditLabel.Size = UDim2.new(0, 300, 0, 20)
CreditLabel.AnchorPoint = Vector2.new(0, 1)
CreditLabel.Position = UDim2.new(0, 16, 1, -16)
CreditLabel.BackgroundTransparency = 1
CreditLabel.Font = Enum.Font.GothamMedium
CreditLabel.Text = "made custom ui by starhub"
CreditLabel.TextColor3 = Color3.fromRGB(160, 160, 185)
CreditLabel.TextSize = 11.5
CreditLabel.TextStrokeTransparency = 0
CreditLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
CreditLabel.TextXAlignment = Enum.TextXAlignment.Left
CreditLabel.ZIndex = 3
CreditLabel.Parent = ScreenGui
axelhubkaitun.CreditLabel = CreditLabel

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.new(0.5, 0, 0.39, 0)
MainFrame.Size = UDim2.new(0, 580, 0, 460)
MainFrame.BackgroundTransparency = 1
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = false
MainFrame.ZIndex = 2
MainFrame.Parent = ScreenGui
axelhubkaitun.MainFrame = MainFrame

local MainLayout = Instance.new("UIListLayout")
MainLayout.SortOrder = Enum.SortOrder.LayoutOrder
MainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
MainLayout.VerticalAlignment = Enum.VerticalAlignment.Top
MainLayout.Padding = UDim.new(0, 8)
MainLayout.Parent = MainFrame

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 142)
Header.BackgroundTransparency = 1
Header.LayoutOrder = 1
Header.Parent = MainFrame

local Logo = Instance.new("ImageLabel")
Logo.Name = "Logo"
Logo.Size = UDim2.new(0, 115, 0, 115)
Logo.AnchorPoint = Vector2.new(0.5, 0)
Logo.Position = UDim2.new(0.5, 0, 0, 0)
Logo.BackgroundTransparency = 1
Logo.Image = "rbxassetid://86949082023913"
Logo.ScaleType = Enum.ScaleType.Fit
Logo.Parent = Header
axelhubkaitun.LogoImage = Logo

local HubTitle = Instance.new("TextLabel")
HubTitle.Name = "HubTitle"
HubTitle.Size = UDim2.new(1, 0, 0, 22)
HubTitle.Position = UDim2.new(0, 0, 1, -20)
HubTitle.BackgroundTransparency = 1
HubTitle.Font = Enum.Font.FredokaOne
HubTitle.Text = "AXEL HUB - KAITUN MONITOR"
HubTitle.TextColor3 = Color3.fromRGB(255, 225, 95)
HubTitle.TextSize = 18
HubTitle.TextStrokeTransparency = 0
HubTitle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
HubTitle.TextXAlignment = Enum.TextXAlignment.Center
HubTitle.Parent = Header

local ColumnsContainer = Instance.new("Frame")
ColumnsContainer.Name = "ColumnsContainer"
ColumnsContainer.Size = UDim2.new(1, 0, 0, 255)
ColumnsContainer.BackgroundTransparency = 1
ColumnsContainer.LayoutOrder = 2
ColumnsContainer.Parent = MainFrame

local function createTransparentColumn(name, width, anchorX, posX)
    local Col = Instance.new("Frame")
    Col.Name = "Col_" .. name
    Col.AnchorPoint = Vector2.new(anchorX, 0)
    Col.Position = UDim2.new(0.5, posX, 0, 0)
    Col.Size = UDim2.new(0, width, 1, 0)
    Col.BackgroundTransparency = 1
    Col.BorderSizePixel = 0
    Col.Parent = ColumnsContainer

    local ColLayout = Instance.new("UIListLayout")
    ColLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ColLayout.Padding = UDim.new(0, 5)
    ColLayout.Parent = Col

    return Col
end

local LeftCol = createTransparentColumn("Left", 270, 1, -10)
local RightCol = createTransparentColumn("Right", 280, 0, 10)

local function createSectionTitle(parent, icon, title, order)
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = "SectionTitle"
    TitleLabel.Size = UDim2.new(1, 0, 0, 22)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Font = Enum.Font.FredokaOne
    TitleLabel.RichText = true
    TitleLabel.Text = string.format('<font color="rgb(255,225,95)">%s</font> <font color="rgb(255,255,255)">%s</font>', icon, title)
    TitleLabel.TextSize = 13.5
    TitleLabel.TextStrokeTransparency = 0
    TitleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.LayoutOrder = order or 1
    TitleLabel.Parent = parent
    return TitleLabel
end

local isEngInit = isEnglishEnabled and isEnglishEnabled()
axelhubkaitun.ProfileSectionTitle = createSectionTitle(LeftCol, "👤", isEngInit and "Player Profile" or "ข้อมูลผู้เล่น (Player Profile)", 1)

local PlayerInfoContainer = Instance.new("Frame")
PlayerInfoContainer.Name = "PlayerInfoContainer"
PlayerInfoContainer.Size = UDim2.new(1, 0, 0, 115)
PlayerInfoContainer.BackgroundTransparency = 1
PlayerInfoContainer.LayoutOrder = 3
PlayerInfoContainer.Parent = LeftCol

local PILayout = Instance.new("UIListLayout")
PILayout.SortOrder = Enum.SortOrder.LayoutOrder
PILayout.Padding = UDim.new(0, 2)
PILayout.Parent = PlayerInfoContainer

local function toRgb(col)
    local r = math.clamp(math.floor(col.R * 255), 0, 255)
    local g = math.clamp(math.floor(col.G * 255), 0, 255)
    local b = math.clamp(math.floor(col.B * 255), 0, 255)
    return string.format("rgb(%d,%d,%d)", r, g, b)
end

local function addPlayerRow(key, labelTextTH, labelTextEN, defaultVal, color, order)
    local Row = Instance.new("TextLabel")
    Row.Name = "Info_" .. key
    Row.Size = UDim2.new(1, 0, 0, 21)
    Row.BackgroundTransparency = 1
    Row.Font = Enum.Font.GothamMedium
    Row.RichText = true
    Row.TextColor3 = Color3.fromRGB(235, 235, 250)
    Row.TextSize = 12.5
    Row.TextStrokeTransparency = 0
    Row.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    Row.TextXAlignment = Enum.TextXAlignment.Left
    Row.LayoutOrder = order or 1
    
    local isEng = isEnglishEnabled and isEnglishEnabled()
    local labelText = isEng and labelTextEN or labelTextTH
    local rgbStr = toRgb(color)
    Row.Text = string.format('• %s: <font color="%s">%s</font>', labelText, rgbStr, tostring(defaultVal))
    Row.Parent = PlayerInfoContainer

    axelhubkaitun.PlayerInfoLabels[key] = {
        Label = Row,
        Prefix = labelText,
        PrefixTH = labelTextTH,
        PrefixEN = labelTextEN,
        Color = color,
        RgbStr = rgbStr
    }
    return Row
end

addPlayerRow("Name", "ชื่อผู้เล่น", "Player", "...", Color3.fromRGB(240, 240, 245), 1)
addPlayerRow("Level", "เลเวล", "Level", "...", Color3.fromRGB(255, 220, 100), 2)
addPlayerRow("Character", "ตัวละครหลัก", "Character", "...", Color3.fromRGB(160, 215, 255), 3)
addPlayerRow("Money", "ยอดเงิน", "Coins", "...", Color3.fromRGB(120, 240, 150), 4)
addPlayerRow("Gems", "เพชร", "Gems", "...", Color3.fromRGB(255, 140, 180), 5)

axelhubkaitun.DropsSectionTitle = createSectionTitle(LeftCol, "📦", isEngInit and "Match Drops" or "ไอเทม / ของดรอป (Match Drops)", 4)

local DropsContainer = Instance.new("Frame")
DropsContainer.Name = "DropsContainer"
DropsContainer.Size = UDim2.new(1, 0, 0, 95)
DropsContainer.BackgroundTransparency = 1
DropsContainer.LayoutOrder = 6
DropsContainer.Parent = LeftCol
axelhubkaitun.DropsList = DropsContainer

local DropsLayout = Instance.new("UIListLayout")
DropsLayout.SortOrder = Enum.SortOrder.LayoutOrder
DropsLayout.Padding = UDim.new(0, 2)
DropsLayout.Parent = DropsContainer

function axelhubkaitun:AddDrop(itemName, count)
    local Row = Instance.new("TextLabel")
    Row.Name = "DropItem"
    Row.Size = UDim2.new(1, 0, 0, 20)
    Row.BackgroundTransparency = 1
    Row.Font = Enum.Font.GothamMedium
    Row.RichText = true
    Row.TextColor3 = Color3.fromRGB(220, 220, 235)
    Row.TextSize = 12
    Row.TextStrokeTransparency = 0
    Row.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    Row.TextXAlignment = Enum.TextXAlignment.Left
    
    local amountText = count and string.format(' <font color="rgb(95,230,165)">(+%s)</font>', tostring(count)) or ""
    Row.Text = string.format('• %s%s', tostring(itemName), amountText)
    Row.Parent = DropsContainer
    table.insert(self.Drops, Row)
end

function axelhubkaitun:ClearDrops()
    for _, item in ipairs(self.Drops) do
        if item and item.Parent then item:Destroy() end
    end
    self.Drops = {}
end

local DefaultDropText = Instance.new("TextLabel")
DefaultDropText.Name = "NoDrops"
DefaultDropText.Size = UDim2.new(1, 0, 0, 20)
DefaultDropText.BackgroundTransparency = 1
DefaultDropText.Font = Enum.Font.GothamMedium
DefaultDropText.TextColor3 = Color3.fromRGB(160, 160, 180)
DefaultDropText.TextSize = 12
DefaultDropText.TextStrokeTransparency = 0
DefaultDropText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
DefaultDropText.TextXAlignment = Enum.TextXAlignment.Left
DefaultDropText.Text = isEngInit and "• No drops recorded in this run" or "• ยังไม่มีข้อมูลของดรอปในรอบนี้"
DefaultDropText.Parent = DropsContainer
axelhubkaitun.DefaultDropLabel = DefaultDropText

axelhubkaitun.ChecklistSectionTitle = createSectionTitle(RightCol, "📋", isEngInit and "Kaitun Checklist" or "ความคืบหน้าไอดีไก่ตัน (Kaitun Checklist)", 1)

local ChecklistContainer = Instance.new("Frame")
ChecklistContainer.Name = "ChecklistContainer"
ChecklistContainer.Size = UDim2.new(1, 0, 0, 215)
ChecklistContainer.BackgroundTransparency = 1
ChecklistContainer.LayoutOrder = 3
ChecklistContainer.Parent = RightCol

local CheckLayout = Instance.new("UIListLayout")
CheckLayout.SortOrder = Enum.SortOrder.LayoutOrder
CheckLayout.Padding = UDim.new(0, 3)
CheckLayout.Parent = ChecklistContainer

function axelhubkaitun:CreateChecklistRow(id, titleText, isDone, statusText, order)
    local Row = Instance.new("TextLabel")
    Row.Name = "Task_" .. id
    Row.Size = UDim2.new(1, 0, 0, 21)
    Row.BackgroundTransparency = 1
    Row.Font = Enum.Font.GothamMedium
    Row.RichText = true
    
    local icon = isDone and '<font color="rgb(95,230,165)">✅</font>' or '<font color="rgb(255,77,77)">❌</font>'
    local tagColor = isDone and "rgb(95,230,165)" or "rgb(160,196,255)"
    local statusTag = statusText and string.format(' <font color="%s">[%s]</font>', tagColor, statusText) or ""
    
    Row.Text = string.format('%s %s%s', icon, titleText, statusTag)
    Row.TextColor3 = Color3.fromRGB(235, 235, 250)
    Row.TextSize = 12.5
    Row.TextStrokeTransparency = 0
    Row.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    Row.TextXAlignment = Enum.TextXAlignment.Left
    Row.LayoutOrder = order or 1
    Row.Parent = ChecklistContainer

    self.ChecklistItems[id] = {
        Label = Row,
        Title = titleText,
        IsDone = isDone,
        Status = statusText
    }

    return Row
end

axelhubkaitun:CreateChecklistRow("delivery", "Delivery Quests (---)", false, isEngInit and "Waiting..." or "กำลังรอข้อมูล", 1)
axelhubkaitun:CreateChecklistRow("summon", "Summon Lyth (---)", false, isEngInit and "Pending" or "รอตรวจสอบ", 2)
axelhubkaitun:CreateChecklistRow("awakening", "Awakening (---)", false, isEngInit and "Pending" or "รอตรวจสอบ", 3)
axelhubkaitun:CreateChecklistRow("wings", "Craft Blast Archer Wings", false, isEngInit and "Not Crafted" or "ยังไม่คราฟต์", 4)
axelhubkaitun:CreateChecklistRow("crown", "Craft Blast Archer Crown", false, isEngInit and "Not Crafted" or "ยังไม่คราฟต์", 5)
axelhubkaitun:CreateChecklistRow("raid", "Raid Flame Director", false, isEngInit and "Pending" or "รอตรวจสอบ", 6)
axelhubkaitun:CreateChecklistRow("awakeFlame", "Awakening Flame Director", false, isEngInit and "Incomplete" or "ยังไม่เสร็จ", 7)
axelhubkaitun:CreateChecklistRow("materials", "Farm Material 100 All Kinds (---)", false, isEngInit and "Waiting..." or "กำลังรอข้อมูล", 8)

local StageBoard = Instance.new("Frame")
StageBoard.Name = "StageBoard"
StageBoard.Size = UDim2.new(1, 0, 0, 38)
StageBoard.BackgroundTransparency = 1
StageBoard.BorderSizePixel = 0
StageBoard.LayoutOrder = 3
StageBoard.Parent = MainFrame

local StageLabel = Instance.new("TextLabel")
StageLabel.Name = "StageLabel"
StageLabel.Size = UDim2.new(1, 0, 1, -4)
StageLabel.Position = UDim2.new(0, 0, 0, 4)
StageLabel.BackgroundTransparency = 1
StageLabel.Font = Enum.Font.FredokaOne
StageLabel.RichText = true
local initTaskPrefix = isEngInit and "Current Task:" or "กำลังทำ:"
local initIdleText = isEngInit and "Idle..." or "รอดำเนินการ..."
StageLabel.Text = string.format('<font color="rgb(255,225,95)">📍 Stage:</font> <font color="rgb(255,255,255)">---</font>   <font color="rgb(153,153,170)">|</font>   <font color="rgb(112,226,255)">%s</font> <font color="rgb(95,230,165)">[ %s ]</font>', initTaskPrefix, initIdleText)
StageLabel.TextSize = 15
StageLabel.TextStrokeTransparency = 0
StageLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
StageLabel.TextXAlignment = Enum.TextXAlignment.Center
StageLabel.Parent = StageBoard
axelhubkaitun.StageLabel = StageLabel

local function refreshStageBoard()
    if StageLabel and StageLabel.Parent then
        local isEng = isEnglishEnabled and isEnglishEnabled()
        local safeStage = sanitizeForRichText(axelhubkaitun.Values.Stage or "---")
        local safeAction = sanitizeForRichText(axelhubkaitun.Values.Action or (isEng and "Idle..." or "รอดำเนินการ..."))
        local taskPrefix = isEng and "Current Task:" or "กำลังทำ:"
        StageLabel.Text = string.format(
            '<font color="rgb(255,225,95)">📍 Stage:</font> <font color="rgb(255,255,255)">%s</font>   <font color="rgb(153,153,170)">|</font>   <font color="rgb(112,226,255)">%s</font> <font color="rgb(95,230,165)">[ %s ]</font>',
            safeStage,
            taskPrefix,
            safeAction
        )
    end
end

function axelhubkaitun:SetStage(stageName, actionText)
    if stageName then self.Values.Stage = stageName end
    if actionText then self.Values.Action = actionText end
    refreshStageBoard()
end

function axelhubkaitun:SetCurrentAction(actionText)
    self.Values.Action = actionText
    refreshStageBoard()
end

function axelhubkaitun:SetPlayerInfo(key, val, color)
    local data = self.PlayerInfoLabels[key]
    if data and data.Label then
        if color and typeof(color) == "Color3" then
            data.Color = color
            data.RgbStr = toRgb(color)
        end
        local isEng = isEnglishEnabled and isEnglishEnabled()
        local prefix = isEng and (data.PrefixEN or data.Prefix) or (data.PrefixTH or data.Prefix)
        local safeVal = sanitizeForRichText(val)
        data.Label.Text = string.format('• %s: <font color="%s">%s</font>', prefix, data.RgbStr, safeVal)
    end
end

function axelhubkaitun:SetChecklist(id, isDone, statusText, newTitle)
    local item = self.ChecklistItems[id] or self.ChecklistItems[string.lower(tostring(id))]
    if item and item.Label then
        if isDone ~= nil then item.IsDone = (isDone == true) end
        if statusText ~= nil then item.Status = statusText end
        if newTitle ~= nil then item.Title = newTitle end
        
        local icon = item.IsDone and '<font color="rgb(95,230,165)">✅</font>' or '<font color="rgb(255,77,77)">❌</font>'
        local tagColor = item.IsDone and "rgb(95,230,165)" or "rgb(160,196,255)"
        local safeTitle = sanitizeForRichText(item.Title)
        local safeStatus = sanitizeForRichText(item.Status)
        local statusTag = safeStatus ~= "" and string.format(' <font color="%s">[%s]</font>', tagColor, safeStatus) or ""
        item.Label.Text = string.format('%s %s%s', icon, safeTitle, statusTag)
    end
end

function axelhubkaitun:SetStat(key, val, extra1, extra2)
    local lk = string.lower(tostring(key))
    if lk == "name" or lk == "player" then
        self:SetPlayerInfo("Name", val)
    elseif lk == "level" or lk == "lv" then
        self:SetPlayerInfo("Level", val)
    elseif lk == "character" or lk == "char" then
        self:SetPlayerInfo("Character", val)
    elseif lk == "money" or lk == "beli" then
        self:SetPlayerInfo("Money", val)
    elseif lk == "gems" or lk == "gem" or lk == "fragments" then
        self:SetPlayerInfo("Gems", val)
    elseif lk == "stage" then
        self.Values.Stage = val
        refreshStageBoard()
    elseif lk == "action" or lk == "doing" or lk == "status" then
        self.Values.Action = val
        refreshStageBoard()
    elseif self.ChecklistItems[key] or self.ChecklistItems[lk] then
        local targetId = self.ChecklistItems[key] and key or lk
        if type(val) == "boolean" then
            self:SetChecklist(targetId, val, extra1, extra2)
        else
            self:SetChecklist(targetId, nil, val, extra1)
        end
    end
end

function axelhubkaitun:SetBackgroundTransparency(val)
    if FullscreenBg then
        FullscreenBg.BackgroundTransparency = val
    end
end

-- Header Dragging
local dragging, dragInput, dragStart, startPos

table.insert(_G.AZ_Connections, Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end))

table.insert(_G.AZ_Connections, Header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end))

table.insert(_G.AZ_Connections, UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end))

-- Toggle UI visibility (Insert / RightControl)
local isUiVisible = true
local function toggleUIVisibility()
    isUiVisible = not isUiVisible
    MainFrame.Visible = isUiVisible
    FullscreenBg.Visible = isUiVisible
end

table.insert(_G.AZ_Connections, UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightControl or input.KeyCode == Enum.KeyCode.Insert then
        toggleUIVisibility()
    end
end))

-- Helper แปลงตัวเลขใส่ลูกน้ำ ปลอดภัย 100% แม้ค่าเป็น nil
local function formatNumCommas(val)
    local n = tonumber(val) or 0
    local formatted = tostring(math.floor(n))
    local k
    while true do
        formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

-- ฟังก์ชันหลักสำหรับอัปเดตข้อมูล UI ทุกส่วนแบบแยกอิสระ (ไม่ให้เออเรอร์จุดไหนบล็อกจุดอื่น)
local function updateAllUI()
    -- 1. ข้อมูลผู้เล่น (Player Profile)
    pcall(function()
        local playerName = (lp and lp.Name) or (_G.AZ_Cache and _G.AZ_Cache.name) or "---"
        if playerName == "---" or playerName == "..." then
            if lp and lp.Name and lp.Name ~= "" then playerName = lp.Name end
        end

        local pLvl = 1
        pcall(function()
            if getPlayerLevel then pLvl = getPlayerLevel() end
        end)
        if (not pLvl or pLvl <= 1) and _G.AZ_Cache and _G.AZ_Cache.level and _G.AZ_Cache.level > 1 then
            pLvl = _G.AZ_Cache.level
        end

        local expInfo = ""
        pcall(function()
            if getPlayerExpProgress then expInfo = getPlayerExpProgress() or "" end
        end)
        if (not expInfo or expInfo == "") and _G.AZ_Cache and _G.AZ_Cache.exp and _G.AZ_Cache.exp ~= "" then
            expInfo = _G.AZ_Cache.exp
        end
        local lvlStr = (expInfo ~= "") and string.format("Lv. %s (%s)", tostring(pLvl), expInfo) or ("Lv. " .. tostring(pLvl))
        
        local charDisplay = "---"
        pcall(function()
            if getCharacterDisplayName then charDisplay = getCharacterDisplayName() end
        end)
        if (not charDisplay or charDisplay == "" or charDisplay == "---" or charDisplay == "None") and _G.AZ_Cache and _G.AZ_Cache.charDisplay then
            charDisplay = _G.AZ_Cache.charDisplay
        end

        local traitName = "None"
        pcall(function()
            if getPlayerTraitName then traitName = getPlayerTraitName() end
        end)
        if (not traitName or traitName == "None") and _G.AZ_Cache and _G.AZ_Cache.trait and _G.AZ_Cache.trait ~= "None" then
            traitName = _G.AZ_Cache.trait
        end
        local charStr = (traitName and traitName ~= "None" and traitName ~= "") and string.format("%s [%s]", tostring(charDisplay), tostring(traitName)) or tostring(charDisplay)
        
        local m = 0
        pcall(function()
            if getCurrency then m = getCurrency("money") end
        end)
        if (not m or m == 0) and _G.AZ_Cache and _G.AZ_Cache.money and _G.AZ_Cache.money > 0 then
            m = _G.AZ_Cache.money
        end

        local g = 0
        pcall(function()
            if getCurrency then g = getCurrency("gems") end
        end)
        if (not g or g == 0) and _G.AZ_Cache and _G.AZ_Cache.gems and _G.AZ_Cache.gems > 0 then
            g = _G.AZ_Cache.gems
        end

        local isEng = isEnglishEnabled and isEnglishEnabled()
        if axelhubkaitun.ProfileSectionTitle then
            axelhubkaitun.ProfileSectionTitle.Text = string.format('<font color="rgb(255,225,95)">👤</font> <font color="rgb(255,255,255)">%s</font>', isEng and "Player Profile" or "ข้อมูลผู้เล่น (Player Profile)")
        end
        if axelhubkaitun.DropsSectionTitle then
            axelhubkaitun.DropsSectionTitle.Text = string.format('<font color="rgb(255,225,95)">📦</font> <font color="rgb(255,255,255)">%s</font>', isEng and "Match Drops" or "ไอเทม / ของดรอป (Match Drops)")
        end
        if axelhubkaitun.ChecklistSectionTitle then
            axelhubkaitun.ChecklistSectionTitle.Text = string.format('<font color="rgb(255,225,95)">📋</font> <font color="rgb(255,255,255)">%s</font>', isEng and "Kaitun Checklist" or "ความคืบหน้าไอดีไก่ตัน (Kaitun Checklist)")
        end
        if axelhubkaitun.DefaultDropLabel then
            axelhubkaitun.DefaultDropLabel.Text = isEng and "• No drops recorded in this run" or "• ยังไม่มีข้อมูลของดรอปในรอบนี้"
        end

        axelhubkaitun:SetPlayerInfo("Name", playerName)
        axelhubkaitun:SetPlayerInfo("Level", lvlStr)
        axelhubkaitun:SetPlayerInfo("Character", charStr)
        axelhubkaitun:SetPlayerInfo("Money", formatNumCommas(m))
        axelhubkaitun:SetPlayerInfo("Gems", formatNumCommas(g))
    end)

    -- 2. Stage & Action
    pcall(function()
        local isEng = isEnglishEnabled and isEnglishEnabled()
        local curArea = isMatch and (isEng and "Combat Stage" or "ด่านต่อสู้") or "Lobby"
        pcall(function()
            if getCurrentArea then
                local a = getCurrentArea()
                if a and a ~= "" and a ~= "---" then curArea = a end
            end
        end)

        local curTask = (State and State.CurrentTask) or (isMatch and (isEng and "⚔️ Auto-farming in combat stage..." or "⚔️ กำลังฟาร์มในด่านต่อสู้อัตโนมัติ...") or (isEng and "Idle..." or "รอดำเนินการ..."))
        axelhubkaitun:SetStage(curArea, curTask)
    end)

    -- 3. ความคืบหน้าไอดีไก่ตัน (Checklist)
    pcall(function()
        local clState = nil
        if Webhook and Webhook.getKaitunChecklistState then
            clState = Webhook.getKaitunChecklistState()
        end
        if (not clState or not next(clState)) and _G.AZ_Cache and _G.AZ_Cache.checklist then
            clState = _G.AZ_Cache.checklist
        end
        if clState and type(clState) == "table" then
            for id, data in pairs(clState) do
                if data and type(data) == "table" then
                    local uTitle = data.uiTitle or data.title
                    local uStatus = data.uiStatus or data.status
                    axelhubkaitun:SetChecklist(id, data.isDone, uStatus, uTitle)
                end
            end
        end
    end)
end

_G.AZ_UpdateAllUI = updateAllUI
axelhubkaitun.UpdateAll = updateAllUI

-- อัปเดตทันทีตอนเริ่ม UI 1 ครั้งโดยไม่ต้องรอ Loop!
pcall(updateAllUI)

-- Loop อัปเดตข้อมูล UI แบบเรียลไทม์ต่อเนื่อง (ไม่พึ่งพา ScreenGui.Parent เพื่อความเข้ากันได้ 100% กับ Executor ทุกตัว)
local _AZ_KaitunUI_Running = true
task.spawn(function()
    while _AZ_KaitunUI_Running do
        pcall(function()
            if ScreenGui and not ScreenGui.Parent then
                ScreenGui.Parent = getSafeUiParent()
            end
            updateAllUI()
        end)
        task.wait(0.5)
    end
end)

-- สำรอง Heartbeat อัปเดตทุก 0.5 วินาที กัน task.spawn ถูก Executor บางตัว freeze
local _lastUiHeartbeat = 0
table.insert(_G.AZ_Connections, RunService.Heartbeat:Connect(function()
    if tick() - _lastUiHeartbeat > 0.5 then
        _lastUiHeartbeat = tick()
        pcall(updateAllUI)
    end
end))
end -- end do block

-- ══════════════════════════════════════════════════
-- 6. AUTO SKILL TREE UPGRADE (มี Point ให้อัพ! ไม่มี Point ข้ามทันที)
--    ลำดับ: Damage -> Crit -> Defense -> Speed
-- ══════════════════════════════════════════════════
upgradeActiveSkillsIfPointsAvailable = function(targetChar)
    if not skillTreePkts then return end

    local charProg = RS:FindFirstChild("global") and RS.global:FindFirstChild("utils") and RS.global.utils:FindFirstChild("characterLevelProgression") and require(RS.global.utils.characterLevelProgression)
    local skillTreeCfg = RS:FindFirstChild("assets") and RS.assets:FindFirstChild("config") and RS.assets.config:FindFirstChild("characterSkillTreeConfig") and require(RS.assets.config.characterSkillTreeConfig)

    local charsToUpgrade = {}
    local seen = {}
    local function addChar(c)
        if c and c ~= "" and tostring(c):lower() ~= "none" and not seen[tostring(c):lower()] then
            seen[tostring(c):lower()] = true
            table.insert(charsToUpgrade, tostring(c):lower())
        end
    end

    if targetChar then
        addChar(targetChar)
    else
        -- ให้ความสำคัญกับตัวละครระดับ LYTH เป็นอันดับแรกเสมอ เพราะเริ่มที่ Lv 1 และต้องการ Skill Tree ทันที
        local lythChar = getOwnedLythCharacter()
        if lythChar then addChar(lythChar) end
        local cur = getCharacter()
        if cur then addChar(cur) end
        if hasFlameDirector() then addChar("hutao") end
        if hasMiyabi() then addChar("miyabi") end
    end

    local s = getAccState()
    local orderedBranches = {
        { name = "Damage",  code = "ATK" },
        { name = "Crit",    code = "CRIT" },
        { name = "Defense", code = "DEF" },
        { name = "Speed",   code = "SPD" }
    }

    for _, cName in ipairs(charsToUpgrade) do
        local cData = s and s.CharactersData and s.CharactersData[cName]
        if cData then
            local xpRaw = cData.Progression and cData.Progression.Xp
            local xp = tonumber(readVal(xpRaw)) or 0
            local curSkills = { ATK = 1, CRIT = 1, DEF = 1, SPD = 1 }
            if cData.Progression and cData.Progression.Skills then
                for _, b in ipairs({"ATK", "CRIT", "DEF", "SPD"}) do
                    local sv = cData.Progression.Skills[b]
                    curSkills[b] = tonumber(readVal(sv)) or 1
                end
            end

            local availTokens = 0
            if charProg and charProg.getAvailableTokens then
                availTokens = charProg.getAvailableTokens(cName, xp, curSkills) or 0
            end

            local charBranchesCfg = skillTreeCfg and skillTreeCfg.characters and skillTreeCfg.characters[cName] and skillTreeCfg.characters[cName].branches

            -- วนลูปอัปเกรดแต้มทั้งหมดที่มีตามลำดับ Damage (ATK) -> Crit (CRIT) -> Defense (DEF) -> Speed (SPD)
            -- โดยจะดันสายแรกให้ตัน 5/5 ก่อนเสมอ เมื่อแต้มพอ หากแต้มยังไม่พอก็รอสะสมแต้มสายนั้น
            local maxPasses = 30
            while availTokens > 0 and maxPasses > 0 do
                maxPasses = maxPasses - 1
                local didUpgrade = false

                for _, branchData in ipairs(orderedBranches) do
                    local curTier = curSkills[branchData.code] or 1
                    local bCfg = charBranchesCfg and charBranchesCfg[branchData.code]
                    local maxTier = (bCfg and bCfg.tiers and #bCfg.tiers) or 5

                    if curTier < maxTier then
                        local nextTier = curTier + 1
                        local nextCost = (bCfg and bCfg.tiers and bCfg.tiers[nextTier] and bCfg.tiers[nextTier].cost) or 1

                        if availTokens >= nextCost then
                            setTask(string.format("🌿 อัปเกรด Skill Tree: %s [%d -> %d] (%s)", branchData.name, curTier, nextTier, cName:upper()))
                            pcall(function()
                                skillTreePkts.purchaseCharacterSkill:fire({
                                    character = cName,
                                    branch = branchData.code,
                                    tier = nextTier,
                                    requestId = nextId()
                                })
                            end)
                            task.wait(0.2)
                            availTokens = availTokens - nextCost
                            curSkills[branchData.code] = nextTier
                            didUpgrade = true
                            break -- อัปเกรดสำเร็จ 1 ขั้น ให้วนกลับไปเช็คสายแรก (Damage) ใหม่ทันที เพื่อดันให้ตันก่อน
                        else
                            -- แต้มยังไม่พอสำหรับสายนี้ (เช่น ต้องใช้ 5 แต่มี 1 แต้ม)
                            -- รอสะสมแต้มสายนี้ก่อน ไม่ข้ามไปอัปสายอื่น เพื่อดันสายหลักให้เต็มก่อน
                            if availTokens > 0 then
                                setTask(string.format("🌿 รอ Point อัปเกรด: %s [%d/%d] (มี %d/%d pts) [%s]", branchData.name, curTier, maxTier, availTokens, nextCost, cName:upper()))
                            end
                            break
                        end
                    end
                end

                if not didUpgrade then
                    break
                end
            end
        end
    end
end

-- ══════════════════════════════════════════════════
-- 6.1 AUTO CRAFT ACCESSORIES BY HIGHEST TIER PRIORITY (14 -> 13 -> 12... -> 1)
--     คราฟต์เฉพาะระดับสูงสุดของเกม ไม่คราฟต์ซ้ำอันที่มีแล้วเด็ดขาด!
-- ══════════════════════════════════════════════════
local function autoCraftAvailableAccessories()
    if not lobbyPkts or not lobbyPkts.craftAccessory then return end
    local s = getAccState()
    if not s or not s.material then return end

    local matTable = (type(s.material) == "table" and (s.material.entries or s.material.current or s.material)) or {}
    local function getMatCount(idStr)
        local v = matTable[tostring(idStr)]
        if type(v) == "table" and v.current ~= nil then v = v.current end
        return tonumber(v) or 0
    end

    local accCraft = RS:FindFirstChild("assets") and RS.assets:FindFirstChild("config") and RS.assets.config:FindFirstChild("accessoryCraftConfig") and require(RS.assets.config.accessoryCraftConfig)
    if not accCraft then return end

    -- คราฟต์เฉพาะของสูงสุด 2 ชิ้นเท่านั้น (14: Blast Archer Wings, 13: Blast Archer Crown ตามรูป 1)
    -- ไม่ต้องคราฟของต่ำสุดเด็ดขาด (ไม่เอา 12..1)
    local recipeIds = { 14, 13 }

    for _, id in ipairs(recipeIds) do
        local recipe = accCraft[tostring(id)] or accCraft[id]
        if recipe and not isAccessoryOwnedOrCrafted(id, recipe) then
            local misc = recipe.Misc
            local canCraft = true
            if misc and type(misc) == "string" then
                for req in misc:gmatch("[^|]+") do
                    local mId, mAmt = req:match("^(%d+),(%d+)$")
                    if mId and mAmt then
                        if getMatCount(mId) < tonumber(mAmt) then
                            canCraft = false
                            break
                        end
                    end
                end
            end

            if canCraft then
                local accName = (ACC_MAPPING[id] and ACC_MAPPING[id].name) or ("Accessory #" .. id)
                setTask(string.format("🔨 คราฟต์ระดับสูงสุด: %s [สูตร #%d] (1 ชิ้น)...", accName, id))
                pcall(function()
                    lobbyPkts.craftAccessory:fire(tostring(id))
                    lobbyPkts.craftAccessory:fire(tonumber(id))
                    lobbyPkts.craftAccessory:fire({ craftId = tostring(id), requestId = nextId() })
                end)
                task.wait(0.35)
                pcall(function() Webhook.notifyAccessory(accName, id) end)
                pcall(autoEquipBestAccessory)
                -- คราฟต์ทีละ 1 ชิ้นแล้วหยุดทันทีตามคำสั่ง!
                break
            end
        end
    end
end

-- ══════════════════════════════════════════════════
-- 7. AUTO JOIN DYNAMIC HIGHEST UNLOCKED STAGE
--    (เคลียร์คิวเก่า -> สร้างห้อง -> เดินเข้าวงแหวน -> ล็อครอวาร์ป 100%)
-- ══════════════════════════════════════════════════
local combatBodyPos, combatBodyGyro = nil, nil
local currentAimTargetPos = nil

-- ★ 100% PINPOINT SKILL AIMING HOOK ★
-- ฮุค inputController.getAimPoint เพื่อให้โมดูล movementController.aim และ AlignOrientation เล็งโดนมอนสเตอร์เป๊ะ 100%
pcall(function()
    local ps = lp:FindFirstChild("PlayerScripts")
    local inputCtrlMod = ps and ((ps:FindFirstChild("global") and ps.global:FindFirstChild("controllers") and ps.global.controllers:FindFirstChild("inputController"))
                               or (ps:FindFirstChild("game") and ps.game:FindFirstChild("controllers") and ps.game.controllers:FindFirstChild("inputController")))
    if inputCtrlMod then
        local ok, inputCtrl = pcall(require, inputCtrlMod)
        if ok and inputCtrl and inputCtrl.getAimPoint and not _G.AZ_AimHooked then
            _G.AZ_AimHooked = true
            local origAim = inputCtrl.getAimPoint
            inputCtrl.getAimPoint = function(...)
                if currentAimTargetPos then
                    return currentAimTargetPos
                end
                return origAim(...)
            end
        end
    end
end)

local function cleanupFlight()
    if combatBodyPos then pcall(function() combatBodyPos:Destroy() end); combatBodyPos = nil end
    if combatBodyGyro then pcall(function() combatBodyGyro:Destroy() end); combatBodyGyro = nil end

    local char = lp.Character
    if char then
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BodyGyro") or obj:IsA("BodyPosition") then
                pcall(function() obj:Destroy() end)
            end
        end
    end
end

local isEnteringStage = false

local function enterHighestUnlockedStage()
    pcall(saveCachedData)
    lobbyPkts = getLobbyPackets()
    if isMatch or not lobbyPkts or isEnteringStage then return end
    isEnteringStage = true
    -- ก่อนลงด่านหาเงิน ยืนยัน 100% ว่าถ้ายังไม่มี Lyth จะต้องสวมใส่ Slot 1 (Dragon Eclipse) เท่านั้น!
    pcall(ensureSlot1Equipped)

    local gamemode, mapName, chapterNum, diffNum, customTask = getStrategicStageInfo()

    if not gamemode or not mapName then
        if customTask then setTask(customTask) end
        isEnteringStage = false
        return
    end

    -- ★ ถ้าเป็น STEP 1 Delivery Quest ให้รันวาร์ปส่งเควสต์ให้ครบก่อน ไม่ต้องเข้า Capsule ★
    if gamemode == "Delivery" then
        if customTask then setTask(customTask) end
        pcall(autoCompleteDeliveryQuests50)
        isEnteringStage = false
        return
    end

    -- ★ ถ้าเป็น STEP 2 Summon ให้นั่งสุ่มใน Lobby จนกว่าจะได้ตัวระดับ LYTH ไม่ต้องเข้า Capsule ★
    if gamemode == "Summon" then
        if customTask then setTask(customTask) end
        pcall(autoSummonSlotsManager)
        isEnteringStage = false
        return
    end

    -- ★ ล็อคระดับความยาก NIGHTMARE (4) ทุกโหมด 100% ตามคำสั่ง (Story, Raid) ★
    diffNum = 4
    if customTask then
        setTask(customTask)
    else
        setTask(string.format("🚀 เข้าด่านสูงสุด: %s %s Ch.%d [NIGHTMARE]...", gamemode:upper(), mapName:upper(), chapterNum))
    end

    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        isEnteringStage = false
        return
    end

    cleanupFlight()

    -- ตรวจสอบและเลือกห้อง Capsule ที่ว่าง (1..6)
    local chosenRoom = 2
    pcall(function()
        local qStore = RS:FindFirstChild("lobby") and RS.lobby:FindFirstChild("stores") and RS.lobby.stores:FindFirstChild("ququeRoomStore") and require(RS.lobby.stores.ququeRoomStore)
        if qStore and qStore.namespace and qStore.namespace._stores then
            for r = 1, 6 do
                local sObj = qStore.namespace._stores["room " .. r]
                if sObj and sObj.state then
                    local st = sObj.state.status and (sObj.state.status.current or sObj.state.status)
                    local plrs = sObj.state.players and (sObj.state.players.current or sObj.state.players)
                    if st == "idle" or tonumber(plrs) == 0 then
                        chosenRoom = r
                        break
                    end
                end
            end
        end
    end)

    local roomsFolder = workspace:FindFirstChild("Systems") and workspace.Systems:FindFirstChild("QuqueRooms")
    local roomModel = roomsFolder and roomsFolder:FindFirstChild(tostring(chosenRoom))

    -- เคลียร์คิวเดิมออกก่อน 1 ครั้ง
    pcall(function() lobbyPkts.leaveQuque:fire() end)
    task.wait(0.2)

    -- ส่งคำขอสร้างห้องด่านสูงสุดที่ปลดล็อก
    pcall(function()
        lobbyPkts.createQuque:fire({
            roomNumber  = chosenRoom,
            maxPlayers  = 1,
            map         = mapName,
            gamemode    = gamemode,
            friendsOnly = false,
            difficulty  = diffNum,
            chapter     = chapterNum
        })
    end)

    -- ตรวจสอบหากหน้าต่าง GUI Quque / Create Lobby เด้งขึ้นมา ให้เลือก BathTub + Nightmare + กด Start อัตโนมัติ
    pcall(function()
        local pg = lp:FindFirstChild("PlayerGui")
        local quque = pg and pg:FindFirstChild("UI Animation (Finished)") and pg["UI Animation (Finished)"]:FindFirstChild("Quque")
        if quque and quque.MainFrame and quque.MainFrame.Visible then
            local mf = quque.MainFrame
            local content = mf:FindFirstChild("Content")

            local bathTubPart = content and content:FindFirstChild("MapsList", true) and content.MapsList:FindFirstChild("BathTub", true)
            local bathBtn = bathTubPart and bathTubPart:FindFirstChildWhichIsA("GuiButton", true)
            if bathBtn then clickGuiElementSafely(bathBtn) end

            local nmPart = content and content:FindFirstChild("Difficulty", true) and content.Difficulty:FindFirstChild("Nightmare", true)
            local nmBtn = nmPart and (nmPart:FindFirstChildWhichIsA("GuiButton", true) or nmPart:FindFirstChild("SeletButton", true))
            if nmBtn then clickGuiElementSafely(nmBtn) end

            local startBtn = content and content:FindFirstChild("StaerButton", true)
            if startBtn then clickGuiElementSafely(startBtn) end
        end
    end)

    task.wait(0.25)

    -- วาร์ปตัวเข้าไปยืนในตู้ Capsule ตรงจุด Inside
    local insidePart = roomModel and (roomModel:FindFirstChild("Inside") or roomModel:FindFirstChild("JoinHitbox"))
    local insidePos = insidePart and (insidePart.Position + Vector3.new(0, 1.5, 0)) or Vector3.new(-83.38, 3.5, 202.38)

    if hrp and hrp.Parent then
        hrp.CFrame = CFrame.new(insidePos)
        if firetouchinterest and roomModel and roomModel:FindFirstChild("JoinHitbox") then
            firetouchinterest(hrp, roomModel.JoinHitbox, 0)
            task.wait(0.04)
            firetouchinterest(hrp, roomModel.JoinHitbox, 1)
        end
    end

    -- ยืนล็อคในตู้ รอเวลานับถอยหลัง 5s จนกว่าจะวาร์ปเข้าด่าน
    local waitStart = tick()
    while tick() - waitStart < 8 do
        if isMatch then break end
        if hrp and hrp.Parent then
            hrp.CFrame = CFrame.new(insidePos)
            if hrp.AssemblyLinearVelocity then
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
        end

        pcall(function()
            local pg = lp:FindFirstChild("PlayerGui")
            local quque = pg and pg:FindFirstChild("UI Animation (Finished)") and pg["UI Animation (Finished)"]:FindFirstChild("Quque")
            if quque and quque.MainFrame and quque.MainFrame.Visible then
                local mf = quque.MainFrame
                local startBtn = mf:FindFirstChild("StaerButton", true)
                if startBtn then clickGuiElementSafely(startBtn) end
            end
        end)

        task.wait(0.5)
    end

    isEnteringStage = false
end

-- ══════════════════════════════════════════════════
-- 8. AUTO COMBAT ENGINE
--    Auto Hit + Auto Skills (1 -> 2 -> 3 BodyGyro Aim) + Auto Heal (<80%) + Auto Coin + Auto Next
-- ══════════════════════════════════════════════════
local function findNearestDrop(dropKind)
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local bestDrop = nil
    local bestDist = 2000
    local targetKind = dropKind:lower()

    -- 1. ค้นหาจาก DropStore แบบไดนามิก (เร็วระดับ 0.001ms ไม่กิน CPU)
    local dropStore = RS:FindFirstChild("game") and RS.game:FindFirstChild("stores") and RS.game.stores:FindFirstChild("dropStore")
    if dropStore then
        pcall(function()
            local ds = require(dropStore)
            local state = ds and ds.store and ds.store.state
            local entries = state and (state.entries or state)
            if entries then
                for _, data in pairs(entries) do
                    local dKind = data and (type(data.kind) == "table" and data.kind.current or data.kind)
                    local dPos = data and (type(data.position) == "table" and data.position.current or data.position)
                    if dKind and tostring(dKind):lower() == targetKind and dPos then
                        local dist = (hrp.Position - dPos).Magnitude
                        if dist < bestDist then
                            bestDist = dist
                            bestDrop = { Position = dPos, CFrame = CFrame.new(dPos) }
                        end
                    end
                end
            end
        end)
        if bestDrop then return bestDrop end
    end

    -- 2. ค้นหาจาก workspace ลูกตรงเท่านั้น (ไม่สแกน GetDescendants ทั้งโลก ป้องกัน FPS ตก 100%)
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("BasePart") then
            local objName = obj.Name:lower()
            local isMatchKind = false
            if targetKind == "cash" then
                isMatchKind = (objName == "cash" or objName:find("coin") or objName:find("money") or objName:find("gold"))
            elseif targetKind == "health" then
                isMatchKind = (objName == "health" or objName:find("heal"))
            end

            if isMatchKind then
                local dist = (hrp.Position - obj.Position).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestDrop = obj
                end
            end
        end
    end
    return bestDrop
end

-- ดึงเหรียญ Coin (Cash) ในระยะใกล้ทันทีด้วย TouchInterest
local function vacuumNearbyCoins(maxRange)
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    maxRange = maxRange or 75

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and (obj.Name:lower() == "cash" or obj.Name:lower():find("coin")) then
            if (hrp.Position - obj.Position).Magnitude <= maxRange then
                pcall(function()
                    if firetouchinterest then
                        firetouchinterest(hrp, obj, 0)
                        task.wait(0.01)
                        firetouchinterest(hrp, obj, 1)
                    end
                end)
            end
        end
    end
end

local matchStartTime = tick()
local matchEndSeenTime = 0
local matchNotificationSent = false
local matchStartInventory = isMatch and Webhook.getInventorySnapshot() or nil

-- (clickGuiElementSafely ถูกประกาศไว้ที่ส่วนบนสุดเรียบร้อยแล้ว)

-- ตรวจจับและกดปุ่ม Next / Continue อัตโนมัติเมื่อจบด่าน หรือกดออกกลับ Lobby ถ้าเคลียร์หมด/ไม่มีปุ่ม Next
local function handleMatchEndAutoNext()
    if not isMatch then return false end

    -- ความปลอดภัยขั้นสูงสุด: ด่านเพิ่งเริ่มไม่เกิน 12 วินาที ไม่มีทางจบด่านเด็ดขาด ป้องกันการหลุดกลับ Lobby อัตโนมัติ
    if tick() - matchStartTime < 12 then
        matchEndSeenTime = 0
        return false
    end

    local pg = lp:FindFirstChild("PlayerGui")
    local es = pg and pg:FindFirstChild("EndScreen")
    if not (es and es:IsA("ScreenGui") and es.Enabled) then
        matchEndSeenTime = 0
        return false
    end

    local holder = es:FindFirstChild("Holder")
    if not (holder and holder.Visible) then
        matchEndSeenTime = 0
        return false
    end

    -- ตรวจสอบ CanvasGroup หากมีความโปร่งแสงมากกว่า 80% แสดงว่าหน้าจอยังไม่แสดงจริง
    if holder:IsA("CanvasGroup") and holder.GroupTransparency > 0.8 then
        matchEndSeenTime = 0
        return false
    end

    -- ตรวจสอบว่าหน้าจอแสดงผลจริงบนหน้าจอ
    if holder.AbsoluteSize.Y < 50 or holder.AbsolutePosition.Y < -100 then
        matchEndSeenTime = 0
        return false
    end

    -- ส่งการแจ้งเตือนจบด่าน + สรุปของดรอปผ่าน Discord Webhook (ส่งครั้งเดียวเมื่อจบด่าน)
    if not matchNotificationSent then
        matchNotificationSent = true
        task.spawn(function()
            local isEng = isEnglishEnabled and isEnglishEnabled()
            local durationSec = math.max(1, math.floor(tick() - matchStartTime))
            local durMin = math.floor(durationSec / 60)
            local durSec = durationSec % 60
            local durationStr = isEng and string.format("%d min %02d sec", durMin, durSec) or string.format("%d นาที %02d วินาที", durMin, durSec)

            local drops = Webhook.getMatchDropsDelta(matchStartInventory)
            local dropsTextList = {}
            if #drops > 0 then
                for _, d in ipairs(drops) do
                    if d.isCharacter then
                        table.insert(dropsTextList, string.format("• **%s** x%d", d.id, d.amount))
                    else
                        local matName = Webhook.getMaterialName(d.id)
                        local countStr = isEng and string.format("(+%d pcs)", d.amount) or string.format("(+%d ชิ้น)", d.amount)
                        table.insert(dropsTextList, string.format("• **%s** %s", matName, countStr))
                    end
                end
            else
                table.insert(dropsTextList, isEng and "• No Material Drops (Earned Coins / EXP)" or "• ไม่มี Material ดรอป (ได้รับ Coins / EXP)")
            end
            local dropsStr = table.concat(dropsTextList, "\n")

            local stageAreaName = (getCurrentArea and getCurrentArea() or (isEng and "Combat Stage" or "ด่านต่อสู้"))
            local descStr = isEng and string.format("Character cleared stage **%s** in **%s**", stageAreaName, durationStr) or string.format("ตัวละครเคลียร์ด่าน **%s** เรียบร้อยแล้ว ใช้เวลาไป **%s**", stageAreaName, durationStr)

            Webhook.send({
                title = isEng and "⚡ AXEL HUB · STAGE CLEARED" or "⚡ AXEL HUB · จบด่านสำเร็จ (STAGE CLEARED)",
                color = 3066993, -- Emerald Green
                description = descStr,
                fields = {
                    Webhook.getPlayerInfoField(),
                    {
                        name = isEng and "📦 Match Drops" or "📦 ไอเทม / ของดรอป (Match Drops)",
                        value = dropsStr,
                        inline = false
                    },
                    Webhook.getPityField(),
                    {
                        name = isEng and "📋 Kaitun Checklist Progress" or "📋 ความคืบหน้าไอดีไก่ตัน (Kaitun Checklist)",
                        value = Webhook.getKaitunChecklist(),
                        inline = false
                    }
                }
            })
        end)
    end

    -- ตรวจสอบปุ่มโหวตออกจากแมตช์บนหน้าจอ (เช่น [ออกจากแมตช์] L / [Leave] L) ถ้าขึ้นแล้วให้ออกทันที 100%
    local pg = lp:FindFirstChild("PlayerGui")
    if pg then
        local foundLeaveButton = false
        for _, g in ipairs(pg:GetChildren()) do
            if g:IsA("ScreenGui") and g.Enabled and g.Name ~= "AZ_Kaitun_HUD" then
                for _, btn in ipairs(g:GetDescendants()) do
                    if (btn:IsA("TextButton") or btn:IsA("ImageButton") or btn:IsA("TextLabel")) and btn.Visible then
                        local tLow = (btn:IsA("TextLabel") or btn:IsA("TextButton")) and btn.Text:lower() or ""
                        if tLow:find("ออกจาก") or tLow:find("leave") then
                            foundLeaveButton = true
                            pcall(function()
                                local clickable = btn:IsA("GuiButton") and btn or btn:FindFirstChildWhichIsA("GuiButton") or btn.Parent:FindFirstChildWhichIsA("GuiButton")
                                if clickable then clickGuiElementSafely(clickable) end
                            end)
                            break
                        end
                    end
                end
            end
            if foundLeaveButton then break end
        end

        if foundLeaveButton then
            pcall(function()
                if not isMobileDevice then
                    local vim = game:GetService("VirtualInputManager")
                    if vim then
                        vim:SendKeyEvent(true, Enum.KeyCode.L, false, game)
                        task.wait(0.04)
                        vim:SendKeyEvent(false, Enum.KeyCode.L, false, game)
                    end
                    VirtualUser:TypeKey("l")
                end
                local runPkts = RS:FindFirstChild("game") and RS.game:FindFirstChild("packets") and RS.game.packets:FindFirstChild("runPackets") and require(RS.game.packets.runPackets)
                if runPkts and runPkts.voteResult then
                    runPkts.voteResult:fire("leave")
                    runPkts.voteResult:fire("Leave")
                end
            end)
            setTask("🚪 แมตช์จบแล้ว (ปุ่ม Leave ปรากฏ) — กด Leave ออกกลับ Lobby ทันที!")
            return true
        end
    end

    local buttonsHolder = holder:FindFirstChild("ButtonsHolder", true)
    if buttonsHolder and buttonsHolder.Visible then
        local leaveBox = buttonsHolder:FindFirstChild("LeaveButton")

        -- ★ เมื่อจบด่านทุกโหมด (Story & Raid): กด Leave ออกกลับมา Lobby ทันทีเพื่อตรวจของคราฟและสวมใส่ ★
        if leaveBox and leaveBox.Visible then
            hasWarpedToBossArea = false
            if matchEndSeenTime == 0 then matchEndSeenTime = tick() end
            local leaveClickable = leaveBox:FindFirstChild("Button") or leaveBox:FindFirstChildWhichIsA("GuiButton") or leaveBox
            clickGuiElementSafely(leaveClickable)
            pcall(function()
                local runPkts = RS:FindFirstChild("game") and RS.game:FindFirstChild("packets") and RS.game.packets:FindFirstChild("runPackets") and require(RS.game.packets.runPackets)
                if runPkts and runPkts.voteResult then
                    runPkts.voteResult:fire("leave")
                    runPkts.voteResult:fire("Leave")
                end
            end)
            setTask("🚪 จบด่านแล้ว — กด Leave กลับ Lobby ทันทีเพื่อตรวจของคราฟและเควสต์!")
            if tick() - matchEndSeenTime > 12.0 then
                pcall(function() TeleportService:Teleport(114574503491412, lp) end)
            end
            return true
        end

        -- เผื่อกรณีปุ่ม Leave ใช้ชื่ออื่นใน ButtonsHolder
        for _, b in ipairs(buttonsHolder:GetChildren()) do
            if b:IsA("GuiObject") and b.Visible and b.Name:lower():find("leave") then
                local bClick = b:FindFirstChildWhichIsA("GuiButton") or b
                clickGuiElementSafely(bClick)
                pcall(function()
                    local runPkts = RS:FindFirstChild("game") and RS.game:FindFirstChild("packets") and RS.game.packets:FindFirstChild("runPackets") and require(RS.game.packets.runPackets)
                    if runPkts and runPkts.voteResult then
                        runPkts.voteResult:fire("leave")
                    end
                end)
                return true
            end
        end
    end
    return false
end

-- ตรวจสอบว่าสกิล (1..3) ติดคูลดาวน์หรือไม่จาก HUD และ Game Store
local function isSkillReady(sNum)
    -- 1. ตรวจสอบจาก UI HUD (ตรวจสอบทั้ง box.Frame.cd และ box.cd)
    local pg = lp:FindFirstChild("PlayerGui")
    local hud = pg and pg:FindFirstChild("HUD")
    local skillsFrame = hud and hud:FindFirstChild("skills", true)
    if skillsFrame then
        for _, box in ipairs(skillsFrame:GetChildren()) do
            if box:IsA("GuiObject") then
                local kb = box:FindFirstChild("keybind")
                local kbTxt = kb and kb:FindFirstChild("Txt") and kb.Txt.Text
                local isMatchBox = (kbTxt == tostring(sNum)) or (box.Name == tostring(sNum)) or (box.Name:lower():find("skill" .. tostring(sNum))) or (box.LayoutOrder == sNum)
                if isMatchBox then
                    for _, cd in ipairs({box:FindFirstChild("cd"), box:FindFirstChild("Frame") and box.Frame:FindFirstChild("cd")}) do
                        if cd and cd.Visible then
                            local txt = cd:FindFirstChild("Txt") and cd.Txt.Text
                            local num = tonumber(txt)
                            if (num and num > 0) or (txt and txt ~= "" and txt ~= "0") then
                                return false -- กำลังติด Cooldown อยู่
                            end
                        end
                    end
                end
            end
        end
    end

    -- 2. ตรวจสอบตรงกับ playerNamespace Store
    local storeReady = true
    pcall(function()
        local pns = RS:FindFirstChild("game") and RS.game:FindFirstChild("stores") and RS.game.stores:FindFirstChild("playerNamespace") and require(RS.game.stores.playerNamespace)
        if pns and pns.getLocalPlayerStore then
            local st = pns.getLocalPlayerStore()
            local state = st and st.state
            if state and state.cooldowns and state.cooldowns.entries then
                local charName = state.character and (type(state.character) == "table" and state.character.current or state.character) or ""
                charName = tostring(charName):lower()
                local sKey = charName .. ".skill" .. tostring(sNum)
                local sEndTime = state.cooldowns.entries[sKey]
                if sEndTime then
                    local curTime = workspace:GetServerTimeNow()
                    if sEndTime > curTime then
                        storeReady = false
                    end
                end
            end
        end
    end)
    if not storeReady then return false end

    return true
end

-- ตรวจสอบว่าสกิล Ultimate (G) พร้อมใช้หรือไม่ (รองรับทั้ง PC และ Mobile)
-- ★ กฎเหล็ก: ใช้สกิล Ultimate ได้ก็ต่อเมื่อตัวละครปลดล็อค Evolve / Awakening แล้วเท่านั้น!
--    หากยังไม่ Evolve (IsUltimateUnlocked == false) จะไม่กดเด็ดขาดเพื่อไม่ให้เสียเวลา
local function isUltimateReady()
    local curChar = getCharacter()
    if curChar and curChar ~= "none" and curChar ~= "" then
        if not isCharacterAwakened(curChar) then
            return false -- ตัวละครยังไม่ได้ Evolve ปลดล็อค Awakening ข้ามทันที ไม่กดให้เสียเวลา
        end
    end

    local pg = lp:FindFirstChild("PlayerGui")
    local hud = pg and (pg:FindFirstChild("HUD") or pg:FindFirstChild("hud") or pg:FindFirstChild("MainHUD"))
    if not hud then return true end
    local ult = hud:FindFirstChild("Ultimate", true) or hud:FindFirstChild("Ult", true) or hud:FindFirstChild("ultimate", true)
    if not ult then return true end
    local locked = ult:FindFirstChild("Locked", true) or ult:FindFirstChild("Cooldown", true) or ult:FindFirstChild("cooldown", true)
    if locked and locked.Visible then
        return false -- อัลติยังติดคูลดาวน์/ยังไม่พร้อม
    end
    local bar = ult:FindFirstChild("Bar", true) or ult:FindFirstChild("Fill", true)
    if bar and bar:IsA("GuiObject") then
        local sz = bar.Size
        if (sz.Y.Scale > 0 and sz.Y.Scale < 0.95) or (sz.X.Scale > 0 and sz.X.Scale < 0.95) then
            return false
        end
    end
    return true
end

-- นับจำนวนมอนสเตอร์ที่ยังมีชีวิตอยู่ในด่าน (รองรับทั้งที่มีและไม่มี Humanoid)
local function countAliveEnemies()
    local ef = workspace:FindFirstChild("enemies")
    if not ef then return 0 end
    local count = 0
    for _, model in ipairs(ef:GetChildren()) do
        local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
        if root and isValidEnemyModel(model, root) then
            local hum = model:FindFirstChildOfClass("Humanoid")
            if (not hum) or (hum.Health > 0) then
                count = count + 1
            end
        end
    end
    return count
end

local currentMatchArea = 1
local hasWarpedToBossArea = false
local areaSpawnedEnemies = {}
local wasTargetingRubble = false
local lastBorderWaitSeen = {}
local lastAreaWaitSeen = {}

local function getMatchAreasFolder()
    local w = workspace:FindFirstChild("World")
    if w and w:FindFirstChild("Areas") then return w.Areas end
    if workspace:FindFirstChild("Areas") then return workspace.Areas end
    if w and w:FindFirstChild("Map") and w.Map:FindFirstChild("Areas") then return w.Map.Areas end
    if workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Areas") then return workspace.Map.Areas end
    return nil
end

local function getCurrentMatchArea()
    -- 1. ดึงจาก runStore โดยตรง (Game Engine State แม่นยำ 100% ไม่มีทางผิดพลาด)
    local rStore = RS:FindFirstChild("game") and RS.game:FindFirstChild("stores") and RS.game.stores:FindFirstChild("runStore")
    if rStore then
        local ok, res = pcall(function()
            local mod = require(rStore)
            local st = mod.store and mod.store.state or mod.state
            if st and st.area then
                local a = (type(st.area) == "table" and st.area.current) or st.area
                local aNum = tonumber(a)
                if aNum and aNum > 0 then return aNum end
            end
        end)
        if ok and res then return res end
    end

    -- 2. Fallback จาก PlayerGui (ตัด NextBoss ออกเด็ดขาด)
    local pg = lp and lp:FindFirstChild("PlayerGui")
    if pg then
        for _, gName in ipairs({"RoundHUD", "RunSide", "HUD"}) do
            local g = pg:FindFirstChild(gName)
            if g then
                for _, d in ipairs(g:GetDescendants()) do
                    if d:IsA("TextLabel") and d.Visible and d.Text ~= "" then
                        local isNextBoss = d.Name:lower():find("nextboss") or (d.Parent and d.Parent.Name:lower():find("nextboss")) or (d.Parent and d.Parent.Parent and d.Parent.Parent.Name:lower():find("nextboss"))
                        if not isNextBoss then
                            local txt = d.Text
                            if not txt:lower():find("next") and not txt:find("ถัดไป") then
                                local aMatch = txt:match("[Aa]rea%s*(%d+)")
                                if aMatch then
                                    local aNum = tonumber(aMatch)
                                    if aNum then return aNum end
                                end
                                local thMatch = txt:match("พื้นที่%s*(%d+)") or txt:match("เขต%s*(%d+)")
                                if thMatch then
                                    local aNum = tonumber(thMatch)
                                    if aNum then return aNum end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return currentMatchArea or 1
end

local function getAreaCenterPosition(areaNum)
    local aNum = areaNum or getCurrentMatchArea()
    local areasFolder = getMatchAreasFolder()
    if areasFolder then
        local aPart = areasFolder:FindFirstChild(tostring(aNum))
        if not aPart and aNum >= 5 then
            aPart = areasFolder:FindFirstChild("5") or areasFolder:FindFirstChild("Boss")
        end
        if not aPart and aNum == 1 then
            aPart = areasFolder:FindFirstChild("1") or areasFolder:FindFirstChildWhichIsA("BasePart")
        end
        if aPart and aPart:IsA("BasePart") then
            return aPart.Position + Vector3.new(0, 1.2, 0), aPart
        end
    end

    -- สำหรับแมพที่ไม่มี Areas folder (เช่น Hunter x Hunter ใช้ Border)
    local mapFolder = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map")
    if mapFolder and aNum and aNum > 1 then
        local border = mapFolder:FindFirstChild("Border" .. tostring(aNum - 1))
        if border then
            local blocker = border:FindFirstChild("Blocker") or border:FindFirstChildWhichIsA("BasePart", true)
            if blocker then
                local forwardDist = (aNum >= 5) and 60 or 35
                local forwardPos = blocker.Position + (blocker.CFrame.LookVector * forwardDist)
                return Vector3.new(forwardPos.X, blocker.Position.Y + 1.2, forwardPos.Z), blocker
            end
        end
    end
    return nil, nil
end

-- ตรวจสอบสถานะและจำนวน Wave ในด่านปัจจุบัน (เช่น Wave 1/2, Wave 2/2)
local cachedWaveProgress = {}
local function getCurrentWaveProgress()
    -- 1. ดึงจาก runStore โดยตรง (Game Engine State)
    local rStore = RS:FindFirstChild("game") and RS.game:FindFirstChild("stores") and RS.game.stores:FindFirstChild("runStore")
    if rStore then
        local ok, cW, mW = pcall(function()
            local mod = require(rStore)
            local st = mod.store and mod.store.state or mod.state
            if st then
                local w = (type(st.wave) == "table" and st.wave.current) or st.wave
                local wc = (type(st.waveCount) == "table" and st.waveCount.current) or st.waveCount
                local curW = tonumber(w) or 1
                local maxW = tonumber(wc) or 1
                return curW, maxW
            end
        end)
        if ok and mW and mW > 0 then
            cW = math.max(1, cW or 1)
            cachedWaveProgress[currentMatchArea or 1] = { curW = cW, maxW = mW }
            return cW, mW
        end
    end

    -- 2. Fallback: ดึงจาก PlayerGui
    local pg = lp and lp:FindFirstChild("PlayerGui")
    if pg then
        for _, gName in ipairs({"RoundHUD", "RunSide", "HUD", "MobileHUD"}) do
            local g = pg:FindFirstChild(gName)
            if g then
                for _, d in ipairs(g:GetDescendants()) do
                    if d:IsA("TextLabel") and d.Visible and d.Text ~= "" then
                        local txt = d.Text
                        local cw, mw = txt:match("[Ww]ave%s*(%d+)%s*/%s*(%d+)")
                        if cw and mw then
                            local cNum = tonumber(cw) or 1
                            local mNum = tonumber(mw) or 1
                            cachedWaveProgress[currentMatchArea or 1] = { curW = cNum, maxW = mNum }
                            return cNum, mNum
                        end
                        local cwTh, mwTh = txt:match("เวฟ%s*(%d+)%s*/%s*(%d+)")
                        if cwTh and mwTh then
                            local cNum = tonumber(cwTh) or 1
                            local mNum = tonumber(mwTh) or 1
                            cachedWaveProgress[currentMatchArea or 1] = { curW = cNum, maxW = mNum }
                            return cNum, mNum
                        end
                    end
                end
            end
        end

        local mh = pg:FindFirstChild("MobileHUD")
        if mh and mh:FindFirstChild("SafeArea") and mh.SafeArea:FindFirstChild("WaveNotice") then
            local msg = mh.SafeArea.WaveNotice:FindFirstChild("Message")
            if msg and msg.Visible and msg.Text:lower():find("next wave starting") then
                return 1, 2
            end
        end
    end

    local saved = cachedWaveProgress[currentMatchArea or 1]
    if saved and saved.maxW and saved.maxW > 1 then
        return saved.curW, saved.maxW
    end
    return 1, 1
end

-- ตรวจสอบว่าเกมขึ้นสถานะให้ทุบ Rubble / กำแพง หรือไม่ (เช็คจากข้อความ Break the rubble ชัดเจน 100%)
local function isRubbleBreakPhase()
    local pg = lp and lp:FindFirstChild("PlayerGui")
    if pg then
        for _, gName in ipairs({"RoundHUD", "RunSide", "HUD"}) do
            local g = pg:FindFirstChild(gName)
            if g then
                for _, d in ipairs(g:GetDescendants()) do
                    if d:IsA("TextLabel") and d.Visible and d.Text ~= "" then
                        local tLow = d.Text:lower()
                        if tLow:find("break the rubble") or tLow:find("break rubble") or tLow:find("rubble to continue") then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

-- ตรวจสอบเงื่อนไขว่าถึงเวลาตี Rubble / กำแพง หรือยัง
local function shouldTargetRubble()
    -- 1. ถ้ายังมีมอนสเตอร์จริงในด่าน ให้ตีมอนสเตอร์ก่อนเสมอ
    if countAliveEnemies and countAliveEnemies() > 0 then
        return false
    end

    -- 2. ถ้าอยู่ใน Area 5/5 (บอส) ไม่มี Rubble ให้ตีเด็ดขาด!
    local curAreaNum = getCurrentMatchArea()
    if curAreaNum >= 5 then
        return false
    end

    -- 3. ตรวจสอบสถานะ Wave ในปัจจุบัน
    local curW, maxW = getCurrentWaveProgress()
    -- ถ้ายังไม่จบทุกเวฟ (เช่น อยู่เวฟ 1/2 หรือ 1/3) แปลว่ามอนสเตอร์เวฟถัดไปกำลังจะเกิด ห้ามไปตี Rubble / กำแพง เด็ดขาด!
    if curW < maxW then
        return false
    end

    -- 4. ถ้าเกมขึ้น UI บอกให้ทุบ Rubble ชัดเจน (Break the rubble)
    if isRubbleBreakPhase() then
        return true
    end

    -- 5. ถ้าจบเวฟสุดท้ายแล้ว (curW >= maxW) และใน Area นี้มอนสเตอร์ตายหมดแล้ว
    if curW >= maxW and maxW > 0 and areaSpawnedEnemies[currentMatchArea] then
        return true
    end

    return false
end

-- ตรวจหาและนับสิ่งกีดขวาง Rubble [BREAK IT] (เมื่อไม่มีมอนสเตอร์จริงในด่านแล้ว และจบทุกเวฟแล้วเท่านั้น)
local function findActiveRubbleTarget()
    -- มีมอนสเตอร์จริง หรือยังไม่ถึงเวลาทุบกำแพง (เช่น ยังอยู่เวฟ 1/2) ห้ามตีเด็ดขาด!
    if not shouldTargetRubble() then
        return nil
    end

    -- 1. ตรวจสอบจาก PlayerGui.RubbleBar (เกมเปิดแถบเลือดกำแพงให้ตี)
    local rb = lp and lp:FindFirstChild("PlayerGui") and lp.PlayerGui:FindFirstChild("RubbleBar")
    if rb and rb.Enabled then
        local holder = rb:FindFirstChild("Holder")
        if holder and holder.Visible then
            local adornee = rb.Adornee
            local targetPart = nil
            local targetPos = nil
            if adornee then
                if adornee:IsA("Attachment") then
                    targetPart = adornee.Parent
                    targetPos = adornee.WorldPosition
                elseif adornee:IsA("BasePart") then
                    targetPart = adornee
                    targetPos = adornee.Position
                end
            end
            if targetPart then
                return {
                    model = targetPart.Parent or targetPart,
                    root = targetPart,
                    pos = targetPos or targetPart.Position,
                    hum = { Health = 100, MaxHealth = 100 },
                    isRubble = true,
                    name = "Rubble [BREAK IT]"
                }
            end
        end
    end

    -- 2. ตรวจสอบจาก workspace.World.Map.Border1..4 ที่มี RubbleMaxHealth และยังไม่พัง
    local map = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map")
    if map then
        for _, border in ipairs(map:GetChildren()) do
            if border.Name:find("Border") then
                local maxHp = border:GetAttribute("RubbleMaxHealth")
                local hp = border:GetAttribute("RubbleHealth")
                if maxHp ~= nil and maxHp > 0 then
                    local currentHp = hp or maxHp
                    if currentHp > 0 then
                        local blocker = border:FindFirstChild("Blocker")
                        local att = blocker and blocker:FindFirstChild("RubbleBar")
                        local rubbleModel = border:FindFirstChild("Rubble")
                        local targetPart = blocker or (rubbleModel and (rubbleModel.PrimaryPart or rubbleModel:FindFirstChildWhichIsA("BasePart")))
                        if targetPart then
                            return {
                                model = border,
                                root = targetPart,
                                pos = att and att.WorldPosition or targetPart.Position,
                                hum = { Health = currentHp, MaxHealth = maxHp },
                                isRubble = true,
                                name = string.format("Rubble [%s]", border.Name)
                            }
                        end
                    end
                end
            end
        end
    end

    return nil
end

-- ดึงชื่อและพลังชีวิตของมอนสเตอร์ (รองรับทั้งมอนสเตอร์ทั่วไปและมอนสเตอร์ที่ไม่มี Humanoid เช่น Spirit Duck)
local function getEnemyInfo(model, root)
    local hum = model:FindFirstChildOfClass("Humanoid")
    local curHp = (hum and hum.Health) or 100
    local maxHp = (hum and hum.MaxHealth) or 100
    local name = model.Name
    local isBoss = false

    -- ค้นหาชื่อและ HP จาก BillboardGui (enemyBar) ใน PlayerGui ที่เล็งมาที่ตัวนี้
    local pg = lp:FindFirstChild("PlayerGui")
    if pg then
        for _, g in ipairs(pg:GetChildren()) do
            if g.Name == "enemyBar" and g:IsA("BillboardGui") then
                local ad = g.Adornee
                if ad and (ad == root or ad:IsDescendantOf(model) or ad.Parent == root) then
                    for _, d in ipairs(g:GetDescendants()) do
                        if d:IsA("TextLabel") and d.Text ~= "" then
                            if d.Name == "Title" or d.Name == "Name" then
                                name = d.Text
                            elseif d.Name == "Tag" and d.Text:find("%[") then
                                name = name .. " " .. d.Text
                            elseif d.Name == "Percent" or d.Text:find("%%") then
                                local pNum = tonumber(d.Text:match("(%d+)%%"))
                                if pNum then
                                    curHp = pNum
                                    maxHp = 100
                                end
                            end
                        end
                    end
                    break
                end
            end
        end
    end

    -- ★ Boss detection จาก getEnemyInfo: ใช้ชื่อ "boss" เท่านั้น (ไม่ใช้ HP) ★
    if name:lower():find("boss") or model.Name:lower():find("boss") then
        isBoss = true
    end

    return name, curHp, maxHp, isBoss
end

-- ตรวจสอบว่าโมเดลมอนสเตอร์ถูกต้องและไม่ใช่ตัวในรูป/ดัมมี่ลอยฟ้า
local function isValidEnemyModel(model, root)
    if not model or not root then return false end
    if root.Position.Y > 500 then return false end
    local mName = model.Name
    if mName:find("Texture") or mName:find("Pin") or mName:find("Dummy") then
        return false
    end
    return true
end



local function findNearestEnemy()
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local enemiesFolder = workspace:FindFirstChild("enemies")
    if enemiesFolder then
        local bossTarget = nil
        local bestTarget = nil
        local bestDist = 100000

        for _, model in ipairs(enemiesFolder:GetChildren()) do
            local mobRoot = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
            if mobRoot and isValidEnemyModel(model, mobRoot) then
                local hum = model:FindFirstChildOfClass("Humanoid")
                local isAlive = (not hum) or (hum.Health > 0)
                if isAlive then
                    -- คำนวณระยะแนวราบ 2D เสมอ
                    local dist = Vector2.new(hrp.Position.X - mobRoot.Position.X, hrp.Position.Z - mobRoot.Position.Z).Magnitude
                    local eName, curHp, maxHp, isBoss = getEnemyInfo(model, mobRoot)

                    local targetData = {
                        model = model,
                        root = mobRoot,
                        hum = hum or { Health = curHp, MaxHealth = maxHp },
                        name = eName,
                        pos = mobRoot.Position,
                        isBoss = isBoss
                    }

                    if isBoss and not bossTarget then
                        bossTarget = targetData
                    end

                    if dist < bestDist then
                        bestDist = dist
                        bestTarget = targetData
                    end
                end
            end
        end

        if bossTarget then return bossTarget end
        if bestTarget then return bestTarget end
    end

    -- 2. ★ ตี Rubble / กำแพง เฉพาะเมื่อมอนสเตอร์ในด่านตายหมด 100% และจบทุกเวฟแล้วเท่านั้น! ★
    -- ห้ามเล็งกำแพงก่อนมอนสเตอร์เด็ดขาด! และห้ามเล็งระหว่างเวฟ (เช่น จบเวฟ 1/2) เด็ดขาด!
    if countAliveEnemies() == 0 and shouldTargetRubble() then
        local rubbleTarget = findActiveRubbleTarget()
        if rubbleTarget then
            return rubbleTarget
        end
    end

    return nil
end

local lastSkillTime = 0
local activeSkillEndTime = 0
local lastUltTime = 0
local skillStepIndex = 1
local lastElevatorPromptTick = 0

-- ══════════════════════════════════════════════════
-- AUTO RAID ELEVATOR & SEGMENT TRANSITION HANDLER
-- ตรวจจับและมุ่งหน้าไปลิฟต์ทันทีเมื่อเคลียร์ห้องเสร็จ เพื่อไปด่านต่อๆ ไป 100%
-- ══════════════════════════════════════════════════
local function handleRaidElevatorTransition(hrp)
    if not isMatch or not hrp then return false end

    -- ตรวจสอบเงื่อนไขลิฟต์เปิด (จาก Attribute ของเซิร์ฟเวอร์ หรือ ข้อความ UI)
    local isElevatorOpen = (workspace:GetAttribute("RaidExitOpen") == true)
    local isSegmentSwitching = (workspace:GetAttribute("SegmentSwitching") == true) or (workspace:GetAttribute("ModeSwitching") == true)

    if not isElevatorOpen then
        local pg = lp:FindFirstChild("PlayerGui")
        local rh = pg and (pg:FindFirstChild("RoundHUD") or pg:FindFirstChild("HUD"))
        if rh then
            for _, d in ipairs(rh:GetDescendants()) do
                if d:IsA("TextLabel") and d.Text ~= "" then
                    local tLow = d.Text:lower()
                    if tLow:find("elevator") or tLow:find("head to the elevator") or tLow:find("go to the elevator") then
                        isElevatorOpen = true
                        break
                    end
                end
            end
        end
    end

    -- ค้นหา Exit Part และ Exit Prompt (มีอยู่ใน Markers.Exit ในทุกห้องของ Raid เสมอ)
    local exitTargetPart = nil
    local exitPrompt = nil

    local markers = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Markers")
    if markers then
        for _, m in ipairs(markers:GetChildren()) do
            local mLow = m.Name:lower()
            if mLow == "exit" or mLow:find("exit") or mLow:find("elevator") or mLow:find("lift") or mLow:find("door") then
                local part = m:IsA("BasePart") and m or m:FindFirstChildWhichIsA("BasePart")
                local prompt = m:FindFirstChildWhichIsA("ProximityPrompt", true)
                if part or prompt then
                    exitTargetPart = part or (prompt and prompt.Parent:IsA("BasePart") and prompt.Parent)
                    exitPrompt = prompt
                    if exitPrompt and exitPrompt.Enabled then
                        isElevatorOpen = true
                        break
                    end
                end
            end
        end
    end

    -- สำรอง: ค้นหา ProximityPrompt ทั่ว workspace ที่เปิดใช้งานอยู่และเกี่ยวกับลิฟต์
    if not exitPrompt then
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("ProximityPrompt") and d.Enabled then
                local oLow = (d.ObjectText or ""):lower()
                local aLow = (d.ActionText or ""):lower()
                local nLow = d.Name:lower()
                if oLow:find("elevator") or oLow:find("exit") or aLow:find("enter") or aLow:find("use") or nLow:find("exit") or nLow:find("elevator") then
                    exitPrompt = d
                    exitTargetPart = d.Parent:IsA("BasePart") and d.Parent or exitTargetPart
                    isElevatorOpen = true
                    break
                end
            end
        end
    end

    -- ถ้าลิฟต์เปิดอยู่ หรือพบ Exit Prompt: ลุยไปลิฟต์ทันที ห้ามรอนิ่งๆ เด็ดขาด!
    if isElevatorOpen or (exitPrompt and exitPrompt.Enabled) then
        setTask("🚪 เคลียร์ห้องเสร็จแล้ว — วาร์ปเข้าลิฟต์และกดเปิดลิฟต์ทันที!")
        cleanupFlight()

        local elevatorPos = nil
        if exitTargetPart and exitTargetPart:IsA("BasePart") then
            elevatorPos = exitTargetPart.Position
        elseif exitPrompt and exitPrompt.Parent and exitPrompt.Parent:IsA("BasePart") then
            elevatorPos = exitPrompt.Parent.Position
        else
            elevatorPos = Vector3.new(383, 98, -57)
        end

        if elevatorPos then
            -- วาร์ปตัวละครไปยืนตรงจุดลิฟต์ / หน้า Prompt
            hrp.CFrame = CFrame.new(elevatorPos + Vector3.new(0, 1.2, 0))
            if hrp.AssemblyLinearVelocity then
                hrp.AssemblyLinearVelocity = Vector3.zero
            end

            -- ทริกเกอร์ Touch บน Exit Part
            if exitTargetPart and firetouchinterest then
                pcall(function()
                    firetouchinterest(hrp, exitTargetPart, 0)
                    task.wait(0.02)
                    firetouchinterest(hrp, exitTargetPart, 1)
                end)
            end

            -- กด ProximityPrompt อัตโนมัติทันที
            if exitPrompt then
                pcall(function()
                    if fireproximityprompt then
                        fireproximityprompt(exitPrompt)
                    else
                        exitPrompt:InputHoldBegin()
                        task.wait(0.05)
                        exitPrompt:InputHoldEnd()
                    end
                end)
            end

            -- จำลองกดปุ่ม E สำรอง (เฉพาะ PC เท่านั้น — Mobile ใช้ Direct Prompt ไม่แตะ Keyboard)
            if not isMobileDevice then
                pcall(function()
                    local vim = game:GetService("VirtualInputManager")
                    if vim then
                        vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                        task.wait(0.03)
                        vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                    end
                    VirtualUser:TypeKey("e")
                end)
            end
        end

        return true
    end

    -- ถ้ากำลังสวิตช์เซกเมนต์ระหว่างโหลดฉาก (และไม่มีลิฟต์เปิดค้างอยู่) ค่อยยืนรอโหลด
    if isSegmentSwitching then
        setTask("🎬 กำลังโหลดฉากลิฟต์ / เปลี่ยนไปยังเซกเมนต์ถัดไป...")
        cleanupFlight()
        return true
    end

    return false
end

-- ★ ล็อคโหวตความยาก NIGHTMARE (4) และกด READY ทันทีในทุกโหมด (Story, Endless/Infinite, Raid) ★
local function autoVoteNightmareAndReady()
    if not isMatch then return end
    pcall(function()
        local runPkts = RS:FindFirstChild("game") and RS.game:FindFirstChild("packets") and RS.game.packets:FindFirstChild("runPackets") and require(RS.game.packets.runPackets)
        if runPkts then
            if runPkts.clientReady then runPkts.clientReady:fire() end
            if runPkts.voteDifficulty then runPkts.voteDifficulty:fire(4) end
        end

        local pg = lp:FindFirstChild("PlayerGui")
        local diffGui = pg and pg:FindFirstChild("Difficulty")
        if diffGui and diffGui.Enabled then
            local nmFrame = diffGui:FindFirstChild("Nightmare", true)
            local selBtn = nmFrame and (nmFrame:FindFirstChild("SeletButton", true) or nmFrame:FindFirstChildWhichIsA("GuiButton", true))
            if selBtn then
                clickGuiElementSafely(selBtn)
            end
        end
    end)
end

local function handleInMatchAreaProgression(hrp)
    if not hrp or not isMatch then return end
    -- ห้ามเดิน/วาร์ปไปจุดอื่นถ้ายังมีมอนสเตอร์ในด่านที่ต้องจัดการ
    if countAliveEnemies and countAliveEnemies() > 0 then return end

    -- ส่งสัญญาณพร้อมสู้และล็อคโหวต Nightmare (4) ทันที
    autoVoteNightmareAndReady()

    -- ตรวจสอบและมุ่งหน้าไปลิฟต์/ประตูทันทีถ้าเปิดอยู่
    if handleRaidElevatorTransition(hrp) then
        return
    end

    local areasFolder = getMatchAreasFolder()

    -- ตรวจสอบเลข Area จาก UI (RoundHUD / HUD)
    local pg = lp:FindFirstChild("PlayerGui")
    local rh = pg and (pg:FindFirstChild("RoundHUD") or pg:FindFirstChild("HUD"))
    if rh then
        for _, d in ipairs(rh:GetDescendants()) do
            if d:IsA("TextLabel") and d.Text ~= "" then
                local txt = d.Text
                -- ถ้าพบ Takedowns 0 แสดงว่าเพิ่งเริ่มด่าน Area 1 ชัวร์ 100%
                if txt:lower():find("takedowns%s*0") and currentMatchArea > 1 then
                    currentMatchArea = 1
                    table.clear(areaSpawnedEnemies)
                end
                -- ตรวจจับ Area ปัจจุบัน (ไม่นับ Next Boss)
                if not txt:lower():find("next boss") then
                    local aMatch = txt:match("[Aa]rea%s*(%d+)")
                    if aMatch then
                        local aNum = tonumber(aMatch)
                        if aNum and aNum > currentMatchArea then
                            currentMatchArea = aNum
                        end
                    end
                end
            end
        end
    end

    if not areasFolder then
        -- สำหรับแมพที่ไม่มี Areas folder แต่ใช้ Border แบ่งโซน (เช่น Hunter x Hunter)
        local mapFolder = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map")
        if mapFolder then
            local highestBrokenBorder = nil
            local highestBorderNum = 0
            for _, b in ipairs(mapFolder:GetChildren()) do
                local bMatch = b.Name:match("[Bb]order(%d+)")
                if bMatch then
                    local bNum = tonumber(bMatch)
                    local hp = b:GetAttribute("RubbleHealth")
                    if hp ~= nil and hp <= 0 then
                        if bNum > highestBorderNum then
                            highestBorderNum = bNum
                            highestBrokenBorder = b
                        end
                    end
                end
            end
            if highestBrokenBorder then
                local blocker = highestBrokenBorder:FindFirstChild("Blocker")
                local targetPart = blocker or highestBrokenBorder:FindFirstChildWhichIsA("BasePart", true)
                if targetPart then
                    local forwardPos = targetPart.Position + (targetPart.CFrame.LookVector * 35)
                    forwardPos = Vector3.new(forwardPos.X, targetPart.Position.Y + 1.2, forwardPos.Z)
                    setTask(string.format("🚶 ข้ามผ่าน Border %d เข้าสู่โซนถัดไป...", highestBorderNum))
                    cleanupFlight()
                    if (hrp.Position - forwardPos).Magnitude > 8 then
                        hrp.CFrame = CFrame.new(forwardPos)
                        if hrp.AssemblyLinearVelocity then
                            hrp.AssemblyLinearVelocity = Vector3.zero
                        end
                    end
                    -- ★ ยืนตรงกลางโซนใหม่รอจนมอนสเตอร์เกิด (ตอบสนองไวเมื่อมอนเกิด) ★
                    if not lastBorderWaitSeen[highestBorderNum] then
                        lastBorderWaitSeen[highestBorderNum] = true
                        cleanupFlight()
                        setTask(string.format("⏳ ยืนตรงกลางโซน %d รอมอนสเตอร์เกิด...", highestBorderNum + 1))
                        for _ = 1, 10 do
                            if findNearestEnemy() then break end
                            task.wait(0.15)
                        end
                    end
                    return
                end
            end
        end

        cleanupFlight()
        setTask("🔍 รอคลื่นมอนสเตอร์เกิดในด่าน...")
        return
    end

    -- ค้นหา Part ประจำ Area ปัจจุบัน
    local areaPart = areasFolder:FindFirstChild(tostring(currentMatchArea))

    -- ถ้าไม่มี Area ปัจจุบัน และยังอยู่ที่ Area 1 ให้หา part แรก
    if not areaPart and currentMatchArea == 1 then
        areaPart = areasFolder:FindFirstChild("1") or areasFolder:FindFirstChildWhichIsA("BasePart")
    end

    -- ถ้ายังไม่เจอ ให้หา Area หมายเลขถัดไปที่ยังมีอยู่ใน Folder
    if not areaPart then
        for a = currentMatchArea + 1, 10 do
            local nextP = areasFolder:FindFirstChild(tostring(a))
            if nextP then
                currentMatchArea = a
                areaPart = nextP
                break
            end
        end
    end

    if areaPart and areaPart:IsA("BasePart") then
        local targetPos = areaPart.Position + Vector3.new(0, 1.2, 0)
        local dist = (hrp.Position - targetPos).Magnitude

        setTask(string.format("🏛️ เดินไปจุดกลางห้อง Area %d (ห่าง %.0f m)...", currentMatchArea, dist))
        cleanupFlight()

        if dist > 8 then
            hrp.CFrame = CFrame.new(targetPos)
            if hrp.AssemblyLinearVelocity then
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
        end

        -- ทริกเกอร์ touch บน trigger part ของห้อง
        if firetouchinterest then
            firetouchinterest(hrp, areaPart, 0)
            task.wait(0.02)
            firetouchinterest(hrp, areaPart, 1)
        end

        -- ★ ยืนตรงกลางห้องรอจนมอนสเตอร์เกิด (ตอบสนองไวเมื่อมอนเกิด) ★
        if not lastAreaWaitSeen[currentMatchArea] then
            lastAreaWaitSeen[currentMatchArea] = true
            cleanupFlight()
            setTask(string.format("⏳ ยืนตรงกลางห้อง Area %d รอมอนสเตอร์เกิด...", currentMatchArea))
            for _ = 1, 10 do
                if findNearestEnemy() then break end
                task.wait(0.15)
            end
        end
    else
        cleanupFlight()
        setTask("🔍 กำลังรอคลื่นมอนสเตอร์ในห้อง...")
    end
end

local function executeCombatCycle()
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then
        cleanupFlight()
        return
    end

    applyNoClip()

    -- ในล็อบบี้: ไม่บินเด็ดขาด
    if not isMatch then
        cleanupFlight()
        enterHighestUnlockedStage()
        return
    end

    -- ★ SAFE SPAWN HOVER (+20 STUDS) WHILE LOADING: ยืนลอยสูง +20 ตอนโหลด กันมอนสเตอร์รุมตีตายก่อนโหลดเสร็จ ★
    local isSafeHoverEnabled = (getgenv().AZ_Config == nil or getgenv().AZ_Config.SafeSpawnHover ~= false)
    local isMatchLoading = (not workspace:FindFirstChild("World")) or (tick() - matchStartTime < 4.5)

    if isSafeHoverEnabled and isMatchLoading then
        setTask("⏳ กำลังโหลดแมพและระบบ — ลอยตัวปลอดภัยที่ความสูง +20 เมตร...")
        if not combatBodyPos or not combatBodyPos.Parent then
            combatBodyPos = Instance.new("BodyPosition")
            combatBodyPos.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            combatBodyPos.P = 32000
            combatBodyPos.D = 850
            combatBodyPos.Parent = hrp
        end
        if not _spawnHoverBaseY then
            _spawnHoverBaseY = hrp.Position.Y
        end
        local safeY = _spawnHoverBaseY + 20
        combatBodyPos.Position = Vector3.new(hrp.Position.X, safeY, hrp.Position.Z)
        if hrp.Position.Y < safeY - 5 then
            hrp.CFrame = CFrame.new(hrp.Position.X, safeY, hrp.Position.Z)
            if hrp.AssemblyLinearVelocity then
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
        end
        return
    else
        _spawnHoverBaseY = nil
    end

    -- ★ โหวตความยาก NIGHTMARE (4) และกด Ready อัตโนมัติทุกโหมด (Story, Endless, Raid) ★
    autoVoteNightmareAndReady()

    -- ══════════════════════════════════════════════════
    -- ★ AUTO NEXT CHECK: ตรวจสอบจบด่านและกด Next ทันที ★
    -- ══════════════════════════════════════════════════
    if handleMatchEndAutoNext() then
        return
    end

    -- ══════════════════════════════════════════════════
    -- ★ AUTO RAID ELEVATOR: ตรวจจับและไปลิฟต์ทันทีเมื่อเคลียร์ห้อง (RaidExitOpen) ★
    -- ══════════════════════════════════════════════════
    if (workspace:GetAttribute("RaidExitOpen") == true) and handleRaidElevatorTransition(hrp) then
        return
    end

    -- ══════════════════════════════════════════════════
    -- ★ HP & RETREAT LOGIC:
    --   1. ถ้าอยู่ในสถานะพักฟื้น (IsHealing): ลอยนิ่งๆ ที่ความสูง Y=100 รอจนกว่าเลือด >= 80% ห้ามลงไปตีเด็ดขาด!
    --   2. เลือดต่ำกว่า 30%: เข้าสู่โหมดพักฟื้น บินขึ้น Y=100 นิ่งๆ ทันที
    --   3. ถ้าเลือดไม่ต่ำกว่า 30% และไม่ได้พักฟื้น: ลุยต่อสู้ต่อเนื่อง
    -- ══════════════════════════════════════════════════
    local hpRatio = hum.Health / hum.MaxHealth

    -- 1. ถ้ากำลังพักฟื้น: รอจนกว่าเลือด >= 80% (0.80) ห้ามลงไปตีเด็ดขาด แม้เลือดจะถึง 50-70% ก็ให้อยู่นิ่งๆ
    if State.IsHealing then
        if hpRatio >= 0.80 then
            State.IsHealing = false
            cleanupFlight()
            setTask("⚔️ เลือดฟื้นฟูถึง 80% แล้ว — วาร์ปกลับลงมาลุยตีทันที!")
        else
            setTask(string.format("🩹 เลือดวิกฤต (%.0f%%) — ลอยพักฟื้นที่ความสูง Y=100 นิ่งๆ รอถึง 80%%...", hpRatio * 100))
            if not combatBodyPos or not combatBodyPos.Parent then
                combatBodyPos = Instance.new("BodyPosition")
                combatBodyPos.MaxForce = Vector3.new(1e6, 1e6, 1e6)
                combatBodyPos.P = 25000
                combatBodyPos.Parent = hrp
            end
            combatBodyPos.Position = Vector3.new(hrp.Position.X, 100, hrp.Position.Z)
            if hrp.Position.Y < 50 then
                hrp.CFrame = CFrame.new(hrp.Position.X, 100, hrp.Position.Z)
                if hrp.AssemblyLinearVelocity then
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end
            end
            pcall(function()
                local charCtrl = lp:FindFirstChild("PlayerScripts") and lp.PlayerScripts:FindFirstChild("game") and lp.PlayerScripts.game:FindFirstChild("controllers") and lp.PlayerScripts.game.controllers:FindFirstChild("characterController") and require(lp.PlayerScripts.game.controllers.characterController)
                if charCtrl and charCtrl.performSkill then charCtrl.performSkill(4) end
                if RS:FindFirstChild("performSkill") then RS.performSkill:FireServer(4) end
                if not isMobileDevice then
                    VirtualUser:TypeKey("f")
                    task.wait(0.1)
                    VirtualUser:TypeKey("4")
                end
            end)
            return
        end
    end

    -- 2. เมื่อเลือดลดต่ำกว่า 30%: เข้าสู่สถานะพักฟื้น บินขึ้น Y=100 นิ่งๆ ทันที
    if hpRatio < 0.30 then
        State.IsHealing = true
        setTask(string.format("🩹 เลือดวิกฤต %.0f%% (<30%%) — บินขึ้นที่สูง Y=100 พักฟื้นจนกว่าจะถึง 80%%!", hpRatio * 100))
        if not combatBodyPos or not combatBodyPos.Parent then
            combatBodyPos = Instance.new("BodyPosition")
            combatBodyPos.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            combatBodyPos.P = 25000
            combatBodyPos.Parent = hrp
        end
        combatBodyPos.Position = Vector3.new(hrp.Position.X, 100, hrp.Position.Z)
        if hrp.Position.Y < 50 then
            hrp.CFrame = CFrame.new(hrp.Position.X, 100, hrp.Position.Z)
            if hrp.AssemblyLinearVelocity then
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
        end
        pcall(function()
            local charCtrl = lp:FindFirstChild("PlayerScripts") and lp.PlayerScripts:FindFirstChild("game") and lp.PlayerScripts.game:FindFirstChild("controllers") and lp.PlayerScripts.game.controllers:FindFirstChild("characterController") and require(lp.PlayerScripts.game.controllers.characterController)
            if charCtrl and charCtrl.performSkill then charCtrl.performSkill(4) end
            if RS:FindFirstChild("performSkill") then RS.performSkill:FireServer(4) end
            if not isMobileDevice then
                VirtualUser:TypeKey("f")
                task.wait(0.1)
                VirtualUser:TypeKey("4")
            end
        end)
        return
    elseif hpRatio < 0.80 then
        -- เลือด < 80% แต่ยังไม่วิกฤต: ถ้ามีกล่องฮีลในด่านให้แวะเก็บ (ถ้าไม่มีก็ตีมอนต่อ ไม่ต้องบินหลบ)
        local healDrop = findNearestDrop("health")
        if healDrop then
            setTask(string.format("🩹 เลือด %.0f%% (<80%%) — แวะเก็บกล่องฮีลเลือด...", hpRatio * 100))
            if not combatBodyPos or not combatBodyPos.Parent then
                combatBodyPos = Instance.new("BodyPosition")
                combatBodyPos.MaxForce = Vector3.new(1e6, 1e6, 1e6)
                combatBodyPos.P = 25000
                combatBodyPos.Parent = hrp
            end
            combatBodyPos.Position = healDrop.Position
            pcall(function()
                if firetouchinterest then
                    firetouchinterest(hrp, healDrop, 0)
                    task.wait(0.04)
                    firetouchinterest(hrp, healDrop, 1)
                else
                    hrp.CFrame = healDrop.CFrame
                end
            end)
            return
        end
    end

    if State.IsHealing then return end

    -- ดูดเหรียญรอบตัวระหว่างต่อสู้
    vacuumNearbyCoins(75)

    -- ★ SPECIAL CHECK: AREA 5 / BOSS ROOM DIRECT WARP ★
    -- ถ้าด่านปัจจุบันถึง Area 5/5 (หรือห้องบอส)
    -- วาร์ปเข้าห้องบอสแน่นอนเพื่อเปิดทริกเกอร์/เสกบอส แต่ถ้าบอสหรือมอนสเตอร์เกิดแล้ว ให้ต่อสู้ได้เลย ไม่ต้องวาร์ปซ้ำ!
    local curAreaNum = getCurrentMatchArea()
    currentMatchArea = curAreaNum
    if curAreaNum >= 5 then
        local existingTarget = findNearestEnemy()
        if not existingTarget and not hasWarpedToBossArea then
            local area5Pos, area5Part = getAreaCenterPosition(5)
            if area5Pos then
                local distToArea5 = (hrp.Position - area5Pos).Magnitude
                if distToArea5 > 15 then
                    cleanupFlight()
                    hrp.CFrame = CFrame.new(area5Pos)
                    if hrp.AssemblyLinearVelocity then
                        hrp.AssemblyLinearVelocity = Vector3.zero
                    end
                    if area5Part and firetouchinterest then
                        pcall(function()
                            firetouchinterest(hrp, area5Part, 0)
                            task.wait(0.02)
                            firetouchinterest(hrp, area5Part, 1)
                        end)
                    end
                    hasWarpedToBossArea = true
                    setTask("⚡ ตรวจพบ Area 5/5 (บอส) — วาร์ปเข้าห้องบอสเปิดการต่อสู้!")
                    task.wait(0.3)
                    return
                end
            end
        elseif existingTarget then
            hasWarpedToBossArea = true
        end
    else
        hasWarpedToBossArea = false
    end

    -- ค้นหามอนสเตอร์
    local target = findNearestEnemy()
    if not target then
        -- ★ ถ้าเพิ่งทุบกำแพง Rubble แตกหมาดๆ: เดินข้ามเข้าสู่โซนใหม่ทันที และยืนนิ่งๆ ตรงกลางรอมอนสเตอร์เกิด 2 วินาที! ★
        if wasTargetingRubble then
            wasTargetingRubble = false
            cleanupFlight()
            handleInMatchAreaProgression(hrp)
            setTask("⏳ ทุบกำแพงสำเร็จ! เข้าสู่โซนใหม่ รอมอนสเตอร์เกิด...")
            for _ = 1, 10 do
                if findNearestEnemy() then break end
                task.wait(0.15)
            end
            return
        end

        local curW, maxW = getCurrentWaveProgress()
        local curArea = getCurrentMatchArea()
        currentMatchArea = curArea
        local centerPos, areaPart = getAreaCenterPosition(curArea)

        -- ★ ถ้าตัวละครอยู่ห่างจากจุดเกิดมอนสเตอร์ของ Area ปัจจุบันเกิน 25 เมตร (เช่น ข้ามห้องมาแล้วแต่ยังไม่ถึงจุดทริกเกอร์มอนสเตอร์)
        if centerPos and (hrp.Position - centerPos).Magnitude > 25 then
            cleanupFlight()
            hrp.CFrame = CFrame.new(centerPos)
            if hrp.AssemblyLinearVelocity then
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
            if areaPart and firetouchinterest then
                pcall(function()
                    firetouchinterest(hrp, areaPart, 0)
                    task.wait(0.02)
                    firetouchinterest(hrp, areaPart, 1)
                end)
            end
            setTask(string.format("🏛️ วาร์ปเข้าสู่จุดกลางห้อง Area %d...", curArea))
            task.wait(0.2)
            return
        end

        -- ★ ตรวจสอบสถานะ Wave ในห้องปัจจุบัน (เช่น จบเวฟ 1/2) ★
        if curW < maxW then
            -- ★ พอจบเวฟ 1/2 ให้วาร์ปไปตรงกลางยืนเฉยๆ ไม่ต้องตีอะไรเลย จนกว่า target monster จะขึ้น ★
            cleanupFlight()
            if centerPos then
                if (hrp.Position - centerPos).Magnitude > 4 then
                    hrp.CFrame = CFrame.new(centerPos)
                end
            elseif hrp.Position.Y > 8 then
                hrp.CFrame = CFrame.new(hrp.Position.X, 3.0, hrp.Position.Z)
            end
            if hrp.AssemblyLinearVelocity then
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
            setTask(string.format("⏳ จบเวฟ %d/%d — วาร์ปมายืนกลางห้องนิ่งๆ รอ Target Monster เกิด...", curW, maxW))
            task.wait(0.2)
            return
        end

        -- ตรวจสอบว่ามีเหรียญ Coin (Cash) ตกค้างในด่านหรือไม่ เก็บให้เกลี้ยงก่อนเข้า Area ถัดไป!
        local coinDrop = findNearestDrop("cash")
        if coinDrop then
            setTask("💰 เก็บเหรียญ Coin (Cash) ที่ตกอยู่ในด่าน...")
            if not combatBodyPos or not combatBodyPos.Parent then
                combatBodyPos = Instance.new("BodyPosition")
                combatBodyPos.MaxForce = Vector3.new(1e6, 1e6, 1e6)
                combatBodyPos.P = 25000
                combatBodyPos.Parent = hrp
            end
            combatBodyPos.Position = coinDrop.Position
            pcall(function()
                if firetouchinterest then
                    firetouchinterest(hrp, coinDrop, 0)
                    task.wait(0.02)
                    firetouchinterest(hrp, coinDrop, 1)
                else
                    hrp.CFrame = coinDrop.CFrame
                end
            end)
            return
        end

        -- ถ้าห้องนี้มอนสเตอร์เคยเกิดและตายหมดแล้วจริงๆ ให้ขยับไปยัง Area ถัดไป
        if areaSpawnedEnemies[currentMatchArea] then
            areaSpawnedEnemies[currentMatchArea] = nil
            currentMatchArea = currentMatchArea + 1
        end

        -- ★ เดิน/วาร์ปไปยืนกลางห้องของ Area ปัจจุบัน เพื่อให้มอนสเตอร์ออกมาทันที ★
        handleInMatchAreaProgression(hrp)
        return
    end

    -- บันทึกสถานะว่ากำลังตี Rubble หรือไม่ เพื่อเตรียมสลับเข้าโซนใหม่
    if target.isRubble then
        wasTargetingRubble = true
    else
        wasTargetingRubble = false
    end

    -- เมื่อพบมอนสเตอร์แล้ว บันทึกว่าห้องนี้มีมอนสเตอร์เกิดแล้ว
    areaSpawnedEnemies[currentMatchArea] = true

    local targetName = target.name or target.model.Name
    local targetHp = target.hum and (target.hum.Health or 100) or 100
    setTask(string.format("⚔️ ฟาร์ม %s (HP: %.0f)", targetName, targetHp))

    local mobPos = target.pos or (target.root and target.root.Position)
    local mobLook = (target.root and target.root.CFrame.LookVector) or Vector3.new(0, 0, -1)
    local flatLook = Vector3.new(mobLook.X, 0, mobLook.Z)
    flatLook = flatLook.Magnitude > 0.1 and flatLook.Unit or Vector3.new(0, 0, -1)

    local isBoss = false
    local pg = lp:FindFirstChild("PlayerGui")
    -- ★ Boss detection เข้มงวด: ใช้ BossBar UI หรือชื่อ "boss" เท่านั้น ห้ามใช้ HP threshold ★
    if pg and pg:FindFirstChild("BossBar") and pg.BossBar.Enabled then
        isBoss = true
    elseif target.isBoss then
        isBoss = true
    elseif target.name and target.name:lower():find("boss") then
        isBoss = true
    elseif target.model and target.model.Name:lower():find("boss") then
        isBoss = true
    end

    -- ══════════════════════════════════════════════════
    -- ★ COMBAT POSITIONING: ORBIT COMBAT SYSTEM (หมุนรอบมอน ลอยจากพื้นนิดนึง ตี M1 + สกิลใส่ Target 100%) ★
    -- ══════════════════════════════════════════════════
    local orbitSpeed  = 3.2
    local orbitRadius = 5.0
    local floatHeight = 2.8

    local orbitAngle = (tick() * orbitSpeed) % (math.pi * 2)
    local orbitOffset = Vector3.new(math.cos(orbitAngle) * orbitRadius, floatHeight, math.sin(orbitAngle) * orbitRadius)
    local desiredOrbitPos = mobPos + orbitOffset

    -- หันหน้าตรงเข้าหาแกนกลางของตัวมอนสเตอร์เสมอ เพื่อให้ M1 และสกิลพุ่งโดนเป้าหมาย 100%
    local aimTargetPos = mobPos + Vector3.new(0, floatHeight * 0.4, 0)
    local orbitCf = CFrame.lookAt(desiredOrbitPos, aimTargetPos)

    if not combatBodyPos or not combatBodyPos.Parent then
        combatBodyPos = Instance.new("BodyPosition")
        combatBodyPos.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        combatBodyPos.P = 32000
        combatBodyPos.D = 850
        combatBodyPos.Parent = hrp
    end
    combatBodyPos.Position = desiredOrbitPos

    if not combatBodyGyro or not combatBodyGyro.Parent then
        combatBodyGyro = Instance.new("BodyGyro")
        combatBodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        combatBodyGyro.P = 32000
        combatBodyGyro.D = 850
        combatBodyGyro.Parent = hrp
    end
    combatBodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    combatBodyGyro.CFrame = orbitCf

    -- เมื่อเป้าหมายเป็น Rubble / กำแพง: วาร์ปไปยืนประชิดหน้ากำแพงทันทีเพื่อให้ M1 และสกิลโดน 100%
    if target.isRubble then
        local targetLook = (target.root and target.root.CFrame.LookVector) or Vector3.new(0, 0, 1)
        local rubbleFrontPos = mobPos + (targetLook * 5) + Vector3.new(0, 1.2, 0)
        if (hrp.Position - rubbleFrontPos).Magnitude > 5 then
            hrp.CFrame = CFrame.lookAt(rubbleFrontPos, mobPos)
            if hrp.AssemblyLinearVelocity then
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
        end
    else
        -- ให้ BodyPosition นำทางและลอยตัวละครอย่างนุ่มนวลตามฟิสิกส์ ไม่ฝืน CFrame ทะลุกำแพงเพื่อป้องกันเซิร์ฟเวอร์ดึงกลับ (Anti-Rubberband)
        local distToOrbit = (hrp.Position - desiredOrbitPos).Magnitude
        if distToOrbit > 16.0 then
            -- เมื่อเป้าหมายอยู่ไกลเกิน 16 เมตร: วาร์ปเข้าสู่วงโคจรประชิดทันทีเพื่อตีและใช้สกิล ไม่เสียเวลาลอยช้าๆ 10-15 วินาที
            hrp.CFrame = orbitCf
            if hrp.AssemblyLinearVelocity then
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end

    -- ตรวจสอบและอัปเกรด Skill Tree ทันทีเมื่อเวลเพิ่มขึ้นระหว่างต่อสู้ในด่าน (เวล 1 -> 2, 3...)
    if tick() - lastSkillTreeCombatTick > 4.0 then
        lastSkillTreeCombatTick = tick()
        pcall(function()
            local activeC = getCharacter()
            if activeC and activeC ~= "None" and upgradeActiveSkillsIfPointsAvailable then
                upgradeActiveSkillsIfPointsAvailable(activeC)
            end
        end)
    end

    -- 1. Auto Hit (M1) ตีต่อเนื่องตลอดเวลาระหว่าง Orbit หมุนรอบมอน
    pcall(function()
        local charPkts = RS:FindFirstChild("game") and RS.game:FindFirstChild("packets") and RS.game.packets:FindFirstChild("characterPackets") and require(RS.game.packets.characterPackets)
        if charPkts and charPkts.performM1 then
            charPkts.performM1:fire()
        elseif RS:FindFirstChild("performM1") then
            RS.performM1:FireServer()
        end
        if not isMobileDevice then
            VirtualUser:Button1Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            VirtualUser:Button1Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end
    end)

    -- 2. ★ ตรวจสอบและปล่อย Ultimate (G/Skill 4) ปล่อยเฉพาะ "บอส (BOSS)" เท่านั้น (ไม่เสียเวลาปล่อยใส่มอนเล็ก) ★
    local canUseUlt = (getgenv().AZ_Config == nil or getgenv().AZ_Config.AutoUltimate ~= false)
    if canUseUlt and isBoss and not target.isRubble and isUltimateReady() and (tick() - lastUltTime > 1.2) then
        lastUltTime = tick()
        currentAimTargetPos = aimTargetPos

        -- ล็อคมุมตัวละครและมุมกล้องเข้าหากึ่งกลางเป้าหมายโดยตรงก่อนออกท่า
        local hrpPos = hrp.Position
        local toMobFlat = Vector3.new(aimTargetPos.X - hrpPos.X, 0, aimTargetPos.Z - hrpPos.Z)
        if toMobFlat.Magnitude > 0.1 then
            hrp.CFrame = CFrame.lookAt(hrpPos, hrpPos + toMobFlat.Unit)
        end
        if combatBodyGyro and combatBodyGyro.Parent then
            combatBodyGyro.CFrame = CFrame.lookAt(hrpPos, aimTargetPos)
        end
        pcall(function()
            local cam = workspace.CurrentCamera
            if cam then
                cam.CFrame = CFrame.lookAt(cam.CFrame.Position, aimTargetPos)
            end
        end)

        pcall(function()
            local charCtrl = lp:FindFirstChild("PlayerScripts") and lp.PlayerScripts:FindFirstChild("game") and lp.PlayerScripts.game:FindFirstChild("controllers") and lp.PlayerScripts.game.controllers:FindFirstChild("characterController") and require(lp.PlayerScripts.game.controllers.characterController)
            if charCtrl and charCtrl.performSkill then
                charCtrl.performSkill(4)
            end
            if RS:FindFirstChild("performSkill") then
                RS.performSkill:FireServer(4)
            end
            if isMobileDevice then
                pcall(function()
                    local pg = lp:FindFirstChild("PlayerGui")
                    if pg then
                        local candidates = {"Ultimate", "Ult", "ultimate", "UltButton", "UltimateButton", "Skill4", "SkillG", "G"}
                        for _, name in ipairs(candidates) do
                            local obj = pg:FindFirstChild(name, true)
                            if obj then
                                local btn = obj:FindFirstChildWhichIsA("GuiButton") or (obj:IsA("GuiButton") and obj)
                                if btn then
                                    clickGuiElementSafely(btn)
                                    break
                                end
                            end
                        end
                    end
                end)
            else
                VirtualUser:TypeKey("g")
                task.wait(0.04)
                VirtualUser:TypeKey("4")
            end
        end)
        setTask(string.format("💥 ปล่อยอัลติเมท (Ultimate) ใส่บอส: %s!", targetName))
    end

    -- 3. ★ Auto Skills (1 -> 2 -> 3) ยิงใส่ Target ระหว่าง Orbit ล็อคเป้าแม่นยำ 100% ★
    if tick() - lastSkillTime > 0.45 then
        local readySkill = nil
        for step = 0, 2 do
            local checkNum = ((skillStepIndex - 1 + step) % 3) + 1
            if isSkillReady(checkNum) then
                readySkill = checkNum
                skillStepIndex = (checkNum % 3) + 1
                break
            end
        end

        if readySkill then
            lastSkillTime = tick()
            currentAimTargetPos = aimTargetPos

            -- ล็อคมุมตัวละครและมุมกล้องเข้าหากึ่งกลางมอนสเตอร์โดยตรง เพื่อให้สกิลเล็งโดน 100%
            local hrpPos = hrp.Position
            local toMobFlat = Vector3.new(aimTargetPos.X - hrpPos.X, 0, aimTargetPos.Z - hrpPos.Z)
            if toMobFlat.Magnitude > 0.1 then
                hrp.CFrame = CFrame.lookAt(hrpPos, hrpPos + toMobFlat.Unit)
            end
            if combatBodyGyro and combatBodyGyro.Parent then
                combatBodyGyro.CFrame = CFrame.lookAt(hrpPos, aimTargetPos)
            end
            pcall(function()
                local cam = workspace.CurrentCamera
                if cam then
                    cam.CFrame = CFrame.lookAt(cam.CFrame.Position, aimTargetPos)
                end
            end)

            pcall(function()
                local charCtrl = lp:FindFirstChild("PlayerScripts") and lp.PlayerScripts:FindFirstChild("game") and lp.PlayerScripts.game:FindFirstChild("controllers") and lp.PlayerScripts.game.controllers:FindFirstChild("characterController") and require(lp.PlayerScripts.game.controllers.characterController)
                if charCtrl and charCtrl.performSkill then
                    charCtrl.performSkill(readySkill)
                end
                if RS:FindFirstChild("performSkill") then
                    RS.performSkill:FireServer(readySkill)
                end
                if isMobileDevice then
                    pcall(function()
                        local pg = lp:FindFirstChild("PlayerGui")
                        local hud = pg and pg:FindFirstChild("HUD")
                        local skillsFrame = hud and hud:FindFirstChild("skills", true)
                        if skillsFrame then
                            for _, box in ipairs(skillsFrame:GetChildren()) do
                                if box:IsA("GuiObject") and ((box.Name == tostring(readySkill)) or (box.LayoutOrder == readySkill) or box.Name:lower():find("skill" .. tostring(readySkill))) then
                                    local btn = box:FindFirstChildWhichIsA("GuiButton") or (box:IsA("GuiButton") and box)
                                    if btn then clickGuiElementSafely(btn) end
                                end
                            end
                        end
                    end)
                else
                    VirtualUser:TypeKey(tostring(readySkill))
                end
            end)

            setTask(string.format("⚔️ ปล่อยสกิล [%d/3] ล็อคเป้าใส่: %s (HP: %.0f)", readySkill, targetName, targetHp))
        end
    end
end

-- ══════════════════════════════════════════════════
-- 9. MASTER ZERO-CLICK KAITUN PIPELINE
-- ══════════════════════════════════════════════════
task.spawn(function()
    task.wait(1)

    if not isMatch then
        cleanupFlight()
        setTask("⏳ กำลังซิงค์ข้อมูลบัญชีและระบบ Lobby จากเซิร์ฟเวอร์...")

        -- รอให้ ReplicatedStorage และ Account State ซิงค์สมบูรณ์ (สูงสุด 6 วินาที)
        local syncStart = tick()
        while tick() - syncStart < 6 do
            lobbyPkts = getLobbyPackets()
            local s = getAccState()
            if lobbyPkts and s and s.currencies and isSlotDataStable() then
                break
            end
            task.wait(0.3)
        end
        lobbyPkts = getLobbyPackets()

        if not _G.AZ_CodesClaimed and lobbyPkts and lobbyPkts.redeemCode then
            setTask("🎁 เคลียร์โค้ดและรับของรางวัลเริ่มต้น...")
            local promoCodes = getDynamicPromoCodes()
            for _, code in ipairs(promoCodes) do
                pcall(function() lobbyPkts.redeemCode:fire(code) end)
                task.wait(0.08)
            end
            _G.AZ_CodesClaimed = true
        end

        if lobbyPkts then
            pcall(function() lobbyPkts.claimDailyReward:fire(1) end)
            pcall(autoClaimLevelMilestones)
            pcall(function() lobbyPkts.claimQuestRewards:fire({ requestId = nextId() }) end)
            pcall(function() lobbyPkts.claimAchievementRewards:fire({ requestId = nextId() }) end)
            task.wait(0.2)
        end

        if lobbyPkts and lobbyPkts.unlockCharacterSlot then
            for slot = 2, 4 do
                local cost = getSlotUnlockCost(slot)
                if getCurrency("money") >= cost then
                    pcall(function() lobbyPkts.unlockCharacterSlot:fire({ slot = slot, requestId = nextId() }) end)
                    task.wait(0.15)
                end
            end
        end

        -- 1.5 ทำ Delivery Quest 50 เควสต์ปลดล็อคโหมดก่อนอันดับแรก (เฉพาะเมื่อเปิดใช้งาน)
        pcall(autoCompleteDeliveryQuests50)

        -- 2. สลับสวมใส่ตัวละครที่ดีที่สุดที่ครอบครองในสล็อต (เช่น Dragon Eclipse) เพื่อใช้ฟาร์มเงิน
        pcall(function()
            local topChar = getBestOwnedCharacter()
            if topChar then
                autoEquipCharacterIfOwned(topChar)
                upgradeActiveSkillsIfPointsAvailable(topChar)
            else
                upgradeActiveSkillsIfPointsAvailable()
            end
        end)
        -- 3. สวมใส่ Best Title อัตโนมัติ
        pcall(autoEquipBestTitle)

        -- 4. ★ ตรวจสอบ SUMMON PROGRESSION FLOW (Slot 1 Sub Summon -> ปลดล็อค Slot 2 -> สุ่ม Slot 2 หา LYTH) ★
        if not isSummonProgressionComplete() then
            -- ถ้ามีโรลหรือเงิน >= 500: สุ่ม Slot ใน Lobby ทันที
            local curr, bal = getRollCurrencyAvailable()
            if curr then
                pcall(autoSummonSlotsManager)
            end
            -- มั่นใจ 100% ว่าก่อนเข้าด่านหาเงิน ต้องใช้ตัวฟาร์มหลักใน Slot 1 เสมอ (ถ้า Slot 2 ยังไม่ได้ Lyth)
            pcall(ensureSlot1Equipped)
            enterHighestUnlockedStage()
        else
            -- 5. ★ เมื่อได้ตัวระดับ LYTH ครบแล้ว ถึงจะเข้าสู่ขั้นตอน AWAKENING, CRAFT, REROLL TRAIT, และ RAID ★
            pcall(function()
                local topChar = getBestOwnedCharacter()
                if topChar then
                    autoEquipCharacterIfOwned(topChar)
                    upgradeActiveSkillsIfPointsAvailable(topChar)
                end
            end)
            local lythChar = getOwnedLythCharacter()
            if lythChar then
                pcall(function() autoEvolveAwakening(lythChar) end)
            end
            if hasFlameDirector() then
                pcall(placeHuTaoInNonLythSlot)
                pcall(function() autoEvolveAwakening("hutao") end)
                pcall(function() upgradeActiveSkillsIfPointsAvailable("hutao") end)
            end
            pcall(autoCraftAvailableAccessories)
            pcall(autoEquipBestAccessory)
            pcall(autoRerollTargetTrait)
            enterHighestUnlockedStage()
        end
    else
        setTask("⚔️ กำลังฟาร์มในด่านต่อสู้อัตโนมัติ...")
    end

    _G.AZ_ThreadId = (_G.AZ_ThreadId or 0) + 1
    local currentThreadId = _G.AZ_ThreadId

    -- Loop ตลอดชีพ
    while true do
        if _G.AZ_ThreadId ~= currentThreadId then break end
        isMatch = checkIsMatch()
        if lobbyPkts then
            pcall(function()
                lobbyPkts.claimQuestRewards:fire({ requestId = nextId() })
                lobbyPkts.claimAchievementRewards:fire({ requestId = nextId() })
            end)
        end

        if not isMatch then
            -- อยู่ในล็อบบี้
            cleanupFlight()
            currentMatchArea = 1
            hasWarpedToBossArea = false
            lobbyPkts = getLobbyPackets()
            table.clear(areaSpawnedEnemies)
            table.clear(lastBorderWaitSeen)
            table.clear(lastAreaWaitSeen)
            wasTargetingRubble = false
            matchStartTime = tick()
            matchEndSeenTime = 0
            matchNotificationSent = false
            matchStartInventory = Webhook.getInventorySnapshot()
            pcall(autoClaimLevelMilestones)
            pcall(autoEquipBestTitle)
            pcall(autoLockLythSlots)
            if lobbyPkts and lobbyPkts.unlockCharacterSlot then
                for slot = 2, 4 do
                    local cost = getSlotUnlockCost(slot)
                    if getCurrency("money") >= cost then
                        pcall(function() lobbyPkts.unlockCharacterSlot:fire({ slot = slot, requestId = nextId() }) end)
                    end
                end
            end
            pcall(ensureSupportGameSlot2Equipped)
            pcall(autoCompleteDeliveryQuests50)

            if not isSummonProgressionComplete() then
                -- อยู่ในขั้นตอนสุ่ม: สวมใส่ตัวฟาร์ม Slot 1 -> สุ่ม Slot 2 -> เงินหมดสลับกลับ Slot 1 -> เข้าด่าน 1 [NIGHTMARE] หาเงิน
                pcall(ensureSlot1Equipped)
                pcall(autoEquipBestTitle)
                local curr, bal = getRollCurrencyAvailable()
                if curr then
                    pcall(autoSummonSlotsManager)
                end
                pcall(ensureSlot1Equipped)
                enterHighestUnlockedStage()
                task.wait(1.0)
            else
                -- ได้ตัวระดับ Lyth ครบแล้ว: สวมใส่ Lyth -> Awakening -> Craft -> Reroll Trait -> เข้าด่าน (Mat/Raid)
                pcall(function()
                    local topChar = getBestOwnedCharacter()
                    if topChar then
                        autoEquipCharacterIfOwned(topChar)
                        upgradeActiveSkillsIfPointsAvailable(topChar)
                    else
                        upgradeActiveSkillsIfPointsAvailable()
                    end
                end)
                pcall(autoEquipBestTitle)
                local lythChar = getOwnedLythCharacter()
                if lythChar then
                    pcall(function() autoEvolveAwakening(lythChar) end)
                end
                if hasFlameDirector() then
                    pcall(placeHuTaoInNonLythSlot)
                    pcall(function() autoEvolveAwakening("hutao") end)
                    pcall(function() upgradeActiveSkillsIfPointsAvailable("hutao") end)
                end
                pcall(autoCraftAvailableAccessories)
                pcall(autoEquipBestAccessory)
                pcall(autoRerollTargetTrait)
                enterHighestUnlockedStage()
                task.wait(1.0)
            end
        else
            -- อยู่ในด่าน: เช็คจบด่าน Auto Next + ลอยตีมอน 90 องศา + รันสกิล 1 -> 2 -> 3 + เก็บเหรียญ + เก็บฮีลเลือด (<80%)
            handleMatchEndAutoNext()
            pcall(executeCombatCycle)
            task.wait(0.08)
        end
    end
end)
if getgenv then
    getgenv()._AZKaitunCleanup = function()
        _G.AZ_ThreadId = (_G.AZ_ThreadId or 0) + 1
        for _, c in ipairs(_G.AZ_Connections or {}) do pcall(function() c:Disconnect() end) end
        _G.AZ_Connections = {}
        cleanupFlight()
        _AZ_KaitunUI_Running = false
        pcall(function() if axelhubkaitun and axelhubkaitun.ScreenGui then axelhubkaitun.ScreenGui:Destroy() end end)
    end
end

print("[Axel Hub] 🚀 Autonomous Kaitun Pro Online (Auto Coin, Heal <80%, BodyGyro Direct Aim, Auto Next)!")
