--!strict
-- Scriptable overhead orbit camera used by the Disaster God and spectators.
-- WASD/arrows pan, Q/E rotate, mouse wheel zooms, right-drag rotates.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config") :: ModuleScript)

local CamCfg = Config.Camera

local OrbitCamera = {}

local enabled = false
local focus = Vector3.zero
local yaw = 0
local pitch = CamCfg.GodPitch
local zoom = CamCfg.GodStartZoom
local rmbDown = false
local connections: { RBXScriptConnection } = {}

local BIND = "DisasterGodOrbit"
local SINK = "DisasterGodOrbitSink"

local function keyAxis(positive: { Enum.KeyCode }, negative: { Enum.KeyCode }): number
	local v = 0
	for _, k in positive do
		if UserInputService:IsKeyDown(k) then
			v += 1
			break
		end
	end
	for _, k in negative do
		if UserInputService:IsKeyDown(k) then
			v -= 1
			break
		end
	end
	return v
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if UserInputService:GetFocusedTextBox() == nil then
		local forward = keyAxis({ Enum.KeyCode.W, Enum.KeyCode.Up }, { Enum.KeyCode.S, Enum.KeyCode.Down })
		local right = keyAxis({ Enum.KeyCode.D, Enum.KeyCode.Right }, { Enum.KeyCode.A, Enum.KeyCode.Left })
		local rotate = keyAxis({ Enum.KeyCode.E }, { Enum.KeyCode.Q })
		yaw -= rotate * CamCfg.GodRotateSpeed * dt
		local flatForward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
		local flatRight = Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
		local speed = CamCfg.GodPanSpeed * (zoom / CamCfg.GodStartZoom)
		focus += (flatForward * forward + flatRight * right) * speed * dt
		local limit = Config.World.ArenaRadius
		if focus.Magnitude > limit then
			focus = focus.Unit * limit
		end
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(focus) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(-pitch, 0, 0) * CFrame.new(0, 0, zoom)
	camera.Focus = CFrame.new(focus)
end

function OrbitCamera.IsEnabled(): boolean
	return enabled
end

function OrbitCamera.GetLookDirection(): Vector3
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

function OrbitCamera.Enable(startFocus: Vector3?)
	if enabled then
		return
	end
	enabled = true
	focus = startFocus or Config.World.ArenaCenter
	zoom = CamCfg.GodStartZoom
	pitch = CamCfg.GodPitch
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value, step)
	-- keep WASD / space from walking the character while flying the camera
	ContextActionService:BindActionAtPriority(SINK, function()
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Space)

	table.insert(connections, UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			rmbDown = true
		end
	end))
	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			rmbDown = false
		end
	end))
	table.insert(connections, UserInputService.InputChanged:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			zoom = math.clamp(zoom - input.Position.Z * 12, CamCfg.GodMinZoom, CamCfg.GodMaxZoom)
		elseif input.UserInputType == Enum.UserInputType.MouseMovement and rmbDown then
			yaw -= input.Delta.X * 0.006
			pitch = math.clamp(pitch + input.Delta.Y * 0.004, math.rad(25), math.rad(85))
		end
	end))
end

function OrbitCamera.Disable()
	if not enabled then
		return
	end
	enabled = false
	rmbDown = false
	RunService:UnbindFromRenderStep(BIND)
	ContextActionService:UnbindAction(SINK)
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

-- World point under a screen position (arena geometry, else the y=0 plane).
function OrbitCamera.ScreenToWorld(screen: Vector2, exclude: { Instance }?): Vector3?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { arena }
		local result = workspace:Raycast(ray.Origin, ray.Direction * 1500, params)
		if result then
			return result.Position
		end
	end
	if math.abs(ray.Direction.Y) > 1e-3 then
		local t = -ray.Origin.Y / ray.Direction.Y
		if t > 0 then
			return ray.Origin + ray.Direction * t
		end
	end
	return nil
end

return OrbitCamera
