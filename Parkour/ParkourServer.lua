--[[
	ParkourServer  (Script)  ->  ServerScriptService > ParkourServer

	Server half of the free-running system:
	  - creates the ParkourEvent remote the client talks through
	  - applies fall damage requested by the client (clamped)
	  - keeps a "Viewpoints" leaderstat for synchronised viewpoints
	  - sets walk speed / jump power on every spawned character
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:WaitForChild("Parkour")
local Config = require(folder:WaitForChild("ParkourConfig"))

local remote = folder:FindFirstChild("ParkourEvent")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "ParkourEvent"
	remote.Parent = folder
end

local synced = {}  -- [player] = { [viewpointId] = true }

local function onCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end
	humanoid.WalkSpeed = Config.WalkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.JumpPower
	humanoid.BreakJointsOnDeath = false
end

Players.PlayerAdded:Connect(function(player)
	synced[player] = {}

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local viewpoints = Instance.new("IntValue")
	viewpoints.Name = "Viewpoints"
	viewpoints.Parent = stats
	stats.Parent = player

	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		onCharacter(player, player.Character)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	synced[player] = nil
end)

remote.OnServerEvent:Connect(function(player, action, arg)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if action == "Sync" and typeof(arg) == "string" then
		local list = synced[player]
		if list and not list[arg] then
			list[arg] = true
			local stats = player:FindFirstChild("leaderstats")
			local value = stats and stats:FindFirstChild("Viewpoints")
			if value then
				value.Value += 1
			end
			remote:FireAllClients("Synced", player.Name, arg)
		end

	elseif action == "FallDamage" and typeof(arg) == "number" and humanoid and humanoid.Health > 0 then
		local amount = math.clamp(arg, 0, 1000)
		if amount >= 1000 then
			humanoid.Health = 0
		else
			humanoid:TakeDamage(amount)
		end
	end
end)
