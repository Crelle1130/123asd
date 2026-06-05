-- Wait for the game's core to load
repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local HttpService = game:GetService("HttpService")

local placeId = game.PlaceId

local function FormatNumberWithCommas(num)
    local formatted = tostring(num)
    while true do
        local replaced
        formatted, replaced = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if replaced == 0 then break end
    end
    return formatted
end

-- =========================================================
-- ==== UI LIBRARY & TABS (initialized early for all places) ====
-- =========================================================
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Crelle1130/123asd/refs/heads/main/UI.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

ThemeManager:SetLibrary(Library)
ThemeManager:ApplyTheme("Jester")

local Options = Library.Options
local Toggles = Library.Toggles
local Running = {}

local Window = Library:CreateWindow({ Title = "GabBoboBading", Footer = "AOT:R Universal", Center = true, AutoShow = true, Resizable = true, ShowCustomCursor = true })

local Tabs = {
    Mission  = Window:AddTab("Mission", "swords"),
    Lobby    = Window:AddTab("Lobby", "house"),
    Menu     = Window:AddTab("Main Menu", "home"),
    Settings = Window:AddTab("Settings", "settings"),
}

Tabs.Mission:SetVisible(placeId ~= 13379208636 and placeId ~= 14916516914)
Tabs.Lobby:SetVisible(placeId == 14916516914)
Tabs.Menu:SetVisible(placeId == 13379208636)

-- =========================================================
-- ==== ANTI-AFK (CURSOR CLICK SIMULATION) ====
-- =========================================================
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- =========================================================
-- ==== MISSION PLACE TRACKER (SAFE DOUBLE FAILSAFE) ====
-- =========================================================
if placeId ~= 13379208636 and placeId ~= 14916516914 then
    _G.TotalMissionDamage = 0

    -- Error notifier: show each unique error once only
    local _shownErrors = {}
    local function SafeNotify(title, msg)
        local key = title .. msg
        if not _shownErrors[key] then
            _shownErrors[key] = true
            Library:Notify({ Title = title, Description = msg, Time = 6 })
        end
    end

    -- 1. Read Current Runs
    local runCount = 0
    pcall(function() runCount = tonumber(readfile("GabBobo_RunCount.txt")) or 0 end)
    
    -- 2. Increment and Save
    runCount = runCount + 1
    pcall(function() writefile("GabBobo_RunCount.txt", tostring(runCount)) end)

    -- 3. Read Max Runs from Lobby Slider
    local maxRuns = 20
    pcall(function()
        local cfg = HttpService:JSONDecode(readfile("GabBobo_MaxRuns.txt"))
        if cfg and cfg.MaxRuns then maxRuns = tonumber(cfg.MaxRuns) end
    end)

    -- FAILSAFE 1: THE CONCRETE WALL
    if runCount > maxRuns then
        task.spawn(function()
            local RS = game:GetService("ReplicatedStorage")
            local postRemote = RS:WaitForChild("Assets", 9e9):WaitForChild("Remotes", 9e9):WaitForChild("POST", 9e9)
            
            while task.wait(5) do
                pcall(function() postRemote:FireServer("Functions", "Teleport") end)
            end
        end)
        return 
    end

    -- FAILSAFE 2: THE UI SNIPER
    if runCount == maxRuns then
        task.spawn(function()
            local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 9e9)
            local Interface = PlayerGui:WaitForChild("Interface", 9e9)
            
            local hasMatchEnded = false
            while not hasMatchEnded and task.wait(0.5) do
                for _, element in pairs(Interface:GetDescendants()) do
                    if (element:IsA("TextLabel") or element:IsA("TextButton")) and element.Visible and element.Text ~= "" then
                        local txt = string.lower(element.Text)
                        
                        if txt == "replay" or txt == "retry" or string.match(txt, "^replay$") then
                            hasMatchEnded = true
                            
                            task.wait(3.5)
                            
                            local RS = game:GetService("ReplicatedStorage")
                            local postRemote = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("Remotes") and RS.Assets.Remotes:FindFirstChild("POST")
                            
                            if postRemote then
                                pcall(function() postRemote:FireServer("Functions", "Teleport") end)
                                
                                task.wait(5)
                                pcall(function() postRemote:FireServer("Functions", "Teleport") end)
                            end
                            break
                        end
                    end
                end
            end
        end)
    end

    -- =========================================================
    -- ==== END-OF-RUN DAMAGE NOTIFICATION (every run) ====
    -- =========================================================
    task.spawn(function()
        local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 9e9)
        local Interface = PlayerGui:WaitForChild("Interface", 9e9)

        local hasMatchEnded = false
        while not hasMatchEnded and task.wait(0.5) do
            for _, element in pairs(Interface:GetDescendants()) do
                if (element:IsA("TextLabel") or element:IsA("TextButton")) and element.Visible and element.Text ~= "" then
                    local txt = string.lower(element.Text)
                    if txt == "replay" or txt == "retry" or string.match(txt, "^replay$") then
                        hasMatchEnded = true

                        local finalDamage = FormatNumberWithCommas(_G.TotalMissionDamage or 0)
                        pcall(function() writefile("GabBobo_TotalDamage.txt", os.date("[%Y-%m-%d %H:%M:%S]") .. " Run " .. runCount .. " | Total Damage: " .. finalDamage) end)
                        _G.TotalMissionDamage = 0
                        break
                    end
                end
            end
        end
    end)

    -- =========================================================
    -- ==== MISSION TAB: COMBAT ====
    -- =========================================================
    -- Global ready flag: wait for cutscene before any toggle runs
    local MissionReady = false
    task.spawn(function()
        -- Wait for cutscene Skip UI to appear then disappear
        local waited = 0
        while waited < 30 do
            local skipUI = LocalPlayer.PlayerGui
                and LocalPlayer.PlayerGui:FindFirstChild("Interface")
                and LocalPlayer.PlayerGui.Interface:FindFirstChild("Skip")
            if skipUI and skipUI.Visible then
                -- Cutscene is playing, wait for it to end
                while skipUI and skipUI.Visible do task.wait(0.2) end
                break
            end
            task.wait(0.2)
            waited = waited + 0.2
        end
        task.wait(1) -- small buffer after cutscene ends
        MissionReady = true
    end)

    local function WaitForMissionReady()
        while not MissionReady do task.wait(0.2) end
    end

    local MissionMainBox = Tabs.Mission:AddLeftGroupbox("Combat")

    MissionMainBox:AddToggle("AutoKill", {
        Text = "Auto Farm Titans", Default = false,
        Callback = function(Value)
            if Value then
                if Running.AutoKill then return end
                Running.AutoKill = true
                task.spawn(function()
                    WaitForMissionReady()
                    if not Toggles.AutoKill.Value then Running.AutoKill = false return end
                    local RS = game:GetService("ReplicatedStorage")
                    local RunService = game:GetService("RunService")
                    local Remotes = RS:WaitForChild("Assets", 10):WaitForChild("Remotes", 10)
                    local GET = Remotes:WaitForChild("GET", 10)
                    local POST = Remotes:WaitForChild("POST", 10)
                    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                    local hrp = char:WaitForChild("HumanoidRootPart", 10)
                    local titansFolder = workspace:WaitForChild("Titans", 10)
                    local missionStartTime = os.clock()

                    local function GetDamage()
                        -- 800-900 float damage range
                        return 800 + math.random() * 100
                    end

                    local function IsTitanDead(titan)
                        if not titan:FindFirstChildOfClass("Humanoid") then return true end
                        local fake = titan:FindFirstChild("Fake")
                        local col = fake and fake:FindFirstChild("Collision")
                        if col and not col.CanCollide then return true end
                        return false
                    end

                    -- Wait for cutscene to finish before starting
                    if Toggles.AutoSkipCutscene.Value then
                        local cutsceneStart = os.clock()
                        while Toggles.AutoKill.Value and (os.clock() - cutsceneStart) < 30 do
                            local skipUI = LocalPlayer.PlayerGui
                                and LocalPlayer.PlayerGui:FindFirstChild("Interface")
                                and LocalPlayer.PlayerGui.Interface:FindFirstChild("Skip")
                            if skipUI and skipUI.Visible then
                                task.wait(0.3) -- still in cutscene
                            else
                                break -- cutscene done
                            end
                        end
                    else
                        -- No AutoSkipCutscene, just wait a moment for map to load
                        task.wait(3)
                    end

                    -- Count total titans at start for anti-speedrun calculation
                    local totalTitans = 0
                    for _, titan in ipairs(titansFolder:GetChildren()) do
                        if not IsTitanDead(titan) and titan:FindFirstChild("Hitboxes")
                        and titan.Hitboxes:FindFirstChild("Hit")
                        and titan.Hitboxes.Hit:FindFirstChild("Nape") then
                            totalTitans = totalTitans + 1
                        end
                    end
                    local halfTitans    = math.floor(totalTitans / 2)
                    local killedCount   = 0
                    local halfWaitDone  = false
                    Library:Notify({ Title = "Auto Farm", Description = "Total titans: " .. totalTitans .. " | Will pause at " .. halfTitans, Time = 4 })

                    while Toggles.AutoKill.Value do
                        local targetTitan = nil
                        local aliveCount = 0
                        for _, titan in ipairs(titansFolder:GetChildren()) do
                            if not IsTitanDead(titan) and titan:FindFirstChild("Hitboxes") and titan.Hitboxes:FindFirstChild("Hit") and titan.Hitboxes.Hit:FindFirstChild("Nape") then
                                if not targetTitan then targetTitan = titan end
                                aliveCount = aliveCount + 1
                            end
                        end

                        if targetTitan then
                            -- Anti-speedrun: pause at half titans until 30s passed
                            if not halfWaitDone and killedCount >= halfTitans then
                                local elapsed = os.clock() - missionStartTime
                                if elapsed < 30 then
                                    local waitTime = 30 - elapsed
                                    Library:Notify({ Title = "Anti-Speedrun", Description = string.format("Half done — waiting %.1fs", waitTime), Time = waitTime })
                                    local waitEnd = os.clock() + waitTime
                                    while os.clock() < waitEnd do
                                        if not Toggles.AutoKill.Value then break end
                                        task.wait(0.1)
                                    end
                                end
                                halfWaitDone = true
                            end

                            if not Toggles.AutoKill.Value then break end

                            local nape = targetTitan.Hitboxes.Hit.Nape
                            local dead = false
                            task.spawn(function()
                                while targetTitan.Parent and not dead and Toggles.AutoKill.Value do
                                    if IsTitanDead(targetTitan) then dead = true end
                                    task.wait(0.1)
                                end
                            end)

                            if not Toggles.AutoKill.Value then break end

                            -- Hover slowly toward target position at speed 300
                            local FLOAT_Y   = nape.Position.Y + 190
                            local targetPos = Vector3.new(nape.Position.X, FLOAT_Y, nape.Position.Z)
                            local HOVER_SPEED = 1000

                            local floatConn = RunService.Heartbeat:Connect(function(dt)
                                pcall(function()
                                    if nape and targetTitan.Parent then
                                        targetPos = Vector3.new(nape.Position.X, FLOAT_Y, nape.Position.Z)
                                        local currentPos = hrp.Position
                                        local diff = targetPos - currentPos
                                        local dist = diff.Magnitude

                                        if dist > 1 then
                                            -- Move toward target at HOVER_SPEED studs/sec
                                            local moveDir = diff.Unit
                                            local step    = math.min(HOVER_SPEED * dt, dist)
                                            hrp.CFrame    = CFrame.new(currentPos + moveDir * step)
                                        else
                                            hrp.CFrame = CFrame.new(targetPos)
                                        end
                                        hrp.AssemblyLinearVelocity  = Vector3.zero
                                        hrp.AssemblyAngularVelocity = Vector3.zero
                                    end
                                end)
                            end)

                            -- ── UI-based supply readers (no remote calls) ─────
                            local function GetGradient()
                                local gui = LocalPlayer.PlayerGui
                                return gui and gui:FindFirstChild("Interface")
                                    and gui.Interface:FindFirstChild("HUD")
                                    and gui.Interface.HUD:FindFirstChild("Main")
                                    and gui.Interface.HUD.Main:FindFirstChild("Top")
                                    and gui.Interface.HUD.Main.Top:FindFirstChild("7")
                                    and gui.Interface.HUD.Main.Top["7"]:FindFirstChild("Blades")
                                    and gui.Interface.HUD.Main.Top["7"].Blades:FindFirstChild("Inner")
                                    and gui.Interface.HUD.Main.Top["7"].Blades.Inner:FindFirstChild("Bar")
                                    and gui.Interface.HUD.Main.Top["7"].Blades.Inner.Bar:FindFirstChild("Gradient")
                            end

                            local function GetReloads()
                                local gui = LocalPlayer.PlayerGui
                                local setsLabel = gui and gui:FindFirstChild("Interface")
                                    and gui.Interface:FindFirstChild("HUD")
                                    and gui.Interface.HUD:FindFirstChild("Main")
                                    and gui.Interface.HUD.Main:FindFirstChild("Top")
                                    and gui.Interface.HUD.Main.Top:FindFirstChild("7")
                                    and gui.Interface.HUD.Main.Top["7"]:FindFirstChild("Blades")
                                    and gui.Interface.HUD.Main.Top["7"].Blades:FindFirstChild("Sets")
                                if setsLabel then
                                    local current, max = setsLabel.Text:match("(%d+)%s*/%s*(%d+)")
                                    return tonumber(current) or 0
                                end
                                return 0
                            end

                            local function IsBladeBroken()
                                local gradient = GetGradient()
                                if gradient and gradient:IsA("UIGradient") then
                                    return gradient.Offset.X <= 0
                                end
                                return false
                            end

                            local function FindNearestRefill()
                                local nearestRefill = nil
                                local nearestDist   = math.huge
                                for _, obj in pairs(workspace:GetDescendants()) do
                                    if obj.Name == "Refill" and obj:IsA("BasePart") then
                                        local dist = (hrp.Position - obj.Position).Magnitude
                                        if dist < nearestDist then
                                            nearestDist   = dist
                                            nearestRefill = obj
                                        end
                                    end
                                end
                                return nearestRefill
                            end
                            -- ── End UI supply readers ──────────────────────────

                            while not dead and Toggles.AutoKill.Value and targetTitan.Parent do

                                -- ── Supply Management (UI-based, no remotes) ───────
                                if IsBladeBroken() then
                                    local reloads = GetReloads()
                                    if reloads == 0 then
                                        -- Both empty: refill first
                                        if Toggles.AutoRefill.Value then
                                            while Toggles.AutoKill.Value and GetReloads() == 0 do
                                                local refillPart = FindNearestRefill()
                                                if refillPart then
                                                    pcall(function() POST:FireServer("Attacks", "Reload", refillPart) end)
                                                    task.wait(1)
                                                else
                                                    task.wait(0.5)
                                                end
                                            end
                                        end
                                        -- After refill reload blades
                                        if GetReloads() > 0 and Toggles.AutoReload.Value then
                                            pcall(function() GET:InvokeServer("Blades", "Reload") end)
                                            task.wait(1.5)
                                        end
                                    elseif Toggles.AutoReload.Value then
                                        -- Has reloads: just reload
                                        pcall(function() GET:InvokeServer("Blades", "Reload") end)
                                        task.wait(1.5)
                                    end
                                    continue
                                end
                                -- Blade not broken: keep slashing
                                -- ── End Supply Management ──────────────────────────

                                if not Toggles.AutoKill.Value then break end
                                local dmg = GetDamage()
                                _G.TotalMissionDamage = _G.TotalMissionDamage + dmg
                                pcall(function() POST:FireServer("Attacks", "Slash", true) end)
                                pcall(function() POST:FireServer("Hitboxes", "Register", nape, dmg, 0) end)
                                task.wait(0.5)
                            end

                            floatConn:Disconnect()
                            killedCount = killedCount + 1
                            if Toggles.AutoKill.Value then
                                task.wait(0.15)
                            end
                        else
                            task.wait(1)
                        end
                    end
                end)
            end
        end
    })

    MissionMainBox:AddToggle("AutoReload", { Text = "Auto Reload Blades", Default = false })
    MissionMainBox:AddToggle("AutoRefill", { Text = "Auto Refill from HQ", Default = false })

    MissionMainBox:AddToggle("AutoSkipCutscene", {
        Text = "Auto Skip Cutscene", Default = false,
        Callback = function(Value)
            if Value then
                if Running.AutoSkipCutscene then return end
                Running.AutoSkipCutscene = true
                task.spawn(function()
                    -- Skip cutscene doesn't need to wait, it IS the cutscene handler
                    local VIM        = game:GetService("VirtualInputManager")
                    local GuiService = game:GetService("GuiService")

                    while Toggles.AutoSkipCutscene.Value do
                        local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
                        if PlayerGui then
                            local interface = PlayerGui:FindFirstChild("Interface")
                            if interface then
                                local skipUI = interface:FindFirstChild("Skip")

                                if skipUI and skipUI.Visible then
                                    local interactBtn = skipUI:FindFirstChild("Interact")

                                    if interactBtn then
                                        local inset = GuiService:GetGuiInset()
                                        local posX  = math.round(interactBtn.AbsolutePosition.X + interactBtn.AbsoluteSize.X / 2)
                                        local posY  = math.round(interactBtn.AbsolutePosition.Y + interactBtn.AbsoluteSize.Y / 2 + inset.Y)

                                        VIM:SendMouseButtonEvent(posX, posY, 0, true, game, 0)
                                        task.wait(0.1)
                                        VIM:SendMouseButtonEvent(posX, posY, 0, false, game, 0)

                                        -- Wait for server to load titans before next check
                                        task.wait(1.5)
                                        Running.AutoSkipCutscene = false
                                    end
                                end
                            end
                        end
                        task.wait(0.1)
                    end
                end)
            end
        end
    })

    MissionMainBox:AddToggle("AutoRetry", {
        Text = "Auto Retry Mission", Default = false,
        Callback = function(Value)
            if Value then
                if Running.AutoRetry then return end
                Running.AutoRetry = true
                task.spawn(function()
                    WaitForMissionReady()
                    if not Toggles.AutoRetry.Value then Running.AutoRetry = false return end
                    local RS   = game:GetService("ReplicatedStorage")
                    local GET  = RS:WaitForChild("Assets", 10):WaitForChild("Remotes", 10):WaitForChild("GET", 10)
                    local POST = RS:WaitForChild("Assets", 10):WaitForChild("Remotes", 10):WaitForChild("POST", 10)

                    local fired = false
                    local conn
                    conn = POST.OnClientEvent:Connect(function(action, sub)
                        if action == "Effects" and sub == "Evaporate" and Toggles.AutoRetry.Value and not fired then
                            task.spawn(function()
                                task.wait(1)
                                local titansFolder = workspace:FindFirstChild("Titans")
                                local aliveCount   = 0
                                if titansFolder then
                                    for _, titan in pairs(titansFolder:GetChildren()) do
                                        local hum  = titan:FindFirstChildOfClass("Humanoid")
                                        local fake = titan:FindFirstChild("Fake")
                                        local col  = fake and fake:FindFirstChild("Collision")
                                        if hum and col and col.CanCollide then
                                            aliveCount = aliveCount + 1
                                        end
                                    end
                                end
                                if aliveCount == 0 then
                                    fired = true
                                    task.wait(1)

                                    -- Check run count
                                    local runCount = 0
                                    local maxRuns  = 20
                                    pcall(function() runCount = tonumber(readfile("GabBobo_RunCount.txt")) or 0 end)
                                    pcall(function()
                                        local cfg = HttpService:JSONDecode(readfile("GabBobo_MaxRuns.txt"))
                                        if cfg and cfg.MaxRuns then maxRuns = tonumber(cfg.MaxRuns) end
                                    end)

                                    if runCount >= maxRuns then
                                        -- Max runs reached — leave to lobby
                                        pcall(function() POST:FireServer("Functions", "Teleport") end)
                                    else
                                        -- Still have runs — retry
                                        pcall(function() GET:InvokeServer("Functions", "Retry", "Add") end)
                                    end

                                    task.wait(3)
                                    fired = false
                                end
                            end)
                        end
                    end)

                    while Toggles.AutoRetry.Value do task.wait(0.5) end
                    conn:Disconnect()
                end)
            end
        end
    })

    MissionMainBox:AddSlider("MaxMissionRuns", {
        Text = "Runs Before Returning to Lobby",
        Default = 20, Min = 1, Max = 100, Rounding = 0,
        Callback = function(Value)
            pcall(function() writefile("GabBobo_MaxRuns.txt", HttpService:JSONEncode({MaxRuns = Value})) end)
        end
    })

    -- Settings for Mission place
    SaveManager:SetLibrary(Library)
    ThemeManager:SetFolder("GabBoboBading/aotr")
    SaveManager:SetFolder("GabBoboBading/aotr/Mission")
    SaveManager:BuildConfigSection(Tabs.Settings)
    ThemeManager:ApplyToTab(Tabs.Settings)
    SaveManager:LoadAutoloadConfig()

    return
