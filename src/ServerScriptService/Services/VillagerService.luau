--!strict
-- VillagerService (ModuleScript) — ServerScriptService/Services/VillagerService
-- Fishers wander between shoreline fishing spots, cast, wait for a bite, catch, then move on.
-- Guards patrol waypoints around the castle, pause and look around, and charge anything hostile.
-- Both use real avatars with Roblox's walk/idle animations.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local Builders = require(ReplicatedStorage.Shared.Builders)
local NpcAnimator = require(ReplicatedStorage.Shared.NpcAnimator)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local IslandService = require(script.Parent.IslandService)
local EconomyService = require(script.Parent.EconomyService)
local CombatService = require(script.Parent.CombatService)
local Monetization = require(script.Parent.MonetizationService)

local VillagerService = {}
local folder: Folder
local rigs: { [Player]: { Fishers: { Model }, Guards: { Model } } } = {}

local function bubble(rig: Model, text: string, color: Color3)
	local head = rig:FindFirstChild("Head") :: BasePart?
	if not head then return end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(160, 26)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.MaxDistance = 60
	bb.Parent = head
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.3
	t.Text = text
	t.Parent = bb
	Debris:AddItem(bb, 2.2)
end

-- Walk to a point using pathfinding; returns true if we got close.
local function walkTo(hum: Humanoid, hrp: BasePart, goal: Vector3, timeout: number?): boolean
	local path = PathfindingService:CreatePath({ AgentRadius = 2.2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 5 })
	local ok = pcall(path.ComputeAsync, path, hrp.Position, goal)
	local deadline = os.clock() + (timeout or 20)
	if ok and path.Status == Enum.PathStatus.Success then
		for _, wp in ipairs(path:GetWaypoints()) do
			if not hum.Parent or hum.Health <= 0 then return false end
			if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
			hum:MoveTo(wp.Position)
			local reached = hum.MoveToFinished:Wait()
			if not reached or os.clock() > deadline then break end
		end
	else
		hum:MoveTo(goal)
		hum.MoveToFinished:Wait()
	end
	return (hrp.Position - goal).Magnitude < 6
end

local function face(hrp: BasePart, target: Vector3)
	local flat = Vector3.new(target.X, hrp.Position.Y, target.Z)
	if (flat - hrp.Position).Magnitude > 0.5 then
		hrp.CFrame = CFrame.lookAt(hrp.Position, flat)
	end
end

----------------------------------------------------------------------
-- Fisher behaviour
----------------------------------------------------------------------
local function splash(at: Vector3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(at)
	p.Parent = Workspace
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxassetid://6071575925"
	pe.Rate = 0
	pe.Lifetime = NumberRange.new(0.5, 0.8)
	pe.Speed = NumberRange.new(4, 7)
	pe.SpreadAngle = Vector2.new(40, 40)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.1) })
	pe.Color = ColorSequence.new(Color3.fromRGB(220, 250, 255))
	pe.Parent = p
	pe:Emit(14)
	Debris:AddItem(p, 1.2)
end

