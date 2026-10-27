--!strict
-- Builders (ModuleScript) — ReplicatedStorage/Shared/Builders
-- Generates the world: terrain islands with walkable beaches, hollow stone castles you can enter,
-- docks with ladders, aquarium tanks, ships (raft → galleon), palms, props, pirate & villager rigs.
-- Everything is Parts + Terrain, so there is nothing to download. Keep the part NAMES and Attributes
-- if you swap in your own models later.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local Config = require(script.Parent.GameConfig)

local Builders = {}

local C = {
	Stone = Color3.fromRGB(214, 210, 200),
	StoneDark = Color3.fromRGB(160, 156, 150),
	StoneTrim = Color3.fromRGB(120, 116, 112),
	RoofRed = Color3.fromRGB(226, 66, 60),
	Wood = Color3.fromRGB(140, 88, 50),
	WoodLight = Color3.fromRGB(204, 150, 96),
	WoodDark = Color3.fromRGB(96, 60, 34),
	Trunk = Color3.fromRGB(150, 100, 58),
	Leaf = Color3.fromRGB(58, 200, 92),
	LeafDark = Color3.fromRGB(40, 160, 76),
	Glass = Color3.fromRGB(150, 235, 255),
	Sail = Color3.fromRGB(250, 246, 236),
	SailStripe = Color3.fromRGB(226, 66, 60),
	Cannon = Color3.fromRGB(42, 42, 48),
	Iron = Color3.fromRGB(70, 72, 80),
	PirateShirt = Color3.fromRGB(200, 40, 40),
	PirateSkin = Color3.fromRGB(240, 190, 150),
	Flag = Color3.fromRGB(22, 22, 24),
	Gold = Color3.fromRGB(255, 200, 50),
	Rock = Color3.fromRGB(120, 118, 125),
}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do (p :: any)[k] = v end
	return p
end

local function wedge(props: { [string]: any }): WedgePart
	local p = Instance.new("WedgePart")
	p.Anchored = true
	p.CanCollide = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do (p :: any)[k] = v end
	return p
end

-- Upright cylinder: size = (height, diameter, diameter)
local function cyl(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance, name: string?): Part
	local p = part({ Shape = Enum.PartType.Cylinder, Size = size, CFrame = cf * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = material, Parent = parent })
	p.Name = name or "Cylinder"
	return p
end