end

-- =========================================================
-- ==== STRICT LOAD VERIFICATION ====
-- =========================================================

-- Global error notifier: show each unique error once only
local _shownErrors = {}
local function SafeNotify(title, msg)
    local key = title .. msg
    if not _shownErrors[key] then
        _shownErrors[key] = true
        Library:Notify({ Title = title, Description = msg, Time = 6 })
    end
end

Library:Notify({ Title = "System", Description = "Verifying Game Load State...", Time = 3 })

-- 1. Check UI Interface Container
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 9e9)
local Interface = PlayerGui:WaitForChild("Interface", 9e9)

-- 2. Smart Lobby Tab Scanner (TRUE VISIBILITY CHECK)
if placeId == 14916516914 then
    Library:Notify({ Title = "System", Description = "Lobby detected. Waiting for Tabs to render...", Time = 3 })
    
    local function IsTrulyVisible(obj)
        local current = obj
        while current and current ~= game and not current:IsA("ScreenGui") do
            if current:IsA("GuiObject") and not current.Visible then return false end
            current = current.Parent
        end
        if current and current:IsA("ScreenGui") and not current.Enabled then return false end
        return true
    end

    local tabsAreVisible = false
    local waitTimeout = 0
    
    while not tabsAreVisible and waitTimeout < 60 do 
        local foundGear = false
        local foundMarket = false
        
        for _, element in pairs(Interface:GetDescendants()) do
            if (element:IsA("TextLabel") or element:IsA("TextButton")) and element.Text ~= "" then
                if IsTrulyVisible(element) and element.TextTransparency < 0.9 then
                    local textStr = string.lower(element.Text)
                    if string.match(textStr, "gear") or string.match(textStr, "equipment") then
                        foundGear = true
                    elseif string.match(textStr, "market") or string.match(textStr, "store") then
                        foundMarket = true
                    end
                end
            end
        end
        
        if foundGear and foundMarket then
            tabsAreVisible = true
        else
            task.wait(0.5)
            waitTimeout = waitTimeout + 1
        end
    end

    if waitTimeout >= 60 then
        Library:Notify({ Title = "Warning", Description = "Tab check timed out. Proceeding anyway.", Time = 4 })
    end
end

-- 3. Check Network Remotes
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage:WaitForChild("Assets", 9e9)
local Remotes = Assets:WaitForChild("Remotes", 9e9)
local GetRemote = Remotes:WaitForChild("GET", 9e9)

-- 4. Check Secure Actor Thread
local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
char:WaitForChild("Actor", 9e9)

Library:Notify({ Title = "System", Description = "Game is fully loaded and ready!", Time = 4 })
task.wait(1.5)

