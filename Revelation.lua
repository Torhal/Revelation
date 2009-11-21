-------------------------------------------------------------------------------
-- Localized globals
-------------------------------------------------------------------------------
local _G = getfenv(0)

local string = _G.string
local table = _G.table

local strfind, strsub, strsplit = string.find, string.sub, string.split

local pairs, ipairs = _G.pairs, _G.ipairs
local tinsert, tremove = table.insert, table.remove
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
local NAME = "Revelation"
local Revelation = LibStub("AceAddon-3.0"):NewAddon(NAME, "AceHook-3.0")

local dev = false
--@debug@
dev = true
--@end-debug@
local L = LibStub("AceLocale-3.0"):GetLocale(NAME, "enUS", true, dev)

local DropDown

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
local PROF_ENCHANTING = GetSpellInfo(7411)
local PROF_INSCRIPTION = GetSpellInfo(45357)
local PROF_RUNEFORGING = GetSpellInfo(53428)

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
	[GetSpellInfo(25229)]	= false, -- Jewelcrafting
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
local table_heap = {}
local active_tables = {}
local db

-------------------------------------------------------------------------------
-- Local functions
-------------------------------------------------------------------------------
local function printf(text, ...)
	return print(string.format(text, ...))
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
	local function AcquireTable()
		local tbl = tremove(table_heap) or {}
		active_tables[#active_tables + 1] = tbl
		return tbl
	end

	local function CraftItem(self, data)
		local prof, skill_idx, amount = string.split(":", data)

		CastSpellByName(prof)
		CloseTradeSkill()
		DoTradeSkill(skill_idx, amount)
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
			tinsert(sub_menu, entry)

			local entry2 = AcquireTable()
			entry2.text = " 1 - "..num_avail
			entry2.func = CraftItem_Popup
			entry2.arg1 = craft_args
			entry2.tooltipTitle = "RevelationTooltip"
			entry2.tooltipText = L["Create"].." 1 - "..num_avail.." "..normal_name.."."
			entry2.notCheckable = true
			tinsert(sub_menu, entry2)
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
		tinsert(recipes, new_recipe)
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

	function IterTrade(prof, skill_idx, item, skill_name, num_avail, level, single)
		if num_avail < 1 or not IsReagent(item.name, skill_idx) then
			return
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
		L["Staff"], L["2H Weapon"], L["Weapon"]
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
			if strfind(item.name, L["Armor Vellum"]) then
				for k, v in pairs(ArmorEnch) do
					if strfind(normal_name, v) then
						found = true
						break
					end
				end
			elseif strfind(item.name, L["Weapon Vellum"]) then
				for k, v in pairs(WeaponEnch) do
					if strfind(normal_name, v) then
						found = true
						break
					end
				end
			end
		elseif item.eqloc == "INVTYPE_WEAPON" or item.eqloc == "INVTYPE_WEAPONMAINHAND" or item.eqloc == "INVTYPE_WEAPONOFFHAND" then
			if (not strfind(normal_name, EquipSlot["INVTYPE_2HWEAPON"])) and strfind(normal_name, eqref) then
				found = true
			end
		elseif item.eqloc == "INVTYPE_2HWEAPON" then
			if strfind(normal_name, eqref) or strfind(normal_name, EquipSlot["INVTYPE_WEAPON"]) or (item.stype == L["Staves"] and strfind(normal_name, L["Staff"])) then
				found = true
			end
		elseif strfind(normal_name, eqref) then
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
		local _, _, ench_str = strfind(GetTradeSkillRecipeLink(skill_idx), "^|%x+|H(.+)|h%[.+%]")
		local _, ench_num = strsplit(":", ench_str)
		local ench_level = EnchantLevel[tonumber(ench_num)]

		if ench_level and ench_level > level then
			return
		end
		--	print(ench_str.." - "..normal_name)
		AddRecipe(prof, skill_name, skill_idx, 1)
	end
end

local Scan
do
	local DIFFICULTY = {
		["trivial"]	= "|cff808080",
		["easy"]	= "|cff40bf40",
		["medium"]	= "|cffffff00",
		["optimal"]	= "|cffff8040",
	}
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
			    or (strfind(item.name, L["Armor Vellum"])
				or strfind(item.name, L["Weapon Vellum"]))) then
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
				name_pair.color = DIFFICULTY[skill_type]..skill_name.."|r"
				func(prof, idx, item, name_pair, num_avail, level, single)
			end
		end
		CloseTradeSkill()
	end
