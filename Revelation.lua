-------------------------------------------------------------------------------
-- Localized Lua API
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
-- AddOn namespace
-------------------------------------------------------------------------------
local ADDON_NAME, private = ...

local LibStub = _G.LibStub
local Revelation = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceHook-3.0")

local dev = false
--@debug@
dev = true
--@end-debug@
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME, "enUS", true, dev)

local debugger = _G.tekDebug and _G.tekDebug:GetFrame(ADDON_NAME)

local highlight = _G.CreateFrame("Frame", nil, _G.UIParent)
highlight:SetFrameStrata("TOOLTIP")
highlight:Hide()

highlight._texture = highlight:CreateTexture(nil, "OVERLAY")
highlight._texture:SetTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]])
highlight._texture:SetBlendMode("ADD")
highlight._texture:SetAllPoints(highlight)

local secure_frame = _G.CreateFrame("Button", "RevelationSecureFrame", _G.UIParent, "SecureActionButtonTemplate")
secure_frame:SetAttribute("type", "macro")
secure_frame:SetScript("OnEnter", function(self, motion)
	_G.GameTooltip_SetDefaultAnchor(_G.GameTooltip, self)
	_G.GameTooltip:SetHyperlink(self.link)

	highlight:SetParent(self)
	highlight:SetAllPoints(self)
	highlight:Show()
end)
secure_frame:SetScript("OnLeave", function()
	_G.GameTooltip:Hide()
	highlight:Hide()
	highlight:ClearAllPoints()
	highlight:SetParent(nil)
end)

secure_frame:Hide()

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------
local MY_CLASS = select(2, _G.UnitClass("player"))

local PROF_ENCHANTING = _G.GetSpellInfo(7411)
local PROF_INSCRIPTION = _G.GetSpellInfo(45357)
local PROF_JEWELCRAFTING = _G.GetSpellInfo(25229)
local PROF_RUNEFORGING = _G.GetSpellInfo(53428)

local SPELL_DISENCHANT = _G.GetSpellInfo(13262)
local SPELL_MILLING = _G.GetSpellInfo(51005)
local SPELL_PROSPECTING = _G.GetSpellInfo(31252)

local SPELL_PICK_LOCK = _G.GetSpellInfo(1804)
local ICON_PICK_LOCK

local EquipSlot = {
	["INVTYPE_CHEST"] = L["Chest"],
	["INVTYPE_ROBE"] = L["Chest"],
	["INVTYPE_FEET"] = L["Boots"],
	["INVTYPE_WRIST"] = L["Bracer"],
	["INVTYPE_HAND"] = L["Gloves"],
	["INVTYPE_FINGER"] = L["Ring"],
	["INVTYPE_CLOAK"] = L["Cloak"],
	["INVTYPE_WEAPON"] = L["Weapon"],
	["INVTYPE_SHIELD"] = L["Shield"],
	["INVTYPE_2HWEAPON"] = _G.ENCHSLOT_2HWEAPON,
	["INVTYPE_WEAPONMAINHAND"] = L["Weapon"],
	["INVTYPE_WEAPONOFFHAND"] = L["Weapon"]
}

local DIFFICULTY_COLORS = {
	["trivial"] = "|cff808080",
	["easy"] = "|cff40bf40",
	["medium"] = "|cffffff00",
	["optimal"] = "|cffff8040",
}

local ENCHANTING_TRADE_GOOD = {
	[L["Enchanting"]] = true,
}

local VALID_PROFESSIONS = {
	[_G.GetSpellInfo(2259)] = true, -- Alchemy
	[_G.GetSpellInfo(2018)] = true, -- Blacksmithing
	[_G.GetSpellInfo(2550)] = true, -- Cooking
	[PROF_ENCHANTING] = true, -- Enchanting
	[_G.GetSpellInfo(4036)] = true, -- Engineering
	[_G.GetSpellInfo(746)] = true, -- First Aid
	[_G.GetSpellInfo(2108)] = true, -- Leatherworking
	[_G.GetSpellInfo(61422)] = true, -- Smelting
	[_G.GetSpellInfo(3908)] = true, -- Tailoring
	[PROF_JEWELCRAFTING] = true, -- Jewelcrafting
	[PROF_INSCRIPTION] = true, -- Inscription
	[PROF_RUNEFORGING] = true, -- Runeforging
}

-------------------------------------------------------------------------------
-- Variables.
-------------------------------------------------------------------------------
private.cur_item = {}

