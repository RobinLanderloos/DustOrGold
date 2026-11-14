-- The text a player reads. Pure (docs/adr/0006): money formatting and
-- material names are passed in by the game layer.
local _, ns = ...

local Display = {}
ns.Display = Display

-- r, g, b per verdict.
Display.Colors = {
  disenchant = { 0.25, 1.00, 0.25 },
  vendor     = { 1.00, 1.00, 1.00 },
  close      = { 1.00, 0.82, 0.00 },
  noprice    = { 0.60, 0.60, 0.60 },
  auction    = { 1.00, 0.60, 0.20 },
}

-- The line about the item's own auction price, for a CompareAuction result.
-- Returns text, color.
function Display.AuctionLine(cmp, L, money, priceAgeDays)
  local text, color
  if cmp.beatsAll then
    text, color = L.AUCTION_BEST, Display.Colors.auction
  elseif cmp.beatsVendor then
    text, color = L.AUCTION_BEATS_VENDOR, Display.Colors.vendor
  else
    text, color = L.AUCTION_BELOW_VENDOR, Display.Colors.noprice
  end
  text = text:format(money(cmp.net))
  if priceAgeDays and priceAgeDays > 1 then
    text = text .. L.PRICE_AGE:format(priceAgeDays)
  end
  return text, color
end

-- The verdict line for an Evaluate result. money(copper) formats an amount.
-- priceAgeDays is the age of the oldest material price, when known.
-- Returns text, color.
function Display.VerdictLine(result, L, money, priceAgeDays)
  local V = ns.Valuation
  local verdict = result.verdict
  if verdict == V.NO_PRICE then
    return L.NO_PRICE, Display.Colors.noprice
  end

  local vendor, disenchant = money(result.vendorValue), money(result.disenchantValue)
  local text
  if verdict == V.DISENCHANT then
    text = L.DISENCHANT_WINS:format(disenchant, vendor)
  elseif verdict == V.VENDOR then
    text = L.VENDOR_WINS:format(vendor, disenchant)
  else
    text = L.CLOSE_CALL:format(disenchant, vendor)
  end
  if priceAgeDays and priceAgeDays > 1 then
    text = text .. L.PRICE_AGE:format(priceAgeDays)
  end
  return text, Display.Colors[verdict]
end

local function percent(chance)
  local pct = chance * 100
  if pct == math.floor(pct) then return ("%d"):format(pct) end
  return ("%.1f"):format(pct)
end

-- What one of a material costs, where the price came from and how old it is.
-- source is "own" or "auctionator".
function Display.PriceNote(price, ageDays, source, L, money)
  if not price then return L.PRICE_NONE end
  local parts = { L.PRICE_EACH:format(money(price)), L.SOURCE[source] or tostring(source) }
  if ageDays == 0 then
    parts[#parts + 1] = L.AGE_TODAY
  elseif ageDays == 1 then
    parts[#parts + 1] = L.AGE_ONE_DAY
  elseif ageDays then
    parts[#parts + 1] = L.AGE_DAYS:format(ageDays)
  end
  return table.concat(parts, ", ")
end

-- One line per drop of a band: chance, material, quantity.
-- nameOf(itemID) returns the material's name. With priceOf(itemID) (returning
-- price, ageDays, source) and money, each line also carries the price.
function Display.BreakdownLines(band, L, nameOf, priceOf, money)
  local lines = {}
  for _, d in ipairs(band.drops) do
    local quantity = d.min == d.max and tostring(d.min) or (d.min .. "-" .. d.max)
    local line = L.BREAKDOWN:format(percent(d.chance), nameOf(d.item), quantity)
    if priceOf then
      local price, age, source = priceOf(d.item)
      line = line .. "  (" .. Display.PriceNote(price, age, source, L, money) .. ")"
    end
    lines[#lines + 1] = line
  end
  return lines
end

-- Every material with its price note, in table order (dusts, essences,
-- shards, crystal), for the materials view.
function Display.MaterialRows(L, nameOf, priceOf, money)
  local rows = {}
  for _, itemID in ipairs(ns.MaterialOrder) do
    local price, age, source = priceOf(itemID)
    rows[#rows + 1] = {
      item = itemID, name = nameOf(itemID), hasPrice = price ~= nil,
      note = Display.PriceNote(price, age, source, L, money),
    }
  end
  return rows
end
