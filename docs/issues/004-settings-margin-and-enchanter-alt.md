## Parent

docs/prd/vendor-or-disenchant-verdict.md

## State

Completed (settings panel and saved margin confirmed in the live client 2026-11-14)

## What to build

Account-wide saved settings for the close-call margin (default 20%) and the "I have an enchanter alt" switch (default on), changeable through slash commands and a category in the game's settings panel. Changes take effect on the next tooltip.

Covers user stories 16, 21, 22, 42-44.

## Acceptance criteria

- [ ] Settings are created with defaults on first load and survive a reload and a relog
- [ ] A slash command shows the current settings and changes the margin and the switch
- [ ] The settings panel has a DustOrGold category with a margin slider and the switch
- [ ] Switching the enchanter-alt setting off removes verdicts on a non-enchanter
- [ ] Applying defaults to stored settings (including settings from an older version) is a pure function with tests

## Blocked by

- docs/issues/002-verdict-line-on-item-tooltips.md
