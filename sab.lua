local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer

-- ==========================================
-- CONFIGURATION
-- ==========================================
local SELL_TEXT = "Sell" -- Change to "Delete" or whatever the specific button says
local COLLECTION_DISTANCE = 5
local INTERACT_DISTANCE = 15
local BUY_COOLDOWN = 1.0

local function getChar()
    local char = lp.Character or lp.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    local hum = char:WaitForChild("Humanoid", 5)
    return char, hrp, hum
end

-- ==========================================
-- ANTI-CHEAT BYPASS & PROMPT TRIGGER
-- ==========================================
local function triggerPrompt(prompt)
    if not prompt then return end
    
    -- Bypasses based on your Discord screenshot
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 9e9
    prompt.RequiresLineOfSight = false
    pcall(function() prompt.ClickablePrompt = true end)
    
    -- Executor firing method with fallback
    local usedFire = pcall(function()
        if fireproximityprompt then
            fireproximityprompt(prompt, 9e9, 0)
        else
            error("No fireproximityprompt")
        end
    end)
    
    if not usedFire then
        pcall(function()
            prompt:InputHoldBegin()
            task.wait(0.1)
            prompt:InputHoldEnd()
        end)
    end
end

-- ==========================================
-- FIND LOCAL PLAYER'S PLOT
-- ==========================================
local function getMyPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    
    for _, plot in ipairs(plots:GetChildren()) do
        local sign = plot:FindFirstChild("PlotSign")
        if sign and sign:FindFirstChild("YourBase") and sign.YourBase:IsA("BillboardGui") and sign.YourBase.Enabled then
            return plot
        end
    end
    return nil
end

-- ==========================================
-- 1. COLLECT MONEY AT BASE
-- ==========================================
local function collectMoney()
    local myPlot = getMyPlot()
    if not myPlot then return end
    
    local _, hrp, hum = getChar()
    if not hrp or not hum then return end
    
    local collector = myPlot:FindFirstChild("Collector") or myPlot:FindFirstChild("MoneyBin") or myPlot:FindFirstChild("ATM")
    
    if collector then
        hum:MoveTo(collector.Position)
        
        local timeout = tick() + 6
        repeat 
            task.wait(0.1) 
        until not hrp or (hrp.Position - collector.Position).Magnitude < COLLECTION_DISTANCE or tick() > timeout
        
        task.wait(0.5) 
    end
end

-- ==========================================
-- 2. FIND LOWEST BRAINROT TO DELETE
-- ==========================================
local function findLowestUnit()
    local myPlot = getMyPlot()
    if not myPlot then return nil end
    
    local lowestVal = math.huge
    local targetPrompt = nil
    
    for _, desc in ipairs(myPlot:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.ActionText == SELL_TEXT then
            local valStr = desc.Parent.Name:match("(%d+)")
            local val = tonumber(valStr)
            
            if val and val < lowestVal then
                lowestVal = val
                targetPrompt = desc
            end
        end
    end
    return targetPrompt
end

-- ==========================================
-- 3. FIND HIGHEST BRAINROT TO BUY
-- ==========================================
local function findHighestUpgrade()
    local highestVal = -1
    local targetPrompt = nil
    
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.ActionText:find("/s") then
            local val = tonumber(desc.ActionText:match("(%d+)"))
            if val and val > highestVal then
                highestVal = val
                targetPrompt = desc
            end
        end
    end
    return targetPrompt
end

-- ==========================================
-- WALK TO OBJECT AND INTERACT
-- ==========================================
local function walkAndInteract(prompt)
    if not prompt then return false end
    local _, hrp, hum = getChar()
    if not hrp or not hum then return false end
    
    local parent = prompt.Parent
    local part = parent:IsA("BasePart") and parent or parent:FindFirstChildWhichIsA("BasePart")
    
    if part then
        hum:MoveTo(part.Position)
        
        local timeout = tick() + 6
        repeat 
            task.wait(0.1) 
        until not hrp or (hrp.Position - part.Position).Magnitude <= INTERACT_DISTANCE or tick() > timeout
        
        if (hrp.Position - part.Position).Magnitude <= INTERACT_DISTANCE + 5 then
            triggerPrompt(prompt)
            return true
        end
    end
    return false
end

-- ==========================================
-- MAIN AUTOMATION LOOP
-- ==========================================
task.spawn(function()
    while true do
        pcall(function()
            -- Step 1: Return to base and collect money
            collectMoney()
            
            -- Step 2: Clear a slot by deleting the lowest unit
            local lowest = findLowestUnit()
            if lowest then
                if walkAndInteract(lowest) then
                    task.wait(BUY_COOLDOWN)
                end
            end
            
            -- Step 3: Go buy the highest available upgrade
            local highest = findHighestUpgrade()
            if highest then
                walkAndInteract(highest)
            end
        end)
        task.wait(0.5) -- Slight delay to prevent crashing/lag
    end
end)
