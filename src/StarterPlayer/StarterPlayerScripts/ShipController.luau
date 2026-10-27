--!strict
-- ShipController (ModuleScript) — StarterPlayer/StarterPlayerScripts/ShipController
-- SHIP: sit at the helm. W/↑ forward, S/↓ reverse, A/D or ←/→ turn, click / F / FIRE = broadside toward camera.
-- CASTLE CANNON: press E at a cannon. A/D or ←/→ swing left/right, W/S or ↑/↓ raise/lower,
--   left click / F / FIRE to shoot, E to step away. Camera locks behind the barrel while you aim.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UI = require(script.Parent.UIController)

local ShipController = {}
local player = Players.LocalPlayer

-- key state (WASD + arrows)
local held: { [Enum.KeyCode]: boolean } = {}
local function axis(neg: { Enum.KeyCode }, pos: { Enum.KeyCode }): number
	local v = 0
	for _, k in ipairs(pos) do if held[k] then v += 1 break end end
	for _, k in ipairs(neg) do if held[k] then v -= 1 break end end
	return v
end
local FWD = { Enum.KeyCode.W, Enum.KeyCode.Up }
local BACK = { Enum.KeyCode.S, Enum.KeyCode.Down }
local LEFT = { Enum.KeyCode.A, Enum.KeyCode.Left }
local RIGHT = { Enum.KeyCode.D, Enum.KeyCode.Right }

-- cannon state
local manningBarrel: BasePart? = nil
local yaw, pitch = 0, 0.08
local lastAimSend = 0

local function currentSeat(): VehicleSeat?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if seat and seat:IsA("VehicleSeat") and seat.Name == "DriverSeat" then return seat end
	return nil
end

local function cameraLook(): Vector3
	local cam = Workspace.CurrentCamera
	return cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
end

local function fire()
	Remotes.FireCannons:FireServer(cameraLook())
end

-- HUD bits
local gui = player:WaitForChild("PlayerGui"):WaitForChild("TycoonHUD") :: ScreenGui
local hint = Instance.new("TextLabel")
hint.Size = UDim2.fromOffset(420, 22)
hint.Position = UDim2.new(0.5, -210, 1, -96)
hint.BackgroundColor3 = Color3.fromRGB(30, 50, 80)
hint.BackgroundTransparency = 0.3
hint.Font = Enum.Font.FredokaOne
hint.TextSize = 13
hint.TextColor3 = Color3.fromRGB(200, 235, 255)
hint.Visible = false
hint.Parent = gui
local hc = Instance.new("UICorner"); hc.CornerRadius = UDim.new(0, 8); hc.Parent = hint
local cross = Instance.new("TextLabel")
cross.Size = UDim2.fromOffset(40, 40)
cross.Position = UDim2.new(0.5, -20, 0.5, -20)
cross.BackgroundTransparency = 1
cross.Font = Enum.Font.FredokaOne
cross.TextSize = 32
cross.TextColor3 = Color3.fromRGB(255, 230, 120)
cross.TextStrokeTransparency = 0.3
cross.Text = "◎"
cross.Visible = false
cross.Parent = gui

local function setCannonCamera(on: boolean)
	local cam = Workspace.CurrentCamera
	if not cam then return end
	if on then
		cam.CameraType = Enum.CameraType.Scriptable
	else
		cam.CameraType = Enum.CameraType.Custom
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then cam.CameraSubject = hum end
	end
end

function ShipController.Start()
	UI.FireButton.MouseButton1Click:Connect(fire)

	UserInputService.InputBegan:Connect(function(input, gp)
		if input.UserInputType == Enum.UserInputType.Keyboard then held[input.KeyCode] = true end
		if gp then return end
		local sailing = currentSeat() ~= nil
		if input.KeyCode == Enum.KeyCode.F and (sailing or manningBarrel) then fire() end
		if input.UserInputType == Enum.UserInputType.MouseButton1 and (manningBarrel or sailing) then fire() end
		if input.UserInputType == Enum.UserInputType.Touch and manningBarrel then fire() end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then held[input.KeyCode] = nil end
	end)

	Remotes.ManCannon.OnClientEvent:Connect(function(barrel: BasePart?)
		manningBarrel = barrel
		cross.Visible = barrel ~= nil
		UI.FireButton.Visible = barrel ~= nil or currentSeat() ~= nil
		if barrel then
			yaw, pitch = 0, 0.08
			hint.Text = "🎯 A/D ←/→ turn • W/S ↑/↓ raise/lower • Click / F / FIRE shoot • E leave"
			hint.Visible = true
			setCannonCamera(true)
		else
			setCannonCamera(false)
			if not currentSeat() then hint.Visible = false end
		end
	end)

	-- Cannon aiming + camera, every frame
	RunService.RenderStepped:Connect(function(dt)
		local barrel = manningBarrel
		if not barrel or not barrel.Parent then
			if barrel then manningBarrel = nil; cross.Visible = false; setCannonCamera(false) end
			return
		end
		yaw = math.clamp(yaw + axis(LEFT, RIGHT) * -1.4 * dt, -math.rad(80), math.rad(80))
		pitch = math.clamp(pitch + axis(BACK, FWD) * 0.8 * dt, -0.2, 0.75)
		if os.clock() - lastAimSend > 0.05 then
			lastAimSend = os.clock()
			Remotes.AimCannon:FireServer(yaw, pitch)
		end
		-- camera: behind & above the barrel, looking down its length
		local cam = Workspace.CurrentCamera
		if cam then
			local pivot = barrel:GetAttribute("Pivot") :: Vector3
			local dir = barrel.CFrame.RightVector
			local flat = Vector3.new(dir.X, 0, dir.Z)
			if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
			flat = flat.Unit
			local eye = pivot - flat * 9 + Vector3.new(0, 5.5, 0)
			cam.CFrame = CFrame.lookAt(eye, pivot + dir * 40)
		end
	end)

	-- Ship driving
	local lastHull: BasePart? = nil
	RunService.Heartbeat:Connect(function()
		local seat = currentSeat()
		local ship = seat and seat:FindFirstAncestorOfClass("Model")
		local hull = ship and ship.PrimaryPart
		if not seat or not hull or ship:GetAttribute("OwnerId") ~= player.UserId then
			if lastHull then
				lastHull = nil
				if not manningBarrel then
					UI.FireButton.Visible = false
					hint.Visible = false
				end
			end
			return
		end
		if lastHull ~= hull then
			lastHull = hull
			UI.FireButton.Visible = true
			hint.Text = "⛵ W/↑ forward • S/↓ back • A/D ←/→ turn • Click / F / FIRE broadside • Space leave"
			hint.Visible = true
		end
		local throttle = (seat.Throttle ~= 0) and seat.Throttle or axis(BACK, FWD)
		local steer = (seat.Steer ~= 0) and seat.Steer or axis(LEFT, RIGHT)
		local speed = (ship:GetAttribute("Speed") :: number) or 24
		local forward = hull.CFrame.LookVector -- bow is at the hull's -Z, which is LookVector
		forward = Vector3.new(forward.X, 0, forward.Z).Unit
		local current = hull.AssemblyLinearVelocity
		local target = forward * (throttle * speed)
		hull.AssemblyLinearVelocity = Vector3.new(
			current.X + (target.X - current.X) * 0.08,
			current.Y,
			current.Z + (target.Z - current.Z) * 0.08
		)
		local turnRate = 0.9 * ((throttle ~= 0) and 1 or 0.6)
		hull.AssemblyAngularVelocity = Vector3.new(0, -steer * turnRate, 0)
	end)
end

return ShipController
