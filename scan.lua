local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local getRemote = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET")

-- ⚙️ CONFIGURATION ⚙️
local webhookUrl = "https://discord.com/api/webhooks/1398304025295982764/26dqhyvUrJlNDNuyQ3QG-dzFeSqJ-hXIp1HPUalE3h-7JrdhtcoWjERoMhiz0FhHcjSE"
local minDelay = 1.00 
local maxDelay = 3.00 
local statusInterval = 600 -- 10 Mins

-- 🎯 STOP TARGETS (Will STOP the script) 🎯
local targetFamilies = {
    ["Helos"] = true,
    ["Fritz"] = true,
}

-- 📦 DEPOSIT TARGETS (Will DEPOSIT and KEEP ROLLING) 📦
local depositFamilies = {
    ["Ackerman"] = true,
    ["Reiss"] = true,
    ["Yeager"] = true,
    
    -- 🛠️ TESTING COMMONS & RARES 🛠️
    ["Iglehaut"] = true,
    ["Kirstein"] = true,
    ["Braus"] = true,
    ["Springer"] = true,
    ["Wagner"] = true,
    ["Hoover"] = true,
    ["Bodt"] = true,
    ["Schultz"] = true,
    ["Galliard"] = true,
    ["Finger"] = true,
    ["Grice"] = true,
    ["Leonhart"] = true,
    ["Tybur"] = true,
    ["Kruger"] = true,
    ["Arlert"] = true,
    ["Boyzan"] = true,
    ["Doyle"] = true,
}

-- 🛡️ ANTI-AFK 🛡️
local VirtualUser = game:GetService("VirtualUser")
Players.LocalPlayer.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

-- 🔔 WEBHOOK FUNCTIONS 🔔
local function sendWebhook(title, msg)
    local data = {
        ["content"] = "@everyone " .. title .. "\n\n" .. msg .. "\n👤 **Account:** `" .. Players.LocalPlayer.Name .. "`"
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

-- 🚀 MAIN AUTO-ROLL LOOP 🚀
print("--- ⚡ [AOT:R] AUTO-DEPOSIT SCRIPT INJECTED ⚡ ---")

local lastStatusTime = tick()

while true do
    local success, spinsLeft, familyName = pcall(function()
        return getRemote:InvokeServer("Family", "Roll")
    end)

    if success and familyName then
        
        -- CHECK 1: Is it a Stop Target? (Mythic)
        if targetFamilies[familyName] then
            print("!!! 🏆 MYTHIC FOUND: " .. familyName .. " 🏆 !!!")
            sendWebhook("🚨 **AOT:R AUTO-ROLL ALERT** 🚨", "🎯 **Target Found & Stopped:** `" .. familyName .. "`\n🎰 **Spins Remaining:** `" .. tostring(spinsLeft) .. "`")
            break -- 🛑 STOPS SCRIPT
            
        -- CHECK 2: Is it a Deposit Target?
        elseif depositFamilies[familyName] then
            print("📦 TARGET FOUND! Auto-Depositing: " .. familyName)
            
            -- Fires the deposit command
            pcall(function()
                getRemote:InvokeServer("Family", "Deposit")
            end)
            
            sendWebhook("📦 **BANKED A TARGET** 📦", "📥 **Deposited:** `" .. familyName .. "`\n🎰 **Spins Remaining:** `" .. tostring(spinsLeft) .. "`\n🔄 *Continuing to roll...*")
            
            task.wait(1.5) -- Wait a second for the deposit to register before rolling again
            continue -- 🔄 KEEPS ROLLING
            
        -- CHECK 3: Trash Family
        else
            print(tostring(familyName) .. " is not selected | Spinning...")
        end

        if type(spinsLeft) == "number" and spinsLeft <= 0 then
            print("❌ Out of spins! Stopping script.")
            sendWebhook("❌ **OUT OF SPINS** ❌", "Script automatically stopped.")
            break
        end

    elseif success and not familyName then
        warn("⏳ Roll not available yet (Server Cooldown). Waiting...")
        task.wait(1.5) 
        continue 
    else
        warn("⚠️ Network lag or remote error. Retrying...")
        task.wait(2)
        continue
    end

    -- ⏱️ 10-MINUTE STATUS CHECK ⏱️
    if tick() - lastStatusTime >= statusInterval then
        if spinsLeft then 
            sendWebhook("🟢 **STATUS UPDATE** 🟢", "✅ **Status:** `Active & Rolling`\n🎰 **Spins Remaining:** `" .. tostring(spinsLeft) .. "`")
            lastStatusTime = tick()
        end
    end

    local randomWait = math.random(minDelay * 100, maxDelay * 100) / 100
    task.wait(randomWait)
end
