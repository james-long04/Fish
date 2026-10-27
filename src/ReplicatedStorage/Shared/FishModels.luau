--!strict
-- FishModels (ModuleScript) — ReplicatedStorage/Shared/FishModels
-- Builds a creature model from a FishDatabase entry. The species name picks a body plan
-- (shark, ray, eel, octopus, turtle, crab, jellyfish, whale, seahorse, puffer, billfish, shell, fish),
-- the entry's color drives the palette, and tier drives size. Every model has:
--   PrimaryPart "Body" (faces -Z), optional "Tail" parts (wagged by the renderer), attribute "Plan".

local FishModels = {}

local PLANS = {
	{ "shark", { "shark", "megalodon", "mako", "hammerhead", "cretoxyrhina", "dogfish" } },
	{ "ray", { "ray", "manta", "skate", "sawfish" } },
	{ "eel", { "eel", "serpent", "oarfish", "snake", "helicoprion", "lamprey" } },
	{ "octopus", { "octopus", "squid", "kraken", "cuttlefish", "nautilus" } },
	{ "turtle", { "turtle", "coelacanth" } },
	{ "crab", { "crab", "lobster", "shrimp", "trilobite" } },
	{ "jelly", { "jellyfish", "jelly" } },
	{ "whale", { "whale", "orca", "narwhal", "leviathan", "basilosaurus", "livyatan", "mosasaur", "plesiosaur", "ichthyosaur", "liopleurodon", "kronosaurus", "elasmosaurus", "dunkleosteus", "titanichthys", "leedsichthys" } },
	{ "seahorse", { "seahorse" } },
	{ "puffer", { "puffer", "blobfish", "sunfish", "moonfish" } },
	{ "bill", { "swordfish", "marlin", "sailfish", "needlefish", "xiphactinus", "barracuda", "wahoo" } },
	{ "shell", { "clam", "urchin", "starfish", "periwinkle", "ammonite", "bottle", "chest", "anchor", "lantern", "hat", "comb", "duck" } },
	{ "angler", { "angler", "viperfish", "fangtooth", "dragonfish", "hatchetfish", "lanternfish", "gulper" } },
}

function FishModels.PlanFor(name: string): string
	local lower = name:lower()
	for _, entry in ipairs(PLANS) do
		for _, kw in ipairs(entry[2]) do
			if lower:find(kw, 1, true) then return entry[1] end
		end
	end
	return "fish"
end

local function hashOf(s: string): number
	local h = 0
	for i = 1, #s do h = (h * 31 + s:byte(i)) % 1000003 end
	return h
end

local function mk(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, mesh: Enum.MeshType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if mesh then
		local m = Instance.new("SpecialMesh")
		m.MeshType = mesh
		m.Parent = p
	end
	p.Parent = parent
	return p
end

local function wedgeP(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function darker(c: Color3, f: number): Color3
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, math.min(1, s * 1.05), v * f)
end
local function lighter(c: Color3, f: number): Color3
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, s * 0.5, math.min(1, v * f))
end

local function eyes(m: Model, body: Part, L: number, W: number, H: number, zOff: number)
	for _, sx in ipairs({ -1, 1 }) do
		local e = mk(m, "Eye", Vector3.new(W * 0.18, W * 0.18, W * 0.18), body.CFrame * CFrame.new(sx * W * 0.42, H * 0.15, -L * zOff), Color3.new(1, 1, 1), nil, Enum.MeshType.Sphere)
		mk(m, "Pupil", Vector3.new(W * 0.09, W * 0.09, W * 0.09), e.CFrame * CFrame.new(sx * W * 0.05, 0, -W * 0.06), Color3.new(0, 0, 0), nil, Enum.MeshType.Sphere)
	end
end

-- Tail is built as a V of two wedges, pivot at the body's rear. Named "Tail" so the renderer can wag it.
local function vTail(m: Model, body: Part, L: number, W: number, H: number, color: Color3, scale: number?)
	local s = scale or 1
	local pivot = body.CFrame * CFrame.new(0, 0, L / 2)
	local tail = mk(m, "Tail", Vector3.new(0.1, 0.1, 0.1), pivot, color)
	tail.Transparency = 1
	for _, sy in ipairs({ -1, 1 }) do
		local f = wedgeP(m, "TailFin", Vector3.new(W * 0.12, H * 0.9 * s, L * 0.35 * s), pivot * CFrame.new(0, sy * H * 0.45 * s, L * 0.17 * s) * CFrame.Angles(0, math.rad(180), 0) * CFrame.Angles(0, 0, sy == 1 and 0 or math.rad(180)), color)
		f:SetAttribute("TailOffset", pivot:ToObjectSpace(f.CFrame))
	end
