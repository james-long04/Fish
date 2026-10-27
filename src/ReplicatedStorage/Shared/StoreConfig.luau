--!strict
-- StoreConfig (ModuleScript) — ReplicatedStorage/Shared/StoreConfig
-- Every Robux offer in the game. Create each pass/product in Creator Dashboard > your experience >
-- Monetization, then paste the real IDs over the 0s below. Items with id 0 are hidden from the store.
--
-- Pricing philosophy (this is what makes it convert):
--  * Low entry prices (29–99 R$) so the first purchase is an impulse, not a decision.
--  * Three coin tiers with HONEST better value per Robux as you go up — the middle tier is the anchor,
--    the big tier is the "best value" and most people pick the middle.
--  * Permanent passes are priced like "one coffee" and described in game outcomes, not features.
--  * Consumables are offered at the moment they matter (after a raid loss, at dusk, when the tank is full).
--  * The Starter Pack is a real one-time discount shown only on the first session. Real, not fake, scarcity.

local StoreConfig = {}

-- Game passes: permanent, one-time, checked with UserOwnsGamePassAsync
StoreConfig.Passes = {
	{
		key = "VIP", id = 0, price = 149,
		name = "VIP Tycoon", icon = "👑", tag = "MOST POPULAR",
		hook = "Earn 2× coins from your aquarium. Forever.",
		bullets = { "2× passive income", "Golden name tag", "VIP chat tag", "Pays for itself in minutes" },
		effects = { IncomeMult = 2 },
	},
	{
		key = "AutoFish", id = 0, price = 99,
		name = "Auto-Fisher", icon = "🤖", tag = "HANDS FREE",
		hook = "Your rod fishes by itself while you build, sail and raid.",
		bullets = { "Casts & reels automatically", "Works while AFK on your dock", "Never miss a bite" },
		effects = { AutoFish = true },
	},
	{
		key = "BigTank", id = 0, price = 79,
		name = "Mega Aquarium", icon = "🐠", tag = "",
		hook = "+50% aquarium slots, permanently.",
		bullets = { "Store way more fish", "More fish = more coins/sec", "Stacks with Aquarium upgrades" },
		effects = { CapacityMult = 1.5 },
	},
	{
		key = "LuckyRod", id = 0, price = 129,
		name = "Lucky Rod", icon = "🍀", tag = "RARE FISH",
		hook = "+15 Luck. Legendary and Mythic fish, way more often.",
		bullets = { "+15 permanent luck", "Shiny golden rod", "Stacks with Rod upgrades" },
		effects = { LuckBonus = 15 },
	},
	{
		key = "Admiral", id = 0, price = 199,
		name = "Admiral's Fleet", icon = "⚓", tag = "RAIDERS",
		hook = "+2 cannons on every ship, +2 on your castle, 1.5× ship speed.",
		bullets = { "+2 ship cannons", "+2 castle cannons", "1.5× sailing speed", "Black sails" },
		effects = { ExtraCannons = 2, SpeedMult = 1.5 },
	},
	{
		key = "Fortress", id = 0, price = 99,
		name = "Fortress Walls", icon = "🛡️", tag = "DEFENSE",
		hook = "Your castle has 2× HP and pirates take only half your coins.",
		bullets = { "2× castle HP", "Pirate losses halved", "Raiders steal half as much" },
		effects = { CastleHPMult = 2, LossMult = 0.5 },
	},
}

-- Developer products: consumable, handled in ProcessReceipt
StoreConfig.Products = {
	-- Coins (value per Robux improves as you go up; percentages below are true)
	{ key = "Coins1", id = 0, price = 29, kind = "coins", name = "Pouch of Coins", icon = "🪙", tag = "", hook = "A quick top-up.", coinsMinutes = 20 },
	{ key = "Coins2", id = 0, price = 79, kind = "coins", name = "Chest of Coins", icon = "💰", tag = "+40% MORE", hook = "The one most players pick.", coinsMinutes = 75 },
	{ key = "Coins3", id = 0, price = 199, kind = "coins", name = "Treasure Hoard", icon = "🏴‍☠️", tag = "BEST VALUE", hook = "Skip straight to the big upgrades.", coinsMinutes = 240 },

	-- Boosts & protection
	{ key = "Boost2x", id = 0, price = 49, kind = "boost", name = "2× Income (1 hour)", icon = "⚡", tag = "", hook = "Double everything your tank earns for the next hour.", seconds = 3600, mult = 2 },
	{ key = "Boost3x", id = 0, price = 99, kind = "boost", name = "3× Income (1 hour)", icon = "🔥", tag = "HOT", hook = "Triple income for an hour. Stacks with VIP.", seconds = 3600, mult = 3 },
	{ key = "Shield", id = 0, price = 59, kind = "shield", name = "Raid Shield (24h)", icon = "🛡️", tag = "", hook = "No player can raid you for 24 hours.", seconds = 86400 },
	{ key = "NoPirates", id = 0, price = 39, kind = "pirateskip", name = "Calm Seas (3 nights)", icon = "🌙", tag = "", hook = "Pirates skip your island for the next 3 nights.", nights = 3 },
	{ key = "LevelUp", id = 0, price = 69, kind = "levelup", name = "Instant Upgrade", icon = "⬆️", tag = "", hook = "+1 level on ANY upgrade, no matter the cost.", },

	-- One-time offers
	{ key = "Starter", id = 0, price = 99, kind = "starter", name = "Starter Pack", icon = "🎁", tag = "ONE TIME • 70% OFF", hook = "2× Income for 24h + Raid Shield 24h + 3 hours of coins + Instant Upgrade. Only on your first day.", oneTime = true },
}

-- "coinsMinutes" = how many minutes of the player's CURRENT income the pack gives (min floor below).
-- Scaling with income keeps coin packs worth buying at every stage of an infinite game.
StoreConfig.CoinsFloor = { Coins1 = 500, Coins2 = 2000, Coins3 = 7000 }

function StoreConfig.PassByKey(key: string)
	for _, p in ipairs(StoreConfig.Passes) do if p.key == key then return p end end
	return nil
end
function StoreConfig.ProductByKey(key: string)
	for _, p in ipairs(StoreConfig.Products) do if p.key == key then return p end end
	return nil
end
function StoreConfig.PassById(id: number)
	for _, p in ipairs(StoreConfig.Passes) do if p.id == id and id ~= 0 then return p end end
	return nil
end
function StoreConfig.ProductById(id: number)
	for _, p in ipairs(StoreConfig.Products) do if p.id == id and id ~= 0 then return p end end
	return nil
end

return StoreConfig
