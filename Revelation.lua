-------------------------------------------------------------------------------
-- Localized globals
-------------------------------------------------------------------------------
local _G = getfenv(0)
local strfind, strsub, tinsert = _G.string.find, _G.string.sub, _G.table.insert

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------
local EquipSlot = {
	["INVTYPE_CHEST"]		= "Chest",
	["INVTYPE_ROBE"]		= "Chest",
	["INVTYPE_FEET"]		= "Boots",
	["INVTYPE_WRIST"]		= {"Bracer", "Bracers"},
	["INVTYPE_HAND"]		= "Gloves",
	["INVTYPE_FINGER"]		= "Ring",
	["INVTYPE_CLOAK"]		= "Cloak",
	["INVTYPE_WEAPON"]		= "Weapon",
	["INVTYPE_SHIELD"]		= "Shield",
	["INVTYPE_2HWEAPON"]		= "2H Weapon",
	["INVTYPE_WEAPONMAINHAND"]	= "Weapon",
	["INVTYPE_WEAPONOFFHAND"]	= "Weapon"
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
local subMenu = {}
local valNames = {}

-------------------------------------------------------------------------------
-- AddOn namespace
-------------------------------------------------------------------------------
local dewdrop = AceLibrary("Dewdrop-2.0")
local AceAddon = LibStub("AceAddon-3.0")
Revelation = AceAddon:NewAddon("Revelation", "AceHook-3.0")

-------------------------------------------------------------------------------
-- Local functions
-------------------------------------------------------------------------------
local function SetTradeSkill(tradeSkill)
	CastSpellByName(tradeSkill)
	CloseTradeSkill()
end

local function AddRecipe(tradeSkill, text, func, skillIndex, numAvailable)
	local hasArrow = false
	wipe(subMenu)

	if (numAvailable ~= nil) and (numAvailable > 1) then
		hasArrow = true
		tinsert(subMenu,
			{
				text = "All",
				func = function()
					       SetTradeSkill(tradeSkill)
					       DoTradeSkill(skillIndex, numAvailable)
					       dewdrop:Close()
				       end,
				tooltipText = "Create every "..text.." you have reagents for."
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
					tooltipText = "Create "..i.." of: "..text.."."
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
						tooltipText = "Create "..i.." of: "..text.."."
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
	local func = function()
			     SetTradeSkill(tradeSkill)
			     DoTradeSkill(skillNum, 1)
			     dewdrop:Close()
		     end

	AddRecipe(tradeSkill, skillName.color, func, skillNum, single and 1 or numAvailable)
end

local function IterEnchant(tradeSkill, skillNum, reference, skillName, numAvailable, single)
	local hyphen = strfind(skillName.normal, "-")
	if (hyphen == nil) or (numAvailable < 1) then return end

	local enchantType = strsub(skillName.normal, 9, hyphen - 2)
	local ref = EquipSlot[reference]
	local found = false

	if (type(ref) == "string") and (enchantType == ref) then
		found = true
	elseif type(ref) == "table" then
		for k, v in ipairs(ref) do
			if enchantType == v then
				found = true
				break
			end
		end
	end

	if not found then return end
	local func = function()
			     SetTradeSkill(tradeSkill)
			     DoTradeSkill(skillNum, 1)
			     dewdrop:Close()
		     end
	AddRecipe(tradeSkill, skillName.color, func, skillNum)
end

local function Scan(tradeSkill, reference, single)
	CastSpellByName(tradeSkill)
	if (ATSW_SkipSlowScan ~= nil) then ATSW_SkipSlowScan() end

	local func = IterTrade

	if (tradeSkill == GetSpellInfo(7411)) and EquipSlot[reference] then func = IterEnchant end

	for i = 1, GetNumTradeSkills() do
		local skillName, skillType, numAvailable, _ = GetTradeSkillInfo(i)
		if skillType ~= "header" then
			valNames = {
				["normal"] = skillName,
				["color"] = Difficulty[skillType]..skillName.."|r"
			}
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
getglobal("TradeRecipientItem7ItemButton"):RegisterForClicks("AnyUp")