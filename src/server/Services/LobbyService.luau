--!strict
-- LobbyService: builds the Sky Lodge and runs its activities — obby rewards, fall
-- resets and ghost "haunt" pings. Hands the vote pads to VoteService and the
-- leaderboard slots and Hall of Legends podium to LeaderboardService.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Lobby = require(ServerScriptService.Server.World.Lobby)

local LeaderboardService = require(script.Parent.LeaderboardService)
local MapService = require(script.Parent.MapService)
local QuestService = require(script.Parent.QuestService)
local RoleService = require(script.Parent.RoleService)
local ScoringService = require(script.Parent.ScoringService)
local VoteService = require(script.Parent.VoteService)

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
	for _, name in { "SkyLodge", "SkySanctuary" } do
		local stale = workspace:FindFirstChild(name)
		if stale then
			stale:Destroy()
		end
	end
	info = Lobby.build(workspace)
	-- anyone who spawned before the lodge existed gets placed in it
	for _, player in Players:GetPlayers() do
		task.spawn(LobbyService.TeleportToLobby, player)
	end

	VoteService.SetPads(info.VotePads)
	LeaderboardService.Setup(info.BoardSlots)
	LeaderboardService.SetupHall(info.HallSpots, info.Model)

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
		QuestService.Progress(player, "Obby", 1)
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

	-- fall reset: anyone not playing in the arena who somehow drops out of the lodge returns to spawn
	local resetY = Config.World.LobbyOrigin.Y - Config.Player.LobbyFallResetDepth
	task.spawn(function()
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
		end
	end)
end

return LobbyService