-- Ellipsoid via SpecialMesh (Ball parts can't stretch, meshes can)
local function ellipsoid(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance, name: string?): Part
	local p = part({ Size = size, CFrame = cf, Color = color, Material = material, Parent = parent, CanCollide = false })
	p.Name = name or "Ellipsoid"
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end

local function pointLight(parent: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

local function billboard(parent: BasePart, text: string, offsetY: number, width: number, color: Color3, maxDist: number): TextLabel
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = UDim2.fromOffset(width, 28)
	bb.StudsOffset = Vector3.new(0, offsetY, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = maxDist
	bb.Parent = parent
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.3
	t.Text = text
	t.Parent = bb
	return t
end

----------------------------------------------------------------------
-- WORLD
----------------------------------------------------------------------
function Builders.BuildWorld()
	local terrain = Workspace.Terrain
	terrain:Clear()
	-- remove the default baseplate / spawn so the sea is clear
	for _, name in ipairs({ "Baseplate", "SpawnLocation" }) do
		local junk = Workspace:FindFirstChild(name)
		if junk then junk:Destroy() end
	end
	terrain.WaterColor = Color3.fromRGB(38, 190, 225)
	terrain.WaterTransparency = 0.55
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.18
	terrain.WaterWaveSpeed = 14
	pcall(function() (terrain :: any).Decoration = true end) -- animated grass; not scriptable on every Studio build
	local size = Config.World.WaterSize
	local y = Config.World.SeaLevelY
	terrain:FillBlock(CFrame.new(0, y - 60, 0), Vector3.new(size, 8, size), Enum.Material.Sand) -- seabed
	terrain:FillBlock(CFrame.new(0, y - 28, 0), Vector3.new(size, 56, size), Enum.Material.Water)
	-- invisible floor so nothing is lost forever
	part({ Name = "SeaFloor", Size = Vector3.new(size, 4, size), CFrame = CFrame.new(0, y - 66, 0), Transparency = 1, Parent = Workspace })

	-- Lighting
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(110, 130, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 170, 190)
	Lighting.ClockTime = 10.5
	Lighting.GlobalShadows = true
	pcall(function() Lighting.ShadowSoftness = 0.3 end)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	pcall(function() Lighting.ExposureCompensation = 0.15 end)
	for _, cls in ipairs({ "Atmosphere", "BloomEffect", "ColorCorrectionEffect", "SunRaysEffect", "DepthOfFieldEffect" }) do
		local e = Lighting:FindFirstChildOfClass(cls)
		if e then e:Destroy() end
	end
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.32
	atm.Offset = 0.25
	atm.Color = Color3.fromRGB(205, 232, 255)
	atm.Decay = Color3.fromRGB(110, 190, 255)
	atm.Glare = 0.4
	atm.Haze = 1.8
	atm.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 32
	bloom.Threshold = 1.1
	bloom.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.2
	cc.Contrast = 0.08
	cc.TintColor = Color3.fromRGB(255, 250, 240)
	cc.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.08
	rays.Spread = 0.6
	rays.Parent = Lighting
	pcall(function()
		local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
		clouds.Cover = 0.45
		clouds.Density = 0.3
		clouds.Color = Color3.fromRGB(255, 255, 255)
		clouds.Parent = terrain
	end)

	-- Hub sandbar with neutral spawn
	local hub = Instance.new("Model")
	hub.Name = "Hub"
	hub.Parent = Workspace
	Builders.BuildTerrainIsland(Vector3.new(0, y, 0), 16)
	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, y + 5, 0)
	spawn.Transparency = 1
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Parent = hub
	Builders.BuildPalm(CFrame.new(7, y + 3, 4), hub)
	Builders.BuildPalm(CFrame.new(-6, y + 3, -6), hub)
end

-- Smooth sloped sand island out of terrain. Top plateau at y+3.
function Builders.BuildTerrainIsland(center: Vector3, R: number)
	local terrain = Workspace.Terrain
	local y = Config.World.SeaLevelY
	local layers = {
		{ 1.9, -5 }, { 1.6, -3 }, { 1.4, -1.2 }, { 1.22, 0.4 }, { 1.1, 1.6 }, { 1.0, 2.4 }, { 0.93, 3 },
	}
	for _, L in ipairs(layers) do
		local r, top = R * L[1], y + L[2]
		local h = top + 14
		terrain:FillCylinder(CFrame.new(center.X, top - h / 2, center.Z), h, r, Enum.Material.Sand)
	end
	-- grassy centre
	terrain:FillCylinder(CFrame.new(center.X, y + 2.6, center.Z), 1.2, R * 0.62, Enum.Material.Grass)
end

----------------------------------------------------------------------
-- PALM TREE & PROPS
----------------------------------------------------------------------
function Builders.BuildPalm(baseCF: CFrame, parent: Instance)
	local m = Instance.new("Model")
	m.Name = "Palm"
	m.Parent = parent
	local yaw = math.random() * math.pi * 2
	local lean = math.rad(8 + math.random() * 10)
	local segs = 6
	local segLen = 2.6 + math.random() * 0.6
	local cf = baseCF * CFrame.Angles(0, yaw, 0)
	local top = cf
	for i = 1, segs do
		local bend = lean * (i / segs)
		cf = cf * CFrame.Angles(bend / segs * 2, 0, 0)
		local segCF = cf * CFrame.new(0, segLen / 2, 0)
		local d = 1.5 - i * 0.12
		local s = cyl(Vector3.new(segLen + 0.3, d, d), segCF, C.Trunk, Enum.Material.Wood, m, "Trunk")
		s.CanCollide = i <= 2
		cf = cf * CFrame.new(0, segLen, 0)
		top = cf
	end
	for i = 1, 8 do
		local ang = (i / 8) * math.pi * 2 + math.random() * 0.3
		local droop = math.rad(-15)
		local fcf = top * CFrame.Angles(0, ang, 0)
		local len = 5 + math.random() * 1.5
		for k = 1, 3 do
			local seg = part({ Name = "Leaf", Size = Vector3.new(1.9 - k * 0.4, 0.18, len / 3 + 0.3), Color = (k == 1) and C.Leaf or C.LeafDark, Material = Enum.Material.Grass, CanCollide = false, Parent = m })
			fcf = fcf * CFrame.Angles(droop - math.rad(10) * k, 0, 0) * CFrame.new(0, 0, -(len / 6))
			seg.CFrame = fcf
			fcf = fcf * CFrame.new(0, 0, -(len / 6))
		end
	end
	for _ = 1, 3 do
		part({ Name = "Coconut", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), Color = C.WoodDark, Material = Enum.Material.Wood, CanCollide = false, Parent = m, CFrame = top * CFrame.new(math.random(-8, 8) / 10, -0.5, math.random(-8, 8) / 10) })
	end
	return m
end

function Builders.BuildProps(center: CFrame, R: number, parent: Instance)
	local y = Config.World.SeaLevelY
	-- rocks
	for _ = 1, 5 do
		local ang = math.random() * math.pi * 2
		local r = R * (0.75 + math.random() * 0.35)
		local s = 1.5 + math.random() * 2.5
		ellipsoid(Vector3.new(s * 1.4, s * 0.8, s), CFrame.new(center.Position + Vector3.new(math.cos(ang) * r, y + 1.4, math.sin(ang) * r)) * CFrame.Angles(0, math.random() * 3, 0), C.Rock, Enum.Material.Slate, parent, "Rock").CanCollide = true
	end
	-- bushes
	for _ = 1, 4 do
		local ang = math.random() * math.pi * 2
		local r = R * (0.3 + math.random() * 0.3)
		local pos = center.Position + Vector3.new(math.cos(ang) * r, y + 3.4, math.sin(ang) * r)
		for k = 1, 3 do
			ellipsoid(Vector3.new(2.4, 1.8, 2.4), CFrame.new(pos + Vector3.new(math.random(-8, 8) / 10, 0, math.random(-8, 8) / 10)), (k == 2) and C.LeafDark or C.Leaf, Enum.Material.Grass, parent, "Bush")
		end
	end
	-- campfire on the beach
	local fc = center * CFrame.new(10, y + 3.2, -(R - 14))
	for i = 1, 6 do
		cyl(Vector3.new(0.8, 1, 1), fc * CFrame.Angles(0, i, 0) * CFrame.new(1.2, 0, 0), C.Rock, Enum.Material.Slate, parent, "FireRock")
	end
	local log = part({ Name = "FireLog", Size = Vector3.new(0.6, 0.6, 2.2), Color = C.WoodDark, Material = Enum.Material.Wood, Parent = parent, CFrame = fc * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0.8, 0) })
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 6
	fire.Parent = log
	pointLight(log, Color3.fromRGB(255, 160, 70), 18, 1.5)
	-- barrels & crate by the dock
	for i = 1, 2 do
		cyl(Vector3.new(2.6, 2, 2), center * CFrame.new(-7 - i * 2.4, y + 4.3, -(R - 10)), C.Wood, Enum.Material.Wood, parent, "Barrel")
	end
	part({ Name = "Crate", Size = Vector3.new(2.4, 2.4, 2.4), Color = C.WoodLight, Material = Enum.Material.WoodPlanks, Parent = parent, CFrame = center * CFrame.new(-6, y + 4.2, -(R - 14)) * CFrame.Angles(0, 0.4, 0) })
end

