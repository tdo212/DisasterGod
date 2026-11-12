--!strict
-- ScoringService: round records, close-call rewards, kill credit and round-end payouts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local PlayerDataService = require(script.Parent.PlayerDataService)
local RoleService = require(script.Parent.RoleService)
local DestructionService = require(script.Parent.DestructionService)

local S = Config.Scoring

local ScoringService = {}

local records: { [Player]: Types.RoundRecord } = {}
local lastHit: { [Player]: { By: Player, At: number } } = {}
local popup = Remotes.get("Popup")

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

-- Pay coins and show a floating score tick.
function ScoringService.Award(player: Player, amount: number, text: string, color: Color3?)
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
	for _, p in Players:GetPlayers() do
		record(p)
	end
end

function ScoringService.GetRecord(player: Player): Types.RoundRecord
	return record(player)
end

-- Survivors who were just outside a blast radius get a near-miss reward.
function ScoringService.CheckNearMiss(center: Vector3, radius: number)
	for _, player in RoleService.GetAliveSurvivors() do
		local hrp = hrpOf(player)
		if hrp then
			local flat = Vector3.new(hrp.Position.X - center.X, 0, hrp.Position.Z - center.Z).Magnitude
			if flat > radius and flat <= radius + S.NearMissMargin then
				record(player).NearMisses += 1
				ScoringService.Award(player, S.NearMissCoins, "NEAR MISS", CYAN)
				Remotes.get("ClientEffect"):FireClient(player, "Shake", 0.35, 0.3)
			end
		end
	end
end

function ScoringService.NoteHit(victim: Player, by: Player?)
	if by and by ~= victim then
		lastHit[victim] = { By = by, At = os.clock() }
	end
end

-- Called when a survivor is eliminated: credits the God if they caused it.
function ScoringService.OnEliminated(victim: Player)
	local hit = lastHit[victim]
	if hit and hit.By.Parent and os.clock() - hit.At <= S.KillCreditWindow then
		record(hit.By).Kills += 1
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

	for _, p in participants do
		if not p.Parent then
			continue
		end
		local r = record(p)
		lines[p] = {}
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
	DestructionService.Collapsed:Connect(function(_building: Model, center: Vector3, size: Vector3)
		local half = size / 2 + Vector3.new(4, 4, 4)
		local inside = {}
		for _, player in RoleService.GetAliveSurvivors() do
			local hrp = hrpOf(player)
			if hrp then
				local d = hrp.Position - center
				if math.abs(d.X) <= half.X and math.abs(d.Y) <= half.Y and math.abs(d.Z) <= half.Z then
					table.insert(inside, player)
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
					ScoringService.Award(player, S.StructuralEscapeCoins, "STRUCTURAL ESCAPE", GOLD)
				end
			end
		end)
	end)
end

return ScoringService
