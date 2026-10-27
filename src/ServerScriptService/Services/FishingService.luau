--!strict
-- FishingService (ModuleScript) — ServerScriptService/Services/FishingService
-- Hold the prompt on a fishing spot to cast -> wait for a bite -> client must tap REEL inside the window.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local IslandService = require(script.Parent.IslandService)
local EconomyService = require(script.Parent.EconomyService)
local Monetization = require(script.Parent.MonetizationService)

local FishingService = {}
local REEL_WINDOW = 1.4
local onReel
local state: { [Player]: { biteAt: number?, casting: boolean, castId: number? } } = {}

local function finishCatch(player: Player)
	local profile = DataService.Get(player)
	if not profile then return end
	local fish
	local lucky = false
	local inWindow = (os.time() - profile.FirstJoin) < Config.NewPlayer.WindowSeconds
	if inWindow and not profile.LuckyStartGiven then
		local catchNo = profile.TotalCaught + 1
		local chances = Config.NewPlayer.ForceChanceByCatch
		local chance = chances[math.min(catchNo, #chances)]
		if math.random() < chance then
			-- pick a forced tier by weight
			local total = 0
			for _, t in ipairs(Config.NewPlayer.ForceTiers) do total += t.weight end
			local r = math.random() * total
			local tier = Config.NewPlayer.ForceTiers[1].tier
			for _, t in ipairs(Config.NewPlayer.ForceTiers) do
				r -= t.weight
				if r <= 0 then tier = t.tier break end
			end
			fish = Config.RollFishOfTier(tier)
			lucky = true
		end
	end
	if not fish then
		fish = Config.RollFish(Config.Stats.RodLuck(profile.Upgrades.Rod) + Monetization.LuckBonus(player))
		-- a natural Rare+ in the window also counts, so we don't stack a forced one on top
		if inWindow and not profile.LuckyStartGiven and fish.tier >= 3 then profile.LuckyStartGiven = true end
	end
	if lucky then
		profile.LuckyStartGiven = true
		task.delay(1.2, function()
			EconomyService.Notify(player, string.format("🍀 Beginner's luck! A %s %s earns %s coins/sec — that's %dx a Sardine. Upgrade your Rod for more like it.", fish.rarity, fish.name, tostring(fish.income), math.floor(fish.income / 0.5)), Color3.fromRGB(255, 220, 90))
		end)
	end
	profile.TotalCaught += 1
	local isNew = not profile.Discovered[fish.name]
	profile.Discovered[fish.name] = true
	local cap = EconomyService.Capacity(player, profile)
	if EconomyService.FishCount(profile) < cap then
		profile.Fish[fish.name] = (profile.Fish[fish.name] or 0) + 1
		IslandService.UpdateAquariumDisplay(player)
		Remotes.Caught:FireClient(player, { name = fish.name, rarity = fish.rarity, tier = fish.tier, income = fish.income, stored = true, isNew = isNew })
	else
		-- Tank full: sell instantly for 20 seconds' worth of income
		local coins = math.floor(fish.income * 20 * Config.Stats.IncomeMultiplier(profile.Upgrades.Aquarium))
		Monetization.Offer(player, "BigTank", "Your tank is full — every catch is being sold instead of earning forever.")
		profile.Coins += coins
		Remotes.Caught:FireClient(player, { name = fish.name, rarity = fish.rarity, tier = fish.tier, income = fish.income, stored = false, sold = coins, isNew = isNew })
	end
	EconomyService.PushStats(player)
end

local function startCast(player: Player)
	local profile = DataService.Get(player)
	if not profile then return end
	local s = state[player]
	if not s then s = { casting = false, biteAt = nil, castId = nil }; state[player] = s end
	if s.casting then return end
	s.casting = true
	s.biteAt = nil
	local minT, maxT = Config.Stats.BiteTime(profile.Upgrades.Rod)
	if (os.time() - profile.FirstJoin) < Config.NewPlayer.WindowSeconds then
		minT *= Config.NewPlayer.BiteTimeMult
		maxT *= Config.NewPlayer.BiteTimeMult
	end
	local wait = minT + math.random() * (maxT - minT)
	local castId = tick()
	s.castId = castId
	task.delay(wait, function()
		if state[player] ~= s or s.castId ~= castId or not s.casting then return end
		s.biteAt = os.clock()
		Remotes.Bite:FireClient(player, REEL_WINDOW)
		if Monetization.HasAutoFish(player) then
			task.delay(0.5, function() if s.castId == castId and s.casting then onReel(player) end end)
		end
		task.delay(REEL_WINDOW + 0.3, function()
			if s.castId == castId and s.casting and s.biteAt then
				s.casting = false
				s.biteAt = nil
				Remotes.Caught:FireClient(player, { missed = true })
			end
		end)
	end)
end

onReel = function(player: Player)
	local s = state[player]
	if not s or not s.casting then return end
	if s.biteAt and (os.clock() - s.biteAt) <= REEL_WINDOW + 0.25 then
		s.casting = false
		s.biteAt = nil
		finishCatch(player)
	else
		-- reeled too early: line snaps
		s.casting = false
		s.biteAt = nil
		Remotes.Caught:FireClient(player, { missed = true, early = true })
	end
end

function FishingService.Start()
	Remotes.Reel.OnServerEvent:Connect(onReel)
	for _, island in ipairs(IslandService.AllIslands()) do
		local spot = island:FindFirstChild("FishingSpot") :: Part
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Cast Line"
		prompt.ObjectText = "Fishing Spot"
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = spot
		prompt.Triggered:Connect(startCast)
	end
	local Players = game:GetService("Players")
	Players.PlayerRemoving:Connect(function(p) state[p] = nil end)
	-- Auto-Fisher pass: cast whenever you're standing near any fishing spot
	task.spawn(function()
		while true do
			task.wait(1.5)
			for _, player in ipairs(Players:GetPlayers()) do
				if Monetization.HasAutoFish(player) then
					local s = state[player]
					if not (s and s.casting) then
						local char = player.Character
						local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
						if hrp then
							for _, island in ipairs(IslandService.AllIslands()) do
								local spot = island:FindFirstChild("FishingSpot") :: BasePart?
								if spot and (spot.Position - hrp.Position).Magnitude <= 12 then
									startCast(player)
									break
								end
							end
						end
					end
				end
			end
		end
	end)
end

return FishingService
