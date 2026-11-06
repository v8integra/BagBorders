local ADDON_NAME, BB = ...
local L = BB.L

-- Makes the BagBorders window stand in for Blizzard's bag windows without
-- tainting anything Blizzard reads (the launch-day blank bank was taint).
--
-- 1. Blizzard still owns WHEN bags are open: keybinds, bag bar, bank, vendors
--    all keep running Blizzard's own, untainted code.
-- 2. Blizzard's bag windows still open, but somewhere you can't see them. The
--    individual bag windows live in ContainerFrameContainer and anchor to it;
--    we move that container offscreen and put the combined window in it too.
--    They stay shown (not hidden), so Blizzard's OnShow/OnHide logic and its
--    IsBagOpen() checks behave exactly as normal.
-- 3. Our window shows while any Blizzard bag window is shown (HookScript).
-- 4. Our close button is a secure button that clicks Blizzard's own combined-
--    window close button, which runs CloseAllBags() untainted. It isn't a child
--    of our window: a protected child would stop our window opening in combat.
--    Protected frames can only move/show/hide out of combat, so in combat the
--    button just fades out instead and catches up when combat ends.
--
-- Only frame methods (SetParent/SetPoint/HookScript) touch Blizzard frames.

local OFFSCREEN_X = -8000

local closeButton
local pendingCloseUpdate = false

local function GetBlizzardBagFrames()
    local frames = { ContainerFrameCombinedBags }
    for _, frame in ipairs(ContainerFrameContainer.ContainerFrames or {}) do
        table.insert(frames, frame)
    end
    return frames
end

local function AnyBlizzardBagShown()
    for _, frame in ipairs(GetBlizzardBagFrames()) do
        if frame:IsShown() then
            return true
        end
    end
    return false
end

local function UpdateCloseButton()
    if not closeButton then
        return
    end

    local window = BB.BagWindow
    local shown = window and window:IsShown()

    if InCombatLockdown() then
        -- Can't move/show/hide a protected button now; just fade it.
        closeButton:SetAlpha(shown and closeButton:IsShown() and 1 or 0)
        pendingCloseUpdate = true
        return
    end
    pendingCloseUpdate = false

    if not shown or not window:GetRight() then
        closeButton:Hide()
        return
    end

    -- Absolute position (not anchored to our window, which would make our
    -- window protected too). Matching the window's scale makes the button the
    -- right size AND puts both in the same coordinate space, so the window's
    -- own corner coordinates work as offsets directly.
    closeButton:SetScale(window:GetEffectiveScale() / UIParent:GetEffectiveScale())
    closeButton:ClearAllPoints()
    closeButton:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", window:GetRight() - 2, window:GetTop() - 2)
    closeButton:SetAlpha(1)
    closeButton:Show()
end

BB.OnBagWindowResized = UpdateCloseButton

local function SyncWindow()
    local window = BB.BagWindow
    if not window then
        return
    end

    if AnyBlizzardBagShown() then
        if not window:IsShown() then
            window:Show()
        end
    elseif window:IsShown() then
        window:Hide()
    end
    UpdateCloseButton()
end

local function CreateCloseButton()
    closeButton = CreateFrame("Button", "BagBordersBagWindowClose", UIParent, "SecureActionButtonTemplate, UIPanelCloseButtonNoScripts")
    closeButton:SetFrameStrata("HIGH")
    closeButton:RegisterForClicks("AnyUp", "AnyDown")
    closeButton:SetAttribute("type", "click")
    closeButton:SetAttribute("clickbutton", ContainerFrameCombinedBags.CloseButton)
    closeButton:Hide()
end

local function ParkBlizzardFrames()
    ContainerFrameContainer:ClearAllPoints()
    ContainerFrameContainer:SetSize(UIParent:GetWidth(), UIParent:GetHeight())
    ContainerFrameContainer:SetPoint("TOPLEFT", UIParent, "TOPLEFT", OFFSCREEN_X, 0)
    ContainerFrameCombinedBags:SetParent(ContainerFrameContainer)
end

local started = false
local startAfterCombat = false

local function Start()
    started = true
    local ok, err = pcall(function()
        BB.CreateBagWindow()
        CreateCloseButton()
        ParkBlizzardFrames()
        for _, frame in ipairs(GetBlizzardBagFrames()) do
            frame:HookScript("OnShow", SyncWindow)
            frame:HookScript("OnHide", SyncWindow)
        end
        SyncWindow()
    end)
    if not ok then
        print("|cffff4444BagBorders:|r bag window failed to start - " .. tostring(err))
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if startAfterCombat then
            startAfterCombat = false
            Start()
        elseif pendingCloseUpdate then
            UpdateCloseButton()
        end
        return
    end

    self:UnregisterEvent("PLAYER_LOGIN")
    if not BB.windowActive or started then
        return
    end

    -- A /reload in combat lands here in combat; the secure button and moving
    -- Blizzard's frames both have to wait (Blizzard's windows work meanwhile).
    if InCombatLockdown() then
        startAfterCombat = true
        print("|cffffd100BagBorders:|r " .. L["bag window will start when combat ends."])
        return
    end
    Start()
end)
