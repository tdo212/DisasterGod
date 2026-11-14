--!strict
-- GodController: the Disaster God's tactical view — orbit camera, projected targeting
-- reticle, the equipped kit's ability hotbar with costs/cooldowns, the Chaos Energy bar.
-- The universal Seismic Ping sits after the five kit slots as a separate, round radar
-- button (offset further on phones so thumbs don't hit it by mistake).
-- Mouse: aim with the cursor, click to cast. Touch: the reticle sits at screen centre
-- (drag to move the view) with a CAST button; tapping the arena casts right there.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Loadout = require(Shared:WaitForChild("Loadout") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)
local Types = require(Shared:WaitForChild("Types") :: ModuleScript)

local ClientRoot = script.Parent.Parent
local Theme = require(ClientRoot:WaitForChild("UI"):WaitForChild("Theme") :: ModuleScript)
local Components = require(ClientRoot:WaitForChild("UI"):WaitForChild("Components") :: ModuleScript)
local OrbitCamera = require(ClientRoot:WaitForChild("Util"):WaitForChild("OrbitCamera") :: ModuleScript)

type Ability = Types.AbilityDefinition
type Slot = { Frame: TextButton, Cooldown: Frame, CooldownText: TextLabel, Icon: GuiObject, Stroke: UIStroke, Scale: UIScale }

local Attributes = Config.Attributes
local C = Theme.Colors
local player = Players.LocalPlayer

local GodController = {}

local SLOT = 74
local SLOT_GAP = 12
local UTILITY_GAP = 26 -- extra space before the radar slot (desktop)
local UTILITY_GAP_TOUCH = 44
local RADAR = Color3.fromRGB(40, 205, 190)

local abilityById: { [string]: Ability } = {}
for _, def in Config.Disasters.Abilities do
	abilityById[def.Id] = def
end

local started = false
local active = false
local touch = false
local selected = 1
local loadout: { Ability } = {}
local gui: ScreenGui
local layer: Frame -- viewport-scaled root for all UI content
local dock: Frame
local slotHolder: Frame
local slots: { Slot } = {}
local energyFill: Frame
local energyText: TextLabel
local lockLabel: TextLabel
local reticle: Model? = nil
local ring: Part? = nil
local line: Part? = nil
local beam: Part? = nil
local castRemote = Remotes.get("CastDisaster")
local inputConnections: { RBXScriptConnection } = {}

local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six }

local function energy(): number
	return player:GetAttribute(Attributes.ChaosEnergy) :: number? or 0
end

local function readyAt(id: string): number
	return player:GetAttribute(Attributes.CooldownPrefix .. id) :: number? or 0
end

-- The five abilities of the equipped kit (with the God Pack signature swapped in), then
-- the universal ones (Seismic Ping). See shared/Loadout.
local function currentLoadout(): { Ability }
	local list = {}
	for _, id in Loadout.ids(player:GetAttribute(Attributes.Kit), ReplicatedStorage:GetAttribute(Attributes.GodSkin)) do
		local def = abilityById[id]
		if def then
			table.insert(list, def)
		end
	end
	return list
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

