## Parent

docs/prd/vendor-or-disenchant-verdict.md

## State

In Progress (built and checked outside the game; in-game check pending)

## What to build

A window, opened with a slash command, listing every bag item that has a verdict, grouped into vendor, disenchant, close call and no price data, with a total per group. It refreshes when the bags change. The window only advises; it has no sell button (ADR 0005).

Covers user stories 23-28, 32.

## Acceptance criteria

- [ ] The slash command toggles the window
- [ ] Each row shows the item, its Vendor Value and its Disenchant Value
- [ ] Groups appear in a fixed order with a total: vendor total for the vendor group, disenchant total for the disenchant group
- [ ] Items with no price data are listed in their own group
- [ ] Kept items and items without a verdict do not appear
- [ ] The window updates after selling or disenchanting an item
- [ ] Grouping, totals and sorting come from a pure Bag Report module with tests

## Blocked by

- docs/issues/002-verdict-line-on-item-tooltips.md
