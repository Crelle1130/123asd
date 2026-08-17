-- SPYREMOTE.lua — log every FireServer / InvokeServer call (Delta-safe, no file I/O)
repeat task.wait() until game:IsLoaded()
print("[Spy] remote spy loading...")

local function fmt(v, depth)
	depth = depth or 0
	local tv = type(v)
	if tv == "string" then return string.format("%q", v) end
	if tv == "number" then return tostring(v) end
	if tv == "boolean" then return tostring(v) end
	if tv == "nil" then return "nil" end
	if tv == "table" then
		if depth > 1 then return "table" end
		local parts = {}
		local count = 0
		for k, val in pairs(v) do
			count = count + 1
			if count > 8 then table.insert(parts, "...") break end
			table.insert(parts, tostring(k) .. "=" .. fmt(val, depth + 1))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	if tv == "userdata" then
		local ok, t = pcall(function() return typeof(v) end)
		if ok then
			if t == "Instance" then
				local ok2, full = pcall(function() return v:GetFullName() end)
				if ok2 then return full end
				return "Instance"
			end
			return t
		end
		return tostring(v)
	end
	return tostring(v)
end

local function logCall(kind, inst, ...)
	local n = select("#", ...)
	local parts = {}
	for i = 1, n do
		local ok, val = pcall(function() return fmt((select(i, ...))) end)
		table.insert(parts, (ok and val) or "?")
	end
	print("[Spy] " .. kind .. " " .. inst:GetFullName() .. " :: " .. table.concat(parts, " | "))
end

local scanned = {}
local function hook(inst)
	if scanned[inst] then return end
	if inst.ClassName ~= "RemoteEvent" and inst.ClassName ~= "RemoteFunction" then return end
	scanned[inst] = true
	if inst.ClassName == "RemoteEvent" then
		local old = inst.FireServer
		inst.FireServer = function(self, ...)
			logCall("FireServer", inst, ...)
			return old(self, ...)
		end
	else
		local old = inst.InvokeServer
		inst.InvokeServer = function(self, ...)
			logCall("InvokeServer", inst, ...)
			return old(self, ...)
		end
	end
end

local function scan(container)
	local ok, list = pcall(function() return container:GetDescendants() end)
	if not ok or not list then return end
	local count = 0
	for _, v in ipairs(list) do
		if v.ClassName == "RemoteEvent" or v.ClassName == "RemoteFunction" then
			hook(v)
			count = count + 1
		end
	end
	print("[Spy] hooked", count, "remotes in", container.Name)
end

local okMain = xpcall(function()
	scan(game:GetService("ReplicatedStorage"))
	scan(workspace)
	scan(game:GetService("Players"))

	game:GetService("ReplicatedStorage").DescendantAdded:Connect(function(v)
		pcall(hook, v)
	end)
	workspace.DescendantAdded:Connect(function(v)
		pcall(hook, v)
	end)

	print("[Spy] ready — do your actions now")
end, function(e)
	print("[Spy] ERROR:", tostring(e))
	local okTb, tb = pcall(debug.traceback)
	if okTb then print(tb) end
end)

if not okMain then print("[Spy] main blocked") end