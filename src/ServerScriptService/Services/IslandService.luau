--!strict
-- IslandService (ModuleScript) — ServerScriptService/Services/IslandService
-- Builds the world + islands, assigns an island per player, rebuilds castle on upgrade, updates signs/aquarium display.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local Builders = require(ReplicatedStorage.Shared.Builders)
local DataService = require(script.Parent.DataService)
local Monetization = require(script.Parent.MonetizationService)

local IslandService = {}
local islandsFolder: Folder
local islands: { Model } = {}
local playerIsland: { [Player]: Model } = {}
local spawnConnections: { [Player]: RBXScriptConnection } = {}

function IslandService.GetIsland(player: Player): Model?
	return playerIsland[player]
end

function IslandService.GetOwner(island: Model): Player?
	local id = island:GetAttribute("OwnerId")
	if id and id ~= 0 then return Players:GetPlayerByUserId(id) end
	return nil
end

function IslandService.AllIslands(): { Model }
	return islands
end

function IslandService.GetCastle(island: Model): Model?
	return island:FindFirstChild("Castle") :: Model?
end

function IslandService.RebuildCastle(player: Player)
	local island = playerIsland[player]
	local profile = DataService.Get(player)
	if not island or not profile then return end
	local castle = Builders.BuildCastle(island, profile.Upgrades.Castle, Monetization.ExtraCannons(player))
	local maxHP = math.floor(Config.Stats.CastleHP(profile.Upgrades.Castle) * Monetization.CastleHPMult(player))
	castle:SetAttribute("MaxHP", maxHP)
	castle:SetAttribute("HP", maxHP)
end

function IslandService.ApplyShield(player: Player)
	local island = playerIsland[player]
	local profile = DataService.Get(player)
	if island and profile then
		island:SetAttribute("RaidShieldUntil", math.max(island:GetAttribute("RaidShieldUntil") or 0, profile.ShieldUntil))
	end
end

function IslandService.UpdateAquariumDisplay(player: Player)
	local island = playerIsland[player]
	local profile = DataService.Get(player)
	if not island or not profile then return end
	local aq = island:FindFirstChild("Aquarium")
	if not aq then return end
	local glass = aq:FindFirstChild("Glass") :: Part
	local count = 0
	for _, n in pairs(profile.Fish) do count += n end
	local cap = math.floor(Config.Stats.AquariumCapacity(profile.Upgrades.Aquarium) * Monetization.CapacityMult(player))
	local label = glass:FindFirstChild("Label")
	if label then
		(label:FindFirstChild("Text") :: TextLabel).Text = string.format("Aquarium %d/%d", count, cap)
	end
	-- Publish the species list (highest income first); clients build and animate the models
	local list = {}
	for name, n in pairs(profile.Fish) do
		local f = Config.FishByName(name)
		if f and n > 0 then table.insert(list, { name = name, count = n, income = f.income }) end
	end
	table.sort(list, function(a, b) return a.income > b.income end)
	local trimmed = {}
	for i = 1, math.min(#list, 16) do table.insert(trimmed, { name = list[i].name, count = list[i].count }) end
	aq:SetAttribute("FishJSON", HttpService:JSONEncode(trimmed))
end

local function updateSign(island: Model, text: string)
	local sign = (island.PrimaryPart :: Part):FindFirstChild("OwnerSign")
	if sign then (sign:FindFirstChild("Text") :: TextLabel).Text = text end
end

local function assign(player: Player)
	local profile = DataService.Get(player)
	if not profile then return end
	for _, island in ipairs(islands) do
		if island:GetAttribute("OwnerId") == 0 then
			island:SetAttribute("OwnerId", player.UserId)
			island:SetAttribute("Owner", player.Name)
			playerIsland[player] = island
			updateSign(island, player.DisplayName .. "'s Island")
			IslandService.RebuildCastle(player)
			IslandService.ApplyShield(player)
			IslandService.UpdateAquariumDisplay(player)
			local spawn = island:FindFirstChild("Spawn") :: SpawnLocation
			player.RespawnLocation = spawn
			-- Always (re)spawn on your own island
			local function placeOnIsland(char: Model)
				local hrp = char:WaitForChild("HumanoidRootPart", 5)
				if hrp and playerIsland[player] == island then
					(hrp :: BasePart).CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
				end
			end
			spawnConnections[player] = player.CharacterAdded:Connect(placeOnIsland)
			if player.Character then task.defer(placeOnIsland, player.Character) end
			return
		end
	end
	warn("[IslandService] no free island for", player.Name)
end

local function release(player: Player)
	local conn = spawnConnections[player]
	if conn then conn:Disconnect(); spawnConnections[player] = nil end
	local island = playerIsland[player]
	if island then
		island:SetAttribute("OwnerId", 0)
		island:SetAttribute("Owner", "")
		island:SetAttribute("RaidShieldUntil", 0)
		updateSign(island, "Unclaimed Island")
		local aq = island:FindFirstChild("Aquarium")
		if aq then aq:SetAttribute("FishJSON", "[]") end
		Builders.BuildCastle(island, 0)
		playerIsland[player] = nil
	end
end

function IslandService.Start()
	islandsFolder = Workspace:FindFirstChild("Islands") :: Folder
	if not islandsFolder then
		islandsFolder = Instance.new("Folder")
		islandsFolder.Name = "Islands"
		islandsFolder.Parent = Workspace
	end
	Builders.BuildWorld()
	for i = 1, Config.World.IslandCount do
		local ang = (i / Config.World.IslandCount) * math.pi * 2
		local center = Vector3.new(math.cos(ang) * Config.World.IslandRingRadius, 0, math.sin(ang) * Config.World.IslandRingRadius)
		table.insert(islands, Builders.BuildIsland(i, center, islandsFolder))
	end
	Players.PlayerRemoving:Connect(release)
end

-- Called by Main after the profile is loaded
IslandService.Assign = assign

return IslandService
