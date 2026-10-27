--!strict
-- FleetService (ModuleScript) — ServerScriptService/Services/FleetService
-- AI boats crewed by your fishers. Each boat is a copy of your current ship (same tier, cannons, speed).
--  Day:   sail to a fishing ground, drop anchor, the crew fish (catches go to your aquarium), move on.
--  Night: if another player's island is raidable, sail there, circle at standoff range and fire broadsides
--         at the castle (counts as a raid: break it and you get the loot). Otherwise patrol home and shoot pirates.
-- Boats are kinematic (anchored, moved by the server) so they can't be shoved or flipped.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
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

local FleetService = {}

type Boat = {
	owner: Player,
	index: number,
	ship: Model,
	hull: BasePart,
	crew: { { rig: Model, offset: CFrame } },
	pos: Vector3,
	yaw: number,
	speed: number,
	maxSpeed: number,
	goal: Vector3?,
	state: string, -- "sailing" | "fishing" | "raiding" | "patrol" | "dead"
	stateUntil: number,
	lastShot: number,
	raidIsland: Model?,
	homeIsland: Model,
	level: number,
	deadAt: number?,
	nextCatch: number,
}

local boats: { [Player]: { Boat } } = {}
local shipsFolder: Folder

local SEA_Y = Config.World.SeaLevelY

----------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------
local function islandCentre(island: Model): Vector3
	return (island.PrimaryPart :: BasePart).Position
end

local function randomFishingGround(home: Model): Vector3
	local c = islandCentre(home)
	for _ = 1, 12 do
		local ang = math.random() * math.pi * 2
		local d = Config.Fleet.FishMinDist + math.random() * (Config.Fleet.FishMaxDist - Config.Fleet.FishMinDist)
		local p = Vector3.new(c.X + math.cos(ang) * d, SEA_Y, c.Z + math.sin(ang) * d)
		local ok = p.Magnitude < Config.World.BorderRadius - 60
		if ok then
			for _, isl in ipairs(IslandService.AllIslands()) do
				if (islandCentre(isl) - p).Magnitude < Config.World.IslandRadius * 1.9 then ok = false break end
			end
		end
		if ok then return p end
	end
	return c + Vector3.new(0, 0, Config.Fleet.FishMinDist)
end

-- steer around islands: repulsion from any island whose shore we're about to cross
local function steerDir(from: Vector3, goal: Vector3, ignore: Model?): Vector3
	local to = Vector3.new(goal.X - from.X, 0, goal.Z - from.Z)
	if to.Magnitude < 1 then return Vector3.new(0, 0, 1) end
	local dir = to.Unit
	for _, isl in ipairs(IslandService.AllIslands()) do
		if isl ~= ignore then
			local c = islandCentre(isl)
			local off = Vector3.new(from.X - c.X, 0, from.Z - c.Z)
			local safe = Config.World.IslandRadius * 1.75
			local d = off.Magnitude
			if d < safe + 60 and dir:Dot(-off.Unit) > 0 then
				dir = (dir + off.Unit * ((safe + 60 - d) / 60) * 1.5).Unit
			end
		end
	end
	return dir
end

