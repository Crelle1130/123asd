-- COMCLEAN.lua — clean messes + glass WITHOUT equipping tools and WITHOUT teleporting near PCs
-- Fires the CleaningSystem ProximityPrompts at range (MaxActivationDistance=50).
-- No EquipTool / UnequipTools. No CFrame teleports near the mess (that proximity is what
-- makes the game auto-equip the fire extinguisher).
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
	if not b then warn("[Clean] no base found") end
	if b then
		local cs = b:FindFirstChild("CleaningSystem")
		if cs then
			local am = cs:FindFirstChild("ActiveMesses")
			if am then
				for _, p in ipairs(am:GetDescendants()) do
					if p:IsA("ProximityPrompt") and p.Enabled then
						pcall(function() p.HoldDuration = 0 end)
						pcall(function() p.RequiresLineOfSight = false end)
						pcall(function() p.MaxActivationDistance = 50 end)
						warn("[Clean] firing at range:", p.Name, "tool=", tostring(p:GetAttribute("RequiredToolAttribute")))
						for _ = 1, 5 do
							if fireproximityprompt then pcall(fireproximityprompt, p) end
							task.wait(0.35)
						end
						task.wait(0.2)
					end
				end
			end
		end
	end
end