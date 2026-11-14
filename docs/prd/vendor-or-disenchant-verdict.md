# DustOrGold: vendor or disenchant verdict

## Problem Statement

On WoW Forever, a player with full bags of green, blue and epic gear has to decide for each piece whether to sell it to a vendor or disenchant it. The vendor price is visible, but what a disenchant is worth is not: it depends on which materials the item can yield, at what odds, and what those materials sell for on the auction house today. Auctionator's built-in disenchant estimate gives nothing for vanilla-era items on the Forever client, so the player is left guessing, and guesses wrong in both directions: vendoring items whose dust is worth more, and disenchanting items that would have vendored for more.

The decision is also not the same on every character. A character that is not an enchanter can only have an item disenchanted by mailing it to an alt, which is impossible once the item is soulbound.

## Solution

DustOrGold gives every disenchantable item a **verdict**: *vendor*, *disenchant*, or *close call*.

- The **Vendor Value** is the item's vendor sell price.
- The **Disenchant Value** is the probability-weighted average of the materials a disenchant yields, priced at Auctionator's scan prices, after the 5% auction house cut.
- The verdict appears as a line on the item's tooltip, with both numbers, and with the material odds while Shift is held.
- A list window, opened with a slash command, shows everything in the player's bags grouped by verdict with totals, and lets an enchanter disenchant items with one click each.
- Each disenchant the player performs is recorded, so the shipped table can be checked against what Forever really gives.

The addon only advises on selling. It never sells anything itself.

## User Stories

### Verdict on the tooltip

1. As a player, I want a verdict line on the tooltip of any disenchantable item, so that I know at a glance whether to vendor or disenchant it.
2. As a player, I want to see both the Vendor Value and the Disenchant Value next to the verdict, so that I can judge how big the difference is.
3. As a player, I want the verdict coloured by outcome, so that I can read it without reading the numbers.
4. As a player, I want a "close call" verdict when the two values are within a margin of each other, so that the addon does not claim a precision it does not have.
5. As a player, I want to hold Shift to see which materials the item can yield and at what odds, so that I understand where the Disenchant Value comes from.
6. As a player, I want material names shown in my game's language, so that the breakdown matches what I see in my bags.
7. As a player, I want the verdict on every item tooltip (bags, loot window, quest rewards, auction house, chat links), so that I get advice wherever I meet an item.
8. As a player, I want no verdict line on items that cannot be disenchanted, so that my tooltips are not cluttered.
9. As a player, I want the tooltip to say "no price data" when a material has no scan price, so that I am not misled into vendoring.
10. As a player, I want to see how old the scan price is, so that I can discount a verdict based on a week-old price.
11. As a player without Auctionator, I want to still see the expected materials, so that the addon is useful before I have price data.

### The verdict rule

12. As a player, I want the Disenchant Value to be net of the 5% auction house cut, so that it reflects what I would actually receive.
13. As a player, I want lesser essences valued with their conversion to greater essences in mind, so that a thin market for one of them does not distort the value.
14. As a player, I want quantity ranges averaged, so that the value reflects a typical result.
15. As a player, I want a very rare drop without a price to be ignored instead of blocking the verdict, so that a missing Nexus Crystal price does not hide the verdict on a blue.
16. As a player, I want to set the close-call margin myself, so that I can be stricter or looser than the 20% default.
17. As a player, I want an item that vendors will not buy to be compared against a Vendor Value of zero, so that it still gets a sensible verdict.

### Who can act

18. As an enchanter, I want a verdict on every disenchantable item including soulbound ones, so that I can act on all of my gear.
19. As a non-enchanter with an enchanter alt, I want a verdict on items I can still mail, so that I know what to send to my alt.
20. As a non-enchanter, I want no disenchant verdict on soulbound items, so that I am not told to do something impossible.
21. As a player without any enchanter, I want to switch off the enchanter-alt setting, so that my non-enchanters see no verdicts at all.
22. As a player, I want the enchanter-alt setting to be on by default and shared across my characters, so that I do not have to configure each one.

### List window

23. As a player, I want a window listing every bag item that has a verdict, so that I can sort out a full bag in one pass at the vendor.
24. As a player, I want the list grouped into vendor, disenchant and close call, so that I can work through one group at a time.
25. As a player, I want a total per group, so that I know what the whole bag is worth each way.
26. As a player, I want items without price data listed separately, so that I know which ones need a fresh auction scan.
27. As a player, I want the list to refresh when my bags change, so that it stays correct while I sell and disenchant.
28. As a player, I want to open the list with a slash command, so that I do not need another button on my screen.
29. As an enchanter, I want a disenchant button on each row in the disenchant group, so that I can disenchant without hunting for the item in my bags.
30. As a non-enchanter, I want no disenchant buttons, so that I am not offered an action I cannot take.
31. As a player, I want the disenchant button to be unavailable in combat, so that the addon does not cause errors.
32. As a player, I want the addon to never sell items for me, so that a wrong verdict cannot cost me an item.

### Keep list

33. As a player, I want to mark an item as kept, so that gear I am saving does not show up as "vendor" every time.
34. As a player, I want kept items to get no verdict in the tooltip and no row in the list, so that they are out of the way.
35. As a player, I want to remove an item from the keep list, so that I can change my mind.
36. As a player, I want the keep list saved between sessions, so that I mark an item once.

### Results log

