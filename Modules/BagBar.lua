local ADDON_NAME, BB = ...

local GENERAL_LABEL_COLOR = { r = 1.00, g = 1.00, b = 1.00 } -- white
local REAGENT_LABEL_COLOR = { r = 0.30, g = 0.85, b = 0.75 } -- teal

local GENERAL_BAG_BUTTON_NAMES = {
    "CharacterBag0Slot",
    "CharacterBag1Slot",
    "CharacterBag2Slot",
    "CharacterBag3Slot",
}

local function GetOrCreateBarLabel(button)
    local label = button.BagBordersBarLabel
    if not label then
        label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
        label:SetJustifyH("RIGHT")
        button.BagBordersBarLabel = label
    end
    return label
end

local function RefreshBagBar()
    if not MainMenuBarBackpackButton then
        return
    end

    local generalFree = C_Container.GetContainerNumFreeSlots(Enum.BagIndex.Backpack) or 0

    for _, globalName in ipairs(GENERAL_BAG_BUTTON_NAMES) do
        local button = _G[globalName]
        if button then
            if button:HasBagEquipped() then
                local bagID = button:GetBagID()
                local numFreeSlots, bagFamily = C_Container.GetContainerNumFreeSlots(bagID)
                numFreeSlots = numFreeSlots or 0

                if BB.IsSpecialBagFamily(bagFamily) then
                    local label = GetOrCreateBarLabel(button)
                    label:SetText(("(%d)"):format(numFreeSlots))
                    label:SetTextColor(BB.SPECIAL_COLOR.r, BB.SPECIAL_COLOR.g, BB.SPECIAL_COLOR.b)
                    label:Show()
                else
                    generalFree = generalFree + numFreeSlots
                    if button.BagBordersBarLabel then
                        button.BagBordersBarLabel:Hide()
                    end
                end
            elseif button.BagBordersBarLabel then
                button.BagBordersBarLabel:Hide()
            end
        end
    end

    local backpackLabel = GetOrCreateBarLabel(MainMenuBarBackpackButton)
    backpackLabel:SetText(("(%d)"):format(generalFree))
    backpackLabel:SetTextColor(GENERAL_LABEL_COLOR.r, GENERAL_LABEL_COLOR.g, GENERAL_LABEL_COLOR.b)
    backpackLabel:Show()

    -- The reagent bag opens as its own independent window (not part of the
    -- combined view), so it always gets its own count on its own icon rather
    -- than folding into the backpack's general total.
    local reagentButton = CharacterReagentBag0Slot
    if reagentButton then
        if reagentButton:HasBagEquipped() then
            local numFreeSlots = C_Container.GetContainerNumFreeSlots(reagentButton:GetBagID()) or 0
            local label = GetOrCreateBarLabel(reagentButton)
            label:SetText(("(%d)"):format(numFreeSlots))
            label:SetTextColor(REAGENT_LABEL_COLOR.r, REAGENT_LABEL_COLOR.g, REAGENT_LABEL_COLOR.b)
            label:Show()
        elseif reagentButton.BagBordersBarLabel then
            reagentButton.BagBordersBarLabel:Hide()
        end
    end
end

BB.RefreshBagBar = RefreshBagBar

-- BAG_UPDATE_DELAYED is the same batched event Blizzard's own bag-slot buttons
-- use to refresh (see BaseBagSlotButtonMixin:BagSlotOnEvent) - it fires once
-- after bag contents/free-slot counts settle, whether from item movement or
-- equipping/unequipping a bag.
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:SetScript("OnEvent", function()
    local ok, err = pcall(RefreshBagBar)
    if not ok and BB.debug then
        print("|cffff4444BagBorders error (bag bar):|r " .. tostring(err))
    end
end)
