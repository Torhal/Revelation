-------------------------------------------------------------------------------
-- AddOn namespace
-------------------------------------------------------------------------------
local Revelation = {}
_G["Revelation"] = Revelation

local dewdrop = AceLibrary("Dewdrop-2.0")

-------------------------------------------------------------------------------
-- Localized globals
-------------------------------------------------------------------------------
local strfind = string.find
local strsub = string.sub
local tinsert = table.insert

-------------------------------------------------------------------------------
-- Local constants and variables
-------------------------------------------------------------------------------
local isHandled = false		-- For HandleModifiedItemClick kludge...
local Recipes
local Menu = {}

local EquipSlot = {
	["INVTYPE_CHEST"] =		"Chest",
	["INVTYPE_ROBE"] =		"Chest",
	["INVTYPE_FEET"] =		"Boots",
	["INVTYPE_WRIST"] =		"Bracer",
	["INVTYPE_HAND"] =		"Gloves",
	["INVTYPE_FINGER"] =		"Ring",
	["INVTYPE_CLOAK"] =		"Cloak",
	["INVTYPE_WEAPON"] =		"Weapon",
	["INVTYPE_SHIELD"] =		"Shield",
	["INVTYPE_2HWEAPON"] =		"2H Weapon",
	["INVTYPE_WEAPONMAINHAND"] =	"Weapon",
	["INVTYPE_WEAPONOFFHAND"] =	"Weapon"						 
}

local Professions = {
	[GetSpellInfo(2259)] = false, -- Alchemy
	[GetSpellInfo(2018)] = false, -- Blacksmithing
	[GetSpellInfo(2550)] = false, -- Cooking
	[GetSpellInfo(7411)] = false, -- Enchanting
	[GetSpellInfo(4036)] = false, -- Engineering
	[GetSpellInfo(746)] = false, -- First Aid
	[GetSpellInfo(2108)] = false, -- Leatherworking
	[GetSpellInfo(2575)] = false, -- Smelting
	[GetSpellInfo(3908)] = false, -- Tailoring
	[GetSpellInfo(25229)] = false, -- Jewelcrafting
	[GetSpellInfo(45357)] = false, -- Inscription
	[GetSpellInfo(53428)] = false, -- Runeforging
}

-------------------------------------------------------------------------------
-- Hooked functions
-------------------------------------------------------------------------------
local oldPaperDollItemSlotButton_OnModifiedClick = PaperDollItemSlotButton_OnModifiedClick
local oldHandleModifiedItemClick = HandleModifiedItemClick
local oldContainerFrameItemButton_OnModifiedClick = ContainerFrameItemButton_OnModifiedClick

function PaperDollItemSlotButton_OnModifiedClick(...)
	local self, button = ...
	if IsAltKeyDown() and (button == "LeftButton") then
		isHandled = true
		Revelation:Menu(self, GetInventoryItemLink("player", self:GetID()))
	else
		oldPaperDollItemSlotButton_OnModifiedClick(...)
	end
	isHandled = false
end

function ContainerFrameItemButton_OnModifiedClick(...)
	local self, button = ...
	if IsAltKeyDown() and (button == "LeftButton") then
		isHandled = true
		Revelation:Menu(self, GetContainerItemLink(self:GetParent():GetID(), self:GetID()))
	end
	oldContainerFrameItemButton_OnModifiedClick(...)
	isHandled = false
end

-- This hook is required as it is the only way to reference TradeRecipientItem7ItemButton
-- A.K.A.: "Will not be traded"
function HandleModifiedItemClick(...)
	if isHandled == false then
		Revelation:Menu(nil, ...)
	end
	return oldHandleModifiedItemClick(...)
end
getglobal("TradeRecipientItem7ItemButton"):RegisterForClicks("AnyUp")

-------------------------------------------------------------------------------
-- Local functions
-------------------------------------------------------------------------------
local function IsValidFrame(frame)
	local frameName = frame:GetName()

	if (frameName == nil) then return false end
	if (strfind(frameName, "Container") ~= nil) then return true end
	if (strfind(frameName, "TradeRecipient") ~= nil) then return true end
	if (strfind(frameName, "Slot") ~= nil) then return true end
	if (strfind(frameName, "BagginsBag") ~= nil) then return true end
	if (strfind(frameName, "BagnonBag") ~= nil) then return true end
	return false
end

