-- Our own auction prices: what counts as the price, and how it is kept.
local ns, test, eq = ...
local PriceBook, M = ns.PriceBook, ns.Materials

local DAY = 86400

-- Batch prices ---------------------------------------------------------------

test("the price is the average cost of buying the cheapest batch", function()
  local listings = {
    { unitPrice = 100, quantity = 2 },
    { unitPrice = 300, quantity = 20 },
    { unitPrice = 50, quantity = 1 },
  }
  -- cheapest 10 units: 1 x 50, 2 x 100, 7 x 300 = 50 + 200 + 2100 = 2350 / 10
  eq(PriceBook.BatchPrice(listings, 10), 235)
end)

test("one cheap single listing does not set the price on its own", function()
  local listings = { { unitPrice = 1, quantity = 1 }, { unitPrice = 1000, quantity = 50 } }
  eq(PriceBook.BatchPrice(listings, 10), 900) -- (1 + 9000) / 10, rounded down
end)

test("with fewer units listed than the batch, all of them count", function()
  eq(PriceBook.BatchPrice({ { unitPrice = 100, quantity = 2 }, { unitPrice = 200, quantity = 1 } }, 10), 133)
end)

test("a batch of one is the cheapest listing", function()
  eq(PriceBook.BatchPrice({ { unitPrice = 900, quantity = 1 }, { unitPrice = 700, quantity = 1 } }, 1), 700)
end)

test("nothing listed means no price", function()
  eq(PriceBook.BatchPrice({}, 10), nil)
  eq(PriceBook.BatchPrice({ { unitPrice = 0, quantity = 5 } }, 10), nil, "free listings are not prices")
end)

-- Price keys ----------------------------------------------------------------

test("a plain item is keyed by its ID", function()
  eq(PriceBook.Key(10940), "i:10940")
  eq(PriceBook.Key("|cffffffff|Hitem:10940::::::::60:::::::::|h[Strange Dust]|h|r"), "i:10940")
end)

test("the suffix and bonus IDs keep 'of the Eagle' and 'of the Bear' apart", function()
  local wrath = "|cnIQ2:|Hitem:727::::::::13:1490:::1:12759::::::|h[Notched Shortsword of Holy Wrath]|h|r"
  eq(PriceBook.Key(wrath), "i:727:b12759")
  eq(PriceBook.Key("item:727:0:0:0:0:0:15:0:13"), "i:727:s15")
  eq(PriceBook.Key("item:727::::::::13::::2:300:100"), "i:727:b100.300", "bonus order does not matter")
end)

test("the character's level and spec in a link do not change the key", function()
  eq(PriceBook.Key("item:727::::::::13:1490:::1:12759"), PriceBook.Key("item:727::::::::60:250:::1:12759"))
end)

test("text that is not an item has no key", function()
  eq(PriceBook.Key("hello"), nil)
  eq(PriceBook.Key(nil), nil)
end)

-- Full scans ----------------------------------------------------------------

test("a full scan gives materials a batch price and gear its cheapest listing", function()
  local isMaterial = { [M.STRANGE_DUST] = true }
  local prices = PriceBook.FromScan({
    { key = "i:10940", itemID = M.STRANGE_DUST, count = 20, buyout = 2000 },  -- 100 each
    { key = "i:10940", itemID = M.STRANGE_DUST, count = 1, buyout = 10 },     -- 10 each
    { key = "i:727:b12759", itemID = 727, count = 1, buyout = 5000 },
    { key = "i:727:b12759", itemID = 727, count = 1, buyout = 4000 },
    { key = "i:727:b999", itemID = 727, count = 1, buyout = 9000 },
  }, isMaterial)
  eq(prices["i:10940"], 91) -- (10 + 9 x 100) / 10
  eq(prices["i:727:b12759"], 4000)
  eq(prices["i:727:b999"], 9000)
end)

test("a full scan skips listings without a buyout", function()
  local prices = PriceBook.FromScan({ { key = "i:727", itemID = 727, count = 1, buyout = 0 } }, {})
  eq(prices["i:727"], nil)
end)

-- Keeping prices ------------------------------------------------------------

test("a stored price comes back with its age in days", function()
  local book = {}
  PriceBook.Store(book, { ["i:10940"] = 91 }, 1000 * DAY)
  local price, age = PriceBook.Lookup(book, "i:10940", 1003 * DAY + 100)
  eq(price, 91)
  eq(age, 3)
end)

test("a newer scan replaces the price; items it did not see keep theirs", function()
  local book = {}
  PriceBook.Store(book, { ["i:10940"] = 91, ["i:11083"] = 300 }, 1000 * DAY)
  PriceBook.Store(book, { ["i:10940"] = 80 }, 1002 * DAY)
  eq(PriceBook.Lookup(book, "i:10940", 1002 * DAY), 80)
  local price, age = PriceBook.Lookup(book, "i:11083", 1002 * DAY)
  eq(price, 300)
  eq(age, 2)
end)

test("an unknown item has no price", function()
  eq(PriceBook.Lookup({}, "i:1", 0), nil)
end)

-- Own first, Auctionator second ----------------------------------------------

test("our own price wins; Auctionator's is only used without one", function()
  local own = function() return 500, 2 end
  local none = function() return nil end
  local auctionator = function() return 900, 0 end
  local price, age, source = PriceBook.Choose(own, auctionator)
  eq(price, 500); eq(age, 2); eq(source, "own")
  price, age, source = PriceBook.Choose(none, auctionator)
  eq(price, 900); eq(age, 0); eq(source, "auctionator")
  eq(PriceBook.Choose(none, none), nil)
end)

test("with Auctionator installed its price wins; ours is only used without one", function()
  local own = function() return 500, 2 end
  local none = function() return nil end
  local auctionator = function() return 900, 0 end
  local price, age, source = PriceBook.Choose(own, auctionator, true)
  eq(price, 900); eq(age, 0); eq(source, "auctionator")
  price, age, source = PriceBook.Choose(own, none, true)
  eq(price, 500); eq(age, 2); eq(source, "own")
  eq(PriceBook.Choose(none, none, true), nil)
end)

test("a full scan can be read a few rows at a time", function()
  local scan = PriceBook.NewScan({ [M.STRANGE_DUST] = true })
  scan:Add({ key = "i:10940", itemID = M.STRANGE_DUST, count = 20, buyout = 2000 })
  scan:Add({ key = "i:727", itemID = 727, count = 1, buyout = 5000 })
  scan:Add({ key = "i:10940", itemID = M.STRANGE_DUST, count = 1, buyout = 10 })
  scan:Add({ key = "i:727", itemID = 727, count = 1, buyout = 4000 })
  scan:Add({ key = "i:727", itemID = 727, count = 1, buyout = 0 })
  local prices = scan:Prices()
  eq(prices["i:10940"], 91)
  eq(prices["i:727"], 4000)
end)
