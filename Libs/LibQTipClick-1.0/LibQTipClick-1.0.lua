assert(LibStub, "LibQTipClick-1.0 requires LibStub")

local MAJOR, MINOR = "LibQTipClick-1.0", 1
local LibQTipClick, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not LibQTipClick then return end -- No upgrade needed

local LibQTip = LibStub:GetLibrary("LibQTip-1.0")

assert(LibQTip, "LibQTipClick-1.0 requires LibQTip-1.0")

-------------------------------------------------------------------------------
-- Local variables
-------------------------------------------------------------------------------
LibQTipClick.LabelProvider, LibQTipClick.LabelPrototype, LibQTipClick.BaseProvider = LibQTip:CreateCellProvider(LibQTip.LabelProvider)

local cProvider, cPrototype, cBase = LibQTipClick.LabelProvider, LibQTipClick.LabelPrototype, LibQTipClick.BaseProvider

LibQTipClick.callbacks = LibQTipClick.callbacks or {} 
local callbacks = LibQTipClick.callbacks

-------------------------------------------------------------------------------
-- Public library API
-------------------------------------------------------------------------------
LibQTipClick.cellFunctions = {
	OnEnter = function(self)
			  if not self.highlight then
				  self.highlight = self:CreateTexture(nil, "BACKGROUND")
				  self.highlight:Hide()
			  end
			  self.highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
			  self.highlight:SetBlendMode("ADD")
			  self.highlight:SetAllPoints(self)
			  self.highlight:Show()
		  end,
	OnLeave = function(self)
			  self.highlight:ClearAllPoints()
			  self.highlight:Hide()
		  end,
	OnMouseDown = function(self)
			      DEFAULT_CHAT_FRAME:AddMessage("LibQTipClick: No function defined.")
		      end,
}
local cellFunctions = LibQTipClick.cellFunctions

local function Cell_Handler(cell, event, ...)
	local callback = cell.callbacks[event]
	if callback then
	        local success, result = pcall(callback, cell, cell.arg, event, ...)
	        if not success then
			geterrorhandler()(result)
	        end
	end
end

local function Cell_OnEnter(cell, ...) Cell_Handler(cell, "OnEnter", ...) end
local function Cell_OnLeave(cell, ...) Cell_Handler(cell, "OnLeave", ...) end
local function Cell_OnMouseDown(cell, ...) Cell_Handler(cell, "OnMouseDown", ...) end

function cPrototype:InitializeCell()
	cBase.InitializeCell(self)
end

function cPrototype:SetupCell(tooltip, value, justification, font, arg)
	local width, height = cBase.SetupCell(self, tooltip, value, justification, font, arg)

	self:EnableMouse(true)
	self.arg = arg
	self.callbacks = callbacks[tooltip.key]
	self:SetScript("OnEnter", Cell_OnEnter)
	self:SetScript("OnLeave", Cell_OnLeave)
	self:SetScript("OnMouseDown", Cell_OnMouseDown)

	return width, height
end

function cPrototype:ReleaseCell()
	self:EnableMouse(false)
	self:SetScript("OnEnter", nil)
	self:SetScript("OnLeave", nil)
	self:SetScript("OnMouseDown", nil)
	self.callbacks = nil
	self.arg = nil
end

-------------------------------------------------------------------------------
-- LibQTip wrapper API
-------------------------------------------------------------------------------
local function SetCallback(tooltip, event, callback)
	callbacks[tooltip.key][event] = callback
end

local function AddNormalLine(tooltip, ...)
	local oldProvider = tooltip:GetDefaultProvider()
	tooltip:SetDefaultProvider(LibQTip.LabelProvider)
	tooltip:AddLine(...)
	tooltip:SetDefaultProvider(oldProvider)
end

local function AddNormalHeader(tooltip, ...)
	local oldProvider = tooltip:GetDefaultProvider()
	tooltip:SetDefaultProvider(LibQTip.LabelProvider)
	tooltip:AddHeader(...)
	tooltip:SetDefaultProvider(oldProvider)
end

function LibQTipClick:Acquire(key, ...)
	local tooltip = LibQTip:Acquire(key, ...)

	tooltip:EnableMouse(true)
	if not callbacks[key] then
	        callbacks[key] = {}
	end
	callbacks[key].OnEnter = cellFunctions.OnEnter
	callbacks[key].OnLeave = cellFunctions.OnLeave
	callbacks[key].OnMouseDown = cellFunctions.OnMouseDown
	tooltip.SetCallback = SetCallback
	tooltip.AddNormalLine = AddNormalLine
	tooltip.AddNormalHeader = AddNormalHeader
	tooltip:SetDefaultProvider(cProvider)

	return tooltip
end

function LibQTipClick:IsAcquired(key)
	return LibQTip:IsAcquired(key)
end

function LibQTipClick:Release(tooltip)
	tooltip:EnableMouse(false)
	wipe(callbacks[tooltip.key]) 
	tooltip.SetCallback = nil
	LibQTip:Release(tooltip)
end

function LibQTipClick:IterateTooltips()
	return LibQTip:IterateTooltips()
end

function LibQTipClick:CreateCellProvider(baseProvider)
	return LibQTip:CreateCellProvider(baseProvider)
end