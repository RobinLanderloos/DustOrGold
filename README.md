# DustOrGold

A WoW Forever addon that tells you whether an item is worth more sold to a vendor or disenchanted.

- **Tooltip:** a verdict (vendor, disenchant or close call) with the vendor price and the expected disenchant value after the auction cut. Hold Shift for the materials and their odds. When Auctionator knows the item's own price, a line shows what listing it would fetch.
- **List window** (`/dog` or the minimap button): your bag items grouped into vendor, disenchant, auction, close calls and no price data, with totals and a one-click Disenchant button for enchanters.
- **Results log:** every disenchant is recorded; `/dog results` compares what you got with the table.

Material prices come from [Auctionator](https://www.curseforge.com/wow/addons/auctionator) scans (optional). `/dog help` lists all commands.

## Development

The calculation lives in `Core/` and makes no game calls, so it is tested outside the game with LuaJIT:

```
luajit tests/run.lua         # unit tests
luajit tests/smoke_test.lua  # loads every file in the .toc against a stand-in for the game
```

Design decisions are in `docs/adr/`, the product requirements in `docs/prd/`, and the work items in `docs/issues/`.
