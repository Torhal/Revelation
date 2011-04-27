-------------------------------------------------------------------------------
-- AddOn namespace
-------------------------------------------------------------------------------
local ADDON_NAME, private = ...


-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------
local CAN_PROSPECT

-------------------------------------------------------------------------------
-- Functions.
-------------------------------------------------------------------------------
function private.CanProspect()
	if not CAN_PROSPECT then
		CAN_PROSPECT = {
			[2770]	= true,	-- Copper Ore
			[2771]	= true,	-- Tin Ore
			[2772]	= true,	-- Iron Ore
			[3858]	= true,	-- Mithril Ore
			[10620]	= true,	-- Thorium Ore
			[23452]	= true,	-- Adamantite Ore
			[23424]	= true,	-- Fel Iron Ore
			[36909]	= true,	-- Cobalt Ore
			[36910]	= true,	-- Titanium Ore
			[36912]	= true,	-- Saronite Ore
		}
	end

	local id = select(3, private.cur_item.link:find("item:(%d+):"))

	if not id or (id and not CAN_PROSPECT[tonumber(id)]) then
		return false
	end
	return true
end
