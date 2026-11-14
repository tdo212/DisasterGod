--!strict
-- LeaderboardService: lobby leaderboards built from the workspace template model
-- (Config.Leaderboards.Template, RenanMSV's "TimePlayedLeaderboard").
--   * The template itself keeps its own script and stays the Time Played board.
--   * Each entry in Config.Leaderboards.Boards gets a clone of the template with that
--     script removed; this service fills it from an OrderedDataStore (live servers) or
--     from the players in the server (Studio).
--   * The Hall of Legends podium in the lodge shows the all-time top three of
--     Config.Leaderboards.Hall.Stat as full avatar statues (a clone of the live character
--     when that player is in the server). Empty places are filled with the best players
--     in the server so the podium is never bare.
--   * Every board's first-place pedestal holds a clone of the Config.Leaderboards.Dancer
--     model instead of the template's avatar rig (the template's own rig is kept hidden,
--     because its script keeps rebuilding it).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PlayerDataService = require(script.Parent.PlayerDataService)

local L = Config.Leaderboards
local ROWS = 10
local STORE_PREFIX = "DisasterGodBoard_v1_"
-- instances the template's own script adds or needs; clones must not carry them
local TEMPLATE_ONLY = { "TimePlayedClass", "TimePlayedLeaderboardBE-SR", "ThumbnailCamera" }
local TEMPLATE_TAG = "TopTimePlayedLeaderboard_Board_Tag"
local TEMPLATE_MAIN_ATTRIBUTE = "TopTimePlayedLeaderboard_IsMainBoard"
local TEST_THUMBNAIL = "rbxassetid://1146888101"
local STATUE_SETTLE = 0.5 -- seconds for accessory welds to seat before freezing a statue

type Row = { UserId: number, Value: number }
type Board = { Model: Model, Stat: string, Unit: string, Store: OrderedDataStore?, Rig: any }
type HallSlot = { Spot: CFrame, Label: TextLabel, UserId: number?, Statue: Model? }

local LeaderboardService = {}

local boards: { Board } = {}
local written: { [Player]: { [string]: number } } = {}
local nameCache: { [number]: string } = {}
local thumbCache: { [number]: string } = {}
local hallSlots: { HallSlot } = {}
local hallFolder: Folder? = nil
local hallStore: OrderedDataStore? = nil

