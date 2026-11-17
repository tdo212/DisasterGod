--!strict
-- RoleService: who is the Disaster God, who is a Survivor, who is alive, and the
-- weighted "God pity" chance that grows every round you don't get picked.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

type Role = Types.PlayerRole

local Attributes = Config.Attributes

local RoleService = {}

local roles: { [Player]: Role } = {}
local alive: { [Player]: boolean } = {}
local weights: { [Player]: number } = {}
local godQueue: { Player } = {} -- bought "Be the God Next Round", first come first served

local soloSwap = Instance.new("BindableEvent")
-- Fired as (player, role) when the solo tester toggles Survivor <-> God.
RoleService.SoloSwapRequested = soloSwap.Event

function RoleService.IsSolo(): boolean
	return #Players:GetPlayers() == 1
end

-- Free first round as the God (Config.LowPop.FirstRoundGod): a player who has never
-- played a round, in a low-pop server, who hasn't picked a role with the solo toggle.
local function freeFirstGod(p: Player): boolean
	if not Config.LowPop.FirstRoundGod or #Players:GetPlayers() > Config.LowPop.MaxRealPlayers then
		return false
	end
	local played = p:GetAttribute(Attributes.RoundsPlayed)
	local godRounds = p:GetAttribute(Attributes.GodRounds)
	return typeof(played) == "number" and played == 0 and (godRounds == nil or godRounds == 0) and p:GetAttribute(Attributes.SoloRolePicked) ~= true
end

-- A brand-new player (few rounds, never the God) weighs much more, so they get to be the
-- God in their first rounds.
local function weightOf(p: Player): number
	local w = weights[p] or Config.Pity.BaseWeight
	local played = p:GetAttribute(Attributes.RoundsPlayed)
	local godRounds = p:GetAttribute(Attributes.GodRounds)
	if typeof(played) == "number" and played < Config.Pity.NewPlayerRounds and (godRounds == nil or godRounds == 0) then
		w *= Config.Pity.NewPlayerMultiplier
	end
	return w
end

function RoleService.UpdateChances()
	local players = Players:GetPlayers()
	-- a purchased "God next round" is a guarantee: show it as 100%
	local guaranteed: Player? = nil
	for _, queued in godQueue do
		if queued.Parent then
			guaranteed = queued
			break
		end
	end
	if guaranteed then
		for _, p in players do
			p:SetAttribute(Attributes.GodChance, if p == guaranteed then 100 else 0)
		end
		return
	end
	if #players == 1 then
		local p = players[1]
		p:SetAttribute(Attributes.GodChance, if p:GetAttribute(Attributes.PreferredRole) == "DisasterGod" or freeFirstGod(p) then 100 else 0)
		return
	end
	local total = 0
	for _, p in players do
		total += weightOf(p)
	end
	for _, p in players do
		local w = weightOf(p)
		p:SetAttribute(Attributes.GodChance, if total > 0 then math.floor(w / total * 1000 + 0.5) / 10 else 0)
	end
end

function RoleService.Init()
	local function onAdded(player: Player)
		weights[player] = Config.Pity.BaseWeight
		RoleService.SetRole(player, "Spectator")
		player:SetAttribute(Attributes.PreferredRole, "Survivor")
		RoleService.UpdateChances()
	end
	Players.PlayerAdded:Connect(onAdded)
	for _, player in Players:GetPlayers() do
		onAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		roles[player] = nil
		alive[player] = nil
		weights[player] = nil
		local i = table.find(godQueue, player)
		if i then
			table.remove(godQueue, i)
		end
		task.defer(RoleService.UpdateChances)
	end)

	Remotes.get("SetSoloRole").OnServerEvent:Connect(function(player, role)
		if not Config.Match.AllowSoloRoleToggle or not RoleService.IsSolo() then
			return
		end
		if role ~= "Survivor" and role ~= "DisasterGod" then
			return
		end
		player:SetAttribute(Attributes.PreferredRole, role)
		player:SetAttribute(Attributes.SoloRolePicked, true)
		RoleService.UpdateChances()
		soloSwap:Fire(player, role)
	end)
