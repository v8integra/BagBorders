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
local PANEL_PADDING_HEIGHT = 38 -- margin above+below the item grid; split evenly to center it
local PANEL_PADDING_WIDTH = 28 -- narrower than the height padding - total width was ~10px too wide
local RIGHT_MARGIN = 14 -- gap between the rightmost column and the border, wider than the default 7
local ITEM_STEP = 41 -- approx. item button size (37) plus grid spacing, used only to estimate lift height

local REAGENT_COLOR = { r = 0.30, g = 0.85, b = 0.75 } -- teal, matches Modules/BagBar.lua
local BORDER_TEXTURE = [[Interface\Common\WhiteIconFrame]]

-- /run atlas checks confirmed the root problem: even SimplePanelTemplate's
-- "SimpleMetal" corner pieces are a fixed 64x64 native size, and this panel
-- is only ~55px tall for a small reagent bag (one row of slots) - the
-- corner art is simply taller than the panel itself. Nine-slice corner/edge
-- atlases render at a fixed native size regardless of frame size (that's
-- why every atlas family tried so far overflowed), so no nine-slice layout
-- will fit a panel this short. A plain SetBackdrop border uses a thin
-- tiling strip that scales to whatever size the frame actually is - use
-- that instead, tinted bronze via SetBackdropBorderColor to match the main
-- window's color.
local BRONZE_TINT = { r = 0.70, g = 0.50, b = 0.28 }

local panel

local function CreatePanel()
    if panel then
        return panel
    end

    panel = CreateFrame("Frame", "BagBordersReagentPanel", ContainerFrameCombinedBags, "BackdropTemplate")
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
        return PANEL_PADDING_WIDTH
    end

    function panel:GetPaddingHeight()
        return PANEL_PADDING_HEIGHT
    end

    -- The default anchor (ContainerFrameMixin:GetInitialItemAnchor) insets
    -- the grid only 9px up from the bottom, leaving the rest of
    -- GetPaddingHeight() as dead space above it - fine for a normal bag
    -- window where that space is the title bar, but this panel has none, so
    -- the grid just looked stuck to the bottom. Split the padding evenly
    -- instead so it's centered, and widen the right inset so the grid
    -- clears the (now much thicker) border.
    function panel:GetInitialItemAnchor()
        local yOffset = self:GetPaddingHeight() / 2
        return AnchorUtil.CreateAnchor("BOTTOMRIGHT", self, "BOTTOMRIGHT", -RIGHT_MARGIN, yOffset)
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

    -- Background fill matching Blizzard's own bag window color.
    local bg = CreateFrame("Frame", nil, panel, "FlatPanelBackgroundTemplate")
    bg:SetPoint("TOPLEFT", 12, -12)
    bg:SetPoint("BOTTOMRIGHT", -12, 12)

    panel:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 40,
        insets = { left = 11, right = 11, top = 11, bottom = 11 },
    })
    panel:SetBackdropBorderColor(BRONZE_TINT.r, BRONZE_TINT.g, BRONZE_TINT.b, 1)

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
    return rows * ITEM_STEP + PANEL_PADDING_HEIGHT + PANEL_GAP
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
