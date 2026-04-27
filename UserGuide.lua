---------------------------------------------------------------------------
-- BazBars User Guide
-- Registered with BazCore so it appears in the User Manual tab.
---------------------------------------------------------------------------

if not BazCore or not BazCore.RegisterUserGuide then return end

BazCore:RegisterUserGuide("BazBars", {
    title = "BazBars",
    intro = "Custom extra action bars that don't consume Blizzard's 120 action slot IDs. Create as many bars as you want, place them anywhere, configure through Blizzard's native Edit Mode.",
    pages = {
        {
            title = "Welcome",
            blocks = {
                { type = "lead", text = "BazBars lets you build action bars that live alongside Blizzard's defaults without conflicting. The same spell can sit on both your default bar and a BazBar simultaneously — buttons are independent of WoW's 1–120 action slot system." },
                { type = "h2", text = "Why BazBars?" },
                { type = "list", items = {
                    "Up to 24x24 button grids per bar (576 buttons each)",
                    "Unlimited number of bars",
                    "Native Blizzard look — same atlases, cooldown sweeps, proc glow, range tinting",
                    "Full Edit Mode integration with grid snap and pixel-precise nudge",
                    "Optional Masque skinning per bar",
                }},
                { type = "note", style = "tip", text = "Drag-and-drop accepts spells, items, macros, toys, mounts, pets, and equipment sets. Items show live bag counts." },
            },
        },
        {
            title = "Creating a Bar",
            blocks = {
                { type = "paragraph", text = "Open Blizzard's |cffffd700Edit Mode|r (default key Shift+F11)." },
                { type = "list", ordered = true, items = {
                    "Look at the top of the Edit Mode panel",
                    "Click the |cffffd700Create New BazBar|r button",
                    "A new bar spawns at the center of your screen",
                    "Drag it where you want, then click it again to open settings",
                }},
                { type = "note", style = "info", text = "You can repeat this as many times as you want. Each bar is independent — its own size, position, layout, and contents." },
            },
        },
        {
            title = "Placing Buttons",
            blocks = {
                { type = "lead", text = "Drag almost anything onto a button slot." },
                { type = "h3", text = "Drag sources" },
                { type = "table",
                  columns = { "Source", "Behavior" },
                  rows = {
                      { "Spells",          "From your spellbook" },
                      { "Items",           "From your bags — shows live stack counts" },
                      { "Macros",          "From the macro window — name displays under icon" },
                      { "Toys",            "From your toy box" },
                      { "Mounts",          "From the mount journal, including Random Favorite" },
                      { "Battle Pets",     "From your pet collection" },
                      { "Equipment Sets",  "From the character pane" },
                  },
                },
                { type = "h3", text = "Removing buttons" },
                { type = "list", items = {
                    "|cffffd700Shift+Drag|r off the button to remove it",
                    "|cffffd700Shift+Right-Click|r to clear in place",
                }},
            },
        },
        {
            title = "Editing a Bar",
            blocks = {
                { type = "paragraph", text = "While in Edit Mode, click any BazBar to select it (yellow highlight). Click again to open its settings popup." },
                { type = "h3", text = "Settings sections" },
                { type = "collapsible", title = "Layout", style = "h4", blocks = {
                    { type = "list", items = {
                        "|cffffd700Bar Name|r — custom display name",
                        "|cffffd700Orientation|r — horizontal or vertical",
                        "|cffffd700Rows / Icons|r — resize the button grid (up to 24x24)",
                        "|cffffd700Icon Size|r — scale from 50% to 250%",
                        "|cffffd700Icon Padding|r — spacing between buttons",
                    }},
                }},
                { type = "collapsible", title = "Visibility", style = "h4", blocks = {
                    { type = "paragraph", text = "Use Blizzard macro conditionals to control when the bar appears." },
                    { type = "code", text = "[combat] show; hide" },
                    { type = "paragraph", text = "Examples: |cffffd700[stance:1]|r, |cffffd700[vehicleui]|r, |cffffd700[group]|r, |cffffd700[mod:shift]|r." },
                }},
                { type = "collapsible", title = "Keybinds", style = "h4", blocks = {
                    { type = "paragraph", text = "Quick Keybind mode lets you bind keys directly to buttons by hovering and pressing. No macros or AddOn dependencies." },
                }},
                { type = "collapsible", title = "Appearance", style = "h4", blocks = {
                    { type = "list", items = {
                        "|cffffd700Always Show Buttons|r — toggle empty-slot visibility",
                        "|cffffd700Show Slot Art|r — toggle the background slot texture under each button",
                        "|cffffd700Bar Opacity|r — overall transparency from 0-100%",
                        "|cffffd700Mouseover Fade|r — fade out when not hovered, fade back on hover",
                        "|cffffd700Bar Visibility|r — preset visibility states (always visible, in combat, etc.) without writing macros",
                        "|cffffd700Masque skinning|r — per-bar Masque support when Masque is installed",
                        "Cooldown sweep + hotkey text visibility",
                    }},
                }},
                { type = "collapsible", title = "Behavior", style = "h4", blocks = {
                    { type = "list", items = {
                        "|cffffd700Right-Click Self-Cast|r — cast helpful spells / use items on yourself with right-click on any button",
                        "|cffffd700Quick Keybind Mode|r — hover a button + press a key to bind it (Esc unbinds)",
                        "|cffffd700Edit Button Macrotext|r — write a custom |cff00ff00/cast|r conditional macro per button. Supports |cff00ff00#showtooltip SpellName|r so the icon and tooltip update to whichever spell the macro will cast.",
                    }},
                }},
                { type = "collapsible", title = "Actions", style = "h4", blocks = {
                    { type = "table",
                      columns = { "Action", "What it does" },
                      rows = {
                          { "|cffffd700Revert Changes|r",      "Undo every change made since selecting the bar" },
                          { "|cffffd700Reset Position|r",      "Snap the bar back to the centre of the screen" },
                          { "|cffffd700BazBars Settings|r",    "Jump to the full options panel for global settings" },
                          { "|cffffd700Export Bar Config|r",   "Copy the bar's complete layout + buttons + settings as a shareable string" },
                          { "|cffffd700Duplicate This Bar|r",  "Clone the bar with all its assignments in one click" },
                          { "|cffffd700Delete This Bar|r",     "Remove the bar permanently (asks for confirmation)" },
                      }},
                }},
            },
        },
        {
            title = "Edit Mode Tools",
            blocks = {
                { type = "paragraph", text = "Bars play by Edit Mode's rules:" },
                { type = "list", items = {
                    "Drag to move",
                    "Snap to the grid",
                    "Nudge with arrow keys for pixel-precise placement",
                    "Selection states use Blizzard's native cyan/yellow highlight art",
                }},
                { type = "note", style = "info", text = "Bar positions save to your active Edit Mode layout. Switching layouts in Edit Mode loads the matching bar positions." },
            },
        },
        {
            title = "Import / Export",
            blocks = {
                { type = "lead", text = "BazBars exports any bar's complete configuration as a shareable string — layout, every button, every setting. Paste a string back to recreate the bar on any character." },
                { type = "h2", text = "Exporting" },
                { type = "list", items = {
                    "Edit Mode → click a bar → Settings popup → Actions → |cffffd700Export Bar Config|r",
                    "Or via slash: |cff00ff00/bb export <id>|r",
                    "A copy-paste dialog opens with the encoded string — copy it, share it, save it for later",
                }},
                { type = "h2", text = "Importing" },
                { type = "list", items = {
                    "|cff00ff00/bb import|r opens an empty paste dialog",
                    "Paste the shared string and confirm — a new bar with the imported config spawns at the centre of your screen",
                    "Drag it where you want and you're done",
                }},
                { type = "h2", text = "Duplicating" },
                { type = "paragraph", text = "Duplicate copies a bar plus every button assignment, position-shifted slightly so it doesn't sit directly on top of the original. Use Edit Mode → Actions → Duplicate This Bar, or |cff00ff00/bb duplicate <id>|r." },
            },
        },
        {
            title = "Profiles",
            blocks = {
                { type = "lead", text = "Switch between named profiles to keep different bar setups for different content — PvE, PvP, Raid, Mythic+, alt-specific layouts." },
                { type = "h2", text = "What lives in a profile" },
                { type = "paragraph", text = "Each profile stores the complete BazBars state: every bar's position, layout, button assignments, keybinds, visibility macros, and per-bar settings. Switching profiles swaps the entire UI in one go." },
                { type = "h2", text = "Per-character defaults" },
                { type = "paragraph", text = "BazBars uses BazCore's standard profile system. By default, each character starts with the |cffffd700Default|r profile — but you can create a named profile, switch your characters to it, and copy settings between profiles freely." },
                { type = "h2", text = "Where to find it" },
                { type = "paragraph", text = "Settings → BazBars → |cffffd700Profiles|r. Standard BazCore profile chrome — Create, Switch, Copy From, Reset, Delete." },
                { type = "note", style = "tip", text = "Profiles are per-addon, so switching your BazBars profile doesn't affect your BazWidgetDrawers or BazNotificationCenter profiles. Each Baz addon owns its own." },
            },
        },
        {
            title = "Slash Commands",
            blocks = {
                { type = "table",
                  columns = { "Command", "Effect" },
                  rows = {
                      { "/bb",                          "Open the BazBars settings page" },
                      { "/bb create [cols] [rows]",     "Create a new bar with optional grid size" },
                      { "/bb delete <id>",              "Delete a bar by ID" },
                      { "/bb duplicate <id>",           "Duplicate a bar with all its button assignments" },
                      { "/bb export <id>",              "Export a bar's config as a shareable string" },
                      { "/bb import",                   "Open the import dialog" },
                      { "/bb scale <id> <value>",       "Set a bar's scale" },
                      { "/bb padding <id> <pixels>",    "Set button spacing" },
                      { "/bb reset",                    "Reset all bars (reloads UI)" },
                      { "/bb help",                     "Print every command" },
                      { "/bazbars",                     "Alias for /bb — every subcommand works on either form" },
                  },
                },
            },
        },
        {
            title = "Tips",
            blocks = {
                { type = "list", items = {
                    "Use a visibility macro like |cffffd700[combat] show; hide|r to make a bar appear only in combat",
                    "Items show live bag counts — handy for tracking herbs, ore, or potion stacks while farming",
                    "Random Favorite Mount works as a button — one click to roll a random mount",
                    "Bars don't take action slots, so all 120 default slots stay free",
                }},
                { type = "note", style = "tip", text = "Combine BazBars with BazWidgetDrawers for a fully customized UI without Blizzard slot constraints." },
            },
        },
    },
})
