--!strict
-- FeelController: Nintendo-style game feel on the local player.
--   * Coyote time: a jump pressed just after walking off a ledge still jumps.
--   * Jump buffering: a jump pressed just before landing fires on touchdown.
--   * Landing thump: a hard landing dips the camera a little (weight).
--   * Mercy flicker: after a disaster hit the server gives a short invulnerability window;
--     the character blinks so you can read it (ClientEffect "Mercy").
--   * 3-2-1-GO!: a countdown into the moment disasters unlock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local UI = script.Parent.Parent:WaitForChild("UI")
local Components = require(UI:WaitForChild("Components") :: ModuleScript)
local Sound = require(UI:WaitForChild("Sound") :: ModuleScript)
local Theme = require(UI:WaitForChild("Theme") :: ModuleScript)
local EffectsController = require(script.Parent:WaitForChild("EffectsController") :: ModuleScript)

local FE = Config.Feel
local M = Config.Match
local Attributes = Config.Attributes
local C = Theme.Colors
local player = Players.LocalPlayer

local FeelController = {}

local lastGrounded = 0
local jumpedSinceGround = false
local bufferedAt = 0
local wasAirborne = false
local peakFall = 0
local countLabel: TextLabel
local countScale: UIScale
local lastCount = -1

local function humanoidOf(): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function canControl(humanoid: Humanoid): boolean
	return humanoid.Health > 0 and player:GetAttribute(Attributes.Ragdolled) ~= true and player:GetAttribute(Attributes.Role) ~= "DisasterGod"
end

local function onJumpRequest()
	local humanoid = humanoidOf()
	if not humanoid or not canControl(humanoid) then
		return
	end
	local now = os.clock()
	local airborne = humanoid.FloorMaterial == Enum.Material.Air
	if not airborne then
		return -- the default controls handle a grounded jump
	end
	if not jumpedSinceGround and now - lastGrounded <= FE.CoyoteTime then
		jumpedSinceGround = true
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	else
		bufferedAt = now
	end
end

local function step()
	local humanoid = humanoidOf()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (humanoid and root) then
		return
	end
	local now = os.clock()
	local airborne = humanoid.FloorMaterial == Enum.Material.Air
	if airborne then
		peakFall = math.max(peakFall, -root.AssemblyLinearVelocity.Y)
		wasAirborne = true
		return
	end
	lastGrounded = now
	if wasAirborne then
		wasAirborne = false
		jumpedSinceGround = false
		if peakFall >= FE.HardLandingSpeed then
			EffectsController.Shake(FE.LandingShake, 0.2)
		end
		peakFall = 0
		if bufferedAt > 0 and now - bufferedAt <= FE.JumpBuffer and canControl(humanoid) then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			jumpedSinceGround = true
		end
		bufferedAt = 0
	end
end

local function mercy(seconds: number)
	local character = player.Character
	if not character then
		return
	end
	task.spawn(function()
		local t = 0
		local on = false
		while t < seconds do
			on = not on
			for _, d in character:GetDescendants() do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = if on then 0.6 else 0
				end
			end
			task.wait(0.07)
			t += 0.07
		end
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 0
			end
		end
	end)
end

-- 3, 2, 1 during the end of Prep, then GO! when disasters unlock.
local function roleCardOpen(): boolean
	local playerGui = player:FindFirstChild("PlayerGui")
	local hud = playerGui and playerGui:FindFirstChild("HUD")
	return hud ~= nil and hud:FindFirstChild("RoleCard", true) ~= nil
end

local function pop(text: string, color: Color3)
	if roleCardOpen() then
		return -- a first-time tutorial card has the centre of the screen; the ticks still play
	end
	countLabel.Text = text
	countLabel.TextColor3 = color
	countLabel.Visible = true
	countScale.Scale = 1.8
	Components.tween(countScale, Theme.Tweens.Pop, { Scale = 1 })
end

local function countdownTick()
	local phase = ReplicatedStorage:GetAttribute(Attributes.RoundPhase)
	local sub = ReplicatedStorage:GetAttribute(Attributes.SubPhase)
	local t = ReplicatedStorage:GetAttribute(Attributes.TimeRemaining) :: number? or 0
	if phase ~= "Active" or sub ~= "Prep" then
		return
	end
	local untilCast = t - (M.RoundDuration - M.PrepDuration)
	if untilCast >= 1 and untilCast <= FE.Countdown and untilCast ~= lastCount then
		lastCount = untilCast
		pop(tostring(untilCast), C.GoldLight)
		Sound.play("Tick", 0.8)
	end
end

local function onSubPhase()
	local sub = ReplicatedStorage:GetAttribute(Attributes.SubPhase)
	if sub == "Escalation" and lastCount ~= 0 then
		lastCount = 0
		pop("GO!", C.GreenLight)
		Sound.play("Tock", 0.9)
		task.delay(0.9, function()
			if countLabel.Text == "GO!" then
				countLabel.Visible = false
			end
		end)
	elseif sub ~= "Prep" then
		countLabel.Visible = false
		if sub ~= "Escalation" then
			lastCount = -1
		end
	end
end

function FeelController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "FeelHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3
	gui.Parent = player:WaitForChild("PlayerGui")
	local layer = Components.scaledRoot(gui)
	countLabel = Components.label({
		Name = "Countdown",
		Text = "",
		TextSize = 96,
		Size = UDim2.fromOffset(300, 120),
		Position = UDim2.fromScale(0.5, 0.4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = layer,
	})
	countLabel.Visible = false
	countScale = Instance.new("UIScale")
	countScale.Parent = countLabel

	UserInputService.JumpRequest:Connect(onJumpRequest)
	RunService.Heartbeat:Connect(step)
	player.CharacterAdded:Connect(function()
		lastGrounded, bufferedAt, peakFall = 0, 0, 0
		wasAirborne, jumpedSinceGround = false, false
	end)
	Remotes.get("ClientEffect").OnClientEvent:Connect(function(kind: string, a: any)
		if kind == "Mercy" and typeof(a) == "number" then
			mercy(a)
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.TimeRemaining):Connect(countdownTick)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.SubPhase):Connect(onSubPhase)
end

return FeelController
