local ADDON_NAME, BB = ...

-- Remembers every character's bags, bank and money in BagBordersDB so the alt
-- viewer (UI/AltViewer.lua) and tooltip counts (Modules/TooltipCounts.lua)
-- work while those characters are logged out.
--
--   BagBordersDB.characters["Name-Realm"] = {
--       name, realm, class, faction, money, updated,
--       bags = { { id = bagID, size = n, items = { [slot] = item } }, ... },
--       bank = { { id = tabID, name = "Tab", size = n, items = {...} }, ... } or nil,
--       bankUpdated = time,
--   }
--   BagBordersDB.accountBank = { tabs = { ...same as bank... }, updated = time }
--   item = { itemID, link, count, quality, icon }
--
-- Bags are read whenever they change; the bank only while it's open (the game
-- only sends bank contents then). Reading is plain C_Container/C_Bank calls on
-- our own tables, so nothing here can taint.

local playerKey
local bankOpen = false
local scanQueued = {}

-- Bumped on every write so cached tooltip counts know to recount.
BB.cacheVersion = 0

local function ReadContainer(bagID)
    local size = C_Container.GetContainerNumSlots(bagID) or 0
    local items = {}
    for slot = 1, size do
        local info = C_Container.GetContainerItemInfo(bagID, slot)
        if info and info.itemID then
            items[slot] = { info.itemID, info.hyperlink, info.stackCount or 1, info.quality, info.iconFileID }
        end
    end
    return size, items
end

local function GetBagIDs()
    local ids = {}
    for bagID = Enum.BagIndex.Backpack, NUM_TOTAL_BAG_FRAMES do
        table.insert(ids, bagID)
    end
    if C_ActionBar and C_ActionBar.ShouldShowKeyring and C_ActionBar.ShouldShowKeyring() then
        table.insert(ids, KEYRING_CONTAINER)
    end
    return ids
end

local function ReadTabs(bankType)
    if C_Bank.FetchBankLockedReason(bankType) then
        return nil
    end
    local tabs = {}
    for _, tab in ipairs(C_Bank.FetchPurchasedBankTabData(bankType) or {}) do
        local size, items = ReadContainer(tab.ID)
        table.insert(tabs, { id = tab.ID, name = tab.name or "", size = size, items = items })
    end
    return tabs
end

local function GetEntry()
    local entry = BagBordersDB.characters[playerKey]
    if not entry then
        entry = {}
        BagBordersDB.characters[playerKey] = entry
    end
    entry.name = UnitName("player")
    entry.realm = GetRealmName()
    entry.class = select(2, UnitClass("player"))
    entry.faction = UnitFactionGroup("player")
    return entry
end

local function ScanBags()
    scanQueued.bags = false
    local entry = GetEntry()
    local bags = {}
    for _, bagID in ipairs(GetBagIDs()) do
        local size, items = ReadContainer(bagID)
        if size > 0 then
            table.insert(bags, { id = bagID, size = size, items = items })
        end
    end
    entry.bags = bags
    entry.money = GetMoney()
    entry.updated = time()
    BB.cacheVersion = BB.cacheVersion + 1
    if BB.RefreshAltViewer then
        BB.RefreshAltViewer()
    end
end

local function ScanBank()
    scanQueued.bank = false
    if not bankOpen then
        return
    end
    local entry = GetEntry()
    local tabs = ReadTabs(Enum.BankType.Character)
    if tabs then
        entry.bank = tabs
        entry.bankUpdated = time()
    end
    if C_Bank.CanViewBank(Enum.BankType.Account) then
        local accountTabs = ReadTabs(Enum.BankType.Account)
        if accountTabs then
            BagBordersDB.accountBank = { tabs = accountTabs, updated = time() }
        end
    end
    BB.cacheVersion = BB.cacheVersion + 1
    if BB.RefreshAltViewer then
        BB.RefreshAltViewer()
    end
end

-- Bags can change many times a second (looting, sorting); read once it settles.
local function Queue(which, fn)
    if scanQueued[which] then
        return
    end
    scanQueued[which] = true
    C_Timer.After(0.5, fn)
end

local BANK_EVENTS = {
    PLAYERBANKSLOTS_CHANGED = true, PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED = true,
    BANK_TABS_CHANGED = true, BANK_TAB_SETTINGS_UPDATED = true,
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        BagBordersDB.characters = BagBordersDB.characters or {}
        playerKey = UnitName("player") .. "-" .. GetRealmName()
        BB.playerKey = playerKey
        for _, e in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_MONEY", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
                "PLAYERBANKSLOTS_CHANGED", "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", "BANK_TABS_CHANGED",
                "BANK_TAB_SETTINGS_UPDATED", "PLAYER_LOGOUT" }) do
            self:RegisterEvent(e)
        end
        ScanBags()
    elseif event == "PLAYER_LOGOUT" then
        ScanBags()
        if bankOpen then
            ScanBank()
        end
    elseif event == "BANKFRAME_OPENED" then
        bankOpen = true
        Queue("bank", ScanBank)
    elseif event == "BANKFRAME_CLOSED" then
        if bankOpen then
            ScanBank() -- last look before the contents go away
        end
        bankOpen = false
    elseif event == "BAG_UPDATE_DELAYED" then
        Queue("bags", ScanBags)
        if bankOpen then
            Queue("bank", ScanBank)
        end
    elseif event == "PLAYER_MONEY" then
        local entry = BagBordersDB.characters[playerKey]
        if entry then
            entry.money = GetMoney()
        end
    elseif BANK_EVENTS[event] and bankOpen then
        Queue("bank", ScanBank)
    end
end)

-- Characters sorted by realm then name (current character first).
function BB.GetCachedCharacters()
    local list = {}
    for key, entry in pairs(BagBordersDB.characters or {}) do
        table.insert(list, { key = key, entry = entry })
    end
    table.sort(list, function(a, b)
        if (a.key == playerKey) ~= (b.key == playerKey) then
            return a.key == playerKey
        end
        if a.entry.realm ~= b.entry.realm then
            return (a.entry.realm or "") < (b.entry.realm or "")
        end
        return (a.entry.name or a.key) < (b.entry.name or b.key)
    end)
    return list
end

function BB.ForgetCharacter(key)
    if key == playerKey or not BagBordersDB.characters[key] then
        return false
    end
    BagBordersDB.characters[key] = nil
    BB.cacheVersion = BB.cacheVersion + 1
    return true
end

-- For tests and /bagborders debug.
BB.ScanCachedBags = ScanBags
BB.ScanCachedBank = ScanBank
