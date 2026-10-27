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
	terrain:FillBlock(CFrame.new(0, y - 30, 0), Vector3.new(size, 8, size), Enum.Material.Sand) -- seabed
	terrain:FillBlock(CFrame.new(0, y - 13, 0), Vector3.new(size, 26, size), Enum.Material.Water)
	-- invisible floor + a ring wall so ships can't reach the edge of the water
	part({ Name = "SeaFloor", Size = Vector3.new(size, 4, size), CFrame = CFrame.new(0, y - 36, 0), Transparency = 1, Parent = Workspace })
	local border = Instance.new("Model")
	border.Name = "Border"
	border.Parent = Workspace
	local segs = 48
	local br = Config.World.BorderRadius
	for i = 1, segs do
		local a = (i / segs) * math.pi * 2
		local len = 2 * math.pi * br / segs + 4
		local p = part({ Name = "BorderWall", Size = Vector3.new(len, 80, 4), Transparency = 1, Parent = border, CFrame = CFrame.new(math.cos(a) * br, y + 20, math.sin(a) * br) * CFrame.Angles(0, -a + math.rad(90), 0) })
		p.CanCollide = true
	end

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
	atm.Density = 0.42       -- thick enough to melt the far edge of the sea into the sky
	atm.Offset = 0.35
	atm.Color = Color3.fromRGB(205, 232, 255)
	atm.Decay = Color3.fromRGB(120, 195, 255)
	atm.Glare = 0.35
	atm.Haze = 2.6
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
		local h = top + 24
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
	for _ = 1, 9 do
		local ang = math.random() * math.pi * 2
		local r = R * (0.8 + math.random() * 0.3)
		local s = 1.5 + math.random() * 2.5
		ellipsoid(Vector3.new(s * 1.4, s * 0.8, s), CFrame.new(center.Position + Vector3.new(math.cos(ang) * r, y + 1.4, math.sin(ang) * r)) * CFrame.Angles(0, math.random() * 3, 0), C.Rock, Enum.Material.Slate, parent, "Rock").CanCollide = true
	end
	-- bushes
	for _ = 1, 8 do
		local ang = math.random() * math.pi * 2
		local r = R * (0.5 + math.random() * 0.3)
		local pos = center.Position + Vector3.new(math.cos(ang) * r, y + 3.4, math.sin(ang) * r)
		for k = 1, 3 do
			ellipsoid(Vector3.new(2.4, 1.8, 2.4), CFrame.new(pos + Vector3.new(math.random(-8, 8) / 10, 0, math.random(-8, 8) / 10)), (k == 2) and C.LeafDark or C.Leaf, Enum.Material.Grass, parent, "Bush")
		end
	end
	-- campfire on the beach
	local fc = center * CFrame.new(14, y + 3.2, -(R - 18))
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
		cyl(Vector3.new(2.6, 2, 2), center * CFrame.new(-9 - i * 2.4, y + 4.3, -(R - 12)), C.Wood, Enum.Material.Wood, parent, "Barrel")
	end
	part({ Name = "Crate", Size = Vector3.new(2.4, 2.4, 2.4), Color = C.WoodLight, Material = Enum.Material.WoodPlanks, Parent = parent, CFrame = center * CFrame.new(-8, y + 4.2, -(R - 16)) * CFrame.Angles(0, 0.4, 0) })
end

