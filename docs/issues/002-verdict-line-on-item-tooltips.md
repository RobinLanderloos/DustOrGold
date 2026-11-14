## Parent

docs/prd/vendor-or-disenchant-verdict.md

## State

Completed (confirmed in the live client 2026-11-14)

## What to build

The addon loads on the WoW Forever client and adds one verdict line to the tooltip of any disenchantable item: the verdict, coloured by outcome, with the Vendor Value and Disenchant Value. This is the first end-to-end path: game item to plain item facts, Auctionator price lookup, calculation, tooltip line. Includes the addon manifest, the locale file for the addon's own labels, and the link from the Forever AddOns folder to the project folder.

Covers user stories 1-4, 7-9, 12, 17-20, 45, 46.

## Acceptance criteria

- [ ] The addon appears in the Forever addon list and loads without Lua errors
- [ ] Hovering an uncommon, rare or epic weapon or armor piece shows a verdict line with both values
- [ ] The line is green for disenchant, a neutral colour for vendor, yellow for close call
- [ ] Items that cannot be disenchanted show no line
- [ ] With a material price missing, the line reads "no price data"
- [ ] Without Auctionator loaded, the addon still loads and shows no errors
- [ ] A soulbound item on a non-enchanter shows no line
- [ ] The translation from game values to plain item facts is tested outside the game where it is pure

## Blocked by

- docs/issues/001-verdict-calculation-core.md
