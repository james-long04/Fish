--!strict
-- DayNightService (ModuleScript) — ServerScriptService/Services/DayNightService
-- Smoothly cycles Lighting.ClockTime. Fires NightStarted / DayStarted for PirateService.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DayNightService = {}
DayNightService.IsNight = false
DayNightService.NightStarted = Instance.new("BindableEvent")
DayNightService.DayStarted = Instance.new("BindableEvent")

local DAY_START, NIGHT_START = 6, 19 -- clock hours

function DayNightService.Start()
	local day = Config.DayNight.DaySeconds
	local night = Config.DayNight.NightSeconds
	local cycle = day + night
	local t = 0
	RunService.Heartbeat:Connect(function(dt)
		t = (t + dt) % cycle
		local hour
		if t < day then
			hour = DAY_START + (t / day) * (NIGHT_START - DAY_START)
		else
			local nt = (t - day) / night
			hour = (NIGHT_START + nt * (24 - NIGHT_START + DAY_START)) % 24
		end
		Lighting.ClockTime = hour
		local nowNight = t >= day
		if nowNight ~= DayNightService.IsNight then
			DayNightService.IsNight = nowNight
			Remotes.NightState:FireAllClients(nowNight)
			if nowNight then DayNightService.NightStarted:Fire() else DayNightService.DayStarted:Fire() end
		end
	end)
end

return DayNightService
