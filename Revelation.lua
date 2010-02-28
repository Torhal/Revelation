-------------------------------------------------------------------------------
-- Localized globals
-------------------------------------------------------------------------------
local _G = getfenv(0)

local string = _G.string
local table = _G.table

local pairs, ipairs = _G.pairs, _G.ipairs
local wipe = _G.wipe

local max = _G.max
local tonumber = _G.tonumber
local select = _G.select

-------------------------------------------------------------------------------
-- Localized Blizzard API
-------------------------------------------------------------------------------
local CastSpellByName = _G.CastSpellByName
local CloseTradeSkill, DoTradeSkill = _G.CloseTradeSkill, _G.DoTradeSkill
local GameTooltip, GetSpellInfo = _G.GameTooltip, _G.GetSpellInfo
local GetContainerItemLink = _G.GetContainerItemLink
local GetInventoryItemLink = _G.GetInventoryItemLink
local GetItemInfo = _G.GetItemInfo
local GetMouseFocus = _G.GetMouseFocus
local GetNumTradeSkills = _G.GetNumTradeSkills
local GetSpellName = _G.GetSpellName
local GetTradeSkillIcon = _G.GetTradeSkillIcon
local GetTradeSkillInfo = _G.GetTradeSkillInfo
local GetTradeSkillItemLink = _G.GetTradeSkillItemLink
local GetTradeSkillNumReagents = _G.GetTradeSkillNumReagents
local GetTradeSkillReagentInfo = _G.GetTradeSkillReagentInfo
local GetTradeSkillRecipeLink = _G.GetTradeSkillRecipeLink
local BOOKTYPE_SPELL = _G.BOOKTYPE_SPELL
local LibStub = _G.LibStub

-------------------------------------------------------------------------------
-- AddOn namespace
-------------------------------------------------------------------------------
local ADDON_NAME = "Revelation"
local Revelation = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceHook-3.0")

local dev = false
--@debug@
dev = true
--@end-debug@
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME, "enUS", true, dev)

local debugger	= _G.tekDebug and _G.tekDebug:GetFrame(ADDON_NAME)

local highlight = CreateFrame("Frame", nil, UIParent)
highlight:SetFrameStrata("TOOLTIP")
highlight:Hide()

highlight._texture = highlight:CreateTexture(nil, "OVERLAY")
highlight._texture:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
highlight._texture:SetBlendMode("ADD")
highlight._texture:SetAllPoints(highlight)

local dis_frame = CreateFrame("Button", "RevelationDisenchantFrame", UIParent, "SecureActionButtonTemplate")
dis_frame:SetAttribute("type", "macro")
dis_frame:SetScript("OnEnter", function(self, motion)
				       highlight:SetParent(self)
				       highlight:SetAllPoints(self)
				       highlight:Show()
			       end)
dis_frame:SetScript("OnLeave", function()
				       highlight:Hide()
				       highlight:ClearAllPoints()
				       highlight:SetParent(nil)
			       end)
dis_frame:Hide()

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------
local EquipSlot = {
	["INVTYPE_CHEST"]		= L["Chest"],
	["INVTYPE_ROBE"]		= L["Chest"],
	["INVTYPE_FEET"]		= L["Boots"],
	["INVTYPE_WRIST"]		= L["Bracer"],
	["INVTYPE_HAND"]		= L["Gloves"],
	["INVTYPE_FINGER"]		= L["Ring"],
	["INVTYPE_CLOAK"]		= L["Cloak"],
	["INVTYPE_WEAPON"]		= L["Weapon"],
	["INVTYPE_SHIELD"]		= L["Shield"],
	["INVTYPE_2HWEAPON"]		= L["2H Weapon"],
	["INVTYPE_WEAPONMAINHAND"]	= L["Weapon"],
	["INVTYPE_WEAPONOFFHAND"]	= L["Weapon"]
}
local PROF_ENCHANTING		= GetSpellInfo(7411)
local PROF_INSCRIPTION		= GetSpellInfo(45357)
local PROF_JEWELCRAFTING	= GetSpellInfo(25229)
local PROF_RUNEFORGING		= GetSpellInfo(53428)

