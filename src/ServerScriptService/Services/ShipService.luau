--!strict
-- ShipService (ModuleScript) — ServerScriptService/Services/ShipService
-- Spawns a player's ship at their dock, hands physics ownership to the driver, fires broadside cannons.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local Builders = require(ReplicatedStorage.Shared.Builders)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local IslandService = require(script.Parent.IslandService)
local EconomyService = require(script.Parent.EconomyService)
local CombatService = require(script.Parent.CombatService)
local Monetization = require(script.Parent.MonetizationService)

local ShipService = {}
local ships: { [Player]: Model } = {}
local shipsFolder: Folder
local lastFire: { [Player]: number } = {}

function ShipService.GetShip(player: Player): Model?
	local s = ships[player]
	if s and s.Parent then return s end
	return nil
end

local function spawnShip(player: Player)
	local profile = DataService.Get(player)
	local island = IslandService.GetIsland(player)
	if not profile or not island then return end
	local old = ships[player]
	if old then old:Destroy() end
	local level = profile.Upgrades.Ship
	local ship = Builders.BuildShip(level, player.DisplayName, Monetization.ExtraCannons(player), Monetization.OwnsPass(player, "Admiral"))
	ship:SetAttribute("OwnerId", player.UserId)
	ship:SetAttribute("Speed", Config.Stats.ShipSpeed(level) * Monetization.SpeedMult(player))
	local dockEnd = island:FindFirstChild("DockEnd") :: Part
	local hull = ship.PrimaryPart :: BasePart
	-- park alongside the dock end, nose pointing out to sea, deck level with the planks
	local sideOffset = 4.5 + hull.Size.X / 2
	ship:PivotTo(dockEnd.CFrame * CFrame.new(sideOffset, -0.8, 0))
	ship.Parent = shipsFolder
	ships[player] = ship

	local seat = ship:FindFirstChild("DriverSeat") :: VehicleSeat
	local drive = hull:FindFirstChild("Drive") :: LinearVelocity
	local steer = hull:FindFirstChild("Steer") :: AngularVelocity
	local prompt = seat:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function(who: Player)
			local hum = who.Character and who.Character:FindFirstChildOfClass("Humanoid")
			if hum and not seat.Occupant then seat:Sit(hum) end
		end)
	end
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occ = seat.Occupant
		if occ then
			local driver = Players:GetPlayerFromCharacter(occ.Parent)
			if driver then
				pcall(function() hull:SetNetworkOwner(driver) end)
				drive.MaxForce = hull.AssemblyMass * 80
				steer.MaxTorque = hull.AssemblyMass * 500
				EconomyService.Notify(driver, "⛵ W/S sail • A/D steer • F or FIRE for cannons • jump to leave", Color3.fromRGB(120, 220, 255))
			end
		else
			drive.PlaneVelocity = Vector2.zero
			steer.AngularVelocity = Vector3.zero
			drive.MaxForce = 0
			steer.MaxTorque = 0
			pcall(function() hull:SetNetworkOwnershipAuto() end)
		end
	end)
	EconomyService.Notify(player, string.format("Your %s is moored beside the dock. Walk aboard and press E at the helm.", Config.Stats.ShipTier(level)), Color3.fromRGB(120, 220, 255))
end

local function fireCannons(player: Player)
	local ship = ShipService.GetShip(player)
	local profile = DataService.Get(player)
	if not ship or not profile then return end
	local seat = ship:FindFirstChild("DriverSeat") :: VehicleSeat
	if not seat.Occupant or Players:GetPlayerFromCharacter(seat.Occupant.Parent) ~= player then return end
	if os.clock() - (lastFire[player] or 0) < 1.5 then return end
	lastFire[player] = os.clock()
	local cannons = ship:FindFirstChild("Cannons")
	if not cannons or #cannons:GetChildren() == 0 then return end
	local level = profile.Upgrades.Ship
	local dmg = math.floor(12 * (1.25 ^ level))
	local hull = ship.PrimaryPart :: BasePart
	for _, c in ipairs(cannons:GetChildren()) do
		if c:IsA("BasePart") then
			local side = c:GetAttribute("Side") :: number
			local dir = hull.CFrame.RightVector * side
			CombatService.FireCannonball(CFrame.new(c.Position + dir * 2), dir, 90, dmg, player, { ship, player.Character :: Instance })
		end
	end
end

function ShipService.Start()
	shipsFolder = Instance.new("Folder")
	shipsFolder.Name = "Ships"
	shipsFolder.Parent = Workspace
	Remotes.SpawnShip.OnServerEvent:Connect(spawnShip)
	Remotes.FireCannons.OnServerEvent:Connect(fireCannons)
	Players.PlayerRemoving:Connect(function(p)
		local s = ships[p]
		if s then s:Destroy() end
		ships[p] = nil
		lastFire[p] = nil
	end)
end

return ShipService
