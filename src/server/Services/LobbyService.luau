--!strict
-- LobbyService: builds the Sky Sanctuary and runs its activities — obby rewards,
-- winners podium, coin leaderboard, fall resets and ghost "haunt" pings.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Lobby = require(ServerScriptService.Server.World.Lobby)

local MapService = require(script.Parent.MapService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RoleService = require(script.Parent.RoleService)
local ScoringService = require(script.Parent.ScoringService)

local LobbyService = {}

local info: Lobby.LobbyInfo
local obbyCooldown: { [Player]: number } = {}
local pingCooldown: { [Player]: number } = {}
local castingOpen = false

local function hrpOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

function LobbyService.GetSpawnCFrame(): CFrame
	local spread = 4
	return info.Spawn.CFrame * CFrame.new(math.random(-spread, spread), 4, math.random(-spread, spread))
end

function LobbyService.TeleportToLobby(player: Player)
	local character = player.Character
	if character then
		character:PivotTo(LobbyService.GetSpawnCFrame())
	end
end

function LobbyService.GetGodPerchCFrame(): CFrame
	return CFrame.new(Config.World.GodPerch + Vector3.new(0, 0.5, 0))
end

function LobbyService.SetGhostPingsOpen(open: boolean)
	castingOpen = open
end

local function makeBillboard(anchor: BasePart): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "PodiumName"
	-- sized in studs so the three names never overlap, hidden until there's a winner
	gui.Size = UDim2.new(7.5, 0, 2.6, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 160
	gui.Enabled = false
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "—"
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label
	return label
end

local podiumLabels: { TextLabel } = {}
local leaderboardRows: { TextLabel } = {}
local LEADERBOARD_ROWS = 8

function LobbyService.SetPodium(entries: { { Name: string, Earned: number } })
	for i, label in podiumLabels do
		local entry = entries[i]
		label.Text = if entry then string.format("%s\n+%d", entry.Name, entry.Earned) else ""
		local gui = label.Parent :: BillboardGui
		gui.Enabled = entry ~= nil
	end
end

local function refreshLeaderboard()
	local rows = {}
	for _, p in Players:GetPlayers() do
		local profile = PlayerDataService.Get(p)
		if profile then
			table.insert(rows, { Name = p.DisplayName, Coins = profile.Coins, Streak = profile.BestStreak })
		end
	end
	table.sort(rows, function(a, b)
		return a.Coins > b.Coins
	end)
	for i, label in leaderboardRows do
		local row = rows[i]
		label.Text = if row then string.format("%d. %s   $%s   best %d", i, row.Name, tostring(row.Coins), row.Streak) else ""
	end
end

local function ghostPing(position: Vector3)
	local ground = MapService.GroundAt(position)
	local hazards = MapService.GetHazardsFolder()
	local ring = Instance.new("Part")
	ring.Name = "GhostPing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(190, 160, 255)
	ring.Transparency = 0.3
	ring.Size = Vector3.new(0.2, 3, 3)
	ring.CFrame = CFrame.new(ground + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = hazards
	TweenService:Create(ring, TweenInfo.new(1.6, Enum.EasingStyle.Quad), { Size = Vector3.new(0.2, 26, 26), Transparency = 1 }):Play()
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(60, 60)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.Parent = ring
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "👻"
	label.TextScaled = true
	label.Parent = gui
	Debris:AddItem(ring, 1.7)
end

function LobbyService.Init()
	-- template leftovers (Baseplate would cover the ocean/lava; a stray spawn would bypass the lobby)
	local ServerStorage = game:GetService("ServerStorage")
	for _, child in workspace:GetChildren() do
		if child.Name == "Baseplate" or (child:IsA("SpawnLocation") and child.Name ~= "LobbySpawn") then
			child.Parent = ServerStorage
		end
	end
	-- a preview copy may exist from edit-mode building; runtime always rebuilds from code
	local stale = workspace:FindFirstChild("SkySanctuary")
	if stale then
		stale:Destroy()
	end
	info = Lobby.build(workspace)
	-- anyone who spawned before the island existed gets placed on it
	for _, player in Players:GetPlayers() do
		task.spawn(LobbyService.TeleportToLobby, player)
	end

	for _, anchor in info.PodiumAnchors do
		table.insert(podiumLabels, makeBillboard(anchor))
	end

	local boardGui = Instance.new("SurfaceGui")
	boardGui.Face = Enum.NormalId.Back
	boardGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	boardGui.PixelsPerStud = 30
	boardGui.LightInfluence = 0
	boardGui.Parent = info.Leaderboard
	-- readable board: a big header + one scaled text row per entry
	local function boardLabel(text: string, y: number, h: number, color: Color3): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, -40, h, 0)
		label.Position = UDim2.new(0, 20, y, 0)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = color
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = text
		label.Parent = boardGui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = label
		return label
	end
	local header = boardLabel("🏆 TOP SURVIVORS", 0.03, 0.16, Color3.fromRGB(255, 210, 60))
	header.TextXAlignment = Enum.TextXAlignment.Center
	for i = 1, LEADERBOARD_ROWS do
		table.insert(leaderboardRows, boardLabel("", 0.2 + (i - 1) * 0.098, 0.088, Color3.new(1, 1, 1)))
	end

	info.ObbyFinish.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local now = os.clock()
		if (obbyCooldown[player] or 0) > now then
			return
		end
		obbyCooldown[player] = now + Config.Scoring.ObbyCooldown
		ScoringService.Award(player, Config.Scoring.ObbyCoins, "OBBY CLEAR", Color3.fromRGB(120, 255, 140))
	end)

	Remotes.get("GhostPing").OnServerEvent:Connect(function(player, position)
		if typeof(position) ~= "Vector3" or position.X ~= position.X then
			return
		end
		if not castingOpen or RoleService.GetRole(player) == "DisasterGod" or RoleService.IsAliveSurvivor(player) then
			return
		end
		if not MapService.InBounds(position) then
			return
		end
		local now = os.clock()
		if (pingCooldown[player] or 0) > now then
			return
		end
		pingCooldown[player] = now + Config.Scoring.GhostPingCooldown
		ghostPing(position)
	end)

	Players.PlayerRemoving:Connect(function(player)
		obbyCooldown[player] = nil
		pingCooldown[player] = nil
	end)

	-- fall reset: anyone not playing in the arena who drops off the island returns to spawn
	local resetY = Config.World.LobbyOrigin.Y - Config.Player.LobbyFallResetDepth
	task.spawn(function()
		local boardTimer = 0
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				if RoleService.IsAliveSurvivor(player) or RoleService.GetRole(player) == "DisasterGod" then
					continue
				end
				local hrp = hrpOf(player)
				if hrp and hrp.Position.Y < resetY then
					hrp.AssemblyLinearVelocity = Vector3.zero
					LobbyService.TeleportToLobby(player)
				end
			end
			boardTimer += 0.5
			if boardTimer >= 5 then
				boardTimer = 0
				refreshLeaderboard()
			end
		end
	end)
	refreshLeaderboard()
end

return LobbyService
