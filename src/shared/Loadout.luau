--!strict
-- Loadout: the abilities a God actually has this round (client hotbar + server checks).
-- The equipped kit gives five, the universal slot adds Seismic Ping, and an equipped
-- God Pack (Config.GodPacks, keyed by GodSkin cosmetic) swaps one ability for its
-- signature version. A signature always costs and cools down exactly like the ability it
-- replaces, so packs change how a God plays, never how strong it is. If the kit lacks
-- that ability, the signature takes the kit's last slot.

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Loadout = {}

function Loadout.kit(kitId: any): Types.KitDefinition
	for _, kit in Config.Kits do
		if kit.Id == kitId then
			return kit
		end
	end
	return Config.Kits[1]
end

-- Ordered ability ids: the five kit slots (with the pack's signature swapped in), then
-- the universal ones.
function Loadout.ids(kitId: any, skinId: any): { string }
	local ids = table.clone(Loadout.kit(kitId).Abilities)
	local pack = if typeof(skinId) == "string" then Config.GodPacks[skinId] else nil
	if pack then
		local slot = table.find(ids, pack.Replaces) or #ids
		ids[slot] = pack.Signature
	end
	for _, id in Config.Disasters.UniversalAbilities do
		table.insert(ids, id)
	end
	return ids
end

function Loadout.allows(kitId: any, skinId: any, abilityId: string): boolean
	return table.find(Loadout.ids(kitId, skinId), abilityId) ~= nil
end

return Loadout
