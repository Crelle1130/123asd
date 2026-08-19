--[[
	KARINDERYA  |  LABA HUB
	Filipino restaurant tycoon menu.
	(c) 2026 LABA HUB.
]]

local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Crelle1130/LABA-HUB/refs/heads/main/LABAHUB.luau"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CounterRemotes = Remotes:WaitForChild("CounterRemotes")
local GetCounterInfo = CounterRemotes:WaitForChild("GetCounterInfo")
local AssignNPC = CounterRemotes:WaitForChild("AssignNPC")

local FoodConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FoodConfig"))

local win = UI:CreateWindow({
	Title = "KARINDERYA",
	Size = UDim2.fromOffset(560, 440),
	Intro = { Title = "KARINDERYA", Subtitle = "LABA HUB", Duration = 2.5 },
})

-- == Auto Appoint engine ==
-- Assigns the customer in line to the first free table, mirroring the
-- game's own CounterController flow (GetCounterInfo -> AssignNPC).
local AutoAppointRun = false
local AutoAppointThread = nil

-- NPCs this store assigned. ClientNPCs only ever holds this client's
-- customers, but tracking the assigned NpcId makes "punish our runaways"
-- exact: an NPC is only ours if we assigned it to one of our tables.
local AssignedNpcs = {}

local function rememberAssigned(npcId)
	if npcId and npcId ~= "" then
		AssignedNpcs[npcId] = true
	end
end

-- Seed the set from the tables we currently occupy, so NPCs assigned
-- before this script (re)loaded still count as ours.
local function seedAssignedFromPlot()
	local userId = LocalPlayer.UserId
	for _, item in ipairs(workspace:GetChildren()) do
		if item.Name:match("^Karenderya") and item:GetAttribute("Owner") == userId then
			for _, dining in ipairs(item:GetChildren()) do
				if dining.Name:match("^DiningPlot") then
					for _, table in ipairs(dining:GetChildren()) do
						if table:IsA("Model") then
							local o1 = table:GetAttribute("OccupiedBy1")
							local o2 = table:GetAttribute("OccupiedBy2")
							rememberAssigned(o1)
							rememberAssigned(o2)
						end
					end
				end
			end
		end
	end
end

-- The server fires CustomerRanAwayEvent ONLY for this store's runaways
-- (it shows the "ran away without paying" alert and looks up the model by
-- name). Recording it here is the authoritative "this NPC is ours".
local CustomerRanAway = Remotes:FindFirstChild("CustomerRanAwayEvent")
if CustomerRanAway then
	CustomerRanAway.OnClientEvent:Connect(function(_, npcName)
		rememberAssigned(npcName)
	end)
end

local function missingIngredients(order)
	if not order or not FoodConfig[order] then
		return nil
	end
	local required = FoodConfig[order].RequiredIngredients or {}
	local ingredients = LocalPlayer:FindFirstChild("Ingredients")
	local missing = {}
	for _, name in ipairs(required) do
		local v = ingredients and ingredients:FindFirstChild(name)
		if not v or (v:IsA("IntValue") and v.Value <= 0) then
			table.insert(missing, name)
		end
	end
	if #missing > 0 then
		return missing
	end
	return nil
end

local function appointOnce()
	local ok, customer, tables = pcall(function()
		return GetCounterInfo:InvokeServer()
	end)
	if not ok then
		return false
	end
	if type(customer) ~= "table" then
		return false -- no one in line
	end
	if type(tables) ~= "table" or #tables == 0 then
		return false -- no free table
	end
	if missingIngredients(customer.Order) then
		return false -- can't serve this order yet
	end
	local npcId = customer.NpcId or customer.TemplateName or ""
	rememberAssigned(npcId)
	local t = tables[1]
	pcall(function()
		AssignNPC:FireServer({
			Slot = t.Slot,
			Seat = t.Seat,
			NPCName = npcId,
			NpcId = npcId,
		})
	end)
	return true
end

local function startAutoAppoint()
	AutoAppointRun = true
	if AutoAppointThread then
		return
	end
	AutoAppointThread = task.spawn(function()
		while AutoAppointRun do
			local did = appointOnce()
			task.wait(did and 1 or 0.5)
		end
		AutoAppointThread = nil
	end)
end

local function stopAutoAppoint()
	AutoAppointRun = false
end

-- == Auto Deliver engine ==
-- Two steps, matching how the game works:
--  1) Get: teleport to the Serve counter, fire the cooked dish's
--     ProximityPrompt (the server validates distance) so the dish is
--     carried as an accessory.
--  2) Give: move the character to the waiting customer whose Order
--     matches the dish; the server consumes the food and marks the
--     table as served.
local AutoDeliverRun = false
local AutoDeliverThread = nil

local function getAssignedPlot()
	local userId = LocalPlayer.UserId
	local ws = workspace
	for _, item in ipairs(ws:GetChildren()) do
		if item.Name:match("^Karenderya") and item:GetAttribute("Owner") == userId then
			return item
		end
	end
	return nil
