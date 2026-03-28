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

-- 🔔 WEBHOOK FUNCTIONS 🔔
local function sendTargetWebhook(spins, family)
    local data = {
        ["content"] = "🚨 **AOT:R AUTO-ROLL ALERT** 🚨\n\n🎯 **Target Found:** `" .. family .. "`\n🎰 **Spins Remaining:** `" .. spins .. "`\n👤 **Account:** `" .. Players.LocalPlayer.Name .. "`"
    }
    pcall(function()
        request({
            Url = webhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(data)
        })
    end)
end

local function sendStatusWebhook(spins)
    local data = {
        ["content"] = "🟢 **STATUS UPDATE** 🟢\n\n✅ **Status:** `Active & Rolling`\n🎰 **Spins Remaining:** `" .. spins .. "`\n👤 **Account:** `" .. Players.LocalPlayer.Name .. "`"
    }
    pcall(function()
        request({
            Url = webhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(data)
        })
    end)
    print("Sent 10-minute status update to Discord.")
end

-- 🚀 MAIN AUTO-ROLL LOOP 🚀
print("--- ⚡ [AOT:R] SMART-WAIT CLONE INJECTED ⚡ ---")

local lastStatusTime = tick()

while true do
    -- We use InvokeServer, which natively waits for the server to finish processing before moving on
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
        -- SMART WAIT: The server accepted the ping but didn't roll. It's on cooldown.
        warn("⏳ Roll not available yet (Server Cooldown). Waiting to try again...")
        task.wait(1.5) -- Force a hard wait before trying to ping the server again
        continue -- Skip the rest of the loop and try rolling again
    else
        warn("⚠️ Network lag or remote error. Retrying in 2 seconds...")
        task.wait(2)
        continue
    end

    -- ⏱️ 10-MINUTE STATUS CHECK ⏱️
    if tick() - lastStatusTime >= statusInterval then
        -- Only send status if we still have spins left to avoid spamming nil values
        if spinsLeft then 
            sendStatusWebhook(tostring(spinsLeft))
            lastStatusTime = tick()
        end
    end

    -- Random delay between successful rolls to stay stealthy
    local randomWait = math.random(minDelay * 100, maxDelay * 100) / 100
    task.wait(randomWait)
end
    end

    -- Random delay between successful rolls
    local randomWait = math.random(minDelay * 100, maxDelay * 100) / 100
    task.wait(randomWait)
end
