local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local getRemote = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET")

-- ⚙️ CONFIGURATION ⚙️
local webhookUrl = "https://discord.com/api/webhooks/1398304025295982764/26dqhyvUrJlNDNuyQ3QG-dzFeSqJ-hXIp1HPUalE3h-7JrdhtcoWjERoMhiz0FhHcjSE"
local minDelay = 0.05 -- Minimum wait time (seconds)
local maxDelay = 3.00 -- Maximum wait time (seconds)

-- 🎯 TARGET FAMILIES 🎯
local targetFamilies = {
    -- MYTHIC
    ["Helos"] = true,
    ["Fritz"] = true,
    
    -- LEGENDARY
    ["Ackerman"] = true,
    ["Reiss"] = true,
    ["Yeager"] = true,
    
    -- 🧪 COMMON FAMILIES (TESTING WEBHOOK) 🧪
    ["Reeves"] = true,
    ["Blouse"] = true,
    ["Inocenio"] = true,
    ["Munsell"] = true,
    ["Boyega"] = true,
    ["Ral"] = true,
    ["Bozado"] = true,
    ["Pikale"] = true,
    ["Hume"] = true,
    ["Iglehaut"] = true,
}

-- 🛡️ ANTI-AFK 🛡️
local VirtualUser = game:GetService("VirtualUser")
Players.LocalPlayer.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

-- 🔔 WEBHOOK FUNCTION 🔔
local function sendDiscordWebhook(spins, family)
    local data = {
        ["content"] = "🚨 **AOT:R AUTO-ROLL ALERT** 🚨\n\n🎯 **Target Found:** `" .. family .. "`\n🎰 **Spins Remaining:** `" .. spins .. "`\n👤 **Account:** `" .. Players.LocalPlayer.Name .. "`"
    }
    
    local success, err = pcall(function()
        request({
            Url = webhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(data)
        })
    end)
    
    if not success then
        warn("Webhook failed! Error: ", err)
    end
end

-- 🚀 MAIN AUTO-ROLL LOOP 🚀
print("--- ⚡ [AOT:R] TEST-MODE INJECTED ⚡ ---")

while true do
    local success, spinsLeft, familyName = pcall(function()
        return getRemote:InvokeServer("Family", "Roll")
    end)

    if success and familyName then
        if targetFamilies[familyName] then
            print("!!! 🏆 TARGET FOUND: " .. familyName .. " 🏆 !!!")
            sendDiscordWebhook(tostring(spinsLeft), tostring(familyName))
            break
        else
            print(tostring(familyName) .. " is not selected | Spinning...")
        end
        
        if type(spinsLeft) == "number" and spinsLeft <= 0 then
            print("❌ Out of spins! Stopping script.")
            break
        end
    else
        warn("⚠️ Roll request failed. Retrying...")
    end

    local randomWait = math.random(minDelay * 100, maxDelay * 100) / 100
    task.wait(randomWait)
end