end

local function teleportTo(pos)
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(pos)
	end
end

local function isCarryingFood()
	local char = LocalPlayer.Character
	if not char then
		return nil
	end
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Accessory") and child:GetAttribute("IsFood") then
			return child
		end
	end
	return nil
end

local function orderFromFood(food)
	local key = food:GetAttribute("OrderKey")
	if key then
		return key
	end
	local name = food.Name
	return name:match("^Cooked_(.+)$") or name
end

local function findTableFor(npcId)
	local userId = LocalPlayer.UserId
	for _, item in ipairs(workspace:GetChildren()) do
		if item.Name:match("^Karenderya") and item:GetAttribute("Owner") == userId then
			for _, dining in ipairs(item:GetChildren()) do
				if dining.Name:match("^DiningPlot") then
					for _, table in ipairs(dining:GetChildren()) do
						if table:IsA("Model") then
							local o1 = table:GetAttribute("OccupiedBy1")
							local o2 = table:GetAttribute("OccupiedBy2")
							if o1 == npcId or o2 == npcId then
								return table
							end
						end
					end
				end
			end
		end
	end
	return nil
end

local function findServePrompt(table, order)
	if not table then
		return nil
	end
	for _, desc in ipairs(table:GetDescendants()) do
		if desc:IsA("ProximityPrompt") and desc.ActionText == "Serve " .. order then
			return desc
		end
	end
	return nil
end

-- Fire a proximity prompt after standing its holder within activation
-- range. The prompt's parent is a BasePart; teleport onto it.
local function firePromptOnPart(prompt)
	if not prompt then
		return false
	end
	local part = prompt.Parent
	if not (part and part:IsA("BasePart")) then
		return false
	end
	local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(part.Position + Vector3.new(0, 0, 1))
	end
	task.wait(0.5)
	pcall(function()
		fireproximityprompt(prompt)
	end)
	return true
end

local function listCookedDishes(serve)
	local dishes = {}
	for _, slot in ipairs(serve:GetChildren()) do
		for _, child in ipairs(slot:GetChildren()) do
			if child.Name:match("^Cooked_") then
				local prompt = child:FindFirstChildWhichIsA("ProximityPrompt", true)
				if prompt and prompt.Enabled and prompt.Parent then
					dishes[#dishes + 1] = {
						slot = slot,
						child = child,
						prompt = prompt,
						order = orderFromFood(child),
					}
				end
			end
		end
	end
	return dishes
end

