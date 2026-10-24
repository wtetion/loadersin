-- [STEALTH] getgenv ผ่าน pcall — ถ้าเกมหา globals ไม่เห็น __HS_UNLOAD string ตรงๆ
local _genv = (type(getgenv) == "function" and pcall(getgenv)) and getgenv() or nil
if _genv then
    local _prev = rawget(_genv, "__HS_UNLOAD")
    if type(_prev) == "function" then pcall(_prev) end
end
pcall(function()
    game:GetService("RunService"):UnbindFromRenderStep("__HS_CameraAim")
end)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- -----------------------------------------------------------------------------
-- 1. Game Modules (Safely required with error isolation)
-- -----------------------------------------------------------------------------
local okShot, ShotClient = pcall(function()
    return require(ReplicatedStorage:WaitForChild("Entity", 10):WaitForChild("ShotClient", 10))
end)
if not okShot or type(ShotClient) ~= "table" or type(ShotClient.AimDirection) ~= "function" then
    warn("[HS] ShotClient not found - wrong game or version")
    return
end

local okGS, GlobalStuff = pcall(function()
    return require(ReplicatedStorage:WaitForChild("Modules", 10):WaitForChild("GlobalStuff", 10))
end)

local okHB, Hitboxes = pcall(function()
    return require(ReplicatedStorage:WaitForChild("Entity", 10):WaitForChild("Hitboxes", 10))
end)

local okAH, ActionHandler = pcall(function()
    local fpg = LocalPlayer:WaitForChild("PlayerGui", 10):WaitForChild("FirstPersonGUI", 10)
    return require(fpg:WaitForChild("ActionHandler", 10))
end)

-- EntityPrediction (for IsRunning + GetTick)
local okEP, EntityPrediction = pcall(function()
    return require(ReplicatedStorage:WaitForChild("Entity", 10):WaitForChild("EntityPrediction", 10))
end)

-- WeaponSim (for CanFire tick check)
local okWS, WeaponSim = pcall(function()
    return require(ReplicatedStorage:WaitForChild("Entity", 10):WaitForChild("WeaponSim", 10))
end)

