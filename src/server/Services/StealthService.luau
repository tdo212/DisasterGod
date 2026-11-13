--!strict
-- StealthService: hide-and-seek between survivors and the God.
--   * Hidden: a survivor standing still under an intact roof, or inside a jammed zone,
--     gets the Hidden attribute. The God's client drops their through-wall name tag,
--     and the anti-camp radar and Seismic Ping skip jammed survivors.
--   * Noise: jumps, dashes, gear, emotes, launch pads and windows shattering next to
--     you send a ripple that only the God sees (ClientEffect "Noise").
--   * Jams: circuit breakers (PropService) open a zone that hides everyone inside.
--   * Reveal: the Seismic Ping shows survivor silhouettes to the God through walls.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DestructionService = require(script.Parent.DestructionService)
local MapService = require(script.Parent.MapService)
local RoleService = require(script.Parent.RoleService)

local S = Config.Stealth
local HIDDEN = Config.Attributes.Hidden

local StealthService = {}

type Jam = { Position: Vector3, Radius: number, Until: number }

local clientEffect = Remotes.get("ClientEffect")
local stillFor: { [Player]: number } = {}
local lastNoise: { [Player]: number } = {}
local indoors: { [Player]: boolean } = {}
local jams: { Jam } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local function hrpOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function godOf(): Player?
	local god = RoleService.GetGod()
	return if god and god.Parent then god else nil
end

-- An intact structural part (a roof or upper floor) directly overhead.
local function underRoof(hrp: BasePart): boolean
	rayParams.FilterDescendantsInstances = { MapService.GetArenaFolder() }
	local hit = workspace:Raycast(hrp.Position + Vector3.new(0, 3, 0), Vector3.new(0, S.RoofCheckHeight, 0), rayParams)
	local part = hit and hit.Instance
	return part ~= nil and part:GetAttribute("Structural") == true and part:GetAttribute("Broken") ~= true
end

function StealthService.IsJammed(position: Vector3): boolean
	local now = os.clock()
	for _, jam in jams do
		if jam.Until > now and (position - jam.Position).Magnitude <= jam.Radius then
			return true
		end
	end
	return false
end

-- Indoors (under an intact roof) as of the last stealth tick.
function StealthService.IsIndoors(player: Player): boolean
	return indoors[player] == true
end

function StealthService.IsHidden(player: Player): boolean
	return player:GetAttribute(HIDDEN) == true
end

-- A ripple at the survivor's feet that only the God sees. Breaks hiding.
function StealthService.Noise(player: Player, strength: number?)
	local hrp = hrpOf(player)
	local god = godOf()
	if not (hrp and RoleService.IsAliveSurvivor(player)) then
		return
	end
	stillFor[player] = 0
	player:SetAttribute(HIDDEN, false)
	local now = os.clock()
	if (lastNoise[player] or 0) + S.NoiseCooldown > now then
		return
	end
	lastNoise[player] = now
	if god and not StealthService.IsJammed(hrp.Position) then
		clientEffect:FireClient(god, "Noise", hrp.Position, strength or 1)
	end
end

-- Circuit breaker: hide everyone inside `radius` for `duration` seconds.
function StealthService.AddJam(position: Vector3, radius: number, duration: number)
	table.insert(jams, { Position = position, Radius = radius, Until = os.clock() + duration })
	clientEffect:FireAllClients("Jam", position, radius, duration)
end

-- Seismic Ping: show every non-jammed survivor within `radius` to the God for `duration`.
-- Returns how many were revealed.
function StealthService.Reveal(center: Vector3, radius: number, duration: number, god: Player?): number
	local found: { Model } = {}
	for _, player in RoleService.GetAliveSurvivors() do
		local hrp = hrpOf(player)
		if hrp and player.Character and (hrp.Position - center).Magnitude <= radius and not StealthService.IsJammed(hrp.Position) then
			table.insert(found, player.Character)
			clientEffect:FireClient(player, "Pinged", duration)
		end
	end
	if god and #found > 0 then
		clientEffect:FireClient(god, "Reveal", found, duration)
	end
	return #found
end

local function tick()
	local now = os.clock()
	for i = #jams, 1, -1 do
		if jams[i].Until <= now then
			table.remove(jams, i)
		end
	end
	local alive: { [Player]: boolean } = {}
	for _, player in RoleService.GetAliveSurvivors() do
		alive[player] = true
		local hrp = hrpOf(player)
		if not hrp then
			continue
		end
		local v = hrp.AssemblyLinearVelocity
		local flat = Vector3.new(v.X, 0, v.Z).Magnitude
		if v.Y > S.JumpNoiseSpeed or flat > S.RunNoiseSpeed then
			StealthService.Noise(player, if flat > S.RunNoiseSpeed then 1.3 else 1)
		end
		indoors[player] = underRoof(hrp)
		if flat < S.StillSpeed and math.abs(v.Y) < S.StillSpeed then
			stillFor[player] = (stillFor[player] or 0) + S.CheckInterval
		else
			stillFor[player] = 0
		end
		local hidden = StealthService.IsJammed(hrp.Position) or (indoors[player] and (stillFor[player] or 0) >= S.HideDelay)
		if player:GetAttribute(HIDDEN) ~= hidden then
			player:SetAttribute(HIDDEN, hidden)
		end
	end
	-- anyone no longer an alive survivor is never hidden
	for _, player in Players:GetPlayers() do
		if not alive[player] and player:GetAttribute(HIDDEN) == true then
			player:SetAttribute(HIDDEN, false)
		end
	end
end

function StealthService.Reset()
	table.clear(jams)
	table.clear(stillFor)
	table.clear(indoors)
end

function StealthService.Init()
	-- shattering glass gives away whoever is standing next to the window
	DestructionService.GlassBroken:Connect(function(position: Vector3)
		for _, player in RoleService.GetAliveSurvivors() do
			local hrp = hrpOf(player)
			if hrp and (hrp.Position - position).Magnitude <= S.GlassNoiseRadius then
				StealthService.Noise(player, 0.8)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		stillFor[player] = nil
		lastNoise[player] = nil
		indoors[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(S.CheckInterval)
			local ok, err = pcall(tick)
			if not ok then
				warn("[StealthService]", err)
			end
		end
	end)
end

return StealthService