-- =========================================================
-- ==== 🎭 SECURE DATA EXTRACTORS (ACTOR THREAD BYPASS) 🎭 ====
-- =========================================================
local function GetSecureData()
    local c = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local targetActor = c:FindFirstChild("Actor")
    if not targetActor or type(run_on_actor) ~= "function" then return nil end

    targetActor:SetAttribute("AOTR_DataReady", false)

    local extractionCode = ""

    if placeId == 13379208636 then
        -- 🔥 MENU PLACE: Ultra-fast lightweight scanner (Family Only)
        extractionCode = [[
            local PlayerData = nil
            for _, obj in pairs(getgc(true)) do
                if type(obj) == "table" then
                    local s1, hasSlots = pcall(function() return rawget(obj, "Slots") ~= nil end)
                    if s1 and hasSlots then
                        PlayerData = obj
                        break
                    end
                end
            end

            if PlayerData then
                local lp = game:GetService("Players").LocalPlayer
                local slotIdx = lp:GetAttribute("Slot") or "A"
                local actor = lp.Character:FindFirstChild("Actor")
                
                if actor and PlayerData.Slots and PlayerData.Slots[slotIdx] then
                    local sData = PlayerData.Slots[slotIdx]
                    if sData.Avatar and sData.Avatar.Family then
                        actor:SetAttribute("AOTR_Family", sData.Avatar.Family)
                    end
                    actor:SetAttribute("AOTR_DataReady", true)
                end
            end
        ]]
    else
        -- 🛡️ LOBBY/MISSION PLACE: Full scanner (Currency, Boosts, Family)
        extractionCode = [[
            local PlayerData = nil
            for _, obj in pairs(getgc(true)) do
                if type(obj) == "table" then
                    local s1, hasBoosts = pcall(function() return rawget(obj, "Boosts") ~= nil end)
                    local s2, hasSlots = pcall(function() return rawget(obj, "Slots") ~= nil end)
                    if s1 and s2 and hasBoosts and hasSlots then
                        PlayerData = obj
                        break
                    end
                end
            end

            if PlayerData then
                local lp = game:GetService("Players").LocalPlayer
                local slotIdx = lp:GetAttribute("Slot") or "A"
                local actor = lp.Character:FindFirstChild("Actor")
                
                if actor then
                    if PlayerData.Slots and PlayerData.Slots[slotIdx] then
                        local sData = PlayerData.Slots[slotIdx]
                        if sData.Currency then
                            actor:SetAttribute("AOTR_Gold", sData.Currency.Gold or 0)
                            actor:SetAttribute("AOTR_Gems", sData.Currency.Gems or 0)
                            actor:SetAttribute("AOTR_Canes", sData.Currency.Canes or 0)
                        end
                        if sData.Avatar and sData.Avatar.Family then
                            actor:SetAttribute("AOTR_Family", sData.Avatar.Family)
                        end
                    end
                    if PlayerData.Boosts then
                        actor:SetAttribute("AOTR_Boost_Gold", PlayerData.Boosts["Gold"] or 0)
                    end
                    actor:SetAttribute("AOTR_DataReady", true)
                end
            end
        ]]
    end

    pcall(function() run_on_actor(targetActor, extractionCode) end)
    
    local timeout = 0
    -- Faster timeout wait since the menu check is incredibly light
    while not targetActor:GetAttribute("AOTR_DataReady") and timeout < 50 do
        task.wait(0.05) 
        timeout = timeout + 1
    end

    local extracted = {
        Gold = targetActor:GetAttribute("AOTR_Gold") or 0,
        Gems = targetActor:GetAttribute("AOTR_Gems") or 0,
        Canes = targetActor:GetAttribute("AOTR_Canes") or 0,
        Family = targetActor:GetAttribute("AOTR_Family") or "Unknown",
        Boosts = { ["Gold"] = targetActor:GetAttribute("AOTR_Boost_Gold") or 0 }
    }
    return extracted
end

local function GetSecurePerks()
    local c = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local targetActor = c:FindFirstChild("Actor")
    if not targetActor or type(run_on_actor) ~= "function" then return nil end

    targetActor:SetAttribute("AOTR_DebugReady", false)
    targetActor:SetAttribute("AOTR_PerkJSON", "")

    local extractionCode = [[
        local HttpService = game:GetService("HttpService")
        local PlayerData = nil
        for _, obj in pairs(getgc(true)) do
            if type(obj) == "table" then
                local s1, hasBoosts = pcall(function() return rawget(obj, "Boosts") ~= nil end)
                local s2, hasSlots = pcall(function() return rawget(obj, "Slots") ~= nil end)
                if s1 and s2 and hasBoosts and hasSlots then 
                    PlayerData = obj 
                    break 
                end
            end
        end

        if PlayerData then
            local lp = game:GetService("Players").LocalPlayer
            local slotIdx = lp:GetAttribute("Slot") or "A"
            local actor = lp.Character:FindFirstChild("Actor")

            if actor and PlayerData.Slots and PlayerData.Slots[slotIdx] then
                local sData = PlayerData.Slots[slotIdx]
                local perksRoot = sData.Perks or (sData.Equipment and sData.Equipment.Perks) or (sData.Inventory and sData.Inventory.Perks)
                
                local currentPrestige = 0
                if type(sData.Progression) == "table" then
                    currentPrestige = tonumber(sData.Progression.Prestige) or 0
                end

                local extractedData = { StorageItems = {}, EquippedSlots = {}, Prestige = currentPrestige }

                if perksRoot then
                    if type(perksRoot.Storage) == "table" then
                        for uuid, perkInfo in pairs(perksRoot.Storage) do
                            if type(perkInfo) == "table" then extractedData.StorageItems[uuid] = tostring(perkInfo.Name) end
                        end
                    end
                    if type(perksRoot.Equipped) == "table" then
                        for slotName, assignedValue in pairs(perksRoot.Equipped) do
                            if type(assignedValue) == "string" then extractedData.EquippedSlots[tostring(slotName)] = assignedValue
                            elseif type(assignedValue) == "table" then extractedData.EquippedSlots[tostring(slotName)] = tostring(assignedValue.UUID or assignedValue.Id)
                            end
                        end
                    end
                end
                local s, j = pcall(function() return HttpService:JSONEncode(extractedData) end)
                actor:SetAttribute("AOTR_PerkJSON", s and j or "ERROR")
                actor:SetAttribute("AOTR_DebugReady", true)
            end
        end
    ]]

    pcall(function() run_on_actor(targetActor, extractionCode) end)

    local timeout = 0
    while not targetActor:GetAttribute("AOTR_DebugReady") and timeout < 50 do
        task.wait(0.1) timeout = timeout + 1
    end

    local rawJson = targetActor:GetAttribute("AOTR_PerkJSON")
    if rawJson == "" or rawJson == "ERROR" then return nil end

    local s, decoded = pcall(function() return HttpService:JSONDecode(rawJson) end)
    return s and decoded or nil
end

local function GetSecureSkills()
    local c = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local targetActor = c:FindFirstChild("Actor")
    if not targetActor or type(run_on_actor) ~= "function" then return nil end

    targetActor:SetAttribute("AOTR_SkillReady", false)
    targetActor:SetAttribute("AOTR_SkillJSON", "")

    local extractionCode = [[
        local HttpService = game:GetService("HttpService")
        local PlayerData = nil
        for _, obj in pairs(getgc(true)) do
            if type(obj) == "table" then
                local s1, hasBoosts = pcall(function() return rawget(obj, "Boosts") ~= nil end)
                local s2, hasSlots = pcall(function() return rawget(obj, "Slots") ~= nil end)
                if s1 and s2 and hasBoosts and hasSlots then 
                    PlayerData = obj 
                    break 
                end
            end
        end

        if PlayerData then
            local lp = game:GetService("Players").LocalPlayer
            local slotIdx = lp:GetAttribute("Slot") or "A"
            local actor = lp.Character:FindFirstChild("Actor")

            if actor and PlayerData.Slots and PlayerData.Slots[slotIdx] then
                local sData = PlayerData.Slots[slotIdx]
                local unlockedSkills = {}
                
                if sData.Skills and type(sData.Skills.Unlocked) == "table" then
                    for _, val in pairs(sData.Skills.Unlocked) do
                        unlockedSkills[tostring(val)] = true
                    end
                end
                
                local s, j = pcall(function() return HttpService:JSONEncode(unlockedSkills) end)
                actor:SetAttribute("AOTR_SkillJSON", s and j or "ERROR")
                actor:SetAttribute("AOTR_SkillReady", true)
            end
        end
    ]]

    pcall(function() run_on_actor(targetActor, extractionCode) end)

    local timeout = 0
    while not targetActor:GetAttribute("AOTR_SkillReady") and timeout < 50 do
        task.wait(0.1) timeout = timeout + 1
    end

    local rawJson = targetActor:GetAttribute("AOTR_SkillJSON")
    if rawJson == "" or rawJson == "ERROR" then return {} end

    local s, decoded = pcall(function() return HttpService:JSONDecode(rawJson) end)
    return s and decoded or {}
end

local function GetSecureFamilyStorage()
    local c = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local targetActor = c:FindFirstChild("Actor")
    if not targetActor or type(run_on_actor) ~= "function" then return {} end

    targetActor:SetAttribute("AOTR_FamStoreReady", false)
    targetActor:SetAttribute("AOTR_FamStoreJSON", "")

    local extractionCode = [[
        local HttpService = game:GetService("HttpService")
        local PlayerData = nil
        for _, obj in pairs(getgc(true)) do
            if type(obj) == "table" then
                -- 🔥 MENU FIX: Only scan for Slots, completely ignore Boosts
                local s1, hasSlots = pcall(function() return rawget(obj, "Slots") ~= nil end)
                if s1 and hasSlots then 
                    PlayerData = obj 
                    break 
                end
            end
        end

        if PlayerData then
            local lp = game:GetService("Players").LocalPlayer
            local slotIdx = lp:GetAttribute("Slot") or "A"
            local actor = lp.Character:FindFirstChild("Actor")

            if actor and PlayerData.Slots and PlayerData.Slots[slotIdx] then
                local sData = PlayerData.Slots[slotIdx]
                local stored = {}
                
                local famRoot = nil
                if sData.Inventory and type(sData.Inventory) == "table" and type(sData.Inventory.Families) == "table" then
                    famRoot = sData.Inventory.Families
                elseif type(sData.Families) == "table" then
                    famRoot = sData.Families
                end

                if famRoot then
                    for _, famData in pairs(famRoot) do
                        if type(famData) == "string" then
                            table.insert(stored, famData)
                        elseif type(famData) == "table" then
                            if famData.Family then table.insert(stored, tostring(famData.Family))
                            elseif famData.Name then table.insert(stored, tostring(famData.Name))
                            elseif famData.Id then table.insert(stored, tostring(famData.Id))
                            end
                        end
                    end
                end

                local s, j = pcall(function() return HttpService:JSONEncode(stored) end)
                actor:SetAttribute("AOTR_FamStoreJSON", s and j or "[]")
                actor:SetAttribute("AOTR_FamStoreReady", true)
            end
        end
    ]]

    pcall(function() run_on_actor(targetActor, extractionCode) end)

    local timeout = 0
    while not targetActor:GetAttribute("AOTR_FamStoreReady") and timeout < 50 do
        task.wait(0.1) timeout = timeout + 1
    end

    local rawJson = targetActor:GetAttribute("AOTR_FamStoreJSON")
    if rawJson == "" or rawJson == "ERROR" then return {} end

    local s, decoded = pcall(function() return HttpService:JSONDecode(rawJson) end)
    return s and decoded or {}
end

local function hasActiveBoost(boostName)
    local pData = GetSecureData()
    if pData and pData.Boosts then
        local remainingTime = pData.Boosts[boostName]
        if type(remainingTime) == "number" and remainingTime > 0 then return true end
    end
    return false
end

-- RARITY CLASSIFICATIONS
local MythicFamilies = {
    ["Fritz"] = true, ["Helos"] = true
}
local LegendaryFamilies = {
    ["Ackerman"] = true, ["Yeager"] = true, ["Reiss"] = true
}

local MapObjectives = {
    ["Shiganshina"] = {"Skirmish", "Breach", "Random"},
    ["Trost"]       = {"Skirmish", "Protect", "Random"},
    ["Outskirts"]   = {"Skirmish", "Escort", "Random"},
    ["Forest"]      = {"Skirmish", "Guard", "Random"},
    ["Utgard"]      = {"Skirmish", "Defend", "Random"},
    ["Docks"]       = {"Skirmish", "Stall", "Random"},
    ["Stohess"]     = {"Skirmish", "Random"},
    ["Chapel"]      = {"Skirmish", "Random"}
}

