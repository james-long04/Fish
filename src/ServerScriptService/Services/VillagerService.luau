--!strict
-- VillagerService (ModuleScript) — ServerScriptService/Services/VillagerService
-- Hire Fishers (they catch fish for you on a timer) and Guards (they fight pirates and raiders).
-- Gear upgrades (rods / weapons) apply to every villager of that type on your island.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local Builders = require(ReplicatedStorage.Shared.Builders)
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
	bb.Size = UDim2.fromOffset(160, 30)
	bb.StudsOffset = Vector3.new(0, 2.5, 0)
	bb.AlwaysOnTop = true
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
-- Fisher loop
----------------------------------------------------------------------
local function runFisher(player: Player, rig: Model)
	local hum = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	while rig.Parent and hum.Health > 0 and player.Parent do
		local profile = DataService.Get(player)
		if not profile then break end
		task.wait(Config.Villagers.FisherInterval(profile.Villagers.FisherRod))
		if not rig.Parent then break end
		profile = DataService.Get(player)
		if not profile then break end
		local luck = Config.Villagers.FisherLuck(profile.Villagers.FisherRod) + Monetization.LuckBonus(player)
		local fish = Config.RollFish(luck)
		profile.TotalCaught += 1
		profile.Discovered[fish.name] = true
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
		hum.Jump = true -- little "cast" hop
	end
end

----------------------------------------------------------------------
-- Guard loop
----------------------------------------------------------------------
local function runGuard(player: Player, rig: Model, island: Model, post: Vector3)
	local hum = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
	local hrp = rig.PrimaryPart :: BasePart
	local lastAttack = 0
	while rig.Parent and hum.Health > 0 and player.Parent do
		local profile = DataService.Get(player)
		if not profile then break end
		local dmg = Config.Villagers.GuardDamage(profile.Villagers.GuardWeapon)
		local targets = CombatService.HostileTargets(island, post, Config.Villagers.GuardRange)
		if #targets > 0 then
			local nearest, nd = nil, math.huge
			for _, t in ipairs(targets) do
				local d = (t.Position - hrp.Position).Magnitude
				if d < nd then nearest, nd = t, d end
			end
			if nearest then
				if nd > 4.5 then
					hum:MoveTo(nearest.Position)
				elseif os.clock() - lastAttack >= Config.Villagers.GuardAttackInterval then
					lastAttack = os.clock()
					local model = nearest.Parent :: Model
					local thum = model:FindFirstChildOfClass("Humanoid")
					if thum then
						thum:TakeDamage(dmg)
						if model:GetAttribute("IsPirate") then model:SetAttribute("LastHitBy", player.UserId) end
					end
					hum.Jump = true
				end
			end
			task.wait(0.25)
		else
			if (hrp.Position - post).Magnitude > 3 then hum:MoveTo(post) end
			task.wait(0.8)
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

	-- Fishers line the beach either side of the dock
	for i = 1, profile.Villagers.Fishers do
		local rig = Builders.BuildVillager("Fisher", 100, profile.Villagers.FisherRod)
		local side = (i % 2 == 0) and 1 or -1
		local slot = math.ceil(i / 2)
		local pos = facing * CFrame.new(side * (8 + slot * 4), y + 5, -(R - 8))
		rig:PivotTo(CFrame.lookAt(pos.Position, pos.Position + facing.LookVector * -1))
		rig:SetAttribute("Island", island.Name)
		rig.Parent = folder
		table.insert(r.Fishers, rig)
		task.spawn(runFisher, player, rig)
	end
	-- Guards stand in a ring around the castle
	for i = 1, profile.Villagers.Guards do
		local hp = Config.Villagers.GuardHP(profile.Villagers.GuardWeapon)
		local rig = Builders.BuildVillager("Guard", hp, profile.Villagers.GuardWeapon)
		local ang = (i / math.max(profile.Villagers.Guards, 1)) * math.pi * 2
		local post = (facing * CFrame.new(math.cos(ang) * 20, y + 5, 8 + math.sin(ang) * 20)).Position
		rig:PivotTo(CFrame.new(post))
		rig:SetAttribute("Island", island.Name)
		rig.Parent = folder
		table.insert(r.Guards, rig)
		local hum = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
		hum.WalkSpeed = Config.Villagers.GuardWalkSpeed
		hum.Died:Connect(function()
			bubble(rig, "💀 Fallen — back at dawn", Color3.fromRGB(255, 120, 120))
			Debris:AddItem(rig, 3)
		end)
		task.spawn(runGuard, player, rig, island, post)
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
