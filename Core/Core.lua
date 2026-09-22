local ADDON_NAME, BB = ...

BB.DEFAULTS = {
    settings = {},
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

    for _, callback in ipairs(BB.readyCallbacks) do
        callback()
    end
    BB.readyCallbacks = {}
end)

_G[ADDON_NAME] = BB
