local ADDON_NAME, BB = ...

-- Item level on gear (weapons and armor, including rings/necks/trinkets) in the
-- BagBorders bag and bank windows, tinted by item quality. Only our own buttons
-- get the label; Blizzard's buttons are never touched.

local WEAPON = Enum.ItemClass and Enum.ItemClass.Weapon or 2
local ARMOR = Enum.ItemClass and Enum.ItemClass.Armor or 4

-- Equip slots that aren't worth an item level (shirts, tabards, cosmetics).
local SKIP_EQUIP_LOC = {
    [""] = true,
    INVTYPE_NON_EQUIP_IGNORE = true,
    INVTYPE_BODY = true,
    INVTYPE_TABARD = true,
}

local function GetLabel(button)
    local label = button.BagBordersItemLevel
    if not label then
        label = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        label:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
        label:SetJustifyH("LEFT")
        button.BagBordersItemLevel = label
    end
    return label
end

local function GetGearItemLevel(bagID, slot, info)
    if not info or not info.itemID then
        return nil
    end
    local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(info.itemID)
    if (classID ~= WEAPON and classID ~= ARMOR) or SKIP_EQUIP_LOC[equipLoc or ""] then
        return nil
    end
    local level = C_Item.GetCurrentItemLevel(ItemLocation:CreateFromBagAndSlot(bagID, slot))
    if level and level > 1 then
        return level
    end
    return nil
end

-- info is the C_Container.GetContainerItemInfo table for that slot (or nil).
function BB.UpdateItemLevel(button, bagID, slot, info)
    local level = BB.db.settings.itemLevel and GetGearItemLevel(bagID, slot, info)
    if not level then
        if button.BagBordersItemLevel then
            button.BagBordersItemLevel:Hide()
        end
        return
    end

    local label = GetLabel(button)
    label:SetText(level)
    local r, g, b = 1, 1, 1
    if info.quality and C_Item.GetItemQualityColor then
        r, g, b = C_Item.GetItemQualityColor(info.quality)
    end
    label:SetTextColor(r, g, b)
    label:Show()
end