----------------------------------------------------------------------
-- ISLAND
----------------------------------------------------------------------
function Builders.BuildIsland(index: number, center: Vector3, parent: Instance): Model
	local R = Config.World.IslandRadius
	local y = Config.World.SeaLevelY
	local island = Instance.new("Model")
	island.Name = "Island" .. index
	island:SetAttribute("Index", index)
	island:SetAttribute("Owner", "")
	island:SetAttribute("OwnerId", 0)
	island.Parent = parent

	local toCenter = Vector3.new(-center.X, 0, -center.Z).Unit
	local facing = CFrame.lookAt(center, center + toCenter)
	local root = part({ Name = "Root", Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, CFrame = facing + Vector3.new(0, y, 0), Parent = island })
	island.PrimaryPart = root

	Builders.BuildTerrainIsland(center, R)

	for i = 1, 9 do
		local ang = (i / 9) * math.pi * 2 + 0.3
		local r = R * (0.72 + (i % 2) * 0.14)
		Builders.BuildPalm(CFrame.new(center + Vector3.new(math.cos(ang) * r, y + 2.6, math.sin(ang) * r)), island)
	end
	local props = Instance.new("Model")
	props.Name = "Props"
	props.Parent = island
	Builders.BuildProps(facing, R, props)

	-- Dock
	local dock = Instance.new("Model")
	dock.Name = "Dock"
	dock.Parent = island
	local dockStart = facing * CFrame.new(0, y + 2.6, -(R - 2))
	local planks = 7
	for i = 0, planks - 1 do
		part({ Name = "Plank", Size = Vector3.new(8, 0.5, 3.6), Color = (i % 2 == 0) and C.WoodLight or C.Wood, Material = Enum.Material.WoodPlanks, Parent = dock, CFrame = dockStart * CFrame.new(0, 0, -i * 3.7) })
		for _, sx in ipairs({ -3.6, 3.6 }) do
			cyl(Vector3.new(8, 0.8, 0.8), dockStart * CFrame.new(sx, -3.2, -i * 3.7), C.WoodDark, Enum.Material.Wood, dock, "Post")
		end
	end
	-- railing posts + rope
	for i = 0, planks - 1, 2 do
		for _, sx in ipairs({ -3.6, 3.6 }) do
			cyl(Vector3.new(2.4, 0.4, 0.4), dockStart * CFrame.new(sx, 1.4, -i * 3.7), C.WoodDark, Enum.Material.Wood, dock, "RailPost").CanCollide = false
		end
	end
	local dockEnd = dockStart * CFrame.new(0, 0, -(planks - 1) * 3.7)
	part({ Name = "DockEnd", Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, Parent = island, CFrame = dockEnd })
	-- ladders / ramps into the water on both sides so you can climb back up from a swim
	for _, sx in ipairs({ -1, 1 }) do
		local w = wedge({ Name = "Ramp", Size = Vector3.new(3.6, 3.4, 6), Color = C.WoodLight, Material = Enum.Material.WoodPlanks, Parent = dock })
		w.CFrame = dockEnd * CFrame.new(sx * 5.8, -1.7, 0) * CFrame.Angles(0, sx * math.rad(90), 0)
	end
	-- lantern at the end
	local lpost = cyl(Vector3.new(4, 0.4, 0.4), dockEnd * CFrame.new(3.6, 2, -1.2), C.WoodDark, Enum.Material.Wood, dock, "LampPost")
	lpost.CanCollide = false
	local lamp = part({ Name = "Lamp", Size = Vector3.new(0.9, 1.1, 0.9), Color = Color3.fromRGB(255, 220, 140), Material = Enum.Material.Neon, CanCollide = false, Parent = dock, CFrame = dockEnd * CFrame.new(3.6, 4.3, -1.2) })
	pointLight(lamp, Color3.fromRGB(255, 210, 130), 16, 1.2)

	local spot = part({ Name = "FishingSpot", Size = Vector3.new(8, 0.55, 3.6), Color = Color3.fromRGB(90, 210, 255), Material = Enum.Material.Neon, Parent = island, CFrame = dockEnd * CFrame.new(0, 0.02, 0), Transparency = 0.45 })
	spot.CanCollide = false
	part({ Name = "ShipSpawn", Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, Parent = island, CFrame = dockEnd * CFrame.new(11, -2.2, -2) })
	part({ Name = "DockZone", Size = Vector3.new(60, 20, 60), Transparency = 1, CanCollide = false, Parent = island, CFrame = dockEnd * CFrame.new(0, 4, -12) })

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Transparency = 1
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Enabled = false
	spawn.Neutral = true
	spawn.CFrame = facing * CFrame.new(0, y + 5, -(R - 12))
	spawn.Parent = island

	Builders.BuildAquarium(island, facing * CFrame.new(-22, y + 3, -13))
	Builders.BuildCastle(island, 0)

	billboard(root, "Unclaimed Island", 40, 240, Color3.fromRGB(255, 240, 150), 180).Parent.Name = "OwnerSign"
	return island
end

----------------------------------------------------------------------
-- AQUARIUM (fish are rendered client-side by AquariumRenderer)
----------------------------------------------------------------------
function Builders.BuildAquarium(island: Model, cf: CFrame)
	local aq = Instance.new("Model")
	aq.Name = "Aquarium"
	aq.Parent = island
	local W, H, D = 14, 8, 9
	part({ Name = "Base", Size = Vector3.new(W + 1.2, 1.2, D + 1.2), Color = C.StoneTrim, Material = Enum.Material.Slate, Parent = aq, CFrame = cf })
	part({ Name = "Sand", Size = Vector3.new(W - 0.4, 0.5, D - 0.4), Color = Color3.fromRGB(240, 222, 170), Material = Enum.Material.Sand, Parent = aq, CFrame = cf * CFrame.new(0, 0.8, 0) })
	local glass = part({ Name = "Glass", Size = Vector3.new(W, H, D), Color = C.Glass, Material = Enum.Material.Glass, Transparency = 0.6, Reflectance = 0.1, Parent = aq, CFrame = cf * CFrame.new(0, 0.6 + H / 2, 0) })
	local water = part({ Name = "Water", Size = Vector3.new(W - 0.5, H - 0.9, D - 0.5), Color = Color3.fromRGB(70, 200, 245), Material = Enum.Material.Glass, Transparency = 0.82, CanCollide = false, Parent = aq, CFrame = cf * CFrame.new(0, 0.55 + H / 2, 0) })
	water:SetAttribute("Inner", Vector3.new(W - 2, H - 2.4, D - 2))
	-- frame edges
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			part({ Name = "Frame", Size = Vector3.new(0.5, H + 0.4, 0.5), Color = C.StoneTrim, Material = Enum.Material.Metal, Parent = aq, CFrame = cf * CFrame.new(sx * W / 2, 0.6 + H / 2, sz * D / 2) })
		end
	end
	part({ Name = "Lid", Size = Vector3.new(W + 0.8, 0.5, D + 0.8), Color = C.StoneTrim, Material = Enum.Material.Metal, Parent = aq, CFrame = cf * CFrame.new(0, H + 0.9, 0) })
	-- decor: coral + plants + bubbles + light
	for i = 1, 6 do
		local px, pz = math.random(-W / 2 + 2, W / 2 - 2), math.random(-D / 2 + 2, D / 2 - 2)
		local h = 1 + math.random() * 2
		local col = ({ Color3.fromRGB(255, 110, 140), Color3.fromRGB(255, 170, 60), Color3.fromRGB(170, 90, 255), Color3.fromRGB(80, 230, 150) })[(i % 4) + 1]
		ellipsoid(Vector3.new(1.2, h, 1.2), cf * CFrame.new(px, 1 + h / 2, pz), col, Enum.Material.Neon, aq, "Coral")
		ellipsoid(Vector3.new(0.6, h * 0.8, 0.6), cf * CFrame.new(px + 0.6, 1 + h * 0.4, pz - 0.4), col, Enum.Material.Neon, aq, "Coral")
	end
	local bubbleEmitter = Instance.new("Attachment")
	bubbleEmitter.Position = Vector3.new(W / 2 - 2, -H / 2 + 1.2, 0)
	bubbleEmitter.Parent = water
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxassetid://6071575925"
	pe.Rate = 6
	pe.Lifetime = NumberRange.new(2.5, 3.5)
	pe.Speed = NumberRange.new(1.5, 2.2)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.45) })
	pe.Transparency = NumberSequence.new(0.4)
	pe.Color = ColorSequence.new(Color3.fromRGB(220, 250, 255))
	pe.LightEmission = 0.4
	pe.Parent = bubbleEmitter
	pointLight(water, Color3.fromRGB(120, 220, 255), 14, 0.8)
	local fishFolder = Instance.new("Folder")
	fishFolder.Name = "FishDisplay"
	fishFolder.Parent = aq
	billboard(glass, "Aquarium 0/10", H / 2 + 2, 220, Color3.new(1, 1, 1), 120)
	return aq
