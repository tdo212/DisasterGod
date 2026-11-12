--!strict
-- Sky Sanctuary: a floating grass island beside the arena. Glass observation
-- balcony facing the arena, rainbow paths, winners podium, gear shop stall and a
-- neon mini-obby around the right edge. Also builds the Disaster God's cloud perch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Builder)
local Config = require(ReplicatedStorage.Shared.Config)

local GRASS = Color3.fromRGB(105, 210, 80)
local ROCK = Color3.fromRGB(125, 105, 90)
local ROCK_DARK = Color3.fromRGB(95, 82, 75)
local MARBLE = Color3.fromRGB(232, 236, 242)
local GLASS = Color3.fromRGB(170, 225, 255)
local WOOD = Color3.fromRGB(165, 115, 70)
local PINK = Color3.fromRGB(255, 160, 200)
local RAINBOW = {
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(255, 160, 50),
	Color3.fromRGB(255, 225, 60),
	Color3.fromRGB(90, 220, 90),
	Color3.fromRGB(70, 160, 255),
	Color3.fromRGB(170, 100, 255),
}

export type LobbyInfo = {
	Model: Model,
	Spawn: SpawnLocation,
	PodiumAnchors: { BasePart },
	Leaderboard: BasePart,
	ObbyFinish: BasePart,
	GodPerch: BasePart,
}

local Lobby = {}

local function tree(parent: Instance, pos: Vector3)
	Builder.block(parent, "Trunk", pos + Vector3.new(0, 4, 0), Vector3.new(2, 8, 2), WOOD, Enum.Material.Wood)
	for _, o in { Vector3.new(0, 9, 0), Vector3.new(2.5, 8, 1), Vector3.new(-2.5, 8.5, -1) } do
		Builder.part(parent, {
			Name = "Blossom",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(7, 7, 7),
			CFrame = CFrame.new(pos + o),
			Color = PINK,
			Material = Enum.Material.Grass,
		})
	end
end

local function lamp(parent: Instance, pos: Vector3)
	Builder.block(parent, "LampPost", pos + Vector3.new(0, 4, 0), Vector3.new(0.8, 8, 0.8), Color3.fromRGB(45, 50, 65), Enum.Material.Metal)
	local bulb = Builder.part(parent, {
		Name = "LampBulb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2, 2),
		CFrame = CFrame.new(pos + Vector3.new(0, 8.6, 0)),
		Color = Color3.fromRGB(255, 240, 190),
		Material = Enum.Material.Neon,
	})
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 1.5
	light.Parent = bulb
end

