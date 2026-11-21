---
status: accepted (amended by 0008)
supersedes: 0002
---

# Own auction prices first, Auctionator as fallback

DustOrGold keeps its own auction prices and uses them before Auctionator's; Auctionator is only asked for items we have no price for. This makes the addon work without Auctionator, while players who already run it lose nothing.

Prices are collected three ways, all on the modern auction house API that the Forever client uses:

- **Material searches when the auction house opens** (switchable): the 24 disenchanting materials are searched one by one. This has no 15-minute limit and keeps the prices that drive every verdict fresh.
- **Every full scan is read**, whoever requested it. The server sends the results of a full scan to all addons, so Auctionator's scans also fill our prices, gear included.
- **`/dog scan`** does both on demand. Full scans are limited by the server to one per 15 minutes, shared with Auctionator.

**The price** of a material is the average per-unit cost of buying its cheapest 10 units, so one under-priced single listing does not set it. The price of gear is the cheapest listing of that exact item, keyed by item ID, suffix and bonus IDs, so "of the Eagle" and "of the Bear" are priced apart.

## Considered Options

- **Keep relying on Auctionator only** (ADR 0002). The addon would not work without it, and the player asked for independence.
- **Own data only.** Nothing would have a price until the first scan, and Auctionator users would lose data they already have.
- **Full scans only.** Covers everything but at most once every 15 minutes, shared with Auctionator; material searches keep the numbers that matter most fresh without that limit.
- **Cheapest single listing as the price** (Auctionator's choice). One cheap dust would pull every verdict down.

## Consequences

- Prices are stored in the saved variables and grow with every full scan.
- Gear seen in a full scan without item data loaded is skipped; materials are recorded anyway because they have no suffixes.
- Material searches run while the auction house is open and can briefly compete with the player's own searches for the server's request allowance.
