--!strict
-- PirateService (ModuleScript) — ServerScriptService/Services/PirateService
-- At night, every owned island gets a wave of pirates that wade ashore and hack at the castle.
-- Kill them for bounty. If the castle falls, the owner loses a cut of their coins.

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local Builders = require(ReplicatedStorage.Shared.Builders)
local NpcAnimator = require(ReplicatedStorage.Shared.NpcAnimator)
local DataService = require(script.Parent.DataService)
local IslandService = require(script.Parent.IslandService)
local EconomyService = require(script.Parent.EconomyService)
local CombatService = require(script.Parent.CombatService)
local DayNightService = require(script.Parent.DayNightService)
local Monetization = require(script.Parent.MonetizationService)

local PirateService = {}

local function moveAlongPath(hum: Humanoid, hrp: BasePart, goal: Vector3): boolean
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 4 })
	local ok = pcall(path.ComputeAsync, path, hrp.Position, goal)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		hum:MoveTo(goal)
		task.wait(0.6)
		return false
	end
	for _, wp in ipairs(path:GetWaypoints()) do
		if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
		hum:MoveTo(wp.Position)
		local reached = hum.MoveToFinished:Wait()
		if not reached or not hum.Parent then return false end
		if (hrp.Position - goal).Magnitude < 5 then return true end
	end
	return true
end

local function runPirate(pirate: Model, island: Model, castleLevel: number)
	local hum = pirate:FindFirstChildOfClass("Humanoid") :: Humanoid
	local hrp = pirate.PrimaryPart :: BasePart
	local damage = Config.Pirates.Damage(castleLevel)
	local lastAttack = 0
	while pirate.Parent and hum.Health > 0 and DayNightService.IsNight do
		local castle = island:FindFirstChild("Castle") :: Model?
		if not castle or not castle.PrimaryPart or (castle:GetAttribute("HP") :: number) <= 0 then break end
		-- a guard in reach? fight it first
		local guardTarget: Humanoid? = nil
		local vf = workspace:FindFirstChild("Villagers")
		if vf then
			for _, v in ipairs(vf:GetChildren()) do
				if v:GetAttribute("Kind") == "Guard" and v:GetAttribute("Island") == island.Name then
					local vh = v:FindFirstChildOfClass("Humanoid")
					local vr = v.PrimaryPart
					if vh and vr and vh.Health > 0 and (vr.Position - hrp.Position).Magnitude <= 7 then
						guardTarget = vh
						break
					end
				end
			end
		end
		if guardTarget then
			hum:MoveTo(hrp.Position)
			if os.clock() - lastAttack >= Config.Pirates.AttackInterval then
				lastAttack = os.clock()
				guardTarget:TakeDamage(damage)
				hum.Jump = true
			end
			task.wait(0.2)
			continue
		end
		local keepTarget = castle:FindFirstChild("KeepTarget") :: BasePart?
		local gateTarget = castle:FindFirstChild("GateTarget") :: BasePart?
		local goal = keepTarget and keepTarget.Position or (castle.PrimaryPart :: BasePart).Position
		local dist = (hrp.Position - goal).Magnitude
		if dist > 5 then
			-- go to the gate first if we're still outside the walls
			local viaGate = gateTarget and (hrp.Position - gateTarget.Position).Magnitude > 6 and (hrp.Position - goal).Magnitude > 20
			moveAlongPath(hum, hrp, viaGate and (gateTarget :: BasePart).Position or goal)
		else
			hum:MoveTo(hrp.Position)
			if os.clock() - lastAttack >= Config.Pirates.AttackInterval then
				lastAttack = os.clock()
				CombatService.DamageCastle(island, damage, nil)
				hum.Jump = true
			end
			task.wait(0.2)
		end
	end
	if pirate.Parent then
		for _, p in ipairs(pirate:GetDescendants()) do
			if p:IsA("BasePart") then p.CanCollide = false end
		end
		Debris:AddItem(pirate, 3)
	end
end

