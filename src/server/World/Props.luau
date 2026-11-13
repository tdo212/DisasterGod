--!strict
-- Interactive props survivors use to outplay the God, placed on free ground in every
-- arena (positions picked by scanning each map for open, flat, hazard-free spots away
-- from spawns):
--   * Circuit breakers: hold the prompt to jam the God's radar around them (PropService).
--   * Launch pads: fling you up and toward the middle of the map to escape a collapse.
--     One per map sits on the roof of the tallest new building and falls with that roof.
--   * Vault: a squat reinforced bunker that survives one big hit before caving in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Builder)
local Config = require(ReplicatedStorage.Shared.Config)

local P = Config.Props

type Spots = { Vault: Vector3, Breakers: { Vector3 }, Pads: { Vector3 }, RoofPad: string }

-- Ground points (Y = surface height).
local SPOTS: { [string]: Spots } = {
	FractureBay = {
		Vault = Vector3.new(-32, 2, -32),
		Breakers = { Vector3.new(30, 2, -50), Vector3.new(-90, 2, 70) },
		Pads = { Vector3.new(-50, 2, 10), Vector3.new(40, 2, 70) },
		RoofPad = "BayHotel",
	},
	MagmaCore = {
		Vault = Vector3.new(-70, 6.2, 26),
		Breakers = { Vector3.new(60, 6.2, -20), Vector3.new(-30, 6.2, -80) },
		Pads = { Vector3.new(-60, 6.2, 0), Vector3.new(40, 6.2, 80) },
		RoofPad = "AssayLab",
	},
	NeoShibuya = {
		Vault = Vector3.new(-80, 0, 0),
		Breakers = { Vector3.new(60, 0, -70), Vector3.new(-50, 0, 70) },
		Pads = { Vector3.new(10, 0, 90), Vector3.new(100, 0, -20) },
		RoofPad = "Shophouse2",
	},
	OutpostZero = {
		Vault = Vector3.new(-98, 5, -24),
		Breakers = { Vector3.new(10, 5, -30), Vector3.new(-30, 5, 60) },
		Pads = { Vector3.new(80, 5, -40), Vector3.new(-50, 5, -60) },
		RoofPad = "DrillHall",
	},
	StarlightBoardwalk = {
		Vault = Vector3.new(-14, 8.5, 20),
		Breakers = { Vector3.new(60, 8.5, 50), Vector3.new(-70, 8.5, -30) },
		Pads = { Vector3.new(70, 8.5, 20), Vector3.new(-50, 8.5, -40) },
		RoofPad = "Pavilion1",
	},
	SunscorchedMirage = {
		Vault = Vector3.new(41, 0, 49),
		Breakers = { Vector3.new(-35, 0, 15), Vector3.new(45, 0, -45) },
		Pads = { Vector3.new(55, 0, 5), Vector3.new(-55, 0, -55) },
		RoofPad = "Bazaar1",
	},
}

local STEEL = Color3.fromRGB(70, 74, 86)
local HAZARD = Color3.fromRGB(250, 200, 40)
local GREEN = Color3.fromRGB(90, 255, 140)
local PAD = Color3.fromRGB(60, 200, 255)

export type PropSet = {
	Breakers: { { Panel: BasePart, Light: BasePart, Prompt: ProximityPrompt } },
	Pads: { BasePart },
	Center: Vector3,
}

local Props = {}

local function breaker(folder: Instance, ground: Vector3, center: Vector3)
	local face = Vector3.new(center.X - ground.X, 0, center.Z - ground.Z)
	local look = if face.Magnitude > 1 then face.Unit else Vector3.zAxis
	local base = CFrame.lookAt(ground, ground + look)
	local post = Builder.part(folder, { Name = "BreakerPost", Size = Vector3.new(0.8, 4, 0.8), CFrame = base * CFrame.new(0, 2, 0.6), Color = STEEL, Material = Enum.Material.Metal })
	post.CanCollide = false
	local panel = Builder.part(folder, { Name = "CircuitBreaker", Size = Vector3.new(3, 4, 1.2), CFrame = base * CFrame.new(0, 4.5, 0), Color = STEEL, Material = Enum.Material.DiamondPlate })
	Builder.part(folder, { Name = "Stripe", Size = Vector3.new(3.1, 0.5, 1.25), CFrame = base * CFrame.new(0, 2.7, 0), Color = HAZARD, Material = Enum.Material.SmoothPlastic })
	local light = Builder.part(folder, { Name = "BreakerLight", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = base * CFrame.new(0, 6.9, 0), Color = GREEN, Material = Enum.Material.Neon, CanCollide = false })
	Builder.sign(panel, Enum.NormalId.Front, "⚡ JAM", Color3.new(1, 1, 1))
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BreakerPrompt"
	prompt.ActionText = "Jam Radar"
	prompt.ObjectText = "Circuit Breaker"
	prompt.HoldDuration = P.BreakerHold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = panel
	return { Panel = panel, Light = light, Prompt = prompt }
