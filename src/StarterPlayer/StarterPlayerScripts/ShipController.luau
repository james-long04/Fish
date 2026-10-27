--!strict
-- ShipController (ModuleScript) — StarterPlayer/StarterPlayerScripts/ShipController
-- When you sit in your ship's DriverSeat, this drives the hull with the constraints the server built.
-- Works with WASD, arrow keys, and the mobile thumbstick (all feed VehicleSeat.Throttle / .Steer).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UI = require(script.Parent.UIController)

local ShipController = {}
local player = Players.LocalPlayer

local function currentSeat(): VehicleSeat?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if seat and seat:IsA("VehicleSeat") and seat.Name == "DriverSeat" then return seat end
	return nil
end

function ShipController.Start()
	UI.FireButton.MouseButton1Click:Connect(function() Remotes.FireCannons:FireServer() end)
	game:GetService("UserInputService").InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.F and currentSeat() then
			Remotes.FireCannons:FireServer()
		end
	end)

	local lastHull: BasePart? = nil
	RunService.Heartbeat:Connect(function()
		local seat = currentSeat()
		local ship = seat and seat:FindFirstAncestorOfClass("Model")
		local hull = ship and ship.PrimaryPart
		if not seat or not hull or ship:GetAttribute("OwnerId") ~= player.UserId then
			UI.FireButton.Visible = false
			if lastHull then
				local lv = lastHull:FindFirstChild("Drive") :: LinearVelocity?
				local av = lastHull:FindFirstChild("Steer") :: AngularVelocity?
				if lv then lv.MaxForce = 0 end
				if av then av.MaxTorque = 0 end
				lastHull = nil
			end
			return
		end
		UI.FireButton.Visible = true
		lastHull = hull
		local lv = hull:FindFirstChild("Drive") :: LinearVelocity
		local av = hull:FindFirstChild("Steer") :: AngularVelocity
		local speed = ship:GetAttribute("Speed") :: number
		local mass = hull.AssemblyMass
		if lv.MaxForce <= 0 then lv.MaxForce = mass * 80 end
		if av.MaxTorque <= 0 then av.MaxTorque = mass * 500 end
		-- throttle forward is -Z in the attachment's local frame (ship nose faces -Z)
		lv.PlaneVelocity = Vector2.new(0, -seat.Throttle * speed)
		av.AngularVelocity = Vector3.new(0, -seat.Steer * 1.2, 0)
	end)
end

return ShipController
