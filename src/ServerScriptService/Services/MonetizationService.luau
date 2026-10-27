--!strict
-- MonetizationService (ModuleScript) — ServerScriptService/Services/MonetizationService
-- Game passes (permanent perks), developer products (coins, boosts, shields, instant upgrades, starter pack),
-- purchase prompts, receipt processing, and contextual offers.
-- Other services ask this module for multipliers; this module never requires them (no circular requires).

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local StoreConfig = require(ReplicatedStorage.Shared.StoreConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local Monetization = {}
-- Fired after any purchase is applied: (player, key). Listened to by Main to rebuild castle/ship/etc.
Monetization.PurchaseApplied = Instance.new("BindableEvent")
-- Fired once passes are known for a player
Monetization.PassesLoaded = Instance.new("BindableEvent")

local owned: { [Player]: { [string]: boolean } } = {}
local pendingLevelUp: { [Player]: string } = {}
local lastOffer: { [Player]: number } = {}
local sessionOffers: { [Player]: { [string]: boolean } } = {}

local OFFER_COOLDOWN = 180
local STARTER_WINDOW = 24 * 3600 -- starter pack visible for 24h after first join

----------------------------------------------------------------------
-- Queries used by the rest of the game
----------------------------------------------------------------------
function Monetization.OwnsPass(player: Player, key: string): boolean
	local o = owned[player]
	return o ~= nil and o[key] == true
end

local function passEffect(player: Player, field: string, default: number, combine: (number, number) -> number): number
	local v = default
	for _, p in ipairs(StoreConfig.Passes) do
		if Monetization.OwnsPass(player, p.key) and (p.effects :: any)[field] then
			v = combine(v, (p.effects :: any)[field])
		end
	end
	return v
end
local mul = function(a: number, b: number) return a * b end
local add = function(a: number, b: number) return a + b end

function Monetization.IncomeMult(player: Player): number
	local m = passEffect(player, "IncomeMult", 1, mul)
	local profile = DataService.Get(player)
	if profile and profile.BoostUntil > os.time() then m *= profile.BoostMult end
	return m
end
function Monetization.CapacityMult(player: Player): number return passEffect(player, "CapacityMult", 1, mul) end
function Monetization.LuckBonus(player: Player): number return passEffect(player, "LuckBonus", 0, add) end
function Monetization.ExtraCannons(player: Player): number return passEffect(player, "ExtraCannons", 0, add) end
function Monetization.SpeedMult(player: Player): number return passEffect(player, "SpeedMult", 1, mul) end
function Monetization.CastleHPMult(player: Player): number return passEffect(player, "CastleHPMult", 1, mul) end
function Monetization.LossMult(player: Player): number return passEffect(player, "LossMult", 1, mul) end
function Monetization.HasAutoFish(player: Player): boolean return Monetization.OwnsPass(player, "AutoFish") end

function Monetization.IsShielded(player: Player): boolean
	local profile = DataService.Get(player)
	return profile ~= nil and profile.ShieldUntil > os.time()
end

-- Returns true (and consumes a night) if pirates should skip this player tonight
function Monetization.ConsumePirateSkip(player: Player): boolean
	local profile = DataService.Get(player)
	if profile and profile.PirateSkipNights > 0 then
		profile.PirateSkipNights -= 1
		return true
	end
	return false
end

function Monetization.StarterEligible(player: Player): boolean
	local profile = DataService.Get(player)
	if not profile or profile.StarterBought then return false end
	return (os.time() - profile.FirstJoin) < STARTER_WINDOW
end

----------------------------------------------------------------------
-- Store info to client
----------------------------------------------------------------------
function Monetization.PushStoreInfo(player: Player)
	local profile = DataService.Get(player)
	if not profile then return end
	local passes = {}
	for _, p in ipairs(StoreConfig.Passes) do
		passes[p.key] = { owned = Monetization.OwnsPass(player, p.key), available = p.id ~= 0 }
	end
	local products = {}
	for _, p in ipairs(StoreConfig.Products) do
		products[p.key] = { available = p.id ~= 0 }
	end
	Remotes.StoreInfo:FireClient(player, {
		Passes = passes,
		Products = products,
		BoostMult = (profile.BoostUntil > os.time()) and profile.BoostMult or 1,
		BoostSecondsLeft = math.max(0, profile.BoostUntil - os.time()),
		ShieldSecondsLeft = math.max(0, profile.ShieldUntil - os.time()),
		PirateSkipNights = profile.PirateSkipNights,
		StarterEligible = Monetization.StarterEligible(player),
		StarterSecondsLeft = math.max(0, STARTER_WINDOW - (os.time() - profile.FirstJoin)),
		CoinPackValues = Monetization.CoinPackValues(player),
	})
end

-- Coin packs scale with the player's income so they stay worth buying forever
function Monetization.CoinPackValues(player: Player): { [string]: number }
	local profile = DataService.Get(player)
	local out = {}
	if not profile then return out end
	local income = 0
	for name, count in pairs(profile.Fish) do
		local f = Config.FishByName(name)
		if f then income += f.income * count end
	end
	income *= Config.Stats.IncomeMultiplier(profile.Upgrades.Aquarium) * Monetization.IncomeMult(player)
	for _, p in ipairs(StoreConfig.Products) do
		if p.kind == "coins" then
			out[p.key] = math.max(StoreConfig.CoinsFloor[p.key], math.floor(income * 60 * p.coinsMinutes))
		end
	end
	return out
end

----------------------------------------------------------------------
-- Contextual offers (one per 3 minutes, each kind once per session)
----------------------------------------------------------------------
function Monetization.Offer(player: Player, key: string, reason: string)
	local product = StoreConfig.ProductByKey(key) or StoreConfig.PassByKey(key)
	if not product or product.id == 0 then return end
	if StoreConfig.PassByKey(key) and Monetization.OwnsPass(player, key) then return end
	if os.time() - (lastOffer[player] or 0) < OFFER_COOLDOWN then return end
	local seen = sessionOffers[player] or {}
	sessionOffers[player] = seen
	if seen[key] then return end
	seen[key] = true
	lastOffer[player] = os.time()
	Remotes.Offer:FireClient(player, key, reason)
end

----------------------------------------------------------------------
-- Purchases
----------------------------------------------------------------------
local function promptBuy(player: Player, key: string, extra: any)
	local pass = StoreConfig.PassByKey(key)
	if pass then
		if pass.id == 0 or Monetization.OwnsPass(player, key) then return end
		MarketplaceService:PromptGamePassPurchase(player, pass.id)
		return
	end
	local product = StoreConfig.ProductByKey(key)
	if product and product.id ~= 0 then
		if product.kind == "starter" and not Monetization.StarterEligible(player) then return end
		if product.kind == "levelup" and type(extra) == "string" and Config.Upgrades[extra] then
			pendingLevelUp[player] = extra
		end
		MarketplaceService:PromptProductPurchase(player, product.id)
	end
end

local function grantCoins(profile: DataService.Profile, player: Player, minutes: number, floorAmount: number): number
	local inc = 0
	for name, count in pairs(profile.Fish) do
		local f = Config.FishByName(name)
		if f then inc += f.income * count end
	end
	inc *= Config.Stats.IncomeMultiplier(profile.Upgrades.Aquarium) * Monetization.IncomeMult(player)
	local amount = math.max(floorAmount, math.floor(inc * 60 * minutes))
	profile.Coins += amount
	return amount
end

local function applyProduct(player: Player, product: any): boolean
	local profile = DataService.Get(player)
	if not profile then return false end
	local now = os.time()
	local msg = ""
	if product.kind == "coins" then
		local amount = grantCoins(profile, player, product.coinsMinutes, StoreConfig.CoinsFloor[product.key])
		msg = string.format("+%d coins!", amount)
	elseif product.kind == "boost" then
		-- extend if same/lower mult, replace if higher
		if profile.BoostUntil > now and profile.BoostMult >= product.mult then
			profile.BoostUntil += product.seconds
		else
			profile.BoostMult = product.mult
			profile.BoostUntil = math.max(now, profile.BoostUntil) + product.seconds
		end
		msg = string.format("%d× income active for %d min!", product.mult, product.seconds / 60)
	elseif product.kind == "shield" then
		profile.ShieldUntil = math.max(now, profile.ShieldUntil) + product.seconds
		msg = "Raid Shield up! Nobody can raid you for 24 hours."
	elseif product.kind == "pirateskip" then
		profile.PirateSkipNights += product.nights
		msg = string.format("Calm seas: pirates will skip your island for %d nights.", profile.PirateSkipNights)
	elseif product.kind == "levelup" then
		local kind = pendingLevelUp[player] or "Rod"
		pendingLevelUp[player] = nil;
		(profile.Upgrades :: any)[kind] += 1
		msg = string.format("%s is now Lv %d!", Config.Upgrades[kind].name, (profile.Upgrades :: any)[kind])
	elseif product.kind == "starter" then
		if profile.StarterBought then return true end
		profile.StarterBought = true
		profile.BoostMult = math.max(profile.BoostMult, 2)
		profile.BoostUntil = math.max(now, profile.BoostUntil) + 86400
		profile.ShieldUntil = math.max(now, profile.ShieldUntil) + 86400
		local amount = grantCoins(profile, player, 180, 3000)
		-- +1 to the lowest upgrade
		local lowest, lowestLv = "Rod", math.huge
		for _, k in ipairs(Config.UpgradeOrder) do
			if (profile.Upgrades :: any)[k] < lowestLv then lowest, lowestLv = k, (profile.Upgrades :: any)[k] end
		end
		(profile.Upgrades :: any)[lowest] += 1
		msg = string.format("Starter Pack! +%d coins, 2× income & shield for 24h, %s +1.", amount, Config.Upgrades[lowest].name)
	end
	profile.RobuxSpent += product.price
	Remotes.Notify:FireClient(player, "🎉 " .. msg, Color3.fromRGB(255, 220, 90))
	Monetization.PurchaseApplied:Fire(player, product.key)
	Monetization.PushStoreInfo(player)
	return true
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local product = StoreConfig.ProductById(receipt.ProductId)
	if not product then
		warn("[Monetization] unknown product", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, applied = pcall(applyProduct, player, product)
	if ok and applied then
		DataService.Save(player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function loadPasses(player: Player)
	local o = {}
	for _, p in ipairs(StoreConfig.Passes) do
		if p.id ~= 0 then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, p.id)
			o[p.key] = ok and has == true
		end
	end
	owned[player] = o
	Monetization.PassesLoaded:Fire(player)
	Monetization.PushStoreInfo(player)
end

function Monetization.Start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then return end
		local pass = StoreConfig.PassById(passId)
		if not pass then return end
		owned[player] = owned[player] or {}
		owned[player][pass.key] = true
		local profile = DataService.Get(player)
		if profile then profile.RobuxSpent += pass.price end
		Remotes.Notify:FireClient(player, "🎉 " .. pass.name .. " unlocked forever!", Color3.fromRGB(255, 220, 90))
		Monetization.PurchaseApplied:Fire(player, pass.key)
		Monetization.PushStoreInfo(player)
	end)
	Remotes.Buy.OnServerEvent:Connect(promptBuy)
	Players.PlayerRemoving:Connect(function(p)
		owned[p] = nil; pendingLevelUp[p] = nil; lastOffer[p] = nil; sessionOffers[p] = nil
	end)
	-- keep timers on the client fresh
	task.spawn(function()
		while true do
			task.wait(15)
			for _, p in ipairs(Players:GetPlayers()) do
				if owned[p] then Monetization.PushStoreInfo(p) end
			end
		end
	end)
end

-- Called by Main after the profile is loaded (yields on MarketplaceService)
Monetization.LoadPasses = loadPasses

return Monetization
