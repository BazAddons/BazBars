-- SPDX-License-Identifier: GPL-2.0-or-later
-- BazBars Flyout Action Handler
--
-- A flyout slot acts like a hybrid spell button + custom popup:
--   * Left-click  -> casts the slot's "current" spell.
--   * Right-click -> toggles a custom popup with all the flyout's spells.
--
-- Sources:
--   * Native: dropping a Blizzard flyout (e.g. Mage Teleport) from the
--     spellbook stores the flyoutID and resolves cells live from
--     C_SpellBook each refresh, so newly-learned variants appear
--     automatically.
--   * Custom: a slot whose cells are user-pinned spells. Created via
--     shift-click on an empty slot; spells are then dropped onto cells
--     in the popup directly.
--
-- Current-spell logic:
--   * mode == "lastUsed" -> currentSpellID updates whenever the user
--     casts a cell from the popup. Optionally persists across reloads.
--   * mode == "specific" -> pinnedSpellID is the slot's left-click action.
--
-- Fallback: if the preferred spell is unlearned or absent, fall back to
-- the next available cell. If no cells are available the slot reverts
-- to empty (deserialize returns nil).

local addon = BazCore:GetAddon("BazBars")
local Actions = BazBars.Actions

---------------------------------------------------------------------------
-- Local helpers
---------------------------------------------------------------------------

local function GetSpellName(spellID)
    if not spellID then return nil end
    local info = C_Spell.GetSpellInfo(spellID)
    return info and info.name or nil
end

local function SpellIsKnown(spellID)
    if not spellID then return false end
    if IsSpellKnownOrOverridesKnown then
        local ok, known = pcall(IsSpellKnownOrOverridesKnown, spellID)
        if ok and known then return true end
    end
    if IsSpellKnown then
        local ok, known = pcall(IsSpellKnown, spellID)
        if ok and known then return true end
    end
    return C_Spell.GetSpellInfo(spellID) ~= nil
end

-- API normalizers - retail still ships the legacy global-scope
-- GetFlyoutInfo / GetFlyoutSlotInfo, while C_SpellBook may or may not
-- expose the same calls in a given build. Try the namespaced version
-- first, fall back to the global so we work either way.
local function FlyoutNumSlots(flyoutID)
    if C_SpellBook and C_SpellBook.GetFlyoutInfo then
        local info = C_SpellBook.GetFlyoutInfo(flyoutID)
        if info and info.numSlots then return info.numSlots end
    end
    if GetFlyoutInfo then
        local _, _, numSlots = GetFlyoutInfo(flyoutID)
        return numSlots
    end
end

local function FlyoutSlot(flyoutID, slotIndex)
    if C_SpellBook and C_SpellBook.GetFlyoutSlotInfo then
        local info = C_SpellBook.GetFlyoutSlotInfo(flyoutID, slotIndex)
        if info and info.spellID then
            return info.spellID, info.isKnown ~= false
        end
    end
    if GetFlyoutSlotInfo then
        local spellID, _, isKnown = GetFlyoutSlotInfo(flyoutID, slotIndex)
        if spellID then return spellID, isKnown ~= false end
    end
end

local function FlyoutDisplayInfo(flyoutID)
    if C_SpellBook and C_SpellBook.GetFlyoutInfo then
        local info = C_SpellBook.GetFlyoutInfo(flyoutID)
        if info then return info.name, info.description end
    end
    if GetFlyoutInfo then
        local name, desc = GetFlyoutInfo(flyoutID)
        return name, desc
    end
end

