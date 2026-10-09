local ADDON_NAME, BB = ...

-- Fixes the combined bag window's slot order and folds the reagent bag into it.
--
-- Order: a build after 70170 changed the combined view's item sort to ascending
-- for every mode but kept filling the grid from the bottom-right corner, so the
-- backpack's first slot lands at the bottom and the last bag at the top. After
-- Blizzard lays the grid out we re-sort descending (the pre-change behavior)
-- and lay it out again, which is a no-op if Blizzard fixes it themselves.
--
-- Reagent bag: Blizzard's combined frame already supports it - ENDING_BAG_INDEX
-- is a global that bounds which bags UpdateItemSlots/SetBagSize/MatchesBagID
-- include, and gamepad mode sets it to NUM_TOTAL_BAG_FRAMES. Doing the same for
-- everyone puts the reagent slots in the combined frame and makes OpenBag(5)
-- route to the combined window instead of spawning a separate side frame. We
-- then lay the reagent slots out as their own block below the general bags.

local REAGENT_GAP = 10 -- extra space between the general block and the reagent block

local function IsReagentItem(itemButton)
    return itemButton:GetBagID() > NUM_BAG_FRAMES
end

local function PartitionItems(frame)
    local general, reagent = {}, {}
    for _, itemButton in frame:EnumerateValidItems() do
        if itemButton then
            if IsReagentItem(itemButton) then
                table.insert(reagent, itemButton)
            else
                table.insert(general, itemButton)
            end
        end
    end
    return general, reagent
end

local function SortDescending(a, b)
    local bagA, bagB = a:GetBagID(), b:GetBagID()
    if bagA ~= bagB then
        return bagA > bagB
    end
    return a:GetID() > b:GetID()
end

-- Accounts without the authenticator have extra locked backpack slots that
-- Blizzard sorts after the normal ones.
local function SortDescendingExtendedLast(a, b)
    local extendedA, extendedB = a:IsExtended(), b:IsExtended()
    if extendedA ~= extendedB then
        return not extendedA
    end
    return SortDescending(a, b)
end

local function GetLayout(frame)
    local blizzardLayout = ContainerFrameMixin.GetAnchorLayout(frame)
    return AnchorUtil.CreateGridLayout(
        GridLayoutMixin.Direction.BottomRightToTopLeft,
        frame:GetColumns(),
        blizzardLayout.paddingX,
        blizzardLayout.paddingY
    )
end

local function ShouldRun()
    return not InputUtil.IsGamepadUIEnabled() and ContainerFrameSettingsManager:IsUsingCombinedBags()
end

local function RelayoutCombinedBags(frame)
    if not ShouldRun() then
        return
    end

    local general, reagent = PartitionItems(frame)
    if #general == 0 and #reagent == 0 then
        return
    end

    local comparator = IsAccountSecured() and SortDescending or SortDescendingExtendedLast
    table.sort(general, comparator)
    table.sort(reagent, comparator)

    local layout = GetLayout(frame)
    local anchor = frame:GetInitialItemAnchor()

    if #reagent > 0 then
        AnchorUtil.GridLayout(reagent, anchor, layout)

        local step = reagent[1]:GetHeight() + layout.paddingY
        local rows = math.ceil(#reagent / layout.stride)
        local point, relativeTo, relativePoint, x, y = anchor:Get()
        anchor = AnchorUtil.CreateAnchor(point, relativeTo, relativePoint, x, y + rows * step + REAGENT_GAP)
    end

    AnchorUtil.GridLayout(general, anchor, layout)
    frame:LayoutAddSlots()
end

-- Blizzard sizes the frame for ceil(totalSlots / columns) rows. Giving the
-- reagent slots their own rows (plus the gap) can need more than that.
local function ResizeCombinedBags(frame)
    if not ShouldRun() then
        return
    end

    local general, reagent = PartitionItems(frame)
    if #reagent == 0 then
        return
    end

    local stride = frame:GetColumns()
    local blizzardRows = math.ceil((#general + #reagent) / stride)
    local ourRows = math.ceil(#general / stride) + math.ceil(#reagent / stride)
    local step = reagent[1]:GetHeight() + GetLayout(frame).paddingY

    frame:SetHeight(frame:GetHeight() + (ourRows - blizzardRows) * step + REAGENT_GAP)
end

BB:OnDBReady(function()
    if BB.db.settings.reagentInCombined and not InputUtil.IsGamepadUIEnabled() then
        ENDING_BAG_INDEX = NUM_TOTAL_BAG_FRAMES
    end
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    -- Hook the frame instance, not the mixin table (see ContainerColors.lua).
    local ok1, err1 = pcall(hooksecurefunc, ContainerFrameCombinedBags, "UpdateItemLayout", function(frame)
        local ok, err = pcall(RelayoutCombinedBags, frame)
        if not ok and BB.debug then
            print("|cffff4444BagBorders error (relayout):|r " .. tostring(err))
        end
    end)
    local ok2, err2 = pcall(hooksecurefunc, ContainerFrameCombinedBags, "UpdateFrameSize", function(frame)
        local ok, err = pcall(ResizeCombinedBags, frame)
        if not ok and BB.debug then
            print("|cffff4444BagBorders error (resize):|r " .. tostring(err))
        end
    end)

    if not ok1 then
        print("|cffff4444BagBorders:|r failed to hook ContainerFrameCombinedBags.UpdateItemLayout - " .. tostring(err1))
    end
    if not ok2 then
        print("|cffff4444BagBorders:|r failed to hook ContainerFrameCombinedBags.UpdateFrameSize - " .. tostring(err2))
    end
end)