37. As a player, I want every disenchant I perform recorded with the item and the materials received, so that the table can be checked against real results.
38. As a player, I want the record to hold item level and required level, so that we can tell which one Forever's bands use.
39. As a player, I want a command that compares my recorded results with the table, so that deviations are visible.
40. As a player, I want results that the table says are impossible called out, so that I learn when Forever differs from vanilla.
41. As a player, I want the log to survive addon updates, so that evidence builds up over time.

### Settings

42. As a player, I want the margin and the enchanter-alt switch in the game's settings panel, so that I can change them without typing commands.
43. As a player, I want slash commands for the same settings, so that I can change them quickly.
44. As a player, I want my settings saved account-wide, so that all my characters behave the same.

### Publishable later

45. As a future user on another language client, I want the addon's own labels in a locale file, so that they can be translated.
46. As a future user without Auctionator, I want the addon to load and work without errors, so that it does not depend on another addon being installed.

## Implementation Decisions

The six ADRs in `docs/adr/` are binding. The modules below follow from them.

**Pure modules (no game calls, per ADR 0006):**

- **Disenchant Table.** Data only: for each kind (armor, weapon) and quality (uncommon, rare, epic), a list of item level bands, each with its drops (material, quantity range, chance). Also the material item IDs with fallback English names, and the lesser-to-greater essence mapping. Written from scratch from publicly known vanilla numbers (ADR 0001).
- **Valuation.** Takes plain item facts and a context, returns a verdict with its numbers, or nothing when the item gets no verdict.
  - Item facts: kind, quality, item level, Vendor Value, bound or not, cannot-disenchant flag, kept flag.
  - Context: a price lookup function, the margin, whether this character can disenchant, the enchanter-alt setting.
  - Result: verdict, Vendor Value, Disenchant Value, the band, and the materials missing a price.
  - Verdicts: disenchant when the Disenchant Value exceeds Vendor Value by more than the margin, vendor when it falls short by more than the margin, close call in between, and "no price" when a drop with a chance of at least 1% has no price (ADR 0003).
- **Bag Report.** Takes a list of bag items with their evaluations and returns the groups (vendor, disenchant, close call, no price) with a total per group, sorted for display. The list window only draws what this returns.
- **Results Log.** Builds a record from a disenchant (item ID, item level, required level, quality, kind, materials and counts received) and compares a set of records against the table: per band, observed share of each material against the table's chance, and any material the table does not list for that band.
- **Keep List.** A set of item IDs with add, remove and contains.

**Game layer:**

- **Item facts adapter.** Turns a game item (link, tooltip data, bag slot) into the plain item facts above. Item level comes from the detailed item level call; bound status and the "cannot be disenchanted" flag come from tooltip lines; cosmetic armor is excluded.
- **Price source.** One lookup function backed by Auctionator's public API, returning nothing when Auctionator is absent (ADR 0002). Also exposes price age when available.
- **Player capability.** Whether this character knows Disenchant. Forever reportedly does not list Disenchant in the spellbook, so this checks more than one signal and must be verified in-game.
- **Tooltip.** Registers one post-call on item tooltips, the same mechanism BetterVendorPrice uses on this client. Money is added as text, not with the money frame, to avoid taint in combat.
- **List window.** Draws the Bag Report. Each disenchant row for an enchanter carries a plain secure spell button targeting that bag slot, created and moved only out of combat (ADR 0005).
- **Results capture.** Watches for the player's Disenchant cast and the loot that follows, and hands a record to the Results Log.
- **Settings.** Account-wide saved variables holding the margin, the enchanter-alt switch, the keep list and the results log. A settings panel category and slash commands.
- **Locale.** All of the addon's own labels in one file; material names come from the game by item ID.

**Packaging:** interface number 16001, Forever only, Auctionator as an optional dependency, one saved variable. Development happens in the project folder, linked into the Forever AddOns folder.

## Testing Decisions

- A good test exercises a module through its public interface with plain values and checks the result a player would see (a verdict, a number, a group), not how it was computed internally.
- The five pure modules are tested outside the game with a Lua 5.1 compatible interpreter (LuaJIT), run from the command line. Each new behaviour is written test-first.
- The table gets structural tests: chances per band add up to 1, bands do not overlap, every drop is a known material.
- The game layer is not tested outside the game. It is kept thin, and checked in-game by hand.
- Prior art: the existing test runner in the project's tests folder, which loads the pure files the same way the game does (passing the addon name and shared namespace).

## Out of Scope

- Selling items to a vendor automatically, with or without confirmation (ADR 0005).
- The item's own auction price as a third verdict (ADR 0003).
- Scanning the auction house or entering prices by hand (ADR 0002).
- A self-learning table that changes verdicts from logged results (ADR 0001).
- Markers on bag slots.
- Clients other than WoW Forever, and languages other than English.
- Publishing to CurseForge or Wago.
- Items above item level 65 for uncommon and rare, or materials from later expansions.

## Further Notes

- The table is unverified for Forever. A Forever disenchanting guide lists the same materials and quantities as vanilla, but bands by required level where the vanilla numbers use item level. The results log is how this gets settled.
- Auctionator's own vanilla table lists Greater Magic Essence for uncommon weapons of item level 21-30, where the community numbers give Astral essences. Our table uses the community numbers; this is one of the first things the log should confirm.
- Whether the Disenchant spell is detectable through the spellbook on Forever is unknown and needs an in-game check.
