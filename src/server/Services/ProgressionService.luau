--!strict
-- ProgressionService: long-term progression and the small social hooks.
--   * Mastery (Config.Mastery): profile counters (rounds survived, ghost rounds, taunts,
--     parts destroyed, God wins per kit) unlock tiered titles ("Storm Herald III"). The
--     best one floats over your head and is published as the Title attribute.
--   * Daily streak (Config.Daily): play on consecutive days to grow a 7-day streak; a chest
--     in the Sky Lodge pays today's reward once (day 3: a spin token, day 7: the Golden
--     Trail dash). First survived round and first God win each day pay double.
--   * Quick settings (SaveSetting remote): Low-FX, camera shake, music and SFX persist.
--   * Spectator cheers (Config.Cheers): eliminated or waiting players spend coins on a
--     firework over a survivor, a speed berry or a bandage.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PlayerDataService = require(script.Parent.PlayerDataService)
local RoleService = require(script.Parent.RoleService)

local Attributes = Config.Attributes
local MA = Config.Mastery
local D = Config.Daily
local CH = Config.Cheers

local ProgressionService = {}

local popup = Remotes.get("Popup")
local GOLD = Color3.fromRGB(255, 210, 60)
local lastCheer: { [Player]: number } = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

---------------------------------------------------------------------------
-- mastery titles

local function tierOf(track: any, value: number): number
	local tier = 0
	for i, need in track.Tiers do
		if value >= need then
			tier = i
		end
	end
	return tier
end

local function titleName(track: any, tier: number): string
	return track.Name .. " " .. MA.Numerals[tier]
end

-- Best title: the highest tier reached, ties broken by track order.
local function bestTitle(profile: any): (string, Color3?)
	local bestTier, bestTrack = 0, nil
	for _, track in MA.Tracks do
		local tier = tierOf(track, profile.Mastery[track.Stat] or 0)
		if tier > bestTier then
			bestTier, bestTrack = tier, track
		end
	end
	if not bestTrack then
		return "", nil
	end
	return titleName(bestTrack, bestTier), bestTrack.Color
end

