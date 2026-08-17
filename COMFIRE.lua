-- COMFIRE.lua — fire + clean WITHOUT equipping any tools (Delta-safe, Lua 5.1)
-- Fires the ProximityPrompts directly. No EquipTool / UnequipTools anywhere.
repeat task.wait() until game:IsLoaded()
if getgenv().COMFIRE_LOADED then return end
getgenv().COMFIRE_LOADED = true

local P = game:GetService("Players")
local LP = P.LocalPlayer
local VU = game:GetService("VirtualUser")

local function ob()
	local bases = workspace:FindFirstChild("Bases")
	if not bases then return nil end
	for _, b in ipairs(bases:GetChildren()) do
		if b:GetAttribute("OwnerUserId") == LP.UserId and (b:FindFirstChild("CleaningSystem") or b:FindFirstChild("PCS")) then
			return b
		end
	end
	return nil
end

local function getPos(p)
	if not p then return nil end
	local o = p.Parent
	if o and o:IsA("BasePart") then return o.Position end
	local m = o and (o:IsA("Model") and o or (o.Parent and o.Parent:IsA("Model") and o.Parent))
	if m then
		local ok, v = pcall(function() return m:GetPivot().Position end)
		if ok then return v end
	end
	return nil
end

local function firePrompt(pr)
	if not pr then return end
	pcall(function() pr.HoldDuration = 0 end)
	pcall(function() pr.RequiresLineOfSight = false end)
	pcall(function() pr.MaxActivationDistance = 50 end)
	if fireproximityprompt then
		pcall(fireproximityprompt, pr)
	end
end

local function tpNear(pos)
	local c = LP.Character
	if not c then return end
	local hrp = c:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	hrp.CFrame = CFrame.lookAt(Vector3.new(pos.X, pos.Y + 2.5, pos.Z + 2.5), Vector3.new(pos.X, pos.Y, pos.Z))
	task.wait(0.15)
	local hm = c:FindFirstChildWhichIsA("Humanoid")
	if hm then hm.Sit = false end
end

local function doFires(b)
	local pcs = b:FindFirstChild("PCS")
	if not pcs then return end
	for _, pc in ipairs(pcs:GetChildren()) do
		if pc:IsA("Model") and pc:GetAttribute("FireActive") == true then
			local pr = nil
			for _, p in ipairs(pc:GetDescendants()) do
				if p:IsA("ProximityPrompt") and p.Enabled then
					local ot = (p.ObjectText or ""):lower()
					if not ot:match("laptop") and not ot:match("select") then pr = p break end
				end
			end
			if pr then
				local pos = pc.PrimaryPart and pc.PrimaryPart.Position or pc:GetPivot().Position
				tpNear(pos)
				for _ = 1, 5 do
					firePrompt(pr)
					VU:ClickButton1(Vector2.new())
					task.wait(0.35)
				end
				task.wait(0.3)
			end
		end
	end
end

local function doCleans(b)
	local cs = b:FindFirstChild("CleaningSystem")
	if not cs then return end
	local am = cs:FindFirstChild("ActiveMesses")
	if not am then return end
	for _, p in ipairs(am:GetDescendants()) do
		if p:IsA("ProximityPrompt") and p.Enabled then
			local pos = getPos(p)
			if pos then
				tpNear(pos)
				for _ = 1, 5 do
					firePrompt(p)
					VU:ClickButton1(Vector2.new())
					task.wait(0.35)
				end
				task.wait(0.2)
			end
		end
	end
end

while true do
	task.wait(0.5)
	local b = ob()
	if b then
		doFires(b)
		doCleans(b)
	end
end