local function listCarriedFood()
	local char = LocalPlayer.Character
	if not char then
		return {}
	end
	local carried = {}
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Accessory") and child:GetAttribute("IsFood") then
			carried[#carried + 1] = child
		end
	end
	return carried
end

local function targetIdOf(food)
	local tid = food:FindFirstChild("TargetNPCId") and food.TargetNPCId.Value
	if tid then
		return tid
	end
	local cn = workspace:FindFirstChild("ClientNPCs")
	if not cn then
		return nil
	end
	for _, npc in ipairs(cn:GetChildren()) do
		if npc:IsA("Model") and npc:GetAttribute("Order") == (food:GetAttribute("OrderKey") or food.Name) then
			return npc.Name
		end
	end
	return nil
end

local function deliverOnce()
	local plot = getAssignedPlot()
	if not plot then
		return false
	end
	local serve = plot:FindFirstChild("Serve")
	if not serve then
		return false
	end

	-- Phase 1: grab every cooked dish sitting on the counter.
	local dishes = listCookedDishes(serve)
	if #dishes == 0 then
		return false
	end
	local picked = 0
	for _, dish in ipairs(dishes) do
		firePromptOnPart(dish.prompt)
		task.wait(0.15)
	end
	-- Collect what actually got picked up.
	local carried = listCarriedFood()
	for _ = 1, 8 do
		task.wait(0.25)
		local now = listCarriedFood()
		if #now >= #carried then
			carried = now
		end
		if #carried >= #dishes then
			break
		end
	end
	if #carried == 0 then
		return false -- nothing got picked up
	end
	picked = #carried

	-- Phase 2: serve every dish to its customer's table.
	local served = 0
	for _, food in ipairs(carried) do
		local order = food:GetAttribute("OrderKey") or orderFromFood(food)
		local targetId = targetIdOf(food)
		local table = findTableFor(targetId)
		if table then
			local servePrompt = findServePrompt(table, order)
			if servePrompt then
				firePromptOnPart(servePrompt)
				task.wait(0.15)
				served = served + 1
			end
		end
	end
	-- Give the server a moment to consume the food.
	for _ = 1, 8 do
		task.wait(0.25)
		if #listCarriedFood() == 0 then
			break
		end
	end
	return served > 0
end

local function startAutoDeliver()
	AutoDeliverRun = true
	if AutoDeliverThread then
		return
	end
	AutoDeliverThread = task.spawn(function()
		while AutoDeliverRun do
			local did = deliverOnce()
			task.wait(did and 1 or 0.35)
		end
		AutoDeliverThread = nil
	end)
end

local function stopAutoDeliver()
	AutoDeliverRun = false
end

-- == Auto Kaltok engine ==
-- Runaway customers (IsRunaway) that didn't pay get punished with the
-- Pan. The game's ClientPanHandler swings the pan on Activated and at the
-- "Hit" marker fires HitRunawayEvent for any IsRunaway NPC in the box in
-- front of the character. We mirror that: find a runaway, equip the pan,
-- stand so the runaway is in the swing box, and activate the pan.
local AutoKaltokRun = false
local AutoKaltokThread = nil

local function findRunaway()
	local cn = workspace:FindFirstChild("ClientNPCs")
	if not cn then
		return nil
	end
	local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local best = nil
	local bestDist = math.huge
	for _, npc in ipairs(cn:GetChildren()) do
		-- Only punish runaways this store actually served (we assigned them).
		if npc:IsA("Model") and npc:GetAttribute("IsRunaway") == true and AssignedNpcs[npc.Name] then
			local npcRoot = npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
			if npcRoot then
				local dist = root and (root.Position - npcRoot.Position).Magnitude or 0
				if dist < bestDist then
					bestDist = dist
					best = npc
				end
			end
		end
	end
	return best
end

local function getPan()
	local char = LocalPlayer.Character
	if char then
		local pan = char:FindFirstChild("Pan")
		if pan then
			return pan
		end
	end
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if backpack then
		return backpack:FindFirstChild("Pan")
	end
	return nil
end

local function equipPan(pan)
	local char = LocalPlayer.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if pan and humanoid then
		pcall(function()
			humanoid:EquipTool(pan)
		end)
	end
end

local function kaltokOnce()
	local pan = getPan()
	if not pan then
		return false -- no pan owned
	end
	local runaway = findRunaway()
	if not runaway then
		return false -- nobody running off right now
	end
	equipPan(pan)
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local npcRoot = runaway:FindFirstChild("HumanoidRootPart") or runaway.PrimaryPart
	if not (root and npcRoot) then
		return false
	end
	-- Teleport right next to the runaway (3 studs away) facing it, so it
	-- lands inside the game's hit box (Character.CFrame * (0,0,-4), 8x6x10).
	local toNpc = (npcRoot.Position - root.Position)
	local dir = toNpc.Magnitude > 0.001 and toNpc.Unit or Vector3.new(0, 0, -1)
	root.CFrame = CFrame.lookAt(npcRoot.Position - dir * 3, npcRoot.Position)
	task.wait(0.35)
	-- Re-check position in case the runaway kept moving, then punish:
	-- fire the same remote the game's pan handler fires.
	local HitRunaway = Remotes:FindFirstChild("HitRunawayEvent")
	if HitRunaway then
		pcall(function()
			HitRunaway:FireServer(runaway.Name)
		end)
	end
	pcall(function()
		pan:Activate()
	end)
	task.wait(0.6)
	return true
end

local function startAutoKaltok()
	AutoKaltokRun = true
	seedAssignedFromPlot()
	if AutoKaltokThread then
		return
	end
	AutoKaltokThread = task.spawn(function()
		while AutoKaltokRun do
			local did = kaltokOnce()
			task.wait(did and 1 or 0.4)
		end
		AutoKaltokThread = nil
	end)
end

local function stopAutoKaltok()
	AutoKaltokRun = false
end

-- == Main tab ==
local Main = win:AddTab("Main")

Main:AddToggle({
	Name = "Auto Appoint",
	Value = false,
	Key = "AutoAppoint",
	Callback = function(v)
		if v then
			startAutoAppoint()
		else
			stopAutoAppoint()
		end
	end,
})

Main:AddToggle({
	Name = "Auto Deliver",
	Value = false,
	Key = "AutoDeliver",
	Callback = function(v)
		if v then
			startAutoDeliver()
		else
			stopAutoDeliver()
		end
	end,
})

Main:AddToggle({
	Name = "Auto Kaltok",
	Value = false,
	Key = "AutoKaltok",
	Callback = function(v)
		if v then
			startAutoKaltok()
		else
			stopAutoKaltok()
		end
	end,
})

-- == Settings tab ==
local Settings = win:AddTab("Settings")

Settings:AddLabel({ Name = "KARINDERYA  |  LABA HUB", Color = Color3.fromRGB(86, 156, 255), TextSize = 15, Center = true })

Settings:AddToggle({
	Name = "Auto-load config on join",
	Value = UI.Config.Settings.AutoLoad,
	Callback = function(v)
		UI.Config.Settings.AutoLoad = v
		UI.Config:SaveMeta()
	end,
})

win:Notify("KARINDERYA", "Loaded — main tab: Auto Appoint, Auto Deliver & Auto Kaltok", 4, "success")
