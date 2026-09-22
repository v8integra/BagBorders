local ADDON_NAME, BB = ...

-- Attaches a second, chrome-less item grid below ContainerFrameCombinedBags
-- showing the reagent bag's own slots, since Blizzard's combined view never
-- includes the reagent bag (OpenBag routes it to its own individual frame
-- regardless of the combined-bags setting). Reuses ContainerFrameMixin's real
-- grid/refresh logic (item buttons, layout, icons, click/drag all work
-- exactly like a normal bag frame) rather than hand-rolling item display -
-- only the title-bar/portrait/search-box parts (which this panel doesn't
-- have) are skipped.
local PANEL_GAP = 8
local COLUMNS = 10
local PANEL_PADDING = 18

local REAGENT_COLOR = { r = 0.30, g = 0.85, b = 0.75 } -- teal, matches Modules/BagBar.lua
local BORDER_TEXTURE = [[Interface\Common\WhiteIconFrame]]

local panel

local function CreatePanel()
    if panel then
        return panel
    end

    panel = CreateFrame("Frame", "BagBordersReagentPanel", ContainerFrameCombinedBags)
    Mixin(panel, ContainerFrameMixin)

    panel.itemButtonPool = CreateFramePool("ItemButton", panel, "ContainerFrameItemButtonTemplate")
    panel.Items = {}

    function panel:SetBagID(id)
        self:SetID(id)
    end

    function panel:GetColumns()
        return COLUMNS
    end

    function panel:GetPaddingHeight()
        return PANEL_PADDING
    end

    panel:SetPoint("TOP", ContainerFrameCombinedBags, "BOTTOM", 0, -PANEL_GAP)
    panel:Hide()

    return panel
end

local function StyleItemButton(itemButton, isFirst, numFreeSlots)
    local border = itemButton.BagBordersBorder
    if not border then
        border = itemButton:CreateTexture(nil, "OVERLAY", nil, 0)
        border:SetTexture(BORDER_TEXTURE)
        border:SetBlendMode("ADD")
        border:SetPoint("TOPLEFT", itemButton, "TOPLEFT", 0, 0)
        border:SetPoint("BOTTOMRIGHT", itemButton, "BOTTOMRIGHT", 0, 0)
        itemButton.BagBordersBorder = border
    end
    border:SetVertexColor(REAGENT_COLOR.r, REAGENT_COLOR.g, REAGENT_COLOR.b, 1)
    border:Show()

    if itemButton.BagBordersFreeLabel then
        itemButton.BagBordersFreeLabel:Hide()
    end

    if isFirst then
        local label = itemButton.BagBordersFreeLabel
        if not label then
            label = itemButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            label:SetPoint("TOPRIGHT", itemButton, "TOPRIGHT", -1, -1)
            label:SetJustifyH("RIGHT")
            itemButton.BagBordersFreeLabel = label
        end
        label:SetText(("(%d)"):format(numFreeSlots or 0))
        label:SetTextColor(REAGENT_COLOR.r, REAGENT_COLOR.g, REAGENT_COLOR.b)
        label:Show()
    end
end

local function RefreshReagentPanel()
    local reagentButton = CharacterReagentBag0Slot
    local combinedFrame = ContainerFrameCombinedBags

    if not reagentButton or not reagentButton:HasBagEquipped() or not combinedFrame or not combinedFrame:IsShown() then
        if panel then
            panel:Hide()
        end
        return
    end

    local p = CreatePanel()
    local bagID = reagentButton:GetBagID()

    local numFreeSlots = C_Container.GetContainerNumFreeSlots(bagID) or 0

    p:SetBagID(bagID)
    p:SetBagSize(C_Container.GetContainerNumSlots(bagID))
    p:UpdateItemSlots()
    p:SetSize(p:CalculateWidth(), p:CalculateHeight())
    p:UpdateItemLayout()
    p:AddItemsForRefresh()

    local isFirst = true
    for _, itemButton in p:EnumerateValidItems() do
        if itemButton then
            StyleItemButton(itemButton, isFirst, numFreeSlots)
            isFirst = false
        end
    end

    p:Show()
end

BB.RefreshReagentPanel = RefreshReagentPanel

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    ContainerFrameCombinedBags:HookScript("OnShow", function()
        local ok, err = pcall(RefreshReagentPanel)
        if not ok and BB.debug then
            print("|cffff4444BagBorders error (reagent panel show):|r " .. tostring(err))
        end
    end)

    ContainerFrameCombinedBags:HookScript("OnHide", function()
        if panel then
            panel:Hide()
        end
    end)

    local updateFrame = CreateFrame("Frame")
    updateFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    updateFrame:SetScript("OnEvent", function()
        if ContainerFrameCombinedBags:IsShown() then
            local ok, err = pcall(RefreshReagentPanel)
            if not ok and BB.debug then
                print("|cffff4444BagBorders error (reagent panel update):|r " .. tostring(err))
            end
        end
    end)
end)
