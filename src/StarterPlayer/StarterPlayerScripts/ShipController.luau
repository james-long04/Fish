--!strict
-- ShipController (ModuleScript) — StarterPlayer/StarterPlayerScripts/ShipController
-- Drives your ship while you're in its DriverSeat (W/S or ↑/↓ = sail, A/D or ←/→ = turn, Space = leave),
-- fires ship broadsides and manned castle cannons toward where the camera is looking
-- (left click, F, or the FIRE button). Shows a small controls hint while driving / manning.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UI = require(script.Parent.UIController)

local ShipController = {}
local player = Players.LocalPlayer
local manningBarrel: BasePart? = nil

-- keyboard state so arrows & WASD both work even if the seat doesn't report them
local keys = { fwd = 0, turn = 0 }
local function keyDelta(input: InputObject, down: boolean)
	local k = input.KeyCode
	if k == Enum.KeyCode.W or k == Enum.KeyCode.Up then keys.fwd = down and 1 or (keys.fwd == 1 and 0 or keys.fwd) end
	if k == Enum.KeyCode.S or k == Enum.KeyCode.Down then keys.fwd = down and -1 or (keys.fwd == -1 and 0 or keys.fwd) end
	if k == Enum.KeyCode.D or k == Enum.KeyCode.Right then keys.turn = down and 1 or (keys.turn == 1 and 0 or keys.turn) end
	if k == Enum.KeyCode.A or k == Enum.KeyCode.Left then keys.turn = down and -1 or (keys.turn == -1 and 0 or keys.turn) end
end

local function currentSeat(): VehicleSeat?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if seat and seat:IsA("VehicleSeat") and seat.Name == "DriverSeat" then return seat end
	return nil
end

local function aimDirection(): Vector3
	local cam = Workspace.CurrentCamera
	if not cam then return Vector3.new(0, 0, -1) end
	return cam.CFrame.LookVector
end

local function fire()
	Remotes.FireCannons:FireServer(aimDirection())
end

-- Controls hint + crosshair
local gui = player:WaitForChild("PlayerGui"):WaitForChild("TycoonHUD") :: ScreenGui
local hint = Instance.new("TextLabel")
hint.Size = UDim2.fromOffset(360, 22)
hint.Position = UDim2.new(0.5, -180, 1, -34)
hint.BackgroundColor3 = Color3.fromRGB(30, 50, 80)
hint.BackgroundTransparency = 0.3
hint.Font = Enum.Font.FredokaOne
hint.TextSize = 13
hint.TextColor3 = Color3.fromRGB(200, 235, 255)
hint.Text = ""
hint.Visible = false
hint.Parent = gui
local hc = Instance.new("UICorner"); hc.CornerRadius = UDim.new(0, 8); hc.Parent = hint
local cross = Instance.new("TextLabel")
cross.Size = UDim2.fromOffset(30, 30)
cross.Position = UDim2.new(0.5, -15, 0.5, -15)
cross.BackgroundTransparency = 1
cross.Font = Enum.Font.FredokaOne
cross.TextSize = 26
cross.TextColor3 = Color3.fromRGB(255, 230, 120)
cross.TextStrokeTransparency = 0.3
cross.Text = "+"
cross.Visible = false
cross.Parent = gui

function ShipController.Start()
	UI.FireButton.MouseButton1Click:Connect(fire)
	UserInputService.InputBegan:Connect(function(input, gp)
		if input.UserInputType == Enum.UserInputType.Keyboard then keyDelta(input, true) end
		if gp then return end
		local sailing = currentSeat() ~= nil
		if input.KeyCode == Enum.KeyCode.F and (sailing or manningBarrel) then fire() end
		if input.UserInputType == Enum.UserInputType.MouseButton1 and manningBarrel then fire() end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then keyDelta(input, false) end
	end)

	Remotes.ManCannon.OnClientEvent:Connect(function(barrel: BasePart?)
		manningBarrel = barrel
		cross.Visible = barrel ~= nil
		UI.FireButton.Visible = barrel ~= nil or currentSeat() ~= nil
		if barrel then
			hint.Text = "🎯 Aim with camera • Click / F / FIRE to shoot • E to step away"
			hint.Visible = true
		elseif not currentSeat() then
			hint.Visible = false
		end
	end)

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
			hint.Text = "⛵ W/S or ↑/↓ sail • A/D or ←/→ turn • F / click FIRE • Space to leave"
			hint.Visible = true
		end
		-- inputs: seat (works on mobile thumbstick) OR keyboard
		local throttle = seat.Throttle ~= 0 and seat.Throttle or keys.fwd
		local steer = seat.Steer ~= 0 and seat.Steer or keys.turn
		local speed = (ship:GetAttribute("Speed") :: number) or 24
		local forward = hull.CFrame.LookVector * -1 -- ship nose faces local -Z
		forward = Vector3.new(forward.X, 0, forward.Z).Unit
		local current = hull.AssemblyLinearVelocity
		local target = forward * (throttle * speed)
		-- smooth accelerate/decelerate, keep vertical (buoyancy) as-is
		local blended = Vector3.new(
			current.X + (target.X - current.X) * 0.08,
			current.Y,
			current.Z + (target.Z - current.Z) * 0.08
		)
		hull.AssemblyLinearVelocity = blended
		local turnRate = 0.9 * (throttle ~= 0 and 1 or 0.6)
		hull.AssemblyAngularVelocity = Vector3.new(0, -steer * turnRate, 0)
	end)
end

return ShipController
