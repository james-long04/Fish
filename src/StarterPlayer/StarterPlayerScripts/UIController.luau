--!strict
-- UIController (ModuleScript) — StarterPlayer/StarterPlayerScripts/UIController
-- Builds the whole HUD in code: coins/income, Shop, Aquarium, Ship button, Fire button, toasts, night banner.
-- Mobile-first: big touch targets, everything anchored to screen edges.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local StoreConfig = require(ReplicatedStorage.Shared.StoreConfig)

local player = Players.LocalPlayer
local UI = {}

local FONT = Enum.Font.FredokaOne
local COL = {
	Panel = Color3.fromRGB(30, 50, 80),
	Panel2 = Color3.fromRGB(42, 70, 110),
	Accent = Color3.fromRGB(255, 200, 60),
	Blue = Color3.fromRGB(70, 190, 255),
	Green = Color3.fromRGB(90, 220, 120),
	Red = Color3.fromRGB(255, 90, 90),
	Text = Color3.new(1, 1, 1),
}

local function fmt(n: number): string
	if n >= 1e12 then return string.format("%.2fT", n / 1e12) end
	if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
	if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
	if n >= 1e4 then return string.format("%.1fK", n / 1e3) end
	return tostring(math.floor(n))
end
UI.fmt = fmt
local latestFish: { [string]: number } = {}

