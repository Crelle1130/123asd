-- aotr
repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local lp = Players.LocalPlayer 

repeat task.wait() until lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local PlayerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local remotesFolder = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Remotes")
local getRemote = remotesFolder:WaitForChild("GET")
local postRemote = remotesFolder:WaitForChild("POST")
local vim = game:GetService("VirtualInputManager")
local INTERFACE = PlayerGui:WaitForChild("Interface")
local rewards = INTERFACE:FindFirstChild("Rewards")
local statsFrame = rewards and rewards.Main.Info.Main.Stats or nil
local itemsFrame = rewards and rewards.Main.Info.Main.Items or nil
local customisation = INTERFACE:FindFirstChild("Customisation") or nil
local familyFrame = customisation and customisation:FindFirstChild("Family") or nil
local rollButton = familyFrame and familyFrame.Buttons_2.Roll or nil

local V3_ZERO = Vector3.new(0, 0, 0)

local lastPlayerData, lastPlayerDataTime = nil, 0
local function GetPlayerData()
	if os.clock() - lastPlayerDataTime < 0.5 and lastPlayerData then return lastPlayerData end
	local args = {
		"Functions",
		"Settings",
		"Get"
	}
	lastPlayerData = getRemote:InvokeServer(unpack(args))
	lastPlayerDataTime = os.clock()	
	return lastPlayerData
end

-- Map data and plr data don't update when I call them so I only need to call them when i need them, not in a loop

local mapData = nil

local startLoadTime = os.clock()
local isLobby = game.PlaceId == 14916516914

repeat
    task.wait(1)
    mapData = getRemote:InvokeServer("Data", "Copy")
    if not mapData then
        lastPlayerData = nil -- force refresh (bypass cache)
        GetPlayerData()
    end
    -- If we're not in the lobby, we should wait longer for mapData to populate
until mapData ~= nil or (lastPlayerData ~= nil and (isLobby or os.clock() - startLoadTime > 15))

if mapData then
	if mapData.Map.Type == "Raids" then
		repeat task.wait() until workspace:GetAttribute("Finalised")
	end
end
local function checkMission()
	local activeType = workspace:GetAttribute("Type")
	if activeType then return true end
	
    mapData = getRemote:InvokeServer("Data", "Copy")
    return mapData ~= nil and mapData.Map ~= nil and mapData.Slots ~= nil
end

local familyRaritiesOptions = {
	"Rare",
	"Epic",
	"Legendary",
	"Mythical"
}
-- Config system for persistent dropdown state
if not isfolder("./GabBoboBading") then makefolder("./GabBoboBading") end
if not isfolder("./GabBoboBading/aotr") then makefolder("./GabBoboBading/aotr") end

-- Identify the current place
local currentEnv = "Mission"
if game.PlaceId == 14916516914 then
    currentEnv = "Lobby"
elseif game.PlaceId == 13379208636 then
    currentEnv = "MainMenu"
end

-- Create completely separated sub-folders
if not isfolder("./GabBoboBading/aotr/" .. currentEnv) then 
    makefolder("./GabBoboBading/aotr/" .. currentEnv) 
end

local ConfigFile = "./GabBoboBading/aotr/" .. currentEnv .. "/dropdown_config.json"
local returnCounterPath = "./GabBoboBading/aotr/return_lobby_counter.txt"
local HttpService = game:GetService("HttpService")

local function LoadConfig()
	if not isfile(ConfigFile) then
		return { Missions = {}, Raids = {}, DeleteMap = false }
	end
	local success, config = pcall(HttpService.JSONDecode, HttpService, readfile(ConfigFile))
	return success and config or { Missions = {}, Raids = {}, DeleteMap = false }
end

local function SaveConfig(config)
	pcall(writefile, ConfigFile, HttpService:JSONEncode(config))
end

local DropdownConfig = LoadConfig()
getgenv().AutoExec = false
getgenv().AutoRoll = false
getgenv().AutoSlot = false
getgenv().AutoUpgrade = false
getgenv().AutoPerk = false
getgenv().AutoSkillTree = false
getgenv().AutoStart = false
getgenv().AutoChest = false
getgenv().AutoRetry = false
getgenv().AutoSkip = false
getgenv().AutoPrestige = false
getgenv().AutoFailsafe = false
getgenv().AutoExecute = false
getgenv().RewardWebhook = false
getgenv().MythicalFamilyWebhook = false
getgenv().AutoReturnLobby = false
getgenv().OpenSecondChest = false
getgenv().DeleteMap = DropdownConfig.DeleteMap or false
if not isfile(returnCounterPath) then writefile(returnCounterPath, "0") end

getgenv().CurrentStatusLabel = nil
function UpdateStatus(text)
	if getgenv().CurrentStatusLabel then 
		getgenv().CurrentStatusLabel:SetText("Status: " .. text) 
	end
end

local AutoFarm = {}
AutoFarm._running = false

getgenv().AutoFarmConfig = {
	AttackCooldown = 1,
	ReloadCooldown = 1,
	AttackRange = 150,
	MoveSpeed = 400,
	HeightOffset = 250,
	MovementMode = "Hover",
}

getgenv().MasteryFarmConfig = {
	Enabled = false,
	Mode = "Both",
}

task.spawn(function()
	while true do
		local Injuries = lp.Character:FindFirstChild("Injuries")
		if Injuries then
			for i, v in Injuries:GetChildren() do
				v:Destroy()
			end
		end
		task.wait(1)
	end
end)

local function TeleportToLobbySafe()
	local pGui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
	if pGui then
		local loadingInterface = pGui:FindFirstChild("Loading_Interface")
		if loadingInterface and loadingInterface:FindFirstChild("Loader") then
			loadingInterface.Loader.BackgroundTransparency = 0
			loadingInterface.Loader.Visible = true
			if loadingInterface.Loader:FindFirstChild("Title") then
				loadingInterface.Loader.Title.Visible = true
			end
		end
	end
	task.wait(0.5)
	pcall(function()
		TeleportService:Teleport(14916516914, lp)
	end)
end

function AutoFarm:Start()
	if self._running then return end
	
	if isLobby then
		return
	end

	self._running = true
	task.spawn(function()
		UpdateStatus("Waiting for mission...")
		
		local function checkReady()
			local char = lp.Character
			local playerReady = char and (char:GetAttribute("Shifter") or (char:FindFirstChild("Main") and char.Main:FindFirstChild("W")))
			
			local mapReady = workspace:FindFirstChild("Unclimbable") 
				and workspace.Unclimbable:FindFirstChild("Reloads")
				and workspace.Unclimbable.Reloads:FindFirstChild("GasTanks")
				and workspace.Unclimbable.Reloads.GasTanks:FindFirstChild("Refill")
				
			local titans = workspace:FindFirstChild("Titans")
			local titansReady = false
			if titans then
				for _, v in ipairs(titans:GetChildren()) do
					if v:FindFirstChild("Fake") and v.Fake:FindFirstChild("Head") and v.Fake.Head:FindFirstChild("Header") then
						titansReady = true
						break
					end
				end
			end
			
			return playerReady and mapReady and titansReady
		end

		local startTime = os.clock()
		while self._running and not checkReady() do
			if os.clock() - startTime > 10 then 
				if getgenv().Library then
					getgenv().Library:Notify({
						Title = "GabBoboBading",
						Description = "Still waiting for mission assets to load...",
						Time = 5
					})
				end
				startTime = os.clock()
			end
			task.wait(1)
		end

		if not self._running then return end
		UpdateStatus("Farming")

		local titansFolder = workspace:FindFirstChild("Titans")
		local lastAttack = 0
		local currentChar, root, charParts = nil, nil, {}

		INTERFACE.ChildAdded:Connect(function(v)
			if getgenv().DeleteDamageText and tonumber(v.Name) then
				task.wait(0.05)
				if v and v.Parent then v:Destroy() end
			end
		end)
		
		local bossNames = {Attack_Titan = true, Armored_Titan = true, Female_Titan = true}
		local attackTitanSpawnTime = nil
		local AttackRangeSq = getgenv().AutoFarmConfig.AttackRange * getgenv().AutoFarmConfig.AttackRange

		local function updateCharState()
			local char = lp.Character
			if not char then return false end
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if not hrp then return false end

			if char ~= currentChar then
				currentChar = char
				root = hrp
				charParts = {}
				for _, p in ipairs(char:GetDescendants()) do
					if p:IsA("BasePart") then
						p.CanCollide = false
						table.insert(charParts, p)
					end
				end
			end
			return true
		end

		local validNapes = {}
		local nextTitanCacheUpdate = 0
		local nextObjectiveCacheUpdate = 0
		local cachedObjectivePart = nil

		local masteryComboIndex = 1
		local lastMasteryPunch = 0

		while self._running do
			if lp:GetAttribute("Cutscene") then
				task.wait()
				continue
			end

			if not checkMission() then
				UpdateStatus("Waiting for mission...")
				task.wait(1)
				continue
			end

			local slotIndex = lp:GetAttribute("Slot")
			local slotData = slotIndex and mapData and mapData.Slots and mapData.Slots[slotIndex]

			if not slotData then
				UpdateStatus("Waiting for data...")
				task.wait(1)
				continue
			end

			if slotData.Weapon == "Blades" then 
				getgenv().AutoFarmConfig.AttackCooldown = 0.15 
			else 
				getgenv().AutoFarmConfig.AttackCooldown = 1 
			end

			if getgenv().AutoFailsafe then
				if not self.missionStartTime then self.missionStartTime = os.clock() end
				
				local missionElapsedTime = os.clock() - self.missionStartTime
				if missionElapsedTime >= 900 then 
					self:Stop()
					TeleportToLobbySafe()
					break
				end
			end

			local playerCount = workspace:GetAttribute("Player_Count") or #Players:GetPlayers()
			if getgenv().SoloOnly and playerCount > 1 then
				self:Stop()
				TeleportToLobbySafe()
				break
			end
			
			if not updateCharState() then task.wait(); continue end

			titansFolder = workspace:FindFirstChild("Titans") or titansFolder

			local ws_ObjectiveFolder = workspace:FindFirstChild("Unclimbable") and workspace.Unclimbable:FindFirstChild("Objective") 
			local rs_ObjectiveFolder = ReplicatedStorage:FindFirstChild("Objectives") 
			local mapType = workspace:GetAttribute("Type") or (mapData and mapData.Map and mapData.Map.Type)

			local isArmoredRaid = ws_ObjectiveFolder:FindFirstChild("Armored_Boss")
			local isFemaleRaid = rs_ObjectiveFolder:FindFirstChild("Defeat_Annie")
			local femaleExists = ws_ObjectiveFolder:FindFirstChild("Female_Boss")
			local attackExists = ws_ObjectiveFolder:FindFirstChild("Attack_Boss")
			local hasReinerObjective = rs_ObjectiveFolder:FindFirstChild("Defeat_Reiner")

			if isFemaleRaid and not femaleExists and not attackExists then
				task.wait()
				continue
			end

			for i = 1, #charParts do
				local p = charParts[i]
				if p and p.Parent then p.CanCollide = false end
			end

			local now = os.clock()
			local isShifted = currentChar and currentChar:GetAttribute("Shifter") or false
			
			if getgenv().MasteryFarmConfig.Enabled then
				local shiftReady = lp:GetAttribute("Bar") and lp:GetAttribute("Bar") == 100

				if not isShifted and shiftReady then
					repeat 
						getRemote:InvokeServer("S_Skills", "Usage", "999", false) 
						task.wait(1) 
					until not self._running or (lp.Character and lp.Character:GetAttribute("Shifter"))
					continue
				end
			end
			if now >= nextTitanCacheUpdate then
				nextTitanCacheUpdate = now + 0.1
				table.clear(validNapes) 
				for _, v in ipairs(titansFolder:GetChildren()) do
					if v:GetAttribute("Killed") then continue end
					local hit = v:FindFirstChild("Hitboxes") and v.Hitboxes:FindFirstChild("Hit")
					if hit then
						local fake = v:FindFirstChild("Fake")
						if fake and fake:FindFirstChild("Collision") and not fake.Collision.CanCollide then continue end
						local nape = hit:FindFirstChild("Nape")
						if nape then table.insert(validNapes, nape) end
					end
				end
			end

			local rootPos = root.Position
			local referencePos = rootPos
			local objectiveFound = false

			if now >= nextObjectiveCacheUpdate then
				nextObjectiveCacheUpdate = now + 1
				cachedObjectivePart = nil
				if ws_ObjectiveFolder then
					for _, desc in ipairs(ws_ObjectiveFolder:GetDescendants()) do
						if desc:IsA("BillboardGui") and desc.Parent and desc.Parent:IsA("BasePart") then
							cachedObjectivePart = desc.Parent
							break
						end
					end
				end
			end

			if cachedObjectivePart and cachedObjectivePart.Parent then
				referencePos = cachedObjectivePart.Position
				objectiveFound = true
			end

			local useRangeLimit = objectiveFound and isArmoredRaid and not hasReinerObjective
			local closestDist, closestNape = math.huge, nil
			local closestIsBoss = false
			local bossDist, bossHitPoint = math.huge, nil
			local attackTitanFound = false
			local highestZ = -math.huge
			local isStall = mapData and mapData.Map and mapData.Map.Objective == "Stall"

			local bossIsRoaring = false

			for i = 1, #validNapes do
				local nape = validNapes[i]
				if not nape.Parent then continue end

				local titanModel = nape.Parent.Parent.Parent
				local fake = titanModel:FindFirstChild("Fake")
				if (fake and fake:FindFirstChild("Collision") and not fake.Collision.CanCollide) or (titanModel:GetAttribute("Dead")) then continue end

				local tName = titanModel.Name
				local isBoss = bossNames[tName]

				if isArmoredRaid and not hasReinerObjective and tName == "Armored_Titan" then continue end
				if isBoss and not titanModel:GetAttribute("State") then continue end
				local isRoaring = isBoss and (titanModel:GetAttribute("Attack") == "Roar" or titanModel:GetAttribute("Attack") == "Berserk_Mode")
				if tName == "Attack_Titan" then attackTitanFound = true end

				local dx = referencePos.X - nape.Position.X
				local dz = referencePos.Z - nape.Position.Z
				local d = dx*dx + dz*dz
				
				local adjustedDist = d
				if getgenv()._currentTargetNape == nape then
					adjustedDist = adjustedDist - 15000
				end

				if useRangeLimit then
					if d > 90000 then continue end
				end

				if isBoss then
					local hitPart = (titanModel:FindFirstChild("Marker") and titanModel.Marker.Adornee) or titanModel.Hitboxes.Hit.Nape
					if hitPart and adjustedDist < bossDist then
						bossDist = adjustedDist
						bossHitPoint = hitPart
						bossIsRoaring = isRoaring
					end
				end

				if isStall then
					if nape.Position.Z > highestZ then
						highestZ = nape.Position.Z
						closestNape = nape
					end
				elseif adjustedDist < closestDist then
					closestDist = adjustedDist
					closestNape = nape
					closestIsBoss = isBoss
				end
			end


			local targetPart = bossHitPoint or closestNape
			local targetIsRoaring = (targetPart ~= nil and targetPart == bossHitPoint) and bossIsRoaring or false
			
			if useRangeLimit and closestNape then
				targetPart = closestNape
				targetIsRoaring = false
			end

			if targetPart and #validNapes == 1 and mapType == "Missions" and (workspace:GetAttribute("Seconds") or 0) < 29 then
				targetPart = nil
			end

			getgenv()._currentTargetNape = targetPart

			if attackTitanFound then
				attackTitanSpawnTime = attackTitanSpawnTime or now
			else
				attackTitanSpawnTime = nil
			end

			local attackTitanReady = not attackTitanFound or (attackTitanSpawnTime and (now - attackTitanSpawnTime) >= 5)

			if targetPart then
				UpdateStatus(closestIsBoss and "Attacking Boss..." or "Farming Titans...")
				local currentTitanModel = targetPart
				while currentTitanModel and currentTitanModel.Parent ~= titansFolder do
					currentTitanModel = currentTitanModel.Parent
				end

				if isShifted then
					local targetHRP = currentTitanModel:FindFirstChild("HumanoidRootPart")
					local targetCFrame = targetHRP and targetHRP.CFrame or targetPart.CFrame
					
					root.AssemblyLinearVelocity = V3_ZERO
					root.CFrame = targetCFrame * CFrame.new(0, 0, 80)
					local mode = getgenv().MasteryFarmConfig.Mode
					local doPunch = mode == "Punching" or mode == "Both"
					local doSkills = mode == "Skill Usage" or mode == "Both"

					if not targetIsRoaring then
						if doPunch and (now - lastMasteryPunch) >= 1 then
							lastMasteryPunch = now
							postRemote:FireServer("Attacks", "Slash", true)
							postRemote:FireServer("Hitboxes", "Register", targetPart, nil, nil, masteryComboIndex) 
							masteryComboIndex = masteryComboIndex + 1
							if masteryComboIndex > 4 then masteryComboIndex = 1 end
						end

						if doSkills and slotData and slotData.Skills and slotData.Skills.Shifter and not getgenv().ShifterSkillsRunning then
							getgenv().ShifterSkillsRunning = true
							task.spawn(function()
								for _, skillId in ipairs(slotData.Skills.Shifter) do
									local idNum = tonumber(skillId)
									if idNum and idNum ~= 200 and idNum ~= 300 and idNum ~= 400 and idNum ~= 210 and idNum ~= 211 and idNum ~= 306 and idNum ~= 308 and idNum ~= 402 and idNum ~= 403 and idNum ~= 407 then
										getRemote:InvokeServer("S_Skills", "Usage", tostring(skillId), false)
									end
									task.wait(1)
								end
								getgenv().ShifterSkillsRunning = false
							end)
						end
					end
					task.wait()
					continue
				end

				local titanHRP = currentTitanModel:FindFirstChild("HumanoidRootPart")
				local targetHeightPos
				if titanHRP then
					targetHeightPos = (titanHRP.CFrame * CFrame.new(0, getgenv().AutoFarmConfig.HeightOffset, 30)).Position
				else
					targetHeightPos = targetPart.Position + Vector3.new(0, getgenv().AutoFarmConfig.HeightOffset, 0)
				end
				
				if getgenv().AutoFarmConfig.MovementMode == "Hover" then
					local dir = targetHeightPos - rootPos
					root.AssemblyLinearVelocity = dir.Magnitude > 1 and dir.Unit * getgenv().AutoFarmConfig.MoveSpeed or V3_ZERO
				else
					root.AssemblyLinearVelocity = V3_ZERO
					root.CFrame = CFrame.new(targetHeightPos)
				end

				if not attackTitanReady then task.wait() continue end

				local dx = root.Position.X - targetPart.Position.X
				local dz = root.Position.Z - targetPart.Position.Z

				if not targetIsRoaring and (dx*dx + dz*dz) <= AttackRangeSq and (now - lastAttack) >= getgenv().AutoFarmConfig.AttackCooldown then
					lastAttack = now

					if slotData.Weapon == "Blades" then
						postRemote:FireServer("Attacks", "Slash", true)
						postRemote:FireServer("Hitboxes", "Register", targetPart, math.random(625, 850))
					else
						local isBoss = bossNames[targetPart.Parent.Parent.Parent.Name]
						local text = PlayerGui.Interface.HUD.Main.Top.Spears.Spears.Text
						local currentAmmo, maxAmmo = string.match(text, "(%d+)%s*/%s*(%d+)")
						currentAmmo, maxAmmo = tonumber(currentAmmo), tonumber(maxAmmo)

						if currentAmmo and currentAmmo > 0 then
							task.spawn(function()
								local function getAmmo()
									local hudText = PlayerGui.Interface.HUD.Main.Top.Spears.Spears.Text
									return tonumber(string.match(hudText, "(%d+)"))
								end

								local beforeAmmo = getAmmo()
								getRemote:InvokeServer("Spears", "S_Fire", tostring(currentAmmo))
								local afterAmmo = getAmmo()

								if afterAmmo and beforeAmmo and afterAmmo == beforeAmmo then
									for j = maxAmmo, 1, -1 do
										local prevAmmo = getAmmo()
										getRemote:InvokeServer("Spears", "S_Fire", tostring(j))
										local newAmmo = getAmmo()
										if newAmmo and prevAmmo and newAmmo < prevAmmo then break end
									end
								end
								
								local loops = isBoss and 30 or 1
								for j = 1, loops do
									postRemote:FireServer("Spears", "S_Explode", targetPart.Position)
								end
							end)
						end
					end
				end
			else
				root.AssemblyLinearVelocity = V3_ZERO
			end

			task.wait()
		end
	end)