end

----------------------------------------------------------------------
-- CASTLE — hollow, enterable, with gate, ramps to the walls, manned cannons
----------------------------------------------------------------------
function Builders.BuildCastle(island: Model, level: number, extraCannons: number?)
	local old = island:FindFirstChild("Castle")
	if old then old:Destroy() end
	local root = island.PrimaryPart :: Part
	local facing = root.CFrame
	local y = Config.World.SeaLevelY
	local castle = Instance.new("Model")
	castle.Name = "Castle"
	castle.Parent = island
	local maxHP = Config.Stats.CastleHP(level)
	castle:SetAttribute("MaxHP", maxHP)
	castle:SetAttribute("HP", maxHP)
	castle:SetAttribute("Level", level)

	local growth = math.min(level, 8)
	local half = 13 + growth * 0.3         -- outer wall half-width
	local wallH = 7 + growth * 0.5
	local wallT = 4                        -- thick enough to walk along
	local ground = y + 3
	local base = facing * CFrame.new(0, ground, 11) -- castle centre, behind the beach
	local stoneMat = Enum.Material.Cobblestone

	-- courtyard floor
	part({ Name = "Courtyard", Size = Vector3.new(half * 2, 0.4, half * 2), Color = C.StoneDark, Material = Enum.Material.Slate, Parent = castle, CFrame = base * CFrame.new(0, 0.2, 0) })

	-- walls: front (sea side, -Z) has a gate gap
	local gateW = 7
	local function wall(size: Vector3, cf: CFrame)
		local w = part({ Name = "Wall", Size = size, Color = C.Stone, Material = stoneMat, Parent = castle, CFrame = cf })
		return w
	end
	-- back & sides
	wall(Vector3.new(half * 2, wallH, wallT), base * CFrame.new(0, wallH / 2, half))
	wall(Vector3.new(wallT, wallH, half * 2), base * CFrame.new(-half, wallH / 2, 0))
	wall(Vector3.new(wallT, wallH, half * 2), base * CFrame.new(half, wallH / 2, 0))
	-- front in two pieces + arch lintel over the gate
	local sideLen = half - gateW / 2
	wall(Vector3.new(sideLen, wallH, wallT), base * CFrame.new(-(gateW / 2 + sideLen / 2), wallH / 2, -half))
	wall(Vector3.new(sideLen, wallH, wallT), base * CFrame.new((gateW / 2 + sideLen / 2), wallH / 2, -half))
	wall(Vector3.new(gateW + 0.2, wallH - 6.5, wallT), base * CFrame.new(0, 6.5 + (wallH - 6.5) / 2, -half))
	-- arch corners (wedges) to round the gate
	for _, sx in ipairs({ -1, 1 }) do
		local w = wedge({ Name = "Arch", Size = Vector3.new(wallT, 1.6, 1.6), Color = C.Stone, Material = stoneMat, Parent = castle })
		w.CFrame = base * CFrame.new(sx * (gateW / 2 - 0.8), 5.7, -half) * CFrame.Angles(0, sx * math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(180))
	end
	-- portcullis (raised, decorative) + gate torches
	for i = -2, 2 do
		part({ Name = "Bar", Size = Vector3.new(0.25, 2.2, 0.25), Color = C.Iron, Material = Enum.Material.Metal, CanCollide = false, Parent = castle, CFrame = base * CFrame.new(i * 1.3, 6.4, -half - 0.9) })
	end
	for _, sx in ipairs({ -1, 1 }) do
		local torch = part({ Name = "Torch", Size = Vector3.new(0.5, 0.5, 0.5), Color = Color3.fromRGB(255, 190, 90), Material = Enum.Material.Neon, CanCollide = false, Parent = castle, CFrame = base * CFrame.new(sx * (gateW / 2 + 1.2), 4.5, -half - 1.7) })
		local f = Instance.new("Fire"); f.Size = 2; f.Heat = 4; f.Parent = torch
		pointLight(torch, Color3.fromRGB(255, 170, 80), 14, 1.2)
	end

	-- battlements on all outer edges
	local step = 2.6
	local function merlons(fromX: number, toX: number, z: number, alongX: boolean)
		local n = math.floor(math.abs(toX - fromX) / step)
		for i = 0, n do
			local t = fromX + (toX - fromX) * (i / math.max(n, 1))
			local pos = alongX and Vector3.new(t, wallH + 0.7, z) or Vector3.new(z, wallH + 0.7, t)
			local m = part({ Name = "Merlon", Size = Vector3.new(1.4, 1.4, 1.4), Color = C.StoneDark, Material = stoneMat, Parent = castle, CFrame = base * CFrame.new(pos) })
			m.CanCollide = true
		end
	end
	merlons(-half, half, half + wallT / 2 - 0.7, true)
	merlons(-half, half, -half - wallT / 2 + 0.7, true)
	merlons(-half, half, -half - wallT / 2 + 0.7, false)
	merlons(-half, half, half + wallT / 2 - 0.7, false)

	-- corner towers (hollow look: solid with windows)
	for _, cx in ipairs({ -1, 1 }) do
		for _, cz in ipairs({ -1, 1 }) do
			local tcf = base * CFrame.new(cx * half, 0, cz * half)
			local th = wallH + 4
			cyl(Vector3.new(th, 6.5, 6.5), tcf * CFrame.new(0, th / 2, 0), C.Stone, stoneMat, castle, "Tower")
			cyl(Vector3.new(0.8, 8, 8), tcf * CFrame.new(0, th + 0.3, 0), C.StoneDark, stoneMat, castle, "TowerLip")
			-- conical roof from stacked cylinders
			for k = 0, 4 do
				cyl(Vector3.new(1.3, 7.2 - k * 1.5, 7.2 - k * 1.5), tcf * CFrame.new(0, th + 1.3 + k * 1.2, 0), C.RoofRed, Enum.Material.SmoothPlastic, castle, "Roof")
			end
			local win = part({ Name = "Window", Size = Vector3.new(1, 1.6, 0.3), Color = Color3.fromRGB(255, 220, 150), Material = Enum.Material.Neon, CanCollide = false, Parent = castle, CFrame = tcf * CFrame.new(cx * -0.2, th * 0.6, cz * -3.3) })
			pointLight(win, Color3.fromRGB(255, 210, 120), 10, 0.8)
		end
	end

	-- ramps up to the wall walkway (inside, along the side walls)
	for _, sx in ipairs({ -1, 1 }) do
		local rampLen = wallH * 1.9
		local r = wedge({ Name = "Ramp", Size = Vector3.new(3, wallH, rampLen), Color = C.StoneDark, Material = Enum.Material.Slate, Parent = castle })
		r.CFrame = base * CFrame.new(sx * (half - wallT / 2 - 1.6), wallH / 2, half - rampLen / 2 - wallT / 2) * CFrame.Angles(0, math.rad(180), 0)
	end

	-- keep: a small hollow hall in the back of the courtyard with an open doorway
	local kW, kD, kH = 11, 9, 7
	local kcf = base * CFrame.new(0, 0, half - kD / 2 - wallT - 1)
	local keep = part({ Name = "CastleRoot", Size = Vector3.new(kW, 0.3, kD), Color = C.StoneDark, Material = Enum.Material.Slate, Parent = castle, CFrame = kcf * CFrame.new(0, 0.35, 0) })
	castle.PrimaryPart = keep
	wall(Vector3.new(kW, kH, 1), kcf * CFrame.new(0, kH / 2, kD / 2))
	wall(Vector3.new(1, kH, kD), kcf * CFrame.new(-kW / 2, kH / 2, 0))
	wall(Vector3.new(1, kH, kD), kcf * CFrame.new(kW / 2, kH / 2, 0))
	local doorW = 3.4
	wall(Vector3.new((kW - doorW) / 2, kH, 1), kcf * CFrame.new(-(doorW / 2 + (kW - doorW) / 4), kH / 2, -kD / 2))
	wall(Vector3.new((kW - doorW) / 2, kH, 1), kcf * CFrame.new((doorW / 2 + (kW - doorW) / 4), kH / 2, -kD / 2))
	wall(Vector3.new(doorW + 0.2, kH - 4.8, 1), kcf * CFrame.new(0, 4.8 + (kH - 4.8) / 2, -kD / 2))
	part({ Name = "KeepRoof", Size = Vector3.new(kW + 1, 0.8, kD + 1), Color = C.StoneDark, Material = stoneMat, Parent = castle, CFrame = kcf * CFrame.new(0, kH + 0.4, 0) })
	-- inside: treasure chest + throne-ish bench, chandelier light
	local chest = part({ Name = "Chest", Size = Vector3.new(2.2, 1.4, 1.4), Color = C.WoodDark, Material = Enum.Material.Wood, Parent = castle, CFrame = kcf * CFrame.new(0, 1.2, kD / 2 - 1.6) })
	part({ Name = "ChestGold", Size = Vector3.new(1.8, 0.3, 1), Color = C.Gold, Material = Enum.Material.Neon, CanCollide = false, Parent = castle, CFrame = chest.CFrame * CFrame.new(0, 0.85, 0) })
	local lamp = part({ Name = "KeepLamp", Size = Vector3.new(0.8, 0.8, 0.8), Color = Color3.fromRGB(255, 210, 120), Material = Enum.Material.Neon, CanCollide = false, Parent = castle, CFrame = kcf * CFrame.new(0, kH - 1, 0) })
	pointLight(lamp, Color3.fromRGB(255, 200, 110), 16, 1.4)
	-- flag on the keep
	cyl(Vector3.new(7, 0.35, 0.35), kcf * CFrame.new(0, kH + 4, 0), C.WoodDark, Enum.Material.Wood, castle, "Pole").CanCollide = false
	part({ Name = "Flag", Size = Vector3.new(3.6, 2.2, 0.15), Color = C.Gold, Material = Enum.Material.Fabric, CanCollide = false, Parent = castle, CFrame = kcf * CFrame.new(1.9, kH + 6.4, 0) })

	-- cannons along the front wall top (manned via prompt, also auto-fire at hostiles)
	local cannons = Config.Stats.CastleCannons(level) + (extraCannons or 0)
	local cannonFolder = Instance.new("Folder")
	cannonFolder.Name = "Cannons"
	cannonFolder.Parent = castle
	for i = 1, cannons do
		local t = (cannons == 1) and 0 or ((i - 1) / (cannons - 1) - 0.5) * (half * 1.5)
		local side = (i % 2 == 0) and 1 or -1
		if cannons > 2 and math.abs(t) < gateW then t = side * (gateW / 2 + 2) end
		local ccf = base * CFrame.new(t, wallH + 1.1, -half)
		part({ Name = "Carriage", Size = Vector3.new(1.8, 1, 2.6), Color = C.WoodDark, Material = Enum.Material.Wood, Parent = cannonFolder, CFrame = ccf * CFrame.new(0, 0, 0) })
		for _, sx in ipairs({ -1, 1 }) do
			cyl(Vector3.new(0.3, 1.1, 1.1), ccf * CFrame.new(sx * 1.05, 0, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, 0, math.rad(-90)) * CFrame.Angles(0, math.rad(90), 0), C.Iron, Enum.Material.Metal, cannonFolder, "Wheel").CanCollide = false
		end
		local barrel = cyl(Vector3.new(3.6, 1.2, 1.2), ccf * CFrame.new(0, 0.7, -0.6) * CFrame.Angles(math.rad(90), 0, 0) * CFrame.Angles(0, 0, 0), C.Cannon, Enum.Material.Metal, cannonFolder, "Cannon")
		barrel.CFrame = ccf * CFrame.new(0, 0.75, -0.8) * CFrame.Angles(math.rad(90) + math.rad(-6), 0, 0) * CFrame.Angles(0, 0, math.rad(-90))
		barrel.CanCollide = false
		barrel:SetAttribute("Muzzle", true)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Fire!"
		prompt.ObjectText = "Cannon"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.Parent = barrel
		CollectionService:AddTag(barrel, "ManualCannon")
	end

	-- HP bar
	local bb = Instance.new("BillboardGui")
	bb.Name = "HPBar"
	bb.Size = UDim2.fromOffset(180, 20)
	bb.StudsOffset = Vector3.new(0, kH + 9, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 220
	bb.Parent = keep
	local bg = Instance.new("Frame")
	bg.Name = "BG"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	bg.BorderSizePixel = 0
	bg.Parent = bb
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 230, 110)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 8)
	local txt = Instance.new("TextLabel")
	txt.Name = "Text"
	txt.Size = UDim2.fromScale(1, 1)
	txt.BackgroundTransparency = 1
	txt.TextScaled = true
	txt.Font = Enum.Font.FredokaOne
	txt.TextColor3 = Color3.new(1, 1, 1)
	txt.TextStrokeTransparency = 0.4
	txt.Text = "Castle Lv " .. level
	txt.Parent = bg

	-- where pirates path to
	part({ Name = "GateTarget", Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, Parent = castle, CFrame = base * CFrame.new(0, 1, -half - 4) })
	part({ Name = "KeepTarget", Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, Parent = castle, CFrame = kcf * CFrame.new(0, 1, -kD / 2 - 2.5) })
	return castle
