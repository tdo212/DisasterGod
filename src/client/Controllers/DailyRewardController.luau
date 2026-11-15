--!strict
-- DailyRewardController: the Daily Reward window, once a day on arrival in the Sky Lodge.
-- Seven day tiles (Config.Daily.Rewards): today's glows gold with CLAIM, tomorrow's is
-- highlighted with "COME BACK TOMORROW" so there is a reason to return. Claiming fires the
-- same ClaimStreak remote as the lodge chest (ProgressionService), so either works. It only
-- opens in the lodge, never mid-round or over the first-round cinematic, and waits for the
-- HUD banners to clear.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local UI = script.Parent.Parent:WaitForChild("UI")
local Components = require(UI:WaitForChild("Components") :: ModuleScript)
local Theme = require(UI:WaitForChild("Theme") :: ModuleScript)

local Attributes = Config.Attributes
local D = Config.Daily
local C = Theme.Colors
local player = Players.LocalPlayer

local DailyRewardController = {}

local started = false
local window: any = nil
local shownToday = false

local function rewardText(r: any): (string, string)
	if r.SolarFlare then
		return "🔥", "Solar Flare\ndash trail"
	elseif r.Cosmetic then
		return "☀️", "Sunforged\nGod skin"
	end
	local text = string.format("%d coins", r.Coins)
	if r.Spins and r.Spins > 0 then
		text ..= string.format("\n+%d spin%s", r.Spins, if r.Spins > 1 then "s" else "")
	end
	return if r.Spins and r.Spins > 0 then "🎡" else "💰", text
end

local function inLobby(): boolean
	local phase = ReplicatedStorage:GetAttribute(Attributes.RoundPhase)
	if phase ~= "Active" then
		return true
	end
	local role = player:GetAttribute(Attributes.Role)
	return not (role == "DisasterGod" or (role == "Survivor" and player:GetAttribute(Attributes.Alive) == true))
end

local function build(layer: Frame)
	window = Components.window(layer, "Daily Reward", UDim2.fromOffset(720, 330))
	local content = window.Content
	local streak = player:GetAttribute(Attributes.LoginStreak) :: number? or 1
	local today = (math.max(1, streak) - 1) % #D.Rewards + 1
	Components.label({ Name = "Streak", Text = string.format("🔥 %d-DAY STREAK · come back every day for bigger rewards", streak), TextSize = 20, Color = C.GoldLight, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 4), Parent = content })
	local row = Instance.new("Frame")
	row.Name = "Days"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -20, 0, 150)
	row.Position = UDim2.fromOffset(10, 40)
	row.Parent = content
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = row
	for i, r in D.Rewards do
		local isToday = i == today
		local isNext = i == today % #D.Rewards + 1
		local tile = Components.panel({
			Name = "Day" .. i,
			Size = UDim2.fromOffset(88, if isToday then 146 else 132),
			Color = if isToday then Color3.fromRGB(120, 90, 20) elseif isNext then Color3.fromRGB(40, 70, 120) elseif i < today then Color3.fromRGB(40, 60, 40) else C.WindowLight,
			Transparency = 0.05,
			Parent = row,
		})
		tile.LayoutOrder = i
		local icon, text = rewardText(r)
		Components.label({ Name = "Day", Text = "DAY " .. i, TextSize = 16, Color = if isToday then C.GoldLight else C.Text, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 4), Parent = tile })
		Components.label({ Name = "Icon", Text = if i < today then "✅" else icon, TextSize = 32, StrokeThickness = 0, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 26), Parent = tile })
		local body = Components.label({ Name = "Reward", Text = text, TextSize = 13, Size = UDim2.new(1, -6, 0, 36), Position = UDim2.new(0.5, 0, 0, 70), AnchorPoint = Vector2.new(0.5, 0), Parent = tile })
		body.TextWrapped = true
		if isToday then
			Components.label({ Name = "Tag", Text = "TODAY", TextSize = 15, Color = C.GoldLight, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -24), Parent = tile })
			local pop = Instance.new("UIScale")
			pop.Parent = tile
			task.spawn(function()
				while tile.Parent do
					Components.tween(pop, Theme.Tweens.Fade, { Scale = 1.06 })
					task.wait(0.6)
					Components.tween(pop, Theme.Tweens.Fade, { Scale = 1 })
					task.wait(0.6)
				end
			end)
		elseif isNext then
			local tag = Components.label({ Name = "Tag", Text = "COME BACK\nTOMORROW", TextSize = 11, Color = C.HeaderLight, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 1, -28), Parent = tile })
			tag.TextWrapped = true
		end
	end
	Components.button({
		Name = "Claim",
		Text = "🎁 CLAIM",
		TextSize = 30,
		Size = UDim2.fromOffset(260, 62),
		Position = UDim2.new(0.5, 0, 1, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = content,
		OnClick = function()
			Remotes.get("ClaimStreak"):FireServer()
			window.Close()
		end,
	})
end

-- another window (the map vote, the shop, the round summary) is already up
local function otherWindowOpen(): boolean
	for _, sg in player:WaitForChild("PlayerGui"):GetChildren() do
		if sg:IsA("ScreenGui") and sg.Enabled and sg.Name ~= "DailyRewardHUD" then
			for _, d in sg:GetDescendants() do
				if d:IsA("GuiObject") and d.Visible and string.sub(d.Name, -6) == "Window" and d.AbsoluteSize.X > 4 then
					return true
				end
			end
		end
	end
	return false
end

local function tryShow(layer: Frame)
	if shownToday or player:GetAttribute(Attributes.StreakReady) ~= true then
		return
	end
	if not inLobby() or player:GetAttribute("Cinematic") == true or player:GetAttribute("RoleReveal") == true then
		return
	end
	if ReplicatedStorage:GetAttribute(Attributes.VoteOpen) == true or otherWindowOpen() then
		return
	end
	shownToday = true
	if window then
		window.Root:Destroy()
	end
	build(layer)
	window.Open()
end

function DailyRewardController.Start()
	if started then
		return
	end
	started = true
	local gui = Instance.new("ScreenGui")
	gui.Name = "DailyRewardHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	local layer = Components.scaledRoot(gui)
	-- a new day while still in the server: offer it again
	player:GetAttributeChangedSignal(Attributes.StreakReady):Connect(function()
		if player:GetAttribute(Attributes.StreakReady) ~= true then
			if window and window.IsOpen() then
				window.Close()
			end
		else
			shownToday = false
		end
	end)
	task.spawn(function()
		task.wait(4) -- let the lodge, the profile and the welcome banners settle first
		while true do
			tryShow(layer)
			task.wait(2)
		end
	end)
end

return DailyRewardController
