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
local CloseTradeSkill = _G.CloseTradeSkill
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
local ADDON_NAME, common = ...
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

local secure_frame = CreateFrame("Button", "RevelationSecureFrame", UIParent, "SecureActionButtonTemplate")
secure_frame:SetAttribute("type", "macro")
secure_frame:SetScript("OnEnter", function(self, motion)
					  GameTooltip_SetDefaultAnchor(GameTooltip, self)
					  GameTooltip:SetHyperlink(self.link)

					  highlight:SetParent(self)
					  highlight:SetAllPoints(self)
					  highlight:Show()
			       end)
secure_frame:SetScript("OnLeave", function()
					  GameTooltip:Hide()
					  highlight:Hide()
					  highlight:ClearAllPoints()
					  highlight:SetParent(nil)
			       end)

secure_frame:Hide()

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------
local MY_CLASS			= select(2, UnitClass("player"))

local PROF_ENCHANTING		= GetSpellInfo(7411)
local PROF_INSCRIPTION		= GetSpellInfo(45357)
local PROF_JEWELCRAFTING	= GetSpellInfo(25229)
local PROF_RUNEFORGING		= GetSpellInfo(53428)

local SPELL_DISENCHANT		= GetSpellInfo(13262)
local SPELL_MILLING		= GetSpellInfo(51005)
local SPELL_PROSPECTING		= GetSpellInfo(31252)

local SPELL_PICK_LOCK		= GetSpellInfo(1804)
local ICON_PICK_LOCK		= select(3, GetSpellInfo(SPELL_PICK_LOCK))

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
	["INVTYPE_2HWEAPON"]		= _G.ENCHSLOT_2HWEAPON,
	["INVTYPE_WEAPONMAINHAND"]	= L["Weapon"],
	["INVTYPE_WEAPONOFFHAND"]	= L["Weapon"]
}

local DIFFICULTY_COLORS = {
	["trivial"]	= "|cff808080",
	["easy"]	= "|cff40bf40",
	["medium"]	= "|cffffff00",
	["optimal"]	= "|cffff8040",
}

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
	global = {
		modifier = 1,	-- ALT
		modifier2 = 10,	-- NONE
		button = 2	-- RightButton
	}
}

-------------------------------------------------------------------------------
-- Variables.
-------------------------------------------------------------------------------
common.cur_item = {}

local cur_item = common.cur_item
local recipes = {}
local table_heap = {}
local active_tables = {}
local db
local DropDown

-------------------------------------------------------------------------------
-- Local functions
-------------------------------------------------------------------------------
function common.Debug(...)
	if debugger then
		debugger:AddMessage(string.join(", ", ...))
	end
end
local Debug = common.Debug

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

		if (prof == PROF_ENCHANTING or prof == PROF_RUNEFORGING) and cur_item.type ~= L["Trade Goods"] then
			DoTradeSkill(skill_idx, 1)

			if common.bag_id and common.slot_id then
				UseContainerItem(common.bag_id, common.slot_id)
			elseif common.slot_id then
				UseInventoryItem(common.slot_id)
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
			entry.tooltipText = string.format(L["Create every %s you have reagents for."], normal_name)
			entry.notCheckable = true
			table.insert(sub_menu, entry)

			local entry2 = AcquireTable()
			entry2.text = string.format(" 1 - %d", num_avail)
			entry2.func = CraftItem_Popup
			entry2.arg1 = craft_args
			entry2.tooltipTitle = "RevelationTooltip"
			entry2.tooltipText = string.format(L["Create 1 - %d %s."], num_avail, normal_name)
			entry2.notCheckable = true
			table.insert(sub_menu, entry2)
		end
		local recipe_link = GetTradeSkillRecipeLink(skill_idx)

		if not icon_cache[normal_name] then
			icon_cache[normal_name] = select(10, GetItemInfo(recipe_link)) or GetTradeSkillIcon(skill_idx)
		end

		local new_recipe = AcquireTable()
		new_recipe.name = normal_name
		new_recipe.text = string.format("|T%s:24:24|t %s (%d)", icon_cache[normal_name], skill_name.color, num_avail)
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

-- The level parameter only exists to make this interchangeable with IterEnchant()
local function IterTrade(prof, skill_idx, skill_name, num_avail, level, single)
	local rune_forge = (cur_item.type == L["Weapon"]) and (prof == PROF_RUNEFORGING)

	if not rune_forge then
		local is_reagent = false

		for reagent = 1, GetTradeSkillNumReagents(skill_idx) do
			if cur_item.name == GetTradeSkillReagentInfo(skill_idx, reagent) then
				Debug("IterTrade()", cur_item.name, skill_idx, " - reagent", reagent)
				is_reagent = true
				break
			end
		end

		if num_avail < 1 or not is_reagent then
			return
		end
	end
	AddRecipe(prof, skill_name, skill_idx, single and 1 or num_avail)