local function spawnWave(island: Model)
	local owner = IslandService.GetOwner(island)
	local castle = island:FindFirstChild("Castle") :: Model?
	if not owner or not castle then return end
	if Monetization.ConsumePirateSkip(owner) then
		EconomyService.Notify(owner, "🌙 Calm seas tonight — the pirates sailed past your island.", Color3.fromRGB(120, 220, 255))
		Monetization.PushStoreInfo(owner)
		return
	end
	local level = castle:GetAttribute("Level") :: number
	local count = Config.Pirates.WaveSize(level)
	local hp = Config.Pirates.HP(level)
	local root = island.PrimaryPart :: Part
	EconomyService.Notify(owner, string.format("%d pirates are raiding your island!", count), Color3.fromRGB(255, 120, 60))
	for i = 1, count do
		task.delay(i * 0.8, function()
			if not DayNightService.IsNight then return end
			local pirate = Builders.BuildPirate(hp)
			pirate:SetAttribute("TargetIsland", island.Name)
			-- spawn on the beach at a random angle, just inside the sand edge
			local ang = math.random() * math.pi * 2
			local R = Config.World.IslandRadius * 1.22
			local pos = root.Position + Vector3.new(math.cos(ang) * R, 5, math.sin(ang) * R)
			pirate:PivotTo(CFrame.new(pos))
			pirate.Parent = CombatService.PiratesFolder()
			NpcAnimator.Attach(pirate)
			local hum = pirate:FindFirstChildOfClass("Humanoid") :: Humanoid
			hum.Died:Connect(function()
				local killerId = pirate:GetAttribute("LastHitBy")
				local killer = killerId and Players:GetPlayerByUserId(killerId)
				local bounty = Config.Pirates.Bounty(level)
				if killer then
					local profile = DataService.Get(killer)
					if profile then
						profile.Coins += bounty
						profile.PiratesSlain += 1
					end
					EconomyService.Notify(killer, string.format("+%d coins bounty!", bounty), Color3.fromRGB(255, 220, 90))
				end
				-- coin burst
				local hrp = pirate.PrimaryPart
				if hrp then
					for _ = 1, 4 do
						local coin = Instance.new("Part")
						coin.Shape = Enum.PartType.Cylinder
						coin.Size = Vector3.new(0.2, 1, 1)
						coin.Color = Color3.fromRGB(255, 210, 50)
						coin.Material = Enum.Material.Neon
						coin.CFrame = hrp.CFrame * CFrame.new(math.random(-1, 1), 2, math.random(-1, 1))
						coin.AssemblyLinearVelocity = Vector3.new(math.random(-10, 10), 25, math.random(-10, 10))
						coin.Parent = workspace
						Debris:AddItem(coin, 1.5)
					end
				end
				Debris:AddItem(pirate, 2)
			end)
			task.spawn(runPirate, pirate, island, level)
		end)
	end
end

function PirateService.Start()
	DayNightService.NightStarted.Event:Connect(function()
		for _, island in ipairs(IslandService.AllIslands()) do
			if island:GetAttribute("OwnerId") ~= 0 then
				task.delay(math.random() * 10, spawnWave, island)
			end
		end
	end)
	DayNightService.DayStarted.Event:Connect(function()
		for _, island in ipairs(IslandService.AllIslands()) do
			CombatService.HealCastle(island)
		end
	end)
	CombatService.CastleDestroyed.Event:Connect(function(island: Model, attacker: Player?)
		if attacker ~= nil then return end -- player raids are handled by RaidService
		local owner = IslandService.GetOwner(island)
		if not owner then return end
		local profile = DataService.Get(owner)
		if not profile then return end
		local lost = math.floor(profile.Coins * Config.Economy.PirateLossFraction * Monetization.LossMult(owner))
		profile.Coins -= lost
		Monetization.Offer(owner, "NoPirates", string.format("You just lost %d coins to pirates. Sleep easy for 3 nights?", lost))
		EconomyService.Notify(owner, string.format("Pirates breached your castle and stole %d coins! Upgrade your walls.", lost), Color3.fromRGB(255, 80, 80))
		EconomyService.PushStats(owner)
	end)
end

return PirateService
