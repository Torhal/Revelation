-------------------------------------------------------------------------------
-- Localized Lua API
-------------------------------------------------------------------------------
local _G = getfenv(0)

-------------------------------------------------------------------------------
-- AddOn namespace
-------------------------------------------------------------------------------
local ADDON_NAME, private = ...

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------
local PICKABLE

-------------------------------------------------------------------------------
-- Functions.
-------------------------------------------------------------------------------
function private.CanPick()
	if not PICKABLE then
		PICKABLE = {
			["4632"]	= 1,	-- Ornate Bronze Lockbox
			["4633"]	= 25,	-- Heavy Bronze Lockbox
			["4634"]	= 70,	-- Iron Lockbox
			["4636"]	= 125,	-- Strong Iron Lockbox
			["4637"]	= 175,	-- Steel Lockbox
			["4638"]	= 225,	-- Reinforced Steel Lockbox
			["5758"]	= 225,	-- Mithril Lockbox
			["5759"]	= 225,	-- Thorium Lockbox
			["5760"]	= 225,	-- Eternium Lockbox
			["6354"]	= 1,	-- Small Locked Chest
			["6355"]	= 70,	-- Sturdy Locked Chest
			["6712"]	= 1,	-- Practice Lock
			["7209"]	= 1,	-- Tazan's Satchel
			["12033"]	= 275,	-- Thaurissan Family Jewels
			["13875"]	= 175,	-- Ironbound Locked Chest
			["13918"]	= 250,	-- Reinforced Locked Chest
			["16882"]	= 1,	-- Battered Junkbox
			["16883"]	= 70,	-- Worn Junkbox
			["16884"]	= 175,	-- Sturdy Junkbox
			["16885"]	= 250,	-- Heavy Junkbox
			["29569"]	= 300,	-- Strong Junkbox
			["31952"]	= 325,	-- Khorium Lockbox
			["43575"]	= 350,	-- Reinforced Junkbox
			["43622"]	= 375,	-- Froststeel Lockbox
			["43624"]	= 400,	-- Titanium Lockbox
			["45986"]	= 400,	-- Tiny Titanium Lockbox
		}
	end
	local id = _G.select(3, private.cur_item.link:find("item:(%d+):"))

	if not id or not PICKABLE[id] then
		return false, nil
	end
	return true, PICKABLE[id]
end
