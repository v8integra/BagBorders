local ADDON_NAME, BB = ...
local L = BB.L

-- The bag strip in the BagBorders bag window: one button per equipped bag
-- (backpack, bags, reagent bag), in the bag's border color.
--
-- - Hover: lights up that bag's slots and shows the bag's tooltip.
-- - Click: hides or shows that bag's slots (saved; only while the strip is open).
-- - Drag a bag off to unequip it; drop a bag (or click with one) to equip it.
--
-- Bags are moved with the same unrestricted calls Blizzard's bag bar uses
-- (PickupBagFromSlot / PutItemInBag / PutItemInBackpack). Only our own frames
-- are touched.

local SLOT_SIZE = 37
local BACKPACK_ICON = [[Interface\Buttons\Button-Backpack-Up]]
local EMPTY_BAG_ICON = [[Interface\PaperDoll\UI-PaperDoll-Slot-Bag]]

local function GetInventoryID(bagID)
    if bagID == Enum.BagIndex.Backpack then
        return nil
    end
    return C_Container.ContainerIDToInventoryID(bagID)
end

local function SetSlotsHighlighted(bagID, on)
    local holder = BB.GetBagWindowHolder(bagID)
    if not holder then
        return
    end
    for slot = 1, holder.numSlots or 0 do
        local button = holder.buttons[slot]
        if button then
            if on then
                button:LockHighlight()
            else
                button:UnlockHighlight()
            end
        end
    end
end

local function OnEnter(self)
    SetSlotsHighlighted(self.bagID, true)

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local invID = GetInventoryID(self.bagID)
    if not invID then
        GameTooltip:SetText(BACKPACK_TOOLTIP or L["Backpack"])
    elseif not GameTooltip:SetInventoryItem("player", invID) then
        GameTooltip:SetText(EQUIP_CONTAINER or L["Equip Container"])
    end
    if C_Container.GetContainerNumSlots(self.bagID) > 0 then
        local hidden = BB.db.settings.hiddenBags[self.bagID]
        GameTooltip:AddLine(hidden and L["Click to show its slots"] or L["Click to hide its slots"], 0.6, 0.8, 1)
    end
    GameTooltip:Show()
end

local function OnLeave(self)
    SetSlotsHighlighted(self.bagID, false)
    GameTooltip_Hide()
end

-- Equip whatever bag is on the cursor into this slot.
local function PutCursorItem(self)
    local invID = GetInventoryID(self.bagID)
    if invID then
        PutItemInBag(invID)
    else
        PutItemInBackpack()
    end
end

local function OnClick(self)
    if CursorHasItem() then
        PutCursorItem(self)
        return
    end
    if C_Container.GetContainerNumSlots(self.bagID) == 0 then
        return
    end
    local hidden = BB.db.settings.hiddenBags
    hidden[self.bagID] = not hidden[self.bagID] or nil
    BB.RelayoutBagWindow()
    if self:IsMouseOver() then
        OnEnter(self)
    end
end

local function OnDragStart(self)
    local invID = GetInventoryID(self.bagID)
    if invID then
        PickupBagFromSlot(invID)
    end
end

function BB.GetStripButton(window, buttons, bagID)
    local button = buttons[bagID]
    if not button then
        button = CreateFrame("ItemButton", "BagBordersBagStrip" .. bagID, window)
        button:SetSize(SLOT_SIZE, SLOT_SIZE)
        button.bagID = bagID
        button:RegisterForDrag("LeftButton")
        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnEnter", OnEnter)
        button:SetScript("OnLeave", OnLeave)
        button:SetScript("OnClick", OnClick)
        button:SetScript("OnDragStart", OnDragStart)
        button:SetScript("OnReceiveDrag", PutCursorItem)
        buttons[bagID] = button
    end
    return button
end

-- Called after the item refresh, so bag colors are already handed out.
function BB.UpdateStripButton(button)
    local bagID = button.bagID
    local invID = GetInventoryID(bagID)
    local texture
    if invID then
        texture = GetInventoryItemTexture("player", invID)
    else
        texture = BACKPACK_ICON
    end
    SetItemButtonTexture(button, texture or EMPTY_BAG_ICON)

    local hidden = BB.db.settings.hiddenBags[bagID] and true or false
    SetItemButtonDesaturated(button, hidden)
    button:SetAlpha(hidden and 0.5 or 1)

    local border = BB.GetOrCreateBorder(button)
    local color = BB.GetAssignedBagColor(bagID)
    if color and texture then
        border:SetVertexColor(color.r, color.g, color.b, 1)
        border:Show()
    else
        border:Hide()
    end

    local label = BB.GetOrCreateFreeSlotLabel(button)
    if texture and C_Container.GetContainerNumSlots(bagID) > 0 then
        label:SetText(C_Container.GetContainerNumFreeSlots(bagID) or 0)
        if color then
            label:SetTextColor(color.r, color.g, color.b)
        end
        label:Show()
    else
        label:Hide()
    end
end
