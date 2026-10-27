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
function CombatService.FireCannonball(origin: CFrame, direction: Vector3, speed: number, damage: number, source: Player?, hitFilter: { Instance })
	local ball = Builders.BuildCannonball(origin)
	ball.Parent = projectilesFolder
	ball.AssemblyLinearVelocity = direction.Unit * speed + Vector3.new(0, speed * 0.15, 0)
	Debris:AddItem(ball, 5)
	-- muzzle flash
	local flash = Instance.new("PointLight")
	flash.Brightness = 6
	flash.Range = 14
	flash.Color = Color3.fromRGB(255, 200, 100)
	flash.Parent = ball
	Debris:AddItem(flash, 0.15)
	local hitDone = false
	ball.Touched:Connect(function(hit: BasePart)
		if hitDone then return end
		if hit:IsDescendantOf(projectilesFolder) then return end
		for _, f in ipairs(hitFilter) do
			if hit:IsDescendantOf(f) then return end
		end
		hitDone = true
		local model = hit:FindFirstAncestorOfClass("Model")
		if model then
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum then
				hum:TakeDamage(damage)
				if source and model:GetAttribute("IsPirate") then
					model:SetAttribute("LastHitBy", source.UserId)
				end
			elseif model.Name == "Castle" then
				local island = model.Parent :: Model
				if source == nil then
					CombatService.DamageCastle(island, damage, nil)
				elseif IslandService.GetOwner(island) ~= source and source.Character and source.Character:GetAttribute("Raiding") == island.Name then
					CombatService.DamageCastle(island, damage, source)
				end
			elseif model.Name:sub(1, 5) == "Ship_" then
				local hp = (model:GetAttribute("HP") :: number) - damage
				model:SetAttribute("HP", hp)
				if hp <= 0 then
					for _, p in ipairs(model:GetDescendants()) do
						if p:IsA("BasePart") then p.Anchored = false; p:BreakJoints() end
					end
					Debris:AddItem(model, 6)
				end
			end
		end
		-- impact puff
		local e = Instance.new("Explosion")
		e.BlastPressure = 0
		e.BlastRadius = 0
		e.Position = ball.Position
		e.Visible = true
		e.Parent = Workspace
		ball:Destroy()
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

-- Manned castle cannons: press E at a cannon to fire where you're facing
local lastManual: { [Player]: number } = {}
local function hookManualCannon(barrel: Instance)
	if not barrel:IsA("BasePart") then return end
	local prompt = barrel:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end
	prompt.Triggered:Connect(function(player: Player)
		if os.clock() - (lastManual[player] or 0) < 0.8 then return end
		local castle = barrel:FindFirstAncestor("Castle")
		local island = castle and castle.Parent :: Model?
		if not island then return end
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then return end
		lastManual[player] = os.clock()
		local level = (castle :: Model):GetAttribute("Level") :: number
		local dmg = Config.Stats.CastleDamage(level)
		local look = hrp.CFrame.LookVector
		local dir = Vector3.new(look.X, 0, look.Z).Unit + Vector3.new(0, 0.12, 0)
		CombatService.FireCannonball(CFrame.new(barrel.Position + dir.Unit * 3), dir, 95, dmg, player, { castle :: Instance, char :: Instance })
		-- recoil puff
		local flash = Instance.new("Explosion")
		flash.BlastPressure = 0
		flash.BlastRadius = 0
		flash.Position = barrel.Position + dir.Unit * 2.5
		flash.Parent = Workspace
	end)
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

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			giveCutlass(player, char)
		end)
		if player.Character then giveCutlass(player, player.Character) end
	end)
	task.spawn(runCastleCannons)
end

return CombatService
