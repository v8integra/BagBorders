local ADDON_NAME, BB = ...

-- On-screen text. Code looks text up by its English wording, L["Sort"], and
-- gets the English back when there's no translation, so English needs no table.
--
-- To translate, add a file like Locales/deDE.lua after this one in the TOC:
--
--   local _, BB = ...
--   if GetLocale() ~= "deDE" then return end
--   local L = BB.L
--   L["Sort"] = "Sortieren"
--   L["%d free"] = "%d frei"
--
-- Keep any %d / %s in the same order as the English. Text the game already
-- translates (BANK, KEYRING, BAG_CLEANUP_BANK...) comes from Blizzard's own
-- globals and isn't listed here.

BB.L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
