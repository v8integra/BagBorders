local ADDON_NAME, BB = ...

-- Neutral cycling palette for general bags, assigned in bag-setup order.
local GENERAL_PALETTE = {
    { r = 0.55, g = 0.55, b = 0.60 }, -- slate
    { r = 0.60, g = 0.52, b = 0.40 }, -- tan
    { r = 0.45, g = 0.55, b = 0.55 }, -- teal-gray
    { r = 0.58, g = 0.48, b = 0.55 }, -- mauve
}

-- Fixed color for special bags (quiver/ammo pouch), independent of slot position.
local SPECIAL_COLOR = { r = 0.85, g = 0.65, b = 0.15 } -- amber

-- bagFamily bit flags for Quiver (1) and Ammo Pouch (2).
local SPECIAL_BAG_FAMILY_MASK = 0x3

local BORDER_TEXTURE = [[Interface\Common\WhiteIconFrame]]

local bagColors = {}
local nextPaletteIndex = 1

local function GetColorForBag(bagID, bagFamily)
    local color = bagColors[bagID]
    if color then
        return color
    end

    if bagFamily and bagFamily ~= 0 and bit.band(bagFamily, SPECIAL_BAG_FAMILY_MASK) ~= 0 then
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
        border:SetPoint("TOPLEFT", itemButton, "TOPLEFT", 0, 0)
        border:SetPoint("BOTTOMRIGHT", itemButton, "BOTTOMRIGHT", 0, 0)
        itemButton.BagBordersBorder = border
    end
    return border
end

local function ColorItemButton(itemButton)
    local bagID = itemButton:GetBagID()
    if not bagID then
        return
    end

    local _, bagFamily = C_Container.GetContainerNumFreeSlots(bagID)
    local color = GetColorForBag(bagID, bagFamily)

    local border = GetOrCreateBorder(itemButton)
    border:SetVertexColor(color.r, color.g, color.b, 1)
    border:Show()
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
    for _, itemButton in combinedFrame:EnumerateValidItems() do
        if itemButton then
            seen = seen + 1
            local ok, err = pcall(ColorItemButton, itemButton)
            if ok then
                colored = colored + 1
            elseif BB.debug then
                print("|cffff4444BagBorders error:|r " .. tostring(err))
            end
        end
    end

    if BB.debug then
        print(("|cff44ff44BagBorders:|r saw %d item buttons, colored %d"):format(seen, colored))
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
    else
        print("BagBorders: /bagborders debug | /bagborders refresh")
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    local ok1, err1 = pcall(hooksecurefunc, ContainerFrameCombinedBagsMixin, "Update", RefreshCombinedBagColors)
    local ok2, err2 = pcall(hooksecurefunc, ContainerFrameMixin, "UpdateItemSlots", function(frame)
        if frame:IsCombinedBagContainer() then
            RefreshCombinedBagColors()
        end
    end)

    if not ok1 then
        print("|cffff4444BagBorders:|r failed to hook ContainerFrameCombinedBagsMixin.Update - " .. tostring(err1))
    end
    if not ok2 then
        print("|cffff4444BagBorders:|r failed to hook ContainerFrameMixin.UpdateItemSlots - " .. tostring(err2))
    end
end)