local function formatNumber(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if formatted:sub(1, 1) == "," then formatted:sub(2) else formatted
end

-- Stand the model on `slot` (a ground point whose LookVector is the way the board faces).
local function place(model: Model, slot: CFrame)
	local pivot = model:GetPivot()
	local cf, size = model:GetBoundingBox()
	local center = pivot:PointToObjectSpace(cf.Position)
	local bottom = center.Y - size.Y / 2
	model:PivotTo(slot * CFrame.new(-center.X, -bottom, -center.Z))
end

local function nameOf(userId: number): string
	if userId <= 0 then
		return "Studio Test Profile"
	end
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.Name
		return player.Name
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok then
		nameCache[userId] = name
		return name
	end
	return "Unknown"
end

local function thumbOf(userId: number): string
	if userId <= 0 then
		return TEST_THUMBNAIL
	end
	local cached = thumbCache[userId]
	if cached then
		return cached
	end
	local ok, image = pcall(function()
		return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if ok then
		thumbCache[userId] = image
		return image
	end
	return TEST_THUMBNAIL
end

local function fetch(stat: string, store: OrderedDataStore?): { Row }
	local rows: { Row } = {}
	if store then
		local ok, err = pcall(function()
			local page = store:GetSortedAsync(false, ROWS):GetCurrentPage()
			for _, entry in page do
				local userId = tonumber(entry.key)
				if userId and typeof(entry.value) == "number" then
					table.insert(rows, { UserId = userId, Value = entry.value })
				end
			end
		end)
		if not ok then
			warn("[Leaderboard] fetch failed for", stat, err)
		end
		return rows
	end
	for _, player in Players:GetPlayers() do
		local profile = PlayerDataService.Get(player)
		local value = profile and (profile :: any)[stat]
		if typeof(value) == "number" and value > 0 then
			table.insert(rows, { UserId = player.UserId, Value = value })
		end
	end
	table.sort(rows, function(a, b)
		return a.Value > b.Value
	end)
	while #rows > ROWS do
		table.remove(rows)
	end
	return rows
end

local function render(board: Board, rows: { Row })
	local scoreBlock = (board.Model :: any).ScoreBlock
	local gui = scoreBlock.Leaderboard
	local empty = #rows == 0
	gui.Enabled = not empty
	scoreBlock.NoDataFound.Enabled = empty
	scoreBlock.NoDataFound.Warning.Visible = empty
	scoreBlock.NoAPIServices.Warning.Visible = false
	scoreBlock.WaitingSync.Warning.Visible = false
	for i = 1, ROWS do
		local row = rows[i]
		local name, score, photo = gui.Names["Name" .. i], gui.Score["Score" .. i], gui.Photos["Photo" .. i]
		name.Visible = row ~= nil
		score.Visible = row ~= nil
		photo.Visible = row ~= nil
		if row then
			name.Text = nameOf(row.UserId)
			score.Text = string.format("%s %s", formatNumber(row.Value), board.Unit)
			photo.Image = thumbOf(row.UserId)
		end
	end
	-- mirror onto the back face, like the template does
	local old = scoreBlock:FindFirstChild("_backside")
	if old then
		old:Destroy()
	end
	local back = gui:Clone()
	back.Name = "_backside"
	back.Face = Enum.NormalId.Back
	back.Parent = scoreBlock
end

local function refresh(board: Board)
	local ok, err = pcall(function()
		render(board, fetch(board.Stat, board.Store))
	end)
	if not ok then
		warn("[Leaderboard] render failed for", board.Stat, err)
	end
end

local function setTimer(board: Board, seconds: number)
	local timer = (board.Model :: any).UpdateBoardTimer.Timer:FindFirstChildOfClass("TextLabel")
	if timer then
		timer.Text = string.format("Updating the board in %d seconds", seconds)
	end
end

local function titlePlate(clone: Model, title: string)
	local text3d = clone:FindFirstChild("ThreeDTextObject")
	local box = text3d and text3d:FindFirstChild("ThreeDTextBoundingBox") :: BasePart?
	if not (text3d and box) then
		return
	end
	local plate = Instance.new("Part")
	plate.Name = "Title"
	plate.Anchored = true
	plate.CanCollide = false
	plate.Size = Vector3.new(box.Size.X + 1, box.Size.Y + 0.9, box.Size.Z)
	plate.CFrame = box.CFrame
	plate.Color = Color3.fromRGB(27, 42, 53)
	plate.Material = Enum.Material.SmoothPlastic
	plate.Parent = clone
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Parent = plate
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = title
		label.Parent = gui
	end
	text3d:Destroy()
end

local function openStore(stat: string): OrderedDataStore?
	if not PlayerDataService.UsesDataStores() then
		return nil
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(STORE_PREFIX .. stat)
	end)
	return if ok then result else nil
end

local function makeClone(template: Model, def: { Stat: string, Title: string, Unit: string }): Board
	local clone = template:Clone()
	clone.Name = def.Stat .. "Leaderboard"
	for _, name in TEMPLATE_ONLY do
		local child = clone:FindFirstChild(name)
		if child then
			child:Destroy()
		end
	end
	clone:RemoveTag(TEMPLATE_TAG)
	clone:SetAttribute(TEMPLATE_MAIN_ATTRIBUTE, nil)
	titlePlate(clone, def.Title)
	clone.Parent = template.Parent

	local store = openStore(def.Stat)
	-- the dancer replaces the template's first-place avatar rig; keep only the pedestal
	local avatar = clone:FindFirstChild("First Place Avatar")
	if avatar then
		for _, child in avatar:GetChildren() do
			if child.Name ~= "Pedestal" then
				child:Destroy()
			end
		end
	end
	return { Model = clone, Stat = def.Stat, Unit = def.Unit, Store = store, Rig = nil }
end

---------------------------------------------------------------------------
-- dancers on the first-place pedestals

local dancerSource: Model? = nil

local function hidePart(d: Instance)
	if d:IsA("BasePart") then
		d.Transparency = 1
		d.CanCollide = false
		d.CanQuery = false
	elseif d:IsA("Decal") then
		d.Transparency = 1
	elseif d:IsA("BillboardGui") then
		d.Enabled = false
	end
end

-- The template's own script rebuilds its "Rig" whenever first place changes: keep it invisible.
local function hideTemplateRig(avatar: Instance)
	local function hide(rig: Instance)
		if rig.Name ~= "Rig" then
			return
		end
		for _, d in rig:GetDescendants() do
			hidePart(d)
		end
		rig.DescendantAdded:Connect(hidePart)
	end
	for _, child in avatar:GetChildren() do
		hide(child)
	end
	avatar.ChildAdded:Connect(hide)
end

local function standDancer(board: Model)
	local source = dancerSource
	if not source then
		return
	end
	local pivot = board:GetPivot()
	local look = pivot.LookVector
	local avatar = board:FindFirstChild("First Place Avatar")
	local pedestal = avatar and avatar:FindFirstChild("Pedestal")
	local spot: Vector3
	if pedestal and pedestal:IsA("Model") then
		local cf, size = pedestal:GetBoundingBox()
		spot = Vector3.new(cf.X, cf.Y + size.Y / 2, cf.Z)
	elseif pedestal and pedestal:IsA("BasePart") then
		spot = pedestal.Position + Vector3.new(0, pedestal.Size.Y / 2, 0)
	else
		spot = (pivot * CFrame.new(L.DancerFallbackOffset)).Position
	end
	if avatar then
		hideTemplateRig(avatar)
	end
	-- the template's spotlight (Brightness 10) blew the dancer out to white
	for _, d in board:GetDescendants() do
		if d:IsA("SpotLight") then
			d.Brightness = L.DancerLight
		end
	end
	local dancer = source:Clone()
	dancer.Name = "Dancer"
	local root = dancer:FindFirstChild("HumanoidRootPart") :: BasePart?
	for _, d in dancer:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d == root
			d.CanCollide = false
			d.CanTouch = false
		end
	end
	local humanoid = dancer:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	place(dancer, CFrame.lookAt(spot, spot + Vector3.new(look.X, 0, look.Z)))
	dancer.Parent = board
end

local function findDancerSource()
	local found = workspace:FindFirstChild(L.Dancer) or ServerStorage:FindFirstChild(L.Dancer)
	if found and found:IsA("Model") then
		-- out of the arena: it is only a source for the clones
		found.Parent = ServerStorage
		dancerSource = found
	else
		warn("[Leaderboard] dancer model '" .. L.Dancer .. "' not found; boards keep empty pedestals")
	end
end

-- Avatar statue for the Hall of Legends (anchored, non-colliding, no scripts), standing
-- on `spot`. Only the root is anchored at first so welds can seat the accessories, then
-- the whole rig is frozen.
local function buildStatue(userId: number, spot: CFrame, name: string, parent: Instance): Model?
	local ok, model = pcall(function()
		-- a player in this server: clone their actual character (exact look, no web call)
		local live = Players:GetPlayerByUserId(userId)
		local character = live and live.Character
		if character and character:FindFirstChildOfClass("Humanoid") then
			character.Archivable = true
			local copy = character:Clone()
			if copy then
				for _, d in copy:GetDescendants() do
					if d:IsA("ForceField") or d:IsA("BillboardGui") or d:IsA("Highlight") then
						d:Destroy()
					end
				end
				return copy
			end
		end
		if userId > 0 then
			return Players:CreateHumanoidModelFromUserId(userId)
		end
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[Leaderboard] hall statue failed for", userId, model)
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d == root
			d.CanCollide = false
			d.CanTouch = false
		elseif d:IsA("BaseScript") then
			d:Destroy()
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	local lift = if humanoid and root then humanoid.HipHeight + root.Size.Y / 2 else 3
	model.Name = name
	model:PivotTo(spot * CFrame.new(0, lift, 0))
	model.Parent = parent
	task.wait(STATUE_SETTLE)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	return model
end

local function hallLabel(parent: BasePart, offset: Vector3): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "LegendLabel"
	gui.Size = UDim2.new(7.5, 0, 2.2, 0) -- narrower than the 9-stud tier spacing
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = 150
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.RichText = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label
	return label
end

local function updateHall(rows: { Row })
	local folder = hallFolder
	if not folder then
		return
	end
	for rank, slot in hallSlots do
		local row = rows[rank]
		if not row then
			if slot.Statue then
				slot.Statue:Destroy()
				slot.Statue = nil
			end
			slot.UserId = nil
			slot.Label.Text = string.format("#%d\n<font color=\"#C8C8D2\">Your name here?</font>", rank)
			continue
		end
		slot.Label.Text = string.format("#%d %s\n<font color=\"#FFD23C\">%s %s</font>", rank, nameOf(row.UserId), formatNumber(row.Value), L.Hall.Unit)
		if slot.UserId ~= row.UserId or not slot.Statue then
			slot.UserId = row.UserId
			local statue = buildStatue(row.UserId, slot.Spot, "Legend" .. rank, folder)
			if slot.UserId ~= row.UserId then
				-- a newer refresh claimed this spot while the avatar loaded
				if statue then
					statue:Destroy()
				end
				continue
			end
			if slot.Statue then
				slot.Statue:Destroy()
			end
			slot.Statue = statue
		end
	end
end

-- All-time rows, then the best players in the server for any empty places (even at 0),
-- so the podium always shows someone.
local function hallRows(): { Row }
	local rows = fetch(L.Hall.Stat, hallStore)
	local taken: { [number]: boolean } = {}
	for _, row in rows do
		taken[row.UserId] = true
	end
	local extra: { Row } = {}
	for _, player in Players:GetPlayers() do
		local profile = PlayerDataService.Get(player)
		if profile and not taken[player.UserId] then
			local value = (profile :: any)[L.Hall.Stat]
			table.insert(extra, { UserId = player.UserId, Value = if typeof(value) == "number" then value else 0 })
		end
	end
	table.sort(extra, function(a, b)
		return a.Value > b.Value
	end)
	for _, row in extra do
		if #rows >= #hallSlots then
			break
		end
		table.insert(rows, row)
	end
	return rows
end

local hallBusy = false
local hallPending = false
local function refreshHall()
	if hallBusy then
		hallPending = true
		return
	end
	hallBusy = true
	repeat
		hallPending = false
		local ok, err = pcall(function()
			updateHall(hallRows())
		end)
		if not ok then
			warn("[Leaderboard] hall update failed", err)
		end
	until not hallPending
	hallBusy = false
end

-- Hall of Legends: `spots` are the podium tier tops (rank 1..3) facing into the hall.
function LeaderboardService.SetupHall(spots: { CFrame }, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Legends"
	folder.Parent = parent
	hallFolder = folder
	hallStore = openStore(L.Hall.Stat)
	for rank, spot in spots do
		local anchor = Instance.new("Part")
		anchor.Name = "LegendSpot" .. rank
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.CFrame = spot
		anchor.Parent = folder
		local label = hallLabel(anchor, Vector3.new(0, 7.6, 0))
		label.Text = string.format("#%d", rank)
		table.insert(hallSlots, { Spot = spot, Label = label })
	end
	-- refresh as soon as anyone's profile is ready, when they leave, and periodically
	PlayerDataService.ProfileLoaded:Connect(function()
		task.spawn(refreshHall)
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshHall)
	end)
	task.spawn(function()
		while true do
			refreshHall()
			task.wait(L.RefreshSeconds)
		end
	end)
end

-- Save one player's board stats (round end). Only values that changed are written.
function LeaderboardService.Record(player: Player)
	local profile = PlayerDataService.Get(player)
	if not profile then
		return
	end
	local cache = written[player]
	if not cache then
		cache = {}
		written[player] = cache
	end
	for _, board in boards do
		local store = board.Store
		local value = (profile :: any)[board.Stat]
		if store and typeof(value) == "number" and value > 0 and cache[board.Stat] ~= value then
			cache[board.Stat] = value
			task.spawn(pcall, function()
				store:SetAsync(tostring(player.UserId), math.floor(value))
			end)
		end
	end
end

function LeaderboardService.RecordAll(players: { Player })
	for _, player in players do
		if player.Parent then
			LeaderboardService.Record(player)
		end
	end
	task.spawn(refreshHall) -- a new record can change the podium right away
end

-- Stand the boards on the lobby slots. Slot 1 is the template (Time Played).
function LeaderboardService.Setup(slots: { CFrame })
	local template = workspace:FindFirstChild(L.Template)
	if not (template and template:IsA("Model")) then
		warn("[Leaderboard] workspace." .. L.Template .. " is missing; lobby leaderboards are disabled")
		return
	end
	-- clone before anything moves so every copy starts from the same layout
	for _, def in L.Boards do
		local ok, result = pcall(makeClone, template, def)
		if ok then
			table.insert(boards, result)
		else
			warn("[Leaderboard] could not build", def.Stat, result)
		end
	end
	if slots[1] then
		place(template, slots[1])
	end
	for i, board in boards do
		local slot = slots[i + 1]
		if slot then
			place(board.Model, slot)
		end
	end
	findDancerSource()
	standDancer(template)
	for _, board in boards do
		standDancer(board.Model)
	end

	Players.PlayerRemoving:Connect(function(player)
		written[player] = nil
	end)
	task.spawn(function()
		local remaining = 0
		while true do
			if remaining <= 0 then
				remaining = L.RefreshSeconds
				for _, board in boards do
					task.spawn(refresh, board)
				end
			end
			for _, board in boards do
				setTimer(board, remaining)
			end
			task.wait(1)
			remaining -= 1
		end
	end)
end

return LeaderboardService