end

----------------------------------------------------------------------
-- SHIP
----------------------------------------------------------------------
function Builders.BuildShip(level: number, ownerName: string, extraCannons: number?, blackSails: boolean?): Model
	local tier = Config.Stats.ShipTier(level)
	local ship = Instance.new("Model")
	ship.Name = "Ship_" .. ownerName
	ship:SetAttribute("Owner", ownerName)
	ship:SetAttribute("Level", level)
	ship:SetAttribute("MaxHP", Config.Stats.ShipHP(level))
	ship:SetAttribute("HP", Config.Stats.ShipHP(level))

	local floaty = PhysicalProperties.new(0.22, 0.4, 0.3, 1, 1)
	local function hp(props: { [string]: any }): Part
		local p = part(props)
		p.Anchored = false
		p.CustomPhysicalProperties = floaty
		p.Parent = ship
		return p
	end
	local function weldTo(hull: BasePart, p: BasePart)
		local w = Instance.new("WeldConstraint")
		w.Part0 = hull
		w.Part1 = p
		w.Parent = p
	end

	local length, width = 11, 7
	if tier == "Dinghy" then length, width = 13, 7
	elseif tier == "Sloop" then length, width = 20, 8.5
	elseif tier == "Brigantine" then length, width = 28, 10.5
	elseif tier == "Galleon" then length, width = 38, 13 end
	local sailColor = blackSails and C.Flag or C.Sail

	local hull: Part
	local deckY: number
	if tier == "Raft" then
		hull = hp({ Name = "Hull", Size = Vector3.new(width, 1.2, length), Color = C.WoodLight, Material = Enum.Material.WoodPlanks })
		deckY = 0.6
		for i = -2, 2 do
			local log = hp({ Name = "Log", Shape = Enum.PartType.Cylinder, Size = Vector3.new(length + 0.5, 1.4, 1.4), Color = C.Wood, Material = Enum.Material.Wood })
			log.CFrame = hull.CFrame * CFrame.new(i * 1.35, -0.35, 0) * CFrame.Angles(0, math.rad(90), 0)
			weldTo(hull, log)
		end
		local barrel = hp({ Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 1.6, 1.6), Color = C.WoodDark, Material = Enum.Material.Wood, CanCollide = false })
		barrel.CFrame = hull.CFrame * CFrame.new(-2, 1.6, 2.5) * CFrame.Angles(0, 0, math.rad(90))
		weldTo(hull, barrel)
		local mast = hp({ Name = "Mast", Shape = Enum.PartType.Cylinder, Size = Vector3.new(9, 0.5, 0.5), Color = C.WoodDark, Material = Enum.Material.Wood, CanCollide = false })
		mast.CFrame = hull.CFrame * CFrame.new(0, 5, -1) * CFrame.Angles(0, 0, math.rad(90))
		weldTo(hull, mast)
		local sail = hp({ Name = "Sail", Size = Vector3.new(4.5, 5, 1.4), Color = sailColor, Material = Enum.Material.Fabric, CanCollide = false })
		sail.CFrame = hull.CFrame * CFrame.new(0, 5.6, -0.4)
		local sm = Instance.new("SpecialMesh"); sm.MeshType = Enum.MeshType.Sphere; sm.Parent = sail
		weldTo(hull, sail)
	else
		local hullH = 3.2
		hull = hp({ Name = "Hull", Size = Vector3.new(width, hullH, length), Color = C.Wood, Material = Enum.Material.WoodPlanks })
		deckY = hullH / 2 + 0.2
		-- hull stripe + lower hull
		local stripe = hp({ Name = "Stripe", Size = Vector3.new(width + 0.1, 0.5, length), Color = C.Gold, Material = Enum.Material.SmoothPlastic, CanCollide = false })
		stripe.CFrame = hull.CFrame * CFrame.new(0, 0.6, 0)
		weldTo(hull, stripe)
		local keel = hp({ Name = "Keel", Size = Vector3.new(width * 0.7, 1.2, length * 0.9), Color = C.WoodDark, Material = Enum.Material.WoodPlanks, CanCollide = false })
		keel.CFrame = hull.CFrame * CFrame.new(0, -hullH / 2 - 0.4, 0)
		weldTo(hull, keel)
		local deck = hp({ Name = "Deck", Size = Vector3.new(width - 0.6, 0.4, length - 0.6), Color = C.WoodLight, Material = Enum.Material.WoodPlanks })
		deck.CFrame = hull.CFrame * CFrame.new(0, deckY, 0)
		weldTo(hull, deck)
		-- bow (pointed) and stern
		local bow = Instance.new("WedgePart")
		bow.Size = Vector3.new(width, hullH, 7)
		bow.Color = C.Wood
		bow.Material = Enum.Material.WoodPlanks
		bow.CustomPhysicalProperties = floaty
		bow.CFrame = hull.CFrame * CFrame.new(0, 0, -length / 2 - 3.5) * CFrame.Angles(0, math.rad(180), 0)
		bow.Parent = ship
		weldTo(hull, bow)
		local figure = hp({ Name = "Figurehead", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), Color = C.Gold, Material = Enum.Material.Metal, CanCollide = false })
		figure.CFrame = hull.CFrame * CFrame.new(0, hullH / 2 + 0.3, -length / 2 - 6.5)
		weldTo(hull, figure)
		-- raised stern cabin for sloop and up
		if tier ~= "Dinghy" then
			local cabin = hp({ Name = "Cabin", Size = Vector3.new(width - 1.5, 3, 6), Color = C.Wood, Material = Enum.Material.WoodPlanks })
			cabin.CFrame = hull.CFrame * CFrame.new(0, deckY + 1.7, length / 2 - 3.5)
			weldTo(hull, cabin)
			local cabinRoof = hp({ Name = "CabinRoof", Size = Vector3.new(width - 1, 0.4, 6.6), Color = C.WoodLight, Material = Enum.Material.WoodPlanks })
			cabinRoof.CFrame = cabin.CFrame * CFrame.new(0, 1.7, 0)
			weldTo(hull, cabinRoof)
			local win = hp({ Name = "CabinWindow", Size = Vector3.new(width - 2.5, 1.2, 0.2), Color = Color3.fromRGB(255, 220, 140), Material = Enum.Material.Neon, CanCollide = false })
			win.CFrame = cabin.CFrame * CFrame.new(0, 0.2, 3.05)
			weldTo(hull, win)
			pointLight(win, Color3.fromRGB(255, 200, 110), 12, 1)
		end
		-- railings with posts
		for _, sx in ipairs({ -1, 1 }) do
			local rail = hp({ Name = "Rail", Size = Vector3.new(0.3, 0.3, length - 1), Color = C.WoodDark, Material = Enum.Material.Wood, CanCollide = false })
			rail.CFrame = hull.CFrame * CFrame.new(sx * (width / 2 - 0.2), deckY + 1.5, 0)
			weldTo(hull, rail)
			local n = math.floor(length / 4)
			for i = 0, n do
				local post = hp({ Name = "RailPost", Size = Vector3.new(0.3, 1.5, 0.3), Color = C.WoodDark, Material = Enum.Material.Wood, CanCollide = false })
				post.CFrame = hull.CFrame * CFrame.new(sx * (width / 2 - 0.2), deckY + 0.8, -length / 2 + 0.5 + i * (length - 1) / n)
				weldTo(hull, post)
			end
		end
		-- masts + billowing sails + crow's nest
		local masts = (tier == "Brigantine") and 2 or (tier == "Galleon") and 3 or 1
		local mh = 15 + level * 0.4
		for m = 1, masts do
			local z = (masts == 1) and -1 or ((m - 1) / (masts - 1) - 0.5) * (length * 0.55)
			local mast = hp({ Name = "Mast", Shape = Enum.PartType.Cylinder, Size = Vector3.new(mh, 0.7, 0.7), Color = C.WoodDark, Material = Enum.Material.Wood, CanCollide = false })
			mast.CFrame = hull.CFrame * CFrame.new(0, deckY + mh / 2, z) * CFrame.Angles(0, 0, math.rad(90))
			weldTo(hull, mast)
			for s = 1, 2 do
				local sh = mh * (s == 1 and 0.42 or 0.3)
				local sw = width * (s == 1 and 1.05 or 0.8)
				local sy = deckY + (s == 1 and mh * 0.42 or mh * 0.8)
				local yard = hp({ Name = "Yard", Shape = Enum.PartType.Cylinder, Size = Vector3.new(sw + 1, 0.35, 0.35), Color = C.WoodDark, Material = Enum.Material.Wood, CanCollide = false })
				yard.CFrame = hull.CFrame * CFrame.new(0, sy + sh / 2, z)
				weldTo(hull, yard)
				local sail = hp({ Name = "Sail", Size = Vector3.new(sw, sh, 2.2), Color = sailColor, Material = Enum.Material.Fabric, CanCollide = false })
				sail.CFrame = hull.CFrame * CFrame.new(0, sy, z + 0.9)
				local sm = Instance.new("SpecialMesh"); sm.MeshType = Enum.MeshType.Sphere; sm.Parent = sail
				weldTo(hull, sail)
				if not blackSails then
					local st = hp({ Name = "SailStripe", Size = Vector3.new(sw * 0.98, sh * 0.16, 2.3), Color = C.SailStripe, Material = Enum.Material.Fabric, CanCollide = false })
					st.CFrame = sail.CFrame
					local sm2 = Instance.new("SpecialMesh"); sm2.MeshType = Enum.MeshType.Sphere; sm2.Parent = st
					weldTo(hull, st)
				end
			end
			if m == 1 and tier ~= "Dinghy" then
				local nest = hp({ Name = "CrowsNest", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 3, 3), Color = C.WoodDark, Material = Enum.Material.Wood, CanCollide = false })
				nest.CFrame = hull.CFrame * CFrame.new(0, deckY + mh * 0.9, z) * CFrame.Angles(0, 0, math.rad(90))
				weldTo(hull, nest)
			end
		end
		local flag = hp({ Name = "Flag", Size = Vector3.new(3.2, 2, 0.15), Color = C.Flag, Material = Enum.Material.Fabric, CanCollide = false })
		flag.CFrame = hull.CFrame * CFrame.new(1.7, deckY + mh + 0.8, -1)
		weldTo(hull, flag)
		local skull = hp({ Name = "Skull", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), Color = Color3.new(1, 1, 1), CanCollide = false })
		skull.CFrame = flag.CFrame * CFrame.new(0, 0.2, -0.15)
		weldTo(hull, skull)
		-- stern lantern
		local lantern = hp({ Name = "Lantern", Size = Vector3.new(0.7, 0.9, 0.7), Color = Color3.fromRGB(255, 220, 140), Material = Enum.Material.Neon, CanCollide = false })
		lantern.CFrame = hull.CFrame * CFrame.new(0, deckY + 4.5, length / 2 + 0.5)
		weldTo(hull, lantern)
		pointLight(lantern, Color3.fromRGB(255, 200, 110), 14, 1)
	end
	ship.PrimaryPart = hull

	-- cannons (every ship has at least one per side)
	local cannonFolder = Instance.new("Folder")
	cannonFolder.Name = "Cannons"
	cannonFolder.Parent = ship
	local cannons = Config.Stats.ShipCannons(level) + (extraCannons or 0)
	for i = 1, cannons do
		local z = ((i - 0.5) / cannons - 0.5) * (length * 0.6)
		for _, sx in ipairs({ -1, 1 }) do
			local c = hp({ Name = "Cannon", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.8, 1, 1), Color = C.Cannon, Material = Enum.Material.Metal, CanCollide = false })
			c.CFrame = hull.CFrame * CFrame.new(sx * (width / 2 + 0.6), deckY + 0.9, z)
			c:SetAttribute("Side", sx)
			c.Parent = cannonFolder
			weldTo(hull, c)
		end
	end

	-- helm + seat
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2, 0.6, 2)
	seat.Color = C.RoofRed
	seat.Material = Enum.Material.Fabric
	seat.MaxSpeed = 0
	seat.TurnSpeed = 0
	seat.Torque = 0
	seat.HeadsUpDisplay = false
	seat.CustomPhysicalProperties = floaty
	seat.CFrame = hull.CFrame * CFrame.new(0, deckY + 0.5, (tier == "Raft") and 2.5 or length / 2 - 8.5)
	seat.Parent = ship
	weldTo(hull, seat)
	local helm = hp({ Name = "Helm", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.2, 2.2), Color = C.WoodDark, Material = Enum.Material.Wood, CanCollide = false })
	helm.CFrame = seat.CFrame * CFrame.new(0, 1.6, -1.6) * CFrame.Angles(0, math.rad(90), 0)
	weldTo(hull, helm)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Sail"
	prompt.ObjectText = "Helm"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = seat

	-- drive constraints (client sets velocities while seated; server opens MaxForce when occupied)
	local att = Instance.new("Attachment")
	att.Name = "DriveAttachment"
	att.Parent = hull
	local lv = Instance.new("LinearVelocity")
	lv.Name = "Drive"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	lv.PlaneVelocity = Vector2.zero
	lv.MaxForce = 0
	lv.Parent = hull
	local av = Instance.new("AngularVelocity")
	av.Name = "Steer"
	av.Attachment0 = att
	av.RelativeTo = Enum.ActuatorRelativeTo.World
	av.AngularVelocity = Vector3.zero
	av.MaxTorque = 0
	av.Parent = hull
	local upAtt = Instance.new("Attachment")
	upAtt.Name = "UprightAttachment"
	upAtt.CFrame = CFrame.Angles(0, 0, math.rad(90))
	upAtt.Parent = hull
	local ao = Instance.new("AlignOrientation")
	ao.Name = "Upright"
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = upAtt
	ao.AlignType = Enum.AlignType.PrimaryAxisParallel
	ao.PrimaryAxis = Vector3.new(0, 1, 0)
	ao.RigidityEnabled = false
	ao.MaxTorque = 1e6
	ao.Responsiveness = 20
	ao.Parent = hull

	billboard(hull, ownerName .. "'s " .. tier, 7, 200, Color3.new(1, 1, 1), 220)
	return ship
