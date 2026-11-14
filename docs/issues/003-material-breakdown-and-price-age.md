## Parent

docs/prd/vendor-or-disenchant-verdict.md

## State

In Progress (built and checked outside the game; in-game check pending, see issue 010)

## What to build

While Shift is held, the tooltip lists the materials the item can yield with their odds and quantity ranges, using the game's localized material names. The age of the scan price is shown next to the Disenchant Value when Auctionator provides it. Without Auctionator, or without prices, the breakdown is shown anyway so the addon is useful before price data exists.

Covers user stories 5, 6, 10, 11.

## Acceptance criteria

- [ ] Holding Shift adds one line per drop: chance, quantity range, material name
- [ ] Material names follow the game's language, with an English fallback until the name is cached
- [ ] The oldest price age among the drops is shown when it is more than a day
- [ ] Without Auctionator the materials are listed and no verdict is claimed
- [ ] The text of the breakdown lines is produced by a pure function with tests

## Blocked by

- docs/issues/002-verdict-line-on-item-tooltips.md
