print("Searching for the Roll remote...")
local count = 0

for _, item in pairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
    if item:IsA("RemoteFunction") and item.Name == "Roll" then
        print("🚨 FOUND IT! The new path is: " .. item:GetFullName())
        count = count + 1
    end
end

if count == 0 then
    warn("Could not find a RemoteFunction named 'Roll'. They might have renamed it!")
end