end

function RoleService.SetRole(player: Player, role: Role)
	roles[player] = role
	alive[player] = role == "Survivor"
	player:SetAttribute(Attributes.Role, role)
	player:SetAttribute(Attributes.Alive, alive[player])
end

function RoleService.GetRole(player: Player): Role
	return roles[player] or "Spectator"
end

function RoleService.IsAliveSurvivor(player: Player): boolean
	return roles[player] == "Survivor" and alive[player] == true
end

function RoleService.MarkEliminated(player: Player): boolean
	if not RoleService.IsAliveSurvivor(player) then
		return false
	end
	alive[player] = false
	player:SetAttribute(Attributes.Alive, false)
	return true
end

function RoleService.GetGod(): Player?
	for player, role in roles do
		if role == "DisasterGod" and player.Parent then
			return player
		end
	end
	return nil
end

function RoleService.GetSurvivors(): { Player }
	local list = {}
	for player, role in roles do
		if role == "Survivor" and player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

function RoleService.GetAliveSurvivors(): { Player }
	local list = {}
	for player, role in roles do
		if role == "Survivor" and alive[player] and player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

-- Weighted pick. Solo: honour the toggle (nil = AI Director plays God).
function RoleService.PickGod(players: { Player }): Player?
	if #players == 0 then
		return nil
	end
	if #players == 1 then
		local p = players[1]
		local queued = table.find(godQueue, p)
		if queued then
			table.remove(godQueue, queued)
			p:SetAttribute(Attributes.GodQueued, false)
			return p
		end
		return if p:GetAttribute(Attributes.PreferredRole) == "DisasterGod" or freeFirstGod(p) then p else nil
	end
	while #godQueue > 0 do
		local queued = table.remove(godQueue, 1) :: Player
		if queued.Parent and table.find(players, queued) then
			queued:SetAttribute(Attributes.GodQueued, false)
			return queued
		end
	end
	-- a quiet server: a first-timer gets the free God round (one at random if several)
	local fresh = {}
	for _, p in players do
		if freeFirstGod(p) then
			table.insert(fresh, p)
		end
	end
	if #fresh > 0 then
		return fresh[math.random(#fresh)]
	end
	local total = 0
	for _, p in players do
		total += weightOf(p)
	end
	local roll = math.random() * total
	for _, p in players do
		roll -= weightOf(p)
		if roll <= 0 then
			return p
		end
	end
	return players[#players]
end

-- Called at round end: survivors build pity, the God resets.
function RoleService.AdvancePity(participants: { Player }, god: Player?, survivedSet: { [Player]: boolean })
	for _, p in participants do
		if p == god then
			weights[p] = Config.Pity.BaseWeight
		else
			local add = Config.Pity.PerRoundParticipated + (if survivedSet[p] then Config.Pity.SurvivedBonus else 0)
			if p:GetAttribute(Attributes.PassPrefix .. "GodPriority") == true then
				add *= Config.Monetization.GodPriorityPityMultiplier
			end
			weights[p] = (weights[p] or Config.Pity.BaseWeight) + add
		end
	end
	RoleService.UpdateChances()
end

-- Robux "Be the God Next Round": guaranteed pick at the next role draw.
function RoleService.QueueGod(player: Player)
	if not table.find(godQueue, player) then
		table.insert(godQueue, player)
	end
	player:SetAttribute(Attributes.GodQueued, true)
	RoleService.UpdateChances()
end

-- Bring an eliminated survivor back into the round (Second Chance).
function RoleService.Revive(player: Player): boolean
	if roles[player] ~= "Survivor" or alive[player] then
		return false
	end
	alive[player] = true
	player:SetAttribute(Attributes.Alive, true)
	return true
end

function RoleService.ResetAll()
	for _, p in Players:GetPlayers() do
		RoleService.SetRole(p, "Spectator")
	end
end

return RoleService
