---
status: accepted
amends: 0007
---

# Auctionator's prices when it is installed, own scans only without it

When Auctionator is installed, DustOrGold does not collect auction prices itself: no material searches when the auction house opens, no reading of full scans, and `/dog scan` points to Auctionator instead. Prices come from Auctionator first. Only without Auctionator does DustOrGold run the scans of ADR 0007 and use its own prices.

Own prices recorded earlier stay in the saved variables and are used only for items Auctionator has no price for; likewise Auctionator's prices fill gaps in our own when both exist.

## Considered Options

- **Own prices first, Auctionator as fallback** (ADR 0007). Two addons searching the same auction house compete for the server's request allowance and for the one full scan per 15 minutes, and players who keep Auctionator's data fresh gain nothing from a second copy.
- **Auctionator only, drop own scans** (ADR 0002). The addon would stop working without Auctionator.

## Consequences

- With Auctionator, the list window has no scan button and price notes say "Auctionator".
- Whether Auctionator is installed is checked each time a price is needed, so enabling or disabling it takes effect after a `/reload`.
