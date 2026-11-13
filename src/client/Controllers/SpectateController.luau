--!strict
-- SpectateController: eliminated / waiting players fly a free orbit camera over
-- the arena and can "haunt" it with harmless ghost pings (Poltergeist mode).

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
		Text = "Back to Sanctuary",
		TextSize = 20,
		Size = UDim2.fromOffset(220, 50),
		Position = UDim2.new(0.5, 0, 1, -50),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Purple,
		ColorLight = C.PurpleLight,
		Parent = layer,
		OnClick = SpectateController.Exit,
	})

	local function evaluate()
		if active and not allowed() then
			SpectateController.Exit()
		end
	end
	player:GetAttributeChangedSignal(Attributes.Role):Connect(evaluate)
	player:GetAttributeChangedSignal(Attributes.Alive):Connect(evaluate)
end

return SpectateController
