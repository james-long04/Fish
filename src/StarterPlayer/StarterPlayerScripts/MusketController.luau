--!strict
-- MusketController (ModuleScript) — StarterPlayer/StarterPlayerScripts/MusketController
-- Equip the Musket, click to fire toward the mouse. Reload timer shown on the tool.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local MusketController = {}
local player = Players.LocalPlayer
local lastShot = 0
local musketLevel = 0

local function equippedMusket(): Tool?
	local char = player.Character
	local t = char and char:FindFirstChild("Musket")
	return t and t:IsA("Tool") and t or nil
end

local function shoot()
	local tool = equippedMusket()
	if not tool then return end
	local reload = Config.Musket.Reload(musketLevel)
	if os.clock() - lastShot < reload then return end
	lastShot = os.clock()
	local cam = Workspace.CurrentCamera
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not cam or not handle then return end
	local mouse = UserInputService:GetMouseLocation()
	local ray = cam:ViewportPointToRay(mouse.X, mouse.Y)
	-- aim at whatever is under the cursor (long ray), from the muzzle
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	local target = hit and hit.Position or (ray.Origin + ray.Direction * 500)
	local muzzle = handle:FindFirstChild("Muzzle") :: Attachment?
	local origin = muzzle and muzzle.WorldPosition or handle.Position
	Remotes.ShootMusket:FireServer(origin, (target - origin).Unit)
end

function MusketController.Start()
	Remotes.Stats.OnClientEvent:Connect(function(s)
		if s.Upgrades and s.Upgrades.Musket then musketLevel = s.Upgrades.Musket end
	end)
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			shoot()
		end
	end)
end

return MusketController
