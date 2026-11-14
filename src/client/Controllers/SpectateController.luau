--!strict
-- SpectateController: eliminated / waiting players fly a free orbit camera over
-- the arena and can "haunt" it with harmless ghost pings (Poltergeist mode), and spend a
-- few coins on a survivor: a firework cheer, a speed berry or a bandage (Config.Cheers).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local ClientRoot = script.Parent.Parent
local Theme = require(ClientRoot:WaitForChild("UI"):WaitForChild("Theme") :: ModuleScript)
local Components = require(ClientRoot:WaitForChild("UI"):WaitForChild("Components") :: ModuleScript)
local OrbitCamera = require(ClientRoot:WaitForChild("Util"):WaitForChild("OrbitCamera") :: ModuleScript)

local Attributes = Config.Attributes
local C = Theme.Colors
local player = Players.LocalPlayer

local SpectateController = {}

local started = false
local active = false
local gui: ScreenGui
local layer: Frame -- viewport-scaled root for all UI content
local hint: TextLabel
local inputConn: RBXScriptConnection? = nil
local nextPing = 0

local function allowed(): boolean
	local role = player:GetAttribute(Attributes.Role)
	if role == "DisasterGod" then
		return false
	end
	if role == "Survivor" and player:GetAttribute(Attributes.Alive) == true then
		return false
	end
	return true
end

function SpectateController.IsActive(): boolean
	return active
end

function SpectateController.Exit()
	if not active then
		return
	end
	active = false
	gui.Enabled = false
	if inputConn then
		inputConn:Disconnect()
		inputConn = nil
	end
	OrbitCamera.Disable()
end

function SpectateController.Enter()
	if active or not allowed() or OrbitCamera.IsEnabled() then
		return
	end
	active = true
	gui.Enabled = true
	OrbitCamera.Enable(Config.World.ArenaCenter)
	inputConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if ReplicatedStorage:GetAttribute(Attributes.CastingOpen) ~= true then
				return
			end
			local now = os.clock()
			if now < nextPing then
				return
			end
			local point = if input.UserInputType == Enum.UserInputType.Touch
				then OrbitCamera.ScreenToWorld(Vector2.new(input.Position.X, input.Position.Y), true)
				else OrbitCamera.ScreenToWorld(UserInputService:GetMouseLocation())
			if point then
				nextPing = now + Config.Scoring.GhostPingCooldown
				Remotes.get("GhostPing"):FireServer(point)
			end
		end
	end)
end

function SpectateController.Toggle()
	if active then
		SpectateController.Exit()
	else
		SpectateController.Enter()
	end
end

function SpectateController.Start()
	if started then
		return
	end
	started = true
	gui = Instance.new("ScreenGui")
	gui.Name = "SpectateHUD"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	layer = Components.scaledRoot(gui)

	hint = Components.label({
		Name = "Hint",
		Text = if Components.isTouch()
			then "👻 SPECTATING · Tap the arena to haunt · Drag to fly, pinch to zoom"
			else "👻 SPECTATING · Click the arena to haunt · WASD/QE/Scroll to fly",
		TextSize = 22,
		Color = C.PurpleLight,
		Size = UDim2.fromOffset(760, 30),
		Position = UDim2.new(0.5, 0, 1, -110),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = layer,
	})
	Components.button({
		Name = "Exit",
		Text = "Back to Lodge",
		TextSize = 20,
		Size = UDim2.fromOffset(220, 50),
		Position = UDim2.new(0.5, 0, 1, -50),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Purple,
		ColorLight = C.PurpleLight,
		Parent = layer,
		OnClick = SpectateController.Exit,
	})

	-- cheer bar: pick a survivor, then cheer / help them (paid in coins, server-checked)
	local CH = Config.Cheers
	local targetIndex = 1
	local bar = Components.panel({
		Name = "CheerBar",
		Size = UDim2.fromOffset(300, 150),
		Position = UDim2.new(1, -14, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = C.Window,
		Transparency = 0.15,
		Parent = layer,
	})
	Components.label({ Name = "Title", Text = "CHEER A SURVIVOR", TextSize = 18, Color = C.GoldLight, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 6), Parent = bar })
	local targetLabel = Components.label({ Name = "Target", Text = "", TextSize = 18, Size = UDim2.new(1, -96, 0, 30), Position = UDim2.new(0.5, 0, 0, 36), AnchorPoint = Vector2.new(0.5, 0), Parent = bar })
	targetLabel.TextTruncate = Enum.TextTruncate.AtEnd
	local function survivors(): { Player }
		local list = {}
		for _, p in Players:GetPlayers() do
			if p ~= player and p:GetAttribute(Attributes.Role) == "Survivor" and p:GetAttribute(Attributes.Alive) == true then
				table.insert(list, p)
			end
		end
		return list
	end
	local function currentTarget(): Player?
		local list = survivors()
		if #list == 0 then
			return nil
		end
		targetIndex = (targetIndex - 1) % #list + 1
		return list[targetIndex]
	end
	local function refreshTarget()
		local target = currentTarget()
		targetLabel.Text = if target then target.DisplayName else "No survivors left"
	end
	for _, spec in { { "<", -1, 10 }, { ">", 1, -10 } } do
		Components.button({
			Name = "Cycle",
			Text = spec[1] :: string,
			TextSize = 22,
			Size = UDim2.fromOffset(38, 32),
			Position = if (spec[2] :: number) < 0 then UDim2.fromOffset(10, 35) else UDim2.new(1, -48, 0, 35),
			Color = C.Header,
			ColorLight = C.HeaderLight,
			Parent = bar,
			OnClick = function()
				targetIndex += spec[2] :: number
				refreshTarget()
			end,
		})
	end
	for i, kind in { "Cheer", "Berry", "Bandage" } do
		local def = (CH :: any)[kind]
		local b = Components.button({
			Name = kind,
			Text = "",
			TextSize = 14,
			Size = UDim2.fromOffset(88, 58),
			Position = UDim2.fromOffset(10 + (i - 1) * 96, 80),
			Color = C.Purple,
			ColorLight = C.PurpleLight,
			Parent = bar,
			OnClick = function()
				local target = currentTarget()
				if target then
					Remotes.get("Cheer"):FireServer(kind, target.UserId)
				end
			end,
		})
		Components.icon({ Name = "Icon", Icon = def.Icon, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(0.5, 0, 0, 3), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3, Parent = b })
		local text = b:FindFirstChild("Text") :: TextLabel?
		if text then
			text.Text = "🪙" .. def.Cost
			text.Size = UDim2.new(1, 0, 0, 20)
			text.Position = UDim2.new(0, 0, 1, -22)
		end
	end
	task.spawn(function()
		while true do
			task.wait(1)
			if gui.Enabled then
				refreshTarget()
			end
		end
	end)

	local function evaluate()
		if active and not allowed() then
			SpectateController.Exit()
		end
	end
	player:GetAttributeChangedSignal(Attributes.Role):Connect(evaluate)
	player:GetAttributeChangedSignal(Attributes.Alive):Connect(evaluate)
end

return SpectateController
