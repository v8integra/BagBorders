local ADDON_NAME, BB = ...

-- Fixes the combined bag window's slot order.
--
-- A build after 70170 changed the combined view's item sort to ascending for
-- every mode but kept filling the grid from the bottom-right corner, so the
-- backpack's first slot lands at the bottom and the last bag at the top. After
-- Blizzard lays the grid out we re-sort descending (the pre-change behavior)
-- and lay it out again, which is a no-op if Blizzard fixes it themselves.
--
-- This module used to also fold the reagent bag into the combined window by
-- setting Blizzard's ENDING_BAG_INDEX global. Any addon write to a Blizzard
-- global taints it, and from launch build 70790 that broke the bank: its OnShow
-- opens the bags first (reading the tainted global), and the tainted execution
-- then can't use the restricted C_Bank calls, so the bank window stayed blank.
-- Never write Blizzard globals here; only re-anchor buttons Blizzard created.

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

local function ShouldRun()
    return not BB.windowActive and not InputUtil.IsGamepadUIEnabled() and ContainerFrameSettingsManager:IsUsingCombinedBags()
end

local function RelayoutCombinedBags(frame)
    if not ShouldRun() then
        return
    end

    local items = {}
    for _, itemButton in frame:EnumerateValidItems() do
        if itemButton then
            table.insert(items, itemButton)
        end
    end
    if #items == 0 then
        return
    end

    table.sort(items, IsAccountSecured() and SortDescending or SortDescendingExtendedLast)

    local blizzardLayout = ContainerFrameMixin.GetAnchorLayout(frame)
    local layout = AnchorUtil.CreateGridLayout(
        GridLayoutMixin.Direction.BottomRightToTopLeft,
        frame:GetColumns(),
        blizzardLayout.paddingX,
        blizzardLayout.paddingY
    )

    AnchorUtil.GridLayout(items, frame:GetInitialItemAnchor(), layout)
    frame:LayoutAddSlots()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    -- Hook the frame instance, not the mixin table (see ContainerColors.lua).
    local ok, err = pcall(hooksecurefunc, ContainerFrameCombinedBags, "UpdateItemLayout", function(frame)
        local relayoutOk, relayoutErr = pcall(RelayoutCombinedBags, frame)
        if not relayoutOk and BB.debug then
            print("|cffff4444BagBorders error (relayout):|r " .. tostring(relayoutErr))
        end
    end)

    if not ok then
        print("|cffff4444BagBorders:|r failed to hook ContainerFrameCombinedBags.UpdateItemLayout - " .. tostring(err))
    end
end)
