local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local lp = Players.LocalPlayer

local WALK_SPEED = 30
local TIMEOUT = 15

local function getCharacter()
    local char = lp.Character
    if not char then
        char = lp.CharacterAdded:Wait()
    end
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    local hum = char:WaitForChild("Humanoid", 5)
    return char, hrp, hum
end

-- Plot detection (improved: also checks values and folders)
local function getMyPlot()
    local myName = lp.Name:lower():gsub("[%s_]", "")
    local myDisp = (lp.DisplayName or ""):lower():gsub("[%s_]", "")
    
    local plotsFolder = workspace:FindFirstChild("Plots") or workspace:FindFirstChild("Tycoons") or workspace:FindFirstChild("Bases")
    local searchRoot = plotsFolder or workspace
    
    -- First, try to find a part with an attribute or value that matches
    for _, obj in ipairs(searchRoot:GetDescendants()) do
        if obj:IsA("BasePart") then
            local owner = obj:GetAttribute("Owner") or obj:FindFirstChild("Owner")
            if owner then
                local ownerName = (type(owner) == "string" and owner or (owner.Value or "")):lower():gsub("[%s_]", "")
                if ownerName == myName or ownerName == myDisp then
                    return obj.Parent -- Return the parent (the plot group)
                end
            end
        end
    end
    
    -- Fallback: look for text labels
    for _, obj in ipairs(searchRoot:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            local text = obj.Text:lower():gsub("[%s_]", "")
            if text:find(myName) or text:find(myDisp) then
                -- climb up to find a plausible plot container
                local current = obj.Parent
                while current and current ~= workspace do
                    if current:FindFirstChild("Collector") or current.Name:find("Plot") then
                        return current
                    end
                    current = current.Parent
                end
                return obj.Parent
            end
        end
    end
    return nil
end

-- Pathfinding version (avoids obstacles)
local function walkToTarget(targetPos)
    local char, hrp, hum = getCharacter()
    if not hrp or not hum then return false end
    
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
    })
    
    local success, err = pcall(function()
        path:ComputeAsync(hrp.Position, targetPos)
    end)
    
    if not success or path.Status ~= Enum.PathStatus.Success then
        -- Fallback to direct line
        return forceWalkTo(targetPos) -- your original function (renamed)
    end
    
    local waypoints = path:GetWaypoints()
    local currentWaypointIndex = 1
    
    local connection
    local timeout = tick() + TIMEOUT
    
    connection = RunService.Heartbeat:Connect(function()
        if not char or not hrp.Parent or hum.Health <= 0 or tick() > timeout then
            connection:Disconnect()
            hum:Move(Vector3.zero, true)
            return
        end
        
        if currentWaypointIndex > #waypoints then
            -- Reached end
            hum:Move(Vector3.zero, true)
            hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
            connection:Disconnect()
            return
        end
        
        local targetWaypoint = waypoints[currentWaypointIndex]
        local direction = (targetWaypoint.Position - hrp.Position).Unit
        local distance = (targetWaypoint.Position - hrp.Position).Magnitude
        
        if distance < 3 then
            currentWaypointIndex = currentWaypointIndex + 1
            return
        end
        
        hum:Move(direction, false)
        hrp.AssemblyLinearVelocity = Vector3.new(direction.X * WALK_SPEED, hrp.AssemblyLinearVelocity.Y, direction.Z * WALK_SPEED)
    end)
    
    while connection and connection.Connected do
        task.wait(0.1)
        if tick() > timeout then
            connection:Disconnect()
            return false
        end
    end
    return true
end

-- Your original forceWalkTo (rename to directWalk) can be kept as fallback

local function test()
    print("[DEBUG] Looking for plot...")
    local plot = getMyPlot()
    if not plot then
        warn("No plot found")
        return
    end
    
    local targetPart = plot:FindFirstChild("Collector", true) or
                       plot:FindFirstChild("MoneyBin", true) or
                       plot:FindFirstChild("ATM", true) or
                       plot:FindFirstChild("Drop", true) or
                       plot:FindFirstChildWhichIsA("BasePart", true)
    
    if not targetPart then
        warn("No target part found inside plot")
        return
    end
    
    print("Moving to", targetPart.Name)
    local ok = walkToTarget(targetPart.Position)
    print(ok and "Arrived!" or "Failed to reach target")
end

test()
