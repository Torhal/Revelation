-------------------------------------------------------------------------------
-- Localized globals
-------------------------------------------------------------------------------
local _G = getfenv(0)
local strfind, strsub = _G.string.find, _G.string.sub
local pairs, ipairs, tinsert = _G.pairs, _G.ipairs, _G.table.insert
local GameTooltip, GetSpellInfo = _G.GameTooltip, _G.GetSpellInfo
local GetTradeSkillItemLink = _G.GetTradeSkillItemLink
local GetTradeSkillRecipeLink = _G.GetTradeSkillRecipeLink

-------------------------------------------------------------------------------
-- AddOn namespace
-------------------------------------------------------------------------------
local NAME = "Revelation"
local Revelation = LibStub("AceAddon-3.0"):NewAddon(NAME, "AceHook-3.0")
local Dewdrop = AceLibrary("Dewdrop-2.0")

local dev = false
--@debug@
dev = true
--@end-debug@
local L = LibStub("AceLocale-3.0"):GetLocale(NAME, "enUS", true, dev)

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

local ArmorEnch = {
	L["Chest"], L["Boots"], L["Bracer"], L["Gloves"], L["Ring"], L["Cloak"], L["Shield"]
}

local WeaponEnch = {
	L["2H Weapon"], L["Weapon"]
}

local Professions = {
	[GetSpellInfo(2259)]	= false, -- Alchemy
	[GetSpellInfo(2018)]	= false, -- Blacksmithing
	[GetSpellInfo(2550)]	= false, -- Cooking
	[GetSpellInfo(7411)]	= false, -- Enchanting
	[GetSpellInfo(4036)]	= false, -- Engineering
	[GetSpellInfo(746)]	= false, -- First Aid
	[GetSpellInfo(2108)]	= false, -- Leatherworking
	[GetSpellInfo(61422)]	= false, -- Smelting
	[GetSpellInfo(3908)]	= false, -- Tailoring
	[GetSpellInfo(25229)]	= false, -- Jewelcrafting
	[GetSpellInfo(45357)]	= false, -- Inscription
	[GetSpellInfo(53428)]	= false, -- Runeforging
}

local EnchantLevel = {
	[25086] = 35,	-- Enchant Cloak - Dodge
	[27899] = 35,	-- Enchant Bracer - Brawn
	[27906] = 35,	-- Enchant Bracer - Major Defense
	[27911] = 35,	-- Enchant Bracer - Superior Healing
	[27913] = 35,	-- Enchant Bracer - Restore Mana Prime
	[27914] = 35,	-- Enchant Bracer - Fortitude
	[27917] = 35,	-- Enchant Bracer - Spellpower
	[27926] = 35,	-- Enchant Ring - Healing Power
	[27927] = 35,	-- Enchant Ring - Stats
	[27945] = 35,	-- Enchant Shield - Intellect
	[27946] = 35,	-- Enchant Shield - Shield Block
	[27947] = 35,	-- Enchant Shield - Resistance
	[27948] = 35,	-- Enchant Boots - Vitality
	[27950] = 35,	-- Enchant Boots - Fortitude
	[27951] = 35,	-- Enchant Boots - Dexterity
	[27954] = 35,	-- Enchant Boots - Surefooted
	[27958] = 60,	-- Enchant Chest - Exceptional Mana
	[27961] = 35,	-- Enchant Cloak - Major Armor
	[27962] = 35,	-- Enchant Cloak - Major Resistance
	[27967] = 35,	-- Enchant Weapon - Major Striking
	[27968] = 35,	-- Enchant Weapon - Major Intellect
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
	[34005] = 35,	-- Enchant Cloak - Greater Arcane Resistance
	[34006] = 35,	-- Enchant Cloak - Greater Shadow Resistance
	[34008] = 35,	-- Enchant Boots - Boar's Speed
	[34009] = 35,	-- Enchant Shield - Major Stamina
	[34010] = 35,	-- Enchant Weapon - Major Healing
	[42620] = 35,	-- Enchant Weapon - Greater Agility
	[42974] = 60,	-- Enchant Weapon - Executioner
	[44383] = 35,	-- Enchant Shield - Resilience
	[44483] = 60,	-- Enchant Cloak - Superior Frost Resistance
	[44494] = 60,	-- Enchant Cloak - Superior Nature Resistance
	[44506] = 60,	-- Enchant Gloves - Gatherer
	[44524] = 60,	-- Enchant Weapon - Icebreaker
	[44555] = 60,	-- Enchant Bracers - Exceptional Intellect
	[44575] = 60,	-- Enchant Bracers - Greater Assault
	[44576] = 60,	-- Enchant Weapon - Lifeward
	[44590] = 60,	-- Enchant Cloak - Superior Shadow Resistance
	[44591] = 60,	-- Enchant Cloak - Titanweave
	[44592] = 60,	-- Enchant Gloves - Exceptional Spellpower
	[44595] = 60,	-- Enchant 2H Weapon - Scourgebane
	[44596] = 60,	-- Enchant Cloak - Superior Arcane Resistance
	[44621] = 60,	-- Enchant Weapon - Giant Slayer
	[44623] = 60,	-- Enchant Chest - Super Stats
	[44625] = 60,	-- Enchant Gloves - Armsman
	[44631] = 60,	-- Enchant Cloak - Shadow Armor
	[46578] = 60,	-- Enchant Weapon - Deathfrost
	[46594] = 35,	-- Enchant Chest - Defense
	[47051] = 35,	-- Enchant Cloak - Steelweave
	[47672] = 60,	-- Enchant Cloak - Mighty Armor
	[47898] = 60,	-- Enchant Cloak - Greater Speed
	[47899] = 60,	-- Enchant Cloak - Wisdom
	[59619] = 60,	-- Enchant Weapon - Accuracy
	[59621] = 60,	-- Enchant Weapon - Berserking
	[59625] = 60,	-- Enchant Weapon - Black Magic
	[60606] = 60,	-- Enchant Boots - Assault
	[60609] = 60,	-- Enchant Cloak - Speed
	[60616] = 60,	-- Enchant Bracers - Striking
	[60621] = 60,	-- Enchant Weapon - Greater Potency
	[60691] = 60,	-- Enchant 2H Weapon - Massacre
	[60692] = 60,	-- Enchant Chest - Powerful Stats
	[60707] = 60,	-- Enchant Weapon - Superior Potency
	[60714] = 60,	-- Enchant Weapon - Mighty Spellpower
	[60763] = 60,	-- Enchant Boots - Greater Assault
	[60767] = 60,	-- Enchant Bracers - Superior Spellpower
	[62256] = 60,	-- Enchant Bracers - Major Stamina
	[62257] = 60,	-- Enchant Weapon - Titanguard
}