end

local IterEnchant
do
	local EnchantLevels

	local ArmorEnch = {
		L["Chest"], L["Boots"], L["Bracer"], L["Gloves"], L["Ring"], L["Cloak"], L["Shield"]
	}

	local WeaponEnch = {
		L["Staff"], _G.ENCHSLOT_2HWEAPON, _G.ENCHSLOT_WEAPON
	}

	function IterEnchant(prof, skill_idx, skill_name, num_avail, level, single)
		if num_avail < 1 then
			return
		end

		local eqref = cur_item.eqloc and EquipSlot[cur_item.eqloc] or nil
		local found = false
		local normal_name = skill_name.normal

		if not eqref then
			if string.find(cur_item.name, L["Armor Vellum"]) then
				for k, v in pairs(ArmorEnch) do
					if string.find(normal_name, v) then
						found = true
						break
					end
				end
			elseif string.find(cur_item.name, L["Weapon Vellum"]) then
				for k, v in pairs(WeaponEnch) do
					if string.find(normal_name, v) then
						found = true
						break
					end
				end
			end
		elseif cur_item.eqloc == "INVTYPE_WEAPON" or cur_item.eqloc == "INVTYPE_WEAPONMAINHAND" or cur_item.eqloc == "INVTYPE_WEAPONOFFHAND" then
			if (not string.find(normal_name, EquipSlot["INVTYPE_2HWEAPON"])) and string.find(normal_name, eqref) then
				found = true
			end
		elseif cur_item.eqloc == "INVTYPE_2HWEAPON" then
			if string.find(normal_name, eqref)
			   or string.find(normal_name, EquipSlot["INVTYPE_WEAPON"])
			   or (cur_item.subtype == L["Staves"]
		               and string.find(normal_name, L["Staff"])) then
				found = true
			end
		elseif string.find(normal_name, eqref) then
			found = true
		end

		if not found then
			return
		end
		local _, _, ench_str = string.find(GetTradeSkillRecipeLink(skill_idx), "^|%x+|H(.+)|h%[.+%]")
		local _, ench_num = string.split(":", ench_str)
		local EnchantLevels = common.GetEnchantLevels()
		local ench_level = EnchantLevels[tonumber(ench_num)]

		if ench_level and ench_level > level then
			return
		end
		AddRecipe(prof, skill_name, skill_idx, 1)
	end
end

local Scan
do
	local PROF_MENU_DATA = {
		[PROF_ENCHANTING]	= {
			["name"]	= SPELL_DISENCHANT,
			["icon"]	= select(3, GetSpellInfo(SPELL_DISENCHANT)),
			["CanPerform"]	= common.CanDisenchant,
		},
		[PROF_INSCRIPTION]	= {
			["name"]	= SPELL_MILLING,
			["icon"]	= select(3, GetSpellInfo(SPELL_MILLING)),
			["CanPerform"]	= common.CanMill,
		},
		[PROF_JEWELCRAFTING]	= {
			["name"]	= SPELL_PROSPECTING,
			["icon"]	= select(3, GetSpellInfo(SPELL_PROSPECTING)),
			["CanPerform"]	= common.CanProspect,
		},
	}

	local name_pair = {}
	local ATSW_SkipSlowScan = _G.ATSW_SkipSlowScan
	local func

	function Scan(prof, level, single)
		CastSpellByName(prof)

		if ATSW_SkipSlowScan then
			ATSW_SkipSlowScan()
		end

		if prof == PROF_ENCHANTING then
			if (EquipSlot[cur_item.eqloc]
			    or (string.find(cur_item.name, L["Armor Vellum"])
				or string.find(cur_item.name, L["Weapon Vellum"]))) then
				func = IterEnchant
			end
		else
			func = IterTrade
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
				func(prof, idx, name_pair, num_avail, level, single)
				Debug("Scan()", prof, idx, skill_name, num_avail, level, tostring(single))
			end
		end
		CloseTradeSkill()

		local menu_data = PROF_MENU_DATA[prof]

		if menu_data and menu_data.CanPerform() then
			local entry = AcquireTable()

			entry.name = menu_data.name
			entry.text = string.format("|T%s:24:24|t %s", menu_data.icon, menu_data.name)
			entry.hasArrow = false
			entry.notCheckable = true
			table.insert(recipes, entry)
		end
	end
end	-- do

