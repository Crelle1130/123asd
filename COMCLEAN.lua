-- COMCLEAN.lua — clean messes + glass WITHOUT equipping tools (Delta-safe, Lua 5.1)
-- Fires the CleaningSystem ProximityPrompts directly. No EquipTool / UnequipTools anywhere.
repeat task.wait() until game:IsLoaded()
if getgenv().COMCLEAN_LOADED then return end
getgenv().COMCLEAN_LOADED = true

local P = game:GetService("Players")
local LP = P.LocalPlayer
local VU = game:GetService("VirtualUser")

local function ob()
	local bases = workspace:FindFirstChild("Bases")
	if not bases then return nil end
	for _, b in ipairs(bases:GetChildren()) do
		if b:GetAttribute("OwnerUserId") == LP.UserId and b:FindFirstChild("CleaningSystem") then
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

while true do
	task.wait(0.5)
	local b = ob()
	if b then
		local cs = b:FindFirstChild("CleaningSystem")
		if cs then
			local am = cs:FindFirstChild("ActiveMesses")
			if am then
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
		end
	end
end