end

----------------------------------------------------------------------
-- RIGS: pirates & villagers
----------------------------------------------------------------------
local function buildRig(name: string, hpAmount: number, shirt: Color3, pants: Color3, hatColor: Color3?, prop: string): Model
	local m = Instance.new("Model")
	m.Name = name
	local function bodyPart(n, size, color, cf)
		local p = Instance.new("Part")
		p.Name = n
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CFrame = cf
		p.Parent = m
		return p
	end
	local hrp = bodyPart("HumanoidRootPart", Vector3.new(2, 2, 1), shirt, CFrame.new(0, 3, 0))
	hrp.Transparency = 1
	hrp.CanCollide = false
	local torso = bodyPart("Torso", Vector3.new(2, 2, 1), shirt, CFrame.new(0, 3, 0))
	local head = bodyPart("Head", Vector3.new(1.4, 1.2, 1.2), C.PirateSkin, CFrame.new(0, 4.6, 0))
	local hm = Instance.new("SpecialMesh"); hm.MeshType = Enum.MeshType.Head; hm.Scale = Vector3.new(1.25, 1.25, 1.25); hm.Parent = head
	local hat = bodyPart("Hat", Vector3.new(2.4, 0.5, 1.6), hatColor or C.Flag, CFrame.new(0, 5.3, 0))
	hat.CanCollide = false
	if not hatColor then hat.Transparency = 1 end
	local lleg = bodyPart("Left Leg", Vector3.new(1, 2, 1), pants, CFrame.new(-0.5, 1, 0))
	local rleg = bodyPart("Right Leg", Vector3.new(1, 2, 1), pants, CFrame.new(0.5, 1, 0))
	local larm = bodyPart("Left Arm", Vector3.new(1, 2, 1), shirt, CFrame.new(-1.5, 3, 0))
	local rarm = bodyPart("Right Arm", Vector3.new(1, 2, 1), shirt, CFrame.new(1.5, 3, 0))
	local sword
	if prop == "sword" then
		sword = bodyPart("Sword", Vector3.new(0.3, 3.2, 0.5), Color3.fromRGB(230, 230, 240), CFrame.new(1.5, 2.8, -1.2) * CFrame.Angles(math.rad(45), 0, 0))
		sword.Material = Enum.Material.Metal
	else
		sword = bodyPart("Rod", Vector3.new(0.2, 5, 0.2), C.Trunk, CFrame.new(1.5, 4, -1.5) * CFrame.Angles(math.rad(60), 0, 0))
	end
	sword.CanCollide = false
	local face = Instance.new("Decal")
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head
	local function weld(a: BasePart, b: BasePart)
		local w = Instance.new("Motor6D")
		w.Part0 = a
		w.Part1 = b
		w.C0 = a.CFrame:Inverse() * b.CFrame
		w.Parent = a
	end
	weld(hrp, torso); weld(torso, head); weld(head, hat); weld(torso, lleg); weld(torso, rleg); weld(torso, larm); weld(torso, rarm); weld(rarm, sword)
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") then p.Anchored = false end
	end
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	hum.MaxHealth = hpAmount
	hum.Health = hpAmount
	hum.WalkSpeed = Config.Pirates.WalkSpeed
	hum.HipHeight = 0
	hum.DisplayName = name
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Subject
	hum.NameDisplayDistance = 22
	hum.HealthDisplayDistance = 22
	hum.Parent = m
	m.PrimaryPart = hrp
	return m