-- Cells are stored as full BazBars actions: { type = "spell|item|mount|
-- toy|macro|...", data = {...} }. This lets a flyout cell be any of the
-- action types BazBars already understands - spells, items, toys,
-- mounts, macros, equipment sets, battle pets - and reuse the same
-- registry machinery (Apply, FromCursor, getIcon, showTooltip, etc.)
-- that drives the regular bar slots.
local function ResolveCells(data)
    if not data then return {} end

    if data.flyoutID then
        local cells = {}
        local numSlots = FlyoutNumSlots(data.flyoutID)
        if not numSlots then return cells end
        for i = 1, numSlots do
            local spellID, isKnown = FlyoutSlot(data.flyoutID, i)
            if spellID then
                cells[#cells + 1] = {
                    type    = "spell",
                    data    = { id = spellID },
                    isKnown = isKnown,
                }
            end
        end
        return cells
    end

    if data.cells then
        -- Cells are sparse-indexed (holes allowed) so a drop on cell 5
        -- with cells 1-4 empty stays at index 5. Iterate by index.
        local out = {}
        for k, c in pairs(data.cells) do
            if type(k) == "number" and c and c.type and c.data then
                local cell = { type = c.type, data = c.data }
                if c.type == "spell" and c.data.id then
                    cell.isKnown = SpellIsKnown(c.data.id)
                else
                    cell.isKnown = true
                end
                out[k] = cell
            end
        end
        return out
    end

    return {}
end

-- Highest occupied index in a (possibly sparse) cell map.
local function MaxCellIndex(cells)
    if not cells then return 0 end
    local m = 0
    for k in pairs(cells) do
        if type(k) == "number" and k > m then m = k end
    end
    return m
end

-- Pick the cell action that the slot's left-click should run. Returns
-- nil when no usable cell exists (caller treats nil as empty).
local function GetCurrentAction(data)
    if not data then return nil end
    local cells = ResolveCells(data)
    local maxIdx = MaxCellIndex(cells)
    if maxIdx == 0 then return nil end

    local preferIndex
    if data.mode == "specific" then
        preferIndex = data.pinnedIndex
    else
        preferIndex = data.currentIndex
    end

    local function asAction(cell)
        return { type = cell.type, data = cell.data }
    end

    if preferIndex and cells[preferIndex] and cells[preferIndex].isKnown then
        return asAction(cells[preferIndex])
    end

    for i = 1, maxIdx do
        local c = cells[i]
        if c and c.isKnown then return asAction(c) end
    end

    return nil
end

---------------------------------------------------------------------------
-- Handler
---------------------------------------------------------------------------

local Flyout = {
    type = "flyout",
    -- Run before Spell (priority 50) so a flyout cursor is captured by
    -- this handler rather than (mistakenly) by the spell handler.
    priority = 30,
}

addon.FlyoutHandler = Flyout

-- Build a default flyout data table. shape can override rows/cols.
function Flyout.MakeDefault(shape)
    return {
        flyoutID = nil,
        cells = nil,
        direction = "UP",
        rows = (shape and shape.rows) or 1,
        cols = (shape and shape.cols) or 3,
        mode = "lastUsed",
        pinnedIndex = nil,
        currentIndex = nil,
        persistCurrent = true,
    }
end

-- Public helpers exposed for other modules (FlyoutPopup, EditSettings).
Flyout.ResolveCells     = ResolveCells
Flyout.GetCurrentAction = GetCurrentAction
Flyout.MaxCellIndex     = MaxCellIndex

---------------------------------------------------------------------------
-- Cursor
---------------------------------------------------------------------------

-- WoW has no native cursor type for "BazBars flyout config", so dragging
-- a flyout slot off the bar uses an internal carrier: the flyout's data
-- table is stashed in this module variable, and a small icon-follower
-- frame is shown next to the mouse cursor for visual feedback (using
-- the slot's actual icon, exactly the texture currently rendered on the
-- button). Bar.lua's PreClick/PostClick hooks check `Flyout.HasPending`
-- alongside `GetCursorInfo` so dropping the carry onto another slot
-- routes through the same drop path real cursor contents use.
local pendingFlyout = nil

local function GetCursorFollower()
    if Flyout._cursorFollower then return Flyout._cursorFollower end
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(36, 36)
    f:SetFrameStrata("TOOLTIP")
    f:Hide()

    f.icon = f:CreateTexture(nil, "OVERLAY")
    f.icon:SetAllPoints()
    f.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)

    f:SetScript("OnUpdate", function(self)
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
            x / scale + 18, y / scale - 18)
    end)

    Flyout._cursorFollower = f
    return f
end

local function HideFollower()
    if Flyout._cursorFollower then Flyout._cursorFollower:Hide() end
end

function Flyout.HasPending()
    return pendingFlyout ~= nil
end

function Flyout.ClearPending()
    if pendingFlyout then
        pendingFlyout = nil
        HideFollower()
    end
end

-- Auto-cancel the carry when WoW clears the cursor (Escape, click on
-- empty world, addon-driven ClearCursor calls).
if not Flyout._cursorHooked then
    hooksecurefunc("ClearCursor", function()
        if pendingFlyout then
            pendingFlyout = nil
            HideFollower()
        end
    end)
    Flyout._cursorHooked = true
end

