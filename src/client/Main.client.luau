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
	"StealthController",
	"HUDController",
	"SurvivorController",
	"GodController",
	"SpectateController",
	"SpinController",
	"QuestController",
	"MenuController",
}

for _, name in order do
	local controller = require(Controllers:WaitForChild(name) :: ModuleScript)
	controller.Start()
end
