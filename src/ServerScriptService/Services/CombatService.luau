--!strict
-- CombatService (ModuleScript) — ServerScriptService/Services/CombatService
-- Castle HP + HP bars, castle cannons (auto-target pirates and enemy players), the Cutlass tool, cannonballs.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local Builders = require(ReplicatedStorage.Shared.Builders)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local IslandService = require(script.Parent.IslandService)
local EconomyService = require(script.Parent.EconomyService)

local CombatService = {}
CombatService.CastleDestroyed = Instance.new("BindableEvent") -- (island: Model, attacker: Player?)

local projectilesFolder: Folder
local piratesFolder: Folder

function CombatService.PiratesFolder(): Folder
	return piratesFolder
end

local function refreshBar(castle: Model)
	local keep = castle.PrimaryPart :: Part
	local bar = keep:FindFirstChild("HPBar")
	if not bar then return end
	local hp, maxHP = castle:GetAttribute("HP") :: number, castle:GetAttribute("MaxHP") :: number
	local bg = bar:FindFirstChild("BG") :: Frame
	local fill = bg:FindFirstChild("Fill") :: Frame
	local frac = math.clamp(hp / maxHP, 0, 1)
	fill.Size = UDim2.fromScale(frac, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 230, 110):Lerp(Color3.fromRGB(255, 70, 70), 1 - frac);
	(bg:FindFirstChild("Text") :: TextLabel).Text = string.format("Castle Lv %d  %d/%d", castle:GetAttribute("Level"), math.floor(hp), maxHP)
end

function CombatService.DamageCastle(island: Model, amount: number, attacker: Player?)
	local castle = island:FindFirstChild("Castle") :: Model?
	if not castle then return end
	local hp = castle:GetAttribute("HP") :: number
	if hp <= 0 then return end
	hp = math.max(0, hp - amount)
	castle:SetAttribute("HP", hp)
	refreshBar(castle)
	if hp <= 0 then
		CombatService.CastleDestroyed:Fire(island, attacker)
		-- Rubble effect: darken walls briefly, then restore
		for _, p in ipairs(castle:GetDescendants()) do
			if p:IsA("BasePart") and (p.Name == "Wall" or p.Name == "Tower" or p.Name == "CastleRoot") then
				p.Color = Color3.fromRGB(90, 85, 90)
			end
		end
		task.delay(8, function()
			if castle.Parent then
				CombatService.HealCastle(island)
				local owner = IslandService.GetOwner(island)
				if owner then IslandService.RebuildCastle(owner) else Builders.BuildCastle(island, 0) end
			end
		end)
	end
end

function CombatService.HealCastle(island: Model)
	local castle = island:FindFirstChild("Castle") :: Model?
	if not castle then return end
	castle:SetAttribute("HP", castle:GetAttribute("MaxHP"))
	refreshBar(castle)
end

-- Anything hostile to `island`: pirates, and players who don't own it
function CombatService.HostileTargets(island: Model, from: Vector3, range: number): { BasePart }
	local out = {}
	for _, pirate in ipairs(piratesFolder:GetChildren()) do
		local hrp = pirate:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = pirate:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 and pirate:GetAttribute("TargetIsland") == island.Name and (hrp.Position - from).Magnitude <= range then
			table.insert(out, hrp)
		end
	end
	local ownerId = island:GetAttribute("OwnerId")
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.UserId ~= ownerId and pl.Character then
			local hrp = pl.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local hum = pl.Character:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.Health > 0 and (hrp.Position - from).Magnitude <= range and pl.Character:GetAttribute("Raiding") == island.Name then
				table.insert(out, hrp)
			end
		end
	end
	return out
end