end

function AutoFarm:Stop()
	self._running = false
end

local function formatTable(tbl)
	local str = ""
	for k, v in pairs(tbl) do
		str ..= string.format("%s: %s\n", k, tostring(v))
	end
	return str ~= "" and str or "None"
end

local function formatItems(tbl)
	local str = ""
	for name, qty in pairs(tbl) do
		name = string.gsub(name, "_", " ")
		str ..= string.format("[+] %s (x%s)\n", name, qty)
	end
	return str ~= "" and str or "None"
end

local data = { Stats = {}, Total = {}, Items = {}, Special = {} }

-- Initialize Persistent Files
local path = "./GabBoboBading/aotr/games_played.txt"
local sliderCounterPath = "./GabBoboBading/aotr/slider_run_counter.txt" 
if not isfile(path) then writefile(path, "0") end
if not isfile(sliderCounterPath) then writefile(sliderCounterPath, "0") end
local gamesPlayed = tonumber(readfile(path))

if rewards then
    rewards:GetPropertyChangedSignal("Visible"):Connect(function()
        if not rewards.Visible then return end

        local currentWebhook = getgenv().Library and getgenv().Library.Options and getgenv().Library.Options.WebhookUrl_Mission and getgenv().Library.Options.WebhookUrl_Mission.Value or ""
        
        -- Trim accidental spaces from the URL
        currentWebhook = currentWebhook:gsub("^%s*(.-)%s*$", "%1")
        
        -- Increment total games
        gamesPlayed = gamesPlayed + 1
        writefile("./GabBoboBading/aotr/games_played.txt", tostring(gamesPlayed))

        -- 1. PERSISTENT SLIDER LOGIC
        if getgenv().AutoReturnLobbyRun then
            local currentRuns = tonumber(readfile(sliderCounterPath)) or 0
            currentRuns = currentRuns + 1
            
            local limit = getgenv().Library and getgenv().Library.Options.ReturnAfterRunsSlider and getgenv().Library.Options.ReturnAfterRunsSlider.Value or 10
            if getgenv().Library then
                getgenv().Library:Notify({ Title = "Run Counter", Description = "Run " .. currentRuns .. "/" .. limit, Time = 3 })
            end
            
            if currentRuns >= limit then
                writefile(sliderCounterPath, "0") 
                getgenv().AutoStart = false
                pcall(function() getgenv().Library.Toggles.AutoStartToggle:SetValue(false) end)
                TeleportToLobbySafe()
                return 
            else
                writefile(sliderCounterPath, tostring(currentRuns))
            end
        end

        -- 2. Handle Global Return Lobby Failsafe (Every 10 games)
        local gamesUntilReturn = tonumber(readfile(returnCounterPath)) or 0
        if getgenv().AutoReturnLobby then
            gamesUntilReturn = gamesUntilReturn + 1
            if gamesUntilReturn >= 10 then
                gamesUntilReturn = 0
                writefile(returnCounterPath, "0")
                TeleportToLobbySafe()
                return
            end
            writefile(returnCounterPath, tostring(gamesUntilReturn))
        elseif gamesUntilReturn >= 10 then
            writefile(returnCounterPath, "0")
        end

        -- 3. WEBHOOK LOGIC (Bulletproofed)
        -- Checks if the URL isn't empty AND starts with http/https
        if currentWebhook ~= "" and string.match(currentWebhook, "^https?://") and getgenv().RewardWebhook then
            task.spawn(function()
                -- Wait up to 3 seconds for stats to populate
                local startWait = os.clock()
                local hasData = false
                repeat 
                    task.wait(0.2)
                    for _, v in ipairs(statsFrame:GetChildren()) do
                        if v:IsA("Frame") and v:FindFirstChild("Amount") and v.Amount.Text ~= "0" and v.Amount.Text ~= "" then
                            hasData = true
                            break
                        end
                    end
                until hasData or (os.clock() - startWait) > 3

                data.Stats, data.Total, data.Items, data.Special = {}, {}, {}, {}

                for _, v in ipairs(statsFrame:GetChildren()) do
                    if v:IsA("Frame") and v:FindFirstChild("Stat") and v:FindFirstChild("Amount") then
                        data.Stats[string.gsub(v.Name, "_", " ")] = v.Amount.Text
                    end
                end

                for _, v in ipairs(itemsFrame:GetChildren()) do
                    if v:IsA("Frame") and v:FindFirstChild("Main") then
                        local inner = v.Main:FindFirstChild("Inner")
                        if inner then
                            data.Items[v.Name] = inner.Quantity.Text
                            if inner:FindFirstChild("Rarity") and inner.Rarity.BackgroundColor3 == Color3.fromRGB(255, 0, 0) then
                                data.Special[v.Name] = inner.Quantity.Text
                            end
                        end
                    end
                end

                local currentSlot = lp:GetAttribute("Slot") or "A"
                local slotData = mapData and mapData.Slots and mapData.Slots[currentSlot]
                local executor = (identifyexecutor and identifyexecutor()) or "Unknown"

                if slotData then
                    if slotData.Currency then
                        for i, v in pairs(slotData.Currency) do
                            if i == "Gems" or i == "Gold" then data.Total[i] = v end
                        end
                    end
                    if slotData.Progression then
                        for i, v in pairs(slotData.Progression) do
                            if i == "Prestige" or i == "Level" or i == "Streak" then data.Total[i] = v end
                        end
                    end
                end

                local hasSpecial = data.Special and next(data.Special) ~= nil
                local specialFormat = hasSpecial and formatItems(data.Special) or "None"
                local cb = string.char(96, 96, 96) 
                
                local payload = {
                    content = hasSpecial and "MYTHICAL DROP! @everyone" or nil,
                    embeds = {{
                        title = "Mission Rewards",
                        color = hasSpecial and 0xff0000 or 0x2b2d31,
                        fields = {
                            { name = "Information", value = cb .. "\nUser: " .. lp.Name .. "\nGames Played: " .. tostring(gamesPlayed) .. "\nDifficulty: " .. tostring(workspace:GetAttribute("Difficulty") or "Unknown") .. "\nExecutor: " .. executor .. "\n" .. cb, inline = true },
                            { name = "Total Stats", value = cb .. "\nLevel : " .. tostring(data.Total.Level or "1") .. "\nGold  : " .. tostring(data.Total.Gold or "0") .. "\nGems  : " .. tostring(data.Total.Gems or "0") .. "\n" .. cb, inline = true },
                            { name = "Combat", value = cb .. "\n" .. formatTable(data.Stats) .. cb, inline = true },
                            { name = "Rewards", value = cb .. "\n" .. formatItems(data.Items) .. cb, inline = true },
                            { name = "Special", value = cb .. "\n" .. specialFormat .. cb, inline = true }
                        },
                        footer = { text = "GabBoboBading • " .. os.date("%X") },
                        timestamp = DateTime.now():ToIsoDate()
                    }}
                }

                local req = (syn and syn.request) or (http and http.request) or http_request or request
                if req then
                    -- Safely wrap the request so bad URLs NEVER throw a red error
                    pcall(function()
                        req({
                            Url = currentWebhook,
                            Method = "POST",
                            Headers = { ["Content-Type"] = "application/json" },
                            Body = HttpService:JSONEncode(payload)
                        })
                    end)
                end
            end)
        end
    end)