-- Drop-in-empty-space cleanup. The ClearCursor hook above only fires
-- when WoW itself clears the cursor (Escape, certain unaccepted drops);
-- a drag-and-release into an empty area of the screen often doesn't
-- trigger ClearCursor at all, leaving pendingFlyout stuck. Without this,
-- a subsequent click on the now-empty slot - or any other slot - would
-- treat the leftover carrier as an incoming drop and re-paint the
-- flyout that the user thought they'd just deleted.
--
-- GLOBAL_MOUSE_UP fires after every mouse release. Frame-level handlers
-- (OnReceiveDrag, PostClick) run BEFORE this event, so legitimate drops
-- onto another BazBars slot or any handler that accepts the carrier
-- have already cleared pendingFlyout via ReceiveDrag by the time we
-- get here. Anything still carried at this point is by definition
-- unaccepted and should be discarded.
if not Flyout._mouseUpHooked then
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("GLOBAL_MOUSE_UP")
    watcher:SetScript("OnEvent", function()
        if pendingFlyout then
            pendingFlyout = nil
            HideFollower()
        end
    end)
    Flyout._mouseUpHooked = true
end

function Flyout.fromCursor()
    -- Native flyout dragged from the spellbook.
    local cType, flyoutID = GetCursorInfo()
    if cType == "flyout" and flyoutID then
        local cols = 3
        local numSlots = FlyoutNumSlots(flyoutID)
        if numSlots and numSlots > 0 then cols = numSlots end

        return {
            flyoutID = flyoutID,
            direction = "UP",
            rows = 1,
            cols = cols,
            mode = "lastUsed",
            persistCurrent = true,
        }
    end

    -- Internal carry from a slot-to-slot drag. Only claim the drop when
    -- the actual cursor is empty - that's the legitimate "finishing a
    -- carry" case. If cType is non-nil here, the user picked something
    -- else up (item from bag, spell from spellbook, etc.) without
    -- finishing the carry; the stale carrier should yield so the real
    -- handler can claim. Without this, a leftover pendingFlyout would
    -- intercept every subsequent drop because Flyout sorts ahead of
    -- Item / Spell / etc. in the cursor-detection priority order.
    if pendingFlyout then
        if cType then
            pendingFlyout = nil
            HideFollower()
            return
        end
        local data = pendingFlyout
        pendingFlyout = nil
        HideFollower()
        return data
    end
end

