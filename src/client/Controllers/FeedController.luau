--!strict
-- FeedController: the kill feed / clutch callout stack under the round bar, the Last
-- Stand zone the God sees, and the final-kill camera moment for everyone.

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local UI = script.Parent.Parent:WaitForChild("UI")
local Components = require(UI:WaitForChild("Components") :: ModuleScript)
local Theme = require(UI:WaitForChild("Theme") :: ModuleScript)

local F = Config.Feed
local C = Theme.Colors
local player = Players.LocalPlayer

local FINAL_BIND = "DisasterGodFinalKill"
local ZONE = Color3.fromRGB(255, 60, 70)

local FeedController = {}

local list: Frame
local lines: { Frame } = {}
local order = 0
local finalPlaying = false

local function push(text: string, color: Color3?)
	order += 1
	local row = Components.panel({
		Name = "Line",
		Size = UDim2.fromOffset(460, 26),
		Color = C.Panel,
		Transparency = 0.25,
		Studs = false,
		Parent = list,
	})
	row.LayoutOrder = -order -- newest on top
	Components.label({ Name = "Text", Text = text, TextSize = 17, Color = color or C.Text, Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(6, 0), Parent = row })
	table.insert(lines, row)
	while #lines > F.MaxLines do
		local old = table.remove(lines, 1)
		if old then
			old:Destroy()
		end
	end
	task.delay(F.LineSeconds, function()
		if row.Parent then
			Components.tween(row, Theme.Tweens.Fade, { BackgroundTransparency = 1 })
			local label = row:FindFirstChild("Text") :: TextLabel?
			if label then
				Components.tween(label, Theme.Tweens.Fade, { TextTransparency = 1 })
			end
			task.delay(0.4, function()
				local i = table.find(lines, row)
				if i then
					table.remove(lines, i)
				end
				row:Destroy()
			end)
		end
	end)
end

-- God only: a pulsing circle around (not on) the Last Stand survivor.
local function showZone(center: Vector3, radius: number, seconds: number)
	local zone = Instance.new("Part")
	zone.Name = "LastStandZone"
	zone.Anchored = true
	zone.CanCollide = false
	zone.CanQuery = false
	zone.CanTouch = false
	zone.CastShadow = false
	zone.Shape = Enum.PartType.Cylinder
	zone.Material = Enum.Material.ForceField
	zone.Color = ZONE
	zone.Size = Vector3.new(0.4, radius * 2, radius * 2)
	zone.CFrame = CFrame.new(center - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	zone.Transparency = 0.4
	zone.Parent = workspace
	TweenService:Create(zone, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Transparency = 1 }):Play()
	Debris:AddItem(zone, seconds)
end

-- Everyone: the camera glides in on the final kill, the world desaturates, FOV narrows.
local function finalKill(position: Vector3, hold: number)
	if finalPlaying then
		return
	end
	finalPlaying = true
	local camera = workspace.CurrentCamera
	if not camera then
		finalPlaying = false
		return
	end
	local fx = Instance.new("ColorCorrectionEffect")
	fx.Name = "FinalKillGrade"
	fx.Parent = Lighting
	TweenService:Create(fx, TweenInfo.new(0.4), { Saturation = -0.6, Contrast = 0.15, TintColor = Color3.fromRGB(255, 225, 225) }):Play()
	local startCf = camera.CFrame
	local startFov = camera.FieldOfView
	local flat = Vector3.new(startCf.Position.X - position.X, 0, startCf.Position.Z - position.Z)
	local away = if flat.Magnitude > 1 then flat.Unit else Vector3.zAxis
	local goal = CFrame.lookAt(position + away * 22 + Vector3.new(0, 10, 0), position)
	local t = 0
	RunService:BindToRenderStep(FINAL_BIND, Enum.RenderPriority.Camera.Value + 1, function(dt)
		t += dt
		local a = math.min(1, t / (hold * 0.6))
		local e = 1 - (1 - a) ^ 3
		camera.CFrame = startCf:Lerp(goal, e)
		camera.FieldOfView = startFov + (42 - startFov) * e
	end)
	Components.label({
		Name = "FinalKillTitle",
		Text = "💀 FINAL KILL",
		TextSize = 44,
		Color = Color3.fromRGB(255, 90, 90),
		Size = UDim2.fromOffset(500, 56),
		Position = UDim2.fromScale(0.5, 0.22),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = list.Parent,
	})
	task.delay(hold, function()
		RunService:UnbindFromRenderStep(FINAL_BIND)
		camera.FieldOfView = startFov
		TweenService:Create(fx, TweenInfo.new(0.5), { Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) }):Play()
		Debris:AddItem(fx, 0.6)
		local title = list.Parent and list.Parent:FindFirstChild("FinalKillTitle")
		if title then
			title:Destroy()
		end
		finalPlaying = false
	end)
end

function FeedController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "FeedHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 2
	gui.Parent = player:WaitForChild("PlayerGui")
	local layer = Components.scaledRoot(gui)
	list = Instance.new("Frame")
	list.Name = "Feed"
	list.BackgroundTransparency = 1
	list.AnchorPoint = Vector2.new(0.5, 0)
	list.Position = UDim2.new(0.5, 0, 0, if Components.isTouch() then 122 else 128)
	list.Size = UDim2.fromOffset(460, F.MaxLines * 30)
	list.Parent = layer
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = list

	Remotes.get("Feed").OnClientEvent:Connect(function(text: any, color: any)
		if typeof(text) == "string" then
			push(text, if typeof(color) == "Color3" then color else nil)
		end
	end)
	Remotes.get("ClientEffect").OnClientEvent:Connect(function(kind: string, a: any, b: any, c: any)
		if kind == "Zone" and typeof(a) == "Vector3" and typeof(b) == "number" then
			showZone(a, b, if typeof(c) == "number" then c else 5)
		elseif kind == "FinalKill" and typeof(a) == "Vector3" then
			finalKill(a, if typeof(b) == "number" then b else F.FinalKillHold)
		end
	end)
end

return FeedController
