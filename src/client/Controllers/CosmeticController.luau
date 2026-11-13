--!strict
-- CosmeticController: renders cosmetics everyone sees.
--   * God skin: while a human God plays, their equipped skin (GodSkin attribute) floats
--     high over their reticle (GodAim attribute) and glides after it. The God sees their
--     own skin almost transparent so it never blocks the view.
--   * Finishers: the effect at an eliminated survivor's body (ClientEffect "Finisher").

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)
local GodSkins = require(Shared:WaitForChild("GodSkins") :: ModuleScript)

local UI = script.Parent.Parent:WaitForChild("UI")
local Components = require(UI:WaitForChild("Components") :: ModuleScript)

local CO = Config.Cosmetics
local Attributes = Config.Attributes
local player = Players.LocalPlayer

local CosmeticController = {}

local fxFolder: Folder
local sky: Model? = nil
local skyId = ""
local skyPos: Vector3? = nil
local spin = 0
local touch = false

local function setTransparency(model: Model, alpha: number)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local base = d:GetAttribute("BaseTransparency")
			if typeof(base) ~= "number" then
				base = d.Transparency
				d:SetAttribute("BaseTransparency", base)
			end
			d.Transparency = 1 - (1 - (base :: number)) * (1 - alpha)
		end
	end
end

local function clearSky()
	if sky then
		sky:Destroy()
		sky = nil
	end
	skyId = ""
	skyPos = nil
end

local function refreshSky()
	local id = ReplicatedStorage:GetAttribute(Attributes.GodSkin)
	local aim = ReplicatedStorage:GetAttribute(Attributes.GodAim)
	if typeof(id) ~= "string" or id == "" or typeof(aim) ~= "Vector3" then
		clearSky()
		return
	end
	if id ~= skyId then
		clearSky()
		skyId = id
		local model = GodSkins.build(id, CO.SkyScale)
		model.Parent = fxFolder
		sky = model
	end
	local model = sky
	if model then
		local isGod = player:GetAttribute(Attributes.Role) == "DisasterGod"
		setTransparency(model, if isGod then CO.GodSkyTransparency else 0)
	end
end

local function stepSky(dt: number)
	local model = sky
	local aim = ReplicatedStorage:GetAttribute(Attributes.GodAim)
	if not model or typeof(aim) ~= "Vector3" then
		return
	end
	local goal = aim + Vector3.new(0, CO.SkyHeight, 0)
	skyPos = if skyPos then skyPos:Lerp(goal, math.min(1, dt * CO.SkyFollow)) else goal
	spin += dt * 0.4
	local bob = math.sin(spin * 2) * 1.5
	model:PivotTo(CFrame.new((skyPos :: Vector3) + Vector3.new(0, bob, 0)) * CFrame.Angles(0, spin, 0))
end

---------------------------------------------------------------------------
-- finishers

local function burst(position: Vector3, count: number, colors: { Color3 }, size: number, speed: number, life: number, material: Enum.Material?)
	for i = 1, count do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = material or Enum.Material.Neon
		p.Color = colors[(i % #colors) + 1]
		p.Size = Vector3.one * size
		p.CFrame = CFrame.new(position)
		p.Parent = fxFolder
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit
		TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(position + dir * speed) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
			Transparency = 1,
		}):Play()
		Debris:AddItem(p, life + 0.05)
	end
end

local CONFETTI = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 200, 40), Color3.fromRGB(90, 220, 90), Color3.fromRGB(70, 160, 255), Color3.fromRGB(200, 100, 255), Color3.fromRGB(255, 120, 200) }

local function finisher(id: string, position: Vector3)
	local scale = if touch then 0.5 else 1 -- fewer pieces on phones
	if id == "GhostRise" then
		local ghost = Instance.new("Part")
		ghost.Anchored = true
		ghost.CanCollide = false
		ghost.CanQuery = false
		ghost.CanTouch = false
		ghost.CastShadow = false
		ghost.Shape = Enum.PartType.Ball
		ghost.Size = Vector3.new(3.4, 4.2, 3.4)
		ghost.Material = Enum.Material.Neon
		ghost.Color = Color3.fromRGB(225, 235, 255)
		ghost.Transparency = 0.3
		ghost.CFrame = CFrame.new(position + Vector3.new(0, 2, 0))
		ghost.Parent = fxFolder
		local face = Instance.new("BillboardGui")
		face.Size = UDim2.fromScale(3, 3)
		face.AlwaysOnTop = false
		face.Parent = ghost
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.TextScaled = true
		label.Text = "👻"
		label.Parent = face
		TweenService:Create(ghost, TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { CFrame = ghost.CFrame + Vector3.new(0, 26, 0), Transparency = 1 }):Play()
		TweenService:Create(label, TweenInfo.new(2.4), { TextTransparency = 1 }):Play()
		Debris:AddItem(ghost, 2.5)
	elseif id == "ConfettiPop" then
		burst(position + Vector3.new(0, 2, 0), math.floor(40 * scale), CONFETTI, 0.6, 16, 1.6, Enum.Material.SmoothPlastic)
	elseif id == "CartoonBoing" then
		burst(position + Vector3.new(0, 3, 0), math.floor(10 * scale), { Color3.fromRGB(255, 230, 80) }, 1, 8, 1.2)
	else
		-- Poof (starter)
		burst(position + Vector3.new(0, 1.5, 0), math.floor(12 * scale), { Color3.fromRGB(200, 200, 210), Color3.fromRGB(160, 160, 170) }, 2.4, 6, 0.9, Enum.Material.SmoothPlastic)
	end
end

function CosmeticController.Start()
	touch = Components.isTouch()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "CosmeticFX"
	fxFolder.Parent = workspace
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.GodSkin):Connect(refreshSky)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.GodAim):Connect(function()
		if typeof(ReplicatedStorage:GetAttribute(Attributes.GodAim)) ~= "Vector3" then
			clearSky() -- round over / the God left
		elseif not sky then
			refreshSky()
		end
	end)
	player:GetAttributeChangedSignal(Attributes.Role):Connect(refreshSky)
	RunService.RenderStepped:Connect(stepSky)
	refreshSky()
	Remotes.get("ClientEffect").OnClientEvent:Connect(function(kind: string, a: any, b: any)
		if kind == "Finisher" and typeof(a) == "string" and typeof(b) == "Vector3" then
			finisher(a, b)
		end
	end)
end

return CosmeticController