-- =========================================================
-- ==== PERK DICTIONARY & SKILL PATHS ====
-- =========================================================
local PerksDict = {
    Offense = { "Art of War", "Black Flash", "Blessed", "Butcher", "Carnifex", "Cripple", "Critical Hunter", "Everlasting Flame", "Eviscerate", "Flame Rhapsody", "Focus", "Forceful", "Hollow", "Kengo", "Lightweight", "Lucky", "Luminous", "Mangle", "Mighty", "Mutilate", "Peerless Focus", "Peerless Strength", "Sanctified", "Speedy", "Tyrant's Stare", "Unparalleled Strength", "Warchief", "Warrior", "Wind Rhapsody" },
    Body = { "Enhanced Metabolism", "Flawed Release", "Founder's Blessing", "Heavenly Restriction", "Indefatigable", "Maximum Firepower", "Perfect Form", "Perfect Soul", "Reckless Abandon" },
    Defense = { "Adaptation", "Aegis", "Enduring", "Font of Vitality", "Fortitude", "Hardy", "Heightened Vitality", "Immortal", "Invincible", "Peerless Constitution", "Protection", "Resilient", "Robust", "Safeguard", "Stalwart Durability", "Tough", "Trauma Battery", "Unbreakable", "Unyielding" },
    Support = { "Adrenaline", "Courage Catalyst", "Exhumation", "Experimental Shells", "Explosive Fortune", "First Aid", "Font of Inspiration", "Fully Stocked", "Gear Beginner", "Gear Expert", "Gear Intermediate", "Gear Master", "Munitions Expert", "Munitions Master", "Peerless Commander", "Siphoning", "Sixth Sense", "Solo", "Soulfeed", "Tatsujin" }
}

local FormattedPerksList = {"None"}
local FormattedToRaw = {}
local PerkCategoryMap = {}

for category, perkList in pairs(PerksDict) do
    for _, perkName in ipairs(perkList) do
        local formattedName = perkName .. " [" .. category .. "]"
        table.insert(FormattedPerksList, formattedName)
        FormattedToRaw[formattedName] = perkName
        PerkCategoryMap[perkName] = category
    end
end

table.sort(FormattedPerksList, function(a, b)
    if a == "None" then return true end
    if b == "None" then return false end
    return a < b
end)

local BasePaths = { ["Mid"] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13}, ["Left"] = {70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80}, ["Right"] = {38, 39, 40, 41, 42, 43, 44, 45} }
local SubPaths = { ["Critical (Mid)"] = {14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25}, ["Damage (Mid)"] = {26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37}, ["Regen (Left)"] = {81, 82, 83, 84, 85, 86, 87, 88, 89}, ["Cooldown (Left)"]= {90, 91, 92, 93, 94, 95, 96, 97, 98}, ["Health (Right)"] = {46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57}, ["Tank (Right)"] = {58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69} }
local BasePathMap = { ["Critical (Mid)"] = "Mid", ["Damage (Mid)"] = "Mid", ["Regen (Left)"] = "Left", ["Cooldown (Left)"] = "Left", ["Health (Right)"] = "Right", ["Tank (Right)"] = "Right" }

-- =========================================================
-- ==== MASTER QUEST AMOUNTS ====
-- =========================================================
local QuestAmounts = {
        ["Novice Adventurer"]=10, ["Seasoned Operative"]=25, ["Master of Missions"]=50, ["Elite Taskmaster"]=100, ["Legendary Quester"]=250, ["Completionist"]=500,
        ["Rookie Raider"]=10, ["Raid Veteran"]=25, ["Raid Commander"]=50, ["Raid Overlord"]=100, ["Raid Warlord"]=250, ["Raid Conqueror"]=500,
        ["Precise Striker"]=5, ["Critical Sniper"]=10, ["Devastating Precision"]=25, ["Critical Master"]=50, ["Critical Legend"]=100, ["Critical Demigod"]=250,
        ["Novice Wrecker"]=400, ["Demolition Expert"]=1600, ["Destruction Maestro"]=5500, ["Damage Dynamo"]=20000, ["Cataclysmic Force"]=70000, ["Devastation Virtuoso"]=150000,
        ["Penny Pincher"]=25000, ["Wealth Accumulator"]=100000, ["Treasure Hunter"]=400000, ["Fortune Hoarder"]=1000000, ["Money Magician"]=5000000, ["Currency Emperor"]=25000000,
        ["Guardian Angel"]=5, ["Rescuer Extraordinaire"]=10, ["Lifesaver Pro"]=25, ["Savior Supreme"]=50, ["Player's Champion"]=100, ["Ultimate Protector"]=250,
        ["Eye of the Storm"]=75, ["Leg Lacerator"]=150, ["Arm Annihilator"]=400, ["Titan Torturer"]=750, ["Titan Annihilator"]=1250, ["Titan's Nightmare"]=2500,
        ["Titan Hunter"]=100, ["Titan Slayer"]=250, ["Titan Executioner"]=500, ["Titan Butcher"]=1000, ["Titan Dominator"]=2500, ["Titan Conqueror"]=10000,
        ["Rookie Adventurer"]=10, ["Seasoned Warrior"]=25, ["Master of Experience"]=50, ["Legendary Ascendant"]=75, ["Divine Prestige"]=100, ["Ultimate Champion"]=125,
        ["Prestige Aspirant"]=1, ["Prestige Challenger"]=2, ["Prestige Enthusiast"]=3, ["Prestige Expert"]=4,
        ["Casual Explorer"]=5, ["Dedicated Adventurer"]=10, ["Seasoned Gamer"]=25, ["Endurance Champion"]=50, ["Timeless Immortal"]=100, ["Infinite Voyager"]=250,
        ["Shifting Apprentice"]=10, ["Shifting Adept"]=25, ["Shifting Expert"]=50, ["Shifting Master"]=100, ["Shifting Guru"]=125, ["Shifting Virtuoso"]=250,
        ["Skill Novice"]=100, ["Skill Practitioner"]=250, ["Skill Expert"]=500, ["Skill Master"]=1000, ["Skill Virtuoso"]=2500, ["Skill Prodigy"]=5000,
        ["Team Player"]=10, ["Teamwork Enthusiast"]=25, ["Cooperative Expert"]=50, ["Teamwork Specialist"]=75, ["Teamwork Virtuoso"]=150, ["Teamwork Maestro"]=250,
        ["Towers"]=3, ["Escort"]=1, ["Ice Burst Stones"]=3, ["Retrieve Missing Supplies"]=3, ["Defend Missing Supplies"]=1
}

-- =========================================================
-- ==== MENU TAB: SLOT & ROLL AUTOMATION ====
-- =========================================================
local MenuLeftBox = Tabs.Menu:AddLeftGroupbox("Slot Automation")

MenuLeftBox:AddToggle("EnableAutoSelect", {
    Text = "Enable Auto Select", Default = false,
    Callback = function(Value)
        if Value then
            if Running.EnableAutoSelect then return end
            Running.EnableAutoSelect = true
            local chosenSlot = Options.AutoSelectSlot.Value
            Library:Notify({ Title = "Auto Slot", Description = "Auto selected Slot " .. chosenSlot, Time = 3 })
            GetRemote:InvokeServer("Functions", "Select", chosenSlot)
        end
    end
})
MenuLeftBox:AddDropdown("AutoSelectSlot", { Text = "Auto Select Slot", Values = {"A", "B", "C"}, Multi = false, Default = 1 })

MenuLeftBox:AddToggle("AutoPlay", {
    Text = "Auto Play (Join Lobby)", Default = false,
    Callback = function(Value)
        if Value then
            if Running.AutoPlay then return end
            Running.AutoPlay = true
            task.spawn(function()
                Library:Notify({ Title = "Auto Play", Description = "Waiting for slot selection", Time = 3 })
                while Toggles.AutoPlay.Value do
                    local currentSlot = LocalPlayer:GetAttribute("Slot")
                    if currentSlot then
                        Library:Notify({ Title = "Auto Play", Description = "Slot " .. currentSlot .. " loaded teleporting to Lobby", Time = 3 })
                        pcall(function() GetRemote:InvokeServer("Functions", "Teleport", "Lobby", nil) end)
                        task.wait(5)
                    end
                    task.wait(0.5)
                end
                Running.AutoPlay = false
            end)
        end
    end
})

local MenuRightBox = Tabs.Menu:AddRightGroupbox("Roll Automation")

-- Webhook Function using a clean JSON Embed design
local function SendFamilyWebhook(familyName, rarity, spinsLeft)
    local webhookUrl = Options.DiscordWebhook.Value
    if not Toggles.EnableWebhook.Value or webhookUrl == "" then return end

    -- Colors based on dynamic rarity
    local embedColor = 5763719 -- Green for Target
    if rarity == "Mythic" then
        embedColor = 10181046 -- Purple for Mythic
    elseif rarity == "Legendary" then
        embedColor = 16753152 -- Gold for Legendary
    end

    local payload = {
        ["content"] = "@everyone",
        ["embeds"] = {{
            ["title"] = "🎲 Family Successfully Rolled!",
            ["type"] = "rich",
            ["color"] = embedColor,
            ["fields"] = {
                {
                    ["name"] = "🧑‍🤝‍🧑 Family Name",
                    ["value"] = "```\n" .. familyName .. "\n```",
                    ["inline"] = true
                },
                {
                    ["name"] = "✨ Rarity",
                    ["value"] = "```\n" .. rarity .. "\n```",
                    ["inline"] = true
                },
                {
                    ["name"] = "🔄 Spins Remaining",
                    ["value"] = "```\n" .. tostring(spinsLeft) .. "\n```",
                    ["inline"] = false
                }
            },
            ["footer"] = {
                ["text"] = "GabBobo Auto Roller • " .. os.date("%X")
            }
        }}
    }

    local jsonData = HttpService:JSONEncode(payload)
    local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    
    if httpRequest then
        task.spawn(function()
            pcall(function()
                httpRequest({
                    Url = webhookUrl,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = jsonData
                })
            end)
        end)
    end
end

MenuRightBox:AddToggle("AutoRoll", {
    Text = "Auto Roll Targets", Default = false,
    Callback = function(Value)
        if Value then
            if Running.AutoRoll then return end
            Running.AutoRoll = true
            Library:Notify({ Title = "Auto Roll", Description = "Initializing safe roller...", Time = 3 })
            
            task.spawn(function()
                -- 1. HEAVY CHECK ONCE AT THE START (Fast Menu Version)
                local pData = GetSecureData()
                local startingFamily = pData and pData.Family or "Unknown"
                
                -- Check if they already have a target equipped before we even spin
                local alreadyHasTarget = false
                if MythicFamilies[startingFamily] then
                    alreadyHasTarget = true
                else
                    for targetName, isEnabled in pairs(Options.FamiliesToStore.Value) do
                        if isEnabled and targetName == startingFamily then alreadyHasTarget = true break end
                    end
                end

                if alreadyHasTarget then
                    Library:Notify({ Title = "Auto Roll", Description = "You already have a target (" .. startingFamily .. ") equipped! Stopping.", Time = 5 })
                    Toggles.AutoRoll:SetValue(false)
                    Running.AutoRoll = false
                    return
                end

                Library:Notify({ Title = "Auto Roll", Description = "No target detected. Starting spins...", Time = 3 })

                -- 2. LIGHTWEIGHT FAST-ROLL LOOP (Relying strictly on Server Args)
                while Toggles.AutoRoll.Value do
                    
                    -- We capture exactly what the server outputs based on the exact debug trace
                    local success, spinsLeft, unknownVar, familyName = pcall(function() return GetRemote:InvokeServer("Family", "Roll") end)
                    
                    if not success or type(familyName) ~= "string" then 
                        task.wait(2) -- Server lag failsafe
                        continue 
                    end

                    if spinsLeft and tonumber(spinsLeft) <= 0 then
                        Library:Notify({ Title = "Auto Roll", Description = "You are out of spins!", Time = 5 })
                        Toggles.AutoRoll:SetValue(false) 
                        break
                    end
                    
                    Library:Notify({ Title = "Auto Roll", Description = "Rolled " .. familyName .. " | Spins left: " .. tostring(spinsLeft), Time = 1.5 })

                    local isTarget = false
                    local rarityAlert = "Target"

                    if MythicFamilies[familyName] then
                        isTarget = true
                        rarityAlert = "Mythic"
                    else
                        for targetName, isEnabled in pairs(Options.FamiliesToStore.Value) do
                            if isEnabled and targetName == familyName then 
                                isTarget = true 
                                if LegendaryFamilies[familyName] then
                                    rarityAlert = "Legendary"
                                else
                                    rarityAlert = "Target"
                                end
                                break 
                            end
                        end
                    end

                    if isTarget then
                        Library:Notify({ Title = "Auto Roll", Description = rarityAlert .. " rolled! Landed on " .. familyName, Time = 4 })
                        SendFamilyWebhook(familyName, rarityAlert, spinsLeft)
                        
                        task.wait(1) 

                        if Toggles.AutoDeposit.Value then
                            local storeSuccess, storeResult = pcall(function() return GetRemote:InvokeServer("Family", "Store") end)
                            
                            if storeSuccess and storeResult then
                                Library:Notify({ Title = "Auto Store", Description = "Successfully deposited " .. familyName .. "!", Time = 4 })
                                task.wait(2)
                            else
                                Library:Notify({ Title = "Store Error", Description = "Vault Full! Stopping Auto Roll to save " .. familyName, Time = 8 })
                                Toggles.AutoRoll:SetValue(false) 
                                break
                            end
                        else
                            Library:Notify({ Title = "Auto Roll", Description = rarityAlert .. " found! Auto Roll stopped.", Time = 6 })
                            Toggles.AutoRoll:SetValue(false) 
                            break
                        end
                    else
                        -- 3. THE GOLDEN BULLETPROOF DELAY
                        task.wait(3.8)
                    end
                end
                Running.AutoRoll = false
            end)
        end
    end
})