local SPELL_DISENCHANT, _, DISENCHANT_ICON	= GetSpellInfo(13262)
local SPELL_PROSPECTING, _, PROSPECTING_ICON	= GetSpellInfo(31252)

local known_professions = {
	[GetSpellInfo(2259)]	= false, -- Alchemy
	[GetSpellInfo(2018)]	= false, -- Blacksmithing
	[GetSpellInfo(2550)]	= false, -- Cooking
	[PROF_ENCHANTING]	= false, -- Enchanting
	[GetSpellInfo(4036)]	= false, -- Engineering
	[GetSpellInfo(746)]	= false, -- First Aid
	[GetSpellInfo(2108)]	= false, -- Leatherworking
	[GetSpellInfo(61422)]	= false, -- Smelting
	[GetSpellInfo(3908)]	= false, -- Tailoring
	[PROF_JEWELCRAFTING]	= false, -- Jewelcrafting
	[PROF_INSCRIPTION]	= false, -- Inscription
	[PROF_RUNEFORGING]	= false, -- Runeforging
}

local defaults = {
	profile = {
		modifier = 1,	-- ALT
		modifier2 = 4,	-- NONE
		button = 1	-- LeftButton
	}
}

-------------------------------------------------------------------------------
-- Variables
-------------------------------------------------------------------------------
local recipes = {}
local scan_item = {}
local table_heap = {}
local active_tables = {}
local db
local DropDown

-- The bag_id and slot_id variables are used with Enchanting and Runeforging.
local bag_id
local slot_id

-------------------------------------------------------------------------------
-- Local functions
-------------------------------------------------------------------------------
local function Debug(...)
	if debugger then
		debugger:AddMessage(string.join(", ", ...))
	end
end

