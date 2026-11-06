local ADDON_NAME, BB = ...
local L = BB.L

-- BagBorders' bank window: every purchased tab of the character bank (or the
-- account bank) in one grid, plus the bank-bag slots. Built from Blizzard's own
-- bank item-button template, so clicks/drags go through Blizzard's handlers.
-- UI/BankTakeover.lua decides when it shows. See docs/BAG_WINDOW_PLAN.md.
--
-- Taint rules (the launch-day blank bank was taint): only our own frames are
-- written to; no Blizzard bank functions are called (only unrestricted C_Bank /
-- C_Container reads and the unrestricted sort/deposit calls). Buying tabs and
-- the money prompts stay on Blizzard's own panel ("Blizzard bank" button).
--
-- Forever's bank switches Character/Account with side tabs that only react to
-- mouse-up, which a secure proxy can't press, so our Bank/Account switch is our
-- own view. Right-click deposits from the bags therefore always go where
-- Blizzard's bank is set (the character bank unless changed on its panel).

local SLOT_SIZE = 37
local SLOT_GAP = 4
local PADDING = 10
local HEADER_HEIGHT = 32
local FOOTER_HEIGHT = 34
local SECTION_GAP = 8
local LABEL_HEIGHT = 16
local MESSAGE_HEIGHT = 40
local OFFSCREEN_NOTE_HEIGHT = 14
local FOOTER_FREE_TEXT_WIDTH = 70 -- "999 free" left of the footer buttons

