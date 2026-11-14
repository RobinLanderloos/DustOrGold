## Parent

docs/prd/vendor-or-disenchant-verdict.md

## State

In Progress (built and checked outside the game; in-game check pending)

## What to build

Every disenchant the player performs is recorded account-wide: item ID, item level, required level, quality, kind, and the materials and counts received (ADR 0001). The record is written when the loot from the Disenchant cast arrives.

Covers user stories 37, 38, 41.

## Acceptance criteria

- [ ] Disenchanting an item adds exactly one record with the item's facts and the materials received
- [ ] Loot from anything other than a disenchant adds no record
- [ ] Records survive a reload, a relog and an addon update
- [ ] Building a record from item facts and received materials is a pure function with tests

## Blocked by

- docs/issues/002-verdict-line-on-item-tooltips.md
- docs/issues/010-verify-client-assumptions-in-game.md
