--!strict
-- Sticker-style icon set (glossy fill, thick navy outline, sparkles) drawn to match the
-- UIReference look. 48 icons packed 16 per 1024x1024 sheet at 256 px, so the whole HUD
-- loads three images. Regenerate with tools/icons/gen_icons.py and re-upload.
--
-- Icons.resolve accepts an icon name ("Shop") or one of the emoji the config already
-- uses ("⚡"), so config entries keep working and anything unmapped falls back to text.

local Icons = {}

local SHEETS = {
	"rbxassetid://89684247763501",
	"rbxassetid://111533529475743",
	"rbxassetid://101621388403037",
}
local CELL = 256

-- name = { sheet, x, y } (pixel offsets inside the sheet)
local INDEX: { [string]: { number } } = {
	Shop = { 1, 0, 0 }, Spin = { 1, 256, 0 }, Quests = { 1, 512, 0 }, Passes = { 1, 768, 0 },
	Spectate = { 1, 0, 256 }, PlayGod = { 1, 256, 256 }, Settings = { 1, 512, 256 }, Coin = { 1, 768, 256 },
	Emote = { 1, 0, 512 }, Dash = { 1, 256, 512 }, Close = { 1, 512, 512 }, SpeedSoda = { 1, 768, 512 },
	Glider = { 1, 0, 768 }, Shield = { 1, 256, 768 }, Trophy = { 1, 512, 768 }, Skull = { 1, 768, 768 },
	Lightning = { 2, 0, 0 }, Gust = { 2, 256, 0 }, Meteor = { 2, 512, 0 }, Tornado = { 2, 768, 0 },
	FaultCleave = { 2, 0, 256 }, ChainLightning = { 2, 256, 256 }, Eruption = { 2, 512, 256 }, Glitch = { 2, 768, 256 },
	SeismicPing = { 2, 0, 512 }, GravitySingularity = { 2, 256, 512 }, TectonicSpire = { 2, 512, 512 }, ChainArc = { 2, 768, 512 },
	MeteorBarrage = { 2, 0, 768 }, PyroclastSurge = { 2, 256, 768 }, SystemOverride = { 2, 512, 768 }, AstralCollapse = { 2, 768, 768 },
	MaelstromVortex = { 3, 0, 0 }, Heart = { 3, 256, 0 }, Gift = { 3, 512, 0 }, Vote = { 3, 768, 0 },
	Bag = { 3, 0, 256 }, Crown = { 3, 256, 256 }, Timer = { 3, 512, 256 }, Star = { 3, 768, 256 },
	Flare = { 3, 0, 512 }, Crate = { 3, 256, 512 }, Firework = { 3, 512, 512 }, Berry = { 3, 768, 512 },
	Bandage = { 3, 0, 768 }, Mastery = { 3, 256, 768 }, Robux = { 3, 512, 768 }, Sound = { 3, 768, 768 },
}

-- Emoji already used across Config (abilities, products, gear, kits, cosmetics).
local EMOJI: { [string]: string } = {
	["🛒"] = "Shop", ["🎡"] = "Spin", ["📜"] = "Quests", ["🎫"] = "Passes",
	["👁️"] = "Spectate", ["👁"] = "Spectate", ["😈"] = "PlayGod", ["⚙️"] = "Settings", ["🪙"] = "Coin",
	["😜"] = "Emote", ["💨"] = "Dash", ["❌"] = "Close", ["🥤"] = "SpeedSoda", ["🎈"] = "Glider",
	["🪂"] = "Glider", ["🛡️"] = "Shield", ["🏆"] = "Trophy", ["💀"] = "Skull", ["⚡"] = "Lightning",
	["🌬️"] = "Gust", ["☄️"] = "Meteor", ["🌪️"] = "Tornado", ["💥"] = "FaultCleave", ["🌩️"] = "ChainLightning",
	["⛈️"] = "ChainLightning", ["🌋"] = "Eruption", ["👾"] = "Glitch", ["📡"] = "SeismicPing",
	["🕳️"] = "GravitySingularity", ["🗻"] = "TectonicSpire", ["🔗"] = "ChainArc", ["🎯"] = "MeteorBarrage",
	["🌊"] = "PyroclastSurge", ["📵"] = "SystemOverride", ["🌌"] = "AstralCollapse", ["🌀"] = "MaelstromVortex",
	["💖"] = "Heart", ["❤️"] = "Heart", ["🎁"] = "Gift", ["🗳️"] = "Vote", ["💰"] = "Bag", ["💰💰"] = "Bag",
	["🏦"] = "Bag", ["🧰"] = "Crate", ["🎒"] = "Crate", ["👑"] = "Crown", ["⚜️"] = "Crown", ["🏛️"] = "Trophy",
	["⏱️"] = "Timer", ["⭐"] = "Star", ["🌟"] = "Star", ["✨"] = "Star", ["💸"] = "Coin", ["🔥"] = "Eruption",
	["🤖"] = "SystemOverride", ["🟣"] = "GravitySingularity", ["🎉"] = "Firework", ["🔊"] = "Sound",
	["✊"] = "TectonicSpire", ["🔦"] = "Flare", ["📦"] = "Crate", ["🫐"] = "Berry", ["🩹"] = "Bandage",
	["🏅"] = "Mastery", ["🎆"] = "Firework",
	["☠️"] = "Skull", ["🏃"] = "Dash", ["⚠️"] = "Flare", ["🎲"] = "Star", ["🛰️"] = "SeismicPing",
}

export type Sprite = { Image: string, Offset: Vector2, Size: Vector2 }

-- Sprite for an icon name or a known emoji, or nil (callers fall back to text).
function Icons.resolve(key: string?): Sprite?
	if not key then
		return nil
	end
	local name = EMOJI[key] or key
	local entry = INDEX[name]
	if not entry then
		return nil
	end
	return { Image = SHEETS[entry[1]], Offset = Vector2.new(entry[2], entry[3]), Size = Vector2.new(CELL, CELL) }
end

function Icons.has(key: string?): boolean
	return Icons.resolve(key) ~= nil
end

-- Point an ImageLabel / ImageButton at an icon. Returns false if the key is unknown.
function Icons.apply(image: ImageLabel | ImageButton, key: string?): boolean
	local sprite = Icons.resolve(key)
	if not sprite then
		return false
	end
	image.Image = sprite.Image
	image.ImageRectOffset = sprite.Offset
	image.ImageRectSize = sprite.Size
	return true
end

-- Every sheet, for ContentProvider preloading.
function Icons.sheets(): { string }
	return table.clone(SHEETS)
end

return Icons