MenuRightBox:AddToggle("AutoDeposit", {
    Text = "Auto Deposit Targets", Default = false,
    Callback = function(Value)
        if Value then
            if Running.AutoDeposit then return end
            Running.AutoDeposit = true
            task.spawn(function()
                while Toggles.AutoDeposit.Value do
                    local pData = GetSecureData()
                    if pData and pData.Family then
                        local currentFamily = pData.Family
                        local isTarget = false

                        if MythicFamilies[currentFamily] then
                            isTarget = true
                        else
                            for targetName, isEnabled in pairs(Options.FamiliesToStore.Value) do
                                if isEnabled and targetName == currentFamily then isTarget = true break end
                            end
                        end

                        if isTarget then
                            -- Use the Server's direct Boolean response to verify storage success
                            local storeSuccess, storeResult = pcall(function() return GetRemote:InvokeServer("Family", "Store") end)

                            if storeSuccess and storeResult then
                                Library:Notify({ Title = "Auto Store", Description = "Deposited your equipped target " .. currentFamily .. "!", Time = 4 })
                            else
                                Library:Notify({ Title = "Store Error", Description = "Vault Full! Could not deposit " .. currentFamily, Time = 6 })
                                Toggles.AutoDeposit:SetValue(false)
                                break
                            end
                        end
                    end
                    task.wait(3)
                end
                Running.AutoDeposit = false
            end)
        end
    end
})

MenuRightBox:AddDropdown("FamiliesToStore", {
    Text = "Families to Store",
    Values = {"Ackerman", "Yeager", "Reiss", "Fritz", "Helos", "Tybur", "Zoe", "Leonhart", "Galliard", "Finger", "Braun", "Arlert", "Ksaver", "Smith", "Hoover", "Kirschtein", "Springer", "Braus"},
    Multi = true, Default = {}
})

MenuRightBox:AddInput("DiscordWebhook", {
    Default = "",
    Numeric = false,
    Finished = false,
    Text = "Discord Webhook URL",
    Tooltip = "Paste your full Discord webhook URL here",
    Placeholder = "https://discord.com/api/webhooks/..."
})

MenuRightBox:AddToggle("EnableWebhook", {
    Text = "Enable Discord Webhook", Default = false
})

-- NEW: Test Webhook Button
MenuRightBox:AddButton({
    Text = 'Test Webhook',
    Func = function()
        local webhookUrl = Options.DiscordWebhook.Value
        if webhookUrl == "" then
            Library:Notify({ Title = "Webhook Error", Description = "Please paste your Webhook URL first!", Time = 4 })
            return
        end

        local payload = {
            ["content"] = "@everyone",
            ["embeds"] = {{
                ["title"] = "🔧 Webhook Test Successful!",
                ["description"] = "Your Discord webhook is properly linked to GabBobo Auto Roller. You will now receive notifications when you roll Target or Mythic families.",
                ["type"] = "rich",
                ["color"] = 3447003, -- Blue
                ["footer"] = {
                    ["text"] = "GabBobo Auto Roller • " .. os.date("%X")
                }
            }}
        }

        local jsonData = HttpService:JSONEncode(payload)
        local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
        
        if httpRequest then
            task.spawn(function()
                local success, err = pcall(function()
                    httpRequest({
                        Url = webhookUrl,
                        Method = "POST",
                        Headers = {["Content-Type"] = "application/json"},
                        Body = jsonData
                    })
                end)
                if success then
                    Library:Notify({ Title = "Webhook", Description = "Test message sent to Discord successfully!", Time = 4 })
                else
                    Library:Notify({ Title = "Webhook Error", Description = "Failed to send. Please check your URL.", Time = 4 })
                end
            end)
        else
            Library:Notify({ Title = "Webhook Error", Description = "Your executor does not support HTTP requests.", Time = 4 })
        end
    end,
    DoubleClick = false,
    Tooltip = 'Click to send a test message to your Discord Server'
})

-- Button to check exactly what is in your family vault
MenuRightBox:AddButton({
    Text = 'Check Stored Families',
    Func = function()
        local stored = GetSecureFamilyStorage()
        if #stored > 0 then
            Library:Notify({ Title = "Vault Storage", Description = "Stored Families:\n" .. table.concat(stored, "\n"), Time = 6 })
        else
            Library:Notify({ Title = "Vault Storage", Description = "Your family storage is currently empty (or needs rejoin to refresh).", Time = 6 })
        end
    end,
    DoubleClick = false,
    Tooltip = 'Click to scan and view your stored families'
})

-- =========================================================
-- ==== STRICT MASTER SEQUENCE STATE MACHINE ====
-- =========================================================
local Sequence = {
    UpgradeFinished = false,
    SkillFinished   = false,
    PerkFinished    = false,
    BoostFinished   = false,
    QuestFinished   = false,
    AchieveFinished = false
}

local function SafeCheck(toggleName, sequenceFlag)
    local t = Toggles[toggleName]
    if t and t.Value and not sequenceFlag then return true end
    return false
end

local function IsWaitingForPreviousTask(currentTask)
    if currentTask == "Skill" then
        return SafeCheck("AutoUpgradeGear", Sequence.UpgradeFinished)
    elseif currentTask == "Perk" then
        return SafeCheck("AutoUpgradeGear", Sequence.UpgradeFinished) or
               SafeCheck("AutoSkillTree", Sequence.SkillFinished)
    elseif currentTask == "Boost" then
        return SafeCheck("AutoUpgradeGear", Sequence.UpgradeFinished) or
               SafeCheck("AutoSkillTree", Sequence.SkillFinished) or
               SafeCheck("AutoEquipPerk", Sequence.PerkFinished)
    elseif currentTask == "Quest" then
        return SafeCheck("AutoUpgradeGear", Sequence.UpgradeFinished) or
               SafeCheck("AutoSkillTree", Sequence.SkillFinished) or
               SafeCheck("AutoEquipPerk", Sequence.PerkFinished) or
               SafeCheck("AutoGoldBoost", Sequence.BoostFinished)
    elseif currentTask == "Achieve" then
        return SafeCheck("AutoUpgradeGear", Sequence.UpgradeFinished) or
               SafeCheck("AutoSkillTree", Sequence.SkillFinished) or
               SafeCheck("AutoEquipPerk", Sequence.PerkFinished) or
               SafeCheck("AutoGoldBoost", Sequence.BoostFinished) or
               SafeCheck("AutoClaimQuests", Sequence.QuestFinished)
    elseif currentTask == "Mission" then
        return SafeCheck("AutoUpgradeGear", Sequence.UpgradeFinished) or
               SafeCheck("AutoSkillTree", Sequence.SkillFinished) or
               SafeCheck("AutoEquipPerk", Sequence.PerkFinished) or
               SafeCheck("AutoGoldBoost", Sequence.BoostFinished) or
               SafeCheck("AutoClaimQuests", Sequence.QuestFinished) or
               SafeCheck("AutoClaimAchieve", Sequence.AchieveFinished)
    end
    return false
end


-- =========================================================
-- ==== LOBBY TAB: AUTO GEAR ====
-- =========================================================
local AutoGearBox = Tabs.Lobby:AddLeftGroupbox("Auto Gear")

AutoGearBox:AddToggle("AutoUpgradeGear", {
    Text = "Auto Upgrade Gear", Default = false,
    Callback = function(Value)
        if Value then
            if Running.AutoUpgradeGear then return end
            Running.AutoUpgradeGear = true
            Sequence.UpgradeFinished = false
            task.spawn(function()
                task.wait(2) 
                Library:Notify({ Title = "Auto Upgrade", Description = "Checking Gear Upgrades", Time = 2 })
                task.wait(1.5)

                local priorityOrder = {"ODM_Damage", "Crit_Chance", "Crit_Damage", "Blade_Durability"}
                local allUpgrades = {"ODM_Damage", "Crit_Chance", "Crit_Damage", "Blade_Durability", "ODM_Gas", "ODM_Range", "ODM_Control", "ODM_Speed"}
                local skippedUpgrades = {}

                local function buildOrderedList()
                    local ordered = {}
                    local selected = Options.SelectGearUpgrades.Value
                    for _, name in ipairs(priorityOrder) do if selected[name] then table.insert(ordered, name) end end
                    for _, name in ipairs(allUpgrades) do if selected[name] and not table.find(ordered, name) then table.insert(ordered, name) end end
                    return ordered
                end

                while Toggles.AutoUpgradeGear.Value do
                    local orderedList = buildOrderedList()
                    local hasAttemptedAnything = false

                    for _, upgradeName in ipairs(orderedList) do
                        if skippedUpgrades[upgradeName] then continue end

                        hasAttemptedAnything = true
                        if not Toggles.AutoUpgradeGear.Value then break end

                        local ok, result = pcall(function() return GetRemote:InvokeServer("S_Equipment", "Upgrade", {upgradeName}) end)
                        local cleanName = string.gsub(upgradeName, "_", " ")

                        if ok and result then
                            Library:Notify({ Title = "Auto Upgrade", Description = "Gear upgraded " .. cleanName, Time = 2 })
                            task.wait(0.25) 
                        else
                            Library:Notify({ Title = "Auto Upgrade", Description = "Upgrade skipped " .. cleanName .. " maxed or no gold", Time = 2 })
                            skippedUpgrades[upgradeName] = true
                            task.wait(0.25)
                        end
                    end

                    if not hasAttemptedAnything then
                        Library:Notify({ Title = "Sequence Queue", Description = "Finished gear upgrade queue. Moving to next task.", Time = 3 })
                        task.wait(1.5)
                        Sequence.UpgradeFinished = true
                        while Toggles.AutoUpgradeGear.Value do task.wait(1) end
                        break
                    end
                end
                Sequence.UpgradeFinished = false
                Running.AutoUpgradeGear = false
            end)
        else
            Sequence.UpgradeFinished = false
        end
    end
})

AutoGearBox:AddDropdown("SelectGearUpgrades", {
    Text = "Select Gear to Upgrade",
    Values = {"Blade_Durability", "ODM_Damage", "ODM_Gas", "ODM_Range", "ODM_Control", "Crit_Chance", "Crit_Damage", "ODM_Speed"},
    Multi = true, Default = {}
})

-- =========================================================
-- ==== LOBBY TAB: AUTO SKILL TREE ====
-- =========================================================
local AutoSkillBox = Tabs.Lobby:AddLeftGroupbox("Auto Skill Tree")

local PriorityList = {}
local OrderDisplay = AutoSkillBox:AddLabel("Priority Order: None")

local function UpdateOrderDisplay()
    if #PriorityList > 0 then
        OrderDisplay:SetText("Priority Order:\n" .. table.concat(PriorityList, " ➔ "))
    else
        OrderDisplay:SetText("Priority Order:\nNone")
    end