do
	local EMPTY_RECIPE = {
		text = L["Either no recipe or no reagents were found."],
		func = function()
			       CloseDropDownMenus()
		       end,
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
		local item_name, item_link, item_quality, item_level, item_minlevel, item_type, item_subtype, item_stack, item_eqloc, _ = GetItemInfo(item_link)

		cur_item.name = item_name
		cur_item.link = item_link
		cur_item.quality = item_quality
		cur_item.level = item_level
		cur_item.minlevel = item_minlevel
		cur_item.type = item_type
		cur_item.subtype = item_subtype
		cur_item.stack = item_stack
		cur_item.eqloc = item_eqloc

		Debug("Item type", item_type, "Item subtype", item_subtype)

		local sfx = tonumber(GetCVar("Sound_EnableSFX"))
		SetCVar("Sound_EnableSFX", 0)

		if item_type == _G.ARMOR or string.find(item_type, L["Weapon"]) then
			if known_professions[PROF_ENCHANTING] then
				Scan(PROF_ENCHANTING, item_level, true)
			end

			if known_professions[PROF_INSCRIPTION] then
				Scan(PROF_INSCRIPTION, item_level, true)
			end

			if known_professions[PROF_RUNEFORGING] then
				Scan(PROF_RUNEFORGING, item_level, true)
			end
		elseif item_type == L["Trade Goods"] and (item_subtype == L["Armor Enchantment"] or item_subtype == L["Weapon Enchantment"]) then
			if known_professions[PROF_ENCHANTING] then
				-- Vellum item levels are 5 higher than the enchant which can be put on them.
				Scan(PROF_ENCHANTING, max(1, item_level - 5), true)
			end
		elseif MY_CLASS == "ROGUE" and common.CanPick() then
			local entry = AcquireTable()

			entry.name = SPELL_PICK_LOCK
			entry.text = string.format("|T%s:24:24|t %s", ICON_PICK_LOCK, SPELL_PICK_LOCK)
			entry.hasArrow = false
			entry.notCheckable = true
			table.insert(recipes, entry)
		else
			for prof, known in pairs(known_professions) do
				if known then
					Scan(prof, 1, false)
				end
			end
		end

		if #recipes == 0 then
			table.insert(recipes, EMPTY_RECIPE)
		end
		ToggleDropDownMenu(1, nil, DropDown, anchor, 0, 0)
		SetCVar("Sound_EnableSFX", sfx)
	end
end

-------------------------------------------------------------------------------
-- Initialization functions.
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
		db = self.db.global

		self:SetupOptions()
		self.OnInitialize = nil
	end
end	-- do

do
	local SPECIAL_MENU_ENTRY = {
		[SPELL_DISENCHANT]	= GetSpellLink(13262),
		[SPELL_MILLING]		= GetSpellLink(51005),
		[SPELL_PROSPECTING]	= GetSpellLink(31252),
		[SPELL_PICK_LOCK]	= GetSpellLink(1804),
	}

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

						if SPECIAL_MENU_ENTRY[v.name] then
							local button = _G[list_name.."Button"..count]

							secure_frame:SetParent(button)
							secure_frame:SetPoint("TOPLEFT", button, "TOPLEFT")
							secure_frame:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT")
							secure_frame:SetAttribute("macrotext", string.format("/cast %s\n/use %s %s\n/script CloseDropDownMenus()", v.name, common.bag_id, common.slot_id))
							secure_frame.link = SPECIAL_MENU_ENTRY[v.name]
							secure_frame:Show()
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
		self:SecureHook("CloseDropDownMenus")
	end
end	-- do block

function Revelation:OnDisable()
	self:UnhookAll()
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
		common.bag_id = nil
		common.slot_id = nil

		if ModifiersPressed() and button == MouseButton[db.button] then
			common.slot_id = hooked_self:GetID()
			self:CreateMenu(hooked_self, GetInventoryItemLink("player", common.slot_id))
		else
			self.hooks.PaperDollItemSlotButton_OnModifiedClick(...)
		end
		click_handled = false
	end

	function Revelation:ContainerFrameItemButton_OnModifiedClick(...)
		local hooked_self, button = ...

		click_handled = true
		common.bag_id = nil
		common.slot_id = nil

		if ModifiersPressed() and button == MouseButton[db.button] then
			common.bag_id = hooked_self:GetParent():GetID()
			common.slot_id = hooked_self:GetID()
			self:CreateMenu(hooked_self, GetContainerItemLink(common.bag_id, common.slot_id))
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

function Revelation:CloseDropDownMenus(...)
	local parent = secure_frame:GetParent()

	if parent and not parent:IsVisible() then
		secure_frame:SetParent(nil)
		secure_frame:ClearAllPoints()
		secure_frame:Hide()
		secure_frame.link = nil
	end
end

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
