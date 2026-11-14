---
status: accepted
---

# The verdict rule: Vendor Value against net Disenchant Value, with a close-call band

The verdict compares two numbers. **Vendor Value** is the item's vendor sell price. **Disenchant Value** is the probability-weighted average of the materials a disenchant yields, priced at Auctionator's scan price, minus the 5% auction house cut. There are three outcomes: *vendor*, *disenchant*, or *close call* when Disenchant Value is within the margin (default 20%, adjustable) of Vendor Value. A forced verdict on a small difference would claim a precision that neither the table nor the scan prices have.

## Rules that look like omissions but are deliberate

- **The item's own auction price is not part of the comparison.** Whether one specific green sells is far less certain than whether dust sells, so listing the item whole is not a third verdict. It is shown as information next to the verdict (after the 5% cut, flagged when it beats both vendor and a known Disenchant Value), so the player can choose to list it. In the list window, items whose auction price beats both are grouped under "Auction these" and get no Disenchant button by default; the tooltip's verdict line stays vendor or disenchant.
- **A missing material price means no verdict**, shown as "no price data". Treating the material as worth zero would produce a confident wrong "vendor".
- **The materials' own vendor price is ignored.**
- **A lesser essence is valued at the lower of its own price and one third of the greater essence's price**, because three lesser combine into one greater.
- **Items that cannot be disenchanted get no verdict at all**: anything that is not an uncommon-to-epic weapon or armor piece, or that carries the "cannot be disenchanted" tooltip line.