end

AutoSkillBox:AddToggle("AutoSkillTree", {
    Text = "Auto Upgrade Skills", Default = false,
    Callback = function(Value)
        if Value then
            if Running.AutoSkillTree then return end
            Running.AutoSkillTree = true
            Sequence.SkillFinished = false
            task.spawn(function()
                while Toggles.AutoSkillTree.Value and IsWaitingForPreviousTask("Skill") do task.wait(1) end
                if not Toggles.AutoSkillTree.Value then return end

                while Toggles.AutoSkillTree.Value do
                    local unlocked = GetSecureSkills()
                    if not unlocked then task.wait(1) continue end
                    
                    local targetIDToBuy = nil
                    
                    for _, pathName in ipairs(PriorityList) do
                        local requiredBase = BasePathMap[pathName]
                        local baseSeq = BasePaths[requiredBase]
                        
                        if baseSeq then
                            for _, id in ipairs(baseSeq) do
                                if not unlocked[tostring(id)] then
                                    targetIDToBuy = id
                                    break
                                end
                            end
                        end
                        if targetIDToBuy then break end
                        
                        local sequence = SubPaths[pathName]
                        if sequence then
                            for _, id in ipairs(sequence) do
                                if not unlocked[tostring(id)] then
                                    targetIDToBuy = id
                                    break
                                end
                            end
                        end
                        if targetIDToBuy then break end
                    end
                    
                    if targetIDToBuy then
                        task.wait(0.5) 
                        
                        local success, result = pcall(function() 
                            return GetRemote:InvokeServer("S_Equipment", "Unlock", {tostring(targetIDToBuy)}) 
                        end)
                        
                        if success and result ~= false and result ~= nil then
                            Library:Notify({ Title = "Auto Skill", Description = "Successfully unlocked Node " .. tostring(targetIDToBuy), Time = 2 })
                        else
                            Library:Notify({ Title = "Sequence Queue", Description = "Not enough SP/Gold. Skill Sequence finished.", Time = 4 })
                            Sequence.SkillFinished = true
                            while Toggles.AutoSkillTree.Value do task.wait(1) end
                            break
                        end
                    else
                        if #PriorityList > 0 then
                            Library:Notify({ Title = "Sequence Queue", Description = "Selected paths maxed! Skill Sequence finished.", Time = 4 })
                        else
                            Library:Notify({ Title = "Auto Skill", Description = "Please select a priority path first!", Time = 3 })
                        end
                        Sequence.SkillFinished = true
                        while Toggles.AutoSkillTree.Value do task.wait(1) end
                        break
                    end
                    task.wait(1)
                end
                Running.AutoSkillTree = false
            end)
        else
            Sequence.SkillFinished = false
        end
    end
})

AutoSkillBox:AddDropdown("SkillPriority", { 
    Text = "Skill Path Priority (Order Matters)", 
    Values = {"Critical (Mid)", "Damage (Mid)", "Regen (Left)", "Cooldown (Left)", "Health (Right)", "Tank (Right)"}, 
    Multi = true, 
    Default = {} 
})

Options.SkillPriority:OnChanged(function(values)
    for i = #PriorityList, 1, -1 do
        if not values[PriorityList[i]] then table.remove(PriorityList, i) end
    end
    for key, isSelected in pairs(values) do
        if isSelected and not table.find(PriorityList, key) then table.insert(PriorityList, key) end
    end
    UpdateOrderDisplay()
end)

-- =========================================================
-- ==== LOBBY TAB: SMART AUTO BOOSTS ====
-- =========================================================
local AutoBoostBox = Tabs.Lobby:AddLeftGroupbox("Auto Boosts")

local BoostData = {
    ["30 mins"] = { BuyId = 7, ItemName = "2x Gold Boost [30m]", GemPrice = 4499 },
    ["1 hr"]    = { BuyId = 8, ItemName = "2x Gold Boost [1h]",   GemPrice = 7999 },
    ["2 hr"]    = { BuyId = 9, ItemName = "2x Gold Boost [2h]",   GemPrice = 13999 }
}

AutoBoostBox:AddToggle("AutoGoldBoost", {
    Text = "Auto Buy & Use Gold Boost", Default = false,
    Callback = function(Value)
        if Value then
            if Running.AutoGoldBoost then return end
            Running.AutoGoldBoost = true
            Sequence.BoostFinished = false
            task.spawn(function()
                while Toggles.AutoGoldBoost.Value and IsWaitingForPreviousTask("Boost") do task.wait(1) end
                if not Toggles.AutoGoldBoost.Value then return end

                task.wait(2.5) 
                
                while Toggles.AutoGoldBoost.Value do
                    Library:Notify({ Title = "Auto Boost", Description = "Checking Gold Boosts", Time = 2 })
                    task.wait(1.5)
                    
                    if hasActiveBoost("Gold") then
                        Library:Notify({ Title = "Auto Boost", Description = "Gold Boost is already active skipping", Time = 2 })
                        task.wait(1.5)
                    else
                        Library:Notify({ Title = "Auto Boost", Description = "No active boost detected", Time = 2 })
                        task.wait(1.5)
                        
                        local pData = GetSecureData()
                        local currentGems = pData and pData.Gems or 0
                        
                        local selectedBoosts = Options.GoldBoostDurations.Value
                        local chosenCurrency = Options.GoldBoostCurrency.Value 
                        local successfullyUsedAny = false
                        local attemptedAny = false
                        
                        for duration, isSelected in pairs(selectedBoosts) do
                            if isSelected and Toggles.AutoGoldBoost.Value then
                                attemptedAny = true
                                local data = BoostData[duration]
                                
                                if data then
                                    local isAffordable = false
                                    local currentBalance = 0
                                    local itemPrice = 0
                                    local buyCategory = "2_Boosts"

                                    itemPrice = data.GemPrice
                                    isAffordable = currentGems >= itemPrice
                                    currentBalance = currentGems
                                    buyCategory = "1_Boosts"

                                    if isAffordable then
                                        Library:Notify({ Title = "Auto Boost", Description = "Affordable buying 1x " .. duration .. " with " .. chosenCurrency, Time = 2 })
                                        task.wait(1.5)
                                        
                                        local buySuccess, buyResult = pcall(function() return GetRemote:InvokeServer("S_Market", "Buy", buyCategory, data.BuyId, 1) end)
                                        task.wait(1.5) 
                                        
                                        if buySuccess and buyResult ~= nil and buyResult ~= false then
                                            Library:Notify({ Title = "Auto Boost", Description = "Bought " .. duration .. " attempting to use", Time = 2 })
                                            task.wait(1.5)
                                            
                                            local useSuccess = pcall(function() return GetRemote:InvokeServer("S_Inventory", "Item", data.ItemName) end)
                                            if useSuccess then successfullyUsedAny = true break
                                            else
                                                Library:Notify({ Title = "Auto Boost", Description = "Failed to use " .. duration .. " boost", Time = 2 })
                                                task.wait(1.5)
                                            end
                                        else
                                            Library:Notify({ Title = "Auto Boost", Description = "Server rejected buy request for " .. duration, Time = 2 })
                                            task.wait(1.5)
                                        end
                                    else
                                        local deficit = itemPrice - currentBalance
                                        local formattedDeficit = FormatNumberWithCommas(deficit)
                                        Library:Notify({ Title = "Auto Boost", Description = "Skipped need " .. formattedDeficit .. " " .. chosenCurrency .. " to buy boost", Time = 3 })
                                        task.wait(1.5)
                                    end
                                end
                            end
                        end
                        
                        if successfullyUsedAny then
                            Library:Notify({ Title = "Sequence Queue", Description = "Boost applied. Sequence finished.", Time = 2 })
                            task.wait(1.5)
                        elseif attemptedAny then
                            Library:Notify({ Title = "Sequence Queue", Description = "Finished checking boosts. Moving on.", Time = 2 })
                            task.wait(1.5)
                        end
                    end
                    
                    Sequence.BoostFinished = true
                    while Toggles.AutoGoldBoost.Value do task.wait(1) end
                    break
                end
                Running.AutoGoldBoost = false
            end)
        else
            Sequence.BoostFinished = false
        end
    end
})

AutoBoostBox:AddDropdown("GoldBoostDurations", { Text = "Gold Boost Options", Values = {"30 mins", "1 hr", "2 hr"}, Multi = true, Default = {} })
AutoBoostBox:AddDropdown("GoldBoostCurrency", { Text = "Currency to Use", Values = {"Gems"}, Multi = false, Default = 1 })

-- =========================================================
-- ==== LOBBY TAB: AUTO PERK ====
-- =========================================================
local AutoPerkBox = Tabs.Lobby:AddRightGroupbox("Auto Perk")

AutoPerkBox:AddToggle("AutoEquipPerk", {
    Text = "Auto Equip Perks", Default = false,
    Callback = function(Value)
        local LastLoadout = ""

        if Value then
            if Running.AutoEquipPerk then return end
            Running.AutoEquipPerk = true
            Sequence.PerkFinished = false
            task.spawn(function()
                while Toggles.AutoEquipPerk.Value and IsWaitingForPreviousTask("Perk") do task.wait(1) end
                if not Toggles.AutoEquipPerk.Value then return end

                while Toggles.AutoEquipPerk.Value do
                    local perkData = GetSecurePerks()
                    if not perkData then
                        task.wait(2)
                        continue
                    end
                    if perkData then
                        -- Build a dictionary of what is CURRENTLY equipped on each slot
                        -- Match UUID by checking both full UUID and partial match
                        local currentEquippedNames = {}
                        for slot, equippedUUID in pairs(perkData.EquippedSlots) do
                            local found = perkData.StorageItems[equippedUUID]
                            if not found then
                                -- Try partial UUID match
                                for uuid, name in pairs(perkData.StorageItems) do
                                    if uuid:sub(1, 8) == equippedUUID:sub(1, 8) then
                                        found = name
                                        break
                                    end
                                end
                            end
                            currentEquippedNames[slot] = found or "Unknown"
                        end

                        -- Build the "Current Loadout" string for the UI Notification
                        local loadoutDisplay = "Current Loadout:\n"
                        if perkData.Prestige == 0 then
                            loadoutDisplay = loadoutDisplay .. "Body: " .. (currentEquippedNames["Body"] or "None")
                        else
                            for _, slotName in ipairs({"Offense", "Body", "Defense", "Support"}) do
                                loadoutDisplay = loadoutDisplay .. slotName .. ": " .. (currentEquippedNames[slotName] or "None") .. "\n"
                            end
                        end

                        -- Notify the user of what they currently have equipped
                        if LastLoadout ~= loadoutDisplay then
                            Library:Notify({ Title = "Auto Perk Status", Description = loadoutDisplay, Time = 4 })
                            LastLoadout = loadoutDisplay
                        end

                        local priorities = {
                            Options.PerkPriority1.Value,
                            Options.PerkPriority2.Value,
                            Options.PerkPriority3.Value,
                            Options.PerkPriority4.Value
                        }
                        
                        local isPrestigeZero = (perkData.Prestige == 0)
                        local hasAnySelection = false
                        for _, v in ipairs(priorities) do if v ~= "None" then hasAnySelection = true break end end

                        if not hasAnySelection then
                            -- Do nothing if priority boxes are empty
                        elseif isPrestigeZero then
                            local highestFound = nil
                            local foundUUID = nil

                            for _, formattedName in ipairs(priorities) do
                                if formattedName == "None" then continue end
                                local rawName = FormattedToRaw[formattedName]
                                
                                for uuid, name in pairs(perkData.StorageItems) do
                                    if name == rawName then 
                                        highestFound = rawName
                                        foundUUID = uuid 
                                        break 
                                    end
                                end
                                if foundUUID then break end
                            end

                            if foundUUID then
                                -- Check if the highest priority perk is ALREADY EQUIPPED
                                if currentEquippedNames["Body"] ~= highestFound then
                                    task.wait(0.5)
                                    pcall(function() GetRemote:InvokeServer("S_Equipment", "Perk_State", foundUUID, "Equip", "Body") end)
                                    Library:Notify({ Title = "Auto Perk", Description = "Equipped " .. highestFound .. " to Body", Time = 3 })
                                    task.wait(2)
                                    LastLoadout = "" -- Force refresh loadout display next loop
                                end
                            end
                        else
                            local handledSlots = {}
                            local equipFired = false

                            for _, formattedName in ipairs(priorities) do
                                if formattedName == "None" then continue end
                                local rawName = FormattedToRaw[formattedName]
                                local nativeSlot = PerkCategoryMap[rawName]

                                if handledSlots[nativeSlot] then continue end

                                local foundUUID = nil
                                for uuid, name in pairs(perkData.StorageItems) do
                                    if name == rawName then foundUUID = uuid break end
                                end

                                if foundUUID then
                                    handledSlots[nativeSlot] = true
                                    
                                    -- Check if the highest priority perk is ALREADY EQUIPPED for this specific slot
                                    if currentEquippedNames[nativeSlot] ~= rawName then
                                        task.wait(0.5)
                                        pcall(function() GetRemote:InvokeServer("S_Equipment", "Perk_State", foundUUID, "Equip", nativeSlot) end)
                                        Library:Notify({ Title = "Auto Perk", Description = "Equipped " .. rawName .. " to " .. nativeSlot, Time = 3 })
                                        task.wait(2)
                                        equipFired = true
                                    end
                                end
                            end
                            if equipFired then LastLoadout = "" end -- Force refresh loadout display next loop
                        end
                    end
                    Sequence.PerkFinished = true
                    -- Equip done, idle until toggled off
                    while Toggles.AutoEquipPerk.Value do task.wait(2) end
                    break
                end
                Running.AutoEquipPerk = false
            end)
        else
            Sequence.PerkFinished = false
        end
    end
})

