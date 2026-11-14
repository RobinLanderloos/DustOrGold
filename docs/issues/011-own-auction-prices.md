## Parent

docs/prd/vendor-or-disenchant-verdict.md

## State

In Progress (built and checked outside the game; in-game check pending)

## What to build

DustOrGold collects its own auction prices and uses them before Auctionator's (ADR 0007). Opening the auction house searches the 24 materials and prices each by the cost of its cheapest 10 units. Every full scan, also Auctionator's, is read: batch prices for materials, the cheapest listing of each exact item for gear. `/dog scan` and a button in the list window do both on demand; `/dog autoscan on|off` switches the automatic material search.

## Acceptance criteria

- [ ] Opening the auction house updates material prices and says how many were found
- [ ] Tooltips and the list use our own price when we have one, Auctionator's otherwise
- [ ] A full scan started by Auctionator fills our prices too, gear included
- [ ] `/dog scan` runs a full scan when 15 minutes have passed, and says how long to wait otherwise
- [ ] Our material searches do not break Auctionator's or the auction house's own searches
- [ ] The price logic (batch price, item keys, storage, own-first choice) is pure and tested

## Blocked by

- docs/issues/002-verdict-line-on-item-tooltips.md
