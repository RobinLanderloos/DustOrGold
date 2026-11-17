-- The results log: a record per disenchant, and a comparison of the records
-- with the table (docs/adr/0001). Pure (docs/adr/0006).
local _, ns = ...

local Results = {}
ns.Results = Results

-- facts: the item's facts (itemID, kind, quality, itemLevel, requiredLevel)
-- received: a list of { item = itemID, count = n }, one per loot slot
function Results.Record(facts, received, time)
  local materials = {}
  for _, r in ipairs(received) do
    materials[r.item] = (materials[r.item] or 0) + r.count
  end
  return {
    itemID = facts.itemID,
    kind = facts.kind,
    quality = facts.quality,
    itemLevel = facts.itemLevel,
    requiredLevel = facts.requiredLevel,
    materials = materials,
    time = time,
  }
end

-- The materials of a record in table order (dusts, essences, shards,
-- crystals), then anything else by ID.
function Results.MaterialList(materials)
  local list, listed = {}, {}
  for _, item in ipairs(ns.MaterialOrder) do
    if materials[item] then list[#list + 1] = item; listed[item] = true end
  end
  local rest = {}
  for item in pairs(materials) do
    if not listed[item] then rest[#rest + 1] = item end
  end
  table.sort(rest)
  for _, item in ipairs(rest) do list[#list + 1] = item end
  return list
end

-- What a disenchant put in the bags when no loot window showed it: every
-- material whose count went up between before and after ({ [itemID] = n }).
-- Returns a list of { item = itemID, count = n } in table order.
function Results.Gained(before, after)
  local list = {}
  for _, item in ipairs(ns.MaterialOrder) do
    local gain = (after[item] or 0) - (before[item] or 0)
    if gain > 0 then list[#list + 1] = { item = item, count = gain } end
  end
  return list
end

-- Which item a disenchant used up: the slot whose item left between two
-- looks at the bags. before and now map "bag:slot" to the item's link; only
-- disenchantable items need to be in before. Returns the slot key or nil.
-- With several gone the lowest bag and slot wins, so the answer is stable.
function Results.Vanished(before, now)
  local gone = {}
  for key, link in pairs(before) do
    if now[key] ~= link then gone[#gone + 1] = key end
  end
  table.sort(gone, function(a, b)
    local ab, as = a:match("^(-?%d+):(%d+)$")
    local bb, bs = b:match("^(-?%d+):(%d+)$")
    ab, as, bb, bs = tonumber(ab), tonumber(as), tonumber(bb), tonumber(bs)
    if ab ~= bb then return ab < bb end
    return as < bs
  end)
  return gone[1]
end

-- What one disenchant was worth next to what the table expected, priced like
-- the verdict (Valuation.MaterialPrice, after the auction cut).
-- materials: { [itemID] = count }; band: the item's band or nil.
-- Returns { actual = copper or nil (a received material has no price),
--           expected = copper or nil, missing = { itemID, ... } }.
function Results.Worth(materials, band, getPrice, auctionCut)
  local V = ns.Valuation
  local cut = auctionCut or V.AUCTION_CUT
  local total, missing = 0, {}
  for _, item in ipairs(Results.MaterialList(materials)) do
    local price = V.MaterialPrice(item, getPrice)
    if price then
      total = total + materials[item] * price
    else
      missing[#missing + 1] = item
    end
  end
  local worth = { missing = missing }
  -- The small nudge keeps 900 * 0.95 from flooring to 854.
  if #missing == 0 then worth.actual = math.floor(total * (1 - cut) + 1e-6) end
  if band then worth.expected = V.DisenchantValue(band, getPrice, auctionCut) end
  return worth
end

-- The running total over the log: records that kept both values.
-- Returns { count, actual, expected }.
function Results.Luck(records)
  local luck = { count = 0, actual = 0, expected = 0 }
  for _, r in ipairs(records) do
    if type(r.actual) == "number" and type(r.expected) == "number" then
      luck.count = luck.count + 1
      luck.actual = luck.actual + r.actual
      luck.expected = luck.expected + r.expected
    end
  end
  return luck
end

-- The chance per material of a band; a material can appear in more than one drop.
local function chances(band)
  local byItem, order = {}, {}
  for _, d in ipairs(band.drops) do
    if not byItem[d.item] then order[#order + 1] = d.item end
    byItem[d.item] = (byItem[d.item] or 0) + d.chance
  end
  return byItem, order
end

local function fits(band, materials)
  if not band then return false end
  local byItem = chances(band)
  for item in pairs(materials) do
    if not byItem[item] then return false end
  end
  return true
end

-- Returns {
--   bands = { { kind, quality, min, max, samples,
--               materials = { { item, observed, expected } },
--               unexpected = { { item, times } } } },
--   outsideTable = number of records with no band,
--   levels = { itemLevel = n, requiredLevel = n }: for records where the two
--            levels point at different bands, which one the result fits
-- }
function Results.Compare(records)
  local V = ns.Valuation
  local summary = { bands = {}, outsideTable = 0, levels = { itemLevel = 0, requiredLevel = 0 } }
  local byBand = {}

  for _, record in ipairs(records) do
    local band = V.FindBand(record.kind, record.quality, record.itemLevel)
    if not band then
      summary.outsideTable = summary.outsideTable + 1
    else
      local entry = byBand[band]
      if not entry then
        entry = { band = band, kind = record.kind, quality = record.quality, records = {} }
        byBand[band] = entry
        summary.bands[#summary.bands + 1] = entry
      end
      entry.records[#entry.records + 1] = record
    end

    local byRequired = V.FindBand(record.kind, record.quality, record.requiredLevel)
    if band ~= byRequired then
      local itemFits, requiredFits = fits(band, record.materials), fits(byRequired, record.materials)
      if itemFits and not requiredFits then
        summary.levels.itemLevel = summary.levels.itemLevel + 1
      elseif requiredFits and not itemFits then
        summary.levels.requiredLevel = summary.levels.requiredLevel + 1
      end
    end
  end

  for i, entry in ipairs(summary.bands) do
    local byItem, order = chances(entry.band)
    local seen, unexpected = {}, {}
    for _, record in ipairs(entry.records) do
      for item in pairs(record.materials) do
        seen[item] = (seen[item] or 0) + 1
        if not byItem[item] and not unexpected[item] then
          unexpected[item] = true
          unexpected[#unexpected + 1] = item
        end
      end
    end

    local samples = #entry.records
    local materials = {}
    for _, item in ipairs(order) do
      materials[#materials + 1] = { item = item, observed = (seen[item] or 0) / samples, expected = byItem[item] }
    end
    local unexpectedList = {}
    table.sort(unexpected)
    for _, item in ipairs(unexpected) do
      unexpectedList[#unexpectedList + 1] = { item = item, times = seen[item] }
    end

    summary.bands[i] = {
      kind = entry.kind, quality = entry.quality, min = entry.band.min, max = entry.band.max,
      samples = samples, materials = materials, unexpected = unexpectedList,
    }
  end

  summary.luck = Results.Luck(records)
  table.sort(summary.bands, function(a, b)
    if a.kind ~= b.kind then return a.kind < b.kind end
    if a.quality ~= b.quality then return a.quality < b.quality end
    return a.min < b.min
  end)
  return summary
end

local function percent(share)
  return math.floor(share * 100 + 0.5)
end

-- The summary as chat lines. nameOf(itemID) returns a material's name;
-- money(copper) formats an amount for the luck total.
function Results.Lines(summary, nameOf, money)
  local L = ns.L
  local lines = {}
  for _, band in ipairs(summary.bands) do
    lines[#lines + 1] = L.RESULTS_BAND:format(L.QUALITY[band.quality] or tostring(band.quality),
      L.KIND[band.kind] or band.kind, band.min, band.max, band.samples)
    for _, m in ipairs(band.materials) do
      lines[#lines + 1] = L.RESULTS_MATERIAL:format(nameOf(m.item), percent(m.observed), percent(m.expected))
    end
    for _, u in ipairs(band.unexpected) do
      lines[#lines + 1] = L.RESULTS_UNEXPECTED:format(nameOf(u.item), u.times)
    end
  end
  if summary.outsideTable > 0 then
    lines[#lines + 1] = L.RESULTS_OUTSIDE:format(summary.outsideTable)
  end
  local levels = summary.levels
  if levels.itemLevel + levels.requiredLevel > 0 then
    lines[#lines + 1] = L.RESULTS_LEVELS:format(levels.itemLevel, levels.requiredLevel)
  end
  local luck = summary.luck
  if luck and luck.count > 0 then
    money = money or tostring
    lines[#lines + 1] = L.RESULTS_LUCK:format(luck.count, money(luck.actual), money(luck.expected),
      ns.Display.Difference(luck.actual, luck.expected))
  end
  if #lines == 0 then lines[1] = L.RESULTS_EMPTY end
  return lines
end
