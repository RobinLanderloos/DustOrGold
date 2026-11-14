-- The bag report: bag items grouped by verdict with totals. The list window
-- draws exactly this. Pure (docs/adr/0006).
local _, ns = ...

local BagReport = {}
ns.BagReport = BagReport

-- The group of items without a verdict, listed only on request (debug mode).
BagReport.OTHER = "other"

-- Whether a row gets the Disenchant button.
-- options: { canDisenchant = this character can, buttonOnAll = the setting }
function BagReport.CanCast(verdict, facts, options)
  local V = ns.Valuation
  if not options.canDisenchant then return false end
  if verdict == V.DISENCHANT or verdict == V.CLOSE then return true end
  if not facts or facts.isKept then return false end
  if options.buttonOnAll and V.CouldBeDisenchanted(facts) and not facts.cannotDisenchant then
    return true
  end
  -- In the debug group, a click on an item the game refuses is a safe test.
  return verdict == BagReport.OTHER and not V.CouldBeDisenchanted(facts)
end

-- The group of items worth more listed on the auction house than both
-- vendored and disenchanted. A list group, not a verdict (docs/adr/0003).
BagReport.AUCTION = "auction"

-- entries: a list of { link = ..., result = Evaluate result or nil,
--   auction = CompareAuction result or nil, ... }.
-- options.includeOthers adds the items without a verdict as a last group.
-- Returns the groups that have items, in display order:
--   { verdict, rows, vendorTotal, disenchantTotal (nil for the no-price
--     group), auctionTotal (auction group only) }
-- The other group has no totals.
function BagReport.Build(entries, options)
  local V = ns.Valuation
  local order = { V.VENDOR, V.DISENCHANT, BagReport.AUCTION, V.CLOSE, V.NO_PRICE }
  local byVerdict = {}
  local others = {}

  local function groupOf(entry)
    if entry.auction and entry.auction.beatsAll then return BagReport.AUCTION end
    return entry.result.verdict
  end

  for _, entry in ipairs(entries) do
    local result = entry.result
    if not result then
      others[#others + 1] = entry
    else
      local key = groupOf(entry)
      local group = byVerdict[key]
      if not group then
        group = { verdict = key, rows = {}, vendorTotal = 0 }
        if key ~= V.NO_PRICE then group.disenchantTotal = 0 end
        if key == BagReport.AUCTION then group.auctionTotal = 0 end
        byVerdict[key] = group
      end
      group.rows[#group.rows + 1] = entry
      group.vendorTotal = group.vendorTotal + result.vendorValue
      if group.disenchantTotal then
        group.disenchantTotal = group.disenchantTotal + (result.disenchantValue or 0)
      end
      if group.auctionTotal then
        group.auctionTotal = group.auctionTotal + entry.auction.net
      end
    end
  end

  -- What a row earns if the player follows its group.
  local function earns(entry)
    local result = entry.result
    if groupOf(entry) == BagReport.AUCTION then return entry.auction.net end
    if result.verdict == V.DISENCHANT or result.verdict == V.CLOSE then
      return result.disenchantValue
    end
    return result.vendorValue
  end

  local groups = {}
  for _, verdict in ipairs(order) do
    local group = byVerdict[verdict]
    if group then
      table.sort(group.rows, function(a, b) return earns(a) > earns(b) end)
      groups[#groups + 1] = group
    end
  end

  if options and options.includeOthers and #others > 0 then
    table.sort(others, function(a, b) return tostring(a.link) < tostring(b.link) end)
    groups[#groups + 1] = { verdict = BagReport.OTHER, rows = others }
  end
  return groups
end