-- Little fisherman's hut: plank walls, palm-thatch roof, a lantern
function Builders.BuildHut(cf: CFrame, parent: Instance)
	local m = Instance.new("Model")
	m.Name = "Hut"
	m.Parent = parent
	part({ Name = "Floor", Size = Vector3.new(9, 0.6, 8), Color = C.WoodLight, Material = Enum.Material.WoodPlanks, Parent = m, CFrame = cf * CFrame.new(0, 0.3, 0) })
	part({ Name = "WallBack", Size = Vector3.new(9, 6, 0.5), Color = C.Wood, Material = Enum.Material.WoodPlanks, Parent = m, CFrame = cf * CFrame.new(0, 3.3, 3.75) })
	part({ Name = "WallL", Size = Vector3.new(0.5, 6, 8), Color = C.Wood, Material = Enum.Material.WoodPlanks, Parent = m, CFrame = cf * CFrame.new(-4.25, 3.3, 0) })
	part({ Name = "WallR", Size = Vector3.new(0.5, 6, 8), Color = C.Wood, Material = Enum.Material.WoodPlanks, Parent = m, CFrame = cf * CFrame.new(4.25, 3.3, 0) })
	part({ Name = "WallFront", Size = Vector3.new(2.5, 6, 0.5), Color = C.Wood, Material = Enum.Material.WoodPlanks, Parent = m, CFrame = cf * CFrame.new(-3.25, 3.3, -3.75) })
	part({ Name = "WallFront", Size = Vector3.new(2.5, 6, 0.5), Color = C.Wood, Material = Enum.Material.WoodPlanks, Parent = m, CFrame = cf * CFrame.new(3.25, 3.3, -3.75) })
	part({ Name = "Lintel", Size = Vector3.new(4.2, 1, 0.5), Color = C.Wood, Material = Enum.Material.WoodPlanks, Parent = m, CFrame = cf * CFrame.new(0, 5.8, -3.75) })
	local win = part({ Name = "Window", Size = Vector3.new(0.3, 1.6, 2), Color = Color3.fromRGB(255, 220, 150), Material = Enum.Material.Neon, CanCollide = false, Parent = m, CFrame = cf * CFrame.new(4.3, 3.6, 1) })
	pointLight(win, Color3.fromRGB(255, 210, 120), 10, 0.7)
	for _, sx in ipairs({ -1, 1 }) do
		local r = wedge({ Name = "Roof", Size = Vector3.new(10.5, 2.6, 4.8), Color = C.LeafDark, Material = Enum.Material.Grass, Parent = m })
		r.CFrame = cf * CFrame.new(0, 7.4, sx * 2.4) * CFrame.Angles(0, sx == 1 and 0 or math.rad(180), 0)
	end
	part({ Name = "Ridge", Size = Vector3.new(10.8, 0.5, 0.8), Color = C.WoodDark, Material = Enum.Material.Wood, Parent = m, CFrame = cf * CFrame.new(0, 8.7, 0) })
	cyl(Vector3.new(2, 1.6, 1.6), cf * CFrame.new(-5.8, 1.6, -2), C.WoodDark, Enum.Material.Wood, m, "Barrel")
	return m
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

	for i = 1, 16 do
		local ang = (i / 16) * math.pi * 2 + 0.3
		local r = R * (0.68 + (i % 2) * 0.16)
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
	spawn.CFrame = facing * CFrame.new(0, y + 5, -(R - 16))
	spawn.Parent = island

	-- shoreline fishing spots for hired fishers (and a few huts)
	local spots = Instance.new("Folder")
	spots.Name = "FisherSpots"
	spots.Parent = island
	for i = 1, 10 do
		local ang = (i / 10) * math.pi * 2 + 0.15
		local pos = center + Vector3.new(math.cos(ang) * R * 0.98, y + 1.6, math.sin(ang) * R * 0.98)
		local sp = part({ Name = "Spot", Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, Parent = spots, CFrame = CFrame.lookAt(pos, Vector3.new(pos.X * 2 - center.X, pos.Y, pos.Z * 2 - center.Z)) })
		sp:SetAttribute("Index", i)
	end
	for i = 1, 3 do
		local ang = (i / 3) * math.pi * 2 + 1.2
		Builders.BuildHut(CFrame.new(center + Vector3.new(math.cos(ang) * R * 0.62, y + 3, math.sin(ang) * R * 0.62)) * CFrame.Angles(0, -ang + math.rad(90), 0), island)
	end
	Builders.BuildAquarium(island, facing * CFrame.new(-36, y + 3, -22))
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
	local W, H, D = 20, 9, 12
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
-- CASTLE — to-scale stone fortress: curtain walls with a walkway, gatehouse, four towers,
-- a two-storey keep you can walk through, banners, braziers, manned cannons on the sea wall.
----------------------------------------------------------------------
-- Points a cylinder's long (X) axis along `dir`
local function aimCylinder(pos: Vector3, dir: Vector3): CFrame
	return CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.rad(90), 0)
