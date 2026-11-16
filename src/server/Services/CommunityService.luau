--!strict
-- CommunityService: the lodge's community reward and the one-time favourite prompt.
--   * Community: the board in the lodge opens Roblox's join prompt for the group that owns
--     the game (client). The client then asks for the reward; the server checks membership
--     itself (IsInGroupAsync) and pays once per player (Config.Community).
--   * Favourite: after a player's Nth round (N fixed per player in FavoriteAfterRounds),
--     a few seconds into the next lobby break, the client is told to show Roblox's favourite
--     prompt. Once ever, never rewarded.

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CM = Config.Community
local Attributes = Config.Attributes

local CommunityService = {}

local lastCheck: { [Player]: number } = {}

function CommunityService.GroupId(): number
	if CM.GroupId > 0 then
		return CM.GroupId
	end
	return if game.CreatorType == Enum.CreatorType.Group then game.CreatorId else 0
end

local function kitName(id: string): string
	for _, kit in Config.Kits do
		if kit.Id == id then
			return kit.Name
		end
	end
	return id
end

-- Fresh membership check (Player:IsInGroup caches for the whole session, so someone who
-- joins mid-session would still read false). Errors propagate to the caller's pcall.
local function isMember(player: Player, groupId: number): boolean
	local ok, result = pcall(function()
		return (player :: any):IsInGroupAsync(groupId)
	end)
	if ok and typeof(result) == "boolean" then
		return result
	end
	for _, group in GroupService:GetGroupsAsync(player.UserId) do
		if group.Id == groupId then
			return true
		end
	end
	return false
end

local function popup(player: Player, text: string, color: Color3)
	Remotes.get("Popup"):FireClient(player, text, color)
end

local function onClaim(player: Player)
	local profile = PlayerDataService.Get(player)
	local groupId = CommunityService.GroupId()
	if not profile or groupId <= 0 then
		return
	end
	if profile.CommunityClaimed then
		popup(player, "COMMUNITY REWARD ALREADY CLAIMED", Color3.fromRGB(200, 200, 210))
		return
	end
	local now = os.clock()
	if now - (lastCheck[player] or -math.huge) < CM.CheckCooldown then
		return
	end
	lastCheck[player] = now
	local ok, member = pcall(isMember, player, groupId)
	if not ok then
		popup(player, "COULDN'T CHECK RIGHT NOW · TRY AGAIN", Color3.fromRGB(255, 120, 120))
		return
	end
	if not member then
		popup(player, "JOIN THE COMMUNITY TO CLAIM", Color3.fromRGB(255, 210, 90))
		return
	end
	-- paid once: mark first, then grant
	profile.CommunityClaimed = true
	PlayerDataService.AddCoins(player, CM.Coins)
	local text: string
	if PlayerDataService.OwnsKit(player, CM.Kit) then
		PlayerDataService.AddCoins(player, CM.KitOwnedCoins)
		text = string.format("COMMUNITY REWARD: +%d COINS", CM.Coins + CM.KitOwnedCoins)
	else
		PlayerDataService.GrantKit(player, CM.Kit)
		text = string.format("COMMUNITY REWARD: +%d COINS & %s KIT!", CM.Coins, string.upper(kitName(CM.Kit)))
	end
	PlayerDataService.Publish(player)
	PlayerDataService.SaveNow(player)
	popup(player, text, Color3.fromRGB(120, 255, 160))
end

-- The round after which this player is asked to favourite (stable across sessions).
local function favoriteRound(player: Player): number
	local low, high = CM.FavoriteAfterRounds[1], CM.FavoriteAfterRounds[2]
	return low + player.UserId % (high - low + 1)
end

local function onIntermission()
	for _, player in Players:GetPlayers() do
		local profile = PlayerDataService.Get(player)
		if profile and not profile.FavoriteAsked and profile.RoundsPlayed >= favoriteRound(player) then
			profile.FavoriteAsked = true
			task.delay(CM.FavoriteDelay, function()
				if player.Parent then
					Remotes.get("CommunityPrompt"):FireClient(player, "Favorite")
				end
			end)
		end
	end
end

function CommunityService.Init()
	Remotes.get("CommunityClaim").OnServerEvent:Connect(onClaim)
	Players.PlayerRemoving:Connect(function(player)
		lastCheck[player] = nil
	end)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.RoundPhase):Connect(function()
		if ReplicatedStorage:GetAttribute(Attributes.RoundPhase) == "Intermission" then
			onIntermission()
		end
	end)
	ReplicatedStorage:SetAttribute(Attributes.CommunityGroupId, CommunityService.GroupId())
end

return CommunityService