local function corner(p: Instance, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = p
end
local function stroke(p: Instance, color: Color3, thick: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thick or 2
	s.Parent = p
end
local function label(parent: Instance, text: string, size: UDim2, pos: UDim2, textSize: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Font = FONT
	l.Text = text
	l.TextColor3 = COL.Text
	l.TextScaled = textSize == nil
	if textSize then l.TextSize = textSize end
	l.TextStrokeTransparency = 0.6
	l.Parent = parent
	return l
end
local function button(parent: Instance, text: string, size: UDim2, pos: UDim2, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color
	b.Font = FONT
	b.Text = text
	b.TextColor3 = COL.Text
	b.TextScaled = true
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b)
	stroke(b, Color3.new(0, 0, 0), 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = b
	return b
end

local gui = Instance.new("ScreenGui")
gui.Name = "TycoonHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- Top-left: coins + income
local statPanel = Instance.new("Frame")
statPanel.Size = UDim2.fromOffset(180, 58)
statPanel.Position = UDim2.fromOffset(12, 12)
statPanel.BackgroundColor3 = COL.Panel
statPanel.BackgroundTransparency = 0.15
statPanel.Parent = gui
corner(statPanel, 14)
stroke(statPanel, COL.Accent, 3)
local coinsLabel = label(statPanel, "🪙 0", UDim2.new(1, -16, 0, 28), UDim2.fromOffset(8, 4))
coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
coinsLabel.TextColor3 = COL.Accent
local incomeLabel = label(statPanel, "+0 /s", UDim2.new(1, -16, 0, 20), UDim2.fromOffset(8, 32))
incomeLabel.TextXAlignment = Enum.TextXAlignment.Left
incomeLabel.TextColor3 = COL.Green

-- Right side: menu buttons
local menu = Instance.new("Frame")
menu.Size = UDim2.fromOffset(96, 330)
menu.Position = UDim2.new(1, -106, 0.5, -165)
menu.BackgroundTransparency = 1
menu.Parent = gui
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.Parent = menu
local storeBtn = button(menu, "💎 Store", UDim2.fromOffset(96, 40), UDim2.new(), Color3.fromRGB(255, 200, 60))
storeBtn.TextColor3 = Color3.fromRGB(50, 35, 0)
local shopBtn = button(menu, "🛒 Shop", UDim2.fromOffset(96, 40), UDim2.new(), COL.Blue)
local aqBtn = button(menu, "🐟 Tank", UDim2.fromOffset(96, 40), UDim2.new(), COL.Green)
local shipBtn = button(menu, "⛵ Ship", UDim2.fromOffset(96, 40), UDim2.new(), Color3.fromRGB(255, 150, 60))
local statsBtn = button(menu, "📜 Stats", UDim2.fromOffset(96, 40), UDim2.new(), Color3.fromRGB(170, 110, 255))
local tradeBtn = button(menu, "🤝 Trade", UDim2.fromOffset(96, 40), UDim2.new(), Color3.fromRGB(255, 120, 180))
local crewBtn = button(menu, "👥 Crew", UDim2.fromOffset(96, 40), UDim2.new(), Color3.fromRGB(90, 180, 110))

-- Bottom-right: FIRE (shown only while driving)
local fireBtn = button(gui, "💥 FIRE", UDim2.fromOffset(110, 48), UDim2.new(1, -122, 1, -70), COL.Red)
fireBtn.Visible = false
UI.FireButton = fireBtn

-- Center: REEL (shown on bite)
local reelBtn = button(gui, "🎣 REEL!", UDim2.fromOffset(150, 56), UDim2.new(0.5, -75, 0.7, 0), COL.Accent)
reelBtn.TextColor3 = Color3.fromRGB(40, 30, 0)
reelBtn.Visible = false
UI.ReelButton = reelBtn

-- Night banner
local night = label(gui, "🌙 Night — pirates incoming, defend your castle", UDim2.new(0, 360, 0, 24), UDim2.new(0.5, -180, 0, 8), 14)
night.TextScaled = false
night.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
night.BackgroundTransparency = 0.2
night.TextColor3 = Color3.fromRGB(255, 160, 80)
night.Visible = false
corner(night, 12)

-- Raid banner (driven by the character's "Raiding" attribute)
local raid = label(gui, "⚔️ Raiding — hit the castle with cutlass or cannons", UDim2.new(0, 360, 0, 24), UDim2.new(0.5, -180, 0, 36), 14)
raid.TextScaled = false
raid.BackgroundColor3 = Color3.fromRGB(90, 20, 20)
raid.BackgroundTransparency = 0.2
raid.TextColor3 = Color3.fromRGB(255, 200, 120)
raid.Visible = false
corner(raid, 12)

-- Toasts
local toastHolder = Instance.new("Frame")
toastHolder.Size = UDim2.fromOffset(300, 160)
toastHolder.Position = UDim2.new(0, 12, 1, -176)
toastHolder.BackgroundTransparency = 1
toastHolder.Parent = gui
local tl = Instance.new("UIListLayout")
tl.VerticalAlignment = Enum.VerticalAlignment.Bottom
tl.Padding = UDim.new(0, 4)
tl.HorizontalAlignment = Enum.HorizontalAlignment.Left
tl.Parent = toastHolder

function UI.Toast(text: string, color: Color3?)
	local t = label(toastHolder, text, UDim2.new(1, 0, 0, 24), UDim2.new(), 13)
	t.BackgroundColor3 = COL.Panel
	t.BackgroundTransparency = 0.25
	t.TextColor3 = color or COL.Text
	t.TextXAlignment = Enum.TextXAlignment.Left
	local tp = Instance.new("UIPadding"); tp.PaddingLeft = UDim.new(0, 8); tp.PaddingRight = UDim.new(0, 8); tp.PaddingTop = UDim.new(0, 3); tp.PaddingBottom = UDim.new(0, 3); tp.Parent = t
	t.TextWrapped = true
	t.AutomaticSize = Enum.AutomaticSize.Y
	corner(t, 10)
	task.delay(3.5, function()
		TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		task.wait(0.4)
		t:Destroy()
	end)
end

-- Generic panel
local function makePanel(title: string): (Frame, Frame)
	local p = Instance.new("Frame")
	p.Size = UDim2.fromOffset(380, 420)
	p.Position = UDim2.new(0.5, -190, 0.5, -210)
	p.BackgroundColor3 = COL.Panel
	p.Visible = false
	p.Parent = gui
	corner(p, 16)
	stroke(p, COL.Accent, 3)
	label(p, title, UDim2.new(1, -60, 0, 44), UDim2.fromOffset(16, 6)).TextXAlignment = Enum.TextXAlignment.Left
	local close = button(p, "✕", UDim2.fromOffset(44, 44), UDim2.new(1, -52, 0, 8), COL.Red)
	close.MouseButton1Click:Connect(function() p.Visible = false end)
	local body = Instance.new("ScrollingFrame")
	body.Size = UDim2.new(1, -20, 1, -66)
	body.Position = UDim2.fromOffset(10, 58)
	body.BackgroundTransparency = 1
	body.ScrollBarThickness = 6
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.Parent = p
	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 8)
	ll.Parent = body
	return p, body
end

local shopPanel, shopBody = makePanel("🛒 Upgrades")
local aqPanel, aqBody = makePanel("🐟 Your Aquarium")
local statsPanel, statsBody = makePanel("📜 Stats")
local storePanel, storeBody = makePanel("💎 Store")
local tradePanel, tradeBody = makePanel("🤝 Trade")
local crewPanel, crewBody = makePanel("👥 Island Crew")
tradePanel.Size = UDim2.fromOffset(440, 470)
tradePanel.Position = UDim2.new(0.5, -220, 0.5, -235)
storePanel.Size = UDim2.fromOffset(420, 460)
storePanel.Position = UDim2.new(0.5, -210, 0.5, -230)

local function toggle(p: Frame)
	local show = not p.Visible
	shopPanel.Visible = false; aqPanel.Visible = false; statsPanel.Visible = false; storePanel.Visible = false; tradePanel.Visible = false; crewPanel.Visible = false
	p.Visible = show
end
shopBtn.MouseButton1Click:Connect(function() toggle(shopPanel) end)
statsBtn.MouseButton1Click:Connect(function() toggle(statsPanel) end)
storeBtn.MouseButton1Click:Connect(function() toggle(storePanel) end)
crewBtn.MouseButton1Click:Connect(function() toggle(crewPanel) end)
shipBtn.MouseButton1Click:Connect(function() Remotes.SpawnShip:FireServer() end)

-- Shop rows
local shopRows: { [string]: { lvl: TextLabel, cost: TextButton } } = {}
for _, kind in ipairs(Config.UpgradeOrder) do
	local u = Config.Upgrades[kind]
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 86)
	row.BackgroundColor3 = COL.Panel2
	row.Parent = shopBody
	corner(row, 12)
	local name = label(row, u.name, UDim2.new(0.6, 0, 0, 30), UDim2.fromOffset(10, 6), 22)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local desc = label(row, u.desc, UDim2.new(0.62, 0, 0, 40), UDim2.fromOffset(10, 36), 15)
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextWrapped = true
	desc.TextColor3 = Color3.fromRGB(200, 215, 235)
	local lvl = label(row, "Lv 0", UDim2.new(0.35, 0, 0, 24), UDim2.new(0.63, 0, 0, 6), 16)
	lvl.TextColor3 = COL.Accent
	local buy = button(row, "🪙 0", UDim2.new(0.35, 0, 0, 44), UDim2.new(0.63, 0, 0, 34), COL.Green)
	buy.MouseButton1Click:Connect(function() Remotes.BuyUpgrade:FireServer(kind) end)
	local lvlUp = StoreConfig.ProductByKey("LevelUp")
	local instant = button(row, "⬆️ R$" .. (lvlUp and lvlUp.price or 0), UDim2.new(0.35, 0, 0, 22), UDim2.new(0.63, 0, 0, 80), Color3.fromRGB(255, 200, 60))
	instant.TextColor3 = Color3.fromRGB(50, 35, 0)
	instant.Visible = false
	instant.Name = "Instant"
	instant.MouseButton1Click:Connect(function() Remotes.Buy:FireServer("LevelUp", kind) end)
	row.Size = UDim2.new(1, -8, 0, 108)
	shopRows[kind] = { lvl = lvl, cost = buy }
end

local aqHeader = label(aqBody, "0 / 10 fish", UDim2.new(1, -8, 0, 30), UDim2.new(), 20)
local aqSub = label(aqBody, "Discovered 0 / 300 species", UDim2.new(1, -8, 0, 22), UDim2.new(), 14)
aqSub.TextColor3 = Color3.fromRGB(200, 215, 235)
local sellAllBtn = button(aqBody, "💰 Sell ALL fish", UDim2.new(1, -8, 0, 34), UDim2.new(), Color3.fromRGB(255, 150, 60))
local sellConfirm = false
sellAllBtn.MouseButton1Click:Connect(function()
	if sellConfirm then
		sellConfirm = false
		sellAllBtn.Text = "💰 Sell ALL fish"
		Remotes.SellFish:FireServer("ALL")
	else
		sellConfirm = true
		sellAllBtn.Text = "⚠️ Tap again to confirm (loses income!)"
		task.delay(3, function() sellConfirm = false; sellAllBtn.Text = "💰 Sell ALL fish" end)
	end
end)
local sellHint = label(aqBody, "Tap a fish to sell one. Each sells for 90s of its income.", UDim2.new(1, -8, 0, 18), UDim2.new(), 12)
sellHint.TextColor3 = Color3.fromRGB(200, 215, 235)
local aqRows: { [string]: Frame } = {}
local function fishRow(parent: Instance, name: string, rarity: string, color: Color3, onTap: ((string) -> ())?): Frame
	local row = Instance.new("Frame")
	row.Name = name
	row.Size = UDim2.new(1, -8, 0, 46)
	row.BackgroundColor3 = COL.Panel2
	row.Parent = parent
	corner(row, 10)
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(26, 26)
	dot.Position = UDim2.fromOffset(10, 10)
	dot.BackgroundColor3 = color
	dot.Parent = row
	corner(dot, 13)
	local n = label(row, name, UDim2.new(0.5, 0, 0, 24), UDim2.fromOffset(44, 2), 16)
	n.TextXAlignment = Enum.TextXAlignment.Left
	n.TextTruncate = Enum.TextTruncate.AtEnd
	local r = label(row, rarity, UDim2.new(0.5, 0, 0, 18), UDim2.fromOffset(44, 24), 12)
	r.TextXAlignment = Enum.TextXAlignment.Left
	r.TextColor3 = Config.RarityColors[rarity] or COL.Text
	local inc = label(row, "", UDim2.new(0.3, 0, 0, 18), UDim2.new(0.42, 0, 0, 24), 12)
	inc.Name = "Income"
	inc.TextXAlignment = Enum.TextXAlignment.Right
	inc.TextColor3 = COL.Green
	local c = label(row, "x0", UDim2.new(0.3, 0, 0, 24), UDim2.new(0.42, 0, 0, 2), 18)
	c.Name = "Count"
	c.TextXAlignment = Enum.TextXAlignment.Right
	if onTap then
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromScale(1, 1)
		b.BackgroundTransparency = 1
		b.Text = ""
		b.Parent = row
		b.MouseButton1Click:Connect(function() onTap(name) end)
	end
	return row
end
local refreshAquarium
refreshAquarium = function(fish: { [string]: number })
	local seen = {}
	local order = {}
	for name, count in pairs(fish) do
		if count > 0 then
			local f = Config.FishByName(name)
			if f then
				seen[name] = true
				table.insert(order, f)
				local row = aqRows[name]
				if not row then
					row = fishRow(aqBody, name, f.rarity, f.color, function(nm) Remotes.SellFish:FireServer(nm, 1) end)
					local sell = button(row, "Sell", UDim2.fromOffset(44, 24), UDim2.new(1, -50, 0, 11), Color3.fromRGB(255, 150, 60))
					sell.ZIndex = 3
					sell.MouseButton1Click:Connect(function() Remotes.SellFish:FireServer(name, 1) end)
					local sellAllOf = button(row, "All", UDim2.fromOffset(36, 24), UDim2.new(1, -92, 0, 11), Color3.fromRGB(200, 110, 50))
					sellAllOf.ZIndex = 3
					sellAllOf.MouseButton1Click:Connect(function() Remotes.SellFish:FireServer(name, 999) end)
					aqRows[name] = row
				end
				(row:FindFirstChild("Count") :: TextLabel).Text = "x" .. tostring(count);
				(row:FindFirstChild("Income") :: TextLabel).Text = "+" .. fmt(f.income) .. "/s each"
				row.LayoutOrder = -math.floor(f.income * 100)
			end
		end
	end
	for name, row in pairs(aqRows) do
		if not seen[name] then row:Destroy(); aqRows[name] = nil end
	end
end

aqBtn.MouseButton1Click:Connect(function() toggle(aqPanel); if aqPanel.Visible then refreshAquarium(latestFish) end end)

local statsText = label(statsBody, "", UDim2.new(1, -8, 0, 300), UDim2.new(), 18)
statsText.TextXAlignment = Enum.TextXAlignment.Left
statsText.TextYAlignment = Enum.TextYAlignment.Top
statsText.TextWrapped = true


----------------------------------------------------------------------
-- STORE (Robux)
----------------------------------------------------------------------
local storeInfo = nil
local storeCards: { [string]: { price: TextButton, tag: TextLabel?, card: Frame } } = {}

local function priceText(p: any): string
	return "R$ " .. tostring(p.price)
end

local function sectionHeader(parent: Instance, text: string)
	local h = label(parent, text, UDim2.new(1, -8, 0, 28), UDim2.new(), 20)
	h.TextXAlignment = Enum.TextXAlignment.Left
	h.TextColor3 = COL.Accent
end

-- Big card for passes / starter / boosts
local function storeCard(parent: Instance, item: any, height: number): Frame
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -8, 0, height)
	card.BackgroundColor3 = COL.Panel2
	card.Parent = parent
	corner(card, 12)
	local icon = label(card, item.icon, UDim2.fromOffset(44, 44), UDim2.fromOffset(8, 8), 30)
	local name = label(card, item.name, UDim2.new(1, -170, 0, 30), UDim2.fromOffset(56, 6), 20)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local hook = label(card, item.hook, UDim2.new(1, -170, 0, height - 44), UDim2.fromOffset(56, 36), 14)
	hook.TextXAlignment = Enum.TextXAlignment.Left
	hook.TextYAlignment = Enum.TextYAlignment.Top
	hook.TextWrapped = true
	hook.TextColor3 = Color3.fromRGB(205, 220, 240)
	local tag: TextLabel? = nil
	if item.tag and item.tag ~= "" then
		tag = label(card, item.tag, UDim2.fromOffset(110, 20), UDim2.new(1, -118, 0, 6), 11)
		tag.BackgroundColor3 = COL.Red
		tag.TextColor3 = COL.Text
		corner(tag, 6)
	end
	local price = button(card, priceText(item), UDim2.fromOffset(100, 40), UDim2.new(1, -108, 1, -48), COL.Green)
	price.MouseButton1Click:Connect(function() Remotes.Buy:FireServer(item.key) end)
	storeCards[item.key] = { price = price, tag = tag, card = card }
	return card
end

-- Featured: starter pack (only while eligible)
local starter = StoreConfig.ProductByKey("Starter")
local starterCard: Frame? = nil
if starter then
	sectionHeader(storeBody, "🎁 Welcome offer")
	starterCard = storeCard(storeBody, starter, 96)
	stroke(starterCard :: Frame, COL.Accent, 3)
end

sectionHeader(storeBody, "👑 Permanent perks")
for _, pass in ipairs(StoreConfig.Passes) do
	storeCard(storeBody, pass, 84)
end

sectionHeader(storeBody, "🪙 Coins")
local coinRow = Instance.new("Frame")
coinRow.Size = UDim2.new(1, -8, 0, 120)
coinRow.BackgroundTransparency = 1
coinRow.Parent = storeBody
local coinLayout = Instance.new("UIListLayout")
coinLayout.FillDirection = Enum.FillDirection.Horizontal
coinLayout.Padding = UDim.new(0, 6)
coinLayout.Parent = coinRow
local coinValueLabels: { [string]: TextLabel } = {}
for _, prod in ipairs(StoreConfig.Products) do
	if prod.kind == "coins" then
		local c = Instance.new("Frame")
		c.Size = UDim2.new(0.333, -4, 1, 0)
		c.BackgroundColor3 = (prod.key == "Coins2") and Color3.fromRGB(60, 95, 150) or COL.Panel2
		c.Parent = coinRow
		corner(c, 12)
		if prod.key == "Coins2" then stroke(c, COL.Accent, 2) end
		label(c, prod.icon, UDim2.new(1, 0, 0, 30), UDim2.fromOffset(0, 4), 24)
		local nm = label(c, prod.name, UDim2.new(1, -4, 0, 18), UDim2.fromOffset(2, 34), 12)
		local val = label(c, "…", UDim2.new(1, -4, 0, 20), UDim2.fromOffset(2, 52), 15)
		val.TextColor3 = COL.Accent
		coinValueLabels[prod.key] = val
		if prod.tag ~= "" then
			local t = label(c, prod.tag, UDim2.new(1, -8, 0, 16), UDim2.fromOffset(4, 70), 10)
			t.BackgroundColor3 = COL.Red
			corner(t, 5)
		end
		local b = button(c, priceText(prod), UDim2.new(1, -12, 0, 28), UDim2.new(0, 6, 1, -32), COL.Green)
		b.MouseButton1Click:Connect(function() Remotes.Buy:FireServer(prod.key) end)
		storeCards[prod.key] = { price = b, tag = nil, card = c }
	end
end

sectionHeader(storeBody, "⚡ Boosts & protection")
for _, prod in ipairs(StoreConfig.Products) do
	if prod.kind ~= "coins" and prod.kind ~= "starter" and prod.kind ~= "levelup" then
		storeCard(storeBody, prod, 72)
	end
end

-- Active effects strip under the coin counter
local effects = label(gui, "", UDim2.fromOffset(230, 18), UDim2.fromOffset(12, 72), 12)
effects.TextXAlignment = Enum.TextXAlignment.Left
effects.TextColor3 = COL.Accent

local function fmtTime(sec: number): string
	if sec >= 3600 then return string.format("%dh %dm", sec // 3600, (sec % 3600) // 60) end
	return string.format("%dm", math.max(1, sec // 60))
end

Remotes.StoreInfo.OnClientEvent:Connect(function(info)
	storeInfo = info
	for key, entry in pairs(storeCards) do
		local p = info.Passes[key]
		local d = info.Products[key]
		if p then
			entry.card.Visible = p.available
			if p.owned then
				entry.price.Text = "✓ OWNED"
				entry.price.BackgroundColor3 = Color3.fromRGB(110, 110, 120)
				entry.price.AutoButtonColor = false
			end
		elseif d then
			entry.card.Visible = d.available
		end
	end
	if starterCard then
		starterCard.Visible = info.StarterEligible and (storeCards.Starter.card.Visible)
		if info.StarterEligible and storeCards.Starter.tag then
			storeCards.Starter.tag.Text = "ENDS IN " .. fmtTime(info.StarterSecondsLeft)
		end
	end
	for key, lbl in pairs(coinValueLabels) do
		local v = info.CoinPackValues[key]
		if v then lbl.Text = "🪙 " .. fmt(v) end
	end
	local parts = {}
	if info.BoostMult > 1 then table.insert(parts, string.format("⚡%d× %s", info.BoostMult, fmtTime(info.BoostSecondsLeft))) end
	if info.ShieldSecondsLeft > 0 then table.insert(parts, "🛡️ " .. fmtTime(info.ShieldSecondsLeft)) end
	if info.PirateSkipNights > 0 then table.insert(parts, "🌙 " .. info.PirateSkipNights) end
	effects.Text = table.concat(parts, "   ")
	-- instant-upgrade buttons only when the product exists
	local lvlUpOK = info.Products.LevelUp and info.Products.LevelUp.available
	for _, row in ipairs(shopBody:GetChildren()) do
		local inst = row:FindFirstChild("Instant")
		if inst then (inst :: TextButton).Visible = lvlUpOK == true end
	end
end)

-- Contextual offer card (dismissable, never blocks play)
local offerCard = Instance.new("Frame")
offerCard.Size = UDim2.fromOffset(300, 110)
offerCard.Position = UDim2.new(1, -312, 1, -190)
offerCard.BackgroundColor3 = COL.Panel
offerCard.Visible = false
offerCard.Parent = gui
corner(offerCard, 14)
stroke(offerCard, COL.Accent, 3)
local offerTitle = label(offerCard, "", UDim2.new(1, -60, 0, 26), UDim2.fromOffset(10, 4), 16)
offerTitle.TextXAlignment = Enum.TextXAlignment.Left
local offerReason = label(offerCard, "", UDim2.new(1, -20, 0, 40), UDim2.fromOffset(10, 30), 12)
offerReason.TextXAlignment = Enum.TextXAlignment.Left
offerReason.TextWrapped = true
offerReason.TextColor3 = Color3.fromRGB(205, 220, 240)
local offerBuy = button(offerCard, "", UDim2.fromOffset(110, 30), UDim2.new(1, -120, 1, -36), COL.Green)
local offerNo = button(offerCard, "No thanks", UDim2.fromOffset(90, 30), UDim2.new(0, 10, 1, -36), Color3.fromRGB(90, 100, 120))
local offerClose = button(offerCard, "✕", UDim2.fromOffset(28, 28), UDim2.new(1, -34, 0, 4), COL.Red)
local currentOffer: string? = nil
offerNo.MouseButton1Click:Connect(function() offerCard.Visible = false end)
offerClose.MouseButton1Click:Connect(function() offerCard.Visible = false end)
offerBuy.MouseButton1Click:Connect(function()
	if currentOffer then Remotes.Buy:FireServer(currentOffer) end
	offerCard.Visible = false
end)
Remotes.Offer.OnClientEvent:Connect(function(key: string, reason: string)
	local item = StoreConfig.ProductByKey(key) or StoreConfig.PassByKey(key)
	if not item then return end
	currentOffer = key
	offerTitle.Text = item.icon .. " " .. item.name
	offerReason.Text = reason .. "  " .. item.hook
	offerBuy.Text = priceText(item)
	offerCard.Visible = true
	task.delay(25, function() if currentOffer == key then offerCard.Visible = false end end)
end)


----------------------------------------------------------------------
-- TRADING
----------------------------------------------------------------------
-- Player picker (shown when no trade is active)
local pickerHeader = label(tradeBody, "Pick a player to trade with", UDim2.new(1, -8, 0, 28), UDim2.new(), 18)
local pickerList = Instance.new("Frame")
pickerList.Size = UDim2.new(1, -8, 0, 0)
pickerList.AutomaticSize = Enum.AutomaticSize.Y
pickerList.BackgroundTransparency = 1
pickerList.Parent = tradeBody
local pl = Instance.new("UIListLayout"); pl.Padding = UDim.new(0, 6); pl.Parent = pickerList
local function refreshPicker()
	pickerList:ClearAllChildren()
	local l2 = Instance.new("UIListLayout"); l2.Padding = UDim.new(0, 6); l2.Parent = pickerList
	local any = false
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			any = true
			local b = button(pickerList, "🤝 " .. p.DisplayName, UDim2.new(1, 0, 0, 44), UDim2.new(), COL.Panel2)
			b.TextXAlignment = Enum.TextXAlignment.Left
			b.MouseButton1Click:Connect(function() Remotes.TradeRequest:FireServer(p.UserId) end)
		end
	end
	if not any then
		local l = label(pickerList, "Nobody else is here yet. Invite a friend!", UDim2.new(1, 0, 0, 40), UDim2.new(), 15)
		l.TextColor3 = Color3.fromRGB(200, 215, 235)
	end
end
tradeBtn.MouseButton1Click:Connect(function() toggle(tradePanel); if tradePanel.Visible then refreshPicker() end end)

-- Trade window (replaces picker while a trade is active)
local tradeWin = Instance.new("Frame")
tradeWin.Size = UDim2.new(1, -8, 0, 0)
tradeWin.AutomaticSize = Enum.AutomaticSize.Y
tradeWin.BackgroundTransparency = 1
tradeWin.Visible = false
tradeWin.Parent = tradeBody
local twl = Instance.new("UIListLayout"); twl.Padding = UDim.new(0, 6); twl.Parent = tradeWin
local tradeTitle = label(tradeWin, "", UDim2.new(1, 0, 0, 26), UDim2.new(), 18)
local tradeStatus = label(tradeWin, "", UDim2.new(1, 0, 0, 22), UDim2.new(), 14)
tradeStatus.TextColor3 = COL.Accent

local function offerBox(title: string): (Frame, Frame)
	local box = Instance.new("Frame")
	box.Size = UDim2.new(1, 0, 0, 0)
	box.AutomaticSize = Enum.AutomaticSize.Y
	box.BackgroundColor3 = Color3.fromRGB(24, 40, 66)
	box.Parent = tradeWin
	corner(box, 10)
	local h = label(box, title, UDim2.new(1, -8, 0, 24), UDim2.fromOffset(6, 0), 14)
	h.TextXAlignment = Enum.TextXAlignment.Left
	local listF = Instance.new("Frame")
	listF.Position = UDim2.fromOffset(4, 26)
	listF.Size = UDim2.new(1, -8, 0, 0)
	listF.AutomaticSize = Enum.AutomaticSize.Y
	listF.BackgroundTransparency = 1
	listF.Parent = box
	local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0, 4); ll.Parent = listF
	local pad = Instance.new("UIPadding"); pad.PaddingBottom = UDim.new(0, 30); pad.Parent = box
	return box, listF
end
local myBox, myList = offerBox("Your offer (tap to remove)")
local theirBox, theirList = offerBox("Their offer")
local confirmBtn = button(tradeWin, "✅ Confirm", UDim2.new(1, 0, 0, 46), UDim2.new(), COL.Green)
local cancelBtn = button(tradeWin, "Cancel trade", UDim2.new(1, 0, 0, 36), UDim2.new(), Color3.fromRGB(110, 110, 120))
local invHeader = label(tradeWin, "Your aquarium (tap to add)", UDim2.new(1, 0, 0, 24), UDim2.new(), 14)
local invList = Instance.new("Frame")
invList.Size = UDim2.new(1, 0, 0, 0)
invList.AutomaticSize = Enum.AutomaticSize.Y
invList.BackgroundTransparency = 1
invList.Parent = tradeWin
local il = Instance.new("UIListLayout"); il.Padding = UDim.new(0, 4); il.Parent = invList

confirmBtn.MouseButton1Click:Connect(function() Remotes.TradeConfirm:FireServer() end)
cancelBtn.MouseButton1Click:Connect(function() Remotes.TradeCancel:FireServer() end)

local function fillOffer(listF: Frame, entries, removable: boolean)
	for _, c in ipairs(listF:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	if #entries == 0 then
		local e = label(listF, "— empty —", UDim2.new(1, 0, 0, 24), UDim2.new(), 13)
		e.TextColor3 = Color3.fromRGB(150, 165, 185)
		e.Name = "Empty"
		return
	end
	for _, e in ipairs(entries) do
		local f = Config.FishByName(e.name)
		local row = fishRow(listF, e.name, e.rarity, f and f.color or COL.Text, removable and function(n) Remotes.TradeOffer:FireServer(n, -1) end or nil)
		row.Size = UDim2.new(1, 0, 0, 40);
		(row:FindFirstChild("Count") :: TextLabel).Text = "x" .. e.count;
		(row:FindFirstChild("Income") :: TextLabel).Text = "+" .. fmt(e.income) .. "/s each"
	end
end
local function fillInventory()
	for _, c in ipairs(invList:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	local items = {}
	for name, count in pairs(latestFish) do
		local f = Config.FishByName(name)
		if f and count > 0 then table.insert(items, f) end
	end
	table.sort(items, function(a, b) return a.income > b.income end)
	for _, f in ipairs(items) do
		local row = fishRow(invList, f.name, f.rarity, f.color, function(n) Remotes.TradeOffer:FireServer(n, 1) end)
		row.Size = UDim2.new(1, 0, 0, 40);
		(row:FindFirstChild("Count") :: TextLabel).Text = "x" .. latestFish[f.name];
		(row:FindFirstChild("Income") :: TextLabel).Text = "+" .. fmt(f.income) .. "/s each"
	end
end

Remotes.TradeState.OnClientEvent:Connect(function(state)
	if not state then
		tradeWin.Visible = false
		pickerHeader.Visible = true
		pickerList.Visible = true
		return
	end
	shopPanel.Visible = false; aqPanel.Visible = false; statsPanel.Visible = false; storePanel.Visible = false
	tradePanel.Visible = true
	pickerHeader.Visible = false
	pickerList.Visible = false
	tradeWin.Visible = true
	tradeTitle.Text = "Trading with " .. state.PartnerName
	fillOffer(myList, state.MyOffer, true)
	fillOffer(theirList, state.TheirOffer, false)
	fillInventory()
	if state.MyConfirmed and state.TheirConfirmed then
		tradeStatus.Text = "Both confirmed — swapping…"
	elseif state.MyConfirmed then
		tradeStatus.Text = "Waiting for " .. state.PartnerName .. " to confirm"
	elseif state.TheirConfirmed then
		tradeStatus.Text = state.PartnerName .. " has confirmed. Check the offer, then confirm."
	else
		tradeStatus.Text = "Add fish, then both players confirm. Changing an offer resets confirms."
	end
	confirmBtn.Text = state.MyConfirmed and "✓ Confirmed (tap to re-confirm)" or "✅ Confirm"
	confirmBtn.BackgroundColor3 = state.MyConfirmed and Color3.fromRGB(60, 140, 90) or COL.Green
end)

-- Incoming request popup
local reqCard = Instance.new("Frame")
reqCard.Size = UDim2.fromOffset(300, 84)
reqCard.Position = UDim2.new(1, -312, 1, -300)
reqCard.BackgroundColor3 = COL.Panel
reqCard.Visible = false
reqCard.Parent = gui
corner(reqCard, 14)
stroke(reqCard, Color3.fromRGB(255, 120, 180), 3)
local reqText = label(reqCard, "", UDim2.new(1, -16, 0, 34), UDim2.fromOffset(8, 4), 14)
local reqYes = button(reqCard, "Accept", UDim2.new(0.45, 0, 0, 30), UDim2.new(0.04, 0, 1, -36), COL.Green)
local reqNo = button(reqCard, "Decline", UDim2.new(0.45, 0, 0, 30), UDim2.new(0.51, 0, 1, -36), COL.Red)
reqYes.MouseButton1Click:Connect(function() reqCard.Visible = false; Remotes.TradeRespond:FireServer(true) end)
reqNo.MouseButton1Click:Connect(function() reqCard.Visible = false; Remotes.TradeRespond:FireServer(false) end)
Remotes.TradeIncoming.OnClientEvent:Connect(function(_, fromName: string)
	reqText.Text = "🤝 " .. fromName .. " wants to trade fish with you"
	reqCard.Visible = true
	task.delay(30, function() reqCard.Visible = false end)
end)


----------------------------------------------------------------------
-- CREW (villagers)
----------------------------------------------------------------------
local crewRows = {}
local function crewRow(icon: string, name: string, desc: string, action: string, color: Color3)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 96)
	row.BackgroundColor3 = COL.Panel2
	row.Parent = crewBody
	corner(row, 12)
	local n = label(row, icon .. " " .. name, UDim2.new(0.62, 0, 0, 30), UDim2.fromOffset(10, 6), 20)
	n.TextXAlignment = Enum.TextXAlignment.Left
	local d = label(row, desc, UDim2.new(0.62, 0, 0, 56), UDim2.fromOffset(10, 36), 13)
	d.TextXAlignment = Enum.TextXAlignment.Left
	d.TextYAlignment = Enum.TextYAlignment.Top
	d.TextWrapped = true
	d.TextColor3 = Color3.fromRGB(200, 215, 235)
	local lvl = label(row, "", UDim2.new(0.35, 0, 0, 24), UDim2.new(0.63, 0, 0, 6), 15)
	lvl.TextColor3 = COL.Accent
	local buy = button(row, "🪙 0", UDim2.new(0.35, 0, 0, 44), UDim2.new(0.63, 0, 0, 36), color)
	buy.MouseButton1Click:Connect(function() Remotes.Crew:FireServer(action) end)
	crewRows[action] = { lvl = lvl, buy = buy, desc = d }
end
crewRow("🎣", "Hire Fisher", "", "HireFisher", COL.Blue)
crewRow("🪝", "Better Rods", "", "UpgradeRods", COL.Blue)
crewRow("🛡️", "Hire Guard", "", "HireGuard", COL.Green)
crewRow("⚔️", "Better Weapons", "", "UpgradeWeapons", COL.Green)

local function refreshCrew(c, coins: number)
	if not c then return end
	local function setRow(action: string, lvlText: string, cost: number, desc: string)
		local r = crewRows[action]
		r.lvl.Text = lvlText
		r.buy.Text = "🪙 " .. fmt(cost)
		r.buy.BackgroundColor3 = (coins >= cost) and r.buy.BackgroundColor3 or Color3.fromRGB(110, 110, 120)
		if coins >= cost then r.buy.BackgroundColor3 = (action:find("Fisher") or action == "UpgradeRods") and COL.Blue or COL.Green end
		r.desc.Text = desc
	end
	setRow("HireFisher", string.format("%d/%d shore • %d/%d boats", c.ShoreFishers or 0, c.MaxShoreFishers or 50, c.Boats or 0, c.MaxBoats or 10), c.HireFisherCost,
		string.format("Lands a fish every %ds. First %d fish from the beach; after that every %d crew a copy of your ship that fishes at sea, shoots pirates and raids at night.", math.floor(c.FisherInterval), c.MaxShoreFishers or 50, c.BoatCrew or 5))
	setRow("UpgradeRods", "Lv " .. c.FisherRod, c.RodCost,
		"Faster catches and rarer fish for every fisher you own. No cap.")
	setRow("HireGuard", string.format("%d / %d", c.Guards, c.MaxPerType), c.HireGuardCost,
		string.format("Guards patrol your castle and fight pirates and raiders. %d HP, %d damage per hit.", c.GuardHP, c.GuardDamage))
	setRow("UpgradeWeapons", "Lv " .. c.GuardWeapon, c.WeaponCost,
		"+30% damage and HP for every guard. Glowing blades at Lv 5. No cap.")
end

-- Stats feed
local latest
Remotes.Stats.OnClientEvent:Connect(function(s)
	latest = s
	coinsLabel.Text = "🪙 " .. fmt(s.Coins)
	incomeLabel.Text = string.format("+%s /s", fmt(s.Income))
	for kind, row in pairs(shopRows) do
		local lvl = s.Upgrades[kind]
		row.lvl.Text = "Lv " .. lvl
		local cost = s.Costs[kind]
		row.cost.Text = "🪙 " .. fmt(cost)
		row.cost.BackgroundColor3 = (s.Coins >= cost) and COL.Green or Color3.fromRGB(110, 110, 120)
	end
	aqHeader.Text = string.format("%d / %d fish  •  %s/s", s.FishCount, s.Capacity, fmt(s.Income))
	aqSub.Text = string.format("Discovered %d / %d species", s.Discovered or 0, s.TotalSpecies or #Config.Fish)
	if aqPanel.Visible or tradePanel.Visible then refreshAquarium(s.Fish) end
	latestFish = s.Fish
	refreshCrew(s.Crew, s.Coins)
	statsText.Text = string.format(
		"Total caught: %d\nPirates slain: %d\nRaids won: %d\nShip: %s (Lv %d)\nMusket: Lv %d (%d dmg)\nCastle HP: %s / %s",
		s.TotalCaught, s.PiratesSlain, s.RaidsWon, s.ShipTier, s.Upgrades.Ship, s.Upgrades.Musket or 0, Config.Musket.Damage(s.Upgrades.Musket or 0), fmt(s.CastleHP), fmt(s.CastleMaxHP)
	)
end)

Remotes.Notify.OnClientEvent:Connect(UI.Toast)
Remotes.NightState.OnClientEvent:Connect(function(isNight) night.Visible = isNight end)
Remotes.Stats.OnClientEvent:Connect(function(s) if s.IsNight ~= nil then night.Visible = s.IsNight end end)

local function watchRaid(char: Model)
	raid.Visible = char:GetAttribute("Raiding") ~= nil
	char:GetAttributeChangedSignal("Raiding"):Connect(function()
		raid.Visible = char:GetAttribute("Raiding") ~= nil
	end)
end
if player.Character then watchRaid(player.Character) end
player.CharacterAdded:Connect(watchRaid)

return UI
