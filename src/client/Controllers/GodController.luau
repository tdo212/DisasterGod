--!strict
-- GodController: the Disaster God's tactical view — orbit camera, projected
-- targeting reticle, ability hotbar with costs/cooldowns and the Chaos Energy bar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local ClientRoot = script.Parent.Parent
local Theme = require(ClientRoot:WaitForChild("UI"):WaitForChild("Theme") :: ModuleScript)
local Components = require(ClientRoot:WaitForChild("UI"):WaitForChild("Components") :: ModuleScript)
local OrbitCamera = require(ClientRoot:WaitForChild("Util"):WaitForChild("OrbitCamera") :: ModuleScript)

local Attributes = Config.Attributes
local Abilities = Config.Disasters.Abilities
local C = Theme.Colors
local player = Players.LocalPlayer

local GodController = {}

local started = false
local active = false
local selected = 1
local gui: ScreenGui
local slots: { { Frame: TextButton, Cooldown: Frame, CooldownText: TextLabel, Icon: TextLabel, Stroke: UIStroke, Scale: UIScale } } = {}
local energyFill: Frame
local energyText: TextLabel
local lockLabel: TextLabel
local reticle: Model? = nil
local ring: Part? = nil
local line: Part? = nil
local beam: Part? = nil
local castRemote = Remotes.get("CastDisaster")
local inputConn: RBXScriptConnection? = nil

local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five }

local function energy(): number
	return player:GetAttribute(Attributes.ChaosEnergy) :: number? or 0
end

local function readyAt(id: string): number
	return player:GetAttribute(Attributes.CooldownPrefix .. id) :: number? or 0
end

---------------------------------------------------------------------------
-- UI

local function select(index: number)
	selected = index
	for i, slot in slots do
		local on = i == index
		slot.Stroke.Color = if on then C.Gold else C.Outline
		slot.Stroke.Thickness = if on then 5 else Theme.Stroke.Heavy
		Components.tween(slot.Scale, Theme.Tweens.Fast, { Scale = if on then 1.12 else 1 })
	end
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "GodHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local dock = Components.panel({
		Name = "Hotbar",
		Size = UDim2.fromOffset(#Abilities * 86 + 20, 162),
		Position = UDim2.new(0.5, 0, 1, -12),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Panel,
		Transparency = 0.15,
		Radius = Theme.Radius.Large,
		Parent = gui,
	})

	for i, def in Abilities do
		local slot = Instance.new("TextButton")
		slot.Name = def.Id
		slot.Text = ""
		slot.AutoButtonColor = false
		slot.Size = UDim2.fromOffset(74, 74)
		slot.Position = UDim2.fromOffset(10 + (i - 1) * 86 + 6, 12)
		slot.BackgroundColor3 = Color3.new(1, 1, 1)
		Components.corner(slot, Theme.Radius.Medium)
		local stroke = Components.stroke(slot, Theme.Stroke.Heavy)
		Components.gradient(slot, C.PanelLight, C.Slot)
		slot.Parent = dock
		local scale = Instance.new("UIScale")
		scale.Parent = slot

		local icon = Components.label({ Name = "Icon", Text = def.Icon, TextSize = 38, StrokeThickness = 0, Size = UDim2.fromScale(1, 1), Parent = slot })
		Components.label({ Name = "Key", Text = tostring(i), TextSize = 18, Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(4, 2), XAlign = Enum.TextXAlignment.Left, Parent = slot })
		local cost = Components.label({ Name = "Cost", Text = tostring(def.Cost), TextSize = 18, Color = C.PurpleLight, Size = UDim2.fromOffset(30, 20), Position = UDim2.new(1, -4, 1, -2), AnchorPoint = Vector2.new(1, 1), XAlign = Enum.TextXAlignment.Right, Parent = slot })
		cost.ZIndex = 3
		Components.label({ Name = "Name", Text = def.DisplayName, TextSize = 15, Size = UDim2.new(1, 16, 0, 18), Position = UDim2.new(0.5, 0, 1, 4), AnchorPoint = Vector2.new(0.5, 0), Parent = slot })

		local cd = Instance.new("Frame")
		cd.Name = "Cooldown"
		cd.BackgroundColor3 = Color3.new(0, 0, 0)
		cd.BackgroundTransparency = 0.35
		cd.BorderSizePixel = 0
		cd.AnchorPoint = Vector2.new(0, 1)
		cd.Position = UDim2.fromScale(0, 1)
		cd.Size = UDim2.fromScale(1, 0)
		cd.ZIndex = 2
		Components.corner(cd, Theme.Radius.Medium)
		cd.Parent = slot
		local cdText = Components.label({ Name = "CooldownText", Text = "", TextSize = 26, Size = UDim2.fromScale(1, 1), Parent = slot })
		cdText.ZIndex = 3

		slot.Activated:Connect(function()
			select(i)
		end)
		slots[i] = { Frame = slot, Cooldown = cd, CooldownText = cdText, Icon = icon, Stroke = stroke, Scale = scale }
	end

	-- Chaos Energy bar (purple, like the reference)
	local track = Instance.new("Frame")
	track.Name = "Energy"
	track.Size = UDim2.new(1, -24, 0, 26)
	track.Position = UDim2.new(0, 12, 1, -34)
	track.BackgroundColor3 = C.Slot
	track.BorderSizePixel = 0
	Components.corner(track, Theme.Radius.Pill)
	Components.stroke(track, Theme.Stroke.Thick)
	track.Parent = dock
	energyFill = Instance.new("Frame")
	energyFill.Size = UDim2.fromScale(0.3, 1)
	energyFill.BackgroundColor3 = Color3.new(1, 1, 1)
	energyFill.BorderSizePixel = 0
	Components.corner(energyFill, Theme.Radius.Pill)
	Components.gradient(energyFill, C.PurpleLight, C.Purple, 0)
	energyFill.Parent = track
	energyText = Components.label({ Name = "Text", Text = "0% Chaos Energy", TextSize = 18, Size = UDim2.fromScale(1, 1), Parent = track })
	energyText.ZIndex = 2

	lockLabel = Components.label({
		Name = "Lock",
		Text = "",
		TextSize = 26,
		Color = C.PurpleLight,
		Size = UDim2.fromOffset(500, 30),
		Position = UDim2.new(0.5, 0, 1, -182),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = gui,
	})
	Components.label({
		Name = "Hint",
		Text = "WASD pan · Q/E rotate · Scroll zoom · Right-drag tilt · 1-5 pick · Click to unleash",
		TextSize = 16,
		Color = C.TextDim,
		Size = UDim2.fromOffset(700, 20),
		Position = UDim2.new(0.5, 0, 1, -206),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = gui,
	})
	select(1)
