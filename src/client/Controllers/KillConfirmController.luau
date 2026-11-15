--!strict
-- KillConfirmController: the God's satisfying kill confirm, on top of the feed line and the
-- coin popup. When a disaster the God cast eliminates a survivor (ScoringService sends
-- ClientEffect "GodKill" to the God only):
--   * a hitmarker X snaps onto the victim's spot on screen (centre if off-screen), white
--     then red, popping in and fading out,
--   * a heavy hitmarker crack with a low coin "ka-ching" under it, pitched up for streaks,
--   * a kill chip under the crosshair: "☠ ELIMINATED <NAME>", and DOUBLE / TRIPLE /
--     MULTI KILL when kills land close together,
--   * a quick purple flash at the screen edges.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local UI = script.Parent.Parent:WaitForChild("UI")
local Components = require(UI:WaitForChild("Components") :: ModuleScript)
local Theme = require(UI:WaitForChild("Theme") :: ModuleScript)
local Sound = require(UI:WaitForChild("Sound") :: ModuleScript)

local F = Config.Feed
local player = Players.LocalPlayer

local KillConfirmController = {}

local KILL_RED = Color3.fromRGB(255, 60, 70)
local GOD_PURPLE = Color3.fromRGB(170, 90, 255)
local STREAK = { "", "DOUBLE KILL", "TRIPLE KILL" }

local started = false
local gui: ScreenGui
local chip: Frame
local chipName: TextLabel
local chipStreak: TextLabel
local chipScale: UIScale
local edge: Frame
local streak = 0
local lastKill = -math.huge
local chipToken = 0

-- four bars in an X around a screen point (raw pixels: the hitmarker sits on the victim)
local function hitmarker(at: Vector2)
	local holder = Instance.new("Frame")
	holder.Name = "Hitmarker"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(64, 64)
	holder.Position = UDim2.fromOffset(at.X, at.Y)
	holder.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 1.7
	scale.Parent = holder
	local bars: { Frame } = {}
	for i = 0, 3 do
		local angle = 45 + i * 90
		local r = math.rad(angle)
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = Color3.new(1, 1, 1)
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Size = UDim2.fromOffset(18, 5)
		bar.Rotation = angle
		bar.Position = UDim2.new(0.5, math.cos(r) * 16, 0.5, math.sin(r) * 16)
		local outline = Instance.new("UIStroke")
		outline.Thickness = 1.5
		outline.Color = Color3.new(0, 0, 0)
		outline.Parent = bar
		bar.Parent = holder
		table.insert(bars, bar)
	end
	TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(0.07, function()
		for _, bar in bars do
			TweenService:Create(bar, TweenInfo.new(0.1), { BackgroundColor3 = KILL_RED }):Play()
		end
	end)
	task.delay(F.HitmarkerSeconds * 0.45, function()
		for _, bar in bars do
			TweenService:Create(bar, TweenInfo.new(F.HitmarkerSeconds * 0.55), { BackgroundTransparency = 1 }):Play()
			local s = bar:FindFirstChildOfClass("UIStroke")
			if s then
				TweenService:Create(s, TweenInfo.new(F.HitmarkerSeconds * 0.55), { Transparency = 1 }):Play()
			end
		end
	end)
	task.delay(F.HitmarkerSeconds + 0.1, function()
		holder:Destroy()
	end)
end

local function showChip(name: string, count: number)
	chipToken += 1
	local token = chipToken
	chipName.Text = "☠ ELIMINATED " .. string.upper(name)
	local word = STREAK[count] or "MULTI KILL"
	chipStreak.Text = if count >= 2 then word .. "  x" .. count else ""
	chipStreak.Visible = count >= 2
	chip.Visible = true
	chipScale.Scale = 1.5
	TweenService:Create(chipScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.6, function()
		if token == chipToken then
			chip.Visible = false
		end
	end)
end

-- purple flash at the screen edges (two gradient frames: left/right and top/bottom)
local function flash()
	for _, f in edge:GetChildren() do
		if f:IsA("Frame") then
			f.BackgroundTransparency = 0.3
			TweenService:Create(f, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
		end
	end
end

local function onKill(name: string, position: Vector3?)
	local now = os.clock()
	streak = if now - lastKill <= F.KillStreakWindow then streak + 1 else 1
	lastKill = now
	-- the hitmarker lands on the victim when they're on screen
	local camera = workspace.CurrentCamera
	local at = if camera then camera.ViewportSize / 2 else Vector2.new(400, 300)
	if camera and position then
		local screen, onScreen = camera:WorldToViewportPoint(position)
		if onScreen then
			at = Vector2.new(screen.X, screen.Y)
		end
	end
	hitmarker(at)
	local pitch = 1 + math.min(streak - 1, 4) * 0.08
	Sound.play("Hitmarker", 1, pitch)
	task.delay(0.06, function()
		Sound.play("Coin", 0.8, 0.75 * pitch)
	end)
	showChip(name, streak)
	flash()
end

function KillConfirmController.Start()
	if started then
		return
	end
	started = true
	gui = Instance.new("ScreenGui")
	gui.Name = "KillConfirmHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 7
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	local layer = Components.scaledRoot(gui)

	edge = Instance.new("Frame")
	edge.Name = "Edge"
	edge.BackgroundTransparency = 1
	edge.Size = UDim2.fromScale(1, 1)
	edge.Parent = gui
	-- a soft vignette: gradients fade each frame out toward the middle of the screen
	for _, rotation in { 0, 90 } do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = GOD_PURPLE
		f.BackgroundTransparency = 1
		f.Parent = edge
		local vignette = Instance.new("UIGradient")
		vignette.Rotation = rotation
		vignette.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.14, 1),
			NumberSequenceKeypoint.new(0.86, 1),
			NumberSequenceKeypoint.new(1, 0),
		})
		vignette.Parent = f
	end

	chip = Components.panel({
		Name = "KillChip",
		Size = UDim2.fromOffset(420, 70),
		Position = UDim2.new(0.5, 0, 0.62, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = Color3.fromRGB(40, 16, 30),
		Transparency = 0.15,
		Parent = layer,
	})
	chip.Visible = false
	chipScale = Instance.new("UIScale")
	chipScale.Parent = chip
	chipName = Components.label({ Name = "Name", Text = "", TextSize = 26, Color = KILL_RED, Size = UDim2.new(1, -16, 0, 32), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), Parent = chip })
	chipName.TextTruncate = Enum.TextTruncate.AtEnd
	chipStreak = Components.label({ Name = "Streak", Text = "", TextSize = 20, Color = Color3.fromRGB(255, 215, 70), Size = UDim2.new(1, -16, 0, 24), Position = UDim2.new(0.5, 0, 0, 38), AnchorPoint = Vector2.new(0.5, 0), Parent = chip })

	Remotes.get("ClientEffect").OnClientEvent:Connect(function(kind: string, a: any, b: any)
		if kind == "GodKill" and typeof(a) == "string" then
			onKill(a, if typeof(b) == "Vector3" then b else nil)
		end
	end)
end

return KillConfirmController