local Difficulty = {
	["trivial"]	= "|cff808080",
	["easy"]	= "|cff40bf40",
	["medium"]	= "|cffffff00",
	["optimal"]	= "|cffff8040",
}

local ButtonName = {
	[1] = L["Left Button"],
	[2] = L["Right Button"]
}

local MouseButton = {
	[1] = "LeftButton",
	[2] = "RightButton"
}

local ModifierName = {
	[1] = L["ALT"],
	[2] = L["CTRL"],
	[3] = L["SHIFT"],
	[4] = L["NONE"]
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
local isHandled = false		-- For HandleModifiedItemClick kludge...
local recipes = {}
local name_pair = {}
local db

-------------------------------------------------------------------------------
-- Local functions
-------------------------------------------------------------------------------
local function ModifiersPressed()
	local ModifierKey = {
		[1] = IsAltKeyDown,	-- ALT
		[2] = IsControlKeyDown,	-- CTRL
		[3] = IsShiftKeyDown,	-- SHIFT
	}
	local mod, mod2 = db.modifier, db.modifier2
	local retval = (mod == 4) or ModifierKey[mod]()
	local retval2 = (mod2 == 4) or ModifierKey[mod2]()
	return retval and retval2
end

local function SetTradeSkill(prof)
	CastSpellByName(prof)
	CloseTradeSkill()
end

local function AddRecipe(prof, skill_name, func, skill_idx, num_avail)
	local has_arrow = false
	local sub_menu = {}

	if (prof ~= GetSpellInfo(7411)) and (num_avail > 1) then
		has_arrow = true
		tinsert(sub_menu,
			{
				text = L["All"],
				func = function()
					       SetTradeSkill(prof)
					       DoTradeSkill(skill_idx, num_avail)
					       Dewdrop:Close()
				       end,
				tooltipText = L["Create every"].." "..skill_name.normal.." "..L["you have reagents for."]
			}
		)
		tinsert(sub_menu,
			{
				text = " 1 - "..num_avail,
				tooltipText = L["Create"].." 1 - "..num_avail.." "..skill_name.normal..".",
				hasArrow = true,
				hasEditBox = true,
				editBoxFunc = function(text)
						      SetTradeSkill(prof)
						      DoTradeSkill(skill_idx, tonumber(text))
						      Dewdrop:Close()
						      return value
					      end,
				editBoxValidateFunc = function(text)
							      local val = tonumber(text)
							      return (val >= 1) and (val <= num_avail)
						      end,
			}
		)
	end

	if recipes["Nothing"] then wipe(recipes) end

	local item_link = GetTradeSkillItemLink(skill_idx)
	local ench_link = GetTradeSkillRecipeLink(skill_idx)

	recipes[skill_name.normal] =	{
		text = skill_name.color,
		func = func,
		hasArrow = has_arrow,
		icon = select(10, GetItemInfo(item_link)) or GetTradeSkillIcon(skill_idx),
		iconWidth = 16,
		iconHeight = 16,
		tooltipFunc = GameTooltip.SetHyperlink,
		tooltipArg1 = GameTooltip,
		tooltipArg2 = (item_link or ench_link),
		subMenu = sub_menu
	}
end

local function IsReagent(item, recipe)
	local num = GetTradeSkillNumReagents(recipe)

	for reagent = 1, num do
		if item == GetTradeSkillReagentInfo(recipe, reagent) then return true end
	end
	return false
end

local function IterTrade(prof, skill_idx, reference, skill_name, num_avail, level, single)
	if (num_avail < 1) or (not IsReagent(reference, skill_idx)) then return end
	local func =
		function()
			SetTradeSkill(prof)
			DoTradeSkill(skill_idx, 1)
			Dewdrop:Close()
		end

	AddRecipe(prof, skill_name, func, skill_idx, single and 1 or num_avail)
end

local function IterEnchant(prof, skill_idx, reference, skill_name, num_avail, level, single)
	if (num_avail < 1) then return end

	local eqref = EquipSlot[reference]
	local found = false

	if (eqref == nil) and (strfind(reference, L["Armor Vellum"]) ~= nil) then
		for k, v in pairs(ArmorEnch) do
			if strfind(skill_name.normal, v) ~= nil then
				found = true
				break
			end
		end
	elseif (eqref == nil) and (strfind(reference, L["Weapon Vellum"]) ~= nil) then
		for k, v in pairs(WeaponEnch) do
			if strfind(skill_name.normal, v) ~= nil then
				found = true
				break
			end
		end
	elseif (reference == "INVTYPE_WEAPON") or (reference == "INVTYPE_WEAPONMAINHAND") or (reference == "INVTYPE_WEAPONOFFHAND") then
		if (strfind(skill_name.normal, EquipSlot["INVTYPE_2HWEAPON"]) == nil) and (strfind(skill_name.normal, eqref) ~= nil) then
			found = true
		end
	elseif (reference == "INVTYPE_2HWEAPON") then
		if (strfind(skill_name.normal, eqref) ~= nil) or (strfind(skill_name.normal, EquipSlot["INVTYPE_WEAPON"]) ~= nil) then
			found = true
		end
	elseif strfind(skill_name.normal, eqref) ~= nil then
		found = true
	end

	if not found then return end

	local _, _, ench_str = string.find(GetTradeSkillRecipeLink(skill_idx), "^|%x+|H(.+)|h%[.+%]")
	local _, ench_num = strsplit(":", ench_str)
	local ench_level = EnchantLevel[tonumber(ench_num)]

	if ench_level and ench_level > level then return end
--	print(ench_str.." - "..skill_name.normal)

	local func =
		function()
			SetTradeSkill(prof)
			DoTradeSkill(skill_idx, 1)
			Dewdrop:Close()
		end
	AddRecipe(prof, skill_name, func, skill_idx, 1)
end

local function Scan(prof, reference, level, single)
	CastSpellByName(prof)
	if (ATSW_SkipSlowScan ~= nil) then ATSW_SkipSlowScan() end

	local func = IterTrade

	if ((prof == GetSpellInfo(7411)) and
	    (EquipSlot[reference] or
	     ((strfind(reference, L["Armor Vellum"]) ~= nil) or
	      (strfind(reference, L["Weapon Vellum"]) ~= nil)))) then func = IterEnchant end

	for i = 1, GetNumTradeSkills() do
		local skill_name, skill_type, num_avail, _ = GetTradeSkillInfo(i)
		if skill_type ~= "header" then
			name_pair.normal = skill_name
			name_pair.color = Difficulty[skill_type]..skill_name.."|r"
			func(prof, i, reference, name_pair, num_avail, level, single)
		end
	end
	CloseTradeSkill()
end

-- I robbed Ackis!
local function GetKnown()
	-- Reset the table, they may have unlearnt a profession
	for i in pairs(Professions) do Professions[i] = false end

	-- Grab names from the spell book
	for index = 1, 25, 1 do
		local spell_name = GetSpellName(index, BOOKTYPE_SPELL)

		if (not spell_name) or (index == 25) then break end

		if (Professions[spell_name] == false) then
			Professions[spell_name] = true
		end
	end
end

-------------------------------------------------------------------------------
-- Main AddOn functions
-------------------------------------------------------------------------------
function Revelation:OnInitialize()
	local LDBinfo = {
		type = "launcher",
		icon = "Interface\\Icons\\Spell_Fire_SealOfFire",
		label = NAME,
		OnClick = function(button) InterfaceOptionsFrame_OpenToCategory(Revelation.optionsFrames.Revelation) end
	}
	self.DataObj = LibStub("LibDataBroker-1.1"):NewDataObject(NAME, LDBinfo)
	self.db = LibStub("AceDB-3.0"):New(NAME.."Config", defaults)
	self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
	db = self.db.profile

	self:SetupOptions()
end

function Revelation:OnEnable()
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

function Revelation:Menu(focus, item)
	if (item == nil) then return end
	if (focus == nil) then
		if not ModifiersPressed() then return end	-- Enforce for HandleModifiedItemClick
		focus = GetMouseFocus()
	end

	recipes = {
		["Nothing"] = {
			text = L["Either no recipe or no reagents were found."],
			func = function() Dewdrop:Close() end,
			hasArrow = false
		}
	}
	GetKnown()

	local item_name, _, _, item_level, _, item_type, item_stype, _, item_eqloc, _ = GetItemInfo(item)
	local ench = GetSpellInfo(7411)

	if (item_type == L["Armor"]) or strfind(item_type, L["Weapon"] ~= nil) then
		local scribe = GetSpellInfo(45357)
		local rune = GetSpellInfo(53428)
		if (Professions[ench] == true) then
			Scan(ench, item_eqloc, item_level, true)
		end
		if (Professions[scribe] == true) then
			Scan(scribe, item_eqloc, item_level, true)
		end
		if (Professions[rune] == true) then
			Scan(rune, item_eqloc, item_level, true)
		end
	elseif item_type == L["Trade Goods"] and ((item_stype == L["Armor Enchantment"]) or (item_stype == L["Weapon Enchantment"])) then
		if (Professions[ench] == true) then
			Scan(ench, item_name, max(1, item_level - 5), true)	-- Vellum item levels are 5 higher than the enchant which can be put on them.
		end
	else
		for key, val in pairs(Professions) do
			if val == true then Scan(key, item_name, 1, false) end
		end
	end
	Dewdrop:Open(focus, "children", function() Dewdrop:FeedTable(recipes) end)
end

-------------------------------------------------------------------------------
-- Hooked functions
-------------------------------------------------------------------------------
function Revelation:PaperDollItemSlotButton_OnModifiedClick(...)
	local hookSelf, button = ...
	isHandled = true
	if (ModifiersPressed() and (button == MouseButton[db.button])) then
		self:Menu(hookSelf, GetInventoryItemLink("player", hookSelf:GetID()))
	else
		self.hooks.PaperDollItemSlotButton_OnModifiedClick(...)
	end
	isHandled = false
end

function Revelation:ContainerFrameItemButton_OnModifiedClick(...)
	local hookSelf, button = ...
	isHandled = true

	if (ModifiersPressed() and (button == MouseButton[db.button])) then
		self:Menu(hookSelf, GetContainerItemLink(hookSelf:GetParent():GetID(), hookSelf:GetID()))
	end
	self.hooks.ContainerFrameItemButton_OnModifiedClick(...)
	isHandled = false
end

-- This hook is required as it is the only way to reference TradeRecipientItem7ItemButton
-- A.K.A.: "Will not be traded"
function Revelation:HandleModifiedItemClick(...)
	if isHandled == false then
		self:Menu(nil, ...)
	end
	return self.hooks.HandleModifiedItemClick(...)
end
_G["TradeRecipientItem7ItemButton"]:RegisterForClicks("AnyUp")

-------------------------------------------------------------------------------
-- Configuration
-------------------------------------------------------------------------------
local options

local function GetOptions()
	if not options then
		options = {
			type = "group",
			name = NAME,
			args = {
				modifier = {
					order = 1,
					type = "select",
					name = L["Modifier Key"],
					desc = L["Select the key to press when mouse-clicking for menu display."],
					get = function() return db.modifier end,
					set = function(info, value) db.modifier = value end,
					values = ModifierName
				},
				modifier2 = {
					order = 2,
					type = "select",
					name = L["Second Modifier Key"],
					desc = L["Select the second key to press when mouse-clicking for menu display."],
					get = function() return db.modifier2 end,
					set = function(info, value) db.modifier2 = value end,
					values = ModifierName
				},
				button = {
					order = 3,
					type = "select",
					name = L["Mouse Button"],
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

function Revelation:SetupOptions()
	self.optionsFrames = {}

	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(NAME, GetOptions())
	LibStub("AceConfig-3.0"):RegisterOptionsTable(NAME, GetOptions(), "nanotalk")
	self.optionsFrames.Revelation = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(NAME)
end