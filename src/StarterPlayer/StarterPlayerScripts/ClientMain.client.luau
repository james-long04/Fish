--!strict
-- ClientMain (LocalScript) — StarterPlayer/StarterPlayerScripts/ClientMain

local UI = require(script.Parent.UIController)
local FishingController = require(script.Parent.FishingController)
local ShipController = require(script.Parent.ShipController)
local AquariumRenderer = require(script.Parent.AquariumRenderer)

FishingController.Start()
ShipController.Start()
AquariumRenderer.Start()

task.delay(2, function()
	UI.Toast("Welcome! Hold the prompt at the end of your dock to fish. Fish = money per second.", Color3.fromRGB(120, 220, 255))
end)