local function AcquireTable()
	local tbl = table.remove(table_heap) or {}

	active_tables[#active_tables + 1] = tbl
	return tbl
end

local ModifiersPressed
do
	local ModifierKey = {
		[1] = IsAltKeyDown,
		[2] = IsControlKeyDown,
		[3] = IsShiftKeyDown,
		[4] = IsRightAltKeyDown,
		[5] = IsLeftAltKeyDown,
		[6] = IsRightControlKeyDown,
		[7] = IsLeftControlKeyDown,
		[8] = IsRightShiftKeyDown,
		[9] = IsLeftShiftKeyDown,
	}
	function ModifiersPressed()
		local mod, mod2 = db.modifier, db.modifier2
		local retval = (mod == 10) or ModifierKey[mod]()
		local retval2 = (mod2 == 10) or ModifierKey[mod2]()
		return retval and retval2
	end
end

local OnCraftItems
local AddRecipe
do
	local function CraftItem(self, data)
		local prof, skill_idx, amount = string.split(":", data)

		CastSpellByName(prof)
		CloseTradeSkill()

		if (prof == PROF_ENCHANTING or prof == PROF_RUNEFORGING) and scan_item.type ~= L["Trade Goods"] then
			DoTradeSkill(skill_idx, 1)

			if bag_id and slot_id then
				UseContainerItem(bag_id, slot_id)
			elseif slot_id then
				UseInventoryItem(slot_id)
			end
		else
			DoTradeSkill(skill_idx, amount)
		end
		CloseDropDownMenus()
	end
	local craft_data

	function OnCraftItems(self)
		local parent = self:GetParent()
		local amount = tonumber(_G[parent:GetName().."EditBox"]:GetText())

		_G[parent:GetName().."EditBox"]:SetText("")

		if amount == "nil" then
			amount = nil
		end
		local prof, skill_idx, max = string.split(":", craft_data)

		if not amount or amount < 1 or amount > tonumber(max) then
			return
		end
		CraftItem(self, string.format("%s:%d:%d", prof, skill_idx, amount))
		parent:Hide()
	end

	local function CraftItem_Popup(self, data)
		local _, _, max = string.split(":", data)

		craft_data = data
		StaticPopupDialogs["Revelation_CraftItems"].text = "1 - "..max
		StaticPopup_Show("Revelation_CraftItems")
		CloseDropDownMenus()
	end
	local icon_cache = {}

	function AddRecipe(prof, skill_name, skill_idx, num_avail)
		local has_arrow = false
		local sub_menu
		local normal_name = skill_name.normal

		if prof ~= PROF_ENCHANTING and num_avail > 1 then
			has_arrow = true
			sub_menu = AcquireTable()

			local craft_args = string.format("%s:%d:%d", prof, skill_idx, num_avail)
			local entry = AcquireTable()
			entry.text = _G.ALL
			entry.func = CraftItem
			entry.arg1 = craft_args
			entry.tooltipTitle = "RevelationTooltip"
			entry.tooltipText = L["Create every"].." "..normal_name.." "..L["you have reagents for."]
			entry.notCheckable = true
			table.insert(sub_menu, entry)

			local entry2 = AcquireTable()
			entry2.text = " 1 - "..num_avail
			entry2.func = CraftItem_Popup
			entry2.arg1 = craft_args
			entry2.tooltipTitle = "RevelationTooltip"
			entry2.tooltipText = L["Create"].." 1 - "..num_avail.." "..normal_name.."."
			entry2.notCheckable = true
			table.insert(sub_menu, entry2)
		end
		local recipe_link = GetTradeSkillRecipeLink(skill_idx)

		if not icon_cache[normal_name] then
			icon_cache[normal_name] = select(10, GetItemInfo(recipe_link)) or GetTradeSkillIcon(skill_idx)
		end

		local new_recipe = AcquireTable()
		new_recipe.name = normal_name
		new_recipe.text = "|T"..icon_cache[normal_name]..":24:24|t".."  "..skill_name.color.." ("..num_avail..")"
		new_recipe.func = CraftItem
		new_recipe.arg1 = string.format("%s:%d:1", prof, skill_idx)
		new_recipe.hasArrow = has_arrow
		new_recipe.tooltipTitle = "RevelationItemLink"
		new_recipe.tooltipText = recipe_link
		new_recipe.notCheckable = true
		new_recipe.subMenu = sub_menu
		table.insert(recipes, new_recipe)
	end
end

local IterTrade
do
	local function IsReagent(item_name, recipe)
		local num = GetTradeSkillNumReagents(recipe)

		for reagent = 1, num do
			if item_name == GetTradeSkillReagentInfo(recipe, reagent) then
				return true
			end
		end
		return false
	end

	-- The level parameter only exists to make this interchangeable with IterEnchant()
	function IterTrade(prof, skill_idx, item, skill_name, num_avail, level, single)
		local rune_forge = (item.type == L["Weapon"]) and (prof == PROF_RUNEFORGING)

		if not rune_forge then
			local is_reagent = IsReagent(item.name, skill_idx)

			if num_avail < 1 or not is_reagent then
				return
			end
		end
		AddRecipe(prof, skill_name, skill_idx, single and 1 or num_avail)
	end
end

local IterEnchant
do
	local ArmorEnch = {
		L["Chest"], L["Boots"], L["Bracer"], L["Gloves"], L["Ring"], L["Cloak"], L["Shield"]
	}

	local WeaponEnch = {
		L["Staff"], _G.ENCHSLOT_2HWEAPON, _G.ENCHSLOT_WEAPON
	}

	local EnchantLevel
	function IterEnchant(prof, skill_idx, item, skill_name, num_avail, level, single)
		if num_avail < 1 then
			return
		end

		local eqref = item.eqloc and EquipSlot[item.eqloc] or nil
		local found = false
		local normal_name = skill_name.normal

		if not eqref then
			if string.find(item.name, L["Armor Vellum"]) then
				for k, v in pairs(ArmorEnch) do
					if string.find(normal_name, v) then
						found = true
						break
					end
				end
			elseif string.find(item.name, L["Weapon Vellum"]) then
				for k, v in pairs(WeaponEnch) do
					if string.find(normal_name, v) then
						found = true
						break
					end
				end
			end
		elseif item.eqloc == "INVTYPE_WEAPON" or item.eqloc == "INVTYPE_WEAPONMAINHAND" or item.eqloc == "INVTYPE_WEAPONOFFHAND" then
			if (not string.find(normal_name, EquipSlot["INVTYPE_2HWEAPON"])) and string.find(normal_name, eqref) then
				found = true
			end
		elseif item.eqloc == "INVTYPE_2HWEAPON" then
			if string.find(normal_name, eqref) or string.find(normal_name, EquipSlot["INVTYPE_WEAPON"]) or (item.stype == L["Staves"] and string.find(normal_name, L["Staff"])) then
				found = true
			end
		elseif string.find(normal_name, eqref) then
			found = true
		end

		if not found then
			return
		end

		if not EnchantLevel then
			EnchantLevel = {
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
			}
		end
		local _, _, ench_str = string.find(GetTradeSkillRecipeLink(skill_idx), "^|%x+|H(.+)|h%[.+%]")
		local _, ench_num = string.split(":", ench_str)
		local ench_level = EnchantLevel[tonumber(ench_num)]

		if ench_level and ench_level > level then
			return
		end
		AddRecipe(prof, skill_name, skill_idx, 1)
	end
end

local Scan
do
	local DIFFICULTY_COLORS = {
		["trivial"]	= "|cff808080",
		["easy"]	= "|cff40bf40",
		["medium"]	= "|cffffff00",
		["optimal"]	= "|cffff8040",
	}
	local DISENCHANT_LINK = GetSpellLink(13262)

	local CANNOT_DE = {
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
		[29378] = true,	-- Starheart Baton
		[31336] = true,	-- Blade of Wizardry
		[32540] = true,	-- Terokk's Might
		[32541] = true,	-- Terokk's Wisdom
		[32660] = true,	-- Crystalforged Sword
		[32662] = true,	-- Flaming Quartz Staff
	}

	local function CanDisenchant()
		local id = select(3, scan_item.link:find("item:(%d+):"))

		if not id or (id and CANNOT_DE[tonumber(id)]) then
			return false
		end
		local type = scan_item.type
		local quality = scan_item.quality

		if (type == _G.ARMOR or type == _G.ENCHSLOT_WEAPON) and quality > 1 and quality < 5 then
			return true
		end
		return false
	end
	local PROSPECTING_LINK = GetSpellLink(31252)

	local CAN_PROSPECT = {
		[2770]	= true,	-- Copper Ore
		[2771]	= true,	-- Tin Ore
		[2772]	= true,	-- Iron Ore
		[3858]	= true,	-- Mithril Ore
		[10620]	= true,	-- Thorium Ore
		[23452]	= true,	-- Adamantite Ore
		[23424]	= true,	-- Fel Iron Ore
		[36909]	= true,	-- Cobalt Ore
		[36910]	= true,	-- Titanium Ore
		[36912]	= true,	-- Saronite Ore
	}

	local function CanProspect()
		local id = select(3, scan_item.link:find("item:(%d+):"))

		if not id or (id and not CAN_PROSPECT[tonumber(id)]) then
			return false
		end
		return true
	end

	local name_pair = {}
	local func
	local ATSW_SkipSlowScan = _G.ATSW_SkipSlowScan

	function Scan(prof, item, level, single)
		CastSpellByName(prof)

		if ATSW_SkipSlowScan then
			ATSW_SkipSlowScan()
		end
		func = IterTrade

		if prof == PROF_ENCHANTING then
			if (EquipSlot[item.eqloc]
			    or (string.find(item.name, L["Armor Vellum"])
				or string.find(item.name, L["Weapon Vellum"]))) then
				func = IterEnchant
			end
		end

		-- Expand all headers for an accurate reading.
		for i = GetNumTradeSkills(), 1, -1 do
			local _, skill_type = GetTradeSkillInfo(i)

			if skill_type == "header" then
				ExpandTradeSkillSubClass(i)
			end
		end

		for idx = 1, GetNumTradeSkills() do
			local skill_name, skill_type, num_avail, _, _ = GetTradeSkillInfo(idx)

			if skill_name and skill_type ~= "header" then
				name_pair.normal = skill_name
				name_pair.color = DIFFICULTY_COLORS[skill_type]..skill_name.."|r"
				func(prof, idx, item, name_pair, num_avail, level, single)
			end
		end
		CloseTradeSkill()

		if prof == PROF_ENCHANTING and CanDisenchant() then
			local entry = AcquireTable()

			entry.name = SPELL_DISENCHANT
			entry.text = "|T"..DISENCHANT_ICON..":24:24|t".." "..SPELL_DISENCHANT
			entry.hasArrow = false
			entry.tooltipTitle = "RevelationItemLink"
			entry.tooltipText = DISENCHANT_LINK
			entry.notCheckable = true
			table.insert(recipes, entry)
		elseif prof == PROF_JEWELCRAFTING and CanProspect() then
			local entry = AcquireTable()

			entry.name = SPELL_PROSPECTING
			entry.text = "|T"..PROSPECTING_ICON..":24:24|t".." "..SPELL_PROSPECTING
			entry.hasArrow = false
			entry.tooltipTitle = "RevelationItemLink"
			entry.tooltipText = PROSPECTING_LINK
			entry.notCheckable = true
			table.insert(recipes, entry)
		end
	end
end	-- do

-------------------------------------------------------------------------------
-- Main AddOn functions
-------------------------------------------------------------------------------
do
	local options_frame = _G.InterfaceOptionsFrame

	function Revelation:OnInitialize()
		local LDBinfo = {
			type = "launcher",
			icon = "Interface\\Icons\\Spell_Fire_SealOfFire",
			label = ADDON_NAME,
			OnClick = function(button)
					  if options_frame:IsVisible() then
						  options_frame:Hide()
					  else
						  _G.InterfaceOptionsFrame_OpenToCategory(Revelation.optionsFrame)
					  end
				  end
		}
		self.DataObj = LibStub("LibDataBroker-1.1"):NewDataObject(ADDON_NAME, LDBinfo)
		self.db = LibStub("AceDB-3.0"):New(ADDON_NAME.."Config", defaults)
		self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
		self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
		self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
		db = self.db.profile

		self:SetupOptions()
	end
end	-- do

local function NameSort(one, two)
	return one.name < two.name
end

function Revelation:OnEnable()
	-------------------------------------------------------------------------------
	-- Create the dropdown frame, and set its state.
	-------------------------------------------------------------------------------
	DropDown = CreateFrame("Frame", "Revelation_DropDown")
	DropDown.displayMode = "MENU"
	DropDown.point = "TOPLEFT"
	DropDown.relativePoint = "TOPRIGHT"
	DropDown.levelAdjust = 0
	DropDown.initialize =
		function(self, level)
			if not level then
				return
			end
			local info

			if level == 1 then
				local list_frame = _G["DropDownList1"]
				local list_name = list_frame:GetName()
				local count = 1

				table.sort(recipes, NameSort)

				for k, v in ipairs(recipes) do
					info = v
					info.value = k
					UIDropDownMenu_AddButton(info, level)

					if v.name == SPELL_DISENCHANT then
						local button = _G[list_name.."Button"..count]

						dis_frame:SetParent(button)
						dis_frame:SetPoint("TOPLEFT", button, "TOPLEFT")
						dis_frame:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT")
						dis_frame:SetAttribute("macrotext", string.format("/cast %s\n/use %s %s", SPELL_DISENCHANT, bag_id, slot_id))
						dis_frame:Show()
					elseif v.name == SPELL_PROSPECTING then
						local button = _G[list_name.."Button"..count]

						dis_frame:SetParent(button)
						dis_frame:SetPoint("TOPLEFT", button, "TOPLEFT")
						dis_frame:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT")
						dis_frame:SetAttribute("macrotext", string.format("/cast %s\n/use %s %s", SPELL_PROSPECTING, bag_id, slot_id))
						dis_frame:Show()
					end
					count = count + 1
				end
			elseif level == 2 then
				local sub_menu = recipes[UIDROPDOWNMENU_MENU_VALUE].subMenu

				if sub_menu then
					for key, val in ipairs(sub_menu) do
						info = val
						UIDropDownMenu_AddButton(info, level)
					end
				end
			end
		end

	-----------------------------------------------------------------------
	-- Static popup initialization
	-----------------------------------------------------------------------
	StaticPopupDialogs["Revelation_CraftItems"] = {
		button1 = OKAY,
		button2 = CANCEL,
		OnAccept = OnCraftItems,
		EditBoxOnEnterPressed = OnCraftItems,
		EditBoxOnEscapePressed = function(self)
						 self:GetParent():Hide()
					 end,
		timeout = 0,
		hideOnEscape = 1,
		exclusive = 1,
		whileDead = 1,
		hasEditBox = 1
	}

	-------------------------------------------------------------------------------
	-- Create our hooks.
	-------------------------------------------------------------------------------
	self:RawHook("PaperDollItemSlotButton_OnModifiedClick", true)
	self:RawHook("ContainerFrameItemButton_OnModifiedClick", true)
	self:RawHook("HandleModifiedItemClick", true)
end

function Revelation:OnDisable()
	self:UnhookAll()
end

function Revelation:OnProfileChanged(event, database, newProfileKey)
	db = database.profile
end

do
	local EMPTY_RECIPE = {
		text = L["Either no recipe or no reagents were found."],
		func = function() CloseDropDownMenus() end,
		hasArrow = false,
		notCheckable = true
	}

	function Revelation:CreateMenu(anchor, item_link)
		if not item_link then
			return
		end

		if not anchor then
			if not ModifiersPressed() then	-- Enforce for HandleModifiedItemClick
				return
			end
			anchor = GetMouseFocus()
		end

		for i = 1, #active_tables do	-- Release the tables for re-use.
			wipe(active_tables[i])
			table.insert(table_heap, active_tables[i])
			active_tables[i] = nil
		end
		wipe(recipes)

		-- Reset the table, they may have unlearnt a profession - I robbed Ackis!
		for i in pairs(known_professions) do
			known_professions[i] = false
		end

		-- Grab names from the spell book
		for index = 1, 25, 1 do
			local spell_name = GetSpellName(index, BOOKTYPE_SPELL)

			if not spell_name or (index == 25) then
				break
			end

			if known_professions[spell_name] == false then
				known_professions[spell_name] = true
			end
		end

		local item_name, item_link, item_quality, item_level, item_minlevel, item_type, item_stype, _, item_eqloc, _ = GetItemInfo(item_link)

		scan_item.name = item_name
		scan_item.link = item_link
		scan_item.quality = item_quality
		scan_item.level = item_level
		scan_item.minlevel = item_minlevel
		scan_item.type = item_type
		scan_item.stype = item_stype
		scan_item.eqloc = item_eqloc

		Debug("Item type", item_type, "Item subtype", item_stype)

		if item_type == _G.ARMOR or string.find(item_type, L["Weapon"]) then
			if known_professions[PROF_ENCHANTING] then
				Scan(PROF_ENCHANTING, scan_item, item_level, true)
			end

			if known_professions[PROF_INSCRIPTION] then
				Scan(PROF_INSCRIPTION, scan_item, item_level, true)
			end

			if known_professions[PROF_RUNEFORGING] then
				Scan(PROF_RUNEFORGING, scan_item, item_level, true)
			end
		elseif item_type == L["Trade Goods"] and (item_stype == L["Armor Enchantment"] or item_stype == L["Weapon Enchantment"]) then
			if known_professions[PROF_ENCHANTING] then
				Scan(PROF_ENCHANTING, scan_item, max(1, item_level - 5), true)	-- Vellum item levels are 5 higher than the enchant which can be put on them.
			end
		else
			for prof, known in pairs(known_professions) do
				if known then
					Scan(prof, scan_item, 1, false)
				end
			end
		end

		if #recipes == 0 then
			table.insert(recipes, EMPTY_RECIPE)
		end
		ToggleDropDownMenu(1, nil, DropDown, anchor, 0, 0)
	end
end

-------------------------------------------------------------------------------
-- Hooked functions
-------------------------------------------------------------------------------
do
	local MouseButton = {
		[1] = "LeftButton",
		[2] = "RightButton",
	}
	local click_handled = false		-- For HandleModifiedItemClick kludge...

	function Revelation:PaperDollItemSlotButton_OnModifiedClick(...)
		local hooked_self, button = ...

		click_handled = true
		bag_id = nil
		slot_id = nil

		if ModifiersPressed() and button == MouseButton[db.button] then
			slot_id = hooked_self:GetID()
			self:CreateMenu(hooked_self, GetInventoryItemLink("player", slot_id))
		else
			self.hooks.PaperDollItemSlotButton_OnModifiedClick(...)
		end
		click_handled = false
	end

	function Revelation:ContainerFrameItemButton_OnModifiedClick(...)
		local hooked_self, button = ...

		click_handled = true
		bag_id = nil
		slot_id = nil

		if ModifiersPressed() and button == MouseButton[db.button] then
			bag_id = hooked_self:GetParent():GetID()
			slot_id = hooked_self:GetID()
			self:CreateMenu(hooked_self, GetContainerItemLink(bag_id, slot_id))
		end
		self.hooks.ContainerFrameItemButton_OnModifiedClick(...)
		click_handled = false
	end

	-- This hook is required as it is the only way to reference TradeRecipientItem7ItemButton
	-- A.K.A.: "Will not be traded"
	function Revelation:HandleModifiedItemClick(...)
		if not click_handled then
			self:CreateMenu(nil, ...)
		end
		return self.hooks.HandleModifiedItemClick(...)
	end
end
_G["TradeRecipientItem7ItemButton"]:RegisterForClicks("AnyUp")

-- Voodoo for UIDropDownMenu tooltips - thanks to Xinhuan for pointing out that not everything must be complex.
hooksecurefunc("GameTooltip_AddNewbieTip",
	       function(frame, normalText, r, g, b, newbieText, noNormalText)
		       if normalText == "RevelationTooltip" then
			       GameTooltip_SetDefaultAnchor(GameTooltip, frame)
			       GameTooltip:AddLine(newbieText)
			       GameTooltip:Show()
		       elseif normalText == "RevelationItemLink" then
			       GameTooltip_SetDefaultAnchor(GameTooltip, frame)
			       GameTooltip:SetHyperlink(newbieText)
		       end
	       end)

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------
local options, GetOptions
do
	local ModifierName = {
		[1]	= _G.ALT_KEY,
		[2]	= _G.CTRL_KEY,
		[3]	= _G.SHIFT_KEY,
		[4]	= _G.RALT_KEY_TEXT,
		[5]	= _G.LALT_KEY_TEXT,
		[6]	= _G.RCTRL_KEY_TEXT,
		[7]	= _G.LCTRL_KEY_TEXT,
		[8]	= _G.RSHIFT_KEY_TEXT,
		[9]	= _G.LSHIFT_KEY_TEXT,
		[10]	= _G.NONE_KEY
	}

	local ButtonName = {
		[1] = _G.KEY_BUTTON1,	-- Left Mouse Button
		[2] = _G.KEY_BUTTON2	-- Right Mouse Button
	}
	function GetOptions()
		if not options then
			options = {
				type = "group",
				name = ADDON_NAME,
				args = {
					modifier = {
						order = 1,
						type = "select",
						name = _G.KEY1,
						desc = L["Select the key to press when mouse-clicking for menu display."],
						get = function() return db.modifier end,
						set = function(info, value) db.modifier = value end,
						values = ModifierName
					},
					modifier2 = {
						order = 2,
						type = "select",
						name = _G.KEY2,
						desc = L["Select the second key to press when mouse-clicking for menu display."],
						get = function() return db.modifier2 end,
						set = function(info, value) db.modifier2 = value end,
						values = ModifierName
					},
					button = {
						order = 3,
						type = "select",
						name = _G.MOUSE_LABEL,
						desc = L["Select the mouse button to click for menu display."],
						get = function() return db.button end,
						set = function(info, value) db.button = value end,
						values = ButtonName
					}
				}
			}
		end
		return options
	end
end

function Revelation:SetupOptions()
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(ADDON_NAME, GetOptions())
	LibStub("AceConfig-3.0"):RegisterOptionsTable(ADDON_NAME, GetOptions())
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(ADDON_NAME)
end