local function island(model: Model, L: Vector3)
	local ground = Instance.new("Folder")
	ground.Name = "Island"
	ground.Parent = model
	Builder.block(ground, "Grass", L + Vector3.new(0, -3, 0), Vector3.new(150, 6, 120), GRASS, Enum.Material.Grass)
	Builder.block(ground, "Rock1", L + Vector3.new(0, -13, 0), Vector3.new(132, 14, 102), ROCK, Enum.Material.Rock)
	Builder.block(ground, "Rock2", L + Vector3.new(4, -26, -2), Vector3.new(100, 14, 76), ROCK_DARK, Enum.Material.Rock)
	Builder.block(ground, "Rock3", L + Vector3.new(-3, -40, 2), Vector3.new(60, 16, 46), ROCK, Enum.Material.Rock)
	Builder.block(ground, "Rock4", L + Vector3.new(2, -54, 0), Vector3.new(24, 14, 20), ROCK_DARK, Enum.Material.Rock)

	-- rainbow paths (spawn -> podium -> balcony, and shop <-> obby)
	local i = 0
	for z = -44, 56, 7 do
		i += 1
		Builder.block(ground, "PathTile", L + Vector3.new(0, 0.2, z), Vector3.new(8, 0.4, 6), RAINBOW[(i % #RAINBOW) + 1], Enum.Material.SmoothPlastic)
	end
	i = 0
	for x = -36, 66, 7 do
		i += 1
		if math.abs(x) < 16 then
			continue
		end
		Builder.block(ground, "PathTile", L + Vector3.new(x, 0.2, -6), Vector3.new(6, 0.4, 7), RAINBOW[(i % #RAINBOW) + 1], Enum.Material.SmoothPlastic)
	end

	for _, p in { Vector3.new(-60, 0, -45), Vector3.new(-62, 0, 30), Vector3.new(58, 0, -48), Vector3.new(-25, 0, 40), Vector3.new(30, 0, 42) } do
		tree(ground, L + p)
	end
	for _, p in { Vector3.new(-8, 0, -20), Vector3.new(8, 0, -20), Vector3.new(-8, 0, 30), Vector3.new(8, 0, 30) } do
		lamp(ground, L + p)
	end
end

local function balcony(model: Model, L: Vector3)
	local b = Instance.new("Folder")
	b.Name = "Balcony"
	b.Parent = model
	Builder.block(b, "Deck", L + Vector3.new(0, -1, 72), Vector3.new(96, 2, 24), MARBLE, Enum.Material.Marble)
	local rail = Builder.block(b, "GlassRail", L + Vector3.new(0, 2.5, 84), Vector3.new(96, 5, 0.6), GLASS, Enum.Material.Glass)
	rail.Transparency = 0.55
	Builder.block(b, "RailGlow", L + Vector3.new(0, 5.2, 84), Vector3.new(96, 0.4, 1), Color3.fromRGB(80, 240, 255), Enum.Material.Neon)
	for _, x in { -48, 48 } do
		local side = Builder.block(b, "GlassRail", L + Vector3.new(x, 2.5, 72), Vector3.new(0.6, 5, 24), GLASS, Enum.Material.Glass)
		side.Transparency = 0.55
	end
	-- telescopes
	for _, x in { -28, 0, 28 } do
		Builder.cylinder(b, "ScopeBase", L + Vector3.new(x, 1.5, 80), 3, 1, Color3.fromRGB(60, 65, 80), Enum.Material.Metal)
		Builder.part(b, {
			Name = "Scope",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(4, 1.4, 1.4),
			CFrame = CFrame.new(L + Vector3.new(x, 3.4, 80)) * CFrame.Angles(0, math.rad(90), math.rad(-20)),
			Color = Color3.fromRGB(210, 215, 230),
			Material = Enum.Material.Metal,
		})
	end
	local sign = Builder.block(b, "BalconySign", L + Vector3.new(0, 8, 60.5), Vector3.new(30, 4, 0.5), Color3.fromRGB(35, 40, 60), Enum.Material.SmoothPlastic)
	Builder.sign(sign, Enum.NormalId.Front, "OBSERVATION DECK", Color3.fromRGB(120, 240, 255))
	for _, x in { -14, 14 } do
		Builder.block(b, "SignPost", L + Vector3.new(x, 3, 60.5), Vector3.new(0.6, 6, 0.6), Color3.fromRGB(35, 40, 60), Enum.Material.Metal)
	end
end

local function podium(model: Model, L: Vector3): { BasePart }
	local p = Instance.new("Folder")
	p.Name = "Podium"
	p.Parent = model
	Builder.cylinder(p, "Plinth", L + Vector3.new(0, 0.5, 14), 1, 30, Color3.fromRGB(60, 65, 85), Enum.Material.Marble)
	local anchors = {}
	local spec = {
		{ 0, 7, Color3.fromRGB(255, 200, 40), "1", Color3.fromRGB(255, 225, 90) },
		{ -9, 5, Color3.fromRGB(205, 210, 220), "2", Color3.fromRGB(110, 210, 255) },
		{ 9, 3.5, Color3.fromRGB(215, 135, 60), "3", Color3.fromRGB(255, 120, 200) },
	}
	for i, s in spec do
		local x, h, color, label, beam = s[1], s[2], s[3], s[4], s[5]
		local block = Builder.cylinder(p, "Podium" .. label, L + Vector3.new(x, 1 + h / 2, 14), h, 8, color, Enum.Material.SmoothPlastic)
		local plate = Builder.block(p, "Number" .. label, L + Vector3.new(x, 1 + h / 2, 9.8), Vector3.new(3, 3, 0.4), Color3.fromRGB(40, 40, 55), Enum.Material.SmoothPlastic)
		Builder.sign(plate, Enum.NormalId.Front, label, Color3.new(1, 1, 1))
		local light = Builder.cylinder(p, "Beam", L + Vector3.new(x, 1 + h + 30, 18), 60, 3, beam, Enum.Material.Neon)
		light.Transparency = 0.6
		light.CanCollide = false
		light.CastShadow = false

		local anchor = Builder.part(p, {
			Name = "PodiumAnchor" .. i,
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(L + Vector3.new(x, 1 + h + 5, 14)),
			Color = Color3.new(1, 1, 1),
			Transparency = 1,
			CanCollide = false,
		})
		anchors[i] = anchor
		block:SetAttribute("PodiumRank", i)
	end
	local title = Builder.block(p, "WinnersSign", L + Vector3.new(0, 14, 22), Vector3.new(24, 4, 0.5), Color3.fromRGB(255, 190, 40), Enum.Material.SmoothPlastic)
	Builder.sign(title, Enum.NormalId.Front, "WINNERS PODIUM", Color3.new(1, 1, 1))
	Builder.sign(title, Enum.NormalId.Back, "WINNERS PODIUM", Color3.new(1, 1, 1))
	return anchors
end

local function shop(model: Model, L: Vector3)
	local s = Instance.new("Folder")
	s.Name = "ShopStall"
	s.Parent = model
	local c = L + Vector3.new(-45, 0, -6)
	local counter = Builder.block(s, "Counter", c + Vector3.new(0, 2, 4), Vector3.new(18, 4, 4), WOOD, Enum.Material.WoodPlanks)
	Builder.block(s, "CounterTop", c + Vector3.new(0, 4.2, 4), Vector3.new(19, 0.4, 5), Color3.fromRGB(240, 240, 245), Enum.Material.SmoothPlastic)
	Builder.block(s, "BackWall", c + Vector3.new(0, 5, -4), Vector3.new(18, 10, 1), Color3.fromRGB(235, 240, 250), Enum.Material.SmoothPlastic)
	for _, x in { -8.5, 8.5 } do
		for _, z in { -4, 5.5 } do
			Builder.block(s, "Post", c + Vector3.new(x, 5.5, z), Vector3.new(1, 11, 1), Color3.fromRGB(70, 140, 230), Enum.Material.SmoothPlastic)
		end
	end
	-- striped awning roof (blue / white like the references)
	for i = 0, 8 do
		Builder.block(s, "Awning", c + Vector3.new(-8 + i * 2, 11.3, 1), Vector3.new(2, 0.8, 12), if i % 2 == 0 then Color3.fromRGB(60, 140, 240) else Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	end
	local sign = Builder.block(s, "ShopSign", c + Vector3.new(0, 14, 6.5), Vector3.new(14, 4, 1), Color3.fromRGB(60, 140, 240), Enum.Material.SmoothPlastic)
	Builder.sign(sign, Enum.NormalId.Back, "SHOP", Color3.new(1, 1, 1))
	Builder.sign(sign, Enum.NormalId.Front, "SHOP", Color3.new(1, 1, 1))
	-- shelf bottles
	for i = 0, 6 do
		Builder.cylinder(s, "Bottle", c + Vector3.new(-6 + i * 2, 7.2, -3), 1.6, 0.9, RAINBOW[(i % #RAINBOW) + 1], Enum.Material.Glass)
	end
	Builder.block(s, "Shelf", c + Vector3.new(0, 6.2, -3), Vector3.new(16, 0.4, 1.5), WOOD, Enum.Material.Wood)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Open Shop"
	prompt.ObjectText = "Gear Shop"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
end

local function obby(model: Model, L: Vector3): BasePart
	local o = Instance.new("Folder")
	o.Name = "NeonObby"
	o.Parent = model
	local count = 12
	local finish: BasePart? = nil
	for i = 1, count do
		local t = i / count
		local pos = L + Vector3.new(82 + math.sin(i * 0.9) * 6, 1 + i * 1.6, -46 + t * 100)
		local isLast = i == count
		local pad = Builder.part(o, {
			Name = if isLast then "ObbyFinish" else "ObbyPad",
			Size = if isLast then Vector3.new(10, 1, 10) else Vector3.new(5, 1, 5),
			CFrame = CFrame.new(pos),
			Color = if isLast then Color3.fromRGB(255, 200, 40) else RAINBOW[(i % #RAINBOW) + 1],
			Material = Enum.Material.Neon,
		})
		if isLast then
			finish = pad
			Builder.block(o, "FlagPole", pos + Vector3.new(3.5, 5, 3.5), Vector3.new(0.5, 9, 0.5), Color3.new(1, 1, 1), Enum.Material.Metal)
			Builder.block(o, "Flag", pos + Vector3.new(3.5, 8.5, 1.5), Vector3.new(0.2, 2.5, 3.5), Color3.fromRGB(255, 70, 90), Enum.Material.SmoothPlastic)
		end
	end
	local start = Builder.block(o, "ObbyStart", L + Vector3.new(72, 0.6, -50), Vector3.new(6, 0.4, 6), Color3.fromRGB(90, 230, 120), Enum.Material.Neon)
	Builder.sign(start, Enum.NormalId.Top, "OBBY", Color3.new(1, 1, 1))
	-- return bridge from the finish back onto the island
	local f = finish :: BasePart
	local a = f.Position + Vector3.new(-5, 0, 0)
	local b = L + Vector3.new(70, 0, 54)
	Builder.part(o, {
		Name = "ReturnSlide",
		Size = Vector3.new(4, 1, (b - a).Magnitude),
		CFrame = CFrame.lookAt((a + b) / 2, b),
		Color = Color3.fromRGB(80, 220, 255),
		Material = Enum.Material.Neon,
	})
	return f
end

local function godPerch(model: Model): BasePart
	local p = Config.World.GodPerch
	local folder = Instance.new("Folder")
	folder.Name = "GodPerch"
	folder.Parent = model
	local platform = Builder.cylinder(folder, "PerchPlatform", p - Vector3.new(0, 3.5, 0), 1, 14, Color3.fromRGB(150, 90, 255), Enum.Material.Neon)
	platform.Transparency = 0.2
	for _, o in { Vector3.new(5, -5, 0), Vector3.new(-5, -5.5, 2), Vector3.new(0, -6, -5), Vector3.new(2, -4.5, 5) } do
		local puff = Builder.part(folder, {
			Name = "Cloud",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(9, 9, 9),
			CFrame = CFrame.new(p + o),
			Color = Color3.fromRGB(235, 230, 255),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
		puff.Transparency = 0.15
	end
	return platform
end

function Lobby.build(parent: Instance): LobbyInfo
	local L = Config.World.LobbyOrigin
	local model = Instance.new("Model")
	model.Name = "SkySanctuary"
	model.Parent = parent

	island(model, L)
	balcony(model, L)
	local anchors = podium(model, L)
	shop(model, L)
	local finish = obby(model, L)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(L + Vector3.new(0, 0.5, -34))
	spawn.Color = Color3.fromRGB(80, 170, 255)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = model
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	local title = Builder.block(model, "TitleSign", L + Vector3.new(0, 16, -52), Vector3.new(40, 7, 1), Color3.fromRGB(255, 160, 30), Enum.Material.SmoothPlastic)
	Builder.sign(title, Enum.NormalId.Front, "SKY SANCTUARY", Color3.new(1, 1, 1))
	Builder.sign(title, Enum.NormalId.Back, "SKY SANCTUARY", Color3.new(1, 1, 1))
	for _, x in { -18, 18 } do
		Builder.block(model, "TitlePost", L + Vector3.new(x, 6, -52), Vector3.new(1, 12, 1), Color3.fromRGB(70, 70, 90), Enum.Material.Metal)
	end

	local board = Builder.block(model, "Leaderboard", L + Vector3.new(38, 8, -50), Vector3.new(26, 14, 1), Color3.fromRGB(35, 38, 55), Enum.Material.SmoothPlastic)
	for _, x in { 26, 50 } do
		Builder.block(model, "BoardPost", L + Vector3.new(x, 1, -50), Vector3.new(1, 2, 1), Color3.fromRGB(70, 70, 90), Enum.Material.Metal)
	end

	local perch = godPerch(model)

	return {
		Model = model,
		Spawn = spawn,
		PodiumAnchors = anchors,
		Leaderboard = board,
		ObbyFinish = finish,
		GodPerch = perch,
	}
end

return Lobby