end

---------------------------------------------------------------------------
-- reticle

local function makeReticle()
	local model = Instance.new("Model")
	model.Name = "GodReticle"
	local function part(name: string): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = C.Purple
		p.Transparency = 0.45
		p.Parent = model
		return p
	end
	local r = part("Ring")
	r.Shape = Enum.PartType.Cylinder
	local l = part("Line")
	local b = part("Beam")
	b.Shape = Enum.PartType.Cylinder
	b.Transparency = 0.6
	model.Parent = workspace.CurrentCamera
	reticle, ring, line, beam = model, r, l, b
end

local function destroyReticle()
	if reticle then
		reticle:Destroy()
	end
	reticle, ring, line, beam = nil, nil, nil, nil
end

local function aimPoint(): Vector3?
	return OrbitCamera.ScreenToWorld(UserInputService:GetMouseLocation())
end

local function updateReticle()
	local def = Abilities[selected]
	local point = aimPoint()
	if not (point and ring and line and beam) then
		return
	end
	local dir = OrbitCamera.GetLookDirection()
	local castable = energy() >= def.Cost and readyAt(def.Id) <= workspace:GetServerTimeNow() and ReplicatedStorage:GetAttribute(Attributes.CastingOpen) == true
	local color = if castable then C.PurpleLight else C.Red
	ring.Color = color
	line.Color = color
	beam.Color = color
	local pulse = 1 + math.sin(os.clock() * 6) * 0.04
	if def.Id == "FaultCleave" then
		ring.Transparency = 1
		line.Transparency = 0.45
		line.Size = Vector3.new(def.Width or 8, 0.3, def.Length or 100)
		line.CFrame = CFrame.lookAt(point, point + dir) + Vector3.new(0, 0.4, 0)
	else
		line.Transparency = if def.Id == "Gust" or def.Id == "Tornado" then 0.5 else 1
		line.Size = Vector3.new(1, 0.3, def.Radius * 1.6)
		line.CFrame = CFrame.lookAt(point, point + dir) * CFrame.new(0, 0.45, -def.Radius * 0.8)
		ring.Transparency = 0.45
		ring.Size = Vector3.new(0.3, def.Radius * 2 * pulse, def.Radius * 2 * pulse)
		ring.CFrame = CFrame.new(point + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90))
	end
	beam.Size = Vector3.new(60, 0.8, 0.8)
	beam.CFrame = CFrame.new(point + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90))
