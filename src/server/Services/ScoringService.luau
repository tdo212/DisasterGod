--!strict
-- ScoringService: round records, close-call rewards, kill credit, the kill feed (with
-- physics-aware causes and clutch callouts) and round-end payouts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local PlayerDataService = require(script.Parent.PlayerDataService)
local QuestService = require(script.Parent.QuestService)
local RoleService = require(script.Parent.RoleService)
local DestructionService = require(script.Parent.DestructionService)

local S = Config.Scoring
local F = Config.Feed
local Attributes = Config.Attributes

local ScoringService = {}

local records: { [Player]: Types.RoundRecord } = {}
local lastHit: { [Player]: { By: Player, At: number } } = {}
local lastCause: { [Player]: { Cause: string, At: number } } = {}
local lastCrush: { [Player]: { Name: string, At: number } } = {}
local lastClutch: { [Player]: number } = {}
local popup = Remotes.get("Popup")
local feed = Remotes.get("Feed")
local RED = Color3.fromRGB(255, 90, 90)

local GOLD = Color3.fromRGB(255, 210, 60)
local CYAN = Color3.fromRGB(90, 230, 255)
local PURPLE = Color3.fromRGB(200, 130, 255)

local function record(player: Player): Types.RoundRecord
	local r = records[player]
	if not r then
		r = {
			Role = RoleService.GetRole(player),
			Survived = false,
			Earned = 0,
			NearMisses = 0,
			Escapes = 0,
			Kills = 0,
			Destroyed = 0,
		}
		records[player] = r
	end
	return r
end

local function hrpOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

-- "BayHotel" / "Shophouse2" -> "Bay Hotel" / "Shophouse"
local function prettyName(name: string): string
	local base = name:gsub("%d+$", "")
	return (base:gsub("(%l)(%u)", "%1 %2"))
end

-- Pay coins and show a floating score tick. Daredevil taunts multiply survivor awards.
function ScoringService.Award(player: Player, amount: number, text: string, color: Color3?)
	local bonusEnds = player:GetAttribute(Attributes.DaredevilUntil)
	if typeof(bonusEnds) == "number" and bonusEnds > workspace:GetServerTimeNow() then
		amount = math.floor(amount * Config.Emotes.DaredevilMultiplier)
		text ..= " 😈"
	end
	local paid = PlayerDataService.EarnCoins(player, amount)
	record(player).Earned += paid
	popup:FireClient(player, string.format("%s +%d", text, paid), color or GOLD)
end

function ScoringService.Notify(player: Player, text: string, color: Color3?)
	popup:FireClient(player, text, color or PURPLE)
end

function ScoringService.ResetRound()
	table.clear(records)
	table.clear(lastHit)
	table.clear(lastCause)
	table.clear(lastCrush)
	table.clear(lastClutch)
	for _, p in Players:GetPlayers() do
		record(p)
	end
end

function ScoringService.GetRecord(player: Player): Types.RoundRecord
	return record(player)
end