local function tagCharacter(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("TitleTag")
	if old then
		old:Destroy()
	end
	local title = player:GetAttribute(Attributes.Title)
	if typeof(title) ~= "string" or title == "" then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "TitleTag"
	gui.Size = UDim2.fromOffset(200, 26)
	gui.StudsOffset = Vector3.new(0, 3.1, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
	label.TextScaled = true
	label.Text = "⭐ " .. title
	local color = player:GetAttribute(Attributes.TitleColor)
	label.TextColor3 = if typeof(color) == "Color3" then color else GOLD
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = head
end

local function publishTitle(player: Player, profile: any)
	local title, color = bestTitle(profile)
	if player:GetAttribute(Attributes.Title) ~= title then
		player:SetAttribute(Attributes.Title, title)
		player:SetAttribute(Attributes.TitleColor, color)
		tagCharacter(player)
	end
end

-- Count progress on a mastery stat; announces any title tier crossed.
function ProgressionService.AddMastery(player: Player, stat: string, amount: number)
	local profile = PlayerDataService.Get(player) :: any
	if not profile or amount <= 0 then
		return
	end
	local before = profile.Mastery[stat] or 0
	local after = before + amount
	profile.Mastery[stat] = after
	for _, track in MA.Tracks do
		if track.Stat == stat then
			local t0, t1 = tierOf(track, before), tierOf(track, after)
			if t1 > t0 then
				popup:FireClient(player, "🏅 TITLE UNLOCKED: " .. string.upper(titleName(track, t1)), track.Color)
			end
		end
	end
	publishTitle(player, profile)
end

-- Every track with the player's tier and progress (for the Titles list).
function ProgressionService.Titles(player: Player): { { Name: string, Tier: number, Max: number, Value: number, Next: number? } }
	local profile = PlayerDataService.Get(player) :: any
	local list = {}
	if not profile then
		return list
	end
	for _, track in MA.Tracks do
		local value = profile.Mastery[track.Stat] or 0
		local tier = tierOf(track, value)
		table.insert(list, { Name = track.Name, Tier = tier, Max = #track.Tiers, Value = value, Next = track.Tiers[tier + 1] })
	end
	return list
end

---------------------------------------------------------------------------
-- daily streak + first win

local function refreshStreak(player: Player, profile: any)
	local day = today()
	if profile.LoginDay ~= day then
		profile.LoginStreak = if profile.LoginDay == day - 1 then profile.LoginStreak + 1 else 1
		profile.LoginDay = day
	end
	player:SetAttribute(Attributes.LoginStreak, profile.LoginStreak)
	player:SetAttribute(Attributes.StreakReady, profile.StreakClaimedDay ~= day)
end

-- The first `kind` ("Survive" | "GodWin") today returns true once.
function ProgressionService.FirstWin(player: Player, kind: string): boolean
	local profile = PlayerDataService.Get(player) :: any
	if not profile then
		return false
	end
	local field = if kind == "GodWin" then "FirstGodWinDay" else "FirstSurviveDay"
	local day = today()
	if profile[field] == day then
		return false
	end
	profile[field] = day
	return true
end

local function claimStreak(player: Player)
	local profile = PlayerDataService.Get(player) :: any
	if not profile then
		return
	end
	refreshStreak(player, profile)
	local day = today()
	if profile.StreakClaimedDay == day then
		popup:FireClient(player, "Come back tomorrow for the next chest!", Color3.fromRGB(200, 205, 220))
		return
	end
	profile.StreakClaimedDay = day
	local index = (math.max(1, profile.LoginStreak) - 1) % #D.Rewards + 1
	local reward = D.Rewards[index]
	PlayerDataService.AddCoins(player, reward.Coins)
	local text = string.format("🎁 DAY %d CHEST: +%d COINS", index, reward.Coins)
	if reward.Spins then
		PlayerDataService.AddSpins(player, reward.Spins)
		text ..= string.format(" + %d FREE SPIN", reward.Spins)
	end
	if reward.GoldenTrail then
		profile.GoldenTrail = true
		text ..= " + GOLDEN TRAIL!"
	end
	PlayerDataService.Publish(player)
	player:SetAttribute(Attributes.StreakReady, false)
	popup:FireClient(player, text, GOLD)
end

-- The streak chest in the Sky Lodge: a gold chest with a prompt and a day counter.
local function buildChest()
	local origin = Config.World.LobbyOrigin + D.ChestOffset
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local lodge = workspace:FindFirstChild("SkyLodge")
	params.FilterDescendantsInstances = if lodge then { lodge } else {}
	local hit = workspace:Raycast(origin + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), params)
	local floorY = if hit then hit.Position.Y else origin.Y
	local model = Instance.new("Model")
	model.Name = "StreakChest"
	local function part(name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = CFrame.new(origin.X, floorY, origin.Z) * CFrame.new(offset)
		p.Color = color
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local base = part("Chest", Vector3.new(5, 3, 3.4), Vector3.new(0, 1.5, 0), Color3.fromRGB(150, 90, 45), Enum.Material.WoodPlanks)
	part("Lid", Vector3.new(5.2, 1.4, 3.6), Vector3.new(0, 3.7, 0), Color3.fromRGB(170, 105, 55), Enum.Material.WoodPlanks)
	part("Band", Vector3.new(5.3, 4.6, 0.6), Vector3.new(0, 2.3, 0), Color3.fromRGB(255, 200, 60), Enum.Material.Metal)
	part("Lock", Vector3.new(1, 1.2, 0.5), Vector3.new(0, 3, -1.9), Color3.fromRGB(255, 220, 90), Enum.Material.Metal)
	model.PrimaryPart = base
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = "Daily Streak Chest"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = base
	prompt.Triggered:Connect(claimStreak)
	local gui = Instance.new("BillboardGui")
	gui.Name = "StreakLabel"
	gui.Size = UDim2.fromOffset(220, 40)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.MaxDistance = 70
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
	label.TextScaled = true
	label.TextColor3 = GOLD
	label.Text = "🎁 DAILY STREAK"
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = base
	model.Parent = lodge or workspace
end

---------------------------------------------------------------------------
-- spectator cheers / aid

local function onCheer(player: Player, kind: any, targetId: any)
	if typeof(kind) ~= "string" or typeof(targetId) ~= "number" then
		return
	end
	local def = (CH :: any)[kind]
	if typeof(def) ~= "table" or not def.Cost then
		return
	end
	if ReplicatedStorage:GetAttribute(Attributes.RoundPhase) ~= "Active" then
		return
	end
	-- only players who are out of the round can cheer
	if RoleService.IsAliveSurvivor(player) or RoleService.GetGod() == player then
		return
	end
	local target = Players:GetPlayerByUserId(targetId)
	if not target or target == player or not RoleService.IsAliveSurvivor(target) then
		return
	end
	local now = os.clock()
	if (lastCheer[player] or 0) + CH.Cooldown > now then
		return
	end
	if not PlayerDataService.SpendCoins(player, def.Cost) then
		popup:FireClient(player, "Not enough coins", Color3.fromRGB(255, 110, 100))
		return
	end
	lastCheer[player] = now
	local character = target.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (hrp and humanoid) then
		return
	end
	Remotes.get("ClientEffect"):FireAllClients("Cheer", kind, hrp.Position)
	if kind == "Berry" then
		target:SetAttribute(Attributes.SpeedUntil, workspace:GetServerTimeNow() + def.Seconds)
		humanoid.WalkSpeed = def.Speed
		task.delay(def.Seconds, function()
			if humanoid.Parent and humanoid.WalkSpeed == def.Speed then
				humanoid.WalkSpeed = Config.Player.WalkSpeed
			end
		end)
	elseif kind == "Bandage" then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + def.Heal)
	end
	Remotes.get("Feed"):FireAllClients(string.format("%s %s sent %s a %s!", def.Icon, player.DisplayName, target.DisplayName, def.Name), Color3.fromRGB(255, 170, 220))
	popup:FireClient(target, string.format("%s %s FROM %s", def.Icon, string.upper(def.Name), string.upper(player.DisplayName)), Color3.fromRGB(255, 170, 220))
end

---------------------------------------------------------------------------

local SETTINGS = { LowFx = "boolean", Shake = "number", Music = "boolean", Sfx = "boolean" }

function ProgressionService.Init()
	PlayerDataService.ProfileLoaded:Connect(function(player: Player)
		local profile = PlayerDataService.Get(player) :: any
		if not profile then
			return
		end
		refreshStreak(player, profile)
		publishTitle(player, profile)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 5)
			tagCharacter(player)
		end)
		if player.Character then
			tagCharacter(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastCheer[player] = nil
	end)
	Remotes.get("ClaimStreak").OnServerEvent:Connect(claimStreak)
	Remotes.get("Cheer").OnServerEvent:Connect(onCheer)
	Remotes.get("SaveSetting").OnServerEvent:Connect(function(player, key, value)
		local kind = if typeof(key) == "string" then SETTINGS[key] else nil
		local profile = PlayerDataService.Get(player) :: any
		if not kind or typeof(value) ~= kind or not profile then
			return
		end
		if kind == "number" then
			value = math.clamp(value, 0, 1)
		end
		profile["Set_" .. key] = value
		player:SetAttribute(Attributes.SettingPrefix .. key, value)
	end)
	task.defer(function()
		-- the lodge is built by LobbyService.Init; wait for it before placing the chest
		workspace:WaitForChild("SkyLodge", 15)
		buildChest()
	end)
end

return ProgressionService
