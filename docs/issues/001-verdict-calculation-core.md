## Parent

docs/prd/vendor-or-disenchant-verdict.md

## State

Completed

## What to build

The pure calculation that turns plain item facts into a verdict: the disenchant table (kind, quality, item level band to drops with odds), material pricing with the lesser/greater essence rule, the Disenchant Value net of the auction cut, the three verdicts with a margin, the "no price" outcome, and the who-can-act rule. No game calls. Tested from the command line.

## Acceptance criteria

- [x] Every band's chances add up to 1, bands do not overlap, every drop is a known material
- [x] Disenchant Value is the probability-weighted average of the drops at the given prices, minus 5%
- [x] A lesser essence is valued at the lower of its own price and a third of the greater essence
- [x] Verdict is disenchant, vendor or close call according to the margin; the margin is adjustable
- [x] A missing price for a drop of at least 1% gives "no price"; a rarer drop is ignored
- [x] Items that cannot be disenchanted, and kept items, get no verdict
- [x] Non-enchanters get a verdict only for unbound items while the enchanter-alt setting is on
- [x] Tests run outside the game and pass

## Blocked by

None - can start immediately
