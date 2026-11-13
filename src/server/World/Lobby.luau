--!strict
-- Sky Sanctuary: a floating grass island beside the arena. Glass observation
-- balcony facing the arena, rainbow paths, winners podium, gear shop stall, map vote
-- pads, game pass pedestals, the daily quest board, the prize wheel stand and a neon
-- mini-obby around the right edge. Also builds the Disaster God's cloud perch.

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
	VotePads: { BasePart },
	BoardSlots: { CFrame }, -- ground points (facing the island) for the leaderboards
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

	for _, p in { Vector3.new(-70, 0, -14), Vector3.new(-62, 0, 30), Vector3.new(64, 0, -26), Vector3.new(-44, 0, 46), Vector3.new(44, 0, 46) } do
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
	local rail = Builder.block(b, "GlassRail", L + Vector3.new(0, 1.6, 84), Vector3.new(96, 3.2, 0.6), GLASS, Enum.Material.Glass)
	rail.Transparency = 0.75
	Builder.block(b, "RailGlow", L + Vector3.new(0, 3.4, 84), Vector3.new(96, 0.4, 1), Color3.fromRGB(80, 240, 255), Enum.Material.Neon)
	for _, x in { -48, 48 } do
		local side = Builder.block(b, "GlassRail", L + Vector3.new(x, 1.6, 72), Vector3.new(0.6, 3.2, 24), GLASS, Enum.Material.Glass)
		side.Transparency = 0.75
	end
	-- telescopes
	for _, x in { -28, 0, 28 } do
		Builder.cylinder(b, "ScopeBase", L + Vector3.new(x, 1.5, 80), 3, 1, Color3.fromRGB(60, 65, 80), Enum.Material.Metal)
		local eye = L + Vector3.new(x, 3.4, 80)
		Builder.part(b, {
			Name = "Scope",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(4, 1.4, 1.4),
			-- cylinder axis is X; rotate so it points along the look direction (toward the arena, slightly down)
			CFrame = CFrame.lookAt(eye, eye + Vector3.new(0, -0.35, 1)) * CFrame.Angles(0, math.rad(90), 0),
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
			CFrame = CFrame.new(L + Vector3.new(x, 1 + h + 3.5, 14)),
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
	-- gentle neon ramp from the finish pad's west edge back down onto the island
	local rise = (f.Position.Y + 0.5) - L.Y
	local length = rise * 2.2
	local highX = f.Position.X - 5
	local center = Vector3.new(highX - length / 2, L.Y + rise / 2, f.Position.Z)
	Builder.ramp(o, "ReturnRamp", CFrame.lookAt(center, center + Vector3.new(-1, 0, 0)), Vector3.new(6, rise, length), Color3.fromRGB(80, 220, 255), Enum.Material.Neon)
	return f
end

-- Three pads in front of the balcony; VoteService labels them and counts who stands where.
local function votePads(model: Model, L: Vector3): { BasePart }
	local f = Instance.new("Folder")
	f.Name = "VotePads"
	f.Parent = model
	local pads = {}
	for i, x in { -22, 0, 22 } do
		Builder.cylinder(f, "VoteRim", L + Vector3.new(x, 0.3, 44), 0.4, 13, Color3.fromRGB(35, 40, 60), Enum.Material.SmoothPlastic)
		pads[i] = Builder.cylinder(f, "VotePad" .. i, L + Vector3.new(x, 0.5, 44), 0.4, 11, Color3.fromRGB(110, 120, 150), Enum.Material.Neon)
	end
	return pads
end

local function prompt(parent: Instance, name: string, action: string, object: string): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

-- Daily quest board beside the spawn path (the client opens the quest window).
local function questBoard(model: Model, L: Vector3)
	local f = Instance.new("Folder")
	f.Name = "QuestBoard"
	f.Parent = model
	local c = L + Vector3.new(-22, 0, -20)
	local board = Builder.block(f, "Board", c + Vector3.new(0, 6.5, 0), Vector3.new(13, 6, 0.6), Color3.fromRGB(130, 88, 52), Enum.Material.WoodPlanks)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		Builder.sign(board, face, "📜 DAILY QUESTS\n3 new every day", Color3.fromRGB(255, 225, 90))
	end
	for _, x in { -5.5, 5.5 } do
		Builder.block(f, "Post", c + Vector3.new(x, 2, 0), Vector3.new(0.8, 4, 0.8), WOOD, Enum.Material.Wood)
	end
	prompt(board, "QuestPrompt", "View Quests", "Daily Quests")
end

-- Prize wheel stand (the client opens the spin window).
local function spinStand(model: Model, L: Vector3)
	local f = Instance.new("Folder")
	f.Name = "SpinStand"
	f.Parent = model
	local c = L + Vector3.new(22, 0, -20)
	local hub = c + Vector3.new(0, 7.5, 0)
	Builder.block(f, "Post", c + Vector3.new(0, 3.5, 0.9), Vector3.new(1.2, 7, 1), Color3.fromRGB(45, 50, 65), Enum.Material.Metal)
	Builder.part(f, {
		Name = "Rim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.7, 10, 10),
		CFrame = CFrame.new(hub) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(190, 215, 245),
	})
	local disc = Builder.part(f, {
		Name = "Disc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.9, 9, 9),
		CFrame = CFrame.new(hub) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(140, 240, 20),
	})
	for i = 0, 4 do
		Builder.part(f, {
			Name = "Spoke",
			Size = Vector3.new(0.3, 4.4, 1.05),
			CFrame = CFrame.new(hub) * CFrame.Angles(0, 0, math.rad(i * 72)) * CFrame.new(0, 2.2, 0),
			Color = Color3.fromRGB(20, 60, 20),
		})
	end
	Builder.part(f, { Name = "Hub", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(hub), Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Neon })
	Builder.block(f, "Pointer", hub + Vector3.new(0, 5.2, 0), Vector3.new(1, 1.4, 1.1), Color3.fromRGB(230, 45, 55), Enum.Material.Neon)
	local sign = Builder.block(f, "SpinSign", hub + Vector3.new(0, 7.4, 0), Vector3.new(11, 2.4, 0.5), Color3.fromRGB(255, 60, 150), Enum.Material.SmoothPlastic)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		Builder.sign(sign, face, "🎡 SPIN TO WIN", Color3.new(1, 1, 1))
	end
	prompt(disc, "SpinPrompt", "Spin", "Prize Wheel")
end

local PASS_SPOTS = {
	{ Key = "VIP", Offset = Vector3.new(-24, 0, 2), Color = Color3.fromRGB(255, 200, 40) },
	{ Key = "GodPriority", Offset = Vector3.new(-31, 0, 16), Color = Color3.fromRGB(170, 90, 255) },
	{ Key = "DoubleCoins", Offset = Vector3.new(24, 0, 2), Color = Color3.fromRGB(90, 220, 90) },
	{ Key = "QuickDash", Offset = Vector3.new(31, 0, 16), Color = Color3.fromRGB(60, 230, 230) },
}

-- Blocky display figure standing on `feet`. Returns the torso.
local function mannequin(parent: Instance, feet: Vector3, color: Color3, material: Enum.Material): BasePart
	for _, x in { -0.55, 0.55 } do
		Builder.block(parent, "Leg", feet + Vector3.new(x, 1, 0), Vector3.new(0.95, 2, 0.95), color, material)
		Builder.block(parent, "Arm", feet + Vector3.new(x * 2.75, 3, 0), Vector3.new(0.9, 2, 0.9), color, material)
	end
	local torso = Builder.block(parent, "Torso", feet + Vector3.new(0, 3, 0), Vector3.new(2, 2, 1), color, material)
	Builder.part(parent, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 1.5, 1.5), CFrame = CFrame.new(feet + Vector3.new(0, 4.8, 0)), Color = color, Material = material })
	return torso
