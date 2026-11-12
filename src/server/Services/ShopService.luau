--!strict
-- ShopService: buy survival gear with coins and use it during a round.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local DestructionService = require(script.Parent.DestructionService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RoleService = require(script.Parent.RoleService)

local ShopService = {}

local gear: { [string]: Types.GearDefinition } = {}
for _, def in Config.Gear do
	gear[def.Id] = def
end

local popup = Remotes.get("Popup")
local clientEffect = Remotes.get("ClientEffect")
local roundActive = false

function ShopService.SetRoundActive(active: boolean)
	roundActive = active
end

local function use(player: Player, def: Types.GearDefinition)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (character and humanoid and hrp) then
		return
	end
	if def.Id == "SpeedSoda" then
		humanoid.WalkSpeed = Config.GearTuning.SpeedSodaWalkSpeed
		task.delay(def.Duration, function()
			if humanoid.Parent then
				humanoid.WalkSpeed = Config.Player.WalkSpeed
			end
		end)
		clientEffect:FireClient(player, "Boost", def.Duration)
	elseif def.Id == "Glider" then
		clientEffect:FireClient(player, "LowGravity", def.Duration, Config.GearTuning.GliderGravityScale)
	elseif def.Id == "Shield" then
		local field = Instance.new("ForceField")
		field.Visible = true
		field.Parent = character
		Debris:AddItem(field, def.Duration)
		-- shockwave pushes nearby loose debris away
		for _, part in DestructionService.GetDebrisNear(hrp.Position, Config.GearTuning.ShieldShockwaveRadius) do
			local away = part.Position - hrp.Position
			if away.Magnitude > 0.1 then
				part.AssemblyLinearVelocity = away.Unit * 60 + Vector3.new(0, 20, 0)
			end
		end
		clientEffect:FireClient(player, "Shake", 0.4, 0.3)
	end
end

function ShopService.Init()
	Remotes.get("BuyGear").OnServerEvent:Connect(function(player, id)
		if typeof(id) ~= "string" then
			return
		end
		local def = gear[id]
		if not def then
			return
		end
		if PlayerDataService.SpendCoins(player, def.Price) then
			PlayerDataService.AddGear(player, def.Id, 1)
			popup:FireClient(player, "BOUGHT " .. string.upper(def.DisplayName), def.Color)
		else
			popup:FireClient(player, "NOT ENOUGH COINS", Color3.fromRGB(255, 80, 80))
		end
	end)

	Remotes.get("UseGear").OnServerEvent:Connect(function(player, id)
		if typeof(id) ~= "string" then
			return
		end
		local def = gear[id]
		if not def or not roundActive or not RoleService.IsAliveSurvivor(player) then
			return
		end
		if PlayerDataService.ConsumeGear(player, def.Id) then
			use(player, def)
		end
	end)
end

return ShopService
