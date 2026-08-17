-- COMCLEAN.lua — clean messes + glass at range WITH the correct tool equipped
-- Range firing avoids the game auto-equipping the extinguisher (that only happens near PCs).
-- The tool must be equipped for the server to accept the clean, so we equip broom/towel.
-- No teleporting near the messes. Delta-safe (Lua 5.1, no continue).
repeat task.wait() until game:IsLoaded()
if getgenv().COMCLEAN_LOADED then return end
getgenv().COMCLEAN_LOADED = true

local P = game:GetService("Players")
local LP = P.LocalPlayer

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

local function findTool(p)
	local bp = LP:FindFirstChild("Backpack")
	if not bp then return nil end
	local rn = p:GetAttribute("RequiredToolName")
	local ra = p:GetAttribute("RequiredToolAttribute")
	for _, t in ipairs(bp:GetChildren()) do
		if t:IsA("Tool") then
			if rn and string.lower(t.Name) == string.lower(rn) then return t end
			if ra and t:GetAttribute(ra) == true then return t end
		end
	end
	local n = (p.Name or ""):lower()
	for _, t in ipairs(bp:GetChildren()) do
		if t:IsA("Tool") then
			local tn = string.lower(t.Name)
			if n:match("glass") and (tn:match("towel") or tn:match("wipe") or tn:match("rag")) then return t end
			if n:match("clean") and (tn:match("walis") or tn:match("broom") or tn:match("mop")) then return t end
		end
	end
	return nil
end

local function equip(tool)
	local c = LP.Character
	local hm = c and c:FindFirstChildWhichIsA("Humanoid")
	if tool and hm then
		hm:EquipTool(tool)
		for _ = 1, 15 do
			if tool.Parent == c then break end
			task.wait(0.1)
		end
		return tool.Parent == c
	end
	return false
end

-- diagnostic watchdog: log whenever the extinguisher enters the hand
local extSeen = false
task.spawn(function()
	while true do
		task.wait(0.2)
		local c = LP.Character
		local t = c and c:FindFirstChildOfClass("Tool")
		local isExt = t and (t.Name:lower():match("extinguish") or t.Name:lower():match("^fire"))
		if isExt and not extSeen then
			extSeen = true
			warn("[Diag] EXTINGUISHER in hand!")
		elseif not isExt and extSeen then
			extSeen = false
			warn("[Diag] EXTINGUISHER left hand")
		end
	end
end)

local t0 = os.clock()
while true do
	if os.clock() - t0 > 15 then warn("[Diag] STOPPED after 15s") break end
	task.wait(0.5)
	local b = ob()
	if b then
		local cs = b:FindFirstChild("CleaningSystem")
		if cs then
			local am = cs:FindFirstChild("ActiveMesses")
			if am then
				for _, p in ipairs(am:GetDescendants()) do
					if p:IsA("ProximityPrompt") and p.Enabled then
						local tool = findTool(p)
						if not tool then
							warn("[Clean] NO TOOL for", p.Name)
						else
							if not equip(tool) then
								warn("[Clean] equip FAILED for", p.Name, tool.Name)
							else
								pcall(function() p.HoldDuration = 0 end)
								pcall(function() p.RequiresLineOfSight = false end)
								pcall(function() p.MaxActivationDistance = 50 end)
								warn("[Clean] firing", p.Name, "with", tool.Name)
								for _ = 1, 5 do
									if fireproximityprompt then pcall(fireproximityprompt, p) end
									task.wait(0.35)
								end
								if not p.Enabled then warn("[Clean] CLEANED:", p.Name) end
								task.wait(0.2)
							end
						end
					end
				end
			end
		end
	end
end