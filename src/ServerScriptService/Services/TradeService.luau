--!strict
-- TradeService (ModuleScript) — ServerScriptService/Services/TradeService
-- Safe fish trading. Both players build an offer, both confirm, server swaps atomically.
-- Any change to either offer clears both confirmations, so nobody can swap items at the last second.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local IslandService = require(script.Parent.IslandService)
local EconomyService = require(script.Parent.EconomyService)

local TradeService = {}

type Trade = {
	a: Player, b: Player,
	offers: { [Player]: { [string]: number } },
	confirmed: { [Player]: boolean },
}
local trades: { [Player]: Trade } = {}      -- player -> their active trade
local pending: { [Player]: Player } = {}    -- target -> requester
local REQUEST_TIMEOUT = 30

local function other(t: Trade, p: Player): Player
	return (t.a == p) and t.b or t.a
end

local function serialize(t: Trade, forPlayer: Player)
	local me, them = forPlayer, other(t, forPlayer)
	local function offerList(p: Player)
		local out = {}
		for name, n in pairs(t.offers[p]) do
			local f = Config.FishByName(name)
			if f and n > 0 then table.insert(out, { name = name, count = n, rarity = f.rarity, income = f.income }) end
		end
		table.sort(out, function(x, y) return x.income > y.income end)
		return out
	end
	return {
		PartnerName = them.DisplayName,
		MyOffer = offerList(me),
		TheirOffer = offerList(them),
		MyConfirmed = t.confirmed[me] == true,
		TheirConfirmed = t.confirmed[them] == true,
	}
end

local function push(t: Trade)
	Remotes.TradeState:FireClient(t.a, serialize(t, t.a))
	Remotes.TradeState:FireClient(t.b, serialize(t, t.b))
end

local function endTrade(t: Trade, reason: string?)
	trades[t.a] = nil
	trades[t.b] = nil
	Remotes.TradeState:FireClient(t.a, nil)
	Remotes.TradeState:FireClient(t.b, nil)
	if reason then
		EconomyService.Notify(t.a, reason, Color3.fromRGB(255, 180, 90))
		EconomyService.Notify(t.b, reason, Color3.fromRGB(255, 180, 90))
	end
end

local function clearConfirms(t: Trade)
	t.confirmed[t.a] = false
	t.confirmed[t.b] = false
end

local function onRequest(from: Player, targetUserId: number)
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == from or trades[from] or trades[target] then
		EconomyService.Notify(from, "That player can't trade right now.", Color3.fromRGB(255, 120, 120))
		return
	end
	if pending[target] then
		EconomyService.Notify(from, "They already have a pending request.", Color3.fromRGB(255, 120, 120))
		return
	end
	pending[target] = from
	Remotes.TradeIncoming:FireClient(target, from.UserId, from.DisplayName)
	EconomyService.Notify(from, "Trade request sent to " .. target.DisplayName, Color3.fromRGB(120, 220, 255))
	task.delay(REQUEST_TIMEOUT, function()
		if pending[target] == from then
			pending[target] = nil
			EconomyService.Notify(from, target.DisplayName .. " didn't answer.", Color3.fromRGB(255, 180, 90))
		end
	end)
end

local function onRespond(target: Player, accept: boolean)
	local from = pending[target]
	pending[target] = nil
	if not from or not from.Parent then return end
	if not accept then
		EconomyService.Notify(from, target.DisplayName .. " declined the trade.", Color3.fromRGB(255, 180, 90))
		return
	end
	if trades[from] or trades[target] then return end
	local t: Trade = { a = from, b = target, offers = { [from] = {}, [target] = {} }, confirmed = { [from] = false, [target] = false } }
	trades[from] = t
	trades[target] = t
	push(t)
end

local function onOffer(player: Player, fishName: string, delta: number)
	local t = trades[player]
	local profile = DataService.Get(player)
	if not t or not profile or type(fishName) ~= "string" or type(delta) ~= "number" then return end
	if not Config.FishByName(fishName) then return end
	delta = math.clamp(math.floor(delta), -99, 99)
	local offer = t.offers[player]
	local current = offer[fishName] or 0
	local owned = profile.Fish[fishName] or 0
	local new = math.clamp(current + delta, 0, owned)
	if new == current then return end
	if new == 0 then offer[fishName] = nil else offer[fishName] = new end
	clearConfirms(t)
	push(t)
end

local function finalize(t: Trade)
	local pa, pb = DataService.Get(t.a), DataService.Get(t.b)
	if not pa or not pb then endTrade(t, "Trade cancelled."); return end
	-- validate ownership
	for p, profile in pairs({ [t.a] = pa, [t.b] = pb }) do
		for name, n in pairs(t.offers[p]) do
			if (profile.Fish[name] or 0) < n then endTrade(t, "Trade cancelled: fish no longer available."); return end
		end
	end
	local function total(o) local n = 0 for _, c in pairs(o) do n += c end return n end
	local giveA, giveB = total(t.offers[t.a]), total(t.offers[t.b])
	if giveA == 0 and giveB == 0 then endTrade(t, "Nothing to trade."); return end
	-- capacity: each side's new count must fit
	local countA = EconomyService.FishCount(pa) - giveA + giveB
	local countB = EconomyService.FishCount(pb) - giveB + giveA
	if countA > EconomyService.Capacity(t.a, pa) then endTrade(t, t.a.DisplayName .. "'s aquarium would overflow. Trade cancelled."); return end
	if countB > EconomyService.Capacity(t.b, pb) then endTrade(t, t.b.DisplayName .. "'s aquarium would overflow. Trade cancelled."); return end
	-- swap
	local function move(fromP: DataService.Profile, toP: DataService.Profile, offer)
		for name, n in pairs(offer) do
			fromP.Fish[name] -= n
			if fromP.Fish[name] <= 0 then fromP.Fish[name] = nil end
			toP.Fish[name] = (toP.Fish[name] or 0) + n
			toP.Discovered[name] = true
		end
	end
	move(pa, pb, t.offers[t.a])
	move(pb, pa, t.offers[t.b])
	endTrade(t, nil)
	for _, p in ipairs({ t.a, t.b }) do
		IslandService.UpdateAquariumDisplay(p)
		EconomyService.PushStats(p)
		EconomyService.Notify(p, "✅ Trade complete!", Color3.fromRGB(120, 255, 140))
		DataService.Save(p)
	end
end

local function onConfirm(player: Player)
	local t = trades[player]
	if not t then return end
	t.confirmed[player] = true
	push(t)
	if t.confirmed[t.a] and t.confirmed[t.b] then
		-- short safety delay so both clients see the double-confirm state
		task.delay(1, function()
			if trades[t.a] == t and t.confirmed[t.a] and t.confirmed[t.b] then finalize(t) end
		end)
	end
end

local function onCancel(player: Player)
	local t = trades[player]
	if t then endTrade(t, player.DisplayName .. " cancelled the trade.") end
end

function TradeService.Start()
	Remotes.TradeRequest.OnServerEvent:Connect(onRequest)
	Remotes.TradeRespond.OnServerEvent:Connect(onRespond)
	Remotes.TradeOffer.OnServerEvent:Connect(onOffer)
	Remotes.TradeConfirm.OnServerEvent:Connect(onConfirm)
	Remotes.TradeCancel.OnServerEvent:Connect(onCancel)
	Players.PlayerRemoving:Connect(function(p)
		onCancel(p)
		pending[p] = nil
		for target, from in pairs(pending) do
			if from == p then pending[target] = nil end
		end
	end)
end

return TradeService
