--!strict
-- EmoteService: the survivor taunt wheel (client: EmoteController).
-- Every emote shows a bubble over your head, plays its sound and makes noise. Emoting
-- while Hidden is a Daredevil taunt: the God sees your silhouette for a moment and every
-- coin you earn for the next few seconds is multiplied (ScoringService.Award).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local AudioService = require(script.Parent.AudioService)
local RoleService = require(script.Parent.RoleService)
local ScoringService = require(script.Parent.ScoringService)
local ProgressionService = require(script.Parent.ProgressionService)
local StealthService = require(script.Parent.StealthService)

local E = Config.Emotes
local Attributes = Config.Attributes
local DAREDEVIL = Color3.fromRGB(255, 90, 160)

local EmoteService = {}

local readyAt: { [Player]: number } = {}

local function bubble(head: BasePart, icon: string)
	local old = head:FindFirstChild("EmoteBubble")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "EmoteBubble"
	gui.Size = UDim2.fromOffset(64, 64)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.MaxDistance = 250
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.Text = icon
	label.Parent = gui
	gui.Parent = head
	task.delay(E.BubbleSeconds, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

local function onEmote(player: Player, id: any)
	if typeof(id) ~= "string" or not RoleService.IsAliveSurvivor(player) then
		return
	end
	local def = nil
	for _, e in E.List do
		if e.Id == id then
			def = e
		end
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not (def and character and head) then
		return
	end
	local now = os.clock()
	if (readyAt[player] or 0) > now then
		return
	end
	readyAt[player] = now + E.Cooldown

	local wasHidden = StealthService.IsHidden(player)
	bubble(head, def.Icon)
	if def.Sound then
		AudioService.playAt(def.Sound, head.Position, 1.6)
	end
	if wasHidden then
		-- Daredevil: give yourself away for a coin multiplier
		player:SetAttribute(Attributes.DaredevilUntil, workspace:GetServerTimeNow() + E.DaredevilSeconds)
		ScoringService.GetRecord(player).Taunts += 1
		ProgressionService.AddMastery(player, "Taunts", 1)
		StealthService.Noise(player, 2)
		local god = RoleService.GetGod()
		if god then
			Remotes.get("ClientEffect"):FireClient(god, "Reveal", { character }, E.RevealSeconds)
			ScoringService.Notify(god, "😈 " .. string.upper(player.DisplayName) .. " IS TAUNTING YOU", DAREDEVIL)
		end
		ScoringService.Notify(player, string.format("😈 DAREDEVIL! x%.1f COINS FOR %ds", E.DaredevilMultiplier, E.DaredevilSeconds), DAREDEVIL)
		Remotes.get("Feed"):FireAllClients(string.format("😈 %s taunted the God from hiding!", player.DisplayName), DAREDEVIL)
	else
		StealthService.Noise(player, 1.2)
	end
end

function EmoteService.Init()
	Remotes.get("Emote").OnServerEvent:Connect(onEmote)
	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
	end)
end

return EmoteService
