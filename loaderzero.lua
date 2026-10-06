--[[
    ⚡ AXEL HUB · UNIVERSAL LOADSTRING LOADER
    สำหรับวางใน autoexec/ หรือหน้าต่าง Execute ของทุกตัวรัน (Delta, Solara, Wave, Potassium ฯลฯ)
]]

repeat task.wait(0.5) until game:IsLoaded()

-- 🔗 ใส่ลิงก์ Raw ของมึงตรงนี้ (เช่น GitHub Raw หรือ Pastebin Raw)
local RAW_URL = "https://raw.githubusercontent.com/wtetion/loadersin/refs/heads/main/Zero.lua"

getgenv().AZ_RAW_URL = RAW_URL
pcall(function()
    loadstring(game:HttpGet(RAW_URL))()
end)
