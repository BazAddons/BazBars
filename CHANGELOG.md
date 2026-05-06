# BazBars Changelog

## 056 — Click-Through bars

Per-bar toggle that makes the bar's buttons stop intercepting mouse
clicks - clicks pass straight through to whatever's underneath (the
world, units, the default action bars, etc.) while the bar's icons,
cooldown sweeps, range tinting, charge counts, and proc glow all
keep rendering normally. Useful for "always-visible cooldown
reference" bars where you want to *see* a spell's status but cast it
from a different bar's keybind.

Find it in Edit Mode → click a bar → Behavior → Click-Through, or
in the per-bar settings page. Also exposed as a global override.

## 055 — Bar slot menu polish

- "Create flyout..." on an empty slot now spawns the default 1×3
  flyout *and* opens the configuration form immediately, so you can
  reshape rows / cols / direction in one go without a second
  shift+right-click.
- Removed the redundant title at the top of the bar-slot menu - the
  slot icon is right next to the menu, no need to echo it.
- Shortened the "Remember Current Spell Across Sessions" toggle
  label to "Remember across sessions" so the text fits inside the
  config form's panel width.

## 054 — Bar slot shift+right-click is now a shared menu

Shift+right-clicking a bar slot used to fire a direct action: spawn a
flyout on an empty slot, open the configure form on a flyout slot,
clear the action on any other slot. Each of those is now a single
entry in a context menu opened via BazCore's shared `bar-slot` scope
(BazCore 116+) — same pattern BazBags uses for its bag-item menu.

Other addons can register their own entries against `bar-slot` and
they'll appear in the same menu. BazTooltipEditor's "Inspect this
tooltip" entry, for example, now shows up automatically.

The trade-off: one extra click for the previously-direct actions
(menu opens, then click the entry). In return, every shift+right-
click on any BazCore-aware frame opens a consistent menu instead of
each addon doing its own thing.

## 053 — Updated User Manual screenshots

Refreshed the "Creating a Bar" and "Editing a Bar" screenshots to
match the current Edit Mode panel and per-bar settings popup.

## 052 — Profession openers work on flyout slots too

Left-clicking a flyout slot whose current cell is a profession spell
(Alchemy, Inscription, Blacksmithing, Mining, etc.) now reliably
opens the trade-skill window — the same way clicking a regular bar
slot with that profession spell does. The profession-window opener
fallback used to only fire on `spell`-type slots, so a flyout slot
sitting on a profession would intermittently fail to open the
window depending on which profession the cell held: Cooking and
Fishing happened to open from `/cast`, but Alchemy and Inscription
didn't. The fallback now follows flyouts into their current cell.

## 051 — In-game User Manual now has screenshots

The User Manual page (Settings → BazBars → User Manual) is now
illustrated end-to-end. Screenshots are paired with the relevant
copy throughout: creating a bar, item stack tracking, the flyout
configuration form, big flyout grids, the per-bar settings popup,
Quick Keybind Mode, and the full Bar Customizer. Most images sit
side-by-side with their explanation now (using BazCore's new
`imageRow` block) instead of taking a full row each. The settings
sections list (Layout, Visibility, Keybinds, Appearance, Behaviour,
Actions) is no longer collapsed under expandable headers — every
section is visible at once.

A few wording tweaks while we were in there: the "Create a Bar"
steps correctly say the button is at the **bottom** of the Edit
Mode panel.

Requires BazCore 109+ for the new `imageRow` block.

## 050 — Empty flyouts now show a question-mark icon

