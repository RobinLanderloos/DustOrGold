## Parent

docs/prd/vendor-or-disenchant-verdict.md

## State

In Progress (built and checked outside the game; needs real records)

## What to build

A slash command that compares the recorded disenchant results with the table: per band, the number of samples and the observed share of each material against the table's chance, plus any result the table says is impossible for that band. It also reports whether item level or required level explains the results better.

Covers user stories 39, 40.

## Acceptance criteria

- [ ] The command prints one summary per band that has records
- [ ] A received material the table does not list for that band is called out
- [ ] Records whose item level and required level fall in different bands are reported with which one matched the result
- [ ] The comparison is a pure function over a list of records, with tests

## Blocked by

- docs/issues/008-results-log-capture.md
