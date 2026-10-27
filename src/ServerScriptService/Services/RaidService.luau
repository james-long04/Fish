--!strict
-- RaidService (ModuleScript) — ServerScriptService/Services/RaidService
-- Sail to someone's island, get near their castle, and you're raiding: their cannons shoot you,
-- your cutlass and ship cannons damage their castle. Break it to steal coins + a fish.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local IslandService = require(script.Parent.IslandService)
local EconomyService = require(script.Parent.EconomyService)
local CombatService = require(script.Parent.CombatService)
local Monetization = require(script.Parent.MonetizationService)
local DayNightService = require(script.Parent.DayNightService)

local RaidService = {}

local function updateRaidStates()
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not char or not hrp then continue end
		local raiding: string? = nil
		if not DayNightService.IsNight then
			if char:GetAttribute("Raiding") ~= nil then char:SetAttribute("Raiding", nil) end
			continue
		end
		for _, island in ipairs(IslandService.AllIslands()) do
			local ownerId = island:GetAttribute("OwnerId")
			if ownerId ~= 0 and ownerId ~= player.UserId then
				local castle = island:FindFirstChild("Castle") :: Model?
				local shieldUntil = island:GetAttribute("RaidShieldUntil") or 0
				if castle and castle.PrimaryPart and os.time() >= shieldUntil then
					local d = ((castle.PrimaryPart :: BasePart).Position - hrp.Position).Magnitude
					if d <= Config.Raid.RangeFromCastle then
						raiding = island.Name
						break
					end
				end
			end
		end
		local prev = char:GetAttribute("Raiding")
		if prev ~= raiding then
			char:SetAttribute("Raiding", raiding)
			if raiding then
				local island = game:GetService("Workspace").Islands:FindFirstChild(raiding) :: Model
				EconomyService.Notify(player, "⚔️ Raiding " .. island:GetAttribute("Owner") .. "'s island! Break the castle!", Color3.fromRGB(255, 120, 60))
				local victim = IslandService.GetOwner(island)
				if victim then
					EconomyService.Notify(victim, "⚠️ " .. player.DisplayName .. " is raiding your island!", Color3.fromRGB(255, 80, 80))
				end
			end
		end
	end
end

local function onCastleDestroyed(island: Model, attacker: Player?)
	if not attacker then return end
	if not DayNightService.IsNight then return end -- raids only count at night
	local victim = IslandService.GetOwner(island)
	if not victim or victim == attacker then return end
	local vProfile = DataService.Get(victim)
	local aProfile = DataService.Get(attacker)
	if not vProfile or not aProfile then return end

	local stolen = math.floor(vProfile.Coins * Config.Economy.RaidStealFraction * Monetization.LossMult(victim))
	vProfile.Coins -= stolen
	aProfile.Coins += stolen
	aProfile.RaidsWon += 1

	-- steal one random fish if the attacker has room
	local stolenFish: string? = nil
	local names = {}
	for name, count in pairs(vProfile.Fish) do
		if count > 0 then table.insert(names, name) end
	end
	if #names > 0 and EconomyService.FishCount(aProfile) < EconomyService.Capacity(attacker, aProfile) then
		stolenFish = names[math.random(#names)]
		vProfile.Fish[stolenFish] -= 1
		if vProfile.Fish[stolenFish] <= 0 then vProfile.Fish[stolenFish] = nil end
		aProfile.Fish[stolenFish] = (aProfile.Fish[stolenFish] or 0) + 1
		IslandService.UpdateAquariumDisplay(victim)
		IslandService.UpdateAquariumDisplay(attacker)
	end

	island:SetAttribute("RaidShieldUntil", os.time() + Config.Raid.ShieldSecondsAfterRaid)
	local fishText = stolenFish and (" and a " .. stolenFish) or ""
	EconomyService.Notify(attacker, string.format("🏴‍☠️ Raid successful! Stole %d coins%s.", stolen, fishText), Color3.fromRGB(255, 220, 90))
	EconomyService.Notify(victim, string.format("%s raided you for %d coins%s. Shield up for 5 min.", attacker.DisplayName, stolen, fishText), Color3.fromRGB(255, 80, 80))
	Remotes.RaidResult:FireClient(attacker, true, stolen)
	Remotes.RaidResult:FireClient(victim, false, stolen)
	Monetization.Offer(victim, "Shield", string.format("%s took %d coins. Lock your island for 24 hours?", attacker.DisplayName, stolen))
	EconomyService.PushStats(attacker)
	EconomyService.PushStats(victim)
end

function RaidService.Start()
	CombatService.CastleDestroyed.Event:Connect(onCastleDestroyed)
	task.spawn(function()
		while true do
			task.wait(0.5)
			updateRaidStates()
		end
	end)
end

return RaidService
