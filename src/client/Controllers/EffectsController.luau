--!strict
-- EffectsController: server-requested juice on the local player — knockback, ragdoll
-- tumbles, camera shake with an impact punch, low-gravity balloon, speed boost FOV.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local player = Players.LocalPlayer

local EffectsController = {}

local shake = 0
local started = false
local ragdolled = false
local punching = false

local function rootAndHumanoid(): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?, character:FindFirstChildOfClass("Humanoid")
end

-- Adds trauma-style shake; falls off with distance from the camera when a centre is given.
function EffectsController.Shake(intensity: number, _duration: number, center: Vector3?)
	local scale = 1
	local camera = workspace.CurrentCamera
	if center and camera then
		local d = (camera.Focus.Position - center).Magnitude
		scale = math.clamp(1 - d / 260, 0.1, 1)
	end
	shake = math.min(2, shake + intensity * scale)
	-- heavy hits also punch the field of view for a beat (the "hitstop" feel)
	if camera and not punching and intensity * scale >= Config.Juice.ImpactThreshold then
		punching = true
		local fov = camera.FieldOfView
		camera.FieldOfView = fov - Config.Juice.ImpactFovKick
		local tween = TweenService:Create(camera, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { FieldOfView = fov })
		tween:Play()
		tween.Completed:Once(function()
			punching = false
		end)
	end
end

-- The server swaps the joints for ball sockets; the owning client has to put the
-- Humanoid into the Physics state for the body to actually flop.
local function setRagdoll(on: boolean)
	local hrp, humanoid = rootAndHumanoid()
	ragdolled = on
	if not humanoid then
		return
	end
	if on then
		humanoid.AutoRotate = false
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		if hrp then
			local spin = Config.Ragdoll.Spin
			hrp.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2 * spin
		end
	else
		humanoid.AutoRotate = true
		if humanoid.Health > 0 then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end
end

local function knockback(velocity: Vector3)
	local hrp, humanoid = rootAndHumanoid()
	if not (hrp and humanoid) or humanoid.Health <= 0 then
		return
	end
	if not ragdolled then
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity * 0.3 + velocity
end

local function lowGravity(duration: number, gravityScale: number)
	local hrp, humanoid = rootAndHumanoid()
	if not (hrp and humanoid) then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = hrp
	local force = Instance.new("VectorForce")
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	local character = hrp.Parent :: Model
	local mass = 0
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			mass += d:GetMass()
		end
	end
	force.Force = Vector3.new(0, mass * workspace.Gravity * (1 - gravityScale), 0)
	force.Parent = hrp

	-- balloon visual
	local balloon = Instance.new("Part")
	balloon.Name = "Balloon"
	balloon.Shape = Enum.PartType.Ball
	balloon.Size = Vector3.new(3, 3, 3)
	balloon.Color = Color3.fromRGB(255, 80, 110)
	balloon.Material = Enum.Material.SmoothPlastic
	balloon.CanCollide = false
	balloon.CanQuery = false
	balloon.Massless = true
	balloon.CFrame = hrp.CFrame * CFrame.new(0, 6, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = balloon
	weld.Parent = balloon
	balloon.Parent = character

	task.delay(duration, function()
		force:Destroy()
		attachment:Destroy()
		balloon:Destroy()
	end)
end

local function boost(duration: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	TweenService:Create(camera, TweenInfo.new(0.25), { FieldOfView = 82 }):Play()
	task.delay(duration, function()
		TweenService:Create(camera, TweenInfo.new(0.5), { FieldOfView = 70 }):Play()
	end)
end

function EffectsController.Start()
	if started then
		return
	end
	started = true

	Remotes.get("ClientEffect").OnClientEvent:Connect(function(kind: string, a: any, b: any, c: any)
		if kind == "Knockback" and typeof(a) == "Vector3" then
			knockback(a)
		elseif kind == "Ragdoll" and typeof(a) == "boolean" then
			setRagdoll(a)
		elseif kind == "Shake" and typeof(a) == "number" then
			EffectsController.Shake(a, if typeof(b) == "number" then b else 0.3, if typeof(c) == "Vector3" then c else nil)
		elseif kind == "LowGravity" and typeof(a) == "number" then
			lowGravity(a, if typeof(b) == "number" then b else 0.3)
		elseif kind == "Boost" and typeof(a) == "number" then
			boost(a)
		end
	end)

	player.CharacterAdded:Connect(function()
		ragdolled = false
	end)

	-- applied after the camera scripts so it works for both custom and orbit cameras
	RunService:BindToRenderStep("DisasterGodShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if shake <= 0.001 then
			shake = 0
			return
		end
		local camera = workspace.CurrentCamera
		if camera then
			local s = shake * shake
			local t = os.clock() * 40
			camera.CFrame *= CFrame.Angles(
				math.rad(math.noise(t, 1) * 4 * s),
				math.rad(math.noise(t, 2) * 4 * s),
				math.rad(math.noise(t, 3) * 3 * s)
			) + Vector3.new(math.noise(t, 4), math.noise(t, 5), 0) * s
		end
		shake = math.max(0, shake - Config.Camera.ShakeDecay * dt * math.max(shake, 0.3))
	end)
end

return EffectsController
