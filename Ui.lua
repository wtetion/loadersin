-- Axel Hub split loader.
-- Keep the movement/UI core in a light build and protect WebLog/Premium
-- separately. Luraph VM/Anti-Tamper settings are applied to the payloads in
-- Luraph; this loader only controls ordering and fallback names.
getgenv().AxelHubCoreFile = "Function-obfuscated.lua"
getgenv().AxelHubWebLogFile = "Weblog-obfuscated.lua"

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

local function fetch(url)
    local ok, source = pcall(function()
        return game:HttpGet(url, true)
    end)
    if ok and type(source) == "string" and #source > 100 then
        return source
    end
    return nil
end

local function loadCandidate(fileName)
    local lastError = "download failed"
    for attempt = 1, 3 do
        local separator = fileName:find("?", 1, true) and "&" or "?"
        local url = base .. fileName .. separator
            .. "cb=" .. tostring(os.time()) .. tostring(math.random(100000, 999999))
        local source = fetch(url)
        if source then
            local chunk, compileError = loadstring(source, "@AxelHub/" .. fileName)
            if type(chunk) == "function" then
                local ok, result = pcall(chunk)
                if ok then return true, result end
                lastError = "runtime error: " .. tostring(result)
            else
                lastError = "compile error: " .. tostring(compileError)
            end
        end
        if attempt < 3 then task.wait(0.25) end
    end
    return false, lastError
end

local function candidateList(override, defaults)
    if type(override) == "string" and override ~= "" then
        return { override }
    end
    return defaults
end

local coreCandidates = candidateList(rawget(env, "AxelHubCoreFile"), {
    "Function-obfuscated.lua",
})

local webLogCandidates = candidateList(rawget(env, "AxelHubWebLogFile"), {
    "Weblog-obfuscated.lua",
})

local function loadFromCandidates(candidates, label)
    local lastError = "unavailable"
    for _, fileName in ipairs(candidates) do
        local ok, value = loadCandidate(fileName)
        if ok then return value end
        lastError = tostring(value)
    end
    error("[Axel Hub] Unable to load " .. label .. ": " .. lastError, 0)
end

local core = loadFromCandidates(coreCandidates, "Function payload")
local webLog = loadFromCandidates(webLogCandidates, "WebLog payload")

return {
    Core = core,
    WebLog = webLog,
}
