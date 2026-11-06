local ADDON_NAME, BB = ...

-- Docks the reagent bag's own window against the combined bag window.
--
-- Replaces the old fold-in (see CombinedLayout.lua for why that had to go).
-- Blizzard positions every open bag window in UpdateContainerFrameAnchors; in
-- combined mode the combined window is always first in that list and anchored
-- to the screen, and the reagent window comes after it in a new column. We
-- post-hook that function and move only the reagent window: directly above
-- the combined window (right edges aligned) when it fits on screen, otherwise
-- to its left with the tops aligned. Frames Blizzard chains after the reagent
-- window (e.g. a keyring) are anchored to it and simply follow along.
--
-- Taint rules: hooksecurefunc only, never write Blizzard globals or fields,
-- and never open/close bags from here. Moving a bag window is just anchor work
-- on an unprotected frame, so it can't taint the bank or vendor flows.

local DOCK_GAP = 4

-- With the BagBorders window on, the reagent bag is part of it, so neither the
-- dock nor the key override is needed.
local function ShouldRun()
    return not BB.windowActive and not InputUtil.IsGamepadUIEnabled() and ContainerFrameSettingsManager:IsUsingCombinedBags()
end

local function GetReagentFrame(combined)
    local frame = ContainerFrameUtil_GetShownFrameForID(Enum.BagIndex.ReagentBag)
    if frame and frame ~= combined then
        return frame
    end
    return nil
end

-- True if the reagent window fits between the combined window's top and the
-- top of the screen. Compared in screen pixels since the frames are scaled.
local function FitsAbove(combined, reagent)
    local combinedTop = combined:GetTop()
    local screenTop = UIParent:GetTop()
    if not combinedTop or not screenTop then
        return false
    end

    local neededTop = combinedTop * combined:GetEffectiveScale()
        + (reagent:GetHeight() + DOCK_GAP) * reagent:GetEffectiveScale()
    return neededTop <= screenTop * UIParent:GetEffectiveScale()
end

local function DockReagentBag()
    if not ShouldRun() then
        return
    end

    local combined = ContainerFrameCombinedBags
    if not combined or not combined:IsShown() then
        return
    end

    local reagent = GetReagentFrame(combined)
    if not reagent then
        return
    end

    local above = FitsAbove(combined, reagent)
    reagent:ClearAllPoints()
    if above then
        reagent:SetPoint("BOTTOMRIGHT", combined, "TOPRIGHT", 0, DOCK_GAP)
    else
        reagent:SetPoint("TOPRIGHT", combined, "TOPLEFT", -DOCK_GAP, 0)
    end

    if BB.debug then
        print("|cff44ff44BagBorders:|r reagent bag docked " .. (above and "above" or "left of") .. " the combined bags")
    end
end

BB.DockReagentBag = DockReagentBag

-- Opening the reagent bag together with the combined bags.
--
-- The Toggle Backpack key (and the backpack button) call ToggleBackpack, which
-- in combined mode opens only the combined window. Blizzard's Open All Bags
-- command (ToggleAllBags) opens the combined window AND the reagent bag. So in
-- combined mode we point every key bound to Toggle Backpack at Open All Bags
-- with an override binding. Blizzard's own binding then does the opening, so
-- it runs untainted. Calling OpenBag(5) from addon code instead would leave
-- tainted bag-frame state behind for the bank and vendor flows to trip over.
-- Override bindings aren't saved: the user's real keybinds are never changed,
-- and turning the setting off clears the overrides immediately.

local bindingOwner = CreateFrame("Frame")
local appliedSignature = ""
local pendingAfterCombat = false

local function WantOverride()
    return BB.db and not BB.windowActive and BB.db.settings.openReagentWithBackpack
        and GetCVarBool("combinedBags")
        and not InputUtil.IsGamepadUIEnabled()
end

local function ApplyBackpackKeyOverride()
    -- Desired keys come from the saved bindings (GetBindingKey ignores
    -- overrides), so applying our overrides can't change the next result.
    local keys = {}
    if WantOverride() then
        keys = { GetBindingKey("TOGGLEBACKPACK") }
    end
    local signature = table.concat(keys, "\31")

    -- SetOverrideBinding fires UPDATE_BINDINGS; skipping unchanged sets is what
    -- stops that from looping back into here.
    if signature == appliedSignature then
        return
    end

    if InCombatLockdown() then
        pendingAfterCombat = true
        return
    end

    -- Record first: the UPDATE_BINDINGS these calls fire can re-enter here.
    appliedSignature = signature
    ClearOverrideBindings(bindingOwner)
    for _, key in ipairs(keys) do
        SetOverrideBinding(bindingOwner, false, key, "OPENALLBAGS")
    end

    if BB.debug then
        print("|cff44ff44BagBorders:|r Toggle Backpack keys opening all bags: " .. (#keys > 0 and table.concat(keys, ", ") or "none"))
    end
end

BB.ApplyBackpackKeyOverride = ApplyBackpackKeyOverride

bindingOwner:RegisterEvent("PLAYER_LOGIN")
bindingOwner:RegisterEvent("UPDATE_BINDINGS")
bindingOwner:RegisterEvent("USE_COMBINED_BAGS_CHANGED")
bindingOwner:RegisterEvent("CVAR_UPDATE")
bindingOwner:RegisterEvent("PLAYER_REGEN_ENABLED")
bindingOwner:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if not pendingAfterCombat then
            return
        end
        pendingAfterCombat = false
    end

    local ok, err = pcall(ApplyBackpackKeyOverride)
    if not ok and BB.debug then
        print("|cffff4444BagBorders error (backpack key):|r " .. tostring(err))
    end
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    local ok, err = pcall(hooksecurefunc, "UpdateContainerFrameAnchors", function()
        local dockOk, dockErr = pcall(DockReagentBag)
        if not dockOk and BB.debug then
            print("|cffff4444BagBorders error (reagent dock):|r " .. tostring(dockErr))
        end
    end)

    if not ok then
        print("|cffff4444BagBorders:|r failed to hook UpdateContainerFrameAnchors - " .. tostring(err))
    end
end)