local function runFisher(player: Player, rig: Model, island: Model, startSpot: number)
	local hum = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	local hrp = rig.PrimaryPart :: BasePart
	local spotsFolder = island:FindFirstChild("FisherSpots")
	local spots = spotsFolder and spotsFolder:GetChildren() or {}
	local spotIdx = startSpot
	while rig.Parent and hum.Health > 0 and player.Parent do
		local profile = DataService.Get(player)
		if not profile or #spots == 0 then task.wait(2) continue end
		-- go to the next spot
		local spot = spots[((spotIdx - 1) % #spots) + 1] :: BasePart
		spotIdx += 1 + math.random(0, 2)
		walkTo(hum, hrp, spot.Position, 25)
		if not rig.Parent then break end
		face(hrp, spot.Position + spot.CFrame.LookVector * 10)
		-- fish here a few times
		local casts = 2 + math.random(0, 3)
		for _ = 1, casts do
			if not rig.Parent or hum.Health <= 0 then break end
			profile = DataService.Get(player)
			if not profile then break end
			-- cast: hop + splash out in the water
			hum.Jump = true
			local waterPoint = hrp.Position + hrp.CFrame.LookVector * 10 + Vector3.new(0, -hrp.Position.Y + Config.World.SeaLevelY, 0)
			task.delay(0.5, splash, waterPoint)
			task.wait(Config.Villagers.FisherInterval(profile.Villagers.FisherRod))
			if not rig.Parent then break end
			profile = DataService.Get(player)
			if not profile then break end
			local luck = Config.Villagers.FisherLuck(profile.Villagers.FisherRod) + Monetization.LuckBonus(player)
			local fish = Config.RollFish(luck)
			profile.TotalCaught += 1
			profile.Discovered[fish.name] = true
			splash(waterPoint)
			if EconomyService.FishCount(profile) < EconomyService.Capacity(player, profile) then
				profile.Fish[fish.name] = (profile.Fish[fish.name] or 0) + 1
				IslandService.UpdateAquariumDisplay(player)
				bubble(rig, "🎣 " .. fish.name, Config.RarityColors[fish.rarity] or Color3.new(1, 1, 1))
				if fish.tier >= 4 then
					EconomyService.Notify(player, string.format("Your Fisher caught a %s %s!", fish.rarity, fish.name), Config.RarityColors[fish.rarity])
				end
			else
				local coins = math.floor(fish.income * 20 * Config.Stats.IncomeMultiplier(profile.Upgrades.Aquarium))
				profile.Coins += coins
				bubble(rig, "🪙 +" .. coins, Color3.fromRGB(255, 220, 90))
			end
		end
	end
end

----------------------------------------------------------------------
-- Guard behaviour
----------------------------------------------------------------------
local function runGuard(player: Player, rig: Model, island: Model, waypoints: { Vector3 })
	local hum = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	local hrp = rig.PrimaryPart :: BasePart
	local lastAttack = 0
	local wpIdx = math.random(#waypoints)
	while rig.Parent and hum.Health > 0 and player.Parent do
		local profile = DataService.Get(player)
		if not profile then break end
		local dmg = Config.Villagers.GuardDamage(profile.Villagers.GuardWeapon)
		local castle = island:FindFirstChild("Castle") :: Model?
		local centre = castle and castle.PrimaryPart and (castle.PrimaryPart :: BasePart).Position or hrp.Position
		local targets = CombatService.HostileTargets(island, centre, Config.Villagers.GuardRange + 30)
		if #targets > 0 then
			-- fight: chase the nearest
			local nearest, nd = nil, math.huge
			for _, t in ipairs(targets) do
				local d = (t.Position - hrp.Position).Magnitude
				if d < nd then nearest, nd = t, d end
			end
			if nearest then
				hum.WalkSpeed = Config.Villagers.GuardWalkSpeed + 4
				if nd > 4.5 then
					hum:MoveTo(nearest.Position)
					task.wait(0.25)
				else
					hum:MoveTo(hrp.Position)
					face(hrp, nearest.Position)
					if os.clock() - lastAttack >= Config.Villagers.GuardAttackInterval then
						lastAttack = os.clock()
						local model = nearest.Parent :: Model
						local thum = model:FindFirstChildOfClass("Humanoid")
						if thum then
							thum:TakeDamage(dmg)
							if model:GetAttribute("IsPirate") then model:SetAttribute("LastHitBy", player.UserId) end
						end
						hum.Jump = true
					end
					task.wait(0.2)
				end
			end
		else
			-- patrol: walk to the next waypoint, pause, look around
			hum.WalkSpeed = Config.Villagers.GuardWalkSpeed
			local goal = waypoints[wpIdx]
			wpIdx = (wpIdx % #waypoints) + 1
			walkTo(hum, hrp, goal, 20)
			if not rig.Parent then break end
			local pauseT = 1.5 + math.random() * 3
			local t0 = os.clock()
			while os.clock() - t0 < pauseT do
				task.wait(0.6)
				if #CombatService.HostileTargets(island, centre, Config.Villagers.GuardRange + 30) > 0 then break end
			end
			face(hrp, hrp.Position + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5))
		end
	end
end

----------------------------------------------------------------------
-- Spawning
----------------------------------------------------------------------
local function clear(player: Player)
	local r = rigs[player]
	if not r then return end
	for _, m in ipairs(r.Fishers) do m:Destroy() end
	for _, m in ipairs(r.Guards) do m:Destroy() end
	rigs[player] = nil
end

function VillagerService.Rebuild(player: Player)
	clear(player)
	local profile = DataService.Get(player)
	local island = IslandService.GetIsland(player)
	if not profile or not island then return end
	local root = island.PrimaryPart :: BasePart
	local facing = root.CFrame
	local R = Config.World.IslandRadius
	local y = Config.World.SeaLevelY
	local r = { Fishers = {}, Guards = {} }
	rigs[player] = r

	local spotsFolder = island:FindFirstChild("FisherSpots")
	local spots = spotsFolder and spotsFolder:GetChildren() or {}
	for i = 1, profile.Villagers.Fishers do
		local rig = Builders.BuildVillager("Fisher", 100, profile.Villagers.FisherRod)
		local spot = (#spots > 0) and (spots[((i - 1) % #spots) + 1] :: BasePart) or nil
		local pos = spot and spot.Position + Vector3.new(0, 4, 0) or (facing * CFrame.new((i % 2 == 0 and 1 or -1) * (8 + i * 2), y + 5, -(R - 10))).Position
		rig:PivotTo(CFrame.new(pos))
		rig:SetAttribute("Island", island.Name)
		rig.Parent = folder
		NpcAnimator.Attach(rig)
		table.insert(r.Fishers, rig)
		task.spawn(runFisher, player, rig, island, i)
	end

	-- guard waypoints: a loop around the outside of the castle plus the gate and the beach
	local castleCentre = (facing * CFrame.new(0, y + 3, 16)).Position
	local waypoints = {}
	for k = 1, 8 do
		local ang = (k / 8) * math.pi * 2
		table.insert(waypoints, castleCentre + Vector3.new(math.cos(ang) * 36, 1, math.sin(ang) * 36))
	end
	table.insert(waypoints, (facing * CFrame.new(0, y + 4, -20)).Position)
	table.insert(waypoints, (facing * CFrame.new(0, y + 4, -(R - 14))).Position)
	for i = 1, profile.Villagers.Guards do
		local hp = Config.Villagers.GuardHP(profile.Villagers.GuardWeapon)
		local rig = Builders.BuildVillager("Guard", hp, profile.Villagers.GuardWeapon)
		local start = waypoints[((i - 1) % #waypoints) + 1]
		rig:PivotTo(CFrame.new(start + Vector3.new(0, 4, 0)))
		rig:SetAttribute("Island", island.Name)
		rig.Parent = folder
		NpcAnimator.Attach(rig)
		table.insert(r.Guards, rig)
		local hum = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
		hum.WalkSpeed = Config.Villagers.GuardWalkSpeed
		hum.Died:Connect(function()
			bubble(rig, "💀 Fallen — back at dawn", Color3.fromRGB(255, 120, 120))
			Debris:AddItem(rig, 3)
		end)
		-- rotate the starting waypoint so guards spread out
		local wps = table.clone(waypoints)
		for _ = 1, (i - 1) % #wps do table.insert(wps, table.remove(wps, 1)) end
		task.spawn(runGuard, player, rig, island, wps)
	end
end

----------------------------------------------------------------------
-- Buying
----------------------------------------------------------------------
local function onCrew(player: Player, action: string)
	local profile = DataService.Get(player)
	if not profile then return end
	local v = profile.Villagers
	local cost, label
	if action == "HireFisher" then
		if v.Fishers >= Config.Villagers.MaxPerType then EconomyService.Notify(player, "Your beach is full of fishers!", Color3.fromRGB(255, 180, 90)) return end
		cost = Config.Villagers.HireCost("Fisher", v.Fishers); label = "Fisher hired!"
	elseif action == "HireGuard" then
		if v.Guards >= Config.Villagers.MaxPerType then EconomyService.Notify(player, "Your castle is full of guards!", Color3.fromRGB(255, 180, 90)) return end
		cost = Config.Villagers.HireCost("Guard", v.Guards); label = "Guard hired!"
	elseif action == "UpgradeRods" then
		cost = Config.Villagers.GearCost("FisherRod", v.FisherRod); label = "Fishers' rods upgraded!"
	elseif action == "UpgradeWeapons" then
		cost = Config.Villagers.GearCost("GuardWeapon", v.GuardWeapon); label = "Guards' weapons upgraded!"
	else
		return
	end
	if profile.Coins < cost then
		EconomyService.Notify(player, "Not enough coins!", Color3.fromRGB(255, 90, 90))
		return
	end
	profile.Coins -= cost
	if action == "HireFisher" then v.Fishers += 1
	elseif action == "HireGuard" then v.Guards += 1
	elseif action == "UpgradeRods" then v.FisherRod += 1
	elseif action == "UpgradeWeapons" then v.GuardWeapon += 1 end
	EconomyService.Notify(player, label, Color3.fromRGB(120, 255, 140))
	VillagerService.Rebuild(player)
	EconomyService.PushStats(player)
end

function VillagerService.CrewStats(profile: DataService.Profile)
	local v = profile.Villagers
	return {
		Fishers = v.Fishers, Guards = v.Guards, FisherRod = v.FisherRod, GuardWeapon = v.GuardWeapon,
		HireFisherCost = Config.Villagers.HireCost("Fisher", v.Fishers),
		HireGuardCost = Config.Villagers.HireCost("Guard", v.Guards),
		RodCost = Config.Villagers.GearCost("FisherRod", v.FisherRod),
		WeaponCost = Config.Villagers.GearCost("GuardWeapon", v.GuardWeapon),
		FisherInterval = Config.Villagers.FisherInterval(v.FisherRod),
		GuardDamage = Config.Villagers.GuardDamage(v.GuardWeapon),
		GuardHP = Config.Villagers.GuardHP(v.GuardWeapon),
		MaxPerType = Config.Villagers.MaxPerType,
	}
end

function VillagerService.Start()
	folder = Instance.new("Folder")
	folder.Name = "Villagers"
	folder.Parent = Workspace
	Remotes.Crew.OnServerEvent:Connect(onCrew)
	Players.PlayerRemoving:Connect(clear)
end

return VillagerService