local BACKDROP = {
    bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
    edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local window
local closeButton
local pendingCloseUpdate = false
local viewType -- Enum.BankType shown in our window
local itemButtons = {}   -- tabID -> { [slot] = button }
local bagSlotButtons = {}
local labels = {}
local activeSections = {}
local queued = { refresh = false, relayout = false }

local function BlizzText(key, fallback)
    return _G[key] or fallback
end

local function CursorHasRefundableItem()
    local location = C_Cursor and C_Cursor.GetCursorItem and C_Cursor.GetCursorItem()
    return location and C_Item.CanBeRefunded(location)
end

-- Blizzard only warns about losing a refund when its own panel shows the
-- account bank; ours can show account slots while Blizzard is on the character
-- bank, so we refuse the drop ourselves and point at Blizzard's panel.
local function GuardAccountDrop(button, original)
    return function(self, ...)
        if self:GetBankType() == Enum.BankType.Account and CursorHasRefundableItem() then
            UIErrorsFrame:AddMessage("BagBorders: " .. L["refundable item - deposit it from the Blizzard bank view to confirm."], 1, 0.3, 0.3)
            return
        end
        return original(self, ...)
    end
end

local function GetItemButton(tabID, slot)
    itemButtons[tabID] = itemButtons[tabID] or {}
    local button = itemButtons[tabID][slot]
    if not button then
        local template = C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo("CamelotBankItemButtonTemplate")
            and "CamelotBankItemButtonTemplate" or "BankItemButtonTemplate"
        button = CreateFrame("ItemButton", ("BagBordersBank%d_%d"):format(tabID, slot), window, template)
        button:SetSize(SLOT_SIZE, SLOT_SIZE)
        button:SetScript("OnClick", GuardAccountDrop(button, button:GetScript("OnClick")))
        button:SetScript("OnReceiveDrag", GuardAccountDrop(button, button:GetScript("OnReceiveDrag")))
        itemButtons[tabID][slot] = button
    end
    return button
end

-- Bank-bag slots (character bank, when the bank uses bags). Slot 1 is the base
-- bank and can't be changed, so Blizzard (and we) start at 2.
local function BagSlotOnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.bought then
        if not GameTooltip:SetBagItem(Enum.BagIndex.Characterbanktab, self.bagSlot) then
            GameTooltip:SetText(BlizzText("BANK_BAG", L["Bank bag"]))
        end
    else
        GameTooltip:SetText(BlizzText("BANK_BAG_PURCHASE", L["Purchasable bag slot"]))
        GameTooltip:AddLine(L["Buy it from the Blizzard bank view."], 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function BagSlotPickup(self)
    if self.bought then
        C_Container.PickupContainerItem(Enum.BagIndex.Characterbanktab, self.bagSlot)
    end
end

local function GetBagSlotButton(slot)
    local button = bagSlotButtons[slot]
    if not button then
        button = CreateFrame("ItemButton", "BagBordersBankBag" .. slot, window)
        button:SetSize(SLOT_SIZE, SLOT_SIZE)
        button.bagSlot = slot
        button:RegisterForDrag("LeftButton")
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnEnter", BagSlotOnEnter)
        button:SetScript("OnLeave", GameTooltip_Hide)
        button:SetScript("OnClick", BagSlotPickup)
        button:SetScript("OnDragStart", BagSlotPickup)
        button:SetScript("OnReceiveDrag", BagSlotPickup)
        bagSlotButtons[slot] = button
    end
    return button
end

local function GetLabel(key)
    local label = labels[key]
    if not label then
        label = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetJustifyH("LEFT")
        labels[key] = label
    end
    return label
end

local function ShouldShowBagSlots()
    return viewType == Enum.BankType.Character and C_Bank.ShouldUsePlayerBagsInBank and C_Bank.ShouldUsePlayerBagsInBank()
end

local function AccountViewAvailable()
    return C_Bank.CanViewBank(Enum.BankType.Account) and true or false
end

local function UpdateHeader()
    window.Title:SetText(viewType == Enum.BankType.Account and BlizzText("ACCOUNT_BANK_PANEL_TITLE", L["Account Bank"]) or BlizzText("BANK", L["Bank"]))

    local account = AccountViewAvailable()
    window.CharacterViewButton:SetShown(account)
    window.AccountViewButton:SetShown(account)
    window.CharacterViewButton:SetEnabled(viewType ~= Enum.BankType.Character)
    window.AccountViewButton:SetEnabled(viewType ~= Enum.BankType.Account)
    window.DepositButton:SetShown(C_Bank.DoesBankTypeSupportAutoDeposit(viewType) and true or false)
end

local function RefreshItems()
    queued.refresh = false
    if not window or not window:IsShown() then
        return
    end

    local totalFree = 0
    for index, section in ipairs(activeSections) do
        local color = BB.GENERAL_PALETTE[((index - 1) % #BB.GENERAL_PALETTE) + 1]
        for slot = 1, section.numSlots do
            local button = itemButtons[section.tabID][slot]
            local ok, err = pcall(button.Refresh, button)
            if not ok and BB.debug then
                print("|cffff4444BagBorders error (bank item):|r " .. tostring(err))
            end
            BB.UpdateItemLevel(button, section.tabID, slot, C_Container.GetContainerItemInfo(section.tabID, slot))
            local border = BB.GetOrCreateBorder(button)
            border:SetVertexColor(color.r, color.g, color.b, 1)
            border:Show()
        end

        local free = C_Container.GetContainerNumFreeSlots(section.tabID) or 0
        totalFree = totalFree + free
        section.label:SetText(L["%s  |cffffffff(%d free)|r"]:format(section.name ~= "" and section.name or L["Tab %d"]:format(index), free))
        section.label:SetTextColor(color.r, color.g, color.b)
    end

    if ShouldShowBagSlots() then
        local bagData = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character) or {}
        for slot, button in pairs(bagSlotButtons) do
            if button:IsShown() then
                button.bought = bagData[slot] ~= nil
                local info = button.bought and C_Container.GetContainerItemInfo(Enum.BagIndex.Characterbanktab, slot)
                SetItemButtonTexture(button, info and info.iconFileID)
                SetItemButtonDesaturated(button, not button.bought)
                button:SetAlpha(button.bought and 1 or 0.45)
            end
        end
    end

    window.FreeText:SetText(L["%d free"]:format(totalFree))
end

local function QueueRefresh()
    if queued.refresh then
        return
    end
    queued.refresh = true
    C_Timer.After(0, RefreshItems)
end

local function PlaceRow(buttons, columns, y)
    local step = SLOT_SIZE + SLOT_GAP
    for index, button in ipairs(buttons) do
        local row, col = math.floor((index - 1) / columns), (index - 1) % columns
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", window, "TOPLEFT", PADDING + col * step, y - row * step)
        button:Show()
    end
    return y - math.ceil(#buttons / columns) * step + SLOT_GAP
end

local function Relayout()
    queued.relayout = false
    if not window or not window:IsShown() then
        return
    end

    if viewType == Enum.BankType.Account and not AccountViewAvailable() then
        viewType = Enum.BankType.Character
    end

    local columns = BB.db.settings.bankColumns or 14
    local step = SLOT_SIZE + SLOT_GAP
    local y = -HEADER_HEIGHT

    for _, slots in pairs(itemButtons) do
        for _, button in pairs(slots) do
            button:Hide()
        end
    end
    for _, button in pairs(bagSlotButtons) do
        button:Hide()
    end
    for _, label in pairs(labels) do
        label:Hide()
    end
    wipe(activeSections)

    local locked = C_Bank.FetchBankLockedReason(viewType)
    local tabs = not locked and C_Bank.FetchPurchasedBankTabData(viewType) or {}

    if locked or #tabs == 0 then
        local message = GetLabel("message")
        message:SetText(locked and L["This bank is locked."] or L["No bank tabs yet. Use the Blizzard bank view to buy one."])
        message:ClearAllPoints()
        message:SetPoint("TOPLEFT", window, "TOPLEFT", PADDING, y - 4)
        message:Show()
        y = y - MESSAGE_HEIGHT
    end

    for index, tab in ipairs(tabs) do
        local numSlots = C_Container.GetContainerNumSlots(tab.ID) or 0
        if numSlots > 0 then
            if #activeSections > 0 then
                y = y - SECTION_GAP
            end
            local label = GetLabel("tab" .. tab.ID)
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", window, "TOPLEFT", PADDING, y)
            label:Show()
            y = y - LABEL_HEIGHT

            local buttons = {}
            for slot = 1, numSlots do
                local button = GetItemButton(tab.ID, slot)
                button:Init(viewType, tab.ID, slot)
                table.insert(buttons, button)
            end
            y = PlaceRow(buttons, columns, y)
            table.insert(activeSections, { tabID = tab.ID, numSlots = numSlots, name = tab.name or "", label = label })
        end
    end

    if ShouldShowBagSlots() then
        local maxBags = C_Bank.FetchMaxNumBankTabs(Enum.BankType.Character) or 0
        if maxBags > 1 then
            y = y - SECTION_GAP
            local label = GetLabel("bagslots")
            label:SetText(BlizzText("BAGSLOTTEXT", L["Bank bags"]))
            label:SetTextColor(1, 0.82, 0)
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", window, "TOPLEFT", PADDING, y)
            label:Show()
            y = y - LABEL_HEIGHT

            local buttons = {}
            for slot = 2, maxBags do
                table.insert(buttons, GetBagSlotButton(slot))
            end
            y = PlaceRow(buttons, columns, y)
        end
    end

    if viewType == Enum.BankType.Account then
        local note = GetLabel("accountnote")
        note:SetText("|cffaaaaaa" .. L["Drag items here to deposit. Right-click in your bags deposits to the character bank."] .. "|r")
        note:ClearAllPoints()
        note:SetPoint("TOPLEFT", window, "TOPLEFT", PADDING, y - 4)
        note:Show()
        y = y - OFFSCREEN_NOTE_HEIGHT - 4
    end

    local width = math.max(PADDING * 2 + columns * step - SLOT_GAP, 360, window.footerWidth or 0)
    window:SetSize(width, -y + FOOTER_HEIGHT)
    UpdateHeader()
    if BB.OnBankWindowResized then
        BB.OnBankWindowResized()
    end
    QueueRefresh()
end

local function QueueRelayout()
    if queued.relayout then
        return
    end
    queued.relayout = true
    C_Timer.After(0, Relayout)
end

BB.RelayoutBankWindow = QueueRelayout

local function SetView(bankType)
    viewType = bankType
    Relayout()
end

-- Sort: same rules as Blizzard's sort button (confirmation CVar), but our own
-- confirm instead of Blizzard's popup.
local sortConfirmUntil = 0
local function OnSortClick(self)
    if (C_Bank.FetchNumPurchasedBankTabs(viewType) or 0) == 0 then
        return
    end
    if GetCVarBool("bankConfirmTabCleanUp") and GetTime() > sortConfirmUntil then
        sortConfirmUntil = GetTime() + 3
        self:SetText(L["Sure?"])
        C_Timer.After(3, function()
            self:SetText(BlizzText("BAG_CLEANUP_BANK", L["Sort"]))
        end)
        return
    end
    sortConfirmUntil = 0
    self:SetText(BlizzText("BAG_CLEANUP_BANK", L["Sort"]))
    PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
    C_Container.SortBank(viewType)
end

-- Deposit all: Blizzard asks first when refundable items would go into the
-- account bank. We don't use its popup (taint), so we refuse instead.
local function OnDepositClick()
    if viewType == Enum.BankType.Account then
        local refundable = ItemUtil.IteratePlayerInventory(function(itemLocation)
            return C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, itemLocation) and C_Item.CanBeRefunded(itemLocation)
        end)
        if refundable then
            UIErrorsFrame:AddMessage("BagBorders: " .. L["you have refundable items - use Deposit on the Blizzard bank view to confirm."], 1, 0.3, 0.3)
            return
        end
    end
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
    C_Bank.AutoDepositItemsIntoBank(viewType)
end

-- Secure close button: clicks Blizzard's own bank close button (HideUIPanel,
-- untainted). Parented to UIParent, not our window, for the same reason as the
-- bag window's (UI/Takeover.lua): a protected child would stop our window
-- opening/closing in combat.
local function UpdateCloseButton()
    if not closeButton then
        return
    end
    local shown = window and window:IsShown()
    if InCombatLockdown() then
        closeButton:SetAlpha(shown and closeButton:IsShown() and 1 or 0)
        pendingCloseUpdate = true
        return
    end
    pendingCloseUpdate = false
    if not shown or not window:GetRight() then
        closeButton:Hide()
        return
    end
    closeButton:SetScale(window:GetEffectiveScale() / UIParent:GetEffectiveScale())
    closeButton:ClearAllPoints()
    closeButton:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", window:GetRight() - 2, window:GetTop() - 2)
    closeButton:SetAlpha(1)
    closeButton:Show()
end

BB.OnBankWindowResized = UpdateCloseButton
BB.UpdateBankCloseButton = UpdateCloseButton
function BB.BankClosePending()
    return pendingCloseUpdate
end

local function SavePosition()
    local point, _, relativePoint, x, y = window:GetPoint(1)
    BB.db.settings.bankPos = { point, relativePoint, x, y }
end

local function RestorePosition()
    window:SetScale(BB.db.settings.scale or 1)
    window:ClearAllPoints()
    local pos = BB.db.settings.bankPos
    if pos then
        window:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        window:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116) -- where Blizzard's bank sits
    end
end

function BB.ApplyBankWindowScale()
    if window then
        RestorePosition()
        UpdateCloseButton()
    end
end

local STRUCTURE_EVENTS = {
    BANK_TABS_CHANGED = true, BANK_TAB_SETTINGS_UPDATED = true, BAG_CONTAINER_UPDATE = true,
    PLAYERBANKSLOTS_CHANGED = true,
}
local WINDOW_EVENTS = {
    "BANK_TABS_CHANGED", "BANK_TAB_SETTINGS_UPDATED", "BAG_CONTAINER_UPDATE", "PLAYERBANKSLOTS_CHANGED",
    "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", "BAG_UPDATE", "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED",
    "BAG_UPDATE_COOLDOWN", "INVENTORY_SEARCH_UPDATE", "PLAYER_MONEY", "ACCOUNT_MONEY",
}

-- Buttons grow to fit their (localized) text; minWidth keeps short ones even.
-- altText is any other text the button can switch to (Sort's "Sure?").
local BUTTON_TEXT_PAD = 24
local function MakeTextButton(text, minWidth, onClick, altText)
    local button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    local width = minWidth
    for _, t in ipairs({ altText or text, text }) do
        button:SetText(t)
        width = math.max(width, math.ceil((button:GetTextWidth() or 0) + BUTTON_TEXT_PAD))
    end
    button:SetSize(width, 22)
    button:SetScript("OnClick", onClick)
    return button
end

function BB.CreateBankWindow()
    window = CreateFrame("Frame", "BagBordersBankWindow", UIParent, "BackdropTemplate")
    window:Hide()
    window:SetFrameStrata("MEDIUM")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetBackdrop(BACKDROP)
    window:SetBackdropColor(0.05, 0.05, 0.06, BB.db.settings.bgAlpha or 0.92)
    window:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    viewType = Enum.BankType.Character

    window.Title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    window.Title:SetPoint("TOPLEFT", window, "TOPLEFT", PADDING + 2, -10)

    window.CharacterViewButton = MakeTextButton(BlizzText("BANK", L["Bank"]), 64, function() SetView(Enum.BankType.Character) end)
    window.CharacterViewButton:SetPoint("TOPLEFT", window, "TOPLEFT", 130, -6)
    window.AccountViewButton = MakeTextButton(L["Account"], 70, function() SetView(Enum.BankType.Account) end)
    window.AccountViewButton:SetPoint("LEFT", window.CharacterViewButton, "RIGHT", 4, 0)

    window.FreeText = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.FreeText:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", PADDING + 2, 13)

    window.BlizzardButton = MakeTextButton(L["Blizzard bank"], 100, function() BB.SetBlizzardBankView(true) end)
    window.BlizzardButton:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PADDING, 7)
    window.SortButton = MakeTextButton(BlizzText("BAG_CLEANUP_BANK", L["Sort"]), 70, OnSortClick, L["Sure?"])
    window.SortButton:SetPoint("RIGHT", window.BlizzardButton, "LEFT", -4, 0)
    window.DepositButton = MakeTextButton(L["Deposit all"], 84, OnDepositClick)
    window.DepositButton:SetPoint("RIGHT", window.SortButton, "LEFT", -4, 0)
    -- Room for the free-slot text plus all three buttons.
    window.footerWidth = PADDING * 2 + FOOTER_FREE_TEXT_WIDTH + 8
        + window.DepositButton:GetWidth() + window.SortButton:GetWidth() + window.BlizzardButton:GetWidth()

    window:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() and not BB.db.settings.locked then
            self:StartMoving()
        end
    end)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
        UpdateCloseButton()
    end)
    window:SetScript("OnShow", function(self)
        FrameUtil.RegisterFrameForEvents(self, WINDOW_EVENTS)
        viewType = Enum.BankType.Character
        Relayout()
    end)
    window:SetScript("OnHide", function(self)
        FrameUtil.UnregisterFrameForEvents(self, WINDOW_EVENTS)
        UpdateCloseButton()
    end)
    window:SetScript("OnEvent", function(self, event)
        if STRUCTURE_EVENTS[event] then
            QueueRelayout()
        else
            QueueRefresh()
        end
    end)

    closeButton = CreateFrame("Button", "BagBordersBankWindowClose", UIParent, "UIPanelCloseButtonNoScripts, SecureActionButtonTemplate")
    closeButton:SetFrameStrata("HIGH")
    closeButton:RegisterForClicks("AnyUp", "AnyDown")
    closeButton:SetAttribute("type", "click")
    closeButton:SetAttribute("clickbutton", BankFrameCloseButton or BankFrame.CloseButton)
    closeButton:Hide()

    RestorePosition()
    BB.BankWindow = window
    return window
end
