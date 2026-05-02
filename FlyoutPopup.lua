-- SPDX-License-Identifier: GPL-2.0-or-later
-- BazBars FlyoutPopup
--
-- Thin BazBars-side wrapper around BazCore:CreateSecureActionPopup.
-- BazCore owns the chrome, grid layout, secure right-click toggle,
-- and click-outside dismissal. This module just maps per-cell events
-- (apply, icon, click, drop, drag-pickup, tooltip) onto the same
-- BazBars.Actions registry that drives the regular bar slots - so
-- spells, items, mounts, toys, macros, equipment sets, and battle
-- pets all work on flyout cells with no flyout-specific casing.

local addon = BazCore:GetAddon("BazBars")
local FlyoutPopup = {}
addon.FlyoutPopup = FlyoutPopup

---------------------------------------------------------------------------
-- Cell list + opts builder
---------------------------------------------------------------------------

local function CellsFor(data)
    local Flyout = addon.FlyoutHandler
    if not Flyout or not Flyout.ResolveCells then return {} end
    return Flyout.ResolveCells(data)
end

local function GridFor(data)
    local cells = CellsFor(data)
    local Flyout = addon.FlyoutHandler
    local maxIdx = (Flyout and Flyout.MaxCellIndex) and Flyout.MaxCellIndex(cells) or 0
    local rows = data.rows or 1
    local cols = data.cols or maxIdx
    if not cols or cols < 1 then cols = math.max(1, maxIdx) end
    if rows * cols < maxIdx then
        cols = math.ceil(maxIdx / rows)
    end
    if rows * cols < 1 then rows, cols = 1, 1 end
    return rows, cols
end

local function BuildOpts(button, data)
    local rows, cols = GridFor(data)
    local cells = CellsFor(data)

    return {
        parent       = button,
        toggleButton = "RightButton",
        toggleShift  = false,
        direction    = data.direction or "UP",
        rows         = rows,
        cols         = cols,
        cells        = cells,

        applyCell    = function(cellBtn, _, cellData)
            if not cellData or not cellData.type then return end
            if cellData.type == "spell" and cellData.isKnown == false then
                return -- visible but inert (e.g. unlearned native flyout slot)
            end
            BazBars.Actions:Apply(cellBtn,
                { type = cellData.type, data = cellData.data }, false)
        end,

        iconForCell  = function(cellData)
            if not cellData or not cellData.type then return nil end
            local handler = BazBars.Actions:Get(cellData.type)
            if handler and handler.getIcon then
                return handler.getIcon(cellData.data)
            end
        end,

        onCellClick  = function(cellIndex, cellData, mouseButton)
            if mouseButton ~= "LeftButton" then return end
            if not cellData or not cellData.type then return end
            local Flyout = addon.FlyoutHandler
            if Flyout and Flyout.RecordCellClick then
                Flyout:RecordCellClick(button, cellIndex)
            end
        end,

        onCellEnter  = function(_, cellData, cellBtn)
            if not cellData or not cellData.type then return end
            local handler = BazBars.Actions:Get(cellData.type)
            if handler and handler.showTooltip then
                GameTooltip:SetOwner(cellBtn or button, "ANCHOR_RIGHT")
                handler.showTooltip(cellData.data)
                GameTooltip:Show()
            end
        end,

        -- Drop anything the registry recognises onto a cell -> store the
        -- full action and re-apply. Empty cells (nil cellData) accept
        -- drops too: SetCellAction places the new action at that index.
        onCellDrag = function(cellIndex)
            -- Don't accept a flyout-carry drop into a cell - cells can't
            -- host nested flyouts, and consuming the carry here would
            -- silently lose the user's pickup. Leave the carry alone so
            -- they can drop it on a bar slot instead.
            local Flyout = addon.FlyoutHandler
            if Flyout and Flyout.HasPending and Flyout.HasPending() then
                return
            end

            local handler, dragData = BazBars.Actions:FromCursor()
            if not handler or not dragData then return end
            ClearCursor()
            if Flyout and Flyout.SetCellAction then
                Flyout:SetCellAction(button, cellIndex,
                    { type = handler.type, data = dragData })
            end
        end,

        onCellDragStart = function(cellIndex, cellData)
            if not cellData or not cellData.type then return end
            local handler = BazBars.Actions:Get(cellData.type)
            if handler and handler.pickup then
                handler.pickup(cellData.data)
                local Flyout = addon.FlyoutHandler
                if Flyout and Flyout.SetCellAction then
                    Flyout:SetCellAction(button, cellIndex, nil)
                end
            end
        end,

        hideOnCast   = true,
    }
