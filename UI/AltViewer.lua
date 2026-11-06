local ADDON_NAME, BB = ...
local L = BB.L

-- Read-only viewer for any remembered character's bags, bank, and the account
-- bank (from Data/Characters.lua). It's its own window with plain buttons, so
-- nothing here can move items or touch the live bag/bank windows. Open it with
-- the "Alts" button on the bag window or /bagborders alts.

local SLOT_SIZE = 37
local SLOT_GAP = 4
local PADDING = 10
local HEADER_HEIGHT = 58
local FOOTER_HEIGHT = 28
local SIDEBAR_WIDTH = 150
local NAME_HEIGHT = 20
local SECTION_GAP = 8
local LABEL_HEIGHT = 16
local VIEW_HEIGHT = 440
local MIN_WIDTH = 580 -- room for the view buttons and search box

local BACKDROP = {
    bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
    edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local VIEWS = { bags = L["Bags"], bank = L["Bank"], account = L["Account bank"] }

local window
local selectedKey
local view = "bags"
local itemButtons = {}
local nameButtons = {}
local sectionLabels = {}

local function BlizzText(key, fallback)
    return _G[key] or fallback
end

local function ClassColor(class)
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

local function FormatAge(t)
    if not t then
        return L["never"]
    end
    local seconds = math.max(0, time() - t)
    if seconds < 3600 then
        return L["%d min ago"]:format(math.floor(seconds / 60))
    elseif seconds < 86400 then
        return L["%d hr ago"]:format(math.floor(seconds / 3600))
    end
    return L["%d days ago"]:format(math.floor(seconds / 86400))
end

local function ItemName(link)
    return link and link:match("%[(.-)%]") or ""
end

local function ItemOnEnter(self)
    if not self.link then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(self.link)
    GameTooltip:Show()
end

local function ItemOnClick(self)
    if self.link and HandleModifiedItemClick then
        HandleModifiedItemClick(self.link)
    end
end

local function GetItemButton(index)
    local button = itemButtons[index]
    if not button then
        button = CreateFrame("ItemButton", "BagBordersAltItem" .. index, window.Content)
        button:SetSize(SLOT_SIZE, SLOT_SIZE)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnEnter", ItemOnEnter)
        button:SetScript("OnLeave", GameTooltip_Hide)
        button:SetScript("OnClick", ItemOnClick)
        itemButtons[index] = button
    end
    return button
end

local function GetSectionLabel(index)
    local label = sectionLabels[index]
    if not label then
        label = window.Content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetJustifyH("LEFT")
        sectionLabels[index] = label
    end
    return label
end

-- The sections (bags or bank tabs) the current view shows, plus when the data
-- was saved and a message when there's nothing to show.
local function GetSections(entry)
    if view == "account" then
        local account = BagBordersDB.accountBank
        if not account then
            return {}, nil, L["No account bank seen yet. Open the bank on any character."]
        end
        return account.tabs or {}, account.updated
    elseif view == "bank" then
        if not entry.bank then
            return {}, nil, L["Bank not seen yet. Open the bank on this character once."]
        end
        return entry.bank, entry.bankUpdated
    end
    return entry.bags or {}, entry.updated
end

local function SectionName(section, index)
    if view == "bags" then
        if section.id == Enum.BagIndex.Backpack then
            return BlizzText("BACKPACK_TOOLTIP", L["Backpack"])
        elseif section.id == KEYRING_CONTAINER then
            return BlizzText("KEYRING", L["Keyring"])
        elseif section.id > Constants.InventoryConstants.NumBagSlots then
            return L["Reagents"]
        end
        return L["Bag %d"]:format(section.id)
    end
    return section.name ~= "" and section.name or L["Tab %d"]:format(index)
end

local function Refresh()
    if not window or not window:IsShown() then
        return
    end

    local characters = BB.GetCachedCharacters()
    if not selectedKey or not BagBordersDB.characters[selectedKey] then
        selectedKey = characters[1] and characters[1].key
    end

    -- Sidebar: one name per character, class colored, money under the list.
    local totalMoney = 0
    for _, button in pairs(nameButtons) do
        button:Hide()
    end
    for index, character in ipairs(characters) do
        local button = nameButtons[index]
        if not button then
            button = CreateFrame("Button", nil, window)
            button:SetSize(SIDEBAR_WIDTH - 8, NAME_HEIGHT)
            button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            button:SetHighlightTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]], "ADD")
            button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            button.Text:SetPoint("LEFT", button, "LEFT", 6, 0)
            button.Text:SetJustifyH("LEFT")
            button.Selected = button:CreateTexture(nil, "BACKGROUND")
            button.Selected:SetAllPoints(button)
            button.Selected:SetColorTexture(1, 1, 1, 0.12)
            button:SetScript("OnClick", function(self, mouseButton)
                if mouseButton == "RightButton" and IsShiftKeyDown() then
                    if BB.ForgetCharacter(self.key) then
                        print("|cffffd100BagBorders:|r " .. L["forgot %s"]:format(self.key))
                    end
                else
                    selectedKey = self.key
                end
                Refresh()
            end)
            button:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.key)
                GameTooltip:AddLine(GetMoneyString(self.money or 0, true), 1, 1, 1)
                GameTooltip:AddLine(L["Bags saved %s"]:format(FormatAge(self.updated)), 0.7, 0.7, 0.7)
                GameTooltip:AddLine(L["Bank saved %s"]:format(FormatAge(self.bankUpdated)), 0.7, 0.7, 0.7)
                if self.key ~= BB.playerKey then
                    GameTooltip:AddLine(L["Shift+right-click to forget this character"], 0.6, 0.8, 1)
                end
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", GameTooltip_Hide)
            nameButtons[index] = button
        end
        local entry = character.entry
        button.key = character.key
        button.money, button.updated, button.bankUpdated = entry.money, entry.updated, entry.bankUpdated
        button.Text:SetText(entry.name or character.key)
        button.Text:SetTextColor(ClassColor(entry.class))
        button.Selected:SetShown(character.key == selectedKey)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", window, "TOPLEFT", PADDING - 2, -HEADER_HEIGHT - (index - 1) * NAME_HEIGHT)
        button:Show()
        totalMoney = totalMoney + (entry.money or 0)
    end
    window.TotalText:SetText(L["Total: %s"]:format(GetMoneyString(totalMoney, true)))

    for key, button in pairs(window.ViewButtons) do
        button:SetEnabled(key ~= view)
    end

    -- Grid
    for _, button in pairs(itemButtons) do
        button:Hide()
    end
    for _, label in pairs(sectionLabels) do
        label:Hide()
    end

    local entry = selectedKey and BagBordersDB.characters[selectedKey]
    if not entry then
        window.Title:SetText(L["No characters saved yet"])
        window.MessageText:SetText("")
        return
    end

    local columns = (view == "bags" and BB.db.settings.columns or BB.db.settings.bankColumns) or 10
    local step = SLOT_SIZE + SLOT_GAP
    local sections, updated, message = GetSections(entry)
    local search = (window.SearchBox:GetText() or ""):lower()
    local y = 0
    local index = 0

    for sectionIndex, section in ipairs(sections) do
        if sectionIndex > 1 then
            y = y - SECTION_GAP
        end
        local color = BB.GENERAL_PALETTE[((sectionIndex - 1) % #BB.GENERAL_PALETTE) + 1]
        local free = 0
        for slot = 1, section.size or 0 do
            if not section.items[slot] then
                free = free + 1
            end
        end
        local label = GetSectionLabel(sectionIndex)
        label:SetText(L["%s  |cffffffff(%d free)|r"]:format(SectionName(section, sectionIndex), free))
        label:SetTextColor(color.r, color.g, color.b)
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", window.Content, "TOPLEFT", 0, y)
        label:Show()
        y = y - LABEL_HEIGHT

        for slot = 1, section.size or 0 do
            index = index + 1
            local button = GetItemButton(index)
            local item = section.items[slot]
            local link = item and item[2]
            button.link = link
            SetItemButtonTexture(button, item and item[5])
            SetItemButtonCount(button, item and item[3] or 0)
            SetItemButtonQuality(button, item and item[4], link)
            local border = BB.GetOrCreateBorder(button)
            border:SetVertexColor(color.r, color.g, color.b, 1)
            border:Show()
            local matches = search == "" or (item and ItemName(link):lower():find(search, 1, true))
            button:SetAlpha(matches and 1 or 0.25)
            local i0 = slot - 1
            local row, col = math.floor(i0 / columns), i0 % columns
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", window.Content, "TOPLEFT", col * step, y - row * step)
            button:Show()
        end
        y = y - math.ceil((section.size or 0) / columns) * step + SLOT_GAP
    end

    local contentWidth = columns * step - SLOT_GAP
    window.Content:SetSize(contentWidth, math.max(-y, 1))
    window:SetWidth(math.max(PADDING * 3 + SIDEBAR_WIDTH + contentWidth + 22, MIN_WIDTH))

    local who = (view == "account") and L["Account"] or (entry.name or selectedKey)
    window.Title:SetText(("%s - %s"):format(who, VIEWS[view]))
    window.MessageText:SetText(message or L["Saved %s - read only"]:format(FormatAge(updated)))
end

BB.RefreshAltViewer = Refresh

local function SetView(newView)
    view = newView
    window.Scroll:SetVerticalScroll(0)
    Refresh()
end

local function CreateViewer()
    window = CreateFrame("Frame", "BagBordersAltWindow", UIParent, "BackdropTemplate")
    window:Hide()
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetBackdrop(BACKDROP)
    window:SetBackdropColor(0.05, 0.05, 0.06, BB.db.settings.bgAlpha or 0.92)
    window:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    window:SetSize(700, HEADER_HEIGHT + VIEW_HEIGHT + FOOTER_HEIGHT)
    window:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    window:SetScript("OnDragStart", function(self)
        if not BB.db.settings.locked then
            self:StartMoving()
        end
    end)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    window.Title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    window.Title:SetPoint("TOPLEFT", window, "TOPLEFT", PADDING + 2, -10)

    -- Our own frame, so an ordinary close button is fine here.
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -2, -2)

    window.ViewButtons = {}
    local previous
    for _, key in ipairs({ "bags", "bank", "account" }) do
        local button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        button:SetText(VIEWS[key])
        button:SetSize(math.max(60, math.ceil((button:GetTextWidth() or 0) + 24)), 22)
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", 4, 0)
        else
            button:SetPoint("TOPLEFT", window, "TOPLEFT", PADDING + SIDEBAR_WIDTH, -28)
        end
        button:SetScript("OnClick", function()
            SetView(key)
        end)
        window.ViewButtons[key] = button
        previous = button
    end

    local search = CreateFrame("EditBox", "BagBordersAltSearchBox", window, "SearchBoxTemplate")
    search:SetHeight(20)
    search:SetAutoFocus(false)
    search:SetMaxLetters(40)
    -- Both anchors top-based so they agree; the right edge stays clear of the X.
    search:SetPoint("TOPLEFT", previous, "TOPRIGHT", 12, -1)
    search:SetPoint("TOPRIGHT", window, "TOPRIGHT", -36, -29)
    search:HookScript("OnTextChanged", Refresh)
    window.SearchBox = search

    local scroll = CreateFrame("ScrollFrame", "BagBordersAltScroll", window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", window, "TOPLEFT", PADDING * 2 + SIDEBAR_WIDTH, -HEADER_HEIGHT)
    scroll:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PADDING - 22, FOOTER_HEIGHT)
    window.Content = CreateFrame("Frame", nil, scroll)
    window.Content:SetSize(1, 1)
    scroll:SetScrollChild(window.Content)
    window.Scroll = scroll

    window.TotalText = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.TotalText:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", PADDING + 2, 10)
    window.MessageText = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.MessageText:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PADDING - 2, 10)

    window:SetScript("OnShow", function()
        selectedKey = selectedKey or BB.playerKey
        Refresh()
    end)
    window:SetScript("OnHide", function(self)
        self.SearchBox:ClearFocus()
    end)
end

function BB.ToggleAltViewer()
    if not BB.playerKey then
        return
    end
    if not window then
        CreateViewer()
    end
    window:SetShown(not window:IsShown())
end