local cur_item = private.cur_item
local recipes = {}
local table_heap = {}
local active_tables = {}
local db
local DropDown

local known_professions = {
	["prof1"] = false,
	["prof2"] = false,
	["archaeology"] = false,
	["fishing"] = false,
	["cooking"] = false,
	["firstaid"] = false,
}

-------------------------------------------------------------------------------
-- Local functions
-------------------------------------------------------------------------------
function private.Debug(...)
	if debugger then
		debugger:AddMessage(string.join(", ", ...))
	end
end

local Debug = private.Debug

local function AcquireTable()
	local tbl = table.remove(table_heap) or {}

	active_tables[#active_tables + 1] = tbl
	return tbl
end

local ModifiersPressed
do
	local ModifierKey = {
		_G.IsAltKeyDown,
		_G.IsControlKeyDown,
		_G.IsShiftKeyDown,
		_G.IsRightAltKeyDown,
		_G.IsLeftAltKeyDown,
		_G.IsRightControlKeyDown,
		_G.IsLeftControlKeyDown,
		_G.IsRightShiftKeyDown,
		_G.IsLeftShiftKeyDown,
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
		local prof, skill_idx, amount = (":"):split(data)

		_G.CastSpellByName(prof)
		_G.CloseTradeSkill()

		_G.DoTradeSkill(skill_idx, amount or 1)
		_G.CloseDropDownMenus()

		if prof == PROF_ENCHANTING and cur_item.type == L["Trade Goods"] and (not ENCHANTING_TRADE_GOOD[cur_item.subtype]) and cur_item.subtype ~= L["Item Enchantment"] then
			return
		end

		if prof == PROF_ENCHANTING or prof == PROF_RUNEFORGING then
			if private.bag_id and private.slot_id then
				_G.UseContainerItem(private.bag_id, private.slot_id)
			elseif private.slot_id then
				_G.UseInventoryItem(private.slot_id)
			end
		end
	end

	local craft_data

	function OnCraftItems(self)
		local parent = self:GetParent()
		local edit_box = parent.editBox or self.editBox
		local amount = tonumber(edit_box:GetText())

		if amount == "" or amount == "nil" then
			amount = nil
		end
		edit_box:SetText("")

		local prof, skill_idx, max = (":"):split(craft_data)

		if not amount or amount < 1 or amount > tonumber(max) then
			return
		end
		CraftItem(self, ("%s:%d:%d"):format(prof, skill_idx, amount))
		edit_box:GetParent():Hide()
	end

	local function CraftItem_Popup(self, data)
		local _, _, max = string.split(":", data)

		craft_data = data
		_G.StaticPopupDialogs["Revelation_CraftItems"].text = "1 - " .. max
		_G.StaticPopup_Show("Revelation_CraftItems")
		_G.CloseDropDownMenus()
	end

	local icon_cache = {}

	function AddRecipe(prof, skill_name_data, skill_idx, num_avail)
		local has_arrow = false
		local sub_menu
		local normal_name = skill_name_data.normal
		local multiple_ok = (prof ~= PROF_ENCHANTING) or (prof == PROF_ENCHANTING and ENCHANTING_TRADE_GOOD[cur_item.subtype])

		if multiple_ok and num_avail > 1 then
			has_arrow = true
			sub_menu = AcquireTable()

			local craft_args = ("%s:%d:%d"):format(prof, skill_idx, num_avail)
			local entry = AcquireTable()
			entry.text = _G.ALL
			entry.func = CraftItem
			entry.arg1 = craft_args
			entry.tooltipTitle = "RevelationTooltip"
			entry.tooltipText = L["Create every %s you have reagents for."]:format(normal_name)
			entry.notCheckable = true
			table.insert(sub_menu, entry)

			local entry2 = AcquireTable()
			entry2.text = (" 1 - %d"):format(num_avail)
			entry2.func = CraftItem_Popup
			entry2.arg1 = craft_args
			entry2.tooltipTitle = "RevelationTooltip"
			entry2.tooltipText = L["Create 1 - %d %s."]:format(num_avail, normal_name)
			entry2.notCheckable = true
			table.insert(sub_menu, entry2)
		end
		local recipe_link = _G.GetTradeSkillRecipeLink(skill_idx)

		if not icon_cache[normal_name] then
			icon_cache[normal_name] = select(10, _G.GetItemInfo(recipe_link)) or _G.GetTradeSkillIcon(skill_idx)
		end

		local new_recipe = AcquireTable()
		new_recipe.name = normal_name

		if num_avail > 1 then
			new_recipe.text = ("%s (%d)"):format(skill_name_data.color, num_avail)
		else
			new_recipe.text = skill_name_data.color
		end
		new_recipe.icon = icon_cache[normal_name]
		new_recipe.func = CraftItem
		new_recipe.arg1 = ("%s:%d:1"):format(prof, skill_idx)
		new_recipe.hasArrow = has_arrow
		new_recipe.tooltipTitle = "RevelationItemLink"
		new_recipe.tooltipText = recipe_link
		new_recipe.notCheckable = true
		new_recipe.subMenu = sub_menu
		table.insert(recipes, new_recipe)
	end
end

-- The level parameter only exists to make this interchangeable with IterEnchant()
local function IterTrade(prof, skill_idx, skill_name_data, num_avail, level, single)
	local rune_forge = (cur_item.type == L["Weapon"]) and (prof == PROF_RUNEFORGING)

	if not rune_forge then
		local is_reagent = false

		for reagent = 1, _G.GetTradeSkillNumReagents(skill_idx) do
			if cur_item.name == _G.GetTradeSkillReagentInfo(skill_idx, reagent) then
				is_reagent = true
				break
			end
		end

		if num_avail < 1 or not is_reagent then
			return
		end
	end
	AddRecipe(prof, skill_name_data, skill_idx, single and 1 or num_avail)
end

local IterEnchant
do
	local ItemEnch = {
		L["Chest"],
		L["Boots"],
		L["Bracer"],
		L["Gloves"],
		L["Ring"],
		L["Cloak"],
		L["Shield"],
		L["Staff"],
		_G.ENCHSLOT_2HWEAPON,
		_G.ENCHSLOT_WEAPON
	}

	function IterEnchant(prof, skill_idx, skill_name_data, num_avail, level, single)
		if num_avail < 1 then
			return
		end
		local eqref = cur_item.eqloc and EquipSlot[cur_item.eqloc]
		local found = false

		if eqref then
			if cur_item.eqloc == "INVTYPE_WEAPON" or cur_item.eqloc == "INVTYPE_WEAPONMAINHAND" or cur_item.eqloc == "INVTYPE_WEAPONOFFHAND" then
				if (not skill_name_data.normal:find(EquipSlot["INVTYPE_2HWEAPON"])) and skill_name_data.normal:find(eqref) then
					found = true
				end
			elseif cur_item.eqloc == "INVTYPE_2HWEAPON" then
				if skill_name_data.normal:find(eqref)
					or skill_name_data.normal:find(EquipSlot["INVTYPE_WEAPON"])
					or (cur_item.subtype == L["Staves"]
					and skill_name_data.normal:find(L["Staff"])) then
					found = true
				end
			elseif skill_name_data.normal:find(eqref) then
				found = true
			end
		elseif string.find(cur_item.name, L["Enchanting Vellum"]) then
			for k, v in pairs(ItemEnch) do
				if skill_name_data.normal:find(v) then
					found = true
					break
				end
			end
		elseif cur_item.subtype == L["Enchanting"] then
			IterTrade(prof, skill_idx, skill_name_data, num_avail, level, single)
			return
		end

		if not found then
			return
		end
		local _, _, enchant_string = string.find(_G.GetTradeSkillRecipeLink(skill_idx), "^|%x+|H(.+)|h%[.+%]")
		local _, enchant_spell_id = (":"):split(enchant_string)
		local enchant_level = private.GetEnchantLevels()[tonumber(enchant_spell_id)]

		if enchant_level and enchant_level > level then
			return
		end
		AddRecipe(prof, skill_name_data, skill_idx, 1)
	end
end

local Scan
do
	local PROF_MENU_DATA

	local DIFFICULTY_IDS = {
		trivial = 1,
		easy = 2,
		medium = 3,
		optimal = 4,
	}

	local name_pair = {}
	local ATSW_SkipSlowScan = _G.ATSW_SkipSlowScan

	function Scan(prof, level, single)
		local func

		if prof == PROF_ENCHANTING then
			if EquipSlot[cur_item.eqloc] or cur_item.subtype == L["Item Enchantment"] or ENCHANTING_TRADE_GOOD[cur_item.subtype] then
				func = IterEnchant
			end
		else
			func = IterTrade
		end

		if func then
			_G.CastSpellByName(prof)

			if ATSW_SkipSlowScan then
				ATSW_SkipSlowScan()
			end
			local num_tradeskills = _G.GetNumTradeSkills()

			-- Expand all headers for an accurate reading.
			for i = num_tradeskills, 1, -1 do
				local _, skill_type = _G.GetTradeSkillInfo(i)

				if skill_type == "header" then
					_G.ExpandTradeSkillSubClass(i)
				end
			end

			for idx = 1, num_tradeskills do
				local skill_name, skill_type, num_avail, _, _ = _G.GetTradeSkillInfo(idx)

				if skill_name and skill_type ~= "header" and DIFFICULTY_IDS[skill_type] >= db.min_skill and DIFFICULTY_IDS[skill_type] <= db.max_skill then
					name_pair.normal = skill_name
					name_pair.color = DIFFICULTY_COLORS[skill_type] .. skill_name .. "|r"
					func(prof, idx, name_pair, num_avail, level, single)
				end
			end
			_G.CloseTradeSkill()
		end

		if not PROF_MENU_DATA then
			PROF_MENU_DATA = {
				[PROF_ENCHANTING] = {
					name = SPELL_DISENCHANT,
					icon = select(3, _G.GetSpellInfo(SPELL_DISENCHANT)),
					CanPerform = private.CanDisenchant,
				},
				[PROF_INSCRIPTION] = {
					name = SPELL_MILLING,
					icon = select(3, _G.GetSpellInfo(SPELL_MILLING)),
					CanPerform = private.CanMill,
				},
				[PROF_JEWELCRAFTING] = {
					name = SPELL_PROSPECTING,
					icon = select(3, _G.GetSpellInfo(SPELL_PROSPECTING)),
					CanPerform = private.CanProspect,
				},
			}
		end
		local menu_data = PROF_MENU_DATA[prof]

		if private.bag_id and private.slot_id and menu_data and menu_data.CanPerform() then
			local entry = AcquireTable()

			entry.icon = menu_data.icon
			entry.name = menu_data.name
			entry.text = menu_data.name
			entry.hasArrow = false
			entry.notCheckable = true
			table.insert(recipes, entry)
		end
	end
end -- do

do
	local EMPTY_RECIPE = {
		text = L["Either no recipe or no reagents were found."],
		disabled = true,
		hasArrow = false,
		notCheckable = true
	}

	local function ScanEverything()
		for prof, index in pairs(known_professions) do
			if index then
				local name = _G.GetProfessionInfo(index)

				if VALID_PROFESSIONS[name] then
					Scan(name, 1, false)
				end
			end
		end
	end

	local function HasProfession(profession_name)
		local known = known_professions

		if known.prof1 and profession_name == (_G.GetProfessionInfo(known.prof1)) then
			return true
		elseif known.prof2 and profession_name == (_G.GetProfessionInfo(known.prof2)) then
			return true
		end
		return false
	end

	function Revelation:CreateMenu(anchor, item_link)
		if not item_link then
			return
		end

		if not anchor then
			if not ModifiersPressed() then -- Enforce for HandleModifiedItemClick
				return
			end
			anchor = _G.GetMouseFocus()
		end

		for index = 1, #active_tables do -- Release the tables for re-use.
			wipe(active_tables[index])
			table.insert(table_heap, active_tables[index])
			active_tables[index] = nil
		end
		wipe(recipes)

		local known = known_professions

		known.prof1, known.prof2, known.archaeology, known.fishing, known.cooking, known.firstaid = _G.GetProfessions()

		local item_name, item_link, item_quality, item_level, item_minlevel, item_type, item_subtype, item_stack, item_eqloc, _ = _G.GetItemInfo(item_link)

		cur_item.name = item_name
		cur_item.link = item_link
		cur_item.quality = item_quality
		cur_item.level = item_level
		cur_item.minlevel = item_minlevel
		cur_item.type = item_type
		cur_item.subtype = item_subtype
		cur_item.stack = item_stack
		cur_item.eqloc = item_eqloc

		local sfx = tonumber(_G.GetCVar("Sound_EnableSFX"))
		_G.SetCVar("Sound_EnableSFX", 0)

		if item_type == _G.ARMOR or item_type:find(L["Weapon"]) then
			if HasProfession(PROF_ENCHANTING) then
				Scan(PROF_ENCHANTING, item_level, true)
			end

			if HasProfession(PROF_INSCRIPTION) then
				Scan(PROF_INSCRIPTION, item_level, true)
			end

			if HasProfession(PROF_RUNEFORGING) then
				Scan(PROF_RUNEFORGING, item_level, true)
			end
		elseif item_type == L["Trade Goods"] then
			local is_enchanter = HasProfession(PROF_ENCHANTING)

			if is_enchanter and ENCHANTING_TRADE_GOOD[item_subtype] then
				Scan(PROF_ENCHANTING, item_level, false)
			elseif is_enchanter and item_subtype == L["Item Enchantment"] then
				Scan(PROF_ENCHANTING, item_level, true)
			else
				ScanEverything()
			end
		elseif MY_CLASS == "ROGUE" and private.CanPick() then
			local entry = AcquireTable()

			ICON_PICK_LOCK = ICON_PICK_LOCK or select(3, _G.GetSpellInfo(SPELL_PICK_LOCK))

			entry.icon = ICON_PICK_LOCK
			entry.name = SPELL_PICK_LOCK
			entry.text = SPELL_PICK_LOCK
			entry.hasArrow = false
			entry.notCheckable = true
			table.insert(recipes, entry)
		else
			ScanEverything()
		end

		if #recipes == 0 then
			table.insert(recipes, EMPTY_RECIPE)
		end
		_G.ToggleDropDownMenu(1, nil, DropDown, anchor, 0, 0)
		_G.SetCVar("Sound_EnableSFX", sfx)
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
			icon = [[Interface\Icons\Spell_Fire_SealOfFire]],
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

		local defaults = {
			global = {
				modifier = 1, -- ALT
				modifier2 = 10, -- NONE
				button = 2, -- RightButton
				min_skill = 1, -- Trivial
				max_skill = 4, -- Optimal
			}
		}
		self.db = LibStub("AceDB-3.0"):New(ADDON_NAME .. "Config", defaults, true)
		db = self.db.global

		self:SetupOptions()
		self.OnInitialize = nil
	end
end -- do

do
	local SPECIAL_MENU_ENTRY = {
		[SPELL_DISENCHANT] = _G.GetSpellLink(13262),
		[SPELL_MILLING] = _G.GetSpellLink(51005),
		[SPELL_PROSPECTING] = _G.GetSpellLink(31252),
		[SPELL_PICK_LOCK] = _G.GetSpellLink(1804),
	}

	local function NameSort(one, two)
		return one.name < two.name
	end

	function Revelation:OnEnable()
		-------------------------------------------------------------------------------
		-- Create the dropdown frame, and set its state.
		-------------------------------------------------------------------------------
		DropDown = _G.CreateFrame("Frame", "Revelation_DropDown")
		DropDown.displayMode = "MENU"
		DropDown.point = "TOPLEFT"
		DropDown.relativePoint = "TOPRIGHT"
		DropDown.levelAdjust = 0

		function DropDown:initialize(level)
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
					_G.UIDropDownMenu_AddButton(info, level)

					if SPECIAL_MENU_ENTRY[v.name] then
						local button = _G[list_name .. "Button" .. count]

						secure_frame:SetParent(button)
						secure_frame:SetPoint("TOPLEFT", button, "TOPLEFT")
						secure_frame:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT")
						secure_frame:SetAttribute("macrotext", string.format("/cast %s\n/use %s %s\n/script CloseDropDownMenus()", v.name, private.bag_id, private.slot_id))
						secure_frame.link = SPECIAL_MENU_ENTRY[v.name]
						secure_frame:Show()
					end
					count = count + 1
				end
			elseif level == 2 then
				local sub_menu = recipes[_G.UIDROPDOWNMENU_MENU_VALUE].subMenu

				if sub_menu then
					for key, val in ipairs(sub_menu) do
						info = val
						_G.UIDropDownMenu_AddButton(info, level)
					end
				end
			end
		end

		-----------------------------------------------------------------------
		-- Static popup initialization
		-----------------------------------------------------------------------
		_G.StaticPopupDialogs["Revelation_CraftItems"] = {
			button1 = _G.OKAY,
			button2 = _G.CANCEL,
			OnShow = function(self)
				self.button1:Disable()
				self.button2:Enable()
				self.editBox:SetFocus()
			end,
			OnAccept = OnCraftItems,
			EditBoxOnEnterPressed = OnCraftItems,
			EditBoxOnEscapePressed = function(self)
				self:GetParent():Hide()
			end,
			EditBoxOnTextChanged = function(self)
				local parent = self:GetParent()

				if parent.editBox:GetText() ~= "" then
					parent.button1:Enable()
				else
					parent.button1:Disable()
				end
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
end -- do block

function Revelation:OnDisable()
	self:UnhookAll()
end

-------------------------------------------------------------------------------
-- Hooked functions
-------------------------------------------------------------------------------
do
	local MouseButton = {
		"LeftButton",
		"RightButton",
	}
	local click_handled = false -- For HandleModifiedItemClick kludge...

	function Revelation:PaperDollItemSlotButton_OnModifiedClick(...)
		local hooked_self, button = ...

		click_handled = true
		private.bag_id = nil
		private.slot_id = nil

		if ModifiersPressed() and button == MouseButton[db.button] then
			private.slot_id = hooked_self:GetID()
			self:CreateMenu(hooked_self, _G.GetInventoryItemLink("player", private.slot_id))
		else
			self.hooks.PaperDollItemSlotButton_OnModifiedClick(...)
		end
		click_handled = false
	end

	function Revelation:ContainerFrameItemButton_OnModifiedClick(...)
		local hooked_self, button = ...

		click_handled = true
		private.bag_id = nil
		private.slot_id = nil

		if ModifiersPressed() and button == MouseButton[db.button] then
			private.bag_id = hooked_self:GetParent():GetID()
			private.slot_id = hooked_self:GetID()
			self:CreateMenu(hooked_self, _G.GetContainerItemLink(private.bag_id, private.slot_id))
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
_G.hooksecurefunc("GameTooltip_AddNewbieTip", function(frame, normalText, r, g, b, newbieText, noNormalText)
	if normalText == "RevelationTooltip" then
		_G.GameTooltip_SetDefaultAnchor(_G.GameTooltip, frame)
		_G.GameTooltip:AddLine(newbieText)
		_G.GameTooltip:Show()
	elseif normalText == "RevelationItemLink" then
		_G.GameTooltip_SetDefaultAnchor(_G.GameTooltip, frame)
		_G.GameTooltip:SetHyperlink(newbieText)
	end
end)

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------
local options, GetOptions
do
	local DifficultyName = {
		[1] = DIFFICULTY_COLORS["trivial"] .. L["Trivial"] .. "|r",
		[2] = DIFFICULTY_COLORS["easy"] .. L["Easy"] .. "|r",
		[3] = DIFFICULTY_COLORS["medium"] .. L["Medium"] .. "|r",
		[4] = DIFFICULTY_COLORS["optimal"] .. L["Optimal"] .. "|r",
	}

	local ModifierName = {
		[1] = _G.ALT_KEY,
		[2] = _G.CTRL_KEY,
		[3] = _G.SHIFT_KEY,
		[4] = _G.RALT_KEY_TEXT,
		[5] = _G.LALT_KEY_TEXT,
		[6] = _G.RCTRL_KEY_TEXT,
		[7] = _G.LCTRL_KEY_TEXT,
		[8] = _G.RSHIFT_KEY_TEXT,
		[9] = _G.LSHIFT_KEY_TEXT,
		[10] = _G.NONE_KEY
	}

	local ButtonName = {
		[1] = _G.KEY_BUTTON1, -- Left Mouse Button
		[2] = _G.KEY_BUTTON2 -- Right Mouse Button
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
						get = function()
							return db.modifier
						end,
						set = function(info, value)
							db.modifier = value
						end,
						values = ModifierName
					},
					modifier2 = {
						order = 2,
						type = "select",
						name = _G.KEY2,
						desc = L["Select the second key to press when mouse-clicking for menu display."],
						get = function()
							return db.modifier2
						end,
						set = function(info, value)
							db.modifier2 = value
						end,
						values = ModifierName
					},
					button = {
						order = 3,
						type = "select",
						name = _G.MOUSE_LABEL,
						desc = L["Select the mouse button to click for menu display."],
						get = function()
							return db.button
						end,
						set = function(info, value)
							db.button = value
						end,
						values = ButtonName
					},
					min_skill = {
						order = 4,
						type = "select",
						name = string.format("%s (%s)", _G.SKILL_LEVEL, _G.MINIMUM),
						get = function()
							return db.min_skill
						end,
						set = function(info, value)
							db.min_skill = value

							if value > db.max_skill then
								db.min_skill = db.max_skill
							end
						end,
						values = DifficultyName
					},
					max_skill = {
						order = 5,
						type = "select",
						name = string.format("%s (%s)", _G.SKILL_LEVEL, _G.MAXIMUM),
						get = function()
							return db.max_skill
						end,
						set = function(info, value)
							db.max_skill = value

							if value < db.min_skill then
								db.max_skill = db.min_skill
							end
						end,
						values = DifficultyName
					},
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