end

---------------------------------------------------------------------------
-- Public API used by Flyout.apply
---------------------------------------------------------------------------

function FlyoutPopup:AttachTo(button, data)
    if not button then return end
    if InCombatLockdown() then
        -- Defer rebuild; current popup (if any) keeps working with stale
        -- attributes. Flyout.apply gets called again on PLAYER_REGEN_ENABLED
        -- via the combat-end hook in Actions/Flyout.lua.
        return
    end

    local opts = BuildOpts(button, data)

    if button._bazFlyoutPopup then
        button._bazFlyoutPopup:Configure(opts)
        return button._bazFlyoutPopup
    end

    local popup = BazCore:CreateSecureActionPopup(opts)
    button._bazFlyoutPopup = popup
    return popup
end

function FlyoutPopup:DetachFrom(button)
    if not button or not button._bazFlyoutPopup then return end
    if InCombatLockdown() then return end
    local popup = button._bazFlyoutPopup
    popup:Hide()
    -- Clear the type="click" -> proxy wiring so right-click on a now-
    -- empty slot doesn't open a stale popup. type2 is restored when a
    -- new action lands; the next handler's apply will overwrite this
    -- anyway, but we also clear here so a slot left empty by ClearAction
    -- behaves predictably.
    if button.SetAttribute then
        button:SetAttribute("type2",         nil)
        button:SetAttribute("clickbutton",   nil)
        button:SetAttribute("clickbutton2",  nil)
    end
    button._bazFlyoutPopup = nil
end

---------------------------------------------------------------------------
-- Config popup
--
-- Shift+right-click on a flyout slot opens a small form with grid +
-- direction + mode controls. The actual flyout popup opens at the same
-- time and stays open while the form is up - it IS the preview, so the
-- user sees real buttons in their real position as they tweak settings.
--
-- Field changes apply live to the slot's data + Flyout.apply, so the
-- popup updates in place. Cancel restores the original snapshot taken
-- when the form opened; Apply just saves the (already-applied) state
-- and closes.
---------------------------------------------------------------------------

local DIRECTION_VALUES = {
    UP    = "Up",
    DOWN  = "Down",
    LEFT  = "Left",
    RIGHT = "Right",
}

local MODE_VALUES = {
    lastUsed = "Last used spell",
    specific = "Specific spell",
}

-- Module-level live-apply context. The poller frame ticks while the
-- config form is open, mirroring its state.values onto the slot's data
-- and re-running Flyout.apply when anything changes.
local liveApply = {
    frame = CreateFrame("Frame"),
    state = nil,
    button = nil,
    data = nil,
}
liveApply.frame:Hide()

local applyAccum = 0
liveApply.frame:SetScript("OnUpdate", function(self, dt)
    applyAccum = applyAccum + dt
    if applyAccum < 0.1 then return end
    applyAccum = 0

    local s = liveApply.state
    if not s or not s.values then return end
    local b = liveApply.button
    local d = liveApply.data
    if not b or not d then return end

    local rows    = s.values.rows
    local cols    = s.values.cols
    local dir     = s.values.direction
    local mode    = s.values.mode
    local persist = s.values.persistCurrent

    if rows == self._lastRows and cols == self._lastCols
       and dir == self._lastDir and mode == self._lastMode
       and persist == self._lastPersist then
        return
    end
    self._lastRows, self._lastCols     = rows, cols
    self._lastDir,  self._lastMode     = dir,  mode
    self._lastPersist                  = persist

    if InCombatLockdown() then return end

    d.rows           = rows    or d.rows
    d.cols           = cols    or d.cols
    d.direction      = dir     or d.direction
    d.mode           = mode    or d.mode
    d.persistCurrent = persist and true or false

    local Flyout = addon.FlyoutHandler
    if Flyout and Flyout.apply then Flyout.apply(b, d) end
    if addon.Button and addon.Button.UpdateButton then
        addon.Button:UpdateButton(b)
    end
    -- Keep the flyout popup visible while the config form is up - it
    -- is the live preview. Show is idempotent.
    if b._bazFlyoutPopup then
        b._bazFlyoutPopup:Show()
    end
end)

local function StopLiveApply()
    liveApply.frame:Hide()
    liveApply.state = nil
    liveApply.button = nil
    liveApply.data = nil
    liveApply.frame._lastRows = nil
    liveApply.frame._lastCols = nil
    liveApply.frame._lastDir = nil
    liveApply.frame._lastMode = nil
    liveApply.frame._lastPersist = nil
