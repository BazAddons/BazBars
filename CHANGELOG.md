# BazBars Changelog

## 059 — Slash commands fixed, no more range-check errors

**`/bb` commands work again.** Every `/bb` subcommand (`create`, `export`,
`reset` and the rest) was failing with a "nil value" error. They now run
as intended.

**No more ADDON_ACTION_BLOCKED from item range checks.** With an item on a
bar and a friendly target in combat (healing a party member, targeting
yourself), BazBars tripped Blizzard's protected-call guard every range
tick. Items now skip that check in the one case Blizzard forbids it and
keep their normal colour. Range colouring against enemies is unchanged.

**Midnight API update.** Flyout spell detection now uses the current
spellbook API instead of a compatibility function that Blizzard is
phasing out.

**Marked compatible with patch 12.1.0.** The addon no longer shows as out of date in the AddOns list.
