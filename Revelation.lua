-------------------------------------------------------------------------------
-- Localized globals
-------------------------------------------------------------------------------
local _G = getfenv(0)
local strfind, strsub = _G.string.find, _G.string.sub
local pairs, ipairs, tinsert = _G.pairs, _G.ipairs, _G.table.insert
local GetSpellInfo = _G.GetSpellInfo

-------------------------------------------------------------------------------
-- AddOn namespace
-------------------------------------------------------------------------------
local dewdrop = AceLibrary("Dewdrop-2.0")
local AceAddon = LibStub("AceAddon-3.0")
Revelation = AceAddon:NewAddon("Revelation", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Revelation", false)

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
	[GetSpellInfo(2575)]	= false, -- Smelting
	[GetSpellInfo(3908)]	= false, -- Tailoring
	[GetSpellInfo(25229)]	= false, -- Jewelcrafting
	[GetSpellInfo(45357)]	= false, -- Inscription
	[GetSpellInfo(53428)]	= false, -- Runeforging
}

local Difficulty = {
	["trivial"]	= "|cff777777",
	["easy"]	= "|cff33bb33",
	["medium"]	= "|cffffff00",
	["optimal"]	= "|cffff7733",
	["difficult"]	= "|cffffffff",
}

-------------------------------------------------------------------------------
-- Variables
-------------------------------------------------------------------------------
local isHandled = false		-- For HandleModifiedItemClick kludge...
local recipes = {}
local valNames = {}

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
				tooltipText = L["CreateAll"]..text..L["HaveReagents"]
			}
		)
		local max = math.min(numAvailable, 10)

		for i = 1, max do
			tinsert(subMenu,
				{
					text = i,
					func = function()
						       SetTradeSkill(tradeSkill)
						       DoTradeSkill(skillIndex, i)
						       dewdrop:Close()
					       end,
					tooltipText = L["Create"]..i.." "..text.."."
				}
			)
		end

		if (numAvailable >= 15) then
			for i = 15, numAvailable, 5 do
				tinsert(subMenu,
					{
						text = i,
						func = function()
							       SetTradeSkill(tradeSkill)
							       DoTradeSkill(skillIndex, i)
							       dewdrop:Close()
						       end,
						tooltipText = L["Create"]..i.." "..text.."."
					}
				)
			end
		end
	end

	if recipes["Nothing"] then wipe(recipes) end

--	local itemLink = GetTradeSkillItemLink(skillIndex)

	recipes[text] =	{
		text = text,
		func = func,
		hasArrow = hasArrow,
		tooltipText = GetTradeSkillDescription(skillIndex),
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

	AddRecipe(tradeSkill, skillName.color, func, skillNum, single and 1 or numAvailable)
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
	AddRecipe(tradeSkill, skillName.color, func, skillNum, 1)
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
end

function Revelation:OnEnable()
	self:RawHook("PaperDollItemSlotButton_OnModifiedClick", true)
	self:RawHook("ContainerFrameItemButton_OnModifiedClick", true)
	self:RawHook("HandleModifiedItemClick", true)
end

function Revelation:OnDisable()
	self:UnhookAll()
end

function Revelation:Menu(focus, item)
	if (item == nil) then return end
	if (focus == nil) then
		if not IsAltKeyDown() then return end	-- Enforce for HandleModifiedItemClick
		focus = GetMouseFocus()
	end

	recipes = {
		["Nothing"] = {
			text = L["NotFound"],
			func = function() dewdrop:Close() end,
			hasArrow = false
		}
	}
	GetKnown(Professions)

	local itemName, _, _, _, _, itemType, _, _, itemEquipLoc, _ = GetItemInfo(item)

	if (itemType == L["Armor"]) or (itemType == L["Weapon"]) then
		local ench = GetSpellInfo(7411)
		if (Professions[ench] == false) then return end
		Scan(ench, itemEquipLoc, true)
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
	if IsAltKeyDown() and (button == "LeftButton") then
		self:Menu(hookSelf, GetInventoryItemLink("player", hookSelf:GetID()))
	else
		self.hooks.PaperDollItemSlotButton_OnModifiedClick(...)
	end
	isHandled = false
end

function Revelation:ContainerFrameItemButton_OnModifiedClick(...)
	local hookSelf, button = ...
	isHandled = true
	if IsAltKeyDown() and (button == "LeftButton") then
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