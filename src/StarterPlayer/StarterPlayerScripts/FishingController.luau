--!strict
-- FishingController (ModuleScript) — StarterPlayer/StarterPlayerScripts/FishingController
-- Shows the REEL button on a bite (tap, click, or press Space), and the catch popup.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UI = require(script.Parent.UIController)

local FishingController = {}
local player = Players.LocalPlayer
local biting = false

local function reel()
	if not biting then return end
	biting = false
	UI.ReelButton.Visible = false
	Remotes.Reel:FireServer()
end

local function popup(text: string, color: Color3)
	local gui = player.PlayerGui:FindFirstChild("TycoonHUD") :: ScreenGui
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromOffset(240, 28)
	l.Position = UDim2.new(0.5, -120, 0, 70)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = false
	l.TextSize = 15
	l.Text = text
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.2
	l.Parent = gui
	TweenService:Create(l, TweenInfo.new(1.4, Enum.EasingStyle.Quad), { Position = UDim2.new(0.5, -120, 0, 50), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.7, function() l:Destroy() end)
end

-- Catch card: compact strip at the top; name, rarity/tier, income, NEW badge
local function catchCard(r)
	local gui = player.PlayerGui:FindFirstChild("TycoonHUD") :: ScreenGui
	local color = Config.RarityColors[r.rarity] or Color3.new(1, 1, 1)
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(260, 54)
	card.Position = UDim2.new(0.5, -130, 0, 66)
	card.BackgroundColor3 = Color3.fromRGB(30, 50, 80)
	card.BackgroundTransparency = 0.15
	card.Parent = gui
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = card
	local st = Instance.new("UIStroke"); st.Color = color; st.Thickness = 2; st.Parent = card
	local function mk(text, size, pos, px, col)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = size; t.Position = pos
		t.Font = Enum.Font.FredokaOne; t.TextSize = px; t.TextColor3 = col
		t.Text = text; t.TextXAlignment = Enum.TextXAlignment.Left; t.TextTruncate = Enum.TextTruncate.AtEnd; t.Parent = card
		return t
	end
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(12, 12)
	dot.Position = UDim2.fromOffset(10, 10)
	dot.BackgroundColor3 = color
	dot.Parent = card
	local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(1, 0); dc.Parent = dot
	mk(r.name, UDim2.new(1, -36, 0, 20), UDim2.fromOffset(28, 6), 16, Color3.new(1, 1, 1))
	local line2
	if r.stored then
		line2 = string.format("%s • Tier %d • +%s/s → aquarium", r.rarity, r.tier or 0, UI.fmt(r.income))
	else
		line2 = string.format("%s • tank full, sold for %s", r.rarity, UI.fmt(r.sold or 0))
	end
	mk(line2, UDim2.new(1, -36, 0, 18), UDim2.fromOffset(28, 28), 12, color)
	if r.isNew then
		local badge = mk("NEW", UDim2.fromOffset(40, 16), UDim2.new(1, -46, 0, 6), 11, Color3.fromRGB(40, 30, 0))
		badge.TextXAlignment = Enum.TextXAlignment.Center
		badge.BackgroundTransparency = 0
		badge.BackgroundColor3 = Color3.fromRGB(255, 220, 60)
		local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 6); bc.Parent = badge
	end
	card.Position = UDim2.new(0.5, -130, 0, 50)
	TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Position = UDim2.new(0.5, -130, 0, 66) }):Play()
	task.delay((r.tier or 1) >= 5 and 3.5 or 2.2, function()
		TweenService:Create(card, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		for _, d in ipairs(card:GetDescendants()) do
			if d:IsA("TextLabel") then TweenService:Create(d, TweenInfo.new(0.35), { TextTransparency = 1, BackgroundTransparency = 1 }):Play() end
			if d:IsA("UIStroke") then TweenService:Create(d, TweenInfo.new(0.35), { Transparency = 1 }):Play() end
			if d:IsA("Frame") then TweenService:Create(d, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play() end
		end
		task.wait(0.4)
		card:Destroy()
	end)
end

function FishingController.Start()
	Remotes.Bite.OnClientEvent:Connect(function(window: number)
		biting = true
		UI.ReelButton.Visible = true
		UI.ReelButton.Size = UDim2.fromOffset(140, 50)
		TweenService:Create(UI.ReelButton, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(160, 58) }):Play()
		task.delay(window, function()
			if biting then
				biting = false
				UI.ReelButton.Visible = false
			end
		end)
	end)
	UI.ReelButton.MouseButton1Click:Connect(reel)
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.Space or input.UserInputType == Enum.UserInputType.MouseButton1 then
			if biting then reel() end
		end
	end)
	Remotes.Caught.OnClientEvent:Connect(function(r)
		if r.missed then
			popup(r.early and "Too early — line snapped!" or "It got away...", Color3.fromRGB(255, 120, 120))
			return
		end
		catchCard(r)
	end)
end

return FishingController