-- Survivors who were just outside a blast radius get a near-miss reward.
-- `cause` (the disaster's name) turns very close calls into a kill-feed callout.
function ScoringService.CheckNearMiss(center: Vector3, radius: number, cause: string?)
	for _, player in RoleService.GetAliveSurvivors() do
		local hrp = hrpOf(player)
		if hrp then
			local flat = Vector3.new(hrp.Position.X - center.X, 0, hrp.Position.Z - center.Z).Magnitude
			if flat > radius and flat <= radius + S.NearMissMargin then
				record(player).NearMisses += 1
				QuestService.Progress(player, "NearMiss", 1)
				local mult = if player:GetAttribute(Attributes.LastStander) == true then Config.Showdown.NearMissMultiplier else 1
				ScoringService.Award(player, S.NearMissCoins * mult, if mult > 1 then "LAST STAND NEAR MISS" else "NEAR MISS", CYAN)
				Remotes.get("ClientEffect"):FireClient(player, "Shake", 0.35, 0.3)
				local margin = flat - radius
				local now = os.clock()
				if cause and margin <= F.ClutchMargin and (lastClutch[player] or 0) + F.ClutchCooldown <= now then
					lastClutch[player] = now
					feed:FireAllClients(string.format("💨 %s escaped %s by %d stud%s!", player.DisplayName, cause, math.max(1, math.round(margin)), if math.round(margin) <= 1 then "" else "s"), CYAN)
				end
			end
		end
	end
end

-- Record who (God credit) and what (kill-feed cause) last hurt `victim`.
function ScoringService.NoteHit(victim: Player, by: Player?, cause: string?)
	if cause then
		lastCause[victim] = { Cause = cause, At = os.clock() }
	end
	if by and by ~= victim then
		lastHit[victim] = { By = by, At = os.clock() }
	end
end

-- "PlayerA was flattened by Bay Hotel", "PlayerB was struck by Lightning", ...
local function deathLine(victim: Player): string
	local now = os.clock()
	local crush = lastCrush[victim]
	if crush and now - crush.At <= F.CrushWindow then
		return string.format("%s was flattened by %s", victim.DisplayName, crush.Name)
	end
	local cause = lastCause[victim]
	if cause and now - cause.At <= F.CauseWindow then
		local phrase = F.Phrases[cause.Cause]
		if phrase then
			return victim.DisplayName .. " " .. phrase
		end
		if cause.Cause:sub(1, 6) == "Fluid:" then
			return string.format("%s was swallowed by the rising %s", victim.DisplayName, string.lower(cause.Cause:sub(7)))
		end
		return string.format("%s was taken out by %s", victim.DisplayName, cause.Cause)
	end
	return victim.DisplayName .. " was eliminated"
end

-- Called when a survivor is eliminated: credits the God if they caused it and posts the
-- kill-feed line. `final` marks the round's last elimination.
function ScoringService.OnEliminated(victim: Player, final: boolean?)
	feed:FireAllClients((if final then "💀 FINAL KILL: " else "☠️ ") .. deathLine(victim), RED)
	lastCause[victim] = nil
	lastCrush[victim] = nil
	local hit = lastHit[victim]
	if hit and hit.By.Parent and os.clock() - hit.At <= S.KillCreditWindow then
		record(hit.By).Kills += 1
		PlayerDataService.RecordGodKill(hit.By)
		QuestService.Progress(hit.By, "GodKill", 1)
		ScoringService.Award(hit.By, S.GodKillCoins, "ELIMINATED " .. string.upper(victim.DisplayName), PURPLE)
	end
	lastHit[victim] = nil
end

function ScoringService.RecordDestruction(by: Player?, count: number)
	if by and count > 0 then
		record(by).Destroyed += count
	end
end

-- Round-end payouts. Returns a summary per player and the podium.
function ScoringService.FinishRound(mapName: string, god: Player?, participants: { Player }): { [Player]: Types.RoundSummary }
	local summaries: { [Player]: Types.RoundSummary } = {}
	local lines: { [Player]: { Types.SummaryLine } } = {}
	local survivorCount = #RoleService.GetAliveSurvivors()
	local mapKey = ReplicatedStorage:GetAttribute(Config.Attributes.MapKey)

	for _, p in participants do
		if not p.Parent then
			continue
		end
		local r = record(p)
		lines[p] = {}
		PlayerDataService.RecordPlayed(p)
		QuestService.Progress(p, "Play", 1)
		if r.NearMisses > 0 then
			table.insert(lines[p], { Text = string.format("Near misses x%d", r.NearMisses), Amount = r.NearMisses * S.NearMissCoins })
		end
		if r.Escapes > 0 then
			table.insert(lines[p], { Text = string.format("Structural escapes x%d", r.Escapes), Amount = r.Escapes * S.StructuralEscapeCoins })
		end
		if p == god then
			if r.Kills > 0 then
				table.insert(lines[p], { Text = string.format("Eliminations x%d", r.Kills), Amount = r.Kills * S.GodKillCoins })
			end
			QuestService.Progress(p, "Destroy", r.Destroyed)
			local destruction = math.floor(r.Destroyed * S.GodDestructionCoinsPerPart)
			if destruction > 0 then
				destruction = PlayerDataService.EarnCoins(p, destruction)
				r.Earned += destruction
				table.insert(lines[p], { Text = string.format("Destruction (%d parts)", r.Destroyed), Amount = destruction })
			end
		elseif RoleService.IsAliveSurvivor(p) then
			r.Survived = true
			local streak = PlayerDataService.RecordRound(p, true)
			local bonus = PlayerDataService.EarnCoins(p, S.SurvivalCoins + S.StreakBonusPerRound * math.max(0, streak - 1))
			PlayerDataService.RecordWin(p)
			QuestService.Progress(p, "Survive", 1)
			if typeof(mapKey) == "string" then
				QuestService.Progress(p, "Survive:" .. mapKey, 1)
			end
			r.Earned += bonus
			table.insert(lines[p], { Text = if streak > 1 then string.format("Survived (streak %d)", streak) else "Survived", Amount = bonus })
		else
			PlayerDataService.RecordRound(p, false)
		end
		local participation = PlayerDataService.EarnCoins(p, S.ParticipationCoins)
		r.Earned += participation
		table.insert(lines[p], { Text = "Participation", Amount = participation })
		if p:GetAttribute(Config.Attributes.PassPrefix .. "VIP") == true then
			local vip = PlayerDataService.EarnCoins(p, Config.Monetization.VipBonusCoinsPerRound)
			r.Earned += vip
			table.insert(lines[p], { Text = "VIP bonus", Amount = vip })
		end
	end

	-- podium: top 3 by coins earned this round
	local ranked = {}
	for _, p in participants do
		if p.Parent then
			table.insert(ranked, p)
		end
	end
	table.sort(ranked, function(a, b)
		return record(a).Earned > record(b).Earned
	end)
	local podium = {}
	for i = 1, math.min(3, #ranked) do
		table.insert(podium, { Name = ranked[i].DisplayName, Earned = record(ranked[i]).Earned })
	end

	for _, p in participants do
		if not p.Parent then
			continue
		end
		local r = record(p)
		summaries[p] = {
			MapName = mapName,
			GodName = if god then god.DisplayName else "The Storm",
			SurvivorCount = survivorCount,
			Podium = podium,
			Role = r.Role,
			Survived = r.Survived,
			Lines = lines[p],
			Total = r.Earned,
		}
	end
	return summaries
end

function ScoringService.Init()
	-- Structural escape: survivors inside a collapsing building who live through it.
	DestructionService.Collapsed:Connect(function(building: Model, center: Vector3, size: Vector3)
		local half = size / 2 + Vector3.new(4, 4, 4)
		local inside = {}
		local name = prettyName(building.Name)
		for _, player in RoleService.GetAliveSurvivors() do
			local hrp = hrpOf(player)
			if hrp then
				local d = hrp.Position - center
				if math.abs(d.X) <= half.X and math.abs(d.Y) <= half.Y and math.abs(d.Z) <= half.Z then
					table.insert(inside, player)
					lastCrush[player] = { Name = name, At = os.clock() }
				end
			end
		end
		if #inside == 0 then
			return
		end
		task.delay(S.StructuralEscapeWindow, function()
			for _, player in inside do
				if RoleService.IsAliveSurvivor(player) then
					record(player).Escapes += 1
					QuestService.Progress(player, "Escape", 1)
					ScoringService.Award(player, S.StructuralEscapeCoins, "STRUCTURAL ESCAPE", GOLD)
					feed:FireAllClients(string.format("🏃 %s escaped the collapsing %s!", player.DisplayName, name), GOLD)
				end
			end
		end)
	end)
end

return ScoringService
