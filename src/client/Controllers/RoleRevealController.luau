--!strict
-- RoleRevealController: the round-start GOD vs SURVIVORS card, every round, for everyone.
-- Shown, not told: portraits flick through every player like a roulette and land on the
-- God (purple, horns), a big VS slams in, then the survivors' faces pop up on the other
-- side (green). Your own face gets a gold ring and a YOU chip, so a new player sees at a
-- glance that one player was picked to be the God and everyone else is up against them.
-- Banners and the tutorial wait while it is up (player attribute "RoleReveal").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)

local UI = script.Parent.Parent:WaitForChild("UI")
local Components = require(UI:WaitForChild("Components") :: ModuleScript)
local Theme = require(UI:WaitForChild("Theme") :: ModuleScript)
local Sound = require(UI:WaitForChild("Sound") :: ModuleScript)

local Attributes = Config.Attributes
local PR = Config.Presentation
local C = Theme.Colors
local player = Players.LocalPlayer

local RoleRevealController = {}

local GOD_PURPLE = Color3.fromRGB(170, 90, 255)
local SURVIVOR_GREEN = Color3.fromRGB(90, 230, 110)
local YOU_GOLD = Color3.fromRGB(255, 210, 60)

local started = false
local gui: ScreenGui
local layer: Frame
local running = false
local faces: { [number]: string } = {} -- userId -> headshot url