end

local Perks = {
	Legendary = {
		"Peerless Commander","Indefatigable","Tyrant's Stare","Invincible","Eviscerate",
		"Font of Vitality","Flame Rhapsody","Robust","Sixth Sense","Gear Master",
		"Carnifex","Munitions Master","Sanctified","Wind Rhapsody","Peerless Constitution",
		"Exhumation","Warchief","Peerless Focus","Perfect Form","Courage Catalyst",
		"Aegis","Unparalleled Strength","Perfect Soul"
	},
	Common = {
		"Cripple","Lucky","Enhanced Metabolism","First Aid","Mighty",
		"Fortitude","Hollow","Gear Beginner","Enduring"
	},
	Epic = {
		"Munitions Expert","Gear Expert","Butcher","Resilient","Speedy",
		"Reckless Abandon","Focus","Stalwart Durability","Adrenaline","Safeguard",
		"Warrior","Solo","Mutilate","Trauma Battery","Hardy",
		"Unbreakable","Siphoning","Flawed Release","Luminous","Peerless Strength"
	},
	Rare = {
		"Blessed","Gear Intermediate","Unyielding","Fully Stocked","Forceful",
		"Lightweight","Protection","Mangle","Experimental Shells","Critical Hunter",
		"Tough","Heightened Vitality"
	},
	Secret = {
		"Everlasting Flame","Heavenly Restriction","Adaptation","Maximum Firepower",
		"Soulfeed","Kengo","Black Flash","Font of Inspiration","Explosive Fortune",
		"Immortal","Art of War","Tatsujin","Founder's Blessing"
	}
}

local PerkRarityMap = {}
for rarity, names in pairs(Perks) do
	for _, name in pairs(names) do PerkRarityMap[name] = rarity end
end

local Talents = {
	"Blitzblade","Crescendo","Swiftshot","Surgeshot","Guardian","Deflectra",
	"Mendmaster","Cooldown Blitz","Stalwart","Stormcharged","Aegisurge","Riposte",
	"Lifefeed","Vitalize","Gem Fiend","Luck Boost","EXP Boost","Gold Boost",
	"Furyforge","Quakestrike","Assassin","Amputation","Steel Frame","Resilience",
	"Vengeflare","Flashstep","Omnirange","Tactician","Gambler","Overslash",
	"Afterimages","Necromantic","Thanatophobia","Apotheosis","Bloodthief"
}

local Perk_Level_XP = {
	Common    = {50, 100, 150, 200, 250, 300, 350, 400, 450, 500},
	Rare      = {125, 250, 375, 500, 625, 750, 875, 1000, 1125, 1250},
	Epic      = {250, 500, 750, 1000, 1250, 1500, 1750, 2000, 2250, 2500},
	Legendary = {500, 1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000},
	Secret    = {2000, 4000, 6000, 8000, 10000, 12000, 14000, 16000, 18000, 20000},
}

local Perk_Base_XP = {
	Common    = 100,
	Rare      = 250,
	Epic      = 625,
	Legendary = 2500,
	Secret    = 10000,
}

local Blades_Critical = {
	"1","2","3","4","5","6","7","8","9","10","11","12","13",
	"14","15","16","17","18","19","20","21","22","23","24","25"
}

local Blades_Damage = {
	"1","2","3","4","5","6","7","8","9","10","11","12","13",
	"26","27","28","29","30","31","32","33","34","35","36","37"
}

local Spears_Critical = {
	"113","114","115","116","117","118","119","120",
	"121","122","123","124","125",
	"126","127","128","129","130","131","132",
	"133","134","135","136","137"
}

local Spears_Damage = {
	"113","114","115","116","117","118","119","120",
	"121","122","123","124","125",
	"138","139","140","141","142","143","144",
	"145","146","147","148","149"
}

local Defense_Health = {
	"38","39","40","41","42","43","44","45",
	"46","47","48","49","50","51","52","53","54","55","56","57"
}

local Defense_Damage_Reduction = {
	"38","39","40","41","42","43","44","45",
	"58","59","60","61","62","63","64","65","66","67","68","69"
}

local Support_Regen = {
	"70","71","72","73","74","75","76","77","78","79","80",
	"81","82","83","84","85","86","87","88","89"
}

local Support_Cooldown_Reduction = {
	"70","71","72","73","74","75","76","77","78","79","80",
	"90","91","92","93","94","95","96","97","98"
}

local Missions = {
	["Shiganshina"] = { "Skirmish", "Breach", "Random" },
	["Trost"] = { "Skirmish", "Protect", "Random" },
	["Outskirts"] = { "Skirmish", "Escort", "Random" },
	["Giant Forest"] = { "Skirmish", "Guard", "Random" },
	["Utgard"] = { "Skirmish", "Defend", "Random" },
	["Loading Docks"] = { "Skirmish", "Stall", "Random" },
	["Stohess"] = { "Skirmish", "Random" }
}

local SkillPaths = {
	Blades = { Damage = Blades_Damage, Critical = Blades_Critical },
	Spears = { Damage = Spears_Damage, Critical = Spears_Critical },
	Defense = { Health = Defense_Health, ["Damage Reduction"] = Defense_Damage_Reduction },
	Support = { Regen = Support_Regen, ["Cooldown Reduction"] = Support_Cooldown_Reduction }
}

local function GetPerkRarity(perkName)
	return PerkRarityMap[perkName]
end

local function GetPerkXP(rarity, level)
	local base = Perk_Base_XP[rarity] or 0
	return base * math.max(level, 1)
end

local _deleteMapRunning = false
local function DeleteMap()
	if _deleteMapRunning or not getgenv().DeleteMap or not workspace:FindFirstChild("Climbable") or mapData.Map.Type == "Raids" then return end
	task.spawn(function()
		_deleteMapRunning = true
		while getgenv().DeleteMap do
			if not workspace:FindFirstChild("Climbable") or mapData.Map.Type == "Raids" then break end
			
			for i, v in workspace.Climbable:GetChildren() do
				v:Destroy()
			end

			for i, v in workspace.Unclimbable:GetChildren() do
				if v.Name ~= "Reloads" and v.Name ~= "Objective" and v.Name ~= "Cutscene" then
					v:Destroy()
				end
			end
			task.wait(3)
		end
		_deleteMapRunning = false
	end)
end

local function setupAutoExecute()
	if getgenv().AutoExecute and not getgenv().AutoExec then
		getgenv().AutoExec = true
		queue_on_teleport([[
			repeat task.wait() until game:IsLoaded()
			task.wait(5)
			loadstring(game:HttpGet("https://raw.githubusercontent.com/Crelle1130/123asd/refs/heads/main/AOTR.lua", true))()
		]])
	end
end

local hasRetriedThisMission = false

local function ExecuteImmediateAutomation()
	if getgenv().AutoSkip then
		local skip = INTERFACE:FindFirstChild("Skip")
		if skip and skip.Visible then
			pcall(function()
				local interact = skip:FindFirstChild("Interact")
				if interact then
					-- Simulated button click via events instead of VIM focus
					for _, connection in pairs(getconnections(interact.MouseButton1Click)) do
						connection:Fire()
					end
				end
			end)
		end
	end

	if getgenv().AutoChest then
		local chests = INTERFACE:FindFirstChild("Chests")
		if chests and chests.Visible then
			local free = chests:FindFirstChild("Free")
			local premium = chests:FindFirstChild("Premium")
			local finish = chests:FindFirstChild("Finish")

			if free and free.Visible then
				pcall(function()
					getRemote:InvokeServer("Functions", "Chest", "Free", free, true)
				end)
			elseif premium and premium.Visible and premium:FindFirstChild("Title") and not string.find(premium.Title.Text, "(0)") and getgenv().OpenSecondChest then
				pcall(function()
					getRemote:InvokeServer("Functions", "Chest", "Premium", premium, true)
				end)
			elseif finish and finish.Visible then
				pcall(function()
					for _, connection in pairs(getconnections(finish.MouseButton1Click)) do
						connection:Fire()
					end
				end)
			end
		end
	end

	if getgenv().AutoRetry then
		local rewardsGui = INTERFACE:FindFirstChild("Rewards")
		if rewardsGui and rewardsGui.Visible and not hasRetriedThisMission then
			-- Set the lock so it ONLY fires once and stops looping!
			hasRetriedThisMission = true
			
			-- NO VIM OR SELECTOR BOX! Firing the remote directly:
			pcall(function()
				getRemote:InvokeServer("Functions", "Retry", "Add")
			end)
			task.wait(1)
		end
	end
end

local function roll(targets, rarities)
	if not PlayerGui.Interface.Customisation.Visible then return end

	local familyString = PlayerGui.Interface.Customisation.Family.Family.Title.Text
	local familyName = targets and string.lower(string.split(familyString, " ")[1]) or nil
	local familyRarity = string.lower(string.match(familyString, "%((.-)%)") or "")

	local stopRolling = false
	if targets and familyName and table.find(targets, familyName) then stopRolling = true end
	if rarities and table.find(rarities, familyRarity) then stopRolling = true end
	if familyRarity == "mythical" then stopRolling = true end

	if stopRolling then
		getgenv().AutoRoll = false
		pcall(function()
			if Library and Library.Toggles and Library.Toggles.AutoRollToggle then
				Library.Toggles.AutoRollToggle:SetValue(false)
			end
		end)

		if familyRarity == "mythical" and getgenv().MythicalFamilyWebhook then
			local menuWebhook = getgenv().Library.Options.WebhookUrl_Menu and getgenv().Library.Options.WebhookUrl_Menu.Value or ""
			menuWebhook = menuWebhook:gsub("^%s*(.-)%s*$", "%1")

			if menuWebhook ~= "" and string.match(menuWebhook, "^https?://") then
				local cb = string.char(96, 96, 96)
				local payload = {
					content = "MYTHICAL FAMILY ROLLED! @everyone",
					embeds = {{
						title = "Family Roll Success",
						color = 0xff0000,
						fields = {
							{
								name = "Information",
								value = cb .. "\nUser: " .. lp.Name .. "\nFamily: " .. tostring(familyString) .. "\n\n" .. cb,
								inline = true
							}
						},
						footer = {
							text = "GabBoboBading • " .. DateTime.now():FormatLocalTime("LTS", "en-us")
						},
						timestamp = DateTime.now():ToIsoDate()
					}}
				}
				local req = (syn and syn.request) or (http and http.request) or http_request or request
				if req then
					pcall(function()
						req({
							Url = menuWebhook,
							Method = "POST",
							Headers = { ["Content-Type"] = "application/json" },
							Body = HttpService:JSONEncode(payload)
						})
					end)
				end
			end
		end

		pcall(function()
			Library:Notify({
				Title = "GabBoboBading",
				Description = "Target family rolled: " .. familyString,
				Time = 5,
			})
		end)

		if getgenv().AutoDeposit then
			local success, result = pcall(function()
				return getRemote:InvokeServer("Family", "Store")
			end)
			if success and result then
				pcall(function()
					Library:Notify({
						Title = "GabBoboBading",
						Description = "Family deposited! Continuing roll...",
						Time = 3,
					})
				end)
				getgenv().AutoRoll = true
				pcall(function()
					if Library and Library.Toggles and Library.Toggles.AutoRollToggle then
						Library.Toggles.AutoRollToggle:SetValue(true)
					end
				end)
			end
			return
		end

		return
	end

	if PlayerGui.Interface.Warning.Prompt.Visible then
		pcall(function()
			for _, connection in pairs(getconnections(PlayerGui.Interface.Warning.Prompt.Main.Yes.MouseButton1Click)) do
				connection:Fire()
			end
		end)
		task.wait(0.5)
	end

	if familyFrame and not familyFrame.Visible then
		pcall(function()
			for _, connection in pairs(getconnections(PlayerGui.Interface.Customisation.Categories.Family.Interact.MouseButton1Click)) do
				connection:Fire()
			end
		end)
		task.wait(1)
	end

	if rollButton then
		pcall(function()
			for _, connection in pairs(getconnections(rollButton.MouseButton1Click)) do
				connection:Fire()
			end
		end)
	end
end

local lastReloadTime = 0
local autoReloadEnabled = false
local autoRefillEnabled = false
local isReloading = false