-- -----------------------------------------------------------------------------
-- 2. Configuration State
-- -----------------------------------------------------------------------------
local S = {
    -- =========================================================================
    -- ALL FEATURES — STEALTH BUILD
    -- Silent Aim   → Camera Aimbot  (ผลเหมือนกัน แต่ server detect ไม่ได้)
    -- Triggerbot   → Human timing   (pattern ไม่ต่างจาก human)
    -- ESP          → เปิด           (client-only, server ไม่เห็น)
    -- Visual HUD   → ปิดทั้งหมด    (mod เห็น screen = ban ทันที)
    -- =========================================================================

    -- [Silent Aim] — ปิด: ใช้ Camera Aimbot แทน (ผลเหมือนกัน server detect ไม่ได้)
    SilentAim = false,
    FovDeg = 6.0,
    ShowFov = false,
    -- [STEALTH] HitChance 72% — คนปกติมี accuracy 55-70%
    -- 100% = obvious anomaly ใน server stat audit หลัง 30+ นาที
    HitChance = 72,
    HitPart = "Nearest",
    HeadBias = 55,             -- ลด head bias ลง (head% สูงเกิน = stat anomaly)
    Priority = "Crosshair",
    WallCheck = true,
    TeamCheck = true,
    MaxDistance = 300,
    Humanize = true,           -- เปิด humanize เสมอ
    HumanizeAmount = 0.25,

    -- [Accuracy Cap] — ให้ accuracy ไม่เกินนี้ (เมื่อเกิน จะเริ่ม inject miss อัตโนมัติ)
    AccuracyCap = 74.0,        -- % ไม่เกินนี้
    AccuracyCapEnabled = true,

    -- [Camera Aimbot]
    CamAimbot = true,
    AimMode = "Hold",
    AimKey = Enum.KeyCode.E,
    -- [STEALTH] Smoothing สูงขึ้น + MaxTurnSpeed ต่ำลง
    -- camera ขยับเร็วเกิน = ไม่ใช่ human -> server stat audit ตรวจจับได้
    Smoothing = 10.0,          -- สูงขึ้น: 10 = smooth ดูเป็น human มากกว่าเดิม
    MaxTurnSpeed = 180,        -- ต่ำลง: 180 deg/s = human aim speed ทั่วไป
    TargetLock = true,

    -- [Prediction & Weapon Engine]
    PredictionMode = "Auto",
    HitscanLead = true,
    CustomSpeed = 350,
    CustomGravity = 80,

    -- [Server Validation]
    CheckAmmo = true,
    CheckReloading = true,
    CheckCooldown = true,
    CheckEmoting = true,

    -- [Simulation] — ปิดทั้งหมด: เส้น/visual = evidence ใน replay
    SimulateRay = true,        -- ✅ safe: Drawing API ไม่ replicate ไป server
    SimulateColor = Color3.fromRGB(0, 255, 220),

    -- [Triggerbot] — เปิด แต่ human timing
    -- mouse1press ยังส่งไป server log — ต้องมี delay สม่ำเสมอกับ human
    Trigger = true,
    TriggerHold = false,       -- false = click ปกติ ไม่ hold (auto weapon ใช้ game's own hold)
    TriggerRate = 0,           -- ปล่อย game คุม fire rate เอง
    TriggerDelayMin = 55,      -- ms: human reaction min
    TriggerDelayMax = 130,     -- ms: human reaction max
    TriggerLead = true,
    TriggerLeadExtra = 0,
    TriggerLock = true,        -- camera lock ขณะ trigger ด้วย (ใช้ camera aimbot ไม่ใช่ silent)
    TriggerPrefire = false,    -- ปิด: ยิงก่อนโผล่ = evidence ใน log
    PrefireMs = 80,

    -- [ESP] — เปิด: client-only drawings server ไม่เห็น
    Esp = true,
    EspBox = true,
    EspName = true,
    EspDist = true,
    EspHealth = true,
    EspTracer = false,
    Chams = true,              -- ✅ safe: client-only, mod ไม่เห็นใน replay
    ChamsFill = 0.6,
    EspColor = Color3.fromRGB(255, 60, 90),

    -- [HUD & Visual] — ปิดหมด: mod เห็น = ban ทันที
    StatusHud = false,         -- ❌ ปิด: mod เห็น HUD = ban ทันที (เปิดเองใน UI)
    TargetMarker = false,      -- ❌ ปิด: target marker โชว์ชัดเกินใน replay
    CustomCrosshair = false,
    CrosshairSize = 6,
    CrosshairGap = 4,
    CrosshairColor = Color3.fromRGB(255, 255, 255),

    -- [Panic]
    PanicKey = Enum.KeyCode.F4,
}

-- -----------------------------------------------------------------------------
-- 3. Runtime Statistics & Tracker

-- -----------------------------------------------------------------------------
local Stats = {
    ShotsFired = 0,
    HitsConfirmed = 0,
    Accuracy = 0,
    TargetAcquisitionTime = 0, -- ms
    FirstSeenClock = 0,
    LastTargetName = "None",
    CurrentWeaponName = "None",
    CurrentWeaponType = "Hitscan",
    LastFireClock = 0,
}

local rng = Random.new()
local connections = {}
local drawings = {}
local highlights = {}
local espPool = {}
local unloaded = false

-- Forward declare Unload (ใช้ใน InputBegan ก่อน define จริง)
local Unload

local isAimingHeld = false
local aimbotToggled = false
local lockedTargetModel = nil
local lastAimTargetPoint = nil
local prefire = nil

-- [STEALTH] Session clock — ติดตามเวลาเล่นเพื่อเพิ่ม variance ตามเวลา
local sessionStart = os.clock()

-- -----------------------------------------------------------------------------
-- 4. Native Drawing Helper (Safe abstraction)
-- -----------------------------------------------------------------------------
local hasDrawing = type(Drawing) == "table" and type(Drawing.new) == "function"

local function newDraw(class, props)
    if not hasDrawing then return nil end
    local ok, d = pcall(Drawing.new, class)
    if not ok or not d then return nil end
    for k, v in pairs(props) do
        pcall(function() d[k] = v end)
    end
    drawings[#drawings + 1] = d
    return d
end

local fovCircle = newDraw("Circle", {
    Thickness = 1,
    NumSides = 64,
    Filled = false,
    Color = Color3.fromRGB(255, 255, 255),
    Transparency = 1,
    Visible = false
})

local simLine = newDraw("Line", {
    Thickness = 1.5,
    Color = S.SimulateColor,
    Transparency = 0.85,
    Visible = false
})

local simImpact = newDraw("Circle", {
    Radius = 4,
    Filled = true,
    Color = S.SimulateColor,
    Transparency = 0.9,
    Visible = false
})

local targetMarker = newDraw("Text", {
    Size = 13,
    Center = true,
    Outline = true,
    Color = Color3.fromRGB(255, 215, 0),
    Visible = false
})

local hudBg = newDraw("Square", {
    Filled = true,
    Color = Color3.fromRGB(15, 15, 18),
    Transparency = 0.75,
    Visible = false
})

local hudText = newDraw("Text", {
    Size = 12,
    Font = 2,
    Color = Color3.fromRGB(230, 230, 230),
    Outline = true,
    Visible = false
})

local chLines = {
    top = newDraw("Line", { Thickness = 1.5, Visible = false }),
    bottom = newDraw("Line", { Thickness = 1.5, Visible = false }),
    left = newDraw("Line", { Thickness = 1.5, Visible = false }),
    right = newDraw("Line", { Thickness = 1.5, Visible = false }),
    dot = newDraw("Circle", { Radius = 1.5, Filled = true, Visible = false })
}

-- -----------------------------------------------------------------------------
-- 5. Game Analysis Helpers
-- -----------------------------------------------------------------------------
-- ============================================================
-- CACHE LAYER — กัน lag จาก expensive calls ทุก frame
-- ============================================================

-- [Cache 1] getLocalModel — refresh ทุก 3s
local _lmCache, _lmCacheTime = nil, -999
local function getLocalModel()
    local now = os.clock()
    if _lmCache and now - _lmCacheTime < 3 then return _lmCache end
    _lmCacheTime = now
    local ok, ign = pcall(function() return ShotClient:Ignore() end)
    if ok and type(ign) == "table" then
        for m in pairs(ign) do _lmCache = m; return m end
    end
    _lmCache = LocalPlayer.Character
    return _lmCache
end

local function playerFromModel(model)
    return Players:FindFirstChild(model.Name:gsub("__Bot$", ""))
end

-- [Cache 2] modelHealth — ไม่ cache (เปลี่ยนบ่อย แต่ GlobalStuff.GetHealth เร็ว)
local function modelHealth(model)
    if not model then return nil end
    if okGS and type(GlobalStuff) == "table" and type(GlobalStuff.GetHealth) == "function" then
        local ok, hp = pcall(GlobalStuff.GetHealth, GlobalStuff, model)
        if ok and type(hp) == "number" then return hp end
    end
    local h = model:GetAttribute("Health")
    return type(h) == "number" and h or nil
end

-- [Cache 3] isAlive — refresh ทุก 0.25s ต่อ model
local _aliveCache, _aliveCacheTime = {}, {}
local function isAlive(model)
    if not model or not model.Parent then return false end
    local now = os.clock()
    if _aliveCache[model] ~= nil and now - (_aliveCacheTime[model] or 0) < 0.25 then
        return _aliveCache[model]
    end
    local result = true
    if okGS and type(GlobalStuff) == "table" and type(GlobalStuff.IsAlive) == "function" then
        local ok, alive = pcall(GlobalStuff.IsAlive, GlobalStuff, model)
        if ok then result = alive == true end
    else
        local hp = modelHealth(model)
        if hp ~= nil and hp <= 0 then result = false end
    end
    _aliveCache[model] = result
    _aliveCacheTime[model] = now
    return result
end

-- [Cache 4] isEnemy — refresh ทุก 5s ต่อ model (team ไม่เปลี่ยนบ่อย)
local _enemyCache, _enemyCacheTime = {}, {}
local function isEnemy(model)
    if not model then return false end
    local lm = getLocalModel()
    if lm and model == lm then return false end
    if not S.TeamCheck then return true end
    local now = os.clock()
    if _enemyCache[model] ~= nil and now - (_enemyCacheTime[model] or 0) < 5 then
        return _enemyCache[model]
    end
    local result = true
    if okGS and type(GlobalStuff) == "table" and type(GlobalStuff.SameTeam) == "function" then
        local myObj = lm or LocalPlayer
        local ok, same = pcall(GlobalStuff.SameTeam, GlobalStuff, myObj, model)
        if ok and type(same) == "boolean" then result = not same end
    end
    _enemyCache[model] = result
    _enemyCacheTime[model] = now
    return result
end

local function angleBetween(a, b)
    return math.deg(math.acos(math.clamp(a:Dot(b), -1, 1)))
end

local REAL_GRAVITY = 80  -- EntityConfig.GRAVITY จริง

-- [Per-Frame Cache] GetPoses — เรียกครั้งเดียวต่อ frame, reuse ทั้ง renderStep+triggerbot
local _posesCache, _posesCacheFrame = nil, -1
local _frameCounter = 0
local function getCachedPoses()
    if _posesCacheFrame == _frameCounter then return _posesCache end
    local ok, poses = pcall(function() return ShotClient:GetPoses() end)
    _posesCache = (ok and type(poses) == "table") and poses or {}
    _posesCacheFrame = _frameCounter
    return _posesCache
end

-- [Cache 6] getCurrentWeapon — ดึงจาก ActionHandler:GetSubject() โดยตรง (MCP-verified)
-- filtergc({WState=true,ShotsSent=true}) ไม่เจอ instance เพราะ Gun.new() ใส่ metatable ทับ
-- GetSubject() → gun instance ที่มี .WState, .Ammo, .WSettings โดยตรง
local _wepCache, _wepCacheTime = nil, -999
local _wepNextScan = 0

local function _getGunSubject()
    -- path: ActionHandler:GetSubject() → subject ที่มี GetToolsFromSubject
    if not okAH or not ActionHandler then return nil end
    local ok1, subj = pcall(function() return ActionHandler:GetSubject() end)
    if not ok1 or not subj then return nil end
    local ok2, tools = pcall(function() return ActionHandler:GetToolsFromSubject(subj) end)
    if not ok2 or type(tools) ~= "table" then return nil end
    -- tools เป็น dict name→instance, เอา element แรกที่มี WState
    for _, inst in pairs(tools) do
        if type(inst) == "table" and type(rawget(inst, "WState")) == "table" then
            return inst
        end
    end
    return nil
end

local function getCurrentWeapon()
    local now = os.clock()
    -- live-read จาก cached gun instance
    if _wepCache then
        local g = _wepCache._ref
        if g and type(g) == "table" then
            local ammo = rawget(g, "Ammo") or 0
            local clip = _wepCache.ClipAmmo
            _wepCache.Ammo        = ammo
            _wepCache.FillAmmo    = rawget(g, "FillAmmo") or 0
            _wepCache.WState      = rawget(g, "WState") or _wepCache.WState
            _wepCache.IsReloading = ammo <= 0 and clip > 0
        end
    end
    -- refresh ทุก 2-3s (jitter)
    if now >= _wepNextScan then
        _wepNextScan = now + 2.0 + rng:NextNumber(0, 1.0)
        task.spawn(function()
            local g = _getGunSubject()
            if not g then
                -- fallback: GetChar ถือ Character ไว้
                local ok3, ch = pcall(function() return ActionHandler:GetChar() end)
                if ok3 and ch then
                    local tool = ch:FindFirstChildOfClass("Tool")
                    if tool then
                        local ok4, gm = pcall(function()
                            return require(tool:FindFirstChildWhichIsA("ModuleScript"))
                        end)
                        if ok4 and type(gm) == "table" and type(rawget(gm,"WState")) == "table" then
                            g = gm
                        end
                    end
                end
            end
            if not g then _wepCache = nil; return end
            local wset     = rawget(g, "WSettings") or {}
            local ammo     = rawget(g, "Ammo") or 0
            local clipAmmo = rawget(g, "WeaponFullClipAmmo") or 1
            local projSpd  = (type(wset) == "table" and (rawget(wset, "ProjSpeed") or (rawget(wset, "Projectile") and 250))) or 0
            local debounce = (type(wset) == "table" and rawget(wset, "Debounce")) or 0.1
            _wepCache = {
                Name         = rawget(g, "Name") or "Unknown",
                Index        = rawget(g, "Index") or 0,
                Gen          = rawget(g, "Gen") or 0,
                Ammo         = ammo,
                FillAmmo     = rawget(g, "FillAmmo") or 0,
                ClipAmmo     = clipAmmo,
                WState       = rawget(g, "WState"),
                WSettings    = wset,
                Debounce     = debounce,
                IsAuto       = rawget(g, "IsAuto") == true,
                IsProjectile = projSpd > 0,
                Speed        = projSpd,
                Gravity      = REAL_GRAVITY,
                IsReloading  = ammo <= 0 and clipAmmo > 0,
                _ref         = g,
            }
            _wepCacheTime = os.clock()
        end)
    end
    return _wepCache
end

-- Server Sanity Validation — ใช้ EntityPrediction:IsRunning() + WeaponSim.CanFire()
-- verified จาก MCP: TICK_RATE=60, WeaponSim.CanFire(wstate,tick) → tick+0.35 >= NextFireTick
local function canFire()
    -- EntityPrediction: ตรวจว่าอยู่ใน round
    if okEP and type(EntityPrediction) == "table" and type(EntityPrediction.IsRunning) == "function" then
        local ok, running = pcall(EntityPrediction.IsRunning, EntityPrediction)
        if ok and running == false then return false end
    end

    local lm = getLocalModel()
    if lm then
        if not isAlive(lm) then return false end
        if S.CheckEmoting and lm:GetAttribute("Emoting") == true then return false end
    end

    local w = getCurrentWeapon()
    if w then
        if S.CheckAmmo and w.Ammo <= 0 then return false end
        if S.CheckReloading and w.IsReloading then return false end
        -- ไม่เช็ค cooldown เอง: Prepare อัปเดต LastFireClock ก่อน AimDirection ของนัดเดียวกัน
        -- ทำให้ elapsed≈0 แล้ว block ทุกนัด (ต้นเหตุยิงโดนตัวตลอด) — เกมคุม fire rate เองอยู่แล้ว
    end
    return true
end

-- Raycast ตรวจกำแพง (Exclude สิ่งที่ไม่ใช่กำแพงของแมพโดยตรง)
local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Exclude
wallParams.IgnoreWater = true

-- [Cache 5] worldIgnoreList base — rebuild ทุก 2s (ไม่ใช่ทุก raycast)
local _ignoreBase, _ignoreBaseTime = nil, -999
local _ignoreWithModel, _ignoreWithModelKey = nil, nil  -- cache model-specific list กัน table.clone ทุก frame
local function worldIgnoreList(model)
    local now = os.clock()
    if not _ignoreBase or now - _ignoreBaseTime >= 2 then
        _ignoreBaseTime = now
        local cam = Workspace.CurrentCamera or Camera
        local base = { cam }
        local lm = getLocalModel()
        if lm then base[#base + 1] = lm end
        local ok, exc = pcall(function() return ShotClient:Exclude() end)
        if ok and type(exc) == "table" then
            for _, inst in ipairs(exc) do
                if inst then base[#base + 1] = inst end
            end
        else
            for _, name in ipairs({ "Entities", "IgnoreThese", "EntityFocus", "StaticTargets" }) do
                local f = Workspace:FindFirstChild(name)
                if f then base[#base + 1] = f end
            end
        end
        _ignoreBase = base
        _ignoreWithModel = nil     -- invalidate model cache เมื่อ base เปลี่ยน
        _ignoreWithModelKey = nil
    end
    -- append per-call target model (cache ถ้า model เดิม — ไม่ต้อง clone ทุก raycast)
    if model then
        if model == _ignoreWithModelKey and _ignoreWithModel then
            return _ignoreWithModel
        end
        local out = table.clone(_ignoreBase)
        out[#out + 1] = model
        _ignoreWithModel = out
        _ignoreWithModelKey = model
        return out
    end
    return _ignoreBase
end

local function isVisible(from, to, model)
    if not S.WallCheck then return true end
    wallParams.FilterDescendantsInstances = worldIgnoreList(model)
    return Workspace:Raycast(from, to - from, wallParams) == nil
end

-- -----------------------------------------------------------------------------
-- 6. Target Selection & Prediction Engine
-- -----------------------------------------------------------------------------
-- HEAD_OFFSET: offset จาก HumanoidRootPart (pose.Pos) ขึ้นไปถึงกึ่งกลางหัว
-- ใช้ pose.Pos + offset แทน visual Head.Position เพราะ server validate ด้วย hitbox
-- ที่คำนวณจาก network position ไม่ใช่ visual
local HEAD_OFFSET  = Vector3.new(0, 1.75, 0)  -- HRP → head center
local TORSO_OFFSET = Vector3.new(0, 0.5,  0)  -- HRP → upper torso

local function partPosition(pose, which)
    local model = pose.Model
    if which == "Head" then
        local head = model and model:FindFirstChild("Head")
        if head and head:IsA("BasePart") then
            return head.Position  -- visual = สอดคล้องกับ server hitbox
        end
        return pose.Pos + Vector3.new(0, 1.75, 0)  -- HRP → head fallback
    end
    local torso = model and (
        model:FindFirstChild("UpperTorso")
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("HumanoidRootPart")
    )
    if torso and torso:IsA("BasePart") then return torso.Position end
    return pose.Pos
end

local function getTargetPartPos(pose)
    local which = S.HitPart
    if which == "Random" then
        which = (rng:NextNumber(0, 100) < S.HeadBias) and "Head" or "Torso"
    elseif which == "Nearest" then
        local headPos = partPosition(pose, "Head")
        local torsoPos = partPosition(pose, "Torso")
        local camPos, look = Camera.CFrame.Position, Camera.CFrame.LookVector
        local angHead = angleBetween(look, (headPos - camPos).Unit)
        local angTorso = angleBetween(look, (torsoPos - camPos).Unit)
        which = (angHead < angTorso) and "Head" or "Torso"
    end
    return partPosition(pose, which)
end

local function leadSeconds()
    if not S.TriggerLead and not S.HitscanLead then return 0 end
    local ping = 0
    local ok, p = pcall(function() return LocalPlayer:GetNetworkPing() end)
    if ok and type(p) == "number" then ping = p end
    -- cap ที่ 0.12s: ping ที่สูงเกินไปทำให้ prediction ผิดเยอะที่ระยะใกล้
    return math.clamp(ping + S.TriggerLeadExtra / 1000, 0, 0.12)
end

-- คำนวณ Prediction จากอาวุธจริง
-- Gravity จริง = REAL_GRAVITY(80) จาก EntityConfig ไม่ใช่ Workspace.Gravity(196.2)
local function getPredictedPos(pose, origin)
    local point = getTargetPartPos(pose)
    local dist = (point - origin).Magnitude
    local w = getCurrentWeapon()

    local vel = (typeof(pose.Vel) == "Vector3") and pose.Vel or Vector3.zero

    if S.PredictionMode == "Auto" and w then
        if w.IsProjectile and w.Speed > 0 then
            -- Projectile: lead + gravity drop (ใช้ gravity จริง = 80)
            local t = dist / w.Speed
            local drop = 0.5 * REAL_GRAVITY * (t * t)
            point = point + (vel * t) + Vector3.new(0, drop, 0)
        else
            -- Hitscan: ping compensation เท่านั้น
            if S.HitscanLead then
                local ping = leadSeconds()
                point = point + (vel * ping)
            end
        end
    elseif S.PredictionMode == "Custom" and S.CustomSpeed > 0 then
        local t = dist / S.CustomSpeed
        local drop = 0.5 * (S.CustomGravity > 0 and S.CustomGravity or REAL_GRAVITY) * (t * t)
        point = point + (vel * t) + Vector3.new(0, drop, 0)
    elseif S.PredictionMode == "Off" then
        -- ไม่ทำ prediction เลย
    else
        -- default: ping lead เสมอ
        if S.HitscanLead then
            local ping = leadSeconds()
            point = point + (vel * ping)
        end
    end

    return point
end

-- ค้นหาเป้าหมายที่ดีที่สุดตาม FOV และ Priority
local function pickTarget(origin)
    local poses = getCachedPoses()
    if #poses == 0 then return nil end

    Camera = Workspace.CurrentCamera
    local camPos, look = Camera.CFrame.Position, Camera.CFrame.LookVector
    local localModel = getLocalModel()

    -- Phase 1: collect candidates by score (NO raycast — cheap)
    local cands, cn = {}, 0
    for _, pose in ipairs(poses) do
        local model = pose.Model
        if model and model ~= localModel and model.Parent and isEnemy(model) and isAlive(model) then
            local point = partPosition(pose, "Head")
            local dist = (point - camPos).Magnitude
            if dist <= S.MaxDistance then
                local ang = angleBetween(look, (point - camPos).Unit)
                if ang <= S.FovDeg then
                    local score
                    if S.Priority == "Distance" then score = dist
                    elseif S.Priority == "Health" then score = modelHealth(model) or 100
                    else score = ang end
                    -- Hysteresis bonus: ให้แต้มต่อ 25% แก่เป้าหมายเดิม ป้องกันการสลับเป้าไปมาเมื่อศัตรูอยู่ใกล้กัน
                    if lockedTargetModel and model == lockedTargetModel then
                        score = score * 0.75
                    end
                    cn = cn + 1
                    cands[cn] = { pose = pose, point = point, score = score }
                end
            end
        end
    end
    if cn == 0 then return nil end

    -- Phase 2: sort by score, raycast only top 3 (ลด raycast จาก N→3 max)
    table.sort(cands, function(a, b) return a.score < b.score end)
    for i = 1, math.min(3, cn) do
        local c = cands[i]
        if isVisible(camPos, c.point, c.pose.Model) then
            return c.pose, c.point
        end
    end
    return nil
end

-- getActiveTarget: Sticky lock พร้อม Hysteresis FOV และ Occlusion Grace Period
local _lockedLastVisible = 0
local function getActiveTarget(origin)
    Camera = Workspace.CurrentCamera
    local camPos = Camera.CFrame.Position
    local look = Camera.CFrame.LookVector
    local now = os.clock()

    if S.TargetLock and lockedTargetModel then
        if not lockedTargetModel.Parent
            or not isAlive(lockedTargetModel)
            or not isEnemy(lockedTargetModel) then
            lockedTargetModel = nil
        else
            local poses = getCachedPoses()
            local foundPose = nil
            for _, pose in ipairs(poses) do
                if pose.Model == lockedTargetModel then
                    foundPose = pose
                    break
                end
            end

            if foundPose then
                local point = partPosition(foundPose, "Head")
                local dist = (point - origin).Magnitude
                local ang = angleBetween(look, (point - origin).Unit)

                -- Lock Hysteresis:
                -- 1) Distance grace: 15% เกิน MaxDistance
                -- 2) FOV grace: 1.6x ของ FovDeg เพื่อไม่ให้หลุดขอบแล้วสลับเป้าทันที
                -- 3) Wall check: grace period 0.35s เมื่อเดินหลบหลังกำแพงชั่วคราว
                local inDist = dist <= (S.MaxDistance * 1.15)
                local inFov = ang <= (S.FovDeg * 1.6)

                local vis = isVisible(camPos, point, lockedTargetModel)
                if vis then
                    _lockedLastVisible = now
                end
                local withinGrace = (now - _lockedLastVisible) < 0.35

                if inDist and inFov and (not S.WallCheck or vis or withinGrace) then
                    local w = getCurrentWeapon()
                    if w and w.IsProjectile and w.Speed > 0 then
                        local vel = (typeof(foundPose.Vel) == "Vector3") and foundPose.Vel or Vector3.zero
                        local t = dist / w.Speed
                        local drop = 0.5 * REAL_GRAVITY * (t * t)
                        point = point + vel * t + Vector3.new(0, drop, 0)
                    end
                    return foundPose, point
                end
            end
            lockedTargetModel = nil
        end
    end

    local pose, point = pickTarget(origin)
    if pose and pose.Model then
        lockedTargetModel = pose.Model
        _lockedLastVisible = now
    else
        lockedTargetModel = nil
    end
    return pose, point
end

-- -----------------------------------------------------------------------------
-- 7. Silent Aim & Shot Tracker Hooks
-- -----------------------------------------------------------------------------
-- MCP-verified: ShotClient.AimDirection ถูก define ใน module body (ไม่ใช่ metatable)
-- ใช้ rawset ก่อน, ถ้าล้มเหลว (frozen table) ใช้ debug.setupvalue เพื่อ swap upvalue แทน
local origAim     = ShotClient.AimDirection
local origPrepare = ShotClient.Prepare
local function hookSet(tbl, key, fn)
    -- ลอง rawset ก่อน
    local ok1 = pcall(rawset, tbl, key, fn)
    if ok1 and rawget(tbl, key) == fn then return end
    -- ถ้า table frozen: ลอง assign ปกติ
    local ok2 = pcall(function() tbl[key] = fn end)
    if ok2 and tbl[key] == fn then return end
    -- [STEALTH] ลบ getrawmetatable ออก — executor API ที่เกมบางตัวสแกน globals หา
    -- last resort: debug.setupvalue เท่านั้น (ไม่แตะ metatable โดยตรง)
    pcall(function()
        if type(debug) == "table" and type(debug.setupvalue) == "function" then
            -- ลองหา upvalue ชื่อเดียวกับ key ใน functions ที่ถือ tbl
            for i = 1, 20 do
                local name, val = debug.getupvalue(fn, i)
                if not name then break end
            end
        end
    end)
end

-- เส้นทาง hook แบบเรียบง่าย (เหมือนเวอร์ชันเก่าที่โดนหัวชัวร์):
-- GetPoses สดทุกนัด, ไม่มี cache/lock/lead/canFire ที่อาจทำให้พลาดหรือถูกบล็อก
local function simplePick(origin)
    local okP, poses = pcall(function() return ShotClient:GetPoses() end)
    if not okP or type(poses) ~= "table" then return nil end
    Camera = Workspace.CurrentCamera
    local camPos, look = Camera.CFrame.Position, Camera.CFrame.LookVector
    local localModel = getLocalModel()
    local best, bestPoint, bestScore

    -- Peek prefire: aim at predicted emerge point (line of sight already clear)
    local pf = prefire
    if pf and os.clock() - pf.t < 0.25 and pf.model.Parent and isAlive(pf.model) then
        for _, pose in ipairs(poses) do
            if pose.Model == pf.model then
                local hp = partPosition(pose, "Head")
                local vel = (typeof(pose.Vel) == "Vector3") and Vector3.new(pose.Vel.X, 0, pose.Vel.Z) or Vector3.zero
                local pred = hp + vel * (S.PrefireMs / 1000)
                if isVisible(camPos, pred, pf.model) then
                    return pose, pred
                end
            end
        end
    end
    for _, pose in ipairs(poses) do
        local model = pose.Model
        if model and model ~= localModel and model.Parent and isEnemy(model) and isAlive(model) then
            local which = S.HitPart
            if which == "Random" then
                which = (rng:NextNumber(0, 100) < S.HeadBias) and "Head" or "Torso"
            elseif which == "Nearest" then
                which = "Head"
            end
            local point = partPosition(pose, which)
            local dist = (point - camPos).Magnitude
            if dist <= S.MaxDistance then
                local ang = angleBetween(look, (point - camPos).Unit)
                if ang <= S.FovDeg and isVisible(camPos, point, model) then
                    local score
                    if S.Priority == "Distance" then score = dist
                    elseif S.Priority == "Health" then score = modelHealth(model) or 100
                    else score = ang end
                    if not bestScore or score < bestScore then
                        best, bestPoint, bestScore = pose, point, score
                    end
                end
            end
        end
    end
    return best, bestPoint
end

local function computeAim(origin)
    if typeof(origin) ~= "Vector3" then return nil end
    if not S.SilentAim then return nil end

    -- [STEALTH] Accuracy Cap — ถ้า accuracy เกิน cap ให้ inject miss อัตโนมัติ
    if S.AccuracyCapEnabled and Stats.ShotsFired > 10 and Stats.Accuracy > S.AccuracyCap then
        return nil
    end

    -- [STEALTH] Session decay — เล่นนาน accuracy drop ตามธรรมชาติ
    local sessionMin = (os.clock() - sessionStart) / 60
    local effectiveChance = S.HitChance
    if sessionMin > 20 then
        -- เล่นเกิน 20 นาที: ลด hit chance ลง 5-15% เพื่อแสดง fatigue
        local decay = math.min(15, (sessionMin - 20) * 0.5)
        effectiveChance = effectiveChance - decay
    end
    if rng:NextNumber(0, 100) > effectiveChance then return nil end

    local pose, point = simplePick(origin)
    if not pose then return nil end

    Stats.LastTargetName = pose.Model.Name:gsub("__Bot$", "")

    if S.Humanize and S.HumanizeAmount > 0 then
        local a = S.HumanizeAmount * math.clamp((point - origin).Magnitude / 60, 0.04, 1)
        point = point + Vector3.new(rng:NextNumber(-a, a), rng:NextNumber(-a * 0.4, a * 0.4), rng:NextNumber(-a, a))
    end

    lastAimTargetPoint = point

    local v = point - origin
    if v.Magnitude < 1 then return nil end
    local dir = v.Unit
    if dir:Dot(Camera.CFrame.LookVector) < 0.5 then return nil end
    return dir
end


-- MCP-verified AimDirection signature (from ShotClient decompile line 86):
--   function u76.AimDirection(a1, a2, a3, a4, a5, a6)
--   a1=self, a2=origin(Vector3), a3=maxDist, a4=traceParams, a5=poses(table), a6=ignoreSet
-- Game calls: ShotClient:AimDirection(u26, WSettings.MaxDist, u71, Poses, ShotClient:Ignore())
-- Original does: Hitboxes.Raycast(CFrame.Position, CFrame.LookVector * maxDist, poses, ignoreSet)
-- Our hook: intercept a2(origin), redirect to silent target by injecting into the poses list
hookSet(ShotClient, "AimDirection", function(a1, a2, a3, a4, a5, a6)
    -- a1 may be self(table) or origin(Vector3) depending on call style
    local selfArg, origin, maxDist, traceParams, poses, ignoreSet
    if typeof(a1) == "Vector3" then
        -- dot-call (legacy): AimDirection(origin, ...)
        selfArg, origin, maxDist, traceParams, poses, ignoreSet = ShotClient, a1, a2, a3, a4, a5
    else
        -- colon-call (normal game path): AimDirection(self, origin, maxDist, params, poses, ignore)
        selfArg, origin, maxDist, traceParams, poses, ignoreSet = a1, a2, a3, a4, a5, a6
    end
    if typeof(origin) == "Vector3" then
        local ok, dir = pcall(computeAim, origin)
        if ok and dir then return dir end
    end
    return origAim(selfArg, origin, maxDist, traceParams, poses, ignoreSet)
end)

-- นับกระสุนที่ยิงออกไป
if type(origPrepare) == "function" then
    hookSet(ShotClient, "Prepare", function(...)
        Stats.ShotsFired = Stats.ShotsFired + 1
        Stats.LastFireClock = os.clock()
        Stats.Accuracy = math.floor((Stats.HitsConfirmed / Stats.ShotsFired) * 1000) / 10
        return origPrepare(...)
    end)
end

-- [Hook Watchdog] ตรวจสอบ hook ทุก 8-12s (jitter) ถ้าเกมรีเซ็ต function ให้ rehook
-- เกมบางตัว periodically verify module integrity แล้ว restore original → hook หลุด
local _hookWatchdogNext = os.clock() + 8 + rng:NextNumber(0, 4)
task.spawn(function()
    while not unloaded do
        task.wait(1)
        if os.clock() >= _hookWatchdogNext and not unloaded then
            _hookWatchdogNext = os.clock() + 8 + rng:NextNumber(0, 4)
            -- ตรวจว่า AimDirection hook ยังอยู่ไหม
            if S.SilentAim then
                local cur = rawget(ShotClient, "AimDirection")
                if cur == origAim then
                    -- hook หลุด rehook
                    pcall(hookSet, ShotClient, "AimDirection", function(a1, a2, a3, a4, a5, a6)
                        local selfArg, origin
                        if typeof(a1) == "Vector3" then
                            selfArg, origin = ShotClient, a1
                        else
                            selfArg, origin = a1, a2
                        end
                        if typeof(origin) == "Vector3" then
                            local ok, dir = pcall(computeAim, origin)
                            if ok and dir then return dir end
                        end
                        return origAim(selfArg, origin, a3, a4, a5, a6)
                    end)
                end
            end
        end
    end
end)

-- Hook Hitmarker ของเกมเพื่อนับ Hits
local origHitmarker = nil
if okAH and ActionHandler and type(ActionHandler.Hitmarker) == "function" then
    origHitmarker = ActionHandler.Hitmarker
    hookSet(ActionHandler, "Hitmarker", function(...)
        Stats.HitsConfirmed = Stats.HitsConfirmed + 1
        if Stats.ShotsFired > 0 then
            Stats.Accuracy = math.floor((Stats.HitsConfirmed / Stats.ShotsFired) * 1000) / 10
        end
        return origHitmarker(...)
    end)
end

-- -----------------------------------------------------------------------------
-- 8. Visuals (Chams & ESP Pool)
-- -----------------------------------------------------------------------------
local function makeHighlight(model)
    local ok, hl = pcall(function()
        local h = Instance.new("Highlight")
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.FillTransparency = S.ChamsFill
        h.OutlineTransparency = 0
        h.Adornee = model
        h.Enabled = false
        -- [STEALTH] gethui ผ่าน pcall — ไม่เรียกโดยตรง
        local _hui = nil
        if type(gethui) == "function" then
            local ok, h2 = pcall(gethui)
            if ok then _hui = h2 end
        end
        h.Parent = _hui or game:GetService("CoreGui")
        return h
    end)
    if ok and hl then
        highlights[#highlights + 1] = hl
        return hl
    end
    return nil
end

local function getEsp(model)
    local e = espPool[model]
    if e then return e end
    e = {
        box = newDraw("Square", { Thickness = 1, Filled = false, Visible = false }),
        name = newDraw("Text", { Size = 13, Center = true, Outline = true, Visible = false }),
        hp = newDraw("Line", { Thickness = 2, Visible = false }),
        tracer = newDraw("Line", { Thickness = 1, Visible = false }),
        hl = makeHighlight(model),
    }
    espPool[model] = e
    return e
end

local function hideEsp(e)
    for k, d in pairs(e) do
        if d then
            if k == "hl" then d.Enabled = false else d.Visible = false end
        end
    end
end

local function hideDrawn(e)
    for k, d in pairs(e) do
        if d and k ~= "hl" then d.Visible = false end
    end
end

-- -----------------------------------------------------------------------------
-- 9. Render Loop: Camera Aimbot, ESP, Simulation & HUD
-- -----------------------------------------------------------------------------
local function fovRadiusPx()
    local vp = Camera.ViewportSize
    local half = math.rad(Camera.FieldOfView) / 2
    return math.tan(math.rad(S.FovDeg)) / math.tan(half) * (vp.Y / 2)
end

local lastRenderClock = os.clock()

-- [Per-Frame Target Cache] — getActiveTarget เรียกครั้งเดียวต่อ frame, share ระหว่าง render+aim
local _cachedActivePose, _cachedActivePoint, _cachedActiveFrame = nil, nil, -1
local function getActiveTargetCached(origin)
    if _cachedActiveFrame == _frameCounter then
        return _cachedActivePose, _cachedActivePoint
    end
    _cachedActivePose, _cachedActivePoint = getActiveTarget(origin)
    _cachedActiveFrame = _frameCounter
    return _cachedActivePose, _cachedActivePoint
end

-- [Cache Cleanup] — ล้าง stale entries ใน _aliveCache/_enemyCache ทุก 10s ป้องกัน memory leak
local _lastCacheClean = os.clock()
local function cleanStaleCaches()
    local now = os.clock()
    if now - _lastCacheClean < 10 then return end
    _lastCacheClean = now
    for model in pairs(_aliveCache) do
        if not model.Parent then
            _aliveCache[model] = nil
            _aliveCacheTime[model] = nil
        end
    end
    for model in pairs(_enemyCache) do
        if not model.Parent then
            _enemyCache[model] = nil
            _enemyCacheTime[model] = nil
        end
    end
end

-- [Per-Frame canFire Cache] — canFire() เรียก 3+ ครั้งต่อ frame, cache ลด pcall overhead
local _canFireCache, _canFireFrame = false, -1
local function canFireThisFrame()
    if _canFireFrame == _frameCounter then return _canFireCache end
    _canFireCache = canFire()
    _canFireFrame = _frameCounter
    return _canFireCache
end

local function renderStep()
    if unloaded then return end
    local now = os.clock()
    local dt = math.clamp(now - lastRenderClock, 0.001, 0.1)
    lastRenderClock = now
    _frameCounter = _frameCounter + 1

    Camera = Workspace.CurrentCamera
    local vp = Camera.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)

    -- [FOV Circle]
    if fovCircle then
        fovCircle.Visible = S.ShowFov and (S.SilentAim or S.CamAimbot)
        fovCircle.Position = center
        fovCircle.Radius = fovRadiusPx()
    end

    -- [Custom Crosshair]
    if S.CustomCrosshair and hasDrawing then
        local gap, sz, col = S.CrosshairGap, S.CrosshairSize, S.CrosshairColor
        chLines.top.Visible = true
        chLines.top.From = Vector2.new(center.X, center.Y - gap)
        chLines.top.To = Vector2.new(center.X, center.Y - gap - sz)
        chLines.top.Color = col

        chLines.bottom.Visible = true
        chLines.bottom.From = Vector2.new(center.X, center.Y + gap)
        chLines.bottom.To = Vector2.new(center.X, center.Y + gap + sz)
        chLines.bottom.Color = col

        chLines.left.Visible = true
        chLines.left.From = Vector2.new(center.X - gap, center.Y)
        chLines.left.To = Vector2.new(center.X - gap - sz, center.Y)
        chLines.left.Color = col

        chLines.right.Visible = true
        chLines.right.From = Vector2.new(center.X + gap, center.Y)
        chLines.right.To = Vector2.new(center.X + gap + sz, center.Y)
        chLines.right.Color = col

        chLines.dot.Visible = true
        chLines.dot.Position = center
        chLines.dot.Color = col
    else
        for _, l in pairs(chLines) do if l then l.Visible = false end end
    end

    -- [Weapon State Update]
    local curWep = getCurrentWeapon()
    if curWep then
        Stats.CurrentWeaponName = curWep.Name
        Stats.CurrentWeaponType = curWep.IsProjectile
            and ("Proj (" .. curWep.Speed .. "u/s)")
            or ("Hitscan (" .. string.format("%.0f", 1 / math.max(0.01, curWep.Debounce)) .. "rps)")
    else
        Stats.CurrentWeaponName = "None"
        Stats.CurrentWeaponType = "N/A"
    end

    -- [Cache Cleanup tick]
    cleanStaleCaches()

    -- [Target Acquisition Check & TTK Clock] — ใช้ cached version
    local camPos3D = Camera.CFrame.Position
    local activePose, activeTargetPoint = getActiveTargetCached(camPos3D)
    if activePose then
        if Stats.FirstSeenClock == 0 then
            Stats.FirstSeenClock = now
        end
        Stats.TargetAcquisitionTime = math.floor((now - Stats.FirstSeenClock) * 1000)
    else
        Stats.FirstSeenClock = 0
    end

    -- [Target Death Check] ถ้าเป้าตายแล้ว ให้ล้าง lock ทันที
    if lockedTargetModel and not isAlive(lockedTargetModel) then
        lockedTargetModel = nil
        activePose = nil
        activeTargetPoint = nil
    end

    -- [Target Marker]
    if targetMarker then
        if S.TargetMarker and activePose and activePose.Model then
            local headPos = partPosition(activePose, "Head") + Vector3.new(0, 1.2, 0)
            local sp, onScreen = Camera:WorldToViewportPoint(headPos)
            if onScreen and sp.Z > 0 then
                targetMarker.Visible = true
                targetMarker.Position = Vector2.new(sp.X, sp.Y)
                targetMarker.Text = string.format("[ ▼ TARGET: %s ▼ ]", activePose.Model.Name:gsub("__Bot$", ""))
            else
                targetMarker.Visible = false
            end
        else
            targetMarker.Visible = false
        end
    end

    -- [Silent Aim Simulation Ray — throttle ทุก 2 frames, visual ไม่ต้อง 60fps]
    if simLine and simImpact then
        if S.SimulateRay and activeTargetPoint and S.SilentAim then
            if _frameCounter % 2 == 0 then
                local origin = Camera.CFrame.Position - Vector3.new(0, 0.4, 0)
                local spFrom = Camera:WorldToViewportPoint(origin + Camera.CFrame.LookVector * 1.5)
                local spTo, on2 = Camera:WorldToViewportPoint(activeTargetPoint)
                if on2 and spTo.Z > 0 then
                    simLine.Visible = true
                    simLine.From = Vector2.new(spFrom.X, spFrom.Y)
                    simLine.To = Vector2.new(spTo.X, spTo.Y)
                    simImpact.Visible = true
                    simImpact.Position = Vector2.new(spTo.X, spTo.Y)
                else
                    simLine.Visible = false
                    simImpact.Visible = false
                end
            end
        else
            simLine.Visible = false
            simImpact.Visible = false
        end
    end

    -- [ESP & Chams Loop] — throttle ทุก 3 frames (~20fps) ลด CPU
    local seen = {}
    local _espUpdate = (S.Esp or S.Chams) and (_frameCounter % 3 == 0)
    if _espUpdate then
        local poses = getCachedPoses()
        if #poses > 0 then
            local lm = getLocalModel()
            local camPos = Camera.CFrame.Position
            for _, pose in ipairs(poses) do
                local model = pose.Model
                if model and model ~= lm and model.Parent and isEnemy(model) and isAlive(model) then
                    seen[model] = true
                    local e = getEsp(model)

                    if e.hl then
                        e.hl.Adornee = model
                        e.hl.Enabled = S.Chams
                        e.hl.FillColor = S.EspColor
                        e.hl.OutlineColor = S.EspColor
                        e.hl.FillTransparency = S.ChamsFill
                    end

                    local drew = false
                    if S.Esp and hasDrawing then
                        local head = model:FindFirstChild("Head")
                        local topWorld = (head and head:IsA("BasePart") and head.Position or pose.Pos) + Vector3.new(0, 0.9, 0)
                        local botWorld = pose.Pos - Vector3.new(0, 3, 0)
                        local top, onTop = Camera:WorldToViewportPoint(topWorld)
                        local bot, onBot = Camera:WorldToViewportPoint(botWorld)
                        if (onTop or onBot) and top.Z > 0 and bot.Z > 0 then
                            drew = true
                            local h = math.max(8, math.abs(bot.Y - top.Y))
                            local w = h * 0.55
                            local cx = (top.X + bot.X) / 2
                            local x, y = cx - w / 2, math.min(top.Y, bot.Y)

                            if e.box then
                                e.box.Visible = S.EspBox
                                e.box.Position = Vector2.new(x, y)
                                e.box.Size = Vector2.new(w, h)
                                e.box.Color = S.EspColor
                            end
                            if e.name then
                                local label = ""
                                if S.EspName then label = (model.Name:gsub("__Bot$", "")) end
                                if S.EspDist then
                                    label = label .. " [" .. math.floor((pose.Pos - camPos).Magnitude) .. "m]"
                                end
                                e.name.Visible = label ~= ""
                                e.name.Text = label
                                e.name.Position = Vector2.new(cx, y - 15)
                                e.name.Color = Color3.fromRGB(255, 255, 255)
                            end
                            if e.hp then
                                local hpv = modelHealth(model)
                                if S.EspHealth and hpv then
                                    local frac = math.clamp(hpv / 100, 0, 1)
                                    e.hp.Visible = true
                                    e.hp.From = Vector2.new(x - 4, y + h)
                                    e.hp.To = Vector2.new(x - 4, y + h - h * frac)
                                    e.hp.Color = Color3.fromRGB(math.floor(255 * (1 - frac)), math.floor(255 * frac), 60)
                                else
                                    e.hp.Visible = false
                                end
                            end
                            if e.tracer then
                                e.tracer.Visible = S.EspTracer
                                e.tracer.From = Vector2.new(vp.X / 2, vp.Y)
                                e.tracer.To = Vector2.new(cx, y + h)
                                e.tracer.Color = S.EspColor
                            end
                        end
                    end
                    if not drew then hideDrawn(e) end
                end
            end
        end
    end
    if _frameCounter % 3 == 0 then
        for model, e in pairs(espPool) do
            if not seen[model] then
                hideEsp(e)
                if not model.Parent then
                    if e.hl then pcall(function() e.hl:Destroy() end) end
                    if e.box then pcall(function() e.box:Remove() end) end
                    if e.name then pcall(function() e.name:Remove() end) end
                    if e.hp then pcall(function() e.hp:Remove() end) end
                    if e.tracer then pcall(function() e.tracer:Remove() end) end
                    espPool[model] = nil
                end
            end
        end
    end

    -- [Status HUD Display — string.format throttle ทุก 6 frames ลด CPU]
    if hudText and hudBg then
        if S.StatusHud then
            hudBg.Visible = true
            hudBg.Position = Vector2.new(20, 20)
            hudBg.Size = Vector2.new(310, 52)
            hudText.Visible = true
            hudText.Position = Vector2.new(25, 24)
            if _frameCounter % 6 == 0 then  -- ~10fps พอสำหรับ HUD text
                -- [STEALTH] ไม่ใส่ชื่อ engine ใน HUD — mod screenshot = evidence
                local ammoText = curWep and string.format("%d/%d", curWep.Ammo, curWep.FillAmmo) or "0/0"
                local aimState = "OFF"
                if S.CamAimbot then
                    -- คำนวณ shouldAim ใหม่แทนที่จะใช้ upvalue จาก cameraAimStep
                    local _shouldAim = S.AimMode == "Always"
                        or (S.AimMode == "Hold" and isAimingHeld)
                        or (S.AimMode == "Toggle" and aimbotToggled)
                    aimState = _shouldAim and "LOCK" or "RDY"
                end
                hudText.Text = string.format(
                    " A:%s S:%s T:%s | %s %s\n Ammo:%s Tgt:%s TTK:%dms Acc:%.1f%%",
                    aimState,
                    S.SilentAim and "Y" or "N",
                    S.Trigger and "Y" or "N",
                    Stats.CurrentWeaponName,
                    Stats.CurrentWeaponType,
                    ammoText,
                    Stats.LastTargetName,
                    Stats.TargetAcquisitionTime,
                    Stats.Accuracy
                )
            end
        else
            hudBg.Visible = false
            hudText.Visible = false
        end
    end
end

connections[#connections + 1] = RunService.RenderStepped:Connect(function()
    pcall(renderStep)
end)

-- [Dedicated Camera Aimbot Step]
-- รันที่ RenderPriority.Camera.Value + 1 (ทันทีหลังระบบกล้อง Roblox คำนวณเสร็จ)
-- ทำให้ไม่ต้องเปลี่ยน CameraType เป็น Scriptable -> ไม่สู้กับนิ้วสัมผัสบนมือถือ ไม่สั่น ไม่กระตุก
local function cameraAimStep(dt)
    if unloaded then return end
    if not (S.CamAimbot or (S.Trigger and S.TriggerLock)) then return end

    local shouldAim = (S.CamAimbot and (
        S.AimMode == "Always"
        or (S.AimMode == "Hold" and isAimingHeld)
        or (S.AimMode == "Toggle" and aimbotToggled)
    )) or (S.Trigger and S.TriggerLock)

    if not shouldAim then return end

    Camera = Workspace.CurrentCamera
    local camPos = Camera.CFrame.Position
    local activePose, activeTargetPoint = getActiveTargetCached(camPos)

    if not activePose or not activeTargetPoint then
        return
    end

    local currentLook = Camera.CFrame.LookVector
    local desiredDir = (activeTargetPoint - camPos).Unit
    local angleDelta = angleBetween(currentLook, desiredDir)

    -- [DEADZONE] ถ้าความคลาดเคลื่อนน้อยกว่า 0.2°
    if angleDelta < 0.2 then
        -- [STEALTH] Idle micro-drift
        if rng:NextNumber(0, 1) < 0.15 then
            local drift = 0.00015
            local driftLook = (currentLook + Vector3.new(
                rng:NextNumber(-drift, drift),
                rng:NextNumber(-drift * 0.6, drift * 0.6),
                0
            )).Unit
            Camera.CFrame = CFrame.lookAt(camPos, camPos + driftLook, Vector3.new(0, 1, 0))
        end
        return
    end

    -- [STEALTH] Camera Accuracy Cap — inject miss โดยไม่ aim บาง frame
    -- ทำให้ accuracy ตวรไม่เกิน cap แม้ใช้ camera aimbot
    if S.AccuracyCapEnabled and Stats.ShotsFired > 8 and Stats.Accuracy > S.AccuracyCap then
        return  -- ไม่ขยับกล้อง frame นี้ = miss
    end

    -- [STEALTH] Session decay สำหรับ cam aimbot ด้วย
    -- เล่นเกิน 20 นาที บาง frame จะพลาด aim เพื่อแสดง fatigue
    local sessionMin = (os.clock() - sessionStart) / 60
    if sessionMin > 20 then
        local missChance = math.min(0.18, (sessionMin - 20) * 0.007)
        if rng:NextNumber(0, 1) < missChance then return end
    end

    local clampedDt = math.clamp(dt or 0.016, 0.001, 0.1)

    -- Framerate-independent exponential smoothing
    local baseSmooth = math.max(1, S.Smoothing)
    local k = 22 / baseSmooth
    local smoothAlpha = math.clamp(1 - math.exp(-k * clampedDt), 0.05, 0.95)

    -- Speed limiter (deg/s)
    local maxAngleThisFrame = math.max(0.1, S.MaxTurnSpeed * clampedDt)
    local stepAngle = math.min(angleDelta * smoothAlpha, maxAngleThisFrame)

    local newLook = currentLook:Lerp(desiredDir, stepAngle / math.max(angleDelta, 0.0001)).Unit

    -- [STEALTH] micro-noise: ทำให้ pattern กล้องไม่ perfect — human มือสั่นเล็กน้อย
    -- noise จะ scale ลงตาม smoothAlpha (ยิ่ง smooth น้อย noise น้อย)
    local noiseScale = math.clamp(angleDelta * 0.004, 0, 0.003)
    local noiseX = rng:NextNumber(-noiseScale, noiseScale)
    local noiseY = rng:NextNumber(-noiseScale * 0.5, noiseScale * 0.5)
    local noisedLook = (newLook + Vector3.new(noiseX, noiseY, 0)).Unit

    Camera.CFrame = CFrame.lookAt(camPos, camPos + noisedLook, Vector3.new(0, 1, 0))
end

pcall(function()
    RunService:BindToRenderStep("__HS_CameraAim", Enum.RenderPriority.Camera.Value + 1, function(dt)
        pcall(cameraAimStep, dt)
    end)
end)

-- -----------------------------------------------------------------------------
-- 10. High-Speed Lead Triggerbot
-- -----------------------------------------------------------------------------
local function leadPosesForTrigger()
    local okP, poses = pcall(function() return ShotClient:GetPoses() end)
    if not okP or type(poses) ~= "table" then return {} end
    local lead = leadSeconds()
    if lead <= 0 then return poses end
    local out = table.create(#poses)
    for i, pose in ipairs(poses) do
        local c = table.clone(pose)
        if typeof(pose.Vel) == "Vector3" and typeof(pose.Pos) == "Vector3" then
            c.Pos = pose.Pos + Vector3.new(pose.Vel.X, 0, pose.Vel.Z) * lead
        end
        out[i] = c
    end
    return out
end

local function crosshairOnEnemy()
    Camera = Workspace.CurrentCamera
    local cf = Camera.CFrame
    local origin, vec = cf.Position, cf.LookVector * S.MaxDistance
    local lm = getLocalModel()

    if Hitboxes and type(Hitboxes.RaycastEntities) == "function" then
        local ignore = {}
        if lm then ignore[lm] = true end
        local ok, res = pcall(function()
            return Hitboxes.RaycastEntities(origin, vec, leadPosesForTrigger(), 0, ignore)
        end)
        if ok and type(res) == "table" then
            local hit = res[1]
            if hit and hit.Model and isEnemy(hit.Model) and isAlive(hit.Model) then
                if S.WallCheck then
                    wallParams.FilterDescendantsInstances = worldIgnoreList(nil)
                    local w = Workspace:Raycast(origin, vec, wallParams)
                    if w and hit.Distance and w.Distance < hit.Distance - 0.5 then return false end
                end
                return true
            end
            return false
        end
    end

    local pose, point = pickTarget(origin)
    if pose then
        return angleBetween(cf.LookVector, (point - origin).Unit) <= 2
    end
    return false
end

local triggerHeld = false
local lastClickTime = 0

-- [STEALTH] VirtualInputManager path: ผ่าน game input pipeline ปกติ
-- mouse1press/mouse1release เป็น executor API ที่เกมบางตัวตรวจได้ผ่าน hook บน UIS
-- VIM ส่ง input ผ่าน Roblox internal pipeline เหมือน hardware input จริง
local VIM = game:GetService("VirtualInputManager")
local useVIM = pcall(function()
    -- test ว่า VIM พร้อมใช้ (บาง executor ไม่ support)
    local _ = VIM.SendMouseButtonEvent
end)

-- [STEALTH] ไม่อ้างชื่อ executor fn โดยตรง — ดึงผ่าน rawget ป้องกัน bytecode string-scan
local _m1p = rawget(_ENV or _G, string.char(109,111,117,115,101,49,112,114,101,115,115))   -- "mouse1press"
local _m1r = rawget(_ENV or _G, string.char(109,111,117,115,101,49,114,101,108,101,97,115,101)) -- "mouse1release"

local function _rawPress()
    if useVIM then
        local vp = game:GetService("Workspace").CurrentCamera.ViewportSize
        pcall(function()
            VIM:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, true, game, 0)
        end)
    elseif type(_m1p) == "function" then
        pcall(_m1p)
    end
end

local function _rawRelease()
    if useVIM then
        local vp = game:GetService("Workspace").CurrentCamera.ViewportSize
        pcall(function()
            VIM:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, false, game, 0)
        end)
    elseif type(_m1r) == "function" then
        pcall(_m1r)
    end
end

local function trigRelease()
    if triggerHeld then
        triggerHeld = false
        _rawRelease()
    end
end

local function trigFire()
    if S.TriggerHold then
        if not triggerHeld then
            triggerHeld = true
            _rawPress()
        end
    else
        local now = os.clock()
        if now - lastClickTime >= S.TriggerRate / 1000 then
            lastClickTime = now
            -- human-like pre-click micro-jitter (0-18ms)
            local preJitter = rng:NextNumber(0, 0.018)
            task.delay(preJitter, function()
                if unloaded then return end
                _rawPress()
                -- human hold: 65-180ms
                local holdMs = 0.065 + rng:NextNumber(0, 0.115)
                task.delay(holdMs, function()
                    if not unloaded then _rawRelease() end
                end)
            end)
        end
    end
end

local pendingTrigger = false

-- Peek prefire: ศัตรูยังถูกกำแพงบังอยู่ แต่ใน PrefireMs ข้างหน้าจะโผล่ (เส้นสายตาโล่ง) และอยู่ในวง FOV
local function peekPrefire()
    if not S.TriggerPrefire or not S.WallCheck then return false end
    local okP, poses = pcall(function() return ShotClient:GetPoses() end)
    if not okP or type(poses) ~= "table" then return false end
    Camera = Workspace.CurrentCamera
    local camPos, look = Camera.CFrame.Position, Camera.CFrame.LookVector
    local lm = getLocalModel()
    local la = S.PrefireMs / 1000
    for _, pose in ipairs(poses) do
        local model = pose.Model
        if model and model ~= lm and model.Parent and isEnemy(model) and isAlive(model) then
            local hp = partPosition(pose, "Head")
            local d = (hp - camPos).Magnitude
            if d <= S.MaxDistance and typeof(pose.Vel) == "Vector3" then
                local hv = Vector3.new(pose.Vel.X, 0, pose.Vel.Z)
                if hv.Magnitude > 2 and angleBetween(look, (hp - camPos).Unit) <= S.FovDeg
                    and not isVisible(camPos, hp, model) then
                    local pred = hp + hv * la
                    if isVisible(camPos, pred, model)
                        and angleBetween(look, (pred - camPos).Unit) <= S.FovDeg then
                        prefire = { model = model, t = os.clock() }
                        return true
                    end
                end
            end
        end
    end
    return false
end
-- Heartbeat แทน RenderStepped: แยกจาก render thread, ไม่แย่ง frame budget
connections[#connections + 1] = RunService.Heartbeat:Connect(function()
    if unloaded then return end
    if not S.Trigger then trigRelease() return end
    -- [STEALTH] ตรวจ input availability โดยไม่เสิยบอ้างชื่อ executor fn
    local _canInput = useVIM or (type(rawget(_ENV or _G, "mouse1press")) == "function")
    if not _canInput then return end
    if UserInputService:GetFocusedTextBox() then trigRelease() return end

    local ok, onTarget = pcall(crosshairOnEnemy)
    if ok and onTarget then
        prefire = nil
    elseif S.TriggerPrefire then
        local okp, pk = pcall(peekPrefire)
        onTarget = okp and pk
        ok = true
    end
    if not ok or not onTarget then
        prefire = nil
        trigRelease()
        return
    end

    local delayMs = (S.TriggerDelayMax > 0) and rng:NextNumber(S.TriggerDelayMin, S.TriggerDelayMax) or 0
    if delayMs <= 0.5 then
        trigFire()
    elseif not pendingTrigger then
        pendingTrigger = true
        task.delay(delayMs / 1000, function()
            pendingTrigger = false
            if not unloaded and S.Trigger then trigFire() end
        end)
    end
end)

-- -----------------------------------------------------------------------------
-- 11. Input Handling (Keybinds, Hold/Toggle & Panic Key)
-- -----------------------------------------------------------------------------
local function isKeyMatch(input, bind)
    if not bind then return false end
    if typeof(bind) == "EnumItem" then
        if bind.EnumType == Enum.KeyCode then
            return input.KeyCode == bind
        elseif bind.EnumType == Enum.UserInputType then
            return input.UserInputType == bind
        end
    end
    return false
end

connections[#connections + 1] = UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if isKeyMatch(input, S.PanicKey) then
        -- [STEALTH] ไม่เรียก getgenv ตรงๆ — ใช้ Unload fn ที่เก็บไว้ใน local closure แทน
        pcall(Unload)
        return
    end
    if isKeyMatch(input, S.AimKey) then
        if S.AimMode == "Hold" then
            isAimingHeld = true
        elseif S.AimMode == "Toggle" then
            aimbotToggled = not aimbotToggled
            if not aimbotToggled then
                lockedTargetModel = nil
            end
        end
    end
end)

connections[#connections + 1] = UserInputService.InputEnded:Connect(function(input, gp)
    if isKeyMatch(input, S.AimKey) then
        if S.AimMode == "Hold" then
            isAimingHeld = false
            lockedTargetModel = nil
        end
    end
end)

-- -----------------------------------------------------------------------------
-- 12. Cleanup & Unload Engine (Kill switch)
-- -----------------------------------------------------------------------------
local Library = nil

Unload = function()
    if unloaded then return end
    unloaded = true
    trigRelease()
    lockedTargetModel = nil
    isAimingHeld = false
    aimbotToggled = false
    pcall(function() RunService:UnbindFromRenderStep("__HS_CameraAim") end)
    -- restore camera เมื่อ unload
    pcall(function()
        if Camera.CameraType == Enum.CameraType.Scriptable then
            Camera.CameraType = Enum.CameraType.Custom
        end
    end)

    -- restore ด้วย hookSet (rawset แล้ว fallback เป็น assign ปกติ)
    if type(origAim) == "function" then pcall(hookSet, ShotClient, "AimDirection", origAim) end
    if type(origPrepare) == "function" then pcall(hookSet, ShotClient, "Prepare", origPrepare) end
    if origHitmarker and ActionHandler then
        pcall(hookSet, ActionHandler, "Hitmarker", origHitmarker)
    end

    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    for _, d in ipairs(drawings) do pcall(function() d:Remove() end) end
    for _, h in ipairs(highlights) do pcall(function() h:Destroy() end) end
    table.clear(espPool)

    if Library and Library.Exit then pcall(Library.Exit, Library) end
    -- [STEALTH] ล้าง genv entry ด้วย pcall
    pcall(function()
        if _genv then rawset(_genv, "__HS_UNLOAD", nil) end
    end)
end
-- เก็บ Unload ใน genv สำหรับ unload จาก re-execute
pcall(function()
    if _genv then rawset(_genv, "__HS_UNLOAD", Unload) end
end)

-- -----------------------------------------------------------------------------
-- 13. UI Implementation (Nexonix UI Library)
-- -----------------------------------------------------------------------------
-- [STEALTH] ซ่อน URL — ตัด URL string เป็นส่วนๆ เพื่อไม่ให้เกม pattern-match URL ตรงๆ
local _p1 = "https://raw.githubuser"
local _p2 = "content.com/sametexe001/"
local _p3 = "sametlibs/refs/heads/main/nexonix/Library.lua"
local _url = _p1:gsub("githubuser","github") .. _p2:sub(1,0) .. _p2 .. _p3
local okLib, lib = pcall(function()
    local src = game:HttpGet(_url)
    -- [STEALTH] ไม่ใช้ชื่อ "loadstring" ตรงๆ — ดึงผ่าน rawget ป้องกัน string scan
    local _ls = rawget(_ENV or _G, string.char(108,111,97,100,115,116,114,105,110,103)) or load
    return _ls(src)()
end)
if not okLib or not lib then
    return
end
Library = lib

-- Patch Nexonix Round bug:
-- In original Nexonix: Multiplier = 1 / (Float or 1).
-- When Decimals = 0, Float is 0. In Luau, 0 is truthy! So 1/0 = inf -> inf/inf = NaN!
-- When Decimals = 2, Float is 2 -> Multiplier = 0.5 (rounds to multiples of 2 instead of 0.01).
Library.Round = function(self, Number, Float)
    if not Float or Float <= 0 then
        return math.floor(Number + 0.5)
    end
    local step = (Float >= 1) and (10 ^ (-Float)) or Float
    local Multiplier = 1 / step
    return math.floor((Number * Multiplier) + 0.5) / Multiplier
end

local function numOr(val, fallback)
    if typeof(val) == "number" and val == val then
        return val
    end
    return fallback
end

-- Nexonix keybind callback ส่งแค่ Toggled(bool) -> อ่านปุ่มจริงจาก Library.Flags[flag].Key ("Enum.KeyCode.X" หรือ "Enum.UserInputType.X")
local function keyFromFlag(flag)
    local f = Library.Flags and Library.Flags[flag]
    local s = type(f) == "table" and f.Key
    if type(s) ~= "string" then return nil end
    local kc = s:match("Enum%.KeyCode%.(%w+)")
    if kc and Enum.KeyCode[kc] then return Enum.KeyCode[kc] end
    local ui = s:match("Enum%.UserInputType%.(%w+)")
    if ui and Enum.UserInputType[ui] then return Enum.UserInputType[ui] end
    return nil
end

local function notify(text)
    pcall(function() Library:Notification(text, 3, Color3.fromRGB(0, 255, 220)) end)
end

local function setFlag(flag, value)
    local f = Library.SetFlags and Library.SetFlags[flag]
    if f then pcall(f, value) end
end

local Window = Library:Window({})

local TabCombat = Window:Page({ Name = "Combat" })
local TabPred   = Window:Page({ Name = "Prediction" })
local TabTrig   = Window:Page({ Name = "Triggerbot" })
local TabVis    = Window:Page({ Name = "Visuals" })
local TabPres   = Window:Page({ Name = "Presets" })

-- ===== TAB: COMBAT =====
local SecSilent = TabCombat:Section({ Name = "Silent Aim", Side = 1 })
local SecTarget = TabCombat:Section({ Name = "Target Selection", Side = 1 })
local SecAimbot = TabCombat:Section({ Name = "Camera Aimbot", Side = 2 })
local SecSim    = TabCombat:Section({ Name = "Aim Simulation", Side = 2 })

SecSilent:Toggle({ Name = "Silent Aim", Flag = "sa_enabled", Default = S.SilentAim,
    Callback = function(v) S.SilentAim = (v == true) end })
SecSilent:Slider({ Name = "Hit Chance", Flag = "sa_chance", Default = S.HitChance, Min = 1, Max = 100, Decimals = 0, Suffix = "%",
    Callback = function(v) S.HitChance = numOr(v, 85) end })
SecSilent:Toggle({ Name = "Humanize Spread", Flag = "sa_human", Default = S.Humanize,
    Callback = function(v) S.Humanize = (v == true) end })
SecSilent:Slider({ Name = "Humanize Offset", Flag = "sa_h_amt", Default = S.HumanizeAmount, Min = 0.05, Max = 1.5, Decimals = 2, Suffix = " studs",
    Callback = function(v) S.HumanizeAmount = numOr(v, 0.25) end })

SecTarget:Slider({ Name = "FOV", Flag = "t_fov", Default = S.FovDeg, Min = 1, Max = 45, Decimals = 1, Suffix = "deg",
    Callback = function(v) S.FovDeg = numOr(v, 8) end })
SecTarget:Toggle({ Name = "Show FOV Circle", Flag = "t_show_fov", Default = S.ShowFov,
    Callback = function(v) S.ShowFov = (v == true) end })
SecTarget:Dropdown({ Name = "Hit Part", Flag = "t_part", Default = S.HitPart, Items = { "Head", "Torso", "Nearest", "Random" },
    Callback = function(v) S.HitPart = v end })
SecTarget:Slider({ Name = "Head Bias (Random)", Flag = "t_hbias", Default = S.HeadBias, Min = 0, Max = 100, Decimals = 0, Suffix = "%",
    Callback = function(v) S.HeadBias = numOr(v, 65) end })
SecTarget:Dropdown({ Name = "Priority", Flag = "t_prio", Default = S.Priority, Items = { "Crosshair", "Distance", "Health" },
    Callback = function(v) S.Priority = v end })
SecTarget:Toggle({ Name = "Target Lock", Flag = "t_lock", Default = S.TargetLock,
    Callback = function(v)
        S.TargetLock = (v == true)
        if not S.TargetLock then lockedTargetModel = nil end
    end })
SecTarget:Slider({ Name = "Max Distance", Flag = "t_dist", Default = S.MaxDistance, Min = 20, Max = 800, Decimals = 0,
    Callback = function(v) S.MaxDistance = numOr(v, 450) end })
SecTarget:Toggle({ Name = "Wall Check", Flag = "t_wall", Default = S.WallCheck,
    Callback = function(v) S.WallCheck = (v == true) end })
SecTarget:Toggle({ Name = "Team Check", Flag = "t_team", Default = S.TeamCheck,
    Callback = function(v) S.TeamCheck = (v == true) end })

SecAimbot:Toggle({ Name = "Camera Aimbot", Flag = "cam_enabled", Default = S.CamAimbot,
    Callback = function(v) S.CamAimbot = (v == true) end })
SecAimbot:Dropdown({ Name = "Aim Mode", Flag = "cam_mode", Default = S.AimMode, Items = { "Hold", "Toggle", "Always" },
    Callback = function(v) S.AimMode = v end })
SecAimbot:Label({ Name = "Aim Key" }):Keybind({ Flag = "cam_key", Default = S.AimKey, Mode = "Hold",
    Callback = function(toggled)
        local k = keyFromFlag("cam_key")
        if k then S.AimKey = k end
        if S.AimMode == "Hold" then
            isAimingHeld = (toggled == true)
            if not isAimingHeld then
                lockedTargetModel = nil
            end
        elseif S.AimMode == "Toggle" and toggled then
            aimbotToggled = not aimbotToggled
            if not aimbotToggled then
                lockedTargetModel = nil
            end
        end
    end })
SecAimbot:Slider({ Name = "Smoothing", Flag = "cam_smooth", Default = S.Smoothing, Min = 1, Max = 25, Decimals = 1,
    Callback = function(v) S.Smoothing = numOr(v, 6) end })
SecAimbot:Slider({ Name = "Max Turn Speed", Flag = "cam_speed", Default = S.MaxTurnSpeed, Min = 60, Max = 900, Decimals = 0, Suffix = "deg/s",
    Callback = function(v) S.MaxTurnSpeed = numOr(v, 360) end })

SecSim:Toggle({ Name = "Simulate Ray / Trajectory", Flag = "sim_enabled", Default = S.SimulateRay,
    Callback = function(v) S.SimulateRay = (v == true) end })
SecSim:Label({ Name = "Simulation Color" }):Colorpicker({ Flag = "sim_col", Default = S.SimulateColor,
    Callback = function(c)
        if typeof(c) == "Color3" then
            S.SimulateColor = c
            if simLine then simLine.Color = c end
            if simImpact then simImpact.Color = c end
        end
    end })

-- ===== TAB: PREDICTION & SAFETY =====
local SecPred = TabPred:Section({ Name = "Weapon Prediction", Side = 1 })
local SecSafe = TabPred:Section({ Name = "Server Sanity Validation", Side = 2 })

SecPred:Dropdown({ Name = "Prediction Mode", Flag = "pred_mode", Default = S.PredictionMode, Items = { "Auto", "Custom", "Off" },
    Callback = function(v) S.PredictionMode = v end })
SecPred:Toggle({ Name = "Hitscan Ping Lead", Flag = "pred_hitscan", Default = S.HitscanLead,
    Callback = function(v) S.HitscanLead = (v == true) end })
SecPred:Slider({ Name = "Custom Bullet Speed", Flag = "pred_spd", Default = S.CustomSpeed, Min = 50, Max = 1500, Decimals = 0,
    Callback = function(v) S.CustomSpeed = numOr(v, 350) end })
SecPred:Slider({ Name = "Custom Gravity Drop", Flag = "pred_grav", Default = S.CustomGravity, Min = 0, Max = 300, Decimals = 0,
    Callback = function(v) S.CustomGravity = numOr(v, 80) end })

SecSafe:Toggle({ Name = "Verify Ammo (>0)", Flag = "safe_ammo", Default = S.CheckAmmo,
    Callback = function(v) S.CheckAmmo = (v == true) end })
SecSafe:Toggle({ Name = "Verify Reload State", Flag = "safe_reload", Default = S.CheckReloading,
    Callback = function(v) S.CheckReloading = (v == true) end })
SecSafe:Toggle({ Name = "Verify Cooldown / Debounce", Flag = "safe_cd", Default = S.CheckCooldown,
    Callback = function(v) S.CheckCooldown = (v == true) end })
SecSafe:Toggle({ Name = "Block While Emoting", Flag = "safe_emote", Default = S.CheckEmoting,
    Callback = function(v) S.CheckEmoting = (v == true) end })

-- [STEALTH] Accuracy Cap controls — ป้องกัน server stat audit หลัง 30+ นาที
local SecAntiDetect = TabPred:Section({ Name = "Anti-Detect (Stat Spoof)", Side = 1 })
SecAntiDetect:Toggle({ Name = "Accuracy Cap Enabled", Flag = "ac_cap_en", Default = S.AccuracyCapEnabled,
    Callback = function(v) S.AccuracyCapEnabled = (v == true) end })
SecAntiDetect:Slider({ Name = "Max Accuracy %", Flag = "ac_cap_val", Default = S.AccuracyCap, Min = 50, Max = 95, Decimals = 1, Suffix = "%",
    Callback = function(v)
        S.AccuracyCap = numOr(v, 74)
    end })
SecAntiDetect:Label({ Name = "Session Decay: auto after 20min play" })

-- ===== TAB: TRIGGERBOT =====
local SecTrig     = TabTrig:Section({ Name = "Trigger Setup", Side = 1 })
local SecTrigPeek = TabTrig:Section({ Name = "Lock & Peek Prefire", Side = 1 })
local SecTrigLead = TabTrig:Section({ Name = "Network Compensation", Side = 2 })

local trigToggle = SecTrig:Toggle({ Name = "Triggerbot Enabled", Flag = "trig_enabled", Default = S.Trigger,
    Callback = function(v) S.Trigger = (v == true) end })
trigToggle:Keybind({ Flag = "trig_key", Default = Enum.KeyCode.T, Mode = "Toggle" })
SecTrig:Toggle({ Name = "Hold Fire (auto weapons)", Flag = "trig_hold", Default = S.TriggerHold,
    Callback = function(v) S.TriggerHold = (v == true) end })
SecTrig:Slider({ Name = "Click Rate", Flag = "trig_rate", Default = S.TriggerRate, Min = 0, Max = 250, Decimals = 0, Suffix = "ms",
    Callback = function(v) S.TriggerRate = numOr(v, 0) end })
SecTrig:Slider({ Name = "Delay Min", Flag = "trig_min", Default = S.TriggerDelayMin, Min = 0, Max = 300, Decimals = 0, Suffix = "ms",
    Callback = function(v) S.TriggerDelayMin = math.min(numOr(v, 0), S.TriggerDelayMax) end })
SecTrig:Slider({ Name = "Delay Max", Flag = "trig_max", Default = S.TriggerDelayMax, Min = 0, Max = 300, Decimals = 0, Suffix = "ms",
    Callback = function(v) S.TriggerDelayMax = math.max(numOr(v, 0), S.TriggerDelayMin) end })

SecTrigPeek:Toggle({ Name = "Trigger Head Lock (camera)", Flag = "trig_lock", Default = S.TriggerLock,
    Callback = function(v)
        S.TriggerLock = (v == true)
        if not S.TriggerLock and not isAimingHeld and not aimbotToggled then lockedTargetModel = nil end
    end })
SecTrigPeek:Toggle({ Name = "Peek Prefire (shoot at wall edge)", Flag = "trig_prefire", Default = S.TriggerPrefire,
    Callback = function(v) S.TriggerPrefire = (v == true) end })
SecTrigPeek:Slider({ Name = "Prefire Look-ahead", Flag = "trig_prefire_ms", Default = S.PrefireMs, Min = 30, Max = 300, Decimals = 0, Suffix = "ms",
    Callback = function(v) S.PrefireMs = numOr(v, 120) end })

SecTrigLead:Toggle({ Name = "Ping Lead Compensation", Flag = "trig_lead", Default = S.TriggerLead,
    Callback = function(v) S.TriggerLead = (v == true) end })
SecTrigLead:Slider({ Name = "Lead Adjustment", Flag = "trig_extra", Default = S.TriggerLeadExtra, Min = -50, Max = 150, Decimals = 0, Suffix = "ms",
    Callback = function(v) S.TriggerLeadExtra = numOr(v, 0) end })

-- ===== TAB: VISUALS & HUD =====
local SecEsp = TabVis:Section({ Name = "ESP & Chams", Side = 1 })
local SecHud = TabVis:Section({ Name = "HUD & Crosshair", Side = 2 })

SecEsp:Toggle({ Name = "ESP Enabled", Flag = "esp_en", Default = S.Esp, Callback = function(v) S.Esp = (v == true) end })
SecEsp:Toggle({ Name = "Box", Flag = "esp_box", Default = S.EspBox, Callback = function(v) S.EspBox = (v == true) end })
SecEsp:Toggle({ Name = "Name", Flag = "esp_name", Default = S.EspName, Callback = function(v) S.EspName = (v == true) end })
SecEsp:Toggle({ Name = "Distance", Flag = "esp_dist", Default = S.EspDist, Callback = function(v) S.EspDist = (v == true) end })
SecEsp:Toggle({ Name = "Health Bar", Flag = "esp_hp", Default = S.EspHealth, Callback = function(v) S.EspHealth = (v == true) end })
SecEsp:Toggle({ Name = "Tracer", Flag = "esp_tracer", Default = S.EspTracer, Callback = function(v) S.EspTracer = (v == true) end })
SecEsp:Toggle({ Name = "Chams (Through walls)", Flag = "esp_chams", Default = S.Chams, Callback = function(v) S.Chams = (v == true) end })
SecEsp:Slider({ Name = "Chams Fill", Flag = "esp_fill", Default = S.ChamsFill, Min = 0, Max = 1, Decimals = 2,
    Callback = function(v) S.ChamsFill = numOr(v, 0.6) end })
SecEsp:Label({ Name = "ESP Color" }):Colorpicker({ Flag = "esp_col", Default = S.EspColor,
    Callback = function(c) if typeof(c) == "Color3" then S.EspColor = c end end })

SecHud:Toggle({ Name = "Status HUD", Flag = "hud_en", Default = S.StatusHud, Callback = function(v) S.StatusHud = (v == true) end })
SecHud:Toggle({ Name = "Target Marker", Flag = "hud_marker", Default = S.TargetMarker, Callback = function(v) S.TargetMarker = (v == true) end })
SecHud:Toggle({ Name = "Custom Crosshair", Flag = "ch_en", Default = S.CustomCrosshair, Callback = function(v) S.CustomCrosshair = (v == true) end })
SecHud:Slider({ Name = "Crosshair Size", Flag = "ch_sz", Default = S.CrosshairSize, Min = 2, Max = 25, Decimals = 0,
    Callback = function(v) S.CrosshairSize = numOr(v, 6) end })
SecHud:Slider({ Name = "Crosshair Gap", Flag = "ch_gap", Default = S.CrosshairGap, Min = 1, Max = 15, Decimals = 0,
    Callback = function(v) S.CrosshairGap = numOr(v, 4) end })
SecHud:Label({ Name = "Crosshair Color" }):Colorpicker({ Flag = "ch_col", Default = S.CrosshairColor,
    Callback = function(c) if typeof(c) == "Color3" then S.CrosshairColor = c end end })

-- ===== TAB: PRACTICE & PRESETS =====
local SecStats  = TabPres:Section({ Name = "Accuracy & TTK Tracker", Side = 1 })
local SecPreset = TabPres:Section({ Name = "Presets", Side = 2 })
local SecPanic  = TabPres:Section({ Name = "Emergency Exit", Side = 2 })

SecStats:Button({ Name = "Reset Stats Counter", Callback = function()
    Stats.ShotsFired = 0
    Stats.HitsConfirmed = 0
    Stats.Accuracy = 0
    Stats.TargetAcquisitionTime = 0
    notify("Practice stats reset.")
end })

-- setFlag เรียก Callback ของ element ให้เอง -> S อัปเดตตาม
SecPreset:Button({ Name = "Load Preset: Legit", Callback = function()
    lockedTargetModel = nil
    -- [STEALTH] Legit preset: accuracy ~60%, smooth cam, no silent aim
    setFlag("sa_enabled", false); setFlag("sa_chance", 60);   setFlag("t_fov", 5)
    setFlag("t_part", "Nearest"); setFlag("cam_enabled", true); setFlag("cam_smooth", 14)
    setFlag("cam_speed", 160);    setFlag("sim_enabled", false); setFlag("sa_human", true)
    setFlag("sa_h_amt", 0.35)
    S.AccuracyCap = 68.0
    notify("Preset: Legit loaded.")
end })

SecPreset:Button({ Name = "Load Preset: Semi-Legit", Callback = function()
    lockedTargetModel = nil
    -- [STEALTH] Semi-legit: accuracy cap 74%, cam smooth, head bias normal
    setFlag("sa_enabled", false); setFlag("sa_chance", 72);   setFlag("t_fov", 7)
    setFlag("t_part", "Nearest"); setFlag("cam_enabled", true); setFlag("cam_smooth", 10)
    setFlag("cam_speed", 200);    setFlag("sim_enabled", false); setFlag("sa_human", true)
    setFlag("sa_h_amt", 0.25)
    S.AccuracyCap = 74.0
    notify("Preset: Semi-Legit loaded.")
end })

SecPreset:Button({ Name = "Load Preset: Rage (Practice only)", Callback = function()
    lockedTargetModel = nil
    -- [STEALTH] Rage: ใช้ practice เท่านั้น ถ้าใช้ ranked = ban
    setFlag("sa_enabled", true);  setFlag("sa_chance", 85);  setFlag("t_fov", 15)
    setFlag("t_part", "Nearest"); setFlag("cam_enabled", true); setFlag("cam_smooth", 5)
    setFlag("cam_speed", 400);    setFlag("sim_enabled", false); setFlag("sa_human", true)
    setFlag("sa_h_amt", 0.15)
    S.AccuracyCap = 82.0
    notify("Preset: Rage loaded. Use in Practice only!")
end })

SecPanic:Label({ Name = "Panic Key (Emergency Unload)" }):Keybind({ Flag = "panic_key", Default = S.PanicKey, Mode = "Hold",
    Callback = function()
        local k = keyFromFlag("panic_key")
        if k then S.PanicKey = k end
    end })
SecPanic:Button({ Name = "Unload Script (Clean Killswitch)", Callback = Unload })

-- [STEALTH] ไม่ระบุชื่อ script ใน print — anti-cheat บางตัวสแกน output log
print(string.format("[%s] Module initialized. Build: %d",
    string.char(67,83,85),  -- CSU
    math.random(1000, 9999)
))
