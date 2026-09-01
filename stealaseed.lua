repeat task.wait() until game:IsLoaded()

for _, g in ipairs(game.Players.LocalPlayer.PlayerGui:GetChildren()) do
	if g.Name == "MyObsidianUI" then
		g:Destroy()
	end
end

local libSrc = game:HttpGet("https://raw.githubusercontent.com/Crelle1130/LABA-HUB/refs/heads/main/LABAHUB.luau")

-- Lower UI pill position
libSrc = string.gsub(libSrc, "pillPos = UDim2%.new%(1, %-12, 0, 12%)", "pillPos = UDim2.new(1, -12, 0, 80)")
libSrc = string.gsub(libSrc, "winMiniPos = UDim2%.new%(1, %-%(12 %+ pillW / 2%), 0, 12 %+ pillH / 2%)", "winMiniPos = UDim2.new(1, -(12 + pillW / 2), 0, 80 + pillH / 2)")

-- Fix releaseConn:Disconnect() bug (nil check)
libSrc = string.gsub(libSrc, "releaseConn:Disconnect%(%)", "if releaseConn then releaseConn:Disconnect() end")

local success, UI = pcall(function() return loadstring(libSrc)() end)
if not success or not UI then warn("Failed to load UI: " .. tostring(UI)) return end

local BASE = Vector3.new(217.375, 6.25, 45.25)
local C_Data = require(game.StarterPlayer.StarterPlayerScripts.Business.C_Data)

local AREA_MAP = {
    {name = "Garden",     z = -200,  rarity = 1},
    {name = "Forest",     z = -400,  rarity = 2},
    {name = "Desert",     z = -710,  rarity = 3},
    {name = "Snowlands",  z = -1150, rarity = 4},
    {name = "Volcano",    z = -1770, rarity = 5},
    {name = "Enchanted",  z = -2380, rarity = 6},
    {name = "Void",       z = -3200, rarity = 7},
}

local AREA_NAMES = {"Garden", "Forest", "Desert", "Snowlands", "Volcano", "Enchanted", "Void"}
local RARITY_DISPLAY = {"1 - Common", "2 - Uncommon", "3 - Rare", "4 - Epic", "5 - Legendary", "6 - Mythic", "7 - Secret"}

local win = UI:CreateWindow({
    Title = "Steal A Seed",
    Size = UDim2.fromOffset(420, 420),
})

local mainTab = win:AddTab("Farm")

local autoSteal = false
local selectedAreas = {["Void"] = true}
local selectedRarities = {[7] = true}
local stealDelay = 0.5
local isStealing = false

local function normalizeMulti(val, validSet)
    local result = {}
    if type(val) == "table" then
        for _, v in ipairs(val) do
            if validSet[v] then result[v] = true end
        end
    elseif type(val) == "string" and validSet[val] then
        result[val] = true
    end
    return result
end

local function findTargetEgg()
    local data = C_Data.GetData()
    local eggs = data.onlyData.enemyEggItemByGid
    local char = game.Players.LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, nil end

    local bestGid = nil
    local bestPos = nil
    local bestDist = 99999

    for gid, eggData in pairs(eggs) do
        if not eggData.isDropping then
            local pos = eggData.cf.Position
            local matchedArea = nil
            for _, area in ipairs(AREA_MAP) do
                if math.abs(pos.Z - area.z) < 200 then
                    matchedArea = area
                    break
                end
            end

            if matchedArea then
                if selectedAreas[matchedArea.name] and selectedRarities[matchedArea.rarity] then
                    local dist = (hrp.Position - pos).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        bestGid = gid
                        bestPos = pos
                    end
                end
            end
        end
    end

    return bestGid, bestPos
end

local function doSteal()
    if isStealing then return false end
    isStealing = true

    local char = game.Players.LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then isStealing = false return false end

    local gid, pos = findTargetEgg()
    if not gid then
        isStealing = false
        return false
    end

    hrp.CFrame = CFrame.new(pos + Vector3.new(2, 0, 2))
    task.wait(0.15)

    local ok, stealModel = pcall(function()
        return game.Workspace:FindFirstChild("创建", true)
            :FindFirstChild("拾取奖励0D", true).Steal
    end)

    if ok and stealModel then
        local prompt = stealModel:FindFirstChild("e_touch")
        if prompt then
            fireproximityprompt(prompt)
        end
    end

    task.wait(0.1)
    hrp.CFrame = CFrame.new(BASE)
    isStealing = false
    return true
end

local areaSet = {}
for _, n in ipairs(AREA_NAMES) do areaSet[n] = true end

mainTab:AddDropdown({
    Name = "Target Areas",
    Options = AREA_NAMES,
    Value = {"Void"},
    Multi = true,
    Callback = function(v)
        selectedAreas = normalizeMulti(v, areaSet)
    end,
})

local raritySet = {}
for _, n in ipairs({"1","2","3","4","5","6","7"}) do raritySet[n] = true end

mainTab:AddDropdown({
    Name = "Target Rarity",
    Options = RARITY_DISPLAY,
    Value = {"7 - Secret"},
    Multi = true,
    Callback = function(v)
        selectedRarities = {}
        local raw = type(v) == "table" and v or {v}
        for _, opt in ipairs(raw) do
            local num = tonumber(tostring(opt):match("(%d+)"))
            if num then selectedRarities[num] = true end
        end
    end,
})

mainTab:AddSlider({
    Name = "Steal Delay",
    Min = 0.1,
    Max = 3,
    Step = 0.1,
    Value = 0.5,
    Suffix = "s",
    Callback = function(v) stealDelay = v end,
})

mainTab:AddToggle({
    Name = "Auto Steal",
    Value = false,
    Callback = function(v) autoSteal = v end,
})

task.spawn(function()
    while true do
        if autoSteal then
            doSteal()
            task.wait(stealDelay)
        else
            task.wait(0.2)
        end
    end
end)