local function getBladeCount()
	if not INTERFACE:FindFirstChild("HUD") then return end
	local text = PlayerGui.Interface.HUD.Main.Top.Blades.Sets.Text
	return tonumber(text:match("(%d+)%s*/"))
end

local function handleWeaponReload()
	if not autoReloadEnabled then return end
	if isReloading then return end
	if os.clock() - lastReloadTime < getgenv().AutoFarmConfig.ReloadCooldown then return end

	local slotIndex = lp:GetAttribute("Slot")
	local slot = slotIndex and mapData and mapData.Slots and mapData.Slots[slotIndex]
	if not slot then return end

	local weaponType = slot.Weapon

	if weaponType == "Blades" then
		local char = lp.Character
		local rig = char and char:FindFirstChild("Rig_" .. lp.Name)
		local blade = rig and rig:FindFirstChild("LeftHand") and rig.LeftHand:FindFirstChild("Blade_1")

		local current = getBladeCount() or 0

		if current == 0 and autoRefillEnabled then
			local refillPart = workspace:FindFirstChild("Unclimbable")
				and workspace.Unclimbable:FindFirstChild("Reloads")
				and workspace.Unclimbable.Reloads:FindFirstChild("GasTanks")
				and workspace.Unclimbable.Reloads.GasTanks:FindFirstChild("Refill")

			if refillPart then
				isReloading = true
				lastReloadTime = os.clock()
				pcall(function()
					postRemote:FireServer("Attacks", "Reload", refillPart)
				end)
				task.delay(1, function() isReloading = false end)
				return
			end
		end

		if blade and blade.Transparency == 1 and current > 0 then
			isReloading = true
			lastReloadTime = os.clock()
			pcall(function()
				getRemote:InvokeServer("Blades", "Reload") 
			end)
			task.delay(0.5, function() isReloading = false end)
			return
		end

	elseif weaponType == "Spears" then
		local HUD = INTERFACE:FindFirstChild("HUD")
		if not HUD then return end
		
		local spearCount = tonumber(HUD.Main.Top.Spears.Spears.Text:match("(%d+)%s*/")) or 0
		if spearCount == 0 and autoRefillEnabled then
			local refillPart = workspace:FindFirstChild("Unclimbable")
				and workspace.Unclimbable:FindFirstChild("Reloads")
				and workspace.Unclimbable.Reloads:FindFirstChild("GasTanks")
				and workspace.Unclimbable.Reloads.GasTanks:FindFirstChild("Refill")

			if refillPart then
				isReloading = true
				lastReloadTime = os.clock()
				postRemote:FireServer("Attacks", "Reload", refillPart)
				task.delay(1, function() isReloading = false end)
			end
		end
	end
end

task.spawn(function()
	while true do
		pcall(handleWeaponReload)
		task.wait(0.5)
	end
end)

getgenv().AutoEscape = false
postRemote.OnClientEvent:Connect(function(...)
	local args = {...}
	if getgenv().AutoEscape and args[1] == "Titans" and args[2] == "Grab_Event" then
		game:GetService("Players").LocalPlayer.PlayerGui.Interface.Buttons.Visible = not getgenv().AutoEscape
		postRemote:FireServer("Attacks", "Slash_Escape")
	end
end)

-- ==========================================
-- OBSIDIAN UI LIBRARY LOAD
-- ==========================================

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

getgenv().Library = Library
local Options = Library.Options
local Toggles = Library.Toggles

local Window = Library:CreateWindow({
	Title = "GabBoboBading",
	Footer = "AOT:R | Freemium",
	Center = true,
	AutoShow = true,
	Resizable = true,
	ShowCustomCursor = true,
})

local Tabs = {
	Main = Window:AddTab("Lobby", "house"),
	Mission = Window:AddTab("Mission", "swords"),
	Misc = Window:AddTab("Misc", "boxes"),
	Menu = Window:AddTab("Main Menu", "home"),
	Settings = Window:AddTab("Settings", "settings"),
}

local MainGroup = Tabs.Mission:AddLeftGroupbox("Farm")
local MissionRightGroup = Tabs.Mission:AddRightGroupbox("Actions")
local AutoStartGroup = Tabs.Main:AddRightGroupbox("Auto Start")

local UpgradesGroup = Tabs.Main:AddLeftGroupbox("Upgrades")
local SkillTreeGroup = Tabs.Main:AddRightGroupbox("Skill Tree")
local PrestigeGroup = Tabs.Main:AddLeftGroupbox("Prestige")
local AutoQuestGroup = Tabs.Main:AddRightGroupbox("Auto Quest")

local SlotGroup = Tabs.Menu:AddLeftGroupbox("Slot")
local FamilyRollGroup = Tabs.Menu:AddRightGroupbox("Family Roll")
local SettingsGroup = Tabs.Misc:AddLeftGroupbox("Settings")

local MissionWebhookGroup = Tabs.Mission:AddRightGroupbox("Webhook") 
local MenuWebhookGroup = Tabs.Menu:AddLeftGroupbox("Webhook")

-- ==========================================
-- MAIN TAB : Farm Groupbox
-- ==========================================
getgenv().CurrentStatusLabel = MainGroup:AddLabel("Status: Idle")

MainGroup:AddToggle("AutoKillToggle", {
	Text = "Auto Farm",
	Default = false,
})
Toggles.AutoKillToggle:OnChanged(function()
	if Toggles.AutoKillToggle.Value then AutoFarm:Start() else AutoFarm:Stop() end
end)

MainGroup:AddToggle("MasteryFarmToggle", {
	Text = "Titan Mastery Farm",
	Default = false,
})
Toggles.MasteryFarmToggle:OnChanged(function()
	getgenv().MasteryFarmConfig.Enabled = Toggles.MasteryFarmToggle.Value
	if Toggles.MasteryFarmToggle.Value then
		if not Toggles.AutoKillToggle.Value then
			Toggles.AutoKillToggle:SetValue(true)
		elseif not AutoFarm._running then
			AutoFarm:Start()
		end
	end
end)

MainGroup:AddDropdown("MasteryModeDropdown", {
	Values = {"Punching", "Skill Usage", "Both"},
	Default = 3,
	Multi = false,
	Text = "Mastery Mode",
})
Options.MasteryModeDropdown:OnChanged(function()
	getgenv().MasteryFarmConfig.Mode = Options.MasteryModeDropdown.Value
end)

MainGroup:AddDropdown("MovementModeDropdown", {
	Values = {"Hover", "Teleport"},
	Default = 1,
	Multi = false,
	Text = "Movement Mode",
})
Options.MovementModeDropdown:OnChanged(function()
	getgenv().AutoFarmConfig.MovementMode = Options.MovementModeDropdown.Value
end)

MainGroup:AddDropdown("FarmOptionsDropdown", {
	Values = {"Auto Execute", "Failsafe", "Open Second Chest"},
	Default = {},
	Multi = true,
	Text = "Farm Options",
})
Options.FarmOptionsDropdown:OnChanged(function()
	local vals = Options.FarmOptionsDropdown.Value
	getgenv().AutoFailsafe = vals["Failsafe"] or false
	getgenv().AutoExecute = vals["Auto Execute"] or false
	getgenv().OpenSecondChest = vals["Open Second Chest"] or false
	if getgenv().AutoExecute then setupAutoExecute() end
end)

MainGroup:AddSlider("HoverSpeedSlider", {
	Text = "Hover Speed",
	Default = 400,
	Min = 100,
	Max = 500,
	Rounding = 0,
})
Options.HoverSpeedSlider:OnChanged(function()
	getgenv().AutoFarmConfig.MoveSpeed = Options.HoverSpeedSlider.Value
end)


MainGroup:AddSlider("FloatHeightSlider", {

	Text = "Float Height",
	Default = 250,
	Min = 100,
	Max = 300,
	Rounding = 0,
})
Options.FloatHeightSlider:OnChanged(function()
	getgenv().AutoFarmConfig.HeightOffset = Options.FloatHeightSlider.Value
end)


MainGroup:AddToggle("AutoReloadToggle", {
	Text = "Auto Reload/Refill",
	Default = false,
})
Toggles.AutoReloadToggle:OnChanged(function()
	autoReloadEnabled = Toggles.AutoReloadToggle.Value
	autoRefillEnabled = Toggles.AutoReloadToggle.Value
end)

MainGroup:AddToggle("AutoEscapeToggle", {
	Text = "Auto Escape",
	Default = false,
})
Toggles.AutoEscapeToggle:OnChanged(function()
	getgenv().AutoEscape = Toggles.AutoEscapeToggle.Value
end)

MainGroup:AddToggle("AutoSkipToggle", {
	Text = "Auto Skip Cutscenes",
	Default = false,
})
Toggles.AutoSkipToggle:OnChanged(function()
	getgenv().AutoSkip = Toggles.AutoSkipToggle.Value
	if getgenv().AutoSkip then ExecuteImmediateAutomation() end
end)

MainGroup:AddToggle("AutoRetryToggle", {
	Text = "Auto Retry",
	Default = false,
})
Toggles.AutoRetryToggle:OnChanged(function()
	getgenv().AutoRetry = Toggles.AutoRetryToggle.Value
	if getgenv().AutoRetry then ExecuteImmediateAutomation() end
end)

MainGroup:AddToggle("AutoChestToggle", {
	Text = "Auto Open Chests",
	Default = false,
})
Toggles.AutoChestToggle:OnChanged(function()
	getgenv().AutoChest = Toggles.AutoChestToggle.Value
	if getgenv().AutoChest then ExecuteImmediateAutomation() end
end)

MainGroup:AddToggle("DeleteMapToggle", {
	Text = "Delete Map (FPS Boost)",
	Default = DropdownConfig.DeleteMap or false,
})
Toggles.DeleteMapToggle:OnChanged(function()
	getgenv().DeleteMap = Toggles.DeleteMapToggle.Value
	DropdownConfig.DeleteMap = getgenv().DeleteMap
	SaveConfig(DropdownConfig)
	if getgenv().DeleteMap then DeleteMap() end
end)
MainGroup:AddToggle("DeleteDamageTextToggle", {
	Text = "Delete Damage Text",
	Default = false,
})
Toggles.DeleteDamageTextToggle:OnChanged(function()
	getgenv().DeleteDamageText = Toggles.DeleteDamageTextToggle.Value
end)
MainGroup:AddToggle("SoloOnlyToggle", {
	Text = "Solo Only",
	Default = false,
})
Toggles.SoloOnlyToggle:OnChanged(function()
	getgenv().SoloOnly = Toggles.SoloOnlyToggle.Value
end)

MainGroup:AddToggle("AutoReturnLobbyToggle", {
	Text = "Auto Return to Lobby",
	Default = false,
})
Toggles.AutoReturnLobbyToggle:OnChanged(function()
	getgenv().AutoReturnLobby = Toggles.AutoReturnLobbyToggle.Value
	if not getgenv().AutoReturnLobby then
		pcall(function() writefile(returnCounterPath, "0") end)
	end
end)

MainGroup:AddLabel("Failsafe tps you back to lobby\nafter a timeout.")

-- ==========================================
-- MAIN TAB : Auto Start Groupbox
-- ==========================================

AutoStartGroup:AddButton({
	Text = "Return to Lobby",
	Func = function()
		TeleportToLobbySafe()
	end,
})

AutoStartGroup:AddButton({
	Text = "Join Discord",
	Func = function()
		setclipboard("https://discord.gg/N83Tn2SkJz")
		Library:Notify({
			Title = "Discord",
			Description = "Invite link copied to clipboard!",
			Time = 5
		})
	end,
})

