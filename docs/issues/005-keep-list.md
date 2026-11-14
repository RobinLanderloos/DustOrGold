## Parent

docs/prd/vendor-or-disenchant-verdict.md

## State

In Progress (built and checked outside the game; in-game check pending)

## What to build

A keep list: items the player marks get no verdict anywhere. Items are added and removed with a slash command taking an item link, the list is saved account-wide, and a command prints what is on it.

Covers user stories 33-36.

## Acceptance criteria

- [ ] An item can be added to and removed from the keep list with a slash command and an item link
- [ ] A kept item shows no verdict line on its tooltip
- [ ] The keep list survives a reload and a relog
- [ ] A command lists the kept items
- [ ] The keep list (add, remove, contains, parsing an item ID from a link) is pure and tested

## Blocked by

- docs/issues/004-settings-margin-and-enchanter-alt.md