local function buildSlots()
	slotHolder:ClearAllChildren()
	table.clear(slots)
	loadout = currentLoadout()
	local utilityGap = if touch then UTILITY_GAP_TOUCH else UTILITY_GAP
	local hasUtility = false
	for _, def in loadout do
		hasUtility = hasUtility or def.Tier == "Utility"
	end
	local width = #loadout * (SLOT + SLOT_GAP) + SLOT_GAP + 8 + (if hasUtility then utilityGap else 0)
	dock.Size = UDim2.fromOffset(width, 162)
	local x = SLOT_GAP + 4
	for i, def in loadout do
		local utility = def.Tier == "Utility"
		if utility then
			x += utilityGap
		end
		local slot = Instance.new("TextButton")
		slot.Name = def.Id
		slot.Text = ""
		slot.AutoButtonColor = false
		slot.Size = UDim2.fromOffset(SLOT, SLOT)
		slot.Position = UDim2.fromOffset(x, 12)
		x += SLOT + SLOT_GAP
		slot.BackgroundColor3 = Color3.new(1, 1, 1)
		Components.corner(slot, if utility then UDim.new(0.5, 0) else Theme.Radius.Medium)
		local stroke = Components.stroke(slot, Theme.Stroke.Heavy)
		local tint = if utility then RADAR elseif def.Tier == "Major" then C.Purple else C.Blue
		Components.gradient(slot, tint:Lerp(Color3.new(1, 1, 1), 0.25), tint:Lerp(Color3.new(0, 0, 0), 0.35), 90, true)
		Components.studs(slot)
		slot.Parent = slotHolder
		local scale = Instance.new("UIScale")
		scale.Parent = slot

		local icon = Components.icon({ Name = "Icon", Icon = def.Id, TextSize = 38, Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.5, 0.48), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2, Parent = slot })
		if not touch then
			Components.keyChip(slot, tostring(i))
		end
		local cost = Components.label({ Name = "Cost", Text = tostring(def.Cost), TextSize = 18, Color = C.GoldLight, Size = UDim2.fromOffset(30, 20), Position = UDim2.new(1, -4, 1, -8), AnchorPoint = Vector2.new(1, 1), XAlign = Enum.TextXAlignment.Right, Parent = slot })
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
	select(math.clamp(selected, 1, math.max(1, #loadout)))
end

local cast: (Vector3?) -> ()

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "GodHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	layer = Components.scaledRoot(gui)

	dock = Components.panel({
		Name = "Hotbar",
		Size = UDim2.fromOffset(450, 162),
		Position = UDim2.new(0.5, 0, 1, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Panel,
		Transparency = 0.1,
		Radius = Theme.Radius.Large,
		Studs = true,
		Parent = layer,
	})
	slotHolder = Instance.new("Frame")
	slotHolder.Name = "Slots"
	slotHolder.BackgroundTransparency = 1
	slotHolder.Size = UDim2.fromScale(1, 1)
	slotHolder.Parent = dock

	-- Chaos Energy bar (purple, like the reference)
	local track = Instance.new("Frame")
	track.Name = "Energy"
	track.Size = UDim2.new(1, -24, 0, 26)
	track.Position = UDim2.new(0, 12, 1, -36)
	track.BackgroundColor3 = C.Slot
	track.BorderSizePixel = 0
	Components.corner(track, Theme.Radius.Small)
	Components.stroke(track, Theme.Stroke.Thick)
	track.Parent = dock
	energyFill = Instance.new("Frame")
	energyFill.Size = UDim2.fromScale(0.3, 1)
	energyFill.BackgroundColor3 = Color3.new(1, 1, 1)
	energyFill.BorderSizePixel = 0
	Components.corner(energyFill, Theme.Radius.Small)
	Components.gradient(energyFill, C.PurpleLight, C.Purple, 90, true)
	energyFill.Parent = track
	energyText = Components.label({ Name = "Text", Text = "0% Chaos Energy", TextSize = 18, Size = UDim2.fromScale(1, 1), Parent = track })
	energyText.ZIndex = 2

	lockLabel = Components.label({
		Name = "Lock",
		Text = "",
		TextSize = 26,
		Color = C.PurpleLight,
		Size = UDim2.fromOffset(560, 30),
		Position = UDim2.new(0.5, 0, 1, -182),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = layer,
	})
	Components.label({
		Name = "Hint",
		Text = if touch
			then "Drag to move · Pinch to zoom · Tap the arena or press CAST"
			else "WASD pan · Q/E rotate · Scroll zoom · Right-drag tilt · 1-5 pick · Click to unleash",
		TextSize = 16,
		Color = C.TextDim,
		Size = UDim2.fromOffset(700, 20),
		Position = UDim2.new(0.5, 0, 1, -206),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = layer,
	})

	if touch then
		-- thumb-sized cast button on the right; the reticle stays at screen centre
		Components.button({
			Name = "Cast",
			Text = "⚡ CAST",
			TextSize = 30,
			Size = UDim2.fromOffset(170, 96),
			Position = UDim2.new(1, -20, 1, -40),
			AnchorPoint = Vector2.new(1, 1),
			Color = C.Purple,
			ColorLight = C.PurpleLight,
			Parent = layer,
			OnClick = function()
				cast(nil)
			end,
		})
	end
	buildSlots()
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

-- Mouse: under the cursor. Touch: the centre of the screen.
local function aimPoint(): Vector3?
	if touch then
		local camera = workspace.CurrentCamera
		return if camera then OrbitCamera.ScreenToWorld(camera.ViewportSize / 2) else nil
	end
	return OrbitCamera.ScreenToWorld(UserInputService:GetMouseLocation())
end

-- The reticle drives the God skin in the sky for everyone (CosmeticService), throttled.
local aimRemote = Remotes.get("GodAim")
local lastAimSent = 0
local function sendAim(point: Vector3)
	local now = os.clock()
	if now - lastAimSent >= 1 / Config.Cosmetics.AimSendRate then
		lastAimSent = now
		aimRemote:FireServer(point)
	end
end

local function updateReticle()
	local def = loadout[selected]
	local point = aimPoint()
	if not (def and point and ring and line and beam) then
		return
	end
	sendAim(point)
	local dir = OrbitCamera.GetLookDirection()
	local castable = energy() >= def.Cost and readyAt(def.Id) <= workspace:GetServerTimeNow() and ReplicatedStorage:GetAttribute(Attributes.CastingOpen) == true
	local color = if castable then C.PurpleLight else C.Red
	ring.Color = color
	line.Color = color
	beam.Color = color
	local pulse = 1 + math.sin(os.clock() * 6) * 0.04
	if def.Width then -- line abilities: Fault Cleave, Meteor Barrage, Pyroclast Surge
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
	for i, def in loadout do
		local slot = slots[i]
		local remaining = readyAt(def.Id) - now
		if remaining > 0 then
			slot.Cooldown.Size = UDim2.fromScale(1, math.clamp(remaining / def.Cooldown, 0, 1))
			slot.CooldownText.Text = string.format("%.0f", math.ceil(remaining))
		else
			slot.Cooldown.Size = UDim2.fromScale(1, 0)
			slot.CooldownText.Text = ""
		end
		Components.setIconTransparency(slot.Icon, if e >= def.Cost then 0 else 0.6)
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

-- Cast the selected ability at `at` (or wherever the reticle is aiming).
cast = function(at: Vector3?)
	local def = loadout[selected]
	local point = at or aimPoint()
	if not (def and point) then
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
	buildSlots() -- the kit may have changed since last round
	gui.Enabled = true
	OrbitCamera.Enable(Config.World.ArenaCenter)
	makeReticle()
	RunService:BindToRenderStep("GodReticle", Enum.RenderPriority.Camera.Value + 2, function()
		updateReticle()
		refreshHotbar()
	end)
	table.insert(inputConnections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		for i, key in KEYS do
			if input.KeyCode == key and loadout[i] then
				select(i)
				return
			end
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			cast(nil)
		end
	end))
	-- a tap (not a drag) on the arena casts exactly where the finger landed
	table.insert(inputConnections, UserInputService.TouchTapInWorld:Connect(function(position, processed)
		if not processed then
			cast(OrbitCamera.ScreenToWorld(position, true))
		end
	end))
end

local function exit()
	if not active then
		return
	end
	active = false
	gui.Enabled = false
	RunService:UnbindFromRenderStep("GodReticle")
	for _, connection in inputConnections do
		connection:Disconnect()
	end
	table.clear(inputConnections)
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
	touch = Components.isTouch()
	buildGui()
	player:GetAttributeChangedSignal(Attributes.Role):Connect(evaluate)
	player:GetAttributeChangedSignal(Attributes.Kit):Connect(buildSlots)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.GodSkin):Connect(buildSlots) -- God Pack signature
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.RoundPhase):Connect(evaluate)
	player.CharacterAdded:Connect(function()
		task.defer(evaluate)
	end)
	evaluate()
end

return GodController
