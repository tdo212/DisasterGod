--!strict
-- LodgeController: brings the Sky Lodge showcase to life on the client.
--   * displays tagged Config.Lodge.DisplayTag (pass icons, gear props, God skin statues)
--     float up and down and turn on a slow turntable; their "Orbit" parts circle faster
--   * lights tagged FlickerTag (hearth, lanterns) wobble softly
--   * particle auras tagged AuraTag switch off in Low-FX
-- Only while the camera is up at the lodge and near a display, at Config.Lodge.AnimateRate.
-- Everything here is anchored and client-local (the server never moves these parts).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config") :: ModuleScript)

local Attributes = Config.Attributes

local LC = Config.Lodge
local player = Players.LocalPlayer

local LodgeController = {}

type Display = {
	Model: Model,
	Base: CFrame?, -- pivot as built (captured once the model has streamed in)
	Parts: { BasePart },
	Offsets: { CFrame },
	Orbit: { boolean },
	Phase: number,
	Spin: number,
	Bob: boolean,
	Dirty: boolean,
}

type Flicker = { Light: Light, Base: number, Phase: number }

local displays: { [Model]: Display } = {}
local flickers: { [Light]: Flicker } = {}

local function lowFx(): boolean
	return player:GetAttribute(Attributes.SettingPrefix .. "LowFx") == true
end

-- (Re)capture a display's parts relative to its pivot (the "Core" part).
local function capture(d: Display)
	local core = d.Model.PrimaryPart
	if not core then
		return
	end
	if not d.Base then
		-- upright and world-aligned: some cores are cylinders lying on their side, and the
		-- turntable must always spin about the vertical
		d.Base = CFrame.new(core.Position)
	end
	local base = d.Base :: CFrame
	-- parts already moved by us are put back to rest first, so offsets stay true
	local parts, offsets, orbit = {}, {}, {}
	for _, p in d.Model:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(parts, p)
			local rest = p:GetAttribute("LodgeRest")
			local cf = if typeof(rest) == "CFrame" then rest else p.CFrame
			p:SetAttribute("LodgeRest", cf)
			table.insert(offsets, base:ToObjectSpace(cf))
			table.insert(orbit, p.Name == "Orbit")
		end
	end
	d.Parts, d.Offsets, d.Orbit = parts, offsets, orbit
	d.Dirty = false
end

local function addDisplay(inst: Instance)
	if not inst:IsA("Model") or displays[inst] then
		return
	end
	local spin = inst:GetAttribute("Spin")
	local d: Display = {
		Model = inst,
		Base = nil,
		Parts = {},
		Offsets = {},
		Orbit = {},
		Phase = math.random() * math.pi * 2,
		Spin = if typeof(spin) == "number" then spin else 1,
		Bob = inst:GetAttribute("Bob") ~= false,
		Dirty = true,
	}
	displays[inst] = d
	-- streaming can deliver parts after the tag: recapture when the model grows
	inst.DescendantAdded:Connect(function(child)
		if child:IsA("BasePart") then
			d.Dirty = true
		end
	end)
end

local function addFlicker(inst: Instance)
	if not inst:IsA("Light") or flickers[inst] then
		return
	end
	local base = inst:GetAttribute("BaseBrightness")
	flickers[inst] = { Light = inst, Base = if typeof(base) == "number" then base else inst.Brightness, Phase = math.random() * 100 }
end

local function setAura(inst: Instance)
	if inst:IsA("ParticleEmitter") then
		inst.Enabled = not lowFx()
	end
end

local function watch(tag: string, added: (Instance) -> (), removed: ((Instance) -> ())?)
	for _, inst in CollectionService:GetTagged(tag) do
		added(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(added)
	if removed then
		CollectionService:GetInstanceRemovedSignal(tag):Connect(removed)
	end
end

local accum = 0

local function step(dt: number)
	accum += dt
	if accum < 1 / LC.AnimateRate then
		return
	end
	accum = 0
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	if eye.Y < Config.Weather.MaxCameraHeight then
		return -- down in the arena: the lodge is out of sight
	end
	local t = os.clock()
	local spinRate = math.rad(LC.DisplaySpin)
	local orbitRate = math.rad(LC.OrbitSpin)

	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	for _, d in displays do
		if d.Dirty then
			capture(d)
		end
		local base = d.Base
		if not base or (base.Position - eye).Magnitude > LC.AnimateDistance then
			continue
		end
		local bob = if d.Bob then math.sin(t * LC.BobSpeed + d.Phase) * LC.BobHeight else 0
		local pose = base * CFrame.new(0, bob, 0) * CFrame.Angles(0, t * spinRate * d.Spin + d.Phase, 0)
		local orbit = pose * CFrame.Angles(0, t * orbitRate, 0)
		for i, p in d.Parts do
			table.insert(parts, p)
			table.insert(cframes, (if d.Orbit[i] then orbit else pose) * d.Offsets[i])
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end

	for light, f in flickers do
		if not light.Parent then
			flickers[light] = nil
			continue
		end
		if (eye - (light.Parent :: any).Position).Magnitude > LC.AnimateDistance then
			continue
		end
		local n = math.noise(t * LC.FlickerSpeed, f.Phase) + 0.5 * math.noise(t * LC.FlickerSpeed * 2.3, f.Phase + 7)
		light.Brightness = f.Base * (1 + n * LC.FlickerAmount)
	end
end

function LodgeController.Start()
	watch(LC.DisplayTag, addDisplay, function(inst)
		if inst:IsA("Model") then
			displays[inst] = nil
		end
	end)
	watch(LC.FlickerTag, addFlicker)
	watch(LC.AuraTag, setAura)
	player:GetAttributeChangedSignal(Attributes.SettingPrefix .. "LowFx"):Connect(function()
		for _, inst in CollectionService:GetTagged(LC.AuraTag) do
			setAura(inst)
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return LodgeController
