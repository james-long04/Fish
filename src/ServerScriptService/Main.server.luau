--!strict
-- Main (Script) — ServerScriptService/Main
-- Boots every service in order, then handles player join.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage.Shared.Remotes) -- creates RemoteEvents

local Services = script.Parent.Services
local DataService = require(Services.DataService)
local IslandService = require(Services.IslandService)
local EconomyService = require(Services.EconomyService)
local FishingService = require(Services.FishingService)
local DayNightService = require(Services.DayNightService)
local CombatService = require(Services.CombatService)
local PirateService = require(Services.PirateService)
local ShipService = require(Services.ShipService)
local RaidService = require(Services.RaidService)
local Monetization = require(Services.MonetizationService)
local TradeService = require(Services.TradeService)
local VillagerService = require(Services.VillagerService)

DataService.Start()
Monetization.Start()
IslandService.Start()      -- builds world + islands
EconomyService.Start()
FishingService.Start()     -- needs islands
DayNightService.Start()
CombatService.Start()
PirateService.Start()
ShipService.Start()
RaidService.Start()
TradeService.Start()
VillagerService.Start()
EconomyService.CrewStatsFn = VillagerService.CrewStats

local function onPlayer(player: Player)
	DataService.Load(player)
	IslandService.Assign(player)
	EconomyService.ApplyOfflineEarnings(player)
	EconomyService.PushStats(player)
	Monetization.LoadPasses(player) -- yields; perks apply when it returns
	IslandService.RebuildCastle(player)
	IslandService.UpdateAquariumDisplay(player)
	VillagerService.Rebuild(player)
	EconomyService.PushStats(player)
end

-- Fallen guards come back at dawn
DayNightService.DayStarted.Event:Connect(function()
	for _, p in ipairs(Players:GetPlayers()) do VillagerService.Rebuild(p) end
end)

-- Re-apply anything a purchase changes in the world
Monetization.PurchaseApplied.Event:Connect(function(player: Player, key: string)
	if key == "Fortress" or key == "Admiral" or key == "LevelUp" or key == "Starter" then
		IslandService.RebuildCastle(player)
	end
	if key == "BigTank" or key == "LevelUp" or key == "Starter" then
		IslandService.UpdateAquariumDisplay(player)
	end
	if key == "Shield" or key == "Starter" then
		IslandService.ApplyShield(player)
	end
	EconomyService.PushStats(player)
end)

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, p)
end

print("[FishingTycoon] server ready")
