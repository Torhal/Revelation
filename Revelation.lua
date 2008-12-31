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
		isHandled = false
	else
		oldPaperDollItemSlotButton_OnModifiedClick(...)
	end
end

function ContainerFrameItemButton_OnModifiedClick(...)
	local self, button = ...
	if IsAltKeyDown() and (button == "LeftButton") then
		isHandled = true
		Revelation:Menu(self, GetContainerItemLink(self:GetParent():GetID(), self:GetID()))
		isHandled = false
	end
	oldContainerFrameItemButton_OnModifiedClick(...)
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
function IsValidFrame(frame)
	local frameName = frame:GetName()

	if (frameName == nil) then return false end
	if (strfind(frameName, "Container") ~= nil) then return true end
	if (strfind(frameName, "TradeRecipient") ~= nil) then return true end
	if (strfind(frameName, "Slot") ~= nil) then return true end
	if (strfind(frameName, "BagginsBag") ~= nil) then return true end
	if (strfind(frameName, "BagnonBag") ~= nil) then return true end
	return false
end

local function SetDefaults()
	Menu.data = nil
	Recipes = {
		["Nothing"] = {
			text = "Either no recipe or no reagents were found.",
			func = function() dewdrop:Close() end,
			hasArrow = false
		}
	}
end

function Menu:Add(text, func, name, skillIndex, numAvailable)
	local hasArrow = false
	local sMenu = {}

	if (self.data == nil) then self.data = {[name] = {}} end

	if (numAvailable ~= nil) and (numAvailable >= 2) then
		hasArrow = true

		table.insert(sMenu, {text = "All", func = function() DoTradeSkill(skillIndex, numAvailable) dewdrop:Close() end})

		local max = math.min(numAvailable, 20)

		for i = 1, max do
			table.insert(sMenu, {text = i, func = function() DoTradeSkill(skillIndex, i) dewdrop:Close() end})
		end

		if (numAvailable > 25) then
			for i = 25, numAvailable, 5 do
				table.insert(sMenu, {text = i, func = function() DoTradeSkill(skillIndex, i) dewdrop:Close() end})
			end
		end
	end
	table.insert(self.data[name], {text = text, func = func, hasArrow = hasArrow, subMenu = sMenu})
end

function Menu:Parent(name)
	Recipes = {
		[name] = {
			text = name,
			func = function() end,
			hasArrow = true,
			subMenu = self.data[name]
		}
	}
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
		if strfind(enchantType, EquipSlot[reference]) then
			retval = enchantType
			Menu:Add(skillName, function() DoTradeSkill(skillNum, 1) dewdrop:Close() end, enchantType, skillNum)
		end
	end
	return retval
end

local function Scan(tradeSkill, reference, single)
	CastSpellByName(tradeSkill)

	if (ATSW_SkipSlowScan ~= nil) then ATSW_SkipSlowScan() end

	local func

	if (tradeSkill == "Enchanting") and EquipSlot[reference] then
		func = IterEnchant
	else
		func = IterTrade
	end

	local found
	local numSkills = GetNumTradeSkills()

	for i = 1, numSkills do
		local skillName, _, numAvailable, _ = GetTradeSkillInfo(i)
		local retval = func(i, reference, skillName, numAvailable, single)

		if (found == nil) then found = retval end
	end

	if (found ~= nil) then Menu:Parent(found) end
	CloseTradeSkill()
end

-------------------------------------------------------------------------------
-- Main AddOn functions
-------------------------------------------------------------------------------
function Revelation:Menu(focus, item)
	if (item == nil) then return end
	if (focus == nil) then
		if not AltKeyIsDown() then return end	-- Enforce for HandleModifiedItemClick
		focus = GetMouseFocus()
	end
	if not IsValidFrame(focus) then	return end
	SetDefaults()

	local itemName, _, itemRarity, _, _, itemType, itemSubType, _, itemEquipLoc, _ = GetItemInfo(item)

	if (itemType == "Armor") or (itemType == "Weapon") then
		Scan("Enchanting", itemEquipLoc, true)
	elseif (itemType == "Gem") then
		Scan("Jewelcrafting", itemName)
	elseif (itemType == "Trade Goods") then
		if (itemSubType == "Cloth") then
			-- Check rarity for things like Spellcloth and Primal Mooncloth
			if ((strsub(itemName, -6) == "Thread") or (strsub(itemName, 1, 4) == "Bolt") or
			    (itemRarity >= 3)) then
				Scan("Tailoring", itemName)
			else
				Scan("Tailoring", itemName)
--				Scan("First Aid", itemName)
			end
		elseif (itemSubType == "Devices") or (itemSubType == "Explosives") then
			Scan("Engineering", itemName)
		elseif (itemSubType == "Herb") or ((itemSubType == "Elemental") and (strsub(itemName, 1, 6) == "Primal")) then
			Scan("Alchemy", itemName)
		elseif (itemSubType == "Enchanting") then
			Scan("Enchanting", itemName, true)
		elseif (itemType == "Jewelcrafting") then
			Scan("Jewelcrafting", itemName)
		elseif (itemSubType == "Leather") then
			Scan("Leatherworking", itemName)
		elseif (itemSubType == "Meat") then
			Scan("Cooking", itemName)
		elseif (itemSubType == "Metal & Stone") then
			if (strsub(itemName, -3) == "Bar") then
				Scan("Blacksmithing", itemName)
			elseif (strsub(itemName, -3) == "Ore") then
				Scan("Smelting", itemName)
			end
		elseif (itemSubType == "Other") then
			if (strsub(itemName, -9) == "Parchment") then
				Scan("Inscription", itemName)
			elseif (strsub(itemName, -7) == "Pigment") then
				Scan("Inscription", itemName)
			elseif (strsub(itemName, -6) == "Spices") then
				Scan("Cooking", itemName)
			elseif (strsub(itemName, -4) == "Vial") then
				Scan("Alchemy", itemName)
			end
		elseif (itemSubType == "Parts") then
			if (strsub(itemName, 1, 3) == "Ink") or (strsub(itemName, -3) == "Ink") then
				Scan("Inscription", itemName)
			else
				Scan("Engineering", itemName)
			end
		end

	end
	dewdrop:Open(focus, 'children', function() dewdrop:FeedTable(Recipes) end)
end