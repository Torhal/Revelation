-------------------------------------------------------------------------------
-- AddOn namespace
-------------------------------------------------------------------------------
local ADDON_NAME, private = ...


-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------
local CANNOT_DE
local ENCHANT_LEVELS

-------------------------------------------------------------------------------
-- Functions.
-------------------------------------------------------------------------------
function private.CanDisenchant()
	local cur_item = private.cur_item
	local id = select(3, cur_item.link:find("item:(%d+):"))

	if not CANNOT_DE then
		CANNOT_DE = {
			[11287] = true,	-- Lesser Magic Wand
			[11288] = true,	-- Greater Magic Wand
			[11289] = true,	-- Lesser Mystic Wand
			[11290] = true,	-- Greater Mystic Wand
			[12772] = true,	-- Inlaid Thorium Hammer
			[14812] = true,	-- Warstrike Buckler
			[18665] = true,	-- The Eye of Shadow
			[20406] = true,	-- Twilight Cultist Mantle
			[20407] = true,	-- Twilight Cultist Robe
			[20408] = true,	-- Twilight Cultist Cowl
			[21766] = true,	-- Opal Necklace of Impact
			[29174] = true,	-- Watcher's Cowl
			[29378] = true,	-- Starheart Baton
			[31336] = true,	-- Blade of Wizardry
			[32540] = true,	-- Terokk's Might
			[32541] = true,	-- Terokk's Wisdom
			[32660] = true,	-- Crystalforged Sword
			[32662] = true,	-- Flaming Quartz Staff
			[32912] = true, -- Yellow Brewfest Stein
			[32915] = true,	-- Filled Yellow Brewfest Stein
			[32917] = true,	-- Filled Yellow Brewfest Stein
			[32918] = true,	-- Filled Yellow Brewfest Stein
			[32919] = true,	-- Filled Yellow Brewfest Stein
			[32920] = true,	-- Filled Yellow Brewfest Stein
		}
	end

	if not id or (id and CANNOT_DE[tonumber(id)]) then
		return false
	end
	local type = cur_item.type
	local quality = cur_item.quality

	if (type == _G.ARMOR or type == _G.ENCHSLOT_WEAPON) and quality > 1 and quality < 5 then
		return true
	end
	return false
end