end

---------------------------------------------------------------------------

local function refreshHotbar()
	local e = energy()
	energyFill.Size = UDim2.fromScale(math.clamp(e / Config.Chaos.Max, 0, 1), 1)
	energyText.Text = string.format("%d%% Chaos Energy", math.floor(e / Config.Chaos.Max * 100))
	local now = workspace:GetServerTimeNow()
	for i, def in Abilities do
		local slot = slots[i]
		local remaining = readyAt(def.Id) - now
		if remaining > 0 then
			slot.Cooldown.Size = UDim2.fromScale(1, math.clamp(remaining / def.Cooldown, 0, 1))
			slot.CooldownText.Text = string.format("%.0f", math.ceil(remaining))
		else
			slot.Cooldown.Size = UDim2.fromScale(1, 0)
			slot.CooldownText.Text = ""
		end
		slot.Icon.TextTransparency = if e >= def.Cost then 0 else 0.6
	end
	if ReplicatedStorage:GetAttribute(Attributes.CastingOpen) ~= true then
		local t = ReplicatedStorage:GetAttribute(Attributes.TimeRemaining) :: number? or 0
		local untilOpen = t - (Config.Match.RoundDuration - Config.Match.PrepDuration)
		lockLabel.Text = string.format("⚡ Charging Chaos… powers unlock in %ds", math.max(0, untilOpen))
	elseif ReplicatedStorage:GetAttribute(Attributes.SubPhase) == "SuddenDeath" then
		lockLabel.Text = "🔥 FINALE — DOUBLE ENERGY REGEN"
	else
		lockLabel.Text = ""
	end
end

local function cast()
	local def = Abilities[selected]
	local point = aimPoint()
	if not point then
		return
	end
	if energy() < def.Cost then
		local hud = require(script.Parent:WaitForChild("HUDController") :: ModuleScript)
		hud.Popup("NOT ENOUGH CHAOS", C.RedLight)
		return
	end
	castRemote:FireServer(def.Id, point, OrbitCamera.GetLookDirection())
	local slot = slots[selected]
	slot.Scale.Scale = 0.85
	Components.tween(slot.Scale, Theme.Tweens.Pop, { Scale = 1.12 })
end

local function enter()
	if active then
		return
	end
	active = true
	gui.Enabled = true
	OrbitCamera.Enable(Config.World.ArenaCenter)
	makeReticle()
	RunService:BindToRenderStep("GodReticle", Enum.RenderPriority.Camera.Value + 2, function()
		updateReticle()
		refreshHotbar()
	end)
	inputConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		for i, key in KEYS do
			if input.KeyCode == key and Abilities[i] then
				select(i)
				return
			end
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			cast()
		end
	end)
end

local function exit()
	if not active then
		return
	end
	active = false
	gui.Enabled = false
	RunService:UnbindFromRenderStep("GodReticle")
	if inputConn then
		inputConn:Disconnect()
		inputConn = nil
	end
	destroyReticle()
	OrbitCamera.Disable()
end

local function evaluate()
	local isGod = player:GetAttribute(Attributes.Role) == "DisasterGod"
	local phase = ReplicatedStorage:GetAttribute(Attributes.RoundPhase)
	if isGod and phase == "Active" then
		enter()
	else
		exit()
	end
end

function GodController.IsActive(): boolean
	return active
end

function GodController.Start()
	if started then
		return
	end
	started = true
	buildGui()
	player:GetAttributeChangedSignal(Attributes.Role):Connect(evaluate)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.RoundPhase):Connect(evaluate)
	player.CharacterAdded:Connect(function()
		task.defer(evaluate)
	end)
	evaluate()
end

return GodController