AutoStartGroup:AddToggle("AutoStartToggle", {
	Text = "Auto Start",
	Default = false,
})
Toggles.AutoStartToggle:OnChanged(function()
	getgenv().AutoStart = Toggles.AutoStartToggle.Value

	if getgenv().AutoStart and game.PlaceId == 14916516914 then
		task.spawn(function()
			local MAX_RETRIES = 10
			local retries = 0

			local function getMyMission()
				local start = os.clock()
				while (os.clock() - start) < 2 do 
					for _, mission in next, ReplicatedStorage.Missions:GetChildren() do
						if mission:FindFirstChild("Leader") and mission.Leader.Value == lp.Name then
							return mission
						end
					end
					task.wait(0.1)
				end
				return nil
			end

			while getgenv().AutoStart do
				for _, mission in next, ReplicatedStorage.Missions:GetChildren() do
					if mission:FindFirstChild("Leader") and mission.Leader.Value == lp.Name then
						getRemote:InvokeServer("S_Missions", "Leave")
					end
				end

				local missionType = Options.StartTypeDropdown.Value
				local selectedDifficulty
				local mapName
				local objective

				if missionType == "Missions" then
					selectedDifficulty = Options.MissionDifficultyDropdown.Value
					mapName = Options.MissionMapDropdown.Value
					objective = Options.MissionObjectiveDropdown.Value
				else
					selectedDifficulty = Options.RaidDifficultyDropdown.Value
					mapName = Options.RaidMapDropdown.Value
					objective = Options.RaidObjectiveDropdown.Value
				end

				local created = false

				if selectedDifficulty == "Hardest" then
					local diffOrder = missionType == "Raids"
						and {"Aberrant", "Severe", "Hard"}
						or {"Aberrant", "Severe", "Hard", "Normal", "Easy"}

					for _, diff in ipairs(diffOrder) do
						if not getgenv().AutoStart then break end

						getRemote:InvokeServer("S_Missions", "Create", {
							Difficulty = diff,
							Type = missionType,
							Name = mapName,
							Objective = objective
						})

						task.wait(0.5)
						if getMyMission() then
							Library:Notify({
								Title = "Auto Start",
								Description = "Selected difficulty: " .. diff,
								Time = 3
							})
							created = true
							break
						end
					end
				else
					getRemote:InvokeServer("S_Missions", "Create", {
						Difficulty = selectedDifficulty,
						Type = missionType,
						Name = mapName,
						Objective = objective
					})

					if getMyMission() then created = true end
				end

				if not getgenv().AutoStart then break end

				if not created then
					retries = retries + 1
					local backoff = math.min(retries * 2, 20)

					if retries >= MAX_RETRIES then
						Library:Notify({
							Title = "Auto Start",
							Description = "Failed after " .. MAX_RETRIES .. " retries. Stopping.",
							Time = 10
						})
						getgenv().AutoStart = false
						Toggles.AutoStartToggle:SetValue(false)
						break
					end

					Library:Notify({
						Title = "Auto Start",
						Description = "Failed to create. Retry " .. retries .. "/" .. MAX_RETRIES .. " in " .. backoff .. "s",
						Time = backoff
					})
					task.wait(backoff)
					continue
				end

				retries = 0

				local activeMods = {}
				if Options.ModifiersDropdown.Value then
					for modName, isActive in pairs(Options.ModifiersDropdown.Value) do
						if isActive then table.insert(activeMods, modName) end
					end
				end

				if #activeMods > 0 then
					for _, modifier in ipairs(activeMods) do
						local applied = false
						local attempts = 0
						repeat
							getRemote:InvokeServer("S_Missions", "Modify", modifier)
							task.wait(0.5)
							local mission = getMyMission()
							if mission then
								local mods = mission:GetAttribute("Modifiers") or ""
								applied = string.find(mods, modifier, 1, true) ~= nil
							end
							attempts = attempts + 1
						until applied or attempts >= 10
					end
				end

				task.wait(0.5)
				getRemote:InvokeServer("S_Missions", "Start")

				task.wait(5)
			end
		end)
	end
end)

AutoStartGroup:AddDropdown("StartTypeDropdown", {
	Values = {"Missions", "Raids"},
	Default = DropdownConfig._lastType and table.find({"Missions", "Raids"}, DropdownConfig._lastType) or 1,
	Multi = false,
	Text = "Type",
})
Options.StartTypeDropdown:OnChanged(function()
	local Value = Options.StartTypeDropdown.Value
	if not Value then return end
	
	DropdownConfig._lastType = Value
	SaveConfig(DropdownConfig)

	local isMission = Value == "Missions"
	Options.MissionMapDropdown:SetVisible(isMission)
	Options.MissionObjectiveDropdown:SetVisible(isMission)
	Options.MissionDifficultyDropdown:SetVisible(isMission)

	Options.RaidMapDropdown:SetVisible(not isMission)
	Options.RaidObjectiveDropdown:SetVisible(not isMission)
	Options.RaidDifficultyDropdown:SetVisible(not isMission)
end)

AutoStartGroup:AddDropdown("MissionMapDropdown", {
	Values = {"Shiganshina","Trost","Outskirts","Giant Forest","Utgard","Loading Docks","Stohess"},
	Default = DropdownConfig.Missions and table.find({"Shiganshina","Trost","Outskirts","Giant Forest","Utgard","Loading Docks","Stohess"}, DropdownConfig.Missions.map) or 1,
	Multi = false,
	Text = "Mission Map",
})
Options.MissionMapDropdown:OnChanged(function()
	local Value = Options.MissionMapDropdown.Value
	if not Value then return end
	Options.MissionObjectiveDropdown:SetValues(Missions[Value] or {})
	DropdownConfig.Missions = DropdownConfig.Missions or {}
	DropdownConfig.Missions.map = Value
	SaveConfig(DropdownConfig)
end)

local initMissionMap = DropdownConfig.Missions and DropdownConfig.Missions.map or "Shiganshina"
local initMissionObjVals = Missions[initMissionMap] or {}
local initMissionObjDef = 1
if DropdownConfig.Missions and DropdownConfig.Missions.objective then
	initMissionObjDef = table.find(initMissionObjVals, DropdownConfig.Missions.objective) or 1
end

AutoStartGroup:AddDropdown("MissionObjectiveDropdown", {
	Values = initMissionObjVals,
	Default = initMissionObjDef,
	Multi = false,
	Text = "Mission Objective",
})
Options.MissionObjectiveDropdown:OnChanged(function()
	local Value = Options.MissionObjectiveDropdown.Value
	DropdownConfig.Missions = DropdownConfig.Missions or {}
	DropdownConfig.Missions.objective = Value
	SaveConfig(DropdownConfig)
end)

AutoStartGroup:AddDropdown("MissionDifficultyDropdown", {
	Values = {"Easy","Normal","Hard","Severe","Aberrant","Hardest"},
	Default = DropdownConfig.Missions and table.find({"Easy","Normal","Hard","Severe","Aberrant","Hardest"}, DropdownConfig.Missions.difficulty) or 2,
	Multi = false,
	Text = "Mission Difficulty",
})
Options.MissionDifficultyDropdown:OnChanged(function()
	local Value = Options.MissionDifficultyDropdown.Value
	DropdownConfig.Missions = DropdownConfig.Missions or {}
	DropdownConfig.Missions.difficulty = Value
	SaveConfig(DropdownConfig)
end)

AutoStartGroup:AddDivider()

AutoStartGroup:AddDropdown("RaidMapDropdown", {
	Values = {"Trost","Shiganshina","Stohess"},
	Default = DropdownConfig.Raids and table.find({"Trost","Shiganshina","Stohess"}, DropdownConfig.Raids.map) or 1,
	Multi = false,
	Text = "Raid Map",
})
Options.RaidMapDropdown:OnChanged(function()
	local Value = Options.RaidMapDropdown.Value
	if not Value then return end
	Options.RaidObjectiveDropdown:SetValues(Missions[Value] or {})
	DropdownConfig.Raids = DropdownConfig.Raids or {}
	DropdownConfig.Raids.map = Value
	SaveConfig(DropdownConfig)
end)

local initRaidMap = DropdownConfig.Raids and DropdownConfig.Raids.map or "Trost"
local initRaidObjVals = Missions[initRaidMap] or {}
local initRaidObjDef = 1
if DropdownConfig.Raids and DropdownConfig.Raids.objective then
	initRaidObjDef = table.find(initRaidObjVals, DropdownConfig.Raids.objective) or 1
end

AutoStartGroup:AddDropdown("RaidObjectiveDropdown", {
	Values = initRaidObjVals,
	Default = initRaidObjDef,
	Multi = false,
	Text = "Raid Objective",
})
Options.RaidObjectiveDropdown:OnChanged(function()
	local Value = Options.RaidObjectiveDropdown.Value
	DropdownConfig.Raids = DropdownConfig.Raids or {}
	DropdownConfig.Raids.objective = Value
	SaveConfig(DropdownConfig)
end)

AutoStartGroup:AddDropdown("RaidDifficultyDropdown", {
	Values = {"Hard","Severe","Aberrant","Hardest"},
	Default = DropdownConfig.Raids and table.find({"Hard","Severe","Aberrant","Hardest"}, DropdownConfig.Raids.difficulty) or 1,
	Multi = false,
	Text = "Raid Difficulty",
})
Options.RaidDifficultyDropdown:OnChanged(function()
	local Value = Options.RaidDifficultyDropdown.Value
	DropdownConfig.Raids = DropdownConfig.Raids or {}
	DropdownConfig.Raids.difficulty = Value
	SaveConfig(DropdownConfig)
end)

AutoStartGroup:AddLabel("Trost: Attack Titan\nShiganshina: Armored Titan\nStohess: Female Titan", true)

AutoStartGroup:AddDivider()

AutoStartGroup:AddDropdown("ModifiersDropdown", {
	Values = {"No Perks","No Skills","No Talents","Nightmare","Oddball","Injury Prone","Chronic Injuries","Fog","Glass Cannon","Time Trial","Boring","Simple"},
	Default = {},
	Multi = true,
	Text = "Modifiers",
})

task.defer(function()
	task.wait(0.2)
	local savedType = DropdownConfig._lastType or "Missions"
	Options.StartTypeDropdown:SetValue(savedType)
end)

-- ==========================================
-- UPGRADES TAB : Upgrades Groupbox
-- ==========================================

UpgradesGroup:AddToggle("AutoUpgradeToggle", {
	Text = "Upgrade Gear",
	Default = false,
})
Toggles.AutoUpgradeToggle:OnChanged(function()
	getgenv().AutoUpgrade = Toggles.AutoUpgradeToggle.Value
	if getgenv().AutoUpgrade then
		if game.PlaceId ~= 14916516914 then return end
		task.spawn(function()
			local plrData = GetPlayerData()
			if not plrData or not plrData.Slots then task.wait(1) return end

			while getgenv().AutoUpgrade do
				local slotIndex = lp:GetAttribute("Slot")
				if not slotIndex or not plrData.Slots[slotIndex] then task.wait(1) continue end
				local weapon = plrData.Slots[slotIndex].Weapon
				local upgrades = plrData.Slots[slotIndex].Upgrades[weapon]

				for upg, lvl in next, upgrades do
					if getRemote:InvokeServer("S_Equipment", "Upgrade", upg) then
						Library:Notify({
							Title = "Upgraded " .. string.gsub(upg, "_", " "),
							Description = "Level " .. tostring(lvl),
							Time = 1.5
						})
						task.wait(0.3)
					end
				end

				task.wait(0.5)
			end
		end)
	end
end)

UpgradesGroup:AddToggle("AutoEnhanceToggle", {
	Text = "Enhance Perks",
	Default = false,
})
Toggles.AutoEnhanceToggle:OnChanged(function()
	getgenv().AutoPerk = Toggles.AutoEnhanceToggle.Value
	if getgenv().AutoPerk then
		if game.PlaceId ~= 14916516914 then return end
		task.spawn(function()
			local plrData = GetPlayerData()
			if not plrData or not plrData.Slots then return end
			local slotIndex = lp:GetAttribute("Slot")
			if not slotIndex or not plrData.Slots[slotIndex] then
				getgenv().AutoPerk = false
				Toggles.AutoEnhanceToggle:SetValue(false)
				return
			end

			local slot = plrData.Slots[slotIndex]
			local storagePerks = {}
			for id, val in pairs(slot.Perks.Storage) do storagePerks[id] = val end

			local perkSlot = Options.PerkSlotDropdown.Value
			local equippedPerkId = slot.Perks.Equipped[perkSlot]
			if not equippedPerkId then
				Library:Notify({ Title = "Auto Perk", Description = "No perk equipped in " .. tostring(perkSlot) .. " slot.", Time = 3 })
				getgenv().AutoPerk = false
				Toggles.AutoEnhanceToggle:SetValue(false)
				return
			end

			local perkData = storagePerks[equippedPerkId]
			if not perkData then
				Library:Notify({ Title = "Auto Perk", Description = "Equipped perk data not found.", Time = 3 })
				getgenv().AutoPerk = false
				Toggles.AutoEnhanceToggle:SetValue(false)
				return
			end

			local perkName = perkData.Name
			local rarity = GetPerkRarity(perkName)
			local currentLevel = perkData.Level or 0
			local currentXP = perkData.XP or 0

			while getgenv().AutoPerk do
				if currentLevel >= 10 then
					Library:Notify({ Title = "Auto Perk", Description = perkName .. " is already Level 10!", Time = 3 })
					break
				end

				local selectedRarities = Options.SelectPerksDropdown.Value
				local rarityPerks = {}
				if selectedRarities then
					for r, isActive in pairs(selectedRarities) do
						if isActive then rarityPerks[r] = true end
					end
				end

				local validPerks = {}
				local totalXPGain = 0

				for perkId, tbl in pairs(storagePerks) do
					local r = GetPerkRarity(tbl.Name)
					if perkId ~= equippedPerkId and rarityPerks[r] then
						table.insert(validPerks, perkId)
						totalXPGain = totalXPGain + GetPerkXP(r, math.max(tbl.Level or 0, 1))
						if #validPerks >= 5 then break end
					end
				end

				if #validPerks == 0 then
					Library:Notify({ Title = "Auto Perk", Description = "No more food perks found.", Time = 3 })
					break
				end

				if getRemote:InvokeServer("S_Equipment", "Enhance", equippedPerkId, validPerks) then
					for _, id in ipairs(validPerks) do storagePerks[id] = nil end

					currentXP = currentXP + totalXPGain

					while currentLevel < 10 do
						local thresholds = Perk_Level_XP[rarity]
						if not thresholds then break end
						local needed = thresholds[currentLevel + 1]
						if not needed or currentXP < needed then break end
						currentXP = currentXP - needed
						currentLevel = currentLevel + 1
					end

					Library:Notify({
						Title = "Enhanced: " .. perkName,
						Description = "Level " .. tostring(currentLevel) .. " (+" .. totalXPGain .. " XP)",
						Time = 1
					})
				else
					continue
				end

				task.wait(0.5)
			end

			getgenv().AutoPerk = false
			Toggles.AutoEnhanceToggle:SetValue(false)
		end)
	end
end)

