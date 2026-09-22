local ADDON_NAME, BB = ...

-- Cycling palette for general bags, assigned in bag-setup order. Saturated and
-- blended with ADD so they read clearly against the dark item-slot background.
local GENERAL_PALETTE = {
    { r = 0.20, g = 0.75, b = 0.95 }, -- cyan
    { r = 0.95, g = 0.55, b = 0.10 }, -- orange
    { r = 0.35, g = 0.90, b = 0.35 }, -- green
    { r = 0.75, g = 0.40, b = 0.95 }, -- violet
}

-- Fixed color for special bags (quiver/ammo pouch), independent of slot position.
local SPECIAL_COLOR = { r = 1.00, g = 0.85, b = 0.10 } -- gold

-- bagFamily bit flags for Quiver (1) and Ammo Pouch (2).
local SPECIAL_BAG_FAMILY_MASK = 0x3

local BORDER_TEXTURE = [[Interface\Common\WhiteIconFrame]]

local function IsSpecialBagFamily(bagFamily)
    return bagFamily and bagFamily ~= 0 and bit.band(bagFamily, SPECIAL_BAG_FAMILY_MASK) ~= 0
end

-- Shared with other modules (e.g. Modules/BagBar.lua) so special-bag detection
-- and its color stay defined in exactly one place.
BB.IsSpecialBagFamily = IsSpecialBagFamily
BB.SPECIAL_COLOR = SPECIAL_COLOR

local bagColors = {}
local nextPaletteIndex = 1

local function GetColorForBag(bagID, bagFamily)
    local color = bagColors[bagID]
    if color then
        return color
    end

    if IsSpecialBagFamily(bagFamily) then
        color = SPECIAL_COLOR
    else
        color = GENERAL_PALETTE[((nextPaletteIndex - 1) % #GENERAL_PALETTE) + 1]
        nextPaletteIndex = nextPaletteIndex + 1
    end

    bagColors[bagID] = color
    return color
end

local function GetOrCreateBorder(itemButton)
    local border = itemButton.BagBordersBorder
    if not border then
        border = itemButton:CreateTexture(nil, "OVERLAY", nil, 0)
        border:SetTexture(BORDER_TEXTURE)
        border:SetBlendMode("ADD")
        border:SetPoint("TOPLEFT", itemButton, "TOPLEFT", 0, 0)
        border:SetPoint("BOTTOMRIGHT", itemButton, "BOTTOMRIGHT", 0, 0)
        itemButton.BagBordersBorder = border
    end
    return border
end

local function GetOrCreateFreeSlotLabel(itemButton)
    local label = itemButton.BagBordersFreeLabel
    if not label then
        label = itemButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPRIGHT", itemButton, "TOPRIGHT", -1, -1)
        label:SetJustifyH("RIGHT")
        itemButton.BagBordersFreeLabel = label
    end
    return label
end

local function ColorItemButton(itemButton)
    local bagID = itemButton:GetBagID()
    if not bagID then
        return nil
    end

    local numFreeSlots, bagFamily = C_Container.GetContainerNumFreeSlots(bagID)
    local color = GetColorForBag(bagID, bagFamily)

    local border = GetOrCreateBorder(itemButton)
    border:SetVertexColor(color.r, color.g, color.b, 1)
    border:Show()

    return bagID, color, numFreeSlots
end

local function RefreshCombinedBagColors()
    local combinedFrame = ContainerFrameCombinedBags
    if not combinedFrame or not combinedFrame:IsShown() then
        return
    end
    if not ContainerFrameSettingsManager or not ContainerFrameSettingsManager:IsUsingCombinedBags() then
        return
    end

    wipe(bagColors)
    nextPaletteIndex = 1

    local seen, colored = 0, 0
    local bagSlotCounts, bagColorNames = {}, {}
    local labeledBags = {}
    for _, itemButton in combinedFrame:EnumerateValidItems() do
        if itemButton then
            seen = seen + 1
            if itemButton.BagBordersFreeLabel then
                itemButton.BagBordersFreeLabel:Hide()
            end

            local ok, resultBagID, resultColor, resultFreeSlots = pcall(ColorItemButton, itemButton)
            if ok then
                if resultBagID then
                    colored = colored + 1
                    bagSlotCounts[resultBagID] = (bagSlotCounts[resultBagID] or 0) + 1
                    if resultColor then
                        bagColorNames[resultBagID] = string.format("%.2f/%.2f/%.2f", resultColor.r, resultColor.g, resultColor.b)
                    end

                    if not labeledBags[resultBagID] then
                        labeledBags[resultBagID] = true
                        local label = GetOrCreateFreeSlotLabel(itemButton)
                        label:SetText(("(%d)"):format(resultFreeSlots or 0))
                        label:SetTextColor(resultColor.r, resultColor.g, resultColor.b)
                        label:Show()
                    end
                end
            elseif BB.debug then
                print("|cffff4444BagBorders error:|r " .. tostring(resultBagID))
            end
        end
    end

    if BB.debug then
        print(("|cff44ff44BagBorders:|r saw %d item buttons, colored %d"):format(seen, colored))
        local bagIDs = {}
        for bagID in pairs(bagSlotCounts) do
            table.insert(bagIDs, bagID)
        end
        table.sort(bagIDs)
        for _, bagID in ipairs(bagIDs) do
            print(("  bag %d: %d slots, color %s"):format(bagID, bagSlotCounts[bagID], bagColorNames[bagID] or "?"))
        end
    end
end

BB.RefreshCombinedBagColors = RefreshCombinedBagColors

SLASH_BAGBORDERS1 = "/bagborders"
SlashCmdList["BAGBORDERS"] = function(msg)
    if msg == "debug" then
        BB.debug = not BB.debug
        print("BagBorders debug: " .. (BB.debug and "on" or "off"))
    elseif msg == "refresh" then
        RefreshCombinedBagColors()
        if BB.RefreshBagBar then
            BB.RefreshBagBar()
        end
        if BB.RefreshReagentPanel then
            BB.RefreshReagentPanel()
        end
    else
        print("BagBorders: /bagborders debug | /bagborders refresh")
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    -- Hook the frame INSTANCE, not the mixin table: ContainerFrameCombinedBags is a
    -- static XML frame whose mixin="ContainerFrameCombinedBagsMixin" attribute copies
    -- Update/UpdateItemSlots onto the instance at load time, long before this addon
    -- runs. Hooking the mixin table afterward only patches that table's own copy and
    -- never affects the frame's already-copied reference.
    local ok1, err1 = pcall(hooksecurefunc, ContainerFrameCombinedBags, "Update", RefreshCombinedBagColors)
    local ok2, err2 = pcall(hooksecurefunc, ContainerFrameCombinedBags, "UpdateItemSlots", RefreshCombinedBagColors)

    if not ok1 then
        print("|cffff4444BagBorders:|r failed to hook ContainerFrameCombinedBags.Update - " .. tostring(err1))
    end
    if not ok2 then
        print("|cffff4444BagBorders:|r failed to hook ContainerFrameCombinedBags.UpdateItemSlots - " .. tostring(err2))
    end
end)
