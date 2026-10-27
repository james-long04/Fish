--!strict
-- AquariumRenderer (ModuleScript) — StarterPlayer/StarterPlayerScripts/AquariumRenderer
-- Reads each Aquarium's "FishJSON" attribute (set by the server) and renders real creature models
-- swimming inside the tank, animated locally. Only tanks near the camera are rendered.

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local FishModels = require(ReplicatedStorage.Shared.FishModels)

local Renderer = {}
local MAX_PER_TANK = 28
local RENDER_DISTANCE = 160

type Swimmer = {
	model: Model,
	plan: string,
	center: Vector3, -- orbit centre inside tank
	radiusX: number, radiusZ: number,
	yBase: number,
	phase: number,
	speed: number,
	yaw: number,
	tailParts: { { part: BasePart, offset: CFrame } },
	segParts: { { part: BasePart, offset: CFrame, idx: number } },
	tentParts: { { part: BasePart, offset: CFrame, idx: number } },
	flipParts: { { part: BasePart, offset: CFrame } },
	tailPivot: BasePart?,
	lastPos: Vector3,
	floor: boolean,
	drift: boolean,
	upright: boolean,
}

local tanks: { [Model]: { swimmers: { Swimmer }, json: string, water: BasePart, folder: Folder } } = {}

local function collect(model: Model, s: Swimmer)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local to = d:GetAttribute("TailOffset")
			if to then table.insert(s.tailParts, { part = d, offset = to }) end
			local so = d:GetAttribute("SegOffset")
			if so then table.insert(s.segParts, { part = d, offset = so, idx = d:GetAttribute("SegIndex") }) end
			local tn = d:GetAttribute("TentOffset")
			if tn then table.insert(s.tentParts, { part = d, offset = tn, idx = d:GetAttribute("TentIndex") }) end
			local fo = d:GetAttribute("FlipperOffset")
			if fo then table.insert(s.flipParts, { part = d, offset = fo }) end
			if d.Name == "Tail" and d.Transparency == 1 then s.tailPivot = d end
		end
	end
end

local function buildTank(aq: Model)
	local water = aq:FindFirstChild("Water") :: BasePart?
	local folder = aq:FindFirstChild("FishDisplay") :: Folder?
	if not water or not folder then return end
	local json = aq:GetAttribute("FishJSON") or "[]"
	local entry = tanks[aq]
	if entry and entry.json == json then return end
	-- clear
	if entry then
		for _, s in ipairs(entry.swimmers) do s.model:Destroy() end
	end
	folder:ClearAllChildren()
	local list = {}
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
	if ok and type(decoded) == "table" then list = decoded end
	local inner = water:GetAttribute("Inner") :: Vector3
	local swimmers = {}
	local shown = 0
	for _, item in ipairs(list) do
		local def = Config.FishByName(item.name)
		if def then
			for _ = 1, math.min(item.count, 4) do
				if shown >= MAX_PER_TANK then break end
				shown += 1
				local scale = FishModels.ScaleFor(def)
				local model = FishModels.Build(def, scale)
				model.Parent = folder
				local plan = model:GetAttribute("Plan") :: string
				local floor = model:GetAttribute("Floor") == true
				local s: Swimmer = {
					model = model, plan = plan,
					center = Vector3.new((math.random() - 0.5) * inner.X * 0.5, 0, (math.random() - 0.5) * inner.Z * 0.5),
					radiusX = inner.X * (0.2 + math.random() * 0.25),
					radiusZ = inner.Z * (0.2 + math.random() * 0.25),
					yBase = floor and (-inner.Y / 2 + 0.3 * scale + 0.3) or ((math.random() - 0.5) * inner.Y * 0.6),
					phase = math.random() * math.pi * 2,
					speed = (0.25 + math.random() * 0.25) * (plan == "whale" and 0.5 or 1) * (plan == "shark" and 1.2 or 1),
					yaw = 0, tailParts = {}, segParts = {}, tentParts = {}, flipParts = {}, tailPivot = nil,
					lastPos = Vector3.zero, floor = floor,
					drift = model:GetAttribute("Drift") == true,
					upright = model:GetAttribute("Upright") == true,
				}
				collect(model, s)
				-- name label
				local bb = Instance.new("BillboardGui")
				bb.Size = UDim2.fromOffset(140, 30)
				bb.StudsOffset = Vector3.new(0, 1.2 * scale + 0.8, 0)
				bb.MaxDistance = 28
				bb.AlwaysOnTop = false
				bb.Parent = model.PrimaryPart
				local t = Instance.new("TextLabel")
				t.Size = UDim2.fromScale(1, 1)
				t.BackgroundTransparency = 1
				t.Font = Enum.Font.FredokaOne
				t.TextScaled = true
				t.TextColor3 = Config.RarityColors[def.rarity] or Color3.new(1, 1, 1)
				t.TextStrokeTransparency = 0.4
				t.Text = string.format("%s  +%s/s", def.name, tostring(def.income))
				t.Parent = bb
				table.insert(swimmers, s)
			end
		end
	end
	tanks[aq] = { swimmers = swimmers, json = json, water = water, folder = folder }
