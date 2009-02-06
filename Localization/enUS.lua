-- English localization file for enUS and enGB.
local AceLocale = LibStub:GetLibrary("AceLocale-3.0")

local dev = false
--@debug@
dev = true
--@end-debug@

local L = AceLocale:NewLocale("Revelation", "enUS", true, dev)
if not L then return end

--@localization(locale="enUS", format="lua_additive_table", table_name="L", same-key-is-true=true)@