function Flyout.pickup(data)
    -- Two roles for pickup:
    --   1. Slot-to-slot move (Button:StartDrag passes the slot's data) -
    --      stash it on the carrier and show the follower icon.
    --   2. Cursor cleanup when no data is supplied - just bail.
    if not data then
        ClearCursor()
        return
    end

    -- Replace anything else on the cursor so the carrier is the only
    -- pending drop.
    ClearCursor()

    pendingFlyout = data
    local icon = Flyout.getIcon and Flyout.getIcon(data)
    if icon then
        local follower = GetCursorFollower()
        follower.icon:SetTexture(icon)
        follower:Show()
    end
end

---------------------------------------------------------------------------
-- Button attributes
---------------------------------------------------------------------------

function Flyout.apply(button, data)
    -- Left-click runs the current cell's action via the BazBars action
    -- registry - same path the regular bar slots use, so spells, items,
    -- mounts, toys, macros, equipment sets, and battle pets all work
    -- without flyout-specific casing here.
    local current = GetCurrentAction(data)
    if current then
        BazBars.Actions:Apply(button, current, false)
    else
        BazBars.Actions:ClearButtonAttributes(button)
    end

    -- Hand off to the popup module for cell construction + secure
    -- right-click toggle wiring. AttachTo overwrites type2 / clickbutton
    -- so right-click toggles the popup instead of triggering whatever
    -- the action handler set there.
    if addon.FlyoutPopup and addon.FlyoutPopup.AttachTo then
        addon.FlyoutPopup:AttachTo(button, data)
    end
end

-- Self-cast doesn't apply to flyouts: the right mouse button is reserved
-- for opening the popup. Intentionally left unimplemented.
Flyout.applySelfCast = nil

---------------------------------------------------------------------------
-- Visuals - everything delegates to the current cell's action handler,
-- so a flyout slot looks and behaves like whatever its current cell
-- would as a regular bar slot.
---------------------------------------------------------------------------

local function CurrentHandler(data)
    local current = GetCurrentAction(data)
    if not current then return nil, nil end
    local handler = BazBars.Actions:Get(current.type)
    return handler, current.data
end

function Flyout.getIcon(data)
    local handler, hData = CurrentHandler(data)
    if handler and handler.getIcon then
        local icon = handler.getIcon(hData)
        if icon then return icon end
    end
    -- Fallback to the first cell's icon even when no current handler
    -- resolved (e.g. flyout from a character that hasn't learned the
    -- super-tracked spell yet, or a custom flyout whose first cell's
    -- icon API hiccuped).
    local cells = ResolveCells(data)
    if cells[1] then
        local h = BazBars.Actions:Get(cells[1].type)
        if h and h.getIcon then
            local icon = h.getIcon(cells[1].data)
            if icon then return icon end
        end
    end
    -- Final fallback for empty flyouts (no cells) and any other case
    -- where no icon resolved. Without this an empty flyout slot looks
    -- visually identical to an empty bar slot, hiding that the slot
    -- is configured as a flyout at all.
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function Flyout.getName(data)
    local handler, hData = CurrentHandler(data)
    if handler and handler.getName then return handler.getName(hData) end
    if data and data.flyoutID then
        local name = FlyoutDisplayInfo(data.flyoutID)
        return name or "Flyout"
    end
    return "Flyout"
end

function Flyout.getCount(data)
    local handler, hData = CurrentHandler(data)
    if handler and handler.getCount then return handler.getCount(hData) end
    return ""
end

function Flyout.applyCooldown(data, cooldownFrame)
    local handler, hData = CurrentHandler(data)
    if handler and handler.applyCooldown then
        handler.applyCooldown(hData, cooldownFrame)
        return
    end
    if handler and handler.getCooldown then
        local start, duration = handler.getCooldown(hData)
        if start and duration and duration > 0 then
            cooldownFrame:Show()
            cooldownFrame:SetCooldown(start, duration)
        else
            cooldownFrame:Clear()
            cooldownFrame:Hide()
        end
        return
    end
    cooldownFrame:Clear()
    cooldownFrame:Hide()
end

function Flyout.isUsable(data)
    local handler, hData = CurrentHandler(data)
    if not handler then return true end
    if handler.isUsable then return handler.isUsable(hData) end
    return true
end

function Flyout.isInRange(data, unit)
    local handler, hData = CurrentHandler(data)
    if not handler or not handler.isInRange then return nil end
    return handler.isInRange(hData, unit)
end

function Flyout.hasProcGlow(data)
    local handler, hData = CurrentHandler(data)
    if not handler or not handler.hasProcGlow then return false end
    return handler.hasProcGlow(hData)
end

function Flyout.showTooltip(data)
    local handler, hData = CurrentHandler(data)
    if handler and handler.showTooltip then
        handler.showTooltip(hData)
        return
    end
    GameTooltip:SetText(Flyout.getName(data) or "Flyout", 1, 1, 1)
    GameTooltip:AddLine("|cff999999Right-click to open|r", nil, nil, nil, true)
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

function Flyout.serialize(data)
    if not data then return nil end
    local out = {
        flyoutID       = data.flyoutID,
        direction      = data.direction,
        rows           = data.rows,
        cols           = data.cols,
        mode           = data.mode,
        pinnedIndex    = data.pinnedIndex,
        persistCurrent = data.persistCurrent,
    }
    if data.persistCurrent then
        out.currentIndex = data.currentIndex
    end
    if data.cells then
        out.cells = {}
        for _, c in ipairs(data.cells) do
            if c and c.type and c.data then
                out.cells[#out.cells + 1] = { type = c.type, data = c.data }
            end
        end
    end
    return out
end

function Flyout.deserialize(saved)
    if not saved then return nil end
    if not saved.flyoutID and not saved.cells then return nil end

    -- Migrate legacy {spellID = X} cells to the full-action shape.
    if saved.cells then
        for i, c in ipairs(saved.cells) do
            if c.spellID and not c.type then
                saved.cells[i] = { type = "spell", data = { id = c.spellID } }
            end
        end
    end

    -- Migrate legacy currentSpellID / pinnedSpellID to indices.
    local function spellIDToIndex(targetID)
        if not targetID or not saved.cells then return nil end
        for i, c in ipairs(saved.cells) do
            if c.type == "spell" and c.data and c.data.id == targetID then
                return i
            end
        end
        return nil
    end
    if saved.currentSpellID and not saved.currentIndex then
        saved.currentIndex = spellIDToIndex(saved.currentSpellID)
    end
    if saved.pinnedSpellID and not saved.pinnedIndex then
        saved.pinnedIndex = spellIDToIndex(saved.pinnedSpellID)
    end

    local data = {
        flyoutID       = saved.flyoutID,
        cells          = saved.cells,
        direction      = saved.direction or "UP",
        rows           = saved.rows or 1,
        cols           = saved.cols or 3,
        mode           = saved.mode or "lastUsed",
        pinnedIndex    = saved.pinnedIndex,
        currentIndex   = saved.currentIndex,
        persistCurrent = saved.persistCurrent ~= false,
    }

    -- Spec: if no resolvable cells exist, the slot reverts to empty.
    if #ResolveCells(data) == 0 then return nil end

    return data
end

---------------------------------------------------------------------------
-- Cell click recording (called by FlyoutPopup when a cell is clicked)
---------------------------------------------------------------------------

function Flyout:RecordCellClick(button, cellIndex)
    if not button or not button.action then return end
    if button.action.type ~= "flyout" then return end
    local data = button.action.data
    if not data or data.mode ~= "lastUsed" then return end
    if not cellIndex then return end

    data.currentIndex = cellIndex

    -- Re-apply so the slot's left-click attribute updates to the new
    -- current cell. Defer in combat - secure attributes can't change
    -- under lockdown. The popup hides itself; the slot's icon stays on
    -- the previous cell until combat ends.
    if InCombatLockdown() then
        button._bazFlyoutPendingApply = true
        return
    end

    Flyout.apply(button, data)
    if addon.Button and addon.Button.UpdateButton then
        addon.Button:UpdateButton(button)
    end
    if addon.Button and addon.Button.SaveButton then
        addon.Button:SaveButton(button)
    end
end

---------------------------------------------------------------------------
-- Cell mutation (called by FlyoutPopup when an action is dropped on a
-- cell, or when a cell's contents are picked up).
---------------------------------------------------------------------------

function Flyout:SetCellAction(button, cellIndex, action)
    if not button or not button.action or button.action.type ~= "flyout" then return end
    if InCombatLockdown() then return end

    local data = button.action.data

    -- Native flyouts are read-only: dropping anything on a cell of a
    -- native flyout converts it into a custom flyout pre-seeded with
    -- the current cells (preserving their indices), then mutates the
    -- requested cell.
    if data.flyoutID then
        local snapshot = {}
        local resolved = ResolveCells(data)
        for i, c in pairs(resolved) do
            if type(i) == "number" and c.type and c.data then
                snapshot[i] = { type = c.type, data = c.data }
            end
        end
        data.flyoutID = nil
        data.cells = snapshot
    end

    -- Drops keep their position. cells is a sparse array indexed by
    -- the cell position the user actually dropped on, so an action
    -- dropped on cell 5 lands at cells[5] regardless of whether cells
    -- 1-4 are filled. The popup renderer happily handles holes
    -- (empty cell positions).
    data.cells = data.cells or {}
    if action and action.type and action.data then
        data.cells[cellIndex] = { type = action.type, data = action.data }
    else
        data.cells[cellIndex] = nil
    end

    Flyout.apply(button, data)
    if addon.Button and addon.Button.UpdateButton then
        addon.Button:UpdateButton(button)
    end
    if addon.Button and addon.Button.SaveButton then
        addon.Button:SaveButton(button)
    end
end

---------------------------------------------------------------------------
-- Combat-end re-apply for slots that recorded a click during combat.
---------------------------------------------------------------------------

local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:SetScript("OnEvent", function()
    if not addon.Bar or not addon.Bar.bars then return end
    for _, barFrame in pairs(addon.Bar.bars) do
        if barFrame.buttons then
            for _, row in pairs(barFrame.buttons) do
                for _, btn in pairs(row) do
                    if btn._bazFlyoutPendingApply and btn.action
                       and btn.action.type == "flyout" then
                        btn._bazFlyoutPendingApply = nil
                        Flyout.apply(btn, btn.action.data)
                        if addon.Button and addon.Button.UpdateButton then
                            addon.Button:UpdateButton(btn)
                        end
                        if addon.Button and addon.Button.SaveButton then
                            addon.Button:SaveButton(btn)
                        end
                    end
                end
            end
        end
    end
end)

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------

Actions:Register(Flyout)
