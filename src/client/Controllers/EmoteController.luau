--!strict
-- EmoteController: the survivor taunt wheel (server: EmoteService). A 😜 button sits
-- above the DASH button (T on keyboard); it opens a row of four emotes. Emoting while
-- HIDDEN is a Daredevil taunt: the God sees you, you earn bonus coins for a while.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local UI = script.Parent.Parent:WaitForChild("UI")
local Components = require(UI:WaitForChild("Components") :: ModuleScript)
local Theme = require(UI:WaitForChild("Theme") :: ModuleScript)

local E = Config.Emotes
local Attributes = Config.Attributes
local C = Theme.Colors
local player = Players.LocalPlayer

local EmoteController = {}

local toggle: TextButton
local wheel: Frame
local readyAt = 0

local function canEmote(): boolean
	return player:GetAttribute(Attributes.Role) == "Survivor"
		and player:GetAttribute(Attributes.Alive) == true
		and ReplicatedStorage:GetAttribute(Attributes.RoundPhase) == "Active"
end

local function refresh()
	local ok = canEmote()
	toggle.Visible = ok
	if not ok then
		wheel.Visible = false
	end
	local hidden = player:GetAttribute(Attributes.Hidden) == true
	Components.setText(toggle, if hidden then "😈" else "😜")
end

local function play(def: { Id: string, Icon: string, Label: string, Emote: string?, Sound: string? })
	wheel.Visible = false
	local now = os.clock()
	if now < readyAt or not canEmote() then
		return
	end
	readyAt = now + E.Cooldown
	Remotes.get("Emote"):FireServer(def.Id)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and def.Emote then
		pcall(function()
			humanoid:PlayEmote(def.Emote :: string)
		end)
	end
end

function EmoteController.Start()
	local playerGui = player:WaitForChild("PlayerGui")
	local survivorHud = playerGui:WaitForChild("SurvivorHUD", 10)
	local dash = survivorHud and survivorHud:FindFirstChild("Dash", true) :: GuiObject?
	if not dash then
		warn("[EmoteController] DASH button not found; taunts disabled")
		return
	end
	local touch = Components.isTouch()
	local size = if touch then 0.72 else 0.8
	toggle = Components.button({
		Name = "Emote",
		Text = "😜",
		TextSize = if touch then 26 else 24,
		Size = UDim2.new(size, 0, size, 0),
		Position = UDim2.new(0.5, 0, 0, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Pink,
		ColorLight = C.PinkLight,
		Parent = dash,
		OnClick = function()
			wheel.Visible = not wheel.Visible and canEmote()
		end,
	})
	toggle.SizeConstraint = Enum.SizeConstraint.RelativeYY
	if not touch then
		Components.label({ Name = "Key", Text = "T", TextSize = 14, Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(3, 1), XAlign = Enum.TextXAlignment.Left, Parent = toggle })
	end

	wheel = Instance.new("Frame")
	wheel.Name = "EmoteWheel"
	wheel.BackgroundTransparency = 1
	wheel.AnchorPoint = Vector2.new(1, 0.5)
	wheel.Position = UDim2.new(0, -8, 0.5, 0)
	wheel.Size = UDim2.new(#E.List, 8 * #E.List, 1, 0)
	wheel.SizeConstraint = Enum.SizeConstraint.RelativeYY
	wheel.Visible = false
	wheel.Parent = toggle
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = wheel
	for i, def in E.List do
		local b = Components.button({
			Name = def.Id,
			Text = def.Icon,
			TextSize = 24,
			Size = UDim2.fromScale(1, 1),
			Color = C.Purple,
			ColorLight = C.PurpleLight,
			Parent = wheel,
			OnClick = function()
				play(def)
			end,
		})
		b.SizeConstraint = Enum.SizeConstraint.RelativeYY
		b.LayoutOrder = i
	end

	ContextActionService:BindAction("DisasterGodEmote", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and canEmote() then
			wheel.Visible = not wheel.Visible
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.T)

	for _, attr in { Attributes.Role, Attributes.Alive, Attributes.Hidden } do
		player:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.RoundPhase):Connect(refresh)
	refresh()
end

return EmoteController
