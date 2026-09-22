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
local ITEM_STEP = 41 -- approx. item button size (37) plus grid spacing, used only to estimate lift height

local REAGENT_COLOR = { r = 0.30, g = 0.85, b = 0.75 } -- teal, matches Modules/BagBar.lua
local BORDER_TEXTURE = [[Interface\Common\WhiteIconFrame]]

-- /run atlas dimension check confirmed the "Metal" family corner pieces are
-- 95-100px native size - built for a large ornate dialog (character panel,
-- spellbook), not a compact panel. Even cropped, the top corners (only the
-- bottom ones get cropped by NineSliceUtil.UpdateCornerCropping) stayed
-- full-size and bled down through the content, and the bottom crop math
-- went negative on a panel this short, which is why those corners vanished
-- entirely. SimplePanelTemplate's "SimpleMetal" pieces are the right scale
-- (and already use one identical texture for top and bottom, by
-- construction) - tint them bronze with SetVertexColor instead of switching
-- to an oversized atlas family.
local BRONZE_TINT = { r = 1.00, g = 0.80, b = 0.45 }
local NINE_SLICE_PIECE_NAMES = {
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
}

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

    function panel:GetPaddingWidth()
        return PANEL_PADDING
    end

    function panel:GetPaddingHeight()
        return PANEL_PADDING
    end

    -- ContainerFrameMixin:CalculateWidth() (which this panel would otherwise
    -- inherit unchanged) returns a fixed width sized for a normal 4-column
    -- individual bag frame - far too narrow for this panel's 10 columns, so
    -- items ended up spilling out past the backdrop's edge instead of being
    -- covered by it. ContainerFrameCombinedBagsMixin:CalculateWidth uses a
    -- proper column-based formula instead; reuse that exact function (it's a
    -- closure that correctly captures Blizzard's own ITEM_SPACING_X, which
    -- this addon has no direct access to) rather than reimplementing it.
    panel.CalculateWidth = ContainerFrameCombinedBagsMixin.CalculateWidth

    -- Match Blizzard's own bag window border exactly, rather than a generic
    -- tooltip-style backdrop: PortraitFrameFlatTemplate (what
    -- ContainerFrameCombinedBags itself inherits) gets its border from a
    -- child "NineSlice" frame plus a separate flat background fill, both
    -- standard, freely-inheritable templates - reuse both directly.
    local bg = CreateFrame("Frame", nil, panel, "FlatPanelBackgroundTemplate")
    bg:SetPoint("TOPLEFT", 2, -2)
    bg:SetPoint("BOTTOMRIGHT", -2, 2)

    local nineSlice = CreateFrame("Frame", nil, panel, "NineSlicePanelTemplate")
    NineSliceUtil.ApplyLayout(nineSlice, NineSliceUtil.GetLayout("SimplePanelTemplate"))
    for _, pieceName in ipairs(NINE_SLICE_PIECE_NAMES) do
        local piece = nineSlice[pieceName]
        if piece then
            piece:SetVertexColor(BRONZE_TINT.r, BRONZE_TINT.g, BRONZE_TINT.b)
        end
    end

    panel:SetPoint("TOP", ContainerFrameCombinedBags, "BOTTOM", 0, -PANEL_GAP)
    panel:Hide()

    return panel
end

local function EstimateLiftAmount(bagID)
    local numSlots = C_Container.GetContainerNumSlots(bagID) or 0
    if numSlots == 0 then
        return 0
    end
    local rows = math.ceil(numSlots / COLUMNS)
    return rows * ITEM_STEP + PANEL_PADDING + PANEL_GAP
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

    -- UpdateContainerFrameAnchors repositions every open bag frame from
    -- scratch on every call (ClearAllPoints + SetPoint, not incremental), and
    -- anchors the first one to the screen's bottom-right corner with just
    -- enough clearance for the bag bar - not enough for our panel underneath
    -- it too. Nudge that same anchor up by the panel's height each time this
    -- runs, reading the freshly-set point back so there's no cumulative
    -- drift. This is a plain global function (not a mixin table copied onto
    -- an instance), so hooksecurefunc on it works reliably.
    local ok, err = pcall(hooksecurefunc, "UpdateContainerFrameAnchors", function()
        local combinedFrame = ContainerFrameCombinedBags
        if not combinedFrame or not combinedFrame:IsShown() then
            return
        end

        local reagentButton = CharacterReagentBag0Slot
        if not (reagentButton and reagentButton:HasBagEquipped()) then
            return
        end

        local liftAmount = EstimateLiftAmount(reagentButton:GetBagID())
        if liftAmount <= 0 then
            return
        end

        local point, relativeTo, relativePoint, x, y = combinedFrame:GetPoint(1)
        if point then
            combinedFrame:ClearAllPoints()
            combinedFrame:SetPoint(point, relativeTo, relativePoint, x, y + liftAmount)
        end
    end)
    if not ok and BB.debug then
        print("|cffff4444BagBorders:|r failed to hook UpdateContainerFrameAnchors - " .. tostring(err))
    end
end)
