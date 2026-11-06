local ADDON_NAME, BB = ...
local L = BB.L

-- BagBorders' page in Blizzard's Options > AddOns, built with Blizzard's own
-- Settings API (it registers through a secure delegate, so it can't taint).
-- Every control is a proxy setting over BB.db.settings, so the slash commands
-- and this page always show the same values. /bagborders opens it.

local category

local function Round(value)
    return math.floor(value + 0.5)
end

local function RelayoutWindows()
    if BB.RelayoutBagWindow then
        BB.RelayoutBagWindow()
    end
    if BB.RelayoutBankWindow then
        BB.RelayoutBankWindow()
    end
end

local function ApplyBackdropAlpha()
    local alpha = BB.db.settings.bgAlpha
    for _, window in ipairs({ BB.BagWindow, BB.BankWindow }) do
        if window then
            window:SetBackdropColor(0.05, 0.05, 0.06, alpha)
        end
    end
end

local function FormatPercent(value)
    return ("%d%%"):format(Round(value * 100))
end

-- One proxy setting over BB.db.settings[key]. transform turns the control's
-- value into what we store (sliders hand back floats); apply runs after.
local function AddSetting(key, varType, name, defaultValue, transform, apply)
    local function GetValue()
        return BB.db.settings[key]
    end
    local function SetValue(value)
        if transform then
            value = transform(value)
        end
        BB.db.settings[key] = value
        if apply then
            apply(value)
        end
    end
    return Settings.RegisterProxySetting(category, "BAGBORDERS_" .. key:upper(), varType, name, defaultValue, GetValue, SetValue)
end

local function AddCheckbox(key, name, tooltip, apply)
    local setting = AddSetting(key, Settings.VarType.Boolean, name, BB.DEFAULTS.settings[key], nil, apply)
    Settings.CreateCheckbox(category, setting, tooltip)
    return setting
end

local function AddSlider(key, name, tooltip, minValue, maxValue, step, formatter, transform, apply)
    local setting = AddSetting(key, Settings.VarType.Number, name, BB.DEFAULTS.settings[key], transform, apply)
    local options = Settings.CreateSliderOptions(minValue, maxValue, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter or Round)
    Settings.CreateSlider(category, setting, options, tooltip)
    return setting
end

local function AddHeader(layout, text)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
end

local function AddButton(layout, name, buttonText, onClick, tooltip)
    layout:AddInitializer(CreateSettingsButtonInitializer(name, buttonText, onClick, tooltip, true))
end

local function Build()
    local layout
    category, layout = Settings.RegisterVerticalLayoutCategory("BagBorders")

    AddHeader(layout, L["Bag and bank windows"])
    AddCheckbox("window", L["Use the BagBorders windows"],
        L["One window for all your bags, and one for the bank. Off = Blizzard's bag windows (still with BagBorders colors). Takes effect after a UI reload."],
        function(value)
            if value ~= BB.windowActive then
                print("|cffffd100BagBorders:|r " .. L["reload your UI (button below) to switch windows."])
            end
        end)
    AddButton(layout, L["Apply window change"], L["Reload UI"], function()
        if InCombatLockdown() then
            print("|cffffd100BagBorders:|r " .. L["can't reload in combat."])
            return
        end
        ReloadUI()
    end, L["Reloads the UI so turning the windows on or off takes effect."])

    AddSlider("columns", L["Bag columns"], L["How many slots wide the bag window is."],
        4, 30, 1, nil, Round, RelayoutWindows)
    AddSlider("bankColumns", L["Bank columns"], L["How many slots wide the bank window is."],
        6, 30, 1, nil, Round, RelayoutWindows)
    AddSlider("scale", L["Window scale"], L["Size of the bag and bank windows."],
        0.5, 2, 0.05, FormatPercent, function(value)
            return Round(value * 100) / 100
        end, function(value)
            BB.SetBagWindowScale(value)
        end)
    AddSlider("bgAlpha", L["Background opacity"], L["How see-through the window backgrounds are."],
        0, 1, 0.05, FormatPercent, function(value)
            return Round(value * 100) / 100
        end, ApplyBackdropAlpha)
    AddCheckbox("locked", L["Lock window position"], L["Stops the bag and bank windows from being dragged."])
    AddButton(layout, L["Window position"], L["Reset"], function()
        if InCombatLockdown() then
            print("|cffffd100BagBorders:|r " .. L["can't move the windows in combat."])
            return
        end
        BB.ResetBagWindowPosition()
    end, L["Puts both windows back in their default spots at 100% scale."])

    AddHeader(layout, L["Finding things"])
    AddCheckbox("bagStrip", L["Show the bag strip"],
        L["Your equipped bags across the top of the bag window. Click one to hide or show its slots."],
        function()
            if BB.RelayoutBagWindow then
                BB.RelayoutBagWindow()
            end
        end)
    AddCheckbox("itemLevel", L["Item level on gear"],
        L["Shows the item level on weapons and armor in the bag and bank windows, colored by quality."],
        RelayoutWindows)

    AddHeader(layout, L["Alts"])
    AddCheckbox("tooltipCounts", L["Item counts in tooltips"],
        L["Item tooltips list how many each of your characters has in their bags and bank, plus the account bank. Characters are remembered once you log in on them; banks once you open them."])
    AddButton(layout, L["Alt bags and banks"], L["Open viewer"], function()
        if BB.ToggleAltViewer then
            BB.ToggleAltViewer()
        end
    end, L["Read-only view of your characters' bags, banks and the account bank. Also: the Alts button on the bag window, or /bagborders alts."])

    AddHeader(layout, L["Blizzard bag windows"])
    AddCheckbox("openReagentWithBackpack", L["Toggle Backpack key opens the reagent bag"],
        L["With Blizzard's combined bags (BagBorders windows off), your Toggle Backpack key opens the reagent bag too."],
        function()
            if BB.ApplyBackpackKeyOverride then
                BB.ApplyBackpackKeyOverride()
            end
        end)

    Settings.RegisterAddOnCategory(category)
end

function BB.OpenOptions()
    if not category then
        return
    end
    if InCombatLockdown() then
        print("|cffffd100BagBorders:|r " .. L["options open after combat - or use /bagborders help."])
        return
    end
    Settings.OpenToCategory(category:GetID())
end

BB:OnDBReady(function()
    local ok, err = pcall(Build)
    if not ok then
        category = nil
        print("|cffff4444BagBorders:|r options page failed to load - " .. tostring(err))
    end
end)