function private.GetEnchantLevels()
	if not ENCHANT_LEVELS then
		ENCHANT_LEVELS = {
			[25086] = 35,	-- Enchant Cloak - Dodge
			[27899] = 35,	-- Enchant Bracer - Brawn
			[27905] = 35,	-- Enchant Bracer - Stats
			[27906] = 35,	-- Enchant Bracer - Major Defense
			[27911] = 35,	-- Enchant Bracer - Superior Healing
			[27913] = 35,	-- Enchant Bracer - Restore Mana Prime
			[27914] = 35,	-- Enchant Bracer - Fortitude
			[27917] = 35,	-- Enchant Bracer - Spellpower
			[27920] = 35,	-- Enchant Ring - Striking
			[27924] = 35,	-- Enchant Ring - Spellpower
			[27926] = 35,	-- Enchant Ring - Healing Power
			[27927] = 35,	-- Enchant Ring - Stats
			[27944] = 35,	-- Enchant Shield - Tough Shield
			[27945] = 35,	-- Enchant Shield - Intellect
			[27946] = 35,	-- Enchant Shield - Shield Block
			[27947] = 35,	-- Enchant Shield - Resistance
			[27948] = 35,	-- Enchant Boots - Vitality
			[27950] = 35,	-- Enchant Boots - Fortitude
			[27951] = 35,	-- Enchant Boots - Dexterity
			[27954] = 35,	-- Enchant Boots - Surefooted
			[27957] = 35,	-- Enchant Chest - Exceptional Health
			[27958] = 60,	-- Enchant Chest - Exceptional Mana
			[27960] = 35,	-- Enchant Chest - Exceptional Stats
			[27961] = 35,	-- Enchant Cloak - Major Armor
			[27962] = 35,	-- Enchant Cloak - Major Resistance
			[27967] = 35,	-- Enchant Weapon - Major Striking
			[27968] = 35,	-- Enchant Weapon - Major Intellect
			[27971] = 35,	-- Enchant 2H Weapon - Savagery
			[27972] = 35,	-- Enchant Weapon - Potency
			[27975] = 35,	-- Enchant Weapon - Major Spellpower
			[27977] = 35,	-- Enchant 2H Weapon - Major Agility
			[27981] = 35,	-- Enchant Weapon - Sunfire
			[27982] = 35,	-- Enchant Weapon - Soulfrost
			[27984] = 35,	-- Enchant Weapon - Mongoose
			[28003] = 35,	-- Enchant Weapon - Spellsurge
			[28004] = 35,	-- Enchant Weapon - Battlemaster
			[33990] = 35,	-- Enchant Chest - Major Spirit
			[33991] = 35,	-- Enchant Chest - Restore Mana Prime
			[33992] = 35,	-- Enchant Chest - Major Resilience
			[33993] = 35,	-- Enchant Gloves - Blasting
			[33994] = 35,	-- Enchant Gloves - Precise Strikes
			[33995] = 35,	-- Enchant Gloves - Major Strength
			[33996] = 35,	-- Enchant Gloves - Assault
			[33997] = 35,	-- Enchant Gloves - Major Spellpower
			[33999] = 35,	-- Enchant Gloves - Major Healing
			[34001] = 35,	-- Enchant Bracer - Major Intellect
			[34002] = 35,	-- Enchant Bracer - Assault
			[34003] = 35,	-- Enchant Cloak - Spell Penetration
			[34004] = 35,	-- Enchant Cloak - Greater Agility
			[34005] = 35,	-- Enchant Cloak - Greater Arcane Resistance
			[34006] = 35,	-- Enchant Cloak - Greater Shadow Resistance
			[34007] = 35,	-- Enchant Boots - Cat's Swiftness
			[34008] = 35,	-- Enchant Boots - Boar's Speed
			[34009] = 35,	-- Enchant Shield - Major Stamina
			[34010] = 35,	-- Enchant Weapon - Major Healing
			[42620] = 35,	-- Enchant Weapon - Greater Agility
			[42974] = 60,	-- Enchant Weapon - Executioner
			[44383] = 35,	-- Enchant Shield - Resilience
			[44483] = 60,	-- Enchant Cloak - Superior Frost Resistance
			[44484] = 60,	-- Enchant Gloves - Expertise
			[44488] = 60,	-- Enchant Gloves - Precision
			[44489] = 60,	-- Enchant Shield - Defense
			[44492] = 60,	-- Enchant Chest - Mighty Health
			[44494] = 60,	-- Enchant Cloak - Superior Nature Resistance
			[44500] = 60,	-- Enchant Cloak - Superior Agility
			[44506] = 60,	-- Enchant Gloves - Gatherer
			[44508] = 60,	-- Enchant Boots - Greater Spirit
			[44509] = 60,	-- Enchant Chest - Greater Mana Restoration
			[44510] = 60,	-- Enchant Weapon - Exceptional Spirit
			[44513] = 60,	-- Enchant Gloves - Greater Assault
			[44524] = 60,	-- Enchant Weapon - Icebreaker
			[44528] = 60,	-- Enchant Boots - Greater Fortitude
			[44529] = 60,	-- Enchant Gloves - Major Agility
			[44555] = 60,	-- Enchant Bracers - Exceptional Intellect
			[44556] = 60,	-- Enchant Cloak - Superior Fire Resistance
			[44575] = 60,	-- Enchant Bracers - Greater Assault
			[44576] = 60,	-- Enchant Weapon - Lifeward
			[44582] = 60,	-- Enchant Cloak - Spell Piercing
			[44584] = 60,	-- Enchant Boots - Greater Vitality
			[44588] = 60,	-- Enchant Chest - Exceptional Resilience
			[44589] = 60,	-- Enchant Boots - Superior Agility
			[44590] = 60,	-- Enchant Cloak - Superior Shadow Resistance
			[44591] = 60,	-- Enchant Cloak - Titanweave
			[44592] = 60,	-- Enchant Gloves - Exceptional Spellpower
			[44593] = 60,	-- Enchant Bracers - Major Spirit
			[44595] = 60,	-- Enchant 2H Weapon - Scourgebane
			[44596] = 60,	-- Enchant Cloak - Superior Arcane Resistance
			[44598] = 60,	-- Enchant Bracers - Expertise
			[44612] = 60,	-- Enchant Gloves - Greater Blasting
			[44616] = 60,	-- Enchant Bracers - Greater Stats
			[44621] = 60,	-- Enchant Weapon - Giant Slayer
			[44623] = 60,	-- Enchant Chest - Super Stats
			[44625] = 60,	-- Enchant Gloves - Armsman
			[44629] = 60,	-- Enchant Weapon - Exceptional Spellpower
			[44630] = 60,	-- Enchant 2H Weapon - Greater Savagery
			[44631] = 60,	-- Enchant Cloak - Shadow Armor
			[44633] = 60,	-- Enchant Weapon - Exceptional Agility
			[44635] = 60,	-- Enchant Bracers - Greater Spellpower
			[44636] = 60,	-- Enchant Ring - Greater Spellpower
			[44645] = 60,	-- Enchant Ring - Assault
			[46578] = 60,	-- Enchant Weapon - Deathfrost
			[46594] = 35,	-- Enchant Chest - Defense
			[47051] = 35,	-- Enchant Cloak - Steelweave
			[47672] = 60,	-- Enchant Cloak - Mighty Armor
			[47766] = 60,	-- Enchant Chest - Greater Defense
			[47898] = 60,	-- Enchant Cloak - Greater Speed
			[47899] = 60,	-- Enchant Cloak - Wisdom
			[47900] = 60,	-- Enchant Chest - Super Health
			[47901] = 60,	-- Enchant Boots - Tuskarr's Vitality
			[59619] = 60,	-- Enchant Weapon - Accuracy
			[59621] = 60,	-- Enchant Weapon - Berserking
			[59625] = 60,	-- Enchant Weapon - Black Magic
			[60606] = 60,	-- Enchant Boots - Assault
			[60609] = 60,	-- Enchant Cloak - Speed
			[60616] = 60,	-- Enchant Bracers - Striking
			[60621] = 60,	-- Enchant Weapon - Greater Potency
			[60623] = 60,	-- Enchant Boots - Icewalker
			[60653] = 60,	-- Enchant Shield - Greater Intellect
			[60663] = 60,	-- Enchant Cloak - Major Agility
			[60668] = 60,	-- Enchant Gloves - Crusher
			[60691] = 60,	-- Enchant 2H Weapon - Massacre
			[60692] = 60,	-- Enchant Chest - Powerful Stats
			[60707] = 60,	-- Enchant Weapon - Superior Potency
			[60714] = 60,	-- Enchant Weapon - Mighty Spellpower
			[60763] = 60,	-- Enchant Boots - Greater Assault
			[60767] = 60,	-- Enchant Bracers - Superior Spellpower
			[62256] = 60,	-- Enchant Bracers - Major Stamina
			[62257] = 60,	-- Enchant Weapon - Titanguard
			[62948] = 60,	-- Enchant Staff - Greater Spellpower
			[62959] = 60,	-- Enchant Staff - Spellpower
			[64441] = 60,	-- Enchant Weapon - Blade Ward
			[64579] = 60,	-- Enchant Weapon - Blood Draining
			[74132]	= 300,	-- Enchant Gloves - Mastery
			[74189]	= 300,	-- Enchant Boots - Earthen Vitality
			[74191]	= 300,	-- Enchant Chest - Mighty Stats
			[74192]	= 300,	-- Enchant Cloak - Greater Spell Piercing
			[74193]	= 300,	-- Enchant Bracer - Speed
			[74195]	= 300,	-- Enchant Weapon - Mending
			[74197]	= 300,	-- Enchant Weapon - Avalanche
			[74198]	= 300,	-- Enchant Gloves - Haste
			[74199]	= 300,	-- Enchant Boots - Haste
			[74200]	= 300,	-- Enchant Chest - Stamina
			[74201]	= 300,	-- Enchant Bracer - Critical Strike
			[74202]	= 300,	-- Enchant Cloak - Intellect
			[74207]	= 300,	-- Enchant Shield - Protection
			[74211]	= 300,	-- Enchant Weapon - Elemental Slayer
			[74212]	= 300,	-- Enchant Gloves - Exceptional Strength
			[74213]	= 300,	-- Enchant Boots - Major Agility
			[74214]	= 300,	-- Enchant Chest - Mighty Resilience
			[74215]	= 300,	-- Enchant Ring - Strength
			[74216]	= 300,	-- Enchant Ring - Agility
			[74217]	= 300,	-- Enchant Ring - Intellect
			[74218]	= 300,	-- Enchant Ring - Greater Stamina
			[74220]	= 300,	-- Enchant Gloves - Greater Expertise
			[74223]	= 300,	-- Enchant Weapon - Hurricane
			[74225]	= 300,	-- Enchant Weapon - Heartsong
			[74226]	= 300,	-- Enchant Shield - Blocking
			[74229]	= 300,	-- Enchant Bracer - Dodge
			[74230]	= 300,	-- Enchant Cloak - Critical Strike
			[74231]	= 300,	-- Enchant Chest - Exceptional Spirit
			[74232]	= 300,	-- Enchant Bracer - Precision
			[74234]	= 300,	-- Enchant Cloak - Protection
			[74235]	= 300,	-- Enchant Off-Hand - Superior Intellect
			[74236]	= 300,	-- Enchant Boots - Precision
			[74237]	= 300,	-- Enchant Bracer - Exceptional Spirit
			[74238]	= 300,	-- Enchant Boots - Mastery
			[74239]	= 300,	-- Enchant Bracer - Greater Expertise
			[74240]	= 300,	-- Enchant Cloak - Greater Intellect
			[74242]	= 300,	-- Enchant Weapon - Power Torrent
			[74244]	= 300,	-- Enchant Weapon - Windwalk
			[74246]	= 300,	-- Enchant Weapon - Landslide
			[74247]	= 300,	-- Enchant Cloak - Greater Critical Strike
			[74248]	= 300,	-- Enchant Bracer - Greater Critical Strike
			[74250]	= 300,	-- Enchant Chest - Peerless Stats
			[74251]	= 300,	-- Enchant Chest - Greater Stamina
			[74252]	= 300,	-- Enchant Boots - Assassin's Step
			[74253]	= 300,	-- Enchant Boots - Lavawalker
			[74254]	= 300,	-- Enchant Gloves - Mighty Strength
			[74255]	= 300,	-- Enchant Gloves - Greater Mastery
			[74256]	= 300,	-- Enchant Bracer - Greater Speed
			[95471]	= 300,	-- Enchant 2H Weapon - Mighty Agility
			[96261] = 300,  -- Enchant Bracer - Major Strength
			[96262] = 300,  -- Enchant Bracer - Mighty Intellect
			[96264] = 300,  -- Enchant Bracer - Agility
		}
	end
	return ENCHANT_LEVELS
end
