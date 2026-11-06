local ADDON_NAME, BB = ...

BB.DEFAULTS = {
    settings = {
        -- In combined mode, make the Toggle Backpack key open all bags so the
        -- reagent bag opens with the combined window (Modules/ReagentDock.lua).
        openReagentWithBackpack = true,
        -- BagBorders' own all-in-one bag window (UI/). Read once at load, so
        -- changing it needs a /reload. Off = Blizzard's windows + the dock.
        window = true,
        columns = 10,
        scale = 1,
        locked = false,
        windowPos = nil, -- { point, relativePoint, x, y }, set when dragged
        bankColumns = 14,
        bankPos = nil,
        bagStrip = true,   -- equipped-bag strip under the search box
        hiddenBags = {},   -- [bagID] = true: slots hidden while the strip is open
        itemLevel = true,  -- item level on gear in the bag and bank windows
        bgAlpha = 0.92,    -- bag/bank window background opacity
        tooltipCounts = true, -- item tooltips list counts on your other characters
    },
}

local function ApplyDefaults(defaults, target)
    target = target or {}
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = ApplyDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

BB.readyCallbacks = {}

function BB:OnDBReady(callback)
    if BB.db then
        callback()
    else
        table.insert(BB.readyCallbacks, callback)
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")

    BagBordersDB = ApplyDefaults(BB.DEFAULTS, BagBordersDB)
    BB.db = BagBordersDB

    -- Fixed for the session: the takeover can't be undone without a /reload.
    BB.windowActive = BB.db.settings.window and not InputUtil.IsGamepadUIEnabled()

    for _, callback in ipairs(BB.readyCallbacks) do
        callback()
    end
    BB.readyCallbacks = {}
end)

_G[ADDON_NAME] = BB
