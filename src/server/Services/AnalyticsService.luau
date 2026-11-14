--!strict
-- AnalyticsService: funnels and balance events for the Creator Dashboard (Roblox
-- AnalyticsService). Every call is pcall-wrapped and cheap; nothing here can break play.
--
--   Onboarding funnel (LogOnboardingFunnelStepEvent, once per player):
--     1 Joined Lobby · 2 Dismissed Role Card / Moved · 3 Entered First Match ·
--     4 Used Dash or Ability · 5 Completed First Round · 6 Opened Shop or Spin Wheel
--   MatchFlow funnel (LogFunnelStepEvent, one session per player per round):
--     1 Map Vote Cast · 2 Role Assigned · 3 First Action · 4 Survived 60s (survivor) /
--     First Elimination (God) · 5 Sudden Death Reached · 6 Round Completed
--   Monetization funnel (one session per shop / wheel visit):
--     1 Shop / Spin Opened · 2 Item Previewed · 3 Robux Prompt Shown · 4 Purchase Completed
--     (item, kind and coin balance in the custom fields)
--   Custom events: AbilityUsed (ability, kit, map|tier), SurvivorEliminated (cause, map),
--     MutatorRolled (mutator, map), RoundEnded, PurchaseCompleted, TutorialStep
--     (VoteService logs MapVote per ballot).
--   Economy events: coin sinks (SpendCoins) and coin packs bought with Robux.
--
-- Clients report UI-only steps on the "Analytics" remote (Config.Analytics.ClientEvents
-- whitelist, rate-limited).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxAnalytics = game:GetService("AnalyticsService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local AN = Config.Analytics
local Attributes = Config.Attributes

local AnalyticsService = {}

type PlayerState = {
	Onboarded: { [number]: boolean },
	Match: { [number]: boolean },
	MatchSession: string?,
	Shop: string?,
	ShopSteps: { [number]: boolean },
	LastClient: number,
	ClientBudget: number,
}

local states: { [Player]: PlayerState } = {}
local roundSession: string? = nil -- the round being voted on / played
local roundStart = 0

local function stateOf(player: Player): PlayerState
	local s = states[player]
	if not s then
		s = { Onboarded = {}, Match = {}, MatchSession = nil, Shop = nil, ShopSteps = {}, LastClient = 0, ClientBudget = AN.ClientBurst }
		states[player] = s
	end
	return s
end

local function fields(a: any?, b: any?, c: any?): { [string]: any }?
	if a == nil and b == nil and c == nil then
		return nil
	end
	local f: { [string]: any } = {}
	if a ~= nil then
		f[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = tostring(a)
	end
	if b ~= nil then
		f[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = tostring(b)
	end
	if c ~= nil then
		f[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = tostring(c)
	end
	return f
end

local function safe(fn: () -> ())
	local ok, err = pcall(fn)
	if not ok and AN.Debug then
		warn("[Analytics]", err)
	end
end

local function mapKey(): string
	local key = ReplicatedStorage:GetAttribute(Attributes.MapKey)
	return if typeof(key) == "string" and key ~= "" then key else "Unknown"
end

local function coins(player: Player): number
	local value = player:GetAttribute(Attributes.Coins)
	return if typeof(value) == "number" then value else 0
end

-- coin balance bucket so the dashboard can split purchasers by wealth
local function balanceBucket(player: Player): string
	local c = coins(player)
	for _, edge in AN.CoinBuckets do
		if c < edge then
			return "<" .. tostring(edge)
		end
	end
	return tostring(AN.CoinBuckets[#AN.CoinBuckets]) .. "+"
end

---------------------------------------------------------------------------
-- funnels

function AnalyticsService.Onboarding(player: Player, step: number)
	local s = stateOf(player)
	if s.Onboarded[step] then
		return
	end
	s.Onboarded[step] = true
	safe(function()
		RobloxAnalytics:LogOnboardingFunnelStepEvent(player, step, AN.OnboardingSteps[step])
	end)
end

function AnalyticsService.MatchStep(player: Player, step: number, a: any?, b: any?)
	local s = stateOf(player)
	if not s.MatchSession then
		s.MatchSession = (roundSession or HttpService:GenerateGUID(false)) .. ":" .. tostring(player.UserId)
	end
	if s.Match[step] then
		return
	end
	s.Match[step] = true
	local session = s.MatchSession :: string
	safe(function()
		RobloxAnalytics:LogFunnelStepEvent(player, "MatchFlow", session, step, AN.MatchSteps[step], fields(a or mapKey(), b))
	end)
end

function AnalyticsService.ShopStep(player: Player, step: number, item: string?, kind: string?)
	local s = stateOf(player)
	if step == 1 or not s.Shop then
		s.Shop = HttpService:GenerateGUID(false)
		table.clear(s.ShopSteps)
	end
	if step ~= 4 and s.ShopSteps[step] then
		return
	end
	s.ShopSteps[step] = true
	local session = s.Shop :: string
	safe(function()
		RobloxAnalytics:LogFunnelStepEvent(player, "Monetization", session, step, AN.ShopSteps[step], fields(item, kind, balanceBucket(player)))
	end)
end

local function custom(player: Player?, name: string, value: number?, a: any?, b: any?, c: any?)
	local who = player or Players:GetPlayers()[1]
	if not who then
		return
	end
	safe(function()
		RobloxAnalytics:LogCustomEvent(who, name, value or 1, fields(a, b, c))
	end)
end

---------------------------------------------------------------------------
-- game hooks (called by the owning services)

-- VoteService: a new ballot opens -> the next round's MatchFlow sessions start fresh.
function AnalyticsService.BallotOpened()
	roundSession = HttpService:GenerateGUID(false)
	for _, s in states do
		s.MatchSession = nil
		table.clear(s.Match)
	end
end

function AnalyticsService.MapVoted(player: Player, map: string)
	AnalyticsService.MatchStep(player, 1, map) -- the per-ballot "MapVote" custom event is logged by VoteService
end

-- MatchService: roles are set and the round is live.
function AnalyticsService.RoundStarted(participants: { Player }, god: Player?)
	if not roundSession then
		AnalyticsService.BallotOpened()
	end
	roundStart = os.clock()
	local session = roundSession
	for _, player in participants do
		local role = if player == god then "God" else "Survivor"
		AnalyticsService.MatchStep(player, 2, mapKey(), role)
		AnalyticsService.Onboarding(player, 3)
	end
	-- survivors still standing a minute in reached step 4
	task.delay(AN.SurviveMarkSeconds, function()
		if roundSession ~= session or ReplicatedStorage:GetAttribute(Attributes.RoundPhase) ~= "Active" then
			return
		end
		for _, player in participants do
			if player.Parent and player ~= god and player:GetAttribute(Attributes.Alive) == true then
				AnalyticsService.MatchStep(player, 4, mapKey(), "Survived60")
			end
		end
	end)
end

function AnalyticsService.FirstAction(player: Player, what: string)
	AnalyticsService.MatchStep(player, 3, mapKey(), what)
	AnalyticsService.Onboarding(player, 4)
end

-- DisasterService.tryCast (caster nil = the AI Director).
function AnalyticsService.AbilityUsed(caster: Player?, abilityId: string, tier: string?)
	local kit = if caster then caster:GetAttribute(Attributes.Kit) else "Director"
	custom(caster, "AbilityUsed", 1, abilityId, kit, mapKey() .. "|" .. tostring(tier))
	if caster then
		AnalyticsService.FirstAction(caster, "Ability")
	end
end

function AnalyticsService.SurvivorEliminated(victim: Player, cause: string, killer: Player?)
	custom(victim, "SurvivorEliminated", math.floor(os.clock() - roundStart), cause, mapKey(), if killer then "God" else "Director")
	if killer then
		AnalyticsService.MatchStep(killer, 4, mapKey(), "FirstElimination")
	end
end

function AnalyticsService.SuddenDeath(players: { Player })
	for _, player in players do
		AnalyticsService.MatchStep(player, 5)
	end
end

function AnalyticsService.RoundEnded(participants: { Player }, survivors: number, godKind: string)
	for _, player in participants do
		if player.Parent then
			AnalyticsService.MatchStep(player, 6, mapKey(), if player:GetAttribute(Attributes.Alive) == true then "Alive" else "Out")
			AnalyticsService.Onboarding(player, 5)
		end
	end
	custom(participants[1], "RoundEnded", survivors, mapKey(), godKind, #participants)
	roundSession = nil
end

function AnalyticsService.MutatorRolled(mutatorId: string)
	custom(nil, "MutatorRolled", 1, mutatorId, mapKey())
end

-- MonetizationService: a Robux purchase was granted.
function AnalyticsService.PurchaseCompleted(player: Player, key: string, kind: string, robux: number?)
	AnalyticsService.ShopStep(player, 4, key, kind)
	custom(player, "PurchaseCompleted", robux or 0, key, kind, balanceBucket(player))
end

-- PlayerDataService: coins in from a Robux pack (source) / coins spent (sink).
function AnalyticsService.CoinsBought(player: Player, amount: number, sku: string)
	safe(function()
		RobloxAnalytics:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Source, "Coins", amount, coins(player), Enum.AnalyticsEconomyTransactionType.IAP.Name, sku)
	end)
end

function AnalyticsService.CoinsSpent(player: Player, amount: number, sku: string?)
	safe(function()
		RobloxAnalytics:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Sink, "Coins", amount, coins(player), Enum.AnalyticsEconomyTransactionType.Shop.Name, sku or "Item")
	end)
end

---------------------------------------------------------------------------

local function onClient(player: Player, event: any, detail: any)
	if typeof(event) ~= "string" or not AN.ClientEvents[event] then
		return
	end
	-- token bucket: a burst of a few, then about one per second
	local s = stateOf(player)
	local now = os.clock()
	s.ClientBudget = math.min(AN.ClientBurst, s.ClientBudget + (now - s.LastClient) * AN.ClientRate)
	s.LastClient = now
	if s.ClientBudget < 1 then
		return
	end
	s.ClientBudget -= 1
	local item = if typeof(detail) == "string" then string.sub(detail, 1, 40) else nil
	if event == "Moved" or event == "CardDismissed" then
		AnalyticsService.Onboarding(player, 2)
	elseif event == "Dash" or event == "HideoutEntered" or event == "Gear" then
		AnalyticsService.FirstAction(player, event)
	elseif event == "ShopOpened" or event == "SpinOpened" then
		AnalyticsService.Onboarding(player, 6)
		AnalyticsService.ShopStep(player, 1, if event == "SpinOpened" then "Spin" else (item or "Shop"))
	elseif event == "ItemPreviewed" then
		AnalyticsService.ShopStep(player, 2, item)
	elseif event == "PromptShown" then
		AnalyticsService.ShopStep(player, 3, item, if detail and Config.Monetization.Passes[item or ""] then "Pass" else "Product")
	elseif event == "TutorialStep" then
		custom(player, "TutorialStep", 1, item)
	end
end

function AnalyticsService.Init()
	Remotes.get("Analytics").OnServerEvent:Connect(onClient)
	local function joined(player: Player)
		AnalyticsService.Onboarding(player, 1)
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return AnalyticsService
