-------------------------------------------------------------------------------
-- AddOn namespace
-------------------------------------------------------------------------------
local ADDON_NAME, common = ...


-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------
local MILLABLE = {
	[765]	= true,	-- Silverleaf
	[785]	= true,	-- Mageroyal
	[2447]	= true,	-- Peacebloom
	[2449]	= true,	-- Earthroot
	[2450]	= true,	-- Briarthorn
	[2452]	= true,	-- Swiftthistle
	[2453]	= true,	-- Bruiseweed
	[3355]	= true,	-- Wild Steelbloom
	[3356]	= true,	-- Kingsblood
	[3357]	= true,	-- Liferoot
	[3358]	= true,	-- Khadgar's Whisker
	[3369]	= true,	-- Grave Moss
	[3818]	= true,	-- Fadeleaf
	[3819]	= true,	-- Wintersbite
	[3820]	= true,	-- Stranglekelp
	[3821]	= true,	-- Goldthorn
	[4625]	= true,	-- Firebloom
	[8831]	= true,	-- Purple Lotus
	[8836]	= true,	-- Arthas' Tears
	[8838]	= true,	-- Sungrass
	[8839]	= true,	-- Blindweed
	[8845]	= true,	-- Ghost Mushroom
	[8846]	= true,	-- Gromsblood
	[13463]	= true,	-- Dreamfoil
	[13464]	= true,	-- Golden Sansam
	[13465]	= true,	-- Mountain Silversage
	[13466]	= true,	-- Plaguebloom
	[13467]	= true,	-- Icecap
	[22785]	= true,	-- Felweed
	[22786]	= true,	-- Dreaming Glory
	[22787]	= true,	-- Ragveil
	[22789]	= true,	-- Terocone
	[22790]	= true,	-- Ancient Lichen
	[22791]	= true,	-- Netherbloom
	[22792]	= true,	-- Nightmare Vine
	[22793]	= true,	-- Mana Thistle
	[36901]	= true,	-- Goldclover
	[36903]	= true,	-- Adder's Tongue
	[36904]	= true,	-- Tiger Lily
	[36905]	= true,	-- Lichbloom
	[36906]	= true,	-- Icethorn
	[36907]	= true,	-- Talandra's Rose
}

-------------------------------------------------------------------------------
-- Variables.
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- Functions.
-------------------------------------------------------------------------------
function common.CanMill()
	local id = select(3, common.cur_item.link:find("item:(%d+):"))

	if not id or (id and not MILLABLE[tonumber(id)]) then
		return false
	end
	return true
end
