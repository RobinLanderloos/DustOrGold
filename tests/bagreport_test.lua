-- The bag report: what the list window shows.
local ns, test, eq = ...
local BagReport, V = ns.BagReport, ns.Valuation

local function entry(name, verdict, vendorValue, disenchantValue, extra)
  local e = {
    link = name,
    result = verdict and { verdict = verdict, vendorValue = vendorValue, disenchantValue = disenchantValue },
  }
  for k, v in pairs(extra or {}) do e[k] = v end
  return e
end

test("items are grouped by verdict in a fixed order", function()
  local groups = BagReport.Build({
    entry("close one", V.CLOSE, 100, 110),
    entry("dust me", V.DISENCHANT, 100, 500),
    entry("no data", V.NO_PRICE, 100, nil),
    entry("sell me", V.VENDOR, 900, 100),
  })
  eq(#groups, 4)
  eq(groups[1].verdict, V.VENDOR)
  eq(groups[2].verdict, V.DISENCHANT)
  eq(groups[3].verdict, V.CLOSE)
  eq(groups[4].verdict, V.NO_PRICE)
  eq(groups[1].rows[1].link, "sell me")
end)

local function withAuction(e, net, beatsAll)
  e.auction = { net = net, beatsVendor = true, beatsAll = beatsAll }
  return e
end

test("items worth more listed than vendored or disenchanted get their own group", function()
  local groups = BagReport.Build({
    withAuction(entry("list me", V.DISENCHANT, 100, 500), 900, true),
    entry("dust me", V.DISENCHANT, 100, 500),
    entry("sell me", V.VENDOR, 900, 100),
  })
  eq(#groups, 3)
  eq(groups[1].verdict, V.VENDOR)
  eq(groups[2].verdict, V.DISENCHANT)
  eq(groups[3].verdict, BagReport.AUCTION)
  eq(groups[3].rows[1].link, "list me")
  eq(#groups[2].rows, 1, "it is no longer in the disenchant group")
end)

test("the auction group totals what the items fetch after the cut", function()
  local groups = BagReport.Build({
    withAuction(entry("a", V.VENDOR, 100, 50), 400, true),
    withAuction(entry("b", V.CLOSE, 100, 110), 900, true),
  })
  eq(groups[1].verdict, BagReport.AUCTION)
  eq(groups[1].auctionTotal, 1300)
  eq(groups[1].rows[1].link, "b", "highest first")
end)

test("an auction price that only beats the vendor does not move the item", function()
  local groups = BagReport.Build({ withAuction(entry("dust me", V.DISENCHANT, 100, 500), 300, false) })
  eq(#groups, 1)
  eq(groups[1].verdict, V.DISENCHANT)
end)

test("the auction group gets no Disenchant button unless the setting is on", function()
  local green = { kind = "armor", quality = 2, itemLevel = 28 }
  eq(BagReport.CanCast(BagReport.AUCTION, green, { canDisenchant = true }), false)
  eq(BagReport.CanCast(BagReport.AUCTION, green, { canDisenchant = true, buttonOnAll = true }), true)
end)

test("a group without items is left out", function()
  local groups = BagReport.Build({ entry("sell me", V.VENDOR, 900, 100) })
  eq(#groups, 1)
  eq(groups[1].verdict, V.VENDOR)
end)

test("items without a verdict do not appear", function()
  local groups = BagReport.Build({ entry("bread", nil), entry("sell me", V.VENDOR, 900, 100) })
  eq(#groups, 1)
  eq(#groups[1].rows, 1)
end)

test("each group totals both values", function()
  local groups = BagReport.Build({
    entry("a", V.DISENCHANT, 100, 500),
    entry("b", V.DISENCHANT, 150, 700),
  })
  eq(groups[1].vendorTotal, 250)
  eq(groups[1].disenchantTotal, 1200)
end)

test("the no-price group totals only the Vendor Value", function()
  local groups = BagReport.Build({ entry("a", V.NO_PRICE, 100, nil), entry("b", V.NO_PRICE, 50, nil) })
  eq(groups[1].vendorTotal, 150)
  eq(groups[1].disenchantTotal, nil)
end)

test("rows are sorted by what the verdict earns, highest first", function()
  local groups = BagReport.Build({
    entry("small", V.VENDOR, 100, 10),
    entry("big", V.VENDOR, 900, 10),
    entry("low dust", V.DISENCHANT, 10, 200),
    entry("high dust", V.DISENCHANT, 10, 800),
  })
  eq(groups[1].rows[1].link, "big")
  eq(groups[1].rows[2].link, "small")
  eq(groups[2].rows[1].link, "high dust")
  eq(groups[2].rows[2].link, "low dust")
end)

test("on request, items without a verdict are listed last as their own group", function()
  local groups = BagReport.Build({
    entry("bread", nil),
    entry("sell me", V.VENDOR, 900, 100),
    entry("apple", nil),
  }, { includeOthers = true })
  eq(#groups, 2)
  eq(groups[2].verdict, BagReport.OTHER)
  eq(#groups[2].rows, 2)
  eq(groups[2].rows[1].link, "apple", "sorted by name")
  eq(groups[2].vendorTotal, nil)
end)

test("without the request, items without a verdict stay out", function()
  eq(#BagReport.Build({ entry("bread", nil) }), 0)
end)

-- Which rows get the Disenchant button.
local green = { kind = "armor", quality = 2, itemLevel = 28 }
local white = { kind = nil, quality = 1 }
local function canCast(verdict, facts, options)
  local o = { canDisenchant = true, buttonOnAll = false }
  for k, v in pairs(options or {}) do o[k] = v end
  return BagReport.CanCast(verdict, facts, o)
end

test("the button is on disenchant and close-call rows", function()
  eq(canCast(V.DISENCHANT, green), true)
  eq(canCast(V.CLOSE, green), true)
  eq(canCast(V.VENDOR, green), false)
  eq(canCast(V.NO_PRICE, green), false)
end)

test("a character that cannot disenchant never gets the button", function()
  eq(canCast(V.DISENCHANT, green, { canDisenchant = false }), false)
  eq(canCast(V.VENDOR, green, { canDisenchant = false, buttonOnAll = true }), false)
end)

test("with the setting on, every disenchantable item gets the button", function()
  local on = { buttonOnAll = true }
  eq(canCast(V.VENDOR, green, on), true)
  eq(canCast(V.NO_PRICE, green, on), true)
  eq(canCast(BagReport.OTHER, { kind = "armor", quality = 3, itemLevel = 120 }, on), true, "outside the table")
end)

test("the setting does not reach items the game will not disenchant", function()
  local on = { buttonOnAll = true }
  eq(canCast(BagReport.OTHER, { kind = "armor", quality = 2, cannotDisenchant = true }, on), false)
end)

test("kept items never get the button", function()
  local kept = { kind = "armor", quality = 2, itemLevel = 28, isKept = true }
  eq(canCast(BagReport.OTHER, kept, { buttonOnAll = true }), false)
end)

test("in the debug group, items the game will refuse get the button to try it out", function()
  eq(canCast(BagReport.OTHER, white), true)
  eq(canCast(BagReport.OTHER, green), false, "without the setting a real green stays safe")
end)

test("rows keep whatever the caller attached, such as the bag slot", function()
  local groups = BagReport.Build({ entry("a", V.DISENCHANT, 100, 500, { bag = 2, slot = 7 }) })
  eq(groups[1].rows[1].bag, 2)
  eq(groups[1].rows[1].slot, 7)
end)