end
Builders.AimCylinder = aimCylinder

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

	local growth = math.min(level, 10)
	local half = 24 + growth * 0.5          -- outer wall half-width (48+ studs across)
	local wallH = 14 + growth * 0.6          -- curtain wall height
	local wallT = 5                          -- walkway width on top
	local ground = y + 3
	local base = facing * CFrame.new(0, ground, 16)  -- castle centre (behind the beach)
	local stoneMat = Enum.Material.Cobblestone
	local seaDir = base.LookVector           -- toward the dock / open sea
	local function wall(size: Vector3, cf: CFrame, color: Color3?, mat: Enum.Material?): Part
		return part({ Name = "Wall", Size = size, Color = color or C.Stone, Material = mat or stoneMat, Parent = castle, CFrame = cf })
	end
	local function trim(size: Vector3, cf: CFrame)
		local t = part({ Name = "Trim", Size = size, Color = C.StoneTrim, Material = Enum.Material.Slate, Parent = castle, CFrame = cf })
		t.CanCollide = false
		return t
	end

	-- courtyard
	part({ Name = "Courtyard", Size = Vector3.new(half * 2, 0.4, half * 2), Color = C.StoneDark, Material = Enum.Material.Slate, Parent = castle, CFrame = base * CFrame.new(0, 0.2, 0) })
	-- cobbled path from the gate to the keep
	part({ Name = "Path", Size = Vector3.new(8, 0.45, half * 2), Color = Color3.fromRGB(185, 180, 170), Material = Enum.Material.Cobblestone, Parent = castle, CFrame = base * CFrame.new(0, 0.22, 0) })

	-- curtain walls (back + sides), with a stone string-course and a slightly darker plinth
	local function curtain(size: Vector3, cf: CFrame)
		wall(size, cf)
		local plinth = size + Vector3.new((size.X > size.Z) and 0 or 0.6, -size.Y + 2.5, (size.X > size.Z) and 0.6 or 0)
		wall(plinth, cf * CFrame.new(0, -size.Y / 2 + 1.25, 0), C.StoneDark)
		local course = size + Vector3.new((size.X > size.Z) and 0 or 0.5, -size.Y + 0.6, (size.X > size.Z) and 0.5 or 0)
		trim(course, cf * CFrame.new(0, size.Y / 2 - 1.5, 0))
	end
	curtain(Vector3.new(half * 2, wallH, wallT), base * CFrame.new(0, wallH / 2, half))
	curtain(Vector3.new(wallT, wallH, half * 2), base * CFrame.new(-half, wallH / 2, 0))
	curtain(Vector3.new(wallT, wallH, half * 2), base * CFrame.new(half, wallH / 2, 0))

	-- gatehouse on the sea wall: two squat towers flanking a tall arch
	local gateW, gateH = 12, 12
	local sideLen = half - gateW / 2 - 5
	curtain(Vector3.new(sideLen, wallH, wallT), base * CFrame.new(-(gateW / 2 + 5 + sideLen / 2), wallH / 2, -half))
	curtain(Vector3.new(sideLen, wallH, wallT), base * CFrame.new((gateW / 2 + 5 + sideLen / 2), wallH / 2, -half))
	for _, sx in ipairs({ -1, 1 }) do
		local gx = sx * (gateW / 2 + 2.5)
		wall(Vector3.new(5, wallH + 4, wallT + 2), base * CFrame.new(gx, (wallH + 4) / 2, -half))
		-- arrow slits
		for k = 1, 3 do
			part({ Name = "Slit", Size = Vector3.new(0.5, 2.2, 0.3), Color = Color3.fromRGB(25, 25, 30), Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = castle, CFrame = base * CFrame.new(gx, 4 + k * 3.2, -half - wallT / 2 - 1.1) })
		end
	end
	-- lintel over the gate + arch wedges
	wall(Vector3.new(gateW + 0.4, wallH + 4 - gateH, wallT + 2), base * CFrame.new(0, gateH + (wallH + 4 - gateH) / 2, -half))
	for _, sx in ipairs({ -1, 1 }) do
		local w = wedge({ Name = "Arch", Size = Vector3.new(wallT + 2, 2.2, 2.2), Color = C.Stone, Material = stoneMat, Parent = castle })
		w.CFrame = base * CFrame.new(sx * (gateW / 2 - 1.1), gateH - 1.1, -half) * CFrame.Angles(0, sx * math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(180))
	end
	-- raised portcullis + chains + torches
	for i = -3, 3 do
		part({ Name = "Bar", Size = Vector3.new(0.3, 3, 0.3), Color = C.Iron, Material = Enum.Material.Metal, CanCollide = false, Parent = castle, CFrame = base * CFrame.new(i * 1.6, gateH + 0.2, -half - wallT / 2 - 0.2) })
	end
	part({ Name = "Bar", Size = Vector3.new(gateW - 0.5, 0.3, 0.3), Color = C.Iron, Material = Enum.Material.Metal, CanCollide = false, Parent = castle, CFrame = base * CFrame.new(0, gateH + 1.5, -half - wallT / 2 - 0.2) })
	for _, sx in ipairs({ -1, 1 }) do
		local torch = part({ Name = "Torch", Size = Vector3.new(0.6, 0.6, 0.6), Color = Color3.fromRGB(255, 190, 90), Material = Enum.Material.Neon, CanCollide = false, Parent = castle, CFrame = base * CFrame.new(sx * (gateW / 2 + 2.5), 7, -half - wallT / 2 - 1.6) })
		local f = Instance.new("Fire"); f.Size = 3; f.Heat = 5; f.Parent = torch
		pointLight(torch, Color3.fromRGB(255, 170, 80), 18, 1.3)
		cyl(Vector3.new(1.2, 0.3, 0.3), base * CFrame.new(sx * (gateW / 2 + 2.5), 6.4, -half - wallT / 2 - 1.3) * CFrame.Angles(math.rad(90), 0, 0), C.Iron, Enum.Material.Metal, castle, "TorchBracket").CanCollide = false
	end

	-- battlements (merlons) along the outer edge of every wall, plus a low inner parapet
	local step = 3
	local function merlonRun(x0: number, x1: number, z: number, alongX: boolean, h: number)
		local n = math.max(1, math.floor(math.abs(x1 - x0) / step))
		for i = 0, n do
			local t = x0 + (x1 - x0) * (i / n)
			local pos = alongX and Vector3.new(t, h + 1, z) or Vector3.new(z, h + 1, t)
			part({ Name = "Merlon", Size = Vector3.new(1.8, 2, 1.8), Color = C.StoneDark, Material = stoneMat, Parent = castle, CFrame = base * CFrame.new(pos) })
		end
	end
	local outer = half + wallT / 2 - 0.9
	merlonRun(-half, half, outer, true, wallH)
	merlonRun(-half, -(gateW / 2 + 5), -outer, true, wallH)
	merlonRun((gateW / 2 + 5), half, -outer, true, wallH)
	merlonRun(-half, half, -outer, false, wallH)
	merlonRun(-half, half, outer, false, wallH)
	merlonRun(-(gateW / 2 + 5), (gateW / 2 + 5), -outer - 1, true, wallH + 4)
	for _, d in ipairs({ { 0, 1 }, { 1, 0 }, { -1, 0 } }) do
		local inner = half - wallT / 2 + 0.3
		local size = (d[1] == 0) and Vector3.new(half * 2, 1, 0.6) or Vector3.new(0.6, 1, half * 2)
		local p = part({ Name = "Parapet", Size = size, Color = C.StoneDark, Material = stoneMat, Parent = castle, CFrame = base * CFrame.new(d[1] * inner, wallH + 0.5, d[2] * inner) })
		p.CanCollide = true
	end

	-- corner towers: tall drums with windows, a lip, conical red roofs and a banner
	for _, cx in ipairs({ -1, 1 }) do
		for _, cz in ipairs({ -1, 1 }) do
			local tcf = base * CFrame.new(cx * half, 0, cz * half)
			local th = wallH + 8
			local td = 11
			cyl(Vector3.new(th, td, td), tcf * CFrame.new(0, th / 2, 0), C.Stone, stoneMat, castle, "Tower")
			cyl(Vector3.new(3, td + 0.8, td + 0.8), tcf * CFrame.new(0, 1.5, 0), C.StoneDark, stoneMat, castle, "TowerBase")
			cyl(Vector3.new(1, td + 2, td + 2), tcf * CFrame.new(0, th + 0.4, 0), C.StoneDark, stoneMat, castle, "TowerLip")
			for k = 0, 7 do
				cyl(Vector3.new(1.6, td + 1.5 - k * 1.45, td + 1.5 - k * 1.45), tcf * CFrame.new(0, th + 1.6 + k * 1.5, 0), C.RoofRed, Enum.Material.SmoothPlastic, castle, "Roof")
			end
			-- spire + banner
			cyl(Vector3.new(6, 0.4, 0.4), tcf * CFrame.new(0, th + 15, 0), C.WoodDark, Enum.Material.Wood, castle, "Spire").CanCollide = false
			part({ Name = "Banner", Size = Vector3.new(0.15, 4, 2.6), Color = C.Gold, Material = Enum.Material.Fabric, CanCollide = false, Parent = castle, CFrame = tcf * CFrame.new(0.1, th + 15.5, 1.4) })
			-- windows on two faces, three rows
			for k = 1, 3 do
				for _, face in ipairs({ Vector3.new(cx, 0, 0), Vector3.new(0, 0, cz) }) do
					local wpos = tcf * CFrame.new(face * (td / 2 - 0.1) + Vector3.new(0, 4 + k * 4, 0))
					local win = part({ Name = "Window", Size = Vector3.new(face.X ~= 0 and 0.4 or 1.4, 2.4, face.Z ~= 0 and 0.4 or 1.4), Color = Color3.fromRGB(255, 220, 150), Material = Enum.Material.Neon, CanCollide = false, Parent = castle, CFrame = wpos })
					if k == 2 then pointLight(win, Color3.fromRGB(255, 210, 120), 12, 0.8) end
				end
			end
		end
	end

	-- ramps up to the wall walk (two, inside the side walls), with a landing
	for _, sx in ipairs({ -1, 1 }) do
		local rampLen = wallH * 2.2
		local r = wedge({ Name = "Ramp", Size = Vector3.new(4, wallH, rampLen), Color = C.StoneDark, Material = Enum.Material.Slate, Parent = castle })
		r.CFrame = base * CFrame.new(sx * (half - wallT / 2 - 2.2), wallH / 2, half - wallT / 2 - rampLen / 2) * CFrame.Angles(0, math.rad(180), 0)
		part({ Name = "Landing", Size = Vector3.new(4, 0.6, 4), Color = C.StoneDark, Material = Enum.Material.Slate, Parent = castle, CFrame = base * CFrame.new(sx * (half - wallT / 2 - 2.2), wallH - 0.3, half - wallT / 2 - rampLen - 2) })
	end

	-- braziers in the courtyard corners
	for _, sx in ipairs({ -1, 1 }) do
		local bcf = base * CFrame.new(sx * (half - 8), 0.4, -half + 10)
		cyl(Vector3.new(2.5, 1.6, 1.6), bcf * CFrame.new(0, 1.25, 0), C.Iron, Enum.Material.Metal, castle, "Brazier")
		local coals = part({ Name = "Coals", Size = Vector3.new(1.2, 0.4, 1.2), Color = Color3.fromRGB(255, 140, 60), Material = Enum.Material.Neon, CanCollide = false, Parent = castle, CFrame = bcf * CFrame.new(0, 2.6, 0) })
		local f = Instance.new("Fire"); f.Size = 4; f.Heat = 8; f.Parent = coals
		pointLight(coals, Color3.fromRGB(255, 160, 70), 20, 1.4)
	end

	-- THE KEEP: two storeys, ground hall with a doorway, upper floor via internal ramp, balcony over the courtyard
	local kW, kD = 22, 16
	local floorH = 9
	local kH = floorH * 2
	local kcf = base * CFrame.new(0, 0, half - kD / 2 - wallT - 3)
	local keep = part({ Name = "CastleRoot", Size = Vector3.new(kW, 0.4, kD), Color = Color3.fromRGB(190, 170, 150), Material = Enum.Material.WoodPlanks, Parent = castle, CFrame = kcf * CFrame.new(0, 0.4, 0) })
	castle.PrimaryPart = keep
	local doorW, doorH = 6, 8
	wall(Vector3.new(kW, kH, 1.5), kcf * CFrame.new(0, kH / 2, kD / 2))
	wall(Vector3.new(1.5, kH, kD), kcf * CFrame.new(-kW / 2, kH / 2, 0))
	wall(Vector3.new(1.5, kH, kD), kcf * CFrame.new(kW / 2, kH / 2, 0))
	wall(Vector3.new((kW - doorW) / 2, kH, 1.5), kcf * CFrame.new(-(doorW / 2 + (kW - doorW) / 4), kH / 2, -kD / 2))
	wall(Vector3.new((kW - doorW) / 2, kH, 1.5), kcf * CFrame.new((doorW / 2 + (kW - doorW) / 4), kH / 2, -kD / 2))
	wall(Vector3.new(doorW + 0.3, kH - doorH, 1.5), kcf * CFrame.new(0, doorH + (kH - doorH) / 2, -kD / 2))
	-- upper floor with a hole for the ramp
	part({ Name = "UpperFloor", Size = Vector3.new(kW - 6, 0.6, kD - 1.5), Color = Color3.fromRGB(190, 170, 150), Material = Enum.Material.WoodPlanks, Parent = castle, CFrame = kcf * CFrame.new(3, floorH, 0) })
	local kr = wedge({ Name = "KeepRamp", Size = Vector3.new(4, floorH - 0.6, kD - 2), Color = C.WoodDark, Material = Enum.Material.WoodPlanks, Parent = castle })
	kr.CFrame = kcf * CFrame.new(-kW / 2 + 2.8, (floorH - 0.6) / 2 + 0.4, 0)
	part({ Name = "UpperFloorStrip", Size = Vector3.new(6, 0.6, 3), Color = Color3.fromRGB(190, 170, 150), Material = Enum.Material.WoodPlanks, Parent = castle, CFrame = kcf * CFrame.new(-kW / 2 + 3, floorH, kD / 2 - 2) })
	-- balcony over the courtyard
	part({ Name = "Balcony", Size = Vector3.new(kW - 4, 0.6, 4), Color = C.StoneDark, Material = Enum.Material.Slate, Parent = castle, CFrame = kcf * CFrame.new(0, floorH, -kD / 2 - 2) })
	part({ Name = "BalconyRail", Size = Vector3.new(kW - 4, 1.2, 0.4), Color = C.StoneTrim, Material = Enum.Material.Slate, Parent = castle, CFrame = kcf * CFrame.new(0, floorH + 0.9, -kD / 2 - 3.9) })
	-- windows upstairs
	for _, sx in ipairs({ -1, 1 }) do
		for k = -1, 1 do
			local w = part({ Name = "Window", Size = Vector3.new(0.4, 3, 1.6), Color = Color3.fromRGB(255, 220, 150), Material = Enum.Material.Neon, CanCollide = false, Parent = castle, CFrame = kcf * CFrame.new(sx * (kW / 2), floorH + 4.5, k * 5) })
			if k == 0 then pointLight(w, Color3.fromRGB(255, 210, 120), 12, 0.8) end
		end
	end
	-- roof: pitched, red, with a ridge and the flag
	local roof = wedge({ Name = "KeepRoofA", Size = Vector3.new(kW + 2, 6, kD / 2 + 1), Color = C.RoofRed, Material = Enum.Material.SmoothPlastic, Parent = castle })
	roof.CFrame = kcf * CFrame.new(0, kH + 3, kD / 4) * CFrame.Angles(0, math.rad(180), 0)
	local roofB = wedge({ Name = "KeepRoofB", Size = Vector3.new(kW + 2, 6, kD / 2 + 1), Color = C.RoofRed, Material = Enum.Material.SmoothPlastic, Parent = castle })
	roofB.CFrame = kcf * CFrame.new(0, kH + 3, -kD / 4)
	part({ Name = "Ridge", Size = Vector3.new(kW + 2.4, 0.5, 0.8), Color = C.StoneTrim, Material = Enum.Material.Slate, Parent = castle, CFrame = kcf * CFrame.new(0, kH + 6.2, 0) })
	cyl(Vector3.new(9, 0.4, 0.4), kcf * CFrame.new(0, kH + 10, 0), C.WoodDark, Enum.Material.Wood, castle, "Pole").CanCollide = false
	part({ Name = "Flag", Size = Vector3.new(5, 3, 0.15), Color = C.Gold, Material = Enum.Material.Fabric, CanCollide = false, Parent = castle, CFrame = kcf * CFrame.new(2.6, kH + 13, 0) })
	-- inside: throne, chest, rugs, chandelier
	part({ Name = "Rug", Size = Vector3.new(8, 0.1, kD - 4), Color = Color3.fromRGB(160, 40, 50), Material = Enum.Material.Fabric, CanCollide = false, Parent = castle, CFrame = kcf * CFrame.new(0, 0.65, 0) })
	local throne = part({ Name = "Throne", Size = Vector3.new(3, 4.5, 1), Color = C.Gold, Material = Enum.Material.Metal, Parent = castle, CFrame = kcf * CFrame.new(0, 2.85, kD / 2 - 1.5) })
	part({ Name = "ThroneSeat", Size = Vector3.new(3, 1.6, 2), Color = Color3.fromRGB(160, 40, 50), Material = Enum.Material.Fabric, Parent = castle, CFrame = throne.CFrame * CFrame.new(0, -1.4, -1) })
	local chest = part({ Name = "Chest", Size = Vector3.new(3, 1.8, 1.8), Color = C.WoodDark, Material = Enum.Material.Wood, Parent = castle, CFrame = kcf * CFrame.new(kW / 2 - 3, 1.3, kD / 2 - 2) })
	part({ Name = "ChestGold", Size = Vector3.new(2.6, 0.3, 1.4), Color = C.Gold, Material = Enum.Material.Neon, CanCollide = false, Parent = castle, CFrame = chest.CFrame * CFrame.new(0, 1.05, 0) })
	local lamp = part({ Name = "KeepLamp", Size = Vector3.new(1, 1, 1), Color = Color3.fromRGB(255, 210, 120), Material = Enum.Material.Neon, CanCollide = false, Parent = castle, CFrame = kcf * CFrame.new(0, floorH - 1.5, 0) })
	pointLight(lamp, Color3.fromRGB(255, 200, 110), 22, 1.6)
	local lamp2 = part({ Name = "KeepLamp", Size = Vector3.new(1, 1, 1), Color = Color3.fromRGB(255, 210, 120), Material = Enum.Material.Neon, CanCollide = false, Parent = castle, CFrame = kcf * CFrame.new(0, kH - 1.5, 0) })
	pointLight(lamp2, Color3.fromRGB(255, 200, 110), 22, 1.6)

	-- cannons along the sea wall walk (manned via E; auto-fire at hostiles too)
	local cannons = Config.Stats.CastleCannons(level) + (extraCannons or 0)
	local cannonFolder = Instance.new("Folder")
	cannonFolder.Name = "Cannons"
	cannonFolder.Parent = castle
	local slots = {}
	for i = 1, cannons do
		local lane = math.ceil(i / 2)
		local sx = (i % 2 == 1) and -1 or 1
		table.insert(slots, sx * (gateW / 2 + 9 + (lane - 1) * 6))
	end
	for _, t in ipairs(slots) do
		if math.abs(t) < half - 3 then
			local ccf = base * CFrame.new(t, wallH + 1.2, -half + 0.3)
			part({ Name = "Carriage", Size = Vector3.new(2.2, 1.2, 3.2), Color = C.WoodDark, Material = Enum.Material.Wood, Parent = cannonFolder, CFrame = ccf })
			for _, wx in ipairs({ -1, 1 }) do
				cyl(Vector3.new(0.4, 1.4, 1.4), ccf * CFrame.new(wx * 1.3, 0, 0.4) * CFrame.Angles(0, 0, 0), C.Iron, Enum.Material.Metal, cannonFolder, "Wheel").CanCollide = false
			end
			local muzzlePos = (ccf * CFrame.new(0, 0.9, -1)).Position
			local barrel = part({ Name = "Cannon", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4.4, 1.3, 1.3), Color = C.Cannon, Material = Enum.Material.Metal, CanCollide = false, Parent = cannonFolder, CFrame = aimCylinder(muzzlePos, (seaDir + Vector3.new(0, 0.08, 0)).Unit) })
			barrel:SetAttribute("Muzzle", true)
			barrel:SetAttribute("RestCFrame", barrel.CFrame)
			barrel:SetAttribute("Pivot", muzzlePos)
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Man cannon"
			prompt.ObjectText = "Cannon"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 8
			prompt.RequiresLineOfSight = false
			prompt.Parent = barrel
			CollectionService:AddTag(barrel, "ManualCannon")
		end
	end

	-- HP bar over the keep
	local bb = Instance.new("BillboardGui")
	bb.Name = "HPBar"
	bb.Size = UDim2.fromOffset(180, 20)
	bb.StudsOffset = Vector3.new(0, kH + 16, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 260
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

	part({ Name = "GateTarget", Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, Parent = castle, CFrame = base * CFrame.new(0, 1, -half - 6) })
	part({ Name = "KeepTarget", Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, Parent = castle, CFrame = kcf * CFrame.new(0, 1, -kD / 2 - 3) })
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

-- Real R15 avatars built from a HumanoidDescription (server only). Falls back to the blocky rig if that fails.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local function avatarRig(name: string, hpAmount: number, skin: Color3, shirt: Color3, pants: Color3, hatColor: Color3?, prop: string): Model
	local m: Model? = nil
	if RunService:IsServer() then
		local ok, result = pcall(function()
			local desc = Instance.new("HumanoidDescription")
			desc.HeadColor = skin; desc.LeftArmColor = skin; desc.RightArmColor = skin
			desc.TorsoColor = shirt
			desc.LeftLegColor = pants; desc.RightLegColor = pants
			desc.HeightScale = 1
			desc.WidthScale = 1
			desc.BodyTypeScale = 0.3
			return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		end)
		if ok and result then m = result end
	end
	if not m then
		return nil :: any
	end
	local model = m :: Model
	model.Name = name
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.MaxHealth = hpAmount
	hum.Health = hpAmount
	hum.WalkSpeed = Config.Pirates.WalkSpeed
	hum.DisplayName = name
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Subject
	hum.NameDisplayDistance = 22
	hum.HealthDisplayDistance = 22
	hum.BreakJointsOnDeath = false
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = false end
	end
	local head = model:FindFirstChild("Head") :: BasePart
	-- hat (part) welded to the head
	if hatColor then
		local hat = Instance.new("Part")
		hat.Name = "Hat"
		hat.Size = (prop == "sword") and Vector3.new(2.6, 0.5, 1.8) or Vector3.new(2.2, 0.35, 2.2)
		hat.Color = hatColor
		hat.Material = Enum.Material.Fabric
		hat.CanCollide = false
		hat.Massless = true
		hat.CFrame = head.CFrame * CFrame.new(0, 0.75, 0)
		hat.Parent = model
		local w = Instance.new("WeldConstraint"); w.Part0 = head; w.Part1 = hat; w.Parent = hat
		if prop == "sword" then
			local crown = Instance.new("Part")
			crown.Name = "HatTop"
			crown.Size = Vector3.new(1.6, 0.9, 1.4)
			crown.Color = hatColor
			crown.Material = Enum.Material.Fabric
			crown.CanCollide = false
			crown.Massless = true
			crown.CFrame = hat.CFrame * CFrame.new(0, 0.6, 0)
			crown.Parent = model
			local w2 = Instance.new("WeldConstraint"); w2.Part0 = head; w2.Part1 = crown; w2.Parent = crown
		else
			local cone = Instance.new("Part")
			cone.Name = "HatTop"
			cone.Shape = Enum.PartType.Ball
			cone.Size = Vector3.new(1.3, 0.9, 1.3)
			cone.Color = hatColor
			cone.Material = Enum.Material.Fabric
			cone.CanCollide = false
			cone.Massless = true
			cone.CFrame = hat.CFrame * CFrame.new(0, 0.4, 0)
			cone.Parent = model
			local w2 = Instance.new("WeldConstraint"); w2.Part0 = head; w2.Part1 = cone; w2.Parent = cone
		end
	end
	-- held prop in the right hand
	local hand = model:FindFirstChild("RightHand") :: BasePart?
	if hand then
		local item = Instance.new("Part")
		item.CanCollide = false
		item.Massless = true
		if prop == "sword" then
			item.Name = "Sword"
			item.Size = Vector3.new(0.3, 3.4, 0.5)
			item.Color = Color3.fromRGB(230, 230, 240)
			item.Material = Enum.Material.Metal
			item.CFrame = hand.CFrame * CFrame.new(0, -1.2, 0) * CFrame.Angles(math.rad(90), 0, 0)
		else
			item.Name = "Rod"
			item.Size = Vector3.new(0.2, 6, 0.2)
			item.Color = C.Trunk
			item.Material = Enum.Material.Wood
			item.CFrame = hand.CFrame * CFrame.new(0, 1.6, -1.4) * CFrame.Angles(math.rad(35), 0, 0)
		end
		item.Parent = model
		local w = Instance.new("WeldConstraint"); w.Part0 = hand; w.Part1 = item; w.Parent = item
	end
	return model
end

function Builders.BuildPirate(hpAmount: number): Model
	local m = avatarRig("Pirate", hpAmount, Color3.fromRGB(225, 180, 140), C.PirateShirt, Color3.fromRGB(60, 50, 45), C.Flag, "sword")
	if not m then m = buildRig("Pirate", hpAmount, C.PirateShirt, Color3.fromRGB(70, 60, 50), C.Flag, "sword") end
	m:SetAttribute("IsPirate", true)
	return m
end

function Builders.BuildVillager(kind: string, hpAmount: number, gearLevel: number): Model
	local m
	if kind == "Fisher" then
		m = avatarRig("Fisher", hpAmount, Color3.fromRGB(235, 190, 150), Color3.fromRGB(70, 160, 255), Color3.fromRGB(235, 215, 165), Color3.fromRGB(255, 220, 90), "rod")
		if not m then m = buildRig("Fisher", hpAmount, Color3.fromRGB(70, 160, 255), Color3.fromRGB(240, 220, 170), Color3.fromRGB(255, 220, 90), "rod") end
	else
		m = avatarRig("Guard", hpAmount, Color3.fromRGB(225, 180, 140), Color3.fromRGB(80, 200, 120), Color3.fromRGB(60, 60, 70), Color3.fromRGB(180, 180, 200), "sword")
		if not m then m = buildRig("Guard", hpAmount, Color3.fromRGB(80, 200, 120), Color3.fromRGB(60, 60, 70), Color3.fromRGB(180, 180, 200), "sword") end
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