end

-- `level`: when set, the pad is part of a building's roof and falls with it.
local function pad(folder: Instance, ground: Vector3, level: number?): BasePart
	local rim = Builder.part(folder, { Name = "PadRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 9, 9), CFrame = CFrame.new(ground + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = STEEL, Material = Enum.Material.Metal })
	local top = Builder.part(folder, {
		Name = "LaunchPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 7, 7),
		CFrame = CFrame.new(ground + Vector3.new(0, 0.55, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = PAD,
		Material = Enum.Material.Neon,
	})
	for i = 1, 3 do
		local chevron = Builder.part(folder, { Name = "Chevron", Size = Vector3.new(2.4, 0.1, 0.5), CFrame = CFrame.new(ground + Vector3.new(0, 0.8, (i - 2) * 1.6)), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, CanCollide = false })
		chevron.CastShadow = false
		if level then
			Builder.structural(chevron, level, false, 20)
		end
	end
	if level then
		Builder.structural(rim, level, false, 200)
		Builder.structural(top, level, false, 200)
	end
	return top
end

-- Pad on top of `building` (a highrise with a RoofY attribute), on the roof's level.
local function roofPad(building: Instance?): BasePart?
	if not (building and building:IsA("Model")) then
		return nil
	end
	local roofY = building:GetAttribute("RoofY")
	if typeof(roofY) ~= "number" then
		return nil
	end
	local cf = building:GetBoundingBox()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { building }
	local hit = workspace:Raycast(Vector3.new(cf.X, roofY + 5, cf.Z), Vector3.new(0, -8, 0), params)
	local level = hit and hit.Instance:GetAttribute("Level")
	if typeof(level) ~= "number" then
		return nil
	end
	return pad(building, Vector3.new(cf.X, roofY, cf.Z), level)
end

local function vault(model: Model, ground: Vector3)
	local building = Builder.highrise(model, "Vault", ground, 16, 14, 1, 9, {
		SlabColor = Color3.fromRGB(110, 112, 120),
		SlabMaterial = Enum.Material.Concrete,
		ColumnColor = HAZARD,
		ColumnMaterial = Enum.Material.Metal,
		WallColor = Color3.fromRGB(95, 98, 108),
		WallMaterial = Enum.Material.Concrete,
		WallTransparency = 0,
		Health = P.VaultHealth,
	})
	local sign = Builder.part(building, { Name = "VaultSign", Size = Vector3.new(8, 2, 0.3), CFrame = CFrame.new(ground + Vector3.new(0, 10.5, -7.3)), Color = HAZARD, Material = Enum.Material.SmoothPlastic, CanCollide = false })
	Builder.sign(sign, Enum.NormalId.Front, "🛡️ VAULT", Color3.fromRGB(30, 30, 40))
	Builder.structural(sign, 2, false, P.VaultHealth)
end

-- Build the props for `mapName` into its model. Returns nil for maps without props.
function Props.build(model: Model, mapName: string, center: Vector3): PropSet?
	local spots = SPOTS[mapName]
	if not spots then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "Props"
	folder.Parent = model
	vault(model, spots.Vault)
	local set: PropSet = { Breakers = {}, Pads = {}, Center = center }
	for _, g in spots.Breakers do
		table.insert(set.Breakers, breaker(folder, g, center))
	end
	for _, g in spots.Pads do
		table.insert(set.Pads, pad(folder, g))
	end
	local top = roofPad(model:FindFirstChild(spots.RoofPad))
	if top then
		table.insert(set.Pads, top)
	end
	return set
end

return Props
