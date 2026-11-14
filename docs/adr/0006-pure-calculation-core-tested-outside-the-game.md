---
status: accepted
---

# Pure calculation core, tested outside the game

The risky part of the addon is arithmetic (band lookup, expected value, essence conversion, auction cut, margin, missing prices, who can act), and a mistake there shows a confident wrong number instead of an error. The calculation therefore lives in files that make no game API calls: they take plain item facts (item level, quality, type, vendor price, bound or not) and a price lookup function, and return a verdict with its numbers. A separate layer reads those facts from the game and draws the tooltip and list window. The pure files are tested from the command line with a standalone Lua 5.1 interpreter, so the logic can be verified without logging in.

## Consequences

- Calculation files must stay free of WoW globals (`C_Item`, `Enum`, frames, `Auctionator`); the game layer translates game values into plain ones before calling in.
- Entries from the results log can be turned directly into test cases.
