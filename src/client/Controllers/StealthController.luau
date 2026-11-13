--!strict
-- StealthController: the client side of hide-and-seek (server: StealthService).
--   God:      sees every survivor's name tag through walls unless they are Hidden,
--             noise ripples where survivors jump, dash or use gear, and the
--             silhouettes a Seismic Ping reveals.
--   Survivor: a HIDDEN badge while hidden, a warning flash when pinged.
--   Everyone: jammed zones around flipped circuit breakers.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local UI = script.Parent.Parent:WaitForChild("UI")
local Components = require(UI:WaitForChild("Components") :: ModuleScript)
local Theme = require(UI:WaitForChild("Theme") :: ModuleScript)

local Attributes = Config.Attributes
local S = Config.Stealth
local C = Theme.Colors
local player = Players.LocalPlayer

local NOISE = Color3.fromRGB(255, 235, 140)
local REVEAL = Color3.fromRGB(255, 70, 90)
local JAM = Color3.fromRGB(150, 110, 255)

local StealthController = {}

local fxFolder: Folder
local tags: { [Player]: BillboardGui } = {}
local badge: TextLabel
local pingFlash: TextLabel

local function isGod(): boolean
	return player:GetAttribute(Attributes.Role) == "DisasterGod"
end

local function localPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	if props.Shape then
		p.Shape = props.Shape
	end
	for k, v in props do
		if k ~= "Shape" then
			(p :: any)[k] = v
		end
	end
	p.Parent = fxFolder
	return p
end

local function ring(position: Vector3, radius: number, color: Color3, duration: number, transparency: number)
	local r = localPart({
		Name = "Ripple",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 2, 2),
		CFrame = CFrame.new(position - Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = transparency,
	})
	TweenService:Create(r, TweenInfo.new(duration, Enum.EasingStyle.Quad), { Size = Vector3.new(0.2, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(r, duration + 0.05)
end

---------------------------------------------------------------------------
-- God: name tags through walls (hidden survivors drop off)

local function makeTag(target: Player): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "GodTag_" .. target.Name
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(160, 26)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.MaxDistance = 600
	gui.ResetOnSpawn = false
	local label = Components.label({ Name = "Name", Text = "▼ " .. target.DisplayName, TextSize = 18, Color = C.GoldLight, Size = UDim2.fromScale(1, 1), Parent = gui })
	label.TextTransparency = 0.05
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

local function refreshTags()
	local god = isGod()
	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		local character = other.Character
		local head = character and character:FindFirstChild("Head") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local show = god
			and head ~= nil
			and other:GetAttribute(Attributes.Role) == "Survivor"
			and other:GetAttribute(Attributes.Alive) == true
			and other:GetAttribute(Attributes.Hidden) ~= true
		local tag = tags[other]
		if show then
			if not tag then
				tag = makeTag(other)
				tags[other] = tag
			end
			tag.Adornee = head
			tag.Enabled = true
		elseif tag then
			tag.Enabled = false
		end
		-- the default overhead name would leak hidden survivors to the God
		if humanoid then
			humanoid.DisplayDistanceType = if god then Enum.HumanoidDisplayDistanceType.None else Enum.HumanoidDisplayDistanceType.Viewer
		end
	end
end

---------------------------------------------------------------------------
-- effects

local function onReveal(characters: any, duration: any)
	if typeof(characters) ~= "table" then
		return
	end
	local d = if typeof(duration) == "number" then duration else 2
	for _, character in characters do
		if typeof(character) == "Instance" and character:IsA("Model") then
			local h = Instance.new("Highlight")
			h.FillColor = REVEAL
			h.OutlineColor = Color3.new(1, 1, 1)
			h.FillTransparency = 0.35
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Adornee = character
			h.Parent = fxFolder
			Debris:AddItem(h, d)
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				ring(root.Position, 12, REVEAL, 0.8, 0.2)
			end
		end
	end
end

local function onJam(position: any, radius: any, duration: any)
	if typeof(position) ~= "Vector3" or typeof(radius) ~= "number" or typeof(duration) ~= "number" then
		return
	end
	local zone = localPart({
		Name = "JamZone",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		CFrame = CFrame.new(position - Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = JAM,
		Transparency = 0.75,
		Material = Enum.Material.ForceField,
	})
	TweenService:Create(zone, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.55 }):Play()
	Debris:AddItem(zone, duration)
end

function StealthController.Start()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "StealthFX"
	fxFolder.Parent = workspace

	local gui = Instance.new("ScreenGui")
	gui.Name = "StealthHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	local layer = Components.scaledRoot(gui)
	badge = Components.label({
		Name = "Hidden",
		Text = "🫥 HIDDEN",
		TextSize = 24,
		Color = Color3.fromRGB(170, 255, 200),
		Size = UDim2.fromOffset(220, 32),
		Position = UDim2.new(0.5, 0, 1, if Components.isTouch() then -250 else -200),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = layer,
	})
	badge.Visible = false
	pingFlash = Components.label({
		Name = "Pinged",
		Text = "📡 PINGED! THE GOD SEES YOU",
		TextSize = 30,
		Color = REVEAL,
		Size = UDim2.fromOffset(520, 40),
		Position = UDim2.new(0.5, 0, 0.3, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = layer,
	})
	pingFlash.Visible = false

	player:GetAttributeChangedSignal(Attributes.Hidden):Connect(function()
		badge.Visible = player:GetAttribute(Attributes.Hidden) == true
	end)

	Remotes.get("ClientEffect").OnClientEvent:Connect(function(kind: string, a: any, b: any, c: any)
		if kind == "Noise" and typeof(a) == "Vector3" and isGod() then
			local strength = if typeof(b) == "number" then b else 1
			ring(a, S.NoiseRippleRadius * strength, NOISE, 1.1, 0.25)
		elseif kind == "Reveal" and isGod() then
			onReveal(a, b)
		elseif kind == "Jam" then
			onJam(a, b, c)
		elseif kind == "Pinged" then
			pingFlash.Visible = true
			task.delay(if typeof(a) == "number" then a else 2, function()
				pingFlash.Visible = false
			end)
		end
	end)

	Players.PlayerRemoving:Connect(function(other)
		local tag = tags[other]
		if tag then
			tag:Destroy()
			tags[other] = nil
		end
	end)
	task.spawn(function()
		while true do
			task.wait(S.CheckInterval)
			refreshTags()
		end
	end)
end

return StealthController
