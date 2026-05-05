-- aotr
repeat task.wait() until game:IsLoaded()

-- Only run in Lobby (14916516914) or Main Menu (13379208636)
local allowedPlaces = {[14916516914] = true, [13379208636] = true}
if not allowedPlaces[game.PlaceId] then return end

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
-- ==========================================
-- OBSIDIAN UI LIBRARY LOAD

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
	Misc = Window:AddTab("Misc", "boxes"),
	Menu = Window:AddTab("Main Menu", "home"),
	Settings = Window:AddTab("Settings", "settings"),
}

local AutoStartGroup = Tabs.Main:AddRightGroupbox("Auto Start")

local UpgradesGroup = Tabs.Main:AddLeftGroupbox("Upgrades")
local SkillTreeGroup = Tabs.Main:AddRightGroupbox("Skill Tree")
local PrestigeGroup = Tabs.Main:AddLeftGroupbox("Prestige")
local AutoQuestGroup = Tabs.Main:AddRightGroupbox("Auto Quest")

local SlotGroup = Tabs.Menu:AddLeftGroupbox("Slot")
local FamilyRollGroup = Tabs.Menu:AddRightGroupbox("Family Roll")
local SettingsGroup = Tabs.Misc:AddLeftGroupbox("Settings")

local MenuWebhookGroup = Tabs.Menu:AddLeftGroupbox("Webhook")