end

-- Glowing pedestals beside the Winners Podium that show each game pass in 3D.
local function passPedestals(model: Model, L: Vector3)
	local folder = Instance.new("Folder")
	folder.Name = "PassPedestals"
	folder.Parent = model
	for _, spot in PASS_SPOTS do
		local def = Config.Monetization.Passes[spot.Key]
		local f = Instance.new("Folder")
		f.Name = spot.Key
		f.Parent = folder
		local base = L + spot.Offset
		local pedestal = Builder.cylinder(f, "Pedestal", base + Vector3.new(0, 0.6, 0), 1.2, 7, Color3.fromRGB(45, 48, 66), Enum.Material.Marble)
		local glow = Builder.cylinder(f, "Glow", base + Vector3.new(0, 1.25, 0), 0.15, 6, spot.Color, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = spot.Color
		light.Range = 16
		light.Brightness = 2
		light.Parent = glow
		local feet = base + Vector3.new(0, 1.3, 0)
		local neon = spot.Key == "GodPriority"
		local torso = mannequin(f, feet, if neon then spot.Color else Color3.fromRGB(235, 236, 242), if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic)

		if spot.Key == "VIP" then
			-- crown + the rainbow dash trail
			Builder.cylinder(f, "Crown", feet + Vector3.new(0, 5.8, 0), 0.6, 1.6, spot.Color, Enum.Material.Neon)
			for i, color in RAINBOW do
				local streak = Builder.block(f, "Trail", feet + Vector3.new(0, 1.6 + i * 0.4, 3), Vector3.new(0.25, 0.3, 4.5 - i * 0.3), color, Enum.Material.Neon)
				streak.CanCollide = false
			end
		elseif spot.Key == "GodPriority" then
			-- storm orbs in each hand
			for _, x in { -2.7, 2.7 } do
				local orb = Builder.part(f, { Name = "Orb", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = CFrame.new(feet + Vector3.new(x, 4.6, 0)), Color = Color3.fromRGB(230, 200, 255), Material = Enum.Material.Neon, CanCollide = false })
				orb.Transparency = 0.1
			end
		elseif spot.Key == "DoubleCoins" then
			-- two stacks of coins
			for _, x in { -2.4, 2.4 } do
				for k = 0, 4 do
					Builder.cylinder(f, "Coin", feet + Vector3.new(x, 0.2 + k * 0.36, 0.4), 0.3, 1.7, Color3.fromRGB(255, 200, 40), Enum.Material.Metal)
				end
			end
		else
			-- speed streaks
			for i = 1, 4 do
				local streak = Builder.block(f, "Streak", feet + Vector3.new((i - 2.5) * 0.7, 1 + i * 0.8, 3.2), Vector3.new(0.2, 0.2, 5), spot.Color, Enum.Material.Neon)
				streak.CanCollide = false
			end
		end

		local gui = Instance.new("BillboardGui")
		gui.Name = "PassLabel"
		gui.Size = UDim2.new(11, 0, 3.6, 0)
		gui.StudsOffset = Vector3.new(0, 5.4, 0)
		gui.MaxDistance = 120
		gui.Parent = torso
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.RichText = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = string.format("%s %s\n<font color=\"#FFD23C\">R$ %d</font>", def.Icon, def.Name, def.Price)
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Parent = label

		local p = prompt(pedestal, "PassPrompt", "Get " .. def.Name, def.Description)
		p:SetAttribute("PassKey", spot.Key)
	end
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
	local pads = votePads(model, L)
	questBoard(model, L)
	spinStand(model, L)
	passPedestals(model, L)

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

	-- leaderboards line the back edge, two either side of the title sign, facing the island
	local boardSlots = {}
	for _, x in { -57, -33, 33, 57 } do
		local p = L + Vector3.new(x, 0, -55)
		table.insert(boardSlots, CFrame.lookAt(p, p + Vector3.new(0, 0, 1)))
	end

	local perch = godPerch(model)

	return {
		Model = model,
		Spawn = spawn,
		PodiumAnchors = anchors,
		VotePads = pads,
		BoardSlots = boardSlots,
		ObbyFinish = finish,
		GodPerch = perch,
	}
end

return Lobby