local function raidableIsland(owner: Player): Model?
	local candidates = {}
	for _, isl in ipairs(IslandService.AllIslands()) do
		local id = isl:GetAttribute("OwnerId")
		if id ~= 0 and id ~= owner.UserId then
			local shield = isl:GetAttribute("RaidShieldUntil") or 0
			local castle = isl:FindFirstChild("Castle")
			if os.time() >= shield and castle and (castle:GetAttribute("HP") :: number) > 0 then
				table.insert(candidates, isl)
			end
		end
	end
	if #candidates == 0 then return nil end
	return candidates[math.random(#candidates)]
end

local function bubble(rig: Model, text: string, color: Color3)
	local head = rig:FindFirstChild("Head") :: BasePart?
	if not head then return end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(150, 24)
	bb.StudsOffset = Vector3.new(0, 2.4, 0)
	bb.MaxDistance = 80
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
	Debris:AddItem(bb, 2)
end

----------------------------------------------------------------------
-- spawning
----------------------------------------------------------------------
local function placeBoat(b: Boat, cf: CFrame)
	b.ship:PivotTo(cf)
	for _, c in ipairs(b.crew) do
		if c.rig.Parent then c.rig:PivotTo(cf * c.offset) end
	end
end

local function spawnBoat(owner: Player, index: number, home: Model, level: number): Boat?
	local profile = DataService.Get(owner)
	if not profile then return nil end
	local ship = Builders.BuildShip(level, owner.DisplayName .. " #" .. index, Monetization.ExtraCannons(owner), Monetization.OwnsPass(owner, "Admiral"))
	ship.Name = "Ship_AI_" .. owner.UserId .. "_" .. index
	ship:SetAttribute("OwnerId", owner.UserId)
	ship:SetAttribute("AI", true)
	ship:SetAttribute("Speed", Config.Stats.ShipSpeed(level) * Monetization.SpeedMult(owner) * 0.8)
	for _, d in ipairs(ship:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true end
		if d:IsA("ProximityPrompt") or d:IsA("LinearVelocity") or d:IsA("AngularVelocity") or d:IsA("AlignOrientation") then d:Destroy() end
	end
	local hull = ship.PrimaryPart :: BasePart
	-- start a little way off the dock, spread so boats don't overlap
	local dockEnd = home:FindFirstChild("DockEnd") :: BasePart
	local startCF = dockEnd.CFrame * CFrame.new(-18 - (index - 1) * 16, SEA_Y - dockEnd.Position.Y + 0.4, -20)
	local b: Boat = {
		owner = owner, index = index, ship = ship, hull = hull, crew = {},
		pos = startCF.Position, yaw = math.atan2(-startCF.LookVector.X, -startCF.LookVector.Z),
		speed = 0, maxSpeed = ship:GetAttribute("Speed") :: number,
		goal = nil, state = "sailing", stateUntil = 0, lastShot = 0, raidIsland = nil, homeIsland = home, level = level, deadAt = nil, nextCatch = 0,
	}
	ship.Parent = shipsFolder
	-- crew on deck
	local deck = ship:FindFirstChild("Deck") :: BasePart? or hull
	local length = hull.Size.Z
	for k = 1, Config.Villagers.BoatCrew do
		local rig = Builders.BuildVillager("Fisher", 100, profile.Villagers.FisherRod)
		for _, d in ipairs(rig:GetDescendants()) do
			if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false end
		end
		local hum = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
		hum.PlatformStand = true
		local sx = (k % 2 == 0) and 1 or -1
		local z = -length * 0.35 + (k - 1) * (length * 0.7 / math.max(Config.Villagers.BoatCrew - 1, 1))
		local offset = CFrame.new(sx * (hull.Size.X / 2 - 1.6), deck.Position.Y - hull.Position.Y + 3.2, z) * CFrame.Angles(0, sx * math.rad(90), 0)
		rig:SetAttribute("Island", home.Name)
		rig:SetAttribute("OnBoat", true)
		rig.Parent = ship
		NpcAnimator.Attach(rig)
		table.insert(b.crew, { rig = rig, offset = offset })
	end
	placeBoat(b, CFrame.new(b.pos) * CFrame.Angles(0, b.yaw, 0))
	return b
end

function FleetService.Clear(player: Player)
	local list = boats[player]
	if not list then return end
	for _, b in ipairs(list) do if b.ship.Parent then b.ship:Destroy() end end
	boats[player] = nil
end

function FleetService.Rebuild(player: Player, count: number)
	FleetService.Clear(player)
	local profile = DataService.Get(player)
	local home = IslandService.GetIsland(player)
	if not profile or not home or count <= 0 then return end
	local list = {}
	for i = 1, count do
		local b = spawnBoat(player, i, home, profile.Upgrades.Ship)
		if b then table.insert(list, b) end
	end
	boats[player] = list
end

----------------------------------------------------------------------
-- behaviour
----------------------------------------------------------------------
local function fireAt(b: Boat, target: Vector3, aiRaid: string?)
	if os.clock() - b.lastShot < Config.Fleet.CannonInterval then return end
	b.lastShot = os.clock()
	local cannons = b.ship:FindFirstChild("Cannons")
	if not cannons then return end
	local toT = target - b.hull.Position
	local side = (toT:Dot(b.hull.CFrame.RightVector) >= 0) and 1 or -1
	local dist = toT.Magnitude
	local dir = (Vector3.new(toT.X, 0, toT.Z).Unit + Vector3.new(0, math.clamp(dist / 400, 0.05, 0.35), 0)).Unit
	local dmg = Config.Fleet.Damage(b.level)
	for _, c in ipairs(cannons:GetChildren()) do
		if c:IsA("BasePart") and c:GetAttribute("Side") == side then
			local spread = CFrame.Angles(0, (math.random() - 0.5) * 0.1, 0)
			local d = (spread * CFrame.new(Vector3.zero, dir)).LookVector
			CombatService.FireCannonball(CFrame.new(c.Position + d * 2.5), d, 110, dmg, b.owner, { b.ship :: Instance }, aiRaid)
		end
	end
end

local function crewFish(b: Boat)
	local profile = DataService.Get(b.owner)
	if not profile then return end
	local luck = Config.Villagers.FisherLuck(profile.Villagers.FisherRod) + Monetization.LuckBonus(b.owner)
	local fish = Config.RollFish(luck)
	profile.TotalCaught += 1
	profile.Discovered[fish.name] = true
	local rig = b.crew[math.random(#b.crew)].rig
	if EconomyService.FishCount(profile) < EconomyService.Capacity(b.owner, profile) then
		profile.Fish[fish.name] = (profile.Fish[fish.name] or 0) + 1
		IslandService.UpdateAquariumDisplay(b.owner)
		bubble(rig, "🎣 " .. fish.name, Config.RarityColors[fish.rarity] or Color3.new(1, 1, 1))
		if fish.tier >= 5 then
			EconomyService.Notify(b.owner, string.format("Boat #%d hauled in a %s %s!", b.index, fish.rarity, fish.name), Config.RarityColors[fish.rarity])
		end
	else
		local coins = math.floor(fish.income * 20 * Config.Stats.IncomeMultiplier(profile.Upgrades.Aquarium))
		profile.Coins += coins
		bubble(rig, "🪙 +" .. coins, Color3.fromRGB(255, 220, 90))
	end
end

local function think(b: Boat, now: number)
	local night = DayNightService.IsNight
	local profile = DataService.Get(b.owner)
	if not profile then return end

	if night then
		if b.state ~= "raiding" and b.state ~= "patrol" then
			local target = raidableIsland(b.owner)
			if target then
				b.raidIsland = target
				b.state = "raiding"
				b.ship:SetAttribute("AIRaidTarget", target.Name)
				local victim = IslandService.GetOwner(target)
				if victim and b.index == 1 then EconomyService.Notify(victim, "⚠️ " .. b.owner.DisplayName .. "'s fleet is sailing to raid you!", Color3.fromRGB(255, 80, 80)) end
			else
				b.state = "patrol"
			end
		end
		if b.state == "raiding" then
			local isl = b.raidIsland
			local castle = isl and isl:FindFirstChild("Castle")
			local keep = castle and castle.PrimaryPart
			local shieldUp = isl and (isl:GetAttribute("RaidShieldUntil") or 0) > os.time()
			if not keep or (castle :: Model):GetAttribute("HP") <= 0 or shieldUp or isl:GetAttribute("OwnerId") == 0 then
				b.state = "patrol"
				b.raidIsland = nil
				b.ship:SetAttribute("AIRaidTarget", nil)
				return
			end
			-- circle the island at standoff range, broadside the keep
			local c = islandCentre(isl :: Model)
			local ring = Config.World.IslandRadius * 1.9 + 10
			local ang = math.atan2(b.pos.Z - c.Z, b.pos.X - c.X) + 0.35
			b.goal = Vector3.new(c.X + math.cos(ang) * ring, SEA_Y, c.Z + math.sin(ang) * ring)
			if ((keep :: BasePart).Position - b.pos).Magnitude < Config.World.IslandRadius * 2.6 then
				fireAt(b, (keep :: BasePart).Position + Vector3.new(0, 4, 0), (isl :: Model).Name)
			end
		else
			-- patrol home at night: orbit, shoot pirates on the beach
			local c = islandCentre(b.homeIsland)
			local ring = Config.World.IslandRadius * 1.6
			local ang = math.atan2(b.pos.Z - c.Z, b.pos.X - c.X) + 0.3
			b.goal = Vector3.new(c.X + math.cos(ang) * ring, SEA_Y, c.Z + math.sin(ang) * ring)
			local targets = CombatService.HostileTargets(b.homeIsland, b.pos, 140)
			if #targets > 0 then fireAt(b, targets[1].Position + Vector3.new(0, 2, 0), nil) end
		end
		return
	end

	-- daytime: fish
	if b.ship:GetAttribute("AIRaidTarget") then b.ship:SetAttribute("AIRaidTarget", nil) end
	if b.state == "raiding" or b.state == "patrol" then b.state = "sailing"; b.goal = nil end
	if b.state == "sailing" then
		if not b.goal then b.goal = randomFishingGround(b.homeIsland) end
		if (Vector3.new(b.goal.X - b.pos.X, 0, b.goal.Z - b.pos.Z)).Magnitude < 12 then
			b.state = "fishing"
			b.stateUntil = now + 40 + math.random() * 40
			b.goal = nil
		end
	elseif b.state == "fishing" then
		if now >= b.stateUntil then
			b.state = "sailing"
			b.goal = randomFishingGround(b.homeIsland)
		else
			-- the whole crew fishes: one catch per fisher-interval divided by crew size
			local interval = Config.Villagers.FisherInterval(profile.Villagers.FisherRod) / #b.crew
			if now >= b.nextCatch then
				b.nextCatch = now + interval
				crewFish(b)
			end
		end
	end
end

local function move(b: Boat, dt: number)
	local turnRate = 0.9
	local targetSpeed = 0
	if b.goal then
		local dir = steerDir(b.pos, b.goal, b.raidIsland)
		local wantYaw = math.atan2(-dir.X, -dir.Z)
		local diff = (wantYaw - b.yaw + math.pi) % (2 * math.pi) - math.pi
		b.yaw += math.clamp(diff, -turnRate * dt, turnRate * dt)
		local dist = Vector3.new(b.goal.X - b.pos.X, 0, b.goal.Z - b.pos.Z).Magnitude
		targetSpeed = (dist < 25) and b.maxSpeed * 0.4 or b.maxSpeed
		if math.abs(diff) > 1.2 then targetSpeed *= 0.5 end
	end
	b.speed += (targetSpeed - b.speed) * math.min(1, dt * 0.8)
	local forward = Vector3.new(-math.sin(b.yaw), 0, -math.cos(b.yaw))
	b.pos += forward * b.speed * dt
	local bob = math.sin(os.clock() * 1.3 + b.index) * 0.25
	local roll = math.sin(os.clock() * 0.9 + b.index) * 0.03
	local cf = CFrame.new(b.pos.X, SEA_Y + 0.6 + bob, b.pos.Z) * CFrame.Angles(0, b.yaw, roll)
	placeBoat(b, cf)
end

----------------------------------------------------------------------
-- main loop
----------------------------------------------------------------------
function FleetService.Start()
	shipsFolder = Workspace:FindFirstChild("Ships") :: Folder
	if not shipsFolder then
		shipsFolder = Instance.new("Folder")
		shipsFolder.Name = "Ships"
		shipsFolder.Parent = Workspace
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		local doThink = acc >= 0.5
		if doThink then acc = 0 end
		local now = os.clock()
		for owner, list in pairs(boats) do
			for i, b in ipairs(list) do
				if b.state == "dead" then
					if b.deadAt and now - b.deadAt > Config.Fleet.RespawnSeconds then
						local profile = DataService.Get(owner)
						local nb = profile and spawnBoat(owner, b.index, b.homeIsland, profile.Upgrades.Ship)
						if nb then list[i] = nb end
					end
					continue
				end
				if not b.ship.Parent or (b.ship:GetAttribute("HP") :: number) <= 0 then
					b.state = "dead"
					b.deadAt = now
					b.ship:SetAttribute("AIRaidTarget", nil)
					EconomyService.Notify(owner, string.format("Boat #%d was sunk! A new one launches in %ds.", b.index, Config.Fleet.RespawnSeconds), Color3.fromRGB(255, 120, 120))
					continue
				end
				if doThink then think(b, now) end
				move(b, dt)
			end
		end
	end)
end

return FleetService
