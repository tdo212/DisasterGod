--!strict
-- ShopService: buy survival gear and God kits with coins; use gear during a round.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local DestructionService = require(script.Parent.DestructionService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local QuestService = require(script.Parent.QuestService)
local RoleService = require(script.Parent.RoleService)
local StealthService = require(script.Parent.StealthService)

local ShopService = {}

local kits: { [string]: Types.KitDefinition } = {}
for _, kit in Config.Kits do
	kits[kit.Id] = kit
end

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
	StealthService.Noise(player, 1) -- gear is loud: the God hears it
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

-- One of every gear item (Survival Kit / Welcome Pack).
function ShopService.GrantKit(player: Player)
	for _, def in Config.Gear do
		PlayerDataService.AddGear(player, def.Id, 1)
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
			QuestService.Progress(player, "Gear", 1)
		end
	end)

	Remotes.get("KitAction").OnServerEvent:Connect(function(player, action, kitId)
		if typeof(action) ~= "string" or typeof(kitId) ~= "string" then
			return
		end
		local kit = kits[kitId]
		if not kit then
			return
		end
		if action == "Buy" then
			if PlayerDataService.OwnsKit(player, kitId) then
				return
			end
			if PlayerDataService.SpendCoins(player, kit.Price) then
				PlayerDataService.GrantKit(player, kitId)
				PlayerDataService.EquipKit(player, kitId)
				popup:FireClient(player, "UNLOCKED " .. string.upper(kit.Name), kit.Color)
				PlayerDataService.SaveNow(player)
			else
				popup:FireClient(player, "NOT ENOUGH COINS", Color3.fromRGB(255, 80, 80))
			end
		elseif action == "Equip" and PlayerDataService.EquipKit(player, kitId) then
			popup:FireClient(player, string.upper(kit.Name) .. " EQUIPPED", kit.Color)
		end
	end)
end

return ShopService
