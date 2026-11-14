-- The text a player reads: the verdict line and the material breakdown.
local ns, test, eq = ...
local Display, V, M, L = ns.Display, ns.Valuation, ns.Materials, ns.L

-- Money as plain copper so the expected text is readable.
local function money(copper) return copper .. "c" end

local band = V.FindBand("armor", 2, 28)

test("disenchant verdict leads with the Disenchant Value", function()
  local text, color = Display.VerdictLine(
    { verdict = V.DISENCHANT, vendorValue = 1000, disenchantValue = 2873, band = band }, L, money)
  eq(text, "Disenchant: 2873c  (vendor 1000c)")
  eq(color, Display.Colors.disenchant)
end)

test("vendor verdict leads with the Vendor Value", function()
  local text, color = Display.VerdictLine(
    { verdict = V.VENDOR, vendorValue = 5000, disenchantValue = 2873, band = band }, L, money)
  eq(text, "Vendor: 5000c  (disenchant ~2873c)")
  eq(color, Display.Colors.vendor)
end)

test("close call shows both values", function()
  local text, color = Display.VerdictLine(
    { verdict = V.CLOSE, vendorValue = 2600, disenchantValue = 2873, band = band }, L, money)
  eq(text, "Close call: disenchant ~2873c, vendor 2600c")
  eq(color, Display.Colors.close)
end)

test("no price data is said plainly, without numbers", function()
  local text, color = Display.VerdictLine(
    { verdict = V.NO_PRICE, vendorValue = 1000, band = band, missing = { M.SOUL_DUST } }, L, money)
  eq(text, "Disenchant: no price data")
  eq(color, Display.Colors.noprice)
end)

test("a price older than a day is flagged", function()
  local result = { verdict = V.DISENCHANT, vendorValue = 1000, disenchantValue = 2873, band = band }
  eq(Display.VerdictLine(result, L, money, 6), "Disenchant: 2873c  (vendor 1000c)  [price 6 days old]")
  eq(Display.VerdictLine(result, L, money, 1), "Disenchant: 2873c  (vendor 1000c)")
  eq(Display.VerdictLine(result, L, money, nil), "Disenchant: 2873c  (vendor 1000c)")
end)

test("auction line when listing the item beats vendor and disenchant", function()
  local text, color = Display.AuctionLine({ net = 9500, beatsVendor = true, beatsAll = true }, L, money)
  eq(text, "Auction: 9500c after the cut, better than vendor and disenchant")
  eq(color, Display.Colors.auction)
end)

test("auction line when it only beats the vendor", function()
  local text, color = Display.AuctionLine({ net = 6000, beatsVendor = true, beatsAll = false }, L, money)
  eq(text, "Auction: 6000c after the cut, better than vendor")
  eq(color, Display.Colors.vendor)
end)

test("auction line when the vendor pays more", function()
  local text, color = Display.AuctionLine({ net = 4940, beatsVendor = false, beatsAll = false }, L, money)
  eq(text, "Auction: 4940c after the cut, less than vendor")
  eq(color, Display.Colors.noprice)
end)

test("an old item price is flagged on the auction line", function()
  eq(Display.AuctionLine({ net = 4940, beatsVendor = false, beatsAll = false }, L, money, 5),
    "Auction: 4940c after the cut, less than vendor  [price 5 days old]")
end)

test("breakdown lists each drop with chance, name and quantity", function()
  local lines = Display.BreakdownLines(band, L, function(id) return ns.MaterialNames[id] end)
  eq(#lines, 3)
  eq(lines[1], "  75% Soul Dust x1-2")
  eq(lines[2], "  20% Greater Astral Essence x1-2")
  eq(lines[3], "  5% Large Glimmering Shard x1")
end)

test("breakdown keeps a fraction of a percent", function()
  local lines = Display.BreakdownLines(V.FindBand("armor", 3, 58), L, function(id) return ns.MaterialNames[id] end)
  eq(lines[1], "  99.5% Large Brilliant Shard x1")
  eq(lines[2], "  0.5% Nexus Crystal x1")
end)