-- Fires a physical cannonball. onHit(hitPart) decides what takes damage.
-- Raycast-stepped projectile: never tunnels, always registers a hit.
function CombatService.FireCannonball(origin: CFrame, direction: Vector3, speed: number, damage: number, source: Player?, hitFilter: { Instance })
	local ball = Builders.BuildCannonball(origin)
	ball.Anchored = true
	ball.Parent = projectilesFolder
	local flash = Instance.new("PointLight")
	flash.Brightness = 6
	flash.Range = 14
	flash.Color = Color3.fromRGB(255, 200, 100)
	flash.Parent = ball
	Debris:AddItem(flash, 0.15)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { projectilesFolder :: Instance }
	for _, f in ipairs(hitFilter) do if f then table.insert(ignore, f) end end
	params.FilterDescendantsInstances = ignore

	local pos = origin.Position
	local vel = direction.Unit * speed + Vector3.new(0, speed * 0.12, 0)
	local gravity = Vector3.new(0, -60, 0)
	local life = 0

	local function impact(at: Vector3, hit: BasePart?)
		local e = Instance.new("Explosion")
		e.BlastPressure = 0
		e.BlastRadius = 0
		e.Position = at
		e.Parent = Workspace
		if hit then
			local model = hit:FindFirstAncestorOfClass("Model")
			-- climb to the top-level model for ships/castles (parts may be nested in folders)
			local top = model
			while top and top.Parent and top.Parent:IsA("Model") do top = top.Parent :: Model end
			if model then
				local hum = model:FindFirstChildOfClass("Humanoid") or (top and top:FindFirstChildOfClass("Humanoid"))
				local castle = hit:FindFirstAncestor("Castle")
				local ship = nil
				local anc = hit.Parent
				while anc do
					if anc:IsA("Model") and anc.Name:sub(1, 5) == "Ship_" then ship = anc break end
					anc = anc.Parent
				end
				if hum then
					hum:TakeDamage(damage)
					local hm = hum.Parent :: Model
					if source and hm:GetAttribute("IsPirate") then hm:SetAttribute("LastHitBy", source.UserId) end
				elseif castle then
					local island = castle.Parent :: Model
					if source == nil then
						CombatService.DamageCastle(island, damage, nil)
					elseif IslandService.GetOwner(island) ~= source then
						local raiding = source.Character and source.Character:GetAttribute("Raiding") == island.Name
						if raiding then
							CombatService.DamageCastle(island, damage, source)
						else
							Remotes.Notify:FireClient(source, "Castles can only be raided at night, within range of the walls.", Color3.fromRGB(255, 180, 90))
						end
					end
				elseif ship then
					if not (source and ship:GetAttribute("OwnerId") == source.UserId) then
						local hp = (ship:GetAttribute("HP") :: number) - damage
						ship:SetAttribute("HP", hp)
						if hp <= 0 then
							for _, p in ipairs(ship:GetDescendants()) do
								if p:IsA("BasePart") then p.Anchored = false; p:BreakJoints() end
							end
							Debris:AddItem(ship, 6)
						end
					end
				end
			end
		end
		ball:Destroy()
	end

	task.spawn(function()
		while ball.Parent and life < 6 do
			local dt = task.wait()
			life += dt
			vel += gravity * dt
			local step = vel * dt
			local result = Workspace:Raycast(pos, step, params)
			if result then
				impact(result.Position, result.Instance)
				return
			end
			pos += step
			ball.CFrame = CFrame.new(pos, pos + vel)
			if pos.Y < Config.World.SeaLevelY - 2 then
				impact(pos, nil)
				return
			end
		end
		if ball.Parent then ball:Destroy() end
	end)
end

