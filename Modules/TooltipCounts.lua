local ADDON_NAME, BB = ...
local L = BB.L

-- Adds "how many of this do my characters have" lines to item tooltips, from
-- the saved character data (Data/Characters.lua):
--
--   Altname        Bags 12, Bank 40
--   Account bank   5
--
-- Hooked through Blizzard's TooltipDataProcessor, which runs addon callbacks
-- insecurely on purpose, so Blizzard's tooltip code stays untainted. Counts are
-- worked out once per item and kept until the saved data changes.

local counts = {}       -- itemID -> { lines = {...}, total = n }
local countsVersion = -1

local function CountIn(sections, itemID)
    local n = 0
    for _, section in ipairs(sections or {}) do
        for _, item in pairs(section.items or {}) do
            if item[1] == itemID then
                n = n + (item[3] or 1)
            end
        end
    end
    return n
end

local function ClassColorCode(class)
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return color and color.colorStr and ("|c" .. color.colorStr) or "|cffffffff"
end

local function BuildCounts(itemID)
    local lines = {}
    local total = 0
    for _, character in ipairs(BB.GetCachedCharacters()) do
        local entry = character.entry
        local bags = CountIn(entry.bags, itemID)
        local bank = CountIn(entry.bank, itemID)
        if bags + bank > 0 then
            local parts = {}
            if bags > 0 then
                table.insert(parts, L["Bags %d"]:format(bags))
            end
            if bank > 0 then
                table.insert(parts, L["Bank %d"]:format(bank))
            end
            local name = entry.name or character.key
            if entry.realm and entry.realm ~= GetRealmName() then
                name = name .. "-" .. entry.realm
            end
            table.insert(lines, { ClassColorCode(entry.class) .. name .. "|r", table.concat(parts, ", ") })
            total = total + bags + bank
        end
    end
    local account = BagBordersDB.accountBank
    local accountCount = account and CountIn(account.tabs, itemID) or 0
    if accountCount > 0 then
        table.insert(lines, { L["Account bank"], tostring(accountCount) })
        total = total + accountCount
    end
    return { lines = lines, total = total }
end

local function GetCounts(itemID)
    if countsVersion ~= BB.cacheVersion then
        wipe(counts)
        countsVersion = BB.cacheVersion
    end
    local result = counts[itemID]
    if not result then
        result = BuildCounts(itemID)
        counts[itemID] = result
    end
    return result
end

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function OnItemTooltip(tooltip, data)
    if not BB.db.settings.tooltipCounts or not data or not BB.playerKey then
        return
    end
    -- Only Blizzard's main tooltips (not comparison/shopping ones), and never
    -- anything the game marks secret.
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then
        return
    end
    local itemID = data.id
    if IsSecret(itemID) or type(itemID) ~= "number" then
        return
    end

    local result = GetCounts(itemID)
    if #result.lines == 0 then
        return
    end
    tooltip:AddLine(" ")
    for _, line in ipairs(result.lines) do
        tooltip:AddDoubleLine(line[1], line[2], 1, 1, 1, 1, 1, 1)
    end
    if #result.lines > 1 then
        tooltip:AddDoubleLine(L["Total"], tostring(result.total), 1, 0.82, 0, 1, 0.82, 0)
    end
end

BB.GetItemCounts = GetCounts

BB:OnDBReady(function()
    if TooltipDataProcessor and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            local ok, err = pcall(OnItemTooltip, tooltip, data)
            if not ok and BB.debug then
                print("|cffff4444BagBorders error (tooltip):|r " .. tostring(err))
            end
        end)
    end
end)