-- ==========================================
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

				local anyUpgraded = false
				for upg, lvl in next, upgrades do
					if getRemote:InvokeServer("S_Equipment", "Upgrade", upg) then
						anyUpgraded = true
						Library:Notify({
							Title = "Upgraded " .. string.gsub(upg, "_", " "),
							Description = "Level " .. tostring(lvl),
							Time = 1.5
						})
						task.wait(0.3)
					end
				end

				-- Nothing left to upgrade — stop and chain to next step
				if not anyUpgraded then
					getgenv().AutoUpgrade = false
					Toggles.AutoUpgradeToggle:SetValue(false)
					Library:Notify({ Title = "Auto Upgrade", Description = "[✓] All upgrades done.", Time = 2 })
					-- Chain: trigger Auto Enhance if toggle is on
					if Toggles.AutoEnhanceToggle and Toggles.AutoEnhanceToggle.Value then
						Toggles.AutoEnhanceToggle:SetValue(false)
						task.wait(0.2)
						Toggles.AutoEnhanceToggle:SetValue(true)
					elseif Toggles.AutoSkillTree and Toggles.AutoSkillTree.Value then
						Toggles.AutoSkillTree:SetValue(false)
						task.wait(0.2)
						Toggles.AutoSkillTree:SetValue(true)
					elseif Toggles.AutoEquipPerkToggle and Toggles.AutoEquipPerkToggle.Value then
						Toggles.AutoEquipPerkToggle:SetValue(false)
						task.wait(0.2)
						Toggles.AutoEquipPerkToggle:SetValue(true)
					elseif Toggles.AutoBuyBoostToggle and Toggles.AutoBuyBoostToggle.Value then
						Toggles.AutoBuyBoostToggle:SetValue(false)
						task.wait(0.2)
						Toggles.AutoBuyBoostToggle:SetValue(true)
					elseif Toggles.AutoBoostToggle and Toggles.AutoBoostToggle.Value then
						Toggles.AutoBoostToggle:SetValue(false)
						task.wait(0.2)
						Toggles.AutoBoostToggle:SetValue(true)
					elseif Toggles.AutoPrestigeToggle and Toggles.AutoPrestigeToggle.Value then
						Toggles.AutoPrestigeToggle:SetValue(false)
						task.wait(0.2)
						Toggles.AutoPrestigeToggle:SetValue(true)
					elseif Toggles.AutoStartToggle and Toggles.AutoStartToggle.Value then
						Toggles.AutoStartToggle:SetValue(false)
						task.wait(0.2)
						Toggles.AutoStartToggle:SetValue(true)
					end
					break
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
			Library:Notify({ Title = "Auto Enhance", Description = "[✓] Enhance done.", Time = 2 })
			-- Chain to next step
			if Toggles.AutoSkillTree and Toggles.AutoSkillTree.Value then
				Toggles.AutoSkillTree:SetValue(false) task.wait(0.2) Toggles.AutoSkillTree:SetValue(true)
			elseif Toggles.AutoEquipPerkToggle and Toggles.AutoEquipPerkToggle.Value then
				Toggles.AutoEquipPerkToggle:SetValue(false) task.wait(0.2) Toggles.AutoEquipPerkToggle:SetValue(true)
			elseif Toggles.AutoBuyBoostToggle and Toggles.AutoBuyBoostToggle.Value then
				Toggles.AutoBuyBoostToggle:SetValue(false) task.wait(0.2) Toggles.AutoBuyBoostToggle:SetValue(true)
			elseif Toggles.AutoBoostToggle and Toggles.AutoBoostToggle.Value then
				Toggles.AutoBoostToggle:SetValue(false) task.wait(0.2) Toggles.AutoBoostToggle:SetValue(true)
			elseif Toggles.AutoPrestigeToggle and Toggles.AutoPrestigeToggle.Value then
				Toggles.AutoPrestigeToggle:SetValue(false) task.wait(0.2) Toggles.AutoPrestigeToggle:SetValue(true)
			elseif Toggles.AutoStartToggle and Toggles.AutoStartToggle.Value then
				Toggles.AutoStartToggle:SetValue(false) task.wait(0.2) Toggles.AutoStartToggle:SetValue(true)
			end
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
				local allCorrect = true

				for _, entry in ipairs(toEquip) do
					local currentId = equipped[entry.slot]
					local currentName = currentId and storage[currentId] and storage[currentId].Name
					if currentName == entry.perk then continue end

					allCorrect = false
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

				-- All perks already correct — stop and chain
				if allCorrect then
					getgenv().AutoEquipPerk = false
					Toggles.AutoEquipPerkToggle:SetValue(false)
					Library:Notify({ Title = "Auto Equip Perk", Description = "[✓] All perks equipped.", Time = 2 })
					if Toggles.AutoBuyBoostToggle and Toggles.AutoBuyBoostToggle.Value then
						Toggles.AutoBuyBoostToggle:SetValue(false) task.wait(0.2) Toggles.AutoBuyBoostToggle:SetValue(true)
					elseif Toggles.AutoBoostToggle and Toggles.AutoBoostToggle.Value then
						Toggles.AutoBoostToggle:SetValue(false) task.wait(0.2) Toggles.AutoBoostToggle:SetValue(true)
					elseif Toggles.AutoPrestigeToggle and Toggles.AutoPrestigeToggle.Value then
						Toggles.AutoPrestigeToggle:SetValue(false) task.wait(0.2) Toggles.AutoPrestigeToggle:SetValue(true)
					elseif Toggles.AutoStartToggle and Toggles.AutoStartToggle.Value then
						Toggles.AutoStartToggle:SetValue(false) task.wait(0.2) Toggles.AutoStartToggle:SetValue(true)
					end
					break
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

				local anyUnlocked = false
				for _, path in ipairs(paths) do
					if path then
						for _, skillId in ipairs(path) do
							if table.find(plrData.Slots[slotIndex].Skills.Unlocked, skillId) then continue end
							local success = getRemote:InvokeServer("S_Equipment", "Unlock", {skillId})
							if success then
								anyUnlocked = true
								Library:Notify({
									Title = "Unlocked Skill",
									Description = "ID: " .. skillId,
									Time = 1
								})
							end
						end
					end
				end

				-- Nothing left to unlock — stop and chain
				if not anyUnlocked then
					getgenv().AutoSkillTree = false
					Toggles.AutoSkillTree:SetValue(false)
					Library:Notify({ Title = "Auto Skill Tree", Description = "[✓] All skills unlocked.", Time = 2 })
					if Toggles.AutoEquipPerkToggle and Toggles.AutoEquipPerkToggle.Value then
						Toggles.AutoEquipPerkToggle:SetValue(false) task.wait(0.2) Toggles.AutoEquipPerkToggle:SetValue(true)
					elseif Toggles.AutoBuyBoostToggle and Toggles.AutoBuyBoostToggle.Value then
						Toggles.AutoBuyBoostToggle:SetValue(false) task.wait(0.2) Toggles.AutoBuyBoostToggle:SetValue(true)
					elseif Toggles.AutoBoostToggle and Toggles.AutoBoostToggle.Value then
						Toggles.AutoBoostToggle:SetValue(false) task.wait(0.2) Toggles.AutoBoostToggle:SetValue(true)
					elseif Toggles.AutoPrestigeToggle and Toggles.AutoPrestigeToggle.Value then
						Toggles.AutoPrestigeToggle:SetValue(false) task.wait(0.2) Toggles.AutoPrestigeToggle:SetValue(true)
					elseif Toggles.AutoStartToggle and Toggles.AutoStartToggle.Value then
						Toggles.AutoStartToggle:SetValue(false) task.wait(0.2) Toggles.AutoStartToggle:SetValue(true)
					end
					break
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
			local currentPrestige = pData.Slots[slotIdx].Progression.Prestige or 0

			-- Gold requirement scales with prestige level
			local prestigeGoldMap = {
				[0] = 200000000,  -- Prestige 1 = 200m
				[1] = 400000000,  -- Prestige 2 = 400m
				[2] = 600000000,  -- Prestige 3 = 600m
				[3] = 800000000,  -- Prestige 4 = 800m
				[4] = 1000000000, -- Prestige 5 = 1b
			}
			local requiredGold = prestigeGoldMap[currentPrestige] or 1000000000

			local function formatGold(n)
				if n >= 1000000000 then return (n/1000000000) .. "b"
				elseif n >= 1000000 then return (n/1000000) .. "m"
				else return tostring(n) end
			end

			if gold < requiredGold then
				Library:Notify({
					Title = "Auto Prestige",
					Description = "Not enough gold (" .. formatGold(gold) .. "/" .. formatGold(requiredGold) .. ")\nPrestige " .. currentPrestige .. " → " .. (currentPrestige + 1),
					Time = 5
				})
				getgenv().AutoPrestige = false
				Toggles.AutoPrestigeToggle:SetValue(false)
				return
			end

			Library:Notify({
				Title = "Auto Prestige",
				Description = "Gold OK! " .. formatGold(gold) .. "/" .. formatGold(requiredGold) .. "\nAttempting Prestige " .. (currentPrestige + 1) .. "...",
				Time = 3
			})

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
							Title = "Successfully Prestiged!",
							Description = "Prestige " .. (currentPrestige + 1) .. " with " .. Options.SelectBoostDropdown.Value .. " and " .. Memory,
							Time = 5
						})
						break
					end
					task.wait(0.1)
				end
				task.wait(1)
			end
			-- Chain to Auto Start after prestige
			getgenv().AutoPrestige = false
			Toggles.AutoPrestigeToggle:SetValue(false)
			if Toggles.AutoStartToggle and Toggles.AutoStartToggle.Value then
				Toggles.AutoStartToggle:SetValue(false) task.wait(0.2) Toggles.AutoStartToggle:SetValue(true)
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

