-- Axel Hub UI entry point.
-- Core and WebLog are loaded from the two fixed GitHub payload URLs below.

local CACHE_TTL = 300

local function sharedEnv()
    local value
    pcall(function()
        if type(getgenv) == "function" then value = getgenv() end
    end)
    return type(value) == "table" and value or _G
end

local env = sharedEnv()
local base = tostring(rawget(env, "AxelHubScriptBase")
    or "https://raw.githubusercontent.com/wtetion/loadersin/refs/heads/main/")
if not base:match("/$") then base = base .. "/" end

local cache = rawget(env, "AxelHubLoaderCache")
if type(cache) ~= "table" then cache = {} end
cache.payloads = type(cache.payloads) == "table" and cache.payloads or {}
env.AxelHubLoaderCache = cache

local function fetchFresh(url)
    for attempt = 1, 3 do
        local separator = string.find(url, "?", 1, true) and "&" or "?"
        local target = url .. separator .. "cb=" .. tostring(os.time()) .. tostring(math.random(100000, 999999))
        local ok, source = pcall(function()
            return game:HttpGet(target, true)
        end)
        if ok and type(source) == "string" and #source >= 100 then
            return source
        end
        if attempt < 3 then task.wait(0.25) end
    end
    return nil
end

local function loadPayload(fileName)
    local now = os.clock()
    local entry = cache.payloads[fileName]
    local chunk = entry and entry.chunk

    if not chunk or now - (entry.compiledAt or 0) > CACHE_TTL then
        local source = fetchFresh(base .. fileName)
        if type(source) ~= "string" then
            error("[Axel Hub] Unable to fetch " .. fileName, 0)
        end

        local compiled, compileError = loadstring(source, "@AxelHub/" .. fileName)
        source = nil
        if type(compiled) ~= "function" then
            error("[Axel Hub] Compile failed for " .. fileName .. ": " .. tostring(compileError), 0)
        end

        chunk = compiled
        cache.payloads[fileName] = {
            chunk = chunk,
            compiledAt = now,
        }
    end

    return chunk()
end

local core = loadPayload(tostring(rawget(env, "AxelHubCoreFile") or "Function-obfuscated.lua"))
local webLog = loadPayload(tostring(rawget(env, "AxelHubWebLogFile") or "Weblog-obfuscated.lua"))

return {
    Core = core,
    WebLog = webLog,
}
