---
status: accepted
---

# Auctionator as an optional price source

Material prices change daily and Auctionator already scans and stores them, so DustOrGold reads material prices through Auctionator's public API (`Auctionator.API.v1.GetAuctionPriceByItemID`) and does not scan the auction house itself. Auctionator is an optional dependency: without it, or without a scan price, the addon still shows the expected materials but gives no verdict.

## Considered Options

- **Own auction house scanning or manually entered prices.** No dependency, but rebuilds what Auctionator does well and adds the largest piece of code in the addon for no gain.
- **Hard dependency on Auctionator.** Simpler, but a public addon should not fail to load because another addon is missing.

## Consequences

- All price access goes through one lookup function, so another price source (TSM, manual prices) can be added later without touching the calculation.
- Only Auctionator's public API is used, never its internals or its database tables.