local function headshot(p: Player): string?
	local cached = faces[p.UserId]
	if cached then
		return cached
	end
	if p.UserId <= 0 then
		return nil -- Studio test players have no avatar thumbnail
	end
	local ok, url = pcall(function()
		return Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if ok and typeof(url) == "string" then
		faces[p.UserId] = url
		return url
	end
	return nil
end

local function prefetch(p: Player)
	task.spawn(headshot, p)
end

-- a round portrait: headshot (or an emoji) in a coloured ring
local function portrait(parent: Instance, size: number, color: Color3, name: string): (ImageLabel, TextLabel)
	local frame = Instance.new("ImageLabel")
	frame.Name = name
	frame.Size = UDim2.fromOffset(size, size)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(28, 30, 44)
	frame.BorderSizePixel = 0
	frame.Image = ""
	frame.ScaleType = Enum.ScaleType.Crop
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local ring = Instance.new("UIStroke")
	ring.Name = "Ring"
	ring.Thickness = math.max(3, size * 0.05)
	ring.Color = color
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = frame
	local glyph = Components.label({ Name = "Glyph", Text = "", TextSize = math.floor(size * 0.55), StrokeThickness = 0, Size = UDim2.fromScale(1, 1), Parent = frame })
	return frame, glyph
end

local function setFace(frame: ImageLabel, glyph: TextLabel, p: Player?)
	local url = if p then headshot(p) else nil
	frame.Image = url or ""
	glyph.Text = if url then "" elseif p then "🙂" else "🌪️"
end

local function youChip(parent: GuiObject)
	local chip = Components.panel({
		Name = "You",
		Size = UDim2.fromOffset(54, 24),
		Position = UDim2.new(0.5, 0, 1, 4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = YOU_GOLD,
		Parent = parent,
	})
	chip.ZIndex = 4
	Components.label({ Name = "Text", Text = "YOU", TextSize = 17, Color = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = chip })
	local ring = parent:FindFirstChild("Ring")
	if ring and ring:IsA("UIStroke") then
		ring.Color = YOU_GOLD
	end
end

local function pop(object: GuiObject, from: number)
	local scale = object:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Scale = from
	scale.Parent = object
	Components.tween(scale, Theme.Tweens.Pop, { Scale = 1 })
end

local function findGod(): Player?
	for _, p in Players:GetPlayers() do
		if p:GetAttribute(Attributes.Role) == "DisasterGod" then
			return p
		end
	end
	return nil
end

local function survivorsOf(god: Player?): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p ~= god and p:GetAttribute(Attributes.Role) == "Survivor" then
			table.insert(list, p)
		end
	end
	-- you first, so your own face is always on the card
	table.sort(list, function(a, b)
		if a == player then
			return true
		elseif b == player then
			return false
		end
		return a.Name < b.Name
	end)
	return list
end

local function reveal()
	if running then
		return
	end
	running = true
	player:SetAttribute("RoleReveal", true)
	task.wait(0.25) -- roles replicate with the phase change
	local god = findGod()
	local survivors = survivorsOf(god)
	local everyone = Players:GetPlayers()

	local band = Instance.new("CanvasGroup")
	band.Name = "RoleReveal"
	band.Size = UDim2.fromOffset(860, 250)
	band.Position = UDim2.fromScale(0.5, 0.46) -- below the top status bar and its pills
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.BackgroundTransparency = 1
	band.GroupTransparency = 0
	band.Parent = layer
	-- two halves: purple God side, green survivor side
	local left = Components.panel({ Name = "GodSide", Size = UDim2.new(0.5, -6, 1, -20), Position = UDim2.fromOffset(0, 10), Color = Color3.fromRGB(60, 30, 100), Transparency = 0.1, Parent = band })
	Components.gradient(left, Color3.fromRGB(150, 80, 240), Color3.fromRGB(70, 30, 120), 90)
	local right = Components.panel({ Name = "SurvivorSide", Size = UDim2.new(0.5, -6, 1, -20), Position = UDim2.new(0.5, 6, 0, 10), Color = Color3.fromRGB(25, 80, 45), Transparency = 0.1, Parent = band })
	Components.gradient(right, Color3.fromRGB(80, 200, 110), Color3.fromRGB(25, 90, 50), 90)
	pop(band, 0.6)

	-- God side: horns over a big portrait that rolls through everyone
	local godFace, godGlyph = portrait(left, 132, GOD_PURPLE, "God")
	godFace.Position = UDim2.new(0.5, 0, 0, 104)
	local horns = Components.label({ Name = "Horns", Text = "😈", TextSize = 46, StrokeThickness = 0, Size = UDim2.fromOffset(60, 50), Position = UDim2.new(0.5, 0, 0, 12), AnchorPoint = Vector2.new(0.5, 0.5), Parent = left })
	horns.Visible = false
	local godName = Components.label({ Name = "Name", Text = "", TextSize = 22, Color = C.Text, Size = UDim2.new(1, -16, 0, 26), Position = UDim2.new(0.5, 0, 1, -22), AnchorPoint = Vector2.new(0.5, 0.5), Parent = left })
	godName.TextTruncate = Enum.TextTruncate.AtEnd
	Components.label({ Name = "Tag", Text = "⚡ GOD", TextSize = 26, Color = Color3.fromRGB(225, 190, 255), Size = UDim2.fromOffset(120, 30), Position = UDim2.fromOffset(12, 8), XAlign = Enum.TextXAlignment.Left, Parent = left })

	-- survivor side: a grid of faces
	Components.label({ Name = "Tag", Text = "SURVIVORS 🏃", TextSize = 26, Color = Color3.fromRGB(200, 255, 210), Size = UDim2.fromOffset(200, 30), Position = UDim2.new(1, -12, 0, 8), AnchorPoint = Vector2.new(1, 0), XAlign = Enum.TextXAlignment.Right, Parent = right })
	local grid = Instance.new("Frame")
	grid.Name = "Faces"
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, -20, 1, -54)
	grid.Position = UDim2.fromOffset(10, 44)
	grid.Parent = right

	-- VS in the middle, on top of both halves
	local vs = Components.label({ Name = "VS", Text = "VS", TextSize = 92, Color = YOU_GOLD, StrokeThickness = 5, Size = UDim2.fromOffset(160, 100), Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 6, Parent = band })
	vs.Visible = false

	-- 1) roulette: flick through everyone, slowing down, then land on the God
	local began = os.clock()
	local i = math.random(1, math.max(1, #everyone))
	local gap = 0.06
	while os.clock() - began < PR.RevealRoulette and #everyone > 1 do
		i = i % #everyone + 1
		setFace(godFace, godGlyph, everyone[i])
		godName.Text = everyone[i].DisplayName
		Sound.play("Tick", 0.6, 1.4)
		task.wait(gap)
		gap *= 1.18
	end
	setFace(godFace, godGlyph, god)
	godName.Text = if god then god.DisplayName else "THE STORM"
	horns.Visible = true
	pop(godFace, 1.5)
	pop(horns, 2)
	if god == player then
		youChip(godFace)
	end
	Sound.play("Banner", 0.8)

	-- 2) VS slams in
	task.wait(0.25)
	vs.Visible = true
	pop(vs, 3)
	Sound.play("Tock", 1, 0.7)

	-- 3) the survivors pop in one by one (AI survivor bots in a low-pop round count too:
	-- the alive count is real survivors plus bots)
	local aliveCount = ReplicatedStorage:GetAttribute(Attributes.AliveCount)
	local bots = math.max(0, (if typeof(aliveCount) == "number" then aliveCount else 0) - #survivors)
	local total = #survivors + bots
	local shown = math.min(total, PR.RevealMaxFaces)
	local size = if shown <= 3 then 92 else 70
	local perRow = 3
	for n = 1, shown do
		local p: Player? = survivors[n]
		local face, glyph = portrait(grid, size, SURVIVOR_GREEN, "Face")
		local row = (n - 1) // perRow
		local col = (n - 1) % perRow
		local rows = math.ceil(shown / perRow)
		local inRow = math.min(perRow, shown - row * perRow)
		face.Position = UDim2.new(0.5, (col - (inRow - 1) / 2) * (size + 24), 0.5, (row - (rows - 1) / 2) * (size + 14) - 6)
		if p then
			setFace(face, glyph, p)
		else
			glyph.Text = "🙂" -- a bot survivor
		end
		if p == player then
			youChip(face)
		end
		pop(face, 0.2)
		Sound.play("Tick", 0.5, 1 + n * 0.08)
		task.wait(0.07)
	end
	if total > shown then
		Components.label({ Name = "More", Text = "+" .. (total - shown), TextSize = 30, Color = Color3.new(1, 1, 1), Size = UDim2.fromOffset(80, 36), Position = UDim2.new(1, -8, 1, -8), AnchorPoint = Vector2.new(1, 1), Parent = grid })
	elseif shown == 0 then
		Components.label({ Name = "Empty", Text = "🏃❔", TextSize = 54, StrokeThickness = 0, Size = UDim2.fromScale(1, 1), Parent = grid })
	end

	-- 4) hold, then lift away
	task.wait(PR.RevealHold)
	player:SetAttribute("RoleReveal", false)
	Components.tween(band, Theme.Tweens.Fade, { GroupTransparency = 1, Position = UDim2.fromScale(0.5, 0.36) }).Completed:Once(function()
		band:Destroy()
	end)
	running = false
end

function RoleRevealController.Start()
	if started then
		return
	end
	started = true
	gui = Instance.new("ScreenGui")
	gui.Name = "RoleRevealHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 6
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	layer = Components.scaledRoot(gui)

	Players.PlayerAdded:Connect(prefetch)
	for _, p in Players:GetPlayers() do
		prefetch(p)
	end

	local previous = ReplicatedStorage:GetAttribute(Attributes.RoundPhase)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.RoundPhase):Connect(function()
		local phase = ReplicatedStorage:GetAttribute(Attributes.RoundPhase)
		if phase == "Active" and previous ~= "Active" then
			task.spawn(function()
				local ok, err = pcall(reveal)
				if not ok then
					warn("[RoleReveal]", err)
					running = false
					player:SetAttribute("RoleReveal", false)
				end
			end)
		end
		previous = phase
	end)
end

return RoleRevealController