end

function Builders.BuildPirate(hpAmount: number): Model
	local m = buildRig("Pirate", hpAmount, C.PirateShirt, Color3.fromRGB(70, 60, 50), C.Flag, "sword")
	m:SetAttribute("IsPirate", true)
	return m
end

function Builders.BuildVillager(kind: string, hpAmount: number, gearLevel: number): Model
	local m
	if kind == "Fisher" then
		m = buildRig("Fisher", hpAmount, Color3.fromRGB(70, 160, 255), Color3.fromRGB(240, 220, 170), Color3.fromRGB(255, 220, 90), "rod")
	else
		m = buildRig("Guard", hpAmount, Color3.fromRGB(80, 200, 120), Color3.fromRGB(60, 60, 70), Color3.fromRGB(180, 180, 200), "sword")
		local sword = m:FindFirstChild("Sword") :: BasePart?
		if sword and gearLevel >= 5 then sword.Material = Enum.Material.Neon; sword.Color = Color3.fromRGB(120, 220, 255) end
	end
	m:SetAttribute("IsVillager", true)
	m:SetAttribute("Kind", kind)
	local hum = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayName = kind .. " Lv " .. gearLevel
	return m
end

function Builders.BuildCannonball(cf: CFrame, color: Color3?): Part
	local ball = part({ Name = "Cannonball", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), Color = color or C.Cannon, Material = Enum.Material.Metal, CanCollide = false, Anchored = false, CFrame = cf })
	ball.CustomPhysicalProperties = PhysicalProperties.new(2, 0.3, 0.1, 1, 1)
	local a0 = Instance.new("Attachment", ball); a0.Position = Vector3.new(0.5, 0, 0)
	local a1 = Instance.new("Attachment", ball); a1.Position = Vector3.new(-0.5, 0, 0)
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.35
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120))
	trail.Parent = ball
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxassetid://6071575925"
	smoke.Rate = 30
	smoke.Lifetime = NumberRange.new(0.4, 0.8)
	smoke.Speed = NumberRange.new(0.5)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.6) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(Color3.fromRGB(120, 120, 120))
	smoke.Parent = ball
	return ball
end

return Builders
