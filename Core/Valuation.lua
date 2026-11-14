-- The verdict: vendor, disenchant, or close call.
--
-- Pure calculation, no game calls (docs/adr/0006). The rule itself is
-- docs/adr/0003; who gets a verdict is docs/adr/0004.
local _, ns = ...

local Valuation = {}
ns.Valuation = Valuation

Valuation.DEFAULT_MARGIN = 0.20
Valuation.AUCTION_CUT = 0.05
-- A drop rarer than this does not block the verdict when it has no price.
Valuation.MIN_CHANCE_NEEDING_PRICE = 0.01

Valuation.VENDOR = "vendor"
Valuation.DISENCHANT = "disenchant"
Valuation.CLOSE = "close"
Valuation.NO_PRICE = "noprice"

-- Whether the game might let the item be disenchanted at all: any uncommon
-- to epic weapon or armor, inside the table or not. Items for which this is
-- false are safe targets for trying the Disenchant button out.
function Valuation.CouldBeDisenchanted(facts)
  return (facts and facts.kind and facts.quality and facts.quality >= 2 and facts.quality <= 4) and true or false
end

-- The item's own auction price against the verdict's numbers. Information
-- only: it never changes the verdict (docs/adr/0003).
-- Returns nil without a price or a result, or for a soulbound item (it
-- cannot be listed), otherwise { price, net (after the cut), beatsVendor, beatsAll }.
function Valuation.CompareAuction(auctionPrice, result, auctionCut)
  if not auctionPrice or not result or result.isBound then return nil end
  local net = math.floor(auctionPrice * (1 - (auctionCut or Valuation.AUCTION_CUT)))
  local beatsVendor = net > result.vendorValue
  -- "Beats all" needs a known Disenchant Value; without one only the vendor is known.
  local beatsAll = beatsVendor and result.disenchantValue ~= nil and net > result.disenchantValue
  return { price = auctionPrice, net = net, beatsVendor = beatsVendor, beatsAll = beatsAll }
end

-- The band for an item, or nil when it cannot be disenchanted.
function Valuation.FindBand(kind, quality, itemLevel)
  local byQuality = kind and ns.DisenchantTable[kind]
  local bands = byQuality and byQuality[quality]
  if not bands or not itemLevel then return nil end
  for _, band in ipairs(bands) do
    if itemLevel >= band.min and itemLevel <= band.max then return band end
  end
  return nil
end

-- Price of one material in copper, or nil. A lesser essence is worth the
-- lower of its own price and a third of its greater essence.
function Valuation.MaterialPrice(itemID, getPrice)
  local own = getPrice(itemID)
  local greaterID = ns.GreaterEssenceOf[itemID]
  local greater = greaterID and getPrice(greaterID)
  if greater then
    local third = greater / 3
    if not own or third < own then return third end
  end
  return own
end

-- Expected value of a band's drops after the auction cut, in copper.
-- Returns value, missing: missing lists the item IDs that have no price and
-- are common enough to matter. With anything missing the value is nil.
function Valuation.DisenchantValue(band, getPrice, auctionCut)
  local total, missing = 0, {}
  for _, d in ipairs(band.drops) do
    local price = Valuation.MaterialPrice(d.item, getPrice)
    if price then
      total = total + d.chance * (d.min + d.max) / 2 * price
    elseif d.chance >= Valuation.MIN_CHANCE_NEEDING_PRICE then
      missing[#missing + 1] = d.item
    end
  end
  if #missing > 0 then return nil, missing end
  return math.floor(total * (1 - (auctionCut or Valuation.AUCTION_CUT))), missing
end

-- item: {
--   kind          "armor" | "weapon" | nil
--   quality       2 uncommon, 3 rare, 4 epic
--   itemLevel     number
--   vendorValue   copper, 0 or nil when vendors will not buy it
--   isBound       true when it can no longer be mailed
--   cannotDisenchant  true when the game says so on the tooltip
--   isKept        true when the player put it on the keep list
-- }
-- context: {
--   getPrice          function(itemID) -> copper or nil
--   margin            0.20 means 20%
--   canDisenchant     this character knows Disenchant
--   hasEnchanterAlt   the account-wide setting
-- }
-- Returns nil and the reason when the item gets no verdict:
--   "kept", "cannotDisenchant" (the game says so), "notDisenchantable" (not an
--   uncommon to epic weapon or armor), "outsideTable", "bound" (this
--   character cannot disenchant and the item cannot be mailed), "noEnchanter"
--   (this character cannot disenchant and has no enchanter to mail items to).
-- Otherwise returns {
--   verdict, vendorValue, disenchantValue (nil without prices), band, missing
-- }. A missing price is the NO_PRICE verdict, not a reason.
function Valuation.Evaluate(item, context)
  if item.isKept then return nil, "kept" end
  if item.cannotDisenchant then return nil, "cannotDisenchant" end
  if not Valuation.CouldBeDisenchanted(item) then return nil, "notDisenchantable" end

  local band = Valuation.FindBand(item.kind, item.quality, item.itemLevel)
  if not band then return nil, "outsideTable" end

  -- A character without Enchanting only gets verdicts on items it can hand
  -- to an enchanter by mail (docs/adr/0004).
  if not context.canDisenchant then
    if item.isBound then return nil, "bound" end
    if not context.hasEnchanterAlt then return nil, "noEnchanter" end
  end

  local vendorValue = item.vendorValue or 0
  local result = { vendorValue = vendorValue, band = band, isBound = item.isBound == true }

  local value, missing = Valuation.DisenchantValue(band, context.getPrice, context.auctionCut)
  result.missing = missing
  if not value then
    result.verdict = Valuation.NO_PRICE
    return result
  end
  result.disenchantValue = value

  local margin = context.margin or Valuation.DEFAULT_MARGIN
  if value > vendorValue * (1 + margin) then
    result.verdict = Valuation.DISENCHANT
  elseif value < vendorValue * (1 - margin) then
    result.verdict = Valuation.VENDOR
  else
    result.verdict = Valuation.CLOSE
  end
  return result
end
