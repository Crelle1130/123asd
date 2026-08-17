-- COMCLEAN.lua — clean messes + glass, close range, correct tool re-equipped each fire
-- Server needs proximity + tool. The game auto-equips the extinguisher when close,
-- so we re-equip the correct tool and fire in the SAME frame (beats the override).
-- Scorch messes (require extinguisher) are fired with whatever the game hands us.
-- Delta-safe (Lua 5.1, no continue).
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
	task.wait(0.4)
	local b = ob()
	if b then
		local cs = b:FindFirstChild("CleaningSystem")
		if cs then
			local am = cs:FindFirstChild("ActiveMesses")
			if am then
				for _, p in ipairs(am:GetDescendants()) do
					if p:IsA("ProximityPrompt") and p.Enabled then
						local ra = p:GetAttribute("RequiredToolAttribute")
						local rn = p:GetAttribute("RequiredToolName")
						local ras = ra and tostring(ra):lower() or ""
						local isScorch = ras:match("fire") or ras:match("exting")
						local tool = isScorch and nil or findTool(p)
						local pos = getPos(p)
						if pos then
							local c = LP.Character
							local hrp = c and c:FindFirstChild("HumanoidRootPart")
							if hrp then
								local dx = hrp.Position.X - pos.X
								local dz = hrp.Position.Z - pos.Z
								local dist = (dx * dx + dz * dz) ^ 0.5
								if dist > 6 then
									hrp.CFrame = CFrame.lookAt(Vector3.new(pos.X, pos.Y + 2.5, pos.Z + 5), Vector3.new(pos.X, pos.Y, pos.Z))
									task.wait(0.15)
									local hm = c:FindFirstChildWhichIsA("Humanoid")
									if hm then hm.Sit = false end
								end
							end
							pcall(function() p.HoldDuration = 0 end)
							pcall(function() p.RequiresLineOfSight = false end)
							pcall(function() p.MaxActivationDistance = 50 end)
							local hm = c and c:FindFirstChildWhichIsA("Humanoid")
							for _ = 1, 5 do
								if tool and hm then
									hm:EquipTool(tool)
								end
								if fireproximityprompt then pcall(fireproximityprompt, p) end
								VU:ClickButton1(Vector2.new())
								task.wait(0.3)
							end
							warn("[Clean] done", p.Name, "ra=", tostring(ra), "tool=", tool and tool.Name or "AUTO", "enabled=", tostring(p.Enabled), "parent=", tostring(p.Parent ~= nil))
						end
					end
				end
			end
		end
	end
end