AutoPerkBox:AddDropdown("PerkPriority1", { Text = "Priority 1", Values = FormattedPerksList, Default = 1 })
AutoPerkBox:AddDropdown("PerkPriority2", { Text = "Priority 2", Values = FormattedPerksList, Default = 1 })
AutoPerkBox:AddDropdown("PerkPriority3", { Text = "Priority 3", Values = FormattedPerksList, Default = 1 })
AutoPerkBox:AddDropdown("PerkPriority4", { Text = "Priority 4", Values = FormattedPerksList, Default = 1 })


-- =========================================================
-- ==== LOBBY TAB: AUTO QUEST ====
-- =========================================================
local AutoQuestBox = Tabs.Lobby:AddLeftGroupbox("Auto Quest")

AutoQuestBox:AddToggle("AutoClaimQuests", {
    Text = "Auto Claim Quests", Default = false,
    Callback = function(Value)
        if Value then
            if Running.AutoClaimQuests then return end
            Running.AutoClaimQuests = true
            Sequence.QuestFinished = false
            task.spawn(function()
                while Toggles.AutoClaimQuests.Value and IsWaitingForPreviousTask("Quest") do task.wait(1) end
                if not Toggles.AutoClaimQuests.Value then return end

                local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                local targetActor = char:FindFirstChild("Actor")

                if not targetActor or type(run_on_actor) ~= "function" then
                    Library:Notify({ Title = "Auto Quest", Description = "Actor not found cannot scan", Time = 4 })
                    Sequence.QuestFinished = true
                    return
                end

                targetActor:SetAttribute("AOTR_QuestJSON", "")

                local extractionCode = [[
                    local HttpService = game:GetService("HttpService")
                    local PlayerData = nil
                    local MasterQuestData = nil

                    for _, obj in pairs(getgc(true)) do
                        if type(obj) == "table" then
                            local s1, hasSlots = pcall(function() return rawget(obj, "Slots") end)
                            if s1 and type(hasSlots) == "table" then 
                                PlayerData = obj 
                            end

                            local s2, isMaster = pcall(function()
                                return rawget(obj, "Main") ~= nil and rawget(obj, "Side") ~= nil and rawget(obj, "Daily") ~= nil
                            end)
                            if s2 and isMaster and not rawget(obj, "Slots") then
                                MasterQuestData = obj
                            end
                        end
                        if PlayerData and MasterQuestData then 
                            break 
                        end
                    end

                    if PlayerData then
                        local lp = game:GetService("Players").LocalPlayer
                        local slotIdx = lp:GetAttribute("Slot") or "A"
                        local actor = lp.Character:FindFirstChild("Actor")

                        if actor and type(PlayerData.Slots) == "table" and PlayerData.Slots[slotIdx] then
                            local sData = PlayerData.Slots[slotIdx]
                            local progress = sData.Quests or sData.Tasks or sData.Missions or sData.Daily or {}

                            local scanResults = {
                                Progress = progress,
                                Definitions = MasterQuestData or {}
                            }

                            local s, j = pcall(function() return HttpService:JSONEncode(scanResults) end)
                            actor:SetAttribute("AOTR_QuestJSON", s and j or "ERROR")
                        end
                    end
                ]]

                pcall(function() run_on_actor(targetActor, extractionCode) end)

                local timeout = 0
                while targetActor:GetAttribute("AOTR_QuestJSON") == "" and timeout < 50 do
                    task.wait(0.1)
                    timeout = timeout + 1
                end

                local rawJson = targetActor:GetAttribute("AOTR_QuestJSON")

                if rawJson ~= "" and rawJson ~= "ERROR" then
                    local s, decoded = pcall(function() return HttpService:JSONDecode(rawJson) end)

                    if s and type(decoded) == "table" then
                        local playerProgress = decoded.Progress
                        local masterDefs = decoded.Definitions
                        local targetCategories = {"Main", "Side", "Daily", "Weekly", "Regiment"}

                        local claimQueue = {}

                        for _, catName in ipairs(targetCategories) do
                            local progData = playerProgress[catName]
                            local defData = masterDefs[catName]

                            if progData then
                                for id, q in pairs(progData) do
                                    if type(q) == "table" and q.Tag and not q.Rewarded then
                                        local current = tonumber(q.Current) or 0
                                        local target = tonumber(q.Amount)

                                        if not target and QuestAmounts[q.Tag] then
                                            target = QuestAmounts[q.Tag]
                                        elseif not target and defData and defData[id] then
                                            target = tonumber(defData[id].Amount)
                                        end

                                        if target and current >= target then
                                            table.insert(claimQueue, {
                                                tag = q.Tag,
                                                category = catName
                                            })
                                        end
                                    end
                                end
                            end
                        end

                        if #claimQueue == 0 then
                            Library:Notify({ Title = "Sequence Queue", Description = "No claimable quests found. Sequence Finished.", Time = 3 })
                        else
                            Library:Notify({ Title = "Auto Quest", Description = "Found " .. #claimQueue .. " claimable quest(s) claiming now", Time = 3 })
                            task.wait(1)

                            for i, quest in ipairs(claimQueue) do
                                local ok, result = pcall(function()
                                    return GetRemote:InvokeServer("Functions", "Quest", quest.tag, quest.category)
                                end)

                                if ok and result then
                                    Library:Notify({ Title = "Auto Quest", Description = "Claimed " .. quest.tag, Time = 3 })
                                else
                                    Library:Notify({ Title = "Auto Quest", Description = "Failed " .. quest.tag, Time = 3 })
                                end

                                task.wait(0.5)
                            end

                            Library:Notify({ Title = "Sequence Queue", Description = "All queued quests claimed! Sequence Finished.", Time = 4 })
                        end
                    end
                else
                    Library:Notify({ Title = "Auto Quest", Description = "Failed to read quest data", Time = 3 })
                end

                Sequence.QuestFinished = true
                Running.AutoClaimQuests = false
                return
            end)
        else
            Sequence.QuestFinished = false
        end
    end
})

-- =========================================================
-- ==== LOBBY TAB: AUTO ACHIEVEMENT ====
-- =========================================================
local AutoAchieveBox = Tabs.Lobby:AddRightGroupbox("Auto Achievement")

local MasterTitles = {
    [1]  = { title = "Pioneer",         req = 15,        cat = "Wings of Valor" },
    [2]  = { title = "Trailblazer",     req = 30,        cat = "Wings of Valor" },
    [3]  = { title = "Virtuoso",        req = 45,        cat = "Wings of Valor" },
    [4]  = { title = "Apex",            req = 64,        cat = "Wings of Valor" },
    [5]  = { title = "Omnipotent",      req = 7,         cat = "Wings of Valor" },
    [6]  = { title = "Proficiency",     req = 10,        cat = "Technique Mastery" },
    [7]  = { title = "Tactical",        req = 1,         cat = "Technique Mastery" },
    [8]  = { title = "Prowess",         req = 2,         cat = "Technique Mastery" },
    [9]  = { title = "Mastery",         req = 3,         cat = "Technique Mastery" },
    [10] = { title = "Masterpiece",     req = 4,         cat = "Technique Mastery" },
    [11] = { title = "Unbroken",        req = 100,       cat = "Scout Domination" },
    [12] = { title = "Slayer",          req = 350,       cat = "Scout Domination" },
    [13] = { title = "Vanquisher",      req = 1500,      cat = "Scout Domination" },
    [14] = { title = "Conqueror",       req = 5000,      cat = "Scout Domination" },
    [15] = { title = "Connoisseur",     req = 10000,     cat = "Scout Domination" },
    [16] = { title = "Overlord",        req = 50000,     cat = "Scout Domination" },
    [17] = { title = "Bravery",         req = 50,        cat = "Scout Bravery" },
    [18] = { title = "Valiance",        req = 250,       cat = "Scout Bravery" },
    [19] = { title = "Valor",           req = 750,       cat = "Scout Bravery" },
    [20] = { title = "Heroism",         req = 2000,      cat = "Scout Bravery" },
    [21] = { title = "Titanic",         req = 7500,      cat = "Scout Bravery" },
    [22] = { title = "Fearless",        req = 20000,     cat = "Scout Bravery" },
    [23] = { title = "Avenger",         req = 1,         cat = "Scout Feats" },
    [24] = { title = "Crusader",        req = 1,         cat = "Scout Feats" },
    [25] = { title = "Maestro",         req = 1,         cat = "Scout Feats" },
    [26] = { title = "Supremacy",       req = 1,         cat = "Scout Feats" },
    [27] = { title = "Champion",        req = 1,         cat = "Scout Feats" },
    [28] = { title = "Guardian Angel",  req = 1,         cat = "True Scout" },
    [29] = { title = "Precision",       req = 1,         cat = "True Scout" },
    [30] = { title = "Vigilant",        req = 1,         cat = "True Scout" },
    [31] = { title = "Fallen",          req = 3,         cat = "Mortality Master" },
    [32] = { title = "Tenacity",        req = 10,        cat = "Mortality Master" },
    [33] = { title = "Resilience",      req = 25,        cat = "Mortality Master" },
    [34] = { title = "Victor",          req = 75,        cat = "Mortality Master" },
    [35] = { title = "Eternal",         req = 250,       cat = "Mortality Master" },
    [36] = { title = "Immortalized",    req = 500,       cat = "Mortality Master" },
    [37] = { title = "Resilient",       req = 100,       cat = "Shock Absorber" },
    [38] = { title = "Endurer",         req = 500,       cat = "Shock Absorber" },
    [39] = { title = "Tough",           req = 1500,      cat = "Shock Absorber" },
    [40] = { title = "Unyielding",      req = 10000,     cat = "Shock Absorber" },
    [41] = { title = "Indomitable",     req = 25000,     cat = "Shock Absorber" },
    [42] = { title = "Sharp",           req = 10000,     cat = "Razor Edge" },
    [43] = { title = "Edge",            req = 40000,     cat = "Razor Edge" },
    [44] = { title = "Lethal",          req = 250000,    cat = "Razor Edge" },
    [45] = { title = "Devastor",        req = 2000000,   cat = "Razor Edge" },
    [46] = { title = "Annihilator",     req = 10000000,  cat = "Razor Edge" },
    [47] = { title = "Fan",             req = 1,         cat = "Misc" },
    [48] = { title = "Recruit",         req = 1,         cat = "Misc" },
    [49] = { title = "Maximus",         req = 1,         cat = "Misc" },
    [50] = { title = "Mishap",          req = 1,         cat = "Misc" },
    [51] = { title = "Type O",          req = 1,         cat = "Misc" },
    [52] = { title = "Encounter",       req = 1,         cat = "Misc" },
    [53] = { title = "Initiate",        req = 50,        cat = "Operative Dominance" },
    [54] = { title = "Agent",           req = 100,       cat = "Operative Dominance" },
    [55] = { title = "Specialist",      req = 250,       cat = "Operative Dominance" },
    [56] = { title = "Veteran",         req = 500,       cat = "Operative Dominance" },
    [57] = { title = "Elite",           req = 1000,      cat = "Operative Dominance" },
    [58] = { title = "Legend",          req = 2500,      cat = "Operative Dominance" },
    [59] = { title = "Sharpshooter",    req = 30,        cat = "Battle Prowess" },
    [60] = { title = "Sentinel",        req = 1,         cat = "Battle Prowess" },
    [61] = { title = "Phantom Striker", req = 1,         cat = "Battle Prowess" },
    [62] = { title = "Death's Door",    req = 1,         cat = "Battle Prowess" },
    [63] = { title = "Devil",           req = 1,         cat = "Titan Mastery" },
    [64] = { title = "Vanguard",        req = 1,         cat = "Titan Mastery" },
    [65] = { title = "Synthesis",       req = 1,         cat = "Titan Mastery" },
    [66] = { title = "Resonator",       req = 1,         cat = "Titan Mastery" },
    [67] = { title = "Warbringer",      req = 1,         cat = "Titan Mastery" },
    [68] = { title = "Prime",           req = 1,         cat = "Seasonal" },
    [69] = { title = "Nexus",           req = 1,         cat = "Seasonal" },
    [70] = { title = "Stormwalker",     req = 1,         cat = "Seasonal" },
    [71] = { title = "Singularity",     req = 1,         cat = "Seasonal" },
}

AutoAchieveBox:AddToggle("AutoClaimAchieve", {
    Text = "Auto Claim Achievements", Default = false,
    Callback = function(Value)
        if Value then
            if Running.AutoClaimAchieve then return end
            Running.AutoClaimAchieve = true
            Sequence.AchieveFinished = false
            task.spawn(function()
                while Toggles.AutoClaimAchieve.Value and IsWaitingForPreviousTask("Achieve") do task.wait(1) end
                if not Toggles.AutoClaimAchieve.Value then return end

                local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                local targetActor = char:FindFirstChild("Actor")

                if not targetActor or type(run_on_actor) ~= "function" then
                    Library:Notify({ Title = "Auto Achievement", Description = "Actor not found cannot scan", Time = 4 })
                    Sequence.AchieveFinished = true
                    return
                end

                targetActor:SetAttribute("AOTR_AchieveJSON", "")

                local extractionCode = [[
                    local HttpService = game:GetService("HttpService")
                    local PlayerData = nil

                    for _, obj in pairs(getgc(true)) do
                        if type(obj) == "table" then
                            local s1, slotsVal = pcall(function() return rawget(obj, "Slots") end)
                            if s1 and type(slotsVal) == "table" then
                                local s2, hasBoosts = pcall(function() return rawget(obj, "Boosts") ~= nil end)
                                if s2 and hasBoosts then 
                                    PlayerData = obj 
                                    break 
                                end
                            end
                        end
                    end

                    if PlayerData then
                        local lp = game:GetService("Players").LocalPlayer
                        local slotIdx = lp:GetAttribute("Slot") or "A"
                        local actor = lp.Character:FindFirstChild("Actor")

                        if actor and type(PlayerData.Slots[slotIdx]) == "table" then
                            local sData = PlayerData.Slots[slotIdx]
                            local titles = sData.Titles or {}
                            local s, j = pcall(function() return HttpService:JSONEncode(titles) end)
                            actor:SetAttribute("AOTR_AchieveJSON", s and j or "ERROR")
                        end
                    end
                ]]

                pcall(function() run_on_actor(targetActor, extractionCode) end)

                local timeout = 0
                while targetActor:GetAttribute("AOTR_AchieveJSON") == "" and timeout < 50 do
                    task.wait(0.1)
                    timeout = timeout + 1
                end

                local rawJson = targetActor:GetAttribute("AOTR_AchieveJSON")

                if rawJson ~= "" and rawJson ~= "ERROR" then
                    local s, titlesData = pcall(function() return HttpService:JSONDecode(rawJson) end)

                    if s and type(titlesData) == "table" then
                        local claimQueue = {}

                        for i, entry in ipairs(titlesData) do
                            if type(entry) == "table" and not entry.Owned then
                                local current = tonumber(entry.Current) or 0
                                local def = MasterTitles[i]
                                if def and current >= def.req then
                                    table.insert(claimQueue, { index = i, title = def.title, cat = def.cat })
                                end
                            end
                        end

                        if #claimQueue == 0 then
                            Library:Notify({ Title = "Sequence Queue", Description = "No claimable achievements found. Sequence Finished.", Time = 3 })
                        else
                            local claimedNames = {}
                            for _, achieve in ipairs(claimQueue) do
                                local ok, result = pcall(function()
                                    return GetRemote:InvokeServer("S_Achievements", "Claim", achieve.index)
                                end)
                                if ok and result then
                                    table.insert(claimedNames, achieve.title)
                                end
                                task.wait(0.5)
                            end

                            if #claimedNames > 0 then
                                Library:Notify({
                                    Title = "Sequence Queue: Claimed Achievements",
                                    Description = table.concat(claimedNames, "\n"),
                                    Time = 6
                                })
                            else
                                Library:Notify({ Title = "Auto Achievement", Description = "No achievements were claimed", Time = 3 })
                            end
                        end
                    end
                else
                    Library:Notify({ Title = "Auto Achievement", Description = "Failed to read achievement data", Time = 3 })
                end

                Sequence.AchieveFinished = true
                Running.AutoClaimAchieve = false
                return
            end)
        else
            Sequence.AchieveFinished = false
        end
    end
})

-- =========================================================
-- ==== LOBBY TAB: AUTO MISSION ====
-- =========================================================
local AutoMissionBox = Tabs.Lobby:AddRightGroupbox("Auto Mission")

AutoMissionBox:AddToggle("AutoCreateMission", {
    Text = "Auto Create & Start Mission", Default = false,
    Callback = function(Value)
        if Value then
            if Running.AutoCreateMission then return end
            Running.AutoCreateMission = true
            task.spawn(function()
                task.wait(3) 
                
                local function getMyMission()
                    local missionsFolder = ReplicatedStorage:FindFirstChild("Missions")
                    if missionsFolder then
                        for _, mission in pairs(missionsFolder:GetChildren()) do
                            if mission:FindFirstChild("Leader") and mission.Leader.Value == LocalPlayer.Name then return mission end
                        end
                    end
                    return nil
                end
                
                local LastWaitNotification = 0
                while Toggles.AutoCreateMission.Value do
                    if IsWaitingForPreviousTask("Mission") then
                        if os.clock() - LastWaitNotification > 5 then
                            Library:Notify({ Title = "Auto Mission", Description = "Waiting for Sequence Queue to finish...", Time = 2 })
                            LastWaitNotification = os.clock()
                        end
                        task.wait(1) 
                        continue 
                    end
                    
                    Library:Notify({ Title = "Sequence Queue", Description = "All tasks complete. Creating lobby.", Time = 2 })
                    task.wait(1.5)
                    
                    -- Reset the Run Counter so the Mission Place starts counting fresh from 0
                    pcall(function() writefile("GabBobo_RunCount.txt", "0") end)
                    
                    if getMyMission() then pcall(function() GetRemote:InvokeServer("S_Missions", "Leave") end) task.wait(1) end
                
                    local mType = Options.MissionType.Value
                    local mMap = Options.MissionMap.Value
                    local mObj = Options.MissionObjective.Value
                    local mDiff = Options.MissionDifficulty.Value
                    local missionCreated = false
                    
                    if mDiff == "Hardest" then
                        local diffOrder = mType == "Raids" and {"Aberrant", "Severe", "Hard"} or {"Aberrant", "Severe", "Hard", "Normal", "Easy"}
                        for _, diff in ipairs(diffOrder) do
                            if not Toggles.AutoCreateMission.Value then break end
                            pcall(function() GetRemote:InvokeServer("S_Missions", "Create", { Difficulty = diff, Type = mType, Objective = mObj, Name = mMap }) end)
                            task.wait(1.5)
                            if getMyMission() then
                                missionCreated = true
                                Library:Notify({ Title = "Auto Mission", Description = "Successfully created " .. diff .. " lobby", Time = 2 })
                                task.wait(1.5) break
                            end
                        end
                    else
                        pcall(function() GetRemote:InvokeServer("S_Missions", "Create", { Difficulty = mDiff, Type = mType, Objective = mObj, Name = mMap }) end)
                        task.wait(1.5)
                        if getMyMission() then
                            missionCreated = true
                            Library:Notify({ Title = "Auto Mission", Description = "Successfully created " .. mDiff .. " lobby", Time = 2 })
                            task.wait(1.5)
                        end
                    end
                    
                    if missionCreated and Toggles.AutoCreateMission.Value then
                        local selectedMods = Options.MissionModifiers.Value
                        if selectedMods then
                            for modName, isSelected in pairs(selectedMods) do
                                if isSelected and Toggles.AutoCreateMission.Value then pcall(function() GetRemote:InvokeServer("S_Missions", "Modify", modName) end) task.wait(0.5) end
                            end
                        end
                        task.wait(1)
                        if Toggles.AutoCreateMission.Value then pcall(function() GetRemote:InvokeServer("S_Missions", "Start") end) end
                    else
                        if Toggles.AutoCreateMission.Value then
                            Library:Notify({ Title = "Auto Mission", Description = "Failed to create mission retrying in 5s", Time = 2 })
                            task.wait(2)
                        end
                    end
                    task.wait(5)
                end
                Running.AutoCreateMission = false
            end)
        end
    end
})

AutoMissionBox:AddDropdown("MissionType", { Text = "Mission Type", Values = {"Missions", "Raids"}, Default = 1, Multi = false })
AutoMissionBox:AddDropdown("MissionMap", { Text = "Map", Values = {"Shiganshina", "Trost", "Outskirts", "Forest", "Utgard", "Docks", "Stohess", "Chapel"}, Default = 1, Multi = false })
AutoMissionBox:AddDropdown("MissionObjective", { Text = "Objective", Values = MapObjectives["Shiganshina"], Default = 1, Multi = false })

Options.MissionMap:OnChanged(function()
    local selectedMap = Options.MissionMap.Value
    local newObjectivesList = MapObjectives[selectedMap] or {"Skirmish", "Random"}
    Options.MissionObjective:SetValues(newObjectivesList)
    Options.MissionObjective:SetValue(newObjectivesList[1])
end)

AutoMissionBox:AddDropdown("MissionDifficulty", { Text = "Difficulty", Values = {"Easy", "Normal", "Hard", "Severe", "Aberrant", "Hardest"}, Default = 6, Multi = false })
AutoMissionBox:AddDropdown("MissionModifiers", { Text = "Modifiers", Values = {"No Perks", "No Skills", "No Memories", "Nightmare", "Oddball", "Injury Prone", "Chronic Injuries", "Fog", "Glass Cannon", "Time Trial", "Boring", "Simple"}, Multi = true, Default = {} })

-- =========================================================
-- ==== VISIBILITY & TAB MANAGEMENT ====
-- =========================================================
task.spawn(function()
        local lastState = nil
        while not Library.Unloaded do
                local currentPlace = game.PlaceId
                if lastState ~= currentPlace then
                        lastState = currentPlace
                        Tabs.Menu:SetVisible(currentPlace == 13379208636)
                        Tabs.Lobby:SetVisible(currentPlace == 14916516914)
                        Tabs.Mission:SetVisible(currentPlace ~= 13379208636 and currentPlace ~= 14916516914)
                end
                task.wait(1)
        end
end)

SaveManager:SetLibrary(Library)
ThemeManager:SetFolder("GabBoboBading/aotr")

if placeId == 13379208636 then SaveManager:SetFolder("GabBoboBading/aotr/Menu")
elseif placeId == 14916516914 then SaveManager:SetFolder("GabBoboBading/aotr/Lobby")
else SaveManager:SetFolder("GabBoboBading/aotr/Mission") end

SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:LoadAutoloadConfig()
