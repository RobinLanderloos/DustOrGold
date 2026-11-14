## Parent

docs/prd/vendor-or-disenchant-verdict.md

## State

In Progress (built and checked outside the game; in-game check pending)

## What to build

For a character that knows Disenchant, each row in the disenchant and close-call groups of the list window carries a button that casts Disenchant on that bag item, one click per item. It is a plain secure spell button, set up only out of combat. Non-enchanters see no buttons.

Covers user stories 29-31.

## Acceptance criteria

- [ ] Clicking a row's button disenchants that exact bag item
- [ ] Buttons are absent on a character that cannot disenchant
- [ ] Entering combat hides or disables the buttons without Lua errors or taint warnings
- [ ] After a disenchant the row disappears and the buttons point at the right slots

## Blocked by

- docs/issues/006-bag-list-window.md
- docs/issues/010-verify-client-assumptions-in-game.md
