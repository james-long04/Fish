--!strict
-- GameConfig (ModuleScript) — ReplicatedStorage/Shared/GameConfig
-- Every number that tunes the game lives here. Everything scales forever.

local Config = {}

Config.Economy = {
	StartingCoins = 50,
	SaveIntervalSeconds = 60,
	OfflineEarningsCapHours = 8,
	StatsBroadcastSeconds = 1,
	RaidStealFraction = 0.10, -- player raid steals 10% of the victim's coins
	PirateLossFraction = 0.20, -- losing to pirates costs 20% of coins
}

Config.World = {
	IslandCount = 8,
	IslandRingRadius = 560,
	IslandRadius = 60,
	BorderRadius = 1150,
	SeaLevelY = 0,
	WaterSize = 3200,
}

Config.DayNight = {
	DaySeconds = 240,
	NightSeconds = 120,
}

-- Upgrade cost = base * growth ^ level  (level starts at 0, no cap)
Config.Upgrades = {
	Rod = { base = 25, growth = 1.35, name = "Fishing Rod", desc = "Rarer fish, faster bites" },
	Aquarium = { base = 60, growth = 1.30, name = "Aquarium", desc = "+25 tank slots, +10% income" },
	Castle = { base = 150, growth = 1.50, name = "Castle Walls", desc = "+HP, more cannons, taller walls" },
	Ship = { base = 200, growth = 1.60, name = "Ship", desc = "Faster, tougher, more cannons" },
	Musket = { base = 120, growth = 1.40, name = "Musket", desc = "More damage, faster reload, longer range" },
}
Config.UpgradeOrder = { "Rod", "Aquarium", "Castle", "Ship", "Musket" }

-- Selling: a fish is worth this many seconds of its own income (so rare fish sell for a lot)
Config.SellSecondsOfIncome = 90

Config.Musket = {
	Damage = function(level: number): number return math.floor(30 * (1.22 ^ level)) end,
	Reload = function(level: number): number return math.max(0.35, 1.6 * (0.93 ^ level)) end,
	Range = function(level: number): number return 120 + level * 8 end,
	Speed = 320,
}

function Config.UpgradeCost(kind: string, level: number): number
	local u = Config.Upgrades[kind]
	return math.floor(u.base * (u.growth ^ level))
end

-- Fish table lives in FishDatabase (300 species, 12 tiers). income = coins/sec per fish in your aquarium.
Config.Fish = require(script.Parent.FishDatabase)

Config.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Exotic", "Ancient", "Abyssal", "Celestial", "Divine", "Secret" }
Config.RarityColors = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(90, 220, 90),
	Rare = Color3.fromRGB(70, 150, 255),
	Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 170, 30),
	Mythic = Color3.fromRGB(255, 60, 120),
	Exotic = Color3.fromRGB(60, 240, 220),
	Ancient = Color3.fromRGB(200, 150, 90),
	Abyssal = Color3.fromRGB(110, 60, 180),
	Celestial = Color3.fromRGB(140, 200, 255),
	Divine = Color3.fromRGB(255, 240, 120),
	Secret = Color3.fromRGB(255, 255, 255),
}

-- Derived stats from upgrade levels (all unbounded)
Config.Stats = {}

function Config.Stats.RodLuck(level: number): number
	return level -- used as exponent base boost
end
function Config.Stats.BiteTime(level: number): (number, number)
	local minT = math.max(0.6, 2.5 - level * 0.08)
	local maxT = math.max(1.2, 6 - level * 0.15)
	return minT, maxT
end
function Config.Stats.AquariumCapacity(level: number): number
	return 50 + level * 25
end
function Config.Stats.IncomeMultiplier(level: number): number
	return 1 + level * 0.10
end
function Config.Stats.CastleHP(level: number): number
	return math.floor(200 * (1.4 ^ level))
end
function Config.Stats.CastleCannons(level: number): number
	return 1 + math.floor(level / 2)
end
function Config.Stats.CastleDamage(level: number): number
	return math.floor(10 * (1.25 ^ level))
end
function Config.Stats.ShipSpeed(level: number): number
	return 24 + level * 3
end
function Config.Stats.ShipHP(level: number): number
	return math.floor(100 * (1.3 ^ level))
end
function Config.Stats.ShipCannons(level: number): number
	return 1 + math.floor(level / 3)
