local ADDON_NAME, BB = ...
local L = BB.L

-- BagBorders' all-in-one bag window: every held bag (backpack, bags, reagent
-- bag, keyring) in one frame, built from Blizzard's own item-button template so
-- clicks, drags, selling and bank deposits go through Blizzard's handlers.
-- UI/Takeover.lua decides when it shows. See docs/BAG_WINDOW_PLAN.md.
--
-- Taint rules: only our own frames are written to. Blizzard helpers are called
-- on our own buttons; nothing here opens/closes bags or writes Blizzard state.

local SLOT_SIZE = 37
local SLOT_GAP = 4
local PADDING = 10
local HEADER_HEIGHT = 58 -- title + search/sort row
local TOOLBAR_Y = -30
local FOOTER_HEIGHT = 26
local SECTION_GAP = 10
local SECTION_LABEL_HEIGHT = 16

local BACKDROP = {
    bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
    edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local window
local holders = {}     -- bagID -> holder frame (SetID(bagID)), parent of that bag's buttons
local stripButtons = {} -- bagID -> equipped-bag button in the bag strip
local sectionLabels = {}
local refreshQueued = false

-- Sections in display order. Bag IDs are resolved at layout time because the
-- keyring only exists on some accounts.
local function GetSections()
    local general = {}
    for bagID = Enum.BagIndex.Backpack, Constants.InventoryConstants.NumBagSlots do
        table.insert(general, bagID)
    end

    local reagent = {}
    for bagID = Constants.InventoryConstants.NumBagSlots + 1, NUM_TOTAL_BAG_FRAMES do
        table.insert(reagent, bagID)
    end

    local sections = {
        { key = "general", bags = general },
        { key = "reagent", bags = reagent, label = L["Reagents"] },
    }
    if C_ActionBar and C_ActionBar.ShouldShowKeyring and C_ActionBar.ShouldShowKeyring() then
        table.insert(sections, { key = "keyring", bags = { KEYRING_CONTAINER }, label = KEYRING or L["Keyring"] })
    end
    return sections
end

-- Max slots includes locked "extended" backpack slots, which Blizzard shows too.
local function GetBagSlotCount(bagID)
    local maxSlots = ContainerFrame_GetContainerNumSlots(bagID)
    return maxSlots or 0
end

-- Bags whose slots are hidden. Only while the strip is open, so a hidden bag
-- can never be lost from view.
local function IsBagHidden(bagID)
    local settings = BB.db.settings
    return settings.bagStrip and settings.hiddenBags[bagID] and true or false
end

local function GetHolder(bagID)
    local holder = holders[bagID]
    if not holder then
        holder = CreateFrame("Frame", nil, window)
        holder:SetID(bagID)
        holder:SetAllPoints(window)
        holder.buttons = {}
        holders[bagID] = holder
    end
    return holder
end

function BB.GetBagWindowHolder(bagID)
    return holders[bagID]
end

local function GetButton(holder, slot)
    local button = holder.buttons[slot]
    if not button then
        local bagID = holder:GetID()
        -- Named because the template names a few children off $parent.
        local name = ("BagBordersItem%s_%d"):format(bagID < 0 and ("m" .. -bagID) or bagID, slot)
        button = CreateFrame("ItemButton", name, holder, "ContainerFrameItemButtonTemplate")
        button:SetSize(SLOT_SIZE, SLOT_SIZE)
        holder.buttons[slot] = button
    end
    return button
end

-- Mirrors ContainerFrameMixin:UpdateItems for one of our buttons (minus the
-- tutorial checks, which belong to Blizzard's own window).
local function UpdateButton(button, tooltipOwner)
    local bagID, slot = button:GetBagID(), button:GetID()
    local info = C_Container.GetContainerItemInfo(bagID, slot)
    local texture = info and info.iconFileID
    local questInfo = C_Container.GetContainerItemQuestInfo(bagID, slot)
    local quality = info and info.quality

    ClearItemButtonOverlay(button)
    button:SetHasItem(texture)
    button:SetItemButtonTexture(texture)
    button:SyncAppearanceWithHasItem()
    SetItemButtonQuality(button, quality, info and info.hyperlink, false, info and info.isBound)
    SetItemButtonCount(button, info and info.stackCount)
    SetItemButtonDesaturated(button, info and info.isLocked)
    button:UpdateExtended()
    button:UpdateQuestItem(questInfo.isQuestItem, questInfo.questID, questInfo.isActive)
    button:UpdateNewItem(quality)
    button:UpdateJunkItem(quality, info and info.hasNoValue)
    button:UpdateItemContextMatching()
    button:UpdateCooldown(texture)
    button:SetReadable(info and info.isReadable)
    button:CheckUpdateTooltip(tooltipOwner)
    button:SetMatchesSearch(not (info and info.isFiltered))
    BB.UpdateItemLevel(button, bagID, slot, info)
end

local function RefreshItems()
    refreshQueued = false
    if not window or not window:IsShown() then
        return
    end

    local tooltipOwner = GameTooltip:GetOwner()
    local totalFree = 0
    BB.ResetBagColors()

    for _, section in ipairs(window.sections or {}) do
        for _, bagID in ipairs(section.bags) do
            local holder = holders[bagID]
            local first = true
            -- Colors are handed out in bag order; a hidden bag still takes its
            -- turn so the other bags keep their colors.
            if GetBagSlotCount(bagID) > 0 then
                BB.AssignBagColor(bagID)
                if section.key == "general" then
                    totalFree = totalFree + (C_Container.GetContainerNumFreeSlots(bagID) or 0)
                end
            end
            for slot = 1, holder and holder.numSlots or 0 do
                local button = holder.buttons[slot]
                if button.BagBordersFreeLabel then
                    button.BagBordersFreeLabel:Hide()
                end

                local ok, err = pcall(UpdateButton, button, tooltipOwner)
                if not ok and BB.debug then
                    print("|cffff4444BagBorders error (item):|r " .. tostring(err))
                end

                local colorOk, _, color, free = pcall(BB.ColorItemButton, button)
                if colorOk and color and first then
                    first = false
                    local label = BB.GetOrCreateFreeSlotLabel(button)
                    label:SetText(("(%d)"):format(free or 0))
                    label:SetTextColor(color.r, color.g, color.b)
                    label:Show()
                end
            end
        end
    end

    for _, button in pairs(stripButtons) do
        if button:IsShown() then
            local ok, err = pcall(BB.UpdateStripButton, button)
            if not ok and BB.debug then
                print("|cffff4444BagBorders error (bag strip):|r " .. tostring(err))
            end
        end
    end

    window.FreeText:SetText(L["%d free"]:format(totalFree))
    window.MoneyText:SetText(GetMoneyString(GetMoney(), true))
end

local function QueueRefresh()
    if refreshQueued then
        return
    end
    refreshQueued = true
    C_Timer.After(0, RefreshItems)
end

local function Relayout()
    if not window then
        return
    end

    local columns = BB.db.settings.columns or 10
    local step = SLOT_SIZE + SLOT_GAP
    local y = -HEADER_HEIGHT
    local sections = GetSections()
    window.sections = sections

    for _, button in pairs(stripButtons) do
        button:Hide()
    end
    if BB.db.settings.bagStrip then
        local index0 = 0
        for _, section in ipairs(sections) do
            if section.key ~= "keyring" then
                for _, bagID in ipairs(section.bags) do
                    local button = BB.GetStripButton(window, stripButtons, bagID)
                    button:ClearAllPoints()
                    local row, col = math.floor(index0 / columns), index0 % columns
                    button:SetPoint("TOPLEFT", window, "TOPLEFT", PADDING + col * step, y - row * step)
                    button:Show()
                    index0 = index0 + 1
                end
            end
        end
        y = y - math.ceil(index0 / columns) * step - SECTION_GAP + SLOT_GAP
    end

    -- Hide everything first; only slots that still exist come back.
    for _, holder in pairs(holders) do
        for _, button in pairs(holder.buttons) do
            button:Hide()
        end
        holder.numSlots = 0
    end
    for _, label in pairs(sectionLabels) do
        label:Hide()
    end

    for index, section in ipairs(sections) do
        local index0 = 0
        for _, bagID in ipairs(section.bags) do
            local holder = GetHolder(bagID)
            local numSlots = IsBagHidden(bagID) and 0 or GetBagSlotCount(bagID)
            holder.numSlots = numSlots
            for slot = 1, numSlots do
                local button = GetButton(holder, slot)
                button:Initialize(window, bagID, slot)
                button:ClearAllPoints()
                -- Header labels push the section down before its first slot.
                if index0 == 0 and section.label then
                    if index > 1 then
                        y = y - SECTION_GAP
                    end
                    local label = sectionLabels[section.key]
                    if not label then
                        label = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        sectionLabels[section.key] = label
                    end
                    label:SetText(section.label)
                    label:ClearAllPoints()
                    label:SetPoint("TOPLEFT", window, "TOPLEFT", PADDING, y)
                    label:Show()
                    y = y - SECTION_LABEL_HEIGHT
                end
                local row, col = math.floor(index0 / columns), index0 % columns
                button:SetPoint("TOPLEFT", window, "TOPLEFT", PADDING + col * step, y - row * step)
                index0 = index0 + 1
            end
        end
        if index0 > 0 then
            y = y - math.ceil(index0 / columns) * step + SLOT_GAP
        end
    end

    window:SetSize(PADDING * 2 + columns * step - SLOT_GAP, -y + FOOTER_HEIGHT)
    if BB.OnBagWindowResized then
        BB.OnBagWindowResized()
    end
    QueueRefresh()
end

BB.RelayoutBagWindow = Relayout

local function SavePosition()
    local point, _, relativePoint, x, y = window:GetPoint(1)
    BB.db.settings.windowPos = { point, relativePoint, x, y }
end

local function RestorePosition()
    window:SetScale(BB.db.settings.scale or 1)
    window:ClearAllPoints()
    local pos = BB.db.settings.windowPos
    if pos then
        window:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        window:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -80, 120)
    end
end

local WINDOW_EVENTS = {
    "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN",
    "INVENTORY_SEARCH_UPDATE", "QUEST_ACCEPTED", "UNIT_QUEST_LOG_CHANGED",
    "PLAYER_MONEY", "BAG_NEW_ITEMS_UPDATED", "BAG_SLOT_FLAGS_UPDATED",
    "BAG_CONTAINER_UPDATE", "MERCHANT_SHOW", "MERCHANT_CLOSED",
}

local function CreateWindow()
    window = CreateFrame("Frame", "BagBordersBagWindow", UIParent, "BackdropTemplate")
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

    -- Our buttons ask their container frame this (empty-slot art etc.).
    function window:IsCombinedBagContainer()
        return true
    end

    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", window, "TOPLEFT", PADDING + 2, -10)
    title:SetText(L["%s - Bags"]:format(UnitName("player")))
    window.Title = title

    -- Search: Blizzard's own item search (C_Container.SetItemSearch, no
    -- restrictions). Matches show through each button's isFiltered flag, in
    -- the bank window too.
    local search = CreateFrame("EditBox", "BagBordersBagSearchBox", window, "SearchBoxTemplate")
    search:SetHeight(20)
    search:SetAutoFocus(false)
    search:SetMaxLetters(40)
    search:HookScript("OnTextChanged", function(self)
        C_Container.SetItemSearch(self:GetText() or "")
    end)
    window.SearchBox = search

    local sort = CreateFrame("Button", nil, window)
    sort:SetSize(28, 26)
    sort:SetNormalAtlas("bags-button-autosort-up")
    sort:SetPushedAtlas("bags-button-autosort-down")
    sort:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]], "ADD")
    sort:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PADDING + 2, TOOLBAR_Y + 3)
    sort:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
        C_Container.SortBags()
    end)
    sort:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip_SetTitle(GameTooltip, BAG_CLEANUP_BAGS or L["Clean Up Bags"], HIGHLIGHT_FONT_COLOR)
        if BAG_CLEANUP_BAGS_DESCRIPTION then
            GameTooltip_AddNormalLine(GameTooltip, BAG_CLEANUP_BAGS_DESCRIPTION)
        end
        GameTooltip:Show()
    end)
    sort:SetScript("OnLeave", GameTooltip_Hide)
    window.SortButton = sort

    local bagsToggle = CreateFrame("Button", nil, window)
    bagsToggle:SetSize(22, 22)
    bagsToggle:SetNormalTexture([[Interface\Buttons\Button-Backpack-Up]])
    bagsToggle:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]], "ADD")
    bagsToggle:SetPoint("RIGHT", sort, "LEFT", -4, 0)
    bagsToggle:SetScript("OnClick", function()
        BB.db.settings.bagStrip = not BB.db.settings.bagStrip
        Relayout()
    end)
    bagsToggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(BB.db.settings.bagStrip and L["Hide bags"] or L["Show bags"])
        GameTooltip:AddLine(L["Shows your equipped bags. Click a bag there to hide or show its slots."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    bagsToggle:SetScript("OnLeave", GameTooltip_Hide)
    window.BagsToggle = bagsToggle

    -- Read-only view of other characters' bags and banks (UI/AltViewer.lua).
    local alts = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    alts:SetText(L["Alts"])
    alts:SetSize(math.max(40, math.ceil((alts:GetTextWidth() or 0) + 16)), 20)
    alts:SetPoint("RIGHT", bagsToggle, "LEFT", -6, 0)
    alts:SetScript("OnClick", function()
        BB.ToggleAltViewer()
    end)
    alts:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Alts"])
        GameTooltip:AddLine(L["See your other characters' bags and banks (read only)."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    alts:SetScript("OnLeave", GameTooltip_Hide)
    window.AltsButton = alts

    -- The search box's clear button sits inside its right edge.
    search:SetPoint("TOPLEFT", window, "TOPLEFT", PADDING + 6, TOOLBAR_Y)
    search:SetPoint("RIGHT", alts, "LEFT", -8, 0)

    window.FreeText = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.FreeText:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", PADDING + 2, 9)
    window.MoneyText = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.MoneyText:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PADDING - 2, 9)

    -- No dragging in combat: the secure close button is positioned against the
    -- window and can only be moved out of combat.
    window:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() and not BB.db.settings.locked then
            self:StartMoving()
        end
    end)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
        if BB.OnBagWindowResized then
            BB.OnBagWindowResized()
        end
    end)

    window:SetScript("OnShow", function(self)
        FrameUtil.RegisterFrameForEvents(self, WINDOW_EVENTS)
        Relayout()
    end)
    window:SetScript("OnHide", function(self)
        FrameUtil.UnregisterFrameForEvents(self, WINDOW_EVENTS)
        -- Closing the bags ends the search, like Blizzard's bags.
        self.SearchBox:ClearFocus()
        if (self.SearchBox:GetText() or "") ~= "" then
            self.SearchBox:SetText("")
        end
    end)
    window:SetScript("OnEvent", function(self, event)
        if event == "BAG_CONTAINER_UPDATE" then
            Relayout()
        else
            QueueRefresh()
        end
    end)

    RestorePosition()
    BB.BagWindow = window
    return window
end

-- Slash-command helpers (see ContainerColors.lua). Scale and reset re-place the
-- window, so the secure close button has to follow.
function BB.SetBagWindowScale(scale)
    BB.db.settings.scale = scale
    if BB.ApplyBankWindowScale then
        BB.ApplyBankWindowScale()
    end
    if window then
        RestorePosition()
        if BB.OnBagWindowResized then
            BB.OnBagWindowResized()
        end
    end
end

function BB.ResetBagWindowPosition()
    BB.db.settings.windowPos = nil
    BB.db.settings.bankPos = nil
    BB.SetBagWindowScale(1)
end

BB.CreateBagWindow = CreateWindow
BB.RefreshBagWindow = QueueRefresh