end

local function dropTank(aq: Model)
	local entry = tanks[aq]
	if not entry then return end
	for _, s in ipairs(entry.swimmers) do s.model:Destroy() end
	tanks[aq] = nil
end

local function step(t: number, dt: number)
	local cam = Workspace.CurrentCamera
	if not cam then return end
	for aq, entry in pairs(tanks) do
		local w = entry.water
		if not w.Parent then dropTank(aq) continue end
		local base = w.CFrame
		for _, s in ipairs(entry.swimmers) do
			local a = t * s.speed + s.phase
			local localPos
			if s.floor then
				localPos = Vector3.new(s.center.X + math.sin(a * 0.3) * 0.6, s.yBase, s.center.Z + math.cos(a * 0.3) * 0.6)
			elseif s.drift then
				localPos = Vector3.new(s.center.X + math.sin(a * 0.5) * 1.5, s.yBase + math.sin(a * 1.1) * 0.8, s.center.Z + math.cos(a * 0.4) * 1.5)
			else
				localPos = Vector3.new(s.center.X + math.cos(a) * s.radiusX, s.yBase + math.sin(a * 0.7) * 0.6, s.center.Z + math.sin(a) * s.radiusZ)
			end
			local worldPos = base:PointToWorldSpace(localPos)
			local dir = worldPos - s.lastPos
			s.lastPos = worldPos
			local cf
			if s.floor or s.drift then
				cf = CFrame.new(worldPos) * CFrame.Angles(0, s.phase + (s.drift and math.sin(a * 0.3) * 0.5 or 0), 0)
			elseif dir.Magnitude > 0.001 then
				local flat = Vector3.new(dir.X, 0, dir.Z)
				if flat.Magnitude > 0.001 then
					-- models face -Z, so look from pos toward pos - dir... we want body's -Z along dir
					cf = CFrame.lookAt(worldPos, worldPos + flat.Unit)
					if s.upright then cf = cf * CFrame.Angles(0, 0, math.sin(a * 2) * 0.1) end
				else
					cf = CFrame.new(worldPos)
				end
			else
				cf = CFrame.new(worldPos)
			end
			s.model:PivotTo(cf)
			-- tail wag
			local wag = math.sin(t * 6 * s.speed * 2 + s.phase) * 0.35
			if s.tailPivot then
				local pivotCF = s.tailPivot.CFrame * CFrame.Angles(0, wag, 0)
				for _, tp in ipairs(s.tailParts) do tp.part.CFrame = pivotCF * tp.offset end
			else
				for _, tp in ipairs(s.tailParts) do tp.part.CFrame = cf * tp.offset * CFrame.Angles(0, wag * 0.6, 0) end
			end
			-- eel body wave
			for _, sp in ipairs(s.segParts) do
				local off = math.sin(t * 5 + s.phase - sp.idx * 0.7) * 0.25 * sp.idx * 0.3
				sp.part.CFrame = cf * sp.offset * CFrame.new(off, 0, 0)
			end
			-- tentacle sway
			for _, tp in ipairs(s.tentParts) do
				local sway = math.sin(t * 2 + tp.idx) * 0.25
				tp.part.CFrame = cf * tp.offset * CFrame.Angles(sway, 0, sway * 0.5)
			end
			-- flipper flap
			for _, fp in ipairs(s.flipParts) do
				fp.part.CFrame = cf * fp.offset * CFrame.Angles(0, 0, math.sin(t * 4 + s.phase) * 0.3)
			end
		end
	end
end

function Renderer.Start()
	local islands = Workspace:WaitForChild("Islands")
	local function scan()
		local cam = Workspace.CurrentCamera
		if not cam then return end
		local camPos = cam.CFrame.Position
		for _, island in ipairs(islands:GetChildren()) do
			local aq = island:FindFirstChild("Aquarium") :: Model?
			if aq then
				local water = aq:FindFirstChild("Water") :: BasePart?
				if water then
					if (water.Position - camPos).Magnitude <= RENDER_DISTANCE then
						buildTank(aq)
					else
						dropTank(aq)
					end
				end
			end
		end
	end
	task.spawn(function()
		while true do
			scan()
			task.wait(1.5)
		end
	end)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		step(os.clock(), dt)
	end)
end

return Renderer