end

function FlyoutPopup:OpenConfig(button)
    if not button or not button.action or button.action.type ~= "flyout" then
        return
    end
    if InCombatLockdown() then
        if BazCore.Alert then
            BazCore:Alert({
                title = "Locked in Combat",
                body  = "Flyout settings can't be edited during combat. Drop combat and try again.",
            })
        end
        return
    end

    local data = button.action.data

    -- Snapshot for Cancel restore.
    local snapshot = {
        rows           = data.rows,
        cols           = data.cols,
        direction      = data.direction,
        mode           = data.mode,
        persistCurrent = data.persistCurrent,
    }

    -- Show the actual flyout popup so the user can see (and edit) real
    -- cells in their real positions while the config form is up. Pin
    -- it open with sticky mode so clicks on form sliders / dropdowns
    -- (which fire GLOBAL_MOUSE_UP outside the popup) don't dismiss it.
    if button._bazFlyoutPopup then
        if button._bazFlyoutPopup.SetSticky then
            button._bazFlyoutPopup:SetSticky(true)
        end
        if not button._bazFlyoutPopup:IsShown() then
            button._bazFlyoutPopup:Show()
        end
    end

    local function applied()
        local Flyout = addon.FlyoutHandler
        if Flyout and Flyout.apply then Flyout.apply(button, data) end
        if addon.Button and addon.Button.UpdateButton then
            addon.Button:UpdateButton(button)
        end
    end

    local popup = BazCore:OpenPopup({
        title = "Flyout Settings",
        body  = "The flyout opens behind this dialog so you can see your changes in place. Drop spells, items, mounts, and more onto cells while editing.",
        width = 360,
        fields = {
            { type = "range", key = "rows",
              label = "Grid Rows", default = data.rows or 1,
              min = 1, max = 12, step = 1, live = true },
            { type = "range", key = "cols",
              label = "Grid Cols", default = data.cols or 3,
              min = 1, max = 12, step = 1, live = true },
            { type = "select", key = "direction",
              label = "Pop-out Direction",
              default = data.direction or "UP",
              values = DIRECTION_VALUES },
            { type = "select", key = "mode",
              label = "Left-click Mode",
              default = data.mode or "lastUsed",
              values = MODE_VALUES },
            { type = "toggle", key = "persistCurrent",
              label = "Remember Current Spell Across Sessions",
              default = data.persistCurrent ~= false },
        },
        buttons = {
            { label = "Cancel", style = "default",
              onClick = function()
                  StopLiveApply()
                  data.rows           = snapshot.rows
                  data.cols           = snapshot.cols
                  data.direction      = snapshot.direction
                  data.mode           = snapshot.mode
                  data.persistCurrent = snapshot.persistCurrent
                  applied()
                  if button._bazFlyoutPopup then
                      if button._bazFlyoutPopup.SetSticky then
                          button._bazFlyoutPopup:SetSticky(false)
                      end
                      button._bazFlyoutPopup:Hide()
                  end
              end },
            { label = "Apply", style = "primary",
              onClick = function()
                  StopLiveApply()
                  if addon.Button and addon.Button.SaveButton then
                      addon.Button:SaveButton(button)
                  end
                  if button._bazFlyoutPopup then
                      if button._bazFlyoutPopup.SetSticky then
                          button._bazFlyoutPopup:SetSticky(false)
                      end
                      button._bazFlyoutPopup:Hide()
                  end
              end },
        },
        onClose = function()
            -- Belt-and-braces in case the user dismissed via the X /
            -- Escape; treat that like Cancel.
            if liveApply.button == button then
                StopLiveApply()
                data.rows           = snapshot.rows
                data.cols           = snapshot.cols
                data.direction      = snapshot.direction
                data.mode           = snapshot.mode
                data.persistCurrent = snapshot.persistCurrent
                applied()
                if button._bazFlyoutPopup then
                    if button._bazFlyoutPopup.SetSticky then
                        button._bazFlyoutPopup:SetSticky(false)
                    end
                    button._bazFlyoutPopup:Hide()
                end
            end
        end,
    })

    -- Hook the live-apply poller to this popup's state.
    if popup and popup._bcState then
        liveApply.state  = popup._bcState
        liveApply.button = button
        liveApply.data   = data
        liveApply.frame:Show()
    end
end
