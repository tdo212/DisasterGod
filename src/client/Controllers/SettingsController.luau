--!strict
-- SettingsController: the quick-settings window (gear tile in the menu). Low-FX mode
-- (no client rubble or weather, for older phones), camera shake strength, and separate
-- music / sound-effect toggles. Values are saved on the profile (SaveSetting remote) and
-- published back as Set_* player attributes, which the other controllers read.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local UI = script.Parent.Parent:WaitForChild("UI")
local Components = require(UI:WaitForChild("Components") :: ModuleScript)
local Theme = require(UI:WaitForChild("Theme") :: ModuleScript)

local Attributes = Config.Attributes
local C = Theme.Colors
local player = Players.LocalPlayer

local SettingsController = {}

local window: Components.WindowHandle
local sfxGroup: SoundGroup
local refreshers: { () -> () } = {}

-- Current value of a setting (defaults until the profile loads).
function SettingsController.Get(key: string): any
	local value = player:GetAttribute(Attributes.SettingPrefix .. key)
	if value == nil then
		return if key == "Shake" then 1 elseif key == "LowFx" then false else true
	end
	return value
end

local function save(key: string, value: any)
	player:SetAttribute(Attributes.SettingPrefix .. key, value) -- instant locally
	Remotes.get("SaveSetting"):FireServer(key, value)
end

-- Music lives in AudioController's "Music" group; everything else goes through "Sfx".
local function applyAudio()
	local music = SoundService:FindFirstChild("Music")
	if music and music:IsA("SoundGroup") then
		music.Volume = if SettingsController.Get("Music") then Config.Audio.Volume.Music else 0
	end
	local on = SettingsController.Get("Sfx") == true
	sfxGroup.Volume = if on then 1 else 0
	for _, name in { "UiSounds", "Ambience", "AmbienceLayer" } do
		local g = SoundService:FindFirstChild(name)
		if g and g:IsA("SoundGroup") then
			if g:GetAttribute("BaseVolume") == nil then
				g:SetAttribute("BaseVolume", g.Volume)
			end
			g.Volume = if on then g:GetAttribute("BaseVolume") :: number else 0
		end
	end
end

local function toggleRow(parent: Instance, order: number, title: string, hint: string, key: string)
	local row = Components.panel({ Name = key, Size = UDim2.new(1, 0, 0, 62), Color = C.WindowLight, Transparency = 0.15, Parent = parent })
	row.LayoutOrder = order
	Components.label({ Name = "Title", Text = title, TextSize = 20, Size = UDim2.new(1, -150, 0, 26), Position = UDim2.fromOffset(12, 6), XAlign = Enum.TextXAlignment.Left, Parent = row })
	Components.label({ Name = "Hint", Text = hint, TextSize = 13, Color = C.TextDim, Size = UDim2.new(1, -150, 0, 18), Position = UDim2.fromOffset(12, 34), XAlign = Enum.TextXAlignment.Left, StrokeThickness = 1, Parent = row })
	local button = Components.button({ Name = "Toggle", Text = "", TextSize = 18, Size = UDim2.fromOffset(110, 40), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Parent = row })
	local function refresh()
		local on = SettingsController.Get(key) == true
		Components.setText(button, if on then "ON" else "OFF")
		Components.setColors(button, if on then C.GreenLight else C.GreyLight, if on then C.Green else C.Grey, true)
	end
	button.Activated:Connect(function()
		save(key, not (SettingsController.Get(key) == true))
		refresh()
		applyAudio()
	end)
	table.insert(refreshers, refresh)
	refresh()
end

local SHAKE_STEPS = { 0, 0.5, 1 }
local SHAKE_NAMES = { [0] = "OFF", [0.5] = "LOW", [1] = "FULL" }

local function shakeRow(parent: Instance, order: number)
	local row = Components.panel({ Name = "Shake", Size = UDim2.new(1, 0, 0, 62), Color = C.WindowLight, Transparency = 0.15, Parent = parent })
	row.LayoutOrder = order
	Components.label({ Name = "Title", Text = "Camera shake", TextSize = 20, Size = UDim2.new(1, -150, 0, 26), Position = UDim2.fromOffset(12, 6), XAlign = Enum.TextXAlignment.Left, Parent = row })
	Components.label({ Name = "Hint", Text = "How hard impacts shake your view", TextSize = 13, Color = C.TextDim, Size = UDim2.new(1, -150, 0, 18), Position = UDim2.fromOffset(12, 34), XAlign = Enum.TextXAlignment.Left, StrokeThickness = 1, Parent = row })
	local button = Components.button({ Name = "Cycle", Text = "", TextSize = 18, Size = UDim2.fromOffset(110, 40), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Color = C.Header, ColorLight = C.HeaderLight, Parent = row })
	local function refresh()
		local v = SettingsController.Get("Shake") :: number
		local name = "FULL"
		for step, label in SHAKE_NAMES do
			if math.abs(step - v) < 0.01 then
				name = label
			end
		end
		Components.setText(button, name)
	end
	button.Activated:Connect(function()
		local v = SettingsController.Get("Shake") :: number
		local index = 1
		for i, step in SHAKE_STEPS do
			if math.abs(step - v) < 0.01 then
				index = i
			end
		end
		save("Shake", SHAKE_STEPS[index % #SHAKE_STEPS + 1])
		refresh()
	end)
	table.insert(refreshers, refresh)
	refresh()
end

function SettingsController.Toggle()
	if window.IsOpen() then
		window.Close()
	else
		for _, refresh in refreshers do
			refresh()
		end
		window.Open()
	end
end

function SettingsController.Start()
	sfxGroup = Instance.new("SoundGroup")
	sfxGroup.Name = "Sfx"
	sfxGroup.Volume = 1
	sfxGroup.Parent = SoundService
	-- world / disaster sounds have no group: route them through Sfx so they can be muted
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("Sound") and d.SoundGroup == nil then
			d.SoundGroup = sfxGroup
		end
	end)

	local gui = Instance.new("ScreenGui")
	gui.Name = "SettingsHUD"
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	gui.Parent = player:WaitForChild("PlayerGui")
	local layer = Components.scaledRoot(gui)
	window = Components.window(layer, "Settings", UDim2.fromOffset(460, 400))
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = window.Content
	toggleRow(window.Content, 1, "Low-FX mode", "No rubble or weather particles (older phones)", "LowFx")
	shakeRow(window.Content, 2)
	toggleRow(window.Content, 3, "Music", "Lobby and round music", "Music")
	toggleRow(window.Content, 4, "Sound effects", "Disasters, UI and ambience", "Sfx")

	for _, key in { "Music", "Sfx" } do
		player:GetAttributeChangedSignal(Attributes.SettingPrefix .. key):Connect(applyAudio)
	end
	SoundService.ChildAdded:Connect(function()
		task.defer(applyAudio)
	end)
	task.defer(applyAudio)
end

return SettingsController