A flyout slot whose current cell had no resolvable icon (an empty
flyout, or one whose super-tracked spell isn't learned yet) used to
render as a blank slot, indistinguishable from a slot with no action
at all. It now falls back to the standard `?` icon so you can see
the slot is configured as a flyout.

(Also adds screenshot assets for the upcoming in-game User Manual
image refresh — no behaviour change there yet.)

## 049 — Dragging a flyout off the bar actually deletes it

Picking up a flyout from a bar slot and dropping in empty space used
to clear the slot visually but leave an invisible "I'm carrying a
flyout" state behind. The next click on that slot — or any other
empty slot — would silently re-apply the flyout, making it look like
the deletion didn't happen.

The carrier now clears the moment you release the mouse without
landing on a slot, matching what default Blizzard action bars do for
spell drags. Drag-and-drop between slots still works exactly as
before.

## 048 — Trade goods on a bar no longer look subdued

Tracking herbs, ore, raw fish, feathers, and other tradegood items
on a bar made the icon look dimmed and broken — not actually
unusable, just visually drained. The check that drove the dim was
asking "is this item click-to-activate?", which trade goods aren't,
but tradegoods on a bar are typically there to track inventory count
rather than to be used, so the dim was misleading.

Items now always render at full colour. Cooldown sweeps, stack
counts, and out-of-range tinting still appear on items that have
those states (potions, on-use trinkets), so nothing useful is lost.

## 047 — Items dropped on a former-flyout slot now create item buttons

Picking up a flyout to move it and then changing your mind — grabbing
something else from your bag or spellbook instead — used to leave the
"I'm carrying a flyout" flag stuck on. The next thing you dropped on
any slot would silently turn into a flyout regardless of what was on
your cursor (peacebloom landing as a question-mark flyout button, for
example). The carrier now yields the moment you pick something else
up, so the right action handler claims the drop.

## 046 — Profession buttons now open their windows

Dragging a profession (Cooking, Alchemy, Inscription, Fishing,
Archaeology, etc.) from your spellbook onto a BazBars slot used to
produce a button that did nothing when clicked. Default Blizzard
action bars handle profession opens through a special slot path
custom buttons couldn't reach.

Two changes work together to fix this:

- All spells now dispatch via `/cast` macro under the hood. The macro
  path matches the route Blizzard's bars use and is enough to open
  the simpler professions (Cooking, Fishing, Archaeology) plus every
  regular combat spell.
- For the Dragonflight-style professions (Alchemy, Blacksmithing,
  Inscription, Engineering, etc.) where `/cast` alone isn't enough,
  the click also calls `C_TradeSkillUI.OpenTradeSkill` on the
  appropriate profession line. Harmless for already-open windows.

Works on both regular bar slots and inside flyouts.

## 045 — Edit Mode and combat-fade fixes

### Bars with combat-only visibility now show in Edit Mode

If you set a bar to only appear in combat (or any conditional that
hides it), opening Blizzard's Edit Mode while the condition was off
left the bar invisible — you couldn't see it to drag, resize, or
configure it. Bars are now forced visible while Edit Mode is open
regardless of any visibility macro, and snap back to their normal
condition the moment you close Edit Mode.

### Mouseover fade no longer throws errors in combat

Bars with Mouseover Fade enabled could throw an action-blocked error
during combat. The fade-in animation was using a Blizzard helper that
briefly toggles the bar's visibility, which isn't allowed on protected
frames during combat. The fade now animates the bar's opacity
directly and is fully combat-safe.

## 044 — User guide refresh

The in-game User Manual was reorganised and brought up to date. New
detail in Placing Buttons covers the Cast on Key Down gotcha (use Shift
+drag to rearrange when that mode is on). Quick Keybind section now
documents the supported mouse buttons (middle, mouse4, mouse5) and the
automatic Blizzard-binding eviction. Added a Profiles page.

## 043 - Custom flyouts on any slot

Right-click any BazBars slot to pop out a small grid of action buttons.
Useful for grouping related abilities under one slot — teleports, tank
trinkets, profession tools, whatever you want one click away without
spending a whole row on it.

**Two ways to make one.** Drag a class flyout (Mage Teleports, Warlock
Summons, etc.) from your spellbook onto an empty slot for a live copy
that updates as you learn new variants. Or Shift+right-click an empty
slot for a blank 3-cell grid that you fill yourself by dragging in
spells, items, mounts, toys, macros, battle pets, or equipment sets.

**How it works.** Left-click the slot casts whatever's currently
showing. Right-click toggles the grid open and closed. Click a cell to
cast it. Drag a cell out to pick it up. Click outside the grid to close
it.

**Configure** by Shift+right-clicking an existing flyout slot. Pick the
grid size (up to 12×12), which way it pops out (up, down, left, right),
and whether the slot icon shows the last-used cell or a specific one
you pin. The flyout opens live behind the config so you see your changes
immediately. Cancel reverts; Apply saves.

**Move flyouts between slots** with Shift+left-drag. A follower icon
tracks your cursor — drop on another BazBars slot to relocate the whole
flyout. Press Esc or click empty world to cancel.

Drops always land where you put them — drop on cell 5 and it lands at
cell 5 even if cells 1–4 are empty. If a pinned cell becomes unlearned,
the slot falls back to the next usable cell.

The User Guide has a new Flyouts page walking through creation,
gestures, config, and slot moves.

## 030 - Mouse Button Keybinding Support
- Quick Keybind Mode now supports **middle mouse, mouse4, and mouse5** bindings (and modifier combos like Shift+MiddleButton)
  - Added `OnMouseDown` handler to hovered buttons during keybind mode to catch mouse button presses (OnKeyDown only fires for keyboard keys)
  - Converts OnMouseDown button names to binding system names: `MiddleButton` → `BUTTON3`, `Button4` → `BUTTON4`, `Button5` → `BUTTON5`
  - Left and right mouse clicks are ignored (those interact with the button, not bind to it)
  - Mouse handlers properly restored on exit from keybind mode

## 029 - Keybind Conflict Eviction, Fix Unbind Error, Smaller Edit Mode Button
- **Fixed Blizzard keybind conflict:** when Quick Keybind Mode claims a key (e.g. `E`) that already has a Blizzard binding, BazBars now automatically evicts the Blizzard binding so the key isn't double-bound silently
  - Previously, setting `E` in Quick Keybind Mode installed a secure override on top of Blizzard's existing `E` binding — the override took priority so only the BazBars click fired, but the Blizzard binding stayed attached and would reactivate if the BazBars binding was cleared
  - New `EvictBlizzardBinding(key)` helper calls `GetBindingAction(key)` + `SetBinding(key, nil)` + `SaveBindings` to cleanly remove the Blizzard side of the conflict; Blizzard-binding clears that happen during combat are queued and processed on `PLAYER_REGEN_ENABLED`
  - Surfaces feedback in chat: `|cffffd700E|r was bound to |cff00ff00ACTIONBUTTON5|r - cleared so the BazBars button can claim it.`
  - Skips eviction when the existing action starts with `CLICK BazBars` (that's another BazBars button handled by the existing override-clearing path)
- **Fixed `Usage: SetOverrideBindingClick(...)` error when clearing a keybind via ESC** in Quick Keybind Mode
  - The old code called `SetOverrideBindingClick(owner, true, oldKey, nil)` to clear an override, but the click variant doesn't accept `nil` for `buttonName` in Midnight — it throws the usage error instead
  - Switched to `SetOverrideBinding(owner, true, oldKey, nil)` (the generic non-click variant) which accepts `nil` as "clear this key" and works for click-overrides as well
- **Shrunk the "Create New BazBar" button in the Edit Mode panel** — previously a 330px-wide stretched bar, now auto-sizes to the text width + padding at 1.2x scale so it hugs its label instead of dominating the panel

## 028 - Fix Spell Cooldown Sweep Not Showing In Combat
- Fixed spell cooldown animations not displaying during combat (v025 regression)
  - The v025 drag-drop rewrite moved cooldown logic into per-type action handlers and switched spells from Midnight's taint-safe `C_Spell.GetSpellCooldownDuration` + `Cooldown:SetCooldownFromDurationObject` duration-object API to the older raw-numbers path (`C_Spell.GetSpellCooldown` → startTime/duration numbers)
  - v026's `SafeNumber` taint-stripping silenced the taint comparison error but didn't solve the underlying problem: `Cooldown:SetCooldown(start, duration)` silently refuses to display when called with tainted numeric arguments in the secure combat environment
  - Restored the duration-object pipeline via a new `handler.applyCooldown(data, cooldownFrame)` method — `Spell.applyCooldown` uses `SetCooldownFromDurationObject` which is the only path that reliably drives the Cooldown frame in combat
  - `Button:UpdateCooldown` now prefers `applyCooldown` over the legacy `getCooldown` raw-numbers path; Item and Toy handlers keep using `getCooldown` since `C_Item.GetItemCooldown` isn't subject to the same taint
- Added a pristine `CooldownPrototype = CreateFrame("Cooldown")` for the legacy fallback path, matching Blizzard's own pattern in `Blizzard_ActionBar/Shared/ActionButton.lua:890`: *"Create a pristine instance of Cooldown frame to mitigate potential secret leaks through overwriting methods"*

## 027 - Fix Buttons Not Firing With Cast on Key Down Enabled
- Fixed BazBars buttons doing nothing when `ActionButtonUseKeyDown` (Cast on Key Down) is enabled
  - Buttons animated on click but never actually fired the ability, because `RegisterForClicks("AnyUp")` only registered for key-up events while the global CVar was directing the secure dispatcher to fire on key-down
  - `ActionButtonUseKeyDown` is a global CVar — BazBars buttons live in the same secure dispatch path as Blizzard's action bars and cannot be independently "locked to up" while Blizzard's stay on down
  - Changed button registration to match Blizzard's own ActionButton: `RegisterForClicks("AnyUp", "LeftButtonDown", "RightButtonDown")` (Blizzard_ActionBar/Shared/ActionButton.lua:458)
  - Result: BazBars buttons now fire correctly in both CVar modes, exactly like Blizzard's default bars
- **Note on drag-drop with Cast on Key Down enabled:** plain click-drag on a BazBars button will fire the ability on mouse-down before the drag starts, matching Blizzard's behavior on their own bars. Use **Shift+drag** to rearrange buttons when Cast on Key Down is on — `shift-type1` / `shift-type2` are set to `"noop"` so shift-click never dispatches anything.

## 026 - Cast on Key Down Toggle, Midnight Taint Fix
- Added "Cast on Key Down" toggle to the Settings page so you can enable cast-on-down for Blizzard default bars (required for One Button Combat's hold-to-cast feature) while BazBars buttons stay on cast-on-up
- Fixed "attempt to compare local 'duration' (a secret number value tainted by 'BazBars')" error from C_Spell.GetSpellCooldown in Midnight
  - Spell cooldown startTime and duration now round-trip through string.format("%d", ...) to strip the taint before being compared

## 025 - Drag & Drop Rewrite
- Completely rewrote the drag & drop system as modular per-type action handlers
- New handlers: Spell, Item, Toy, Mount, BattlePet, Macro, EquipmentSet, MacroText
- Each handler lives in Actions/ and owns cursor detection, pickup, secure attributes, visuals, and persistence for its type
- Bars are now unlocked by default — drag without holding Shift
- Added per-bar "Lock Buttons" toggle (Edit Mode popup + bar options panel)
- Drag-fires-cast bug fixed for all types
- Mount swaps preserve the exact variant (skin/color) instead of collapsing to the canonical mountID
- First-run warning offers to change "Cast on key down" CVar so drag-and-drop works consistently
- Old flat storage format (bbCommand/bbValue/bbSubValue/bbID/bbMacrotext) auto-migrates to the new `{ type, data }` format
- Dropped ~700 lines of legacy code from Button.lua

## 024 - Use BazCore:SetScaleFromCenter
- Bar scaling now uses shared BazCore:SetScaleFromCenter() utility

## 023 - Unified Profiles
- Profiles now managed centrally in BazCore settings
- Removed per-addon Profiles subcategory

## 022 - Global Options + Settings Page
- Added Global Options page with per-bar overrides for scale, opacity, spacing, slot art, always show buttons, and mouseover fade
- When a global override is enabled, per-bar settings are grayed out
- Moved display settings (range color, tooltips, keybind text, macro names) to new Settings subcategory
- Subcategory order: Settings, Profiles, Global Options, Bar Options

## 020 - Macro Fixes + Button Move System
- Fixed #showtooltip in macros now displays proper spell/item tooltips
- Fixed macros shifting when other macros deleted (stored by name instead of index)
- Auto-migration for existing users with index-based macro saves
- Unified internal move system for all button types (spells, items, macros, mounts, pets)
- Button swaps: drop A on B, B goes to cursor, click to place
- Drag from BazBar to default action bars works
- Removed dead PickUp-based drag code

## 019 - Audit Fixes
- Range ticker frame now stored with reference (can be paused)
- Category changed to "Baz Suite"

## 018 - Range Indicator & Keybind Fixes
- Unified range/usability coloring (out of range always takes priority)
- Full button range color option: tint entire button red or just hotkey text
- Keybinds now always override default WoW bindings
- Fixed secret string taint in spell names
- Fixed NormalTexture reset causing inconsistent range tinting

## 017 - Global Options Panel
- Added Global Options subcategory with Display settings
- Full Button Range Color, Show Tooltips, Show Keybind Text, Show Macro Names
- Parent settings page shows addon description, quick guide, and slash commands

## 016 - Range Indicator Improvements
- Full button range coloring (icon, frame, hotkey, macro name)
- Range state tracking prevents flashing at boundaries
- Target existence check prevents stuck red state

## 015 - Secret String & Item Fixes
- Fixed Midnight secret string taint in loot/currency chat messages
- Fixed uncached item crash using item:ID format
- Spell range check uses spellID instead of spell name

## 014
- Version now reads from TOC dynamically

## 013 - Mount, Pet & Drag Fixes
- Fixed mount shift-drag turning mounts into Random Mount
- Fixed battlepet SetAction crash (API return value change in Midnight)
- Mounts and battlepets now use internal move system with floating cursor icon
- Added companion cursor type support for mount journal compatibility
- Shift+RightClick still removes mounts/battlepets from buttons

## 012 - Edit Mode Framework
- Edit Mode now powered by BazCore's shared EditMode framework
- Grid snapping, selection sync, and settings popup handled by BazCore
- ESC key closes the Edit Mode settings popup
- Settings popup smart-positions to avoid going off-screen
- Bar name changes update overlay and popup title live
- Consolidated range update ticker for cleaner performance
- Removed ~500 lines of redundant Edit Mode code

## 011 - BazCore Migration
- Migrated from Ace3 libraries to BazCore framework
- Reduced addon size from ~8MB to ~50KB (libraries no longer bundled)
- BazCore is now a required dependency
- Automatic migration of existing saved data from Ace3 format
- All existing features preserved