-- Castle cannons loop
local function runCastleCannons()
	while true do
		task.wait(Config.Pirates.CannonInterval)
		for _, island in ipairs(IslandService.AllIslands()) do
			local castle = island:FindFirstChild("Castle") :: Model?
			if castle and (castle:GetAttribute("HP") :: number) > 0 and island:GetAttribute("OwnerId") ~= 0 then
				local level = castle:GetAttribute("Level") :: number
				local cannons = castle:FindFirstChild("Cannons")
				if cannons then
					for _, c in ipairs(cannons:GetChildren()) do
						if c.Name == "Cannon" and c:IsA("BasePart") then
							local targets = CombatService.HostileTargets(island, c.Position, Config.Pirates.CannonRange)
							if #targets > 0 then
								local target = targets[math.random(#targets)]
								local dir = (target.Position - c.Position)
								CombatService.FireCannonball(CFrame.new(c.Position + dir.Unit * 2.5), dir, 70, Config.Stats.CastleDamage(level), nil, { castle })
							end
						end
					end
				end
			end
		end
	end
end

-- Cutlass tool: swing to hit pirates / enemy castles in front of you
local function giveCutlass(player: Player, char: Model)
	-- never stack duplicates
	for _, container in ipairs({ player.Backpack, char }) do
		local existing = container:FindFirstChild("Cutlass")
		if existing then return end
	end
	local tool = Instance.new("Tool")
	tool.Name = "Cutlass"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Swing at pirates!"
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 4, 0.6)
	handle.Color = Color3.fromRGB(235, 235, 245)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Parent = tool
	local grip = Instance.new("Part")
	grip.Name = "Grip"
	grip.Size = Vector3.new(0.6, 1, 0.8)
	grip.Color = Color3.fromRGB(150, 90, 50)
	grip.CanCollide = false
	grip.CFrame = handle.CFrame * CFrame.new(0, -1.8, 0)
	grip.Parent = tool
	local w = Instance.new("WeldConstraint", grip); w.Part0 = handle; w.Part1 = grip
	tool.Grip = CFrame.new(0, -1.3, 0) * CFrame.Angles(0, 0, 0)
	local lastSwing = 0
	tool.Activated:Connect(function()
		if os.clock() - lastSwing < 0.5 then return end
		lastSwing = os.clock()
		local profile = DataService.Get(player)
		local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not profile or not hrp then return end
		local dmg = Config.Pirates.SwordDamage(profile.Upgrades.Rod)
		local range = Config.Pirates.SwordRange
		-- pirates
		for _, pirate in ipairs(piratesFolder:GetChildren()) do
			local phrp = pirate:FindFirstChild("HumanoidRootPart") :: BasePart?
			local hum = pirate:FindFirstChildOfClass("Humanoid")
			if phrp and hum and hum.Health > 0 then
				local offset = phrp.Position - hrp.Position
				if offset.Magnitude <= range and hrp.CFrame.LookVector:Dot(offset.Unit) > 0.3 then
					hum:TakeDamage(dmg)
					pirate:SetAttribute("LastHitBy", player.UserId)
				end
			end
		end
		-- enemy castle (while raiding)
		local raidingName = char:GetAttribute("Raiding")
		if raidingName then
			local island = Workspace.Islands:FindFirstChild(raidingName) :: Model?
			local castle = island and island:FindFirstChild("Castle") :: Model?
			if castle and castle.PrimaryPart then
				local keep = castle.PrimaryPart :: Part
				local closest = keep.Position
				if (closest - hrp.Position).Magnitude <= range + keep.Size.X / 2 then
					CombatService.DamageCastle(island :: Model, dmg, player)
				end
			end
		end
	end)
	tool.Parent = player.Backpack
end

-- Manned castle cannons: press E at a cannon to take control; aim with the camera; click / F / FIRE to shoot.
local manning: { [Player]: BasePart } = {}
local lastManual: { [Player]: number } = {}

local function leaveCannon(player: Player)
	if manning[player] then
		manning[player] = nil
		Remotes.ManCannon:FireClient(player, nil)
	end
end

local function hookManualCannon(barrel: Instance)
	if not barrel:IsA("BasePart") then return end
	local prompt = barrel:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end
	prompt.ActionText = "Man cannon"
	prompt.Triggered:Connect(function(player: Player)
		if manning[player] == barrel then
			leaveCannon(player)
			return
		end
		manning[player] = barrel
		Remotes.ManCannon:FireClient(player, barrel)
		Remotes.Notify:FireClient(player, "🎯 Aim with the camera • click, F or FIRE to shoot • E again to step away", Color3.fromRGB(120, 220, 255))
	end)
end

function CombatService.FireManned(player: Player, aim: Vector3): boolean
	local barrel = manning[player]
	if not barrel or not barrel.Parent then return false end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp or (hrp.Position - barrel.Position).Magnitude > 10 then
		leaveCannon(player)
		return false
	end
	if os.clock() - (lastManual[player] or 0) < 0.9 then return true end
	lastManual[player] = os.clock()
	local castle = barrel:FindFirstAncestor("Castle") :: Model
	local level = castle:GetAttribute("Level") :: number
	local dmg = Config.Stats.CastleDamage(level)
	-- clamp pitch so you can't shoot straight down through the wall
	local dir = aim.Unit
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.2 then flat = barrel.CFrame.LookVector end
	local pitch = math.clamp(dir.Y, -0.25, 0.6)
	dir = (flat.Unit + Vector3.new(0, pitch, 0)).Unit
	-- swing the barrel to face the shot
	local rest = barrel:GetAttribute("RestCFrame") :: CFrame
	barrel.CFrame = CFrame.lookAt(rest.Position, rest.Position + dir) * CFrame.Angles(0, 0, math.rad(-90)) * CFrame.Angles(0, math.rad(90), 0)
	CombatService.FireCannonball(CFrame.new(barrel.Position + dir * 3), dir, 110, dmg, player, { castle :: Instance, char :: Instance })
	return true
end

function CombatService.Start()
	for _, b in ipairs(CollectionService:GetTagged("ManualCannon")) do hookManualCannon(b) end
	CollectionService:GetInstanceAddedSignal("ManualCannon"):Connect(hookManualCannon)
	projectilesFolder = Instance.new("Folder")
	projectilesFolder.Name = "Projectiles"
	projectilesFolder.Parent = Workspace
	piratesFolder = Instance.new("Folder")
	piratesFolder.Name = "Pirates"
	piratesFolder.Parent = Workspace

	Players.PlayerRemoving:Connect(function(p) manning[p] = nil; lastManual[p] = nil end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			leaveCannon(player)
			giveCutlass(player, char)
		end)
		if player.Character then giveCutlass(player, player.Character) end
	end)
	task.spawn(runCastleCannons)
end

return CombatService
