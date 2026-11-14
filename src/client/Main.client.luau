--!strict
-- Client bootstrap: start every controller.

local StarterGui = game:GetService("StarterGui")

local Controllers = script.Parent:WaitForChild("Controllers")

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local order = {
	"AudioController",
	"EffectsController",
	"DebrisController",
	"MapFxController",
	"StealthController",
	"FeedController",
	"VoteController",
	"FeelController",
	"CosmeticController",
	"SettingsController",
	"HUDController",
	"SurvivorController",
	"GodController",
	"SpectateController",
	"SpinController",
	"QuestController",
	"MenuController",
	"EmoteController", -- after SurvivorController (attaches to its DASH button)
	"SaveController",
	"PolishController", -- after HUD / Spectate (intro camera, danger edges, cheers, lodge Arena Cam)
}

for _, name in order do
	local controller = require(Controllers:WaitForChild(name) :: ModuleScript)
	controller.Start()
end