function Menu:Add(text, func, name, skillIndex, numAvailable)
	local hasArrow = false
	local subMenu = {}

	if (numAvailable ~= nil) and (numAvailable >= 2) then
		hasArrow = true

		tinsert(subMenu,
			{
				text = "All",
				func = function() DoTradeSkill(skillIndex, numAvailable) dewdrop:Close() end,
				tooltipText = "Create every "..text.." you have reagents for."
			})

		local max = math.min(numAvailable, 10)

		for i = 1, max do
			tinsert(subMenu,
				{
					text = i,
					func = function() DoTradeSkill(skillIndex, i) dewdrop:Close() end,
					tooltipText = "Create "..i.." of: "..text.."."
				})
		end

		if (numAvailable > 15) then
			for i = 15, numAvailable, 5 do
				tinsert(subMenu,
					{
						text = i,
						func = function() DoTradeSkill(skillIndex, i) dewdrop:Close() end,
						tooltipText = "Create "..i.." of: "..text.."."
					})
			end
		end
	end

	if (self.data == nil) or (self.data[name] == nil) then self.data = {[name] = {}} end

	tinsert(self.data[name],
		{
			text = text,
			func = func,
			hasArrow = hasArrow,
			tooltipText = GetTradeSkillDescription(skillIndex),
			subMenu = subMenu
		})
end

local function IsReagent(item, recipe)
	local num = GetTradeSkillNumReagents(recipe)

	for reagent = 1, num do
		if item == GetTradeSkillReagentInfo(recipe, reagent) then return true end
	end
	return false
end

local function IterTrade(skillNum, reference, skillName, numAvailable, single)
	local retval

	if ((numAvailable >= 1)
	    and (IsReagent(reference, skillNum)
		 or (skillName == "Transmute: Primal Might"))) then
		retval = reference

		local func = function() DoTradeSkill(skillNum, 1) dewdrop:Close() end

		if single then
			Menu:Add(skillName, func, reference, skillNum, 1)
		else
			Menu:Add(skillName, func, reference, skillNum, numAvailable)
		end
	end
	return retval
end

local function IterEnchant(skillNum, reference, skillName, numAvailable, single)
	local hyphen = strfind(skillName, "-")
	local retval

	if (hyphen ~= nil) and (numAvailable >= 1) then
		local enchantType = strsub(skillName, 9, hyphen - 2)
		local equipRef = EquipSlot[reference]
		if strfind(enchantType, equipRef) then
			retval = enchantType
			Menu:Add(skillName, function() DoTradeSkill(skillNum, 1) dewdrop:Close() end, enchantType, skillNum)
		end
	end
	return retval
end

local function Scan(tradeSkill, reference, single)
	CastSpellByName(tradeSkill)

	if (ATSW_SkipSlowScan ~= nil) then ATSW_SkipSlowScan() end

	local func = IterTrade

	if (tradeSkill == GetSpellInfo(7411)) and EquipSlot[reference] then
		func = IterEnchant
	end

	local found
	local numSkills = GetNumTradeSkills()

	for i = 1, numSkills do
		local skillName, _, numAvailable, _ = GetTradeSkillInfo(i)
		local retval = func(i, reference, skillName, numAvailable, single)

		if (retval ~= nil) then
			if Recipes["Nothing"] then
				Recipes = {}
			end
			Recipes[retval] = {
				text = retval,
				func = function() end,
				hasArrow = true,
				subMenu = Menu.data[retval]
			}
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
function Revelation:Menu(focus, item)
	if (item == nil) then return end
	if (focus == nil) then
		if not IsAltKeyDown() then return end	-- Enforce for HandleModifiedItemClick
		focus = GetMouseFocus()
	end
	if not IsValidFrame(focus) then	return end

	Menu.data = nil
	Recipes = {
		["Nothing"] = {
			text = "Either no recipe or no reagents were found.",
			func = function() dewdrop:Close() end,
			hasArrow = false
		}
	}
	GetKnown(Professions)

	local itemName, _, itemRarity, _, _, itemType, itemSubType, _, itemEquipLoc, _ = GetItemInfo(item)

	if (itemType == "Armor") or (itemType == "Weapon") then
		local ench = GetSpellInfo(7411)
		if (Professions[ench] == false) then return end
		Scan(ench, itemEquipLoc, true)
	else
		for key, val in pairs(Professions) do
			if val == true then Scan(key, itemName)	end
		end
	end
	dewdrop:Open(focus, 'children', function() dewdrop:FeedTable(Recipes) end)
end