UpgradesGroup:AddDropdown("PerkSlotDropdown", {
	Values = {"Defense", "Support", "Family", "Extra", "Offense", "Body"},
	Default = 6,
	Multi = false,
	Text = "Perk Slot",
})

UpgradesGroup:AddDropdown("SelectPerksDropdown", {
	Values = {"Common", "Rare", "Epic", "Legendary"},
	Default = {},
	Multi = true,
	Text = "Perks to use (Food)",
})

UpgradesGroup:AddLabel("Default perk slot is Body")

-- ==========================================
-- LOBBY TAB : Auto Equip Perk Groupbox
-- ==========================================

local AutoEquipPerkGroup = Tabs.Main:AddLeftGroupbox("Auto Equip Perk")

local PerksBySlot = {
	Offense = {
		"Art of War","Black Flash","Blessed","Butcher","Carnifex",
		"Cripple","Critical Hunter","Everlasting Flame","Eviscerate",
		"Flame Rhapsody","Focus","Forceful","Hollow","Kengo",
		"Lightweight","Lucky","Luminous","Mangle","Mighty",
		"Mutilate","Peerless Focus","Peerless Strength","Sanctified",
		"Speedy","Tyrant's Stare","Unparalleled Strength","Warchief",
		"Warrior","Wind Rhapsody"
	},
	Body = {
		"Enhanced Metabolism","Flawed Release","Founder's Blessing",
		"Heavenly Restriction","Indefatigable","Maximum Firepower",
		"Perfect Form","Perfect Soul","Reckless Abandon"
	},
	Defense = {
		"Adaptation","Aegis","Enduring","Font of Vitality","Fortitude",
		"Hardy","Heightened Vitality","Immortal","Invincible",
		"Peerless Constitution","Protection","Resilient","Robust",
		"Safeguard","Stalwart Durability","Tough","Trauma Battery",
		"Unbreakable","Unyielding"
	},
	Support = {
		"Adrenaline","Courage Catalyst","Exhumation","Experimental Shells",
		"Explosive Fortune","First Aid","Font of Inspiration",
		"Fully Stocked","Gear Beginner","Gear Expert","Gear Intermediate",
		"Gear Master","Munitions Expert","Munitions Master",
		"Peerless Commander","Siphoning","Sixth Sense","Solo",
		"Soulfeed","Tatsujin"
	}
}

local function equipPerkByName(perkName, slotName, storage)
	local uuid = nil
	for id, info in pairs(storage) do
		if info.Name == perkName then
			uuid = id
			break
		end
	end
	if not uuid then return false, "not found" end
	pcall(function()
		getRemote:InvokeServer("S_Equipment", "Perk_State", uuid, "Equip", slotName)
	end)
	return true, uuid
end

local validPerkEntries = {}
for slotName, perks in pairs(PerksBySlot) do
	for _, perkName in ipairs(perks) do
		table.insert(validPerkEntries, perkName .. " [" .. slotName .. "]")
	end
end
table.sort(validPerkEntries)

AutoEquipPerkGroup:AddDropdown("PerkPriority1", {
	Values = validPerkEntries,
	Default = {},
	Multi = true,
	Text = "Priority 1",
})

AutoEquipPerkGroup:AddDropdown("PerkPriority2", {
	Values = validPerkEntries,
	Default = {},
	Multi = true,
	Text = "Priority 2",
})

AutoEquipPerkGroup:AddDropdown("PerkPriority3", {
	Values = validPerkEntries,
	Default = {},
	Multi = true,
	Text = "Priority 3",
})

AutoEquipPerkGroup:AddDivider()

