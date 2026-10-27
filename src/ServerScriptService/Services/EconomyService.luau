--!strict
-- EconomyService (ModuleScript) — ServerScriptService/Services/EconomyService
-- Passive income from aquarium fish, upgrades, offline earnings, and the per-second Stats broadcast.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local IslandService = require(script.Parent.IslandService)
local DayNightService = require(script.Parent.DayNightService)
local Monetization = require(script.Parent.MonetizationService)

local EconomyService = {}
EconomyService.CrewStatsFn = nil -- set by Main (VillagerService.CrewStats) to avoid a circular require

function EconomyService.IncomePerSecond(profile: DataService.Profile, player: Player?): number
	local total = 0
	for name, count in pairs(profile.Fish) do
		local f = Config.FishByName(name)
		if f then total += f.income * count end
	end
	local mult = Config.Stats.IncomeMultiplier(profile.Upgrades.Aquarium)
	if player then mult *= Monetization.IncomeMult(player) end
	return total * mult
end

function EconomyService.Capacity(player: Player, profile: DataService.Profile): number
	return math.floor(Config.Stats.AquariumCapacity(profile.Upgrades.Aquarium) * Monetization.CapacityMult(player))
end

function EconomyService.FishCount(profile: DataService.Profile): number
	local n = 0
	for _, c in pairs(profile.Fish) do n += c end
	return n
end

function EconomyService.Notify(player: Player, text: string, color: Color3?)
	Remotes.Notify:FireClient(player, text, color)
end

function EconomyService.AddCoins(player: Player, amount: number)
	local profile = DataService.Get(player)
	if profile then profile.Coins = math.max(0, profile.Coins + amount) end
end

function EconomyService.PushStats(player: Player)
	local profile = DataService.Get(player)
	if not profile then return end
	local island = IslandService.GetIsland(player)
	local castle = island and IslandService.GetCastle(island)
	local costs = {}
	for _, kind in ipairs(Config.UpgradeOrder) do
		costs[kind] = Config.UpgradeCost(kind, (profile.Upgrades :: any)[kind])
	end
	Remotes.Stats:FireClient(player, {
		Coins = math.floor(profile.Coins),
		Income = EconomyService.IncomePerSecond(profile, player),
		Fish = profile.Fish,
		FishCount = EconomyService.FishCount(profile),
		Capacity = EconomyService.Capacity(player, profile),
		Upgrades = profile.Upgrades,
		Costs = costs,
		CastleHP = castle and castle:GetAttribute("HP") or 0,
		CastleMaxHP = castle and castle:GetAttribute("MaxHP") or 0,
		ShipTier = Config.Stats.ShipTier(profile.Upgrades.Ship),
		TotalCaught = profile.TotalCaught,
		Discovered = (function() local n = 0 for _ in pairs(profile.Discovered) do n += 1 end return n end)(),
		TotalSpecies = #Config.Fish,
		PiratesSlain = profile.PiratesSlain,
		RaidsWon = profile.RaidsWon,
		IsNight = DayNightService.IsNight,
		Crew = EconomyService.CrewStatsFn and EconomyService.CrewStatsFn(profile) or nil,
	})
end

local failedBuys: { [Player]: number } = {}

local function onBuy(player: Player, kind: string)
	local profile = DataService.Get(player)
	if not profile or not Config.Upgrades[kind] then return end
	local level = (profile.Upgrades :: any)[kind]
	local cost = Config.UpgradeCost(kind, level)
	if profile.Coins < cost then
		EconomyService.Notify(player, "Not enough coins!", Color3.fromRGB(255, 90, 90))
		failedBuys[player] = (failedBuys[player] or 0) + 1
		if failedBuys[player] >= 2 then
			failedBuys[player] = 0
			Monetization.Offer(player, "Coins2", string.format("%s is %s coins away. Skip the wait?", Config.Upgrades[kind].name, tostring(math.floor(cost - profile.Coins))))
		end
		return
	end
	failedBuys[player] = 0
	profile.Coins -= cost;
	(profile.Upgrades :: any)[kind] = level + 1
	EconomyService.Notify(player, string.format("%s upgraded to Lv %d!", Config.Upgrades[kind].name, level + 1), Color3.fromRGB(120, 255, 140))
	if kind == "Castle" then
		IslandService.RebuildCastle(player)
	elseif kind == "Aquarium" then
		IslandService.UpdateAquariumDisplay(player)
	end
	EconomyService.PushStats(player)
end

function EconomyService.ApplyOfflineEarnings(player: Player)
	local profile = DataService.Get(player)
	if not profile then return end
	local away = os.time() - (profile.LastSeen or os.time())
	local capped = math.clamp(away, 0, Config.Economy.OfflineEarningsCapHours * 3600)
	local earned = math.floor(EconomyService.IncomePerSecond(profile, player) * capped * 0.5) -- 50% rate while offline
	if earned > 0 then
		profile.Coins += earned
		EconomyService.Notify(player, string.format("Welcome back! Your aquarium earned %d coins while you were away.", earned), Color3.fromRGB(255, 220, 90))
	end
end

function EconomyService.Start()
	Remotes.BuyUpgrade.OnServerEvent:Connect(onBuy)
	task.spawn(function()
		while true do
			task.wait(Config.Economy.StatsBroadcastSeconds)
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = DataService.Get(player)
				if profile then
					profile.Coins += EconomyService.IncomePerSecond(profile, player) * Config.Economy.StatsBroadcastSeconds
					EconomyService.PushStats(player)
				end
			end
		end
	end)
end

return EconomyService
