local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local getRemote = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET")

-- ⚙️ CONFIGURATION ⚙️
local webhookUrl = "https://discord.com/api/webhooks/1398304025295982764/26dqhyvUrJlNDNuyQ3QG-dzFeSqJ-hXIp1HPUalE3h-7JrdhtcoWjERoMhiz0FhHcjSE"
local minDelay = 1.00 -- Safest minimum delay
local maxDelay = 3.00 -- Safest maximum delay
local statusInterval = 600 -- Time between status pings (600 seconds = 10 mins)

-- 🎯 TARGET FAMILIES 🎯
local targetFamilies = {
    -- MYTHIC
    ["Helos"] = true,
    ["Fritz"] = true,
    
    -- LEGENDARY
    ["Ackerman"] = true,
    ["Reiss"] = true,
    ["Yeager"] = true,
}

-- 🛡️ ANTI-AFK 🛡️
local VirtualUser = game:GetService("VirtualUser")
Players.LocalPlayer.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

-- 🛠️ EXECUTOR HTTP DETECTION (FIXES THE NIL ERROR) 🛠️
local httprequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

-- 🔔 WEBHOOK FUNCTIONS 🔔
local function sendTargetWebhook(spins, family)
    if not httprequest then return end
    
    local data = {
        ["content"] = "@everyone 🚨 **AOT:R AUTO-ROLL ALERT** 🚨\n\n🎯 **Target Found:** `" .. family .. "`\n🎰 **Spins Remaining:** `" .. spins .. "`\n👤 **Account:** `" .. Players.LocalPlayer.Name .. "`"
    }
    pcall(function()
        httprequest({
            Url = webhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(data)
        })
    end)
end

local function sendStatusWebhook(spins)
    if not httprequest then return end
    
    local data = {
        ["content"] = "@everyone 🟢 **STATUS UPDATE** 🟢\n\n✅ **Status:** `Active & Rolling`\n🎰 **Spins Remaining:** `" .. spins .. "`\n👤 **Account:** `" .. Players.LocalPlayer.Name .. "`"
    }
    pcall(function()
        httprequest({
            Url = webhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(data)
        })
    end)
    print("Sent 10-minute status update to Discord.")
end

-- 🚀 MAIN AUTO-ROLL LOOP 🚀
print("--- ⚡ [AOT:R] TARGETED MASTER REMOTE SCRIPT INJECTED ⚡ ---")

local lastStatusTime = tick()

while true do
    -- Sending the specific arguments to the master remote
    local success, spinsLeft, familyName = pcall(function()
        return getRemote:InvokeServer("Family", "Roll")
    end)

    if success and familyName then
        if targetFamilies[familyName] then
            print("!!! 🏆 TARGET FOUND: " .. familyName .. " 🏆 !!!")
            sendTargetWebhook(tostring(spinsLeft), tostring(familyName))
            break
        else
            print(tostring(familyName) .. " is not selected | Spinning...")
        end
        
        if type(spinsLeft) == "number" and spinsLeft <= 0 then
            print("❌ Out of spins! Stopping script.")
            break
        end

    elseif success and not familyName then
        warn("⏳ Roll not available yet (Server Cooldown). Waiting to try again...")
        task.wait(1.5) 
        continue 
    else
        warn("⚠️ Network lag or remote error. Retrying in 2 seconds...")
        task.wait(2)
        continue
    end

    -- ⏱️ 10-MINUTE STATUS CHECK ⏱️
    if tick() - lastStatusTime >= statusInterval then
        if spinsLeft then 
            sendStatusWebhook(tostring(spinsLeft))
            lastStatusTime = tick()
        end
    end

    -- Random delay between successful rolls
    local randomWait = math.random(minDelay * 100, maxDelay * 100) / 100
    task.wait(randomWait)
end
