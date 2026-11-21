-- Our own auction prices (docs/adr/0007): what counts as the price, how
-- items are keyed, and how prices are kept. Pure (docs/adr/0006).
local _, ns = ...

local PriceBook = {}
ns.PriceBook = PriceBook

PriceBook.MATERIAL_BATCH = 10 -- units: a material's price is the cost of buying this many
local DAY = 86400

-- The average per-unit cost of buying the cheapest `size` units, rounded
-- down; with fewer units listed, all of them. nil when nothing is listed.
-- listings: { { unitPrice, quantity } }
function PriceBook.BatchPrice(listings, size)
  local sorted = {}
  for _, l in ipairs(listings) do
    if l.unitPrice and l.unitPrice > 0 and l.quantity and l.quantity > 0 then
      sorted[#sorted + 1] = l
    end
  end
  if #sorted == 0 then return nil end
  table.sort(sorted, function(a, b) return a.unitPrice < b.unitPrice end)

  local units, total = 0, 0
  for _, l in ipairs(sorted) do
    local take = math.min(l.quantity, size - units)
    units = units + take
    total = total + take * l.unitPrice
    if units >= size then break end
  end
  return math.floor(total / units)
end

-- The fields of an item string ("item:727::::::::13:..."), empty ones kept.
local function fields(itemString)
  local list, start = {}, 1
  while true do
    local colon = itemString:find(":", start, true)
    list[#list + 1] = itemString:sub(start, (colon or 0) - 1)
    if not colon then return list end
    start = colon + 1
  end
end

-- The key prices are kept under: the item ID, plus its suffix and bonus IDs
-- so "of the Eagle" and "of the Bear" are priced apart. The level and spec
-- of the character who made the link are left out.
function PriceBook.Key(item)
  if type(item) == "number" then return "i:" .. item end
  if type(item) ~= "string" then return nil end
  local itemString = item:match("item:([%-%d:]+)")
  if not itemString then return nil end

  local f = fields(itemString)
  local itemID = tonumber(f[1])
  if not itemID then return nil end
  local key = "i:" .. itemID

  local suffix = tonumber(f[7])
  if suffix and suffix ~= 0 then key = key .. ":s" .. suffix end

  local bonusCount = tonumber(f[13]) or 0
  if bonusCount > 0 then
    local bonuses = {}
    for i = 14, 13 + bonusCount do
      local bonus = tonumber(f[i])
      if bonus then bonuses[#bonuses + 1] = bonus end
    end
    table.sort(bonuses)
    if #bonuses > 0 then key = key .. ":b" .. table.concat(bonuses, ".") end
  end
  return key
end

-- Prices from the rows of a full scan.
-- rows: { { key, itemID, count, buyout (for the whole stack) } }
-- isMaterial: { [itemID] = true } for items priced by the batch
-- Returns { [key] = price }.
function PriceBook.FromScan(rows, isMaterial)
  local scan = PriceBook.NewScan(isMaterial)
  for _, row in ipairs(rows) do scan:Add(row) end
  return scan:Prices()
end

-- A full scan read row by row, so a big auction house can be spread over
-- many frames. Gear keeps only its cheapest listing as it goes; materials
-- keep their listings for the batch price.
-- scan:Add(row) takes one row as FromScan does; scan:Prices() gives the result.
function PriceBook.NewScan(isMaterial)
  local cheapest, materialListings = {}, {}
  local scan = {}

  function scan:Add(row)
    if not (row.key and row.count and row.count > 0 and row.buyout and row.buyout > 0) then return end
    local unitPrice = row.buyout / row.count
    if isMaterial[row.itemID] then
      local listings = materialListings[row.key]
      if not listings then listings = {}; materialListings[row.key] = listings end
      listings[#listings + 1] = { unitPrice = unitPrice, quantity = row.count }
    else
      local best = cheapest[row.key]
      if not best or unitPrice < best then cheapest[row.key] = unitPrice end
    end
  end

  function scan:Prices()
    local prices = {}
    for key, price in pairs(cheapest) do prices[key] = math.floor(price) end
    for key, listings in pairs(materialListings) do
      prices[key] = PriceBook.BatchPrice(listings, PriceBook.MATERIAL_BATCH)
    end
    return prices
  end

  return scan
end

-- Keeps prices seen at `now` (seconds). Items not in `prices` keep theirs.
function PriceBook.Store(book, prices, now)
  for key, price in pairs(prices) do
    book[key] = { p = price, t = now }
  end
end

-- A kept price and its age in whole days, or nil.
function PriceBook.Lookup(book, key, now)
  local entry = key and book[key]
  if not entry then return nil end
  return entry.p, math.max(0, math.floor((now - entry.t) / DAY))
end

-- Our own price first, Auctionator's only without one; with
-- auctionatorFirst (Auctionator is installed, docs/adr/0008) the other way
-- round. Each source is a function returning price, ageDays.
-- Returns price, ageDays, "own" | "auctionator"; nil without either.
function PriceBook.Choose(own, auctionator, auctionatorFirst)
  local order = auctionatorFirst
    and { { auctionator, "auctionator" }, { own, "own" } }
    or { { own, "own" }, { auctionator, "auctionator" } }
  for _, source in ipairs(order) do
    local price, age = source[1]()
    if price then return price, age, source[2] end
  end
  return nil
end
