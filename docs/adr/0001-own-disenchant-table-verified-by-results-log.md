---
status: accepted
---

# Own disenchant table, verified by a results log

Blizzard exposes no API or published data for disenchant results or odds, and Auctionator's disenchant estimate returns nothing for vanilla-era items on the WoW Forever client (its retail logic only supports Warlords of Draenor and later). DustOrGold therefore ships its own table mapping item type, quality and item level band to expected materials and odds, seeded from the long-standing vanilla community numbers and written from scratch so the addon stays publishable. Because Forever is not pure vanilla (it has enchanting recipes that never existed in 2006) and nobody has confirmed the table for it, every disenchant the player performs is recorded to saved variables so deviations show up as data.

## Considered Options

- **Call Auctionator's disenchant price API.** Least code, but gives no value for the items this addon exists for.
- **Self-learning table** that replaces the seed with observed results. Rejected for now: it needs hundreds of samples per band before it beats the seed. The log record (item ID, item level, required level, quality, type, materials received) is designed so this stays possible without migrating data.
- **Ship the vanilla table with no log.** Rejected: silently wrong wherever Forever deviates.

## Consequences

- The table is hand-maintained; the log informs corrections but never changes verdicts by itself.
- The table is keyed on item level. A Forever guide bands by required level instead, so the log stores both to settle which one the server really uses.
