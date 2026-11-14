--!strict
-- Client side of the analytics funnels: reports UI-only steps (shop / wheel opened, item
-- previewed, Robux prompt shown, dash, first movement, tutorial steps) to the server's
-- AnalyticsService on the "Analytics" remote. One-shot events are sent once per session.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes") :: ModuleScript)

local Analytics = {}

local ONCE = { Moved = true, CardDismissed = true, Dash = true, HideoutEntered = true }
local sent: { [string]: boolean } = {}
local remote: RemoteEvent? = nil

function Analytics.track(event: string, detail: string?)
	if ONCE[event] then
		if sent[event] then
			return
		end
		sent[event] = true
	end
	if not remote then
		remote = Remotes.get("Analytics")
	end
	(remote :: RemoteEvent):FireServer(event, detail)
end

-- First real movement counts as onboarding step 2 (alongside dismissing the role card).
function Analytics.watchMovement()
	local player = Players.LocalPlayer
	local function hook(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if not humanoid or sent.Moved then
			return
		end
		local conn: RBXScriptConnection
		conn = humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
			if humanoid.MoveDirection.Magnitude > 0.1 then
				conn:Disconnect()
				Analytics.track("Moved")
			end
		end)
	end
	if player.Character then
		task.spawn(hook, player.Character)
	end
	player.CharacterAdded:Connect(hook)
end

return Analytics
