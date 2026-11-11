--!strict
-- HUDController: shows the round phase/timer and the local player's role.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)

local Attributes = Config.Attributes

-- Design tokens (keep UI values consistent across controllers)
local Tokens = {
	Background = Color3.fromRGB(20, 22, 30),
	BackgroundTransparency = 0.25,
	Text = Color3.fromRGB(245, 245, 250),
	Accent = Color3.fromRGB(255, 120, 60),
	Font = Enum.Font.GothamBold,
	TextSize = 22,
	CornerRadius = UDim.new(0, 10),
	Padding = UDim.new(0, 8),
}

local Tweens = {
	Fade = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
}

local PHASE_LABELS: { [string]: string } = {
	Intermission = "Intermission",
	Active = "Survive!",
	RoundEnd = "Round Over",
}

local HUDController = {}

local started = false

local function makeLabel(name: string, parent: Instance, order: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, Tokens.TextSize + 6)
	label.BackgroundTransparency = 1
	label.Font = Tokens.Font
	label.TextSize = Tokens.TextSize
	label.TextColor3 = Tokens.Text
	label.Text = ""
	label.Parent = parent
	return label
end

local function formatTime(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

function HUDController.Start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false

	local panel = Instance.new("Frame")
	panel.Name = "RoundPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 12)
	panel.Size = UDim2.fromOffset(220, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = Tokens.Background
	panel.BackgroundTransparency = Tokens.BackgroundTransparency
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Tokens.CornerRadius
	corner.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = Tokens.Padding
	padding.PaddingBottom = Tokens.Padding
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = panel

	local phaseLabel = makeLabel("Phase", panel, 1)
	local timerLabel = makeLabel("Timer", panel, 2)
	timerLabel.TextColor3 = Tokens.Accent
	local roleLabel = makeLabel("Role", panel, 3)

	gui.Parent = playerGui

	local function refreshPhase()
		local phase = ReplicatedStorage:GetAttribute(Attributes.RoundPhase)
		phaseLabel.Text = if typeof(phase) == "string" then (PHASE_LABELS[phase] or phase) else "Waiting…"
		phaseLabel.TextTransparency = 1
		TweenService:Create(phaseLabel, Tweens.Fade, { TextTransparency = 0 }):Play()
	end

	local function refreshTimer()
		local t = ReplicatedStorage:GetAttribute(Attributes.TimeRemaining)
		timerLabel.Text = if typeof(t) == "number" then formatTime(t) else "--:--"
	end

	local function refreshRole()
		local role = player:GetAttribute(Attributes.Role)
		roleLabel.Text = "Role: " .. (if typeof(role) == "string" then role else "—")
	end

	ReplicatedStorage:GetAttributeChangedSignal(Attributes.RoundPhase):Connect(refreshPhase)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.TimeRemaining):Connect(refreshTimer)
	player:GetAttributeChangedSignal(Attributes.Role):Connect(refreshRole)

	refreshPhase()
	refreshTimer()
	refreshRole()
end

return HUDController
