--!strict
-- RagdollService: lets a character flop under physics. Used for hard knockback (a short
-- stun) and for deaths (the body stays a ragdoll).
--   * Current avatars are driven by AnimationConstraints and already carry ball sockets:
--     disabling the constraints is enough.
--   * Older Motor6D rigs get ball sockets built for them the first time they ragdoll.
-- The owning client switches the Humanoid to the Physics state (see EffectsController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Attributes = Config.Attributes

local RagdollService = {}

-- Joints: Motor6D or AnimationConstraint (both have .Enabled). Sockets: ours, Motor6D rigs only.
type Rig = { Joints: { Instance }, Sockets: { BallSocketConstraint } }

local rigs: { [Model]: Rig } = {}
local tokens: { [Player]: number } = {}
local clientEffect = Remotes.get("ClientEffect")

local SOCKET_CONE = 50
local SOCKET_TWIST = 40

local function socketFor(motor: Motor6D): BallSocketConstraint
	local a0 = Instance.new("Attachment")
	a0.Name = "RagdollA0"
	a0.CFrame = motor.C0
	a0.Parent = motor.Part0
	local a1 = Instance.new("Attachment")
	a1.Name = "RagdollA1"
	a1.CFrame = motor.C1
	a1.Parent = motor.Part1
	local socket = Instance.new("BallSocketConstraint")
	socket.Name = "RagdollSocket"
	socket.Attachment0 = a0
	socket.Attachment1 = a1
	socket.LimitsEnabled = true
	socket.UpperAngle = SOCKET_CONE
	socket.TwistLimitsEnabled = true
	socket.TwistLowerAngle = -SOCKET_TWIST
	socket.TwistUpperAngle = SOCKET_TWIST
	socket.Enabled = false
	socket.Parent = motor.Part0
	return socket
end

local function build(character: Model): Rig
	local rig: Rig = { Joints = {}, Sockets = {} }
	for _, d in character:GetDescendants() do
		-- the root joint stays rigid so the body follows the HumanoidRootPart
		if d.Name == "Root" or d.Name == "RootJoint" then
			continue
		end
		if d:IsA("AnimationConstraint") then
			table.insert(rig.Joints, d)
		elseif d:IsA("Motor6D") and d.Part0 and d.Part1 then
			table.insert(rig.Joints, d)
			table.insert(rig.Sockets, socketFor(d))
		end
	end
	rigs[character] = rig
	character.Destroying:Once(function()
		rigs[character] = nil
	end)
	return rig
end

local function set(character: Model, on: boolean)
	local rig = rigs[character] or build(character)
	for _, joint in rig.Joints do
		if joint.Parent then
			(joint :: any).Enabled = not on
		end
	end
	for _, socket in rig.Sockets do
		if socket.Parent then
			socket.Enabled = on
		end
	end
end

-- Ragdoll a living player for `duration` seconds, then stand them back up.
function RagdollService.Stun(player: Player, duration: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and humanoid) or humanoid.Health <= 0 then
		return
	end
	local token = (tokens[player] or 0) + 1
	tokens[player] = token
	set(character, true)
	player:SetAttribute(Attributes.Ragdolled, true)
	clientEffect:FireClient(player, "Ragdoll", true)
	task.delay(duration, function()
		if tokens[player] ~= token or not player.Parent then
			return
		end
		player:SetAttribute(Attributes.Ragdolled, false)
		if player.Character == character and humanoid.Health > 0 then
			set(character, false)
			clientEffect:FireClient(player, "Ragdoll", false)
		end
	end)
end

-- Leave a dead character as a ragdoll (needs Humanoid.BreakJointsOnDeath = false).
function RagdollService.OnDeath(player: Player, character: Model)
	tokens[player] = (tokens[player] or 0) + 1
	player:SetAttribute(Attributes.Ragdolled, false)
	set(character, true)
end

function RagdollService.Init()
	Players.PlayerRemoving:Connect(function(player)
		tokens[player] = nil
	end)
end

return RagdollService