end

function FishModels.Build(def: any, scale: number): Model
	local name: string = def.name
	local plan = FishModels.PlanFor(name)
	local base: Color3 = def.color
	local belly = lighter(base, 1.25)
	local dark = darker(base, 0.7)
	local h = hashOf(name)
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Plan", plan)
	local origin = CFrame.new()
	local body: Part

	if plan == "shark" then
		local L, W, H = 5 * scale, 1.3 * scale, 1.5 * scale
		body = mk(m, "Body", Vector3.new(W, H, L), origin, base, nil, Enum.MeshType.Sphere)
		mk(m, "Belly", Vector3.new(W * 0.9, H * 0.6, L * 0.9), origin * CFrame.new(0, -H * 0.2, 0), belly, nil, Enum.MeshType.Sphere)
		wedgeP(m, "Dorsal", Vector3.new(W * 0.15, H * 0.9, L * 0.3), origin * CFrame.new(0, H * 0.8, L * 0.05) * CFrame.Angles(0, math.rad(180), 0), dark)
		for _, sx in ipairs({ -1, 1 }) do
			wedgeP(m, "Pectoral", Vector3.new(W * 0.1, L * 0.3, W * 0.9), origin * CFrame.new(sx * W * 0.8, -H * 0.1, -L * 0.1) * CFrame.Angles(math.rad(-90), 0, sx * math.rad(-25)), dark)
		end
		if name:lower():find("hammer") then
			mk(m, "Hammer", Vector3.new(W * 2.6, H * 0.4, L * 0.18), origin * CFrame.new(0, 0, -L * 0.48), base)
		end
		vTail(m, body, L, W, H, dark, 1.1)
		eyes(m, body, L, W, H, 0.4)
	elseif plan == "ray" then
		local L, W, H = 3.2 * scale, 4 * scale, 0.5 * scale
		body = mk(m, "Body", Vector3.new(W, H, L), origin, base, nil, Enum.MeshType.Sphere)
		mk(m, "Belly", Vector3.new(W * 0.95, H * 0.7, L * 0.95), origin * CFrame.new(0, -H * 0.2, 0), belly, nil, Enum.MeshType.Sphere)
		local tail = mk(m, "Tail", Vector3.new(W * 0.06, H * 0.6, L * 0.9), origin * CFrame.new(0, 0, L * 0.85), dark, nil, Enum.MeshType.Sphere)
		tail:SetAttribute("TailOffset", origin:ToObjectSpace(tail.CFrame))
		eyes(m, body, L, W * 0.3, H * 2, 0.35)
	elseif plan == "eel" then
		local L, W = 6 * scale, 0.7 * scale
		local segs = 7
		body = mk(m, "Body", Vector3.new(W, W * 1.2, L / segs + 0.1), origin, base, nil, Enum.MeshType.Sphere)
		for i = 1, segs - 1 do
			local t = i / segs
			local seg = mk(m, "Seg", Vector3.new(W * (1 - t * 0.5), W * 1.2 * (1 - t * 0.4), L / segs + 0.1), origin * CFrame.new(0, 0, i * L / segs), (i % 2 == 0) and base or dark, nil, Enum.MeshType.Sphere)
			seg:SetAttribute("SegIndex", i)
			seg:SetAttribute("SegOffset", origin:ToObjectSpace(seg.CFrame))
		end
		mk(m, "Head", Vector3.new(W * 1.1, W * 1.2, W * 1.4), origin * CFrame.new(0, 0, -L / segs * 0.6), base, nil, Enum.MeshType.Sphere)
		eyes(m, body, L / segs, W, W, 0.5)
		wedgeP(m, "Dorsal", Vector3.new(W * 0.1, W * 0.6, L * 0.7), origin * CFrame.new(0, W * 0.8, L * 0.4) * CFrame.Angles(0, math.rad(180), 0), dark)
	elseif plan == "octopus" then
		local R = 1.6 * scale
		body = mk(m, "Body", Vector3.new(R * 1.3, R * 1.5, R * 1.3), origin, base, nil, Enum.MeshType.Sphere)
		local isSquid = name:lower():find("squid") or name:lower():find("cuttle")
		if isSquid then
			mk(m, "Mantle", Vector3.new(R * 0.9, R * 1.4, R * 0.9), origin * CFrame.new(0, R * 1.2, 0), base, nil, Enum.MeshType.Sphere)
			for _, sx in ipairs({ -1, 1 }) do
				wedgeP(m, "Fin", Vector3.new(R * 0.1, R * 0.8, R * 0.9), origin * CFrame.new(sx * R * 0.5, R * 1.6, 0) * CFrame.Angles(0, 0, sx * math.rad(90)), dark)
			end
		end
		for i = 1, 8 do
			local ang = (i / 8) * math.pi * 2
			local t = mk(m, "Tentacle", Vector3.new(R * 0.25, R * 1.6, R * 0.25), origin * CFrame.new(math.cos(ang) * R * 0.5, -R * 1.2, math.sin(ang) * R * 0.5) * CFrame.Angles(math.sin(ang) * 0.35, 0, -math.cos(ang) * 0.35), dark, nil, Enum.MeshType.Sphere)
			t:SetAttribute("TentIndex", i)
			t:SetAttribute("TentOffset", origin:ToObjectSpace(t.CFrame))
		end
		eyes(m, body, R, R * 1.3, R, 0.3)
	elseif plan == "turtle" then
		local L, W, H = 2.8 * scale, 2.4 * scale, 1.1 * scale
		body = mk(m, "Body", Vector3.new(W, H, L), origin, dark, nil, Enum.MeshType.Sphere)
		mk(m, "ShellTop", Vector3.new(W * 0.85, H * 0.6, L * 0.85), origin * CFrame.new(0, H * 0.3, 0), base, nil, Enum.MeshType.Sphere)
		mk(m, "Head", Vector3.new(W * 0.35, H * 0.5, L * 0.35), origin * CFrame.new(0, 0, -L * 0.6), lighter(base, 1.1), nil, Enum.MeshType.Sphere)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local f = mk(m, "Flipper", Vector3.new(W * 0.5, H * 0.2, L * 0.3), origin * CFrame.new(sx * W * 0.6, -H * 0.1, sz * L * 0.3) * CFrame.Angles(0, sx * sz * math.rad(25), 0), lighter(base, 1.1), nil, Enum.MeshType.Sphere)
				f:SetAttribute("FlipperOffset", origin:ToObjectSpace(f.CFrame))
			end
		end
		eyes(m, body, L, W * 0.35, H * 0.5, 0.65)
	elseif plan == "crab" then
		local W, L, H = 2.2 * scale, 1.5 * scale, 0.9 * scale
		body = mk(m, "Body", Vector3.new(W, H, L), origin, base, nil, Enum.MeshType.Sphere)
		for _, sx in ipairs({ -1, 1 }) do
			mk(m, "Claw", Vector3.new(W * 0.35, H * 0.6, L * 0.7), origin * CFrame.new(sx * W * 0.6, 0, -L * 0.6), dark, nil, Enum.MeshType.Sphere)
			for i = 1, 3 do
				mk(m, "Leg", Vector3.new(W * 0.08, H * 0.6, L * 0.35), origin * CFrame.new(sx * W * 0.6, -H * 0.3, -L * 0.3 + i * L * 0.3) * CFrame.Angles(0, 0, sx * math.rad(40)), dark)
			end
		end
		eyes(m, body, L, W * 0.4, H, 0.4)
		m:SetAttribute("Floor", true)
	elseif plan == "jelly" then
		local R = 1.8 * scale
		body = mk(m, "Body", Vector3.new(R * 1.4, R, R * 1.4), origin, base, Enum.Material.Neon, Enum.MeshType.Sphere)
		body.Transparency = 0.35
		mk(m, "Inner", Vector3.new(R * 0.8, R * 0.6, R * 0.8), origin * CFrame.new(0, -R * 0.1, 0), lighter(base, 1.3), Enum.Material.Neon, Enum.MeshType.Sphere).Transparency = 0.4
		for i = 1, 10 do
			local ang = (i / 10) * math.pi * 2
			local t = mk(m, "Tentacle", Vector3.new(R * 0.08, R * 1.8, R * 0.08), origin * CFrame.new(math.cos(ang) * R * 0.5, -R * 1.1, math.sin(ang) * R * 0.5), base, Enum.Material.Neon, Enum.MeshType.Sphere)
			t.Transparency = 0.3
			t:SetAttribute("TentIndex", i)
			t:SetAttribute("TentOffset", origin:ToObjectSpace(t.CFrame))
		end
		local pl = Instance.new("PointLight")
		pl.Color = base
		pl.Range = 8 * scale
		pl.Brightness = 0.6
		pl.Parent = body
		m:SetAttribute("Drift", true)
	elseif plan == "whale" then
		local L, W, H = 6.5 * scale, 2 * scale, 2 * scale
		body = mk(m, "Body", Vector3.new(W, H, L), origin, base, nil, Enum.MeshType.Sphere)
		mk(m, "Belly", Vector3.new(W * 0.9, H * 0.6, L * 0.9), origin * CFrame.new(0, -H * 0.25, 0), belly, nil, Enum.MeshType.Sphere)
		-- horizontal flukes
		local pivot = origin * CFrame.new(0, 0, L / 2)
		local tail = mk(m, "Tail", Vector3.new(0.1, 0.1, 0.1), pivot, dark)
		tail.Transparency = 1
		for _, sx in ipairs({ -1, 1 }) do
			local f = mk(m, "Fluke", Vector3.new(W * 0.9, H * 0.12, L * 0.25), pivot * CFrame.new(sx * W * 0.45, 0, L * 0.1) * CFrame.Angles(0, sx * math.rad(-20), 0), dark, nil, Enum.MeshType.Sphere)
			f:SetAttribute("TailOffset", pivot:ToObjectSpace(f.CFrame))
		end
		wedgeP(m, "Dorsal", Vector3.new(W * 0.15, H * (name:lower():find("orca") and 1.0 or 0.4), L * 0.2), origin * CFrame.new(0, H * 0.6, L * 0.1) * CFrame.Angles(0, math.rad(180), 0), dark)
		for _, sx in ipairs({ -1, 1 }) do
			mk(m, "Flipper", Vector3.new(W * 0.7, H * 0.12, L * 0.18), origin * CFrame.new(sx * W * 0.7, -H * 0.2, -L * 0.15) * CFrame.Angles(0, 0, sx * math.rad(-15)), dark, nil, Enum.MeshType.Sphere)
		end
		if name:lower():find("narwhal") then
			mk(m, "Tusk", Vector3.new(W * 0.12, W * 0.12, L * 0.6), origin * CFrame.new(0, H * 0.1, -L * 0.75), Color3.fromRGB(240, 235, 220), nil, Enum.MeshType.Cylinder)
		end
		eyes(m, body, L, W, H, 0.38)
	elseif plan == "seahorse" then
		local H, W = 2.6 * scale, 0.7 * scale
		body = mk(m, "Body", Vector3.new(W, H, W * 1.1), origin, base, nil, Enum.MeshType.Sphere)
		mk(m, "Head", Vector3.new(W * 0.8, W * 0.9, W * 1.1), origin * CFrame.new(0, H * 0.55, -W * 0.3), base, nil, Enum.MeshType.Sphere)
		mk(m, "Snout", Vector3.new(W * 0.25, W * 0.25, W * 0.9), origin * CFrame.new(0, H * 0.55, -W * 0.9), dark, nil, Enum.MeshType.Cylinder)
		local tail = mk(m, "Tail", Vector3.new(W * 0.4, H * 0.5, W * 0.4), origin * CFrame.new(0, -H * 0.6, W * 0.3) * CFrame.Angles(math.rad(-40), 0, 0), dark, nil, Enum.MeshType.Sphere)
		tail:SetAttribute("TailOffset", origin:ToObjectSpace(tail.CFrame))
		wedgeP(m, "Dorsal", Vector3.new(W * 0.1, H * 0.35, W * 0.6), origin * CFrame.new(0, 0, W * 0.7) * CFrame.Angles(0, 0, 0), lighter(base, 1.2))
		eyes(m, body, W * 0.6, W * 0.8, W * 0.2, -0.9)
		m:SetAttribute("Upright", true)
	elseif plan == "puffer" then
		local R = 1.6 * scale
		body = mk(m, "Body", Vector3.new(R, R, R * 1.1), origin, base, nil, Enum.MeshType.Sphere)
		mk(m, "Belly", Vector3.new(R * 0.9, R * 0.6, R), origin * CFrame.new(0, -R * 0.25, 0), belly, nil, Enum.MeshType.Sphere)
		if name:lower():find("puffer") then
			for i = 1, 14 do
				local a, b = (i * 2.4) % (math.pi * 2), ((i * 1.7) % 3) - 1.5
				local dir = Vector3.new(math.cos(a) * math.cos(b), math.sin(b), math.sin(a) * math.cos(b))
				mk(m, "Spike", Vector3.new(R * 0.08, R * 0.08, R * 0.35), CFrame.lookAt(origin.Position + dir * R * 0.55, origin.Position + dir * 2) , lighter(base, 1.3), nil, Enum.MeshType.Cylinder)
			end
		end
		vTail(m, body, R * 1.1, R, R, dark, 0.7)
		eyes(m, body, R * 1.1, R, R, 0.35)
	elseif plan == "bill" then
		local L, W, H = 5.5 * scale, 1 * scale, 1.4 * scale
		body = mk(m, "Body", Vector3.new(W, H, L), origin, base, nil, Enum.MeshType.Sphere)
		mk(m, "Belly", Vector3.new(W * 0.9, H * 0.55, L * 0.9), origin * CFrame.new(0, -H * 0.2, 0), belly, nil, Enum.MeshType.Sphere)
		mk(m, "Bill", Vector3.new(W * 0.18, W * 0.18, L * 0.5), origin * CFrame.new(0, 0, -L * 0.7), dark, nil, Enum.MeshType.Cylinder)
		local sailH = name:lower():find("sailfish") and H * 1.6 or H * 0.6
		wedgeP(m, "Dorsal", Vector3.new(W * 0.12, sailH, L * 0.5), origin * CFrame.new(0, H * 0.4 + sailH / 2, 0) * CFrame.Angles(0, math.rad(180), 0), dark)
		vTail(m, body, L, W, H, dark, 1.2)
		eyes(m, body, L, W, H, 0.42)
	elseif plan == "shell" then
		local R = 1.3 * scale
		local lower = name:lower()
		if lower:find("starfish") then
			body = mk(m, "Body", Vector3.new(R * 0.6, R * 0.25, R * 0.6), origin, base, nil, Enum.MeshType.Sphere)
			for i = 1, 5 do
				mk(m, "Arm", Vector3.new(R * 0.3, R * 0.2, R * 1.1), origin * CFrame.Angles(0, i / 5 * math.pi * 2, 0) * CFrame.new(0, 0, -R * 0.5), base, nil, Enum.MeshType.Sphere)
			end
		elseif lower:find("urchin") then
			body = mk(m, "Body", Vector3.new(R, R, R), origin, dark, nil, Enum.MeshType.Sphere)
			for i = 1, 18 do
				local a, b = (i * 2.4) % (math.pi * 2), ((i * 1.7) % 3) - 1.5
				local dir = Vector3.new(math.cos(a) * math.cos(b), math.sin(b), math.sin(a) * math.cos(b))
				mk(m, "Spike", Vector3.new(R * 0.06, R * 0.06, R * 0.8), CFrame.lookAt(origin.Position + dir * R * 0.5, origin.Position + dir * 2), base, nil, Enum.MeshType.Cylinder)
			end
		elseif lower:find("chest") then
			body = mk(m, "Body", Vector3.new(R * 1.6, R, R), origin, Color3.fromRGB(110, 70, 40), Enum.Material.Wood)
			mk(m, "Lid", Vector3.new(R * 1.6, R * 0.5, R), origin * CFrame.new(0, R * 0.7, 0), Color3.fromRGB(90, 55, 30), Enum.Material.Wood, Enum.MeshType.Cylinder).CFrame = origin * CFrame.new(0, R * 0.65, 0) * CFrame.Angles(0, 0, math.rad(90))
			mk(m, "Gold", Vector3.new(R * 1.3, R * 0.2, R * 0.7), origin * CFrame.new(0, R * 0.5, 0), Color3.fromRGB(255, 200, 50), Enum.Material.Neon)
		else
			body = mk(m, "Body", Vector3.new(R * 1.4, R * 0.8, R * 1.2), origin, base, nil, Enum.MeshType.Sphere)
			mk(m, "Shell2", Vector3.new(R * 1.2, R * 0.5, R), origin * CFrame.new(0, R * 0.35, 0), lighter(base, 1.2), nil, Enum.MeshType.Sphere)
		end
		m:SetAttribute("Floor", true)
	elseif plan == "angler" then
		local L, W, H = 3 * scale, 1.5 * scale, 1.7 * scale
		body = mk(m, "Body", Vector3.new(W, H, L), origin, dark, nil, Enum.MeshType.Sphere)
		mk(m, "Jaw", Vector3.new(W * 0.95, H * 0.35, L * 0.6), origin * CFrame.new(0, -H * 0.3, -L * 0.25), darker(base, 0.5), nil, Enum.MeshType.Sphere)
		for i = -2, 2 do
			mk(m, "Tooth", Vector3.new(W * 0.08, H * 0.25, W * 0.08), origin * CFrame.new(i * W * 0.17, -H * 0.2, -L * 0.5), Color3.new(1, 1, 1))
		end
		local stalk = mk(m, "Stalk", Vector3.new(W * 0.06, H * 0.9, W * 0.06), origin * CFrame.new(0, H * 0.8, -L * 0.3) * CFrame.Angles(math.rad(30), 0, 0), dark, nil, Enum.MeshType.Cylinder)
		local lure = mk(m, "Lure", Vector3.new(W * 0.3, W * 0.3, W * 0.3), origin * CFrame.new(0, H * 1.1, -L * 0.6), base, Enum.Material.Neon, Enum.MeshType.Sphere)
		local pl = Instance.new("PointLight"); pl.Color = base; pl.Range = 10 * scale; pl.Brightness = 1.2; pl.Parent = lure
		vTail(m, body, L, W, H, dark, 0.9)
		eyes(m, body, L, W, H, 0.35)
	else
		-- generic fish, three silhouettes picked by name hash
		local shapeV = h % 3
		local L, W, H
		if shapeV == 0 then L, W, H = 2.6 * scale, 0.8 * scale, 1.1 * scale        -- slim
		elseif shapeV == 1 then L, W, H = 2.2 * scale, 0.9 * scale, 1.7 * scale    -- tall (angel/butterfly)
		else L, W, H = 3 * scale, 1.1 * scale, 1.2 * scale end                     -- chunky
		body = mk(m, "Body", Vector3.new(W, H, L), origin, base, nil, Enum.MeshType.Sphere)
		mk(m, "Belly", Vector3.new(W * 0.9, H * 0.55, L * 0.9), origin * CFrame.new(0, -H * 0.22, 0), belly, nil, Enum.MeshType.Sphere)
		if (h % 5) < 2 then
			for i = -1, 1 do
				mk(m, "Stripe", Vector3.new(W * 1.02, H * 0.9, L * 0.1), origin * CFrame.new(0, 0, i * L * 0.25), lighter(base, 1.6), nil, Enum.MeshType.Sphere)
			end
		end
		wedgeP(m, "Dorsal", Vector3.new(W * 0.12, H * 0.5, L * 0.45), origin * CFrame.new(0, H * 0.6, L * 0.05) * CFrame.Angles(0, math.rad(180), 0), dark)
		for _, sx in ipairs({ -1, 1 }) do
			local f = mk(m, "Pectoral", Vector3.new(W * 0.5, H * 0.08, L * 0.25), origin * CFrame.new(sx * W * 0.55, -H * 0.1, -L * 0.1) * CFrame.Angles(0, 0, sx * math.rad(-25)), dark, nil, Enum.MeshType.Sphere)
			f:SetAttribute("FlipperOffset", origin:ToObjectSpace(f.CFrame))
		end
		vTail(m, body, L, W, H, dark)
		eyes(m, body, L, W, H, 0.4)
	end

	-- rarity glow for high tiers
	if def.tier >= 6 then
		local pl = Instance.new("PointLight")
		pl.Color = base
		pl.Range = 6 + def.tier * 0.6
		pl.Brightness = 0.5
		pl.Parent = body
		if def.tier >= 9 then body.Material = Enum.Material.Neon end
	end
	m.PrimaryPart = body
	return m
end

-- Size (scale) by tier: tier 1 ≈ 0.55, tier 12 ≈ 1.6. Big plans are shrunk to fit the tank.
function FishModels.ScaleFor(def: any): number
	local s = 0.5 + def.tier * 0.09
	local plan = FishModels.PlanFor(def.name)
	if plan == "whale" or plan == "shark" or plan == "eel" or plan == "bill" then s *= 0.6 end
	if plan == "ray" then s *= 0.7 end
	return s
end

return FishModels