end	-- do

-------------------------------------------------------------------------------
-- Main AddOn functions
-------------------------------------------------------------------------------
do
	local options_frame = InterfaceOptionsFrame

	function Revelation:OnInitialize()
		local LDBinfo = {
			type = "launcher",
			icon = "Interface\\Icons\\Spell_Fire_SealOfFire",
			label = NAME,
			OnClick = function(button)
					  if options_frame:IsVisible() then
						  options_frame:Hide()
					  else
						  InterfaceOptionsFrame_OpenToCategory(Revelation.optionsFrame)
					  end
				  end
		}
		self.DataObj = LibStub("LibDataBroker-1.1"):NewDataObject(NAME, LDBinfo)
		self.db = LibStub("AceDB-3.0"):New(NAME.."Config", defaults)
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
				table.sort(recipes, NameSort)

				for k, v in ipairs(recipes) do
					info = v
					info.value = k
					UIDropDownMenu_AddButton(info, level)
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
	local scan_item = {}

	function Revelation:Menu(anchor, item_link)
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
			tinsert(table_heap, active_tables[i])
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

		local item_name, _, _, item_level, _, item_type, item_stype, _, item_eqloc, _ = GetItemInfo(item_link)

		scan_item.name = item_name
		scan_item.level = item_level
		scan_item.type = item_type
		scan_item.stype = item_stype
		scan_item.eqloc = item_eqloc

		if item_type == L["Armor"] or strfind(item_type, L["Weapon"]) then
			if known_professions[PROF_ENCHANTING] == true then
				Scan(PROF_ENCHANTING, scan_item, item_level, true)
			end

			if known_professions[PROF_INSCRIPTION] == true then
				Scan(PROF_INSCRIPTION, scan_item, item_level, true)
			end

			if known_professions[PROF_RUNEFORGING] == true then
				Scan(PROF_RUNEFORGING, scan_item, item_level, true)
			end
		elseif item_type == L["Trade Goods"] and (item_stype == L["Armor Enchantment"] or item_stype == L["Weapon Enchantment"]) then
			if known_professions[PROF_ENCHANTING] == true then
				Scan(PROF_ENCHANTING, scan_item, max(1, item_level - 5), true)	-- Vellum item levels are 5 higher than the enchant which can be put on them.
			end
		else
			for prof, known in pairs(known_professions) do
				if known == true then
					Scan(prof, scan_item, 1, false)
				end
			end
		end

		if #recipes == 0 then
			tinsert(recipes, EMPTY_RECIPE)
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
		local hookSelf, button = ...

		click_handled = true

		if ModifiersPressed() and button == MouseButton[db.button] then
			self:Menu(hookSelf, GetInventoryItemLink("player", hookSelf:GetID()))
		else
			self.hooks.PaperDollItemSlotButton_OnModifiedClick(...)
		end
		click_handled = false
	end

	function Revelation:ContainerFrameItemButton_OnModifiedClick(...)
		local hookSelf, button = ...

		click_handled = true

		if ModifiersPressed() and button == MouseButton[db.button] then
			self:Menu(hookSelf, GetContainerItemLink(hookSelf:GetParent():GetID(), hookSelf:GetID()))
		end
		self.hooks.ContainerFrameItemButton_OnModifiedClick(...)
		click_handled = false
	end

	-- This hook is required as it is the only way to reference TradeRecipientItem7ItemButton
	-- A.K.A.: "Will not be traded"
	function Revelation:HandleModifiedItemClick(...)
		if not click_handled then
			self:Menu(nil, ...)
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
				name = NAME,
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
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(NAME, GetOptions())
	LibStub("AceConfig-3.0"):RegisterOptionsTable(NAME, GetOptions())
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(NAME)
end
