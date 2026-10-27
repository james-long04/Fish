--!strict
-- Remotes (ModuleScript) — ReplicatedStorage/Shared/Remotes
-- Server creates the RemoteEvents/Functions on first require; clients just look them up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"Stats",          -- server -> client: full stat snapshot
	"Bite",           -- server -> client: fish is biting, reel now
	"Reel",           -- client -> server: player tapped reel
	"Caught",         -- server -> client: result of a cast
	"BuyUpgrade",     -- client -> server
	"SpawnShip",      -- client -> server
	"FireCannons",    -- client -> server: (aimDirection: Vector3) ship broadside / manned castle cannon
	"Notify",         -- server -> client: toast message
	"NightState",     -- server -> client: true = night
	"RaidResult",     -- server -> client
	"StoreInfo",      -- server -> client: prices, owned passes, active boosts, starter eligibility
	"Buy",            -- client -> server: (key, extra) prompt a pass or product purchase
	"Offer",          -- server -> client: contextual offer card (key, reason)
	"TradeRequest",   -- client -> server: (targetUserId)
	"TradeIncoming",  -- server -> client: (fromUserId, fromName)
	"TradeRespond",   -- client -> server: (accept: boolean)
	"TradeOffer",     -- client -> server: (fishName, delta)
	"TradeConfirm",   -- client -> server
	"TradeCancel",    -- client -> server
	"TradeState",     -- server -> client: (state table or nil)
	"Crew",           -- client -> server: ("HireFisher" | "HireGuard" | "UpgradeRods" | "UpgradeWeapons")
	"ManCannon",      -- server -> client: (barrel or nil) you are now manning / left a castle cannon
	"AimCannon",      -- client -> server: (yaw, pitch) in radians while manning
}

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if not folder then
	if RunService:IsServer() then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	else
		folder = ReplicatedStorage:WaitForChild("Remotes")
	end
end

local Remotes = {}
for _, name in ipairs(EVENTS) do
	local ev = folder:FindFirstChild(name)
	if not ev then
		if RunService:IsServer() then
			ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = folder
		else
			ev = folder:WaitForChild(name)
		end
	end
	Remotes[name] = ev :: RemoteEvent
end

return Remotes
