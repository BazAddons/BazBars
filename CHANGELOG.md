# BazBars Changelog

## 060 — Flyout combat fixes

**Flyouts close the moment you cast, even in combat.** With BazCore 121,
casting from an open flyout closes it immediately instead of leaving it
open until combat ends.

**No more error when closing flyout settings mid-fight.** If combat began
while a flyout's settings dialog was open, pressing Cancel, Apply or the
close button tripped Blizzard's protected-frame guard. The flyout now
closes once combat ends instead.