getgenv().AutoEquipPerk = false
AutoEquipPerkGroup:AddToggle("AutoEquipPerkToggle", {
	Text = "Auto Equip Perks",
	Default = false,
})
Toggles.AutoEquipPerkToggle:OnChanged(function()
	getgenv().AutoEquipPerk = Toggles.AutoEquipPerkToggle.Value
	if not getgenv().AutoEquipPerk then return end
	if game.PlaceId ~= 14916516914 then
		Library:Notify({ Title = "Auto Equip Perk", Description = "Must be in lobby.", Time = 3 })
		getgenv().AutoEquipPerk = false
		Toggles.AutoEquipPerkToggle:SetValue(false)
		return
	end

	task.spawn(function()
		local function buildToEquip()
			local toEquip = {}
			local slotsHandled = {}
			local function collectPriority(dropId)
				local val = Options[dropId] and Options[dropId].Value
				if not val then return end
				local entries = {}
				for entry, isActive in pairs(val) do
					if isActive then table.insert(entries, entry) end
				end
				table.sort(entries)
				for _, entry in ipairs(entries) do
					local perk, slot = string.match(entry, "^(.+) %[(.+)%]$")
					if perk and slot and not slotsHandled[slot] then
						slotsHandled[slot] = true
						table.insert(toEquip, { perk = perk, slot = slot })
					end
				end
			end
			collectPriority("PerkPriority1")
			collectPriority("PerkPriority2")
			collectPriority("PerkPriority3")
			return toEquip
		end

		local toEquip = buildToEquip()
		if #toEquip == 0 then
			Library:Notify({ Title = "Auto Equip Perk", Description = "No perks configured.", Time = 3 })
			getgenv().AutoEquipPerk = false
			Toggles.AutoEquipPerkToggle:SetValue(false)
			return
		end

		Library:Notify({ Title = "Auto Equip Perk", Description = "Watching for " .. #toEquip .. " perk(s)...", Time = 3 })

		while getgenv().AutoEquipPerk do
			local slotIdx = lp:GetAttribute("Slot")
			local pData = getRemote:InvokeServer("Functions", "Settings", "Get")

			if pData and pData.Slots and slotIdx and pData.Slots[slotIdx] then
				local storage = pData.Slots[slotIdx].Perks.Storage
				local equipped = pData.Slots[slotIdx].Perks.Equipped
				local justEquipped = {}

				for _, entry in ipairs(toEquip) do
					local currentId = equipped[entry.slot]
					local currentName = currentId and storage[currentId] and storage[currentId].Name
					if currentName == entry.perk then continue end

					local ok, _ = equipPerkByName(entry.perk, entry.slot, storage)
					if ok then
						table.insert(justEquipped, "[✓] " .. entry.slot .. " → " .. entry.perk)
						task.wait(0.4)
					end
				end

				if #justEquipped > 0 then
					Library:Notify({
						Title = "Auto Equip Perk",
						Description = table.concat(justEquipped, "\n"),
						Time = 4
					})
				end
			end

			task.wait(3) 
		end
	end)
end)

AutoEquipPerkGroup:AddLabel("Stays on until toggled off.\nEquips as soon as perk is found.")

-- ==========================================
-- UPGRADES TAB : Skill Tree Groupbox
-- ==========================================

SkillTreeGroup:AddToggle("AutoSkillTree", {
	Text = "Auto Skill Tree",
	Default = false,
})
Toggles.AutoSkillTree:OnChanged(function()
	getgenv().AutoSkillTree = Toggles.AutoSkillTree.Value
	local plrData = GetPlayerData()

	if getgenv().AutoSkillTree then
		if game.PlaceId ~= 14916516914 then return end
		if not plrData or not plrData.Slots then return end
		task.spawn(function()
			while getgenv().AutoSkillTree do
				local slotIndex = lp:GetAttribute("Slot")
				if not slotIndex or not plrData.Slots[slotIndex] then task.wait(1) continue end
				local weapon = plrData.Slots[slotIndex].Weapon

				local middle = Options.MiddlePathDropdown.Value
				local left = Options.LeftPathDropdown.Value
				local right = Options.RightPathDropdown.Value

				local middlePath = SkillPaths[weapon] and SkillPaths[weapon][middle]
				local leftPath = SkillPaths.Support[left]
				local rightPath = SkillPaths.Defense[right]

				local p1 = Options.Priority1Dropdown.Value or "Middle"
				local p2 = Options.Priority2Dropdown.Value or "Left"
				local p3 = Options.Priority3Dropdown.Value or "None"

				local pathMap = { Left = leftPath, Middle = middlePath, Right = rightPath }
				local paths = {}
				local used = {}

				local function addPath(p)
					if not used[p] and pathMap[p] then
						table.insert(paths, pathMap[p])
						used[p] = true
					end
				end

				addPath(p1)
				addPath(p2)
				addPath(p3)

				for _, path in ipairs(paths) do
					if path then
						for _, skillId in ipairs(path) do
							if table.find(plrData.Slots[slotIndex].Skills.Unlocked, skillId) then continue end
							local success = getRemote:InvokeServer("S_Equipment", "Unlock", {skillId})
							if success then
								Library:Notify({
									Title = "Unlocked Skill",
									Description = "ID: " .. skillId,
									Time = 1
								})
							end
						end
					end
				end
				task.wait()
			end
		end)
	end
end)

SkillTreeGroup:AddDropdown("MiddlePathDropdown", {
	Values = {"Damage", "Critical"},
	Default = 2,
	Multi = false,
	Text = "Middle Path",
})

SkillTreeGroup:AddDropdown("LeftPathDropdown", {
	Values = {"Regen", "Cooldown Reduction"},
	Default = 2,
	Multi = false,
	Text = "Left Path",
})

SkillTreeGroup:AddDropdown("RightPathDropdown", {
	Values = {"Health", "Damage Reduction"},
	Default = 2,
	Multi = false,
	Text = "Right Path",
})

SkillTreeGroup:AddDropdown("Priority1Dropdown", {
	Values = {"Left", "Middle", "Right", "None"},
	Default = 2,
	Multi = false,
	Text = "Priority 1",
})

SkillTreeGroup:AddDropdown("Priority2Dropdown", {
	Values = {"Left", "Middle", "Right", "None"},
	Default = 1,
	Multi = false,
	Text = "Priority 2",
})

SkillTreeGroup:AddDropdown("Priority3Dropdown", {
	Values = {"Left", "Middle", "Right", "None"},
	Default = 4,
	Multi = false,
	Text = "Priority 3",
})

-- ==========================================
-- MISC TAB : Slot Groupbox
-- ==========================================

SlotGroup:AddToggle("AutoSelectSlot", {
	Text = "Auto Select Slot",
	Default = false,
})
Toggles.AutoSelectSlot:OnChanged(function()
	getgenv().AutoSlot = Toggles.AutoSelectSlot.Value
	if getgenv().AutoSlot then
		task.spawn(function()
			while getgenv().AutoSlot do
				if game.PlaceId ~= 13379208636 then break end

				local selectedSlot = Options.SelectSlotDropdown.Value
				local slotLetter = string.sub(selectedSlot, -1)
				local lp = game:GetService("Players").LocalPlayer

				if lp:GetAttribute("Slot") ~= slotLetter then
					lp:SetAttribute("Slot", slotLetter)
					Library:Notify({
						Title = "Auto Slot",
						Description = "Bypassed UI. Forced Slot " .. slotLetter .. "!",
						Time = 2
					})
				end
				task.wait(1)
			end
		end)
	end
end)

SlotGroup:AddDropdown("SelectSlotDropdown", {
	Values = {"Slot A", "Slot B", "Slot C"},
	Default = 1,
	Multi = false,
	Text = "Select Slot",
})

SlotGroup:AddToggle("AutoPlayToggle", {
	Text = "Auto Play When Slot Met",
	Default = false,
})
Toggles.AutoPlayToggle:OnChanged(function()
	getgenv().AutoPlay = Toggles.AutoPlayToggle.Value
	if getgenv().AutoPlay then
		task.spawn(function()
			while getgenv().AutoPlay do
				if game.PlaceId ~= 13379208636 then break end

				local lp = game:GetService("Players").LocalPlayer
				local selectedSlot = Options.SelectSlotDropdown.Value
				local slotLetter = string.sub(selectedSlot, -1)

				if lp:GetAttribute("Slot") == slotLetter then
					Library:Notify({ Title = "Auto Play", Description = "Teleporting to Lobby...", Time = 3 })
					getgenv().AutoStart = true
					pcall(function() Toggles.AutoStartToggle:SetValue(true) end)
					TeleportToLobbySafe()
					break
				end
				task.wait(0.5)
			end
		end)
	end
end)

PrestigeGroup:AddToggle("AutoPrestigeToggle", {
	Text = "Auto Prestige",
	Default = false,
})
Toggles.AutoPrestigeToggle:OnChanged(function()
	getgenv().AutoPrestige = Toggles.AutoPrestigeToggle.Value
	if getgenv().AutoPrestige then
		if game.PlaceId ~= 14916516914 then return end
		task.spawn(function()
			local pData = GetPlayerData()
			if not pData or not pData.Slots then return end
			local slotIdx = lp:GetAttribute("Slot")
			if not slotIdx or not pData.Slots[slotIdx] then return end
			local gold = pData.Slots[slotIdx].Currency.Gold
			local requiredGold = Options.PrestigeGoldSlider.Value * 1000000

			if gold < requiredGold then
				Library:Notify({ Title = "Auto Prestige", Description = "Not enough gold (" .. gold .. "/" .. requiredGold .. ")", Time = 4 })
				getgenv().AutoPrestige = false
				Toggles.AutoPrestigeToggle:SetValue(false)
				return
			end

			while getgenv().AutoPrestige do
				local guessList = {}
				local selectedPriorities = Options.PrestigeTalentPriority and Options.PrestigeTalentPriority.Value or {}
				for _, talent in ipairs(Talents) do if selectedPriorities[talent] then table.insert(guessList, talent) end end
				for _, talent in ipairs(Talents) do if not selectedPriorities[talent] then table.insert(guessList, talent) end end

				for _, Memory in ipairs(guessList) do
					if not getgenv().AutoPrestige then break end
					local success = getRemote:InvokeServer("S_Equipment", "Prestige", {Boosts = Options.SelectBoostDropdown.Value, Talents = Memory})
					if success then
						Library:Notify({
							Title = "Successfully Prestiged",
							Description = "Prestiged with " .. Options.SelectBoostDropdown.Value .. " and " .. Memory,
							Time = 5
						})
						break
					end
					task.wait(0.1)
				end
				task.wait(1)
			end
		end)
	end
end)

PrestigeGroup:AddDropdown("SelectBoostDropdown", {
	Values = {"Luck Boost", "EXP Boost", "Gold Boost"},
	Default = 1,
	Multi = false,
	Text = "Select Boost",
})

PrestigeGroup:AddDropdown("PrestigeTalentPriority", {
	Values = Talents,
	Default = {},
	Multi = true,
	Text = "Talent Priority",
})

PrestigeGroup:AddSlider("PrestigeGoldSlider", {
	Text = "Prestige Gold (in millions)",
	Default = 0,
	Min = 0,
	Max = 500,
	Rounding = 0,
})

-- ==========================================
-- LOBBY TAB : Auto Quest Groupbox
-- ==========================================

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

getgenv().AutoClaimQuest = false

AutoQuestGroup:AddToggle("AutoClaimQuestToggle", {
	Text = "Auto Claim Quests",
	Default = false,
})

Toggles.AutoClaimQuestToggle:OnChanged(function()
	getgenv().AutoClaimQuest = Toggles.AutoClaimQuestToggle.Value
	if not getgenv().AutoClaimQuest then return end

	if game.PlaceId ~= 14916516914 then
		Library:Notify({ Title = "Auto Quest", Description = "Must be in lobby.", Time = 3 })
		getgenv().AutoClaimQuest = false
		Toggles.AutoClaimQuestToggle:SetValue(false)
		return
	end

	task.spawn(function()
		while getgenv().AutoClaimQuest do
			local ok, pData = pcall(function() return getRemote:InvokeServer("Functions", "Settings", "Get") end)
			local currentSlot = lp:GetAttribute("Slot")

			if ok and pData and currentSlot then
				local slotData = pData.Slots and pData.Slots[currentSlot]
				if slotData and slotData.Quests then
					local function processCategory(catName, questsTbl)
						if type(questsTbl) ~= "table" then return end
						for questId, qInfo in pairs(questsTbl) do
							if type(qInfo) == "table" then
								local tag = qInfo.Tag or tostring(questId)
								local current = qInfo.Current or 0
								local amount = qInfo.Amount
								local rewarded = qInfo.Rewarded
								if rewarded == nil or rewarded == false then
									local targetAmount = type(amount) == "number" and amount or QuestAmounts[tag]
									if targetAmount and current >= targetAmount then
										local claimOk, result = pcall(function()
											return getRemote:InvokeServer("Functions", "Quest", tag, catName)
										end)
										if claimOk and type(result) == "table" then
											Library:Notify({ Title = "Auto Quest", Description = "[✓] Claimed: " .. tag, Time = 3 })
										end
										task.wait(0.5)
									end
								end
							end
						end
					end

					local standardCats = {"Daily", "Weekly", "Main", "Side", "Spears"}
					for _, cat in ipairs(standardCats) do
						if slotData.Quests[cat] then
							processCategory(cat, slotData.Quests[cat])
						end
					end
				end
			end
			task.wait(10)
		end
	end)
end)

AutoQuestGroup:AddLabel("Automatically claims finished quests.")

-- ==========================================
-- LOBBY TAB : Auto Boost Groupbox
-- ==========================================

local AutoBoostGroup = Tabs.Main:AddLeftGroupbox("Auto Boost")

getgenv().AutoBoostEnabled = false
getgenv().BuyIfEmpty = false

AutoBoostGroup:AddToggle("AutoBuyBoostToggle", {
	Text = "Buy if Empty (Uses Gems)",
	Default = false,
})

Toggles.AutoBuyBoostToggle:OnChanged(function()
	getgenv().BuyIfEmpty = Toggles.AutoBuyBoostToggle.Value
	if not getgenv().BuyIfEmpty then return end
	
	if game.PlaceId ~= 14916516914 then return end

	task.spawn(function()
		while getgenv().BuyIfEmpty do
			local pData = getRemote:InvokeServer("Functions", "Settings", "Get")
			if pData and pData.Boosts then
				local boostType = Options.BoostTypeDropdown and Options.BoostTypeDropdown.Value or "2x Gold Boost [30m]"
				
				local boostKey = nil
				if string.find(boostType, "Gold") then boostKey = "Gold"
				elseif string.find(boostType, "XP") then boostKey = "XP"
				elseif string.find(boostType, "Luck") then boostKey = "Luck"
				end

				local timer = boostKey and (pData.Boosts[boostKey] or 0) or 0
				local slotIdx = lp:GetAttribute("Slot")
				local hasItem = pData.Slots and slotIdx and pData.Slots[slotIdx] and pData.Slots[slotIdx].Inventory and pData.Slots[slotIdx].Inventory.Items and (pData.Slots[slotIdx].Inventory.Items[boostType] or 0) > 0

				if timer == 0 and not hasItem then
					local ok, result = pcall(function()
						return getRemote:InvokeServer("S_Market", "Buy", boostType, 1, nil)
					end)
					if ok and result then
						Library:Notify({ Title = "Auto Buy", Description = "[✓] Bought 1x " .. boostType, Time = 3 })
					end
				end
			end
			task.wait(3) 
		end
	end)
end)

AutoBoostGroup:AddToggle("AutoBoostToggle", {
	Text = "Auto Use Boost",
	Default = false,
})

Toggles.AutoBoostToggle:OnChanged(function()
	getgenv().AutoBoostEnabled = Toggles.AutoBoostToggle.Value
	if not getgenv().AutoBoostEnabled then return end
	
	if game.PlaceId ~= 14916516914 then
		Library:Notify({ Title = "Auto Boost", Description = "Must be in lobby.", Time = 3 })
		getgenv().AutoBoostEnabled = false
		Toggles.AutoBoostToggle:SetValue(false)
		return
	end

	task.spawn(function()
		while getgenv().AutoBoostEnabled do
			local pData = getRemote:InvokeServer("Functions", "Settings", "Get")
			if pData and pData.Boosts then
				local boostType = Options.BoostTypeDropdown and Options.BoostTypeDropdown.Value or "2x Gold Boost [30m]"
				
				local boostKey = nil
				if string.find(boostType, "Gold") then boostKey = "Gold"
				elseif string.find(boostType, "XP") then boostKey = "XP"
				elseif string.find(boostType, "Luck") then boostKey = "Luck"
				end

				local timer = boostKey and (pData.Boosts[boostKey] or 0) or 0
				local slotIdx = lp:GetAttribute("Slot")
				local hasItem = pData.Slots and slotIdx and pData.Slots[slotIdx] and pData.Slots[slotIdx].Inventory and pData.Slots[slotIdx].Inventory.Items and (pData.Slots[slotIdx].Inventory.Items[boostType] or 0) > 0

				if timer == 0 and hasItem then
					local ok, result = pcall(function()
						return getRemote:InvokeServer("S_Inventory", "Item", boostType)
					end)
					if ok and type(result) == "table" then
						Library:Notify({ Title = "Auto Use", Description = "[✓] Used " .. boostType .. "!", Time = 4 })
					end
				end
			end
			task.wait(2) 
		end
	end)
end)

AutoBoostGroup:AddDropdown("BoostTypeDropdown", {
	Values = {
		"2x Gold Boost [30m]", "2x Gold Boost [1h]", "2x Gold Boost [2h]",
		"2x XP Boost [30m]",   "2x XP Boost [1h]",   "2x XP Boost [2h]",
		"2x Luck Boost [30m]", "2x Luck Boost [1h]", "2x Luck Boost [2h]",
	},
	Default = 1,
	Multi = false,
	Text = "Boost Type",
})

AutoBoostGroup:AddLabel("Uses from inventory first.\nBuys from market if empty.")

-- ==========================================
-- MISC TAB : Family Roll Groupbox
-- ==========================================

FamilyRollGroup:AddToggle("AutoRollToggle", {
	Text = "Auto Roll",
	Default = false,
})
FamilyRollGroup:AddToggle("AutoDepositToggle", {
	Text = "Auto Deposit",
	Default = false,
})
Toggles.AutoDepositToggle:OnChanged(function()
	getgenv().AutoDeposit = Toggles.AutoDepositToggle.Value
end)
Toggles.AutoRollToggle:OnChanged(function()
	getgenv().AutoRoll = Toggles.AutoRollToggle.Value
	if getgenv().AutoRoll then
		if game.PlaceId ~= 13379208636 then
			Library:Notify({
				Title = "GabBoboBading",
				Description = "You must be in the lobby to use family roll features.",
				Time = 3
			})
			return
		end
		task.spawn(function()
			while getgenv().AutoRoll do
				local targets, rarities

				local familySelected = Options.SelectFamily.Value
				if familySelected then
					targets = {}
					for familyName, isEnabled in pairs(familySelected) do
						if isEnabled then
							table.insert(targets, string.lower(familyName))
						end
					end
					if #targets == 0 then targets = nil end
				end

				local raritySelected = Options.SelectFamilyRarity.Value
				if raritySelected then
					rarities = {}
					for rarityName, isEnabled in pairs(raritySelected) do
						if isEnabled then
							table.insert(rarities, string.lower(rarityName))
						end
					end
				end

				local success, spinsLeft, familyName = pcall(function()
					return getRemote:InvokeServer("Family", "Roll")
				end)

				if not success or not familyName then
					continue
				end

				if spinsLeft and spinsLeft <= 0 then
					getgenv().AutoRoll = false
					Toggles.AutoRollToggle:SetValue(false)
					Library:Notify({ Title = "GabBoboBading", Description = "Out of spins!", Time = 5 })
					break
				end

				local familyNameLower = string.lower(familyName)
				local familyString = PlayerGui.Interface.Customisation.Family.Family.Title.Text
				local familyRarity = string.lower(string.match(familyString, "%((.-)%)") or "")

				local stopRolling = false
				if targets and table.find(targets, familyNameLower) then stopRolling = true end
				if rarities and table.find(rarities, familyRarity) then stopRolling = true end
				if familyRarity == "mythical" then stopRolling = true end

				if stopRolling then
					getgenv().AutoRoll = false
					pcall(function()
						if Library and Library.Toggles and Library.Toggles.AutoRollToggle then
							Library.Toggles.AutoRollToggle:SetValue(false)
						end
					end)

					if familyRarity == "mythical" and getgenv().MythicalFamilyWebhook then
						local menuWebhook = Options.WebhookUrl_Menu and Options.WebhookUrl_Menu.Value or ""
						menuWebhook = menuWebhook:gsub("^%s*(.-)%s*$", "%1")

						if menuWebhook ~= "" and string.match(menuWebhook, "^https?://") then
							local cb = string.char(96, 96, 96)
							local payload = {
								content = "MYTHICAL FAMILY ROLLED! @everyone",
								embeds = {{
									title = "Family Roll Success",
									color = 0xff0000,
									fields = {
										{
											name = "Information",
											value = cb .. "\nUser: " .. lp.Name .. "\nFamily: " .. tostring(familyString) .. "\n\n" .. cb,
											inline = true
										}
									},
									footer = {
										text = "GabBoboBading • " .. DateTime.now():FormatLocalTime("LTS", "en-us")
									},
									timestamp = DateTime.now():ToIsoDate()
								}}
							}
							local req = (syn and syn.request) or (http and http.request) or http_request or request
							if req then
								pcall(function()
									req({
										Url = menuWebhook,
										Method = "POST",
										Headers = { ["Content-Type"] = "application/json" },
										Body = HttpService:JSONEncode(payload)
									})
								end)
							end
						end
					end

					pcall(function()
						Library:Notify({
							Title = "GabBoboBading",
							Description = "Target family rolled: " .. familyString,
							Time = 5,
						})
					end)

					if getgenv().AutoDeposit then
						local success, result = pcall(function()
							return getRemote:InvokeServer("Family", "Store")
						end)
						if success and result then
							pcall(function()
								Library:Notify({
									Title = "GabBoboBading",
									Description = "Family deposited! Continuing roll...",
									Time = 3,
								})
							end)
							getgenv().AutoRoll = true
							pcall(function()
								if Library and Library.Toggles and Library.Toggles.AutoRollToggle then
									Library.Toggles.AutoRollToggle:SetValue(true)
								end
							end)
						end
						return
					end

					return
				end
			end
		end)
	end
end)

FamilyRollGroup:AddDropdown("SelectFamily", {
	Values = {
		-- Epic
		"Zoe", "Tybur", "Leonhart", "Galliard", "Finger", "Braun", "Arlert", "Ksaver",
		-- Legendary
		"Ackerman", "Yeager", "Reiss",
		-- Mythical
		"Fritz", "Helos",
	},
	Default = {},
	Multi = true,
	Text = "Select Families",
})
Options.SelectFamily:OnChanged(function()
	local selected = {}
	for name, isEnabled in pairs(Options.SelectFamily.Value) do
		if isEnabled then table.insert(selected, name) end
	end
end)

FamilyRollGroup:AddDropdown("SelectFamilyRarity", {
	Values = familyRaritiesOptions,
	Default = {},
	Multi = true,
	Text = "Stop At",
})

FamilyRollGroup:AddLabel("Mythical families won't be rolled", true)

FamilyRollGroup:AddButton({
	Text = "Check Stats",
	Func = function()
		task.spawn(function()
			local pData = getRemote:InvokeServer("Functions", "Settings", "Get")
			if not pData then
				Library:Notify({ Title = "Family Stats", Description = "Failed to get data.", Time = 5 })
				return
			end

			-- Spins
			local spins = tostring(pData.Spins or 0)

			-- Current slot family
			local slotIdx = lp:GetAttribute("Slot") or "A"
			local slotData = pData.Slots and pData.Slots[slotIdx]
			local currentFamily = slotData and slotData.Avatar and slotData.Avatar.Family or "Unknown"
			local totalSpins = slotData and slotData.Total_Spins or 0

			-- Storage families
			local storageNames = {}
			if slotData and slotData.Inventory and slotData.Inventory.Families then
				for _, name in pairs(slotData.Inventory.Families) do
					table.insert(storageNames, tostring(name))
				end
			end
			local storageStr = #storageNames > 0 and table.concat(storageNames, ", ") or "Empty"

			Library:Notify({
				Title = "Family Stats",
				Description =
					"Current: " .. currentFamily .. "\n" ..
					"Spins: " .. spins .. "\n" ..
					"Storage: " .. storageStr,
				Time = 10
			})
		end)
	end,
})

-- ==========================================
-- WEBHOOKS
-- ==========================================

MissionRightGroup:AddButton({
	Text = "Teleport to Lobby",
	Func = function()
		Library:Notify({ Title = "Teleporting", Description = "Heading to lobby...", Time = 3 })
		local loadingInterface = PlayerGui:FindFirstChild("Loading_Interface")
		if loadingInterface and loadingInterface:FindFirstChild("Loader") then
			loadingInterface.Loader.BackgroundTransparency = 0
			loadingInterface.Loader.Visible = true
			if loadingInterface.Loader:FindFirstChild("Title") then
				loadingInterface.Loader.Title.Visible = true
			end
		end
		task.wait(0.5)
		pcall(function() TeleportService:Teleport(14916516914, lp) end)
	end
})

MissionRightGroup:AddToggle("AutoReturnLobbyRunToggle", {
	Text = "Return to Lobby After X Runs",
	Default = false,
})

MissionRightGroup:AddSlider("ReturnAfterRunsSlider", {
	Text = "Return After Runs",
	Default = 10,
	Min = 1,
	Max = 50,
	Rounding = 0,
})

MissionRightGroup:AddLabel("Teleports to lobby after X runs.")

getgenv().AutoReturnLobbyRun = false
getgenv()._runCounter = 0

Toggles.AutoReturnLobbyRunToggle:OnChanged(function()
	getgenv().AutoReturnLobbyRun = Toggles.AutoReturnLobbyRunToggle.Value
	if not getgenv().AutoReturnLobbyRun then
		pcall(function() writefile("./GabBoboBading/aotr/slider_run_counter.txt", "0") end)
	end
end)

MissionWebhookGroup:AddToggle("ToggleRewardWebhook", {
	Text = "Reward Webhook",
	Default = false,
})
Toggles.ToggleRewardWebhook:OnChanged(function()
	getgenv().RewardWebhook = Toggles.ToggleRewardWebhook.Value
end)

MissionWebhookGroup:AddInput("WebhookUrl_Mission", {
	Default = "",
	Text = "Webhook URL",
	Placeholder = "https://discord.com/api/webhooks/...",
})

MenuWebhookGroup:AddToggle("ToggleMythicalFamilyWebhook", {
	Text = "Mythical Family Webhook",
	Default = false,
})
Toggles.ToggleMythicalFamilyWebhook:OnChanged(function()
	getgenv().MythicalFamilyWebhook = Toggles.ToggleMythicalFamilyWebhook.Value
end)

MenuWebhookGroup:AddInput("WebhookUrl_Menu", {
	Default = "",
	Text = "Webhook URL",
	Placeholder = "https://discord.com/api/webhooks/...",
})

SettingsGroup:AddToggle("AutoHideToggle", {
	Text = "Auto Hide GUI",
	Default = false,
})

SettingsGroup:AddToggle("Disable3DRendering", {
	Text = "Disable 3D Rendering (FPS Boost)",
	Default = false,
})
Toggles.Disable3DRendering:OnChanged(function()
	RunService:Set3dRenderingEnabled(not Toggles.Disable3DRendering.Value)
end)

SettingsGroup:AddLabel("Menu toggle"):AddKeyPicker("MenuKeybind", { Default = "RightControl", NoUI = true, Text = "Menu keybind" })
Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

ThemeManager:SetFolder("GabBoboBading/aotr")
local placeId = game.PlaceId
local configSubfolder

local missionFlags = {"AutoKillToggle", "MasteryFarmToggle", "MasteryModeDropdown", "MovementModeDropdown", "FarmOptionsDropdown", "HoverSpeedSlider", "FloatHeightSlider", "AutoReloadToggle", "AutoEscapeToggle", "AutoSkipToggle", "AutoRetryToggle", "AutoChestToggle", "DeleteMapToggle", "DeleteDamageTextToggle", "SoloOnlyToggle", "AutoReturnLobbyToggle", "AutoReturnLobbyRunToggle", "ReturnAfterRunsSlider", "ToggleRewardWebhook", "WebhookUrl_Mission"}
local lobbyFlags = {"AutoStartToggle", "StartTypeDropdown", "MissionMapDropdown", "MissionObjectiveDropdown", "MissionDifficultyDropdown", "RaidMapDropdown", "RaidObjectiveDropdown", "RaidDifficultyDropdown", "ModifiersDropdown", "AutoUpgradeToggle", "AutoEnhanceToggle", "PerkSlotDropdown", "SelectPerksDropdown", "AutoEquipPerkToggle", "PerkPriority1", "PerkPriority2", "PerkPriority3", "AutoSkillTree", "MiddlePathDropdown", "LeftPathDropdown", "RightPathDropdown", "Priority1Dropdown", "Priority2Dropdown", "Priority3Dropdown", "AutoPrestigeToggle", "SelectBoostDropdown", "PrestigeTalentPriority", "PrestigeGoldSlider", "AutoGoldBoostToggle", "GoldBoostTypeDropdown", "AutoBuyBoostToggle", "AutoBoostToggle", "BoostTypeDropdown", "AutoClaimQuestToggle"}
local menuFlags = {"AutoSelectSlot", "SelectSlotDropdown", "AutoPlayToggle", "AutoRollToggle", "AutoDepositToggle", "SelectFamily", "SelectFamilyRarity", "ToggleMythicalFamilyWebhook", "WebhookUrl_Menu"}

local ignoreList = {}

if placeId == 13379208636 then
	configSubfolder = "GabBoboBading/aotr/MainMenu"
	for _, v in ipairs(missionFlags) do table.insert(ignoreList, v) end
	for _, v in ipairs(lobbyFlags) do table.insert(ignoreList, v) end
elseif placeId == 14916516914 then
	configSubfolder = "GabBoboBading/aotr/Lobby"
	for _, v in ipairs(missionFlags) do table.insert(ignoreList, v) end
	for _, v in ipairs(menuFlags) do table.insert(ignoreList, v) end
else
	configSubfolder = "GabBoboBading/aotr/Mission"
	for _, v in ipairs(lobbyFlags) do table.insert(ignoreList, v) end
	for _, v in ipairs(menuFlags) do table.insert(ignoreList, v) end
end

SaveManager:SetFolder(configSubfolder)
SaveManager:SetIgnoreIndexes(ignoreList)

SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

ThemeManager:ApplyTheme("Jester")
SaveManager:LoadAutoloadConfig()

Library:OnUnload(function()
	Library.Unloaded = true
end)

task.spawn(function()
	while not Library.Unloaded do
		local success, err = pcall(ExecuteImmediateAutomation)
		task.wait(0.5)
	end
end)

-- ==========================================
-- LOBBY PIPELINE AUTOMATION
-- ==========================================
task.spawn(function()
	if game.PlaceId ~= 14916516914 then return end
	task.wait(3) 

	Library:Notify({ Title = "Pipeline", Description = "Starting lobby pipeline...", Time = 3 })

	local function waitForToggle(flagName, timeoutSecs)
		local start = os.clock()
		while getgenv()[flagName] do
			if os.clock() - start > (timeoutSecs or 60) then break end
			task.wait(1)
		end
	end

	if Toggles.AutoUpgradeToggle and Toggles.AutoUpgradeToggle.Value then
		Library:Notify({ Title = "Pipeline [1/6]", Description = "Upgrading gear...", Time = 3 })
		Toggles.AutoUpgradeToggle:SetValue(true)
		waitForToggle("AutoUpgrade", 30)
		Library:Notify({ Title = "Pipeline [1/6]", Description = "[✓] Gear upgrade done.", Time = 2 })
		task.wait(1)
	end

	if Toggles.AutoSkillTree and Toggles.AutoSkillTree.Value then
		Library:Notify({ Title = "Pipeline [2/6]", Description = "Upgrading skill tree...", Time = 3 })
		Toggles.AutoSkillTree:SetValue(true)
		waitForToggle("AutoSkillTree", 30)
		Library:Notify({ Title = "Pipeline [2/6]", Description = "[✓] Skill tree done.", Time = 2 })
		task.wait(1)
	end

	if Toggles.AutoEquipPerkToggle and Toggles.AutoEquipPerkToggle.Value then
		Library:Notify({ Title = "Pipeline [3/6]", Description = "Equipping perks...", Time = 3 })
		Toggles.AutoEquipPerkToggle:SetValue(true)
		waitForToggle("AutoEquipPerk", 30)
		Library:Notify({ Title = "Pipeline [3/6]", Description = "[✓] Perks equipped.", Time = 2 })
		task.wait(1)
	end

	if Toggles.AutoBuyBoostToggle and Toggles.AutoBuyBoostToggle.Value then
		Library:Notify({ Title = "Pipeline [4/6]", Description = "Checking boost — buying if empty...", Time = 3 })
		Toggles.AutoBuyBoostToggle:SetValue(true)
		task.wait(5)
		Library:Notify({ Title = "Pipeline [4/6]", Description = "[✓] Boost buy check done.", Time = 2 })
	end

	if Toggles.AutoBoostToggle and Toggles.AutoBoostToggle.Value then
		Library:Notify({ Title = "Pipeline [4/6]", Description = "Using boost if available...", Time = 3 })
		Toggles.AutoBoostToggle:SetValue(true)
		task.wait(5)
		Library:Notify({ Title = "Pipeline [4/6]", Description = "[✓] Boost use check done.", Time = 2 })
	end

	if Toggles.AutoPrestigeToggle and Toggles.AutoPrestigeToggle.Value then
		Library:Notify({ Title = "Pipeline [5/6]", Description = "Checking prestige gold...", Time = 3 })
		local pData = getRemote:InvokeServer("Functions", "Settings", "Get")
		local slotIdx = lp:GetAttribute("Slot")
		if pData and pData.Slots and slotIdx and pData.Slots[slotIdx] then
			local gold = pData.Slots[slotIdx].Currency.Gold
			local required = Options.PrestigeGoldSlider and Options.PrestigeGoldSlider.Value * 1000000 or 0
			if gold >= required then
				Library:Notify({ Title = "Pipeline [5/6]", Description = "Gold OK (" .. gold .. "). Prestiging...", Time = 3 })
				Toggles.AutoPrestigeToggle:SetValue(true)
				waitForToggle("AutoPrestige", 60)
				Library:Notify({ Title = "Pipeline [5/6]", Description = "[✓] Prestige done.", Time = 2 })
				task.wait(1)
			else
				Library:Notify({ Title = "Pipeline [5/6]", Description = "[✗] Not enough gold (" .. gold .. "/" .. required .. ")", Time = 4 })
			end
		end
	end

	if Toggles.AutoStartToggle and Toggles.AutoStartToggle.Value then
		Library:Notify({ Title = "Pipeline [6/6]", Description = "[✓] All done! Starting mission...", Time = 4 })
		Toggles.AutoStartToggle:SetValue(true)
	end
end)

task.spawn(function()
	local lastState = nil
	while not Library.Unloaded do
		local placeId = game.PlaceId
		local isMainMenu = placeId == 13379208636
		local isLobbyPlace = placeId == 14916516914

		if lastState ~= placeId then
			lastState = placeId
			Tabs.Main:SetVisible(isLobbyPlace)
			Tabs.Mission:SetVisible(not isMainMenu and not isLobbyPlace)
			Tabs.Misc:SetVisible(isLobbyPlace)
			Tabs.Menu:SetVisible(isMainMenu)
		end
		task.wait(1)
	end
end)

local virtualUser = game:GetService("VirtualUser")
lp.Idled:Connect(function()
	virtualUser:CaptureController()
	virtualUser:ClickButton2(Vector2.new())
end)

task.spawn(function()
	task.wait(0.5) 
	if getgenv().DeleteMap then DeleteMap() end
	if Toggles.AutoHideToggle.Value then
		Library:Toggle(false)
		Library:Notify({ Title = "GabBoboBading", Description = "Auto Hid GUI", Time = 2 })
	end
end)