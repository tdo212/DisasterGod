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
	"CommunityController", -- lodge community reward + the one-time favourite prompt
	"EmoteController", -- after SurvivorController (attaches to its DASH button)
	"SaveController",
	"PolishController", -- after HUD / Spectate (intro camera, danger edges, lodge Arena Cam)
	"LodgeController", -- idle animation of the lodge showcase (displays, flicker, auras)
	"RoleRevealController", -- round-start GOD vs SURVIVORS card
	"KillConfirmController", -- the God's hitmarker + sound on a kill
	"DailyRewardController", -- the once-a-day login reward window in the lodge
	"TutorialController", -- last: points at buttons the other controllers built
}

for _, name in order do
	local controller = require(Controllers:WaitForChild(name) :: ModuleScript)
	controller.Start()
end
