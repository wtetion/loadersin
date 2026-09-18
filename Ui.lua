-- Axel Hub UI entry point.
-- Set AxelHubScriptBase to the raw GitHub folder that contains the two payloads.
-- This loader owns ordering only: Core first, WebLog second.

local function sharedEnv()
    local value
    pcall(function()
        if type(getgenv) == "function" then value = getgenv() end
    end)
    return type(value) == "table" and value or _G
end

local env = sharedEnv()
local base = tostring(rawget(env, "AxelHubScriptBase") or "")
if base == "" then
    error("[Axel Hub] Set getgenv().AxelHubScriptBase to your raw GitHub folder URL.", 0)
end
if not base:match("/$") then base = base .. "/" end

local function loadPayload(fileName)
    local url = base .. fileName
    local cacheBust = "?cb=" .. tostring(os.time()) .. tostring(math.random(100000, 999999))
    local ok, source = pcall(function()
        return game:HttpGet(url .. cacheBust, true)
    end)
    if not ok or type(source) ~= "string" or source == "" then
        error("[Axel Hub] Unable to fetch " .. fileName, 0)
    end

    local chunk, compileError = loadstring(source, "@AxelHub/" .. fileName)
    if type(chunk) ~= "function" then
        error("[Axel Hub] Compile failed for " .. fileName .. ": " .. tostring(compileError), 0)
    end
    return chunk()
end

local core = loadPayload(tostring(rawget(env, "AxelHubCoreFile") or "AxelHub_Functions.luau"))
local webLog = loadPayload(tostring(rawget(env, "AxelHubWebLogFile") or "AxelWebLog_Loadstring.luau"))

return {
    Core = core,
    WebLog = webLog,
}
