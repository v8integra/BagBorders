local ADDON_NAME, BB = ...
local L = BB.L

-- Makes the BagBorders bank window stand in for Blizzard's bank panel, the
-- same way UI/Takeover.lua does for bags:
--
-- 1. Blizzard still opens/closes the bank (NPC, walking away, ESC) and keeps
--    BankFrame shown, so its own OnShow/OnHide and C_Bank calls run untainted.
-- 2. Blizzard's UI panel manager places BankFrame with SetPoint. We post-hook
--    that SetPoint (hooksecurefunc on the instance) and move it offscreen right
--    after, remembering Blizzard's position so we can put it back.
-- 3. Our window shows while BankFrame is shown (HookScript).
-- 4. "Blizzard bank" puts Blizzard's panel back on screen (for buying tabs,
--    money, tab settings) and hides ours; a button on Blizzard's panel, or
--    closing the bank, switches back.
--
-- Only frame methods (SetPoint/HookScript) touch BankFrame; no Blizzard bank
-- functions are called and no Blizzard values are written.

local OFFSCREEN_X = -8000

local blizzardView = false
local lastBlizzardPoint
local moving = false

local function Park()
    moving = true
    BankFrame:ClearAllPoints()
    BankFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", OFFSCREEN_X, 0)
    moving = false
end

local function Unpark()
    moving = true
    BankFrame:ClearAllPoints()
    if lastBlizzardPoint then
        BankFrame:SetPoint(unpack(lastBlizzardPoint))
    else
        BankFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
    end
    moving = false
end

local function OnBankSetPoint(frame, ...)
    if moving then
        return
    end
    lastBlizzardPoint = { ... }
    if not blizzardView then
        Park()
    end
end

local function Sync()
    local window = BB.BankWindow
    if not window then
        return
    end
    if BankFrame:IsShown() and not blizzardView then
        if not window:IsShown() then
            window:Show()
        end
    elseif window:IsShown() then
        window:Hide()
    end
    BB.UpdateBankCloseButton()
end

function BB.SetBlizzardBankView(on)
    blizzardView = on and true or false
    if blizzardView then
        Unpark()
    else
        Park()
    end
    Sync()
end

local function CreateReturnButton()
    local button = CreateFrame("Button", "BagBordersBankReturnButton", BankFrame, "UIPanelButtonTemplate")
    button:SetSize(130, 22)
    button:SetText(L["BagBorders view"])
    button:SetPoint("TOPRIGHT", BankFrame, "BOTTOMRIGHT", 0, -2)
    button:SetScript("OnClick", function()
        BB.SetBlizzardBankView(false)
    end)
end

local started = false
local startAfterCombat = false

local function Start()
    started = true
    local ok, err = pcall(function()
        BB.CreateBankWindow()
        CreateReturnButton()
        hooksecurefunc(BankFrame, "SetPoint", OnBankSetPoint)
        Park()
        BankFrame:HookScript("OnShow", Sync)
        BankFrame:HookScript("OnHide", function()
            -- Every visit starts in our view.
            if blizzardView then
                blizzardView = false
                Park()
            end
            Sync()
        end)
        Sync()
    end)
    if not ok then
        print("|cffff4444BagBorders:|r bank window failed to start - " .. tostring(err))
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
        elseif BB.BankClosePending and BB.BankClosePending() then
            BB.UpdateBankCloseButton()
        end
        return
    end

    self:UnregisterEvent("PLAYER_LOGIN")
    if not BB.windowActive or started or not BankFrame then
        return
    end
    if InCombatLockdown() then
        startAfterCombat = true
        return
    end
    Start()
end)