PrestigeGroup:AddLabel("Gold req scales with prestige level.\n200m→400m→600m→800m→1b")

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
			else
				Library:Notify({ Title = "Auto Buy", Description = "[—] Already have boost or item.", Time = 2 })
			end
		end

		-- Done — stop and chain to AutoUseBoost
		getgenv().BuyIfEmpty = false
		Toggles.AutoBuyBoostToggle:SetValue(false)
		if Toggles.AutoBoostToggle and Toggles.AutoBoostToggle.Value then
			Toggles.AutoBoostToggle:SetValue(false) task.wait(0.2) Toggles.AutoBoostToggle:SetValue(true)
		elseif Toggles.AutoPrestigeToggle and Toggles.AutoPrestigeToggle.Value then
			Toggles.AutoPrestigeToggle:SetValue(false) task.wait(0.2) Toggles.AutoPrestigeToggle:SetValue(true)
		elseif Toggles.AutoStartToggle and Toggles.AutoStartToggle.Value then
			Toggles.AutoStartToggle:SetValue(false) task.wait(0.2) Toggles.AutoStartToggle:SetValue(true)
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
			-- Run once then stop and chain
			getgenv().AutoBoostEnabled = false
			Toggles.AutoBoostToggle:SetValue(false)
			if Toggles.AutoPrestigeToggle and Toggles.AutoPrestigeToggle.Value then
				Toggles.AutoPrestigeToggle:SetValue(false) task.wait(0.2) Toggles.AutoPrestigeToggle:SetValue(true)
			elseif Toggles.AutoStartToggle and Toggles.AutoStartToggle.Value then
				Toggles.AutoStartToggle:SetValue(false) task.wait(0.2) Toggles.AutoStartToggle:SetValue(true)
			end
		end)
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

local lobbyFlags = {"AutoStartToggle", "StartTypeDropdown", "MissionMapDropdown", "MissionObjectiveDropdown", "MissionDifficultyDropdown", "RaidMapDropdown", "RaidObjectiveDropdown", "RaidDifficultyDropdown", "ModifiersDropdown", "AutoUpgradeToggle", "AutoEnhanceToggle", "PerkSlotDropdown", "SelectPerksDropdown", "AutoEquipPerkToggle", "PerkPriority1", "PerkPriority2", "PerkPriority3", "AutoSkillTree", "MiddlePathDropdown", "LeftPathDropdown", "RightPathDropdown", "Priority1Dropdown", "Priority2Dropdown", "Priority3Dropdown", "AutoPrestigeToggle", "SelectBoostDropdown", "PrestigeTalentPriority", "PrestigeGoldSlider", "AutoGoldBoostToggle", "GoldBoostTypeDropdown", "AutoBuyBoostToggle", "AutoBoostToggle", "BoostTypeDropdown", "AutoClaimQuestToggle"}
local menuFlags = {"AutoSelectSlot", "SelectSlotDropdown", "AutoPlayToggle", "AutoRollToggle", "AutoDepositToggle", "SelectFamily", "SelectFamilyRarity", "ToggleMythicalFamilyWebhook", "WebhookUrl_Menu"}

local ignoreList = {}

if placeId == 13379208636 then
	configSubfolder = "GabBoboBading/aotr/MainMenu"
	for _, v in ipairs(lobbyFlags) do table.insert(ignoreList, v) end
elseif placeId == 14916516914 then
	configSubfolder = "GabBoboBading/aotr/Lobby"
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


task.spawn(function()
	local lastState = nil
	while not Library.Unloaded do
		local placeId = game.PlaceId
		local isMainMenu = placeId == 13379208636
		local isLobbyPlace = placeId == 14916516914

		if lastState ~= placeId then
			lastState = placeId
			Tabs.Main:SetVisible(isLobbyPlace)
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
	if Toggles.AutoHideToggle.Value then
		Library:Toggle(false)
		Library:Notify({ Title = "GabBoboBading", Description = "Auto Hid GUI", Time = 2 })
	end
end)