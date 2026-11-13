--!strict
-- DebrisController: client-side performance for destruction.
--   * Cosmetic rubble: the server sends small broken pieces (wall panels, glass, trim)
--     in per-frame batches; they are simulated only here, capped and faded quickly
--     (tighter cap and shorter life on phones / tablets).
--   * Touch devices: particle emitters, fire and trails are toned down as they appear,
--     and server debris stops casting shadows.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local UI = script.Parent.Parent:WaitForChild("UI")
local Components = require(UI:WaitForChild("Components") :: ModuleScript)

local DB = Config.Debris
local RUBBLE_GROUP = "ClientRubble" -- registered by the server (DestructionService)
local DEBRIS_TAG = "Debris" -- server debris (DestructionService)

local DebrisController = {}

local touch = false
local folder: Folder
local active: { BasePart } = {}

local function retire(part: BasePart)
	local i = table.find(active, part)
	if i then
		table.remove(active, i)
	end
	if part.Parent then
		part:Destroy()
	end
end

local function fadeOut(part: BasePart)
	if not part.Parent then
		return
	end
	local tween = TweenService:Create(part, TweenInfo.new(DB.ClientFadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 1,
		Size = part.Size * 0.35,
	})
	tween.Completed:Once(function()
		retire(part)
	end)
	tween:Play()
end

local function spawnPiece(entry: { any }, lifetime: number)
	local cframe, size, color, material, transparency, velocity = entry[1], entry[2], entry[3], entry[4], entry[5], entry[6]
	if typeof(cframe) ~= "CFrame" or typeof(size) ~= "Vector3" or typeof(velocity) ~= "Vector3" then
		return
	end
	local part = Instance.new("Part")
	part.Name = "Rubble"
	part.Size = size
	part.CFrame = cframe
	part.Color = if typeof(color) == "Color3" then color else Color3.new(0.6, 0.6, 0.6)
	if typeof(material) == "EnumItem" then
		part.Material = material :: any
	end
	part.Transparency = if typeof(transparency) == "number" then transparency else 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = not touch
	part.CollisionGroup = RUBBLE_GROUP
	part.AssemblyLinearVelocity = velocity
	part.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 6
	part.Parent = folder
	table.insert(active, part)
	task.delay(lifetime, fadeOut, part)
end

local function onRubble(batch: any)
	if typeof(batch) ~= "table" then
		return
	end
	local cap = if touch then DB.TouchClientCap else DB.ClientCap
	local lifetime = if touch then DB.TouchClientLifetime else DB.ClientLifetime
	for _, entry in batch do
		if typeof(entry) == "table" then
			spawnPiece(entry, lifetime)
		end
	end
	while #active > cap do
		retire(active[1])
	end
end

-- Phones / tablets: lighter particles and no debris shadows.
local function throttle(inst: Instance)
	if inst:IsA("ParticleEmitter") then
		inst.Rate *= DB.TouchParticleRate
		local life = inst.Lifetime
		inst.Lifetime = NumberRange.new(life.Min * DB.TouchParticleLifetime, life.Max * DB.TouchParticleLifetime)
	elseif inst:IsA("Trail") then
		inst.Lifetime *= DB.TouchTrailLifetime
	elseif inst:IsA("Fire") then
		inst.Size *= DB.TouchFireSize
	end
end

local function noShadow(inst: Instance)
	if inst:IsA("BasePart") then
		inst.CastShadow = false
	end
end

function DebrisController.Start()
	touch = Components.isTouch()
	folder = Instance.new("Folder")
	folder.Name = "ClientRubble"
	folder.Parent = workspace
	Remotes.get("Rubble").OnClientEvent:Connect(onRubble)

	if touch then
		for _, inst in workspace:GetDescendants() do
			throttle(inst)
		end
		workspace.DescendantAdded:Connect(function(inst)
			-- emitters are configured right after they are created; adjust once that settles
			if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Fire") then
				task.defer(throttle, inst)
			end
		end)
		for _, part in CollectionService:GetTagged(DEBRIS_TAG) do
			noShadow(part)
		end
		CollectionService:GetInstanceAddedSignal(DEBRIS_TAG):Connect(noShadow)
	end
end

return DebrisController
