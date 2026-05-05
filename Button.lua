-- SPDX-License-Identifier: GPL-2.0-or-later
-- BazBars Button Module
-- Creates action buttons, dispatches cursor/drag/click events to action
-- handlers (Actions/*.lua), and updates visuals (texture, cooldown, range,
-- usability, charge count, glow, tooltip).
--
-- All button state lives in btn.action = { type = "...", data = {...} }.
-- Every behavior delegates to the handler for that type via the registry.

local addon = BazCore:GetAddon("BazBars")
local Button = {}
addon.Button = Button

-- Localized globals for perf
local pairs = pairs
local InCombatLockdown = InCombatLockdown
local GetCursorInfo = GetCursorInfo
local ClearCursor = ClearCursor
local IsEquippedItem = C_Item.IsEquippedItem
local GameTooltip = GameTooltip

-- Textures
local EMPTY_SLOT = 136511 -- Interface\PaperDoll\UI-Backpack-EmptySlot
local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Pristine Cooldown instance used to call SetCooldown/Clear through its
-- unmodified metatable. Going through `btn.cooldown:SetCooldown(...)`
-- dispatches via the individual frame's (potentially tainted) method
-- table - in combat that taint path can make SetCooldown silently
-- no-op, which is why our cooldown animations were missing during
-- combat. Using the prototype's method directly bypasses that.
-- Same pattern as Blizzard's ActionButton (Blizzard_ActionBar/Shared/
-- ActionButton.lua:890).
local CooldownPrototype = CreateFrame("Cooldown")

---------------------------------------------------------------------------
-- Handler helper
---------------------------------------------------------------------------

-- Returns (handler, data) for the button's current action, or nil if empty.
local function GetHandler(btn)
    if not btn.action then return nil end
    local handler = BazBars.Actions:Get(btn.action.type)
    if not handler then return nil end
    return handler, btn.action.data
end

---------------------------------------------------------------------------
-- Visuals
---------------------------------------------------------------------------

function Button:UpdateTexture(btn)
    local icon = btn.icon

    if not btn.action then
        icon:Hide()
        CooldownPrototype.Clear(btn.cooldown)
        if btn.bbShowEmpty then
            btn:SetNormalTexture(EMPTY_SLOT)
        else
            btn:SetNormalTexture("")
        end
        return
    end

    local tex = Button:GetTexture(btn)
    if tex then
        icon:SetTexture(tex)
    else
        icon:SetTexture(QUESTION_MARK)
    end
    icon:Show()
end

function Button:GetTexture(btn)
    local handler, data = GetHandler(btn)
    if handler and handler.getIcon then
        return handler.getIcon(data)
    end
end

function Button:UpdateCooldown(btn)
    local handler, data = GetHandler(btn)
    if not handler then
        CooldownPrototype.Clear(btn.cooldown)
        btn.cooldown:Hide()
        return
    end

    -- Preferred path: handler applies the cooldown directly via Midnight's
    -- SetCooldownFromDurationObject (the only path that survives combat
    -- taint). Each handler owns its own cooldown update because the
    -- underlying API differs per type (spells use GetSpellCooldownDuration,
    -- items use GetItemCooldown numbers, etc.).
    if handler.applyCooldown then
        handler.applyCooldown(data, btn.cooldown)
        return
    end

    -- Legacy fallback: handler returns raw (start, duration) numbers.
    -- Used by Item and Toy handlers which don't have a duration-object
    -- API. Still routes through CooldownPrototype to avoid taint on the
    -- method dispatch itself.
    if handler.getCooldown then
        local start, duration, enable = handler.getCooldown(data)
        if start and duration and duration > 0 then
            btn.cooldown:Show()
            CooldownPrototype.SetCooldown(btn.cooldown, start, duration)
        else
            CooldownPrototype.Clear(btn.cooldown)
            btn.cooldown:Hide()
        end
        return
    end

    CooldownPrototype.Clear(btn.cooldown)
    btn.cooldown:Hide()
end

function Button:UpdateUsable(btn)
    if not btn.action then return end

    -- Out of range takes priority
    if btn._outOfRange then
        if addon.db.profile.fullRangeColor ~= false then
            btn.icon:SetVertexColor(0.8, 0.1, 0.1)
            if btn.NormalTexture then btn.NormalTexture:SetVertexColor(0.8, 0.1, 0.1) end
            if btn.Name then btn.Name:SetVertexColor(0.8, 0.1, 0.1) end
        end
        if btn.HotKey then btn.HotKey:SetVertexColor(0.8, 0.1, 0.1) end
        return
    end

    local handler, data = GetHandler(btn)
    if handler and handler.isUsable then
        local isUsable, insufficientPower = handler.isUsable(data)
        if isUsable then
            btn.icon:SetVertexColor(1.0, 1.0, 1.0)
        elseif insufficientPower then
            btn.icon:SetVertexColor(0.5, 0.5, 1.0)
        else
            btn.icon:SetVertexColor(0.4, 0.4, 0.4)
        end
    else
        btn.icon:SetVertexColor(1.0, 1.0, 1.0)
    end

    if btn.NormalTexture then btn.NormalTexture:SetVertexColor(1.0, 1.0, 1.0) end
    if btn.HotKey then btn.HotKey:SetVertexColor(0.6, 0.6, 0.6) end
    if btn.Name then btn.Name:SetVertexColor(1.0, 1.0, 1.0) end
end

function Button:UpdateRange(btn)
    if not btn.action then return end

    local outOfRange = false
    if UnitExists("target") then
        local handler, data = GetHandler(btn)
        if handler and handler.isInRange then
            local inRange = handler.isInRange(data, "target")
            if inRange == false then outOfRange = true end
        end
    end

    if outOfRange == btn._outOfRange then return end
    btn._outOfRange = outOfRange
    Button:UpdateUsable(btn)
end

function Button:UpdateCount(btn)
    local handler, data = GetHandler(btn)
    if handler and handler.getCount then
        btn.Count:SetText(handler.getCount(data) or "")
    else
        btn.Count:SetText("")
    end
end

function Button:ShowTooltip(btn)
    if not btn.action then return end
    if addon.db.profile.showTooltips == false then return end

    local handler, data = GetHandler(btn)
    if not handler or not handler.showTooltip then return end

    if addon.db.profile.tooltipAnchor == "button" then
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    else
        GameTooltip_SetDefaultAnchor(GameTooltip, btn)
    end
    handler.showTooltip(data)
    GameTooltip:Show()
end

function Button:UpdateGlow(btn)
    local handler, data = GetHandler(btn)
    if handler and handler.hasProcGlow and handler.hasProcGlow(data) then
        BazCore:ShowGlow(btn)
    else
        BazCore:HideGlow(btn)
    end
end

function Button:UpdateEquipped(btn)
    -- Only the Item handler has an item id that can be "equipped"
    if btn.action and btn.action.type == "item"
        and btn.action.data and btn.action.data.id
        and IsEquippedItem(btn.action.data.id)
    then
        if not btn.bbEquipBorder then
            btn.bbEquipBorder = btn:CreateTexture(nil, "OVERLAY")
            btn.bbEquipBorder:SetAtlas("UI-HUD-ActionBar-IconFrame-Border")
            btn.bbEquipBorder:SetAllPoints()
        end
        btn.bbEquipBorder:SetVertexColor(0, 1.0, 0, 0.5)
        btn.bbEquipBorder:Show()
    else
        if btn.bbEquipBorder then
            btn.bbEquipBorder:Hide()
        end
    end
end

function Button:UpdateMacroName(btn)
    if not btn.Name then return end
    if addon.db.profile.showMacroNames == false then
        btn.Name:SetText("")
        btn.Name:Hide()
        return
    end

    if btn.action and btn.action.type == "macro" and btn.action.data and btn.action.data.name then
        btn.Name:SetText(btn.action.data.name)
        btn.Name:Show()
    else
        btn.Name:SetText("")
    end
end

---------------------------------------------------------------------------
-- Full button update (called on events)
---------------------------------------------------------------------------

-- Render the small directional arrow overlay on flyout slots using
-- Blizzard's own UI-HUD-ActionBar-Flyout atlas (the same texture
-- Blizzard's action-bar flyouts use - confirmed via FrameXML's
-- Blizzard_Flyout/Flyout.xml). The atlas's natural orientation is "UP";
-- DOWN/LEFT/RIGHT rotate around the texture's center.
local FLYOUT_ARROW_ATLAS = "UI-HUD-ActionBar-Flyout"
local FLYOUT_ARROW_OFFSET = {
    UP    = { "TOP",     0,   3,    0           },
    DOWN  = { "BOTTOM",  0,  -3,    math.pi     },
    LEFT  = { "LEFT",   -3,   0,    math.pi / 2 },
    RIGHT = { "RIGHT",   3,   0,   -math.pi / 2 },
}

function Button:UpdateFlyoutArrow(btn)
    local isFlyout = btn.action and btn.action.type == "flyout"
    if not isFlyout then
        if btn.bbFlyoutArrow then btn.bbFlyoutArrow:Hide() end
        return
    end
    if not btn.bbFlyoutArrow then
        btn.bbFlyoutArrow = btn:CreateTexture(nil, "OVERLAY")
        btn.bbFlyoutArrow:SetAtlas(FLYOUT_ARROW_ATLAS, true)
    end
    local direction = (btn.action.data and btn.action.data.direction) or "UP"
    local geom = FLYOUT_ARROW_OFFSET[direction] or FLYOUT_ARROW_OFFSET.UP
    btn.bbFlyoutArrow:ClearAllPoints()
    btn.bbFlyoutArrow:SetPoint(geom[1], btn, geom[1], geom[2], geom[3])
    btn.bbFlyoutArrow:SetRotation(geom[4])
    btn.bbFlyoutArrow:Show()
end

function Button:UpdateButton(btn)
    Button:UpdateTexture(btn)
    Button:UpdateCooldown(btn)
    Button:UpdateUsable(btn)
    Button:UpdateCount(btn)
    Button:UpdateGlow(btn)
    Button:UpdateEquipped(btn)
    Button:UpdateMacroName(btn)
    Button:UpdateFlyoutArrow(btn)
end

---------------------------------------------------------------------------
-- Drag and drop
---------------------------------------------------------------------------

function Button:ReceiveDrag(btn)
    if InCombatLockdown() then
        ClearCursor()
        return
    end

    local handler, newData = BazBars.Actions:FromCursor()
    if not handler then return end

    ClearCursor()

    -- Swap: put current contents back on the cursor so the user can chain
    Button:PickUpCurrent(btn)

    Button:SetActionFromHandler(btn, handler, newData)
end

function Button:StartDrag(btn)
    if InCombatLockdown() then return end

    -- Locked bars don't allow dragging.
    if btn.bbBarData and btn.bbBarData.locked then return end

    if not btn.action then return end

    local handler = BazBars.Actions:Get(btn.action.type)
    if handler and handler.pickup then
        handler.pickup(btn.action.data)
    end
    Button:ClearAction(btn)
end

-- Put whatever's currently on the button onto the cursor (for swaps).
-- Returns true if something was picked up.
function Button:PickUpCurrent(btn)
    if not btn.action then return false end
    local handler = BazBars.Actions:Get(btn.action.type)
    if not handler or not handler.pickup then return false end
    handler.pickup(btn.action.data)
    return true
end

-- Apply a handler-based action to a button.
function Button:SetActionFromHandler(btn, handler, data)
    -- If the slot was previously a flyout and the new action isn't,
    -- tear down the popup + _onclick snippet so a stale right-click
    -- toggle doesn't keep opening a dead popup.
    if btn.action and btn.action.type == "flyout" and handler.type ~= "flyout" then
        if addon.FlyoutPopup and addon.FlyoutPopup.DetachFrom then
            addon.FlyoutPopup:DetachFrom(btn)
        end
    end

    btn.action = { type = handler.type, data = data }

    local selfCast = btn.bbBarData and btn.bbBarData.rightClickSelfCast
    BazBars.Actions:Apply(btn, btn.action, selfCast)

    Button:UpdateButton(btn)
    Button:SaveButton(btn)
end

function Button:ClearAction(btn)
    btn.action = nil
    BazBars.Actions:ClearButtonAttributes(btn)
    -- Tear down any flyout popup wired to this slot so right-click
    -- doesn't keep opening a stale grid after the slot is cleared.
    if addon.FlyoutPopup and addon.FlyoutPopup.DetachFrom then
        addon.FlyoutPopup:DetachFrom(btn)
    end
    Button:UpdateButton(btn)
    Button:SaveButton(btn)
end

---------------------------------------------------------------------------
-- Self-cast on right-click
---------------------------------------------------------------------------

function Button:ApplySelfCast(barFrame)
    local enabled = barFrame.barData.rightClickSelfCast
    for _, row in pairs(barFrame.buttons) do
        for _, btn in pairs(row) do
            -- Clear existing self-cast attrs
            btn:SetAttribute("type2", nil)
            btn:SetAttribute("spell2", nil)
            btn:SetAttribute("item2", nil)
            btn:SetAttribute("unit2", nil)

            if enabled and btn.action then
                local handler = BazBars.Actions:Get(btn.action.type)
                if handler and handler.applySelfCast then
                    handler.applySelfCast(btn, btn.action.data)
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Save / load
---------------------------------------------------------------------------

function Button:SaveButton(btn)
    local db = addon.db.profile.bars[btn.bbBarID]
    if not db then return end
    db.buttons = db.buttons or {}
    local key = btn.bbRow .. ":" .. btn.bbCol

    if btn.action then
        db.buttons[key] = BazBars.Actions:Serialize(btn.action)
    else
        db.buttons[key] = nil
    end
end

function Button:LoadButton(btn)
    local db = addon.db.profile.bars[btn.bbBarID]
    if not db or not db.buttons then return end

    local key = btn.bbRow .. ":" .. btn.bbCol
    local saved = db.buttons[key]
    if not saved then return end

    -- New format: { type = "...", data = {...} }
    if saved.type and saved.data then
        local action = BazBars.Actions:Deserialize(saved)
        if action then
            local handler = BazBars.Actions:Get(action.type)
            if handler then
                Button:SetActionFromHandler(btn, handler, action.data)
            end
        end
        return
    end

    -- Legacy format: { command, value, subValue, id, macrotext }
    -- Try to migrate via a registered handler's migrate() method.
    if saved.command then
        local action = BazBars.Actions:MigrateLegacy(saved)
        if action then
            local handler = BazBars.Actions:Get(action.type)
            if handler then
                Button:SetActionFromHandler(btn, handler, action.data)
            end
        end
    end
end

---------------------------------------------------------------------------
-- XML script handlers (wired by BazBars.xml)
---------------------------------------------------------------------------

function BazBarsButton_OnEnter(self)
    Button:ShowTooltip(self)
end

function BazBarsButton_OnReceiveDrag(self)
    Button:ReceiveDrag(self)
end

function BazBarsButton_OnDragStart(self)
    Button:StartDrag(self)
end

---------------------------------------------------------------------------
-- bar-slot context menu section
--
-- Three behaviours collapsed into one menu, registered against the
-- shared "bar-slot" scope so other addons can append entries:
--   * empty slot      -> "Create flyout (1x3)"
--   * flyout slot     -> "Configure flyout..."
--   * other filled    -> "Clear button"
---------------------------------------------------------------------------

local function GetBarSlotSection(ctx)
    if not ctx or not ctx.button then return end
    local btn    = ctx.button
    local action = ctx.action

    if not action then
        return {
            {
                label = "Create flyout...",
                onClick = function()
                    if InCombatLockdown() then return end
                    local Flyout = addon.FlyoutHandler
                    if not Flyout then return end
                    local handler = BazBars.Actions:Get("flyout")
                    if not handler then return end
                    -- Seed with a default 1x3 so the slot is a flyout
                    -- the moment the config form opens; the user
                    -- adjusts rows / cols / direction / mode in the
                    -- form and the live preview reshapes as they go.
                    Button:SetActionFromHandler(btn, handler,
                        Flyout.MakeDefault({ rows = 1, cols = 3 }))
                    if addon.FlyoutPopup and addon.FlyoutPopup.OpenConfig then
                        addon.FlyoutPopup:OpenConfig(btn)
                    end
                end,
            },
        }
    end

    if action.type == "flyout" then
        return {
            {
                label = "Configure flyout...",
                onClick = function()
                    if InCombatLockdown() then return end
                    if addon.FlyoutPopup and addon.FlyoutPopup.OpenConfig then
                        addon.FlyoutPopup:OpenConfig(btn)
                    end
                end,
            },
        }
    end

    return {
        {
            label = "Clear button",
            onClick = function()
                if InCombatLockdown() then return end
                Button:ClearAction(btn)
            end,
        },
    }
end

if BazCore.RegisterContextMenuSection then
    BazCore:RegisterContextMenuSection("bar-slot", "BazBars", GetBarSlotSection)
end

function BazBarsButton_PostClick(self, button)
    if InCombatLockdown() then return end

    -- Shift+Right-Click opens a context menu. BazBars's own actions
    -- (spawn flyout / configure flyout / clear button) live as
    -- entries in that menu, sharing the popup with any other addon
    -- that registers under the "bar-slot" scope (BazTooltipEditor's
    -- "Inspect this tooltip" being the first such consumer).
    if button == "RightButton" and IsShiftKeyDown() then
        if BazCore.OpenContextMenu then
            -- No title intentionally - the slot's icon is already
            -- visible right next to the menu, so a title would just
            -- echo what the user can see. Bag-stack menus need the
            -- item link as a title to disambiguate stack vs single,
            -- but bar slots don't have that ambiguity.
            BazCore:OpenContextMenu("bar-slot", self, {
                button = self,
                action = self.action,
            })
        end
        return
    end

    Button:UpdateButton(self)
end
