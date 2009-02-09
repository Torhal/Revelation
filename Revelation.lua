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
local dewdrop = AceLibrary("Dewdrop-2.0")

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

local Difficulty = {
	["trivial"]	= "|cff808080",
	["easy"]	= "|cff40bf40",
	["medium"]	= "|cffffff00",
	["optimal"]	= "|cffff8040",
}

local function ReturnTrue() return true end

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

local ModifierKey = {
	[1] = IsAltKeyDown,	-- ALT
	[2] = IsControlKeyDown,	-- CTRL
	[3] = IsShiftKeyDown,	-- SHIFT
	[4] = ReturnTrue	-- NONE
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
local valNames = {}
local db

-------------------------------------------------------------------------------
-- Local functions
-------------------------------------------------------------------------------
local function SetTradeSkill(tradeSkill)
	CastSpellByName(tradeSkill)
	CloseTradeSkill()
end

local function AddRecipe(tradeSkill, text, func, skillIndex, numAvailable)
	local hasArrow = false
	local subMenu = {}

	if (tradeSkill ~= GetSpellInfo(7411)) and (numAvailable > 1) then
		hasArrow = true
		tinsert(subMenu,
			{
				text = L["All"],
				func = function()
					       SetTradeSkill(tradeSkill)
					       DoTradeSkill(skillIndex, numAvailable)
					       dewdrop:Close()
				       end,
				tooltipText = L["Create every"].." "..text.normal.." "..L["you have reagents for."]
			}
		)
		tinsert(subMenu,
			{
				text = " 1 - "..numAvailable,
				tooltipText = L["Create"].." 1 - "..numAvailable.." "..text.normal..".",
				hasArrow = true,
				hasEditBox = true,
				editBoxFunc = function(text)
						      SetTradeSkill(tradeSkill)
						      DoTradeSkill(skillIndex, tonumber(text))
						      dewdrop:Close()
						      return value
					      end,
				editBoxValidateFunc = function(text)
							      local val = tonumber(text)
							      return (val >= 1) and (val <= numAvailable)
						      end,
			}
		)
	end

	if recipes["Nothing"] then wipe(recipes) end

	local itemLink = GetTradeSkillItemLink(skillIndex)
	local enchantLink = GetTradeSkillRecipeLink(skillIndex)

	recipes[text.normal] =	{
		text = text.color,
		func = func,
		hasArrow = hasArrow,
		icon = select(10, GetItemInfo(itemLink)) or GetTradeSkillIcon(skillIndex),
		iconWidth = 16,
		iconHeight = 16,
		tooltipFunc = GameTooltip.SetHyperlink,
		tooltipArg1 = GameTooltip,
		tooltipArg2 = (itemLink or enchantLink),
		subMenu = subMenu
	}
end

local function IsReagent(item, recipe)
	local num = GetTradeSkillNumReagents(recipe)

	for reagent = 1, num do
		if item == GetTradeSkillReagentInfo(recipe, reagent) then return true end
	end
	return false
end

local function IterTrade(tradeSkill, skillNum, reference, skillName, numAvailable, single)
	if (numAvailable < 1) or (not IsReagent(reference, skillNum)) then return end
	local func =
		function()
			SetTradeSkill(tradeSkill)
			DoTradeSkill(skillNum, 1)
			dewdrop:Close()
		end

	AddRecipe(tradeSkill, skillName, func, skillNum, single and 1 or numAvailable)
end

local function IterEnchant(tradeSkill, skillNum, reference, skillName, numAvailable, single)
	if (numAvailable < 1) then return end

	local ref = EquipSlot[reference]
	local found = false

	if (reference == "INVTYPE_WEAPONMAINHAND") or (reference == "INVTYPE_WEAPONOFFHAND") then
		if (strfind(skillName.normal, EquipSlot["INVTYPE_2HWEAPON"]) == nil) and (strfind(skillName.normal, ref) ~= nil) then
			found = true
		end
	elseif (strfind(skillName.normal, ref) ~= nil) then
		found = true
	end

	if not found then return end
	local func =
		function()
			SetTradeSkill(tradeSkill)
			DoTradeSkill(skillNum, 1)
			dewdrop:Close()
		end
	AddRecipe(tradeSkill, skillName, func, skillNum, 1)
end

local function Scan(tradeSkill, reference, single)
	CastSpellByName(tradeSkill)
	if (ATSW_SkipSlowScan ~= nil) then ATSW_SkipSlowScan() end

	local func = IterTrade

	if (tradeSkill == GetSpellInfo(7411)) and EquipSlot[reference] then func = IterEnchant end

	for i = 1, GetNumTradeSkills() do
		local skillName, skillType, numAvailable, _ = GetTradeSkillInfo(i)
		if skillType ~= "header" then
			valNames.normal = skillName
			valNames.color = Difficulty[skillType]..skillName.."|r"
			func(tradeSkill, i, reference, valNames, numAvailable, single)
		end
	end
	CloseTradeSkill()
end

-- I robbed Ackis!
local function GetKnown(ProfTable)
	-- Reset the table, they may have unlearnt a profession
	for i in pairs(ProfTable) do ProfTable[i] = false end

	-- Grab names from the spell book
	for index = 1, 25, 1 do
		local spellName = GetSpellName(index, BOOKTYPE_SPELL)

		if (not spellName) or (index == 25) then break end

		if (ProfTable[spellName] == false) then
			ProfTable[spellName] = true
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
		if (not ModifierKey[db.modifier]()) and (not ModifierKey[db.modifier2]()) then return end	-- Enforce for HandleModifiedItemClick
		focus = GetMouseFocus()
	end

	recipes = {
		["Nothing"] = {
			text = L["Either no recipe or no reagents were found."],
			func = function() dewdrop:Close() end,
			hasArrow = false
		}
	}
	GetKnown(Professions)

	local itemName, _, _, _, _, itemType, _, _, itemEquipLoc, _ = GetItemInfo(item)

	if (itemType == L["Armor"]) or (itemType == L["Weapon"]) then
		local ench = GetSpellInfo(7411)
		local scribe = GetSpellInfo(45357)
		local rune = GetSpellInfo(53428)
		if (Professions[ench] == true) then
			Scan(ench, itemEquipLoc, true)
		end
		if (Professions[scribe] == true) then
			Scan(scribe, itemEquipLoc, true)
		end
		if (Professions[rune] == true) then
			Scan(rune, itemEquipLoc, true)
		end
	else
		for key, val in pairs(Professions) do
			if val == true then Scan(key, itemName, false) end
		end
	end
	dewdrop:Open(focus, "children", function() dewdrop:FeedTable(recipes) end)
end

-------------------------------------------------------------------------------
-- Hooked functions
-------------------------------------------------------------------------------
function Revelation:PaperDollItemSlotButton_OnModifiedClick(...)
	local hookSelf, button = ...
	isHandled = true
	if (ModifierKey[db.modifier]() and ModifierKey[db.modifier2]() and (button == MouseButton[db.button])) then
		self:Menu(hookSelf, GetInventoryItemLink("player", hookSelf:GetID()))
	else
		self.hooks.PaperDollItemSlotButton_OnModifiedClick(...)
	end
	isHandled = false
end

function Revelation:ContainerFrameItemButton_OnModifiedClick(...)
	local hookSelf, button = ...
	isHandled = true

	if (ModifierKey[db.modifier]() and ModifierKey[db.modifier2]() and (button == MouseButton[db.button])) then
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
					values = MouseButton
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
