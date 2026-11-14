## Parent

docs/prd/vendor-or-disenchant-verdict.md

## State

In Progress (first report received 2026-11-14, see Findings)

## What to build

HITL. A short in-game session on the live Forever client to confirm the assumptions the game layer rests on. None of these can be checked from outside the game. `/dog debug [item link]` prints what the addon sees and stores the report in the saved variables, because chat cannot be copied out of the game.

## Acceptance criteria

- [x] On an enchanter, the addon detects that the character can disenchant; record which signal works (spellbook check, profession check)
- [ ] On a non-enchanter, it detects that the character cannot
- [ ] A soulbound item and a bind-on-pickup quest reward are both seen as bound; a bind-on-equip item is not
- [ ] An item marked as not disenchantable is detected from its tooltip line
- [ ] The item level the addon reads matches the item level shown in the auction house
- [x] Auctionator returns a price for a dust that has been scanned
- [ ] The events that fire on a disenchant (cast, loot) are noted, as input for the results log

## Findings

Build 70938, interface 16001, on an enchanter:

- All three Disenchant signals report yes: `C_SpellBook.IsSpellKnown(13262)`, `IsPlayerSpell(13262)`, and Enchanting (skill line 333) among the professions. The community report that Disenchant is missing from the spellbook does not hold on this build.
- Auctionator's public API returns prices: Strange Dust 87 copper.
- Notched Shortsword of Holy Wrath (item 727): weapon, uncommon, item level 10, required level 5, vendor 244 copper, not bound. Verdict vendor against a Disenchant Value of 159 copper, consistent with the table (80% Lesser Magic Essence, 20% Strange Dust).
- The saved margin (10%) persisted through a reload, and the settings panel works.

Still to check: a non-enchanter, bound items, the "cannot be disenchanted" line, item level against the auction house, and the disenchant events. The results capture assumes the item is locked in the bags during the cast and that the materials arrive in a loot window (LOOT_READY); with `/dog debug` run once first, each disenchant prints `[log]` lines showing whether that holds.

## Blocked by

- docs/issues/002-verdict-line-on-item-tooltips.md