end
function Config.Stats.ShipTier(level: number): string
	if level == 0 then return "Raft" end
	if level <= 2 then return "Dinghy" end
	if level <= 5 then return "Sloop" end
	if level <= 9 then return "Brigantine" end
	return "Galleon"
end

-- First-session hook: most new players land a Rare/Epic in their first two minutes.
-- Faster bites while the window is open, then an escalating chance per catch to force a higher tier.
Config.NewPlayer = {
	WindowSeconds = 120,            -- measured from first join
	BiteTimeMult = 0.45,            -- bites come ~2× faster during the window
	ForceChanceByCatch = { 0, 0.5, 0.8, 1.0 }, -- catch #1 never, #2 50%, #3 80%, #4+ guaranteed
	ForceTiers = { { tier = 3, weight = 70 }, { tier = 4, weight = 30 } }, -- Rare 70% / Epic 30%
}

function Config.RollFishOfTier(tier: number)
	local pool = {}
	for _, f in ipairs(Config.Fish) do if f.tier == tier then table.insert(pool, f) end end
	if #pool == 0 then return Config.Fish[1] end
	return pool[math.random(#pool)]
end

-- Villagers: hire with coins, upgrade their gear with coins. Each upgrade applies to all villagers of that type.
Config.Villagers = {
	MaxPerType = 20,      -- guards
	MaxShoreFishers = 50, -- first 50 fish from the island
	BoatCrew = 5,         -- after that, every 5 crew a boat (a copy of your ship)
	MaxBoats = 10,
	MaxFishers = 50 + 5 * 10,
	HireCost = function(kind: string, owned: number): number
		local base = (kind == "Fisher") and 150 or 220
		return math.floor(base * (1.5 ^ owned))
	end,
	GearCost = function(kind: string, level: number): number -- "FisherRod" | "GuardWeapon"
		local base = (kind == "FisherRod") and 120 or 160
		return math.floor(base * (1.4 ^ level))
	end,
	-- Fishers
	FisherInterval = function(rodLevel: number): number return math.max(4, 20 * (0.92 ^ rodLevel)) end,
	FisherLuck = function(rodLevel: number): number return rodLevel * 2 end,
	-- Guards
	GuardHP = function(weaponLevel: number): number return math.floor(120 * (1.3 ^ weaponLevel)) end,
	GuardDamage = function(weaponLevel: number): number return math.floor(14 * (1.3 ^ weaponLevel)) end,
	GuardRange = 60,
	GuardAttackInterval = 1.2,
	GuardWalkSpeed = 15,
}

Config.Fleet = {
	FishMinDist = 150, FishMaxDist = 320,      -- fishing grounds, distance from home island
	CannonInterval = 3,
	RaidStandoff = 95,                          -- how far from an enemy castle boats circle
	RespawnSeconds = 90,
	Damage = function(shipLevel: number): number return math.floor(10 * (1.25 ^ shipLevel)) end,
}

Config.Pirates = {
	WaveSize = function(castleLevel: number): number return 2 + math.floor(castleLevel / 2) end,
	HP = function(castleLevel: number): number return math.floor(40 * (1.25 ^ castleLevel)) end,
	Damage = function(castleLevel: number): number return math.floor(8 * (1.3 ^ castleLevel)) end,
	Bounty = function(castleLevel: number): number return math.floor(15 * (1.4 ^ castleLevel)) end,
	AttackInterval = 1.5,
	WalkSpeed = 12,
	CannonRange = 110,
	CannonInterval = 2,
	SwordDamage = function(rodLevel: number): number return 25 + rodLevel * 2 end,
	SwordRange = 9,
}

Config.Raid = {
	ShieldSecondsAfterRaid = 300,
	RangeFromCastle = 130,
}

-- Rarity roll: weight * (1 + 0.035 * luck) ^ (tier - 1)
function Config.RollFish(luck: number)
	local total = 0
	local weights = {}
	for i, f in ipairs(Config.Fish) do
		local w = f.weight * ((1 + 0.035 * luck) ^ (f.tier - 1))
		weights[i] = w
		total += w
	end
	local r = math.random() * total
	for i, f in ipairs(Config.Fish) do
		r -= weights[i]
		if r <= 0 then return f end
	end
	return Config.Fish[1]
end

local fishIndex = {}
for _, f in ipairs(Config.Fish) do fishIndex[f.name] = f end
function Config.FishByName(name: string)
	return fishIndex[name]
end

return Config
