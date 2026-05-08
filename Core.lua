-- SPDX-License-Identifier: GPL-2.0-or-later
-- BazBars Core Module
-- Addon lifecycle, slash commands, Edit Mode integration
-- Powered by BazCore framework

---------------------------------------------------------------------------
-- Addon Registration via BazCore
---------------------------------------------------------------------------

local addon = BazCore:RegisterAddon("BazBars", {
    title = "BazBars",
    savedVariable = "BazBarsDB",
    profiles = true,
    defaults = {
        bars = {},
        keybinds = {},
        globalOverrides = {},
        minimap = { hide = false },
        fullRangeColor = true,
        showTooltips = true,
        tooltipAnchor = "default",  -- "default" = bottom-right corner, "button" = next to button
        showKeybindText = true,
        showMacroNames = true,
    },

    -- Slash commands
    slash = { "/bb", "/bazbars" },
    commands = {
        create = {
            desc = "Create a new bar: /bb create [cols] [rows]",
            handler = function(args)
                local parts = {}
                for word in args:gmatch("%S+") do parts[#parts + 1] = word end
                local cols = tonumber(parts[1]) or BazBars.DEFAULT_COLS
                local rows = tonumber(parts[2]) or BazBars.DEFAULT_ROWS
                cols = math.max(1, math.min(BazBars.MAX_COLS, cols))
                rows = math.max(1, math.min(BazBars.MAX_ROWS, rows))
                local id = addon:CreateNewBar(cols, rows)
                addon:Print(("Created Bar %d (%dx%d). Use Edit Mode or /bb to configure."):format(id, cols, rows))
            end,
        },
        export = {
            desc = "Export bar config: /bb export <id>",
            handler = function(args)
                local id = tonumber(args:match("(%d+)"))
                if id then
                    local str = addon:ExportBar(id)
                    if str then
                        addon.Dialogs:ShowExportString(str)
                    else
                        addon:Print("Bar " .. id .. " not found.")
                    end
                else
                    addon:Print("Usage: /bb export <bar id>")
                end
            end,
        },
        import = {
            desc = "Import bar config: /bb import <string>",
            handler = function(args)
                local importStr = args:match("^(.+)$")
                if importStr and importStr ~= "" then
                    addon:ImportBar(importStr)
                else
                    addon.Dialogs:ShowImportDialog()
                end
            end,
        },
        duplicate = {
            desc = "Duplicate a bar: /bb duplicate <id>",
            usage = "dup, copy",
            handler = function(args)
                local id = tonumber(args:match("(%d+)"))
                if id then
                    local newID = addon:DuplicateBar(id)
                    if newID then
                        addon:Print(("Duplicated Bar %d as Bar %d."):format(id, newID))
                    end
                else
                    addon:Print("Usage: /bb duplicate <bar id>")
                end
            end,
        },
        delete = {
            desc = "Delete a bar: /bb delete <id>",
            usage = "remove",
            handler = function(args)
                local id = tonumber(args:match("(%d+)"))
                if id then
                    addon:DeleteBar(id)
                else
                    addon:Print("Usage: /bb delete <bar id>")
                end
            end,
        },
        scale = {
            desc = "Set bar scale: /bb scale <id> <scale>",
            handler = function(args)
                local parts = {}
                for word in args:gmatch("%S+") do parts[#parts + 1] = word end
                local id = tonumber(parts[1])
                local scale = tonumber(parts[2])
                if id and scale then
                    local frame = addon.Bar:Get(id)
                    if frame then
                        addon.Bar:SetScale(frame, scale)
                        addon:Print(("Bar %d scale set to %.2f"):format(id, scale))
                    else
                        addon:Print("Bar " .. id .. " not found.")
                    end
                else
                    addon:Print("Usage: /bb scale <bar id> <scale>")
                end
            end,
        },
        padding = {
            desc = "Set button spacing: /bb padding <id> <pixels>",
            usage = "spacing",
            handler = function(args)
                local parts = {}
                for word in args:gmatch("%S+") do parts[#parts + 1] = word end
                local id = tonumber(parts[1])
                local spacing = tonumber(parts[2])
                if id and spacing then
                    local frame = addon.Bar:Get(id)
                    if frame then
                        addon.Bar:Resize(frame, frame.barData.rows, frame.barData.cols, spacing)
                        addon:Print(("Bar %d spacing set to %d"):format(id, spacing))
                    else
                        addon:Print("Bar " .. id .. " not found.")
                    end
                else
                    addon:Print("Usage: /bb padding <bar id> <pixels>")
                end
            end,
        },
        reset = {
            desc = "Reset all bars (reloads UI)",
            handler = function()
                addon:Print("Resetting all bars. Reload UI to apply.")
                local sv = _G["BazBarsDB"]
                if sv then
                    local profile = BazCore:GetActiveProfile("BazBars")
                    if sv.profiles and sv.profiles[profile] then
                        sv.profiles[profile].bars = {}
                    end
                end
                ReloadUI()
            end,
        },
    },

    -- Minimap button
    minimap = {
        label = "BazBars",
        icon = 5213776,
        onClick = function(button)
            local bb = BazCore:GetAddon("BazBars")
            if button == "LeftButton" then
                if bb and bb.Options then bb.Options:Open() end
            elseif button == "RightButton" then
                if bb and not InCombatLockdown() then
                    local id = bb:CreateNewBar()
                    if id then
                        bb:Print("Created Bar " .. id .. ". Enter Edit Mode to configure.")
                    end
                end
            end
        end,
    },

})

---------------------------------------------------------------------------
-- Per-character button payloads
---------------------------------------------------------------------------
--
-- Bar STRUCTURE (cols/rows/scale/position/keybind shape) lives in the
-- profile and is meant to be shared across characters. Bar PAYLOADS
-- (the actual spell/macro/item slotted into each button) are class-
-- specific, so they live OUTSIDE the profile in a per-character /
-- per-profile / per-bar bucket:
--
--   BazBarsDB.charButtons[charKey][profileName][barID]["r:c"] = action
--
-- LoadButton / SaveButton route reads + writes through this bucket. A
-- one-shot migration on first load with the new format moves any
-- legacy profile.bars[id].buttons into the current character's bucket
-- so users coming from earlier versions don't lose their slotted
-- abilities; other characters using the same profile then start with
-- empty bars and re-slot independently (the desired behavior).
---------------------------------------------------------------------------

local function GetCharKey()
    local name, realm = UnitFullName("player")
    return (name or "Unknown") .. "-" .. (realm or "Unknown")
end

local function GetActiveProfileName()
    if BazCore and BazCore.GetActiveProfile then
        return BazCore:GetActiveProfile("BazBars") or "Default"
    end
    return "Default"
end

local function CharBucket(create)
    if not BazBarsDB then return nil end
    if create then BazBarsDB.charButtons = BazBarsDB.charButtons or {} end
    local cb = BazBarsDB.charButtons
    if not cb then return nil end
    local ck = GetCharKey()
    if create then cb[ck] = cb[ck] or {} end
    if not cb[ck] then return nil end
    local pn = GetActiveProfileName()
    if create then cb[ck][pn] = cb[ck][pn] or {} end
    return cb[ck][pn]
end

function addon:GetCharBarButtons(barID, create)
    local bucket = CharBucket(create)
    if not bucket then return nil end
    if create then bucket[barID] = bucket[barID] or {} end
    return bucket[barID]
end

function addon:GetButtonPayload(barID, key)
    local t = self:GetCharBarButtons(barID, false)
    return t and t[key] or nil
end

function addon:SetButtonPayload(barID, key, payload)
    local t = self:GetCharBarButtons(barID, true)
    if not t then return end
    t[key] = payload   -- nil clears
end

function addon:ClearCharBarButtons(barID)
    local bucket = CharBucket(false)
    if bucket then bucket[barID] = nil end
end

-- One-shot migration: walks profile.bars[*].buttons and moves each
-- payload to the current character's bucket. Per-profile sentinel so
-- subsequent characters using the same profile DON'T inherit (which
-- is the bug we're fixing). Run before any LoadButton call so the
-- live load reads from the new location.
function addon:MigrateButtonsToCharStorage()
    local profile = self.db and self.db.profile
    if not profile or not profile.bars then return end
    if profile._bbCharButtonsMigrated then return end

    local moved = 0
    local barsTouched = 0
    for barID, barData in pairs(profile.bars) do
        if barData.buttons and next(barData.buttons) then
            local target = self:GetCharBarButtons(barID, true)
            if target then
                for key, payload in pairs(barData.buttons) do
                    target[key] = payload
                    moved = moved + 1
                end
                barsTouched = barsTouched + 1
            end
            barData.buttons = {}   -- clear from profile
        end
    end

    profile._bbCharButtonsMigrated = true

    if moved > 0 then
        self:Print(string.format(
            "Moved %d button payloads across %d bar(s) into per-character storage. Other characters using this profile will start with empty bars - slot their own abilities and they'll save independently.",
            moved, barsTouched))
    end
end

-- Lifecycle callbacks (defined after addon is assigned)
addon.config.onLoad = function(self)
    self:MigrateFromAceDB()
    self:MigrateButtonsToCharStorage()
    self.Options:Setup()
end

---------------------------------------------------------------------------
-- First-run CVar warning
-- If the player has "cast on key down" enabled, dragging BazBars buttons
-- would also fire the cast (mousedown triggers the secure click before drag
-- can start). BazBars buttons always register for mouseup, so they work
-- correctly regardless - but the user may see inconsistent behavior between
-- their Blizzard bars and BazBars. Offer to change the CVar on first run.
---------------------------------------------------------------------------

local function MaybeShowKeyDownWarning()
    if addon.db.profile.keyDownWarningShown then return end
    if not GetCVarBool("ActionButtonUseKeyDown") then
        addon.db.profile.keyDownWarningShown = true
        return
    end
    addon.db.profile.keyDownWarningShown = true
    if BazCore.Confirm then
        BazCore:Confirm({
            title       = "BazBars: Cast on key up?",
            body        = "BazBars works best with |cffffffffCast on key up|r enabled - the global game setting that also matches Blizzard's default.\n\nYou currently have |cffff7f00Cast on key down|r enabled. BazBars buttons still work correctly, but your Blizzard action bars will feel slightly different from BazBars.\n\nChange the setting to |cffffffffCast on key up|r now?",
            acceptLabel = "Yes, change it",
            cancelLabel = "Keep my setting",
            acceptStyle = "primary",
            onAccept    = function()
                SetCVar("ActionButtonUseKeyDown", "0")
                print("|cff3399ff[BazBars]|r Cast on key up enabled.")
            end,
        })
    end
end

addon.config.onReady = function(self)
    self.Bar:LoadAll()

    -- Targeted updates - only run the sub-update each event actually
    -- needs, instead of the full 8-function UpdateButton for every
    -- button on every event. High-frequency combat events like
    -- SPELL_UPDATE_COOLDOWN can fire dozens of times per second in
    -- raids; doing a full update pass each time was the main perf hit.
    self:On("SPELL_UPDATE_COOLDOWN", function() addon:UpdateAllCooldowns() end)
    self:On("SPELL_UPDATE_USABLE",  function() addon:UpdateAllUsable() end)
    self:On("UNIT_POWER_UPDATE",    function() addon:UpdateAllUsable() end)
    self:On("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", function() addon:UpdateAllGlow() end)
    self:On("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", function() addon:UpdateAllGlow() end)
    self:On("UPDATE_MACROS",        function() addon:UpdateAllMacroNames() end)
    self:On("PLAYER_TARGET_CHANGED", function() addon:OnRangeEvent() end)

    -- These are infrequent events - a full update pass is fine.
    self:On("BAG_UPDATE",               function() addon:QueueFullUpdate() end)
    self:On("PLAYER_EQUIPMENT_CHANGED", function() addon:QueueFullUpdate() end)
    self:On("ACTIONBAR_UPDATE_STATE",   function() addon:QueueFullUpdate() end)

    -- Pause the range ticker when not in combat - no reason to poll
    -- spell range every 0.2s while standing in town.
    self:On("PLAYER_REGEN_DISABLED", function() addon:StartRangeTicker() end)
    self:On("PLAYER_REGEN_ENABLED",  function() addon:StopRangeTicker() end)

    self:SetupEditMode()

    C_Timer.After(1, function()
        addon:UpdateAllButtons()
        addon.Keybinds:RestoreAll()
        MaybeShowKeyDownWarning()
        -- If we loaded mid-combat (e.g. /reload during a boss pull),
        -- start the range ticker immediately.
        if InCombatLockdown() then
            addon:StartRangeTicker()
        end
    end)
end

-- Profile change handler
addon:OnProfileChanged(function(newProfile, oldProfile)
    -- Clear all keybinds
    if addon.Keybinds then
        local keybindOwner = _G["BazBarsKeybindOwner"]
        if keybindOwner and not InCombatLockdown() then
            ClearOverrideBindings(keybindOwner)
        end
    end

    -- Destroy all existing bars
    addon.Bar:DeselectAll()
    addon.Bar:DestroyAll()

    -- Recreate from new profile data
    addon.Bar:LoadAll()

    -- Restore keybinds for new profile
    if addon.Keybinds then
        addon.Keybinds:RestoreAll()
    end

    -- Refresh options panel
    addon.Options:Refresh()

    addon:Print("Profile changed. Bars reloaded.")
end)

---------------------------------------------------------------------------
-- db compatibility proxy
-- Makes addon.db.profile.X work so existing code doesn't need changes
---------------------------------------------------------------------------

local dbProxy = {}
local profileProxy = setmetatable({}, {
    __index = function(_, key)
        local sv = _G["BazBarsDB"]
        if not sv then return nil end
        local profileName = BazCore:GetActiveProfile("BazBars")
        local profile = sv.profiles and sv.profiles[profileName]
        if profile then return profile[key] end
        return nil
    end,
    __newindex = function(_, key, value)
        local sv = _G["BazBarsDB"]
        if not sv then return end
        local profileName = BazCore:GetActiveProfile("BazBars")
        if not sv.profiles then sv.profiles = {} end
        if not sv.profiles[profileName] then sv.profiles[profileName] = {} end
        sv.profiles[profileName][key] = value
    end,
})
dbProxy.profile = profileProxy
addon.db = dbProxy

---------------------------------------------------------------------------
-- AceDB Migration
---------------------------------------------------------------------------

function addon:MigrateFromAceDB()
    local sv = _G["BazBarsDB"]
    if not sv then return end
    if not sv.profileKeys then return end -- not AceDB format

    -- Convert profileKeys to BazCore assignments
    sv.assignments = sv.assignments or {}
    sv.assignments.character = sv.assignments.character or {}
    sv.assignments.class = sv.assignments.class or {}
    sv.assignments.spec = sv.assignments.spec or {}
    for charKey, profileName in pairs(sv.profileKeys) do
        sv.assignments.character[charKey] = profileName
    end

    -- Clean up AceDB metadata
    sv.profileKeys = nil
    sv.global = nil
    sv.char = nil
    sv.factionrealm = nil
    sv.faction = nil
    sv.realm = nil
    sv.class = nil
    sv.race = nil

    addon:Print("Migrated saved data from Ace3 format.")
end

---------------------------------------------------------------------------
-- Edit Mode Integration
---------------------------------------------------------------------------

function addon:SetupEditMode()
    if not EditModeManagerFrame then return end

    -- "Create New BazBar" button in Edit Mode panel. Auto-size to
    -- whatever the text needs + a small horizontal padding so the
    -- button hugs its label instead of stretching across the panel.
    -- Scale 1.2 so the whole button (text + chrome) reads ~20% larger
    -- without changing the auto-sizing math.
    local createBtn = CreateFrame("Button", nil, EditModeManagerFrame, "UIPanelButtonTemplate")
    createBtn:SetText("Create New BazBar")
    createBtn:SetSize((createBtn.Text:GetStringWidth() or 120) + 24, 22)
    createBtn:SetScale(1.2)
    createBtn:SetPoint("BOTTOM", EditModeManagerFrame, "BOTTOM", 0, -36)
    createBtn:SetScript("OnClick", function()
        if not InCombatLockdown() then
            local id = addon:CreateNewBar()
            if id then
                addon:Print("Created Bar " .. id)
            end
        end
    end)
end

---------------------------------------------------------------------------
-- Event Handlers
---------------------------------------------------------------------------

-- Helper: iterate all buttons with an action and call `fn(btn)` on each.
local function ForEachButton(fn)
    for _, frame in pairs(addon.Bar:GetAll()) do
        for _, row in pairs(frame.buttons) do
            for _, btn in pairs(row) do
                if btn.action then fn(btn) end
            end
        end
    end
end

-- Full update - walks every button through all 8 sub-updates.
-- Used at startup, profile change, and rare events (BAG_UPDATE, etc.).
function addon:UpdateAllButtons()
    ForEachButton(function(btn) self.Button:UpdateButton(btn) end)
end

-- Targeted update helpers - each walks the button grid but only runs
-- the one sub-update that the triggering event actually needs.
function addon:UpdateAllCooldowns()
    ForEachButton(function(btn) self.Button:UpdateCooldown(btn) end)
end

function addon:UpdateAllUsable()
    ForEachButton(function(btn) self.Button:UpdateUsable(btn) end)
end

function addon:UpdateAllGlow()
    ForEachButton(function(btn) self.Button:UpdateGlow(btn) end)
end

function addon:UpdateAllMacroNames()
    ForEachButton(function(btn) self.Button:UpdateMacroName(btn) end)
end

function addon:OnRangeEvent()
    ForEachButton(function(btn) self.Button:UpdateRange(btn) end)
end

---------------------------------------------------------------------------
-- Coalesced full update - infrequent events (BAG_UPDATE, equip change,
-- action bar state) may fire in rapid bursts (e.g. swapping a gear set
-- triggers one PLAYER_EQUIPMENT_CHANGED per slot). Instead of doing a
-- full update pass per event, set a dirty flag and flush once at the
-- end of the frame.
---------------------------------------------------------------------------

local fullUpdatePending = false
local flushFrame = CreateFrame("Frame")
flushFrame:Hide()
flushFrame:SetScript("OnUpdate", function(self)
    self:Hide()
    fullUpdatePending = false
    addon:UpdateAllButtons()
end)

function addon:QueueFullUpdate()
    if fullUpdatePending then return end
    fullUpdatePending = true
    flushFrame:Show()
end

---------------------------------------------------------------------------
-- Range ticker - polls spell range every 0.2s, but only while in
-- combat. Out-of-combat there's no target switching that matters for
-- range coloring, and the 5-times-per-second loop over every button
-- was burning CPU for no reason.
---------------------------------------------------------------------------

local rangeTimer = 0
local RANGE_INTERVAL = 0.2
local rangeFrame = CreateFrame("Frame")
rangeFrame:Hide()  -- starts paused; enabled on PLAYER_REGEN_DISABLED

rangeFrame:SetScript("OnUpdate", function(self, elapsed)
    rangeTimer = rangeTimer + elapsed
    if rangeTimer >= RANGE_INTERVAL then
        rangeTimer = 0
        addon:OnRangeEvent()
    end
end)

function addon:StartRangeTicker()
    rangeTimer = 0
    rangeFrame:Show()
end

function addon:StopRangeTicker()
    rangeFrame:Hide()
end

-- Also kick the range ticker on target change (already registered
-- as a direct OnRangeEvent call above), and start it if we load
-- mid-combat.
addon.rangeFrame = rangeFrame

---------------------------------------------------------------------------
-- Import / Export
---------------------------------------------------------------------------

function addon:ExportBar(barID)
    local barData = self.db.profile.bars[barID]
    if not barData then return nil end

    local exportData = CopyTable(barData)
    exportData.pos = nil
    exportData.id = nil
    -- Bake the CURRENT character's slotted payloads into the export
    -- so the receiver gets both structure and contents. The profile
    -- side stays empty post-migration; reading from charButtons is
    -- where the actual data lives now.
    local charBtns = self:GetCharBarButtons(barID, false)
    if charBtns and next(charBtns) then
        exportData.buttons = CopyTable(charBtns)
    else
        exportData.buttons = nil
    end

    return BazCore:Serialize(exportData)
end

function addon:ImportBar(encodedString)
    if not encodedString or encodedString == "" then
        self:Print("No import string provided.")
        return
    end

    local barData = BazCore:Deserialize(encodedString)
    if not barData or type(barData) ~= "table" then
        self:Print("Invalid import string.")
        return
    end

    local newID = self.Bar:GetNextID()
    barData.id = newID
    barData.pos = nil
    -- Pull any imported button payloads OFF the profile entry and
    -- apply them to the current character's bucket. The profile
    -- itself stays structure-only.
    local importedButtons = barData.buttons
    barData.buttons = {}

    self.db.profile.bars[newID] = barData

    if importedButtons and next(importedButtons) then
        local target = self:GetCharBarButtons(newID, true)
        if target then
            for key, payload in pairs(importedButtons) do
                target[key] = CopyTable(payload)
            end
        end
    end

    local frame = self.Bar:Create(barData)

    for r, row in pairs(frame.buttons) do
        for c, btn in pairs(row) do
            self.Button:LoadButton(btn)
        end
    end

    self.Bar:ApplyVisibility(frame)
    self.Bar:UpdateSlotArt(frame)
    self.Bar:UpdateButtonVisibility(frame)
    self.Bar:SetBarAlpha(frame, BazBars.GetBarSetting(barData, "alpha") or 1.0)
    self.Bar:ApplyMouseoverFade(frame)
    self.Options:Refresh()

    self:Print("Imported as Bar " .. newID .. ".")
    return newID
end

---------------------------------------------------------------------------
-- Bar Management
---------------------------------------------------------------------------

function addon:DuplicateBar(sourceID)
    if InCombatLockdown() then
        self:Print("Cannot duplicate bars during combat.")
        return
    end

    local sourceData = self.db.profile.bars[sourceID]
    if not sourceData then
        self:Print("Bar " .. sourceID .. " not found.")
        return
    end

    local newID = self.Bar:GetNextID()
    local newData = CopyTable(sourceData)
    newData.id = newID
    newData.pos = nil
    newData.customName = (newData.customName or ("Bar " .. sourceID)) .. " (Copy)"
    -- Buttons live per-character now; the profile copy carries no
    -- payload data (it would be empty anyway post-migration). We
    -- copy the current character's source-bar payload into the new
    -- bar's per-char bucket below.
    newData.buttons = {}

    self.db.profile.bars[newID] = newData

    -- Mirror the current character's slotted buttons from source -> new.
    local sourceBtns = self:GetCharBarButtons(sourceID, false)
    if sourceBtns and next(sourceBtns) then
        local targetBtns = self:GetCharBarButtons(newID, true)
        for key, payload in pairs(sourceBtns) do
            targetBtns[key] = CopyTable(payload)
        end
    end

    local frame = self.Bar:Create(newData)

    for r, row in pairs(frame.buttons) do
        for c, btn in pairs(row) do
            self.Button:LoadButton(btn)
        end
    end

    self.Bar:ApplyVisibility(frame)
    self.Bar:UpdateSlotArt(frame)
    self.Bar:UpdateButtonVisibility(frame)
    self.Bar:SetBarAlpha(frame, BazBars.GetBarSetting(newData, "alpha") or 1.0)
    self.Bar:ApplyMouseoverFade(frame)
    self.Options:Refresh()

    return newID
end

function addon:CreateNewBar(cols, rows)
    if InCombatLockdown() then
        self:Print("Cannot create bars during combat.")
        return
    end

    local id = self.Bar:GetNextID()
    local barData = BazBars.DefaultBarData(id)
    barData.cols = cols or BazBars.DEFAULT_COLS
    barData.rows = rows or BazBars.DEFAULT_ROWS

    self.db.profile.bars[id] = barData
    self.Bar:Create(barData)
    self.Options:Refresh()

    return id
end

function addon:DeleteBar(id)
    if InCombatLockdown() then
        self:Print("Cannot delete bars during combat.")
        return
    end

    if self.Bar:Destroy(id) then
        self.db.profile.bars[id] = nil
        -- Clear the current character's payload for this bar. Other
        -- characters' payloads for this bar in this profile are now
        -- orphaned but harmless; they'll be cleaned up on the next
        -- per-profile cleanup pass (or never - they consume a few
        -- bytes of SV memory and are easy to ignore).
        self:ClearCharBarButtons(id)
        self.Options:Refresh()
        self:Print("Bar " .. id .. " deleted.")
    else
        self:Print("Bar " .. id .. " not found.")
    end
end
