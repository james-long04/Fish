--!strict
-- DataService (ModuleScript) — ServerScriptService/Services/DataService
-- Loads/saves each player's profile with DataStoreService. Session-cached, autosaves, saves on leave & shutdown.
-- Enable "Enable Studio Access to API Services" in Game Settings > Security to test saving in Studio.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GameConfig)

local STORE_NAME = "FishingTycoon_v1"
local store = DataStoreService:GetDataStore(STORE_NAME)

export type Profile = {
	Coins: number,
	Upgrades: { Rod: number, Aquarium: number, Castle: number, Ship: number },
	Fish: { [string]: number }, -- fish name -> count in aquarium
	Discovered: { [string]: boolean }, -- species ever caught
	TotalCaught: number,
	LastSeen: number,
	PiratesSlain: number,
	RaidsWon: number,
	-- monetization
	FirstJoin: number,
	BoostUntil: number,
	BoostMult: number,
	ShieldUntil: number,
	PirateSkipNights: number,
	StarterBought: boolean,
	RobuxSpent: number,
	LuckyStartGiven: boolean,
	Villagers: { Fishers: number, Guards: number, FisherRod: number, GuardWeapon: number },
}

local DataService = {}
local profiles: { [Player]: Profile } = {}
local loaded: { [Player]: boolean } = {}

local function defaultProfile(): Profile
	return {
		Coins = Config.Economy.StartingCoins,
		Upgrades = { Rod = 0, Aquarium = 0, Castle = 0, Ship = 0 },
		Fish = {},
		Discovered = {},
		TotalCaught = 0,
		LastSeen = os.time(),
		PiratesSlain = 0,
		RaidsWon = 0,
		FirstJoin = os.time(),
		BoostUntil = 0,
		BoostMult = 1,
		ShieldUntil = 0,
		PirateSkipNights = 0,
		StarterBought = false,
		RobuxSpent = 0,
		LuckyStartGiven = false,
		Villagers = { Fishers = 0, Guards = 0, FisherRod = 0, GuardWeapon = 0 },
	}
end

local function reconcile(data: any): Profile
	local p = defaultProfile()
	if type(data) ~= "table" then return p end
	for k, v in pairs(p) do
		if data[k] ~= nil then (p :: any)[k] = data[k] end
	end
	for k, v in pairs(defaultProfile().Upgrades) do
		if p.Upgrades[k] == nil then (p.Upgrades :: any)[k] = v end
	end
	if type(p.Villagers) ~= "table" then p.Villagers = defaultProfile().Villagers end
	for k, v in pairs(defaultProfile().Villagers) do
		if (p.Villagers :: any)[k] == nil then (p.Villagers :: any)[k] = v end
	end
	return p
end

function DataService.Load(player: Player): Profile
	local key = "player_" .. player.UserId
	local data
	local ok, err = pcall(function()
		data = store:GetAsync(key)
	end)
	if not ok then
		warn("[DataService] load failed for", player.Name, err)
	end
	local profile = reconcile(data)
	profiles[player] = profile
	loaded[player] = ok
	return profile
end

function DataService.Get(player: Player): Profile?
	return profiles[player]
end

function DataService.Save(player: Player)
	local profile = profiles[player]
	if not profile or not loaded[player] then return end -- never overwrite with a failed load
	profile.LastSeen = os.time()
	local key = "player_" .. player.UserId
	local ok, err = pcall(function()
		store:SetAsync(key, profile)
	end)
	if not ok then warn("[DataService] save failed for", player.Name, err) end
end

function DataService.Release(player: Player)
	DataService.Save(player)
	profiles[player] = nil
	loaded[player] = nil
end

function DataService.Start()
	Players.PlayerRemoving:Connect(DataService.Release)
	task.spawn(function()
		while true do
			task.wait(Config.Economy.SaveIntervalSeconds)
			for player in pairs(profiles) do
				DataService.Save(player)
			end
		end
	end)
	game:BindToClose(function()
		if RunService:IsStudio() then return end
		for player in pairs(profiles) do
			DataService.Save(player)
		end
	end)
end

return DataService
